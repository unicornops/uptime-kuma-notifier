/*
    native_preferences.rs

    Native macOS preferences panel implemented directly with the
    `objc` runtime (no cocoa wrapper crates) to avoid mixed
    objc2 version conflicts.

    Features:
      * Single modeless window
      * Auto Layout (NSStackView + constraints) instead of manual frames
      * Fields:
          - API URL (NSTextField)
          - API Key (NSSecureTextField)
          - Refresh Interval (NSTextField numeric)
          - Show Notifications (NSButton checkbox)
      * Actions:
          - Test Connection (async, non‑blocking)
          - Save
          - Close
      * Status feedback label
      * Reuses one window instance

    Safety:
      * Some objects are intentionally leaked for lifetime = process.
      * All UI ops must stay on main thread.

    Integration:
      1. Call `native_preferences::register_native_prefs(manager_arc)` once at startup.
      2. Menu action calls `native_preferences::show_preferences_native()`.
*/

use std::ffi::CString;
use std::sync::Arc;

use objc::{
    class,
    declare::ClassDecl,
    msg_send,
    runtime::{Class, Object, Sel},
    sel, sel_impl,
};

use crate::simple_preferences::SimplePreferencesManager;
use dispatch::Queue;

// -------------------------------------------------------------------------------------------------
// Basic geometry structs (mirroring AppKit)
// -------------------------------------------------------------------------------------------------
#[repr(C)]
#[derive(Copy, Clone)]
struct NSPoint {
    x: f64,
    y: f64,
}
#[repr(C)]
#[derive(Copy, Clone)]
struct NSSize {
    width: f64,
    height: f64,
}
#[repr(C)]
#[derive(Copy, Clone)]
struct NSRect {
    origin: NSPoint,
    size: NSSize,
}

// -------------------------------------------------------------------------------------------------
// Globals
// -------------------------------------------------------------------------------------------------
static mut PREFS_MANAGER_PTR: *const SimplePreferencesManager = std::ptr::null();
static mut PREFS_WINDOW: *mut Object = std::ptr::null_mut();
static mut PREFS_CONTROLLER: *mut Object = std::ptr::null_mut();
static mut PREFS_CONTROLLER_CLASS: *const Class = std::ptr::null();

// Ivar names
const IVAR_API_URL: &str = "apiUrlField";
const IVAR_API_KEY: &str = "apiKeyField";
const IVAR_REFRESH: &str = "refreshField";
const IVAR_NOTIFY: &str = "notifyCheckbox";
const IVAR_STATUS: &str = "statusLabel";
const IVAR_TEST_BUTTON: &str = "testButton";
const IVAR_MANAGER: &str = "managerPtr";
const IVAR_WINDOW: &str = "windowRef";

// -------------------------------------------------------------------------------------------------
// Public API
// -------------------------------------------------------------------------------------------------

/// Register (store) the Arc manager globally. Should be called once during startup.
pub fn register_native_prefs(manager: Arc<SimplePreferencesManager>) {
    unsafe {
        if PREFS_MANAGER_PTR.is_null() {
            // Convert Arc into raw pointer (will live for process lifetime). We intentionally
            // never reclaim it since this is a menu-bar utility.
            let raw: *const SimplePreferencesManager = Arc::into_raw(manager);
            PREFS_MANAGER_PTR = raw;
        }
    }
}

/// Show (or create) the preferences window.
pub fn show_preferences_native() {
    unsafe {
        if PREFS_WINDOW.is_null() {
            ensure_controller_class();
            build_window_and_controller();
        }
        if PREFS_WINDOW.is_null() {
            eprintln!("Failed to build preferences window");
            return;
        }

        // Refresh displayed values each time (in case they changed externally)
        populate_fields_from_prefs();

        let _: () = msg_send![PREFS_WINDOW, makeKeyAndOrderFront: std::ptr::null::<Object>()];
        let _: () = msg_send![PREFS_WINDOW, orderFrontRegardless];
    }
}

// -------------------------------------------------------------------------------------------------
// Helper: create NSString from &str
// -------------------------------------------------------------------------------------------------
unsafe fn nsstring(s: &str) -> *mut Object {
    let c = CString::new(s).unwrap_or_else(|_| CString::new("").unwrap());
    let ns: *mut Object = msg_send![class!(NSString), alloc];
    let ns: *mut Object = msg_send![ns, initWithUTF8String: c.as_ptr()];
    ns
}

/// Auto Layout helper: create a constraint matching the same anchor (leading / top)
/// sub_attr should be a selector like leadingAnchor / topAnchor on the subview
/// Constant is applied directly (positive values inset).
unsafe fn constraint_make(
    superview: *mut Object,
    subview: *mut Object,
    sub_attr: Sel,
    _m1: f64,
    _m2: f64,
    constant: f64,
) -> *mut Object {
    // anchor1 = subview.attr, anchor2 = superview.attr
    let anchor1: *mut Object = msg_send![subview, performSelector: sub_attr];
    let anchor2: *mut Object = msg_send![superview, performSelector: sub_attr];
    if anchor1.is_null() || anchor2.is_null() {
        return std::ptr::null_mut();
    }
    let constraint: *mut Object =
        msg_send![anchor1, constraintEqualToAnchor: anchor2 constant: constant];
    constraint
}

/// Auto Layout helper for trailing / bottom with a (possibly negative) constant.
/// We look up the requested anchor on both objects similarly.
unsafe fn constraint_make_equal_attr(
    subview: *mut Object,
    superview: *mut Object,
    attr: Sel,
    constant: f64,
) -> *mut Object {
    let anchor1: *mut Object = msg_send![subview, performSelector: attr];
    let anchor2: *mut Object = msg_send![superview, performSelector: attr];
    if anchor1.is_null() || anchor2.is_null() {
        return std::ptr::null_mut();
    }
    let constraint: *mut Object =
        msg_send![anchor1, constraintEqualToAnchor: anchor2 constant: constant];
    constraint
}

// -------------------------------------------------------------------------------------------------
// Controller class definition
// -------------------------------------------------------------------------------------------------
unsafe fn ensure_controller_class() {
    if !PREFS_CONTROLLER_CLASS.is_null() {
        return;
    }

    let superclass = class!(NSObject);
    let mut decl = ClassDecl::new("UKPreferencesPanelController", superclass)
        .expect("Create UKPreferencesPanelController class");

    // Add ivars
    decl.add_ivar::<*mut Object>(IVAR_API_URL);
    decl.add_ivar::<*mut Object>(IVAR_API_KEY);
    decl.add_ivar::<*mut Object>(IVAR_REFRESH);
    decl.add_ivar::<*mut Object>(IVAR_NOTIFY);
    decl.add_ivar::<*mut Object>(IVAR_STATUS);
    decl.add_ivar::<usize>(IVAR_MANAGER);
    decl.add_ivar::<*mut Object>(IVAR_WINDOW);
    decl.add_ivar::<*mut Object>(IVAR_TEST_BUTTON);

    // saveAction:
    extern "C" fn save_action(this: &Object, _cmd: Sel, _sender: *mut Object) {
        unsafe {
            if PREFS_MANAGER_PTR.is_null() {
                status_message(this, "No manager");
                return;
            }
            let manager = &*PREFS_MANAGER_PTR;

            let api_url_field: *mut Object = *this.get_ivar(IVAR_API_URL);
            let api_key_field: *mut Object = *this.get_ivar(IVAR_API_KEY);
            let refresh_field: *mut Object = *this.get_ivar(IVAR_REFRESH);
            let notify_checkbox: *mut Object = *this.get_ivar(IVAR_NOTIFY);

            let api_url = nsstring_to_rust(api_url_field);
            let api_key = nsstring_to_rust(api_key_field);
            let refresh_raw = nsstring_to_rust(refresh_field);
            let refresh_interval = refresh_raw.parse::<u64>().unwrap_or(30).clamp(5, 3600);

            let state: i64 = msg_send![notify_checkbox, state];
            let show_notifications = state == 1; // NSControlStateValueOn = 1

            match manager.save_preferences(api_url, api_key, refresh_interval, show_notifications) {
                Ok(_) => status_message(this, "✅ Saved"),
                Err(e) => status_message(this, &format!("❌ Save failed: {e}")),
            }
        }
    }

    // cancelAction:
    extern "C" fn cancel_action(this: &Object, _cmd: Sel, _sender: *mut Object) {
        unsafe {
            let window: *mut Object = *this.get_ivar(IVAR_WINDOW);
            if !window.is_null() {
                let _: () = msg_send![window, orderOut: std::ptr::null::<Object>()];
            }
        }
    }

    decl.add_method(
        sel!(saveAction:),
        save_action as extern "C" fn(&Object, Sel, *mut Object),
    );
    decl.add_method(
        sel!(cancelAction:),
        cancel_action as extern "C" fn(&Object, Sel, *mut Object),
    );

    // testConnectionAction:
    extern "C" fn test_connection_action(this: &Object, _cmd: Sel, _sender: *mut Object) {
        unsafe {
            if PREFS_MANAGER_PTR.is_null() {
                status_message(this, "No manager");
                return;
            }
            // Pass controller pointer as a plain usize to satisfy 'Send' bounds in closures.
            let controller_raw = this as *const Object as usize;

            // Read current field values but do not save (copy into owned Strings for thread move).
            let api_url_field: *mut Object = *this.get_ivar(IVAR_API_URL);
            let api_key_field: *mut Object = *this.get_ivar(IVAR_API_KEY);

            let api_url = nsstring_to_rust(api_url_field);
            let api_key = nsstring_to_rust(api_key_field);

            status_message(this, "⏳ Testing...");

            std::thread::spawn(move || {
                let rt = tokio::runtime::Runtime::new();
                if let Ok(rt) = rt {
                    let result =
                        rt.block_on(async { super::fetch_metrics_once(&api_url, &api_key).await });
                    let controller_val = controller_raw;
                    Queue::main().exec_async(move || {
                        if controller_val == 0 {
                            return;
                        }
                        let controller_ptr = controller_val as *mut Object;
                        match result {
                            Ok((up, down)) => status_message(
                                &*controller_ptr,
                                &format!("✅ OK Up:{up} Down:{down}"),
                            ),
                            Err(e) => status_message(&*controller_ptr, &format!("❌ {e}")),
                        }
                    });
                } else {
                    let controller_val = controller_raw;
                    Queue::main().exec_async(move || {
                        if controller_val == 0 {
                            return;
                        }
                        let controller_ptr = controller_val as *mut Object;
                        status_message(&*controller_ptr, "❌ Failed runtime");
                    });
                }
            });
        }
    }

    decl.add_method(
        sel!(testConnectionAction:),
        test_connection_action as extern "C" fn(&Object, Sel, *mut Object),
    );

    // NSTextField delegate - enforce numeric-only + clamp (for refresh interval field)
    extern "C" fn control_text_did_change(this: &Object, _cmd: Sel, notification: *mut Object) {
        unsafe {
            // Get our tracked refresh field
            let refresh_field: *mut Object = *this.get_ivar(IVAR_REFRESH);
            if refresh_field.is_null() {
                return;
            }
            // Identify which field changed
            let changed: *mut Object = msg_send![notification, object];
            if changed != refresh_field {
                return; // not our field
            }
            // Current string
            let current = nsstring_to_rust(refresh_field);
            // Filter to digits only
            let filtered: String = current.chars().filter(|c| c.is_ascii_digit()).collect();
            let mut changed_flag = false;
            if filtered != current {
                changed_flag = true;
            }
            // Clamp if parseable
            let clamped_str = if let Ok(v) = filtered.parse::<u64>() {
                let c = v.clamp(5, 3600);
                if c.to_string() != filtered {
                    changed_flag = true;
                }
                c.to_string()
            } else {
                filtered
            };
            if changed_flag {
                let _: () = msg_send![refresh_field, setStringValue: nsstring(&clamped_str)];
            }
        }
    }
    decl.add_method(
        sel!(controlTextDidChange:),
        control_text_did_change as extern "C" fn(&Object, Sel, *mut Object),
    );

    PREFS_CONTROLLER_CLASS = decl.register();
}

// -------------------------------------------------------------------------------------------------
// Build window & UI
// -------------------------------------------------------------------------------------------------
unsafe fn build_window_and_controller() {
    // Create controller
    PREFS_CONTROLLER = msg_send![PREFS_CONTROLLER_CLASS, new];

    // Window (utility size)
    let style_mask: u64 = (1 << 0)  // NSTitledWindowMask
        | (1 << 1)                  // NSClosableWindowMask
        | (1 << 3); // NSMiniaturizableWindowMask (optional)
    let backing: u64 = 2; // NSBackingStoreBuffered
    let defer: bool = false;

    let frame = NSRect {
        origin: NSPoint { x: 0.0, y: 0.0 },
        size: NSSize {
            width: 480.0,
            height: 300.0,
        },
    };

    let window: *mut Object = msg_send![class!(NSWindow), alloc];
    let window: *mut Object = msg_send![window, initWithContentRect:frame styleMask:style_mask backing:backing defer:defer];
    let title = nsstring("Uptime Kuma Preferences");
    let _: () = msg_send![window, setTitle: title];
    let _: () = msg_send![window, setReleasedWhenClosed: false];

    // Store window in controller ivar
    (&mut *PREFS_CONTROLLER).set_ivar(IVAR_WINDOW, window);

    // Build controls with Auto Layout
    let content_view: *mut Object = msg_send![window, contentView];
    let stack: *mut Object = msg_send![class!(NSStackView), alloc];
    let stack: *mut Object = msg_send![stack, init];
    let _: () = msg_send![stack, setOrientation: 1_i64]; // 1 = vertical
    let _: () = msg_send![stack, setAlignment: 1_i64]; // leading
    let _: () = msg_send![stack, setSpacing: 12.0f64];
    let _: () = msg_send![stack, setTranslatesAutoresizingMaskIntoConstraints: false];
    let _: () = msg_send![content_view, addSubview: stack];

    // Convenience helper to make a label
    unsafe fn make_label(text: &str) -> *mut Object {
        let lbl: *mut Object = msg_send![class!(NSTextField), alloc];
        let lbl: *mut Object = msg_send![lbl, init];
        let _: () = msg_send![lbl, setEditable: false];
        let _: () = msg_send![lbl, setBezeled: false];
        let _: () = msg_send![lbl, setDrawsBackground: false];
        let _: () = msg_send![lbl, setStringValue: nsstring(text)];
        lbl
    }

    unsafe fn make_text_field(secure: bool) -> *mut Object {
        if secure {
            let f: *mut Object = msg_send![class!(NSSecureTextField), alloc];
            let f: *mut Object = msg_send![f, init];
            let _: () = msg_send![f, setTranslatesAutoresizingMaskIntoConstraints: false];
            f
        } else {
            let f: *mut Object = msg_send![class!(NSTextField), alloc];
            let f: *mut Object = msg_send![f, init];
            let _: () = msg_send![f, setTranslatesAutoresizingMaskIntoConstraints: false];
            f
        }
    }

    unsafe fn add_row(stack: *mut Object, label_text: &str, field: *mut Object) -> *mut Object {
        let row: *mut Object = msg_send![class!(NSStackView), alloc];
        let row: *mut Object = msg_send![row, init];
        let _: () = msg_send![row, setOrientation: 0_i64]; // horizontal
        let _: () = msg_send![row, setAlignment: 1_i64];
        let _: () = msg_send![row, setSpacing: 8.0f64];
        let _: () = msg_send![row, setTranslatesAutoresizingMaskIntoConstraints: false];

        let lbl = make_label(label_text);
        let _: () = msg_send![row, addArrangedSubview: lbl];
        let _: () = msg_send![row, addArrangedSubview: field];
        let _: () = msg_send![stack, addArrangedSubview: row];
        field
    }

    // Fields
    let api_url_field = make_text_field(false);
    add_row(stack, "API URL:", api_url_field);

    let api_key_field = make_text_field(true);
    add_row(stack, "API Key:", api_key_field);

    let refresh_field = make_text_field(false);
    // Enforce numeric-only integer input (5 - 3600) using delegate filtering
    // We set the controller as the delegate; see controlTextDidChange: implementation.
    let _: () = msg_send![refresh_field, setDelegate: PREFS_CONTROLLER];
    add_row(stack, "Refresh Interval (seconds):", refresh_field);

    // Checkbox row
    let notify_row: *mut Object = msg_send![class!(NSStackView), alloc];
    let notify_row: *mut Object = msg_send![notify_row, init];
    let _: () = msg_send![notify_row, setOrientation: 0_i64];
    let _: () = msg_send![notify_row, setAlignment: 1_i64];
    let _: () = msg_send![notify_row, setSpacing: 8.0f64];
    let _: () = msg_send![notify_row, setTranslatesAutoresizingMaskIntoConstraints: false];
    let notify_label = make_label("Show Notifications:");
    let notify_checkbox: *mut Object = msg_send![class!(NSButton), alloc];
    let notify_checkbox: *mut Object = msg_send![notify_checkbox, init];
    let _: () = msg_send![notify_checkbox, setButtonType: 3u64];
    let _: () = msg_send![notify_checkbox, setTitle: nsstring("")];
    let _: () = msg_send![notify_row, addArrangedSubview: notify_label];
    let _: () = msg_send![notify_row, addArrangedSubview: notify_checkbox];
    let _: () = msg_send![stack, addArrangedSubview: notify_row];

    // Status label
    let status_label = make_label("");
    let _: () = msg_send![stack, addArrangedSubview: status_label];

    // Action buttons row
    let buttons_row: *mut Object = msg_send![class!(NSStackView), alloc];
    let buttons_row: *mut Object = msg_send![buttons_row, init];
    let _: () = msg_send![buttons_row, setOrientation: 0_i64];
    let _: () = msg_send![buttons_row, setAlignment: 1_i64];
    let _: () = msg_send![buttons_row, setSpacing: 12.0f64];
    let _: () = msg_send![buttons_row, setTranslatesAutoresizingMaskIntoConstraints: false];

    let test_btn: *mut Object = msg_send![class!(NSButton), alloc];
    let test_btn: *mut Object = msg_send![test_btn, init];
    let _: () = msg_send![test_btn, setTitle: nsstring("Test Connection")];
    let _: () = msg_send![test_btn, setTarget: PREFS_CONTROLLER];
    let _: () = msg_send![test_btn, setAction: sel!(testConnectionAction:)];

    let save_btn: *mut Object = msg_send![class!(NSButton), alloc];
    let save_btn: *mut Object = msg_send![save_btn, init];
    let _: () = msg_send![save_btn, setTitle: nsstring("Save")];
    let _: () = msg_send![save_btn, setTarget: PREFS_CONTROLLER];
    let _: () = msg_send![save_btn, setAction: sel!(saveAction:)];

    let close_btn: *mut Object = msg_send![class!(NSButton), alloc];
    let close_btn: *mut Object = msg_send![close_btn, init];
    let _: () = msg_send![close_btn, setTitle: nsstring("Close")];
    let _: () = msg_send![close_btn, setTarget: PREFS_CONTROLLER];
    let _: () = msg_send![close_btn, setAction: sel!(cancelAction:)];

    // Flexible spacer (NSView)
    let spacer: *mut Object = msg_send![class!(NSView), alloc];
    let spacer: *mut Object = msg_send![spacer, init];
    let _: () = msg_send![spacer, setTranslatesAutoresizingMaskIntoConstraints: false];

    let _: () = msg_send![buttons_row, addArrangedSubview: test_btn];
    let _: () = msg_send![buttons_row, addArrangedSubview: spacer];
    let _: () = msg_send![buttons_row, addArrangedSubview: save_btn];
    let _: () = msg_send![buttons_row, addArrangedSubview: close_btn];
    let _: () = msg_send![stack, addArrangedSubview: buttons_row];

    // Constraints for stack inside content_view
    let _: () = msg_send![content_view, addConstraint:
        constraint_make(content_view, stack, sel!(leadingAnchor),  1.0, 1.0, 20.0)];
    let _: () = msg_send![content_view, addConstraint:
        constraint_make(content_view, stack, sel!(topAnchor),      1.0, 1.0, 20.0)];
    let _: () = msg_send![content_view, addConstraint:
        constraint_make_equal_attr(stack, content_view, sel!(trailingAnchor), -20.0)];
    let _: () = msg_send![content_view, addConstraint:
        constraint_make_equal_attr(stack, content_view, sel!(bottomAnchor),   -20.0)];

    // Buttons
    // (Replaced by Auto Layout buttons row above)

    // (Replaced by Auto Layout buttons row above)

    // (Replaced by Auto Layout buttons row above)

    // Assign ivars
    (&mut *PREFS_CONTROLLER).set_ivar(IVAR_API_URL, api_url_field);
    (&mut *PREFS_CONTROLLER).set_ivar(IVAR_API_KEY, api_key_field);
    (&mut *PREFS_CONTROLLER).set_ivar(IVAR_REFRESH, refresh_field);
    (&mut *PREFS_CONTROLLER).set_ivar(IVAR_NOTIFY, notify_checkbox);
    (&mut *PREFS_CONTROLLER).set_ivar(IVAR_STATUS, status_label);
    (&mut *PREFS_CONTROLLER).set_ivar(IVAR_TEST_BUTTON, test_btn);

    // Manager pointer
    if PREFS_MANAGER_PTR.is_null() {
        eprintln!("WARNING: Preferences manager not registered before opening window.");
    } else {
        let ptr_val = PREFS_MANAGER_PTR as usize;
        (&mut *PREFS_CONTROLLER).set_ivar(IVAR_MANAGER, ptr_val);
    }

    PREFS_WINDOW = window;
}

/// Populate fields with stored preferences (called each show).
unsafe fn populate_fields_from_prefs() {
    if PREFS_MANAGER_PTR.is_null() || PREFS_CONTROLLER.is_null() {
        return;
    }
    let manager = &*PREFS_MANAGER_PTR;
    let prefs = manager.get_preferences();

    let api_url_field: *mut Object = *(*PREFS_CONTROLLER).get_ivar(IVAR_API_URL);
    let api_key_field: *mut Object = *(*PREFS_CONTROLLER).get_ivar(IVAR_API_KEY);
    let refresh_field: *mut Object = *(*PREFS_CONTROLLER).get_ivar(IVAR_REFRESH);
    let notify_checkbox: *mut Object = *(*PREFS_CONTROLLER).get_ivar(IVAR_NOTIFY);
    let status_label: *mut Object = *(*PREFS_CONTROLLER).get_ivar(IVAR_STATUS);

    let _: () = msg_send![api_url_field, setStringValue: nsstring(&prefs.api_url)];
    let _: () = msg_send![api_key_field, setStringValue: nsstring(&prefs.api_key)];
    let _: () =
        msg_send![refresh_field, setStringValue: nsstring(&prefs.refresh_interval.to_string())];
    let state: i64 = if prefs.show_notifications { 1 } else { 0 };
    let _: () = msg_send![notify_checkbox, setState: state];
    let _: () = msg_send![status_label, setStringValue: nsstring("")];
}

// Helper: update status message label
unsafe fn status_message(this: &Object, msg: &str) {
    let status_label: *mut Object = *this.get_ivar(IVAR_STATUS);
    if !status_label.is_null() {
        let _: () = msg_send![status_label, setStringValue: nsstring(msg)];
    }
}

// Convert NSTextField stringValue -> Rust String
unsafe fn nsstring_to_rust(field: *mut Object) -> String {
    if field.is_null() {
        return String::new();
    }
    let ns: *mut Object = msg_send![field, stringValue];
    if ns.is_null() {
        return String::new();
    }
    let cstr: *const std::os::raw::c_char = msg_send![ns, UTF8String];
    if cstr.is_null() {
        return String::new();
    }
    let bytes = std::ffi::CStr::from_ptr(cstr).to_bytes().to_vec();
    String::from_utf8(bytes).unwrap_or_default()
}
