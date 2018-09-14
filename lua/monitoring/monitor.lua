require ("monitoring/devel/utilities")

-- TODO
-- reorganize sequence of functions so the code is more readable
-- get rid of sync/async stuff

--class
monitor = {}

--body of the class
function monitor:new()

   local private = {}

      --private properties
      private.pluginsDir = nil
      private.hostsTable = nil
      private.execTable = {}
      private.pluginsFile = nil
      private.hostsFile = nil
      private.hostName = nil

      private.hostPlaceholder = nil
      private.tenantPlaceholder = nil
      private.usernamePlaceholder = nil
      private.passwordPlaceholder = nil

      private.isInitError = false

      --private methods
      function private:initialize()

         private.hostPlaceholder = cdb:get('monitoring.placeholder.host')
         private.tenantPlaceholder = cdb:get('monitoring.placeholder.tenant')
         private.usernamePlaceholder = cdb:get('monitoring.placeholder.username')
         private.passwordPlaceholder = cdb:get('monitoring.placeholder.password')

         private.pluginsFile = cdb:get('monitoring.plugins.table')
         private.hostsFile = cdb:get('monitoring.hosts.table')
         private.pluginsDir = cdb:get('monitoring.plugins.directory')

         if not private:fileExists(private.pluginsFile) then
            private.isInitError = true
            srError("MONITORING File with plugins table is not accessible")
         end

         if not private:fileExists(private.hostsFile) then
            private.isInitError = true
            srError("MONITORING File with hosts table is not accessible")
         end

         if not private:fileExists(private.pluginsDir) then
            private.isInitError = true
            srError("MONITORING Directory with plugins is not accessible")
         end

         private.pluginsTable = dofile(private.pluginsFile)
         private.hostsTable = dofile(private.hostsFile)

         if private.hostsTable["localhost"] then
            private.hostsTable["localhost"]["c8y_id"] = c8y.ID
         end

         private:getExternalIdsForHosts()
         private:getHostName()
         private:compileExecTable()
      end

      function private:fileExists(filename)
         local f = io.open(filename,"r")
         if f then
            io.close(f)
            return true
         else
            return false
         end
      end

      function private:getExternalIdsForHosts()
         for host_id, host_tbl in pairs(private.hostsTable) do
            if not host_tbl.c8y_id then
               local ID = private:getExternalId(host_id, host_tbl)
               if ID then
                  srInfo("MONITORING Host "..host_id.." has ID: "..ID)
               else
                  private.isInitError = true
                  srError("MONITORING Could not retrieve ID for host "..host_id)
               end
            end
         end
      end

      --performs GET external Id request
      function private:getExternalId(host_id, host_tbl)
         local ID
         http:clear()
         if http:post('339,'..host_id) <= 0 then return nil end
         local resp = http:response()
         if string.sub(resp, 1, 2) == "50" then
            http:clear()
            if http:post('340,'..host_id..',1440') <= 0 then return nil end
            resp = http:response()
            if string.sub(resp, 1, 3) == '801' then
               ID = string.match(resp, '%d+,%d+,(%d+)')
               if not ID then return nil end
               local msg = '341,'..ID..','..host_id
               if http:post(msg) < 0 then return nil end
            end
         elseif string.sub(resp, 1, 3) == "800" then
            ID = string.match(resp, "%d+,%d+,(%d+)")
         end
         if ID then host_tbl.c8y_id = ID end
         return ID
      end

      function private:getHostName()
         local file = io.popen("hostname -f")
         local output = file:read("*l")
         file:close()
         if output then
            srInfo("MONITORING Hostname is "..output)
            private.hostName = output:gsub("%.","_")
         else
            srInfo("MONITORING Could not retrieve hostname")
         end
      end

      function private:compileExecTable()
         local exec_unit_id = 1
         for host_id, host_tbl in pairs(private.hostsTable) do
            if host_tbl.c8y_id then
               for i, plugin_id in ipairs(host_tbl.plugins_to_run) do
                  if not private.pluginsTable[plugin_id] then
                     private.isInitError = true
                     srError("MONITORING Plugin "..plugin_id
                        .." is not specified in ".. private.pluginsFile)
                  else
                     local exec_unit =
                        private:compileExecUnit(host_id, plugin_id, exec_unit_id)
                     table.insert(private.execTable, exec_unit_id, exec_unit)
                     exec_unit_id = exec_unit_id + 1
                  end
               end
            end
         end
      end

      function private:compileExecUnit(host_id, plugin_id, exec_unit_id)
         local host_tbl = private.hostsTable[host_id]
         local plugin_tbl = private.pluginsTable[plugin_id]
         local exec_unit = {}
         exec_unit.host = host_id
         exec_unit.plugin = plugin_id
         exec_unit.use_exit_code = plugin_tbl.use_exit_code
         exec_unit.regex = plugin_tbl.regex
         exec_unit.series = plugin_tbl.series
         exec_unit.command_with_path_and_params, exec_unit.final_command =
            private:compileFinalCommand(host_id, plugin_id, exec_unit_id)

         --TODO
         if (private.hostName and host_tbl.plugins_with_observer_hostname) then
            for i, p in ipairs(host_tbl.plugins_with_observer_hostname) do
               if p == plugin_id then
                  exec_unit.add_observer_hostname = true
                  break
               end
            end
         end
         return exec_unit
      end

      function private:compileFinalCommand(host_id, plugin_id, exec_unit_id)
         local plugin_tbl = private.pluginsTable[plugin_id]
         local cwp --command with path
         local cwpap --command with path and parameters
         local fc --final command with path, params and exit code
         local params = plugin_tbl.params or ""

         --replacement of placeholders
         if (params ~= "") then
            local host_tbl = private.hostsTable[host_id]

            params = params:gsub(private.hostPlaceholder, host_id)
            params = params:gsub(private.tenantPlaceholder, host_tbl.tenant or "")
            params = params:gsub(private.usernamePlaceholder, host_tbl.username or "")
            params = params:gsub(private.passwordPlaceholder, host_tbl.password or "")
         end

         cwp = private.pluginsDir.."/"..plugin_tbl.command

         if not private:fileExists(cwp) then
            private.isInitError = true
            srError("MONITORING Plugin "..cwp.." is not accessible")
         end

         cwpap = cwp.." "..params
         fc = cwpap.." 2>&1; echo $?"
         return cwpap, fc
      end

      function private:runExecUnit(exec_unit_id)
         local command = private.execTable[exec_unit_id]["final_command"]

         local file = io.popen(command)
         local output = file:read("*a")
         file:close()

         --extract exit code
         local exit_code = tonumber(output:sub(-2, -2))
         --remove exit code and redundant \n
         output = output:sub(1, -4)

         return output, exit_code
      end

      function private:getFragment(output, exec_unit_id)
         local exec_unit = private.execTable[exec_unit_id]
         local results = {}

         if output and exec_unit.series and #exec_unit.series > 0 then
            results = { string.match(output, exec_unit.regex) }

            if #results == #exec_unit.series then
               return results
            end
         end

         return {}
      end

      function private:sendFragment(exec_unit_id, exit_code, ms_tbl, output)
         local exec_unit = private.execTable[exec_unit_id]
         local host_id = exec_unit.host
         local c8y_id = private.hostsTable[host_id]["c8y_id"]

         local fragmentName
         local typeName = "c8y_"..exec_unit.plugin
         if exec_unit.add_observer_hostname == true then
            fragmentName = typeName.."_from_"..private.hostName
         else
            fragmentName = typeName
         end

         for i=1, #ms_tbl do
            local series_id = exec_unit.series[i]["name"]
            local unit = exec_unit.series[i]["unit"]

            if ms_tbl[i] and series_id and unit then
               c8y:send(table.concat({
                     '342',
                     c8y_id,
                     fragmentName,
                     series_id,
                     ms_tbl[i],
                     unit,
                     typeName
                  }, ','), 0)
            end
         end

         if (exec_unit.use_exit_code == true) then
            c8y:send(table.concat({
                  '343',
                  c8y_id,
                  fragmentName,
                  exit_code,
                  typeName
               }, ','), 0)
            if (exit_code == 1) then
               c8y:send(table.concat({
                  '344',
                  c8y_id,
                  "c8y_"..exec_unit.plugin.."Alarm",
                  private:getAlarmDescription(exec_unit_id, exit_code, output)
               }, ','), 1)
            elseif (exit_code > 1) then
               c8y:send(table.concat({
                  '345',
                  c8y_id,
                  "c8y_"..exec_unit.plugin.."Alarm",
                  private:getAlarmDescription(exec_unit_id, exit_code, output)
               }, ','), 1)
            end
         end
      end

      function private:getAlarmDescription(exec_unit_id, exit_code, output)
         local plugin_id = private.execTable[exec_unit_id]["plugin"]
         local plugin_tbl = private.pluginsTable[plugin_id]

         if not output and not plugin_tbl.alarmtext then
            if (exit_code == 1) then
               return "WARNING returned by "..plugin_id
                  .." plugin. Output is not available."
            elseif (exit_code > 1)  then
               return "CRITICAL returned by "..plugin_id
                  .." plugin. Output is not available."
            end
         end

         if plugin_tbl.alarmtext then
            if (exit_code == 1) then
               return plugin_tbl.alarmtext["warning"] or ""
            elseif (exit_code > 1) then
               return plugin_tbl.alarmtext["critical"] or ""
            end
         end

         --default is first 128 chars with newline chars replaced with spaces
         local default, n = string.gsub(output:sub(1, 128), '\n' ,' ')
         --quote marks added
         default = string.format("%s%s%s",'"',default,'"')

         return default
      end

   private:initialize()

   local public = {}

      --public methods
      function public:singleRunOfExecUnits()
         if not private.isInitError then
            for exec_unit_id, exec_unit in pairs(private.execTable) do
               local exec_unit = private.execTable[exec_unit_id]

               local output, exit_code = private:runExecUnit(exec_unit_id)

               local ms_tbl = private:getFragment(output, exec_unit_id)

               private:sendFragment(exec_unit_id, exit_code, ms_tbl, output)
            end
         end
      end

   setmetatable(public,self)
   self.__index = self
   return public
end
