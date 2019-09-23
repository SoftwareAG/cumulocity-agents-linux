#!/usr/bin/lua

local t = os.time()
math.randomseed (t)
local time = t + math.floor(10000 * math.random() + 0.5)/10000

local value = math.abs(math.floor(1000 * math.sin(time) + 0.5)/1000)

local output = string.format("timestamp: %s, value: %s", time, tostring(value))

print(output)

os.exit(0)