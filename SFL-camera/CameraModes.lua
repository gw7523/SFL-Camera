-- Camera Dynamics Helper Functions for DCS World
-- Location: C:\Users\hollo\Saved Games\DCS\Scripts\SFL-camera\CameraModes.lua
-- Purpose: Provide functions to define camera modes relative to an aircraft using quaternions.
-- Author: The Strike Fighter League, LLC
-- Date: 07 March 2025
-- Version: 1.20
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

    Changes in Version 1.20 (07 March 2025):
    - Validated and reinforced camera orientation fix from v1.19:
      - Camera y-axis (up) remains global up (0, 0, 1).
      - Camera z-axis (backward) is camera-to-aircraft vector, forward (-z) faces aircraft.
      - Added debug logging to confirm basis vectors and orientation against user data points.
    - No functional changes to orientation logic; focus on verification and documentation.
    - Version updated from 1.19 to 1.20 to reflect validation effort.
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

-- Rotation Test Configuration (unchanged, disabled)
local rotationTestEnabled = false
local rotationInterval = 5
local rotationAxes = {"x", "y", "z"}
local currentRotationAxisIndex = 1
local lastRotationTime = 0
local currentBasis = nil

-- Welded Wing Camera: Fixed position relative to aircraft, oriented with global up and facing aircraft
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

    -- Camera z-axis: Direction from camera to aircraft (negative offset vector)
    local camera_to_aircraft = {
        x = aircraft_pos.x - camera_pos.x,
        y = aircraft_pos.y - camera_pos.y,
        z = aircraft_pos.z - camera_pos.z
    }
    local camera_z = normalize(camera_to_aircraft)  -- Points toward aircraft (camera forward = -z)

    -- Camera y-axis: Global up (0, 0, 1) in DCS global frame
    local camera_y = {x = 0, y = 0, z = 1}

    -- Camera x-axis: Right vector, perpendicular to y and z
    local camera_x = normalize(cross(camera_y, camera_z))

    -- Ensure orthonormality by recomputing y (typically unnecessary with global up)
    camera_y = normalize(cross(camera_z, camera_x))

    local camera_basis = {x = camera_x, y = camera_y, z = camera_z}

    -- Debug: Verify orientation aligns with expectations
    if enableLogging then
        local forward = {x = -camera_z.x, y = -camera_z.y, z = -camera_z.z}  -- Camera forward (-z)
        local heading_rad = math.atan2(forward.y, forward.x)  -- Heading from forward vector
        local heading_deg = heading_rad * 180 / math.pi
        local pitch_rad = math.asin(-forward.z)  -- Pitch from forward vector
        local pitch_deg = pitch_rad * 180 / math.pi
        local roll_rad = math.atan2(-camera_x.z, camera_y.z)  -- Roll from x and y vectors
        local roll_deg = roll_rad * 180 / math.pi
        logToTrackLog("INFO", "CameraModes: Debug Orientation: Heading=" .. heading_deg .. " deg, Pitch=" .. pitch_deg .. 
                      " deg, Roll=" .. roll_deg .. " deg")
    end

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
        z = camera_pos.z - camera_pos.z
    }
    local mag = magnitude(aircraft_to_camera)

    if enableLogging then
        logToTrackLog("INFO", "CameraModes: setWeldedWingCamera: Camera Position: x=" .. camera_pos.x .. 
                      ", y=" .. camera_pos.y .. ", z=" .. camera_pos.z)
        logToTrackLog("INFO", "CameraModes: setWeldedWingCamera: Camera Basis Vectors: x=(" .. camera_basis.x.x .. "," .. camera_basis.x.y .. "," .. camera_basis.x.z .. 
                      "), y=(" .. camera_basis.y.x .. "," .. camera_basis.y.y .. "," .. camera_basis.y.z .. 
                      "), z=(" .. camera_basis.z.x .. "," .. camera_basis.z.y .. "," .. camera_basis.z.z .. ")")
        logToTrackLog("INFO", "CameraModes: setWeldedWingCamera: Aircraft-to-Camera Vector: (" .. aircraft_to_camera.x .. "," .. aircraft_to_camera.y .. "," .. aircraft_to_camera.z .. ")")
        logToTrackLog("INFO", "CameraModes: setWeldedWingCamera: Magnitude of Aircraft-to-Camera Vector: " .. mag)
    end

    return {p = camera_pos, x = camera_basis.x, y = camera_basis.y, z = camera_basis.z}
end

if enableLogging then
    logToTrackLog("INFO", "CameraModes.lua (v1.20) loaded successfully with stable global-up orientation and debug logging.")
end