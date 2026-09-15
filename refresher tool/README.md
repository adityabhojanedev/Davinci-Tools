# DaVinci Toolkit — Tool 1: Auto-Sub Text+ Refresher

A small desktop app (nav page + tool) that talks to a running DaVinci Resolve
via its scripting API, finds every Text+ clip in your timeline, and
re-triggers "Adjust Word Timing" on each one automatically.

## Why it needs a "discovery" step

Resolve's "Adjust Word Timing" button doesn't have a public, documented
input ID — it's part of Resolve's built-in subtitle Text+ template, not a
standard Fusion tool. Rather than guess and risk it silently doing nothing,
this tool has you do the click-fix **once by hand** while it watches which
internal input value changes. Once it finds that input ID, it saves it
(`config.json`) and reuses it forever — you only do this setup once per
Resolve version.

## 1. Requirements

- DaVinci Resolve (Studio recommended; scripting works on free version too)
- Python 3.6–3.10 installed on your machine (Resolve ships its own, but a
  regular system Python works fine for this since we only use `tkinter`,
  which is in the standard library)

## 2. Enable external scripting in Resolve

Resolve → Preferences → General → **External scripting using** → set to
**Local**. Restart Resolve.

## 3. Point Python at Resolve's scripting modules

The app tries sensible defaults automatically, but if it can't connect,
set these environment variables yourself before running:

**Windows (PowerShell):**
```powershell
$env:RESOLVE_SCRIPT_API="C:\ProgramData\Blackmagic Design\DaVinci Resolve\Support\Developer\Scripting"
$env:RESOLVE_SCRIPT_LIB="C:\Program Files\Blackmagic Design\DaVinci Resolve\fusionscript.dll"
```

**macOS:**
```bash
export RESOLVE_SCRIPT_API="/Library/Application Support/Blackmagic Design/DaVinci Resolve/Developer/Scripting"
export RESOLVE_SCRIPT_LIB="/Applications/DaVinci Resolve/DaVinci Resolve.app/Contents/Libraries/Fusion/fusionscript.so"
```

## 4. Run it

With DaVinci Resolve **open** and a project/timeline loaded:

```bash
cd davinci-toolkit
python3 main.py
```

You'll land on the nav page → click **Auto-Sub Text+ Refresher**.

## 5. First-time setup (one time only)

1. **Connect to Resolve**
2. **Scan Timeline** — lists every Text+ clip found
3. Click one clip in the list, then **Snapshot Before**
4. In Resolve, open that clip's Inspector and click **Adjust Word Timing
   twice** (same as your manual fix)
5. Back in the tool, click **Snapshot After / Diff**
6. It will show which input(s) changed and auto-fill the **Trigger Input
   ID** field — click **Save**

If nothing shows as changed, try a different clip, or click the button a
couple more times before snapshotting — some Resolve builds only update
the value on the *second* click, which matches your manual workaround.

## 6. Every day after that

Just: **Connect → Scan → Refresh ALL Text+ Clips.** It loops through every
Text+ generator on your video tracks and flips the saved trigger input
twice, same as your manual fix, on all of them in one pass.

## Notes / limitations

- Only scans **video tracks** (where Text+ subtitle clips normally live).
- If you upgrade Resolve to a new major version, Blackmagic occasionally
  renames internal inputs — if Refresh All stops working, just redo the
  one-time discovery step.
- This uses documented Fusion scripting calls (`GetToolList`, `GetAttrs`,
  `GetInput`, `SetInput`) — nothing hacky, just the one internal ID that
  Resolve doesn't publish.

## Next up

Tool 2 (Daily Setup Builder) is stubbed on the nav page already, greyed
out — tell me your exact layer order and presets whenever you're ready
and we'll wire it in the same app.
