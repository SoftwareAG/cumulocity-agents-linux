local tbl = {}
local agentName = "cumulocity-agent"
local agentVersion = '4.1.0'
local agentUrl = ''

function init()
   updateAgentVersion()
   return 0
end

function updateAgentVersion()
   c8y:send(table.concat({
         '352',
         c8y.ID,
         agentName,
         agentVersion,
         agentUrl
      }, ','), 1)
   srNotice("Agent version: " .. agentVersion)
end
