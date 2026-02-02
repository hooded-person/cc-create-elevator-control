-- Define here
local config = {
    main_monitor = "monitor_4",
    main_floor = 0,
    levels = {
        [0] = {
            relay = "redstone_relay_4",
            public = true,
            reset_side = "top",
            call_side = "right",
            elevator_present_side = "left",
        },
        [ -1 ] = {
            relay = "redstone_relay_5",
            unlock_side = "left",
            call_side = "front",
            elevator_present_side = "top",
        },
        [-2] = {
            relay = "redstone_relay_3",
            unlock_side = "left",
            call_side = "right",
            elevator_present_side = "front",
        }
    },
    codes = {
        ["15"] = { -1, -2 },
    }
}

-- Define defaults
local defaults = {
    main_floor = 0,
    levels = {
        unlock_side = "front",
        call_side = "right",
        elevator_present_side = "back",
    }
}

-- Applies defaults
config.main_floor = config.main_floor or defaults.main_floor
for floor, level_config in pairs(config.levels) do
    for key, default in pairs(defaults.levels) do
        level_config[key] = level_config[key] or default
    end
end

-- Returns config
return config
