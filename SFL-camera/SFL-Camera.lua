-- SFL Camera Control Script for DCS World
-- Location: C:\Users\hollo\Saved Games\DCS\Scripts\SFL-camera\SFL-Camera.lua
-- Purpose: Central script to load dependencies, apply camera configurations, and update camera position in DCS Export.lua environment.
-- Author: The Strike Fighter League, LLC
-- Date: 03 February 2025
-- Version: 1.9
-- Dependencies: Quaternion.lua, Camera-cfg.lua, CameraModes.lua

--[[
    Overview:
    - Loads scripts in order: Quaternion.lua, Camera-cfg.lua, CameraModes.lua.
    - Applies camera configurations and updates position via export hooks.
    - Update modes: "frame" (every frame) or "interval" (time-based).

    Changes in Version 1.9:
    - Ensured Quaternion.lua loads before CameraModes.lua to resolve function access issues.
    - Added explicit check for setWeldedWingCamera after loading CameraModes.lua.
    - Enhanced updateCamera with detailed logging and nil checks.
    - Updated export hooks to prevent LuaExportActivityNextEvent errors and ensure continuous updates.
    - Updated date to 03 February 2025.
]]

-- Logging Control
enableLogging = true

-- Camera Update Configuration
updateMode = "frame"  -- "frame" or "interval"
updateInterval = 0.02 -- Seconds, used if updateMode is "interval"

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
        return t + 0.01 -- Ensure hook remains active
    end
end

function LuaExportBeforeNextFrame()
    if updateMode == "frame" then
        updateCamera()
    end
end

if enableLogging then
    log.write("SFL-Camera", log.INFO, "SFL-Camera.lua (v1.9) initialized with updateMode=" .. updateMode)
end