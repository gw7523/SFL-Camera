-- Quaternion and Frame Conversion Library for DCS World
-- Location: C:\Users\hollo\Saved Games\DCS\Scripts\SFL-camera\Quaternion.lua
-- Purpose: Provide quaternion operations and aircraft data retrieval for camera positioning.
-- Author: The Strike Fighter League, LLC
-- Date: 03 February 2025
-- Version: 1.29
-- Dependencies: None (loaded first by SFL-Camera.lua)

--[[
    Conventions:
    - Aircraft Frame: x=Forward, y=Right, z=Down
    - Camera Frame: x=Right, y=Up, z=Backward
    - Global Frame: x=East, y=North, z=Up
    - Quaternion: {w = scalar, x = i, y = j, z = k}
    - Logging: Errors always logged; Warnings/Info logged if enableLogging is true.

    Changes in Version 1.29:
    - Ensured all functions are globally scoped for accessibility by CameraModes.lua.
    - Enhanced getAircraftData with fallback to LoGetSelfData() when Position data is invalid.
    - Added detailed logging for aircraft data retrieval to debug tracking issues.
    - Updated date and version to reflect modifications as of 03 February 2025.
]]

-- Enable logging by default (can be overridden by SFL-Camera.lua)
enableLogging = true

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

-- Convert Euler angles to quaternion
function eulerToQuat(pitch, heading, roll)
    local cy = math.cos(heading * 0.5)
    local sy = math.sin(heading * 0.5)
    local cp = math.cos(pitch * 0.5)
    local sp = math.sin(pitch * 0.5)
    local cr = math.cos(roll * 0.5)
    local sr = math.sin(roll * 0.5)
    local q = {
        w = cr * cp * cy + sr * sp * sy,
        x = sr * cp * cy - cr * sp * sy,
        y = cr * sp * cy + sr * cp * sy,
        z = cr * cp * sy - sr * sp * cy
    }
    if enableLogging then
        log.write("Quaternion", log.INFO, "eulerToQuat: pitch=" .. pitch .. ", heading=" .. heading .. ", roll=" .. roll ..
                  ", quat=(" .. q.w .. "," .. q.x .. "," .. q.y .. "," .. q.z .. ")")
    end
    return q
end

-- Retrieve aircraft data by unit name
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
                log.write("Quaternion", log.INFO, "Found object ID for '" .. identifier .. "': " .. tostring(id))
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

    if detailedObj.Position and type(detailedObj.Position) == "table" and detailedObj.Heading and detailedObj.Pitch and detailedObj.Bank then
        local position = {
            x = detailedObj.Position.x,
            y = detailedObj.Position.y,
            z = detailedObj.Position.z
        }
        local heading = detailedObj.Heading
        local pitch = detailedObj.Pitch
        local roll = detailedObj.Bank
        local quat = eulerToQuat(pitch, heading, roll)

        if enableLogging then
            log.write("Quaternion", log.INFO, "getAircraftData: '" .. identifier .. 
                      "' - Pos=(" .. position.x .. "," .. position.y .. "," .. position.z .. 
                      "), Heading=" .. heading .. ", Pitch=" .. pitch .. ", Roll=" .. roll ..
                      ", Quat=(" .. quat.w .. "," .. quat.x .. "," .. quat.y .. "," .. quat.z .. ")")
        end

        return {
            pos = position,
            heading = heading,
            pitch = pitch,
            roll = roll,
            quat = quat
        }
    else
        -- Fallback to LoGetSelfData if the aircraft is the player's own
        local selfData = LoGetSelfData()
        if selfData and selfData.Name == identifier then
            local position = selfData.Position
            local heading = selfData.Heading
            local pitch = selfData.Pitch
            local roll = selfData.Bank
            local quat = eulerToQuat(pitch, heading, roll)

            if enableLogging then
                log.write("Quaternion", log.INFO, "getAircraftData (fallback): '" .. identifier .. 
                          "' - Pos=(" .. position.x .. "," .. position.y .. "," .. position.z .. 
                          "), Heading=" .. heading .. ", Pitch=" .. pitch .. ", Roll=" .. roll ..
                          ", Quat=(" .. quat.w .. "," .. quat.x .. "," .. quat.y .. "," .. quat.z .. ")")
            end

            return {
                pos = position,
                heading = heading,
                pitch = pitch,
                roll = roll,
                quat = quat
            }
        else
            log.write("Quaternion", log.ERROR, "Invalid data for '" .. identifier .. "'. Self data not applicable.")
            return nil
        end
    end
end

-- Convert aircraft orientation to camera orientation
function aircraftToCamera(q_aircraft)
    local q_transform = {w = 0, x = 0, y = 1, z = 0} -- 180° rotation around y-axis
    local q_camera = quatMultiply(q_transform, q_aircraft)
    if enableLogging then
        log.write("Quaternion", log.INFO, "aircraftToCamera: q_aircraft=(" .. q_aircraft.w .. "," .. q_aircraft.x .. "," .. q_aircraft.y .. "," .. q_aircraft.z .. 
                  "), q_camera=(" .. q_camera.w .. "," .. q_camera.x .. "," .. q_camera.y .. "," .. q_camera.z .. ")")
    end
    return q_camera
end

-- Log initialization
if enableLogging then
    log.write("Quaternion", log.INFO, "Quaternion.lua (v1.29) loaded with global scope and fallback mechanism.")
end