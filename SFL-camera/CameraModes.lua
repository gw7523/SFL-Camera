-- Camera Dynamics Helper Functions for DCS World
-- Location: C:\Users\hollo\Saved Games\DCS\Scripts\SFL-camera\CameraModes.lua
-- Purpose: Provide functions to define camera modes relative to an aircraft using quaternions.
-- Author: The Strike Fighter League, LLC
-- Date: 07 February 2025
-- Version: 1.18
-- Dependencies: Quaternion.lua (must be loaded first by SFL-Camera.lua)

--[[
    Overview:
    - Defines camera modes: welded_wing, independent_rotation, cinematic.
    - Conventions:
      - Aircraft Frame: x=Forward, y=Right, z=Down
      - Camera Frame: x=Right, y=Up, z=Backward
      - Global Frame: x=East, y=North, z=Up
      - Quaternion: {w = scalar, x = i, y = j, z = k}
    - Logging: Errors always logged; Info logged to TrackLog.txt if enableLogging is true.

    Changes in Version 1.18 (07 February 2025):
    - Fixed camera orientation issue where camera looked at nadir/zenith:
      - Revised setWeldedWingCamera basis vector calculation:
        - z-axis: Now points from camera to aircraft (negative offset vector).
        - y-axis: Aligned with aircraft up vector, orthonormalized against z-axis.
        - x-axis: Cross product of y and z for right-handed system.
      - Ensures camera consistently faces aircraft while respecting up direction.
    - Version updated from 1.17 to 1.18.
    - Added detailed comments on orientation fix and coordinate conventions.
]]--

-- Dependency Check
if not quatMultiply or not quatConjugate or not getAircraftData or not aircraftToCamera then
    log.write("CameraModes", log.ERROR, "Required functions from Quaternion.lua not found.")
    return
else
    if enableLogging then
        logToTrackLog("INFO", "CameraModes: All required Quaternion.lua functions confirmed available.")
    end
end

-- Local helper functions
local function cross(u, v)
    return {
        x = u.y * v.z - u.z * v.y,
        y = u.z * v.x - u.x * v.z,
        z = u.x * v.y - u.y * v.x
    }
end

local function normalize(v)
    local len = math.sqrt(v.x^2 + v.y^2 + v.z^2)
    if len < 1e-6 then return {x=0, y=0, z=0} end
    return {x = v.x / len, y = v.y / len, z = v.z / len}
end

local function magnitude(v)
    return math.sqrt(v.x^2 + v.y^2 + v.z^2)
end

local function dot(u, v)
    return u.x * v.x + u.y * v.y + u.z * v.z
end

-- Rotation Test Configuration (unchanged)
local rotationTestEnabled = false  -- Disabled by default for stable tracking
local rotationInterval = 5         -- Seconds between rotations
local rotationAxes = {"x", "y", "z"}
local currentRotationAxisIndex = 1
local lastRotationTime = 0
local currentBasis = nil           -- Persistent rotated basis vectors

-- Welded Wing Camera: Fixed position relative to aircraft, oriented to look at aircraft origin
function setWeldedWingCamera(identifier, offset_local)
    local mission_time = LoGetModelTime()
    if enableLogging then
        logToTrackLog("INFO", "CameraModes: setWeldedWingCamera called at mission time: " .. tostring(mission_time))
    end

    local aircraft_data = getAircraftData(identifier)
    if not aircraft_data then
        log.write("CameraModes", log.ERROR, "Aircraft not found: " .. identifier)
        return nil
    end
    local q_aircraft = aircraft_data.quat
    local aircraft_pos = aircraft_data.pos
    if enableLogging then
        logToTrackLog("INFO", "CameraModes: setWeldedWingCamera: '" .. identifier .. "' Position: x=" .. aircraft_pos.x .. 
                      ", y=" .. aircraft_pos.y .. ", z=" .. aircraft_pos.z)
        logToTrackLog("INFO", "CameraModes: setWeldedWingCamera: Local Offset: x=" .. offset_local.x .. 
                      ", y=" .. offset_local.y .. ", z=" .. offset_local.z)
    end

    -- Transform offset to global frame
    local offset_quat = {w = 0, x = offset_local.x, y = offset_local.y, z = offset_local.z}
    local offset_global = quatMultiply(quatMultiply(q_aircraft, offset_quat), quatConjugate(q_aircraft))
    local offset_global_vec = {x = offset_global.x, y = offset_global.y, z = offset_global.z}
    if enableLogging then
        logToTrackLog("INFO", "CameraModes: setWeldedWingCamera: Global Offset: x=" .. offset_global_vec.x .. 
                      ", y=" .. offset_global_vec.y .. ", z=" .. offset_global_vec.z)
    end

    -- Calculate camera position
    local camera_pos = {
        x = aircraft_pos.x + offset_global_vec.x,
        y = aircraft_pos.y + offset_global_vec.y,
        z = aircraft_pos.z + offset_global_vec.z
    }

    -- Aircraft up vector (local -z, i.e., upward in aircraft frame)
    local up_local_quat = {w = 0, x = 0, y = 0, z = -1}
    local aircraft_up_global = quatMultiply(quatMultiply(q_aircraft, up_local_quat), quatConjugate(q_aircraft))
    local aircraft_up_global_vec = normalize({x = aircraft_up_global.x, y = aircraft_up_global.y, z = aircraft_up_global.z})

    -- Camera z-axis: Direction from camera to aircraft (negative offset vector)
    local camera_to_aircraft = {
        x = aircraft_pos.x - camera_pos.x,
        y = aircraft_pos.y - camera_pos.y,
        z = aircraft_pos.z - camera_pos.z
    }
    local camera_z = normalize(camera_to_aircraft)  -- Points toward aircraft

    -- Camera y-axis: Align with aircraft up vector, orthogonal to z-axis
    -- First, project aircraft up vector onto plane perpendicular to camera_z
    local dot_up_z = dot(aircraft_up_global_vec, camera_z)
    local temp_y = {
        x = aircraft_up_global_vec.x - dot_up_z * camera_z.x,
        y = aircraft_up_global_vec.y - dot_up_z * camera_z.y,
        z = aircraft_up_global_vec.z - dot_up_z * camera_z.z
    }
    local camera_y = normalize(temp_y)  -- Ensure y is orthogonal to z and aligned with aircraft up

    -- Camera x-axis: Right vector, computed as cross product of y and z
    local camera_x = normalize(cross(camera_y, camera_z))

    -- Ensure orthonormality by recomputing y as cross of z and x
    camera_y = normalize(cross(camera_z, camera_x))

    local camera_basis = {x = camera_x, y = camera_y, z = camera_z}

    -- Rotation Test (unchanged, disabled by default)
    if rotationTestEnabled and mission_time - lastRotationTime >= rotationInterval then
        local axis = rotationAxes[currentRotationAxisIndex]
        local axis_vec
        if axis == "x" then axis_vec = camera_basis.x
        elseif axis == "y" then axis_vec = camera_basis.y
        elseif axis == "z" then axis_vec = camera_basis.z
        end

        -- Define 90° rotation quaternion around local axis
        local rotation_quat = {
            w = math.cos(math.pi/4),
            x = axis_vec.x * math.sin(math.pi/4),
            y = axis_vec.y * math.sin(math.pi/4),
            z = axis_vec.z * math.sin(math.pi/4)
        }

        -- Rotate basis vectors
        local function rotateVector(v, q)
            local v_quat = {w = 0, x = v.x, y = v.y, z = v.z}
            local result = quatMultiply(quatMultiply(q, v_quat), quatConjugate(q))
            return normalize({x = result.x, y = result.y, z = result.z})
        end

        camera_basis.x = rotateVector(camera_basis.x, rotation_quat)
        camera_basis.y = rotateVector(camera_basis.y, rotation_quat)
        camera_basis.z = rotateVector(camera_basis.z, rotation_quat)
        currentBasis = camera_basis

        currentRotationAxisIndex = (currentRotationAxisIndex % #rotationAxes) + 1
        lastRotationTime = mission_time
        if enableLogging then
            logToTrackLog("INFO", "CameraModes: Applied 90° rotation around " .. axis .. " axis at mission time: " .. mission_time .. 
                          ", New Basis: x=(" .. camera_basis.x.x .. "," .. camera_basis.x.y .. "," .. camera_basis.x.z .. 
                          "), y=(" .. camera_basis.y.x .. "," .. camera_basis.y.y .. "," .. camera_basis.y.z .. 
                          "), z=(" .. camera_basis.z.x .. "," .. camera_basis.z.y .. "," .. camera_basis.z.z .. ")")
        end
    elseif currentBasis then
        camera_basis = currentBasis
        if enableLogging then
            logToTrackLog("INFO", "CameraModes: Using last rotated basis at mission time: " .. mission_time .. 
                          ", Basis: x=(" .. camera_basis.x.x .. "," .. camera_basis.x.y .. "," .. camera_basis.x.z .. 
                          "), y=(" .. camera_basis.y.x .. "," .. camera_basis.y.y .. "," .. camera_basis.y.z .. 
                          "), z=(" .. camera_basis.z.x .. "," .. camera_basis.z.y .. "," .. camera_basis.z.z .. ")")
        end
    end

    -- Logging for verification
    local aircraft_to_camera = {
        x = camera_pos.x - aircraft_pos.x,
        y = camera_pos.y - aircraft_pos.y,
        z = camera_pos.z - aircraft_pos.z
    }
    local mag = magnitude(aircraft_to_camera)
    local dot_product = dot(camera_y, aircraft_up_global_vec)

    if enableLogging then
        logToTrackLog("INFO", "CameraModes: setWeldedWingCamera: Camera Position: x=" .. camera_pos.x .. 
                      ", y=" .. camera_pos.y .. ", z=" .. camera_pos.z)
        logToTrackLog("INFO", "CameraModes: setWeldedWingCamera: Camera Basis Vectors: x=(" .. camera_basis.x.x .. "," .. camera_basis.x.y .. "," .. camera_basis.x.z .. 
                      "), y=(" .. camera_basis.y.x .. "," .. camera_basis.y.y .. "," .. camera_basis.y.z .. 
                      "), z=(" .. camera_basis.z.x .. "," .. camera_basis.z.y .. "," .. camera_basis.z.z .. ")")
        logToTrackLog("INFO", "CameraModes: setWeldedWingCamera: Aircraft-to-Camera Vector: (" .. aircraft_to_camera.x .. "," .. aircraft_to_camera.y .. "," .. aircraft_to_camera.z .. ")")
        logToTrackLog("INFO", "CameraModes: setWeldedWingCamera: Magnitude of Aircraft-to-Camera Vector: " .. mag)
        logToTrackLog("INFO", "CameraModes: setWeldedWingCamera: Camera Up Vector: (" .. camera_basis.y.x .. "," .. camera_basis.y.y .. "," .. camera_basis.y.z .. ")")
        logToTrackLog("INFO", "CameraModes: setWeldedWingCamera: Aircraft Up Vector: (" .. aircraft_up_global_vec.x .. "," .. aircraft_up_global_vec.y .. "," .. aircraft_up_global_vec.z .. ")")
        logToTrackLog("INFO", "CameraModes: setWeldedWingCamera: Dot Product (Camera Up · Aircraft Up): " .. dot_product)
    end

    return {p = camera_pos, x = camera_basis.x, y = camera_basis.y, z = camera_basis.z}
end

if enableLogging then
    logToTrackLog("INFO", "CameraModes.lua (v1.18) loaded successfully with corrected camera orientation.")
end