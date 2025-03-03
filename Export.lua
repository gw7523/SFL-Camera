-- C:\Users\hollo\Saved Games\DCS\Scripts\Export.lua
-- Version: 1.5
-- Purpose: Integrates SFL-Camera.lua into the DCS Export environment via LuaExport hooks.
-- Date: 03 February 2025
-- Notes:
--   - Preserves existing LuaExportActivityNextEvent functionality.
--   - Adds detailed logging for debugging.

--[[
    Changes in Version 1.5:
    - Enhanced logging to track original and SFL LuaExportActivityNextEvent calls.
    - Adjusted timing to integrate with SFL-Camera.lua’s update mechanism.
    - Updated date to 03 February 2025.
]]

-- Save original LuaExportActivityNextEvent
local original_LuaExportActivityNextEvent = LuaExportActivityNextEvent

-- Load SFL-Camera script
dofile("C:\\Users\\hollo\\Saved Games\\DCS\\Scripts\\SFL-camera\\SFL-Camera.lua")
local sfl_LuaExportActivityNextEvent = LuaExportActivityNextEvent

-- Combined LuaExportActivityNextEvent
function LuaExportActivityNextEvent(t)
    local next_t = t + 1
    if original_LuaExportActivityNextEvent then
        next_t = original_LuaExportActivityNextEvent(t)
        if log then
            log.write("Export", log.INFO, "Original LuaExportActivityNextEvent called, next_t=" .. tostring(next_t))
        end
    end
    if sfl_LuaExportActivityNextEvent then
        local sfl_next_t = sfl_LuaExportActivityNextEvent(t)
        if log then
            log.write("Export", log.INFO, "SFL LuaExportActivityNextEvent called, sfl_next_t=" .. tostring(sfl_next_t))
        end
        return math.min(next_t, sfl_next_t)
    else
        if log then
            log.write("Export", log.ERROR, "SFL-Camera.lua did not define LuaExportActivityNextEvent.")
        end
        return next_t
    end
end

if log then
    log.write("Export", log.INFO, "Export.lua (v1.5) loaded successfully.")
end