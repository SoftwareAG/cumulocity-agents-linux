#!/usr/bin/lua

local time = os.time()

print ("timestamp: "..time ..", value: "
   ..math.abs(math.floor(1000 * math.sin(time) + 0.5)/1000))

return 0