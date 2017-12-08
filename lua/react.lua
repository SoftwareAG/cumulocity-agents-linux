function init()
    local interval = loadInterval()
    local measurementTimer = c8y:addTimer(interval * 1000, "createStartMeasurement")
    measurementTimer:start()
    c8y:addMsgHandler(854, 'handleReactOperation')
    return 0
end

function loadInterval()
    local interval = cdb:get('react.measurement.interval.seconds')
    if type(interval) == 'string' and interval:len() > 0 then
        interval = tonumber(interval)
    else
        interval = 60
    end
    srInfo('React interval is ' .. interval)
    return interval
end

function createStartMeasurement()
    local nanos = currentNanos()
    c8y:send('337,' .. c8y.ID .. ',' .. nanos)
end

function currentNanos()
    local handle = io.popen('date -u +%s%N')
    local nanos = handle:read('*n')
    handle:close()
    return nanos
end

function handleReactOperation(record)
    local operationId = record:value(2)
    local startNanos = tonumber(record:value(3))
    local duration = (currentNanos() - startNanos) / 1000000000.0
    createDurationMeasurement(duration)
    setOperationSuccessful(operationId)
end

function createDurationMeasurement(duration)
    c8y:send('338,' .. c8y.ID .. ',' .. duration)
end

function setOperationSuccessful(operationId)
    c8y:send('303,' .. operationId .. ',SUCCESSFUL')
end