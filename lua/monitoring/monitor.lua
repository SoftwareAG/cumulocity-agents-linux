require ("monitoring/util/misc")

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
      private.pluginsConcurrentExecution = nil
      private.activeAlarmsTable = {}
      private.noDuplicateAlarms = nil
      private.clearingAlarmsGlobal = nil
      private.updateAlarmOnTextChangeGlobal = nil
      private.refreshAlarmsNow = nil
      private.debugLogLevelVerbose = nil
      private.chefLinkedExternalId = nil
      private.chefAttributesTable = {}
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

         private.pluginsConcurrentExecution =
            cdb:get('monitoring.plugins.concurrent_execution') == 'true'

         private.noDuplicateAlarms =
            cdb:get('monitoring.alarms.no_duplicates') == 'true' or
            cdb:get('monitoring.alarms.clearing') == 'true' and
            cdb:get('monitoring.alarms.no_duplicates') ~= 'false'

         private.clearingAlarmsGlobal =
            cdb:get('monitoring.alarms.clearing') == 'true'
            and private.noDuplicateAlarms

         private.updateAlarmOnTextChangeGlobal =
            cdb:get('monitoring.alarm.update_on_text_change') == 'true'

         private.debugLogLevelVerbose =
            cdb:get('monitoring.log.level.debug.verbose') == 'true'

         private.chefLinkedExternalId  =
            cdb:get('monitoring.chef.linked.external.id') == 'true'

         private.pluginsTimeout = tonumber(cdb:get('monitoring.plugins.timeout'))
         if private.pluginsTimeout <= 0 then
            private.pluginsTimeout = nil
         end

         if not private:fileExists(private.pluginsFile) then
            private.isInitError = true
            srError("MON File with plugins table is not accessible")
            return
         end

         if not private:fileExists(private.hostsFile) then
            private.isInitError = true
            srError("MON File with hosts table is not accessible")
            return
         end

         if #private.pluginsPath == 0 then
            private.isInitError = true
            srError("MON No path to plugins is accessible")
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
            srError("MON No plugins to run")
         end

         if private.chefLinkedExternalId then
            private:fetchChefAttributes()
            private:createChefLinkedExternalId()
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
                  srInfo("MON Host "..host_id.." has ID: "..ID)
               else
                  private.isInitError = true
                  srError("MON Could not retrieve ID for host "..host_id)
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
            srInfo("MON Hostname is "..output)
            private.hostName = output:gsub("%.","_")
         else
            srInfo("MON Could not retrieve hostname")
         end
      end

      function private:compileExecTable()
         local exec_unit_id = 1
         for host_id, host_tbl in pairs(private.hostsTable) do
            if host_tbl.c8y_id then
               for i, plugin_id in ipairs(host_tbl.plugins_to_run) do
                  if not private.pluginsTable[plugin_id] then
                     srWarning("MON Plugin "..plugin_id
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
         exec_unit.use_exit_code = plugin_tbl.use_exit_code == true
         exec_unit.plugin_alarms_clearing =
            plugin_tbl.no_alarms_clearing ~= true
         exec_unit.update_alarm_on_text_change =
            private.updateAlarmOnTextChangeGlobal and
            plugin_tbl.update_alarm_on_text_change ~= false
         exec_unit.regex = plugin_tbl.regex
         exec_unit.series = plugin_tbl.series or {}
         --true if all active or acknowledged alarms of the given type are cleared
         exec_unit.did_clear_all_alarms = false

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
            srWarning("MON Plugin "..plugin_id.." is not accessible")
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

      function private:fetchChefAttributes()
         local chef_file = "/etc/motd"
         if not private:fileExists(chef_file) then return end

         local environment, node_name
         for line in io.lines(chef_file) do
            if not environment then
               environment = line:match("^Environment:%s+([%w-_]+)$")
            end
            if not node_name then
               node_name = line:match("^Node name:%s+([%w-_]+)$")
            end
            if environment and node_name then
               private.chefAttributesTable.environment = environment
               private.chefAttributesTable.node_name = node_name
               break
            end
         end
      end

      function private:createChefLinkedExternalId()
         local environment =  private.chefAttributesTable.environment
         local node_name = private.chefAttributesTable.node_name

         if not environment or not node_name then
            srError([[MON Chef Linked External Id is configured to be used,
               but the Chef attributes are unavailable]])
            return
         end

         c8y:send((string.format("%d,%s,%s:%s",
            302, c8y.ID, environment, node_name)), 0)
      end

      function private:runPluginsConcurrently()
         local pipes = private:populatePipeTable()

         local posixUnistd = require 'posix.unistd'
         local posixPoll = require 'posix.poll'

         while true do
            posixUnistd.sleep(1)
            posixPoll.poll(pipes, 0)
            for fd, pipe in pairs(pipes) do
               if pipe.revents.HUP then
                  private:processPipe(pipe)
                  pipe["pipe"]:close()
                  pipes[fd] = nil
               elseif pipe.revents.ERR then
                  local exec_unit_id = pipe.exec_unit_id
                  local plugin_id = private.execTable[exec_unit_id].plugin
                  srError("MON Error condition in returned events for plugin: "..plugin_id)
                  pipe["pipe"]:close()
                  pipes[fd] = nil
               end
            end
            if next(pipes) == nil then
               return
            end
         end
      end

      function private:populatePipeTable()
         local stdio = require "posix.stdio"
         local pipes = {}
         for exec_unit_id, exec_unit in pairs(private.execTable) do
            local command = exec_unit.final_command
            local plugin_id = exec_unit.plugin

            if private.debugLogLevelVerbose then
               srDebug("MON Concurrent execution of plugin: "..plugin_id)
               srDebug("MON "..plugin_id.." command: "..command)
            end

            local pipe = io.popen(command)
            local fd = stdio.fileno(pipe)
            pipes[fd] = {
               ["events"] = { IN = true },
               ["exec_unit_id"] = exec_unit_id,
               ["pipe"] = pipe
            }
         end

         return pipes
      end

      function private:processPipe(pipe)
         local exec_unit_id = pipe.exec_unit_id
         local plugin_id = private.execTable[exec_unit_id].plugin

         local raw_output = pipe["pipe"]:read("*a")

         local output, exit_code = private:processRawOutput(raw_output, plugin_id)

         local ms_tbl = private:getMeasurements(output, exec_unit_id)
         private:sendMeasurementsAndAlarms(exec_unit_id, exit_code, ms_tbl, output)
      end

      function private:processRawOutput(raw_output, plugin_id)
         local output_table = {}
         local n = 0
         for line in string.gmatch(raw_output, "([^\r\n]+)") do
            table.insert(output_table, line)
            n = n + 1
         end

         local exit_code
         local output = ""

         if n > 0 then
            exit_code = tonumber(output_table[n])
            if not exit_code then
               srError("MON "..plugin_id
                  ..": Can't extract exit code from line: "..output_table[n])
               exit_code = 100 -- special exit code for this case
            end
            if n > 1 then
               output = table.concat(output_table, ' ', 1, n - 1)
            end
         end

         if private.debugLogLevelVerbose then
            srDebug("MON "..plugin_id.." output: "..output)
            srDebug("MON "..plugin_id.." exit code: "..exit_code)
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
                     exec_unit_id,
                     timestamp,
                     exit_code,
                     c8y_id,
                     alarm_type,
                     private:getAlarmText(exec_unit_id, exit_code, output)
                  )
            elseif (exit_code == 0 and private.noDuplicateAlarms) then
               private:resetAlarm(exec_unit_id, c8y_id, alarm_type)
            end
         end
      end

      --retrieves a timestamp if exists
      function private:getTimestamp(exec_unit, ms_tbl)
         for i=1, #exec_unit.series do
            if (exec_unit.series[i]["use_as_timestamp"]) then
               if not tonumber(ms_tbl[i]) then
                  srError("MON timestamp is not a number")
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
                  srError("MON wrong unit for timestamp")
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

      function private:getAlarmText(exec_unit_id, exit_code, output)
         local plugin_id = private.execTable[exec_unit_id]["plugin"]
         local plugin_tbl = private.pluginsTable[plugin_id]

         if (exit_code == 124 or exit_code == 137) then
            -- a plugin terminated using SIGTERM or SIGKILL
            return "Plugin "..plugin_id.." was terminated due to expired timeout"

         elseif (
               plugin_tbl.alarmtext and
               exit_code == 1 and
               plugin_tbl.alarmtext["warning"] and
               type(plugin_tbl.alarmtext["warning"]) == "string" and
               string.len(plugin_tbl.alarmtext["warning"]) ~= 0
            ) then

            return plugin_tbl.alarmtext["warning"]

         elseif (
               plugin_tbl.alarmtext and
               exit_code > 1 and
               plugin_tbl.alarmtext["critical"] and
               type(plugin_tbl.alarmtext["critical"]) == "string" and
               string.len(plugin_tbl.alarmtext["critical"]) ~= 0
            ) then

            return plugin_tbl.alarmtext["critical"]

         elseif (not output or string.len(output) == 0) then
            if (exit_code == 1) then
               return "Plugin "..plugin_id
                  .." returned WARNING. Output is not available"
            elseif (exit_code > 1)  then
               return "Plugin "..plugin_id
                  .." returned CRITICAL. Output is not available"
            end
         end

         --default is first 128 chars with newline chars replaced with spaces
         local default, n = string.gsub(output:sub(1, 128), '\n' ,' ')
         --quote marks added
         default = string.format("%s%s%s",'"',default,'"')

         return default
      end

      function private:sendAlarm(exec_unit_id, timestamp, exit_code, c8y_id, type, text)
         local severity = exit_code == 1 and "MINOR" or "CRITICAL"

         if private.noDuplicateAlarms
            and private:isAlarmActive(exec_unit_id, c8y_id, type, severity, text) then
            -- do not send the alarm
            return
         end

         http:clear()

         if timestamp then
            if http:post(table.concat({
                  exit_code == 1 and '350' or '351',
                  timestamp,
                  c8y_id,
                  type,
                  text
               }, ',')) <= 0 then return end
         else --no explicit timestamp
            if http:post(table.concat({
                  exit_code == 1 and '344' or '345',
                  c8y_id,
                  type,
                  text
               }, ',')) <= 0 then return end
         end

         local alarm_id = private:processAlarmResponse(http:response(),
            exec_unit_id, c8y_id, type, severity, text)

         if alarm_id ~= nil then
            private:activateAlarm(exec_unit_id, c8y_id, alarm_id, type, severity, text)
         end
      end

      function private:isAlarmActive(exec_unit_id, c8y_id, alarm_type, severity, text)
         local is_alarm_active = false
         local alarms = private.activeAlarmsTable
         local uaotc = private.execTable[exec_unit_id].update_alarm_on_text_change

         local alarm_hash = uaotc and private:getAlarmHash(severity, text)
            or  private:getAlarmHash(severity)

         is_alarm_active = alarms[c8y_id] and alarms[c8y_id][alarm_type]
            and alarms[c8y_id][alarm_type][alarm_hash]

         if is_alarm_active and private.refreshAlarmsNow then
            local alarm_id = alarms[c8y_id][alarm_type][alarm_hash]
            if private:isAlarmCleared(alarm_id) then
               is_alarm_active = false
               alarms[c8y_id][alarm_type] = nil
            end
         end

         return is_alarm_active
      end

      function private:getAlarmHash(...)
         local n = arg.n
         if n == 0 then return end

         local first = arg[1]
         if n == 1 and (type(first) ~= "string" or string.len(first) <= 32) then
            return first
         else
            local md5 = require 'monitoring/util/md5'
            return md5.sumhexa(table.concat(arg,','))
         end
      end

      function private:isAlarmCleared(alarm_id)
         http:clear()

         if http:post(
               string.format("358,"..alarm_id)
            ) <= 0 then return end

         local resp = http:response()

         if string.sub(resp, 1, 3) == '876' then
            local status = string.match(resp, '^%d+,%d+,%d+,%a+,%d+,(%a+),.*$')

            return status == "CLEARED"
         end
      end

      function private:processAlarmResponse(resp, exec_unit_id, c8y_id, type,
         severity, text)

         local uaotc = private.execTable[exec_unit_id].update_alarm_on_text_change
         local alarms = private.activeAlarmsTable

         local alarm_id, severity_resp, count, text_resp

         if string.sub(resp, 1, 3) == '876' then
            alarm_id, severity_resp, count, text_resp =
               string.match(resp, '^%d+,%d+,(%d+),(%a+),(%d+),%a+,(.*)$')
         end

         if not alarm_id then
            srWarning("MON Could not process alarm repsonse of type: "..type)
            return
         end

         if count ~= '1' then
            local update_severity = severity ~= severity_resp
            local update_text = text ~= text_resp and uaotc

            if update_severity and update_text then
               c8y:send(table.concat({
                     '354',
                     alarm_id,
                     severity,
                     text
                  }, ','), 0)
            elseif update_severity and not update_text then
               c8y:send(table.concat({
                     '355',
                     alarm_id,
                     severity
                  }, ','), 0)
            elseif not update_severity and update_text then
               c8y:send(table.concat({
                     '356',
                     alarm_id,
                     text
                  }, ','), 0)
            end
         end

         return alarm_id
      end

      function private:activateAlarm(exec_unit_id, c8y_id, alarm_id, alarm_type, severity, text)
         local alarms = private.activeAlarmsTable
         local uaotc = private.execTable[exec_unit_id].update_alarm_on_text_change

         if not alarms[c8y_id] then
            alarms[c8y_id] = {}
         end

         --this removes info about active alarms same type with different hash (severity, text)
         --as the cumulocity platform normally can have only one active alarm of one type
         alarms[c8y_id][alarm_type] = {}

         local alarm_hash = uaotc and private:getAlarmHash(severity, text)
            or private:getAlarmHash(severity)
         alarms[c8y_id][alarm_type][alarm_hash] = alarm_id
      end

      function private:resetAlarm(exec_unit_id, c8y_id, alarm_type, plugin_alarms_clearing)
         local exec_unit = private.execTable[exec_unit_id]
         local plugin_alarms_clearing = exec_unit.plugin_alarms_clearing
         local global_alarms_clearing = private.clearingAlarmsGlobal
         local alarms = private.activeAlarmsTable

         --if 'alarms clearing' for this exec unit is off and 'no duplicates' is on
         if not global_alarms_clearing or not plugin_alarms_clearing then
            if alarms[c8y_id] and alarms[c8y_id][alarm_type] then
               alarms[c8y_id][alarm_type] = nil
            end
            return
         end

         local just_cleared = false

         if not exec_unit.did_clear_all_alarms then
            --clearing all active or acknowledged alarms of the given type
            private:clearAlarms(c8y_id, alarm_type)
            exec_unit.did_clear_all_alarms = true
            just_cleared = true
         end

         if alarms[c8y_id] and alarms[c8y_id][alarm_type] then
            if not just_cleared then
               for alarm_hash, alarm_id in pairs(alarms[c8y_id][alarm_type]) do
                  c8y:send('313,'..alarm_id, 0)
               end
            end
            alarms[c8y_id][alarm_type] = nil
         end
      end

      function private:clearAlarms(c8y_id, alarm_type)
         http:clear()

         if http:post(
               string.format("357,%s,%s", c8y_id, alarm_type)
            ) <= 0 then return end

         for alarm_id in string.gmatch(http:response(), "808,%d+,(%d+),") do
            c8y:send('313,'..alarm_id, 0)
         end
      end

      function private:runPluginsSequentially()
         for exec_unit_id in pairs(private.execTable) do
            local output, exit_code = private:runExecUnit(exec_unit_id)
            local ms_tbl = private:getMeasurements(output, exec_unit_id)

            private:sendMeasurementsAndAlarms(exec_unit_id, exit_code,
               ms_tbl, output)
         end
      end

      function private:runExecUnit(exec_unit_id)
         local plugin_id = private.execTable[exec_unit_id]["plugin"]
         local command = private.execTable[exec_unit_id]["final_command"]

         if private.debugLogLevelVerbose then
            srDebug("MON Sequential execution of plugin: "..plugin_id)
            srDebug("MON "..plugin_id.." command: "..command)
         end

         local file = io.popen(command)
         local raw_output = file:read("*a")
         file:close()

         return private:processRawOutput(raw_output, plugin_id)
      end

   private:initialize()

   local public = {}

      --public methods
      function public:singleRunOfExecUnits(refresh_alarms_now)
         if private.isInitError then return end

         private.refreshAlarmsNow = refresh_alarms_now

         if private.refreshAlarmsNow then
            srDebug("MON Alarms will be refreshed...")
         end

         if private.pluginsConcurrentExecution then
            private:runPluginsConcurrently()
         else
            private:runPluginsSequentially()
         end
      end

   setmetatable(public,self)
   self.__index = self
   return public
end
