package.path = package.path .. ';/snap/cumulocity-agent/current/usr/share/lua/5.2/?.lua'
package.cpath = package.cpath .. ';/snap/cumulocity-agent/current/usr/lib/x86_64-linux-gnu/lua/5.2/?.so'

local socket = require("socket")
local sock
local codev = {}
local cotype = {}
local alarms = {}
local Type
local transmitTimer, pollTimer
local keyPollingRate = 'canopen.pollingRate'
local keyTransmitRate = 'canopen.transmitRate'
local keyBaud = 'canopen.baud'
local keyPort = 'canopen.port'
local keyNode = 'canopen.nodeID'

local function rfind(tbl, index, subIndex)
   for i, Reg in ipairs(tbl) do
      if Reg[1] == index and Reg[2] == subIndex then
         return i
      end
   end
end


local function rinsert(tbl, index, subIndex, idx, item)
   local i = #tbl
   while i > 0 and (tbl[i][1] ~= index or tbl[i][2] ~= subIndex) do
         i = i - 1
   end
   tbl[i][idx] = item
end


local function bitrate2ascii(baud)
   local baudtbl = {[10] = 's0', [20] = 's1', [50] = 's2',
      [100] = 's3', [125] = 's4', [250] = 's5', [500] = 's6',
      [800] = 's7', [1000] = 's8'}
   baud = math.floor(baud / 1000)
   return baudtbl[baud] or 's0'
end


local function setupCAN()
   local canType = cdb:get('canopen.type')
   local canPort = cdb:get('canopen.port')
   local baud = tonumber(cdb:get('canopen.baud')) * 1000
   local cmd
   if canType == 'vcan' then
      cmd = 'modprobe vcan'
      os.execute(cmd)
      srInfo('canopen: ' .. cmd)
      cmd = 'ip link add dev ' .. canPort .. ' type vcan'
      os.execute(cmd)
      srInfo('canopen: ' .. cmd)
   elseif canType == 'can' then
      cmd = 'ip link set ' .. canPort .. ' type can bitrate ' .. baud
      os.execute(cmd)
      srInfo('canopen: ' .. cmd)
   elseif canType == 'slcan' then
      cmd = 'modprobe can'
      os.execute(cmd)
      srInfo('canopen: ' .. cmd)
      cmd = 'modprobe can-raw'
      os.execute(cmd)
      srInfo('canopen: ' .. cmd)
      cmd = 'modprobe slcan'
      os.execute(cmd)
      srInfo('canopen: ' .. cmd)
      local serial = cdb:get('canopen.serial')
      local ascii = bitrate2ascii(baud)
      local fmt = 'cumulocity-agent.slcan-attach -f -%s -n %s -o %s'
      cmd = string.format(fmt, ascii, canPort, serial)
      os.execute(cmd)
      srInfo('canopen: ' .. cmd)
      fmt = 'cumulocity-agent.slcand %s %s'
      cmd = string.format(fmt, string.sub(serial, 6), canPort)
      os.execute(cmd)
      srInfo('canopen: ' .. cmd)
   end
   cmd = 'ip link set up ' .. canPort
   os.execute(cmd)
   srInfo('canopen: ' .. cmd)
end


local function getDataType(datatype)
   local Type, bits = string.match(datatype, '([a-z]+)(%d*)')
   local first = string.sub(Type, 1, 1)
   if first == 'r' then
      return 'real' .. bits
   elseif first == 'u' then
      return 'unsigned' .. bits
   elseif first == 'i' or first == 's' then
      return 'signed' .. bits
   elseif first == 'b' then
      return 'boolean'
   end
end


function init()
   sock = socket.udp()
   sock:setsockname("*", 9678)
   sock:setpeername("127.0.0.1", 9677)
   sock:settimeout(2)
   c8y:addMsgHandler(855, 'addDevice')
   c8y:addMsgHandler(856, 'removeDevice')
   c8y:addMsgHandler(857, 'addDevice')
   c8y:addMsgHandler(858, 'useServerTime')
   c8y:addMsgHandler(859, 'addRegister')
   c8y:addMsgHandler(860, 'addRegisterAlarm')
   c8y:addMsgHandler(861, 'addRegisterEvent')
   c8y:addMsgHandler(862, 'addRegisterMeasurement')
   c8y:addMsgHandler(863, 'addRegisterStatus')
   c8y:addMsgHandler(864, 'setCanopenConf')
   c8y:addMsgHandler(865, 'setOp')
   c8y:addMsgHandler(866, 'setCanopenConf')
   c8y:addMsgHandler(867, 'clearRegAlarm')
   c8y:addMsgHandler(868, 'setRegister')
   c8y:addMsgHandler(869, 'setRegister')
   c8y:addMsgHandler(870, 'clearAlarm')
   c8y:addMsgHandler(871, 'setOp')
   c8y:addMsgHandler(873, 'executeShell')
   local transmitRate = tonumber(cdb:get(keyTransmitRate)) or 60
   local pollingRate = tonumber(cdb:get(keyPollingRate)) or 15
   local baud = tonumber(cdb:get(keyBaud)) or 125
   local port = cdb:get(keyPort) or 'can0'
   local nodeID = tonumber(cdb:get(keyNode)) or 119
   transmitTimer = c8y:addTimer(transmitRate * 1000, 'transmit')
   pollTimer = c8y:addTimer(pollingRate * 1000, 'poll')
   c8y:send('323,' .. c8y.ID)
   local tbl = {'346', c8y.ID, pollingRate, transmitRate, baud}
   c8y:send(table.concat(tbl, ','))

   setupCAN()
   local msg = table.concat({'startCan', port, nodeID, baud}, ' ')
   srInfo('canopen: ' .. msg)
   sock:send(msg)
   msg = sock:receive() or 'timeout'
   srInfo('canopen: ' .. msg)
   return 0
end


function addDevice(r)
   if r:value(0) == '855' then
      c8y:send('303,' .. r:value(2) .. ',EXECUTING', 1)
   end
   local oft = r:value(0) == '855' and 3 or 2
   local ID, nodeId = r:value(oft), r:value(oft+1)
   Type = tonumber(string.match(r:value(oft + 2), '/(%d+)$'))
   local msg = 'addNode ' .. nodeId .. ' ' .. Type
   srInfo('canopen: ' .. msg)
   sock:send(msg)
   msg = sock:receive() or 'timeout'
   srInfo('canopen: ' .. msg)
   if not codev[nodeId] then
      codev[nodeId] = {ID, Type, {}, {}}
      c8y:send('311,' .. ID .. ',ACTIVE')
      c8y:send('311,' .. ID .. ',ACKNOWLEDGED')
      c8y:send('314,' .. ID .. ',PENDING')
   end
   if not cotype[Type] then
      cotype[Type] = {false, {}}
      c8y:send('309,' .. Type)
   end
   if r:value(0) == '855' then
      c8y:send('303,' .. r:value(2) .. ',SUCCESSFUL', 1)
   end
   pollTimer:start()
   transmitTimer:start()
end


function useServerTime(r)
   if r:value(3) == 'canopen' then
      flag = r:value(4) == 'true' and true or false
      Type = tonumber(r:value(2))
      cotype[Type][1] = flag
   end
end


function addRegister(r)
   if not Type then return end
   index, sub = tonumber(r:value(2)), tonumber(r:value(3))
   dataType, attr = r:value(4), r:value(5)
   item = {index, sub, dataType, attr, nil, nil, nil, nil}
   table.insert(cotype[Type][2], item)
   local msg = string.format('addReg %d %d %d %s', Type, index, sub, dataType)
   srDebug('canopen: ' .. msg)
   sock:send(msg)
   msg = sock:receive() or 'timeout'
   srDebug('canopen: ' .. msg)
end


function addRegisterAlarm(r)
   if not Type then return end
   index, subIndex = tonumber(r:value(2)), tonumber(r:value(3))
   alarm, mask = tonumber(r:value(4)), tonumber(r:value(5))
   rinsert(cotype[Type][2], index, subIndex, 5, {alarm, mask})
end


function addRegisterEvent(r)
   if not Type then return end
   index, subIndex = tonumber(r:value(2)), tonumber(r:value(3))
   event = tonumber(r:value(4))
   rinsert(cotype[Type][2], index, subIndex, 6, event)
end


function addRegisterMeasurement(r)
   if not Type then return end
   index, subIndex = tonumber(r:value(2)), tonumber(r:value(3))
   measurement = tonumber(r:value(4))
   rinsert(cotype[Type][2], index, subIndex, 7, measurement)
end


function addRegisterStatus(r)
   if not Type then return end
   index, subIndex = tonumber(r:value(2)), tonumber(r:value(3))
   status = r:value(4)
   rinsert(cotype[Type][2], index, subIndex, 8, status)
end


local function getTimestamp()
   local x = os.date('!*t')
   local fmt = '%d-%02d-%02dT%02d:%02d:%02d+00:00'
   return string.format(fmt, x.year, x.month, x.day, x.hour, x.min, x.sec)
end


local function sockpoll()
   srDebug('canopen: poll')
   sock:send('poll')
   local isAlarm = {}
   for node, dev in pairs(codev) do isAlarm[node] = false end
   local line = sock:receive()
   while line do
      srDebug('canopen: ' .. line)
      local fmt = "(%S+) (%d+) (%d+) (%d+) (.+)"
      local req, node, index, subIndex, rem = string.match(line, fmt)
      if node and index and subIndex and rem and codev[node] then
         local dev = codev[node]
         if req == 'sdo' then
            local key = index * 256 + subIndex
            local value = rem
            if dev[3][key] ~= value then
               dev[3][key] = value
               dev[4][key] = true
            end
         elseif req == 'sdoError' then
            if not alarms[node] then
               local msg = {'347', getTimestamp(), dev[1], node,
                            string.format('0x%x', index), subIndex, rem}
               c8y:send(table.concat(msg, ','), 1)
               alarms[node] = true
            end
            isAlarm[node] = true
         else
            srWarning('canopen: unknown response ' .. line)
         end
      end
      line = sock:receive()
   end
   for node, flag in pairs(isAlarm) do
      if not flag and alarms[node] then
         alarms[node] = false
         c8y:send('311,' .. codev[node][1] .. ',ACTIVE', 1)
         c8y:send('311,' .. codev[node][1] .. ',ACKNOWLEDGED', 1)
      end
   end
end


local function sendMsg(msgs, ID, MyTyp, serverTime)
   local tbl = {}
   if msgs['101'] then
      local s = '101,' .. ID .. ',' .. table.concat(msgs['101'], ',')
      table.insert(tbl, s)
      msgs['101'] = nil
   end
   for msgid, vals in pairs(msgs) do
      local s = msgid .. ',' .. ID
      if not serverTime then s = s .. ',' .. getTimestamp() end
      if #vals > 0 then s = s .. ',' .. table.concat(vals, ',') end
      table.insert(tbl, s)
   end
   if #tbl >= 1 then
      tbl[1] = MyTyp .. ',' .. tbl[1]
      c8y:send(table.concat(tbl, '\n'), 2)
   end
end


function transmit()
   for nodeID, V in pairs(codev) do
      local ID, MyTyp, Vals, _ = unpack(V)
      local tbl = {}
      for _, reg in ipairs(cotype[MyTyp][2]) do
         local measurement = reg[7]
         local val = Vals[reg[1] * 256 + reg[2]]
         if measurement and val then
            if tbl[measurement] then
               table.insert(tbl[measurement], val)
            else
               tbl[measurement] = {val}
            end
         end
      end
      sendMsg(tbl, ID, MyTyp, cotype[MyTyp][1])
   end
end


function poll()
   sockpoll()
   for nodeID, V in pairs(codev) do
      local ID, MyTyp, Vals, Flags = unpack(V)
      local tbl, clearAlarm = {}, false
      tbl['101'] = {}
      for _, reg in ipairs(cotype[MyTyp][2]) do
         local key = reg[1] * 256 + reg[2]
         local val = Vals[key]
         if not val then return end

         local event, measurement, status = reg[6], reg[7], reg[8]
         if status then table.insert(tbl['101'], val) end
         if Flags[key] then
            if reg[5] then
               local alarm, mask = unpack(reg[5])
               local value = tonumber(val)
               if bitAnd(value, mask) ~= 0 then tbl[alarm] = {}
               else clearAlarm = true
               end
            end
            if event then tbl[event] = {val} end
            Flags[key] = false
         end
      end
      if clearAlarm then
         c8y:send('311,' .. ID .. ',ACTIVE', 1)
         c8y:send('311,' .. ID .. ',ACKNOWLEDGED', 1)
      end
      sendMsg(tbl, ID, MyTyp, cotype[MyTyp][1])
   end
end


function setCanopenConf(r)
   local opid, baud = r:value(2), r:value(3)
   local pollrate, transmitrate = r:value(4), r:value(5)
   local msg = table.concat({'canopen: setConf poll', pollrate, 'transmit',
                             transmitrate, 'baud', baud}, ' ')
   srInfo(msg)
   c8y:send('303,' .. opid .. ',EXECUTING')
   msg = 'setBaud ' .. baud
   srInfo('canopen: ' .. msg)
   sock:send(msg)
   msg = sock:receive() or 'setBaudError timeout'
   srInfo('canopen: ' .. msg)
   local errMsg = string.match(msg, 'setBaudError (.+)')
   if errMsg then
      c8y:send('304,' .. opid .. ',' .. errMsg)
      return
   end
   transmitTimer.interval = transmitrate * 1000
   pollTimer.interval = pollrate * 1000
   transmitTimer:start()
   pollTimer:start()
   c8y:send(string.format('346,%d,%d,%d,%d', c8y.ID,
                          pollrate, transmitrate, baud))
   local fpath = cdb:get("datapath") .. '/cumulocity-agent.conf'
   cdb:set(keyBaud, baud)
   cdb:set(keyPollingRate, pollrate)
   cdb:set(keyTransmitRate, transmitrate)
   cdb:save(fpath)
   srInfo('canopen: save conf ' .. fpath)
   c8y:send('303,' .. opid .. ',SUCCESSFUL')
end


function removeDevice(r)
   local opid, node, id = r:value(2), r:value(3), r:value(4)
   codev[node] = nil
   alarms[node] = nil
   local msg = 'removeNode ' .. node
   srInfo('canopen: ' .. msg)
   sock:send(msg)
   msg = sock:receive() or 'timeout'
   srInfo('canopen: ' .. msg)
   c8y:send('303,' .. opid .. ',SUCCESSFUL', 1)
end


function setRegister(r)
   local opid = r:value(2)
   local node, index, subIndex = r:value(3), r:value(4), r:value(5)
   local value, dataType = r:value(6), r:value(7)
   local fmt = 'wrSdo %d %d %d %s %s'
   c8y:send('303,' .. opid .. ',EXECUTING', 1)
   local msg = string.format(fmt, node, index, subIndex, dataType, value)
   srInfo('canopen: ' .. msg)
   sock:send(msg)
   msg = sock:receive() or 'wrSdoError 0 0 0 recv timeout'
   if msg == 'wrSdo OK' then
      srInfo('canopen: ' .. msg)
      c8y:send('303,' .. opid .. ',SUCCESSFUL', 1)
   else
      srError('canopen: ' .. msg)
      fmt = 'wrSdoError %d+ %d+ %d+ (.+)'
      local errMsg = string.match(msg, fmt)
      c8y:send('304,' .. opid .. ',' .. errMsg, 1)
   end
end


function clearAlarm(r)
   local alarmId, alarmType, node = r:value(2), r:value(3), r:value(4)
   if alarmType == 'c8y_CANopenAvailabilityAlarm' and not alarms[node] then
      c8y:send('313,' .. alarmId)
   end
end


function setOp(r)
   if r:value(0) == '865' or r:value(0) == '871' then
      c8y:send('303,' .. r:value(2) .. ',SUCCESSFUL')
   end
end


function clearRegAlarm(r)
   local alarmId, alarmType = r:value(2), r:value(3)
   local index, subIndex = tonumber(r:value(4)), tonumber(r:value(5))
   local ID = r:value(6)
   local node = findNodeId(ID)
   if not node then return end
   local key = index * 256 + subIndex
   local MyType, value = cotype[codev[node][2]], codev[node][3][key]
   if not value then return end
   local idx = rfind(MyType[2], index, subIndex)
   if not idx then return end
   local mask = MyType[2][idx][5][2]
   if not mask then return end
   if bitAnd(value, mask) == 0 then
      c8y:send('313,' .. alarmId)
   end
end


function executeShell(r)
   operationId, deviceId, text = r:value(2), r:value(3), r:value(4)
   if deviceId == c8y.ID then return end
   c8y:send('303,' .. operationId .. ',EXECUTING')
   srInfo('CANopen shell command received: id: ' .. operationId .. ', deviceId: ' .. deviceId .. ', text: "' .. text .. '"')
   success, result = pcall(function ()
      line = parseShellCommand(text)
      if line['command'] == 'write' then
         return executeWrite(line, deviceId)
      elseif line['command'] == 'read' then
         return executeRead(line, deviceId)
      elseif line['command'] == 'info' then
         return executeInfo(line, deviceId)
      end
   end)
   if success then
      srInfo("CANopen shell command '" .. operationId .. "' successfully completed")
      c8y:send('310,' .. operationId .. ',SUCCESSFUL,"' .. text .. '","' .. result ..'"')
   else
      srInfo("CANopen shell command '" .. operationId .. "' failed with result '" .. (result or 'nil') .. "'")
      c8y:send('310,' .. operationId .. ',FAILED,"' .. text .. '","' .. (result or 'nil') ..'"')
   end
end

function parseShellCommand(text)
   firstWord = string.match(text, '^%w+')
   line = {}
   line['command'] = verifyCommand(firstWord)
   srDebug("Found command word '" .. line['command'] .. "'")
   if string.find(text, ',') then
      srDebug('Parsing named parameters')
      parseNamed(text, line)
   else
      srDebug('Parsing enumerated parameters')
      parseEnumerated(text, line)
   end
   verifyParameters(line)
   return line
end

function verifyParameters(line)
   if (line['command'] == 'write') then
      verifyContains(line, 'index')
      verifyContains(line, 'subindex')
      verifyContains(line, 'datatype')
      verifyContains(line, 'value')
   elseif (line['command'] == 'read') then
      verifyContains(line, 'index')
      verifyContains(line, 'subindex')
      verifyContains(line, 'datatype')
   elseif (line['command'] == 'info') then
      verifyContains(line, 'value')
   end
end

function verifyContains(line, parameter)
   if not line[parameter] then
      error(line['command'] .. " command missing parameter '" .. parameter .. "'")
   end
end

function parseNamed(text, line)
   first, last, key, value = string.find(text, '(%w+)=(%w+)')
   while (key and value) do
      srDebug(key .. '=' .. value)
      line[key] = value
      first, last, key, value = string.find(text, '(%w+)=(%w+)', last)
   end
end

function parseEnumerated(text, line)
   split = {}
   for segment in string.gmatch(text, '%g+') do
      table.insert(split, segment)
   end
   srDebug('Parsed ' .. #split .. ' segments')
   if (line['command'] == 'write') then
      line['index'] = split[2]
      line['subindex'] = split[3]
      line['datatype'] = split[4]
      line['value'] = split[5]
   elseif (line['command'] == 'read') then
      line['index'] = split[2]
      line['subindex'] = split[3]
      line['datatype'] = split[4]
   elseif (line['command'] == 'info') then
      line['value'] = split[2]
   end
end

function verifyCommand(word)
   if word == 'w' or word == 'write' then
      return 'write'
   elseif word == 'r' or word == 'read' then
      return 'read'
   elseif word == 'i' or word == 'info' then
      return 'info'
   else
      error("Invalid command word '" .. (word or 'nil') .. "'")
   end
end

function findNodeId(deviceId)
   for nodeId, canDevice in pairs(codev) do
      if canDevice[1] == deviceId then
         srDebug("Found node ID " .. nodeId .. ' for device ' .. deviceId)
         return nodeId
      end
   end
   srInfo("Node ID for device " .. deviceId .. " unknown")
   error("Cannot find Node ID for device ID '" .. (deviceId or 'nil') .. "'")
end


function executeWrite(command, deviceId)
   nodeId = findNodeId(deviceId)
   local index = tonumber(command['index'])
   local subIndex = tonumber(command['subindex'])
   local dataType = getDataType(command['datatype'])
   local value = command['value']
   local fmt = 'wrSdo %d %d %d %s %s'
   sock:send(string.format(fmt, nodeId, index, subIndex, dataType, value))
   line = sock:receive()
   verifyResponseExists(line)
   if string.find(line, 'wrSdo OK') then
      srDebug("Value successfully written")
      return executeRead(command, deviceId)
   end
    first, last, errorCode, errorMsg = string.find(line, 'wrSdoError%s+%w+%s+%w+%s+%w+%s+(%w+)%s+(.+)')
    error("Writing register failed with code '" .. (errorCode or 'nil') .. "' and message '" .. (errorMsg or 'nil') .. "'")
end


function executeRead(command, deviceId)
   nodeId = findNodeId(deviceId)
   local index = tonumber(command['index'])
   local subIndex = tonumber(command['subindex'])
   local dataType = getDataType(command['datatype'])
   local fmt = 'rdSdo %d %d %d %s'
   sock:send(string.format(fmt, nodeId, index, subIndex, dataType))
   line = sock:receive()
   verifyResponseExists(line)
   first, last, value = string.find(line, 'rdSdo%s+%w+%s+%w+%s+%w+%s+(.+)')
   if value then
      srDebug("Read value: " .. value)
      return value
   end
   first, last, errorCode, errorMsg = string.find(line, 'rdSdoError%s+%w+%s+%w+%s+%w+%s+(%w+)%s+(.+)')
   error("Reading register failed with code '" .. (errorCode or 'nil') .. "' and message '" .. (errorMsg or 'nil') .. "'")
end

function verifyResponseExists(line)
   if line then
      srDebug("CANopen service response: '" .. line .. "'")
   else
      srInfo("No response from CANopen service")
      error("No response from CANopen service",2)
   end
end

function executeInfo(command, deviceId)
   if command['value'] == 'id' then
      return findNodeId(deviceId)
   elseif command['value'] == 'bitrate' then
      return cdb:get(keyBaud) .. ' kbit/s'
   elseif command['value'] == 'sdo_timeout' then
      nodeId = findNodeId(deviceId)
      sock:send(string.format('rdSdoTimeout %d', nodeId))
      line = sock:receive()
      verifyResponseExists(line)
      first, last, value = string.find(line, 'rdSdoTimeout%s+(%w+)')
      if value then
         return value .. " ms"
      end
      first, last, errorCode, errorMsg = string.find(line, 'rdSdoTimeoutError%s+%w+%s+(%w+)%s+(.+)')
      error("Reading SDO timeout failed with code '" .. (errorCode or 'nil') .. "' and message '" .. (errorMsg or 'nil') .. "'")
   end
   error("Unknown info command")
end
