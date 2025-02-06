local colors = {
    TRANSP      = rgbm(0, 0, 0, 0),
    WHITE       = rgbm(1, 1, 1, 1),
    BLACK       = rgbm(0, 0, 0, 1),
    RED         = rgbm(255 / 255, 31 / 255, 31 / 255, 1),
    GREEN       = rgbm(9 / 255, 207 / 255, 46 / 255, 1),
    LIGHT_GREEN = rgbm(0 / 255, 255 / 255, 133 / 255, 1),
    YELLOW      = rgbm(255 / 255, 228 / 255, 0 / 255, 1),
    BLUE        = rgbm(33 / 255, 77 / 255, 203 / 255, 1),
    LIGHT_BG    = rgbm(0, 0, 0, 0.45),
    BG          = rgbm(0, 0, 0, 0.65),
    DARK_BG     = rgbm(0, 0, 0, 0.75),
    DARKEST_BG  = rgbm(0, 0, 0, 0.9),
    LIGHT_GRAY  = rgbm(142 / 255, 142 / 255, 142 / 255, 0.65),
    GRAY        = rgbm(98 / 255, 98 / 255, 98 / 255, 0.45),
    DARK_GRAY   = rgbm(27 / 255, 27 / 255, 27 / 255, 1),
    TEXT_LIGHT_GRAY= rgbm(1, 1, 1, 0.4),
    TEXT_GRAY   = rgbm(209 / 255, 209 / 255, 209 /255, 1),
    TEXT_YELLOW = rgbm(255 / 255, 204 / 255, 49 / 255, 1),
    WARNING_RED = rgbm(237 / 255, 58 / 255, 39 / 255, 1),
    SETTINGS_TEXT = rgbm(180 / 255, 180 / 255, 180 /255, 1),
    PURPLE      = rgbm(253 / 255, 56 / 255, 255 / 255, 1),
    INDICATOR_YLLW = rgbm(254 / 255, 204 / 255, 55 / 255, 1),
    INDICATOR_BLUE = rgbm(13 / 255, 157 / 255, 253 / 255, 1),
}

local fonts = {
    archivo_bold    = ui.DWriteFont("Archivo SemiExpanded:/fonts;Weight=Bold"),
    archivo_medium  = ui.DWriteFont("Archivo SemiExpanded:/fonts;Weight=Medium"),
    archivo_black   = ui.DWriteFont("Archivo SemiExpanded:/fonts;Weight=Black"),
    opti_edgar = ui.DWriteFont("OPTIEdgarBold:/fonts"),
}

local settings = {
    colors = colors,
    fonts = fonts,
    line_height = 30
}

local winstuff = table.new(9, 0)
local appnames = {
    APPNAMES.deltabar,
    APPNAMES.gearbox,
    APPNAMES.leaderboard,
    APPNAMES.map,
    APPNAMES.local_time,
    APPNAMES.real_time,
    APPNAMES.pedals,
    APPNAMES.radar,
    APPNAMES.sectors,
    APPNAMES.tyres,
}

local appsize_storage = ac.storage{
    local_time_old_size  = vec2(),
    real_time_old_size   = vec2(),
    deltabar_old_size    = vec2(),
    gearbox_old_size     = vec2(),
    leaderboard_old_size = vec2(),
    map_old_size         = vec2(),
    pedals_old_size      = vec2(),
    radar_old_size       = vec2(),
    sectors_old_size     = vec2(),
    tyres_old_size       = vec2(),
}

function settings.init()
    local all = ac.getAppWindows()
    local app_name = nil
    local win = nil
    -- NOTE(cogno): I have no idea why this is the only list in the api that starts from 1 instead of 0
    for i=1, #all do
        local app = all[i]
        for j=1, #appnames do
            if app ~= nil and app.title == appnames[j] then
                app_name = app.name
                if app_name ~= nil then
                    win = ac.accessAppWindow(app_name)
                    winstuff[appnames[j]] = {
                        win=win, app_name=app_name
                    }
                end
            end
        end
    end
end

-- NOTE(cogno): it seems like the api counts wrongly the size of the font:
-- if we say "font is 48px" it will make a 36px font
-- interestingly, a 36pt font is a 48px font
-- so it seems like they have a wrong conversion
-- in other words, if you want a 36 px font you will have to give 36 * 4/3
--
---@param px number
function settings.fontsize(px)
    return px * 4 / 3
end

function settings.is_inside(to_check, area_center, area_half_size)
    if to_check.x < area_center.x - area_half_size.x then return false end
    if to_check.x > area_center.x + area_half_size.x then return false end
    if to_check.y < area_center.y - area_half_size.y then return false end
    if to_check.y > area_center.y + area_half_size.y then return false end
    return true
end

---@param c1 rgbm
---@param c2 rgbm
---@param t number
function settings.color_lerp(c1, c2, t)
    return rgbm(
        math.lerp(c1.r, c2.r, t),
        math.lerp(c1.g, c2.g, t),
        math.lerp(c1.b, c2.b, t),
        math.lerp(c1.mult, c2.mult, t)
    )
end

function settings.color_rgb_to_hsv(r, g, b)
    -- formula from https://math.stackexchange.com/questions/556341/rgb-to-hsv-color-conversion-algorithm
    local cmax = math.max(r, g, b)
    local cmin = math.min(r, g, b)
    local delta = cmax - cmin
    local sat = 0
    local value = cmax
    if delta == 0 then return 0, 0, value end
    if cmax ~= 0 then sat = delta / cmax end
    local hue = 0
    if cmax == r then hue = 60 * (((g - b) / delta) % 6) end
    if cmax == g then hue = 60 * ((2 + (b - r) / delta) % 6) end
    if cmax == b then hue = 60 * ((4 + (r - g) / delta) % 6) end
    return hue, sat, value
end

function settings.color_hsv_to_rgb(h, s, v)
    -- formula from https://scratch.mit.edu/discuss/topic/694772/
    local c = v * s
    local m = v - c
    local x = c * (1 - math.abs(((h / 60) % 2) - 1))
    local r = 0
    local g = 0
    local b = 0
    if h < 60 then      r, g, b = c, x, 0
    elseif h < 120 then r, g, b = x, c, 0
    elseif h < 180 then r, g, b = 0, c, x
    elseif h < 240 then r, g, b = 0, x, c
    elseif h < 300 then r, g, b = x, 0, c
    elseif h < 360 then r, g, b = c, 0, x
    end
    r = (r + m) * 255
    g = (g + m) * 255
    b = (b + m) * 255
    return r, g, b
end

---@param c1 rgbm
---@param c2 rgbm
---@param t number
function settings.color_lerp_hsv(c1, c2, t)
    local h1, s1, v1 = settings.color_rgb_to_hsv(c1.r, c1.g, c1.b)
    local h2, s2, v2 = settings.color_rgb_to_hsv(c2.r, c2.g, c2.b)
    local h_out = math.lerp(h1, h2, t)
    local s_out = math.lerp(s1, s2, t)
    local v_out = math.lerp(v1, v2, t)
    h_out = (h_out + 360) % 360
    local r, g, b = settings.color_hsv_to_rgb(h_out, s_out, v_out)
    return rgbm(
        r / 255, g / 255, b / 255,
        math.lerp(c1.mult, c2.mult, t)
    )
end


function settings.remap(value, old_min, old_max, new_min, new_max)
    return new_min + (value - old_min) * (new_max - new_min) / (old_max - old_min)
end

function settings.get_asset(name)
    return string.format("apps/lua/CMRT-Essential-HUD/assets/%s.png", name)
end

function settings.ease_out_back(x)
    local c1 = 9.70158 -- upper curve control (controls how much the curve exceeds 1)
    local c3 = c1 + 1
    return 1 + c3 * math.pow(x - 1, 3) + c1 * math.pow(x - 1, 2)
end

function settings.get_curve_t(anim_start_time, do_end_animation, total_duration)
    if anim_start_time == nil then return 0 end
    local start_anim_duration = 0.3
    local end_anim_duration = 0.5
    local animation_elapsed = Time - anim_start_time
    local start_animation_percentage = math.clamp(settings.remap(animation_elapsed, 0, start_anim_duration, 0, 1), 0, 1)
    local curve_t = settings.ease_out_back(start_animation_percentage)
    if do_end_animation == false then return curve_t end
    local end_animation_percentage = math.clamp(settings.remap(animation_elapsed, total_duration - end_anim_duration, total_duration, 0, 1), 0, 1)
    local out = curve_t - end_animation_percentage
    return out
end

function settings.get_window_and_name(name)
    local data = winstuff[name]
    if data == nil then return nil, nil end
    return data.win, data.app_name
end

function settings.auto_scale_window(size, name)
    if not Apps_AutoScale then return end -- user wants to resize manually, let him do it!
    local win, app_name = settings.get_window_and_name(name)
    if win == nil then return end -- nothing we can do, api doesn't work!
    local ui_info = ac.getUI()
    local real_size = (size + vec2(0, 22)) * ui_info.uiScale -- top bar takes 22px of height
    win:resize(real_size)

    local old_size = vec2()
    if name == APPNAMES.deltabar    then old_size = appsize_storage.deltabar_old_size    end
    if name == APPNAMES.gearbox     then old_size = appsize_storage.gearbox_old_size     end
    if name == APPNAMES.leaderboard then old_size = appsize_storage.leaderboard_old_size end
    if name == APPNAMES.map         then old_size = appsize_storage.map_old_size         end
    if name == APPNAMES.local_time  then old_size = appsize_storage.local_time_old_size  end
    if name == APPNAMES.real_time   then old_size = appsize_storage.real_time_old_size   end
    if name == APPNAMES.pedals      then old_size = appsize_storage.pedals_old_size      end
    if name == APPNAMES.radar       then old_size = appsize_storage.radar_old_size       end
    if name == APPNAMES.sectors     then old_size = appsize_storage.sectors_old_size     end
    if name == APPNAMES.tyres       then old_size = appsize_storage.tyres_old_size       end

    local diff_to_move = (real_size - old_size) * ui_info.uiScale
    diff_to_move.x = math.round(diff_to_move.x)
    diff_to_move.y = math.round(diff_to_move.y)
    if name == APPNAMES.deltabar then diff_to_move.x = 0 end -- the deltabar scales in its own way, we don't want to interact with that on the x axis only
    if old_size.x ~= 0 and old_size.y ~= 0 and (diff_to_move.x ~= 0 or diff_to_move.y ~= 0) then
        local app_center = (ui.windowPos() + ui.windowSize() / 2) * ui_info.uiScale
        local sim_info = ac.getSim()
        local screensize = vec2(sim_info.windowWidth, sim_info.windowHeight)
        local step = screensize / 3
        local win_idx = vec2(math.floor(app_center.x / step.x), math.floor(app_center.y / step.y))
        -- win_idx goes from (0, 0) (top left screen quadrant) to (2, 2) (bottom right screen quadrant)
        -- we move the app depending on each one
        
        -- if we are in x=0 we extend to the right automatically, nothing to do
        -- if we are in y=0 we extend to the bottom automatically, nothing to do
        -- if we are in x=1 we keep it centered, move halfway to the left
        -- if we are in y=1 we keep it centered, move halfway up
        -- if we are in x=2 we extend it left
        -- if we are in x=y we extend it up
        local new_pos = ui.windowPos() * ui_info.uiScale
        if win_idx.x == 1 then new_pos.x = new_pos.x - diff_to_move.x / 2 end
        if win_idx.y == 1 then new_pos.y = new_pos.y - diff_to_move.y / 2 end
        if win_idx.x == 2 then new_pos.x = new_pos.x - diff_to_move.x end
        if win_idx.y == 2 then new_pos.y = new_pos.y - diff_to_move.y end
        win:move(new_pos)
    end
    
    if name == APPNAMES.deltabar    then appsize_storage.deltabar_old_size    = real_size end
    if name == APPNAMES.gearbox     then appsize_storage.gearbox_old_size     = real_size end
    if name == APPNAMES.leaderboard then appsize_storage.leaderboard_old_size = real_size end
    if name == APPNAMES.map         then appsize_storage.map_old_size         = real_size end
    if name == APPNAMES.local_time  then appsize_storage.local_time_old_size  = real_size end
    if name == APPNAMES.real_time   then appsize_storage.real_time_old_size   = real_size end
    if name == APPNAMES.pedals      then appsize_storage.pedals_old_size      = real_size end
    if name == APPNAMES.radar       then appsize_storage.radar_old_size       = real_size end
    if name == APPNAMES.sectors     then appsize_storage.sectors_old_size     = real_size end
    if name == APPNAMES.tyres       then appsize_storage.tyres_old_size       = real_size end
end

function settings.auto_place_once(size, name)
    local can_move = CanMoveApps[name]
    if can_move == nil or can_move == false then return end -- if we don't want to move then there's nothing we should do anyway
    local win, app_name = settings.get_window_and_name(name)
    if win == nil then return end -- nothing we can do, api doesn't work!

    -- TODO(cogno): check if we can do this or not, then save that we did that so we don't do it again
    local sim_info = ac.getSim()
    local ui_info = ac.getUI()
    local real_size = size * ui_info.uiScale
    local screensize = vec2(sim_info.windowWidth, sim_info.windowHeight)
    local padding = 50
    local top_bar_size = 63
    local rear_mirror_width = 442
    local rear_mirror_height = 61
    local app_positions = {
        [APPNAMES.gearbox]     = vec2(screensize.x - real_size.x - padding, screensize.y - real_size.y - padding),
        [APPNAMES.leaderboard] = vec2(padding, top_bar_size),
        [APPNAMES.sectors]     = vec2(screensize.x - real_size.x - padding, top_bar_size),
        [APPNAMES.pedals]      = vec2(screensize.x / 2 - real_size.x / 2 + 1, screensize.y - real_size.y - padding),
        [APPNAMES.map]         = vec2(padding, screensize.y * 0.64 - real_size.y - padding),
        [APPNAMES.real_time]   = vec2(screensize.x / 2 - real_size.x/2 + rear_mirror_width / 2, top_bar_size),
        [APPNAMES.local_time]  = vec2(screensize.x / 2 - real_size.x/2, top_bar_size - real_size.y),
        [APPNAMES.tyres]       = vec2(padding, screensize.y - real_size.y - padding),
        [APPNAMES.radar]       = screensize / 2 - real_size / 2 - vec2(0, padding * 4),
        [APPNAMES.deltabar]    = vec2(screensize.x / 2 - real_size.x / 2, top_bar_size + rear_mirror_height),
    }

    local target_pos = app_positions[name]
    if target_pos == nil then return end -- no info on where to place, nothing we can do

    win:move(target_pos)
    CanMoveApps[name] = false -- we've moved it, we don't have to do it again
end

local lock_states = table.new(0, 11)
function settings.lock_app(center, size, name, app_scale)
    local win, app_name = settings.get_window_and_name(name)
    if win == nil or app_name == nil then return end -- nothing we can do, api doesn't work!
    
    local lock_storage = ac.storage("lock app " .. app_name, false)
    if settings.is_inside(ui.mouseLocalPos(), center, size / 2) and ui.mouseClicked(ui.MouseButton.Right) then
        local pin_state = win:pinned()
        win:setPinned(not pin_state)
        lock_states[app_name] = { pinned=not pin_state, start=Time }
        lock_storage:set(not pin_state)
    end

    local lock_info = lock_states[app_name]
    if lock_info == nil then
        -- nothing set, gather from files the previous states (if it exists)
        win:setPinned(lock_storage:get())
        lock_states[app_name] = { pinned=lock_storage:get(), start=-10 } -- start time so we don't play the anim when the game opens
    else
        local elapsed = Time - lock_info.start
        if elapsed > 1 then return end -- animation finished

        -- animation working, do it
        local anim_length = 0.2
        local asset_size = vec2(50, 40) * 0.85
        local height_offset = 10
        local width = 8
        local radius = asset_size.x / 2 - width / 2
        local center_offset = 25
        local full_size = asset_size + vec2(0, height_offset + radius)
        if lock_info.pinned == false then
            elapsed = anim_length - elapsed
        end
        local min_x = math.min(full_size.x, size.x)
        local min_y = math.min(full_size.y, size.y)
        local ratio = math.clamp(math.min(min_x / full_size.x, min_y / full_size.y), 0, 1)
        asset_size = asset_size * ratio * app_scale
        height_offset = height_offset * ratio * app_scale
        radius = radius * ratio * app_scale
        center_offset = center_offset * ratio * app_scale
        width = width * ratio * app_scale

        local anim_lerp = settings.remap(math.clamp(elapsed, 0, anim_length), 0, anim_length, 0, 1)
        center = center + vec2(0, settings.remap(math.clamp(anim_lerp, 0, 0.5), 0, 0.5, 0, 10) - settings.remap(math.clamp(anim_lerp, 0.5, 1), 0.5, 1, 0, 10))

        local clip_offset = vec2(settings.remap(math.clamp(Time - lock_info.start, 0.3, 0.8), 0.3, 0.8, 0, size.x * 2), 0)
        ui.pushClipRect(center - size + clip_offset, center + size + clip_offset)

        ui.drawRectFilled(
            center + vec2(0, height_offset) - asset_size / 2,
            center + vec2(0, height_offset) + asset_size / 2,
            colors.WHITE,
            10 * ratio * app_scale, ui.CornerFlags.Bottom
        )

        local center_top = center + vec2(0, height_offset - center_offset)
        ui.pathClear()
        local points_count = 16
        local anim_angle = settings.remap(anim_lerp, 0, 1, math.pi, 0)
        local rotator = quat():setAngleAxis(anim_angle, 0, 1, 0)
        local offset = vec3(radius, 0, 0):rotate(rotator)
        
        local rotated_pos_3d = vec3(-radius, 0, 0):rotate(rotator)
        local end_pos = center + vec2(rotated_pos_3d.x -offset.x + radius, 0)
        ui.pathLineTo(end_pos)
        for i = 0, points_count-1 do
            local angle = settings.remap(i, 0, points_count-1, -math.pi, 0)
            local pos_3d = vec3(math.cos(angle), math.sin(angle), 0) * radius
            local rotated = pos_3d:rotate(rotator)
            local pos_2d = vec2(rotated.x, rotated.y)
            ui.pathLineTo(pos_2d + center_top + vec2(-offset.x + radius, 0))
        end
        ui.pathLineTo(center + vec2(asset_size.x / 2, -asset_size.y / 2) + vec2(-width / 2, height_offset + 10))
        ui.pathStroke(colors.WHITE, false, width)
        ui.drawCircleFilled(end_pos, width / 2, colors.WHITE)
        ui.popClipRect()
    end
end

return settings