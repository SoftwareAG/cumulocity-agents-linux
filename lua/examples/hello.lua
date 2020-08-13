-- hello.lua: lua/example/hello.lua

function init()  -- init() works like main function in C/C++
   srDebug("Hello world!")        -- Debug

   srInfo("Info message")         -- Info
   srNotice("Notice message")     -- Notice
   srError("Error message")       -- Error
   srCritical("Critical message") -- Critical

return 0
end