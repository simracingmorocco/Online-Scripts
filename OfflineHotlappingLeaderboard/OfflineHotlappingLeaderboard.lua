
DataFile = ac.INIConfig.load(ac.getFolder(ac.FolderID.ACApps) .. "/lua/OfflineHotlappingLeaderboard/Data/" .. ac.getCarID(0) .. "_" .. ac.getTrackFullID("_") .. ".ini", ac.INIFormat.Extended)
if ac.getSim().penaltiesEnabled and ac.getSim().raceSessionType == 4 then
    DataFile:save()
end

math.randomseed(os.preciseClock())

local NewLap = false
local NewLapDone = true
local AutopilotLapTimer = DataFile:get("AILap", "AIBestLapTime", nil)
if AutopilotLapTimer then AutopilotLapTimer = tonumber(AutopilotLapTimer[1]) end
local PlayerLapTimer = DataFile:get("PlayerLap", "PlayerBestLapTime", nil)
if PlayerLapTimer then PlayerLapTimer = tonumber(PlayerLapTimer[1]) end

local AutopilotLap = false
local RefreshLeaderboardTimer = 5
local RefreshLeaderboardProgress = 0


function table_append(appendTarget, appendData)
    for _, value in pairs(appendData) do
        table.insert(appendTarget, value)
    end
end

function table_copy(tbl)
	local copy = {}
	for key, value in pairs(tbl) do
		copy[key] = value
	end
	return copy
end

function string_formatTime(seconds, hidehours, hideminutes, hideseconds)
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local miliseconds = math.floor(seconds*1000 % 1000)
    local seconds = math.floor(seconds % 60)
    local hoursString = tostring(hours)
    local minutesString = tostring(minutes)
    local secondsString = tostring(seconds)
    local milisecondsString = tostring(miliseconds)
    if miliseconds < 10 then
        milisecondsString = "00" .. milisecondsString
    elseif miliseconds < 100 then
        milisecondsString = "0" .. milisecondsString
    end
    if seconds < 10 and ((minutes > 1 or not hideminutes) or (hours > 1 or not hidehours)) then
        secondsString = "0" .. secondsString
    end
    if minutes < 10 and (hours > 0 or not hidehours) then
        minutesString = "0" .. minutesString
    end
    if hours > 0 or not hidehours then
        return hoursString .. ":" .. minutesString .. ":" .. secondsString .. "." .. milisecondsString
    elseif minutes > 0 or not hideminutes then
        return minutesString .. ":" .. secondsString .. "." .. milisecondsString
    else
        return secondsString .. "." .. milisecondsString
    end
end

-- Driver Names Collection
NameDir = '/Names'
NameFiles = table.map(io.scanDir( __dirname .. NameDir, '*'), function (x) return { string.sub(x, 1, #x - 4), NameDir .. '/' .. x } end)
NamesList = {}
for i = 1, #NameFiles do
    table_append(NamesList, require("Names/" .. NameFiles[i][1]))
end

local previousSessionStartTimer = 0
Timer = 0

function RefreshDrivers()
    GlobalLeaderboard = stringify.parse(DataFile:get("AINames", "Leaderboard", "{}"))
    for _ = 1,math.random(1,5) do
        local name = NamesList[math.random(1,#NamesList)]
        local randomtime = math.random(math.floor(math.min(PlayerLapTimer/1.01, AutopilotLapTimer/1.08)), math.ceil(AutopilotLapTimer/0.9))
        if not GlobalLeaderboard[name] or (GlobalLeaderboard[name] and GlobalLeaderboard[name] > randomtime) then
            GlobalLeaderboard[name] = randomtime
        end
        RefreshLeaderboardTimer = math.random(50,70)
        RefreshLeaderboardProgress = 0
    end
    GlobalLeaderboardSorted = {}
    for index, key in pairs(GlobalLeaderboard) do
        GlobalLeaderboardSorted[#GlobalLeaderboardSorted + 1] = {laptime = key, name = index}
        table.sort(GlobalLeaderboardSorted, function(a,b) return a.laptime < b.laptime end)
    end

    repeat 
        local name = NamesList[math.random(1,#NamesList)]
        local randomtime = math.random(math.floor(math.min(PlayerLapTimer/1.01, AutopilotLapTimer/1.08)), math.ceil(AutopilotLapTimer/0.9))
        if not GlobalLeaderboard[name] or (GlobalLeaderboard[name] and GlobalLeaderboard[name] > randomtime) then
            GlobalLeaderboard[name] = randomtime
        end
        GlobalLeaderboardSorted = {}
        for index, key in pairs(GlobalLeaderboard) do
            GlobalLeaderboardSorted[#GlobalLeaderboardSorted + 1] = {laptime = key, name = index}
            table.sort(GlobalLeaderboardSorted, function(a,b) return a.laptime < b.laptime end)
        end
        untilrandom = math.random(20,150)
    until #GlobalLeaderboardSorted > untilrandom

    GlobalLeaderboardSorted[#GlobalLeaderboardSorted + 1] = {laptime = PlayerLapTimer, name = "aaa-insert-player-name-here-aaa"}
    table.sort(GlobalLeaderboardSorted, function(a,b) return a.laptime < b.laptime end)
    ac.log(GlobalLeaderboardSorted)
    local stringifiedleaderboard = stringify(GlobalLeaderboard, true, 1000000)
    DataFile:setAndSave("AINames", "Leaderboard", stringifiedleaderboard)
end

function script.update(dt)
    if ac.getSim().penaltiesEnabled and ac.getSim().raceSessionType == 4 and (not ac.getSim().isReplayActive)then
        Timer = Timer + dt

        if previousSessionStartTimer < ac.getSim().timeToSessionStart-1 then
            SessionSwitched = true
            Timer = 0
        elseif SessionSwitched then
            SessionSwitched = false
            NewLap = false
            NewLapDone = false
            physics.setCarAutopilot(false)
        end
    
        if RefreshLeaderboardTimer >= 0 then
            RefreshLeaderboardTimer = RefreshLeaderboardTimer - dt
        end
    
        if RefreshLeaderboardTimer <= 0 then
            RefreshLeaderboardProgress = RefreshLeaderboardProgress + (dt*math.random())
        end
    
        if RefreshLeaderboardTimer <= 0 and RefreshLeaderboardProgress >= 2 then
            RefreshLeaderboardTimer = math.random(50,70)
        end

        if ac.getCar(0).isAIControlled then
            AutopilotEnabled = true
        else
            AutopilotEnabled = false
            AutopilotLap = false
        end

        if NewLap == false and NewLapDone == false and ac.getCar(0).lapTimeMs <= 1000 then
            NewLap = true
        end

        if ac.getCar(0).lapTimeMs > 1000 then
            NewLapDone = false
        end

        if NewLap and not NewLapDone then
            ac.log("New Lap", Timer)
            if AutopilotLap and not DataFile:get("AILap", "Calibrated", nil) then
                if (not AutopilotLapTimer or AutopilotLapTimer > ac.getCar(0).previousLapTimeMs) and ac.getCar(0).previousLapTimeMs ~= 0 then
                    AutopilotLapTimer = ac.getCar(0).previousLapTimeMs
                    DataFile:setAndSave("AILap", "AIBestLapTime", AutopilotLapTimer)
                    DataFile:setAndSave("AILap", "Calibrated", true)
                end
            elseif ac.getCar(0).isLastLapValid then
                if not PlayerLapTimer or PlayerLapTimer > ac.getCar(0).previousLapTimeMs then
                    PlayerLapTimer = ac.getCar(0).previousLapTimeMs
                    DataFile:setAndSave("PlayerLap", "PlayerBestLapTime", PlayerLapTimer)
                end
            end

            if AutopilotEnabled then
                AutopilotLap = true
            else
                AutopilotLap = false
            end

            if ac.getCar(0).isInPitlane then
                if physics.allowed() then
                    physics.markLapAsSpoiled(0)
                end
                ac.markLapAsSpoiled(false)
            end

            if PlayerLapTimer and AutopilotLapTimer then
                RefreshLeaderboardTimer = 0
                RefreshLeaderboardProgress = 0
            end

            NewLap = false
            NewLapDone = true
        end

        if PlayerLapTimer and AutopilotLapTimer and RefreshLeaderboardTimer <= 0 and RefreshLeaderboardProgress >= 1 then
            RefreshDrivers()
        end

        physics.setAIThrottleLimit(0, 0.80)
        physics.setAILevel(0, 0.95)
        physics.setAISteerMultiplier(0, 2)
        physics.setExtraAIGrip(0, 1.2)

        --if ac.getCar(0).speedKmh < 50 then
        --    physics.setAILookaheadBase(0, 20)
        --    physics.setAILookaheadGasBrake(0, 50)
        --    physics.setAIBrakeHint(0, 0.5)
        --end

        ac.debug("AutopilotEnabled", AutopilotEnabled)
        ac.debug("AutopilotLap", AutopilotLap)
        ac.debug("AutopilotLapTimer", AutopilotLapTimer)
    end
end

function script.windowMedals()
    if AutopilotLapTimer and ac.getSim().penaltiesEnabled and ac.getSim().raceSessionType == 4 then
        ui.text(ac.getTrackName())
        ui.separator()
        
        local master = math.floor((AutopilotLapTimer/1.07)/10)/100
        local gold = math.floor((AutopilotLapTimer/1.04)/10)/100
        local silver = math.floor(AutopilotLapTimer/10)/100
        local bronze = math.floor((AutopilotLapTimer/0.95)/10)/100
        if master%1 ~= 0 then
            master = master .. "0"
        end
        if gold%1 ~= 0 then
            gold = gold .. "0"
        end
        if silver%1 ~= 0 then
            silver = silver .. "0"
        end
        if bronze%1 ~= 0 then
            bronze = bronze .. "0"
        end
        ac.debug("AutopilotLapTimer", AutopilotLapTimer)
        ac.debug("master", master)
        ac.debug("gold", gold)
        ac.debug("silver", silver)
        ac.debug("bronze", bronze)
        local personalbest = nil
        if PlayerLapTimer then
            personalbest = PlayerLapTimer/1000
        end
        if personalbest and personalbest < tonumber(master) then
            ui.text("Personal Best")
            ui.sameLine(110)
            ui.text(string_formatTime(personalbest, true))
        end
        ui.textColored("Master", rgbm(0, 1, 0, 1))
        ui.sameLine(110)
        if personalbest and personalbest < tonumber(gold) then
            ui.text(string_formatTime(master, true))
            if personalbest then
                ui.sameLine(180)
                local split = -(personalbest - tonumber(master))
                if split < 0 then
                    ui.textColored("-" .. string_formatTime(-split, true, true), rgbm(1, 0, 0, 1))
                else
                    ui.textColored("+" .. string_formatTime(split, true, true), rgbm(0.2, 0.8, 1, 1))
                end
            end
        else
            ui.text("-:--.---")
        end
        if personalbest and personalbest < tonumber(gold) and personalbest > tonumber(master) then
            ui.text("Personal Best")
            ui.sameLine(110)
            ui.text(string_formatTime(personalbest, true))
        end
        ui.textColored("Gold", rgbm(1, 1, 0, 1))
        ui.sameLine(110)
        ui.text(string_formatTime(gold, true))
        if personalbest then
            ui.sameLine(180)
            local split = -(personalbest - tonumber(gold))
            if split < 0 then
                ui.textColored("-" .. string_formatTime(-split, true, true), rgbm(1, 0, 0, 1))
            else
                ui.textColored("+" .. string_formatTime(split, true, true), rgbm(0.2, 0.8, 1, 1))
            end
        end
        if personalbest and personalbest < tonumber(silver) and personalbest > tonumber(gold) then
            ui.text("Personal Best")
            ui.sameLine(110)
            ui.text(string_formatTime(personalbest, true))
        end
        ui.textColored("Silver", rgbm(0.8, 0.8, 0.8, 1))
        ui.sameLine(110)
        ui.text(string_formatTime(silver, true))
        if personalbest then
            ui.sameLine(180)
            local split = -(personalbest - tonumber(silver))
            if split < 0 then
                ui.textColored("-" .. string_formatTime(-split, true, true), rgbm(1, 0, 0, 1))
            else
                ui.textColored("+" .. string_formatTime(split, true, true), rgbm(0.2, 0.8, 1, 1))
            end
        end
        if personalbest and personalbest < tonumber(bronze) and personalbest > tonumber(silver) then
            ui.text("Personal Best")
            ui.sameLine(110)
            ui.text(string_formatTime(personalbest, true))
        end
        ui.textColored("Bronze", rgbm(0.8, 0.5, 0, 1))
        ui.sameLine(110)
        ui.text(string_formatTime(bronze, true))
        if personalbest then
            ui.sameLine(180)
            local split = -(personalbest - tonumber(bronze))
            if split < 0 then
                ui.textColored("-" .. string_formatTime(-split, true, true), rgbm(1, 0, 0, 1))
            else
                ui.textColored("+" .. string_formatTime(split, true, true), rgbm(0.2, 0.8, 1, 1))
            end
        end
        if personalbest and personalbest > tonumber(bronze) then
            ui.text("Personal Best")
            ui.sameLine(110)
            ui.text(string_formatTime(personalbest, true))
        end
        if not personalbest then
            ui.text("Personal Best")
            ui.sameLine(110)
            ui.text("-:--.---")
        end
        if not ac.getCar(0).isLapValid then
            ui.textColored("Invalid Lap", rgbm(1,0,0,1))
        end
        if ac.getCar(0).isAIControlled then
            ui.button("A")
            if ui.itemClicked(ui.MouseButton.Left, false) then
                physics.setCarAutopilot(false)
                DataFile:setAndSave("AILap", "Calibrated", true)
            end
            ui.sameLine(50)
            ui.text("Toggle Autopilot")
        end
    elseif ac.getSim().penaltiesEnabled and ac.getSim().raceSessionType == 4 then
        ui.text(ac.getTrackName())
        ui.separator()
        ui.text()
        ui.text("Medals need to be calibrated")
        ui.text("Turn on autopilot and wait for it to complete a full lap")
        
        if ac.getCar(0).isAIControlled then
            if AutopilotLap then
                ui.textColored("Calibration Lap In Progress", rgbm(0,1,0,1))
                
            else
                ui.textColored("Waiting For Calibration Lap To Start", rgbm(1,1,0,1))
            end
        else
            ui.textColored("Autopilot is not enabled", rgbm(1,0,0,1))
        end
        ui.button("A")
        if ui.itemClicked(ui.MouseButton.Left, false) then
            physics.setCarAutopilot(not ac.getCar(0).isAIControlled)
        end
        ui.sameLine(50)
        ui.text("Toggle Autopilot")
    elseif ac.getSim().raceSessionType == 4 then
        ui.text(ac.getTrackName())
        ui.separator()
        ui.text()
        ui.text("Penalties are not enabled")
        ui.text("Please Enable Penalties")
        ui.text()
        ui.text()
    else
        ui.text(ac.getTrackName())
        ui.separator()
        ui.text()
        ui.text("Not in hotlap mode")
        ui.text("Please run the game in Hotlap mode")
        ui.text()
        ui.text()
    end
end

function script.windowRecords()
    if AutopilotLapTimer and ac.getSim().penaltiesEnabled and ac.getSim().raceSessionType == 4 then
        if RefreshLeaderboardProgress == 0 and RefreshLeaderboardTimer >= 0 and GlobalLeaderboardSorted and #GlobalLeaderboardSorted > 1 then
            for i = 1,#GlobalLeaderboardSorted do
                local driverName = GlobalLeaderboardSorted[i].name
                if driverName == "aaa-insert-player-name-here-aaa" then driverName = ac.getDriverName(0) end

                if driverName == ac.getDriverName(0) then
                    ui.text("Position: " .. i .. "/" .. #GlobalLeaderboardSorted)
                    ui.separator()
                    PlayerPosition = i
                    break
                end
            end

            for i = 1,#GlobalLeaderboardSorted do
                local driverName = GlobalLeaderboardSorted[i].name
                if driverName == "aaa-insert-player-name-here-aaa" then driverName = ac.getDriverName(0) end
                if i <= 5 then
                    ui.text(i .. ". " .. driverName)
                    ui.sameLine(200)
                    ui.text(string_formatTime(math.floor(GlobalLeaderboardSorted[i].laptime)/1000, true))
                    local split = -(PlayerLapTimer/1000 - tonumber(GlobalLeaderboardSorted[i].laptime/1000))
                    if split < 0 then
                        ui.sameLine(265)
                        ui.textColored("-" .. string_formatTime(-split, true, true), rgbm(1, 0, 0, 1))
                    elseif split > 0 then
                        ui.sameLine(265)
                        ui.textColored("+" .. string_formatTime(split, true, true), rgbm(0.2, 0.8, 1, 1))
                    end
                    if i == 5 and PlayerPosition >= 9 then
                        ui.separator()
                    end
                end
            end
            for i = 1,#GlobalLeaderboardSorted do
                if GlobalLeaderboardSorted[i].name == "aaa-insert-player-name-here-aaa" then
                    for j = -3, 3 do
                        j = -j
                        if GlobalLeaderboardSorted[i-j] then
                            local driverName = GlobalLeaderboardSorted[i-j].name
                            if driverName == "aaa-insert-player-name-here-aaa" then driverName = ac.getDriverName(0) end
                            if i-j > 5 then
                                ui.text(i-j .. ". " .. driverName)
                                ui.sameLine(200)
                                ui.text(string_formatTime(math.floor(GlobalLeaderboardSorted[i-j].laptime)/1000, true))
                                local split = -(PlayerLapTimer/1000 - tonumber(GlobalLeaderboardSorted[i-j].laptime/1000))
                                if split < 0 then
                                    ui.sameLine(265)
                                    ui.textColored("-" .. string_formatTime(-split, true, true), rgbm(1, 0, 0, 1))
                                elseif split > 0 then
                                    ui.sameLine(265)
                                    ui.textColored("+" .. string_formatTime(split, true, true), rgbm(0.2, 0.8, 1, 1))
                                end
                            end
                        end
                    end
                end
            end
        elseif RefreshLeaderboardTimer <= 0 and RefreshLeaderboardProgress < 1 then
            ui.text("Refreshing... " .. math.ceil(RefreshLeaderboardProgress*100) .. "%")
        elseif PlayerLapTimer then
            ui.text("Connecting to records service.")
        else
            ui.text("Post a personal best time to show your position on the leaderboard.")
        end
    elseif ac.getSim().penaltiesEnabled and ac.getSim().raceSessionType == 4 then
        ui.text()
        ui.text("Times need to be calibrated")
        ui.text("Turn on autopilot and wait for it to complete a full lap")
        
        if ac.getCar(0).isAIControlled then
            if AutopilotLap then
                ui.textColored("Calibration Lap In Progress", rgbm(0,1,0,1))
                
            else
                ui.textColored("Waiting For Calibration Lap To Start", rgbm(1,1,0,1))
            end
        else
            ui.textColored("Autopilot is not enabled", rgbm(1,0,0,1))
        end
        ui.button("A")
        if ui.itemClicked(ui.MouseButton.Left, false) then
            physics.setCarAutopilot(not ac.getCar(0).isAIControlled)
        end
        ui.sameLine(50)
        ui.text("Toggle Autopilot")
    elseif ac.getSim().raceSessionType == 4 then
        ui.text()
        ui.text("Penalties are not enabled")
        ui.text("Please Enable Penalties")
        ui.text()
        ui.text()
    else
        ui.text()
        ui.text("Not in hotlap mode")
        ui.text("Please run the game in Hotlap mode")
        ui.text()
        ui.text()
    end
end

function script.windowSettings()
    ui.button("R")
    ui.sameLine(50)
    ui.text("Reset Times For This Car and Track")
    if ui.itemClicked(ui.MouseButton.Left, false) then
        DataFile:setAndSave("AILap", "AIBestLapTime", nil)
        AutopilotLapTimer = nil
        DataFile:setAndSave("PlayerLap", "PlayerBestLapTime", nil)
        PlayerLapTimer = nil
        DataFile:setAndSave("AILap", "Calibrated", nil)
        DataFile:setAndSave("AINames", "Leaderboard", stringify({}, true, 100000))
    end
end