-- SFL Camera Control Script for DCS World
-- Location: C:\Users\hollo\Saved Games\DCS\Scripts\SFL-camera\SFL-Camera.lua
-- Purpose: Central script to load dependencies, apply camera configurations, and update camera position in DCS Export.lua environment.
-- Author: The Strike Fighter League, LLC
-- Date: 03 February 2025
-- Version: 2.1
-- Dependencies: Quaternion.lua, Camera-cfg.lua, CameraModes.lua

--[[
    Overview:
    - Loads scripts in order: Quaternion.lua, Camera-cfg.lua, CameraModes.lua.
    - Applies camera configurations and updates position via export hooks.
    - Update modes: "frame" (every frame) or "interval" (time-based).

    Changes in Version 2.1 (03 February 2025):
    - Fixed tracking issue: Moved updateCamera call to LuaExportAfterNextFrame for "frame" mode to ensure per-frame updates, addressing the simulation not tracking the aircraft.
    - Fixed logging error: Replaced binary logging with string.pack (unavailable in DCS Lua) with text-based logging to TrackLog.txt using string.format, resolving "attempt to call field 'pack' (a nil value)" error.
    - Added error handling: Wrapped writeTrackLog in pcall to prevent script failure if logging fails, ensuring continuous camera updates.
    - Updated version from 2.0 to 2.1 to reflect these critical fixes.
    - Enhanced comments: Detailed explanations of changes and their impact on functionality.
]]

-- Logging Control
enableLogging = true

-- Camera Update Configuration
updateMode = "frame"  -- "frame" or "interval"
updateInterval = 0.02 -- Seconds, used if updateMode is "interval"

-- Track Log Configuration
local trackLogFile = nil
local function initTrackLog()
    if not trackLogFile then
        trackLogFile = io.open(lfs.writedir() .. "Logs/TrackLog.txt", "a") -- Append mode for text logging
        if not trackLogFile then
            log.write("SFL-Camera", log.ERROR, "Failed to open TrackLog.txt for writing.")
            return false
        end
        if enableLogging then
            log.write("SFL-Camera", log.INFO, "TrackLog.txt initialized at " .. lfs.writedir() .. "Logs/")
        end
    end
    return true
end

local function writeTrackLog(missionTime, aircraftPos, aircraftQuat, cameraPos, cameraBasis)
    if trackLogFile then
        -- Text-based logging: Replaces binary string.pack with string.format for DCS Lua compatibility
        local logEntry = string.format(
            "Time: %.3f, AircraftPos: (%.2f, %.2f, %.2f), AircraftQuat: (%.4f, %.4f, %.4f, %.4f), " ..
            "CameraPos: (%.2f, %.2f, %.2f), CameraBasis: (%.4f, %.4f, %.4f, %.4f, %.4f, %.4f, %.4f, %.4f, %.4f)\n",
            missionTime,
            aircraftPos.x, aircraftPos.y, aircraftPos.z,
            aircraftQuat.w, aircraftQuat.x, aircraftQuat.y, aircraftQuat.z,
            cameraPos.x, cameraPos.y, cameraPos.z,
            cameraBasis.x.x, cameraBasis.x.y, cameraBasis.x.z,
            cameraBasis.y.x, cameraBasis.y.y, cameraBasis.y.z,
            cameraBasis.z.x, cameraBasis.z.y, cameraBasis.z.z
        )
        trackLogFile:write(logEntry)
        trackLogFile:flush() -- Ensure data is written to file immediately
    end
end

local function closeTrackLog()
    if trackLogFile then
        trackLogFile:close()
        trackLogFile = nil
        if enableLogging then
            log.write("SFL-Camera", log.INFO, "TrackLog.txt closed.")
        end
    end
end

-- Load Dependencies
local function loadScript(path)
    local status, err = pcall(function() dofile(path) end)
    if not status then
        log.write("SFL-Camera", log.ERROR, "Failed to load " .. path .. ": " .. tostring(err))
        return false
    end
    if enableLogging then
        log.write("SFL-Camera", log.INFO, "Successfully loaded " .. path)
    end
    return true
end

if not loadScript("C:\\Users\\hollo\\Saved Games\\DCS\\Scripts\\SFL-camera\\Quaternion.lua") then
    return
end
if not loadScript("C:\\Users\\hollo\\Saved Games\\DCS\\Scripts\\SFL-camera\\Camera-cfg.lua") then
    return
end
if not loadScript("C:\\Users\\hollo\\Saved Games\\DCS\\Scripts\\SFL-camera\\CameraModes.lua") then
    return
end

-- Dependency Checks
if not (quatMultiply and quatConjugate and getAircraftData and aircraftToCamera) then
    log.write("SFL-Camera", log.ERROR, "Quaternion.lua functions missing.")
    return
end
if not cameraConfig then
    log.write("SFL-Camera", log.ERROR, "cameraConfig not found in Camera-cfg.lua.")
    return
end
if not setWeldedWingCamera then
    log.write("SFL-Camera", log.ERROR, "setWeldedWingCamera not found in CameraModes.lua.")
    return
end

-- Apply Camera Configuration
function applyCameraConfig()
    local config = cameraConfig
    local identifier = config.identifier
    local mode = config.mode
    local params = config.params

    if mode == "welded_wing" then
        local camera_data = setWeldedWingCamera(identifier, params.offset_local)
        if camera_data and enableLogging then
            log.write("SFL-Camera", log.INFO, "Applied welded_wing mode for '" .. identifier .. "'")
        end
        return camera_data
    else
        log.write("SFL-Camera", log.ERROR, "Unsupported mode: " .. tostring(mode))
        return nil
    end
end

-- Update Camera Position
local function updateCamera()
    if enableLogging then
        log.write("SFL-Camera", log.INFO, "updateCamera called at t=" .. tostring(os.clock()))
    end
    local camera_data = applyCameraConfig()
    if camera_data then
        LoSetCameraPosition(camera_data)
        -- Log track data with error handling to prevent script interruption
        local aircraft_data = getAircraftData(cameraConfig.identifier)
        if aircraft_data then
            local success, err = pcall(function()
                writeTrackLog(LoGetModelTime(), aircraft_data.pos, aircraft_data.quat, camera_data.p, 
                              {x=camera_data.x, y=camera_data.y, z=camera_data.z})
            end)
            if not success and enableLogging then
                log.write("SFL-Camera", log.WARNING, "TrackLog write failed: " .. tostring(err))
            end
        end
        if enableLogging then
            log.write("SFL-Camera", log.INFO, "LoSetCameraPosition executed: p=(" .. camera_data.p.x .. "," .. 
                      camera_data.p.y .. "," .. camera_data.p.z .. ")")
        end
    else
        log.write("SFL-Camera", log.WARNING, "No camera_data returned from applyCameraConfig()")
    end
end

-- DCS Export Hooks
if updateMode == "interval" then
    local next_time = 0
    function LuaExportActivityNextEvent(t)
        if t >= next_time then
            updateCamera()
            next_time = t + updateInterval
        end
        return next_time
    end
else -- "frame" mode
    function LuaExportAfterNextFrame()
        updateCamera()
        if enableLogging then
            log.write("SFL-Camera", log.INFO, "LuaExportAfterNextFrame called updateCamera")
        end
    end
end

function LuaExportStop()
    closeTrackLog()
end

-- Initialize track log on script load
initTrackLog()

if enableLogging then
    log.write("SFL-Camera", log.INFO, "SFL-Camera.lua (v2.1) initialized with updateMode=" .. updateMode .. " and text track logging.")
end