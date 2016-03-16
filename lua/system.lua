require('sysutils')
local memTimer
local cpuTimer
local t0, t1
function init()
   t0 = os.time()
   t1 = os.time()
   c8y:addMsgHandler(803, 'restartSystem')
   memTimer = c8y:addTimer(10*1000, 'sendMemUsage')
   cpuTimer = c8y:addTimer(10*1000, 'sendSystemLoad')
   memTimer:start()
   cpuTimer:start()
   return 0
end


function restartSystem(r)
   c8y:send('303,' .. r:value(2) .. ',EXECUTING')
   c8y:send('304,' .. r:value(2) .. ',"Not supported yet!"')
end


function sendMemUsage()
   local t = os.time()
   if t0 + cdb:get('system.mem.interval') <= t then
      t0 = t
      local total, use = getMemUsage()
      local perc = string.format("%.1f", use*100/total)
      c8y:send("305," .. c8y.ID .. ',' .. use .. ',' .. perc)
   end
end


function sendSystemLoad()
   local t = os.time()
   if t1 + cdb:get('system.cpu.interval') <= t then
      t1 = t
      local value = getSystemLoad()*100
      c8y:send("306," .. c8y.ID .. ',' .. value)
   end
end
