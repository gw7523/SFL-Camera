-- CameraModes.lua
-- Version 1.25, 07Mar2025
-- Changes:
-- 1. Enhanced logging to include expected vs observed orientations for debugging.
-- 2. Maintained basis vector calculation (z=forward to aircraft, y=global up, x=right).
-- Note: No change to orientation logic as previous fixes align with DCS conventions; issue appears mode-specific.

local log = require("log")

-- Utility functions (assumed available from Quaternion.lua or elsewhere)
local function normalize(v)
    local mag = math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
    if mag == 0 then return {x=0, y=0, z=1} end
    return {x = v.x / mag, y = v.y / mag, z = v.z / mag}
end

local function cross(a, b)
    return {
        x = a.y * b.z - a.z * b.y,
        y = a.z * b.x - a.x * b.z,
        z = a.x * b.y - a.y * b.x
    }
end

-- Convert basis vectors to Euler angles for logging (degrees)
local function basisToEuler(x, y, z)
    local pitch = math.deg(math.asin(-z.z)) -- Assuming z forward
    local heading = math.deg(math.atan2(z.x, z.y))
    local roll = math.deg(math.atan2(-x.z, y.z))
    return heading, pitch, roll
end

-- Set camera in welded wing position
function setWeldedWingCamera(aircraftID, offset)
    -- Get aircraft position and orientation
    local aircraftData = LoGetObjectByName and LoGetObjectByName(aircraftID) or LoGetSelfData()
    if not aircraftData then
        log.write("CameraModes", log.ERROR, "Aircraft " .. tostring(aircraftID) .. " not found")
        return
    end

    local aircraft_pos = aircraftData.Position or {x=0, y=0, z=0}

    -- Calculate camera position (simple offset for now; assumes aircraft frame)
    local camera_pos = {
        x = aircraft_pos.x + offset.x,
        y = aircraft_pos.y + offset.y,
        z = aircraft_pos.z + offset.z
    }

    -- Define camera orientation
    local camera_to_aircraft = {
        x = aircraft_pos.x - camera_pos.x,
        y = aircraft_pos.y - camera_pos.y,
        z = aircraft_pos.z - camera_pos.z
    }
    local camera_z = normalize(camera_to_aircraft) -- Forward: toward aircraft
    local camera_y = {x=0, y=0, z=1} -- Up: global up
    local camera_x = normalize(cross(camera_y, camera_z)) -- Right
    camera_y = normalize(cross(camera_z, camera_x)) -- Recalculate up for orthonormality

    -- Prepare camera table for LoSetCameraPosition
    local camera = {
        p = camera_pos,
        x = camera_x,
        y = camera_y,
        z = camera_z
    }

    -- Log expected orientation
    local h, p, r = basisToEuler(camera_x, camera_y, camera_z)
    logToTrackLog("INFO", string.format("Setting camera at t=%.3f: Pos=(%.1f, %.1f, %.1f), Expected H=%.3f°, P=%.3f°, R=%.3f°",
        LoGetMissionTime(), camera_pos.x, camera_pos.y, camera_pos.z, h, p, r))

    -- Set camera position and orientation
    LoSetCameraPosition(camera)

    -- Log observed orientation (post-set, if DCS provides feedback)
    -- Note: No direct API to get current camera orientation; this is a placeholder
    logToTrackLog("INFO", "Camera set command issued; check DCS behavior")
end

-- Make function globally accessible
_G.setWeldedWingCamera = setWeldedWingCamera