-- DriftZonesEditor.lua

local LocalRenderGates = require('local_render_gates')
local LocalGates = require('local_gates')

local sim = ac.getSim()
local uis = ac.getUI()

local function deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deepcopy(orig_key)] = deepcopy(orig_value)
        end
        setmetatable(copy, deepcopy(getmetatable(orig)))
    else
        copy = orig
    end
    return copy
end

local AppState = {
    editorActive = false
}

local undoStack = {}
local redoStack = {}
local savedUndoCounter = 0
local currentGates = {}

local selectedGateForEdit = nil
local editedGate = nil
local originalGate = nil

local GATE_ARRAYS = {
    NORMAL = "gates",
    NOGO = "noGoZones",
    TRAJECTORY = "trajectoryGates"
}

local currentConfigName = "default"

local function recordState()
    return deepcopy(currentGates)
end

local function restoreState(state)
    local previousState = deepcopy(currentGates)
    currentGates = state
    return previousState
end

local function addUndoPoint()
    undoStack[#undoStack + 1] = recordState()
    table.clear(redoStack)
end

local function loadCurrentTrackGates()
    local trackData = LocalGates.getTrackData()
    if trackData then
        currentGates = deepcopy(trackData.gates or {})
        LocalRenderGates.updateGates(currentGates)
        ac.debug("Loaded " .. #currentGates .. " gates from track data")
    else
        ac.debug("No track data found, initializing empty gates array")
        currentGates = {}
    end

    if not trackData.startPosition then
        trackData.startPosition = vec3(0, 0, 0)
        trackData.startRotation = 0
        ac.debug("Initialized startPosition to default values")
    end

    if not trackData.alternateStartPosition then
        trackData.alternateStartPosition = vec3(0, 0, 0)
        trackData.alternateStartRotation = 0
        ac.debug("Initialized alternateStartPosition to default values")
    end
end

local function loadLastConfig()
    local settingsPath = ac.getFolder(ac.FolderID.Root) .. '/apps/lua/DriftZonesEditor/settings.txt'
    local file = io.open(settingsPath, 'r')
    if file then
        local lastConfig = file:read('*line')
        file:close()
        return lastConfig or "default"
    end
    return "default"
end

local function saveLastConfig(configName)
    local settingsPath = ac.getFolder(ac.FolderID.Root) .. '/apps/lua/DriftZonesEditor/settings.txt'
    local dir = ac.getFolder(ac.FolderID.Root) .. '/apps/lua/DriftZonesEditor/'
    os.execute('mkdir "' .. dir .. '" 2>nul')
    
    local file = io.open(settingsPath, 'w')
    if file then
        file:write(configName)
        file:close()
        return true
    end
    return false
end

local function initializeTrack()
    local currentTrack = ac.getTrackID()
    local lastConfig = loadLastConfig()
    
    if LocalGates.setCurrentTrack(currentTrack, lastConfig) then
        ac.debug("LocalGates.setCurrentTrack succeeded with config: " .. lastConfig)
        LocalRenderGates.init()
        loadCurrentTrackGates()
        ac.debug("Track initialized: " .. currentTrack .. " with config: " .. lastConfig)
    else
        ac.debug("Failed to initialize track: " .. currentTrack .. " with config: " .. lastConfig)
    end
end

local function deactivateEditor()
    if AppState.editorActive then
        AppState.editorActive = false
        if LocalRenderGates and LocalRenderGates.clear then
            LocalRenderGates.clear()
        end
        ac.setWindowOpen('gate_editor', false)
        selectedGateForEdit = nil
        editedGate = nil
        originalGate = nil
        ac.debug("Editor closed, gates deactivated")
    end
end

local function activateEditor()
    local sim = ac.getSim()
    if sim.raceSessionType ~= ac.SessionType.Practice or ac.load('.mode.driftchallenge.anythinggoeshere') == 1 then
        return false
    end

    if not AppState.editorActive then
        AppState.editorActive = true
        LocalRenderGates.init()
        initializeTrack()
        ac.debug("Editor opened, gates activated")
    end
    return true
end

function windowGateEditor()
    if not selectedGateForEdit or not editedGate then
        ac.setWindowOpen('gate_editor', false)
        return
    end

    ui.pushFont(ui.Font.Small)

    ui.text("Editing Zone #" .. selectedGateForEdit)
    ui.sameLine(120)  
    if editedGate.type == "normal" or editedGate.type == "OZ" then
        ui.text("Zone Type:")
        ui.sameLine()
        if ui.button(editedGate.type == "normal" and "Normal##type" or "OZ##type") then
            if editedGate.type == "normal" then
                editedGate.type = "OZ"
                editedGate.score_multiplier = 0.25
                editedGate.size.width = 0.1
                editedGate.size.length = 2.5
            else
                editedGate.type = "normal"
                editedGate.score_multiplier = 1.0
                editedGate.size.width = 2.0
                editedGate.size.length = 5.0
            end
            LocalRenderGates.updateGateInRealtime(selectedGateForEdit, editedGate)
        end
        if ui.itemHovered() then
            ui.setTooltip('Click to switch between TG and OZ zone types')
        end
    else
        ui.text("Zone Type: " .. (editedGate.type:upper() or "UNKNOWN"))
    end
    ui.separator()

    local pos = editedGate.position

    ui.text("Zones Settings")
    ui.dummy(vec2(0, 3))  

    local range = {
        fine = {
            x = 5, z = 5,
            rotation = 15
        }
    }
    local currentRange = range.fine

    

    if not editedGate.baseX then
        editedGate.baseX = pos.x
        editedGate.baseZ = pos.z
    end

    ui.text("Local Position Offsets:")

    ui.setNextItemWidth(200)
    local newOffsetX = ui.slider("Forward/Back##pos", editedGate.localOffsetX or 0, -currentRange.x, currentRange.x, "%.3f")
    if newOffsetX ~= editedGate.localOffsetX then
        editedGate.localOffsetX = newOffsetX
        LocalRenderGates.updateGateInRealtime(selectedGateForEdit, editedGate)
    end

    if not ui.mouseDown(ui.MouseButton.Left) and editedGate.localOffsetX ~= 0 then
        editedGate.baseX = editedGate.position.x
        editedGate.baseZ = editedGate.position.z
        editedGate.localOffsetX = 0
        LocalRenderGates.updateGateInRealtime(selectedGateForEdit, editedGate)
    end

    ui.setNextItemWidth(200)
    local newOffsetZ = ui.slider("Right/Left##pos", editedGate.localOffsetZ or 0, -currentRange.z, currentRange.z, "%.3f")
    if newOffsetZ ~= editedGate.localOffsetZ then
        editedGate.localOffsetZ = newOffsetZ
        LocalRenderGates.updateGateInRealtime(selectedGateForEdit, editedGate)
    end

    if not ui.mouseDown(ui.MouseButton.Left) and editedGate.localOffsetZ ~= 0 then
        editedGate.baseX = editedGate.position.x
        editedGate.baseZ = editedGate.position.z
        editedGate.localOffsetZ = 0
        LocalRenderGates.updateGateInRealtime(selectedGateForEdit, editedGate)
    end

    local rotation_rad = math.rad(editedGate.rotation or 0)
    local cos_rot = math.cos(rotation_rad)
    local sin_rot = math.sin(rotation_rad)

    local newX = editedGate.baseX + (editedGate.localOffsetX * cos_rot - editedGate.localOffsetZ * sin_rot)
    local newZ = editedGate.baseZ + (editedGate.localOffsetX * sin_rot + editedGate.localOffsetZ * cos_rot)

    local rayStart = vec3(newX, pos.y + 1, newZ)
    local rayDir = vec3(0, -1, 0)
    local hitPoint = vec3()
    local hitNormal = vec3()
    local distance = physics.raycastTrack(rayStart, rayDir, 10, hitPoint, hitNormal)

    if distance ~= -1 then
        pos.x = hitPoint.x
        pos.y = hitPoint.y
        pos.z = hitPoint.z
    else
        pos.x = newX
        pos.z = newZ
    end

    LocalRenderGates.updateGateInRealtime(selectedGateForEdit, editedGate)

    if editedGate.baseRotation == nil then
        editedGate.baseRotation = editedGate.rotation or 0
    end

    ui.text("Rotation:")
    ui.setNextItemWidth(200)
    local rotationOffset = (editedGate.rotation or 0) - editedGate.baseRotation
    local newRotationOffset = ui.slider("Yaw##rotation", rotationOffset, -currentRange.rotation, currentRange.rotation, "%.1f°")

    if newRotationOffset ~= rotationOffset then
        editedGate.rotation = editedGate.baseRotation + newRotationOffset
        LocalRenderGates.updateGateInRealtime(selectedGateForEdit, editedGate)
    end

    if not ui.mouseDown(ui.MouseButton.Left) and newRotationOffset ~= 0 then
        editedGate.baseRotation = editedGate.rotation
        editedGate.rotation = editedGate.baseRotation
        editedGate.localOffsetX = 0
        editedGate.localOffsetZ = 0
        LocalRenderGates.updateGateInRealtime(selectedGateForEdit, editedGate)
    end

    ui.text("Size:")
    local size = editedGate.size
    if editedGate.type ~= "OZ" and editedGate.type ~= "no_go_zone" and 
       editedGate.type ~= "trajectory" and editedGate.type ~= "start" and 
       editedGate.type ~= "finish" then
        size.width = ui.slider("Width##size", size.width, 0.1, 20, "%.2f")
    end
    size.length = ui.slider("Length##size", size.length, 0.1, 20, "%.2f")
    LocalRenderGates.updateGateInRealtime(selectedGateForEdit, editedGate)

    ui.text("Line Thickness:")
    ui.setNextItemWidth(200)
    editedGate.line_width = ui.slider("##line_width", editedGate.line_width or 1.0, 0.05, 3.00, "%.2f")
    ui.sameLine()
    if ui.button("Apply to all") then
        local currentLineWidth = editedGate.line_width
        if editedGate.arrayType == GATE_ARRAYS.NOGO then
            local noGoZones = LocalGates.getNoGoZones()
            for _, zone in ipairs(noGoZones) do
                zone.line_width = currentLineWidth
            end
            LocalGates.setNoGoZones(noGoZones)
        elseif editedGate.arrayType == GATE_ARRAYS.TRAJECTORY then
            local trajectoryGates = LocalGates.getTrajectoryGates()
            for _, gate in ipairs(trajectoryGates) do
                gate.line_width = currentLineWidth
            end
            LocalGates.setTrajectoryGates(trajectoryGates)
        else
            for _, gate in ipairs(currentGates) do
                if gate.type == editedGate.type then
                    gate.line_width = currentLineWidth
                end
            end
            LocalGates.setGates(currentGates)
        end
        LocalRenderGates.updateGates(currentGates)
        local gateTypeName = editedGate.type == "normal" and "TG" or 
                             editedGate.type == "OZ" and "OZ" or 
                             editedGate.type == "no_go_zone" and "No-Go" or 
                             editedGate.type == "trajectory" and "Trajectory" or 
                             editedGate.type:upper()
        ui.toast(ui.Icons.Confirm, string.format("Line width %.2f applied to all %s zones", currentLineWidth, gateTypeName))
        addUndoPoint()
    end
    if ui.itemHovered() then
        ui.setTooltip('Apply current line width to all gates of the same type')
    end

    if editedGate.type == "normal" or editedGate.type == "OZ" or 
       editedGate.type == "start" or editedGate.type == "finish" then
        ui.text("Line Colors RGB:")
        ui.setNextItemWidth(64)
        editedGate.color_r = ui.slider("##color_r", editedGate.color_r or 0.9, 0.0, 1.0, "%.2f")
        ui.sameLine(0, 4)
        ui.setNextItemWidth(64)
        editedGate.color_g = ui.slider("##color_g", editedGate.color_g or 0.9, 0.0, 1.0, "%.2f")
        ui.sameLine(0, 4)
        ui.setNextItemWidth(64)
        editedGate.color_b = ui.slider("##color_b", editedGate.color_b or 0.9, 0.0, 1.0, "%.2f")
        ui.sameLine()
        if ui.button("Apply to all##color") then
            local currentColor = {
                r = editedGate.color_r,
                g = editedGate.color_g,
                b = editedGate.color_b
            }
            for _, gate in ipairs(currentGates) do
                if gate.type == editedGate.type then
                    gate.color_r = currentColor.r
                    gate.color_g = currentColor.g
                    gate.color_b = currentColor.b
                end
            end
            LocalGates.setGates(currentGates)
            LocalRenderGates.updateGates(currentGates)
            local gateTypeName = editedGate.type == "normal" and "TG" or 
                                editedGate.type == "OZ" and "OZ" or
                                editedGate.type == "start" and "Start" or
                                editedGate.type == "finish" and "Finish"
            ui.toast(ui.Icons.Confirm, string.format("Color applied to all %s gates", gateTypeName))
            addUndoPoint()
        end
        if ui.itemHovered() then
            ui.setTooltip('Apply current color to all gates of the same type')
        end
    end

    if editedGate.score_multiplier then
        ui.dummy(vec2(0, 10))  
        ui.separator()
        ui.text("Gameplay Settings")
        ui.dummy(vec2(0, 5))
        
        ui.text("Drift Zone Bonus Rate:")
        if ui.itemHovered() then
            ui.setTooltip("This is the multiplier that makes this zone more valuable in overall score")
        end
        ui.setNextItemWidth(200)
        editedGate.score_multiplier = ui.slider("##multiplier", editedGate.score_multiplier, 0, 2, "%.2f")

        if editedGate.type == "normal" or editedGate.type == "OZ" then
            ui.text("Target Drift Angle:")
            if ui.itemHovered() then
                ui.setTooltip("Minimum drift angle to maximize your score in this zone")
            end
            ui.setNextItemWidth(200)
            editedGate.target_angle = ui.slider("##target_angle", editedGate.target_angle or 30, 15, 90, "%.0f°")
        end
    end

    ui.separator()
    


    if ui.button("Apply") then
        editedGate.baseX = editedGate.position.x
        editedGate.baseZ = editedGate.position.z
        editedGate.baseRotation = editedGate.rotation
        editedGate.localOffsetX = 0
        editedGate.localOffsetZ = 0
        addUndoPoint()

        if editedGate.arrayType == GATE_ARRAYS.NOGO then
            local noGoZones = LocalGates.getNoGoZones()
            noGoZones[selectedGateForEdit] = {
                type = editedGate.type,
                position = editedGate.position,
                rotation = editedGate.rotation,
                size = editedGate.size,
                thickness = editedGate.thickness,
                line_width = editedGate.line_width
            }
            LocalGates.setNoGoZones(noGoZones)
            LocalRenderGates.updateGates(currentGates)
        elseif editedGate.arrayType == GATE_ARRAYS.TRAJECTORY then
            local trajectoryGates = LocalGates.getTrajectoryGates()
            trajectoryGates[selectedGateForEdit] = {
                type = editedGate.type,
                position = editedGate.position,
                rotation = editedGate.rotation,
                size = editedGate.size,
                thickness = editedGate.thickness,
                line_width = editedGate.line_width
            }
            LocalGates.setTrajectoryGates(trajectoryGates)
            LocalRenderGates.updateGates(currentGates)
        else
            currentGates[selectedGateForEdit] = {
                type = editedGate.type,
                position = editedGate.position,
                rotation = editedGate.rotation,
                size = editedGate.size,
                score_multiplier = editedGate.score_multiplier,
                target_angle = editedGate.target_angle,
                thickness = editedGate.thickness,
                line_width = editedGate.line_width,
                color_r = editedGate.color_r,
                color_g = editedGate.color_g,
                color_b = editedGate.color_b
            }
            LocalGates.setGates(currentGates)
            LocalRenderGates.updateGates(currentGates)
        end
    end
    ui.sameLine(0, 4)

    if ui.button("Cancel") then
        editedGate = deepcopy(originalGate)
        LocalRenderGates.updateGateInRealtime(selectedGateForEdit, editedGate)

        if editedGate.arrayType == GATE_ARRAYS.NOGO then
            local noGoZones = LocalGates.getNoGoZones()
            noGoZones[selectedGateForEdit] = deepcopy(originalGate)
            LocalGates.setNoGoZones(noGoZones)
        elseif editedGate.arrayType == GATE_ARRAYS.TRAJECTORY then
            local trajectoryGates = LocalGates.getTrajectoryGates()
            trajectoryGates[selectedGateForEdit] = deepcopy(originalGate)
            LocalGates.setTrajectoryGates(trajectoryGates)
        else
            currentGates[selectedGateForEdit] = deepcopy(originalGate)
            LocalGates.setGates(currentGates)
        end

        LocalRenderGates.updateGates(currentGates)

        ac.setWindowOpen('gate_editor', false)
        selectedGateForEdit = nil
        editedGate = nil
        originalGate = nil
    end

    ui.sameLine(0, 20)  

    if ui.button("<<") then
        local prevIndex, prevGate, prevArrayType
        if editedGate and editedGate.arrayType then
            if editedGate.arrayType == GATE_ARRAYS.NOGO then
                local noGoZones = LocalGates.getNoGoZones()
                prevIndex = selectedGateForEdit > 1 and selectedGateForEdit - 1 or #noGoZones
                prevGate = noGoZones[prevIndex]
                prevArrayType = GATE_ARRAYS.NOGO
            elseif editedGate.arrayType == GATE_ARRAYS.TRAJECTORY then
                local trajectoryGates = LocalGates.getTrajectoryGates()
                prevIndex = selectedGateForEdit > 1 and selectedGateForEdit - 1 or #trajectoryGates
                prevGate = trajectoryGates[prevIndex]
                prevArrayType = GATE_ARRAYS.TRAJECTORY
            else
                local gates = LocalGates.getGates()
                prevIndex = selectedGateForEdit > 1 and selectedGateForEdit - 1 or #gates
                prevGate = gates[prevIndex]
                prevArrayType = GATE_ARRAYS.NORMAL
            end
        else
            local gates = LocalGates.getGates()
            prevIndex = #gates
            prevGate = gates[prevIndex]
            prevArrayType = GATE_ARRAYS.NORMAL
        end
        teleportCamera(prevGate, prevIndex, prevArrayType)
    end
    if ui.itemHovered() then
        ui.setTooltip('Previous Gate')
    end
    ui.sameLine(0, 4)

    if ui.button(">>") then
        local nextIndex, nextGate, nextArrayType
        if editedGate and editedGate.arrayType then
            if editedGate.arrayType == GATE_ARRAYS.NOGO then
                local noGoZones = LocalGates.getNoGoZones()
                nextIndex = selectedGateForEdit < #noGoZones and selectedGateForEdit + 1 or 1
                nextGate = noGoZones[nextIndex]
                nextArrayType = GATE_ARRAYS.NOGO
            elseif editedGate.arrayType == GATE_ARRAYS.TRAJECTORY then
                local trajectoryGates = LocalGates.getTrajectoryGates()
                nextIndex = selectedGateForEdit < #trajectoryGates and selectedGateForEdit + 1 or 1
                nextGate = trajectoryGates[nextIndex]
                nextArrayType = GATE_ARRAYS.TRAJECTORY
            else
                local gates = LocalGates.getGates()
                nextIndex = selectedGateForEdit < #gates and selectedGateForEdit + 1 or 1
                nextGate = gates[nextIndex]
                nextArrayType = GATE_ARRAYS.NORMAL
            end
        else
            local gates = LocalGates.getGates()
            nextIndex = 1
            nextGate = gates[nextIndex]
            nextArrayType = GATE_ARRAYS.NORMAL
        end
        teleportCamera(nextGate, nextIndex, nextArrayType)
    end
    if ui.itemHovered() then
        ui.setTooltip('Next Gate')
    end

    ui.popFont()
end


function teleportCamera(gate, gateIndex, arrayType)
    local gateRotationRad = math.rad(gate.rotation or 0)
    local distance = 13
    local height = 8

    local targetPosition = gate.position + vec3(
        math.sin(gateRotationRad) * distance,
        height,
        math.cos(gateRotationRad) * distance
    )

    local currentCamPos = ac.getCameraPosition()
    
    ac.setCameraPosition(targetPosition)
    ac.setCameraDirection((gate.position - targetPosition):normalize())
    
    setTimeout(function()
        local newCamPos = ac.getCameraPosition()
        

        local distanceToTarget = (newCamPos - targetPosition):length()
        if distanceToTarget > 1.0 then  
            ui.toast(ui.Icons.Warning, "Press F7 to get into Free Mode")
            return
        end
        
        selectedGateForEdit = gateIndex
        editedGate = {
            type = gate.type or "normal",
            position = vec3(gate.position.x, gate.position.y, gate.position.z),
            rotation = gate.rotation or 0,
            baseRotation = gate.rotation or 0,
            size = {
                width = gate.size.width or 2,
                length = gate.size.length or 5
            },
            score_multiplier = gate.score_multiplier,
            target_angle = gate.target_angle,
            editMode = "fine",
            baseX = gate.position.x,
            baseY = gate.position.y,
            baseZ = gate.position.z,
            localOffsetX = 0,
            localOffsetZ = 0,
            line_width = gate.line_width or 1.0,
            color_r = gate.color_r or 0.9,
            color_g = gate.color_g or 0.9,
            color_b = gate.color_b or 0.9
        }
        originalGate = deepcopy(editedGate)
        editedGate.arrayType = arrayType
        ac.setWindowOpen('gate_editor', true)
    end, 0.1)
end

function addNewGate(gateType)
    local car = ac.getCar(0)

    local forward = vec3(car.look.x, 0, car.look.z):normalize()
    local baseRotation = math.deg(math.atan2(forward.z, forward.x)) + 90

    local gateSize
    local rotation

    if gateType == "start" or gateType == "finish" then
        gateSize = { width = 0.1, length = 9 }
        rotation = baseRotation + 90
    elseif gateType == "OZ" or gateType == "no_go_zone" or gateType == "trajectory" then
        gateSize = { width = 0.1, length = 2.5 }
        rotation = baseRotation + 90
    else
        gateSize = { width = 2, length = 5 }
        rotation = baseRotation
    end

    local newGate = {
        type = gateType,
        position = car.position,
        rotation = rotation,
        baseRotation = rotation,
        size = gateSize,
    }

    if gateType == "normal" then
        newGate.score_multiplier = 1.0
        newGate.target_angle = 30
    elseif gateType == "OZ" then
        newGate.score_multiplier = 0.25
        newGate.target_angle = 30
    end

    addUndoPoint()

    if gateType == "no_go_zone" then
        local noGoZones = LocalGates.getNoGoZones()
        table.insert(noGoZones, newGate)
        LocalGates.setNoGoZones(noGoZones)
    elseif gateType == "trajectory" then
        local trajectoryGates = LocalGates.getTrajectoryGates()
        table.insert(trajectoryGates, newGate)
        LocalGates.setTrajectoryGates(trajectoryGates)
    else
        table.insert(currentGates, newGate)
        LocalGates.setGates(currentGates)
    end

    LocalRenderGates.updateGates(currentGates)
end

function addNewGateAtPosition(gateType, position, lookDir)
    local forward = vec3(lookDir.x, 0, lookDir.z):normalize()
    local baseRotation = math.deg(math.atan2(forward.z, forward.x)) + 90

    local rayStart = position + vec3(0, 1, 0)
    local rayDir = vec3(0, -1, 0)
    local rayLength = 10

    local hitPoint = vec3()
    local hitNormal = vec3()
    local distance = physics.raycastTrack(rayStart, rayDir, rayLength, hitPoint, hitNormal)

    local finalPosition, pitchAngle, rollAngle
    if distance ~= -1 then
        finalPosition = hitPoint
        local normal = hitNormal
        pitchAngle = math.deg(math.atan2(normal.z, normal.y))
        rollAngle = math.deg(math.atan2(-normal.x, normal.y))
    else
        finalPosition = position
        pitchAngle = 0
        rollAngle = 0
    end

    local gateSize
    local rotation = baseRotation

    if gateType == "start" or gateType == "finish" then
        gateSize = { width = 0.1, length = 9 }
        rotation = baseRotation + 90
    elseif gateType == "OZ" or gateType == "no_go_zone" or gateType == "trajectory" then
        gateSize = { width = 0.1, length = 2.5 }
        rotation = baseRotation
    else
        gateSize = { width = 2, length = 5 }
    end

    local newGate = {
        type = gateType,
        position = finalPosition,
        rotation = rotation,
        baseRotation = rotation,
        size = gateSize,
    }

    if gateType == "normal" then
        newGate.score_multiplier = 1.0
        newGate.target_angle = 30
    elseif gateType == "OZ" then
        newGate.score_multiplier = 0.25
        newGate.target_angle = 30
    end

    addUndoPoint()

    local gateIndex
    if gateType == "no_go_zone" then
        local noGoZones = LocalGates.getNoGoZones()
        table.insert(noGoZones, newGate)
        gateIndex = #noGoZones
        LocalGates.setNoGoZones(noGoZones)
        newGate.arrayType = GATE_ARRAYS.NOGO
    elseif gateType == "trajectory" then
        local trajectoryGates = LocalGates.getTrajectoryGates()
        table.insert(trajectoryGates, newGate)
        gateIndex = #trajectoryGates
        LocalGates.setTrajectoryGates(trajectoryGates)
        newGate.arrayType = GATE_ARRAYS.TRAJECTORY
    else
        table.insert(currentGates, newGate)
        gateIndex = #currentGates
        LocalGates.setGates(currentGates)
        newGate.arrayType = GATE_ARRAYS.NORMAL
    end

    LocalRenderGates.updateGates(currentGates)

    selectedGateForEdit = gateIndex
    editedGate = {
        type = newGate.type,
        position = vec3(newGate.position.x, newGate.position.y, newGate.position.z),
        rotation = newGate.rotation,
        baseRotation = newGate.rotation,
        size = {
            width = newGate.size.width,
            length = newGate.size.length
        },
        score_multiplier = newGate.score_multiplier,
        target_angle = newGate.target_angle,
        editMode = "fine",
        baseX = newGate.position.x,
        baseY = newGate.position.y,
        baseZ = newGate.position.z,
        localOffsetX = 0,
        localOffsetZ = 0,
        arrayType = newGate.arrayType
    }
    originalGate = deepcopy(editedGate)
    ac.setWindowOpen('gate_editor', true)
end


local function setMaxTransitions(value)
    local trackData = LocalGates.getTrackData()
    if trackData then
        value = math.max(0, math.min(99, math.floor(value)))
        trackData.maxAllowedTransitions = value

        local currentConfig = LocalGates.getCurrentConfig()
        if LocalGates.saveToFile() then
            saveLastConfig(currentConfig)
            ui.toast(ui.Icons.Confirm, string.format("Max transitions set to: %d", value))
        else
            ui.toast(ui.Icons.Warning, "Failed to save track data")
        end
    end
end

local function closeGateEditor()
    if selectedGateForEdit then
        selectedGateForEdit = nil
        editedGate = nil
        originalGate = nil
        ac.setWindowOpen('gate_editor', false)
    end
end

local function deleteConfig(configName)
    if configName == "default" then
        ui.toast(ui.Icons.Warning, "Cannot delete default configuration")
        return false
    end

    local currentTrack = ac.getTrackID()
    local filePath = ac.getFolder(ac.FolderID.Root) .. '/apps/lua/DriftZonesEditor/tracks/' .. currentTrack .. '_' .. configName .. '.lua'
    

    local success = os.remove(filePath)
    if success then
        if configName == LocalGates.getCurrentConfig() then
            LocalGates.setCurrentConfig("default")
            loadCurrentTrackGates()
        end
        return true
    end
    return false
end


local function checkClickOnGate(position)
    local function isPointInGate(point, gate)
        local gateRotation = math.rad(gate.rotation or 0)
        local dx = point.x - gate.position.x
        local dz = point.z - gate.position.z
        
        local localX = dx * math.cos(-gateRotation) - dz * math.sin(-gateRotation)
        local localZ = dx * math.sin(-gateRotation) + dz * math.cos(-gateRotation)
        
        local margin = 0.5 
        return math.abs(localX) <= (gate.size.width / 2 + margin) and 
               math.abs(localZ) <= (gate.size.length / 2 + margin)
    end

    for i, gate in ipairs(currentGates) do
        if isPointInGate(position, gate) then
            selectedGateForEdit = i
            editedGate = {
                type = gate.type or "normal",
                position = vec3(gate.position.x, gate.position.y, gate.position.z),
                rotation = gate.rotation or 0,
                baseRotation = gate.rotation or 0,
                size = {
                    width = gate.size.width or 2,
                    length = gate.size.length or 5
                },
                score_multiplier = gate.score_multiplier,
                target_angle = gate.target_angle,
                editMode = "fine",
                baseX = gate.position.x,
                baseY = gate.position.y,
                baseZ = gate.position.z,
                localOffsetX = 0,
                localOffsetZ = 0,
                arrayType = GATE_ARRAYS.NORMAL,
                line_width = gate.line_width or 1.0,
                color_r = gate.color_r or 0.9,
                color_g = gate.color_g or 0.9,
                color_b = gate.color_b or 0.9
            }
            originalGate = deepcopy(editedGate)
            ac.setWindowOpen('gate_editor', true)
            return true
        end
    end

    local noGoZones = LocalGates.getNoGoZones()
    for i, zone in ipairs(noGoZones) do
        if isPointInGate(position, zone) then
            selectedGateForEdit = i
            editedGate = {
                type = "no_go_zone",
                position = vec3(zone.position.x, zone.position.y, zone.position.z),
                rotation = zone.rotation or 0,
                size = {
                    width = zone.size.width or 2,
                    length = zone.size.length or 5
                },
                editMode = "fine",
                baseX = zone.position.x,
                baseY = zone.position.y,
                baseZ = zone.position.z,
                localOffsetX = 0,
                localOffsetZ = 0,
                arrayType = GATE_ARRAYS.NOGO,
                line_width = zone.line_width
            }
            originalGate = deepcopy(editedGate)
            ac.setWindowOpen('gate_editor', true)
            return true
        end
    end

    local trajectoryGates = LocalGates.getTrajectoryGates()
    for i, gate in ipairs(trajectoryGates) do
        if isPointInGate(position, gate) then
            selectedGateForEdit = i
            editedGate = {
                type = "trajectory",
                position = vec3(gate.position.x, gate.position.y, gate.position.z),
                rotation = gate.rotation or 0,
                size = {
                    width = gate.size.width or 2,
                    length = gate.size.length or 5
                },
                editMode = "fine",
                baseX = gate.position.x,
                baseY = gate.position.y,
                baseZ = gate.position.z,
                localOffsetX = 0,
                localOffsetZ = 0,
                arrayType = GATE_ARRAYS.TRAJECTORY,
                line_width = gate.line_width
            }
            originalGate = deepcopy(editedGate)
            ac.setWindowOpen('gate_editor', true)
            return true
        end
    end
    return false
end



function windowMain(dt)
    local sim = ac.getSim()
    
    if sim.raceSessionType ~= ac.SessionType.Practice or ac.load('.mode.driftchallenge.anythinggoeshere') == 1 then
        ui.pushFont(ui.Font.Small)
        ui.text("Editor is not available.")
        ui.text("Try an offline practice session.")
        ui.popFont()
        return
    end

    if not AppState.editorActive then
        activateEditor()
    end

    ui.pushFont(ui.Font.Small)

    ui.textColored("Create Drift Track for New Game Mode - Drift Challenge")
    ui.separator()

    if ui.button("Open FAQ") then
        ac.setWindowOpen('faq', true)
    end
    ui.separator()

    ui.text("Track Configurations:")
    

    local currentConfig = LocalGates.getCurrentConfig()
    if currentConfig then
        ui.text("Current: " .. currentConfig)
    else
        ui.text("Current: ")
        ui.sameLine()
        ui.textColored("Create New Config or Load Existing")
    end

    if ui.button("New Config") then
        closeGateEditor() 
        ui.modalPrompt('New Configuration', 'Configuration name:', '', 
            'Create', 'Cancel', ui.Icons.Save, ui.Icons.Cancel, 
            function (configName)
                if configName and configName ~= "" then
                    if LocalGates.setCurrentConfig(configName) then
                        saveLastConfig(configName)
                        if LocalGates.saveToFile() then
                            ui.toast(ui.Icons.Confirm, "Created new configuration: " .. configName)
                            loadCurrentTrackGates()
                        else
                            ui.toast(ui.Icons.Warning, "Failed to save new configuration")
                            LocalGates.setCurrentTrack(ac.getTrackID())
                        end
                    end
                end
            end
        )
    end
    ui.sameLine()

    local configs = LocalGates.getAvailableConfigs()
    if #configs > 0 then
        if ui.button("Load Config") then
            ui.openPopup("load_config_popup")
        end
        ui.sameLine()
    end

    if ui.beginPopup("load_config_popup") then
        ui.text("Select configuration:")
        local configs = LocalGates.getAvailableConfigs()
        
        for _, config in ipairs(configs) do
            if ui.selectable(config, config == LocalGates.getCurrentConfig()) then
                closeGateEditor() 
                if LocalGates.setCurrentConfig(config) then
                    loadCurrentTrackGates()
                    saveLastConfig(config)
                    ui.toast(ui.Icons.Confirm, "Loaded configuration: " .. config)
                    ui.closePopup()
                end
            end
            
            if ui.itemHovered() and config ~= "default" then
                ui.setTooltip("Right click to delete")
                if ui.mouseClicked(ui.MouseButton.Right) then
                    closeGateEditor() 
                    local configToDelete = config
                    ui.modalDialog("Delete Configuration", function()
                        ui.text("Are you sure you want to delete configuration '" .. configToDelete .. "'?")
                        ui.newLine()
                        ui.offsetCursorY(4)
                        
                        local buttonWidth = ui.availableSpaceX() / 2 - 4
                        if ui.modernButton("Yes", vec2(buttonWidth, 40)) then
                            if deleteConfig(configToDelete) then
                                ui.toast(ui.Icons.Confirm, "Configuration deleted: " .. configToDelete)
                            else
                                ui.toast(ui.Icons.Warning, "Failed to delete configuration")
                            end
                            return true
                        end
                        ui.sameLine(0, 8)
                        if ui.modernButton("No", vec2(buttonWidth, 40)) then
                            return true
                        end
                        return false
                    end)
                end
            end
        end
        ui.endPopup()
    end

    if currentConfig and ui.button("Delete Config") then
        closeGateEditor() 
        local configToDelete = currentConfig
        ui.modalDialog("Delete Configuration", function()
            ui.text("Are you sure you want to delete configuration '" .. configToDelete .. "'?")
            ui.newLine()
            ui.offsetCursorY(4)
            
            local buttonWidth = ui.availableSpaceX() / 2 - 4
            if ui.modernButton("Yes", vec2(buttonWidth, 40)) then
                if deleteConfig(configToDelete) then
                    ui.toast(ui.Icons.Confirm, "Configuration deleted: " .. configToDelete)
                else
                    ui.toast(ui.Icons.Warning, "Failed to delete configuration")
                end
                return true
            end
            ui.sameLine(0, 8)
            if ui.modernButton("No", vec2(buttonWidth, 40)) then
                return true
            end
            return false
        end)
    end

    ui.separator()


    if ui.button("Add Drift Zones by Click", not currentConfig and ui.ButtonFlags.Disabled or 0) then
        closeGateEditor()
        ui.openPopup("add_gate_click_popup")
    end
    if ui.itemHovered() and not currentConfig then
        ui.setTooltip('Please create or load a configuration first')
    end
    ui.sameLine(0, 4)

    if ui.beginPopup("add_gate_click_popup") then
        if ui.selectable("Start Gate") then
            if clickToAddGate then
                clearInterval(clickToAddGate)
                clickToAddGate = nil
            end
            selectedGateTypeToAdd = "start"
            clickToAddGate = setInterval(function(dt)
                if ac.getUI().isMouseLeftKeyClicked and not ac.getUI().wantCaptureMouse then
                    local pos = vec3()
                    local ray = render.createMouseRay()
                    if ray:physics(pos) ~= -1 then
                        addNewGateAtPosition(selectedGateTypeToAdd, pos, -ac.getSim().cameraLook)
                    end

                    clearInterval(clickToAddGate)
                    clickToAddGate = nil
                    selectedGateTypeToAdd = nil
                end
            end)
            ui.closePopup()
        end
        if ui.selectable("TG Zone (Touch And Go)") then
            if clickToAddGate then
                clearInterval(clickToAddGate)
                clickToAddGate = nil
            end
            selectedGateTypeToAdd = "normal"
            clickToAddGate = setInterval(function(dt)
                if ac.getUI().isMouseLeftKeyClicked and not ac.getUI().wantCaptureMouse then
                    local pos = vec3()
                    local ray = render.createMouseRay()
                    if ray:physics(pos) ~= -1 then
                        addNewGateAtPosition(selectedGateTypeToAdd, pos, -ac.getSim().cameraLook)
                    end

                    clearInterval(clickToAddGate)
                    clickToAddGate = nil
                    selectedGateTypeToAdd = nil
                end
            end)
            ui.closePopup()
        end
        if ui.selectable("OZ Zone") then
            if clickToAddGate then
                clearInterval(clickToAddGate)
                clickToAddGate = nil
            end
            selectedGateTypeToAdd = "OZ"
            clickToAddGate = setInterval(function(dt)
                if ac.getUI().isMouseLeftKeyClicked and not ac.getUI().wantCaptureMouse then
                    local pos = vec3()
                    local ray = render.createMouseRay()
                    if ray:physics(pos) ~= -1 then
                        addNewGateAtPosition(selectedGateTypeToAdd, pos, -ac.getSim().cameraLook)
                    end

                    clearInterval(clickToAddGate)
                    clickToAddGate = nil
                    selectedGateTypeToAdd = nil
                end
            end)
            ui.closePopup()
        end
        if ui.selectable("Finish Gate") then
            if clickToAddGate then
                clearInterval(clickToAddGate)
                clickToAddGate = nil
            end
            selectedGateTypeToAdd = "finish"
            clickToAddGate = setInterval(function(dt)
                if ac.getUI().isMouseLeftKeyClicked and not ac.getUI().wantCaptureMouse then
                    local pos = vec3()
                    local ray = render.createMouseRay()
                    if ray:physics(pos) ~= -1 then
                        addNewGateAtPosition(selectedGateTypeToAdd, pos, -ac.getSim().cameraLook)
                    end

                    clearInterval(clickToAddGate)
                    clickToAddGate = nil
                    selectedGateTypeToAdd = nil
                end
            end)
            ui.closePopup()
        end
        if ui.selectable("No-Go Zone") then
            if clickToAddGate then
                clearInterval(clickToAddGate)
                clickToAddGate = nil
            end
            selectedGateTypeToAdd = "no_go_zone"
            clickToAddGate = setInterval(function(dt)
                if ac.getUI().isMouseLeftKeyClicked and not ac.getUI().wantCaptureMouse then
                    local pos = vec3()
                    local ray = render.createMouseRay()
                    if ray:physics(pos) ~= -1 then
                        addNewGateAtPosition(selectedGateTypeToAdd, pos, -ac.getSim().cameraLook)
                    end

                    clearInterval(clickToAddGate)
                    clickToAddGate = nil
                    selectedGateTypeToAdd = nil
                end
            end)
            ui.closePopup()
        end
        if ui.selectable("Trajectory Correction") then
            if clickToAddGate then
                clearInterval(clickToAddGate)
                clickToAddGate = nil
            end
            selectedGateTypeToAdd = "trajectory"
            clickToAddGate = setInterval(function(dt)
                if ac.getUI().isMouseLeftKeyClicked and not ac.getUI().wantCaptureMouse then
                    local pos = vec3()
                    local ray = render.createMouseRay()
                    if ray:physics(pos) ~= -1 then
                        addNewGateAtPosition(selectedGateTypeToAdd, pos, -ac.getSim().cameraLook)
                    end

                    clearInterval(clickToAddGate)
                    clickToAddGate = nil
                    selectedGateTypeToAdd = nil
                end
            end)
            ui.closePopup()
        end
        ui.endPopup()
    end

    if ui.button("Add Start Positions and Entry Speed Line by Click", not currentConfig and ui.ButtonFlags.Disabled or 0) then
        ui.openPopup("start_positions_click_popup")
    end
    if ui.itemHovered() and not currentConfig then
        ui.setTooltip('Please create or load a configuration first')
    end

    ui.separator()

    if ui.button("Set Max Transitions", not currentConfig and ui.ButtonFlags.Disabled or 0) then
        ui.openPopup("max_transitions_popup")
    end
    if ui.itemHovered() and not currentConfig then
        ui.setTooltip('Please create or load a configuration first')
    end
    ui.sameLine(0, 4)

    if ui.button("Lines Transparency", not currentConfig and ui.ButtonFlags.Disabled or 0) then
        ui.openPopup("transparency_popup")
    end
    if ui.itemHovered() and not currentConfig then
        ui.setTooltip('Please create or load a configuration first')
    end
    ui.sameLine(0, 4)

    if ui.button("Set Perfect Entry Speed", not currentConfig and ui.ButtonFlags.Disabled or 0) then
        ui.openPopup("entry_speed_popup")
    end
    if ui.itemHovered() and not currentConfig then
        ui.setTooltip('Please create or load a configuration first')
    end

    if ui.beginPopup("start_positions_click_popup") then
        if ui.selectable("Initial Position") then
            beginStartPositionPlacement("initial")
            ui.closePopup()
        end
        if ui.selectable("Position at the Start Line") then
            beginStartPositionPlacement("line")
            ui.closePopup()
        end
        if ui.selectable("Entry Speed Detection Line") then
            beginStartPositionPlacement("entry_speed")
            ui.closePopup()
        end
        ui.endPopup()
    end

    if ui.beginPopup("max_transitions_popup") then
        local trackData = LocalGates.getTrackData()
        if not AppState.tempMaxTransitions then
            AppState.tempMaxTransitions = (trackData and trackData.maxAllowedTransitions) or 6
        end

        ui.text("Maximum allowed transitions:")
        ui.setNextItemWidth(200)

        local newValue = ui.slider("##transitions", AppState.tempMaxTransitions, 0, 99, "%.0f")
        if newValue ~= AppState.tempMaxTransitions then
            AppState.tempMaxTransitions = math.floor(newValue)
        end

        ui.separator()

        if ui.button("Apply") then
            setMaxTransitions(AppState.tempMaxTransitions)
            AppState.tempMaxTransitions = nil
            ui.closePopup()
        end
        ui.sameLine()
        if ui.button("Cancel") then
            AppState.tempMaxTransitions = nil
            ui.closePopup()
        end

        ui.endPopup()
    else
        AppState.tempMaxTransitions = nil
    end

    if ui.beginPopup("transparency_popup") then
        local trackData = LocalGates.getTrackData()
        if not trackData.gatesTransparency then
            trackData.gatesTransparency = {
                normal = 1.0,
                start = 1.0,
                finish = 1.0,
                oz = 1.0,
                noGoZone = 1.0,
                trajectory = 1.0
            }
        end

        if not AppState.tempTransparency then
            AppState.tempTransparency = {
                normal = trackData.gatesTransparency.normal or 1.0,
                start = trackData.gatesTransparency.start or 1.0,
                finish = trackData.gatesTransparency.finish or 1.0,
                oz = trackData.gatesTransparency.oz or 1.0,
                noGoZone = trackData.gatesTransparency.noGoZone or 1.0,
                trajectory = trackData.gatesTransparency.trajectory or 1.0
            }
        end

        ui.text("Lines transparency settings:")
        ui.separator()

        ui.text("Normal Gates:")
        ui.setNextItemWidth(200)
        AppState.tempTransparency.normal = ui.slider("##normal", AppState.tempTransparency.normal, 0.0, 1.0, "%.1f")

        ui.text("Start Gates:")
        ui.setNextItemWidth(200)
        AppState.tempTransparency.start = ui.slider("##start", AppState.tempTransparency.start, 0.0, 1.0, "%.1f")

        ui.text("Finish Gates:")
        ui.setNextItemWidth(200)
        AppState.tempTransparency.finish = ui.slider("##finish", AppState.tempTransparency.finish, 0.0, 1.0, "%.1f")

        ui.text("OZ Gates:")
        ui.setNextItemWidth(200)
        AppState.tempTransparency.oz = ui.slider("##oz", AppState.tempTransparency.oz, 0.0, 1.0, "%.1f")

        ui.text("No-Go Zones:")
        ui.setNextItemWidth(200)
        AppState.tempTransparency.noGoZone = ui.slider("##nogo", AppState.tempTransparency.noGoZone, 0.0, 1.0, "%.1f")

        ui.text("Trajectory Corrections:")
        ui.setNextItemWidth(200)
        AppState.tempTransparency.trajectory = ui.slider("##trajectory", AppState.tempTransparency.trajectory, 0.0, 1.0, "%.1f")

        ui.dummy(vec2(0, 4))

        if ui.button("Apply") then
            trackData.gatesTransparency = table.clone(AppState.tempTransparency)
            if LocalGates.saveToFile() then
                ui.toast(ui.Icons.Confirm, "Lines transparency settings saved")
            else
                ui.toast(ui.Icons.Warning, "Failed to save transparency settings")
            end
            AppState.tempTransparency = nil
            ui.closePopup()
        end
        ui.sameLine()
        if ui.button("Cancel") then
            AppState.tempTransparency = nil
            ui.closePopup()
        end

        ui.endPopup()
    else
        AppState.tempTransparency = nil
    end

    if ui.beginPopup("entry_speed_popup") then
        local trackData = LocalGates.getTrackData()
        if not AppState.tempEntrySpeed then
            AppState.tempEntrySpeed = trackData.perfectEntrySpeed or 120
        end

        ui.text("Perfect Entry Speed (km/h):")
        ui.setNextItemWidth(200)
        AppState.tempEntrySpeed = ui.slider("##entryspeed", AppState.tempEntrySpeed, 50, 250, "%.0f")

        ui.dummy(vec2(0, 4))

        if ui.button("Apply") then
            trackData.perfectEntrySpeed = AppState.tempEntrySpeed
            if LocalGates.saveToFile() then
                ui.toast(ui.Icons.Confirm, string.format("Perfect Entry Speed set to: %d km/h", AppState.tempEntrySpeed))
            else
                ui.toast(ui.Icons.Warning, "Failed to save Perfect Entry Speed")
            end
            AppState.tempEntrySpeed = nil
            ui.closePopup()
        end
        ui.sameLine()
        if ui.button("Cancel") then
            AppState.tempEntrySpeed = nil
            ui.closePopup()
        end

        ui.endPopup()
    else
        AppState.tempEntrySpeed = nil
    end

    ui.separator()
    

    local trackData = LocalGates.getTrackData()
    if trackData then
        ui.text("Start Positions:")

        if trackData.startPosition then
            ui.text(string.format("Initial: X: %.2f Y: %.2f Z: %.2f (Rotation: %.1f°)",
                trackData.startPosition.x,
                trackData.startPosition.y,
                trackData.startPosition.z,
                trackData.startRotation or 0))
        else
            ui.text("Initial position not set")
        end

        if trackData.alternateStartPosition then
            ui.text(string.format("At line: X: %.2f Y: %.2f Z: %.2f (Rotation: %.1f°)",
                trackData.alternateStartPosition.x,
                trackData.alternateStartPosition.y,
                trackData.alternateStartPosition.z,
                trackData.alternateStartRotation or 0))
        else
            ui.text("Line position not set")
        end

        ui.separator()
        ui.text("Track Settings:")
        ui.text(string.format("Max Transitions: %d", trackData.maxAllowedTransitions or 6))
    end

    ui.separator()

    for i, gate in ipairs(currentGates) do
        ui.pushID(i)

        local gateType = gate.type or "normal"
        local displayType = gateType
        if gateType == "normal" then
            displayType = "TG Zone"
        elseif gateType == "OZ" then
            displayType = "OZ Zone"
        elseif gateType == "start" then
            displayType = "Start"
        elseif gateType == "finish" then
            displayType = "Finish"
        end
        
        ui.text(string.format("%s #%d", displayType:upper(), i))
        ui.sameLine(100)

        local pos = string.format("X: %.2f Y: %.2f Z: %.2f",
            gate.position.x,
            gate.position.y,
            gate.position.z)
        ui.text(pos)
        ui.sameLine(300)

        if ui.button("Teleport and Edit##" .. i) then
            teleportCamera(gate, i, GATE_ARRAYS.NORMAL)
        end
        ui.sameLine(0, 4)

        if ui.button("Delete##" .. i) then
            closeGateEditor()
            addUndoPoint()
            table.remove(currentGates, i)
            LocalRenderGates.updateGates(currentGates)
        end

        if i < #currentGates then
            ui.separator()
        end

        ui.popID()
    end

    if #LocalGates.getNoGoZones() > 0 then
        ui.separator()
        ui.text("No-Go Zones:")
        ui.separator()

        local noGoZones = LocalGates.getNoGoZones()
        for i, zone in ipairs(noGoZones) do
            ui.pushID("nogo_" .. i)

            ui.text(string.format("NO-GO ZONE #%d", i))
            ui.sameLine(120)

            local pos = string.format("X: %.2f Y: %.2f Z: %.2f",
                zone.position.x,
                zone.position.y,
                zone.position.z)
            ui.text(pos)
            ui.sameLine(300)

            if ui.button("Teleport and Edit##" .. i) then
                teleportCamera(zone, i, GATE_ARRAYS.NOGO)
            end
            ui.sameLine(0, 4)

            if ui.button("Delete##" .. i) then
                closeGateEditor()  
                addUndoPoint()
                table.remove(noGoZones, i)
                LocalGates.setNoGoZones(noGoZones)
                LocalRenderGates.updateGates(currentGates)
            end

            if i < #noGoZones then
                ui.separator()
            end

            ui.popID()
        end
    end

    if #LocalGates.getTrajectoryGates() > 0 then
        ui.separator()
        ui.text("Trajectory Corrections:")
        ui.separator()

        local trajectoryGates = LocalGates.getTrajectoryGates()
        for i, gate in ipairs(trajectoryGates) do
            ui.pushID("traj_" .. i)

            ui.text(string.format("TRAJECTORY #%d", i))
            ui.sameLine(120)

            local pos = string.format("X: %.2f Y: %.2f Z: %.2f",
                gate.position.x,
                gate.position.y,
                gate.position.z)
            ui.text(pos)
            ui.sameLine(300)

            if ui.button("Teleport and Edit##" .. i) then
                teleportCamera(gate, i, GATE_ARRAYS.TRAJECTORY)
            end
            ui.sameLine(0, 4)

            if ui.button("Delete##" .. i) then
                closeGateEditor()  
                addUndoPoint()
                table.remove(trajectoryGates, i)
                LocalGates.setTrajectoryGates(trajectoryGates)
                LocalRenderGates.updateGates(currentGates)
            end

            if i < #trajectoryGates then
                ui.separator()
            end

            ui.popID()
        end
    end

    ui.separator()


    if ui.button("Create map for Drift Task") then
        local driftMap = require('drift_map')
        driftMap.generateMap()
    end
    ui.sameLine(0, 4)

    if ui.button("Save") or (uis.ctrlDown and ui.keyboardButtonPressed(ui.KeyIndex.S)) then
        local currentConfig = LocalGates.getCurrentConfig()
        if LocalGates.saveToFile() then
            savedUndoCounter = #undoStack
            saveLastConfig(currentConfig)  
            ui.toast(ui.Icons.Confirm, "Track data saved successfully")
        else
            ui.toast(ui.Icons.Warning, "Failed to save track data")
        end
    end
    if ui.itemHovered() then
        ui.setTooltip('Save track data to file (Ctrl+S)')
    end
    ui.sameLine(0, 4)

    if ui.button("Export to Game Mode") then
        local trackData = LocalGates.getTrackData()

        if trackData and 
           (math.abs(trackData.startPosition.x) < 0.01 and math.abs(trackData.startPosition.z) < 0.01) or
           (math.abs(trackData.alternateStartPosition.x) < 0.01 and math.abs(trackData.alternateStartPosition.z) < 0.01) then
            ui.toast(ui.Icons.Warning, "Please set both Initial and Line start positions before exporting")
        else

            if LocalGates.exportToGameMode() then
                local currentTrack = ac.getTrackID()
                local currentConfig = LocalGates.getCurrentConfig()
                

                local sourcePngPath = ac.getFolder(ac.FolderID.Root) .. 
                    '/apps/lua/DriftZonesEditor/tracks/' .. 
                    currentTrack .. '_' .. currentConfig .. '.png'
                

                local targetPngPath = ac.getFolder(ac.FolderID.Root) .. 
                    '/extension/lua/new-modes/drift-challenge/tracks/' .. 
                    currentTrack .. '.png'
                

                local sourceFile = io.open(sourcePngPath, 'rb')
                if sourceFile then
                    local targetFile = io.open(targetPngPath, 'wb')
                    if targetFile then
                        local content = sourceFile:read('*all')
                        targetFile:write(content)
                        targetFile:close()
                        sourceFile:close()
                        ui.toast(ui.Icons.Confirm, "Track configuration and map image exported successfully")
                    else
                        sourceFile:close()
                        ui.toast(ui.Icons.Warning, "Failed to export map image")
                    end
                else
                    ui.toast(ui.Icons.Warning, "Map image not found")
                end
            else
                ui.toast(ui.Icons.Warning, "Failed to export track configuration")
            end
        end
    end

    ui.popFont()
end

function update(dt)
    if not ac.isWindowOpen('main') then
        deactivateEditor()
    else
        activateEditor()
        

        if AppState.editorActive and ac.getUI().isMouseLeftKeyClicked and not ac.getUI().wantCaptureMouse then
            local pos = vec3()
            local ray = render.createMouseRay()
            if ray:physics(pos) ~= -1 then

                if not clickToAddGate then

                    if not checkClickOnGate(pos) then
                        closeGateEditor()
                    end
                end
            end
        end
    end
end

function windowSettings()
    return {
        title = 'Drift Zones Editor',
        defaultSize = vec2(400, 300)
    }
end

local clickToAddGate = nil
local selectedGateTypeToAdd = nil

local clickToAddStartPosition = nil
local startPositionTypeToAdd = nil

function beginStartPositionPlacement(positionType)
    if clickToAddStartPosition then
        clearInterval(clickToAddStartPosition)
        clickToAddStartPosition = nil
    end

    ui.toast(ui.Icons.Pointer, "Click on the track to set the start position")

    local capturedPositionType = positionType  

    clickToAddStartPosition = setInterval(function()
        if ac.getUI().isMouseLeftKeyClicked and not ac.getUI().wantCaptureMouse then
            local pos = vec3()
            local ray = render.createMouseRay()
            if ray:physics(pos) ~= -1 then
                setStartPositionByClick(capturedPositionType, pos, -ac.getSim().cameraLook)
            end

            clearInterval(clickToAddStartPosition)
            clickToAddStartPosition = nil
        end
    end)
end

function setStartPositionByClick(positionType, position, lookDir)
    local forward = vec3(lookDir.x, 0, lookDir.z):normalize()
    local carRotation = math.deg(math.atan2(forward.z, forward.x))
    
    local rayStart = position + vec3(0, 1, 0)
    local rayDir = vec3(0, -1, 0)
    local hitPoint = vec3()
    local hitNormal = vec3()
    local distance = physics.raycastTrack(rayStart, rayDir, 10, hitPoint, hitNormal)

    local finalPosition
    if distance ~= -1 then
        finalPosition = hitPoint
    else
        finalPosition = position
    end

    local trackData = LocalGates.getTrackData()
    if positionType == "initial" then
        trackData.startPosition = finalPosition
        trackData.startRotation = carRotation
        ui.toast(ui.Icons.Confirm, "Initial position set")
    elseif positionType == "line" then
        trackData.alternateStartPosition = finalPosition
        trackData.alternateStartRotation = carRotation
        ui.toast(ui.Icons.Confirm, "Position at the line set")
    elseif positionType == "entry_speed" then
        local halfLength = 5.0
        local lineRotation = carRotation + 90
        local rotationRad = math.rad(lineRotation)
        local forward = vec3(math.cos(rotationRad), 0, math.sin(rotationRad))
        
        trackData.entrySpeedLine = {
            position = finalPosition,
            rotation = lineRotation,
            length = 15.0,
            center = finalPosition
        }
        ui.toast(ui.Icons.Confirm, "Entry speed line set")
    end

    if LocalGates.saveToFile() then
        loadCurrentTrackGates()
    else
        ui.toast(ui.Icons.Warning, "Failed to save track data")
    end
end

function windowFAQ()
    local screenSize = ui.windowSize()
    local windowSize = vec2(400, 300) 
    local pos = vec2(
        (screenSize.x - windowSize.x) / 2,
        (screenSize.y - windowSize.y) / 2
    )
    
    ui.setNextWindowPosition(pos, vec2(0, 0)) 
    
    ui.pushFont(ui.Font.Small)
    
    ui.textColored("Drift Challenge Editor: FAQ")
    ui.separator()
    
    ui.text("How to create a drift track:")
    ui.text("")
    ui.text("1. Create Track Config:")
    ui.text("   - Begin by creating a new config or loading an existing one.")
    ui.text("   - The Drift Zones Editor supports multiple configs.")
    ui.text("")
    ui.text("2. Drift Zones Placement:")
    ui.text("   - Start by placing the START gate.")
    ui.text("   - Add TG zones and OZ zones.")
    ui.text("   - Complete the track with a FINISH gate.")
    ui.text("")
    ui.text("   - Use TELEPORT and EDIT in Free Mode to set up settings.")
    ui.text("   - You can click on an existing zone to edit it.")
    ui.text("")
    ui.text("3. Gate Editor:")
    ui.text("   - Each TG and OZ zone has a Drift Zone Bonus Rate.")
    ui.text("   - For challenging zones, you can set up to a 2x multiplier.")
    ui.text("   - Maximum score remains the same (75 points for TG and OZ zones).")
    ui.text("")
    ui.text("4. Additional Zones and Examples:")
    ui.text("   - No Go Zone: 10-point penalty areas.")
    ui.text("   - Trajectory Correction Zone: Small penalty for more precise drift trajectory control.")
    ui.text("")
    ui.text("    - Example of use: Create 5 OZ Zones with a 0.20 Bonus Rate each")
    ui.text("    to achieve a total value equal to 1 zone with a 1.00 multiplier.")
    ui.text("    - You can grab OZ Zones with the front and rear wheels.")
    ui.text("    - You can grab TG Zones ONLY with the rear wheels.")
    ui.text("")
    ui.text("5. Start Positions and Entry Speed Line:")
    ui.text("   - Initial Position: Warm up your tires and get to the start.")
    ui.text("   - Position at Start Line: Quick restart position")
    ui.text("    !! (Preserves tire temperature after the first start) !!")
    ui.text("   - Entry Speed Detection Line: Captures your speed to score Entry Speed points.")
    ui.text("   - Slowing down from acceleration over 15 km/h will be an alternative")
    ui.text("    detection even without a line.")
    ui.text("")
    ui.text("7. Additions:")
    ui.text("     Max Transitions Setting:")
    ui.text("   - System to control opposite drift.")
    ui.text("   - Count the required drift transitions on your track.")
    ui.text("   - Set the exact number.")
    ui.text("")
    ui.text("   Lines Transparency:     ")
    ui.text("   - Adjust for competition tracks or hide specific gates for visuals.")
    ui.text("")
    ui.text("   Set Perfect Entry Speed:     ")
    ui.text("   - Set Entry Speed number for 100% points.")
    ui.text("")
    ui.text("8. Create Map for Drift Task:")
    ui.text("   - Create a PNG map for Drift Challenge Game Mode.")
    ui.text("   - The track shape is created by placed Zones and Gates.")
    ui.text("   - Consider adding additional zones or alternate locations to create a better map.")
    ui.text("   - The Save Map button will modify the track file, ready for export to Drift Challenge.")
    ui.text("   - You can create your own PNG map. Place the PNG file into Drift Challenge with a matching track name:")
    ui.text("    /assettocorsa/extension/lua/new-modes/drift-challenge/tracks")
    ui.text("    For example, tsukuba_fia_drift2019.png for tsukuba_fia_drift2019.lua.")
    ui.text("")
    ui.text("9. Final Settings:")
    ui.text("   - Save: Save your configuration in the Drift Zones Editor.")
    ui.text("   - Export to Game Mode: Export for Drift Challenge.")
    ui.text("")
    ui.text("After exporting, exit the game and launch Drift Challenge.")
    ui.text("")
    ui.text("How to activate Free Cam (F7).")
    ui.text("Put ALLOW_FREE_CAMERA=1. Modify assetto_corsa.ini")
    ui.text("in /Steam/steamapps/common/assettocorsa/system/cfg ")
    ui.text("")



    ui.popFont()
end

