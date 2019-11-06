require ("monitoring/devel/utilities")

--class
monitor = {}

--body of the class
function monitor:new()

   local private = {}

      --private properties
      private.pluginsPath = {}
      private.hostsTable = nil
      private.execTable = {}
      private.pluginsFile = nil
      private.hostsFile = nil
      private.hostName = nil
      private.activeAlarmsTable = {}
      private.noDuplicateAlarms = nil
      private.clearingAlarms = nil
      private.debugLogLevelVerbose = nil
      private.pluginsTimeout = nil

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
         private.pluginsPath = private:getAndVerifyPluginsPath()

         private.noDuplicateAlarms =
            cdb:get('monitoring.alarms.no_duplicates') == 'true'
            and true or false

         private.clearingAlarms =
            cdb:get('monitoring.alarms.clearing') == 'true'
            and private.noDuplicateAlarms
            and true or false

         private.debugLogLevelVerbose =
            cdb:get('monitoring.log.level.debug.verbose') == 'true'
            and true or false

         private.pluginsTimeout = tonumber(cdb:get('monitoring.plugins.timeout'))
         if private.pluginsTimeout <= 0 then
            private.pluginsTimeout = nil
         end

         if not private:fileExists(private.pluginsFile) then
            private.isInitError = true
            srError("MONITORING File with plugins table is not accessible")
            return
         end

         if not private:fileExists(private.hostsFile) then
            private.isInitError = true
            srError("MONITORING File with hosts table is not accessible")
            return
         end

         if #private.pluginsPath == 0 then
            private.isInitError = true
            srError("MONITORING No path to plugins is accessible")
            return
         end

         private.pluginsTable = dofile(private.pluginsFile)
         private.hostsTable = dofile(private.hostsFile)

         if private.hostsTable["localhost"] then
            private.hostsTable["localhost"]["c8y_id"] = c8y.ID
         end

         private:getC8YIdsForHosts()
         private:getHostName()
         private:compileExecTable()

         if #private.execTable == 0 then
            private.isInitError = true
            srError("MONITORING No plugins to run")
         end
      end

      function private:getAndVerifyPluginsPath()
         local path_str = cdb:get('monitoring.plugins.path')
         local path={}

         for capture in path_str:gmatch("([^,]+)") do
            table.insert(path, capture)
         end

         for i, value in ipairs(path) do
            if not private:fileExists(value) then
               table.remove(path, i)
            end
         end

         return path
      end

      function private:fileExists(filename)
         local f = io.open(filename, "r")
         if f then
            io.close(f)
            return true
         else
            return false
         end
      end

      function private:getC8YIdsForHosts()
         for host_id, host_tbl in pairs(private.hostsTable) do
            if not host_tbl.c8y_id then
               local ID = private:getC8YId(host_id, host_tbl)
               if ID then
                  srInfo("MONITORING Host "..host_id.." has ID: "..ID)
               else
                  private.isInitError = true
                  srError("MONITORING Could not retrieve ID for host "..host_id)
               end
            end
         end
      end

      --performs GET managed object for a specific external id request
      function private:getC8YId(host_id, host_tbl)
         local ID
         http:clear()
         if http:post('339,'..host_id) <= 0 then return nil end
         local resp = http:response()
         if string.sub(resp, 1, 2) == "50" then
            http:clear()
            if http:post('340,'..host_id..',1440') <= 0 then return nil end
            resp = http:response()
            if string.sub(resp, 1, 3) == '801' then
               ID = string.match(resp, "%d+,%d+,(%d+)")
               if not ID then return nil end
               local msg
               if host_tbl.is_child_device then
                  msg = string.format("341,%s,%s\n353,%s,%s",
                     ID, host_id, c8y.ID, ID)
               else
                  msg = string.format("341,%s,%s", ID, host_id)
               end
               if http:post(msg) < 0 then return nil end
            end
         elseif string.sub(resp, 1, 3) == '800' then
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
                     srWarning("MONITORING Plugin "..plugin_id
                        .." is not specified in ".. private.pluginsFile)
                  else
                     local exec_unit =
                        private:compileExecUnit(host_id, plugin_id, exec_unit_id)
                     if exec_unit then
                        table.insert(private.execTable, exec_unit_id, exec_unit)
                        exec_unit_id = exec_unit_id + 1
                     end
                  end
               end
            end
         end
      end

      function private:compileExecUnit(host_id, plugin_id, exec_unit_id)
         local host_tbl = private.hostsTable[host_id]
         local plugin_tbl = private.pluginsTable[plugin_id]
         local exec_unit = {}

         exec_unit.command_with_path_and_params, exec_unit.final_command =
            private:compileFinalCommand(host_id, plugin_id, exec_unit_id)

         if not exec_unit.command_with_path_and_params then
            return nil
         end

         if not plugin_tbl.series and not plugin_tbl.use_exit_code then
            return nil
         end

         exec_unit.host = host_id
         exec_unit.plugin = plugin_id
         exec_unit.use_exit_code = plugin_tbl.use_exit_code or false
         exec_unit.regex = plugin_tbl.regex
         exec_unit.series = plugin_tbl.series or {}

         if private.hostName and plugin_tbl.add_observer_hostname then
            exec_unit.add_observer_hostname = true
         end

         return exec_unit
      end

      function private:compileFinalCommand(host_id, plugin_id, exec_unit_id)
         local timeout = private.pluginsTimeout
         local plugin_tbl = private.pluginsTable[plugin_id]
         local cwp --command with path
         local cwtpap --command with timeout, path and parameters
         local fc --final command with timeout, path, params and exit code
         local params = plugin_tbl.params

         for i, value in ipairs(private.pluginsPath) do
            local temp_cwp = value.."/"..plugin_tbl.command

            if private:fileExists(temp_cwp) then
               cwp = temp_cwp
               break
            end
         end

         if not cwp then
            srWarning("MONITORING Plugin "..plugin_id.." is not accessible")
            return nil
         end

         --replacement of placeholders
         if params then
            local host_tbl = private.hostsTable[host_id]

            params = params:gsub(private.hostPlaceholder, host_id)
            params = params:gsub(private.tenantPlaceholder, host_tbl.tenant or "")
            params = params:gsub(private.usernamePlaceholder, host_tbl.username or "")
            params = params:gsub(private.passwordPlaceholder, host_tbl.password or "")
         end

         if params then
            cwtpap = cwp.." "..params
         else
            cwtpap = cwp
         end

         if timeout then
            cwtpap = string.format("timeout %d %s", timeout, cwtpap)
         end

         fc = cwtpap.." 2>&1; echo $?"
         return cwtpap, fc
      end

      function private:runExecUnit(exec_unit_id)
         local plugin_id = private.execTable[exec_unit_id]["plugin"]
         local command = private.execTable[exec_unit_id]["final_command"]

         if private.debugLogLevelVerbose then
            srDebug("MONITORING Executing plugin: "..plugin_id)
            srDebug("MONITORING Command: "..command)
         end

         local file = io.popen(command)
         local output = file:read("*a")
         file:close()

         --extract exit code
         local exit_code = tonumber(output:sub(-2, -2))
         --remove exit code and redundant \n
         output = output:sub(1, -4)

         if private.debugLogLevelVerbose then
            srDebug("MONITORING Output: "..output)
            srDebug("MONITORING Exit code: "..exit_code)
         end

         return output, exit_code
      end

      function private:getMeasurements(output, exec_unit_id)
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

      function private:sendMeasurementsAndAlarms(exec_unit_id, exit_code,
         ms_tbl, output)

         local exec_unit = private.execTable[exec_unit_id]
         local host_id = exec_unit.host
         local c8y_id = private.hostsTable[host_id]["c8y_id"]

         local timestamp = private:getTimestamp(exec_unit, ms_tbl)

         if (timestamp == -1) then --there is a timestamp but the value or unit is wrong
            return
         end

         local fragment_name
         local type_name = "c8y_"..exec_unit.plugin
         if exec_unit.add_observer_hostname then
            fragment_name = type_name.."_from_"..private.hostName
         else
            fragment_name = type_name
         end

         for i=1, #ms_tbl do
            local series_id = exec_unit.series[i]["name"]
            local unit = exec_unit.series[i]["unit"] or ""

            if ms_tbl[i] and series_id then
               if timestamp then
                  c8y:send(table.concat({
                        '348',
                        timestamp,
                        c8y_id,
                        fragment_name,
                        series_id,
                        ms_tbl[i],
                        unit,
                        type_name
                     }, ','), 0)
               else
                  c8y:send(table.concat({
                        '342',
                        c8y_id,
                        fragment_name,
                        series_id,
                        ms_tbl[i],
                        unit,
                        type_name
                     }, ','), 0)
               end
            end
         end

         if exec_unit.use_exit_code then
            private:sendExitCodeAsMeasurement(
                  timestamp,
                  exit_code,
                  c8y_id,
                  fragment_name,
                  type_name
               )

            local alarm_type = "c8y_"..exec_unit.plugin.."Alarm"

            if (exit_code >= 1) then
               private:sendAlarm(
                     timestamp,
                     exit_code,
                     c8y_id,
                     alarm_type,
                     private:getAlarmDescription(exec_unit_id, exit_code, output)
                  )
            elseif (exit_code == 0 and private.noDuplicateAlarms) then
               private:resetAlarm(c8y_id, alarm_type)
            end
         end
      end

      -- retrieves a timestamp if exists
      function private:getTimestamp(exec_unit, ms_tbl)
         for i=1, #exec_unit.series do
            if (exec_unit.series[i]["use_as_timestamp"]) then
               if not tonumber(ms_tbl[i]) then
                  srError("MONITORING timestamp is not a number")
                  return -1
               end
               if (exec_unit.series[i]["unit"] == "ms") then
                  local seconds,decimal = math.modf(tonumber(ms_tbl[i]))
                  local millisec = math.floor(decimal * 1000 + 0.5)
                  local utcdate = os.date("*t", seconds)

                  return string.format('%04d-%02d-%02dT%02d:%02d:%02d.%03d+0000',
                     utcdate.year,
                     utcdate.month,
                     utcdate.day,
                     utcdate.hour,
                     utcdate.min,
                     utcdate.sec,
                     millisec)
               elseif (exec_unit.series[i]["unit"] == "s") then
                  local utcdate = os.date("*t", tonumber(ms_tbl[i]))

                  return string.format('%04d-%02d-%02dT%02d:%02d:%02d+0000',
                     utcdate.year,
                     utcdate.month,
                     utcdate.day,
                     utcdate.hour,
                     utcdate.min,
                     utcdate.sec)
               else
                  srError("MONITORING wrong unit for timestamp")
                  return -1
               end
            end
         end
      end

      function private:sendExitCodeAsMeasurement(timestamp, exit_code, c8y_id,
         fragment_name, type_name)

         if timestamp then
            c8y:send(table.concat({
                  '349',
                  timestamp,
                  c8y_id,
                  fragment_name,
                  exit_code,
                  type_name
               }, ','), 0)

         else --no explicit timestamp
            c8y:send(table.concat({
                  '343',
                  c8y_id,
                  fragment_name,
                  exit_code,
                  type_name
               }, ','), 0)
         end
      end

      function private:sendAlarm(timestamp, exit_code, c8y_id, alarm_type,
         alarm_description)

         if private.noDuplicateAlarms
            and private:isAlarmActive(c8y_id, alarm_type) then

            return -- do not send the alarm
         end

         http:clear()

         if timestamp then
            if http:post(table.concat({
                  exit_code == 1 and '350' or '351',
                  timestamp,
                  c8y_id,
                  alarm_type,
                  alarm_description
               }, ',')) <= 0 then

               --TODO modify, output warning or error
               return nil
            end

            -- c8y:send(table.concat({
            --       exit_code == 1 and '350' or '351',
            --       timestamp,
            --       c8y_id,
            --       alarm_type,
            --       alarm_description
            --    }, ','), 1)

         else --no explicit timestamp

            if http:post(table.concat({
                  exit_code == 1 and '344' or '345',
                  c8y_id,
                  alarm_type,
                  alarm_description
               }, ',')) <= 0 then

                  --TODO modify, output warning or error
               return nil
            end
            -- c8y:send(table.concat({
            --       exit_code == 1 and '344' or '345',
            --       c8y_id,
            --       alarm_type,
            --       alarm_description
            --    }, ','), 1)
         end

         local alarm_id = getAlarmId(http:response())
         private:activateAlarm(c8y_id, alarm_type, alarm_id)
      end

      function private:getAlarmDescription(exec_unit_id, exit_code, output)
         local plugin_id = private.execTable[exec_unit_id]["plugin"]
         local plugin_tbl = private.pluginsTable[plugin_id]

         if plugin_tbl.alarmtext then
            if (exit_code == 1) then
               return plugin_tbl.alarmtext["warning"] or ""
            elseif (exit_code > 1) then
               return plugin_tbl.alarmtext["critical"] or ""
            end

         elseif (not output or string.len(output) == 0) then
            if (exit_code == 1) then
               return "Plugin "..plugin_id
                  .." returned WARNING. Output is not available."
            elseif (exit_code > 1)  then
               return "Plugin "..plugin_id
                  .." returned CRITICAL. Output is not available."
            end
         end

         --default is first 128 chars with newline chars replaced with spaces
         local default, n = string.gsub(output:sub(1, 128), '\n' ,' ')
         --quote marks added
         default = string.format("%s%s%s",'"',default,'"')

         return default
      end

      function private:resetAlarm(c8y_id, alarm_type)
         local alarms = private.activeAlarmsTable

         if alarms.c8y_id and alarms.c8y_id[alarm_type] then
            if private.clearingAlarms then
               --clear the alarm with corresponding id
               c8y:send('313,'..alarms.c8y_id[alarm_type], 0)
            end
            -- alarms.c8y_id[alarm_type] = false
            alarms.c8y_id[alarm_type] = nil
         end
      end

      function private:isAlarmActive(c8y_id, alarm_type)
         local alarms = private.activeAlarmsTable

         return alarms.c8y_id and alarms.c8y_id[alarm_type] ~= nil
      end

      function private:getAlarmId(resp)
         local alarm_id
         if string.sub(resp, 1, 3) == '876' then
            alarm_id = string.match(resp, "%d+,%d+,(%d+)")
         end
         return alarm_id
      end

      function private:activateAlarm(c8y_id, alarm_type, alarm_id)
         local alarms = private.activeAlarmsTable

         if not alarms.c8y_id then
            alarms.c8y_id = {}
         end

         -- alarms.c8y_id[alarm_type] = true
         alarms.c8y_id[alarm_type] = alarm_id
      end


   private:initialize()

   local public = {}

      --public methods
      function public:singleRunOfExecUnits()
         if not private.isInitError then
            for exec_unit_id, exec_unit in pairs(private.execTable) do
               local exec_unit = private.execTable[exec_unit_id]

               local output, exit_code = private:runExecUnit(exec_unit_id)

               local ms_tbl = private:getMeasurements(output, exec_unit_id)

               private:sendMeasurementsAndAlarms(exec_unit_id, exit_code,
                  ms_tbl, output)
            end
         end
      end

   setmetatable(public,self)
   self.__index = self
   return public
end
