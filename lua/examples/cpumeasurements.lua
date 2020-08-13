-- cpumeasurements.lua: lua/example/cpumesurements.lua

local cpuTimer

function init()
   local intervalInSec = cdb:get('example.cpu.interval') -- Get the interval from cumulocity-agent.conf
   cpuTimer = c8y:addTimer(intervalInSec * 1000, 'sendCPU') -- Add the timer to agent scheduler
   cpuTimer:start() -- Start the timer
   return 0
end

function sendCPU()
   local value = 20  -- Fake cpu usage (20%)
   c8y:send("326," .. c8y.ID .. ',' .. value) -- Send the fake cpu usage to Cumulocity as measurments
end