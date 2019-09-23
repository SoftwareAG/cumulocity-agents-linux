local tbl = {}
local agentName = "cumulocity-agent"
local agentVersion = '2.1.8'
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
