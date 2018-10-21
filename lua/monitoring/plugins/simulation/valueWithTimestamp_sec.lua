#!/usr/bin/lua

local time = os.time()

local value = math.abs(math.floor(1000 * math.sin(time) + 0.5)/1000)

local output = string.format("timestamp: %s, value: %s", time, tostring(value))

print(output)

return 0