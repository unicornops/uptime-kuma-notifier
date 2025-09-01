use reqwest::Client;
use serde::Deserialize;
use std::time::Duration;

#[derive(Debug, Deserialize)]
struct Monitor {
    status: i32,
}

#[derive(Debug, Deserialize)]
struct StatusPageResponse {
    heartbeat_list: serde_json::Value,
    uptime_list: serde_json::Value,
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    println!("Testing connection to your Uptime Kuma instance...");

    let api_url = "https://uptime.example.com";
    let api_key = "uk1_xxxxxxxxxx";

    let client = Client::new();

    // First, let's try to find available status pages
    println!("\n--- Looking for available status pages ---");

    let response = client
        .get(&format!("{}/api/status-page", api_url))
        .header("Authorization", format!("Bearer {}", api_key))
        .timeout(Duration::from_secs(10))
        .send()
        .await?;

    if response.status().is_success() {
        let response_text = response.text().await?;
        println!("Status page response: {}", response_text);

        // Try to parse as JSON to see what status pages are available
        if let Ok(status_pages) = serde_json::from_str::<serde_json::Value>(&response_text) {
            println!(
                "✅ Found status pages: {}",
                serde_json::to_string_pretty(&status_pages).unwrap()
            );
        }
    } else {
        println!("Status page endpoint failed: {}", response.status());
    }

    // Test the working endpoint with the actual response format
    println!("\n--- Testing working endpoint: /api/status-page/heartbeat/your-status-page-id ---");

    let response = client
        .get(&format!(
            "{}/api/status-page/heartbeat/your-status-page-id",
            api_url
        ))
        .header("Authorization", format!("Bearer {}", api_key))
        .timeout(Duration::from_secs(10))
        .send()
        .await?;

    if response.status().is_success() {
        let response_text = response.text().await?;
        println!("Response: {}", response_text);

        // Try to parse with the correct structure
        match serde_json::from_str::<StatusPageResponse>(&response_text) {
            Ok(status_data) => {
                println!("✅ Successfully parsed status page response!");
                println!("Heartbeat list: {:?}", status_data.heartbeat_list);
                println!("Uptime list: {:?}", status_data.uptime_list);

                // Check if we can extract monitor information
                if let Some(heartbeat_list) = status_data.heartbeat_list.as_object() {
                    println!("Number of heartbeat entries: {}", heartbeat_list.len());
                }

                if let Some(uptime_list) = status_data.uptime_list.as_object() {
                    println!("Number of uptime entries: {}", uptime_list.len());
                }
            }
            Err(e) => {
                println!("❌ Failed to parse status page response: {}", e);
            }
        }
    }

    // Also try the monitor endpoint with different auth headers
    println!("\n--- Testing monitor endpoint with different auth methods ---");

    let auth_methods = vec![
        ("Bearer", format!("Bearer {}", api_key)),
        ("Token", format!("Token {}", api_key)),
        ("X-API-Key", format!("X-API-Key: {}", api_key)),
    ];

    for (method, header_value) in auth_methods {
        println!("Trying {} authentication...", method);

        let response = client
            .get(&format!("{}/api/monitor", api_url))
            .header("Authorization", header_value)
            .timeout(Duration::from_secs(10))
            .send()
            .await?;

        if response.status().is_success() {
            let response_text = response.text().await?;

            if !response_text.trim().starts_with("<!DOCTYPE html>")
                && !response_text.trim().starts_with("<html")
            {
                println!("✅ {} auth worked! Got non-HTML response", method);
                println!(
                    "Response preview: {}",
                    &response_text[..response_text.len().min(200)]
                );

                // Try to parse as monitor list
                match serde_json::from_str::<Vec<Monitor>>(&response_text) {
                    Ok(monitors) => {
                        let mut up_count = 0;
                        let mut down_count = 0;
                        let mut pending_count = 0;

                        for monitor in &monitors {
                            match monitor.status {
                                1 => up_count += 1,      // Up
                                2 => down_count += 1,    // Down
                                0 => pending_count += 1, // Pending
                                _ => {}                  // Other statuses
                            }
                        }

                        println!("✅ Monitor parsing successful!");
                        println!("Total monitors: {}", monitors.len());
                        println!(
                            "Up: {}, Down: {}, Pending: {}",
                            up_count, down_count, pending_count
                        );
                        return Ok(());
                    }
                    Err(e) => {
                        println!("❌ Monitor parsing failed: {}", e);
                    }
                }
            } else {
                println!("❌ {} auth still returns HTML", method);
            }
        } else {
            println!(
                "❌ {} auth failed with status: {}",
                method,
                response.status()
            );
        }
    }

    println!("\n❌ All authentication methods failed. Possible issues:");
    println!("1. API key is invalid or expired");
    println!("2. API key doesn't have the right permissions");
    println!("3. The API endpoints are different for your Uptime Kuma version");
    println!("4. You need to create a status page first in Uptime Kuma");

    Ok(())
}
