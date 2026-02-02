local args = { ... }
local controller = require "elevator_controller"

local func = controller[args[1]]
if func == nil then
    print(("operation '%s' does not exist"):format(args[1]))
    return
end

local func_args = { select(2, ...) }

for i, arg in ipairs(func_args) do
    if tonumber(arg) then
        func_args[i] = tonumber(arg)
    end
end

local ok, msg = func(table.unpack(func_args))
if ok then
    term.setTextColor(colors.white)
else
    term.setTextColor(colors.red)
end
print(msg)
term.setTextColor(colors.white)
