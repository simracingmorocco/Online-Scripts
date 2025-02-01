ui.setAsynchronousImagesLoading(true)

local counter = 0

local settings = ac.storage{
  flashIcon = true,
  customGameHUD = false,
  customVirtualMirror = true
}

ac.redirectVirtualMirror(settings.customVirtualMirror)

local light = nil

function script.fullscreenUI()
  ac.redirectVirtualMirror(settings.customGameHUD and settings.customVirtualMirror)
  if not settings.customGameHUD then return end -- always consider making fullscreen HUDs optional

  local uiState = ac.getUI()
  ui.transparentWindow('helloWorldSpeedometer', uiState.windowSize - vec2(300, 280), vec2(200, 200), function ()
    local car = ac.getCar(0)
    local center = vec2(100, 100)
    local markColor = rgbm(1, 1, 1, 0.3)
    local markRedColor = rgbm(1, 0, 0, 0.7)
    local needleColor = rgbm(1, 1, 1, 1)
    ui.drawCircleFilled(center, 100, rgbm(0, 0, 0, 0.5), 40)

    for i = 0, 10 do 
      local s = math.sin(math.lerp(-0.7, 0.7, i / 10) * math.pi)
      local c = -math.cos(math.lerp(-0.7, 0.7, i / 10) * math.pi)
      ui.drawLine(center + vec2(s, c) * 70, center + vec2(s, c) * 90, i > 7 and markRedColor or markColor, 1.5)
    end

    for i = 0, 30 do 
      if i % 3 ~= 0 then 
        local s = math.sin(math.lerp(-0.7, 0.7, i / 30) * math.pi)
        local c = -math.cos(math.lerp(-0.7, 0.7, i / 30) * math.pi)
        ui.drawLine(center + vec2(s, c) * 80, center + vec2(s, c) * 90, i > 23 and markRedColor or markColor, 1)
      end
    end

    -- ui.text('speed:'..math.lerpInvSat(car.speedKmh, 0, 300))
    local angle = math.lerp(-0.7, 0.7, math.lerpInvSat(car.rpm, 0, car.rpmLimiter * 1.2)) * math.pi
    local s = math.sin(angle)
    local c = -math.cos(angle)
    ui.drawLine(center - vec2(s, c) * 20, center + vec2(s, c) * 95, needleColor, 1.5)

    ui.setCursor(vec2(0, 115))
    ui.pushFont(ui.Font.Title)
    ui.textAligned(string.format('%.0f', car.speedKmh), vec2(0.5, 0), vec2(200, 0))
    ui.popFont()    

    ui.setCursor(vec2(0, 140))
    ui.pushFont(ui.Font.Small)
    ui.textAligned('km/h', vec2(0.5, 0), vec2(200, 0))
    ui.popFont()

    ui.setCursor(vec2(0, 165))
    ui.pushFont(ui.Font.Monospace)
    ui.textAligned(string.format('%07.1f', car.distanceDrivenSessionKm), vec2(0.5, 0), vec2(200, 0))
    ui.popFont()
  end)

  local simState = ac.getSim()
  if simState.isVirtualMirrorActive and settings.customVirtualMirror then
    ui.transparentWindow('helloWorldMirror', vec2(uiState.windowSize.x / 2 - 300, 20), vec2(600, 150), function ()
      ui.drawVirtualMirror(vec2(), vec2(600, 150))
    end)
  end
end

function script.Draw3D(dt)
  ac.debug('AI controlled', ac.getCar(0).isAIControlled)
  ac.debug('tyre temperature: core', ac.getCar(0).wheels[0].tyreCoreTemperature)
  ac.debug('tyre temperature: inside', ac.getCar(0).wheels[0].tyreInsideTemperature)
  ac.debug('tyre temperature: middle', ac.getCar(0).wheels[0].tyreMiddleTemperature)
  ac.debug('tyre temperature: outside', ac.getCar(0).wheels[0].tyreOutsideTemperature)
  render.debugSphere(vec3(172.27, 3.23, -538.84), 0.3)
end

local state = refbool(true)
local stateN = refnumber(17)
local stateC = false

local function tab1()
  ui.text('TAB 1')
  ui.text('physics late: '..ac.getSim().physicsLate)
  ui.text('CPU occupancy: '..ac.getSim().cpuOccupancy)
  ui.text('CPU time: '..ac.getSim().cpuTime)
end

ac.debug('car ID', ac.getCarName(0, true))

ac.onChatMessage(function (message, carIndex, sessionID)
  ac.log(string.format('Message `%s` from %s, sessionID=%s, filtering: %s', message, carIndex, sessionID, message:match('ass') ~= nil))
  if message:match('damn') ~= nil and carIndex ~= 0 then
    -- no swearing on my christian server
    return true
  end
end)

ac.onConsoleInput(function (msg)
  -- if msg == 'help' then
  --   ac.console('No help for you')
  --   return true
  -- end
  if msg:sub(1, 5) == 'eval ' then
    local f = loadstring('return ('..msg:sub(6)..')')
    local _, r = pcall(f)
    ac.console(r)
    return true
  end
end)

local customCameraActive = false

---@type ac.GrabbedCamera
local customCameraHeld = nil

local function tab2()
  if ui.slider("slider", stateN, 0, 100, "%.3f") then
    ui.text("moved")
  end

  -- ui.text('AI level: '..tostring(ac.getCar(1).aiLevel))
  -- ui.text('AI aggression: '..tostring(ac.getCar(1).aiAggression))
  -- ui.text('caster: '..ac.getCar(0).caster)
  -- ui.text('caster: '..ac.getCar(0).racePosition)
  ui.text('connected cars: '..tostring(ac.getSim().connectedCars))
  ui.text('FFB pure: '..tostring(ac.getCar(0).ffbPure))
  ui.text('FFB final: '..tostring(ac.getCar(0).ffbFinal))
  ui.text('FFB gain: '..tostring(ac.getCar(0).ffbMultiplier))

  local newFFBMultiplier = ui.slider('##ffbSlider', ac.getCar(0).ffbMultiplier * 100, 0, 200, 'FFB gain: %.0f%%') / 100
  if ui.itemEdited() then
    ac.setFFBMultiplier(newFFBMultiplier)
  end

  ui.text(string.format('current splits: %s (first: %s, len: %s)', ac.getCar(0).currentSplits, ac.getCar(0).currentSplits[0], #ac.getCar(0).currentSplits))
  ui.text(string.format('last splits: %s (first: %s, len: %s)', ac.getCar(0).lastSplits, ac.getCar(0).lastSplits[0], #ac.getCar(0).lastSplits))
  ui.text(string.format('best splits: %s (first: %s, len: %s)', ac.getCar(0).bestSplits, ac.getCar(0).bestSplits[0], #ac.getCar(0).bestSplits))
  if ui.button('Do console') then
    ac.console('Hello from Lua!')
    ac.consoleExecute('help')
  end

  if ui.checkbox('Custom camera motion', customCameraActive) then
    customCameraActive = not customCameraActive
    if customCameraActive and not customCameraHeld then
      local holdError
      customCameraHeld, holdError = ac.grabCamera('custom camera motion')
      if not customCameraHeld then
        ui.toast(ui.Icons.Warning, string.format('Couldn’t grab camera: %s', holdError))
        customCameraActive = false
      else
        customCameraHeld.ownShare = 0
      end
    end
    -- if customCameraActive then
    --   customCameraMotion:stop()
    --   customCameraActive = nil
    -- else
    -- end
  end
end

local function updateCustomCameraMotion()
  if customCameraHeld == nil then return end
  customCameraHeld.ownShare = math.applyLag(customCameraHeld.ownShare, customCameraActive and 1 or 0, 0.9, ac.getSim().dt)

  if not customCameraActive and customCameraHeld.ownShare < 0.0001 then
    customCameraHeld:dispose()
    customCameraHeld = nil
  else
    local c = ac.getCar(0)
    customCameraHeld.transform.position = c.pos + c.side * 4 + c.look * c.aabbCenter.z + c.up * c.aabbCenter.y
    customCameraHeld.transform.look = -c.side
    customCameraHeld.transform.up = c.up
    customCameraHeld.fov = 90
    -- customCameraHeld.dofFactor = 1
    -- customCameraHeld.dofDistance = 4
    customCameraHeld:normalize()
  end
end

local function tabRealMirrors()
  if ac.getRealMirrorCount() == 0 then
    ui.text('No Real Mirrors available')
  end

  ac.forceFadingIn()
  for i = 1, ac.getRealMirrorCount() do
    ui.pushID(i)
    ui.header(string.format('Mirror %d', i))
    local p, c = ac.getRealMirrorParams(i - 1), true

    ui.beginGroup()

    ui.setNextItemWidth((ui.availableSpaceX() - 4) / 2)
    p.rotation.x = ui.slider('##rotationX', p.rotation.x, -1, 1, 'Rotation X: %.2f')
    ui.sameLine(0, 4)
    ui.setNextItemWidth(ui.availableSpaceX())
    p.rotation.y = ui.slider('##rotationY', p.rotation.y, -1, 1, 'Rotation Y: %.2f')   
    
    ui.setNextItemWidth((ui.availableSpaceX() - 4) / 2)
    p.fov = ui.slider('##fov', p.fov, 2, 20, 'FOV: %.2f°')   
    ui.sameLine(0, 4)
    ui.setNextItemWidth(ui.availableSpaceX())
    p.aspectMultiplier = ui.slider('##ratio', p.aspectMultiplier, 0.5, 2, 'Aspect mult.: %.2f', 1.6)   

    ui.setNextItemWidth((ui.availableSpaceX() - 4) / 3)
    if ui.checkbox('Monitor', p.isMonitor) then p.isMonitor, c = not p.isMonitor, true end
    ui.sameLine(0, 4)
    ui.setNextItemWidth((ui.availableSpaceX() - 4) / 2)
    if ui.checkbox('Monitor shader', p.useMonitorShader) then p.useMonitorShader, c = not p.useMonitorShader, true end
    ui.sameLine(0, 4)
    ui.text('Matrix type:')
    ui.sameLine()
    ui.setNextItemWidth(ui.availableSpaceX())
    p.monitorShaderType = ui.combo('##monitorType', p.monitorShaderType , { [0] = 'TN', 'VA', 'IPS' })
    
    ui.setNextItemWidth((ui.availableSpaceX() - 4) / 2)
    if ui.checkbox('Flip X', bit.band(p.flip, ac.MirrorPieceFlip.Horizontal) ~= 0) then p.flip, c = bit.bxor(p.flip, ac.MirrorPieceFlip.Horizontal), true end
    ui.sameLine(0, 4)
    if ui.checkbox('Flip Y', bit.band(p.flip, ac.MirrorPieceFlip.Vertical) ~= 0) then p.flip, c = bit.bxor(p.flip, ac.MirrorPieceFlip.Vertical), true end
    
    ui.endGroup()

    if c or ui.itemEdited() then
      ac.setRealMirrorParams(i - 1, p)
    end
    ui.popID()
    ui.offsetCursorY(12)
  end
  ui.text('Note: if you are creating a config for a car, move settings to the config. You can find settings here:')
  if ui.button('Folder with settings') then
    local dir = ac.getFolder(ac.FolderID.Documents)..'/Assetto Corsa/cfg/extension/real_mirrors'
    local filename = dir..'/'..ac.getCarID(0)..'.ini'
    if io.exists(filename) then os.showInExplorer(filename)
    else os.openInExplorer(dir) end
  end
  -- error('oops')
end

local lastReply = nil
local selectedFile = nil

local function tabMirror()
  local sizeX = ui.availableSpaceX()
  local cur = ui.getCursor()
  ui.drawVirtualMirror(cur, cur + vec2(sizeX, sizeX * 0.25))
  ui.offsetCursorY(sizeX * 0.25 + 20)

  if ui.button('Run cmd /C dir', lastReply == false and ui.ButtonFlags.Disabled or ui.ButtonFlags.None) then
    lastReply = false
    ac.debug('here', 'os')

    os.runConsoleProcess({
      filename = 'c:\\windows\\system32\\cmd.exe',
      arguments = {
        '/C', 'dir'
      },
    }, function (err, data)
      lastReply = 'Exit code: '..tostring(err)..'\nStdOut:\n'..data.stdout
    end)
  end
  if lastReply then ui.textWrapped(lastReply) end

  if ui.button('Select file', selectedFile == false and ui.ButtonFlags.Disabled or ui.ButtonFlags.None) then
    os.openFileDialog({
      title = 'Open',
      defaultFolder = ac.getFolder(ac.FolderID.Root),
      fileTypes = {
        {
          name = 'Images',
          mask = '*.png;*.jpg;*.jpeg;*.psd'
        }
      },
      addAllFilesFileType = true,
      flags = bit.bor(os.DialogFlags.PathMustExist, os.DialogFlags.FileMustExist)
    }, function (err, filename)
      selectedFile = err and 'Error: '..err or filename and 'Selected file: '..filename or 'No file selected'
    end)
  end
  if selectedFile then ui.text(selectedFile) end
end

local function tabTextWithGradient()
  -- ui.beginTextureShade(myPlayer)
  ui.pushDWriteFont(ui.DWriteFont('UKNumberPlate', '.'))

  ui.beginGradientShade()
  local c = ui.getCursor()
  ui.dwriteText('Hello World!', 40, rgbm.colors.white)
  ui.endGradientShade(c, c + ui.measureDWriteText('Hello World!', 40), rgbm.colors.red, rgbm.colors.blue)

  ui.beginGradientShade()
  local c = ui.getCursor()
  ui.dwriteText('Hello World!', 40, rgbm.colors.white)
  ui.endGradientShade(c, c + vec2(0, ui.measureDWriteText('Hello World!', 40).y), rgbm.colors.red, rgbm.colors.blue)

  for i = 1, 20 do
    ui.beginGradientShade()
    local c = ui.getCursor()
    ui.dwriteText('Row: '..i, 40, rgbm.colors.white)
    ui.endGradientShade(c, c + vec2(0, ui.measureDWriteText('Hello World!', 40).y), rgbm.colors.red, rgbm.colors.blue)
    ui.drawRect(ui.getCursor(), ui.getCursor() + vec2(100, 2), rgbm.colors.yellow)
  end

  ui.popDWriteFont()
end

local myPlayer = ui.MediaPlayer('TallShip-medium.wmv'):setAutoPlay(true):setMuted(true)

local function tabVideo()
  ui.text('Drag mouse over this video for a highlight:')
  local cur = ui.getCursor() + vec2(100, 100)
  ui.drawImage(myPlayer, cur - vec2(100, 100), cur + vec2(100, 100))
  ui.pushClipRect(cur - vec2(100, 100), cur + vec2(100, 100))
  ui.beginTextureShade(myPlayer)
  local piv = ui.mouseLocalPos()
  for i = 1, 30 do
    local a = math.pi * 2 * i / 30
    local s, c = math.sin(a), math.cos(a)
    ui.pathLineTo(piv + vec2(s * (i % 2 == 0 and 80 or 60), c * (i % 2 == 0 and 80 or 60)))
  end
  ui.pathStroke(rgbm.colors.yellow, true, 30)
  ui.popClipRect()
  ui.endTextureShade(cur - vec2(100, 100), cur + vec2(100, 100), false)
end

function script.windowMain(dt)
  ui.beginOutline()

  ui.text('Hello World! First Lua app is here')
  ui.text(counter)  
  ui.checkbox("test", state)
  if ui.checkbox("test2", stateC) then 
    stateC = not stateC 
  end
  if state.value then 
    ui.text("chckbox clicked")
  else
    ui.text("chckbox not") 
  end

  ui.tabBar('someTabBarID', function ()
    ui.tabItem('Tab 1', tab1)
    ui.tabItem('Tab 2', tab2)
    ui.tabItem('Real Mirrors', tabRealMirrors)
    ui.tabItem('Mirror', tabMirror)
    ui.tabItem('Gradient', tabTextWithGradient)
    ui.tabItem('Video', tabVideo)
  end)

  ui.endOutline(rgbm(0, 0, 0, ac.windowFading()), 1)
end

local color = rgbm(1, 0, 0, 1)

function script.windowExtras(dt)
  ui.colorPicker('Color', color, ui.ColorPickerFlags.PickerHueBar)
end

function script.windowYoutube(dt)
  require('youtube')(dt)
end

local iconFlash = false
setInterval(function() iconFlash = not iconFlash end, 0.5)

function script.windowMainIcon(dt)
  if settings.flashIcon and iconFlash then
    local space = ui.availableSpace()
    ui.drawCircleFilled(space - 4, 4, rgbm(1, 0, 0, 1))
    ui.glowCircleFilled(space - 4, space.x * 10, rgbm(1, 0 , 0, 1))
    -- ui.drawRectFilled(vec2(), space, rgbm(1, 0, 0, 1))
  end
end

function script.windowMainSettings(dt)
  ui.text('Hello Settings!')
  
  if ui.checkbox('Flash icon', settings.flashIcon) then 
    settings.flashIcon = not settings.flashIcon 
  end
  
  if ui.checkbox('Custom HUD', settings.customGameHUD) then 
    settings.customGameHUD = not settings.customGameHUD 
  end
  
  if ui.checkbox('Custom virtual mirror', settings.customVirtualMirror) then 
    settings.customVirtualMirror = not settings.customVirtualMirror 
  end

  ui.childWindow('scrolling', vec2(200, 400), function ()
    for i = 1, 1000 do
      ui.text('Row '..i)
    end
  end)
end

function script.update(dt)

  if light == nil then
    light = ac.LightSource(ac.LightType.Regular)
    light.position = vec3(-24.64, 30, 115.07)
    light.direction = vec3(0, -1, 0)
    light.spot = 150
    light.spotSharpness = 0.99
    light.color = rgb(0, 10, 0)
    light.range = 100
    light.shadows = true
    light.fadeAt = 500
    light.fadeSmooth = 200
  end

  counter = counter + dt
  updateCustomCameraMotion()
end
