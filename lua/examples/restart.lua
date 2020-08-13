-- restart.lua: lua/example/restart.lua
local fpath = '/usr/share/cumulocity-agent/restart.txt'

function restart(r)
   c8y:send('303,' .. r:value(2) .. ',EXECUTING', 1)
   local file = io.open(fpath, 'w')
   if not file then
      c8y:send('304,' .. r:value(2) .. ',"Failed to store Operation ID"', 1)
      return
   end
   file:write(r:value(2))  -- write the operation ID to the local file
   file:close()
   local ret = os.execute('reboot')
   if ret == true then ret = 0 end  -- for Lua5.2 and 5.3
   if ret == nil then ret = -1 end  -- for Lua5.2 and 5.3
   if ret ~= 0 then
      os.remove(fpath)  -- remove the local file when error occurs
      c8y:send('304,' .. r:value(2) .. ',"Error code: ' .. ret .. '"', 1)
   end
end

function init()
   c8y:addMsgHandler(804, 'restart')
   local file = io.open(fpath, 'r')
   local opid
   if file then  -- file should be exist after rebooting
      opid = file:read('*n')
      file:close()
      os.remove(fpath) -- delete the temporary local file
   end
   if opid then 
      c8y:send('303,' .. opid .. ',SUCCESSFUL', 1)
   end
   return 0
end
