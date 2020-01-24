-- File with hosts
return {

   ["localhost"] = {
      plugins_to_run={
         "CpuUsage",
         "DiskUsageMountedOnRootDisk",
         "SystemUptime",
         "ProcessesCount",
         "SwapUsage",

         -- for debugging
         "ValueWithTimestampInSeconds",
         "ValueWithTimestampInMilliseconds",
         "NoSeriesMeasurement",
         "NoSeriesMeasurementNALC",
         -- "TestPluginsTimeout",
         "AlarmUpdateSeverityAndText",
         "AlarmUpdateSeverityAndTextAndIgnoreText",
         "AlarmUpdateTextOnly",
         "AlarmUpdateSeverityOnly",
      }
   },

   --example of monitoring of a remote host
   ["www.google.com"] = {
      plugins_to_run={
         "ContentAvailability",
      },
      is_child_device=true,
   },

}
