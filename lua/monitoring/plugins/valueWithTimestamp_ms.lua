#!/usr/bin/lua

t = os.time()
math.randomseed (t)
time = t + math.floor(10000 * math.random() + 0.5)/10000

print ("timestamp: "..time ..", value: "
   ..math.abs(math.floor(1000 * math.sin(time) + 0.5)/1000))

return 0