local logger = {}

local log_dir = "logs/"
local log_file = log_dir .. os.date("!%d_%m_%y") .. ".log"
local h = fs.open(log_file, "a")

function cleanOldestLog()
    local logs = fs.list(log_dir)
    local log_info = {}
    for _, log_name in ipairs(logs) do
        local log_path = log_dir .. log_name
        local attr = fs.attributes(log_path)
        if not attr.isDir and not attr.isReadOnly then
            table.insert(log_info, {
                path = log_path,
                modified = attr.modified,
            })
        end
    end
    table.sort(log_info, function(a,b) return a.modified < b.modified end)

    fs.delete(log_info[1].path)
    logger.warn(("Out of space, deleted oldest log file '%s'"):format(log_info[1].path))
end

function safeWrite(str)
    local bytes = #str
    local free = fs.getFreeSpace(log_dir)
    while bytes > free do
        cleanOldestLog()
        free = fs.getFreeSpace(log_dir)
    end
    h.write(str)
end

function log(str)
    local time = os.date("!%d/%m/%y %T")
    local out = ("[%s] %s"):format(time, str)
    safeWrite(out .. "\n")
    h.flush()
    print(out)
end

return setmetatable(logger, {
    __index = function(self, key)
        local method = key:upper()

        return function(str)
            log(method .. ": " .. str)
        end
    end
})
