-- File with plugins
return {

   ["CpuUsage"] = {
      command="check_cpu.pl",
      params="-w 85 -c 95",
      use_exit_code=true,
      regex="%s(%d+%.?%d*)%%",
      series={
         {name="workload", unit="%"}
      },
      update_alarm_on_text_change=true,
   },

   ["DiskUsageMountedOnRootDisk"] = {
      command="check_disk",
      params="-w 20% -c 10% -p /",
      use_exit_code=true,
      regex="(%d+%.?%d*)%%",
      series={
         {name="free", unit="%"}
      },
      update_alarm_on_text_change=true,
   },

   ["ProcessesCount"] = {
      command="check_procs",
      params="-w 300 -c 400",
      use_exit_code=true,
      regex="(%d+)%s*process",
      series={
         {name="count", unit=""}
      },
      update_alarm_on_text_change=true,
   },

   ["SystemUptime"] = {
      command="check_uptime.sh",
      params="600",
      use_exit_code=true,
      regex="(%d+)%s*s",
      series={
         {name="time", unit="s"}
      },
      update_alarm_on_text_change=true,
   },

   ["SwapUsage"] = {
      command="check_swap",
      params="-w 20% -c 3%",
      use_exit_code=true,
      regex="(%d+)%s*%%%D*%((%d+)%s*MB%D*(%d+)%s*MB%s*%)",
      series={
         {name="free", unit="%"},
         {name="used", unit="MB"},
         {name="total", unit="MB"},
      },
      update_alarm_on_text_change=true,
   },

   ["CepAvailability"] = {
      command="check_http",
      params="-j GET -H %H% -u /cep/health -w 5 -c 10 -f follow -s UP",
      use_exit_code=true,
      regex="time=(%d+%.?%d-)s.+size=(%d+)B",
      series={
         {name="response_time", unit="s"},
         {name="size", unit="B"},
      },
      update_alarm_on_text_change=true,
   },

   ["WebappDeviceManagementAvailability"] = {
      command="check_http",
      params="-j GET -H %H% -u /apps/devicemanagement/index.html -w 5 -c 10 -S -f follow",
      use_exit_code=true,
      regex="time=(%d+%.?%d-)s.+size=(%d+)B",
      series={
         {name="response_time", unit="s"},
         {name="size", unit="B"},
      },
      update_alarm_on_text_change=true,
   },

   ["WebappDeviceCockpitAvailability"] = {
      command="check_http",
      params="-j GET -H %H% -u /apps/cockpit/index.html -w 5 -c 10 -S -f follow",
      use_exit_code=true,
      regex="time=(%d+%.?%d-)s.+size=(%d+)B",
      series={
         {name="response_time", unit="s"},
         {name="size", unit="B"},
      },
      update_alarm_on_text_change=true,
   },

   ["WebappDeviceAdministrationAvailability"] = {
      command="check_http",
      params="-j GET -H %H% -u /apps/administration/index.html -w 5 -c 10 -S -f follow",
      use_exit_code=true,
      regex="time=(%d+%.?%d-)s.+size=(%d+)B",
      series={
         {name="response_time", unit="s"},
         {name="size", unit="B"},
      },
      update_alarm_on_text_change=true,
   },

   ["ContentAvailability"] = {
      command="check_http",
      params="-w 5 -c 10 --ssl -H %H%",
      use_exit_code=true,
      regex="time=(%d+%.?%d-)s.+size=(%d+)B",
      series={
         {name="response_time", unit="s"},
         {name="size", unit="B"},
      },
      update_alarm_on_text_change=true,
   },

   ["CumulocityApiTests"] = {
      command="testc8yapi.py",
      params="%H% %T% %U% %P%",
      use_exit_code=true,
      regex="Ran %d+ tests in (%d+%.?%d-)s",
      series={
         {name="execution_time", unit="s"},
      },
      update_alarm_on_text_change=true,
   },

   ["CumulocityApiResponse"] = {
      command="c8yApiResponse.py",
      params="%H% %T% %U% %P%",
      use_exit_code=true,
      regex="Average response time: (%d+%.?%d-)ms",
      series={
         {name="response_time", unit="ms"},
      },
      update_alarm_on_text_change=true,
   },

   -- for debugging
   ["ValueWithTimestampInSeconds"] = {
      command="simulation/valueWithTimestamp_sec.lua",
      regex="(%d+%.?%d-)%D+(%d+%.?%d-)%D-$",
      series={
         {use_as_timestamp=true, unit="s"},
         {name="value"}
      },
      update_alarm_on_text_change=true,
   },

   -- for debugging
   ["ValueWithTimestampInMilliseconds"] = {
      command="simulation/valueWithTimestamp_ms.lua",
      regex="(%d+%.?%d-)%D+(%d+%.?%d-)%D-$",
      series={
         {use_as_timestamp=true, unit="ms"},
         {name="value"}
      },
      update_alarm_on_text_change=true,
   },

   -- for debugging
   ["NoSeriesMeasurement"] = {
      command="simulation/noSeriesMeasurement.lua",
      params="",
      use_exit_code=true,
      update_alarm_on_text_change=true,
      alarmtext={
         warning="This is OSCILLATING measurement with ALARMS CLEARING ON",
         critical="This is OSCILLATING measurement with ALARMS CLEARING ON"
      },
   },

   -- for debugging
   ["NoSeriesMeasurementNALC"] = { -- NALC = No ALarms Clearing
      command="simulation/noSeriesMeasurement.lua",
      params="",
      use_exit_code=true,
      no_alarms_clearing=true,
      update_alarm_on_text_change=true,
      alarmtext={
         warning="This is OSCILLATING measurement with ALARMS CLEARING OFF",
         critical="This is OSCILLATING measurement with ALARMS CLEARING OFF"
      },
   },

   -- for debugging
   ["TestPluginsTimeout"] = {
      command="simulation/suspending.lua",
      params="",
      use_exit_code=true,
      update_alarm_on_text_change=true,
      alarmtext={
         warning="Some Warning Alarm text",
         critical="Plugin's timeout expired"
      },
   },

   -- for debugging
   ["AlarmUpdateSeverityAndText"] = {
      command="simulation/alarmUpdateAll.lua",
      use_exit_code=true,
      update_alarm_on_text_change=true,
   },

   -- for debugging
   ["AlarmUpdateSeverityAndTextAndIgnoreText"] = {
      command="simulation/alarmUpdateAll.lua",
      use_exit_code=true,
      update_alarm_on_text_change=false
   },

   -- for debugging
   ["AlarmUpdateTextOnly"] = {
      command="simulation/alarmUpdateText.lua",
      use_exit_code=true,
      update_alarm_on_text_change=true,
   },

   -- for debugging
   ["AlarmUpdateSeverityOnly"] = {
      command="simulation/alarmUpdateAll.lua",
      use_exit_code=true,
      update_alarm_on_text_change=true,
      alarmtext={
         warning="This is PERMANENT alarm which changes SEVERITY only",
         critical="This is PERMANENT alarm which changes SEVERITY only"
      },
   },

}
