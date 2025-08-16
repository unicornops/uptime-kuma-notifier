use dirs;
use plist::{Dictionary, Integer, Value};
use serde::{Deserialize, Serialize};
use std::fs;
use std::path::PathBuf;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Preferences {
    pub api_url: String,
    pub api_key: String,
    pub refresh_interval: u64,
    pub show_notifications: bool,
}

impl Default for Preferences {
    fn default() -> Self {
        Self {
            api_url: "https://uptime.lazzurs.net".to_string(),
            api_key: "uk2_gzVzUo7eGeREUsNYD7A88z6a23vo8KeQ-xQjwuZy".to_string(),
            refresh_interval: 30,
            show_notifications: true,
        }
    }
}

impl Preferences {
    pub fn save(&self) -> Result<(), Box<dyn std::error::Error>> {
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

    pub fn get_preferences_path() -> Option<PathBuf> {
        if let Some(app_support) = dirs::config_dir() {
            let prefs_dir = app_support.join("uptime-kuma-notifier");
            Some(prefs_dir.join("preferences.json"))
        } else {
            None
        }
    }

    pub fn get_plist_path() -> Option<PathBuf> {
        if let Some(app_support) = dirs::config_dir() {
            let prefs_dir = app_support.join("uptime-kuma-notifier");
            Some(prefs_dir.join("preferences.plist"))
        } else {
            None
        }
    }

    pub fn save_to_plist(&self) -> Result<(), Box<dyn std::error::Error>> {
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

    pub fn load_from_plist() -> Self {
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
