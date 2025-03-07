-- SFL-Camera.lua
-- Version 2.5, 07Mar2025
-- Changes:
-- 1. Wrapped initTrackLog() in pcall to prevent script crash if logToTrackLog fails.
-- 2. Added debug logging to confirm script execution and camera mode.
-- 3. Maintained existing camera update logic in LuaExportAfterNextFrame().

local lfs = require("lfs")
local log = require("log")

-- Define trackLogFile globally
trackLogFile = nil

-- Logging function to TrackLog.txt
function logToTrackLog(level, message)
    if trackLogFile then
        trackLogFile:write(level .. ": " .. message .. "\n")
        trackLogFile:flush()
    end
end

-- Initialize TrackLog.txt
local function initTrackLog()
    local logDir = lfs.writedir() .. "Logs/"
    lfs.mkdir(logDir)
    trackLogFile = io.open(logDir .. "TrackLog.txt", "w")
    if trackLogFile then
        logToTrackLog("INFO", "SFL-Camera: TrackLog.txt initialized at " .. logDir)
    else
        log.write("SFL-Camera", log.ERROR, "Failed to initialize TrackLog.txt at " .. logDir)
    end
end

-- Attempt to initialize logging safely
local success, err = pcall(initTrackLog)
if not success then
    log.write("SFL-Camera", log.ERROR, "initTrackLog failed: " .. tostring(err))
end

-- Load CameraModes.lua (assumes it's in the same directory)
local cameraModesStatus, cameraModes = pcall(dofile, lfs.writedir() .. "Scripts/SFL-camera/CameraModes.lua")
if not cameraModesStatus then
    log.write("SFL-Camera", log.ERROR, "Failed to load CameraModes.lua: " .. tostring(cameraModes))
end

-- Export hook to update camera position every frame
function LuaExportAfterNextFrame()
    if not cameraModes then
        log.write("SFL-Camera", log.ERROR, "CameraModes not loaded, skipping frame")
        return
    end

    -- Debug: Log that the script is running
    logToTrackLog("DEBUG", "LuaExportAfterNextFrame called at mission time " .. tostring(LoGetMissionTime()))

    -- Get current camera mode (if available)
    local cameraMode = LoGetCameraMode and LoGetCameraMode() or "unknown"
    logToTrackLog("DEBUG", "Current camera mode: " .. tostring(cameraMode))

    -- Update camera position and orientation
    local aircraftID = "SFL-Pilot-1"
    local offset = {x = -30, y = 0, z = 0} -- 30m behind aircraft
    cameraModes.setWeldedWingCamera(aircraftID, offset)
end

-- Cleanup on mission stop
function LuaExportStop()
    if trackLogFile then
        trackLogFile:close()
        trackLogFile = nil
        log.write("SFL-Camera", log.INFO, "TrackLog.txt closed")
    end
end