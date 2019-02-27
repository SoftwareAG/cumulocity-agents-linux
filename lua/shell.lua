function init()
   c8y:addMsgHandler(807, 'shell')
   c8y:addMsgHandler(875, 'shell')
   return 0
end


function shell(r)
   local opid, line, deviceId = r:value(2), r:value(3), r:value(4)
   if deviceId ~= c8y.ID then return end
   c8y:send('303,' .. opid .. ',EXECUTING')
   local cmd, key, value = string.match(line, '(%S+)%s+(%S+)%s*(%S*)')
   line = '"' .. line .. '"'
   if cmd == 'get' then
      local res = '"' .. cdb:get(key) .. '"'
      c8y:send(table.concat({'310', opid, 'SUCCESSFUL', line, res}, ','), 1)
   elseif cmd == 'set' then
      cdb:set(key, value or '')
      cdb:save(cdb:get('datapath') .. '/cumulocity-agent.conf')
      c8y:send(table.concat({'310', opid, 'SUCCESSFUL', line, ''}, ','), 1)
   else
      c8y:send('304,' .. opid .. ',invalid command')
   end
end
