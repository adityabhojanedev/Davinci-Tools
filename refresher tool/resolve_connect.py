"""
Handles connecting to a running DaVinci Resolve instance.
Resolve must be open, and 'External scripting using' must be set to
'Local' (or 'Network') in Resolve > Preferences > General.
"""

import sys
import os


def _add_script_paths():
    """Make sure Resolve's scripting modules are importable."""
    if sys.platform.startswith("win"):
        default_api = r"C:\ProgramData\Blackmagic Design\DaVinci Resolve\Support\Developer\Scripting"
        default_lib = r"C:\Program Files\Blackmagic Design\DaVinci Resolve\fusionscript.dll"
    elif sys.platform == "darwin":
        default_api = "/Library/Application Support/Blackmagic Design/DaVinci Resolve/Developer/Scripting"
        default_lib = "/Applications/DaVinci Resolve/DaVinci Resolve.app/Contents/Libraries/Fusion/fusionscript.so"
    else:  # linux
        default_api = "/opt/resolve/Developer/Scripting"
        default_lib = "/opt/resolve/libs/Fusion/fusionscript.so"

    api_path = os.environ.get("RESOLVE_SCRIPT_API", default_api)
    modules_path = os.path.join(api_path, "Modules")
    if modules_path not in sys.path:
        sys.path.append(modules_path)
    os.environ.setdefault("RESOLVE_SCRIPT_API", api_path)
    os.environ.setdefault("RESOLVE_SCRIPT_LIB", default_lib)


def get_resolve():
    """Returns the Resolve app object, or raises a clear error if it can't connect."""
    _add_script_paths()
    try:
        import DaVinciResolveScript as dvr
    except ImportError as e:
        raise RuntimeError(
            "Could not import DaVinciResolveScript. Make sure DaVinci Resolve is "
            "installed and the paths in README.md match your install location."
        ) from e

    resolve = dvr.scriptapp("Resolve")
    if resolve is None:
        raise RuntimeError(
            "Could not connect to Resolve. Is DaVinci Resolve running, and is "
            "'External scripting using' set to 'Local' in Preferences > General?"
        )
    return resolve


def get_current_timeline(resolve):
    project = resolve.GetProjectManager().GetCurrentProject()
    if project is None:
        raise RuntimeError("No project is currently open in Resolve.")
    timeline = project.GetCurrentTimeline()
    if timeline is None:
        raise RuntimeError("No timeline is currently open in Resolve.")
    return timeline
