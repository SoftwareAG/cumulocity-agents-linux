#!/usr/bin/lua

local t = os.time()
math.randomseed (t)

t = {
   "-1324.24356e+7",
   "3.33e-7",
   "-1434.33454E5",
   "0.33422E-9",
   "-2323.43923453",
}

print("value="..t[math.random(#t)])

os.exit(0)
