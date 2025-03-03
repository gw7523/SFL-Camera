-- Camera Dynamics Helper Functions for DCS World
-- Location: C:\Users\hollo\Saved Games\DCS\Scripts\SFL-camera\CameraModes.lua
-- Purpose: Provide functions to define camera modes relative to an aircraft using quaternions.
-- Author: The Strike Fighter League, LLC
-- Date: 03 February 2025
-- Version: 1.8
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

    Changes in Version 1.8 (03 February 2025):
    - Fixed camera position by permuting offset_local to {y, x, -z} before transformation, correcting for DCS coordinate system mismatch.
      - Ensures offset {x=20, y=5, z=2} (20m forward, 5m right, 2m down) positions camera correctly relative to aircraft.
    - Fixed camera orientation in setWeldedWingCamera:
      - Replaced global up vector {0,0,1} with aircraft's up vector in global frame (q_aircraft * {0,0,-1} * q_aircraft^-1).
      - Ensures camera's y-axis (up) aligns with aircraft's up vector, maintaining fixed orientation relative to aircraft's local frame.
    - Added logging for permuted offset and aircraft's global up vector to verify transformations.
    - Updated version to 1.8.
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

-- Local helper function to convert quaternion to basis vectors (retained for other modes)
local function quatToBasis(q)
    local xVec = {
        x = 1 - 2 * (q.y * q.y + q.z * q.z),
        y = 2 * (q.x * q.y + q.w * q.z),
        z = 2 * (q.x * q.z - q.w * q.y)
    }
    local yVec = {
        x = 2 * (q.x * q.y - q.w * q.z),
        y = 1 - 2 * (q.x * q.x + q.z * q.z),
        z = 2 * (q.y * q.z + q.w * q.x)
    }
    local zVec = {
        x = 2 * (q.x * q.z + q.w * q.y),
        y = 2 * (q.y * q.z - q.w * q.x),
        z = 1 - 2 * (q.x * q.x + q.y * q.y)
    }
    return {x = xVec, y = yVec, z = zVec}
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

    -- Permute offset_local to match DCS coordinate system (x=forward->y_global, y=right->x_global, z=down->-z_global)
    local offset_perm = {x = offset_local.y, y = offset_local.x, z = -offset_local.z}
    if enableLogging then
        log.write("CameraModes", log.INFO, "setWeldedWingCamera: Permuted Offset: x=" .. offset_perm.x .. 
                  ", y=" .. offset_perm.y .. ", z=" .. offset_perm.z)
    end

    -- Transform permuted offset from local to global frame
    local offset_quat = {w = 0, x = offset_perm.x, y = offset_perm.y, z = offset_perm.z}
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

    -- Compute aircraft's up vector in global frame (local up is -z)
    local up_local_quat = {w = 0, x = 0, y = 0, z = -1}
    local aircraft_up_global = quatMultiply(quatMultiply(q_aircraft, up_local_quat), quatConjugate(q_aircraft))
    local aircraft_up_global_vec = {x = aircraft_up_global.x, y = aircraft_up_global.y, z = aircraft_up_global.z}
    if enableLogging then
        log.write("CameraModes", log.INFO, "setWeldedWingCamera: Aircraft Up Global: x=" .. aircraft_up_global_vec.x .. 
                  ", y=" .. aircraft_up_global_vec.y .. ", z=" .. aircraft_up_global_vec.z)
    end

    -- Compute camera orientation: z-axis towards aircraft, y-axis aligned with aircraft's up
    local d = {
        x = aircraft_pos.x - camera_pos.x,
        y = aircraft_pos.y - camera_pos.y,
        z = aircraft_pos.z - camera_pos.z
    }
    local len = math.sqrt(d.x^2 + d.y^2 + d.z^2)
    if len < 1e-6 then len = 1e-6 end -- Prevent division by zero
    local camera_z = {x = d.x / len, y = d.y / len, z = d.z / len} -- z-axis points to aircraft

    local camera_x = cross(aircraft_up_global_vec, camera_z)
    len = math.sqrt(camera_x.x^2 + camera_x.y^2 + camera_x.z^2)
    if len > 1e-6 then
        camera_x = {x = camera_x.x / len, y = camera_x.y / len, z = camera_x.z / len}
    else
        camera_x = {x = 1, y = 0, z = 0} -- Fallback if parallel
    end
    local camera_y = cross(camera_z, camera_x) -- y-axis aligned with aircraft up, orthogonal to z

    local camera_basis = {x = camera_x, y = camera_y, z = camera_z}

    if enableLogging then
        log.write("CameraModes", log.INFO, "setWeldedWingCamera: Camera Position: x=" .. camera_pos.x .. 
                  ", y=" .. camera_pos.y .. ", z=" .. camera_pos.z)
        log.write("CameraModes", log.INFO, "setWeldedWingCamera: Camera Basis Vectors: x=(" .. camera_basis.x.x .. "," .. camera_basis.x.y .. "," .. camera_basis.x.z .. 
                  "), y=(" .. camera_basis.y.x .. "," .. camera_basis.y.y .. "," .. camera_basis.y.z .. 
                  "), z=(" .. camera_basis.z.x .. "," .. camera_basis.z.y .. "," .. camera_basis.z.z .. ")")
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
    log.write("CameraModes", log.INFO, "CameraModes.lua (v1.8) loaded successfully.")
end