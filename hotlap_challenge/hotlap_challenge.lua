local json = require "./dkjson"

local session_start_time = nil
local session_running = false
local best_lap_time = -1
local driver_name = ""
local result_url = "https://api.jsonbin.io/v3/b/67a105ebe41b4d34e4837cde"
local master_key = "$2a$10$nXo5EIMscPbedTWyQmS3SO.jLsETSi10/SSElTI7b1ZqfVPW8CZkm"
local session_duration = 600000
local time_left = session_duration
local lap_data = {}
local current_lap_start_time = nil
local first_lap_completed = false

-- Helper function to format time
local function formatTime(ms)
    local minutes = math.floor(ms / 60000)
    local seconds = math.floor((ms % 60000) / 1000)
    local milliseconds = ms % 1000
    return string.format("%02d:%02d:%03d", minutes, seconds, milliseconds)
end

-- Async function to fetch JSON data from the remote API using web.get
local function fetch_remote_json_async(callback)
    web.get(result_url, {
        ["X-Master-Key"] = master_key
    }, function(err, response)
        if err then
            ac.log("Failed to fetch JSON: " .. err)
            callback(nil)  -- Notify failure to caller
            return
        end
        try(function()
            local data = json.decode(response.body)
            callback(data.record)  -- Notify success to caller
        end, function(parse_err)
            ac.log("Failed to parse JSON: " .. parse_err)
            callback(nil)  -- Notify failure to caller
        end)
    end)
end

-- Async function to update JSON data on the remote API using web.put
local function update_remote_json_async(data, callback)
    local request_body = json.encode(data)
    
    ac.debug(request_body)

    web.request("PUT", result_url, {
        ["X-Master-Key"] = master_key,
        ["Content-Type"] = "application/json"
    }, request_body, function(err, response)
        if err then
            ac.log('Failed to update JSON: ' .. err)
            callback(false)  -- Notify failure
            return
        end
        if response.status == 200 then
            ac.log("Remote JSON data updated successfully.")
            callback(true)  -- Notify success
        else
            ac.log("Failed to update remote JSON. Status code: " .. response.status)
            callback(false)  -- Notify failure
        end
    end)
end

function script.draw()
    local draw_top_left = vec2(0, 22)
    local draw_size = ui.windowSize() - vec2(0, 22)
    local draw_center = draw_top_left + draw_size / 2

    ui.drawImage(
        "./assets/trackstar.png",
        draw_top_left,
        draw_center / 2,
        rgbm(1, 1, 1, 1)
    )

    ui.dummy(vec2(0, ui.windowHeight() * 0.2 + 10))
    ui.drawRect(ui.getCursor(), ui.getCursor() + vec2(300, 2), rgbm.colors.black)

    ui.pushFont(ui.Font.Big)

    ui.beginGradientShade()
    local c = ui.getCursor()
    ui.dwriteText('TrackStar Hotlap challenge', 25, rgbm.colors.white)
    ui.endGradientShade(c, c + vec2(0, ui.measureDWriteText('TrackStar Hotlap challenge', 25).y), rgbm.colors.red, rgbm.colors.white)
    ui.drawRect(ui.getCursor(), ui.getCursor() + vec2(300, 2), rgbm.colors.black)

    ui.dummy(vec2(0, ui.windowHeight() * 0.05 ))

    if not session_running then
        driver_name = ui.inputText("", driver_name, 64)

        if ui.button("Start Session") and driver_name ~= "" then
            start_session()
        end
    else
        ui.text("Session Running: Driver - " .. driver_name)
        ui.text("Time Left: " .. string.format(": %s", formatTime(time_left)))

        if ui.button("Reset to Hotlap Start") then
            reset_to_start()
        end

        if ui.button("End Session") then
            end_session()
        end

        if best_lap_time > 0 then
            ui.text("Best Lap Time: " .. formatTime(best_lap_time))
        end
    end

    ui.popFont()
end

function start_session()
    session_running = true
    session_start_time = os.clock() * 1000  
    time_left = session_duration
    lap_data = {}
    best_lap_time = -1
    current_lap_start_time = os.clock() * 1000
    first_lap_completed = false

    local carIndex = 0 
    local spawnSet = ac.SpawnSet.HotlapStart 
    physics.teleportCarTo(carIndex, spawnSet)

    ac.log("Car teleported to the hotlap start!")
    ac.log("Session started for " .. driver_name)
end

function reset_to_start()
    local carIndex = 0
    local spawnSet = ac.SpawnSet.HotlapStart
    physics.teleportCarTo(carIndex, spawnSet)
    current_lap_start_time = os.clock() * 1000
    first_lap_completed = false
    ac.log("Car reset to Hotlap start for " .. driver_name)
end

-- Function to end the session
function end_session()
    save_session_data_async()
    
    session_running = false
    local carIndex = 0
    local spawnSet = ac.SpawnSet.HotlapStart
    physics.teleportCarTo(carIndex, spawnSet)

    ac.log("Car teleported to the hotlap start!")
    ac.tryToRestartSession()
    reset_ui()
    ac.log("Session ended for " .. driver_name)
end

function save_session_data_async()
    if #lap_data < 1 then
        ac.log("No laps recorded.")
        return
    end

    local data = {
        name = driver_name,
        best_lap_time = best_lap_time,
        best_timeFormatted = formatTime(best_lap_time),
        laps = lap_data
    }

    fetch_remote_json_async(function(results)
        if not results then
            ac.log("Failed to fetch remote JSON data.")
            return
        end
        
        -- Add the new session data
        table.insert(results, data)
        -- Sort the best times
        table.sort(results, function(a, b) return a.best_lap_time < b.best_lap_time end)

        -- Update the remote JSON asynchronously
        update_remote_json_async(results, function(success)
            if success then
                ac.log("Session data saved successfully.")
            else
                ac.log("Failed to save session data.")
            end
        end)
    end)
end

-- Function to reset the UI after session ends
function reset_ui()
    driver_name = ""
    session_running = false
    best_lap_time = -1
end

-- Function to track lap times
function track_laps()
    if session_running then
        local car = ac.getCar(0)
        -- Check if 10 minutes are over
        local current_time = os.clock() * 1000
        time_left = session_duration - (current_time - session_start_time)

        -- If time is up, end the session automatically
        if time_left <= 0 then
            end_session()
            return
        end

        -- Track current lap time
        local lap_time = current_time - current_lap_start_time

        -- If a new lap is completed (assuming a lap is completed every time the car crosses the start line)
        if car.lapTimeMs > 1000 and car.lapTimeMs < lap_time then
            -- if car.isLastLapValid then 
                if first_lap_completed then
                    if best_lap_time == -1 or lap_time < best_lap_time then
                        best_lap_time = lap_time
                    end

                    -- Add lap time to lap data
                    table.insert(lap_data, {
                        lap = #lap_data + 1,
                        time = lap_time,
                        timeFormatted = formatTime(lap_time)
                    })
                else
                    first_lap_completed = true
                end
            -- end
            -- Reset lap start time
            current_lap_start_time = current_time
        end
    end
end

-- Register a callback function to track laps every frame
function script.update(dt)
    track_laps()
end
