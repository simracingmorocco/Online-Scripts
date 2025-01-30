local LocalGates = {}

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

local DEFAULT_TRACK_DATA = {
    gates = {},
    noGoZones = {},
    trajectoryGates = {},
    maxAllowedTransitions = 99,
    startPosition = vec3(0, 0, 0),
    startRotation = 0,
    alternateStartPosition = vec3(0, 0, 0),
    alternateStartRotation = 0,
    gatesTransparency = {
        normal = 1.0,
        start = 1.0,
        finish = 1.0,
        oz = 1.0,
        noGoZone = 1.0,
        trajectory = 1.0
    },
    perfectEntrySpeed = 120
}

local Gate = {}
Gate.__index = Gate

function Gate.new(data)
    local self = setmetatable({}, Gate)
    self.position = data.position
    self.rotation = data.rotation
    self.size = data.size
    self.type = data.type
    self.score_multiplier = data.score_multiplier or 1
    return self
end

local function createGate(data)
    return Gate.new(data)
end

local currentTrack = nil
local trackData = nil
local currentConfig = "default"

function LocalGates.setCurrentTrack(track, config)
    currentTrack = track
    currentConfig = nil
    
    local configs = LocalGates.getAvailableConfigs()
    if #configs > 0 then
        if config and config ~= "" then
            currentConfig = config
        else
            currentConfig = configs[1]
        end
        
        local success, result = pcall(require, string.format('tracks.%s_%s', track, currentConfig))
        if success then
            trackData = result
            return true
        end
    end
    
    currentConfig = nil
    trackData = deepcopy(DEFAULT_TRACK_DATA)
    return true
end

function LocalGates.getGates()
    return trackData and trackData.gates or {}
end

function LocalGates.getNoGoZones()
    return trackData and trackData.noGoZones or {}
end

function LocalGates.getTrajectoryGates()
    return trackData and trackData.trajectoryGates or {}
end

function LocalGates.getTrackData()
    return trackData
end

function doPolygonsIntersect(poly1, poly2)
    for i = 1, #poly1 do
        if isPointInsidePolygon(poly1[i], poly2) then
            return true
        end
    end
    for i = 1, #poly2 do
        if isPointInsidePolygon(poly2[i], poly1) then
            return true
        end
    end
    return false
end

function isPointInsidePolygon(point, polygon)
    local inside = false
    local j = #polygon
    for i = 1, #polygon do
        if (polygon[i].y > point.y) ~= (polygon[j].y > point.y) and
           point.x < (polygon[j].x - polygon[i].x) * (point.y - polygon[i].y) / (polygon[j].y - polygon[i].y) + polygon[i].x then
            inside = not inside
        end
        j = i
    end
    return inside
end

function LocalGates.isCarInGate(car, gate)
    local halfCarWidth = car.aabbSize.x / 2
    local halfCarLength = car.aabbSize.z / 2
    local halfGateWidth = gate.size.width / 2
    local halfGateLength = gate.size.length / 2
    local angleRad = math.rad(gate.rotation + 0)
    local cosAngle = math.cos(angleRad)
    local sinAngle = math.sin(angleRad)

    local gateCorners = {
        vec2(-halfGateWidth, -halfGateLength),
        vec2(halfGateWidth, -halfGateLength),
        vec2(halfGateWidth, halfGateLength),
        vec2(-halfGateWidth, halfGateLength)
    }

    for i, corner in ipairs(gateCorners) do
        local rotatedX = corner.x * cosAngle - corner.y * sinAngle
        local rotatedY = corner.x * sinAngle + corner.y * cosAngle
        gateCorners[i] = vec2(rotatedX + gate.position.x, rotatedY + gate.position.z)
    end

    local carCorners = {
        vec2(-halfCarWidth, -halfCarLength),
        vec2(halfCarWidth, -halfCarLength),
        vec2(halfCarWidth, halfCarLength),
        vec2(-halfCarWidth, halfCarLength)
    }

    for i, corner in ipairs(carCorners) do
        local worldPos = car.position 
            + car.look * corner.y 
            + car.side * corner.x
        carCorners[i] = vec2(worldPos.x, worldPos.z)
    end

    if doPolygonsIntersect(carCorners, gateCorners) then
        local carCenter = vec2(car.position.x, car.position.z)
        local gateCenter = vec2(gate.position.x, gate.position.z)
        local gateDirection = vec2(math.cos(angleRad), math.sin(angleRad))
        local carToGateVector = carCenter - gateCenter
        local projectionLength = carToGateVector:dot(gateDirection)
        local percentage = ((projectionLength + halfGateLength) / (2 * halfGateLength)) * 100
        percentage = math.min(math.max(percentage, 0), 100)
        return true, percentage
    end

    return false, 0
end

function LocalGates.isCarInAnyGate(car)
    if not currentTrack then return 0, nil, 0 end

    local gates = LocalGates.getGates()
    for i, gate in ipairs(gates) do
        local isInGate, percentage = LocalGates.isCarInGate(car, gate)
        if isInGate then
            local gateType = gate.type
            return i, gateType, percentage
        end
    end

    local noGoZones = LocalGates.getNoGoZones()
    for i, zone in ipairs(noGoZones) do
        local isInGate, _ = LocalGates.isCarInGate(car, zone)
        if isInGate then
            return -i, "no_go_zone", 0
        end
    end

    local trajectoryGates = LocalGates.getTrajectoryGates()
    for i, gate in ipairs(trajectoryGates) do
        local isInGate, percentage = LocalGates.isCarInGate(car, gate)
        if isInGate then
            return -i, "trajectorygate", percentage
        end
    end

    return 0, nil, 0
end

function LocalGates.isTrackSupported()
    return currentTrack ~= nil and trackData ~= nil
end

function LocalGates.setGates(gates)
    if trackData then
        trackData.gates = gates
    end
end

function LocalGates.setNoGoZones(zones)
    if trackData then
        trackData.noGoZones = zones
    end
end

function LocalGates.setTrajectoryGates(gates)
    if trackData then
        trackData.trajectoryGates = gates
    end
end

function LocalGates.setTrackData(newTrackData)
    if trackData then
        trackData = newTrackData
    end
end

local function formatVec3(vec)
    if not vec then return "vec3(0, 0, 0)" end
    return string.format("vec3(%.3f, %.3f, %.3f)", vec.x, vec.y, vec.z)
end

local function formatVec2(vec)
    if not vec then return "vec2(0, 0)" end
    return string.format("vec2(%.3f, %.3f)", vec.x, vec.y)
end

local function ensureDirectoryExists(path)
    local function splitPath(str)
        return str:match("(.*\\)")
    end

    local directory = splitPath(path)
    if directory then
        os.execute('md "' .. directory .. '" 2>nul')
    end
end

function LocalGates.saveToFile(configName)
    if not currentTrack then
        ac.debug("No track selected")
        return false
    end

    if configName and configName ~= currentConfig then
        ac.debug("Cannot save to different configuration")
        return false
    end

    local tracksDir = ac.getFolder(ac.FolderID.Root) .. '/apps/lua/DriftZonesEditor/tracks/'
    local filePath = tracksDir .. currentTrack .. '_' .. currentConfig .. '.lua'
    
    ensureDirectoryExists(filePath)

    if not trackData.startPosition then
        trackData.startPosition = vec3(0, 0, 0)
        trackData.startRotation = 0
        ac.debug("startPosition was nil, initialized to default")
    end

    if not trackData.alternateStartPosition then
        trackData.alternateStartPosition = vec3(0, 0, 0)
        trackData.alternateStartRotation = 0
        ac.debug("alternateStartPosition was nil, initialized to default")
    end

    local fileContent = [[local LocalGates = require('local_gates')

return {
]]

    fileContent = fileContent .. "    gates = {\n"
    for i, gate in ipairs(trackData.gates or {}) do
        fileContent = fileContent .. string.format([[        { type = %q, position = %s, rotation = %.3f, pitch = %.1f, roll = %.1f, size = {width = %.3f, length = %.3f}%s%s%s%s%s%s%s%s },
]], 
            gate.type or "normal",
            formatVec3(gate.position),
            gate.rotation or 0,
            gate.pitch or 0,
            gate.roll or 0,
            gate.size.width or 2,
            gate.size.length or 5,
            gate.score_multiplier and string.format(", score_multiplier = %.2f", gate.score_multiplier) or "",
            gate.target_angle and string.format(", target_angle = %.0f", gate.target_angle) or "",
            gate.thickness and string.format(", thickness = %.3f", gate.thickness) or "",
            gate.heightOffset and string.format(", heightOffset = %.3f", gate.heightOffset) or "",
            gate.line_width and string.format(", line_width = %.2f", gate.line_width) or "",
            gate.color_r and string.format(", color_r = %.2f", gate.color_r) or "",
            gate.color_g and string.format(", color_g = %.2f", gate.color_g) or "",
            gate.color_b and string.format(", color_b = %.2f", gate.color_b) or ""
        )
    end
    fileContent = fileContent .. "    },\n"

    fileContent = fileContent .. "    noGoZones = {\n"
    for i, zone in ipairs(trackData.noGoZones or {}) do
        fileContent = fileContent .. string.format([[        {
            position = %s,
            rotation = %.3f,
            size = {width = %.3f, length = %.3f}%s%s
        },
]], 
            formatVec3(zone.position),
            zone.rotation or 0,
            zone.size.width or 2,
            zone.size.length or 5,
            zone.heightOffset and string.format(",\n            heightOffset = %.3f", zone.heightOffset) or "",
            zone.line_width and string.format(",\n            line_width = %.2f", zone.line_width) or ""
        )
    end
    fileContent = fileContent .. "    },\n"

    fileContent = fileContent .. "    trajectoryGates = {\n"
    for i, gate in ipairs(trackData.trajectoryGates or {}) do
        fileContent = fileContent .. string.format([[        {
            type = "trajectory",
            position = %s,
            rotation = %.3f,
            pitch = %.1f,
            roll = %.1f,
            size = {width = %.3f, length = %.3f}%s%s
        },
]], 
            formatVec3(gate.position),
            gate.rotation or 0,
            gate.pitch or 0,
            gate.roll or 0,
            gate.size.width or 2,
            gate.size.length or 5,
            gate.heightOffset and string.format(",\n            heightOffset = %.3f", gate.heightOffset) or "",
            gate.line_width and string.format(",\n            line_width = %.2f", gate.line_width) or ""
        )
    end
    fileContent = fileContent .. "    },\n"

    if trackData.mapSettings then
        fileContent = fileContent .. "    mapSettings = {\n"
        fileContent = fileContent .. string.format([[        scale = { x = %.3f, y = %.3f },
        curvature = %.3f,
        rotation = %.3f,
        tension = %.3f,
        mergeDistance = %.3f,
        lineWidth = %.3f,
        startLine = {
            length = %.3f,
            angle = %.3f
        },
        finishLine = {
            length = %.3f,
            angle = %.3f
        }
    },
]], 
            trackData.mapSettings.scale.x,
            trackData.mapSettings.scale.y,
            trackData.mapSettings.curvature,
            trackData.mapSettings.rotation,
            trackData.mapSettings.tension,
            trackData.mapSettings.mergeDistance,
            trackData.mapSettings.lineWidth,
            trackData.mapSettings.startLine.length,
            trackData.mapSettings.startLine.angle,
            trackData.mapSettings.finishLine.length,
            trackData.mapSettings.finishLine.angle
        )
    end

    if trackData.squareSettings then
        fileContent = fileContent .. "    squareSettings = {\n"
        for i, square in ipairs(trackData.squareSettings) do
            fileContent = fileContent .. string.format([[        {
            index = %d,
            offset = %s,
            rotation = %.3f,
            size = {width = %.3f, height = %.3f},
            deleted = %s
        },
]], 
                square.index,
                formatVec2(square.offset),
                square.rotation or 0,
                square.size.width,
                square.size.height,
                tostring(square.deleted or false)
            )
        end
        fileContent = fileContent .. "    },\n"
    end

    if trackData.mapTexts then
        fileContent = fileContent .. "    mapTexts = {\n"
        for _, text in ipairs(trackData.mapTexts) do
            fileContent = fileContent .. string.format([[        {
            text = %q,
            position = vec2(%.3f, %.3f)
        },
]], 
                text.text,
                text.position.x,
                text.position.y
            )
        end
        fileContent = fileContent .. "    },\n"
    end

    if trackData.entrySpeedLine then
        fileContent = fileContent .. string.format([[    entrySpeedLine = {
        position = %s,
        rotation = %.3f,
        length = %.3f
    },
]], 
        formatVec3(trackData.entrySpeedLine.position),
        trackData.entrySpeedLine.rotation,
        trackData.entrySpeedLine.length
    )
    end

    fileContent = fileContent .. string.format([[    maxAllowedTransitions = %d,

    startPosition = %s,
    startRotation = %.3f,
    alternateStartPosition = %s,
    alternateStartRotation = %.3f,
    perfectEntrySpeed = %d,
    gatesTransparency = {
        normal = %.1f,
        start = %.1f,
        finish = %.1f,
        oz = %.1f,
        noGoZone = %.1f,
        trajectory = %.1f
    }
}]], 
        trackData.maxAllowedTransitions or 0,
        formatVec3(trackData.startPosition),
        trackData.startRotation or 0,
        formatVec3(trackData.alternateStartPosition),
        trackData.alternateStartRotation or 0,
        trackData.perfectEntrySpeed or 120,
        (trackData.gatesTransparency and trackData.gatesTransparency.normal) or 1.0,
        (trackData.gatesTransparency and trackData.gatesTransparency.start) or 1.0,
        (trackData.gatesTransparency and trackData.gatesTransparency.finish) or 1.0,
        (trackData.gatesTransparency and trackData.gatesTransparency.oz) or 1.0,
        (trackData.gatesTransparency and trackData.gatesTransparency.noGoZone) or 1.0,
        (trackData.gatesTransparency and trackData.gatesTransparency.trajectory) or 1.0
    )

    local file = io.open(filePath, 'w')
    if file then
        file:write(fileContent)
        file:close()
        ac.debug("Track data saved successfully to " .. filePath)
        return true
    else
        ac.debug("Failed to open file for writing: " .. filePath)
        return false
    end
end

function LocalGates.exportToGameMode()
    if not currentTrack or not trackData then
        ac.debug("No track data to export")
        return false
    end

    local gameModeDir = ac.getFolder(ac.FolderID.ExtRoot) .. '\\lua\\new-modes\\drift-challenge\\tracks\\'
    local filePath = gameModeDir .. currentTrack .. '.lua'
    
    ac.debug("Attempting to export to: " .. filePath)
    
    ensureDirectoryExists(filePath)

    local fileContent = [[local LocalGates = require('local_gates')

return {
]]

    fileContent = fileContent .. "    gates = {\n"
    for i, gate in ipairs(trackData.gates or {}) do
        fileContent = fileContent .. string.format([[        { type = %q, position = %s, rotation = %.3f, pitch = %.1f, roll = %.1f, size = {width = %.3f, length = %.3f}%s%s%s%s%s%s%s%s },
]], 
            gate.type or "normal",
            formatVec3(gate.position),
            gate.rotation or 0,
            gate.pitch or 0,
            gate.roll or 0,
            gate.size.width or 2,
            gate.size.length or 5,
            gate.score_multiplier and string.format(", score_multiplier = %.2f", gate.score_multiplier) or "",
            gate.target_angle and string.format(", target_angle = %.0f", gate.target_angle) or "",
            gate.thickness and string.format(", thickness = %.3f", gate.thickness) or "",
            gate.heightOffset and string.format(", heightOffset = %.3f", gate.heightOffset) or "",
            gate.line_width and string.format(", line_width = %.2f", gate.line_width) or "",
            gate.color_r and string.format(", color_r = %.2f", gate.color_r) or "",
            gate.color_g and string.format(", color_g = %.2f", gate.color_g) or "",
            gate.color_b and string.format(", color_b = %.2f", gate.color_b) or ""
        )
    end
    fileContent = fileContent .. "    },\n"

    fileContent = fileContent .. "    noGoZones = {\n"
    for i, zone in ipairs(trackData.noGoZones or {}) do
        fileContent = fileContent .. string.format([[        {
            position = %s,
            rotation = %.3f,
            size = {width = %.3f, length = %.3f}%s%s
        },
]], 
            formatVec3(zone.position),
            zone.rotation or 0,
            zone.size.width or 2,
            zone.size.length or 5,
            zone.heightOffset and string.format(",\n            heightOffset = %.3f", zone.heightOffset) or "",
            zone.line_width and string.format(",\n            line_width = %.2f", zone.line_width) or ""
        )
    end
    fileContent = fileContent .. "    },\n"

    fileContent = fileContent .. "    trajectoryGates = {\n"
    for i, gate in ipairs(trackData.trajectoryGates or {}) do
        fileContent = fileContent .. string.format([[        {
            type = "trajectory",
            position = %s,
            rotation = %.3f,
            pitch = %.1f,
            roll = %.1f,
            size = {width = %.3f, length = %.3f}%s%s
        },
]], 
            formatVec3(gate.position),
            gate.rotation or 0,
            gate.pitch or 0,
            gate.roll or 0,
            gate.size.width or 2,
            gate.size.length or 5,
            gate.heightOffset and string.format(",\n            heightOffset = %.3f", gate.heightOffset) or "",
            gate.line_width and string.format(",\n            line_width = %.2f", gate.line_width) or ""
        )
    end
    fileContent = fileContent .. "    },\n"

    if trackData.mapSettings then
        fileContent = fileContent .. "    mapSettings = {\n"
        fileContent = fileContent .. string.format([[        scale = { x = %.3f, y = %.3f },
        curvature = %.3f,
        rotation = %.3f,
        tension = %.3f,
        mergeDistance = %.3f,
        lineWidth = %.3f,
        startLine = {
            length = %.3f,
            angle = %.3f
        },
        finishLine = {
            length = %.3f,
            angle = %.3f
        }
    },
]], 
            trackData.mapSettings.scale.x,
            trackData.mapSettings.scale.y,
            trackData.mapSettings.curvature,
            trackData.mapSettings.rotation,
            trackData.mapSettings.tension,
            trackData.mapSettings.mergeDistance,
            trackData.mapSettings.lineWidth,
            trackData.mapSettings.startLine.length,
            trackData.mapSettings.startLine.angle,
            trackData.mapSettings.finishLine.length,
            trackData.mapSettings.finishLine.angle
        )
    end

    if trackData.squareSettings then
        fileContent = fileContent .. "    squareSettings = {\n"
        for i, square in ipairs(trackData.squareSettings) do
            fileContent = fileContent .. string.format([[        {
            index = %d,
            offset = %s,
            rotation = %.3f,
            size = {width = %.3f, height = %.3f},
            deleted = %s
        },
]], 
                square.index,
                formatVec2(square.offset),
                square.rotation or 0,
                square.size.width,
                square.size.height,
                tostring(square.deleted or false)
            )
        end
        fileContent = fileContent .. "    },\n"
    end

    if trackData.mapTexts then
        fileContent = fileContent .. "    mapTexts = {\n"
        for _, text in ipairs(trackData.mapTexts) do
            fileContent = fileContent .. string.format([[        {
            text = %q,
            position = vec2(%.3f, %.3f)
        },
]], 
                text.text,
                text.position.x,
                text.position.y
            )
        end
        fileContent = fileContent .. "    },\n"
    end

    if trackData.entrySpeedLine then
        fileContent = fileContent .. string.format([[    entrySpeedLine = {
        position = %s,
        rotation = %.3f,
        length = %.3f
    },
]], 
        formatVec3(trackData.entrySpeedLine.position),
        trackData.entrySpeedLine.rotation,
        trackData.entrySpeedLine.length
    )
    end

    fileContent = fileContent .. string.format([[    maxAllowedTransitions = %d,

    startPosition = %s,
    startRotation = %.3f,
    alternateStartPosition = %s,
    alternateStartRotation = %.3f,
    perfectEntrySpeed = %d,
    gatesTransparency = {
        normal = %.1f,
        start = %.1f,
        finish = %.1f,
        oz = %.1f,
        noGoZone = %.1f,
        trajectory = %.1f
    }
}]], 
        trackData.maxAllowedTransitions or 0,
        formatVec3(trackData.startPosition),
        trackData.startRotation or 0,
        formatVec3(trackData.alternateStartPosition),
        trackData.alternateStartRotation or 0,
        trackData.perfectEntrySpeed or 120,
        (trackData.gatesTransparency and trackData.gatesTransparency.normal) or 1.0,
        (trackData.gatesTransparency and trackData.gatesTransparency.start) or 1.0,
        (trackData.gatesTransparency and trackData.gatesTransparency.finish) or 1.0,
        (trackData.gatesTransparency and trackData.gatesTransparency.oz) or 1.0,
        (trackData.gatesTransparency and trackData.gatesTransparency.noGoZone) or 1.0,
        (trackData.gatesTransparency and trackData.gatesTransparency.trajectory) or 1.0
    )

    local file = io.open(filePath, 'w')
    if file then
        file:write(fileContent)
        file:close()
        ac.debug("Track data exported successfully to " .. filePath)
        return true
    else
        ac.debug("Failed to export file: " .. filePath)
        return false
    end
end

function LocalGates.getCurrentConfig()
    return currentConfig
end

function LocalGates.setCurrentConfig(configName)
    if not configName or configName == "" then
        return false
    end

    currentConfig = configName
    if currentTrack then
        local success, result = pcall(require, string.format('tracks.%s_%s', currentTrack, currentConfig))
        if success then
            trackData = result
            if not trackData.mapSettings then
                trackData.mapSettings = {
                    scale = { x = 1.0, y = 1.0 },
                    curvature = 1.0,
                    rotation = 0.0,
                    tension = -0.5,
                    mergeDistance = 5.0,
                    lineWidth = 60.0,
                    startLine = {
                        length = 20.0,
                        angle = 0.0
                    },
                    finishLine = {
                        length = 20.0,
                        angle = 0.0
                    }
                }
            end
            return true
        else
            trackData = deepcopy(DEFAULT_TRACK_DATA)
            trackData.mapSettings = {
                scale = { x = 1.0, y = 1.0 },
                curvature = 1.0,
                rotation = 0.0,
                tension = -0.5,
                mergeDistance = 5.0,
                lineWidth = 60.0,
                startLine = {
                    length = 20.0,
                    angle = 0.0
                },
                finishLine = {
                    length = 20.0,
                    angle = 0.0
                }
            }
            return true
        end
    end
    return false
end

function LocalGates.getAvailableConfigs()
    if not currentTrack then return {} end
    
    local configs = {}
    local tracksDir = ac.getFolder(ac.FolderID.Root) .. '/apps/lua/DriftZonesEditor/tracks/'
    
    local files = io.scanDir(tracksDir, currentTrack .. '_*.lua')
    for _, filename in ipairs(files) do
        local config = filename:match(currentTrack .. '_(.+)%.lua')
        if config then
            table.insert(configs, config)
        end
    end

    table.sort(configs)
    
    return configs
end

return LocalGates
