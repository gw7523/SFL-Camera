-- SFL Camera Control Script for DCS World
-- Location: C:\Users\hollo\Saved Games\DCS\Scripts\SFL-camera\SFL-Camera.lua
-- Purpose: Central script to load dependencies, apply camera configurations, and update camera position in DCS Export.lua environment.
-- Author: The Strike Fighter League, LLC
-- Date: 08 March 2025
-- Version: 1.8
-- Dependencies: Quaternion.lua, Camera-cfg.lua, CameraModes.lua (loaded via dofile below)

--[[
    Overview:
    - Main entry point for the SFL Camera system.
    - Loads required scripts: Quaternion.lua, Camera-cfg.lua, CameraModes.lua.
    - Applies camera configurations using applyCameraConfig().
    - Updates camera position based on user-defined updateMode: "frame" (every frame) or "interval" (time-based).
    - Global enableLogging flag controls WARNING and INFO logs (ERROR logs always written).

    Changes in Version 1.8:
    - Ensured LuaExportActivityNextEvent is always defined to suppress log errors when updateMode = "frame".
    - Added explicit export hook registration for both frame and interval modes.
    - Enhanced logging to track export hook execution and camera updates.
    - Improved comments for clarity and debugging.
]]

-- Logging Control
enableLogging = true  -- Set to false to disable WARNING and INFO logs

-- Camera Update Configuration
updateMode = "frame"  -- Options: "frame" (every frame), "interval" (time-based)
updateInterval = 0.02 -- Update interval in seconds (used only if updateMode is "interval")

-- Load Dependencies with Error Handling
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

-- Load Quaternion.lua first
if not loadScript("C:\\Users\\hollo\\Saved Games\\DCS\\Scripts\\SFL-camera\\Quaternion.lua") then
    return
end

-- Load Camera-cfg.lua
if not loadScript("C:\\Users\\hollo\\Saved Games\\DCS\\Scripts\\SFL-camera\\Camera-cfg.lua") then
    return
end

-- Load CameraModes.lua after Quaternion.lua
if not loadScript("C:\\Users\\hollo\\Saved Games\\DCS\\Scripts\\SFL-camera\\CameraModes.lua") then
    return
end

-- Dependency Checks
if not quatMultiply then
    log.write("SFL-Camera", log.ERROR, "quatMultiply not found. Ensure it is defined globally in Quaternion.lua.")
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

-- ### Configuration Integration ###
function applyCameraConfig()
    local config = cameraConfig
    local identifier = config.identifier
    local mode = config.mode
    local params = config.params

    if mode == "welded_wing" then
        local camera_data = setWeldedWingCamera(identifier, params.offset_local)
        if camera_data and enableLogging then
            local aircraft_data = getAircraftData(identifier)
            if aircraft_data then
                local q_aircraft = aircraft_data.quat
                log.write("SFL-Camera", log.INFO, "Mode: welded_wing - Aircraft Quaternion: w=" .. q_aircraft.w .. 
                          ", x=" .. q_aircraft.x .. ", y=" .. q_aircraft.y .. ", z=" .. q_aircraft.z)
            end
            log.write("SFL-Camera", log.INFO, "Mode: welded_wing - Camera Position: x=" .. camera_data.p.x .. 
                      ", y=" .. camera_data.p.y .. ", z=" .. camera_data.p.z)
        end
        return camera_data
    -- Add other modes as needed
    else
        log.write("SFL-Camera", log.ERROR, "Unsupported camera mode: " .. tostring(mode))
        return nil
    end
end

-- ### Camera Update Function ###
local function updateCamera()
    if enableLogging then
        log.write("SFL-Camera", log.INFO, "updateCamera() called at t=" .. tostring(os.clock()))
    end
    local camera_data = applyCameraConfig()
    if camera_data then
        if enableLogging then
            log.write("SFL-Camera", log.INFO, "Calling LoSetCameraPosition with camera_data at t=" .. tostring(os.clock()))
        end
        LoSetCameraPosition(camera_data)
        if enableLogging then
            log.write("SFL-Camera", log.INFO, "LoSetCameraPosition executed successfully")
        end
    else
        log.write("SFL-Camera", log.WARNING, "No camera_data returned from applyCameraConfig()")
    end
end

-- ### DCS Export Hooks ###
-- Always define LuaExportActivityNextEvent to avoid log errors
local next_time = 0
function LuaExportActivityNextEvent(t)
    if updateMode == "interval" then
        if t >= next_time then
            if enableLogging then
                log.write("SFL-Camera", log.INFO, "LuaExportActivityNextEvent triggered at t=" .. t)
            end
            updateCamera()
            next_time = t + updateInterval
        end
        return next_time
    else
        -- For "frame" mode, return a default time to keep the hook active
        if enableLogging then
            log.write("SFL-Camera", log.INFO, "LuaExportActivityNextEvent called in frame mode at t=" .. t .. " (no action)")
        end
        return t + 1
    end
end

-- Frame-based updates
function LuaExportBeforeNextFrame()
    if updateMode == "frame" then
        if enableLogging then
            log.write("SFL-Camera", log.INFO, "LuaExportBeforeNextFrame triggered")
        end
        updateCamera()
    end
end

-- Log successful initialization
if enableLogging then
    log.write("SFL-Camera", log.INFO, "SFL-Camera.lua (v1.8) initialized with updateMode=" .. updateMode)
end