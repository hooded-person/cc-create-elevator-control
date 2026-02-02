local config = require "elevator_config"

local controller = {
    -- floor = number, only present when running controller.listenChangeFloor (this keeps it updated)
}

function peripheralCall(...)
    -- print(...)
    return peripheral.call(...)
end

function controller.lock(floor)
    if floor == nil then
        local callers = {}
        for _, level_config in pairs(config.levels) do
            if not level_config.public then
                table.insert(callers, function()
                    peripheralCall(level_config.relay, "setOutput", level_config.unlock_side, false)
                end)
            end
        end
        parallel.waitForAll(table.unpack(callers))
        return true
    end

    if config.levels[floor] == nil then
        return false, "Invalid floor"
    end
    local level_config = config.levels[floor]

    if level_config.public == true then
        return false, "Can not lock public floor"
    end
    peripheralCall(level_config.relay, "setOutput", level_config.unlock_side, false)
    return true
end
function controller.unlock(floor)
    if floor == nil then
        local callers = {}
        for _, level_config in pairs(config.levels) do
            if not level_config.public then
                table.insert(callers, function()
                    peripheralCall(level_config.relay, "setOutput", level_config.unlock_side, true)
                end)
            end
        end
        parallel.waitForAll(table.unpack(callers))
        return true
    end

    if config.levels[floor] == nil then
        return false, "Invalid floor"
    end
    local level_config = config.levels[floor]

    if level_config.public == true then
        return false, "Can not unlock public floor"
    end
    peripheralCall(level_config.relay, "setOutput", level_config.unlock_side, true)
    return true
end

function controller.goto(floor, change_floor)
    if config.levels[floor] == nil then
        return false, "Invalid floor"
    end
    local level_config = config.levels[floor]

    if not level_config.public and not peripheralCall(level_config.relay, "getOutput", level_config.unlock_side) then
        return false, "Floor locked"
    end
    if controller.floor ~= nil and change_floor == true then
        controller.floor = floor
    end
    peripheralCall(level_config.relay, "setOutput", level_config.call_side, true)
    sleep(1)
    peripheralCall(level_config.relay, "setOutput", level_config.call_side, false)
    return true
end

function controller.locate()
    for floor, level_config in pairs(config.levels) do
        if peripheralCall(level_config.relay, "getInput", level_config.elevator_present_side) then
            return true, floor
        end
    end
    return false, "Uhhh, no elevator?"
end

function controller.onFloor(floor)
    if config.levels[floor] == nil then
        return false, "Invalid floor"
    end
    local level_config = config.levels[floor]

    return true, peripheralCall(level_config.relay, "getInput", level_config.elevator_present_side)
end

function controller.listenChangeFloor()
    controller.floor = select(2, controller.locate())
    while true do
        os.pullEvent("redstone")
        local floor = controller.locate()
        if controller.floor ~= floor then
            print("floor changed")
            os.queueEvent("elevator_change_floor", floor)
            controller.goto(floor)
        end
        controller.floor = floor
    end
end

return setmetatable({}, {
    __index = function(self, key)
        return function(...)
            print(key, ...)
            return controller[key](...)
        end
    end
})
