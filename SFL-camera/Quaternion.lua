-- Quaternion and Frame Conversion Library for DCS World
-- Location: C:\Users\hollo\Saved Games\DCS\Scripts\SFL-camera\Quaternion.lua
-- Purpose: Provide quaternion operations and aircraft data retrieval for camera positioning.
-- Author: The Strike Fighter League, LLC
-- Date: 11 March 2025
-- Version: 1.28
-- Dependencies: None (loaded first by SFL-Camera.lua)

--[[
    Conventions:
    - Aircraft Frame: x=Forward, y=Right, z=Down
    - Camera Frame: x=Right, y=Up, z=Backward
    - Global Frame: x=East, y=North, z=Up
    - Quaternion: {w = scalar, x = i, y = j, z = k}
    - Logging: Errors always logged; Warnings/Info logged if enableLogging is true.

    Changes in Version 1.28:
    - Enhanced getAircraftData to retrieve position, heading, pitch, and bank using LoGetObjectById.
    - Added robust error checking and logging for missing data fields.
    - Clarified use of export environment functions (no LoGetUnitByID exists).
    - Comprehensive comments added for clarity and maintainability.
]]

-- Enable logging by default (can be overridden by SFL-Camera.lua)
enableLogging = true

-- ### CORE QUATERNION OPERATIONS ###

-- Quaternion multiplication
-- Multiplies two quaternions q1 and q2 to combine rotations, returning the resulting quaternion.
function quatMultiply(q1, q2)
    local result = {
        w = q1.w * q2.w - q1.x * q2.x - q1.y * q2.y - q1.z * q2.z,
        x = q1.w * q2.x + q1.x * q2.w + q1.y * q2.z - q1.z * q2.y,
        y = q1.w * q2.y - q1.x * q2.z + q1.y * q2.w + q1.z * q2.x,
        z = q1.w * q2.z + q1.x * q2.y - q1.y * q2.x + q1.z * q2.w
    }
    if enableLogging then
        log.write("Quaternion", log.INFO, "quatMultiply executed: q1=(" .. q1.w .. "," .. q1.x .. "," .. q1.y .. "," .. q1.z .. 
                  "), q2=(" .. q2.w .. "," .. q2.x .. "," .. q2.y .. "," .. q2.z .. ")")
    end
    return result
end

-- Quaternion conjugate
-- Returns the conjugate of quaternion q by negating its vector components, useful for inverse rotation.
function quatConjugate(q)
    local result = {w = q.w, x = -q.x, y = -q.y, z = -q.z}
    if enableLogging then
        log.write("Quaternion", log.INFO, "quatConjugate executed: q=(" .. q.w .. "," .. q.x .. "," .. q.y .. "," .. q.z .. ")")
    end
    return result
end

-- Convert Euler angles to quaternion
-- Takes pitch, heading, and roll (in radians) and converts them to a quaternion for 3D orientation.
function eulerToQuat(pitch, heading, roll)
    local cy = math.cos(heading * 0.5)  -- Half-angle cosine for heading (yaw)
    local sy = math.sin(heading * 0.5)  -- Half-angle sine for heading (yaw)
    local cp = math.cos(pitch * 0.5)    -- Half-angle cosine for pitch
    local sp = math.sin(pitch * 0.5)    -- Half-angle sine for pitch
    local cr = math.cos(roll * 0.5)     -- Half-angle cosine for roll (bank)
    local sr = math.sin(roll * 0.5)     -- Half-angle sine for roll (bank)
    local q = {
        w = cr * cp * cy + sr * sp * sy,
        x = sr * cp * cy - cr * sp * sy,
        y = cr * sp * cy + sr * cp * sy,
        z = cr * cp * sy - sr * sp * cy
    }
    if enableLogging then
        log.write("Quaternion", log.INFO, "eulerToQuat executed: pitch=" .. pitch .. ", heading=" .. heading .. ", roll=" .. roll ..
                  ", quat=(" .. q.w .. "," .. q.x .. "," .. q.y .. "," .. q.z .. ")")
    end
    return q
end

-- Retrieve aircraft data by unit name
-- Fetches position, heading, pitch, and roll (bank) for a unit identified by its name using export environment functions.
function getAircraftData(identifier)
    -- Get all world objects to find the unit's object ID
    local worldObjects = LoGetWorldObjects()
    if not worldObjects then
        log.write("Quaternion", log.ERROR, "LoGetWorldObjects returned nil.")
        return nil
    end

    -- Search for the object ID matching the provided unit name
    local objectId = nil
    for id, obj in pairs(worldObjects) do
        if obj.UnitName == identifier then
            objectId = id
            if enableLogging then
                log.write("Quaternion", log.INFO, "Found object ID for identifier '" .. identifier .. "': " .. tostring(id))
            end
            break
        end
    end

    if not objectId then
        log.write("Quaternion", log.ERROR, "No object found with identifier: " .. identifier)
        return nil
    end

    -- Retrieve detailed data using the object ID
    local detailedObj = LoGetObjectById(objectId)
    if not detailedObj then
        log.write("Quaternion", log.ERROR, "LoGetObjectById failed for ID: " .. tostring(objectId))
        return nil
    end

    -- Verify required orientation fields are present
    if not detailedObj.Heading or not detailedObj.Pitch or not detailedObj.Bank then
        log.write("Quaternion", log.ERROR, "Missing orientation data for '" .. identifier .. "'. Available fields: " .. tableToString(detailedObj))
        return nil
    end

    -- Extract orientation data (in radians)
    local heading = detailedObj.Heading  -- Rotation around vertical axis (yaw)
    local pitch = detailedObj.Pitch      -- Rotation around lateral axis
    local roll = detailedObj.Bank        -- Rotation around longitudinal axis (roll/bank in DCS)

    -- Extract position data if available
    local position = nil
    if detailedObj.Position and type(detailedObj.Position) == "table" then
        position = {
            x = detailedObj.Position.x,  -- East in global frame (meters)
            y = detailedObj.Position.y,  -- North in global frame (meters)
            z = detailedObj.Position.z   -- Up in global frame (meters)
        }
    else
        log.write("Quaternion", log.WARNING, "Position data missing or invalid for '" .. identifier .. "'.")
    end

    -- Convert Euler angles to quaternion for use in 3D transformations
    local quat = eulerToQuat(pitch, heading, roll)

    -- Log retrieved data for debugging
    if enableLogging then
        local posStr = position and ("Pos=(" .. position.x .. "," .. position.y .. "," .. position.z .. ")") or "Pos=unavailable"
        log.write("Quaternion", log.INFO, "getAircraftData: Retrieved data for '" .. identifier .. 
                  "' - Heading=" .. heading .. ", Pitch=" .. pitch .. ", Roll=" .. roll .. 
                  ", Quat=(" .. quat.w .. "," .. q.x .. "," .. q.y .. "," .. q.z .. "), " .. posStr)
    end

    -- Return a table with all retrieved data
    return {
        heading = heading,  -- Heading in radians
        pitch = pitch,      -- Pitch in radians
        roll = roll,        -- Roll (bank) in radians
        quat = quat,        -- Quaternion representation of orientation
        pos = position      -- Position table {x, y, z} or nil if unavailable
    }
end

-- Helper function to convert a table to a string for logging
function tableToString(tbl)
    local str = ""
    for k, v in pairs(tbl) do
        str = str .. tostring(k) .. "=" .. tostring(v) .. ", "
    end
    return str
end

-- Log script initialization
if enableLogging then
    log.write("Quaternion", log.INFO, "Quaternion.lua (v1.28) loaded successfully with direct orientation retrieval.")
end