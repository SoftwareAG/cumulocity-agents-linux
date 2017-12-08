require('sysutils')
local memTimer
local cpuTimer
local t0, t1 = 0, 0
function init()
   c8y:addMsgHandler(804, 'restartSystem')
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
      c8y:send("325," .. c8y.ID .. ',' .. use .. ',' .. total)
   end
end


function sendSystemLoad()
   local t = os.time()
   if t1 + cdb:get('system.cpu.interval') <= t then
      t1 = t
      local value = getSystemLoad()*100
      c8y:send("326," .. c8y.ID .. ',' .. value)
   end
end
