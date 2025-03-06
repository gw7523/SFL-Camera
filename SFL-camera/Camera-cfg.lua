-- Camera Configuration File for DCS World
-- Location: C:\Users\hollo\Saved Games\DCS\Scripts\SFL-camera\Camera-cfg.lua
-- Purpose: Define the aircraft to monitor and the camera mode with its parameters for use by SFL-Camera.lua.
-- Author: The Strike Fighter League, LLC
-- Date: 04 March 2025
-- Version: 1.3

--[[
    Overview:
    - Defines cameraConfig table with:
      - identifier: Aircraft to monitor (unit name, group name, or callsign).
      - mode: Camera mode ("welded_wing", "independent_rotation", "cinematic").
      - params: Mode-specific parameters.
    - Includes validation to ensure configuration usability.
    - Logging: Errors always logged; Warnings logged if enableLogging is true (set in SFL-Camera.lua).

    Supported Modes:
    - "welded_wing":
      - offset_local: {x, y, z} (meters) - Position relative to aircraft.
        - x: Forward (+) / Backward (-)
        - y: Right (+) / Left (-)
        - z: Down (+) / Up (-)
    - "independent_rotation":
      - offset_local: {x, y, z} (meters) - Same as above.
      - rotation: {angle, axisX, axisY, axisZ} - Rotation in radians around a global axis.
    - "cinematic":
      - a, b, c: Ellipsoid semi-axes (meters) - x (east), y (north), z (up).
      - theta0, phi0: Initial angles (radians).
      - dtheta_dt, dphi_dt: Angular rates (radians/second).
      - start_time: Orbit start time (seconds, e.g., os.time()).

    Changes in Version 1.3:
    - Increased offset_local.x from 15 to 20 meters to position camera farther forward.

    Usage:
    - Modify cameraConfig below to set camera behavior.
    - Loaded by SFL-Camera.lua via dofile().
]]

cameraConfig = {
    identifier = "SFL-Pilot-1",  -- Aircraft identifier (unit name for precise targeting)
    mode = "welded_wing",       -- Camera mode
    params = {
        offset_local = {x = 20, y = 5, z = 2}  -- 20m forward, 5m right, 2m below (x increased from 15 to 20)
    }
}

-- Validation Function
-- Checks configuration validity and logs errors
local function validateConfig(config)
    if not config.identifier or type(config.identifier) ~= "string" then
        log.write("CameraConfig", log.ERROR, "Invalid or missing identifier in cameraConfig.")
        return false
    end

    if not config.mode or type(config.mode) ~= "string" then
        log.write("CameraConfig", log.ERROR, "Invalid or missing mode in cameraConfig.")
        return false
    end

    if not config.params or type(config.params) ~= "table" then
        log.write("CameraConfig", log.ERROR, "Invalid or missing params in cameraConfig.")
        return false
    end

    local validModes = {
        welded_wing = true,
        independent_rotation = true,
        cinematic = true
    }

    if not validModes[config.mode] then
        if enableLogging then
            log.write("CameraConfig", log.WARNING, "Unknown mode '" .. config.mode .. "'. Ensure CameraModes.lua supports it.")
        end
    end

    if config.mode == "welded_wing" or config.mode == "independent_rotation" then
        if not config.params.offset_local or type(config.params.offset_local) ~= "table" then
            log.write("CameraConfig", log.ERROR, "Missing or invalid offset_local for mode: " .. config.mode)
            return false
        end
        local ol = config.params.offset_local
        if type(ol.x) ~= "number" or type(ol.y) ~= "number" or type(ol.z) ~= "number" then
            log.write("CameraConfig", log.ERROR, "offset_local must contain numeric x, y, z for mode: " .. config.mode)
            return false
        end
    end

    if config.mode == "independent_rotation" then
        if not config.params.rotation or type(config.params.rotation) ~= "table" then
            log.write("CameraConfig", log.ERROR, "Missing or invalid rotation for independent_rotation mode.")
            return false
        end
        local r = config.params.rotation
        if type(r.angle) ~= "number" or type(r.axisX) ~= "number" or
           type(r.axisY) ~= "number" or type(r.axisZ) ~= "number" then
            log.write("CameraConfig", log.ERROR, "rotation must contain numeric angle, axisX, axisY, axisZ.")
            return false
        end
    end

    if config.mode == "cinematic" then
        local required = {"a", "b", "c", "theta0", "phi0", "dtheta_dt", "dphi_dt", "start_time"}
        for _, key in ipairs(required) do
            if not config.params[key] or type(config.params[key]) ~= "number" then
                log.write("CameraConfig", log.ERROR, "Missing or invalid parameter '" .. key .. "' for cinematic mode.")
                return false
            end
        end
    end

    return true
end

-- Validate on load
validateConfig(cameraConfig)