require ("monitoring/devel/utilities")

--class
monitor = {}

--body of the class
function monitor:new()

   local private = {}
      --private properties
      private.pluginsTable = nil
      private.pluginsDir = nil
      private.hostsTable = nil
      private.execTable = {}
      private.pluginsFile = nil
      private.hostsFile = nil
      private.hostPlaceholder = cdb:get('monitoring.placeholder.host')
      private.tenantPlaceholder = cdb:get('monitoring.placeholder.tenant')
      private.usernamePlaceholder = cdb:get('monitoring.placeholder.username')
      private.passwordPlaceholder = cdb:get('monitoring.placeholder.password')
      private.smsAgentIpPlaceholder = cdb:get('monitoring.placeholder.sms_agent_ip')
      private.hostName = nil

      --private methods
      function private:initialize()
         private.pluginsFile = cdb:get('monitoring.plugins.table')
         private.hostsFile = cdb:get('monitoring.hosts.table')
         private.pluginsDir = cdb:get('monitoring.plugins.directory')
         private.pluginsTable = dofile(private.pluginsFile)
         private.hostsTable = dofile(private.hostsFile)

         if (private.hostsTable["localhost"] ~= nil) then
            private.hostsTable["localhost"]["c8y_id"] = c8y.ID
         end
         private:getExternalIdsForHosts()
         private:getHostName() --should be before private:compileExecTable()
         private:compileExecTable()
      end

      function private:addExitCodeAndAsync(exec_unit_id, cwpap, is_async)
         local fc
         if (is_async == true) then
            local temp_output_file = private.outputTempdir.."/output_"..exec_unit_id
            fc = "(("..cwpap.."; echo '| EXIT_CODE =' $?) > "
               ..temp_output_file.." 2>&1 &); echo $?"
         else
            fc = cwpap.." 2>&1; echo $?"
         end
         return fc
      end

      function private:compileFinalCommand(host_id, plugin_id, exec_unit_id)
         local plugin_tbl = private.pluginsTable[plugin_id]
         local cwpap --command with path and parameters
         local fc --final command with path, params, exit code and async mode when needed
         local params = plugin_tbl.params or ""
         if (params ~= "") then
            local host_tbl = private.hostsTable[host_id]

            params = params:gsub(private.hostPlaceholder, host_id)
            params = params:gsub(private.tenantPlaceholder, host_tbl.tenant or "")
            params = params:gsub(private.usernamePlaceholder, host_tbl.username or "")
            params = params:gsub(private.passwordPlaceholder, host_tbl.password or "")
            params = params:gsub(private.smsAgentIpPlaceholder, host_tbl.sms_agent_ip or "")
         end
         cwpap = private.pluginsDir.."/"..plugin_tbl.command.." "..params
         fc = private:addExitCodeAndAsync(exec_unit_id, cwpap, plugin_tbl.async)
         return fc, cwpap
      end

      function private:compileExecUnit(host_id, plugin_id, exec_unit_id)
         local host_tbl = private.hostsTable[host_id]
         local plugin_tbl = private.pluginsTable[plugin_id]
         local exec_unit = {}
         exec_unit.host = host_id
         exec_unit.plugin = plugin_id
         exec_unit.exectime = 0 --TODO
         exec_unit.async = plugin_tbl.async or false --TODO when add async
         exec_unit.use_exit_code = plugin_tbl.use_exit_code
         exec_unit.regex = plugin_tbl.regex
         exec_unit.series = plugin_tbl.series
         exec_unit.final_command, exec_unit.command_with_path_and_params =
            private:compileFinalCommand(host_id, plugin_id, exec_unit_id)
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

      function private:compileExecTable()
         local exec_unit_id = 1
         for host_id, host_tbl in pairs(private.hostsTable) do
            if host_tbl["c8y_id"] then
               for i, plugin_id in ipairs(host_tbl.plugins_to_run) do
                  if (private.pluginsTable[plugin_id] == nil) then
                     srError("MONITORING No plugin with this id to run")
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

      function private:runSyncExecUnit(exec_unit_id)
         local exec_unit = private.execTable[exec_unit_id]

         local t = os.time()
         local file = io.popen(exec_unit.final_command)
         local output = file:read("*a")
         file:close()

         local exit_code = tonumber(output:sub(-2, -2)) --extract exit code
         output = output:sub(1, -4) --remove exit code and redundant \n
         exec_unit.exectime = os.time() - t --in seconds

         return output, exit_code
      end

      function private:runExecUnit(exec_unit_id)
         local exec_unit = private.execTable[exec_unit_id]

         if (exec_unit.async == false) then
            local output, exit_code = private:runSyncExecUnit(exec_unit_id)
            return output, exit_code
         elseif (exec_unit.async == true) then
            --TODO
         end
      end

      function private:getFragment(output, exec_unit_id)
         local exec_unit = private.execTable[exec_unit_id]
         local results = {}

         if (output ~= nil and exec_unit.series ~= nil and #exec_unit.series>0) then
            results = { string.match(output, exec_unit.regex) }

            if #results == #exec_unit.series then
               return results
            end
         end
         return nil
      end

      function private:getFormatString(str, captures, output)
         local result = ""
         local is_p = false -- is previous % char, reset after second % char
         local j = 1 -- captuter's number
         for i = 1, #str do
            local c = str:sub(i,i)
            if (c == '%') then
               if (is_p == false) then is_p = true
               elseif (is_p == true) then
                  result = result..'%'
                  is_p = false
               end
            elseif (c == 's' and is_p == true) then
               result = result..(string.match(output, captures[j]) or "")
               j = j + 1
               is_p = false
            else
               result = result..c
            end
         end
         return result
      end

      function private:getAlarmDescription(exec_unit_id, exit_code, output)
         local plugin_id = private.execTable[exec_unit_id]["plugin"]
         local plugin_tbl = private.pluginsTable[plugin_id]
         local warning, critical

         if (output == nil and alarmtext==nil) then
            if (exit_code == 1) then
               return "WARNING returned by "..plugin_id.." plugin. Output is not available."
            elseif (exit_code > 1)  then
               return "CRITICAL returned by "..plugin_id.." plugin. Output is not available."
            end
         end

         if (plugin_tbl.alarmtext ~= nil) then
            warning = plugin_tbl.alarmtext["warning"]
            critical = plugin_tbl.alarmtext["critical"]
         end

         if (exit_code == 1) then
            if (warning ~= nil and warning.formatstring ~= nil) then
               return private:getFormatString(
                                                warning.formatstring,
                                                warning.captures,
                                                output)
            end
         elseif (exit_code > 1) then
            if (critical ~= nil and critical.formatstring ~= nil) then
               return private:getFormatString(
                                                critical.formatstring,
                                                critical.captures,
                                                output)
            end
         end

         local result, n = string.gsub(output:sub(1, 128), '\n' ,' ')
         --return first 128 chars of output without newline
         return string.format("%s%s%s",'"',result,'"')
      end

      function private:sendFragment(exec_unit_id, exit_code, ms_tbl, output)
         local exec_unit = private.execTable[exec_unit_id]
         local host_id = exec_unit["host"]
         local c8y_id = private.hostsTable[host_id]["c8y_id"]

         local toSendType = "c8y_"..exec_unit["plugin"]
         if exec_unit.add_observer_hostname == true then
            toSendType = toSendType.."From "..private.hostName
         end

         for i=1, #ms_tbl do
            local series_id = exec_unit["series"][i]["name"]
            local unit = exec_unit["series"][i]["unit"]

            if (ms_tbl[i] ~= nil and series_id ~= nil and unit ~= nil) then
               c8y:send(table.concat({
                                       '342',
                                       c8y_id,
                                       toSendType,
                                       series_id,
                                       ms_tbl[i],
                                       unit,
                                       toSendType
                                    }, ','), 0)
            end
         end

         if (exec_unit["use_exit_code"] == true) then
            c8y:send(table.concat({
                                    '343',
                                    c8y_id,
                                    toSendType,
                                    exit_code,
                                    toSendType
                                 }, ','), 0)
            if (exit_code == 1) then
               c8y:send(table.concat({
                  '344',
                  c8y_id,
                  "c8y_"..exec_unit["plugin"].."Alarm",
                  private:getAlarmDescription(exec_unit_id, exit_code, output)
               }, ','), 1)
            elseif (exit_code > 1) then
               c8y:send(table.concat({
                  '345',
                  c8y_id,
                  "c8y_"..exec_unit["plugin"].."Alarm",
                  private:getAlarmDescription(exec_unit_id, exit_code, output)
               }, ','), 1)
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
         if ID then host_tbl["c8y_id"] = ID end
         return ID
      end

      function private:getExternalIdsForHosts()
         for host_id, host_tbl in pairs(private.hostsTable) do
            if (host_tbl["c8y_id"] == nil) then
               local ID = private:getExternalId(host_id, host_tbl)
               if ID then
                  srInfo("MONITORING Host "..host_id.." has ID: "..ID)
               else
                  srError("MONITORING Could not retrieve ID for host "..host_id)
               end
            end
         end
      end

      function private:getHostName()
         local file = io.popen("hostname -f")
         local output = file:read("*l")
         file:close()
         if output then
            private.hostName = output
            srInfo("MONITORING Hostname is "..output)
         else
            srError("MONITORING Could not retrieve hostname")
         end
      end

   private:initialize()

   local public = {}
      --public properties

      --public methods

      --dumps the content of 'private.pluginsTable'
      --for debugging
      function public:dumpAllPlugins()
         print_r(private.pluginsTable) -- function from module "utilities"
      end

      --dumps the content of 'private.execTable'
      --for debugging
      function public:dumpExecTable()
         print_r(private.execTable) -- function from module "utilities"
      end

      function public:singleRunOfExecUnits()

         for exec_unit_id, exec_unit in pairs(private.execTable) do
            local exec_unit = private.execTable[exec_unit_id]
            local output, exit_code = private:runExecUnit(exec_unit_id)
            local ms_tbl = private:getFragment(output, exec_unit_id) or {}

            private:sendFragment(exec_unit_id, exit_code, ms_tbl, output)
         end
      end

   setmetatable(public,self)
   self.__index = self
   return public
end
