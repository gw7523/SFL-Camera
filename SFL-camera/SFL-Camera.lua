-- SFL Camera Control Script for DCS World
-- Location: C:\Users\hollo\Saved Games\DCS\Scripts\SFL-camera\SFL-Camera.lua
-- Purpose: Central script to load dependencies, apply camera configurations, and update camera position in DCS Export.lua environment.
-- Author: The Strike Fighter League, LLC
-- Date: 03 February 2025
-- Version: 2.0
-- Dependencies: Quaternion.lua, Camera-cfg.lua, CameraModes.lua

--[[
    Overview:
    - Loads scripts in order: Quaternion.lua, Camera-cfg.lua, CameraModes.lua.
    - Applies camera configurations and updates position via export hooks.
    - Update modes: "frame" (every frame) or "interval" (time-based).

    Changes in Version 2.0 (03 February 2025):
    - Added compact track log: Implemented `TrackLog.bin` in binary format to record mission time, aircraft position/quaternion, and camera position/orientation, reducing log size.
    - Enhanced frame mode: Moved `updateCamera()` call to `LuaExportActivityNextEvent` for consistent frame updates, preventing skips.
    - Updated version from 1.9 to 2.0 and date to 03 February 2025.
    - Integrated with rotation test fixes in CameraModes.lua v1.16.
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
        trackLogFile = io.open(lfs.writedir() .. "Logs/TrackLog.bin", "wb")
        if not trackLogFile then
            log.write("SFL-Camera", log.ERROR, "Failed to open TrackLog.bin for writing.")
            return false
        end
        if enableLogging then
            log.write("SFL-Camera", log.INFO, "TrackLog.bin initialized at " .. lfs.writedir() .. "Logs/")
        end
    end
    return true
end

local function writeTrackLog(missionTime, aircraftPos, aircraftQuat, cameraPos, cameraBasis)
    if trackLogFile then
        -- Binary format: missionTime (double), aircraftPos (3 floats), aircraftQuat (4 floats), cameraPos (3 floats), cameraBasis (9 floats)
        trackLogFile:write(string.pack("d", missionTime))
        trackLogFile:write(string.pack("fff", aircraftPos.x, aircraftPos.y, aircraftPos.z))
        trackLogFile:write(string.pack("ffff", aircraftQuat.w, aircraftQuat.x, aircraftQuat.y, aircraftQuat.z))
        trackLogFile:write(string.pack("fff", cameraPos.x, cameraPos.y, cameraPos.z))
        trackLogFile:write(string.pack("fffffffff", cameraBasis.x.x, cameraBasis.x.y, cameraBasis.x.z,
                                      cameraBasis.y.x, cameraBasis.y.y, cameraBasis.y.z,
                                      cameraBasis.z.x, cameraBasis.z.y, cameraBasis.z.z))
    end
end

local function closeTrackLog()
    if trackLogFile then
        trackLogFile:close()
        trackLogFile = nil
        if enableLogging then
            log.write("SFL-Camera", log.INFO, "TrackLog.bin closed.")
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
        -- Log track data
        local aircraft_data = getAircraftData(cameraConfig.identifier)
        if aircraft_data then
            writeTrackLog(LoGetModelTime(), aircraft_data.pos, aircraft_data.quat, camera_data.p, {x=camera_data.x, y=camera_data.y, z=camera_data.z})
        end
        if enableLogging then
            log.write("SFL-Camera", log.INFO, "LoSetCameraPosition executed: p=(" .. camera_data.p.x .. "," .. camera_data.p.y .. "," .. camera_data.p.z .. ")")
        end
    else
        log.write("SFL-Camera", log.WARNING, "No camera_data returned from applyCameraConfig()")
    end
end

-- DCS Export Hooks
local next_time = 0
function LuaExportActivityNextEvent(t)
    if updateMode == "interval" then
        if t >= next_time then
            updateCamera()
            next_time = t + updateInterval
        end
        return next_time
    else -- "frame" mode
        if enableLogging then
            log.write("SFL-Camera", log.INFO, "LuaExportActivityNextEvent in frame mode at t=" .. t)
        end
        updateCamera() -- Call updateCamera every frame
        return t + 0.01 -- Ensure hook remains active
    end
end

function LuaExportBeforeNextFrame()
    -- Removed updateCamera call to avoid duplicate updates in frame mode
end

function LuaExportStop()
    closeTrackLog()
end

-- Initialize track log on script load
initTrackLog()

if enableLogging then
    log.write("SFL-Camera", log.INFO, "SFL-Camera.lua (v2.0) initialized with updateMode=" .. updateMode .. " and track logging.")
end