local motec = require("shared\\sim\\motec")
local logger = motec.TelemetryCollector(0)
local loggerSettings = ac.storage({ autoLog = false, dropShortLogTime = 30, fadeApp = false, fadeStatus = false })
local toggleLogButton = ac.ControlButton("__APP_CSP_DATA_LOGGER_TOGGLE")
local vec2Temp1 = vec2()

local function getMotecDirectory(carIndex)
	return string.format(
		"%s/telemetry/%s/%s",
		ac.getFolder(ac.FolderID.ACDocuments),
		ac.getTrackID(),
		ac.getCarID(carIndex)
	)
end

local function getMotecFilename(carIndex)
	local prefix = string.format(
		"%s/%s_&_%s_&_%s_&_stint_",
		getMotecDirectory(carIndex),
		ac.getTrackID(),
		ac.getCarID(carIndex),
		ac.getDriverName(carIndex)
	)

	local filename
	for i = 1, 1e6 do
		filename = prefix .. i .. ".ld"
		if not io.exists(filename) then
			break
		end
	end
	io.createFileDir(filename)
	return filename
end

local function loggerActive()
	return logger:active()
end

local function loggerTime()
	return math.round(logger:time(), 3)
end

local function loggerDrop()
	logger:drop()
	ui.toast(ui.Icons.CarFront, "Stopped recording Motec data, recorded data dropped")
	ac.log("Stopped recording Motec data, recorded data dropped")
end

local function loggerStart()
	if loggerActive() then
		return
	end
	logger:begin()
	ui.toast(ui.Icons.CarFront, "Started recording Motec data"):button(ui.Icons.Cancel, "Cancel", function()
		loggerDrop()
	end)
	ac.log("Started recording Motec data")
end

local function loggerEnd()
	if loggerSettings.dropShortLogTime > 0 and loggerTime() < loggerSettings.dropShortLogTime then
		logger:drop()
		ui.toast(ui.Icons.CarFront, "Insufficient Motec log time, recorded data dropped")
		ac.log("Insufficient Motec log time, recorded data dropped")
		return
	end

	local logFilename = getMotecFilename(0)
	logger:finishAsync(logFilename, function(err, savedChannels)
		if err then
			ac.error("Logger saving error: %s" % err)
		else
			ui.toast(ui.Icons.Save, "Motec log saved"):button(ui.Icons.File, "View in Explorer", function()
				os.showInExplorer(logFilename)
			end)
			ac.log("Log filed saved - " .. logFilename)
		end
	end)
end

toggleLogButton:onPressed(function()
	if loggerActive() then
		loggerEnd()
	else
		loggerStart()
	end
end)

if loggerSettings.autoLog then
	ac.log("Auto-Log Active")
	loggerStart()
end

function script.windowSettings(dt)
	ui.text("Toggle Logging:")
	ui.sameLine()
	toggleLogButton:control(vec2Temp1:set(161, 0))

	if ui.checkbox("Auto-Log", loggerSettings.autoLog) then
		loggerSettings.autoLog = not loggerSettings.autoLog
	end
	if ui.itemHovered() then
		ui.setTooltip("Automatically begin logging after launching AC.")
	end

	ui.setNextItemWidth(ui.availableSpaceX())
	local value, changed = ui.slider(
		"##dropShortLogTimeSlider",
		loggerSettings.dropShortLogTime,
		0,
		60,
		loggerSettings.dropShortLogTime > 0 and "Minimum log time: %.0f s" or "Minimum log time: None",
		1
	)
	if changed then
		loggerSettings.dropShortLogTime = value
	end
	if ui.itemHovered() then
		ui.setTooltip(
			string.format("Logs won't save if they are below this time threshold.", loggerSettings.dropShortLogTime)
		)
	end

	ui.newLine()
	if ui.checkbox("Show All UI", not loggerSettings.fadeApp) then
		loggerSettings.fadeApp = not loggerSettings.fadeApp
	end
	if ui.itemHovered() then
		ui.setTooltip("Force app UI to remain visible.")
	end

	if ui.checkbox("Show Status UI", not loggerSettings.fadeStatus) then
		loggerSettings.fadeStatus = not loggerSettings.fadeStatus
	end
	if ui.itemHovered() then
		ui.setTooltip("Forces status and time to remain\nvisible if 'Show All UI' is disabled.")
	end
	ui.dummy(2)
end

function script.windowMain(dt)
	if not loggerSettings.fadeApp then
		ac.forceFadingIn()
	end

	local isLoggerActive = loggerActive()
	local isWindowFaded = ac.windowFading() >= 0.5

	if loggerSettings.fadeStatus and isWindowFaded then
		return
	end

	ui.setCursorY(36)
	ui.beginGroup(125)
	ui.dwriteText(
		string.format("Status: %s", isLoggerActive and "Active" or "Inactive"),
		16,
		isLoggerActive and rgbm.colors.lime or rgbm.colors.red
	)
	ui.dwriteText(string.format("Time: %s", loggerTime()), 16, rgbm.colors.white)
	ui.endGroup()

	if isWindowFaded then
		return
	end

	ui.sameLine()
	ui.beginGroup(200)
	if isLoggerActive then
		if ui.button("Stop & Save", vec2Temp1:set(108, 24), ui.ButtonFlags.None) then
			loggerEnd()
		end
		ui.sameLine()
		if ui.iconButton(ui.Icons.Trash, vec2Temp1:set(24, 24)) then
			loggerDrop()
		end
		if ui.itemHovered() then
			ui.setTooltip("Stops logging and drops anything already collected")
		end
	else
		if ui.button("Start", vec2Temp1:set(140, 24), ui.ButtonFlags.None) then
			loggerStart()
		end
	end

	if ui.button("Open Log Folder", vec2Temp1:set(140, 24), ui.ButtonFlags.None) then
		local logDirectory = getMotecDirectory(0)
		os.openInExplorer(logDirectory)
	end
	ui.endGroup()

	ui.newLine(-10)
	ui.dwriteText("Logging will continue, even if this window is closed.", 10, rgbm.colors.white)

	ui.dummy(3)
end

ac.onSessionStart(function(sessionIndex, restarted)
	if not loggerActive() then
		return
	end
	ac.log("New session or restart, restarting logger")
	loggerEnd()
	loggerStart()
end)

ac.onRelease(function(item)
	if loggerActive() then
		ac.log("AC shutting down, saving log")
		loggerEnd()
	end
end)
