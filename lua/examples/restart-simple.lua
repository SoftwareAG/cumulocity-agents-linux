-- restart-simple.lua: lua/example/restart-simple.lua
function restart(r)
   srDebug('Agent received c8y_Restart operation!')
   c8y:send('303,' .. r:value(2) .. ',EXECUTING', 1)
   srDebug('Executing restart..')
   c8y:send('303,' .. r:value(2) .. ',SUCCESSFUL', 1)
end

function init()
   c8y:addMsgHandler(804, 'restart')
   return 0   -- signify successful initialization
end
