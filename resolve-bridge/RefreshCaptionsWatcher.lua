--[[
  RefreshCaptionsWatcher.lua
  ---------------------------
  Runs INSIDE Resolve (via Workspace > Scripts). Watches a small trigger
  file for requests from the AutoSubs Refresh app and, when one arrives,
  refreshes every AutoSubs Text+ node on the current timeline.

  No sockets, no extra Lua libraries - just plain file I/O, which Resolve's
  built-in Lua supports out of the box.

  INSTALL
    Copy this file into:
      Windows: %APPDATA%\Blackmagic Design\DaVinci Resolve\Support\Fusion\Scripts\Utility\
      macOS:   ~/Library/Application Support/Blackmagic Design/DaVinci Resolve/Fusion/Scripts/Utility/
      Linux:   ~/.local/share/DaVinciResolve/Fusion/Scripts/Utility/

  USE
    Each time you open Resolve and want the app to work, run once:
      Workspace > Scripts > Utility > RefreshCaptionsWatcher
    Leave it running in the background (check Workspace > Console for its
    log output). It sleeps between checks, so it uses ~0% CPU while idle.
    Stop it by closing Resolve, or from the Console with Ctrl+C.
]]

-- ====================== CONFIG (same as AutoSubsRefresh.lua) ======================

local NAME_HINTS = { "adjust", "word", "timing" }

-- Paste the exact BTNCS_Execute Lua code from your macro's .setting file here
-- for a 100%-faithful fix. Leave empty to use the generic toggle method.
local CUSTOM_REFRESH_CODE = [[

]]

-- How often to check for a new request, in seconds.
local POLL_INTERVAL_SECONDS = 1

-- ===================================================================================

resolve = bmd.scriptapp("Resolve")

local function isWindows()
    return package.config:sub(1, 1) == "\\"
end

local function getBridgeDir()
    local base = os.getenv("TEMP") or os.getenv("TMPDIR") or os.getenv("TMP") or "/tmp"
    base = base:gsub("\\", "/")
    if base:sub(-1) ~= "/" then base = base .. "/" end
    local dir = base .. "autosubs_refresh_bridge"
    if isWindows() then
        os.execute('mkdir "' .. dir:gsub("/", "\\") .. '" >NUL 2>NUL')
    else
        os.execute('mkdir -p "' .. dir .. '"')
    end
    return dir
end

local BRIDGE_DIR = getBridgeDir()
local TRIGGER_FILE = BRIDGE_DIR .. "/trigger.json"
local RESULT_FILE = BRIDGE_DIR .. "/result.json"

local function readFile(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local content = f:read("*a")
    f:close()
    return content
end

local function writeFile(path, content)
    local f = io.open(path, "w")
    if f then
        f:write(content)
        f:close()
    end
end

local function extractId(jsonText)
    if not jsonText then return nil end
    return jsonText:match('"id"%s*:%s*"([^"]+)"')
end

local function jsonEscape(s)
    return (s:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', ' '))
end

local function sleepSeconds(n)
    if isWindows() then
        os.execute("ping -n " .. (n + 1) .. " 127.0.0.1 >NUL")
    else
        os.execute("sleep " .. tostring(n))
    end
end

local function matchesHints(name)
    name = (name or ""):lower()
    for _, hint in ipairs(NAME_HINTS) do
        if not name:find(hint, 1, true) then
            return false
        end
    end
    return true
end

-- Walks the current timeline and refreshes every matching Text+/macro control.
-- Returns fixedCount, errorMessageOrNil
local function runRefresh()
    local projectManager = resolve:GetProjectManager()
    local project = projectManager:GetCurrentProject()
    if not project then
        return 0, "No project open in Resolve."
    end

    local timeline = project:GetCurrentTimeline()
    if not timeline then
        return 0, "No active timeline."
    end

    local trackCount = timeline:GetTrackCount("video")
    local fixedCount = 0

    for trackIndex = 1, trackCount do
        local items = timeline:GetItemListInTrack("video", trackIndex)
        if items then
            for _, item in ipairs(items) do
                local compCount = item:GetFusionCompCount()
                if compCount and compCount > 0 then
                    for compIndex = 1, compCount do
                        local comp = item:GetFusionCompByIndex(compIndex)
                        if comp then
                            local toolList = comp:GetToolList(false)
                            for _, tool in pairs(toolList) do
                                local inputList = tool:GetInputList()
                                for _, input in pairs(inputList) do
                                    local attrs = input:GetAttrs()
                                    local dispName = attrs.INPS_Name or ""
                                    local inputID = attrs.INPS_ID
                                    if matchesHints(dispName) then
                                        comp:SetActiveTool(tool)
                                        if CUSTOM_REFRESH_CODE and CUSTOM_REFRESH_CODE:match("%S") then
                                            pcall(function()
                                                comp:Execute(CUSTOM_REFRESH_CODE)
                                                comp:Execute(CUSTOM_REFRESH_CODE)
                                            end)
                                        else
                                            tool:SetInput(inputID, 1)
                                            tool:SetInput(inputID, 0)
                                            tool:SetInput(inputID, 1)
                                            tool:SetInput(inputID, 0)
                                        end
                                        fixedCount = fixedCount + 1
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    return fixedCount, nil
end

print("[AutoSubsRefresh] Watcher started. Bridge folder: " .. BRIDGE_DIR)
print("[AutoSubsRefresh] Leave this running, then use the AutoSubs Refresh app.")

local lastSeenId = nil

while true do
    local content = readFile(TRIGGER_FILE)
    local id = extractId(content)

    if id and id ~= lastSeenId then
        lastSeenId = id
        print("[AutoSubsRefresh] Request received (id=" .. id .. "). Refreshing...")

        local count, err = runRefresh()
        local message
        if err then
            message = "Error: " .. err
        elseif count == 0 then
            message = "No matching captions found - check NAME_HINTS/CUSTOM_REFRESH_CODE in the script."
        else
            message = "Refreshed " .. tostring(count) .. " Text+ node(s)."
        end

        writeFile(RESULT_FILE, string.format('{"id":"%s","message":"%s"}', id, jsonEscape(message)))
        print("[AutoSubsRefresh] " .. message)
    end

    sleepSeconds(POLL_INTERVAL_SECONDS)
end
