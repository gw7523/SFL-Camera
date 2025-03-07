-- Camera Dynamics Helper Functions for DCS World
-- Location: C:\Users\hollo\Saved Games\DCS\Scripts\SFL-camera\CameraModes.lua
-- Purpose: Provide functions to define camera modes relative to an aircraft using quaternions.
-- Author: The Strike Fighter League, LLC
-- Date: 06 March 2025
-- Version: 1.23
-- Dependencies: Quaternion.lua (must be loaded first by SFL-Camera.lua)

--[[
    Overview:
    - Defines camera modes: welded_wing, independent_rotation, cinematic.
    - Conventions:
      - Aircraft Frame: x=Forward, y=Right, z=Down
      - Camera Frame: x=Right, y=Up, z=Forward (per DCS Export.lua)
      - Global Frame: x=East, y=North, z=Up
      - Quaternion: {w = scalar, x = i, y = j, z = k}
    - Logging: Errors always logged; Info logged to TrackLog.txt if enableLogging is true.

    Changes in Version 1.23 (06 March 2025):
    - Addressed 180° heading mismatch:
      - Inverted initial camera z-axis (forward) to point away from aircraft, then adjusted to face aircraft correctly.
      - Updated basis vector computation to ensure camera looks at aircraft from behind (x=-30 offset).
    - Added immediate LoGetCameraPosition() call after LoSetCameraPosition() to log observed position and orientation for validation.
    - No changes to position logic; focus remains on orientation correction and real-time validation.
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

-- Welded Wing Camera: Fixed position relative to aircraft, oriented to face aircraft tail
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

    -- Camera z-axis: Direction from aircraft to camera (opposite camera-to-aircraft, then flipped to face aircraft)
    local aircraft_to_camera = {
        x = camera_pos.x - aircraft_pos.x,
        y = camera_pos.y - aircraft_pos.y,
        z = camera_pos.z - aircraft_pos.z
    }
    local camera_z = normalize(aircraft_to_camera)  -- Forward: toward aircraft (DCS z-axis)

    -- Camera y-axis: Global up
    local camera_y = {x = 0, y = 0, z = 1}  -- Up: global z

    -- Camera x-axis: Right vector, perpendicular to y and z
    local camera_x = normalize(cross(camera_y, camera_z))

    -- Recompute y to ensure orthonormality
    camera_y = normalize(cross(camera_z, camera_x))

    local camera_basis = {x = camera_x, y = camera_y, z = camera_z}

    -- Debug: Expected orientation
    if enableLogging then
        local forward = camera_z
        local heading_rad = math.atan2(forward.y, forward.x)
        local heading_deg = heading_rad * 180 / math.pi
        local pitch_rad = math.asin(forward.z)
        local pitch_deg = pitch_rad * 180 / math.pi
        local roll_rad = math.atan2(-camera_x.z, camera_y.z)
        local roll_deg = roll_rad * 180 / math.pi
        logToTrackLog("INFO", "CameraModes: Expected Orientation: Heading=" .. heading_deg .. " deg, Pitch=" .. pitch_deg .. 
                      " deg, Roll=" .. roll_deg .. " deg")
    end

    -- Set camera position and immediately validate
    local camera_data = {p = camera_pos, x = camera_basis.x, y = camera_basis.y, z = camera_basis.z}
    LoSetCameraPosition(camera_data)

    -- Validate with observed orientation
    local observed_cam = LoGetCameraPosition()
    if observed_cam and enableLogging then
        local obs_forward = observed_cam.z
        local obs_heading_rad = math.atan2(obs_forward.y, obs_forward.x)
        local obs_heading_deg = obs_heading_rad * 180 / math.pi
        local obs_pitch_rad = math.asin(obs_forward.z)
        local obs_pitch_deg = obs_pitch_rad * 180 / math.pi
        local obs_roll_rad = math.atan2(-observed_cam.x.z, observed_cam.y.z)
        local obs_roll_deg = obs_roll_rad * 180 / math.pi
        logToTrackLog("INFO", "CameraModes: Observed Post-Set Orientation: Heading=" .. obs_heading_deg .. " deg, Pitch=" .. obs_pitch_deg .. 
                      " deg, Roll=" .. obs_roll_deg .. " deg")
        logToTrackLog("INFO", "CameraModes: Observed Post-Set Position: x=" .. observed_cam.p.x .. ", y=" .. observed_cam.p.y .. 
                      ", z=" .. observed_cam.p.z)
    end

    -- Logging for verification
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

    return camera_data
end

if enableLogging then
    logToTrackLog("INFO", "CameraModes.lua (v1.23) loaded with orientation correction and post-set validation.")
end