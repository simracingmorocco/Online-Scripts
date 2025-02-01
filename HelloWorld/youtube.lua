---A silly example of how Youtube might be integrated into a script, semi-functional Youtube app in
---200 lines of code. Of course though, it would not last for long without official SDK. I tried to
---get a key for it, but apparently there is now a form with a couple of dozens questions I’d need
---to fill out first.

---@type ui.MediaPlayer
local youtubePlayer = nil
local youtubeError = nil
local searchQuery = nil
local videos = nil
local selectedVideo = nil
local selectedVideoProgress = nil

---Very simple parsing of a youtube page.
local function parseYoutubeMainPage(html)
  local ret = {}
  local searchFrom = 1
  while true do
    local index = html:find('"videoRenderer"', searchFrom)
    if index == nil then return ret end
    local id = html:match('"videoId":"(.-)"', index)
    local thumbnail = html:match('"thumbnails":%[{"url":"(.-)"', index)
    local title = html:match('"title":{"runs":%[{"text":"(.-)"}', index)
    local published = html:match('"publishedTimeText":{"simpleText":"(.-)"', index)
    local views = html:match('"viewCountText":{"simpleText":"(.-)"', index)
    if id and thumbnail and title then
      table.insert(ret, { id = id, thumbnail = thumbnail, title = title, published = published, views = views, hovered = 0 })
    end
    searchFrom = index + 1
  end
end

---A UI control with video preview and a very primitive animation on hover.
local function videoPreview(v, dt)
  ui.beginGroup()
  local c = ui.getCursor()
  ui.image(v.thumbnail, vec2(284, 160), true)
  ui.drawRectFilled(c + vec2(0, math.lerp(160, 120, v.hovered)), c + vec2(284, 160), rgbm(0, 0, 0, 0.7))
  local a = math.ceil(v.hovered * 24)
  if a > 1 then
    ui.setCursor(c + vec2(8, 124 + (24 - a)))
    ui.textAligned(v.title, vec2(0.5, 0), vec2(284-16, a))
    ui.pushFont(ui.Font.Small)
    ui.setCursor(c + vec2(8, 132 + (24 - a)))
    ui.textAligned(v.views, vec2(0, 1), vec2(284-16, a))        
    ui.setCursor(c + vec2(8, 132 + (24 - a)))
    ui.textAligned(v.published, vec2(1, 1), vec2(284-16, a))
    ui.popFont()
  end
  ui.endGroup()
  v.hovered = math.applyLag(v.hovered, ui.itemHovered() and 1 or 0, 0.8, dt)
  return ui.itemClicked(ui.MouseButton.Left)
end

---A UI control with video player. Again, very primitive, uses sliders for time and volume bars. Of course, could be done better,
---but for an example that should be all right.
---@param videoPlayer ui.MediaPlayer
local function videoPlayerControl(videoPlayer)
  ui.beginGroup()
  local width = ui.availableSpaceX()
  local height = math.ceil(width * 9 / 16)
  local pos = ui.getCursor()

  ui.image(videoPlayer, vec2(width, height), true)

  ui.setCursor(pos + vec2(20, height - 40))  
  if ui.button(videoPlayer:playing() and 'Pause' or 'Play', vec2(60, 0)) then
    if videoPlayer:playing() then videoPlayer:pause() else videoPlayer:play() end
  end
  ui.setCursor(pos + vec2(100, height - 40))
  ui.setNextItemWidth(width - 220)
  local newTime = ui.slider('##position', videoPlayer:currentTime(), 0, videoPlayer:duration(), '')
  if ui.itemEdited() then 
    videoPlayer:setCurrentTime(newTime) 
    setTimeout(function () videoPlayer:play() end, 0.01)
  end
  ui.setCursor(pos + vec2(width - 100, height - 40))
  ui.setNextItemWidth(80)
  local newVolume = ui.slider('##volume', videoPlayer:volume(), 0, 1, '')
  if ui.itemEdited() then videoPlayer:setVolume(newVolume) end
  ui.endGroup()
end

---Finds optimal format from list of formats returned by yt-dlp. Prefers something with both audio and video,
---looking for the largest file.
local function findOptimalQuality(data)
  return tostring(table.maxEntry(data:split('\n'), function (format)
    if string.match(format, 'audio only') or not string.match(format, 'iB') then return -1e9 end
    local w = 0
    if string.match(format, 'video only') then w = w - 20 end
    if string.match(format, 'mp4_dash') then w = w + 10 end
    if string.match(format, '3gp') then w = w - 5 end
    local v, u = string.match(format, ' ([0-9.]+)([MKG])iB')
    v = tonumber(v) or 0
    if u == 'M' then v = v * 1e3
    elseif u == 'G' then v = v * 1e6 end
    w = w + v / 1e6
    return w
  end):sub(1, 3):trim())
end

---Gets URL of a video stream from video URL using yt-dlp.
local function findVideoStreamURL(videoURL, callback, progressCallback)
  progressCallback('Getting list of available formats…')
  os.runConsoleProcess({ filename = 'yt-dlp.exe', arguments = { '-F', videoURL } }, function (err, data)
    if err then return callback(err) end
    local quality = findOptimalQuality(data.stdout)
    if quality == nil then callback('Failed to find optimal quality') end
    progressCallback('Getting a stream URL…')
    os.runConsoleProcess({ filename = 'yt-dlp.exe', arguments = { '-f', quality, '--get-url', videoURL } }, function (err, data) callback(err, data.stdout) end)
  end)
end

---Select a video, start showing (find stream URL and get it to video player).
local function selectVideo(video)
  if video == selectedVideo then return end
  selectedVideo = video
  if video ~= nil then
    findVideoStreamURL('https://www.youtube.com/watch?v='..video.id, function (err, url)
      if err then
        selectedVideoProgress = 'Failed to get video URL: '..err
        return
      end
      selectedVideoProgress = nil
      youtubePlayer:setSource(url):setCurrentTime(0)
      setTimeout(function () youtubePlayer:play() end, 0.01)
    end, function (state)
      selectedVideoProgress = state
    end)
  else
    youtubePlayer:setSource(''):pause()
  end
end

---Load Youtube page and parse it into a bunch of videos.
local function loadYoutubePage(url)
  videos = nil
  youtubeError = nil
  web.get(url, function (err, response)
    if err then
      youtubeError = 'Failed to load YouTube: '..err
      return
    end
    try(function ()
      videos = parseYoutubeMainPage(response.body)
    end, function (err)
      youtubeError = 'Failed to parse YouTube: '..err
    end)
  end)
end

---Main Youtube app thing: either shows a fullscreen video, if any selected, or list of videos with optional search.
return function (dt)
  if selectedVideo ~= nil then
    ui.pushFont(ui.Font.Title)
    ui.text(selectedVideo.title)
    ui.popFont()
    if selectedVideoProgress then
      ui.text(selectedVideoProgress)
    else
      local cur = ui.getCursor()
      videoPlayerControl(youtubePlayer)
      ui.setCursor(cur + vec2(20, 20))
      if ui.button('Back', vec2(60, 0)) then
        youtubePlayer:pause()
        selectedVideo = nil
      end
    end
    return
  end

  if youtubePlayer == nil then
    youtubePlayer = ui.MediaPlayer():setAutoPlay(true):setBalance(1)
    loadYoutubePage('https://m.youtube.com')
  end

  ui.setNextItemWidth(ui.availableSpaceX())
  searchQuery = ui.inputText('Search', searchQuery, bit.bor(ui.InputTextFlags.Placeholder, ui.InputTextFlags.ClearButton))
  if ui.itemEdited() then
    setTimeout(function ()
      local query = searchQuery:trim()
      loadYoutubePage(#query > 0 and 'https://m.youtube.com/results?search_query='..searchQuery or 'https://m.youtube.com')
    end, 1, 'search')
  end

  if not videos then
    ui.text(youtubeError or 'Loading list of videos…')
  elseif #videos == 0 then
    ui.text('No videos found')
  else
    for _, v in ipairs(videos) do
      if videoPreview(v, dt) then
        selectVideo(v)
      end
      ui.sameLine()
      if ui.availableSpaceX() < 240 then
        ui.newLine()
      end
    end
  end
end
