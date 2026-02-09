return {
    main_monitor = "monitor_4",
    main_floor = 0,
    levels = {
        [0] = {
            name = "Surface",
            public = true,
            relay = "redstone_relay_4",
            reset_side = "top",
            call_side = "right",
            elevator_present_side = "left",
        },
        [ -1 ] = {
            name = "Computer room",
            relay = "redstone_relay_9",
            call_side = "right",
            elevator_present_side = "left",
            to_floor_side = "back",
            to_main_side = "top",
        },
        [ -2 ] = {
            name = "Elevator maintenance",
            relay = "redstone_relay_8",
            call_side = "right",
            elevator_present_side = "left",
            to_floor_side = "back",
            to_main_side = "top",
        }
    },
    kill_code = true,
    codes = {
        ["15"] = { -1, -2 },
        ["8"] = { -1 },
    }
}