local logger = require "logger"

while true do
    logger.info(("hi there"):rep(1000))

    local free = fs.getFreeSpace("logs/")
    logger.info(("Remaining space: %d"):format(free))
    sleep()
end