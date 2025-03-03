-- observerConfig.lua
-- Version 1.4 | Timestamp: 2024-10-26 14:00:00
-- Configuration file for observer camera settings

-- dx: Forward Vector
-- dy: Up Vector
-- dz: Right Vector

observerConfig = {
    -- Blue side game masters
    ["Hornet-Config_1"] = {
        trackUnit = "Hornet",  -- Replace with actual unit or group name from mission
        behavior = "a",             -- Camera behavior class (a, b, or c)
        relPos = {dx = 40, dy = 0, dz = 0} -- Offset: in front of aircraft
    },
    ["Hornet-Config_2"] = {
        trackUnit = "Hornet",
        behavior = "b",
        relPos = {dx = -50, dy = 0, dz = 0},  -- 50m behind
        orientation = {pitch = 0, yaw = 0, roll = 0},  -- World-relative orientation (north, level)
    },
    ["Hornet-Config_3"] = {
        trackUnit = "Hornet",
        behavior = "c",
        relPos = {dx = 100, dy = 50, dz = 0},  -- Starting position 100m right, 50m up
        angularVel = {x = 0, y = 0.1, z = 0},  -- Orbit at 0.1 rad/s around y-axis
    },
    -- Red side game masters
    ["Viper-Config_1"] = {
        trackUnit = "Viper",  -- Replace with actual unit or group name from mission
        behavior = "a",
        relPos = {dx = 0, dy = 100, dz = 0},   -- 100m above
    },
    ["Viper-Config_3"] = {
        trackUnit = "Callsign-2",
        behavior = "c",
        relPos = {dx = 0, dy = 50, dz = -100}, -- Start 100m behind, 50m up
        angularVel = {x = 0, y = 0.05, z = 0}, -- Slower orbit
    }
    -- Add more game masters as needed (blue_4, red_3, etc.)
}