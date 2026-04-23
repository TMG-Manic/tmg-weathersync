local TMGCore = exports['tmg-core']:GetCoreObject()

local CurrentWeather = Config.StartWeather
local lastWeather = CurrentWeather
local baseTime = Config.BaseTime
local timeOffset = Config.TimeOffset
local freezeTime = Config.FreezeTime
local blackout = Config.Blackout
local blackoutVehicle = Config.BlackoutVehicle
local disable = Config.Disabled or false

RegisterNetEvent('TMGCore:Client:OnPlayerLoaded', function()
    SetTimeout(math.random(200, 1000), function()
        TriggerServerEvent('tmg-weathersync:server:RequestStateSync')
    end)
end)

RegisterNetEvent('tmg-weathersync:client:EnableSync', function()
    if not disable then return end 
    
    disable = false
    
    TriggerServerEvent('tmg-weathersync:server:RequestStateSync')
    
    TMGCore.Functions.Notify("Mainframe Weather Sync: ENABLED", "success")
end)

RegisterNetEvent('tmg-weathersync:client:DisableSync', function()
    disable = true
    
    SetRainLevel(0.0)
    SetForceVehicleTrails(false)
    SetForcePedFootstepsTracks(false)
    
    SetArtificialLightsState(false)
    SetArtificialLightsStateAffectsVehicles(false)
    
    ClearOverrideWeather()
    ClearWeatherTypePersist()
    SetWeatherTypePersist('EXTRASUNNY')
    SetWeatherTypeNow('EXTRASUNNY')
    SetWeatherTypeNowPersist('EXTRASUNNY')
    
    NetworkOverrideClockTime(18, 0, 0)
    
    TMGCore.Functions.Notify("Mainframe Weather Sync: DISABLED (Environment Purged)", "error")
end)

RegisterNetEvent('tmg-weathersync:client:SyncWeather', function(NewWeather, newblackout)
    if CurrentWeather == NewWeather and blackout == newblackout then return end

    CurrentWeather = NewWeather
    blackout = newblackout

    SetWeatherTypeOverTime(CurrentWeather, 15.0)
    
    SetArtificialLightsState(blackout)
    SetArtificialLightsStateAffectsVehicles(Config.BlackoutVehicle)

    if CurrentWeather == 'XMAS' then
        SetForceVehicleTrails(true)
        SetForcePedFootstepsTracks(true)
    else
        SetForceVehicleTrails(false)
        SetForcePedFootstepsTracks(false)
    end

    if CurrentWeather == 'RAIN' then
        SetRainLevel(0.3)
    elseif CurrentWeather == 'THUNDER' then
        SetRainLevel(0.5)
    else
        SetRainLevel(0.0)
    end
    if Config.Debug then
        print(string.format("^5[TMG Mainframe]^7 Weather synced to: ^2%s^7 | Blackout: ^2%s^7", CurrentWeather, tostring(blackout)))
    end
end)

RegisterNetEvent('tmg-weathersync:client:SyncTime', function(base, offset, freeze)
    freezeTime = freeze
    timeOffset = offset
    baseTime = base

    if not disable then
        local totalMinutes = baseTime + timeOffset
        local hour = math.floor((totalMinutes / 60) % 24)
        local minute = math.floor(totalMinutes % 60)
        
        NetworkOverrideClockTime(hour, minute, 0)
    end

    if Config.Debug then
        print(string.format("^3[TMG Mainframe]^7 Time Synced: ^2%02d:%02d^7 | Frozen: ^2%s^7", 
            math.floor(((baseTime + timeOffset) / 60) % 24), 
            math.floor((baseTime + timeOffset) % 60), 
            tostring(freezeTime)
        ))
    end
end)

local function ApplyWeatherEffects(weather, isBlackout)
    SetArtificialLightsState(isBlackout)
    SetArtificialLightsStateAffectsVehicles(Config.BlackoutVehicle)

    local isSnow = (weather == 'XMAS')
    SetForceVehicleTrails(isSnow)
    SetForcePedFootstepsTracks(isSnow)

    if weather == 'RAIN' then 
        SetRainLevel(0.3)
    elseif weather == 'THUNDER' then 
        SetRainLevel(0.5)
    else 
        SetRainLevel(0.0) 
    end
end

CreateThread(function()
    while true do
        if not disable then
            if lastWeather ~= CurrentWeather then
                lastWeather = CurrentWeather
                
                SetWeatherTypeOverTime(CurrentWeather, 15.0)
                
                ApplyWeatherEffects(CurrentWeather, blackout)
                
                Wait(15000) 
            end

            ClearOverrideWeather()
            ClearWeatherTypePersist()
            SetWeatherTypePersist(lastWeather)
            SetWeatherTypeNow(lastWeather)
            SetWeatherTypeNowPersist(lastWeather)
            
            Wait(5000) 
        else
            Wait(1000)
        end
    end
end)


CreateThread(function()
    local hour, minute, second = 0, 0, 0
    local lastTick = GetGameTimer()
    local decimalSecond = 0.0

    while true do
        if not disable then
            Wait(100) 
            
            local currentTick = GetGameTimer()
            local delta = currentTick - lastTick
            lastTick = currentTick

            if Config.RealTimeSync then
                local _, _, _, hours, minutes, seconds = GetLocalTime()
                hour, minute, second = hours, minutes, seconds
            else
                local totalMinutes = baseTime + timeOffset
                hour = math.floor((totalMinutes / 60) % 24)
                minute = math.floor(totalMinutes % 60)

                if not freezeTime then
                    decimalSecond = decimalSecond + (delta / 1000) * (60 / (Config.MinuteDuration or 2))
                    if decimalSecond >= 60 then decimalSecond = 0 end
                    second = math.floor(decimalSecond)
                else
                    second = 0
                    decimalSecond = 0
                end
            end

            NetworkOverrideClockTime(hour, minute, second)
        else
            Wait(1000)
        end
    end
end)
