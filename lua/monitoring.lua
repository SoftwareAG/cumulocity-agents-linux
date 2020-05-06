require('monitoring/monitor')

local monitorTimer
local mt0 = 0
local at0 = os.time()

local monitor = monitor:new()
local isError = false
local refreshAlarmsNow = false

function sendMonitorData()
   local monitoringInterval = tonumber(cdb:get('monitoring.interval'))
   if not monitoringInterval or monitoringInterval <= 0 then
      return
   end

   local alarmsRefreshInterval = tonumber(cdb:get('monitoring.alarms.refresh.interval'))
   if alarmsRefreshInterval and alarmsRefreshInterval <= 0 then
      alarmsRefreshInterval = nil
   end

   local current_time = os.time()
   if mt0 + monitoringInterval > current_time or isError then
      return
   end
   mt0 = current_time

   if alarmsRefreshInterval ~= nil then
      if at0 + alarmsRefreshInterval > current_time then
         refreshAlarmsNow = false
      else
         refreshAlarmsNow = true
         at0 = current_time
      end
   end

   --protected call of monitor:singleRunOfExecUnits()
   local status, err = pcall(monitor.singleRunOfExecUnits, monitor, refreshAlarmsNow)

   if not status then
      srError("MON "..(err or "plugin terminated with an error"))
      isError = true
   end
end

function init()
   monitorTimer = c8y:addTimer(1*1000, 'sendMonitorData')
   monitorTimer:start()
   return 0
end
