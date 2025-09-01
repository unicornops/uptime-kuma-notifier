#![allow(non_snake_case)]
//! Uptime Kuma Notifier
//! Rewritten main.rs without cacao / objc2_app_kit target/action mixing.
//!
//! Uses only the `objc` runtime for:
//!   * Creating the status bar item
//!   * Building an NSMenu with Preferences / Quit
//!   * Handling target/action via a tiny Objective-C bridge class
//!
//! Preferences editing is delegated to the existing console-driven PreferencesWindow.
//! Dock icon is hidden via LSUIElement in Info.plist.
//!
//! Status is refreshed periodically (interval from preferences). Title updates
//! are dispatched onto the main thread using the `dispatch` crate.

use std::{
    ffi::CString,
    ptr,
    sync::{
        atomic::{AtomicBool, AtomicI32, Ordering},
        Arc, Mutex, RwLock,
    },
    thread,
    time::Duration,
};

use dispatch::Queue;
use objc::{
    class,
    declare::ClassDecl,
    msg_send,
    runtime::{Class, Object, Sel},
    sel, sel_impl,
};

use reqwest::Client;
use tokio::runtime::Runtime;

#[link(name = "AppKit", kind = "framework")]
extern "C" {}

// ------------------------------------------------------------------------------------
// Preference system modules
// ------------------------------------------------------------------------------------
mod native_preferences;
mod preferences;
// Removed legacy console/browser preferences module
mod simple_preferences; // native preferences data manager

use preferences::Preferences;

use simple_preferences::SimplePreferencesManager;

// ------------------------------------------------------------------------------------
// Global UI / bridge state
// ------------------------------------------------------------------------------------

static mut GLOBAL_STATUS_ITEM: *mut Object = ptr::null_mut();
// Removed legacy GLOBAL_PREFERENCES_WINDOW_MUTEX (console prefs deprecated)
static mut MENU_HANDLER_CLASS: *const Class = ptr::null();
static mut MENU_HANDLER_INSTANCE: *mut Object = ptr::null_mut();

static UI_DIRTY: AtomicBool = AtomicBool::new(false);
static LATEST_UP: AtomicI32 = AtomicI32::new(0);
static LATEST_DOWN: AtomicI32 = AtomicI32::new(0);
static LATEST_ERROR: RwLock<Option<String>> = RwLock::new(None);

// ------------------------------------------------------------------------------------
// Helper: create NSString from &str
// ------------------------------------------------------------------------------------
unsafe fn nsstring(s: &str) -> *mut Object {
    let c = CString::new(s).unwrap_or_else(|_| CString::new("").unwrap());
    let ns: *mut Object = msg_send![class!(NSString), alloc];
    let ns: *mut Object = msg_send![ns, initWithUTF8String: c.as_ptr()];
    ns
}

// ------------------------------------------------------------------------------------
// Objective-C bridge class (menu target)
// ------------------------------------------------------------------------------------
unsafe fn register_menu_handler_class() {
    if !MENU_HANDLER_CLASS.is_null() {
        return;
    }
    let superclass = class!(NSObject);
    let mut decl = ClassDecl::new("UKMenuBridgeHandler", superclass).expect("Create class");

    extern "C" fn showPreferences(_this: &Object, _cmd: Sel, _sender: *mut Object) {
        // Always open native preferences window
        crate::native_preferences::show_preferences_native();
    }

    extern "C" fn quitApp(_this: &Object, _cmd: Sel, _sender: *mut Object) {
        println!("👋 Quit selected");
        std::process::exit(0);
    }

    unsafe {
        decl.add_method(
            sel!(showPreferences:),
            showPreferences as extern "C" fn(&Object, Sel, *mut Object),
        );
        decl.add_method(
            sel!(quitApp:),
            quitApp as extern "C" fn(&Object, Sel, *mut Object),
        );
        MENU_HANDLER_CLASS = decl.register();
    }
}

unsafe fn get_menu_handler_instance() -> *mut Object {
    if MENU_HANDLER_CLASS.is_null() {
        register_menu_handler_class();
    }
    if MENU_HANDLER_INSTANCE.is_null() {
        MENU_HANDLER_INSTANCE = msg_send![MENU_HANDLER_CLASS, new];
    }
    MENU_HANDLER_INSTANCE
}

// ------------------------------------------------------------------------------------
// Status updating logic
// ------------------------------------------------------------------------------------
async fn fetch_metrics_once(api_url: &str, api_key: &str) -> Result<(i32, i32), String> {
    let client = Client::new();

    // Try Basic Auth (API key as password)
    let basic = client
        .get(&format!("{}/metrics", api_url))
        .basic_auth("", Some(api_key))
        .timeout(Duration::from_secs(10))
        .send()
        .await
        .map_err(|e| format!("Basic request error: {e}"))?;

    if basic.status().is_success() {
        let text = basic.text().await.unwrap_or_default();
        return Ok(parse_prometheus_metrics(&text));
    }

    if basic.status().as_u16() == 401 {
        // Try Bearer
        let bearer = client
            .get(&format!("{}/metrics", api_url))
            .header("Authorization", format!("Bearer {}", api_key))
            .timeout(Duration::from_secs(10))
            .send()
            .await
            .map_err(|e| format!("Bearer request error: {e}"))?;

        if bearer.status().is_success() {
            let text = bearer.text().await.unwrap_or_default();
            return Ok(parse_prometheus_metrics(&text));
        } else if bearer.status().as_u16() == 401 {
            // Try no auth
            let noauth = client
                .get(&format!("{}/metrics", api_url))
                .timeout(Duration::from_secs(10))
                .send()
                .await
                .map_err(|e| format!("No-auth request error: {e}"))?;
            if noauth.status().is_success() {
                let text = noauth.text().await.unwrap_or_default();
                return Ok(parse_prometheus_metrics(&text));
            } else {
                return Err(format!(
                    "All auth methods failed (last status: {})",
                    noauth.status()
                ));
            }
        } else {
            return Err(format!("Bearer auth failed: {}", bearer.status()));
        }
    }

    Err(format!("Metrics endpoint failed: {}", basic.status()))
}

fn parse_prometheus_metrics(text: &str) -> (i32, i32) {
    let mut up = 0;
    let mut down = 0;
    for line in text.lines() {
        if line.contains("monitor_status{") {
            if let Some(raw) = line.split('}').last() {
                if let Ok(v) = raw.trim().parse::<i32>() {
                    match v {
                        1 => up += 1,
                        0 => down += 1,
                        _ => {}
                    }
                }
            }
        }
    }
    (up, down)
}

fn schedule_ui_update() {
    UI_DIRTY.store(true, Ordering::Relaxed);
    Queue::main().exec_async(|| unsafe {
        if !UI_DIRTY.swap(false, Ordering::Relaxed) {
            return;
        }
        if GLOBAL_STATUS_ITEM.is_null() {
            return;
        }
        let status_item = GLOBAL_STATUS_ITEM;

        let btn: *mut Object = msg_send![status_item, button];
        if btn.is_null() {
            return;
        }

        let up = LATEST_UP.load(Ordering::Relaxed);
        let down = LATEST_DOWN.load(Ordering::Relaxed);
        let err_opt = LATEST_ERROR.read().ok().and_then(|g| g.clone());
        let title = if let Some(err) = err_opt {
            if err.len() > 40 {
                format!("❌ {}", &err[..40])
            } else {
                format!("❌ {err}")
            }
        } else if up == 0 && down == 0 {
            "🔄 Loading...".to_string()
        } else {
            format!("✅ {} 🔴 {}", up, down)
        };

        let ns = nsstring(&title);
        let _: () = msg_send![btn, setTitle: ns];
        // ns will leak intentionally (small; acceptable for status updates)
    });
}

// ------------------------------------------------------------------------------------
// Menu creation
// ------------------------------------------------------------------------------------
unsafe fn build_menu() -> *mut Object {
    let menu: *mut Object = msg_send![class!(NSMenu), alloc];
    let menu: *mut Object = msg_send![menu, init];

    let handler = get_menu_handler_instance();

    // Preferences...
    let prefs_title = nsstring("Preferences...");
    let empty = nsstring("");
    let prefs_item: *mut Object = msg_send![class!(NSMenuItem), alloc];
    let prefs_item: *mut Object = msg_send![prefs_item, initWithTitle:prefs_title action:sel!(showPreferences:) keyEquivalent:empty];
    let _: () = msg_send![prefs_item, setTarget: handler];

    // Separator
    let sep: *mut Object = msg_send![class!(NSMenuItem), separatorItem];

    // Quit
    let quit_title = nsstring("Quit");
    let q = nsstring("q");
    let quit_item: *mut Object = msg_send![class!(NSMenuItem), alloc];
    let quit_item: *mut Object = msg_send![
        quit_item,
        initWithTitle:quit_title
        action:sel!(quitApp:)
        keyEquivalent:q
    ];
    let _: () = msg_send![quit_item, setTarget: handler];

    let _: () = msg_send![menu, addItem: prefs_item];
    let _: () = msg_send![menu, addItem: sep];
    let _: () = msg_send![menu, addItem: quit_item];

    menu
}

// ------------------------------------------------------------------------------------
// App bootstrap
// ------------------------------------------------------------------------------------
fn main() {
    // Ensure NSApplication / AppKit is initialized before touching NSStatusBar
    unsafe {
        let _app: *mut Object = msg_send![class!(NSApplication), sharedApplication];
    }

    // Initialize runtime / preferences
    let runtime = Arc::new(Runtime::new().expect("Tokio runtime"));
    let preferences = Arc::new(Mutex::new(Preferences::load_from_plist())); // load() removed; use plist loader
    let preferences_manager = Arc::new(SimplePreferencesManager::new(Arc::clone(&preferences)));

    // Register native prefs manager (legacy console window removed)
    native_preferences::register_native_prefs(Arc::clone(&preferences_manager));

    // Removed legacy GLOBAL_PREFERENCES_WINDOW_MUTEX initialization

    // Show prefs info (console)
    preferences_manager.show_current_preferences();
    preferences_manager.show_storage_location();

    println!("🔧 Uptime Kuma Notifier starting (menu bar only, dock hidden)");
    println!("   • Click icon → Preferences… to configure (native window)");
    println!("   • Click icon → Quit to exit");

    // Create status bar item & menu
    unsafe {
        let status_bar: *mut Object = msg_send![class!(NSStatusBar), systemStatusBar];
        let status_item: *mut Object = msg_send![status_bar, statusItemWithLength: -1.0f64];

        // Set initial title
        let button: *mut Object = msg_send![status_item, button];
        if !button.is_null() {
            let ns = nsstring("🔄 Loading...");
            let _: () = msg_send![button, setTitle: ns];
        }

        // Attach menu
        let menu = build_menu();
        let _: () = msg_send![status_item, setMenu: menu];

        GLOBAL_STATUS_ITEM = status_item;
    }

    // Spawn status monitoring thread
    {
        let runtime_clone = Arc::clone(&runtime);
        let prefs_clone = Arc::clone(&preferences);

        thread::spawn(move || loop {
            let (api_url, api_key, interval) = {
                if let Ok(p) = prefs_clone.lock() {
                    (
                        p.api_url.clone(),
                        p.api_key.clone(),
                        p.refresh_interval.max(5).min(3600),
                    )
                } else {
                    (
                        "https://uptime.example.com".to_string(),
                        "invalid_key".to_string(),
                        30,
                    )
                }
            };

            let result =
                runtime_clone.block_on(async { fetch_metrics_once(&api_url, &api_key).await });

            match result {
                Ok((up, down)) => {
                    LATEST_UP.store(up, Ordering::Relaxed);
                    LATEST_DOWN.store(down, Ordering::Relaxed);
                    if let Ok(mut e) = LATEST_ERROR.write() {
                        *e = None;
                    }
                }
                Err(err) => {
                    LATEST_UP.store(0, Ordering::Relaxed);
                    LATEST_DOWN.store(0, Ordering::Relaxed);
                    if let Ok(mut e) = LATEST_ERROR.write() {
                        *e = Some(err);
                    }
                }
            }
            schedule_ui_update();
            thread::sleep(Duration::from_secs(interval));
        });
    }

    // Run NSApplication main loop (agent / LSUIElement)
    unsafe {
        let app: *mut Object = msg_send![class!(NSApplication), sharedApplication];
        // No dock icon (Info.plist LSUIElement). Just run loop.
        let _: () = msg_send![app, run];
    }
}
