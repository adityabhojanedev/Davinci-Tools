# AutoSubs Text+ Refresher

Fixes the "animation breaks, have to click each caption and press Adjust Word
Timing twice" problem — for the whole timeline at once, no clicking required.

## Why this works without the socket/app bridge

AutoSubs' desktop app can't call Resolve's API directly from outside the
process — that's the Free-version restriction you mentioned. That's why it
loads a Lua script *inside* Resolve that opens a small local HTTP server, and
talks to Resolve through that.

A script placed in Resolve's own **Scripts** menu runs inside Resolve the
same way, so it already has full access to the timeline and Fusion comps —
no bridge, no external process, works in the Free version.

## Setup

1. Copy `AutoSubsRefresh.lua` into:
   - **Windows:** `%APPDATA%\Blackmagic Design\DaVinci Resolve\Support\Fusion\Scripts\Utility\`
   - **macOS:** `~/Library/Application Support/Blackmagic Design/DaVinci Resolve/Fusion/Scripts/Utility/`
   - **Linux:** `~/.local/share/DaVinciResolve/Fusion/Scripts/Utility/`
2. Restart Resolve (or right-click the Scripts menu > "Update").
3. Run it from **Workspace ▸ Scripts ▸ Utility ▸ AutoSubsRefresh** with your
   timeline open. Check **Workspace ▸ Console** for output.

## Step 1 — find your exact button (do this once)

Button controls in Fusion don't always respond to a script just toggling
their value — the real click runs a Lua snippet baked into the macro. To get
a 100%-faithful fix instead of the generic guess:

1. In the Effects Library, find your AutoSubs caption preset, right-click ▸
   **Reveal in Explorer/Finder**, and open the `.setting` file in a text
   editor (VS Code, Notepad++, etc. — it's plain text/Lua).
2. Search for `Adjust Word Timing`. Nearby you'll find a block like:
   ```
   AdjustWordTiming = InstanceInput {
       ...
       INPID_InputControl = "ButtonControl",
       BTNCS_Execute = [[ ...lua code here... ]],
   }
   ```
3. Copy everything between the `[[` and `]]` and paste it into the
   `CUSTOM_REFRESH_CODE` variable near the top of `AutoSubsRefresh.lua`.

If you can't find that block (naming varies by macro version), set
`DIAGNOSTIC_MODE = true` at the top of the script and run it once — it will
print every tool name and every input's display name it finds on your
timeline's Fusion comps, with nothing modified. Use that to correct
`NAME_HINTS` (currently `"adjust"`, `"word"`, `"timing"`) to whatever your
button is actually called.

## Step 2 — run it for real

Set `DIAGNOSTIC_MODE = false`, save, and run the script again. It will:

- Walk every video track and every clip on the current timeline
- Open each clip's Fusion composition (no need to actually open the Fusion
  page in the UI — this works headlessly)
- Find every tool/control matching your button's name
- Run your captured code twice per match (or the generic toggle, if you
  didn't paste custom code)
- Print a summary of how many nodes it fixed

Re-run any time animation breaks after adding new captions.

---

## About "a similar app I can just install"

Full disclosure on scope: AutoSubs itself (Rust + Tauri + local Whisper
transcription + Lua bridge) represents a genuinely large project. Since it's
already open-source under the MIT license, the fastest and most maintainable
path to "an installable app with a Refresh button" is **not** to rebuild it
from zero, but to extend it:

1. Fork `tmoroney/auto-subs`.
2. Add a new handler (e.g. `RefreshAllTextPlus`) to
   `AutoSubs-App/.../autosubs_core.lua`, using the same tool-walking logic as
   the script above, exposed over their existing local HTTP server.
3. Add a matching Rust command in `resolve_bridge.rs` and a "Refresh
   Captions" button in the React frontend.
4. Their repo already has GitHub Actions set up for cross-platform builds —
   push to your fork and you get installers for Windows/macOS/Linux for free.

If instead you want a *standalone* lightweight tool of your own (not a fork),
the same architecture pattern is the right one to copy:

- **Bridge (runs inside Resolve):** a Lua script identical in spirit to
  `AutoSubsRefresh.lua`, but wrapped in a tiny HTTP server (LuaSocket) so an
  external app can call it.
- **App shell:** Tauri (Rust backend + Svelte or React frontend) — small
  binary size, cross-platform, and Rust's `reqwest` can call the local Lua
  server the same way AutoSubs does.
- **CI/CD:** GitHub Actions with `tauri-apps/tauri-action` builds signed
  installers for all three platforms on every tag push.

Happy to scaffold that Tauri project (package.json, Cargo.toml, the HTTP
bridge call, and the GitHub Actions workflow) as a next step if you want to
go that route — let me know and I'll set it up as a pushable repo structure.
