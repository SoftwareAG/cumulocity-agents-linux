local months = {Jan = 1, Feb = 2, Mar = 3, Apr = 4, May = 5, Jun = 6,
                Jul = 7, Aug = 8, Sep = 9, Oct = 10, Nov = 11, Dec = 12}

function pacman_b_filter(line, start)
   local t = {string.match(line, '%[(%d+)-(%d+)-(%d+) (%d+):(%d+)')}
   local b = false
   if #t == 5 then
      local lt = os.time{year=t[1], month=t[2], day=t[3],
                           hour=t[4], min=t[5], sec=0}
      b = lt >= start
   end
   return b
end


function pacman_e_filter(line, stop)
   local t = {string.match(line, '%[(%d+)-(%d+)-(%d+) (%d+):(%d+)')}
   local b = true
   if #t == 5 then
      local lt = os.time{year=t[1], month=t[2], day=t[3],
                           hour=t[4], min=t[5], sec=0}
      b = lt <= stop
   end
   return b
end


function syslog_b_filter(line, start)
   local t = {string.match(line, '(%w+)%s+(%d+)%s+(%d+):(%d+):(%d+)')}
   local b = false
   if #t == 5 then
      local y = os.date('%Y', os.time())
      local lt = os.time{year=y, month=months[t[1]], day=t[2],
                           hour=t[3], min=t[4], sec=t[5]}
      b = lt >= start
   end
   return b
end


function syslog_e_filter(line, stop)
   local t = {string.match(line, '(%w+)%s+(%d+)%s+(%d+):(%d+):(%d+)')}
   local b = true
   if #t == 5 then
      local y = os.date('%Y', os.time())
      local lt = os.time{year=y, month=months[t[1]], day=t[2],
                           hour=t[3], min=t[4], sec=t[5]}
      b = lt <= stop
   end
   return b
end


function dmesg_b_filter(line, start)
   local t = {string.match(line, '(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)')}
   local b = false
   if #t == 6 then
      local lt = os.time{year=t[1], month=t[2], day=t[3],
                         hour=t[4], min=t[5], sec=t[6]}
      b = lt >= start
   end
   return b
end


function dmesg_e_filter(line, stop)
   local t = {string.match(line, '(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)')}
   local b = true
   if #t == 6 then
      local lt = os.time{year=t[1], month=t[2], day=t[3],
                           hour=t[4], min=t[5], sec=t[6]}
      b = lt <= stop
   end
   return b
end


function journald_filter(line, start)
   return true
end
