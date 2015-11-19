function getMemUsage()
   local file = io.popen('free -m')
   file:read('*l')
   local value = file:read('*l')
   file:close()
   d1, memTotal, memUse = string.match(value, "(%S+)%s*(%S+)%s*(%S+)")
   return memTotal, memUse
end


function getSystemLoad()
   local file = io.popen('cat /proc/loadavg')
   local value = file:read('*n')
   file:close()
   return value or 0
end


function command(cmd)
   local file = io.popen(cmd)
   local value = file:read('*l')
   file:close()
   return value
end
