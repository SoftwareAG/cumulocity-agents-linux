-- software.lua: lua/example/software.lua

-- Linux commands
local cmd_list = 'apt list --installed'
local cmd_install = 'apt install -y'
local cmd_remove = 'apt remove -y'

-- File extention
local file_ext = '.deb'

-- Agent name (in order not to remove agent package)
local agent_name = 'cumulocity-agent'

-- Tables for received packages
local receives = {}
local pkg_fmt = '{""name"":""%s"",""version"":""%s"",""url"":"" ""}'
local pkg_path = '/tmp/'

-- Error messages
local charmsg = '"package %s has special characters, only [a-z0-9.+-] allowed"'
local errmsgs = {[-1] = '"Unknown reason"',
   [-2] = '"Download failed"',
   [-3] = '"Install/remove failed"',
   [129] = '"Uninstall agent not permitted"'
}


local function strerr(errno)
   return errmsgs[errno] or ('errno:' .. errno)
end


local function pack(tbl)
   local t = {}
   for name, version in pairs(tbl) do
      table.insert(t, string.format(pkg_fmt, name, version))
   end
   return '"' .. table.concat(t, ',') .. '"'
end


local function pkg_list()
   local tbl = {}
   local file = io.popen(cmd_list)
   for line in file:lines() do
      local name, version = string.match(line, '([%w%-%.]+)/.- (.-) .+')
      if name and version then tbl[name] = version end
   end
   file:close()
   return tbl
end


local function pkg_perform(cmd, pkgs)
   local param = cmd .. ' ' .. pkgs
   srInfo('software: ' .. param)
   local ret = os.execute(param)
   if ret == 0 or ret == true then -- os.execute returns different in Lua5.1 or 5.2&5.3
      return 0
   else
      return -3
   end
end


local function pkg_batch(tbl, cmd)
   if #tbl > 0 then
      local param = table.concat(tbl, ' ')
      return pkg_perform(cmd, param)
   else
      return 0
   end
end


local function send_failed(opid, c)
   c8y:send('319,' .. c8y.ID .. ',' .. pack(pkg_list()))
   c8y:send('304,' .. opid .. ',' .. strerr(c), 1)
end


function clear(r)
   receives = {}
end


function aggregate(r)
   -- receives[c8y_SoftwareList.name] = {c8y_SoftwareList.version, c8y_SoftwareList.url}
   receives[r:value(2)] = {r:value(3), r:value(4)}
end


function perform(r)
   -- Update the operation status to EXECUTING
   c8y:send('303,' .. r:value(2) .. ',EXECUTING')

   -- Check for invalid special characters in the package name
   for key, _ in pairs(receives) do
      if not string.match(key, '^[a-z0-9.+-]+$') then
         local errmsg = string.format(charmsg, key)
         c8y:send('304,' .. r:value(2) .. ',' .. errmsg, 1)
         return
      end
   end

   -- Create software list to be installed
   -- Remove received software from locallist -> the remaining should be uninstalled later
   local locallist = pkg_list()
   local installs = {}
   for key, value in pairs(receives) do
      local id = string.match(value[2], '/(%w+)$') -- ID of /inventory/binaries
      if value[1] ~= locallist[key] then
         installs[key] = {value[1], id}
      end
      locallist[key] = nil
   end

   receives = {}
   local c, removes = 0, {}

   -- Create software table to be removed
   for name, _ in pairs(locallist) do
      removes[#removes + 1] = name
      -- Agent package is forbidden to be removed
      if name == agent_name then c = 129 end
   end
   if c ~= 0 then
      send_failed(r:value(2), c)
      return
   end

   -- Remove packages if applicable
   c = pkg_batch(removes, cmd_remove)
   if c ~= 0 then
      send_failed(r:value(2), c)
      return
   end

   -- Create downloaded software table to be installed later
   local downloads = {}
   for name, value in pairs(installs) do
      local filename = pkg_path .. name .. file_ext
      if c8y:getf(value[2], filename) > 0 then
         downloads[#downloads + 1] = filename
      else
         c = -2
         break
      end
   end
   if c ~= 0 then
      send_failed(r:value(2), c)
      return
   end

   -- Install packages if applicable
   c = pkg_batch(downloads, cmd_install)
   if c ~= 0 then
      send_failed(r:value(2), c)
      return
   end

   -- Update the operation to SUCCESSFUL
   c8y:send('303,' .. r:value(2) .. ',SUCCESSFUL', 1)

   -- Send new package list
   c8y:send('319,' .. c8y.ID .. ',' .. pack(pkg_list()))
end


function init()
   c8y:addMsgHandler(837, 'clear')
   c8y:addMsgHandler(814, 'aggregate')
   c8y:addMsgHandler(815, 'perform')

   c8y:send('319,' .. c8y.ID .. ',' .. pack(pkg_list()))
   return 0
end
