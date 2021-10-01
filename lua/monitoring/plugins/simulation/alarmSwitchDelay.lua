#!/usr/bin/lua

local time = os.date("*t")
local minute = time.min

print(time.hour..":"..minute..":"..time.sec)

local exit_code = (minute % 10 < 5) and 2 or 0
os.exit(exit_code)
