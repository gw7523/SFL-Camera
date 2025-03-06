-- SFL Camera Control Script for DCS World
-- Location: C:\Users\hollo\Saved Games\DCS\Scripts\SFL-camera\SFL-Camera.lua
-- Purpose: Central script to load dependencies, apply camera configurations, and update camera position in DCS Export.lua environment.
-- Author: The Strike Fighter League, LLC
-- Date: 04 February 2025
-- Version: 2.3
-- Dependencies: Quaternion.lua, Camera-cfg.lua, CameraModes.lua

--[[
    Overview:
    - Loads scripts in order: Quaternion.lua, Camera-cfg.lua, CameraModes.lua.
    - Applies camera configurations and updates position via export hooks.
    - Update modes: "frame" (every frame) or "interval" (time-based).
    - Logging: Errors to DCS.log, Info to TrackLog.txt.

    Changes in Version 2.3 (04 February 2025):
    - Moved initTrackLog() and logToTrackLog definition to the top to ensure availability before loading dependencies.
    - Made enableLogging and logToTrackLog global for access in loaded scripts.
    - Added logging of world objects to verify aircraft identifier.
    - Version updated from 2.2 to 2.3.
]]

-- Logging Control
enableLogging = true  -- Global variable for consistent logging across scripts

-- Camera Update Configuration
updateMode = "frame"  -- "frame" or "interval"
updateInterval = 0.02 -- Seconds, used if updateMode is "interval"

-- Track Log Configuration
local trackLogFile = nil
function initTrackLog()
    if not trackLogFile then
        trackLogFile = io.open(lfs.writedir() .. "Logs/TrackLog.txt", "a") -- Append mode for text logging
        if not trackLogFile then
            log.write("SFL-Camera", log.ERROR, "Failed to open TrackLog.txt for writing.")
            return false
        end
        if enableLogging then
            logToTrackLog("INFO", "SFL-Camera: TrackLog.txt initialized at " .. lfs.writedir() .. "Logs/")
        end
    end
    return true
end

-- Initialize track log early
initTrackLog()

-- Define logToTrackLog globally before dependencies
function logToTrackLog(level, message)
    if trackLogFile then
        trackLogFile:write(level .. ": " .. message .. "\n")
        trackLogFile:flush()
    end
end

local function writeTrackLog(missionTime, aircraftPos, aircraftQuat, cameraPos, cameraBasis)
    if trackLogFile then
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
        trackLogFile:flush()
    end
end

local function closeTrackLog()
    if trackLogFile then
        trackLogFile:close()
        trackLogFile = nil
        if enableLogging then
            logToTrackLog("INFO", "SFL-Camera: TrackLog.txt closed.")
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
        logToTrackLog("INFO", "SFL-Camera: Successfully loaded " .. path)
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

-- Log world objects to verify aircraft identifier
local worldObjects = LoGetWorldObjects()
for id, obj in pairs(worldObjects) do
    if enableLogging then
        logToTrackLog("INFO", "SFL-Camera: Object ID: " .. id .. ", Name: " .. (obj.UnitName or "N/A"))
    end
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
            logToTrackLog("INFO", "SFL-Camera: Applied welded_wing mode for '" .. identifier .. "'")
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
        logToTrackLog("INFO", "SFL-Camera: updateCamera called at t=" .. tostring(LoGetModelTime()))
    end
    local camera_data = applyCameraConfig()
    if camera_data then
        LoSetCameraPosition(camera_data)
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
            logToTrackLog("INFO", "SFL-Camera: LoSetCameraPosition executed: p=(" .. camera_data.p.x .. "," .. 
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
            logToTrackLog("INFO", "SFL-Camera: LuaExportAfterNextFrame called updateCamera")
        end
    end
end

function LuaExportStop()
    closeTrackLog()
end

if enableLogging then
    logToTrackLog("INFO", "SFL-Camera.lua (v2.3) initialized with updateMode=" .. updateMode .. " and text track logging.")
end