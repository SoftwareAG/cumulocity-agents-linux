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
         -- "ValueWithTimestampInSeconds",
         -- "ValueWithTimestampInMilliseconds",
         -- "FloatValueMeasurement",
         -- "NoSeriesMeasurement",
         -- "NoSeriesMeasurementNALC",
         -- "NoSeriesMeasurementNoCustomAlarmText",
         -- "TestPluginsTimeout",
         -- "AlarmUpdateSeverityAndText",
         -- "AlarmUpdateSeverityAndTextAndIgnoreText",
         -- "AlarmUpdateTextOnly",
         -- "AlarmUpdateSeverityOnly",
      }
   },

   -- example of monitoring of a remote host
   -- ["www.google.com"] = {
   --    plugins_to_run={
   --       "ContentAvailability",
   --    },
   --    is_child_device=true,
   -- },

}
