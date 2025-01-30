local json = require "./dkjson"  -- Include dkjson for handling JSON if needed, or use a simple encoder/decoder as shown earlier
local session_start_time = nil
local session_running = false
local best_lap_time = -1
local driver_name = ""
local result_path = "C:/Users/HP/Documents/Assetto Corsa/out/hotlap_results.json"
local session_duration = 600000  -- 10 minutes in milliseconds
local time_left = session_duration
local lap_data = {}
local current_lap_start_time = nil
local first_lap_completed = false

-- Draw the app's interface
function script.draw()
    if not session_running then
        ui.text("Hotlap Challenge - Enter Driver Name")
        driver_name = ui.inputText("", driver_name, 64)

        if ui.button("Start Session") and driver_name ~= "" then
            start_session()
        end
    else
        ui.text("Session Running: Driver - " .. driver_name)
        ui.text("Time Left: " .. string.format("%.2f", time_left / 1000) .. " seconds")

        if ui.button("Reset to Hotlap Start") then
            reset_to_start()
        end

        if ui.button("End Session") then
            end_session()
        end

        if best_lap_time > 0 then
            ui.text("Best Lap Time: " .. string.format("%.2f", best_lap_time / 1000) .. " seconds")
        end
    end
end

-- Function to start the session
function start_session()
    session_running = true
    session_start_time = os.clock() * 1000  -- Use os.clock() to get the current time in milliseconds
    time_left = session_duration
    lap_data = {}
    best_lap_time = -1
    current_lap_start_time = os.clock() * 1000
    first_lap_completed = false

    local carIndex = 0 -- Assuming player is car 0
    local spawnSet = ac.SpawnSet.HotlapStart -- Use the spawn set for the hotlap start
    physics.teleportCarTo(carIndex, spawnSet)

    ac.log("Car teleported to the hotlap start!")
    ac.log("Session started!")

    print("Session started for " .. driver_name)
end

-- Function to reset the car to the Hotlap start position
function reset_to_start()
    local carIndex = 0 -- Assuming player is car 0
    local spawnSet = ac.SpawnSet.HotlapStart -- Use the spawn set for the hotlap start
    physics.teleportCarTo(carIndex, spawnSet)
    current_lap_start_time = os.clock() * 1000
    first_lap_completed = false
    print("Car reset to Hotlap start for " .. driver_name)
end

-- Function to end the session
function end_session()
    session_running = false
    save_session_data()
    reset_ui()
    local carIndex = 0 -- Assuming player is car 0
    local spawnSet = ac.SpawnSet.HotlapStart -- Use the spawn set for the hotlap start
    physics.teleportCarTo(carIndex, spawnSet)

    ac.log("Car teleported to the hotlap start!")
    ac.tryToRestartSession()
    print("Session ended for " .. driver_name)
end
function save_session_data()
    -- If lap_data is empty, return
    print(lap_data)

    if #lap_data <= 1 then
        print("No laps recorded.")
        return
    end

    -- Read existing results or create a new table
    local file = io.open(result_path, "r")
    local results = {}

    if file then
        local content = file:read("*a")
        results = json.decode(content)
        file:close()
    end

    -- Add the new session data
    table.insert(results, {
        name = driver_name,
        best_lap_time = best_lap_time,
        laps = lap_data
    })

    -- Write the updated results back to the file
    file = io.open(result_path, "w")
    file:write(json.encode(results, { indent = true }))
    file:close()

    print("Session data saved for " .. driver_name)
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
        local current_time = os.clock() * 1000  -- Use os.clock() to get the current time in milliseconds
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
            if car.isLastLapValid then 
                if first_lap_completed then
                    if best_lap_time == -1 or lap_time < best_lap_time then
                        best_lap_time = lap_time
                    end

                    -- Add lap time to lap data
                    table.insert(lap_data, {
                        lap = #lap_data + 1,
                        time = lap_time
                    })
                else
                    first_lap_completed = true
                end
            end
            -- Reset lap start time
            current_lap_start_time = current_time
        end
    end
end

-- Register a callback function to track laps every frame
function script.update(dt)
    track_laps()
end