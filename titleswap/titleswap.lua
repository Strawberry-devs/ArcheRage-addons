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
------------- Thanks to Pinkl and Raikiri ---------------
ADDON:ImportObject(OBJECT_TYPE.TEXT_STYLE)
ADDON:ImportObject(OBJECT_TYPE.BUTTON)
ADDON:ImportObject(OBJECT_TYPE.DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.NINE_PART_DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.COLOR_DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.WINDOW)
ADDON:ImportObject(OBJECT_TYPE.LABEL)
ADDON:ImportObject(OBJECT_TYPE.ICON_DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.IMAGE_DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.EDITBOX)
ADDON:ImportObject(OBJECT_TYPE.X2_EDITBOX)

ADDON:ImportAPI(API_TYPE.OPTION.id)
ADDON:ImportAPI(API_TYPE.CHAT.id)
ADDON:ImportAPI(API_TYPE.ACHIEVEMENT.id)
ADDON:ImportAPI(API_TYPE.UNIT.id)
ADDON:ImportAPI(API_TYPE.LOCALE.id)
ADDON:ImportAPI(API_TYPE.PLAYER.id)

local titles = {}
local titlesFile = "titles.lua"
local titleMetadata = TitleSwapTitleData or {}
local titleWidgets = {}
local settingsRows = {}
local settingsWindow = nil
local selectedTitleId = nil
local refreshingSettings = false
local pendingTitleId = nil
local titleCheckElapsed = 0
local ICON_SETTING_SAVE_KEY = "titleswap_show_icons"

local MAIN_ICON_SIZE = 20
local MAIN_ROW_HEIGHT = 24
local MAIN_BUTTON_HEIGHT = 27
local MAIN_WINDOW_WIDTH = 100
local MAIN_TOP_PADDING = 10
local MAIN_BOTTOM_PADDING = 10
local SETTINGS_WIDTH = 470
local SETTINGS_ROW_HEIGHT = 32

local COLOR_NORMAL = { 0.2, 0.2, 0.2, 1 }
local COLOR_ACTIVE = { 0.348, 0.609, 0.370, 1 }
local COLOR_FAILED = { 0.9, 0.2, 0.2, 1 }
local COLOR_SELECTED = { 1, 1, 1, 1 }
local UNKNOWN_ICON = "icons/icon_unknown_item.dds"

local function LoadShowIcons()
	local saved = ADDON:LoadData(ICON_SETTING_SAVE_KEY)
	if saved ~= nil and saved.enabled ~= nil then
		return saved.enabled == true
	end
	return true
end

local function SaveShowIcons(enabled)
	ADDON:ClearData(ICON_SETTING_SAVE_KEY)
	ADDON:SaveData(ICON_SETTING_SAVE_KEY, { enabled = enabled == true })
end

local showIcons = LoadShowIcons()

local titleListWindow = CreateEmptyWindow("titleListWindow", "UIParent")
titleListWindow:SetExtent(MAIN_WINDOW_WIDTH, 35)
titleListWindow:EnableDrag(true)
titleListWindow:Show(true)

local background = titleListWindow:CreateColorDrawable(0, 0, 0, 0.5, "background")
background:AddAnchor("TOPLEFT", titleListWindow, 0, 0)
background:AddAnchor("BOTTOMRIGHT", titleListWindow, 0, 0)

local function GetUIScaleFactor()
	return UIParent:GetUIScale() or 1.0
end

local filePath = "TitleWindowPos.txt"
local function SaveWindowPosition(x, y)
	local file = io.open(filePath, "w")
	if file == nil then
		return
	end
	local uiScale = GetUIScaleFactor()
	file:write(string.format("%d,%d", math.floor(x / uiScale), math.floor(y / uiScale)))
	file:close()
end

local function LoadSavedPosition()
	local file = io.open(filePath, "r")
	if file == nil then
		return 0, 0
	end
	local line = file:read("*line") or ""
	file:close()
	local x, y = line:match("(-?%d+),(-?%d+)")
	return tonumber(x) or 0, tonumber(y) or 0
end

local savedWindowX, savedWindowY = LoadSavedPosition()
titleListWindow:AddAnchor("TOPLEFT", "UIParent", savedWindowX, savedWindowY)

local function LuaUnescape(value)
	value = value:gsub("\\n", "\n")
	value = value:gsub('\\"', '"')
	return value:gsub("\\\\", "\\")
end

local function LuaEscape(value)
	value = tostring(value or "")
	value = value:gsub("\\", "\\\\")
	value = value:gsub('"', '\\"')
	return value:gsub("[\r\n]", " ")
end

local function GetTitleMetadata(titleId)
	return titleMetadata[tonumber(titleId)]
end

local function GetTitleName(titleId)
	local metadata = GetTitleMetadata(titleId)
	if metadata ~= nil and metadata.name ~= nil and metadata.name ~= "" then
		return metadata.name
	end
	return "Title " .. tostring(titleId)
end

local function GetTitleIcon(titleId, savedIcon)
	local metadata = GetTitleMetadata(titleId)
	if metadata ~= nil and metadata.icon ~= nil and metadata.icon ~= "" and metadata.icon ~= UNKNOWN_ICON then
		return metadata.icon
	end
	if savedIcon ~= nil and savedIcon ~= "" then
		return savedIcon
	end
	if metadata ~= nil and metadata.icon ~= nil and metadata.icon ~= "" then
		return metadata.icon
	end
	return UNKNOWN_ICON
end

local function GetCurrentEffectTitleId()
	local currentTitle = X2Player:GetEffectAppellation()
	if currentTitle == nil or currentTitle[1] == nil then
		return "0"
	end
	return tostring(currentTitle[1])
end

local function GetSortedTitleIds()
	local ids = {}
	for id in pairs(titles) do
		table.insert(ids, id)
	end
	table.sort(ids, function(left, right)
		local leftOrder = tonumber(titles[left].order) or 999999
		local rightOrder = tonumber(titles[right].order) or 999999
		if leftOrder == rightOrder then
			return (tonumber(left) or 0) < (tonumber(right) or 0)
		end
		return leftOrder < rightOrder
	end)
	return ids
end

local function GetNextTitleOrder()
	local highest = 0
	for _, data in pairs(titles) do
		highest = math.max(highest, tonumber(data.order) or 0)
	end
	return highest + 1
end

local function initializeTitles()
	local file = io.open(titlesFile, "r")
	if file == nil then
		return
	end
	titles = {}
	local fileOrder = 0
	for line in file:lines() do
		local id, name, path, order = line:match(
			'%["(%d+)"%]%s*=%s*{name%s*=%s*"(.-)",%s*icon%s*=%s*"(.-)",%s*order%s*=%s*(%d+)}'
		)
		if id == nil then
			id, name, path = line:match('%["(%d+)"%]%s*=%s*{name%s*=%s*"(.-)",%s*icon%s*=%s*"(.-)"}')
		end
		if id ~= nil and name ~= nil and path ~= nil then
			fileOrder = fileOrder + 1
			titles[id] = {
				name = LuaUnescape(name),
				icon = LuaUnescape(path),
				order = tonumber(order) or fileOrder,
			}
		end
	end
	file:close()
end

local function WriteTitlesFile()
	local file = io.open(titlesFile, "w")
	if file == nil then
		aaprint("Failed to save TitleSwap titles.")
		return false
	end
	file:write("titles = {\n")
	local ids = GetSortedTitleIds()
	for _, id in ipairs(ids) do
		local data = titles[id]
		file:write(string.format(
			'    ["%s"] = {name = "%s", icon = "%s", order = %d},\n',
			id,
			LuaEscape(data.name),
			LuaEscape(data.icon),
			tonumber(data.order) or 0
		))
	end
	file:write("}\n")
	file:close()
	return true
end

local function SetButtonState(button, color)
	button:SetStyle("text_default")
	SetButtonFontOneColor(button, color)
	button:SetExtent(showIcons and 63 or 80, MAIN_BUTTON_HEIGHT)
end

local function RefreshMainButtonColors()
	local currentTitleId = GetCurrentEffectTitleId()
	for _, row in ipairs(titleWidgets) do
		if row.titleId ~= nil then
			SetButtonState(row.button, row.titleId == currentTitleId and COLOR_ACTIVE or COLOR_NORMAL)
		end
	end
end

local function FindMainRow(titleId)
	for _, row in ipairs(titleWidgets) do
		if row.titleId == titleId then
			return row
		end
	end
	return nil
end

local function StartTitleSwap(titleId)
	local showingTitle = X2Player:GetShowingAppellation()
	local showingTitleId = 0
	if showingTitle ~= nil and showingTitle[1] ~= nil then
		showingTitleId = tonumber(showingTitle[1]) or 0
	end
	X2Player:ChangeAppellation(showingTitleId, tonumber(titleId))
	pendingTitleId = tostring(titleId)
	titleCheckElapsed = 0
	RefreshMainButtonColors()
	local requestedRow = FindMainRow(pendingTitleId)
	if requestedRow ~= nil then
		SetButtonState(requestedRow.button, COLOR_ACTIVE)
	end
end

local function EnsureMainRow(index)
	if titleWidgets[index] ~= nil then
		return titleWidgets[index]
	end
	local row = {}
	local y = MAIN_TOP_PADDING + ((index - 1) * MAIN_ROW_HEIGHT)
	row.icon = titleListWindow:CreateImageDrawable(UNKNOWN_ICON, "artwork")
	row.icon:AddAnchor("TOPLEFT", titleListWindow, 9, y + 3)
	row.icon:SetExtent(MAIN_ICON_SIZE, MAIN_ICON_SIZE)

	row.button = titleListWindow:CreateChildWidget("button", "titleButton" .. index, index, true)
	row.button:AddAnchor("TOPLEFT", titleListWindow, 29, y)
	row.button:SetAutoResize(false)
	row.button:SetHandler("OnClick", function(self, arg)
		if arg == "RightButton" or self.titleId == nil then
			return
		end
		StartTitleSwap(self.titleId)
	end)
	titleWidgets[index] = row
	return row
end

local function createTitleList()
	local ids = GetSortedTitleIds()
	for index, id in ipairs(ids) do
		local row = EnsureMainRow(index)
		local data = titles[id]
		local y = MAIN_TOP_PADDING + ((index - 1) * MAIN_ROW_HEIGHT)
		row.titleId = id
		row.button.titleId = id
		row.button:RemoveAllAnchors()
		row.button:AddAnchor("TOPLEFT", titleListWindow, showIcons and 29 or 10, y)
		row.button:SetText(data.name)
		row.button:Show(true)
		if showIcons then
			row.icon:SetTexture(GetTitleIcon(id, data.icon))
			row.icon:Show(true)
		else
			row.icon:Show(false)
		end
	end
	for index = #ids + 1, #titleWidgets do
		local row = titleWidgets[index]
		row.titleId = nil
		row.button.titleId = nil
		row.button:SetText("")
		row.button:Show(false)
		row.icon:Show(false)
	end
	local contentHeight = 0
	if #ids > 0 then
		contentHeight = ((#ids - 1) * MAIN_ROW_HEIGHT) + MAIN_BUTTON_HEIGHT
	end
	titleListWindow:SetExtent(
		MAIN_WINDOW_WIDTH,
		math.max(35, MAIN_TOP_PADDING + contentHeight + MAIN_BOTTOM_PADDING)
	)
	RefreshMainButtonColors()
end

local function saveTitles()
	if WriteTitlesFile() then
		createTitleList()
	end
end

local function saveTitle(titleId, titleName, titleIconPath)
	if titleId == nil or tostring(titleId) == "0" then
		aaprint("No active title to add.")
		return false
	end
	local id = tostring(titleId)
	local existingOrder = titles[id] ~= nil and titles[id].order or nil
	titles[id] = {
		name = titleName ~= nil and titleName ~= "" and titleName or GetTitleName(id),
		icon = GetTitleIcon(id, titleIconPath),
		order = existingOrder or GetNextTitleOrder(),
	}
	selectedTitleId = id
	saveTitles()
	return true
end

local function deleteTitle(titleId, name)
	if titleId ~= nil and titles[tostring(titleId)] ~= nil then
		titles[tostring(titleId)] = nil
		saveTitles()
		return true
	end
	for id, data in pairs(titles) do
		if data.name == name then
			titles[id] = nil
			saveTitles()
			return true
		end
	end
	aaprint("Title not found: " .. tostring(name or titleId or ""))
	return false
end

local function CreateLocalEditBox(parent, id, width)
	local edit = parent:CreateChildWidgetByType(UOT_X2_EDITBOX, id, 0, true)
	edit:SetExtent(width, 26)
	edit:SetInset(5, 5, 5, 5)
	edit:EnableFocus(true)
	edit:UseSelectAllWhenFocused(true)
	edit.style:SetAlign(ALIGN_LEFT)
	edit.style:SetColorByKey("title")
	local bg = edit:CreateDrawable("ui/common/default.dds", "editbox_df", "background")
	bg:AddAnchor("TOPLEFT", edit, 0, 0)
	bg:AddAnchor("BOTTOMRIGHT", edit, 0, 0)
	return edit
end

local RefreshSettingsWindow

local function MoveTitle(titleId, direction)
	local ids = GetSortedTitleIds()
	local currentIndex = nil
	for index, id in ipairs(ids) do
		if id == titleId then
			currentIndex = index
			break
		end
	end
	if currentIndex == nil then
		return
	end
	local targetIndex = currentIndex + direction
	if targetIndex < 1 or targetIndex > #ids then
		return
	end
	local otherId = ids[targetIndex]
	local currentOrder = titles[titleId].order
	titles[titleId].order = titles[otherId].order
	titles[otherId].order = currentOrder
	saveTitles()
	RefreshSettingsWindow()
end

local function EnsureSettingsRow(index)
	if settingsRows[index] ~= nil then
		return settingsRows[index]
	end
	local row = {}
	local y = 62 + ((index - 1) * SETTINGS_ROW_HEIGHT)
	row.icon = settingsWindow:CreateImageDrawable(UNKNOWN_ICON, "artwork")
	row.icon:AddAnchor("TOPLEFT", settingsWindow, 20, y + 2)
	row.icon:SetExtent(24, 24)

	row.titleButton = settingsWindow:CreateChildWidget("button", "titleSettingsSelect" .. index, index, true)
	row.titleButton:AddAnchor("TOPLEFT", settingsWindow, 50, y)
	row.titleButton:SetAutoResize(false)
	row.titleButton:SetExtent(145, 26)
	row.titleButton:SetStyle("text_default")
	row.titleButton.style:SetEllipsis(true)
	row.titleButton:SetHandler("OnClick", function(self, arg)
		if arg ~= "RightButton" and self.titleId ~= nil then
			selectedTitleId = self.titleId
			RefreshSettingsWindow()
		end
	end)
	row.titleButton:SetWidth(145)

	row.moveUpButton = settingsWindow:CreateChildWidget("button", "titleSettingsMoveUp" .. index, index, true)
	row.moveUpButton:AddAnchor("TOPLEFT", settingsWindow, 200, y)
	row.moveUpButton:SetStyle("text_default")
	row.moveUpButton:SetAutoResize(false)
	row.moveUpButton:SetExtent(25, 26)
	row.moveUpButton:SetText("^")
	row.moveUpButton:SetHandler("OnClick", function(self, arg)
		if arg ~= "RightButton" and self.titleId ~= nil then
			MoveTitle(self.titleId, -1)
		end
	end)
	row.moveUpButton:SetWidth(18)

	row.moveDownButton = settingsWindow:CreateChildWidget("button", "titleSettingsMoveDown" .. index, index, true)
	row.moveDownButton:AddAnchor("TOPLEFT", settingsWindow, 220, y)
	row.moveDownButton:SetStyle("text_default")
	row.moveDownButton:SetAutoResize(false)
	row.moveDownButton:SetExtent(25, 26)
	row.moveDownButton:SetText("v")
	row.moveDownButton:SetHandler("OnClick", function(self, arg)
		if arg ~= "RightButton" and self.titleId ~= nil then
			MoveTitle(self.titleId, 1)
		end
	end)
	row.moveDownButton:SetWidth(18)

	row.nicknameEdit = CreateLocalEditBox(settingsWindow, "titleSettingsNickname" .. index, 204)
	row.nicknameEdit:AddAnchor("TOPLEFT", settingsWindow, 246, y)
	row.nicknameEdit:SetMaxTextLength(48)
	row.nicknameEdit:SetHandler("OnTextChanged", function(self)
		if not refreshingSettings and self.titleId ~= nil and titles[self.titleId] ~= nil then
			titles[self.titleId].name = self:GetText()
		end
	end)
	row.nicknameEdit:SetHandler("OnEnterPressed", function(self)
		if self.titleId == nil or titles[self.titleId] == nil then
			return
		end
		if self:GetText() == "" then
			titles[self.titleId].name = GetTitleName(self.titleId)
		end
		self:ClearFocus()
		saveTitles()
		RefreshSettingsWindow()
	end)
	settingsRows[index] = row
	return row
end

local function CreateSettingsWindow()
	if settingsWindow ~= nil then
		return
	end
	settingsWindow = CreateEmptyWindow("titleSwapSettingsWindow", "UIParent")
	settingsWindow:SetExtent(SETTINGS_WIDTH, 180)
	settingsWindow:AddAnchor("CENTER", "UIParent", 0, 0)
	settingsWindow:SetCloseOnEscape(true)
	settingsWindow:EnableDrag(true)
	settingsWindow:Show(false)

	local settingsBackground = settingsWindow:CreateDrawable("ui/common/default.dds", "main_bg", "background")
	settingsBackground:AddAnchor("TOPLEFT", settingsWindow, -5, -5)
	settingsBackground:AddAnchor("BOTTOMRIGHT", settingsWindow, 5, 5)

	local settingsTitle = settingsWindow:CreateChildWidget("label", "titleSettingsWindowTitle", 0, true)
	settingsTitle:AddAnchor("TOP", settingsWindow, 0, 11)
	settingsTitle:SetExtent(SETTINGS_WIDTH - 70, 24)
	settingsTitle:SetText("TitleSwap Settings")
	settingsTitle.style:SetAlign(ALIGN_CENTER)
	settingsTitle.style:SetFontSize(16)
	settingsTitle.style:SetColorByKey("title")

	local closeButton = settingsWindow:CreateChildWidget("button", "titleSettingsClose", 0, true)
	closeButton:AddAnchor("TOPRIGHT", settingsWindow, 3, -3)
	closeButton:SetStyle("btn_close_default")
	closeButton:SetHandler("OnClick", function(_, arg)
		if arg == "RightButton" then
			return
		end
		saveTitles()
		settingsWindow:Show(false)
	end)

	settingsWindow:SetHandler("OnDragStart", function(self)
		self:StartMoving()
		self.moving = true
	end)
	settingsWindow:SetHandler("OnDragStop", function(self)
		self:StopMovingOrSizing()
		self.moving = false
	end)

	local titleHeader = settingsWindow:CreateChildWidget("label", "titleSettingsTitleHeader", 0, true)
	titleHeader:AddAnchor("TOPLEFT", settingsWindow, 50, 42)
	titleHeader:SetExtent(180, 20)
	titleHeader:SetText("Saved title")
	titleHeader.style:SetAlign(ALIGN_LEFT)
	titleHeader.style:SetColorByKey("default")

	local nicknameHeader = settingsWindow:CreateChildWidget("label", "titleSettingsNicknameHeader", 0, true)
	nicknameHeader:AddAnchor("TOPLEFT", settingsWindow, 246, 42)
	nicknameHeader:SetExtent(204, 20)
	nicknameHeader:SetText("Nickname")
	nicknameHeader.style:SetAlign(ALIGN_LEFT)
	nicknameHeader.style:SetColorByKey("default")

	settingsWindow.addButton = settingsWindow:CreateChildWidget("button", "titleSettingsAdd", 0, true)
	settingsWindow.addButton:SetStyle("text_default")
	settingsWindow.addButton:SetAutoResize(false)
	settingsWindow.addButton:SetExtent(80, 28)
	settingsWindow.addButton:SetText("Add")
	settingsWindow.addButton:SetHandler("OnClick", function(_, arg)
		if arg == "RightButton" then
			return
		end
		local currentTitle = X2Player:GetEffectAppellation()
		if currentTitle == nil or currentTitle[1] == nil or tonumber(currentTitle[1]) == 0 then
			aaprint("No active title to add.")
			return
		end
		local iconPath = nil
		if currentTitle[6] ~= nil then
			iconPath = currentTitle[6].path
		end
		if saveTitle(currentTitle[1], currentTitle[2], iconPath) then
			RefreshSettingsWindow()
		end
	end)

	settingsWindow.removeButton = settingsWindow:CreateChildWidget("button", "titleSettingsRemove", 0, true)
	settingsWindow.removeButton:SetStyle("text_default")
	settingsWindow.removeButton:SetAutoResize(false)
	settingsWindow.removeButton:SetExtent(32, 28)
	settingsWindow.removeButton:SetText("X")
	settingsWindow.removeButton:SetHandler("OnClick", function(_, arg)
		if arg == "RightButton" or selectedTitleId == nil then
			return
		end
		if deleteTitle(selectedTitleId) then
			selectedTitleId = nil
			RefreshSettingsWindow()
		end
	end)

	settingsWindow.showIconsButton = settingsWindow:CreateChildWidget("button", "titleSettingsShowIcons", 0, true)
	settingsWindow.showIconsButton:SetStyle("text_default")
	settingsWindow.showIconsButton:SetAutoResize(false)
	settingsWindow.showIconsButton:SetExtent(95, 28)
	settingsWindow.showIconsButton:SetText("Show icons")
	settingsWindow.showIconsButton:SetHandler("OnClick", function(_, arg)
		if arg == "RightButton" then
			return
		end
		showIcons = not showIcons
		SaveShowIcons(showIcons)
		createTitleList()
		RefreshSettingsWindow()
	end)
	settingsWindow.showIconsButton:SetWidth(95)

	function settingsWindow:OnClose()
		saveTitles()
	end
end

RefreshSettingsWindow = function()
	CreateSettingsWindow()
	local ids = GetSortedTitleIds()
	refreshingSettings = true
	for index, id in ipairs(ids) do
		local row = EnsureSettingsRow(index)
		local data = titles[id]
		row.titleId = id
		row.titleButton.titleId = id
		row.moveUpButton.titleId = id
		row.moveDownButton.titleId = id
		row.nicknameEdit.titleId = id
		row.icon:SetTexture(GetTitleIcon(id, data.icon))
		row.icon:Show(true)
		row.titleButton:SetText(GetTitleName(id))
		row.titleButton:SetWidth(145)
		SetButtonFontOneColor(row.titleButton, id == selectedTitleId and COLOR_SELECTED or COLOR_NORMAL)
		row.titleButton:Show(true)
		row.moveUpButton:Show(true)
		row.moveDownButton:Show(true)
		row.nicknameEdit:SetText(data.name)
		row.nicknameEdit:Show(true)
	end
	for index = #ids + 1, #settingsRows do
		local row = settingsRows[index]
		row.titleId = nil
		row.titleButton.titleId = nil
		row.moveUpButton.titleId = nil
		row.moveDownButton.titleId = nil
		row.nicknameEdit.titleId = nil
		row.icon:Show(false)
		row.titleButton:Show(false)
		row.moveUpButton:Show(false)
		row.moveDownButton:Show(false)
		row.nicknameEdit:Show(false)
	end
	refreshingSettings = false

	local footerY = 72 + (#ids * SETTINGS_ROW_HEIGHT)
	settingsWindow.addButton:RemoveAllAnchors()
	settingsWindow.addButton:AddAnchor("TOPLEFT", settingsWindow, 20, footerY)
	settingsWindow.removeButton:RemoveAllAnchors()
	settingsWindow.removeButton:AddAnchor("LEFT", settingsWindow.addButton, "RIGHT", 6, 0)
	settingsWindow.showIconsButton:RemoveAllAnchors()
	settingsWindow.showIconsButton:AddAnchor("TOPRIGHT", settingsWindow, -20, footerY)
	SetButtonFontOneColor(settingsWindow.showIconsButton, showIcons and COLOR_ACTIVE or COLOR_NORMAL)
	settingsWindow:SetExtent(SETTINGS_WIDTH, math.max(145, footerY + 48))
end

local function ToggleSettingsWindow()
	CreateSettingsWindow()
	if settingsWindow:IsVisible() then
		saveTitles()
		settingsWindow:Show(false)
	else
		RefreshSettingsWindow()
		settingsWindow:Show(true)
	end
end

local settingsButton = titleListWindow:CreateChildWidget("button", "titleSwapSettingsButton", 0, true)
settingsButton:AddAnchor("TOPRIGHT", titleListWindow, 0, -25)
settingsButton:SetStyle("text_default")
settingsButton:SetExtent(35, 25)
settingsButton:SetText("?")
settingsButton:SetHandler("OnClick", ToggleSettingsWindow)
settingsButton:SetWidth(25)

function titleListWindow:OnUpdate(dt)
	if pendingTitleId == nil then
		return
	end
	titleCheckElapsed = titleCheckElapsed + dt
	if titleCheckElapsed < 500 then
		return
	end
	local requestedTitleId = pendingTitleId
	pendingTitleId = nil
	titleCheckElapsed = 0
	local activeTitleId = GetCurrentEffectTitleId()
	RefreshMainButtonColors()
	if activeTitleId ~= requestedTitleId then
		local failedRow = FindMainRow(requestedTitleId)
		if failedRow ~= nil then
			SetButtonState(failedRow.button, COLOR_FAILED)
		end
		aaprint("Title swap failed.")
	end
end
titleListWindow:SetHandler("OnUpdate", titleListWindow.OnUpdate)

local chatEvents = {
	CHAT_MESSAGE = function(_, _, name, message)
		if name ~= X2Unit:UnitName("player") then
			return
		end
		local command = string.match(message, "/%w+")
		local nickname = string.match(message, "/%w+%s+(.+)")
		if command == "/addtitle" then
			local currentTitle = X2Player:GetEffectAppellation()
			if currentTitle == nil then
				return
			end
			local iconPath = currentTitle[6] ~= nil and currentTitle[6].path or nil
			saveTitle(currentTitle[1], nickname or currentTitle[2], iconPath)
			if settingsWindow ~= nil and settingsWindow:IsVisible() then
				RefreshSettingsWindow()
			end
		elseif command == "/removetitle" then
			local currentTitle = X2Player:GetEffectAppellation()
			local currentId = currentTitle ~= nil and currentTitle[1] or nil
			local currentName = currentTitle ~= nil and currentTitle[2] or nil
			deleteTitle(nickname == nil and currentId or nil, nickname or currentName)
			if settingsWindow ~= nil and settingsWindow:IsVisible() then
				RefreshSettingsWindow()
			end
		end
	end,
}

local chatEventListener = CreateEmptyWindow("titleSwapChatEventListener", "UIParent")
chatEventListener:Show(false)
chatEventListener:SetHandler("OnEvent", function(_, event, ...)
	if chatEvents[event] ~= nil then
		chatEvents[event](...)
	end
end)
for event in pairs(chatEvents) do
	chatEventListener:RegisterEvent(event)
end

function titleListWindow:OnDragStart()
	self:StartMoving()
	self.moving = true
end
titleListWindow:SetHandler("OnDragStart", titleListWindow.OnDragStart)

function titleListWindow:OnDragStop()
	self:StopMovingOrSizing()
	self.moving = false
	local offsetX, offsetY = self:GetOffset()
	local uiScale = GetUIScaleFactor()
	SaveWindowPosition(offsetX * uiScale, offsetY * uiScale)
end
titleListWindow:SetHandler("OnDragStop", titleListWindow.OnDragStop)

aaprint("Initializing Titleswap.")
initializeTitles()
createTitleList()
aaprint("Titleswap loaded successfully.")
