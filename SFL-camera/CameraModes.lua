-- Camera Dynamics Helper Functions for DCS World
-- Location: C:\Users\hollo\Saved Games\DCS\Scripts\SFL-camera\CameraModes.lua
-- Purpose: Provide functions to define camera modes relative to an aircraft using quaternions.
-- Author: The Strike Fighter League, LLC
-- Date: 03 February 2025
-- Version: 1.10
-- Dependencies: Quaternion.lua (must be loaded first by SFL-Camera.lua)

--[[
    Overview:
    - Defines camera modes: welded_wing, independent_rotation, cinematic.
    - Conventions:
      - Aircraft Frame: x=Forward, y=Right, z=Down
      - Camera Frame: x=Right, y=Up, z=Backward
      - Global Frame: x=East, y=North, z=Up
      - Quaternion: {w = scalar, x = i, y = j, z = k}
    - Logging: Errors always logged; Info logged if enableLogging is true.

    Changes in Version 1.10 (03 February 2025):
    - Corrected camera orientation:
      - Set camera z-axis (backward) to point from aircraft to camera, ensuring the camera looks at the aircraft.
      - Aligned camera y-axis (up) with the aircraft's up vector in the global frame.
    - Enhanced logging:
      - Added logs for camera backward vector, up vector, and aircraft-to-camera vector.
      - Computed and logged the magnitude of the aircraft-to-camera vector to verify offset.
    - Updated version to 1.10.
]]

-- Dependency Check
if not quatMultiply or not quatConjugate or not getAircraftData or not aircraftToCamera then
    log.write("CameraModes", log.ERROR, "Required functions from Quaternion.lua (quatMultiply, quatConjugate, getAircraftData, aircraftToCamera) not found.")
    return
else
    if enableLogging then
        log.write("CameraModes", log.INFO, "All required Quaternion.lua functions confirmed available.")
    end
end

-- Local helper function to compute cross product
local function cross(u, v)
    return {
        x = u.y * v.z - u.z * v.y,
        y = u.z * v.x - u.x * v.z,
        z = u.x * v.y - u.y * v.x
    }
end

-- Local helper function to normalize a vector
local function normalize(v)
    local len = math.sqrt(v.x^2 + v.y^2 + v.z^2)
    if len < 1e-6 then return {x=0, y=0, z=0} end -- Avoid division by zero
    return {x = v.x / len, y = v.y / len, z = v.z / len}
end

-- Local helper function to compute vector magnitude
local function magnitude(v)
    return math.sqrt(v.x^2 + v.y^2 + v.z^2)
end

-- Welded Wing Camera: Fixed position relative to aircraft, oriented to look at aircraft origin with up vector aligned to aircraft's up
function setWeldedWingCamera(identifier, offset_local)
    local aircraft_data = getAircraftData(identifier)
    if not aircraft_data then
        log.write("CameraModes", log.ERROR, "Aircraft not found: " .. identifier)
        return nil
    end
    local q_aircraft = aircraft_data.quat
    local aircraft_pos = aircraft_data.pos
    if enableLogging then
        log.write("CameraModes", log.INFO, "setWeldedWingCamera: '" .. identifier .. "' Position: x=" .. aircraft_pos.x .. 
                  ", y=" .. aircraft_pos.y .. ", z=" .. aircraft_pos.z)
        log.write("CameraModes", log.INFO, "setWeldedWingCamera: Local Offset: x=" .. offset_local.x .. 
                  ", y=" .. offset_local.y .. ", z=" .. offset_local.z)
    end

    -- Transform offset from local to global frame
    local offset_quat = {w = 0, x = offset_local.x, y = offset_local.y, z = offset_local.z}
    local offset_global = quatMultiply(quatMultiply(q_aircraft, offset_quat), quatConjugate(q_aircraft))
    local offset_global_vec = {x = offset_global.x, y = offset_global.y, z = offset_global.z}
    if enableLogging then
        log.write("CameraModes", log.INFO, "setWeldedWingCamera: Global Offset: x=" .. offset_global_vec.x .. 
                  ", y=" .. offset_global_vec.y .. ", z=" .. offset_global_vec.z)
    end

    -- Calculate camera position
    local camera_pos = {
        x = aircraft_pos.x + offset_global_vec.x,
        y = aircraft_pos.y + offset_global_vec.y,
        z = aircraft_pos.z + offset_global_vec.z
    }

    -- Compute aircraft's up vector in global frame (local up is -z, since aircraft z is down)
    local up_local_quat = {w = 0, x = 0, y = 0, z = -1}
    local aircraft_up_global = quatMultiply(quatMultiply(q_aircraft, up_local_quat), quatConjugate(q_aircraft))
    local aircraft_up_global_vec = normalize({x = aircraft_up_global.x, y = aircraft_up_global.y, z = aircraft_up_global.z})
    if enableLogging then
        log.write("CameraModes", log.INFO, "setWeldedWingCamera: Aircraft Up Global: x=" .. aircraft_up_global_vec.x .. 
                  ", y=" .. aircraft_up_global_vec.y .. ", z=" .. aircraft_up_global_vec.z)
    end

    -- Compute direction from aircraft to camera (camera z-axis, backward)
    local d = {
        x = camera_pos.x - aircraft_pos.x,
        y = camera_pos.y - aircraft_pos.y,
        z = camera_pos.z - aircraft_pos.z
    }
    local camera_z = normalize(d) -- z-axis points from aircraft to camera

    -- Compute camera x-axis (right vector) as perpendicular to z and aircraft's up
    local camera_x = cross(aircraft_up_global_vec, camera_z)
    camera_x = normalize(camera_x)

    -- Compute camera y-axis (up vector) to ensure orthogonality
    local camera_y = cross(camera_z, camera_x)
    camera_y = normalize(camera_y)

    local camera_basis = {x = camera_x, y = camera_y, z = camera_z}

    -- Compute aircraft-to-camera vector
    local aircraft_to_camera = {
        x = camera_pos.x - aircraft_pos.x,
        y = camera_pos.y - aircraft_pos.y,
        z = camera_pos.z - aircraft_pos.z
    }
    local magnitude_atc = magnitude(aircraft_to_camera)

    if enableLogging then
        log.write("CameraModes", log.INFO, "setWeldedWingCamera: Camera Position: x=" .. camera_pos.x .. 
                  ", y=" .. camera_pos.y .. ", z=" .. camera_pos.z)
        log.write("CameraModes", log.INFO, "setWeldedWingCamera: Camera Basis Vectors: x=(" .. camera_basis.x.x .. "," .. camera_basis.x.y .. "," .. camera_basis.x.z .. 
                  "), y=(" .. camera_basis.y.x .. "," .. camera_basis.y.y .. "," .. camera_basis.y.z .. 
                  "), z=(" .. camera_basis.z.x .. "," .. camera_basis.z.y .. "," .. camera_basis.z.z .. ")")
        log.write("CameraModes", log.INFO, "setWeldedWingCamera: Aircraft-to-Camera Vector: (" .. aircraft_to_camera.x .. "," .. aircraft_to_camera.y .. "," .. aircraft_to_camera.z .. ")")
        log.write("CameraModes", log.INFO, "setWeldedWingCamera: Magnitude of Aircraft-to-Camera Vector: " .. magnitude_atc)
        log.write("CameraModes", log.INFO, "setWeldedWingCamera: Camera Backward Vector: (" .. camera_basis.z.x .. "," .. camera_basis.z.y .. "," .. camera_basis.z.z .. ")")
        log.write("CameraModes", log.INFO, "setWeldedWingCamera: Camera Up Vector: (" .. camera_basis.y.x .. "," .. camera_basis.y.y .. "," .. camera_basis.y.z .. ")")
    end

    return {p = camera_pos, x = camera_basis.x, y = camera_basis.y, z = camera_basis.z}
end

-- Independent Rotation Camera: Fixed position with independent orientation
function setIndependentRotationCamera(identifier, offset_local, q_camera_global)
    local aircraft_data = getAircraftData(identifier)
    if not aircraft_data then
        log.write("CameraModes", log.ERROR, "Aircraft not found: " .. identifier)
        return nil
    end
    local q_aircraft = aircraft_data.quat
    local aircraft_pos = aircraft_data.pos
    if enableLogging then
        log.write("CameraModes", log.INFO, "setIndependentRotationCamera: '" .. identifier .. "' Position: x=" .. aircraft_pos.x .. 
                  ", y=" .. aircraft_pos.y .. ", z=" .. aircraft_pos.z)
    end

    local offset_quat = {w = 0, x = offset_local.x, y = offset_local.y, z = offset_local.z}
    local offset_global = quatMultiply(quatMultiply(q_aircraft, offset_quat), quatConjugate(q_aircraft))
    local offset_global_vec = {x = offset_global.x, y = offset_global.y, z = offset_global.z}

    local camera_pos = {
        x = aircraft_pos.x + offset_global_vec.x,
        y = aircraft_pos.y + offset_global_vec.y,
        z = aircraft_pos.z + offset_global_vec.z
    }

    local camera_basis = quatToBasis(q_camera_global)
    return {p = camera_pos, x = camera_basis.x, y = camera_basis.y, z = camera_basis.z}
end

-- Rotating/Cinematic Camera: Orbits aircraft on an ellipsoid
function setRotatingCinematicCamera(identifier, a, b, c, theta0, phi0, dtheta_dt, dphi_dt, start_time)
    local function normalize(v)
        local len = math.sqrt(v.x^2 + v.y^2 + v.z^2)
        if len == 0 then return v end
        return {x = v.x / len, y = v.y / len, z = v.z / len}
    end
    local function dot(u, v)
        return u.x * v.x + u.y * v.y + u.z * v.z
    end

    local aircraft_data = getAircraftData(identifier)
    if not aircraft_data then
        log.write("CameraModes", log.ERROR, "Aircraft not found: " .. identifier)
        return nil
    end
    local aircraft_pos = aircraft_data.pos

    local t = os.time() - start_time
    local theta = theta0 + dtheta_dt * t
    local phi = phi0 + dphi_dt * t

    local pos_rel = {
        x = a * math.sin(theta) * math.cos(phi),
        y = b * math.sin(theta) * math.sin(phi),
        z = c * math.cos(theta)
    }
    local camera_pos = {
        x = aircraft_pos.x + pos_rel.x,
        y = aircraft_pos.y + pos_rel.y,
        z = aircraft_pos.z + pos_rel.z
    }

    local dir = {x = aircraft_pos.x - camera_pos.x, y = aircraft_pos.y - camera_pos.y, z = aircraft_pos.z - camera_pos.z}
    local camera_z = normalize({x = -dir.x, y = -dir.y, z = -dir.z})
    local up = {x = 0, y = 0, z = 1}
    local up_dot_z = dot(up, camera_z)
    if math.abs(up_dot_z) > 0.99 then
        up = {x = 0, y = 1, z = 0}
    end
    local camera_y = normalize({x = up.x - up_dot_z * camera_z.x, y = up.y - up_dot_z * camera_z.y, z = up.z - up_dot_z * camera_z.z})
    local camera_x = cross(camera_y, camera_z)

    return {p = camera_pos, x = camera_x, y = camera_y, z = camera_z}
end

if enableLogging then
    log.write("CameraModes", log.INFO, "CameraModes.lua (v1.10) loaded successfully.")
end