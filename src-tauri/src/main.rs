// Prevents an extra console window on Windows in release builds.
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

use std::fs;
use std::path::PathBuf;
use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};
use tauri::Manager;

/// Where Resolve looks for user scripts, per OS.
fn resolve_scripts_dir() -> Option<PathBuf> {
    #[cfg(target_os = "windows")]
    {
        let appdata = std::env::var("APPDATA").ok()?;
        return Some(
            PathBuf::from(appdata)
                .join("Blackmagic Design")
                .join("DaVinci Resolve")
                .join("Support")
                .join("Fusion")
                .join("Scripts")
                .join("Utility"),
        );
    }
    #[cfg(target_os = "macos")]
    {
        let home = std::env::var("HOME").ok()?;
        return Some(
            PathBuf::from(home)
                .join("Library")
                .join("Application Support")
                .join("Blackmagic Design")
                .join("DaVinci Resolve")
                .join("Fusion")
                .join("Scripts")
                .join("Utility"),
        );
    }
    #[cfg(target_os = "linux")]
    {
        let home = std::env::var("HOME").ok()?;
        return Some(
            PathBuf::from(home)
                .join(".local")
                .join("share")
                .join("DaVinciResolve")
                .join("Fusion")
                .join("Scripts")
                .join("Utility"),
        );
    }
    #[allow(unreachable_code)]
    None
}

/// Copies the bundled watcher script into Resolve's Scripts folder.
/// Runs every launch, so updates to the script ship automatically with app updates.
fn install_bridge_script(app: &tauri::AppHandle) -> Result<PathBuf, String> {
    let resource_path = app
        .path()
        .resolve(
            "resolve-bridge/RefreshCaptionsWatcher.lua",
            tauri::path::BaseDirectory::Resource,
        )
        .map_err(|e| format!("Couldn't locate the bundled script: {e}"))?;

    let dest_dir = resolve_scripts_dir()
        .ok_or_else(|| "Couldn't determine Resolve's Scripts folder for this OS.".to_string())?;

    fs::create_dir_all(&dest_dir)
        .map_err(|e| format!("Couldn't create {}: {}", dest_dir.display(), e))?;

    let dest_file = dest_dir.join("RefreshCaptionsWatcher.lua");
    fs::copy(&resource_path, &dest_file)
        .map_err(|e| format!("Couldn't copy script to {}: {}", dest_file.display(), e))?;

    Ok(dest_file)
}

#[tauri::command]
fn bridge_status(app: tauri::AppHandle) -> String {
    match install_bridge_script(&app) {
        Ok(path) => format!(
            "Bridge script installed at:\n{}\n\nIn Resolve: Workspace ▸ Scripts ▸ Utility ▸ RefreshCaptionsWatcher (run it once per session), then click Refresh Captions below.",
            path.display()
        ),
        Err(e) => format!(
            "Couldn't auto-install the bridge script ({e}). You can copy it manually - see the README."
        ),
    }
}

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
        .invoke_handler(tauri::generate_handler![refresh_captions, bridge_status])
        .run(tauri::generate_context!())
        .expect("error while running the AutoSubs Refresh app");
}
