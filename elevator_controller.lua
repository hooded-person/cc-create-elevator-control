local config = require "elevator_config"

local controller = {
    -- _floor = number, only present when running controller.listenChangeFloor (this keeps it updated)
    _debug = false,
    _logger = nil,
}

function dprint(...)
    if controller._debug then
        print(...)
    end
end

function controller.goto(floor, change_floor)
    if config.levels[floor] == nil then
        return false, "Invalid floor"
    end
    local level_config = config.levels[floor]

    if controller._logger then
        controller._logger.info(("Elevator to floor %d"):format(floor))
    end

    if controller._floor ~= nil and change_floor == true then
        controller._floor = floor
    end
    peripheral.call(level_config.relay, "setOutput", level_config.call_side, true)
    sleep(1)
    peripheral.call(level_config.relay, "setOutput", level_config.call_side, false)
    return true
end

function controller.locate()
    local located_floor
    local callers = {}
    for floor, level_config in pairs(config.levels) do
        table.insert(callers, function()
            if peripheral.call(level_config.relay, "getInput", level_config.elevator_present_side) then
                located_floor = floor
            end
        end)
    end
    parallel.waitForAll(table.unpack(callers))
    if located_floor ~= nil then
        return true, located_floor
    end
    return false, "In transit"
end

function controller.onFloor(floor)
    if config.levels[floor] == nil then
        return false, "Invalid floor"
    end
    local level_config = config.levels[floor]

    return true, peripheral.call(level_config.relay, "getInput", level_config.elevator_present_side)
end

function controller.listenChangeFloor()
    controller._floor = select(2, controller.locate())
    while true do
        os.pullEvent("redstone")
        local floor = controller.locate()
        if controller._floor ~= floor then
            dprint("floor changed")
            os.queueEvent("elevator_change_floor", floor)
            controller.goto(floor)
        end
        controller._floor = floor
    end
end

return controller
-- return setmetatable({}, {
--     __index = function(self, key)
--         if controller[key] == nil then 
--             return nil
--         end
--         return function(...)
--             print(key, ...)
--             return controller[key](...)
--         end
--     end
-- })