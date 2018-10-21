#!/usr/bin/lua

local max = 10 --max number of messages in a dump
local t = os.time()
math.randomseed (t)
local time = t + math.floor(10000 * math.random() + 0.5)/10000

local count = math.random(max)
local timestamp = time
local output = ""

for i=1, count do
   local value
   local r = math.random() / 50

   value = math.abs(math.floor(1000 * math.sin(t + r) + 0.5)/1000)
   output = string.format("%stimestamp: %s, value: %s\n",
      output,
      timestamp,
      value)

   timestamp = timestamp + math.random(10) / 100
end

output = output:sub(1, -2) --remove redundant last newline

print(output)

return 0