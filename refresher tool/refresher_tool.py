import json
import os
import tkinter as tk
from tkinter import scrolledtext, messagebox

from resolve_connect import get_resolve, get_current_timeline

CONFIG_PATH = os.path.join(os.path.dirname(__file__), "config.json")


def load_config():
    if os.path.exists(CONFIG_PATH):
        with open(CONFIG_PATH, "r") as f:
            return json.load(f)
    return {}


def save_config(cfg):
    with open(CONFIG_PATH, "w") as f:
        json.dump(cfg, f, indent=2)


def find_textplus_tools(timeline):
    """Returns (clip_name, track_index, tool) for every Text+ generator
    found on the video tracks of the given timeline."""
    found = []
    track_count = timeline.GetTrackCount("video")
    for t in range(1, track_count + 1):
        items = timeline.GetItemListInTrack("video", t)
        if not items:
            continue
        for item in items:
            try:
                if item.GetFusionCompCount() < 1:
                    continue
                comp = item.GetFusionCompByIndex(1)
                for tool in comp.GetToolList().values():
                    attrs = tool.GetAttrs()
                    if attrs.get("TOOLS_RegID") == "TextPlus":
                        found.append((item.GetName(), t, tool))
            except Exception:
                continue
    return found


def snapshot_inputs(tool):
    """Best-effort read of every input's current value, keyed by input ID."""
    snap = {}
    try:
        input_list = tool.GetInputList()
    except Exception:
        return snap
    for input_id in input_list.keys():
        try:
            snap[input_id] = tool.GetInput(input_id)
        except Exception:
            pass
    return snap


class RefresherFrame(tk.Frame):
    def __init__(self, master, on_back):
        super().__init__(master, bg="#1e1e1e")
        self.on_back = on_back
        self.resolve = None
        self.timeline = None
        self.found_tools = []
        self.before_snap = None
        cfg = load_config()
        self.trigger_id = cfg.get("trigger_input_id", "")
        self._build_ui()

    def _build_ui(self):
        top = tk.Frame(self, bg="#1e1e1e")
        top.pack(fill="x", padx=20, pady=15)
        tk.Button(top, text="< Back", command=self.on_back).pack(side="left")
        tk.Label(top, text="Auto-Sub Text+ Refresher", font=("Segoe UI", 15, "bold"),
                 bg="#1e1e1e", fg="white").pack(side="left", padx=15)

        self.status = tk.Label(self, text="Not connected", bg="#1e1e1e", fg="#aaaaaa")
        self.status.pack(anchor="w", padx=20)

        row1 = tk.Frame(self, bg="#1e1e1e")
        row1.pack(fill="x", padx=20, pady=8)
        tk.Button(row1, text="1. Connect to Resolve", command=self.connect).pack(side="left")
        tk.Button(row1, text="2. Scan Timeline", command=self.scan).pack(side="left", padx=8)

        tk.Label(self, text="Found Text+ clips (click one to select for discovery):",
                 bg="#1e1e1e", fg="#cccccc").pack(anchor="w", padx=20, pady=(10, 0))
        self.listbox = tk.Listbox(self, height=6, bg="#2a2a2a", fg="white")
        self.listbox.pack(fill="x", padx=20, pady=5)

        tk.Frame(self, bg="#333333", height=1).pack(fill="x", padx=20, pady=10)

        tk.Label(self, text="One-time setup: find the button's input ID",
                 bg="#1e1e1e", fg="#cccccc", font=("Segoe UI", 10, "bold")).pack(anchor="w", padx=20)
        tk.Label(self,
                 text="Select a clip above, hit 'Snapshot Before', then in Resolve click\n"
                      "'Adjust Word Timing' twice on that clip's Inspector, then hit 'Snapshot After'.",
                 bg="#1e1e1e", fg="#999999", justify="left").pack(anchor="w", padx=20)

        row2 = tk.Frame(self, bg="#1e1e1e")
        row2.pack(fill="x", padx=20, pady=8)
        tk.Button(row2, text="Snapshot Before", command=self.snapshot_before).pack(side="left")
        tk.Button(row2, text="Snapshot After / Diff", command=self.snapshot_after).pack(side="left", padx=8)

        row3 = tk.Frame(self, bg="#1e1e1e")
        row3.pack(fill="x", padx=20, pady=4)
        tk.Label(row3, text="Trigger Input ID:", bg="#1e1e1e", fg="#cccccc").pack(side="left")
        self.trigger_entry = tk.Entry(row3, width=30)
        self.trigger_entry.insert(0, self.trigger_id)
        self.trigger_entry.pack(side="left", padx=8)
        tk.Button(row3, text="Save", command=self.save_trigger_id).pack(side="left")

        tk.Frame(self, bg="#333333", height=1).pack(fill="x", padx=20, pady=10)

        tk.Button(self, text="Refresh ALL Text+ Clips", bg="#2f6f2f", fg="white",
                  font=("Segoe UI", 11, "bold"), command=self.refresh_all).pack(padx=20, pady=5, fill="x")

        self.log = scrolledtext.ScrolledText(self, height=8, bg="#111111", fg="#00ff88")
        self.log.pack(fill="both", expand=True, padx=20, pady=10)

    def log_msg(self, msg):
        self.log.insert("end", msg + "\n")
        self.log.see("end")

    def connect(self):
        try:
            self.resolve = get_resolve()
            self.timeline = get_current_timeline(self.resolve)
            self.status.config(text=f"Connected — timeline: {self.timeline.GetName()}", fg="#7CFC00")
            self.log_msg("Connected to Resolve.")
        except Exception as e:
            self.status.config(text="Connection failed", fg="#ff5555")
            messagebox.showerror("Connection error", str(e))

    def scan(self):
        if not self.timeline:
            messagebox.showwarning("Not connected", "Connect to Resolve first.")
            return
        self.found_tools = find_textplus_tools(self.timeline)
        self.listbox.delete(0, "end")
        for name, track, _tool in self.found_tools:
            self.listbox.insert("end", f"V{track}  •  {name}")
        self.log_msg(f"Found {len(self.found_tools)} Text+ clip(s).")

    def _selected_tool(self):
        if not self.found_tools:
            messagebox.showwarning("Scan first", "Scan the timeline first.")
            return None
        sel = self.listbox.curselection()
        idx = sel[0] if sel else 0
        return self.found_tools[idx][2]

    def snapshot_before(self):
        tool = self._selected_tool()
        if tool is None:
            return
        self.before_snap = snapshot_inputs(tool)
        self.log_msg(f"Snapshot BEFORE taken ({len(self.before_snap)} inputs). "
                      f"Now go click 'Adjust Word Timing' twice on that clip in Resolve.")

    def snapshot_after(self):
        if self.before_snap is None:
            messagebox.showwarning("No baseline", "Take 'Snapshot Before' first.")
            return
        tool = self._selected_tool()
        if tool is None:
            return
        after = snapshot_inputs(tool)
        changed = {k: (self.before_snap.get(k), v) for k, v in after.items() if self.before_snap.get(k) != v}
        if not changed:
            self.log_msg("No input value changed. The button may just force a visual "
                          "redraw rather than storing a value — try a different clip, "
                          "or this method may not be able to detect it.")
        else:
            self.log_msg("Changed input(s) — this is very likely your trigger ID:")
            for k, (b, a) in changed.items():
                self.log_msg(f"   {k}:  {b}  ->  {a}")
            first_key = list(changed.keys())[0]
            self.trigger_entry.delete(0, "end")
            self.trigger_entry.insert(0, first_key)

    def save_trigger_id(self):
        self.trigger_id = self.trigger_entry.get().strip()
        save_config({"trigger_input_id": self.trigger_id})
        self.log_msg(f"Saved trigger input ID: {self.trigger_id}")

    def refresh_all(self):
        if not self.found_tools:
            messagebox.showwarning("Scan first", "Scan the timeline first.")
            return
        if not self.trigger_id:
            messagebox.showwarning("No trigger ID", "Run the discovery steps above first, "
                                                       "or type the input ID manually and Save.")
            return
        for name, track, tool in self.found_tools:
            try:
                current = tool.GetInput(self.trigger_id)
                flip = 1 if current in (0, None) else 0
                tool.SetInput(self.trigger_id, flip)
                tool.SetInput(self.trigger_id, current)
                self.log_msg(f"Refreshed: V{track} — {name}")
            except Exception as e:
                self.log_msg(f"FAILED: V{track} — {name}  ({e})")
        self.log_msg("Done.")
