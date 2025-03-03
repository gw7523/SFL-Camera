-- Quaternion and Frame Conversion Library for DCS World
-- Location: C:\Users\hollo\Saved Games\DCS\Scripts\SFL-camera\Quaternion.lua
-- Purpose: Provide quaternion operations and aircraft data retrieval for camera positioning.
-- Author: The Strike Fighter League, LLC
-- Date: 09 March 2025
-- Version: 1.26
-- Dependencies: None (loaded first by SFL-Camera.lua)

--[[
    Conventions:
    - Aircraft Frame: x=Forward, y=Right, z=Down
    - Camera Frame: x=Right, y=Up, z=Backward
    - Global Frame: x=East, y=North, z=Up
    - Quaternion: {w = scalar, x = i, y = j, z = k}
    - Logging: Errors always logged; Warnings/Info logged if enableLogging is true.

    Changes in Version 1.26:
    - Added aircraftToCamera function to align camera orientation with aircraft frame.
    - Updated logging to confirm function definitions and execution.
]]

-- Enable logging by default (can be overridden by SFL-Camera.lua)
enableLogging = true

-- ### CORE QUATERNION OPERATIONS ###
-- Quaternion multiplication
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
function quatConjugate(q)
    local result = {w = q.w, x = -q.x, y = -q.y, z = -q.z}
    if enableLogging then
        log.write("Quaternion", log.INFO, "quatConjugate executed: q=(" .. q.w .. "," .. q.x .. "," .. q.y .. "," .. q.z .. ")")
    end
    return result
end

-- Convert basis vectors to quaternion
function basisToQuat(xVec, yVec, zVec)
    local trace = xVec.x + yVec.y + zVec.z
    local q = {}
    if trace > 0 then
        local s = math.sqrt(trace + 1.0) * 2
        q.w = 0.25 * s
        q.x = (zVec.y - yVec.z) / s
        q.y = (xVec.z - zVec.x) / s
        q.z = (yVec.x - xVec.y) / s
    else
        -- Fallback to identity quaternion if trace is invalid
        q = {w = 1, x = 0, y = 0, z = 0}
        if enableLogging then
            log.write("Quaternion", log.WARNING, "basisToQuat: Invalid trace, using identity quaternion")
        end
    end
    if enableLogging then
        log.write("Quaternion", log.INFO, "basisToQuat executed: result=(" .. q.w .. "," .. q.x .. "," .. q.y .. "," .. q.z .. ")")
    end
    return q
end

-- Retrieve aircraft data
function getAircraftData(identifier)
    local worldObjects = LoGetWorldObjects()
    if not worldObjects then
        log.write("Quaternion", log.ERROR, "LoGetWorldObjects returned nil.")
        return nil
    end

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

    local detailedObj = LoGetObjectById(objectId)
    if not detailedObj then
        log.write("Quaternion", log.ERROR, "LoGetObjectById failed for ID: " .. tostring(objectId))
        return nil
    end

    local pos = detailedObj.Position or {}
    if pos and type(pos.p) == "table" and type(pos.x) == "table" then
        local xVec = pos.x
        local yVec = pos.y
        local zVec = pos.z
        local quat = basisToQuat(xVec, yVec, zVec)
        local position = pos.p
        if enableLogging then
            log.write("Quaternion", log.INFO, "getAircraftData: Retrieved data for '" .. identifier .. 
                      "' - Pos=(" .. position.x .. "," .. position.y .. "," .. position.z .. 
                      "), Quat=(" .. quat.w .. "," .. quat.x .. "," .. quat.y .. "," .. quat.z .. ")")
        end
        return { quat = quat, pos = position }
    else
        log.write("Quaternion", log.WARNING, "Invalid Position structure for '" .. identifier .. "'. Expected p=table, x/y/z=tables.")
        return nil
    end
end

-- Convert aircraft orientation to camera orientation
function aircraftToCamera(q_aircraft)
    -- Transformation quaternion: 180° rotation around y-axis
    -- Maps: aircraft x (forward) -> camera -z (backward), y (right) -> x (right), z (down) -> y (up)
    local q_transform = {w = 0, x = 0, y = 1, z = 0}
    local q_camera = quatMultiply(q_transform, q_aircraft)
    if enableLogging then
        log.write("Quaternion", log.INFO, "aircraftToCamera executed: q_aircraft=(" .. q_aircraft.w .. "," .. q_aircraft.x .. "," .. q_aircraft.y .. "," .. q_aircraft.z .. 
                  "), q_camera=(" .. q_camera.w .. "," .. q_camera.x .. "," .. q_camera.y .. "," .. q_camera.z .. ")")
    end
    return q_camera
end

-- Log confirmation of script loading
if enableLogging then
    log.write("Quaternion", log.INFO, "Quaternion.lua (v1.26) loaded successfully with global functions defined, including aircraftToCamera.")
end