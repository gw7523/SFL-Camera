-- CameraModes.lua
-- Version: 1.1
-- Date: 2025-03-06
-- Purpose: Implement camera-specific functionality for SFL-Camera project
-- Author: AI Assistant, based on user specifications
-- Changes: v1.1 - Moved target unit identification to init, updated LoSetCameraPosition to use Euler angles

CameraModeA = {
    name = "Welded Wing",
    targetUnit = nil, -- Store the target unit here during init
    init = function(self)
        -- Identify the target unit "SFL-Pilot-1" once during initialization
        local allUnits = LoGetAllUnits()
        for _, unit in pairs(allUnits) do
            if unit.Name == CameraConfig.targetUnitName then
                self.targetUnit = unit
                log.write("SFL-Camera", log.INFO, "Welded Wing mode initialized, target unit " .. CameraConfig.targetUnitName .. " found")
                break
            end
        end
        if not self.targetUnit then
            log.write("SFL-Camera", log.ERROR, "Could not find unit " .. CameraConfig.targetUnitName .. " during initialization")
        end
    end,
    update = function(self)
        -- Use the cached target unit
        local targetUnit = self.targetUnit
        if not targetUnit then
            log.write("SFL-Camera", log.ERROR, "No target unit available for tracking")
            return
        end

        -- Get unit position (assuming Position is available; adjust based on DCS API)
        local P_a = targetUnit.Position or {x = 0, y = 0, z = 0}
        if not P_a.x then
            log.write("SFL-Camera", log.ERROR, "Position data unavailable for " .. CameraConfig.targetUnitName)
            return
        end

        -- Get unit orientation (assuming Attitude provides heading, pitch, roll in radians)
        local heading = targetUnit.Attitude and targetUnit.Attitude.heading or 0
        local pitch = targetUnit.Attitude and targetUnit.Attitude.pitch or 0
        local roll = targetUnit.Attitude and targetUnit.Attitude.roll or 0

        -- Calculate rotation matrix from Euler angles (Z-Y-X convention) for position offset
        local cosH, sinH = math.cos(heading), math.sin(heading)
        local cosP, sinP = math.cos(pitch), math.sin(pitch)
        local cosR, sinR = math.cos(roll), math.sin(roll)

        local R_a = {
            {cosH*cosP, cosH*sinP*sinR - sinH*cosR, cosH*sinP*cosR + sinH*sinR},
            {sinH*cosP, sinH*sinP*sinR + cosH*cosR, sinH*sinP*cosR - cosH*sinR},
            {-sinP,     cosP*sinR,                  cosP*cosR}
        }

        -- Transform offset from local to world coordinates
        local offset = CameraConfig.offset
        local offset_world = {
            R_a[1][1]*offset.x + R_a[1][2]*offset.y + R_a[1][3]*offset.z,
            R_a[2][1]*offset.x + R_a[2][2]*offset.y + R_a[2][3]*offset.z,
            R_a[3][1]*offset.x + R_a[3][2]*offset.y + R_a[3][3]*offset.z
        }

        -- Calculate camera position
        local P_c = {
            x = P_a.x + offset_world[1],
            y = P_a.y + offset_world[2],
            z = P_a.z + offset_world[3]
        }

        -- Set camera position with Euler angles for orientation (relative to global axes)
        -- Assuming LoSetCameraPosition accepts: x, y, z, pitch, roll, heading
        LoSetCameraPosition(P_c.x, P_c.y, P_c.z, pitch, roll, heading)
    end
}