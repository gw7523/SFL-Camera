-- Camera Dynamics Helper Functions for DCS World
-- Location: C:\Users\hollo\Saved Games\DCS\Scripts\SFL-camera\CameraModes.lua
-- Purpose: Provide functions to define camera modes relative to an aircraft using quaternions.
-- Author: The Strike Fighter League, LLC
-- Date: 03 February 2025
-- Version: 1.15
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

    Changes in Version 1.15 (03 February 2025):
    - Orientation Fix: Changed camera up vector (camera_y) to use aircraft's up vector projected onto the plane perpendicular to the look direction, improving stability during maneuvers.
    - Rotation Test: Added optional 90° rotation cycling around x, y, z axes every 5 seconds for orientation debugging (enable with rotationTestEnabled = true).
    - Enhanced Logging: Added mission time stamps and dot product logging to quantify alignment.
    - Updated version to 1.15 from 1.14.
]]

-- Dependency Check
if not quatMultiply or not quatConjugate or not getAircraftData or not aircraftToCamera then
    log.write("CameraModes", log.ERROR, "Required functions from Quaternion.lua not found.")
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

-- Local helper function to project vector u onto plane perpendicular to n
local function projectOntoPlane(u, n)
    local dot_un = u.x * n.x + u.y * n.y + u.z * n.z
    return {
        x = u.x - dot_un * n.x,
        y = u.y - dot_un * n.y,
        z = u.z - dot_un * n.z
    }
end

-- Local helper function to compute dot product
local function dot(u, v)
    return u.x * v.x + u.y * v.y + u.z * v.z
end

-- Rotation Test Configuration
local rotationTestEnabled = true  -- Set to true to enable rotation test for debugging
local rotationInterval = 5        -- Seconds between rotations
local rotationAxes = {"x", "y", "z"}
local currentRotationAxisIndex = 1
local lastRotationTime = 0

-- Welded Wing Camera: Fixed position relative to aircraft, oriented to look at aircraft origin
function setWeldedWingCamera(identifier, offset_local)
    local mission_time = LoGetModelTime()
    if enableLogging then
        log.write("CameraModes", log.INFO, "setWeldedWingCamera called at mission time: " .. tostring(mission_time))
    end

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

    -- Compute direction from camera to aircraft (camera z-axis, backward)
    local d = {
        x = aircraft_pos.x - camera_pos.x,
        y = aircraft_pos.y - camera_pos.y,
        z = aircraft_pos.z - camera_pos.z
    }
    local camera_z = normalize(d) -- z-axis points from camera to aircraft

    -- Project aircraft's up vector onto the plane perpendicular to camera_z
    local projected_up = projectOntoPlane(aircraft_up_global_vec, camera_z)
    local camera_y = normalize(projected_up) -- y-axis aligned with projected aircraft up

    -- Compute camera x-axis (right vector) as cross product of camera_y and camera_z
    local camera_x = cross(camera_y, camera_z)
    camera_x = normalize(camera_x)

    local camera_basis = {x = camera_x, y = camera_y, z = camera_z}

    -- Rotation Test: Apply 90° rotation every 5 seconds if enabled
    if rotationTestEnabled then
        local current_time = os.time()
        if current_time - lastRotationTime >= rotationInterval then
            local axis = rotationAxes[currentRotationAxisIndex]
            local rotation_quat = {w = math.cos(math.pi/4), x = 0, y = 0, z = 0} -- 90° rotation
            if axis == "x" then
                rotation_quat.x = math.sin(math.pi/4)
            elseif axis == "y" then
                rotation_quat.y = math.sin(math.pi/4)
            elseif axis == "z" then
                rotation_quat.z = math.sin(math.pi/4)
            end
            -- Apply rotation to camera basis vectors
            local function rotateVector(v, q)
                local v_quat = {w = 0, x = v.x, y = v.y, z = v.z}
                local result = quatMultiply(quatMultiply(q, v_quat), quatConjugate(q))
                return {x = result.x, y = result.y, z = result.z}
            end
            camera_x = rotateVector(camera_x, rotation_quat)
            camera_y = rotateVector(camera_y, rotation_quat)
            camera_z = rotateVector(camera_z, rotation_quat)
            camera_basis = {x = camera_x, y = camera_y, z = camera_z}
            currentRotationAxisIndex = (currentRotationAxisIndex % #rotationAxes) + 1
            lastRotationTime = current_time
            if enableLogging then
                log.write("CameraModes", log.INFO, "Applied 90° rotation around " .. axis .. " axis at mission time: " .. mission_time)
            end
        end
    end

    -- Compute dot product for alignment check
    local dot_product = dot(camera_y, aircraft_up_global_vec)

    -- Compute vectors for logging
    local aircraft_to_camera = {
        x = camera_pos.x - aircraft_pos.x,
        y = camera_pos.y - aircraft_pos.y,
        z = camera_pos.z - aircraft_pos.z
    }
    local camera_to_aircraft = {
        x = aircraft_pos.x - camera_pos.x,
        y = aircraft_pos.y - camera_pos.y,
        z = aircraft_pos.z - camera_pos.z
    }
    local magnitude_atc = magnitude(aircraft_to_camera)

    if enableLogging then
        log.write("CameraModes", log.INFO, "setWeldedWingCamera: Camera Position: x=" .. camera_pos.x .. 
                  ", y=" .. camera_pos.y .. ", z=" .. camera_pos.z)
        log.write("CameraModes", log.INFO, "setWeldedWingCamera: Camera Basis Vectors: x=(" .. camera_basis.x.x .. "," .. camera_basis.x.y .. "," .. camera_basis.x.z .. 
                  "), y=(" .. camera_basis.y.x .. "," .. camera_basis.y.y .. "," .. camera_basis.y.z .. 
                  "), z=(" .. camera_basis.z.x .. "," .. camera_basis.z.y .. "," .. camera_basis.z.z .. ")")
        log.write("CameraModes", log.INFO, "setWeldedWingCamera: Aircraft-to-Camera Vector: (" .. aircraft_to_camera.x .. "," .. aircraft_to_camera.y .. "," .. aircraft_to_camera.z .. ")")
        log.write("CameraModes", log.INFO, "setWeldedWingCamera: Camera-to-Aircraft Vector: (" .. camera_to_aircraft.x .. "," .. camera_to_aircraft.y .. "," .. camera_to_aircraft.z .. ")")
        log.write("CameraModes", log.INFO, "setWeldedWingCamera: Magnitude of Aircraft-to-Camera Vector: " .. magnitude_atc)
        log.write("CameraModes", log.INFO, "setWeldedWingCamera: Camera Up Vector: (" .. camera_basis.y.x .. "," .. camera_basis.y.y .. "," .. camera_basis.y.z .. ")")
        log.write("CameraModes", log.INFO, "setWeldedWingCamera: Aircraft Up Vector: (" .. aircraft_up_global_vec.x .. "," .. aircraft_up_global_vec.y .. "," .. aircraft_up_global_vec.z .. ")")
        log.write("CameraModes", log.INFO, "setWeldedWingCamera: Dot Product (Camera Up · Aircraft Up): " .. dot_product)
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
    log.write("CameraModes", log.INFO, "CameraModes.lua (v1.15) loaded successfully.")
end