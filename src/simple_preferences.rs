use crate::preferences::Preferences;
use std::sync::{Arc, Mutex};

#[derive(Debug)]
pub struct SimplePreferencesManager {
    preferences: Arc<Mutex<Preferences>>,
}

impl SimplePreferencesManager {
    pub fn new(preferences: Arc<Mutex<Preferences>>) -> Self {
        Self { preferences }
    }

    pub fn save_preferences(
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

    pub fn get_preferences(&self) -> Preferences {
        if let Ok(prefs) = self.preferences.lock() {
            prefs.clone()
        } else {
            Preferences::default()
        }
    }

    #[allow(dead_code)]
    pub fn reload_preferences(&self) -> Result<(), Box<dyn std::error::Error>> {
        let new_prefs = Preferences::load_from_plist();
        let mut current_prefs = self.preferences.lock().unwrap();
        *current_prefs = new_prefs;
        println!("✅ Preferences reloaded from disk");
        Ok(())
    }

    pub fn show_current_preferences(&self) {
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

    pub fn show_storage_location(&self) {
        println!("\n💾 Preferences Storage Location:");
        if let Some(plist_path) = Preferences::get_plist_path() {
            println!("   PLIST: {}", plist_path.display());
        }
        if let Some(json_path) = Preferences::get_preferences_path() {
            println!("   JSON: {}", json_path.display());
        }
    }
}
