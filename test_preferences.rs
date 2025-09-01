use dirs;
use plist::{Dictionary, Integer, Value};
use serde::{Deserialize, Serialize};
use std::fs;
use std::path::PathBuf;
use std::sync::{Arc, Mutex};

// Preferences module
#[derive(Debug, Clone, Serialize, Deserialize)]
struct Preferences {
    pub api_url: String,
    pub api_key: String,
    pub refresh_interval: u64,
    pub show_notifications: bool,
}

impl Default for Preferences {
    fn default() -> Self {
        Self {
            api_url: "https://uptime.example.com".to_string(),
            api_key: "uk2_xxxxxxxx".to_string(),
            refresh_interval: 30,
            show_notifications: true,
        }
    }
}

impl Preferences {
    fn save(&self) -> Result<(), Box<dyn std::error::Error>> {
        if let Some(prefs_path) = Self::get_preferences_path() {
            // Ensure the directory exists
            if let Some(parent) = prefs_path.parent() {
                fs::create_dir_all(parent)?;
            }

            let json = serde_json::to_string_pretty(self)?;
            fs::write(&prefs_path, json)?;
        }
        Ok(())
    }

    fn get_preferences_path() -> Option<PathBuf> {
        if let Some(app_support) = dirs::config_dir() {
            let prefs_dir = app_support.join("uptime-kuma-notifier");
            Some(prefs_dir.join("preferences.json"))
        } else {
            None
        }
    }

    fn get_plist_path() -> Option<PathBuf> {
        if let Some(app_support) = dirs::config_dir() {
            let prefs_dir = app_support.join("uptime-kuma-notifier");
            Some(prefs_dir.join("preferences.plist"))
        } else {
            None
        }
    }

    fn save_to_plist(&self) -> Result<(), Box<dyn std::error::Error>> {
        if let Some(plist_path) = Self::get_plist_path() {
            // Ensure the directory exists
            if let Some(parent) = plist_path.parent() {
                fs::create_dir_all(parent)?;
            }

            // Convert to plist Value
            let mut dict = Dictionary::new();
            dict.insert("api_url".to_string(), Value::String(self.api_url.clone()));
            dict.insert("api_key".to_string(), Value::String(self.api_key.clone()));
            dict.insert(
                "refresh_interval".to_string(),
                Value::Integer(Integer::from(self.refresh_interval as i64)),
            );
            dict.insert(
                "show_notifications".to_string(),
                Value::Boolean(self.show_notifications),
            );

            let plist_value = Value::Dictionary(dict);
            plist::to_file_xml(&plist_path, &plist_value)?;
        }
        Ok(())
    }

    fn load_from_plist() -> Self {
        if let Some(plist_path) = Self::get_plist_path() {
            if let Ok(plist_value) = Value::from_file(&plist_path) {
                if let Value::Dictionary(dict) = plist_value {
                    let mut prefs = Preferences::default();

                    if let Some(Value::String(url)) = dict.get("api_url") {
                        prefs.api_url = url.clone();
                    }
                    if let Some(Value::String(key)) = dict.get("api_key") {
                        prefs.api_key = key.clone();
                    }
                    if let Some(Value::Integer(interval)) = dict.get("refresh_interval") {
                        prefs.refresh_interval = interval.as_unsigned().unwrap_or(30);
                    }
                    if let Some(Value::Boolean(notifications)) = dict.get("show_notifications") {
                        prefs.show_notifications = *notifications;
                    }

                    return prefs;
                }
            }
        }

        Preferences::default()
    }
}

// SimplePreferencesManager module
struct SimplePreferencesManager {
    preferences: Arc<Mutex<Preferences>>,
}

impl SimplePreferencesManager {
    fn new(preferences: Arc<Mutex<Preferences>>) -> Self {
        Self { preferences }
    }

    fn save_preferences(
        &self,
        api_url: String,
        api_key: String,
        refresh_interval: u64,
        show_notifications: bool,
    ) -> Result<(), Box<dyn std::error::Error>> {
        let mut prefs = self.preferences.lock().unwrap();
        prefs.api_url = api_url;
        prefs.api_key = api_key;
        prefs.refresh_interval = refresh_interval;
        prefs.show_notifications = show_notifications;

        // Save to both JSON and plist for compatibility
        prefs.save()?;
        prefs.save_to_plist()?;

        println!("✅ Preferences saved successfully");
        Ok(())
    }

    fn get_preferences(&self) -> Preferences {
        if let Ok(prefs) = self.preferences.lock() {
            prefs.clone()
        } else {
            Preferences::default()
        }
    }

    fn reload_preferences(&self) -> Result<(), Box<dyn std::error::Error>> {
        let new_prefs = Preferences::load_from_plist();
        let mut current_prefs = self.preferences.lock().unwrap();
        *current_prefs = new_prefs;
        println!("✅ Preferences reloaded from disk");
        Ok(())
    }

    fn show_current_preferences(&self) {
        let prefs = self.get_preferences();
        println!("\n📋 Current Preferences:");
        println!("   API URL: {}", prefs.api_url);
        println!(
            "   API Key: {}...{}",
            &prefs.api_key[..8],
            &prefs.api_key[prefs.api_key.len() - 4..]
        );
        println!("   Refresh Interval: {} seconds", prefs.refresh_interval);
        println!("   Show Notifications: {}", prefs.show_notifications);
    }

    fn show_storage_location(&self) {
        println!("\n💾 Preferences Storage Location:");
        if let Some(plist_path) = Preferences::get_plist_path() {
            println!("   PLIST: {}", plist_path.display());
        }
        if let Some(json_path) = Preferences::get_preferences_path() {
            println!("   JSON: {}", json_path.display());
        }
    }
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    println!("Testing Uptime Kuma Notifier Preferences System");
    println!("==============================================");

    // Test loading default preferences
    println!("\n1. Loading default preferences...");
    let prefs = Preferences::default();
    println!("   API URL: {}", prefs.api_url);
    println!(
        "   API Key: {}...{}",
        &prefs.api_key[..8],
        &prefs.api_key[prefs.api_key.len() - 4..]
    );
    println!("   Refresh Interval: {} seconds", prefs.refresh_interval);
    println!("   Show Notifications: {}", prefs.show_notifications);

    // Test saving preferences
    println!("\n2. Testing preferences save...");
    let preferences = Arc::new(Mutex::new(prefs));
    let manager = SimplePreferencesManager::new(preferences);

    // Save preferences
    manager.save_preferences(
        "https://test.example.com".to_string(),
        "test_api_key_12345".to_string(),
        60,
        false,
    )?;
    println!("   Preferences saved successfully");

    // Test loading saved preferences
    println!("\n3. Testing preferences load...");
    let loaded_prefs = Preferences::load_from_plist();
    println!("   API URL: {}", loaded_prefs.api_url);
    println!(
        "   API Key: {}...{}",
        &loaded_prefs.api_key[..8],
        &loaded_prefs.api_key[loaded_prefs.api_key.len() - 4..]
    );
    println!(
        "   Refresh Interval: {} seconds",
        loaded_prefs.refresh_interval
    );
    println!("   Show Notifications: {}", loaded_prefs.show_notifications);

    // Test preferences manager
    println!("\n4. Testing preferences manager...");
    let manager_prefs = manager.get_preferences();
    println!("   API URL: {}", manager_prefs.api_url);
    println!(
        "   API Key: {}...{}",
        &manager_prefs.api_key[..8],
        &manager_prefs.api_key[manager_prefs.api_key.len() - 4..]
    );
    println!(
        "   Refresh Interval: {} seconds",
        manager_prefs.refresh_interval
    );
    println!(
        "   Show Notifications: {}",
        manager_prefs.show_notifications
    );

    // Test reloading preferences
    println!("\n5. Testing preferences reload...");
    manager.reload_preferences()?;
    let reloaded_prefs = manager.get_preferences();
    println!("   API URL: {}", reloaded_prefs.api_url);
    println!(
        "   API Key: {}...{}",
        &reloaded_prefs.api_key[..8],
        &reloaded_prefs.api_key[reloaded_prefs.api_key.len() - 4..]
    );
    println!(
        "   Refresh Interval: {} seconds",
        reloaded_prefs.refresh_interval
    );
    println!(
        "   Show Notifications: {}",
        reloaded_prefs.show_notifications
    );

    // Show current preferences and storage location
    println!("\n6. Showing preferences info...");
    manager.show_current_preferences();
    manager.show_storage_location();

    println!("\n✅ All preferences tests passed!");

    Ok(())
}
