-- Camera Dynamics Helper Functions for DCS World
-- Location: C:\Users\hollo\Saved Games\DCS\Scripts\SFL-camera\CameraModes.lua
-- Purpose: Provide functions to define camera modes (welded_wing, independent_rotation, cinematic) relative to an aircraft using quaternions.
-- Author: The Strike Fighter League, LLC
-- Date: 03 March 2025
-- Version: 1.5
-- Dependencies: Quaternion.lua (must be loaded before this script by SFL-Camera.lua)

--[[
    Overview:
    - Defines three camera modes originally from Camera.lua.
    - applyCameraConfig() moved to SFL-Camera.lua.
    - Conventions:
      - Aircraft Frame: x=Forward, y=Right, z=Down
      - Camera Frame: x=Right, y=Up, z=Backward
      - Global Frame: x=East, y=North, z=Up
      - Quaternion: {w = scalar, x = i, y = j, z = k}
    - Logging: Errors always logged; Warnings logged if enableLogging is true (set in SFL-Camera.lua).

    Changes in Version 1.5:
    - Added logging for aircraft quaternion in setWeldedWingCamera to verify fallback orientation.
    - Incremented version and enhanced comments.

    Usage:
    - Loaded by SFL-Camera.lua via dofile().
    - Functions called by applyCameraConfig() based on Camera-cfg.lua mode.
]]

-- Dependency Check
if not quatMultiply or not quatConjugate or not getAircraftData or not aircraftToCamera then
    log.write("CameraModes", log.ERROR, "Required functions from Quaternion.lua (quatMultiply, quatConjugate, getAircraftData, aircraftToCamera) not found.")
    return
end

-- Local helper function to convert quaternion to basis vectors
-- @param q table: Quaternion {w, x, y, z}
-- @return table: Basis vectors {x={x,y,z}, y={x,y,z}, z={x,y,z}}
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

-- ### Class A: "Welded Wing" Camera ###
-- Fixed position and orientation relative to aircraft
-- @param identifier string: Aircraft identifier (unit name)
-- @param offset_local table: {x, y, z} offset in aircraft frame (meters)
-- @return table: Camera data {p, x, y, z} for LoSetCameraPosition, or nil if aircraft not found
function setWeldedWingCamera(identifier, offset_local)
    local aircraft_data = getAircraftData(identifier)
    if not aircraft_data then
        log.write("CameraModes", log.ERROR, "Aircraft not found: " .. identifier)
        return nil
    end
    local q_aircraft = aircraft_data.quat   -- Aircraft orientation
    local aircraft_pos = aircraft_data.pos   -- Aircraft position
    if enableLogging then
        log.write("CameraModes", log.INFO, "Welded Wing - Aircraft Quaternion: w=" .. q_aircraft.w .. 
                  ", x=" .. q_aircraft.x .. ", y=" .. q_aircraft.y .. ", z=" .. q_aircraft.z)
        log.write("CameraModes", log.INFO, "Welded Wing - Aircraft Position: x=" .. aircraft_pos.x .. ", y=" .. aircraft_pos.y .. ", z=" .. aircraft_pos.z)
    end

    -- Transform offset from local aircraft frame to global frame
    local offset_quat = {w = 0, x = offset_local.x, y = offset_local.y, z = offset_local.z}
    local offset_global = quatMultiply(quatMultiply(q_aircraft, offset_quat), quatConjugate(q_aircraft))
    local offset_global_vec = {x = offset_global.x, y = offset_global.y, z = offset_global.z}

    -- Calculate camera position in global coordinates
    local camera_pos = {
        x = aircraft_pos.x + offset_global_vec.x,
        y = aircraft_pos.y + offset_global_vec.y,
        z = aircraft_pos.z + offset_global_vec.z
    }

    -- Set camera orientation aligned with aircraft, converted to camera frame
    local q_camera = aircraftToCamera(q_aircraft)
    local camera_basis = quatToBasis(q_camera)
    if enableLogging then
        log.write("CameraModes", log.INFO, "Welded Wing - Camera Quaternion: w=" .. q_camera.w .. 
                  ", x=" .. q_camera.x .. ", y=" .. q_camera.y .. ", z=" .. q_camera.z)
        log.write("CameraModes", log.INFO, "Welded Wing - Camera Basis Vectors: x=(" .. camera_basis.x.x .. "," .. camera_basis.x.y .. "," .. camera_basis.x.z .. 
                  "), y=(" .. camera_basis.y.x .. "," .. camera_basis.y.y .. "," .. camera_basis.y.z .. 
                  "), z=(" .. camera_basis.z.x .. "," .. camera_basis.z.y .. "," .. camera_basis.z.z .. ")")
    end

    return {p = camera_pos, x = camera_basis.x, y = camera_basis.y, z = camera_basis.z}
end

-- ### Class B: "Welded Wing with Independent Camera Rotation" ###
-- Fixed position with independent global orientation
-- @param identifier string: Aircraft identifier (unit name)
-- @param offset_local table: {x, y, z} offset in aircraft frame (meters)
-- @param q_camera_global table: Quaternion for camera orientation in global frame
-- @return table: Camera data {p, x, y, z}, or nil if aircraft not found
function setIndependentRotationCamera(identifier, offset_local, q_camera_global)
    local aircraft_data = getAircraftData(identifier)
    if not aircraft_data then
        log.write("CameraModes", log.ERROR, "Aircraft not found: " .. identifier)
        return nil
    end
    local q_aircraft = aircraft_data.quat   -- Aircraft orientation
    local aircraft_pos = aircraft_data.pos   -- Aircraft position
    if enableLogging then
        log.write("CameraModes", log.INFO, "Independent Rotation - Aircraft Position: x=" .. aircraft_pos.x .. ", y=" .. aircraft_pos.y .. ", z=" .. aircraft_pos.z)
    end

    -- Transform offset from local aircraft frame to global frame
    local offset_quat = {w = 0, x = offset_local.x, y = offset_local.y, z = offset_local.z}
    local offset_global = quatMultiply(quatMultiply(q_aircraft, offset_quat), quatConjugate(q_aircraft))
    local offset_global_vec = {x = offset_global.x, y = offset_global.y, z = offset_global.z}

    -- Calculate camera position in global coordinates
    local camera_pos = {
        x = aircraft_pos.x + offset_global_vec.x,
        y = aircraft_pos.y + offset_global_vec.y,
        z = aircraft_pos.z + offset_global_vec.z
    }

    -- Use provided global camera orientation
    local camera_basis = quatToBasis(q_camera_global)
    if enableLogging then
        log.write("CameraModes", log.INFO, "Independent Rotation - Camera Basis Vectors: x=(" .. camera_basis.x.x .. "," .. camera_basis.x.y .. "," .. camera_basis.x.z .. 
                  "), y=(" .. camera_basis.y.x .. "," .. camera_basis.y.y .. "," .. camera_basis.y.z .. 
                  "), z=(" .. camera_basis.z.x .. "," .. camera_basis.z.y .. "," .. camera_basis.z.z .. ")")
    end

    return {p = camera_pos, x = camera_basis.x, y = camera_basis.y, z = camera_basis.z}
end

-- ### Class C: "Rotating/Cinematic" Camera ###
-- Orbits aircraft on an ellipsoid, always looking at it
-- @param identifier string: Aircraft identifier (unit name)
-- @param a number: X-axis semi-axis (meters)
-- @param b number: Y-axis semi-axis (meters)
-- @param c number: Z-axis semi-axis (meters)
-- @param theta0 number: Initial theta angle (radians)
-- @param phi0 number: Initial phi angle (radians)
-- @param dtheta_dt number: Theta angular rate (radians/second)
-- @param dphi_dt number: Phi angular rate (radians/second)
-- @param start_time number: Start time (seconds)
-- @return table: Camera data {p, x, y, z}, or nil if aircraft not found
function setRotatingCinematicCamera(identifier, a, b, c, theta0, phi0, dtheta_dt, dphi_dt, start_time)
    -- Helper functions for vector operations
    local function normalize(v)
        local len = math.sqrt(v.x^2 + v.y^2 + v.z^2)
        if len == 0 then return v end
        return {x = v.x / len, y = v.y / len, z = v.z / len}
    end
    local function dot(u, v)
        return u.x * v.x + u.y * v.y + u.z * v.z
    end
    local function cross(u, v)
        return {
            x = u.y * v.z - u.z * v.y,
            y = u.z * v.x - u.x * v.z,
            z = u.x * v.y - u.y * v.x
        }
    end

    -- Get aircraft position
    local aircraft_data = getAircraftData(identifier)
    if not aircraft_data then
        log.write("CameraModes", log.ERROR, "Aircraft not found: " .. identifier)
        return nil
    end
    local aircraft_pos = aircraft_data.pos
    if enableLogging then
        log.write("CameraModes", log.INFO, "Cinematic - Aircraft Position: x=" .. aircraft_pos.x .. ", y=" .. aircraft_pos.y .. ", z=" .. aircraft_pos.z)
    end

    -- Calculate camera position on ellipsoid orbit
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

    -- Orient camera to look at aircraft
    local dir = {x = aircraft_pos.x - camera_pos.x, y = aircraft_pos.y - camera_pos.y, z = aircraft_pos.z - camera_pos.z}
    local camera_z = normalize({x = -dir.x, y = -dir.y, z = -dir.z}) -- Z-axis points toward aircraft
    local up = {x = 0, y = 0, z = 1}                                  -- Default up vector
    local up_dot_z = dot(up, camera_z)
    if math.abs(up_dot_z) > 0.99 then
        up = {x = 0, y = 1, z = 0}                                    -- Adjust up vector if too aligned with z
    end
    local camera_y = normalize({x = up.x - up_dot_z * camera_z.x, y = up.y - up_dot_z * camera_z.y, z = up.z - up_dot_z * camera_z.z})
    local camera_x = cross(camera_y, camera_z)

    local camera_basis = {x = camera_x, y = camera_y, z = camera_z}
    if enableLogging then
        log.write("CameraModes", log.INFO, "Cinematic - Camera Basis Vectors: x=(" .. camera_basis.x.x .. "," .. camera_basis.x.y .. "," .. camera_basis.x.z .. 
                  "), y=(" .. camera_basis.y.x .. "," .. camera_basis.y.y .. "," .. camera_basis.y.z .. 
                  "), z=(" .. camera_basis.z.x .. "," .. camera_basis.z.y .. "," .. camera_basis.z.z .. ")")
    end

    return {p = camera_pos, x = camera_basis.x, y = camera_basis.y, z = camera_basis.z}
end