require('sysutils')
require('logview')

local ID = 10045

function sendMemUsage()
   local total, use = getMemUsage()
   local perc = string.format("%.1f", use*100/total)
   print("105," .. ID .. ',' .. use .. ',' .. perc)
end


function sendSystemLoad()
   local value = string.format("%.2f", getSystemLoad())
   print("106," .. ID .. ',' .. value)
end


function sendHWInfo()
   local model = command("dmidecode -s system-product-name")
   local sn = command("dmidecode -s system-serial-number")
   if model and sn then
      print(model .. ', ' .. sn)
   else
      print('not found')
   end
end


local start = utc_time('2014-10-30T15:49:52+0100') + tzsec()
local stop = utc_time('2015-11-03T15:49:52+0100') + tzsec()
print(_log('journald', start, stop, '"', '10'))
