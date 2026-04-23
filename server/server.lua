local TMGCore = exports['tmg-core']:GetCoreObject()
local CurrentWeather = Config.StartWeather
local baseTime = Config.BaseTime
local timeOffset = Config.TimeOffset
local freezeTime = Config.FreezeTime
local blackout = Config.Blackout
local newWeatherTimer = Config.NewWeatherTimer




local function getSource(src)
    return src == '' and 0 or src
end




local function isAllowedToChange(src)
    return src == 0 or TMGCore.Functions.HasPermission(src, "admin") or IsPlayerAceAllowed(src, 'command')
end



local function shiftToMinute(minute)
    timeOffset = timeOffset - (((baseTime + timeOffset) % 60) - minute)
end



local function shiftToHour(hour)
    timeOffset = timeOffset - ((((baseTime + timeOffset) / 60) % 24) - hour) * 60
end


local function nextWeatherStage()
    if CurrentWeather == "CLEAR" or CurrentWeather == "CLOUDS" or CurrentWeather == "EXTRASUNNY" then
        CurrentWeather = (math.random(1, 5) > 2) and "CLEARING" or "OVERCAST" 
    elseif CurrentWeather == "CLEARING" or CurrentWeather == "OVERCAST" then
        local new = math.random(1, 6)
        if new == 1 then CurrentWeather = (CurrentWeather == "CLEARING") and "FOGGY" or "RAIN"
        elseif new == 2 then CurrentWeather = "CLOUDS"
        elseif new == 3 then CurrentWeather = "CLEAR"
        elseif new == 4 then CurrentWeather = "EXTRASUNNY"
        elseif new == 5 then CurrentWeather = "SMOG"
        else CurrentWeather = "FOGGY"
        end
    elseif CurrentWeather == "THUNDER" or CurrentWeather == "RAIN" then CurrentWeather = "CLEARING"
    elseif CurrentWeather == "SMOG" or CurrentWeather == "FOGGY" then CurrentWeather = "CLEAR"
    else CurrentWeather = "CLEAR"
    end
    TriggerEvent("tmg-weathersync:server:RequestStateSync")
end




local function setWeather(weather)
    local validWeatherType = false
    for _, weatherType in pairs(Config.AvailableWeatherTypes) do
        if weatherType == string.upper(weather) then
            validWeatherType = true
        end
    end
    if not validWeatherType then return false end
    CurrentWeather = string.upper(weather)
    newWeatherTimer = Config.NewWeatherTimer
    TriggerEvent('tmg-weathersync:server:RequestStateSync')
    return true
end





local function setTime(hour, minute)
    local argh = tonumber(hour)
    local argm = tonumber(minute) or 0
    if argh == nil or argh > 24 then
        print(Lang:t('time.invalid'))
        return false
    end
    shiftToHour((argh < 24) and argh or 0)
    shiftToMinute((argm < 60) and argm or 0)
    print(Lang:t('time.change', {value = argh, value2 = argm}))
    TriggerEvent('tmg-weathersync:server:RequestStateSync')
    return true
end




local function setBlackout(state)
    if state == nil then state = not blackout end
    if state then blackout = true
    else blackout = false end
    TriggerEvent('tmg-weathersync:server:RequestStateSync')
    return blackout
end




local function setTimeFreeze(state)
    if state == nil then state = not freezeTime end
    if state then freezeTime = true
    else freezeTime = false end
    TriggerEvent('tmg-weathersync:server:RequestStateSync')
    return freezeTime
end




local function setDynamicWeather(state)
    if state == nil then state = not Config.DynamicWeather end
    if state then Config.DynamicWeather = true
    else Config.DynamicWeather = false end
    TriggerEvent('tmg-weathersync:server:RequestStateSync')
    return Config.DynamicWeather
end


local function retrieveTimeFromApi(callback)
    Citizen.CreateThread(function()
        local apiKey = "REPLACE_ME_TO_YOUR_API" 
        local zone = "America/Los_Angeles" 
        local url = "http://api.timezonedb.com/v2.1/get-time-zone?key=" .. apiKey .. "&format=json&by=zone&zone=" .. zone
        
        PerformHttpRequest(url, function(statusCode, response)
            if statusCode == 200 and response then
                local data = json.decode(response)
                if data and data.timestamp then
                    callback(data.timestamp)
                    return
                end
            end
            callback(nil)
        end, "GET", nil, nil)
    end)
end


RegisterNetEvent('tmg-weathersync:server:RequestStateSync', function()
    TriggerClientEvent('tmg-weathersync:client:SyncWeather', -1, CurrentWeather, blackout)
    TriggerClientEvent('tmg-weathersync:client:SyncTime', -1, baseTime, timeOffset, freezeTime)
end)

RegisterNetEvent('tmg-weathersync:server:setWeather', function(weather)
    local src = getSource(source)
    if isAllowedToChange(src) then
        local success = setWeather(weather)
        if src > 0 then
            if (success) then TriggerClientEvent('TMGCore:Notify', src, Lang:t('weather.updated'))
            else TriggerClientEvent('TMGCore:Notify', src, Lang:t('weather.invalid'))
            end
        end
    end
end)

RegisterNetEvent('tmg-weathersync:server:setTime', function(hour, minute)
    local src = getSource(source)
    if isAllowedToChange(src) then
        local success = setTime(hour, minute)
        if src > 0 then
            if (success) then TriggerClientEvent('TMGCore:Notify', src, Lang:t('time.change', {value = hour, value2 = minute or "00"}))
            else TriggerClientEvent('TMGCore:Notify', src, Lang:t('time.invalid'))
            end
        end
    end
end)

RegisterNetEvent('tmg-weathersync:server:toggleBlackout', function(state)
    local src = getSource(source)
    if isAllowedToChange(src) then
        local newstate = setBlackout(state)
        if src > 0 then
            if (newstate) then TriggerClientEvent('TMGCore:Notify', src, Lang:t('blackout.enabled'))
            else TriggerClientEvent('TMGCore:Notify', src, Lang:t('blackout.disabled'))
            end
        end
    end
end)

RegisterNetEvent('tmg-weathersync:server:toggleFreezeTime', function(state)
    local src = getSource(source)
    if isAllowedToChange(src) then
        local newstate = setTimeFreeze(state)
        if src > 0 then
            if (newstate) then TriggerClientEvent('TMGCore:Notify', src, Lang:t('time.now_frozen'))
            else TriggerClientEvent('TMGCore:Notify', src, Lang:t('time.now_unfrozen'))
            end
        end
    end
end)

RegisterNetEvent('tmg-weathersync:server:toggleDynamicWeather', function(state)
    local src = getSource(source)
    if isAllowedToChange(src) then
        local newstate = setDynamicWeather(state)
        if src > 0 then
            if (newstate) then TriggerClientEvent('TMGCore:Notify', src, Lang:t('weather.now_unfrozen'))
            else TriggerClientEvent('TMGCore:Notify', src, Lang:t('weather.now_frozen'))
            end
        end
    end
end)


TMGCore.Commands.Add('freezetime', Lang:t('help.freezecommand'), {}, false, function(source)
    local newstate = setTimeFreeze()
    if source > 0 then
        if (newstate) then return TriggerClientEvent('TMGCore:Notify', source, Lang:t('time.frozenc')) end
        return TriggerClientEvent('TMGCore:Notify', source, Lang:t('time.unfrozenc'))
    end
    if (newstate) then return print(Lang:t('time.now_frozen')) end
    return print(Lang:t('time.now_unfrozen'))
end, 'admin')

TMGCore.Commands.Add('freezeweather', Lang:t('help.freezeweathercommand'), {}, false, function(source)
    local newstate = setDynamicWeather()
    if source > 0 then
        if (newstate) then return TriggerClientEvent('TMGCore:Notify', source, Lang:t('dynamic_weather.enabled')) end
        return TriggerClientEvent('TMGCore:Notify', source, Lang:t('dynamic_weather.disabled'))
    end
    if (newstate) then return print(Lang:t('weather.now_unfrozen')) end
    return print(Lang:t('weather.now_frozen'))
end, 'admin')

TMGCore.Commands.Add('weather', Lang:t('help.weathercommand'), {{name = Lang:t('help.weathertype'), help = Lang:t('help.availableweather')}}, true, function(source, args)
    local success = setWeather(args[1])
    if source > 0 then
        if (success) then return TriggerClientEvent('TMGCore:Notify', source, Lang:t('weather.willchangeto', {value = string.lower(args[1])})) end
        return TriggerClientEvent('TMGCore:Notify', source, Lang:t('weather.invalidc'), 'error')
    end
    if (success) then return print(Lang:t('weather.updated')) end
    return print(Lang:t('weather.invalid'))
end, 'admin')

TMGCore.Commands.Add('blackout', Lang:t('help.blackoutcommand'), {}, false, function(source)
    local newstate = setBlackout()
    if source > 0 then
        if (newstate) then return TriggerClientEvent('TMGCore:Notify', source, Lang:t('blackout.enabledc')) end
        return TriggerClientEvent('TMGCore:Notify', source, Lang:t('blackout.disabledc'))
    end
    if (newstate) then return print(Lang:t('blackout.enabled')) end
    return print(Lang:t('blackout.disabled'))
end, 'admin')

TMGCore.Commands.Add('morning', Lang:t('help.morningcommand'), {}, false, function(source)
    setTime(9, 0)
    if source > 0 then return TriggerClientEvent('TMGCore:Notify', source, Lang:t('time.morning')) end
end, 'admin')

TMGCore.Commands.Add('noon', Lang:t('help.nooncommand'), {}, false, function(source)
    setTime(12, 0)
    if source > 0 then return TriggerClientEvent('TMGCore:Notify', source, Lang:t('time.noon')) end
end, 'admin')

TMGCore.Commands.Add('evening', Lang:t('help.eveningcommand'), {}, false, function(source)
    setTime(18, 0)
    if source > 0 then return TriggerClientEvent('TMGCore:Notify', source, Lang:t('time.evening')) end
end, 'admin')

TMGCore.Commands.Add('night', Lang:t('help.nightcommand'), {}, false, function(source)
    setTime(23, 0)
    if source > 0 then return TriggerClientEvent('TMGCore:Notify', source, Lang:t('time.night')) end
end, 'admin')

TMGCore.Commands.Add('time', Lang:t('help.timecommand'), {{ name=Lang:t('help.timehname'), help=Lang:t('help.timeh') }, { name=Lang:t('help.timemname'), help=Lang:t('help.timem') }}, true, function(source, args)
    local success = setTime(args[1], args[2])
    if source > 0 then
        if (success) then return TriggerClientEvent('TMGCore:Notify', source, Lang:t('time.changec', {value = args[1] .. ':' .. (args[2] or "00")})) end
        return TriggerClientEvent('TMGCore:Notify', source, Lang:t('time.invalidc'), 'error')
    end
    if (success) then return print(Lang:t('time.change', {value = args[1], value2 = args[2] or "00"})) end
    return print(Lang:t('time.invalid'))
end, 'admin')


CreateThread(function()
    local previous = 0
    local realTimeFromApi = nil
    local failedCount = 0

    while true do
        Wait(60000) 
        local newBaseTime = os.time(os.date("!*t")) / 2 + 360 
        if Config.RealTimeSync then
            retrieveTimeFromApi(function(unixTime)
                if unixTime then
                    baseTime = unixTime
                else
                    baseTime = os.time(os.date("!*t"))
                end
            end)
        else
            baseTime = os.time(os.date("!*t")) / 2 + 360
        end        
    end
end)

CreateThread(function()
    while true do
        Wait(2000)
        TriggerClientEvent('tmg-weathersync:client:SyncTime', -1, baseTime, timeOffset, freezeTime)
    end
end)

CreateThread(function()
    while true do
        Wait(300000)
        TriggerClientEvent('tmg-weathersync:client:SyncWeather', -1, CurrentWeather, blackout)
    end
end)

CreateThread(function()
    while true do
        newWeatherTimer = newWeatherTimer - 1
        Wait((1000 * 60) * Config.NewWeatherTimer)
        if newWeatherTimer == 0 then
            if Config.DynamicWeather then
                nextWeatherStage()
            end
            newWeatherTimer = Config.NewWeatherTimer
        end
    end
end)


exports('nextWeatherStage', nextWeatherStage)
exports('setWeather', setWeather)
exports('setTime', setTime)
exports('setBlackout', setBlackout)
exports('setTimeFreeze', setTimeFreeze)
exports('setDynamicWeather', setDynamicWeather)
exports('getBlackoutState', function() return blackout end)
exports('getTimeFreezeState', function() return freezeTime end)
exports('getWeatherState', function() return CurrentWeather end)
exports('getDynamicWeather', function() return Config.DynamicWeather end)

exports('getTime', function()
    local hour = math.floor(((baseTime+timeOffset)/60)%24)
    local minute = math.floor((baseTime+timeOffset)%60)

    return hour,minute
end)
