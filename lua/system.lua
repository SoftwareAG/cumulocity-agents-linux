require('sysutils')
local memTimer
local cpuTimer
function init()
   c8y:addMsgHandler(803, 'restartSystem')
   memTimer = c8y:addTimer(300*1000, 'sendMemUsage')
   cpuTimer = c8y:addTimer(300*1000, 'sendSystemLoad')
   memTimer:start()
   cpuTimer:start()
   local model = command("dmidecode -s system-product-name")
   local sn = command("dmidecode -s system-serial-number")
   if model and sn then
      c8y:send(table.concat({'310', c8y.ID, model, sn}, ','))
   end
   return 0
end


function restartSystem(r)
   c8y:send('303,' .. r:value(2) .. ',EXECUTING')
   c8y:send('304,' .. r:value(2) .. ',"Not supported yet!"')
end


function sendMemUsage()
   local total, use = getMemUsage()
   local perc = string.format("%.1f", use*100/total)
   c8y:send("305," .. c8y.ID .. ',' .. use .. ',' .. perc)
end


function sendSystemLoad()
   local value = string.format("%.2f", getSystemLoad())
   c8y:send("306," .. c8y.ID .. ',' .. value)
end
