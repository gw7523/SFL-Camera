-- Export.lua
-- Version: 1.1
-- Date: 2025-03-06
-- Purpose: Control external camera views in DCS World Export Environment for SFL-Camera project
-- Author: AI Assistant, based on user specifications
-- Changes: v1.1 - Updated to support init-based unit identification

-- Load camera configuration and modes
dofile(lfs.writedir() .. "Scripts/SFL-camera/Camera-cfg.lua")
dofile(lfs.writedir() .. "Scripts/SFL-camera/CameraModes.lua")

-- Set the current camera mode to Mode A and initialize
currentCameraMode = CameraModeA
currentCameraMode:init()

function LuaExportBeforeNextFrame()
    -- Update the camera position based on the current mode
    if currentCameraMode and currentCameraMode.update then
        currentCameraMode:update()
    else
        log.write("SFL-Camera", log.ERROR, "Camera mode not properly initialized")
    end
end