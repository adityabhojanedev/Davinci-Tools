# AutoSubs Refresh

A tiny, single-purpose desktop app: one button that fixes broken AutoSubs
caption animations across your whole DaVinci Resolve timeline. Not a clone
of AutoSubs — just the one thing you actually needed automated.

## How it works

```
[AutoSubs Refresh app]  --writes-->  trigger.json (temp folder)
                                           |
                                           v
[RefreshCaptionsWatcher.lua running inside Resolve, via Workspace > Scripts]
     - notices the new trigger
     - walks every video track / Fusion comp / Text+ on the timeline
     - refreshes every matching caption node
     - writes result.json
                                           |
                                           v
[AutoSubs Refresh app]  <--reads--  result.json, shows it to you
```

No sockets, no ports, no extra Lua libraries to install — just two small
files exchanged through your system's temp folder. This sidesteps the
"external apps can't talk to Resolve's API directly in the Free version"
restriction the same way AutoSubs itself does: the script that does the real
work runs *inside* Resolve, launched from its own Scripts menu.

## One-time setup

1. Copy `resolve-bridge/RefreshCaptionsWatcher.lua` into:
   - **Windows:** `%APPDATA%\Blackmagic Design\DaVinci Resolve\Support\Fusion\Scripts\Utility\`
   - **macOS:** `~/Library/Application Support/Blackmagic Design/DaVinci Resolve/Fusion/Scripts/Utility/`
   - **Linux:** `~/.local/share/DaVinciResolve/Fusion/Scripts/Utility/`
2. Open the `.lua` file and (recommended) paste the exact code your
   "Adjust Word Timing" button runs into `CUSTOM_REFRESH_CODE` — see
   "Finding your exact button code" below. You can skip this and try the
   generic method first.

## Daily use

1. Open Resolve, open your project/timeline.
2. **Workspace ▸ Scripts ▸ Utility ▸ RefreshCaptionsWatcher** — leave it
   running (check Workspace ▸ Console to confirm it says "Watcher started").
   Do this once per Resolve session.
3. Open the AutoSubs Refresh app, click **Refresh Captions**.
4. The app shows you how many caption nodes were fixed.

## Finding your exact button code (recommended, one-time)

Fusion's button controls run embedded Lua on click — a script just toggling
the same value doesn't always trigger it. For a guaranteed match instead of
the generic guess:

1. In the Effects Library, right-click your AutoSubs caption preset ▸
   **Reveal in Explorer/Finder**, and open the `.setting` file as plain text.
2. Search for `Adjust Word Timing`. Copy the Lua code between the `[[` and
   `]]` in the nearby `BTNCS_Execute = [[ ... ]]` block.
3. Paste it into `CUSTOM_REFRESH_CODE` near the top of
   `RefreshCaptionsWatcher.lua`, save, and re-run the watcher script.

If the button's display name isn't "Adjust Word Timing" in your version,
adjust `NAME_HINTS` in the same file (currently `"adjust"`, `"word"`,
`"timing"` — all three must appear in the name for a match).

## Building the app yourself

Requires [Rust](https://rustup.rs) and [Node.js](https://nodejs.org).

```bash
npm install
npx tauri icon path/to/your-logo.png   # generates src-tauri/icons/* (one-time)
npm run dev                             # run it locally
npm run build                           # build an installer for your OS
```

## Publishing installers via GitHub

Push this folder to a GitHub repo, then tag a release:

```bash
git tag v0.1.0
git push origin v0.1.0
```

The included `.github/workflows/build.yml` (using
[tauri-action](https://github.com/tauri-apps/tauri-action)) builds Windows,
macOS, and Linux installers automatically and attaches them as a draft
GitHub Release. Publish the draft when you're happy with it, and future
updates are just: bump the version, tag, push.

## Project layout

```
AutoSubsRefreshApp/
├── resolve-bridge/
│   └── RefreshCaptionsWatcher.lua   # runs inside Resolve
├── src/                              # app frontend (plain HTML/JS, no build step)
│   ├── index.html
│   ├── main.js
│   └── styles.css
├── src-tauri/                        # Rust backend + packaging config
│   ├── src/main.rs
│   ├── Cargo.toml
│   ├── build.rs
│   └── tauri.conf.json
├── .github/workflows/build.yml       # CI: builds installers on tag push
└── package.json
```

## Limitations / things to know

- You need to launch `RefreshCaptionsWatcher` from Resolve's Scripts menu
  once per session — there's no way around this in the Free version, since
  nothing outside Resolve can reach its API directly.
- If the generic toggle method doesn't fix the animation, use the
  "Finding your exact button code" steps above — it's the reliable path.
- The watcher script currently refreshes the **current** timeline only,
  matching what you asked for; it's a small change to loop over every
  timeline in the project if you want that later.
