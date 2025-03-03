-- C:\Users\hollo\Saved Games\DCS\Scripts\Export.lua
-- Version: 1.4
-- Purpose: Integrates SFL-Camera.lua into the DCS Export environment, allowing camera updates via LuaExport hooks.
-- Date: 04 March 2025
-- Notes:
--   - Preserves any existing LuaExportActivityNextEvent functionality while adding SFL-Camera updates.
--   - Version updated from 1.3 to 1.4 to add diagnostic logging for LuaExportActivityNextEvent.

-- Save the original LuaExportActivityNextEvent if it exists
local original_LuaExportActivityNextEvent = LuaExportActivityNextEvent

-- Load the SFL-Camera script
dofile("C:\\Users\\hollo\\Saved Games\\DCS\\Scripts\\SFL-camera\\SFL-Camera.lua")
local sfl_LuaExportActivityNextEvent = LuaExportActivityNextEvent

-- Custom LuaExportActivityNextEvent to combine original and SFL-Camera timing
-- Ensures compatibility with other scripts using this hook
function LuaExportActivityNextEvent(t)
    local next_t = t + 1  -- Default interval if no original function exists
    if original_LuaExportActivityNextEvent then
        next_t = original_LuaExportActivityNextEvent(t)
        log.write("Export", log.INFO, "Original LuaExportActivityNextEvent called, next_t=" .. tostring(next_t))
    end
    if sfl_LuaExportActivityNextEvent then
        local sfl_next_t = sfl_LuaExportActivityNextEvent(t)
        log.write("Export", log.INFO, "SFL LuaExportActivityNextEvent called, sfl_next_t=" .. tostring(sfl_next_t))
        return math.min(next_t, sfl_next_t)
    else
        log.write("Export", log.ERROR, "SFL-Camera.lua did not define LuaExportActivityNextEvent.")
        return next_t
    end
end


---local wwtlfs = require('lfs')
---dofile(wwtlfs.writedir() .. 'Scripts/wwt/wwtExport.lua')
