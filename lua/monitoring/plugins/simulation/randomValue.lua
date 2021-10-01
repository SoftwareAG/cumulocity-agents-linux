#!/usr/bin/lua

local t = os.time()
math.randomseed (t)

local value1 = math.floor(1000 * math.random() + 0.5)/1000
local value2 = math.floor(1000 * math.random() + 0.5)/1000
local value3 = math.floor(1000 * math.random() + 0.5)/1000

local output = string.format("%s,%s,%s",
   tostring(value1), tostring(value2), tostring(value3))

print(output)

os.exit(0)
