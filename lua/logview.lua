require('logfilter')
local jfmt = 'journalctl -q --no-pager --since %q --until %q|grep %q|tail -%d'
local logtable = {
   pacman = {'/var/log/pacman.log', pacman_b_filter, pacman_e_filter},
   syslog = {'/var/log/syslog', syslog_b_filter, syslog_e_filter},
   journald = {'/bin/journalctl'},
   dmesg = {'/bin/dmesg'},
   cumulocityagent= {cdb:get('log.path'), syslog_b_filter, syslog_e_filter},
}


function init()
   c8y:addMsgHandler(813, 'logview')
   c8y:send('317,' .. c8y.ID .. ',' .. probe_logs())
   return 0
end


function probe_logs()
   local tbl = {}
   for k, v in pairs(logtable) do
      if io.open(v[1], 'r') then table.insert(tbl, '""' .. k .. '""') end
   end
   return '"' .. table.concat(tbl, ',') .. '"'
end


-- Convert ISO time (2011-05-12T13:12:32+0001) to utc seconds since epoch
function utc_time(time)
   local tfmt = '(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)[.%d]*'
   local tbl = {string.match(time, tfmt)}
   if #tbl < 6 then return end
   local st = os.time{year=tbl[1], month=tbl[2], day=tbl[3],
                      hour=tbl[4], min=tbl[5], sec=tbl[6]}
   local tz = string.match(time, '[+-]%d+:?%d+$')
   local num = tz and tonumber(string.sub(tz, 1, 3)) or 0
   return st + num * 3600
end


-- UTC + tzsec() = LOCAL
function tzsec()
   local now = os.time()
   local utc = os.time(os.date('!*t', now))
   return os.difftime(os.time(os.date('*t', now)), utc)
end


function wrap(tbl, index)
   local data = ''
   for i = index, #tbl do
      data = data .. tbl[i] .. '\n'
   end
   for i = 1, index-1 do
      data = data .. tbl[i] .. '\n'
   end
   return data
end


function file_iter(lt)
   return io.open(logtable[lt][1]), logtable[lt][2], logtable[lt][3]
end


function dmesg_iter(start, stop, match, limit)
   local file = io.popen('dmesg -TP --time-format=iso --color=never')
   return file, dmesg_b_filter, dmesg_e_filter
end


function journald_iter(start, stop, match, limit)
   local pattern = string.gsub(match, '"', '\"')
   local t0 = os.date('%Y-%m-%d %H:%M:%S', start)
   local t1 = os.date('%Y-%m-%d %H:%M:%S', stop)
   local file = io.popen(string.format(jfmt, t0, t1, pattern, limit))
   return file, journald_filter, journald_filter
end


function _log(logtype, start, stop, match, limit)
   local file, bf, ef
   if logtype == 'journald' then
      file, bf, ef = journald_iter(start, stop, match, limit)
   elseif logtype == 'dmesg' then
      file, bf, ef = dmesg_iter(start, stop, match, limit)
   else
      file, bf, ef = file_iter(logtype)
   end
   if not file then return nil end
   local index = 1
   local tbl = {}
   for line in file:lines() do
      if bf(line, start) then
         if ef(line, stop) then
            tbl[index] = line
            index = 2
         end
         break
      end
   end
   for line in file:lines() do
      if not ef(line, stop) then break end
      if string.match(line, match) then
         tbl[index] = line
         index = index % limit + 1
      end
   end
   file:close()
   return wrap(tbl, index)
end


function getFileUrl(json)
   local urlmatch = '"self":"([^ {},?]+/inventory/)%w+/(%d+)"'
   local prefix, id = string.match(json, urlmatch)
   if prefix and id then
      return prefix .. 'binaries/' .. id
   end
end


function logview(r)
   local start = utc_time(r:value(4)) + tzsec()
   local stop = utc_time(r:value(5)) + tzsec()
   local data = _log(r:value(3), start, stop, r:value(7), r:value(6))
   local reason = ',"Cannot get log"'
   if data then
      local no = c8y:post(r:value(3) .. '.log', "text/plain", data)
      if no >= 0 then
         local url = getFileUrl(c8y.resp)
         if url then
            c8y:send(table.concat({'318', r:value(2), r:value(3), r:value(4),
                                   r:value(5), r:value(6), r:value(7), url},
                        ','), 1)
            return
         else
            reason = ',"Cannot find log ID"'
         end
      else
         reason = ',"Cannot upload log"'
      end
   end
   c8y:send('304,' .. r:value(2) .. reason, 1)
end
