local DriftMap = {}

local DEFAULT_SIZES = {
    normal = { width = 32, height = 12 },
    OZ = { width = 12, height = 2 },
    start = { width = 40, height = 15 },
    finish = { width = 40, height = 15 },
    trajectory = { width = 19, height = 5 },
    nogo = { width = 12, height = 2 }
}

local map_scale_x = 1.0
local map_scale_y = 1.0
local map_curvature = 1.0
local map_rotation_angle = 0.0
local map_tension = -0.5

local start_line_length = 20.0
local start_line_angle = 0.0
local finish_line_length = 20.0
local finish_line_angle = 0.0

local map_points = {}
local rotation_radians = 0
local hud_scale = 1.0

local colors = {
    BLACK = rgbm(0, 0, 0, 0.5),
    BLACK2 = rgbm(1, 1, 1, 0.1),
    WHITE = rgbm(1, 1, 1, 1),
    WHITE2 = rgbm(1, 1, 1, 0),
    GREEN = rgbm(0, 1, 0, 1),
    RED = rgbm(1, 0, 0, 1),
}

local min_pos = vec2(math.huge, math.huge)
local max_pos = vec2(-math.huge, -math.huge)

local isGateCreationMode = false
local isDraggingGate = false
local selectedGateIndex = nil
local dragStartPos = nil
local selectedGate = nil

local original_min_pos = vec2(math.huge, math.huge)
local original_max_pos = vec2(-math.huge, -math.huge)

local gate_merge_distance = 5.0

local isTextCreationMode = false
local selectedText = nil
local textOptions = {
    "Start",
    "Finish",
    "TG",
    "OZ",
    "NG"
}

local tempGates = {}
local tempTexts = {}

local square_offsets = {}
local square_rotations = {}
local square_sizes = {}
local square_deleted = {}
local square_points = {}

local no_go_square_points = {}
local no_go_square_offsets = {}
local no_go_square_rotations = {}
local no_go_square_sizes = {}
local no_go_square_deleted = {}

local isSquareSelected = false
local selectedSquareIndex = nil

local isNoGoSquareSelected = false
local selectedNoGoSquareIndex = nil

local DEFAULT_WIDTH = 40
local DEFAULT_HEIGHT = 15

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

local function rotatePoint(point, angleDegrees)
    local angleRad = math.rad(angleDegrees)
    local cosRot = math.cos(angleRad)
    local sinRot = math.sin(angleRad)
    return vec2(
        point.x * cosRot - point.y * sinRot,
        point.x * sinRot + point.y * cosRot
    )
end

local function lerp(a, b, t)
    return a + (b - a) * t
end

local function rotatePointAround(point, center, angle)
    local s = math.sin(math.rad(angle))
    local c = math.cos(math.rad(angle))
    local px = point.x - center.x
    local py = point.y - center.y
    local rotated_x = px * c - py * s
    local rotated_y = px * s + py * c
    return vec2(
        rotated_x + center.x,
        rotated_y + center.y
    )
end

function math.clamp(value, min_, max_)
    if value < min_ then return min_ end
    if value > max_ then return max_ end
    return value
end

local function remap(value, in_min, in_max, out_min, out_max)
    return (value - in_min) / (in_max - in_min) * (out_max - out_min) + out_min
end

local function cubicHermite(p0, p1, p2, p3, t, tension)
    tension = tension or 0.0
    local m1 = ((p2 - p0) * (1 + tension)) / 2
    local m2 = ((p3 - p1) * (1 + tension)) / 2

    local t2 = t * t
    local t3 = t2 * t

    local h00 = 2 * t3 - 3 * t2 + 1
    local h10 = t3 - 2 * t2 + t
    local h01 = -2 * t3 + 3 * t2
    local h11 = t3 - t2

    return h00 * p1 + h10 * m1 + h01 * p2 + h11 * m2
end

local function world_point_remap(to_remap)
    return vec2(
        remap(to_remap.x, min_pos.x, max_pos.x, 0, 1),
        remap(to_remap.y, min_pos.y, max_pos.y, 0, 1)
    )
end

local function center_to_map(normalized, map_center_pos, mapsize, map_aspect)
    if map_aspect > 1 then
        local corner_tl = map_center_pos - vec2(mapsize, mapsize / map_aspect) / 2
        return corner_tl + normalized * vec2(mapsize, mapsize / map_aspect)
    else
        local corner_tl = map_center_pos - vec2(mapsize * map_aspect, mapsize) / 2
        return corner_tl + normalized * vec2(mapsize * map_aspect, mapsize)
    end
end

local function calculateMaxRadius(points, center)
    local maxRadius = 0
    for _, point in ipairs(points) do
        local distance = (point - center):length()
        if distance > maxRadius then
            maxRadius = distance
        end
    end
    return maxRadius
end

local function gateWorldToScreen(worldPos, map_view_size)
    return vec2(
        remap(worldPos.x, original_min_pos.x, original_max_pos.x, 0, map_view_size.x),
        remap(worldPos.y, original_min_pos.y, original_max_pos.y, 0, map_view_size.y)
    )
end

local function gateScreenToWorld(screenPos, map_view_size)
    return vec2(
        remap(screenPos.x, 0, map_view_size.x, original_min_pos.x, original_max_pos.x),
        remap(screenPos.y, 0, map_view_size.y, original_min_pos.y, original_max_pos.y)
    )
end

local function drawMapText(text, screenPos, map_view_size)
    local textSize = 27
    ui.pushDWriteFont('Montserrat:\\Fonts')
    local shadowOffsets = { vec2(1, 1), vec2(-1, 1), vec2(1, -1), vec2(-1, -1) }
    for _, offset in ipairs(shadowOffsets) do
        ui.dwriteDrawText(text, textSize, screenPos + offset, rgbm(0, 0, 0, 0.6))
    end
    local textColor = text:match("^NG") and rgbm(1, 0.3, 0.3, 1) or rgbm(1, 1, 1, 1)
    ui.dwriteDrawText(text, textSize, screenPos, textColor)
    ui.popDWriteFont()
end

local function updateTextNumbering(textType)
    if textType == "Start" or textType == "Finish" then return end
    if not tempTexts then return end
    local typeTexts = {}
    for i, textObj in ipairs(tempTexts) do
        if textObj.text:match("^" .. textType) then
            table.insert(typeTexts, {
                index = i,
                number = tonumber(textObj.text:match("-(%d+)$")) or 0
            })
        end
    end
    table.sort(typeTexts, function(a, b) return a.number < b.number end)
    for i, textData in ipairs(typeTexts) do
        tempTexts[textData.index].text = textType .. "-" .. i
    end
end

local function findClosestPointOnPath(position)
    local minDistSquared = math.huge
    local closestIndex = 1
    for i = 1, #map_points do
        local point = map_points[i]
        local dx = point.x - position.x
        local dy = point.y - position.y
        local distSquared = dx * dx + dy * dy
        if distSquared < minDistSquared then
            minDistSquared = distSquared
            closestIndex = i
        end
    end
    return closestIndex
end

local function draw_zones(center, mapsize, map_aspect_ratio)
    for i = 2, #square_points - 1 do
        if square_offsets[i] and square_rotations[i] and square_sizes[i] and not square_deleted[i] then
            local target_point = square_points[i]
            local normalized_target = world_point_remap(target_point)
            local screen_target = center_to_map(normalized_target, center, mapsize, map_aspect_ratio)
            local final_position = screen_target + square_offsets[i]
            local size = square_sizes[i]
            local corners = {
                vec2(-size.width, -size.height),
                vec2(size.width, -size.height),
                vec2(size.width, size.height),
                vec2(-size.width, size.height)
            }
            local rotation = square_rotations[i]
            for j, corner in ipairs(corners) do
                corners[j] = rotatePointAround(corner, vec2(0, 0), rotation)
                corners[j] = corners[j] + final_position
            end
            
            local LocalGates = require('local_gates')
            local trackData = LocalGates.getTrackData()
            local gateType = "normal"
            if trackData and trackData.gates and trackData.gates[i] then
                gateType = trackData.gates[i].type or "normal"
            end
            
            ui.pathClear()
            ui.pathLineTo(corners[1])
            ui.pathLineTo(corners[2])
            ui.pathLineTo(corners[3])
            ui.pathLineTo(corners[4])
            ui.pathLineTo(corners[1])
            
            local outlineOffsets = { vec2(1,1), vec2(-1,1), vec2(1,-1), vec2(-1,-1) }
            
            for _, offset in ipairs(outlineOffsets) do
                ui.pathClear()
                ui.pathLineTo(corners[1] + offset)
                ui.pathLineTo(corners[2] + offset)
                ui.pathLineTo(corners[3] + offset)
                ui.pathLineTo(corners[4] + offset)
                ui.pathLineTo(corners[1] + offset)
                
                if gateType == "OZ" then
                    ui.pathFillConvex(rgbm(0, 0, 0, 0.6))
                else
                    ui.pathStroke(rgbm(0, 0, 0, 0.6), true, 4.0)
                end
            end
            
            ui.pathClear()
            ui.pathLineTo(corners[1])
            ui.pathLineTo(corners[2])
            ui.pathLineTo(corners[3])
            ui.pathLineTo(corners[4])
            ui.pathLineTo(corners[1])
            
            if gateType == "OZ" then
                if isSquareSelected and selectedSquareIndex == i and not isNoGoSquareSelected then
                    ui.pathFillConvex(rgbm(1, 0.5, 0, 1))
                else
                    ui.pathFillConvex(colors.WHITE)
                end
            else
                ui.pathStroke(isSquareSelected and selectedSquareIndex == i and not isNoGoSquareSelected and rgbm(1, 0.5, 0, 1) or colors.WHITE, true, 4.0)
            end
        end
    end

    for i = 1, #no_go_square_points do
        if no_go_square_offsets[i] and no_go_square_rotations[i] and no_go_square_sizes[i] and not no_go_square_deleted[i] then
            local target_point = no_go_square_points[i]
            local normalized_target = world_point_remap(target_point)
            local screen_target = center_to_map(normalized_target, center, mapsize, map_aspect_ratio)
            local final_position = screen_target + no_go_square_offsets[i]
            local size = no_go_square_sizes[i]
            local corners = {
                vec2(-size.width, -size.height),
                vec2(size.width, -size.height),
                vec2(size.width, size.height),
                vec2(-size.width, size.height)
            }
            local rotation = no_go_square_rotations[i]
            for j, corner in ipairs(corners) do
                corners[j] = rotatePointAround(corner, vec2(0, 0), rotation)
                corners[j] = corners[j] + final_position
            end
            
            ui.pathClear()
            ui.pathLineTo(corners[1])
            ui.pathLineTo(corners[2])
            ui.pathLineTo(corners[3])
            ui.pathLineTo(corners[4])
            ui.pathLineTo(corners[1])

            local outlineOffsets = { vec2(1,1), vec2(-1,1), vec2(1,-1), vec2(-1,-1) }
            for _, offset in ipairs(outlineOffsets) do
                ui.pathClear()
                ui.pathLineTo(corners[1] + offset)
                ui.pathLineTo(corners[2] + offset)
                ui.pathLineTo(corners[3] + offset)
                ui.pathLineTo(corners[4] + offset)
                ui.pathLineTo(corners[1] + offset)
                ui.pathFillConvex(rgbm(0, 0, 0, 0.6))
            end

            ui.pathClear()
            ui.pathLineTo(corners[1])
            ui.pathLineTo(corners[2])
            ui.pathLineTo(corners[3])
            ui.pathLineTo(corners[4])
            ui.pathLineTo(corners[1])
            
            if isNoGoSquareSelected and selectedNoGoSquareIndex == i then
                ui.pathFillConvex(rgbm(1, 0.5, 0, 1))
            else
                ui.pathFillConvex(rgbm(1, 0.3, 0.3, 1))
            end
        end
    end
end

local function draw_map_path(center, mapsize, map_aspect_ratio, line_width)
    local num_points = #map_points
    if num_points < 2 then return end

    local LocalGates = require('local_gates')
    local trackData = LocalGates.getTrackData()
    if not trackData or not trackData.gates then return end

    local num_segments = 100
    local mainColor = rgbm(0.5, 1, 0.5, 1)
    local outlineOffsets = { vec2(1,1), vec2(-1,1), vec2(1,-1), vec2(-1,-1) }

    for _, offset in ipairs(outlineOffsets) do
        ui.pathClear()
        for i = 1, num_points - 1 do
            local p0 = map_points[math.max(i - 1, 1)]
            local p1 = map_points[i]
            local p2 = map_points[i + 1]
            local p3 = map_points[math.min(i + 2, num_points)]
            for j = 0, num_segments - 1 do
                local t = j / num_segments
                local interpolated_point = cubicHermite(p0, p1, p2, p3, t, map_tension)
                local normalized = world_point_remap(interpolated_point)
                local screen_point = center_to_map(normalized, center, mapsize, map_aspect_ratio)
                ui.pathLineTo(screen_point + offset)
            end
        end
        ui.pathStroke(rgbm(0, 0, 0, 0.6), false, line_width + 14.0)
    end

    ui.pathClear()
    for i = 1, num_points - 1 do
        local p0 = map_points[math.max(i - 1, 1)]
        local p1 = map_points[i]
        local p2 = map_points[i + 1]
        local p3 = map_points[math.min(i + 2, num_points)]
        for j = 0, num_segments - 1 do
            local t = j / num_segments
            local interpolated_point = cubicHermite(p0, p1, p2, p3, t, map_tension)
            local normalized = world_point_remap(interpolated_point)
            local screen_point = center_to_map(normalized, center, mapsize, map_aspect_ratio)
            ui.pathLineTo(screen_point)
        end
    end
    ui.pathStroke(colors.WHITE, false, line_width + 10.0)

    ui.pathClear()
    for i = 1, num_points - 1 do
        local p0 = map_points[math.max(i - 1, 1)]
        local p1 = map_points[i]
        local p2 = map_points[i + 1]
        local p3 = map_points[math.min(i + 2, num_points)]
        for j = 0, num_segments - 1 do
            local t = j / num_segments
            local interpolated_point = cubicHermite(p0, p1, p2, p3, t, map_tension)
            local normalized = world_point_remap(interpolated_point)
            local screen_point = center_to_map(normalized, center, mapsize, map_aspect_ratio)
            ui.pathLineTo(screen_point)
        end
    end
    ui.pathStroke(mainColor, false, line_width)

    draw_zones(center, mapsize, map_aspect_ratio)
end

local function drawMapFn(map_view_size, map_bounds, line_width)
    if #map_points > 0 then
        local canvas_size = vec2(map_view_size.x - 20, map_view_size.y - 20)
        local map_full_width = max_pos.x - min_pos.x
        local map_full_height = max_pos.y - min_pos.y
        local map_aspect_ratio = map_full_width / map_full_height
        local mapsize = math.min(canvas_size.x, canvas_size.y) * 0.9
        local map_center_pos = vec2(canvas_size.x / 2, canvas_size.y / 2)

        draw_map_path(map_center_pos, mapsize, map_aspect_ratio, line_width)

        if #map_points > 1 then
            local function drawPerpendicularLine(point, nextPoint, color, lineLengthMeters, angleOffsetDegrees, map_center_pos, mapsize, map_aspect_ratio)
                local normalizedPoint = world_point_remap(point)
                local screenPoint = center_to_map(normalizedPoint, map_center_pos, mapsize, map_aspect_ratio)
                local normalizedNextPoint = world_point_remap(nextPoint)
                local screenNextPoint = center_to_map(normalizedNextPoint, map_center_pos, mapsize, map_aspect_ratio)
                local direction = (screenNextPoint - screenPoint):normalize()
                local angleRad = math.rad(angleOffsetDegrees)
                local cosAngle = math.cos(angleRad)
                local sinAngle = math.sin(angleRad)
                direction = vec2(
                    direction.x * cosAngle - direction.y * sinAngle,
                    direction.x * sinAngle + direction.y * cosAngle
                )
                local perpendicular = vec2(-direction.y, direction.x)
                local mapScale = (max_pos - min_pos):length()
                local lineLengthPixels = lineLengthMeters / mapScale * mapsize
                local lineStart = screenPoint + perpendicular * lineLengthPixels
                local lineEnd = screenPoint - perpendicular * lineLengthPixels
                local lineThickness = 8.0 * hud_scale

                if color == colors.GREEN then
                    ui.drawLine(lineStart, lineEnd, rgbm(0, 0, 0, 1), lineThickness)
                else
                    ui.drawLine(lineStart, lineEnd, rgbm(1, 0.5, 0.5, 1), lineThickness)
                end
            end

            local startPoint = map_points[1]
            local nextStartPoint = map_points[2]
            drawPerpendicularLine(startPoint, nextStartPoint, colors.GREEN, start_line_length, start_line_angle, map_center_pos, mapsize, map_aspect_ratio)

            local finishPoint = map_points[#map_points]
            local prevFinishPoint = map_points[#map_points - 1]
            drawPerpendicularLine(finishPoint, prevFinishPoint, colors.RED, finish_line_length, finish_line_angle, map_center_pos, mapsize, map_aspect_ratio)
        end

        ui.setCursorScreenPos(vec2(0, 0))
        ui.invisibleButton("map_click_area", map_view_size)

        if ui.mouseClicked(0) then
            local mousePos = ui.mousePos()
            local childPos = ui.windowPos()
            local relativeMousePos = mousePos - childPos
            if relativeMousePos.x >= 0 and relativeMousePos.x <= map_view_size.x and
               relativeMousePos.y >= 0 and relativeMousePos.y <= map_view_size.y then
               
                if isTextCreationMode and selectedText then
                    local worldPos = gateScreenToWorld(relativeMousePos, map_view_size)
                    local newText = {
                        text = (selectedText == "Start" or selectedText == "Finish") and selectedText or
                              (function()
                                  local nextNumber = 1
                                  if tempTexts then
                                      local maxNumber = 0
                                      for _, textObj in ipairs(tempTexts) do
                                          if textObj.text:match("^" .. selectedText) then
                                              local num = tonumber(textObj.text:match("-(%d+)$")) or 0
                                              if num > maxNumber then
                                                  maxNumber = num
                                              end
                                          end
                                      end
                                      nextNumber = maxNumber + 1
                                  end
                                  return selectedText .. "-" .. nextNumber
                              end)(),
                        position = worldPos
                    }

                    if not tempTexts then
                        tempTexts = {}
                    end

                    if (selectedText == "Start" or selectedText == "Finish") then
                        for i, textObj in ipairs(tempTexts) do
                            if textObj.text == selectedText then
                                table.remove(tempTexts, i)
                                break
                            end
                        end
                    end

                    table.insert(tempTexts, newText)
                    isTextCreationMode = false
                    selectedText = nil
                elseif isGateCreationMode then
                    -- Добавление ворот если нужно
                else
                    local clickedOnSquare = false
                    do
                        local mousePos = ui.mousePos()
                        local childPos = ui.windowPos()
                        local relativeMousePos = mousePos - childPos
                        for i = 2, #square_points - 1 do
                            if not square_deleted[i] then
                                local target_point = square_points[i]
                                local normalized_target = world_point_remap(target_point)
                                local mapsize = math.min((map_view_size.x - 20), (map_view_size.y - 20)) * 0.9
                                local map_full_width = max_pos.x - min_pos.x
                                local map_full_height = max_pos.y - min_pos.y
                                local map_aspect_ratio = map_full_width / map_full_height
                                local map_center_pos = vec2((map_view_size.x - 20) / 2, (map_view_size.y - 20) / 2)
                                local screen_target = center_to_map(normalized_target, map_center_pos, mapsize, map_aspect_ratio)
                                local final_position = screen_target + square_offsets[i]
                                local size = square_sizes[i] or { width = DEFAULT_WIDTH, height = DEFAULT_HEIGHT }
                                local rotation = square_rotations[i] or 0

                                local delta = relativeMousePos - final_position
                                local angleRad = math.rad(-rotation)
                                local cosRot = math.cos(angleRad)
                                local sinRot = math.sin(angleRad)
                                local localX = delta.x * cosRot - delta.y * sinRot
                                local localY = delta.x * sinRot + delta.y * cosRot

                                if math.abs(localX) <= size.width and math.abs(localY) <= size.height then
                                    isSquareSelected = true
                                    selectedSquareIndex = i
                                    isNoGoSquareSelected = false
                                    selectedNoGoSquareIndex = nil
                                    clickedOnSquare = true
                                    break
                                end
                            end
                        end
                    end

                    if not clickedOnSquare then
                        local mousePos = ui.mousePos()
                        local childPos = ui.windowPos()
                        local relativeMousePos = mousePos - childPos
                        local map_full_width = max_pos.x - min_pos.x
                        local map_full_height = max_pos.y - min_pos.y
                        local map_aspect_ratio = map_full_width / map_full_height
                        local mapsize = math.min((map_view_size.x - 20), (map_view_size.y - 20)) * 0.9
                        local map_center_pos = vec2((map_view_size.x - 20) / 2, (map_view_size.y - 20) / 2)
                        
                        for i = 1, #no_go_square_points do
                            if not no_go_square_deleted[i] then
                                local target_point = no_go_square_points[i]
                                local normalized_target = world_point_remap(target_point)
                                local screen_target = center_to_map(normalized_target, map_center_pos, mapsize, map_aspect_ratio)
                                local final_position = screen_target + no_go_square_offsets[i]
                                local size = no_go_square_sizes[i] or { width = DEFAULT_WIDTH, height = DEFAULT_HEIGHT }
                                local rotation = no_go_square_rotations[i] or 0

                                local delta = relativeMousePos - final_position
                                local angleRad = math.rad(-rotation)
                                local cosRot = math.cos(angleRad)
                                local sinRot = math.sin(angleRad)
                                local localX = delta.x * cosRot - delta.y * sinRot
                                local localY = delta.x * sinRot + delta.y * cosRot

                                if math.abs(localX) <= size.width and math.abs(localY) <= size.height then
                                    isNoGoSquareSelected = true
                                    selectedNoGoSquareIndex = i
                                    isSquareSelected = false
                                    selectedSquareIndex = nil
                                    clickedOnSquare = true
                                    break
                                end
                            end
                        end
                    end

                    if not clickedOnSquare then
                        isSquareSelected = false
                        selectedSquareIndex = nil
                        isNoGoSquareSelected = false
                        selectedNoGoSquareIndex = nil
                    end
                end
            end
        end

        if tempTexts then
            for _, textObj in ipairs(tempTexts) do
                local screenPos = gateWorldToScreen(textObj.position, map_view_size)
                drawMapText(textObj.text, screenPos, map_view_size)
            end
        end
    end
end

function DriftMap.setMapParameters(scale_x, scale_y, curvature, rotation_angle)
    map_scale_x = scale_x or 1.0
    map_scale_y = scale_y or 1.0
    map_curvature = curvature or 1.0
    map_rotation_angle = rotation_angle or 0.0
    DriftMap.initMap()
end

function DriftMap.showMapEditor()
    ac.setWindowOpen('map_editor', true)
end

function DriftMap.generateMap()
    local LocalGates = require('local_gates')
    local trackData = LocalGates.getTrackData()
    
    if not trackData or not trackData.gates then
        ac.debug("No track data available for map generation")
        return false
    end
    
    DriftMap.loadMapSettings()
    
    if trackData.mapGates then
        tempGates = deepcopy(trackData.mapGates)
    else
        tempGates = {}
    end
    
    if trackData.mapTexts then
        tempTexts = deepcopy(trackData.mapTexts)
    else
        tempTexts = {}
    end
    
    DriftMap.initMap()
    DriftMap.showMapEditor()
    return true
end

function DriftMap.initMap()
    local LocalGates = require('local_gates')
    local trackData = LocalGates.getTrackData()
    if not trackData or not trackData.gates then return end
    
    local original_points = {}
    for _, gate in ipairs(trackData.gates) do
        table.insert(original_points, vec2(gate.position.x, gate.position.z))
    end

    local no_go_original_points = {}
    if trackData.noGoZones then
        for _, zone in ipairs(trackData.noGoZones) do
            table.insert(no_go_original_points, vec2(zone.position.x, zone.position.z))
        end
    end

    local merged_points = {}
    local visited = {}
    for i, point in ipairs(original_points) do
        if not visited[i] then
            local cluster = { point }
            visited[i] = true
            for j = i + 1, #original_points do
                if not visited[j] then
                    if (original_points[j] - point):length() <= gate_merge_distance then
                        table.insert(cluster, original_points[j])
                        visited[j] = true
                    end
                end
            end
            local avg_point = vec2(0, 0)
            for _, p in ipairs(cluster) do
                avg_point = avg_point + p
            end
            avg_point = avg_point / #cluster
            table.insert(merged_points, avg_point)
        end
    end

    local min_orig = vec2(math.huge, math.huge)
    local max_orig = vec2(-math.huge, -math.huge)
    for _, point in ipairs(merged_points) do
        min_orig.x = math.min(min_orig.x, point.x)
        min_orig.y = math.min(min_orig.y, point.y)
        max_orig.x = math.max(max_orig.x, point.x)
        max_orig.y = math.max(max_orig.y, point.y)
    end

    original_min_pos = min_orig
    original_max_pos = max_orig

    local center = vec2((min_orig.x + max_orig.x) / 2, (min_orig.y + max_orig.y) / 2)

    map_points = {}
    min_pos = vec2(math.huge, math.huge)
    max_pos = vec2(-math.huge, -math.huge)
    rotation_radians = math.rad(map_rotation_angle)
    local cos_rot = math.cos(rotation_radians)
    local sin_rot = math.sin(rotation_radians)

    local function transformPoint(point, index, total)
        local centered = point - center
        centered.x = centered.x * map_scale_x
        centered.y = centered.y * map_scale_y
        if map_curvature ~= 1.0 and total > 1 then
            local t = (index - 1) / (total - 1)
            local center_offset = (t - 0.5) * 2
            local curvature_factor = 1 + (center_offset^2) * (map_curvature - 1)
            centered.x = centered.x * curvature_factor
            centered.y = centered.y * curvature_factor
        end
        local rotated = vec2(
            centered.x * cos_rot - centered.y * sin_rot,
            centered.x * sin_rot + centered.y * cos_rot
        )
        return rotated
    end

    for i, point in ipairs(merged_points) do
        local rotated = transformPoint(point, i, #merged_points)
        table.insert(map_points, rotated)
        min_pos.x = math.min(min_pos.x, rotated.x)
        min_pos.y = math.min(min_pos.y, rotated.y)
        max_pos.x = math.max(max_pos.x, rotated.x)
        max_pos.y = math.max(max_pos.y, rotated.y)
    end

    DriftMap.maxRadius = calculateMaxRadius(map_points, vec2(0,0))

    square_points = {}
    for i, point in ipairs(original_points) do
        local rotated = transformPoint(point, i, #original_points)
        table.insert(square_points, rotated)
    end

    no_go_square_points = {}
    for i, point in ipairs(no_go_original_points) do
        local rotated = transformPoint(point, i, #no_go_original_points)
        table.insert(no_go_square_points, rotated)
    end

    local gatesCount = #square_points  -- ИЗМЕНЕНИЯ: количество ворот

    local trackData = LocalGates.getTrackData()
    if trackData and trackData.squareSettings then
        -- ИЗМЕНЕНИЯ: Применяем настройки и к no go зонам
        for _, square in ipairs(trackData.squareSettings) do
            local idx = square.index
            if idx <= gatesCount then
                square_offsets[idx] = square.offset
                square_rotations[idx] = square.rotation
                square_sizes[idx] = square.size
                square_deleted[idx] = square.deleted or false
            else
                local noGoIndex = idx - gatesCount
                no_go_square_offsets[noGoIndex] = square.offset
                no_go_square_rotations[noGoIndex] = square.rotation
                no_go_square_sizes[noGoIndex] = square.size
                no_go_square_deleted[noGoIndex] = square.deleted or false
            end
        end
    end

    for i = 1, #square_points do
        if not square_offsets[i] then
            square_offsets[i] = vec2(0, 0)
            if trackData.gates[i] then
                square_rotations[i] = (trackData.gates[i].rotation + 90) or 90
                local gateType = trackData.gates[i].type
                local defaultSize = DEFAULT_SIZES[gateType] or DEFAULT_SIZES.normal
                square_sizes[i] = {
                    width = defaultSize.width,
                    height = defaultSize.height
                }
            else
                square_rotations[i] = 90
                square_sizes[i] = {width = DEFAULT_WIDTH, height = DEFAULT_HEIGHT}
            end
        end
    end

    if trackData and trackData.noGoZones then
        for i = 1, #no_go_square_points do
            if not no_go_square_offsets[i] then
                no_go_square_offsets[i] = vec2(0, 0)
                no_go_square_rotations[i] = (trackData.noGoZones[i].rotation + 90) or 90
                no_go_square_sizes[i] = DEFAULT_SIZES.nogo
                no_go_square_deleted[i] = false
            end
        end
    end
end

function DriftMap.saveMapSettings()
    local LocalGates = require('local_gates')
    local trackData = LocalGates.getTrackData()
    local currentConfig = LocalGates.getCurrentConfig()
    
    if not trackData or not currentConfig then 
        ui.toast(ui.Icons.Warning, "No active configuration to save to")
        return false 
    end

    trackData.mapSettings = {
        scale = { x = map_scale_x, y = map_scale_y },
        curvature = map_curvature,
        rotation = map_rotation_angle,
        tension = map_tension,
        mergeDistance = gate_merge_distance,
        lineWidth = DriftMap.line_width,
        startLine = {
            length = start_line_length,
            angle = start_line_angle
        },
        finishLine = {
            length = finish_line_length,
            angle = finish_line_angle
        }
    }

    trackData.mapTexts = deepcopy(tempTexts)

    trackData.squareSettings = {}
    local gatesCount = #square_points
    -- ИЗМЕНЕНИЯ: Сохраняем ворота
    for i = 1, gatesCount do
        if square_offsets[i] then
            table.insert(trackData.squareSettings, {
                index = i,
                offset = square_offsets[i],
                rotation = square_rotations[i],
                size = square_sizes[i],
                deleted = square_deleted[i] or false
            })
        end
    end
    -- ИЗМЕНЕНИЯ: Сохраняем no go зоны, индексируя их после ворот
    for i = 1, #no_go_square_points do
        if no_go_square_offsets[i] then
            table.insert(trackData.squareSettings, {
                index = gatesCount + i,
                offset = no_go_square_offsets[i],
                rotation = no_go_square_rotations[i],
                size = no_go_square_sizes[i],
                deleted = no_go_square_deleted[i] or false
            })
        end
    end

    LocalGates.setTrackData(trackData)

    local success = LocalGates.saveToFile(currentConfig)
    if success then
        local tracksDir = ac.getFolder(ac.FolderID.Root) .. '/apps/lua/DriftZonesEditor/tracks/'
        local currentTrack = ac.getTrackID()
        local pngFileName = currentTrack .. '_' .. currentConfig .. '.png'
        local pngPath = tracksDir .. pngFileName
        
        ac.debug("Saving PNG to: " .. pngPath)
        
        local canvas = ui.ExtraCanvas(vec2(800, 700), math.huge)
        canvas:update(function (dt)
            drawMapFn(vec2(800, 700), {}, DriftMap.line_width or 60.0)
        end)
        
        local pngSuccess = canvas:save(pngPath)
        
        if pngSuccess then
            ui.toast(ui.Icons.Confirm, "Map settings and image saved successfully")
            ac.debug("PNG saved successfully to: " .. pngPath)
        else
            ui.toast(ui.Icons.Warning, "Failed to save PNG image")
            ac.debug("Failed to save PNG to: " .. pngPath)
        end
    else
        ui.toast(ui.Icons.Warning, "Failed to save map settings")
    end

    return success
end

function DriftMap.loadMapSettings()
    local LocalGates = require('local_gates')
    local trackData = LocalGates.getTrackData()
    if not trackData or not trackData.mapSettings then return false end

    local settings = trackData.mapSettings
    map_scale_x = settings.scale.x or 1.0
    map_scale_y = settings.scale.y or 1.0
    map_curvature = settings.curvature or 1.0
    map_rotation_angle = settings.rotation or 0.0
    map_tension = settings.tension or -0.5
    gate_merge_distance = settings.mergeDistance or 5.0
    DriftMap.line_width = settings.lineWidth or 60.0
    
    start_line_length = settings.startLine.length or 20.0
    start_line_angle = settings.startLine.angle or 0.0
    finish_line_length = settings.finishLine.length or 20.0
    finish_line_angle = settings.finishLine.angle or 0.0

    if trackData.mapTexts then
        tempTexts = deepcopy(trackData.mapTexts)
    else
        tempTexts = {}
    end

    return true
end

function windowMapEditor()
    local window_size = ui.windowSize()
    local settings_width = 200
    local gate_controls_width = 200
    local map_view_size = vec2(800, 700)
    local total_width = settings_width + map_view_size.x + gate_controls_width + 40
    local total_height = map_view_size.y + 20
    
    ui.setNextWindowSize(vec2(total_width, total_height))
    ui.pushFont(ui.Font.Small)
    
    ui.beginChild("settings", vec2(settings_width, total_height), true)
    ui.text("Map Settings:")
    ui.separator()
    
    ui.text("Scale:")
    local new_scale_x = ui.slider("X##scale", map_scale_x, 0.1, 5.0, "%.2f")
    local new_scale_y = ui.slider("Y##scale", map_scale_y, 0.1, 5.0, "%.2f")
    local changed = false
    if new_scale_x ~= map_scale_x or new_scale_y ~= map_scale_y then
        map_scale_x = new_scale_x
        map_scale_y = new_scale_y
        changed = true
    end
    
    ui.text("Curvature:")
    local new_curvature = ui.slider("##curvature", map_curvature, 0.5, 2.0, "%.2f")
    if new_curvature ~= map_curvature then
        map_curvature = new_curvature
        changed = true
    end
    
    ui.text("Merge Distance:")
    local new_merge_distance = ui.slider("##merge_distance", gate_merge_distance, 0.0, 20.0, "%.1f")
    if new_merge_distance ~= gate_merge_distance then
        gate_merge_distance = new_merge_distance
        DriftMap.initMap()
    end
    
    ui.text("Rotation:")
    local new_rotation = ui.slider("##rotation", map_rotation_angle, -180, 180, "%.1f°")
    if new_rotation ~= map_rotation_angle then
        map_rotation_angle = new_rotation
        changed = true
    end

    ui.text("Tension:")
    local new_tension = ui.slider("##tension", map_tension, -1.0, 1.0, "%.2f")
    if new_tension ~= map_tension then
        map_tension = new_tension
        changed = true
    end

    ui.text("Line Width:")
    local line_width = DriftMap.line_width or 60.0
    local new_line_width = ui.slider("##line_width", line_width, 1.0, 200.0, "%.1f")
    if new_line_width ~= line_width then
        DriftMap.line_width = new_line_width
        line_width = new_line_width
    end
    

    if changed then
        DriftMap.setMapParameters(map_scale_x, map_scale_y, map_curvature, map_rotation_angle)
    end

    ui.separator()
    ui.text("Start Line Settings:")
    start_line_length = ui.slider("Length##start_line_length", start_line_length, 5.0, 100.0, "%.1f")
    start_line_angle = ui.slider("Angle##start_line_angle", start_line_angle, -180.0, 180.0, "%.1f°")

    ui.separator()
    ui.text("Finish Line Settings:")
    finish_line_length = ui.slider("Length##finish_line_length", finish_line_length, 5.0, 100.0, "%.1f")
    finish_line_angle = ui.slider("Angle##finish_line_angle", finish_line_angle, -180.0, 180.0, "%.1f°")

    ui.dummy(vec2(0, 225))  -- Добавляем отступ перед кнопками
    ui.separator()

    -- Перемещаем кнопки в левую панель
    if ui.button("Save Map", vec2(130, 20)) then
        if DriftMap.saveMapSettings() then
            ui.toast(ui.Icons.Confirm, "Map settings saved successfully")
        else
            ui.toast(ui.Icons.Warning, "Failed to save map settings")
        end
    end
    ui.dummy(vec2(0, 0))  -- Небольшой отступ между кнопками
    if ui.button("Close", vec2(130, 20)) then
        ac.setWindowOpen('map_editor', false)
    end
    
    ui.endChild()
    
    ui.sameLine()
    ui.beginChild("map_view", map_view_size, true)
    drawMapFn(map_view_size, {}, line_width)
    ui.endChild()
    
    ui.sameLine()
    ui.beginChild("gate_controls", vec2(gate_controls_width, total_height), true)
    ui.text("Add Map Markers:")
    ui.separator()

    local textsByType = {}
    if tempTexts then
        for i, textObj in ipairs(tempTexts) do
            local baseType = textObj.text:match("^([^-]+)")
            if baseType then
                if not textsByType[baseType] then
                    textsByType[baseType] = {}
                end
                table.insert(textsByType[baseType], {index = i, text = textObj})
            end
        end
    end

    for _, textType in ipairs(textOptions) do
        if ui.button(isTextCreationMode and selectedText == textType and "Cancel " .. textType or "Add " .. textType) then
            if isTextCreationMode and selectedText == textType then
                isTextCreationMode = false
                selectedText = nil
            else
                isTextCreationMode = true
                selectedText = textType
                isGateCreationMode = false
            end
        end
        
        if textsByType[textType] then
            local buttonsPerRow = 5  -- Максимальное количество кнопок в строке
            for i, textInfo in ipairs(textsByType[textType]) do
                if i <= buttonsPerRow then
                    ui.sameLine(0, 1)
                else
                    -- Начинаем новую строку после каждых 5 кнопок
                    if (i - 1) % buttonsPerRow == 0 then
                        ui.dummy(vec2(0, 0))  -- Создаем новую строку
                    else
                        ui.sameLine(0, 1)
                    end
                end
                
                if ui.button("X##" .. textType .. textInfo.index, vec2(20, 20)) then
                    table.remove(tempTexts, textInfo.index)
                    updateTextNumbering(textType)
                    ui.toast(ui.Icons.Confirm, textType .. " text deleted")
                end
                if ui.itemHovered() then
                    ui.setTooltip(textInfo.text.text)
                end
            end
        end
    end

    ui.dummy(vec2(0, 5))
    if ui.button("Reset Deleted Zones", vec2(180, 20)) then
        -- Сброс всех обычных зон
        for i = 1, #square_points do
            square_deleted[i] = false
        end
        -- Сброс всех no-go зон
        for i = 1, #no_go_square_points do
            no_go_square_deleted[i] = false
        end
        ui.toast(ui.Icons.Confirm, "All zones restored")
    end

    ui.dummy(vec2(0, 0))
    if ui.button("Reset All Offsets", vec2(180, 20)) then
        -- Сброс оффсетов для обычных зон
        for i = 1, #square_points do
            square_offsets[i] = vec2(0, 0)
            local LocalGates = require('local_gates')
            local trackData = LocalGates.getTrackData()
            if trackData and trackData.gates[i] then
                local gateType = trackData.gates[i].type or "normal"
                square_rotations[i] = (trackData.gates[i].rotation + 90) or 90
                local defaultSize = DEFAULT_SIZES[gateType] or DEFAULT_SIZES.normal
                square_sizes[i] = {
                    width = defaultSize.width,
                    height = defaultSize.height
                }
            else
                square_rotations[i] = 90
                square_sizes[i] = {width = DEFAULT_WIDTH, height = DEFAULT_HEIGHT}
            end
        end
        -- Сброс оффсетов для no-go зон
        for i = 1, #no_go_square_points do
            no_go_square_offsets[i] = vec2(0, 0)
            no_go_square_rotations[i] = 90
            no_go_square_sizes[i] = DEFAULT_SIZES.nogo
        end
        ui.toast(ui.Icons.Confirm, "All offsets and sizes reset to default")
    end
    ui.dummy(vec2(0, 5))
    ui.separator()

    if isSquareSelected and selectedSquareIndex then
        ui.separator()
        ui.text(string.format("Gate Zone %d Control:", selectedSquareIndex))
        ui.text("Offset X:")
        ui.setNextItemWidth(180)
        local new_offset_x = ui.slider(
            string.format("##square_offset_x_%d", selectedSquareIndex), 
            square_offsets[selectedSquareIndex].x, 
            -100, 
            100, 
            "%.0f"
        )
        if new_offset_x ~= square_offsets[selectedSquareIndex].x then
            square_offsets[selectedSquareIndex].x = new_offset_x
        end
        
        ui.text("Offset Y:")
        ui.setNextItemWidth(180)
        local new_offset_y = ui.slider(
            string.format("##square_offset_y_%d", selectedSquareIndex), 
            square_offsets[selectedSquareIndex].y, 
            -100, 
            100, 
            "%.0f"
        )
        if new_offset_y ~= square_offsets[selectedSquareIndex].y then
            square_offsets[selectedSquareIndex].y = new_offset_y
        end

        local current_size = square_sizes[selectedSquareIndex] or { width = DEFAULT_WIDTH, height = DEFAULT_HEIGHT }

        ui.text("Width:")
        ui.setNextItemWidth(180)
        local new_width = ui.slider(
            string.format("##rect_width_%d", selectedSquareIndex),
            current_size.width,
            10,
            100,
            "%.0f"
        )
        if new_width ~= current_size.width then
            square_sizes[selectedSquareIndex].width = new_width
        end

        ui.text("Height:")
        ui.setNextItemWidth(180)
        
        local LocalGates = require('local_gates')
        local trackData = LocalGates.getTrackData()
        local gateType = "normal"
        if trackData and trackData.gates[selectedSquareIndex] then
            gateType = trackData.gates[selectedSquareIndex].type or "normal"
        end
        
        local minHeight = gateType == "OZ" and 1 or 5
        local maxHeight = gateType == "OZ" and 20 or 50

        local new_height = ui.slider(
            string.format("##rect_height_%d", selectedSquareIndex),
            current_size.height,
            minHeight,
            maxHeight,
            "%.0f"
        )
        if new_height ~= current_size.height then
            square_sizes[selectedSquareIndex].height = new_height
        end

        ui.text("Rotation:")
        ui.setNextItemWidth(180)
        local new_rotation = ui.slider(
            string.format("##square_rotation_%d", selectedSquareIndex),
            square_rotations[selectedSquareIndex],
            -180,
            180,
            "%.1f°"
        )
        if new_rotation ~= square_rotations[selectedSquareIndex] then
            square_rotations[selectedSquareIndex] = new_rotation
        end

        ui.dummy(vec2(0, 10))
        if ui.button("Delete Zone") then
            square_deleted[selectedSquareIndex] = true
            isSquareSelected = false
            selectedSquareIndex = nil
            ui.toast(ui.Icons.Confirm, "Zone deleted")
        end
    end

    if isNoGoSquareSelected and selectedNoGoSquareIndex then
        ui.separator()
        ui.text(string.format("NoGo Zone %d Control:", selectedNoGoSquareIndex))
        ui.text("Offset X:")
        ui.setNextItemWidth(180)
        local new_offset_x = ui.slider(
            string.format("##no_go_offset_x_%d", selectedNoGoSquareIndex), 
            no_go_square_offsets[selectedNoGoSquareIndex].x, 
            -100, 
            100, 
            "%.0f"
        )
        if new_offset_x ~= no_go_square_offsets[selectedNoGoSquareIndex].x then
            no_go_square_offsets[selectedNoGoSquareIndex].x = new_offset_x
        end
        
        ui.text("Offset Y:")
        ui.setNextItemWidth(180)
        local new_offset_y = ui.slider(
            string.format("##no_go_offset_y_%d", selectedNoGoSquareIndex), 
            no_go_square_offsets[selectedNoGoSquareIndex].y, 
            -100, 
            100, 
            "%.0f"
        )
        if new_offset_y ~= no_go_square_offsets[selectedNoGoSquareIndex].y then
            no_go_square_offsets[selectedNoGoSquareIndex].y = new_offset_y
        end

        local current_size = no_go_square_sizes[selectedNoGoSquareIndex] or { width = DEFAULT_WIDTH, height = DEFAULT_HEIGHT }

        ui.text("Width:")
        ui.setNextItemWidth(180)
        local new_width = ui.slider(
            string.format("##no_go_width_%d", selectedNoGoSquareIndex),
            current_size.width,
            10,
            100,
            "%.0f"
        )
        if new_width ~= current_size.width then
            no_go_square_sizes[selectedNoGoSquareIndex].width = new_width
        end

        ui.text("Height:")
        ui.setNextItemWidth(180)
        
        local new_height = ui.slider(
            string.format("##no_go_height_%d", selectedNoGoSquareIndex),
            current_size.height,
            5,
            100,
            "%.0f"
        )
        if new_height ~= current_size.height then
            no_go_square_sizes[selectedNoGoSquareIndex].height = new_height
        end

        ui.text("Rotation:")
        ui.setNextItemWidth(180)
        local new_rotation = ui.slider(
            string.format("##no_go_rotation_%d", selectedNoGoSquareIndex),
            no_go_square_rotations[selectedNoGoSquareIndex],
            -180,
            180,
            "%.1f°"
        )
        if new_rotation ~= no_go_square_rotations[selectedNoGoSquareIndex] then
            no_go_square_rotations[selectedNoGoSquareIndex] = new_rotation
        end

        ui.dummy(vec2(0, 10))
        if ui.button("Delete NoGo Zone") then
            no_go_square_deleted[selectedNoGoSquareIndex] = true
            isNoGoSquareSelected = false
            selectedNoGoSquareIndex = nil
            ui.toast(ui.Icons.Confirm, "NoGo Zone deleted")
        end
    end

    ui.endChild()
    ui.popFont()
end

return DriftMap
