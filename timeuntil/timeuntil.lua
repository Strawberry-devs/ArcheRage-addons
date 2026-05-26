-------------- Original Author: Strawberry --------------
----------------- Discord: exec_noir --------------------
if API_TYPE == nil then
	ADDON:ImportAPI(8)
	X2Chat:DispatchChatMessage(
		CMF_SYSTEM,
		"Globals folder not found. Please install it at https://github.com/Schiz-n/ArcheRage-addons/tree/master/globals"
	)
	return
end
--------------- Thanks to Koala and Zilus ---------------
ADDON:ImportObject(OBJECT_TYPE.TEXT_STYLE)
ADDON:ImportObject(OBJECT_TYPE.BUTTON)
ADDON:ImportObject(OBJECT_TYPE.DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.NINE_PART_DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.COLOR_DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.WINDOW)
ADDON:ImportObject(OBJECT_TYPE.LABEL)
ADDON:ImportObject(OBJECT_TYPE.ICON_DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.IMAGE_DRAWABLE)

ADDON:ImportAPI(API_TYPE.CHAT.id)
ADDON:ImportAPI(API_TYPE.TIME.id)
ADDON:ImportAPI(API_TYPE.MAP.id)
ADDON:ImportAPI(API_TYPE.LOCALE.id) --add to localization

--window length saved
local countFilePath = "TimeUntilWindowCount.txt"
local filterFilePath = "TimeUntilEventFilters.txt"

local function SaveTimerCount(count)
	local file = io.open(countFilePath, "w")
	file:write(tostring(count))
	file:close()
end

local function LoadTimerCount()
	local file = io.open(countFilePath, "r")
	if not file then
		return 10
	end
	local line = file:read("*line")
	file:close()
	local num = tonumber(line)
	if num then
		return num
	else
		return 10
	end
end

local function SaveEventFilters(filters)
	local file = io.open(filterFilePath, "w")
	if not file then
		return
	end
	for name, isFiltered in pairs(filters) do
		if isFiltered then
			file:write(name .. "\n")
		end
	end
	file:close()
end

local function LoadEventFilters()
	local filters = {}
	local file = io.open(filterFilePath, "r")
	if not file then
		return filters
	end
	for line in file:lines() do
		if line ~= nil and line ~= "" then
			filters[line] = true
		end
	end
	file:close()
	return filters
end

---

local timerAnchor = CreateEmptyWindow("timerAnchor", "UIParent")
timerAnchor:Show(true)
timerAnchor:AddAnchor("TOPLEFT", "UIParent", 100, 100)
timerAnchor:SetExtent(150, 50)
timerAnchor:EnableDrag(true)
local background = timerAnchor:CreateColorDrawable(0, 0, 0, 0.5, "background")
background:AddAnchor("TOPLEFT", timerAnchor, 0, 0)
background:AddAnchor("BOTTOMRIGHT", timerAnchor, 0, 0)
local amountOfTimers = LoadTimerCount()
local eventLabels = {}
local timerLabels = {}
function updateTimers()
	timerAnchor:SetExtent(150, amountOfTimers * 25)

	for i = 1, amountOfTimers do
		if eventLabels[i] == nil then
			local lblEventName = timerAnchor:CreateChildWidget("label", "timerLabelEvent" .. i, 0, false)
			lblEventName:SetHeight(20)
			lblEventName.style:SetFontSize(16)
			lblEventName:AddAnchor("TOPLEFT", timerAnchor, 0, (i - 1) * 25)
			lblEventName.style:SetAlign(ALIGN_LEFT)
			lblEventName.style:SetColor(255, 255, 255, 255)
			eventLabels[i] = lblEventName

			local lblTimer = timerAnchor:CreateChildWidget("label", "timerLabelTime" .. i, 0, false)
			lblTimer:SetHeight(20)
			lblTimer.style:SetFontSize(16)
			lblTimer:AddAnchor("TOPRIGHT", timerAnchor, 0, (i - 1) * 25)
			lblTimer.style:SetAlign(ALIGN_RIGHT)
			lblTimer.style:SetColor(255, 255, 255, 255)
			timerLabels[i] = lblTimer
		end

		eventLabels[i]:SetText("")
		eventLabels[i]:Show(true)
		timerLabels[i]:SetText("")
		timerLabels[i]:Show(true)
	end

	for i = amountOfTimers + 1, #eventLabels do
		eventLabels[i]:Show(false)
		timerLabels[i]:Show(false)
	end
end
updateTimers()
local moreEntries = timerAnchor:CreateChildWidget("button", "moreEntries", 0, true)
moreEntries:AddAnchor("TOPLEFT", timerAnchor, -5, -25)
moreEntries:SetStyle("text_default")
--ApplyButtonSkin(moreEntries, buttonskin)
moreEntries:SetExtent(35, 25)
--moreEntries:SetWidth(25)
moreEntries:SetText("+")

moreEntries:SetWidth(25)
function moreEntries:OnClick(arg)
	amountOfTimers = amountOfTimers + 1
	updateTimers()
	SaveTimerCount(amountOfTimers)
end
moreEntries:SetHandler("OnClick", moreEntries.OnClick)
local lessEntries = timerAnchor:CreateChildWidget("button", "lessEntries", 0, true)
lessEntries:AddAnchor("TOPLEFT", timerAnchor, 20, -25)
lessEntries:SetStyle("text_default")
--ApplyButtonSkin(lessEntries, buttonskin)
lessEntries:SetExtent(35, 25)
lessEntries:SetText("-")
lessEntries:SetWidth(25)
function lessEntries:OnClick(arg)
	if amountOfTimers > 1 then
		amountOfTimers = amountOfTimers - 1
		updateTimers()
		SaveTimerCount(amountOfTimers)
	end
end
lessEntries:SetHandler("OnClick", lessEntries.OnClick)

----- save draggable window ----------
local filePath = "TimeUntilWindowPos.txt"
local function GetUIScaleFactor()
	return UIParent:GetUIScale() or 1.0
end
local function SaveWindowPosition(x, y)
	local uiScale = GetUIScaleFactor()
	x = math.floor(x / uiScale)
	y = math.floor(y / uiScale)
	local file = io.open(filePath, "w")
	file:write(string.format("%d,%d", x, y))
	file:close()
end
local function LoadSavedPosition()
	local file = io.open(filePath, "r")
	if not file then
		return 0, 0
	end
	local line = file:read("*line")
	file:close()
	local x, y = line:match("(%d+),(%d+)")
	if x and y then
		return x, y
	else
		return 0, 0
	end
end
function timerAnchor:OnDragStart()
	self:StartMoving()
	self.moving = true
end
timerAnchor:SetHandler("OnDragStart", timerAnchor.OnDragStart)
function timerAnchor:OnDragStop()
	self:StopMovingOrSizing()
	self.moving = false
	local offsetX, offsetY = self:GetOffset()
	local uiScale = UIParent:GetUIScale() or 1.0
	local normalizedX = offsetX * uiScale
	local normalizedY = offsetY * uiScale
	SaveWindowPosition(normalizedX, normalizedY)
end
timerAnchor:SetHandler("OnDragStop", timerAnchor.OnDragStop)
local savedWindowX, savedWindowY = LoadSavedPosition()
timerAnchor:AddAnchor("TOPLEFT", "UIParent", tonumber(savedWindowX), tonumber(savedWindowY))

local whaleConflict = false
local aegConflict = true
local dynamicEvents = {}
local filteredEvents = LoadEventFilters()
local filterWindow = nil
local filterButtons = {}
local filterColumnCount = 3
local filterButtonWidth = 88
local filterButtonHeight = 25
local filterButtonGap = 4

local locale = timeUntilLocale or "en_us"
local serverEvents = naServerEvents or {}

if playerIsOnRuServer ~= nil and playerIsOnRuServer() and ruServerEvents ~= nil then
	serverEvents = ruServerEvents
end

local function setFilterButtonColor(button, isFiltered)
	if button == nil or button.style == nil then
		return
	end
	if isFiltered then
		SetButtonFontOneColor(button, { 0.9, 0.333, 0.333, 1 })
	else
		SetButtonFontOneColor(button, { 0.348, 0.609, 0.370, 1 })
	end
end

local function getVisibleFilterNames()
	local names = {}
	for name, _ in pairs(serverEvents) do
		table.insert(names, name)
	end
	table.sort(names)
	return names
end

local function refreshFilterWindow()
	if filterWindow == nil then
		return
	end

	local names = getVisibleFilterNames()
	local rowCount = math.ceil(#names / filterColumnCount)
	local windowWidth = (filterColumnCount * filterButtonWidth) + ((filterColumnCount + 1) * filterButtonGap)
	local windowHeight = (rowCount * (filterButtonHeight + filterButtonGap)) + filterButtonGap
	filterWindow:SetExtent(windowWidth, windowHeight)

	for i = 1, #names do
		if filterButtons[i] == nil then
			local row = math.floor((i - 1) / filterColumnCount)
			local col = (i - 1) % filterColumnCount
			local button = filterWindow:CreateChildWidget("button", "timeUntilFilterEvent" .. i, 0, true)
			button:AddAnchor(
				"TOPLEFT",
				filterWindow,
				filterButtonGap + (col * (filterButtonWidth + filterButtonGap)),
				filterButtonGap + (row * (filterButtonHeight + filterButtonGap))
			)
			button:SetStyle("text_default")
			button:SetExtent(filterButtonWidth, filterButtonHeight)
			button.style:SetFontSize(12)
			button.style:SetAlign(ALIGN_CENTER)
			function button:OnClick(arg)
				if self.eventName == nil then
					return
				end
				filteredEvents[self.eventName] = not filteredEvents[self.eventName]
				SaveEventFilters(filteredEvents)
				refreshFilterWindow()
			end
			button:SetHandler("OnClick", button.OnClick)
			filterButtons[i] = button
		end

		local button = filterButtons[i]
		local name = names[i]
		button.eventName = name
		button:SetText(name)
		button:Show(true)
		setFilterButtonColor(button, filteredEvents[name])
	end

	for i = #names + 1, #filterButtons do
		filterButtons[i].eventName = nil
		filterButtons[i]:SetText("")
		filterButtons[i]:Show(false)
	end
end

local function toggleFilterWindow()
	if filterWindow == nil then
		filterWindow = CreateEmptyWindow("timeUntilFilterWindow", "UIParent")
		filterWindow:AddAnchor("CENTER", "UIParent", 0, 0)
		filterWindow:SetExtent(280, 90)
		filterWindow:SetCloseOnEscape(true)
		filterWindow:EnableDrag(true)
		filterWindow:Show(false)

		function filterWindow:OnDragStart()
			self:StartMoving()
			self.moving = true
		end
		filterWindow:SetHandler("OnDragStart", filterWindow.OnDragStart)

		function filterWindow:OnDragStop()
			self:StopMovingOrSizing()
			self.moving = false
		end
		filterWindow:SetHandler("OnDragStop", filterWindow.OnDragStop)

		local filterBackground = filterWindow:CreateColorDrawable(0, 0, 0, 0.75, "background")
		filterBackground:AddAnchor("TOPLEFT", filterWindow, 0, 0)
		filterBackground:AddAnchor("BOTTOMRIGHT", filterWindow, 0, 0)
	end

	filterWindow:Show(not filterWindow:IsVisible())
	refreshFilterWindow()
end

local filterEntries = timerAnchor:CreateChildWidget("button", "filterEntries", 0, true)
filterEntries:AddAnchor("TOPLEFT", timerAnchor, 45, -25)
filterEntries:SetStyle("text_default")
filterEntries:SetExtent(35, 25)
filterEntries:SetText("?")
filterEntries:SetWidth(25)
filterEntries:SetHandler("OnClick", toggleFilterWindow)

local function calculateDayOfWeek(year, month, day)
	if month < 3 then
		month = month + 12
		year = year - 1
	end
	local k = year % 100
	local j = math.floor(year / 100)
	local dayOfWeek = (day + math.floor((13 * (month + 1)) / 5) + k + math.floor(k / 4) + math.floor(j / 4) + 5 * j) % 7
	return (dayOfWeek + 6) % 7 + 1
end

local function serverMinutesSinceMidnight(serverTimeTable)
	if not serverTimeTable then
		return nil
	end
	return (serverTimeTable.hour * 60) + serverTimeTable.minute
end

local function getServerEventMinutes(eventTimes, eventDays, currentServerMinutes, currentDayOfWeek)
	local eventMinutesList = {}

	for _, time in ipairs(eventTimes) do
		local eventMinutes = (time.hour * 60) + time.minute
		local dayOffset = nil

		for _, eventDay in ipairs(eventDays) do
			local daysAway = eventDay - currentDayOfWeek
			if daysAway < 0 then
				daysAway = daysAway + 7
			end
			if dayOffset == nil or daysAway < dayOffset then
				dayOffset = daysAway
			end
		end

		local minutesAway = eventMinutes - currentServerMinutes + (dayOffset * 1440)
		if minutesAway < 0 then
			--minutesAway = minutesAway + 1440
		end

		table.insert(eventMinutesList, minutesAway)
	end

	return eventMinutesList
end

local timer = 0
function timerAnchor:OnUpdate(dt)
	timer = timer + dt
	if timer > 1000 then
		timer = 0
		local isAM, currentHour, currentMinute = X2Time:GetGameTime()
		local serverTimeTable = UIParent:GetServerTimeTable()
		local currentServerMinutes = serverMinutesSinceMidnight(serverTimeTable)
		local dayOfWeek = calculateDayOfWeek(serverTimeTable.year, serverTimeTable.month, serverTimeTable.day)
		local sortedEvents = {}
		for name, eventList in pairs(serverEvents) do
			for _, eventData in ipairs(eventList) do
				local minutesList =
					getServerEventMinutes(eventData.times, eventData.days, currentServerMinutes, dayOfWeek)
				for i, minutesAway in ipairs(minutesList) do
					if minutesAway then
						--X2Chat:DispatchChatMessage(CMF_SYSTEM, tostring(minutesAway) .. " - " .. eventData.times[i].duration)
						--X2Chat:DispatchChatMessage(CMF_SYSTEM, tostring(eventDuration) .. " times: " .. eventData.times[i] .. " duration: " .. eventData.times[i].duration)
						local eventDuration = eventData.times[i] and eventData.times[i].duration or 0
						table.insert(sortedEvents, {
							name = name,
							minutes = minutesAway,
							duration = eventDuration,
							isServerEvent = true,
						})
					end
				end
			end
		end

		for i = #dynamicEvents, 1, -1 do
			local ev = dynamicEvents[i]
			local minutesLeftUntilStart = ev.endTime - currentServerMinutes - ev.duration
			if currentServerMinutes > ev.endTime then
				table.remove(dynamicEvents, i)
			else
				local remainingDuration = ev.endTime - currentServerMinutes
				local showMinutes = (minutesLeftUntilStart > 0) and minutesLeftUntilStart or 0
				table.insert(sortedEvents, {
					name = ev.name,
					minutes = showMinutes,
					duration = remainingDuration,
					isServerEvent = false,
				})
			end
		end

		table.sort(sortedEvents, function(a, b)
			return a.minutes < b.minutes
		end)

		if filterWindow ~= nil and filterWindow:IsVisible() then
			refreshFilterWindow()
		end

		for i = 1, amountOfTimers do
			if eventLabels[i] ~= nil then
				eventLabels[i]:SetText("")
				timerLabels[i]:SetText("")
			end
		end

		local displayIndex = 0
		for i, event in ipairs(sortedEvents) do
			--X2Chat:DispatchChatMessage(CMF_SYSTEM, tostring(event.minutes))
			if (event.minutes + event.duration) > 0 and not filteredEvents[event.name] then
				displayIndex = displayIndex + 1
				if eventLabels[displayIndex] then
					eventLabels[displayIndex]:SetText(event.name)
					local hours = math.floor(event.minutes / 60)
					local minutes = event.minutes % 60
					if event.minutes <= 0 then
						eventLabels[displayIndex].style:SetColor(255, 0, 0, 255)
						timerLabels[displayIndex].style:SetColor(255, 0, 0, 255)
						local timeEventIsActive = event.duration + event.minutes
						timerLabels[displayIndex]:SetText(string.format("Ends %02d", timeEventIsActive))
					else
						eventLabels[displayIndex].style:SetColor(255, 255, 255, 255)
						timerLabels[displayIndex].style:SetColor(255, 255, 255, 255)
						if event.name == "Big Titan" or event.name == "Small Titan" then
							eventLabels[displayIndex].style:SetColor(0.3, 0.7, 1, 255)
							timerLabels[displayIndex].style:SetColor(0.3, 0.7, 1, 255)
						end
						if
							event.name == dynamicEventsName[locale].whalesong
							or event.name == dynamicEventsName[locale].aegis
						then
							eventLabels[displayIndex].style:SetColor(1, 0.6, 0.1, 255)
							timerLabels[displayIndex].style:SetColor(1, 0.6, 0.1, 255)
						end
						if hours == 0 then
							timerLabels[displayIndex]:SetText(string.format("%02d", minutes))
						else
							timerLabels[displayIndex]:SetText(string.format("%02d:%02d", hours, minutes))
						end
					end
				end
			end
		end
	end
end
timerAnchor:SetHandler("OnUpdate", timerAnchor.OnUpdate)

local events = { "HPW_ZONE_STATE_CHANGE" }
local function GenericEventHandler(eventName)
	return function(info1)
		if info1 == 102 or info1 == 103 then
			local zoneInfo = X2Map:GetZoneStateInfoByZoneId(info1)
			if zoneInfo.conflictState == 5 then
				local serverTime = UIParent:GetServerTimeTable()
				local now = serverMinutesSinceMidnight(serverTime)
				local name = (info1 == 102) and dynamicEventsName[locale].aegis or dynamicEventsName[locale].whalesong
				local startIn = 15
				local duration = 15
				local endTime = now + startIn + duration
				for _, e in ipairs(dynamicEvents) do
					if e.name == name and now < e.endTime then
						return
					end
				end
				table.insert(dynamicEvents, {
					name = name,
					minutes = startIn,
					duration = duration,
					isServerEvent = false,
					endTime = endTime,
				})
			end
		end
	end
end
for _, event in ipairs(events) do
	UIParent:SetEventHandler(UIEVENT_TYPE[event], GenericEventHandler(event))
end

--moreEntries:SetWidth(25)
