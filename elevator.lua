local config = require "elevator_config"
local controller = require "elevator_controller"

local awaitingRelock = false

local mon = peripheral.wrap(config.main_monitor)

-- initial setup
controller.goto(0)
controller.lock()

-- helper functions
local function writeCenter(term, y, str)
    local w,h = term.getSize()
    local x = math.ceil((w - #str + 1)/2)
    term.setCursorPos(x, y)
    term.clearLine()
    term.write(str)
end

-- monitor drawing and input handling
local charMap = {
    {" ", " ", " ", " ", " ", " ", " "},
    {" ", "1", " ", "2", " ", "3", " "},
    {" ", "4", " ", "5", " ", "6", " "},
    {" ", "7", " ", "8", " ", "9", " "},
    {" ", "*", " ", "0", " ", "#", " "},
}

local function drawMonitor()
    mon.setTextColor(colors.white)
    mon.setBackgroundColor(colors.black)
    mon.clear()
    for y, line in ipairs(charMap) do
        mon.setCursorPos(1,y)
        for x, char in ipairs(line) do
            mon.write(char)
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

local function monitor()
    drawMonitor()
    local code = ""
    while true do
        writeCenter(mon, 1, ("*"):rep(#code))

        local event, side, x, y = os.pullEvent("monitor_touch")
        if side == config.main_monitor then
            local char = charMap[y][x]
            if char ~= " " then
                print(char)
                if char == "*" then
                    code = ""
                elseif char == "#" then
                    local ok = checkCode(code)
                    if ok then
                        mon.setTextColor(colors.green)
                    else 
                        mon.setTextColor(colors.red)
                    end
                    writeCenter(mon, 1, ("*"):rep(#code))
                    sleep(1)
                    mon.setTextColor(colors.white)
                    code = ""
                else
                    code = code .. char
                end
            end
        end
    end
end

-- checking code and elevator stuff
function checkCode(code)
    if code == "000" then
        mon.clear()
        error("exited")
    end

    local access = config.codes[code]
    if access == nil then
        return false
    end

    controller.goto(config.main_floor, true)
    sleep()
    for _, floor in ipairs(access) do
        controller.unlock(floor)
    end

    awaitingRelock = true

    if #access == 1 then -- like, where else you gonna go
        print("Only one unlocked floor, changing to it")
        controller.goto(access[1])
    end

    return true
end

local function relock()
    while true do
        os.pullEvent("elevator_change_floor")
        if awaitingRelock then
            print("Relocking all floors")
            controller.lock()
            awaitingRelock = false
        end
    end
end

local function detectVaultDoor()
    while true do
        os.pullEvent("redstone")
        local floor_config = config.levels[config.main_floor]
        if peripheral.call(floor_config.relay, "getInput", floor_config.reset_side) then
            print("Reset line triggered (Vault door opening)")
            controller.goto(0)
            controller.lock()
            awaitingRelock = false
        end
    end
end

parallel.waitForAny(
    monitor,
    relock, 
    detectVaultDoor,
    controller.listenChangeFloor
)
