#!/usr/bin/lua

local t = os.time()
math.randomseed (t)

local exit_code = math.random(0, 2)

os.exit(exit_code)