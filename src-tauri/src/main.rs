// Prevents an extra console window on Windows in release builds.
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

use std::fs;
use std::path::PathBuf;
use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};

fn bridge_dir() -> PathBuf {
    let dir = std::env::temp_dir().join("autosubs_refresh_bridge");
    let _ = fs::create_dir_all(&dir);
    dir
}

fn trigger_path() -> PathBuf {
    bridge_dir().join("trigger.json")
}

fn result_path() -> PathBuf {
    bridge_dir().join("result.json")
}

fn extract_field(json: &str, field: &str) -> Option<String> {
    let key = format!("\"{}\"", field);
    let start = json.find(&key)? + key.len();
    let rest = &json[start..];
    let colon = rest.find(':')?;
    let rest = &rest[colon + 1..];
    let quote_start = rest.find('"')? + 1;
    let rest = &rest[quote_start..];
    let quote_end = rest.find('"')?;
    Some(rest[..quote_end].to_string())
}

#[tauri::command]
fn refresh_captions() -> Result<String, String> {
    let id = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map_err(|e| e.to_string())?
        .as_nanos()
        .to_string();

    // Clear any stale result before asking for a new one.
    let _ = fs::remove_file(result_path());

    fs::write(trigger_path(), format!("{{\"id\":\"{}\"}}", id))
        .map_err(|e| format!("Couldn't write the request file: {}", e))?;

    // Poll for the watcher script's response, inside Resolve, to pick this up.
    let deadline = Instant::now() + Duration::from_secs(15);
    loop {
        if let Ok(content) = fs::read_to_string(result_path()) {
            if let Some(found_id) = extract_field(&content, "id") {
                if found_id == id {
                    return Ok(extract_field(&content, "message")
                        .unwrap_or_else(|| "Done.".to_string()));
                }
            }
        }

        if Instant::now() >= deadline {
            return Err(
                "No response from Resolve after 15s. Is RefreshCaptionsWatcher.lua running \
                 (Workspace > Scripts > Utility > RefreshCaptionsWatcher)?"
                    .to_string(),
            );
        }

        std::thread::sleep(Duration::from_millis(300));
    }
}

fn main() {
    tauri::Builder::default()
        .invoke_handler(tauri::generate_handler![refresh_captions])
        .run(tauri::generate_context!())
        .expect("error while running the AutoSubs Refresh app");
}
