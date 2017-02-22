local hdmiAlarmActive = nil
local urlAlarmActive = nil
local networkStatus = {}

function init()
    local temperatureTimer = c8y:addTimer(30 * 1000, "sendCpuTemperature")
    local checkUrlTimer = c8y:addTimer(cdb:get('nel.urlcheck.interval') * 1000, "sendUrlAlarm")
    local checkHdmiTimer = c8y:addTimer(30 * 1000, "sendHdmiAlarm")
    local networkTimer = c8y:addTimer(30 * 1000, "sendNetworkUsage")
    c8y:addMsgHandler(808, "handleAlarmsResponse")
    networkStatus["lastTime"] = os.time()
    temperatureTimer:start()
    checkUrlTimer:start()
    checkHdmiTimer:start()
    networkTimer:start()
    return 0
end

function sendNetworkUsage()
    local now = os.time()
    local duration = now - networkStatus.lastTime
    networkStatus.lastTime = now
    for line in io.lines("/proc/net/dev") do
        interface, readBytes, sendBytes = line:match("^%s*(.+):%s+(%d+)%s+%d+%s+%d+%s+%d+%s+%d+%s+%d+%s+%d+%s+%d+%s+(%d+)")
        if interface ~= nil then
            createNetworkMeasurement(interface, readBytes, sendBytes, duration)
            networkStatus[interface .. "_read"] = readBytes
            networkStatus[interface .. "_send"] = sendBytes
        end
    end
end

function createNetworkMeasurement(interface, readBytes, sendBytes, duration)
    if networkStatus[interface .. "_read"] ~= nil then
        downloadRate = (tonumber(readBytes) - tonumber(networkStatus[interface .. "_read"])) / (1000 * duration)
        uploadRate = (tonumber(sendBytes) - tonumber(networkStatus[interface .. "_send"])) / (1000 * duration)
        c8y:send("338," .. c8y.ID .. "," .. interface .. "_download," .. downloadRate .. "," .. interface .. "_upload," .. uploadRate)
    end
end

function handleAlarmsResponse(record)
    local alarmType = record:value(3)
    if (not urlAlarmActive) and alarmType == "c8y_WebsiteUnavailableAlarm" then
        c8y:send("313," .. record:value(2))
    end
    if (not hdmiAlarmActive) and alarmType == "c8y_DisplayUnavailableAlarm" then
        c8y:send("313," .. record:value(2))
    end
end

function sendCpuTemperature()
    local temperature = tonumber(getCpuTemperature()) / 1000
    c8y:send("337," .. c8y.ID .. "," .. temperature)
end

function getCpuTemperature()
    local file = io.open("/sys/class/thermal/thermal_zone0/temp", "r")
    local temperature = file:read("*all")
    file:close()
    return temperature
end

function sendUrlAlarm()
    local success = queryUrl()
    if success then
        urlAlarmActive = false
        c8y:send("311," .. c8y.ID .. ",ACTIVE")
        c8y:send("311," .. c8y.ID .. ",ACKNOWLEDGED")
    else
        urlAlarmActive = true
        c8y:send("312," .. c8y.ID .. ",c8y_WebsiteUnavailableAlarm,MAJOR,Unexpected response from http://www.infonel.de/")
    end
end

function sendHdmiAlarm()
    local success, response = queryDisplay()
    if success then
        hdmiAlarmActive = false
        c8y:send("311," .. c8y.ID .. ",ACTIVE")
        c8y:send("311," .. c8y.ID .. ",ACKNOWLEDGED")
    else
        hdmiAlarmActive = true
        c8y:send("312," .. c8y.ID .. ',c8y_DisplayUnavailableAlarm,MAJOR,"Unexpected display state: ' .. response .. '"')
    end
end

function queryUrl()
    local handle = io.popen('curl -I "http://www.infonel.de/"')
    sleep(1)
    local response = handle:read("*a")
    local success = response:find("HTTP/1.1 200 OK")
    handle:close()
    return success
end

function queryDisplay()
    local handle = io.popen("tvservice -s")
    sleep(1)
    local response = handle:read("*l")
    local success = response == "state 0x120006 [DVI DMT (81) RGB full 16:9], 1366x768 @ 60.00Hz, progressive"
    handle:close()
    return success, response
end

local clock = os.clock
function sleep(n)  -- seconds
    local t0 = clock()
    while clock() - t0 <= n do end
end
