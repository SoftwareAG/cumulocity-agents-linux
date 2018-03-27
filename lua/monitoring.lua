require('monitoring/monitor')

local monitorTimer
local t0 = 0
local monitor = monitor:new()

function sendMonitorData()
   local interval = cdb:get('monitoring.interval')
   local current_time = os.time()
   if interval == 0 or t0 + interval > current_time then
      return
   end
   t0 = current_time
   monitor:singleRunOfExecUnits()
end

function init()
   monitorTimer = c8y:addTimer(1*1000, 'sendMonitorData')
   monitorTimer:start()
   return 0
end