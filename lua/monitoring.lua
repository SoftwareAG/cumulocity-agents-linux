require('monitoring/monitor')

local monitorTimer
local t0 = 0
local monitor = monitor:new()
local isError = false

function sendMonitorData()
   local interval = tonumber(cdb:get('monitoring.interval'))
   if not interval or interval <= 0 then
      return
   end

   local current_time = os.time()
   if t0 + interval > current_time or isError then
      return
   end
   t0 = current_time

   --protected call of monitor:singleRunOfExecUnits()
   local status, err = pcall(monitor.singleRunOfExecUnits, monitor)

   if not status then
      srError("MONITORING "..(err or "plugin terminated with an error"))
      isError = true
   end
end

function init()
   monitorTimer = c8y:addTimer(1*1000, 'sendMonitorData')
   monitorTimer:start()
   return 0
end
