#!/usr/bin/lua

local max = 10 --max number of messages in a dump
local t = os.time()
math.randomseed (t)

local count = math.random(max)
local output = ""

for i=1, count do
   local value
   local r = math.random() / 50
   value = math.abs(math.floor(1000 * math.sin(t + r) + 0.5)/1000)
   output = string.format("%svalue: %s\n", output, value)
end

output = output:sub(1, -2) --remove redundant last newline

print(output)

return 0
