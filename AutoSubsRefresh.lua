--[[
  AutoSubsRefresh.lua
  --------------------
  Fixes broken AutoSubs animated-caption Text+ nodes across an ENTIRE timeline
  in one click, instead of opening each clip in Fusion and pressing
  "Adjust Word Timing" twice by hand.

  INSTALL
    Copy this file into Resolve's Scripts/Utility folder:
      Windows: %APPDATA%\Blackmagic Design\DaVinci Resolve\Support\Fusion\Scripts\Utility\
      macOS:   ~/Library/Application Support/Blackmagic Design/DaVinci Resolve/Fusion/Scripts/Utility/
      Linux:   ~/.local/share/DaVinciResolve/Fusion/Scripts/Utility/

  RUN
    In Resolve: Workspace > Scripts > Utility > AutoSubsRefresh
    (Console output shows under Workspace > Console)

  This runs INSIDE Resolve, so it works fine in the Free version -
  there's no external connection involved, unlike AutoSubs' own app bridge.
]]

-- ====================== CONFIG ======================

-- Set true to just LIST every tool/input name on the timeline's Fusion comps
-- and change NOTHING. Use this once to find the exact button name if the
-- default guess below doesn't match your macro.
local DIAGNOSTIC_MODE = false

-- Words that must ALL appear (case-insensitive) in an input's display name
-- for it to be treated as the "Adjust Word Timing" control.
local NAME_HINTS = { "adjust", "word", "timing" }

-- OPTIONAL but recommended for a 100% faithful fix:
-- Open the macro's .setting file in a text editor (find it via the Effects
-- Library: right-click your AutoSubs caption preset > "Reveal in
-- Explorer/Finder"), search for "Adjust Word Timing", and copy the Lua code
-- inside the nearby `BTNCS_Execute = [[ ... ]]` block in here as a Lua long
-- string. Leave empty to use the generic toggle method instead.
local CUSTOM_REFRESH_CODE = [[

]]

-- =====================================================

resolve = bmd.scriptapp("Resolve")
local projectManager = resolve:GetProjectManager()
local project = projectManager:GetCurrentProject()
if not project then
    print("[AutoSubsRefresh] No project open.")
    return
end

local timeline = project:GetCurrentTimeline()
if not timeline then
    print("[AutoSubsRefresh] No active timeline.")
    return
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

local trackCount = timeline:GetTrackCount("video")
local fixedCount = 0
local seenCount = 0

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

                                if DIAGNOSTIC_MODE then
                                    print(string.format(
                                        "[scan] tool='%s' (%s)  input='%s'  id=%s",
                                        tool.Name, tool:GetAttrs().TOOLS_RegID or "?",
                                        dispName, tostring(inputID)))
                                    seenCount = seenCount + 1
                                elseif matchesHints(dispName) then
                                    print(string.format(
                                        "[fix] tool='%s'  input='%s' (id=%s)",
                                        tool.Name, dispName, tostring(inputID)))

                                    comp:SetActiveTool(tool)

                                    if CUSTOM_REFRESH_CODE and CUSTOM_REFRESH_CODE:match("%S") then
                                        -- Faithful replica: run the button's own code, twice.
                                        local ok, err = pcall(function()
                                            comp:Execute(CUSTOM_REFRESH_CODE)
                                            comp:Execute(CUSTOM_REFRESH_CODE)
                                        end)
                                        if not ok then
                                            print("  ! custom refresh code failed: " .. tostring(err))
                                        end
                                    else
                                        -- Generic method: toggle the control twice to force
                                        -- Fusion to mark it dirty and recompute, mimicking a
                                        -- double click. Works for many, not all, button setups.
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

if DIAGNOSTIC_MODE then
    print(string.format("[AutoSubsRefresh] Diagnostic scan complete. %d inputs listed above.", seenCount))
    print("Find the row for your button, then set NAME_HINTS to words unique to its name.")
else
    print(string.format("[AutoSubsRefresh] Done. Refreshed %d Text+ node(s).", fixedCount))
    if fixedCount == 0 then
        print("No matches found - set DIAGNOSTIC_MODE = true and re-run to see all available inputs.")
    end
end
