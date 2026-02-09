local config = require "elevator_config"
local controller = require "elevator_controller"
local logger = require "logger"

local mon = peripheral.wrap(config.main_monitor)

local _debug = true
controller._debug = _debug
controller._logger = logger

logger.info("Running elevator.lua")

function dprint(...)
    if _debug then
        print(...)
    end
end

-- helper functions
local function writeCenter(term, y, str)
    local w,h = term.getSize()
    local x = math.ceil((w - #str + 1)/2)
    term.setCursorPos(x, y)
    term.clearLine()
    term.write(str)
end

-- monitor drawing
local charMap = {
    {" ", " ", " ", " ", " ", " ", " "},
    {" ", "1", " ", "2", " ", "3", " "},
    {" ", "4", " ", "5", " ", "6", " "},
    {" ", "7", " ", "8", " ", "9", " "},
    {" ", "*", " ", "0", " ", "#", " "},
}

local function drawMonitorKeypad(clickedX, clickedY)
    mon.setTextColor(colors.white)
    mon.setBackgroundColor(colors.black)
    mon.clear()
    mon.setTextScale(1)

    for y, line in ipairs(charMap) do
        mon.setCursorPos(1,y)
        for x, char in ipairs(line) do
            if x == clickedX and y == clickedY then
                mon.setBackgroundColor(colors.gray) 
                mon.write(char)
                mon.setBackgroundColor(colors.black) 
            else
                mon.write(char)
            end
        end
    end
    -- mon.setCursorPos(1,2)

    -- mon.write(" 1 2 3 ")
    -- mon.setCursorPos(1,3)
    -- mon.write(" 4 5 6 ")
    -- mon.setCursorPos(1,4)
    -- mon.write(" 7 8 9 ")
    -- mon.setCursorPos(1,5)
    -- mon.write(" * 0 # ")
end

local function drawMonitorFloors(floors, selected)
    mon.setTextColor(colors.white)
    mon.setBackgroundColor(colors.black)
    mon.clear()
    mon.setTextScale(0.5)

    local w, h = mon.getSize()

    table.sort(floors, function(a,b) return a > b end)

    local longestFloorNum = 0
    local containsNegative = false
    for i, floor in ipairs(floors) do
        local str = tostring(floor)
        if floor >= 0 then
            str = " "..str
        else
            containsNegative = true
        end
        if longestFloorNum < #str then
            longestFloorNum = #str
        end
    end
    if not containsNegative then
        longestFloorNum = longestFloorNum - 1
    end

    mon.setBackgroundColor(colors.gray)
    mon.setCursorPos(1,1)
    mon.clearLine()
    writeCenter(mon, 1, "Choose floor")
    
    mon.setBackgroundColor(colors.black)
    for i, floor in ipairs(floors) do
        local level_config = config.levels[floor]

        if i + 1 > h - 1 then break end

        mon.setCursorPos(1, i + 1)

        if floor == selected then
            mon.setBackgroundColor(colors.gray)
            mon.clearLine()
        else
            mon.setBackgroundColor(colors.black)
        end

        local floor_str = tostring(floor)
        if floor >= 0 then
            floor_str = " "..floor_str
        end
        mon.write(floor_str)

        if level_config.name ~= nil then
            mon.setCursorPos(longestFloorNum + 2, i + 1)

            local remainingSpace = w - longestFloorNum - 1
            if #level_config.name <= remainingSpace then
                mon.write(level_config.name)
            else
                mon.write(
                    level_config.name:sub(1, remainingSpace - 2) .. ".."
                )
            end
        end
    end

    mon.setBackgroundColor(colors.red)
    mon.setCursorPos(1,h)
    mon.clearLine()
    writeCenter(mon, h, "Return")
end

-- monitor input handling
function monitorChooseFloor(access)
    if #access == 1 then -- like, where else you gonna go
        dprint("Only one unlocked floor, changing to it")
        controller.goto(access[1])
        return
    end

    drawMonitorFloors(access)

    local w, h = mon.getSize()
    while true do
        local event, side, x, y = os.pullEvent("monitor_touch")
        if side == config.main_monitor then
            if y == h then
                logger.info("Returned without choosing floor")
                break
            end

            local selected = y - 1
            local floor = access[selected]
            if floor ~= nil then
                dprint(("Floor chosen: %d"):format(floor))
                drawMonitorFloors(access, floor)
                controller.goto(floor)
                break
            end
        end
    end
end

local function checkCode(code)
    if config.kill_code and code == "000" then
        logger.info("Kill code used")
        mon.clear()
        error("exited")
    end

    local access = config.codes[code]
    if access == nil then
        return false
    end

    return true, access
end

local function monitorKeypad()
    logger.info("Started main floor keypad")
    drawMonitorKeypad()
    local code = ""
    while true do
        writeCenter(mon, 1, ("*"):rep(#code))

        local event, side, x, y = os.pullEvent("monitor_touch")

        if side == config.main_monitor then
            local char = charMap[y][x]
            if char ~= " " then
                dprint(("Keypad char: '%s'"):format(char))
                if char == "*" then
                    code = ""
                elseif char == "#" then
                    local ok, access = checkCode(code)
                    logger.info(("Access attempt '%s': %s"):format(code, ok and table.concat(access, ",") or "denied"))

                    if ok then
                        mon.setTextColor(colors.green)
                    else 
                        mon.setTextColor(colors.red)
                    end
                    writeCenter(mon, 1, ("*"):rep(#code))
                    sleep(1)
                    mon.setTextColor(colors.white)
                    code = ""

                    if ok then
                        monitorChooseFloor(access)
                        sleep(0.5)
                        drawMonitorKeypad()
                    end
                else
                    code = code .. char
                end
            end
        end
    end
end

local function detectRedstone()
    logger.info("Started redstone detection")
    while true do
        os.pullEvent("redstone")
        -- vault door
        local main_floor_config = config.levels[config.main_floor]
        if peripheral.call(main_floor_config.relay, "getInput", main_floor_config.reset_side) then
            dprint("Reset line triggered (Vault door opening)")
            controller.goto(config.main_floor)
        end
        -- go back up buttons
        local gotoMain = false
        local callers = {}
        for _, floor_config in pairs(config.levels) do
            if floor_config.to_main_side ~= nil then
                table.insert(callers, function()
                    gotoMain = gotoMain or peripheral.call(floor_config.relay, "getInput", floor_config.to_main_side)
                end)
            end
        end
        parallel.waitForAll(table.unpack(callers))
        if gotoMain then
            dprint("Returning to main floor")
            controller.goto(config.main_floor)
        end
        -- call to floor buttons
        local gotoFloor = nil
        local callers = {}
        for floor, floor_config in pairs(config.levels) do
            if floor_config.to_floor_side ~= nil then
                table.insert(callers, function()
                    if peripheral.call(floor_config.relay, "getInput", floor_config.to_floor_side) then
                        gotoFloor = floor
                    end
                end)
            end
        end
        parallel.waitForAll(table.unpack(callers))
        if gotoFloor then
            dprint(("Called to floor %d"):format(gotoFloor))
            controller.goto(gotoFloor)
        end
    end
end


parallel.waitForAny(
    monitorKeypad,
    detectRedstone
)
logger.fatal("parallel.waitForAny returned")