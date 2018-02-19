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
   },

   ["DiskUsageMountedOnRootDisk"] = {
      command="check_disk",
      params="-w 20% -c 10% -p /",
      use_exit_code=true,
      regex="(%d+%.?%d*)%%",
      series={
         {name="free", unit="%"}
      },
   },

   ["ProcessesCount"] = {
      command="check_procs",
      params="-w 300 -c 400",
      use_exit_code=true,
      regex="(%d+)%s*process",
      series={
         {name="count", unit=""}
      },
   },

   ["SystemUptime"] = {
      command="check_uptime.sh",
      params="600",
      use_exit_code=true,
      regex="(%d+)%s*s",
      series={
         {name="time", unit="s"}
      },
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
   },

   ["CepAvailability"] = {
      command="check_http",
      params="-j GET -H %H% -u /cep/health -w 5 -c 10 -f follow -s UP",
      use_exit_code=true,
      regex="time=(%d+.?%d-)s.+size=(%d+)B",
      series={
         {name="response_time", unit="s"},
         {name="size", unit="B"},
      },
   },

   ["WebappDeviceManagementAvailability"] = {
      command="check_http",
      params="-j GET -H %H% -u /apps/devicemanagement/index.html -w 5 -c 10 -S -f follow",
      use_exit_code=true,
      regex="time=(%d+.?%d-)s.+size=(%d+)B",
      series={
         {name="response_time", unit="s"},
         {name="size", unit="B"},
      },
   },

   ["WebappDeviceCockpitAvailability"] = {
      command="check_http",
      params="-j GET -H %H% -u /apps/cockpit/index.html -w 5 -c 10 -S -f follow",
      use_exit_code=true,
      regex="time=(%d+.?%d-)s.+size=(%d+)B",
      series={
         {name="response_time", unit="s"},
         {name="size", unit="B"},
      },
   },

   ["WebappDeviceAdministrationAvailability"] = {
      command="check_http",
      params="-j GET -H %H% -u /apps/administration/index.html -w 5 -c 10 -S -f follow",
      use_exit_code=true,
      regex="time=(%d+.?%d-)s.+size=(%d+)B",
      series={
         {name="response_time", unit="s"},
         {name="size", unit="B"},
      },
   },

   ["ContentAvailability"] = {
      command="check_http",
      params="-w 5 -c 10 --ssl -H %H%",
      use_exit_code=true,
      regex="time=(%d+.?%d-)s.+size=(%d+)B",
      series={
         {name="response_time", unit="s"},
         {name="size", unit="B"},
      },
   },

   ["CumulocityApiTests"] = {
      command="testc8yapi.py",
      params="%H% %T% %U% %P%",
      use_exit_code=true,
      regex="Ran %d+ tests in (%d+%.?%d-)s",
      series={
         {name="time", unit="s"},
      },
   },

   ["CumulocityApiResponse"] = {
      command="c8yApiResponse.py",
      params="%H% %T% %U% %P%",
      use_exit_code=true,
      regex="Average response time: (%d+%.?%d-)ms",
      series={
         {name="CumulocityApiResponse", unit="ms"},
      },
   },

}