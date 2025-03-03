-- observerCamera.lua
-- Version 2.9 | Timestamp: 2024-11-10 12:00:00
-- Main script for controlling the observer camera in DCS World to track "Hornet" group

-- Adjust Lua search path to include user scripts directory
local lfs = require('lfs')
local userScriptsPath = lfs.writedir() .. "Scripts\\?.lua"
package.path = package.path .. ";" .. userScriptsPath

-- Load DCS libraries with logging
log.write("ObserverCamera", log.INFO, "Attempting to load Vector")
local Vector = require('Vector')
log.write("ObserverCamera", log.INFO, "Vector loaded successfully, type: " .. type(Vector))

-- Validate that Vector is a table
if type(Vector) ~= "table" then
    log.write("ObserverCamera", log.ERROR, "Vector is not a table, cannot proceed.")
    return
end

log.write("ObserverCamera", log.INFO, "Attempting to load Matrix33")
local Matrix33 = require('Matrix33')
log.write("ObserverCamera", log.INFO, "Matrix33 loaded successfully, type: " .. type(Matrix33))

-- Validate that Matrix33 is a table
if type(Matrix33) ~= "table" then
    log.write("ObserverCamera", log.ERROR, "Matrix33 is not a table, cannot proceed.")
    return
end

-- Logging settings
local LogEnabled = true  -- Set to false to disable logging
local lastLogTime = 0
local logInterval = 1  -- seconds

-- Initialize logging
if LogEnabled then
    log.write("ObserverCamera", log.INFO, "ObserverCamera script loaded")
end

-- Load the configuration file
local configPath = lfs.writedir() .. "Scripts/observerConfig.lua"
dofile(configPath)

-- Configuration ID for this instance
local myConfig = "Hornet-Config_1"  -- Must match a key in observerConfig.lua
local cfg = observerConfig[myConfig]
if not cfg then
    log.write("ObserverCamera", log.ERROR, "Invalid configuration ID: " .. myConfig)
    return
end
if LogEnabled then
    log.write("ObserverCamera", log.INFO, "Valid configuration ID: " .. myConfig)
end

-- Ensure the tracked group is "Hornet"
cfg.trackUnit = "Hornet"

-- Variable to store the unit's ID
local unitId = nil

-- Function to find the "Hornet" group
local function findUnit()
    log.write("ObserverCamera", log.INFO, "findUnit function called")
    local objects = LoGetWorldObjects()
    local groupNames = {}
    for id, obj in pairs(objects) do
        if obj.GroupName then
            groupNames[#groupNames + 1] = obj.GroupName
            if obj.GroupName == cfg.trackUnit then
                log.write("ObserverCamera", log.INFO, "Found unit by GroupName: " .. obj.GroupName .. " with ID: " .. id)
                return id
            end
        end
    end
    log.write("ObserverCamera", log.WARNING, "Group 'Hornet' not found. Available groups: " .. table.concat(groupNames, ", "))
    return nil
end

-- Fallback function for vector transformation using dot notation
local function TransformVector(matrix, vector)
    return Vector(
        matrix.x.x * vector.x + matrix.x.y * vector.y + matrix.x.z * vector.z,
        matrix.y.x * vector.x + matrix.y.y * vector.y + matrix.y.z * vector.z,
        matrix.z.x * vector.x + matrix.z.y * vector.y + matrix.z.z * vector.z
    )
end

-- Function to update the camera position
function updateCamera()
    local currentTime = LoGetModelTime()
    local shouldLog = LogEnabled and (currentTime - lastLogTime >= logInterval)
    if shouldLog then
        lastLogTime = currentTime
        log.write("ObserverCamera", log.INFO, "updateCamera started")
    end
    
    -- Locate the unit if not already tracked
    if not unitId then
        unitId = findUnit()
        if not unitId then
            if shouldLog then
                log.write("ObserverCamera", log.WARNING, "Waiting for group 'Hornet' to appear")
            end
            return
        end
    end

    -- Get the unit's data
    local obj = LoGetObjectById(unitId)
    if not obj then
        if shouldLog then
            log.write("ObserverCamera", log.WARNING, "Unit from group 'Hornet' lost, resetting unitId")
        end
        unitId = nil
        return
    end

    -- Unit position as Vector
    local pos = Vector(obj.Position.x, obj.Position.y, obj.Position.z)

    -- Unit orientation (in radians)
    local heading = obj.Heading or 0
    local pitch = obj.Pitch or 0
    local bank = obj.Bank or 0

    -- Log orientation in degrees for readability
    if shouldLog then
        local headingDeg = math.deg(heading)
        local pitchDeg = math.deg(pitch)
        local bankDeg = math.deg(bank)
        log.write("ObserverCamera", log.INFO, "Hornet orientation: heading=" .. headingDeg .. ", pitch=" .. pitchDeg .. ", bank=" .. bankDeg)
    end

    -- Camera position relative to Hornet (from config or defaults)
    local relPos = cfg.relPos or {dx = 40, dy = 0, dz = 0}  -- In front of aircraft
    local localOffset = Vector(relPos.dx, relPos.dy, relPos.dz)

    -- Check for behavior "a"
    if cfg.behavior == "a" then
        -- Build rotation matrix using Matrix33
        local rotMatrix = Matrix33()
        rotMatrix:RotateY(heading)
        rotMatrix:RotateZ(pitch)
        rotMatrix:RotateX(bank)

        -- Transform local offset to global coordinates using fallback
        local globalOffset = TransformVector(rotMatrix, localOffset)

        -- Compute camera position
        local cameraP = pos + globalOffset

        -- Compute forward vector: direction from camera to aircraft
        local dirToAircraft = pos - cameraP
        local forward = dirToAircraft:ort()

        -- Use global up vector for stability, then adjust
        local globalUp = Vector(0, 1, 0)
        local right = globalUp ^ forward
        if right:length() < 1e-6 then
            right = Vector(1, 0, 0)  -- Fallback if forward aligns with global up
        else
            right = right:ort()
        end
        local up = forward ^ right
        up = up:ort()

        -- Define camera orientation
        local cameraOrient = {
            x = right,    -- Right vector
            y = up,       -- Up vector
            z = forward   -- Forward vector (looking at aircraft)
        }

        -- Set camera position and orientation
        local cameraPos = {
            p = {x = cameraP.x, y = cameraP.y, z = cameraP.z},
            x = {x = cameraOrient.x.x, y = cameraOrient.x.y, z = cameraOrient.x.z},  -- Right
            y = {x = cameraOrient.y.x, y = cameraOrient.y.y, z = cameraOrient.y.z},  -- Up
            z = {x = cameraOrient.z.x, y = cameraOrient.z.y, z = cameraOrient.z.z}   -- Forward
        }
        LoSetCameraPosition(cameraPos)

        -- Enhanced logging
        if shouldLog then
            local aircraftForward = TransformVector(rotMatrix, Vector(1, 0, 0))
            local logMsg = string.format(
                "CameraPos: %.2f,%.2f,%.2f | Forward: %.4f,%.4f,%.4f | Up: %.4f,%.4f,%.4f",
                cameraP.x, cameraP.y, cameraP.z,
                forward.x, forward.y, forward.z,
                up.x, up.y, up.z
            )
            log.write("ObserverCamera", log.INFO, logMsg)
            -- Log aircraft position for verification
            log.write("ObserverCamera", log.INFO, "AircraftPos: " .. pos.x .. "," .. pos.y .. "," .. pos.z)
        end
    else
        -- Simplified behavior (existing code remains unchanged)
        local orientX = {x = math.cos(heading), y = 0, z = math.sin(heading)}
        local orientY = {x = 0, y = 1, z = 0}
        local orientZ = {x = -math.sin(heading), y = 0, z = math.cos(heading)}

        local cameraP = {
            x = pos.x + relPos.dx * orientX.x + relPos.dy * orientY.x + relPos.dz * orientZ.x,
            y = pos.y + relPos.dx * orientX.y + relPos.dy * orientY.y + relPos.dz * orientZ.y,
            z = pos.z + relPos.dx * orientX.z + relPos.dy * orientY.z + relPos.dz * orientZ.z,
        }

        local cameraPos = {
            p = cameraP,
            x = orientX,
            y = orientY,
            z = orientZ
        }
        LoSetCameraPosition(cameraPos)

        if shouldLog then
            log.write("ObserverCamera", log.INFO, "Camera set to: x=" .. cameraP.x .. ", y=" .. cameraP.y .. ", z=" .. cameraP.z)
        end
    end
end