-------------- Original Author: Strawberry --------------
----------------- Discord: exec_noir --------------------
-------------- Thanks to MikeTheShadow ------------------
if API_TYPE == nil then
	ADDON:ImportAPI(8)
	X2Chat:DispatchChatMessage(
		CMF_SYSTEM,
		"Globals folder not found. Please install it at https://github.com/Schiz-n/ArcheRage-addons/tree/master/globals"
	)
	return
end
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
ADDON:ImportAPI(API_TYPE.EQUIPMENT.id)
ADDON:ImportAPI(API_TYPE.BAG.id)

-- actual gear box
local gears = {}
local gearsFile = "gears.lua"
local GEAR_SETTINGS_SAVE_KEY = "gearswap_settings_v2"
local UNKNOWN_ICON = "ui/icon/icon_unknown_item.dds"
local MAIN_ICON_SIZE = 20
local MAIN_ROW_HEIGHT = 25
local MAIN_BUTTON_HEIGHT = 30
local MAIN_WINDOW_WIDTH = 100
local MAIN_TOP_PADDING = 10
local MAIN_BOTTOM_PADDING = 10
local SETTINGS_WIDTH = 470
local SETTINGS_ROW_HEIGHT = 32
local CONTENT_ROW_HEIGHT = 25
local CONTENT_COLUMNS = 2
local COLOR_NORMAL = { 0.2, 0.2, 0.2, 1 }
local COLOR_ACTIVE = { 0.348, 0.609, 0.370, 1 }
local COLOR_SELECTED = { 1, 1, 1, 1 }
local GEAR_SLOT_NAMES = {
	"Head",
	"Chest",
	"Waist",
	"Wrists",
	"Hands",
	"Cloak",
	"Legs",
	"Feet",
	"Undergarments",
	"Necklace",
	"Earring 1",
	"Earring 2",
	"Ring 1",
	"Ring 2",
	"Main Hand",
	"Off Hand",
	"Ranged",
	"Instrument",
	"Costume",
}
local GEAR_SLOT_IDS = { 1, 3, 4, 8, 6, 9, 5, 7, 15, 2, 10, 11, 12, 13, 16, 17, 18, 19, 28 }
local GEAR_SLOT_NAMES_BY_ID = {}
for index, slotId in ipairs(GEAR_SLOT_IDS) do
	GEAR_SLOT_NAMES_BY_ID[slotId] = GEAR_SLOT_NAMES[index]
end

local gearSettings = {
	showIcons = true,
	showContents = false,
	sets = {},
}
local settingsWindow = nil
local settingsRows = {}
local contentRows = {}
local selectedGearName = nil
local itemIconsByName = GearSwapItemIcons or {}
local addSetWindow = nil
local customIconWindow = nil
local customIconRows = {}
local customIconEntries = nil
local customIconFiltered = {}
local customIconPage = 1
local CUSTOM_ICON_ROWS = 12

local function LoadGearSettings()
	local saved = ADDON:LoadData(GEAR_SETTINGS_SAVE_KEY)
	if type(saved) == "table" then
		gearSettings.showIcons = saved.showIcons ~= false
		gearSettings.showContents = saved.showContents == true
		gearSettings.sets = type(saved.sets) == "table" and saved.sets or {}
	end
end

local function SaveGearSettings()
	ADDON:ClearData(GEAR_SETTINGS_SAVE_KEY)
	ADDON:SaveData(GEAR_SETTINGS_SAVE_KEY, gearSettings)
end

local function ToClientIconPath(iconPath)
	local path = tostring(iconPath or ""):gsub("%.png$", "")
	if path == "" then
		return UNKNOWN_ICON
	end
	return path:gsub("^icons/", "ui/icon/")
end

local function GetItemIcon(itemName, fallbackIcon)
	local normalizedName = tostring(itemName or ""):gsub("^%+%d+%s+", "")
	local icon = itemIconsByName[normalizedName] or itemIconsByName[itemName] or fallbackIcon
	return ToClientIconPath(icon)
end

local function SetIconTexture(drawable, iconPath)
	if drawable == nil then
		return
	end
	if drawable.SetTexture ~= nil then
		drawable:SetTexture(ToClientIconPath(iconPath))
	end
	if drawable.SetCoords ~= nil then
		drawable:SetCoords(0, 0, 48, 48)
	end
end

local gearListWindow = CreateEmptyWindow("gearListWindow", "UIParent")
gearListWindow:SetExtent(0, 0)
--gearListWindow:AddAnchor("RIGHT", "UIParent", -100, -200)
gearListWindow:EnableDrag(true)
gearListWindow:Show(true)
local function GetUIScaleFactor()
	return UIParent:GetUIScale() or 1.0
end

local gearWidgets = {}

local filePath = "GearWindowPos.txt"
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
local savedWindowX, savedWindowY = LoadSavedPosition()
gearListWindow:AddAnchor("TOPLEFT", "UIParent", tonumber(savedWindowX), tonumber(savedWindowY))

local background = gearListWindow:CreateColorDrawable(0, 0, 0, 0.5, "background")
background:AddAnchor("TOPLEFT", gearListWindow, 0, 0)
background:AddAnchor("BOTTOMRIGHT", gearListWindow, 0, 0)

--fullSetToEquip is the full set
local fullSetToEquip = {}
--gearToEquip shrinks as you equip items
local gearToEquip = {}

--gear equip processor
local delayCounter = 0
local imBusy = false
function gearListWindow:OnUpdate(dt)
	if delayCounter > 200 and imBusy == false then
		--X2Chat:DispatchChatMessage(CMF_SYSTEM, dump(gearToEquip))
		imBusy = true
		if #gearToEquip > 0 then
			--X2Chat:DispatchChatMessage(CMF_SYSTEM, "Equipping: " .. dump(gearToEquip[1]))
			local itemToEquip = table.remove(gearToEquip, 1)
			--X2Chat:DispatchChatMessage(CMF_SYSTEM, "Equipping: " .. dump(itemToEquip))
			X2Bag:EquipBagItem(itemToEquip.posInBag, itemToEquip.alternative)
			--X2Chat:DispatchChatMessage(CMF_SYSTEM, "Equipping: " .. dump(itemToEquip))
		end
		delayCounter = 0
		imBusy = false
	end
	delayCounter = delayCounter + dt
end
gearListWindow:SetHandler("OnUpdate", gearListWindow.OnUpdate)

--welcome to race condition central

local function isItemInSet(item)
	--X2Chat:DispatchChatMessage(CMF_SYSTEM, dump(fullSetToEquip))
	for _, setItem in ipairs(fullSetToEquip) do
		if item.name == setItem.name then --and item.grade == setItem.grade then
			return true, setItem.alternative or false
		end
	end
	return false, false
end

local function markSecondAsAlternative(setIndex)
	local equippedIndex
	--setIndex does not correlate with real equipped gear
	--this fixes that, under 14 is earring & ring, above 14 is weapon
	if setIndex > 14 then
		equippedIndex = setIndex + 1
	else
		equippedIndex = setIndex - 1
	end
	local nameToFind = fullSetToEquip[setIndex].name
	if nameToFind ~= fullSetToEquip[setIndex + 1].name then
		return
	end

	local itemInMainSlot = X2Equipment:GetEquippedItemTooltipInfo(equippedIndex, true)
	local mainSlotItemName = itemInMainSlot.name
	local forceAlt = false
	if mainSlotItemName == nameToFind then
		forceAlt = true
	end

	local foundOnce = false
	for _, item in ipairs(gearToEquip) do
		if item.name == nameToFind then
			if not foundOnce then
				foundOnce = true
				if forceAlt == true then
					item.alternative = true
					return
				end
			else
				item.alternative = true
				return
			end
		end
	end
end

local function getGearFromInventory()
	for posInBag = 1, 150 do
		local item = X2Bag:GetBagItemInfo(1, posInBag)
		if item then
			local found, alternative = isItemInSet(item)
			if found then
				--X2Chat:DispatchChatMessage(CMF_SYSTEM, "Found at " .. tostring(posInBag))
				table.insert(
					gearToEquip,
					{ posInBag = posInBag, name = item.name, grade = item.grade, alternative = alternative }
				)
			end
		end
	end
	markSecondAsAlternative(11) --earring
	markSecondAsAlternative(13) --ring
	markSecondAsAlternative(15) --weapon
end

local function equipGear(setName)
	-- gearToEquip = get set from file
	fullSetToEquip = gears[setName]
	gearToEquip = {}
	getGearFromInventory()
	return true
end
local function getEquippedGearArray()
	local items = {}
	for _, i in ipairs(GEAR_SLOT_IDS) do
		local item = X2Equipment:GetEquippedItemTooltipInfo(i, true)
		if item ~= nil then
			local new_item = { name = item.name, grade = item.itemGrade, slot = i, icon = item.icon }
			if i == 13 or i == 11 or i == 17 then
				new_item.alternative = true
			else
				new_item.alternative = false
			end
			table.insert(items, new_item)
		end
	end
	return items
end

local function saveGearsToFile()
	local file = io.open(gearsFile, "w")
	if not file then
		X2Chat:DispatchChatMessage(CMF_SYSTEM, "Failed to open gear file for writing.")
		return
	end

	file:write("return {\n")
	for setName, gearArray in pairs(gears) do
		file:write(string.format('  ["%s"] = {\n', setName))
		for _, item in ipairs(gearArray) do
			local slotText = item.slot ~= nil and string.format(", slot = %d", item.slot) or ""
			local iconText = item.icon ~= nil and string.format(', icon = "%s"', item.icon) or ""
			file:write(string.format(
				'    {name = "%s", grade = %d, alternative = %s%s%s},\n',
				item.name,
				item.grade,
				item.alternative and "true" or "false",
				slotText,
				iconText
			))
		end
		file:write("  },\n")
	end
	file:write("}\n")
	file:close()
	--X2Chat:DispatchChatMessage(CMF_SYSTEM, "Gear sets saved.")
end

local function loadGearSetsFromFile()
	local file = io.open(gearsFile, "r")
	if file then
		local content = file:read("*a")
		file:close()

		local chunk, err = loadstring(content)
		if not chunk then
			X2Chat:DispatchChatMessage(CMF_SYSTEM, "Error loading gear file: " .. tostring(err))
			gears = {}
			return
		end

		local ok, result = pcall(chunk)
		if ok and type(result) == "table" then
			gears = result
			X2Chat:DispatchChatMessage(CMF_SYSTEM, "Gear sets loaded.")
		else
			gears = {}
			X2Chat:DispatchChatMessage(CMF_SYSTEM, "Failed to load gear sets.")
		end
	else
		gears = {}
		X2Chat:DispatchChatMessage(CMF_SYSTEM, "Gear file not found, initializing empty list.")
	end
end

local function GetHighestGearOrder()
	local highest = 0
	for _, data in pairs(gearSettings.sets) do
		highest = math.max(highest, tonumber(data.order) or 0)
	end
	return highest
end

local function SyncGearSettings()
	for setName in pairs(gearSettings.sets) do
		if gears[setName] == nil then
			gearSettings.sets[setName] = nil
		end
	end
	local missing = {}
	for setName in pairs(gears) do
		if type(gearSettings.sets[setName]) ~= "table" then
			table.insert(missing, setName)
		end
	end
	table.sort(missing)
	local nextOrder = GetHighestGearOrder() + 1
	for _, setName in ipairs(missing) do
		gearSettings.sets[setName] = { order = nextOrder }
		nextOrder = nextOrder + 1
	end
end

local function GetOrderedGearNames()
	local names = {}
	for setName in pairs(gears) do
		table.insert(names, setName)
	end
	table.sort(names, function(left, right)
		local leftSettings = gearSettings.sets[left] or {}
		local rightSettings = gearSettings.sets[right] or {}
		local leftOrder = tonumber(leftSettings.order) or 999999
		local rightOrder = tonumber(rightSettings.order) or 999999
		if leftOrder == rightOrder then
			return string.lower(left) < string.lower(right)
		end
		return leftOrder < rightOrder
	end)
	return names
end

local function GearContainsItem(gearArray, itemName)
	if itemName == nil then
		return false
	end
	for _, item in ipairs(gearArray or {}) do
		if item.name == itemName then
			return true
		end
	end
	return false
end

local function GetGearIconItem(setName)
	local gearArray = gears[setName] or {}
	local setSettings = gearSettings.sets[setName] or {}
	if GearContainsItem(gearArray, setSettings.iconName) then
		return setSettings.iconName
	end
	for _, item in ipairs(gearArray) do
		if tonumber(item.slot) == 16 then
			return item.name
		end
	end
	if gearArray[15] ~= nil then
		return gearArray[15].name
	end
	for _, item in ipairs(gearArray) do
		if GetItemIcon(item.name) ~= UNKNOWN_ICON then
			return item.name
		end
	end
	return gearArray[1] ~= nil and gearArray[1].name or nil
end

local function GetGearIcon(setName)
	local setSettings = gearSettings.sets[setName] or {}
	if setSettings.customIcon ~= nil and setSettings.customIcon ~= "" then
		return ToClientIconPath(setSettings.customIcon)
	end
	local itemName = GetGearIconItem(setName)
	for _, item in ipairs(gears[setName] or {}) do
		if item.name == itemName then
			return GetItemIcon(itemName, item.icon)
		end
	end
	return GetItemIcon(itemName)
end

local function IsGearItemCurrentlyEquipped(item, itemIndex, currentGear)
	local savedSlot = tonumber(item.slot) or GEAR_SLOT_IDS[itemIndex]
	for _, equippedItem in ipairs(currentGear or {}) do
		if tonumber(equippedItem.slot) == savedSlot and equippedItem.name == item.name then
			return true
		end
	end
	return false
end

local function getSortedNames(gear)
	local names = {}
	for _, item in ipairs(gear) do
		table.insert(names, item.name)
	end
	table.sort(names)
	return names
end

local function isGearNameEqual(setA, setB)
	local aNames = getSortedNames(setA)
	local bNames = getSortedNames(setB)

	if #aNames ~= #bNames then
		return false
	end
	for i = 1, #aNames do
		if aNames[i] ~= bNames[i] then
			return false
		end
	end
	return true
end

local function SetGearButtonState(button, color)
	button:SetStyle("text_default")
	SetButtonFontOneColor(button, color)
	button:SetExtent(gearSettings.showIcons and 63 or 80, MAIN_BUTTON_HEIGHT)
end

local function EnsureGearRow(index)
	if gearWidgets[index] ~= nil then
		return gearWidgets[index]
	end
	local row = {}
	local y = MAIN_TOP_PADDING + ((index - 1) * MAIN_ROW_HEIGHT)
	row.icon = gearListWindow:CreateImageDrawable(UNKNOWN_ICON, "artwork")
	row.icon:AddAnchor("TOPLEFT", gearListWindow, 9, y + 5)
	row.icon:SetExtent(MAIN_ICON_SIZE, MAIN_ICON_SIZE)

	row.button = gearListWindow:CreateChildWidget("button", "gearButton" .. index, index, true)
	row.button:AddAnchor("TOPLEFT", gearListWindow, 29, y)
	row.button:SetAutoResize(false)
	row.button.style:SetEllipsis(true)
	row.button:SetHandler("OnClick", function(self, arg)
		if arg == "RightButton" or self.gearName == nil then
			return
		end
		if equipGear(self.gearName) then
			for _, otherRow in ipairs(gearWidgets) do
				if otherRow.gearName ~= nil then
					SetGearButtonState(otherRow.button, otherRow == row and COLOR_ACTIVE or COLOR_NORMAL)
				end
			end
		end
	end)
	gearWidgets[index] = row
	return row
end

local function createGearList()
	local names = GetOrderedGearNames()
	local currentGear = getEquippedGearArray()
	for index, setName in ipairs(names) do
		local row = EnsureGearRow(index)
		local y = MAIN_TOP_PADDING + ((index - 1) * MAIN_ROW_HEIGHT)
		row.gearName = setName
		row.button.gearName = setName
		row.button:RemoveAllAnchors()
		row.button:AddAnchor("TOPLEFT", gearListWindow, gearSettings.showIcons and 29 or 10, y)
		row.button:SetText(setName)
		row.button:Show(true)
		if gearSettings.showIcons then
			SetIconTexture(row.icon, GetGearIcon(setName))
			row.icon:Show(true)
		else
			row.icon:Show(false)
		end
		SetGearButtonState(row.button, isGearNameEqual(currentGear, gears[setName]) and COLOR_ACTIVE or COLOR_NORMAL)
	end
	for index = #names + 1, #gearWidgets do
		local row = gearWidgets[index]
		row.gearName = nil
		row.button.gearName = nil
		row.button:SetText("")
		row.button:Show(false)
		row.icon:Show(false)
	end
	local contentHeight = 0
	if #names > 0 then
		contentHeight = ((#names - 1) * MAIN_ROW_HEIGHT) + MAIN_BUTTON_HEIGHT
	end
	gearListWindow:SetExtent(
		MAIN_WINDOW_WIDTH,
		math.max(35, MAIN_TOP_PADDING + contentHeight + MAIN_BOTTOM_PADDING)
	)
end

------------- dirt zone -----------------------

--
--
--
--
--
local RefreshSettingsWindow

local function deleteGear(setName)
	if gears[setName] then
		gears[setName] = nil
		gearSettings.sets[setName] = nil
		saveGearsToFile()
		SaveGearSettings()
		createGearList()
		if settingsWindow ~= nil and settingsWindow:IsVisible() then
			RefreshSettingsWindow()
		end
		X2Chat:DispatchChatMessage(CMF_SYSTEM, "Deleted gear set: " .. setName)
	else
		X2Chat:DispatchChatMessage(CMF_SYSTEM, "Gear set not found: " .. setName)
	end
end
--
local function saveGear(gearName)
	local currentEquipment = getEquippedGearArray()
	--X2Chat:DispatchChatMessage(CMF_SYSTEM, "saving:" .. dump(getEquippedGearArray()))
	gears[gearName] = currentEquipment
	if gearSettings.sets[gearName] == nil then
		gearSettings.sets[gearName] = { order = GetHighestGearOrder() + 1 }
	else
		gearSettings.sets[gearName].iconName = nil
		gearSettings.sets[gearName].customIcon = nil
	end
	saveGearsToFile()
	SaveGearSettings()
	createGearList()
	if settingsWindow ~= nil and settingsWindow:IsVisible() then
		RefreshSettingsWindow()
	end
end

local function MoveGearSet(setName, direction)
	local names = GetOrderedGearNames()
	local currentIndex = nil
	for index, name in ipairs(names) do
		if name == setName then
			currentIndex = index
			break
		end
	end
	if currentIndex == nil then
		return
	end
	local targetIndex = currentIndex + direction
	if targetIndex < 1 or targetIndex > #names then
		return
	end
	local otherName = names[targetIndex]
	local currentOrder = gearSettings.sets[setName].order
	gearSettings.sets[setName].order = gearSettings.sets[otherName].order
	gearSettings.sets[otherName].order = currentOrder
	SaveGearSettings()
	createGearList()
	RefreshSettingsWindow()
end

local function CreateWindowBackground(window)
	local bg = window:CreateDrawable("ui/common/default.dds", "main_bg", "background")
	bg:AddAnchor("TOPLEFT", window, -5, -5)
	bg:AddAnchor("BOTTOMRIGHT", window, 5, 5)
	return bg
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

local function OpenAddSetWindow()
	if addSetWindow == nil then
		addSetWindow = CreateEmptyWindow("gearSwapAddSetWindow", "UIParent")
		addSetWindow:SetExtent(350, 145)
		addSetWindow:AddAnchor("CENTER", "UIParent", 0, 0)
		addSetWindow:SetCloseOnEscape(true)
		addSetWindow:Show(false)
		CreateWindowBackground(addSetWindow)

		local title = addSetWindow:CreateChildWidget("label", "gearAddSetTitle", 0, true)
		title:AddAnchor("TOP", addSetWindow, 0, 11)
		title:SetExtent(280, 24)
		title:SetText("Add Gear Set")
		title.style:SetAlign(ALIGN_CENTER)
		title.style:SetFontSize(16)
		title.style:SetColorByKey("title")

		local closeButton = addSetWindow:CreateChildWidget("button", "gearAddSetClose", 0, true)
		closeButton:AddAnchor("TOPRIGHT", addSetWindow, 3, -3)
		closeButton:SetStyle("btn_close_default")
		closeButton:SetHandler("OnClick", function(_, arg)
			if arg ~= "RightButton" then
				addSetWindow:Show(false)
			end
		end)

		addSetWindow.nameEdit = CreateLocalEditBox(addSetWindow, "gearAddSetName", 310)
		addSetWindow.nameEdit:AddAnchor("TOPLEFT", addSetWindow, 20, 48)
		addSetWindow.nameEdit:SetMaxTextLength(48)
		addSetWindow.nameEdit:SetGuideText("Set name")

		local function SubmitAddSet()
			local setName = tostring(addSetWindow.nameEdit:GetText() or ""):match("^%s*(.-)%s*$")
			if setName == "" then
				aaprint("Please enter a gear set name.")
				return
			end
			if gears[setName] ~= nil then
				aaprint("Gear set already exists. Select it and use Update.")
				return
			end
			selectedGearName = setName
			saveGear(setName)
			addSetWindow.nameEdit:ClearFocus()
			addSetWindow:Show(false)
			RefreshSettingsWindow()
		end

		local addButton = addSetWindow:CreateChildWidget("button", "gearAddSetConfirm", 0, true)
		addButton:AddAnchor("BOTTOMLEFT", addSetWindow, 20, -18)
		addButton:SetStyle("text_default")
		addButton:SetAutoResize(false)
		addButton:SetExtent(75, 28)
		addButton:SetText("Add")
		addButton:SetHandler("OnClick", function(_, arg)
			if arg ~= "RightButton" then
				SubmitAddSet()
			end
		end)
		addButton:SetWidth(75)

		local cancelButton = addSetWindow:CreateChildWidget("button", "gearAddSetCancel", 0, true)
		cancelButton:AddAnchor("LEFT", addButton, "RIGHT", 6, 0)
		cancelButton:SetStyle("text_default")
		cancelButton:SetAutoResize(false)
		cancelButton:SetExtent(75, 28)
		cancelButton:SetText("Cancel")
		cancelButton:SetHandler("OnClick", function(_, arg)
			if arg ~= "RightButton" then
				addSetWindow:Show(false)
			end
		end)
		cancelButton:SetWidth(75)
		addSetWindow.nameEdit:SetHandler("OnEnterPressed", SubmitAddSet)
	end

	addSetWindow.nameEdit:SetText("")
	addSetWindow:Show(true)
	addSetWindow.nameEdit:SetFocus()
end

local function BuildCustomIconEntries()
	if customIconEntries ~= nil then
		return
	end
	customIconEntries = {}
	for itemName, iconPath in pairs(itemIconsByName) do
		local clientPath = ToClientIconPath(iconPath)
		local filename = clientPath:match("([^/]+)$") or clientPath
		table.insert(customIconEntries, {
			name = itemName,
			icon = clientPath,
			filename = filename,
			search = string.lower(itemName .. " " .. filename .. " " .. clientPath),
		})
	end
	table.sort(customIconEntries, function(left, right)
		local leftName = string.lower(left.name)
		local rightName = string.lower(right.name)
		if leftName == rightName then
			return left.icon < right.icon
		end
		return leftName < rightName
	end)
end

local RefreshCustomIconWindow

local function EnsureCustomIconRow(index)
	if customIconRows[index] ~= nil then
		return customIconRows[index]
	end
	local row = {}
	local y = 102 + ((index - 1) * 27)
	row.icon = customIconWindow:CreateImageDrawable(UNKNOWN_ICON, "artwork")
	row.icon:AddAnchor("TOPLEFT", customIconWindow, 20, y + 2)
	row.icon:SetExtent(22, 22)
	row.button = customIconWindow:CreateChildWidget("button", "gearCustomIconRow" .. index, index, true)
	row.button:AddAnchor("TOPLEFT", customIconWindow, 48, y)
	row.button:SetStyle("text_default")
	row.button:SetAutoResize(false)
	row.button:SetExtent(552, 25)
	row.button.style:SetEllipsis(true)
	row.button:SetHandler("OnClick", function(self, arg)
		if arg == "RightButton" or self.entry == nil then
			return
		end
		local setName = customIconWindow.gearName
		if setName == nil or gearSettings.sets[setName] == nil then
			return
		end
		gearSettings.sets[setName].customIcon = self.entry.icon
		gearSettings.sets[setName].iconName = nil
		SaveGearSettings()
		createGearList()
		RefreshSettingsWindow()
		customIconWindow:Show(false)
	end)
	row.button:SetHandler("OnEnter", function(self)
		if self.tooltip ~= nil and SetTooltip ~= nil then
			SetTooltip(self.tooltip, self)
		end
	end)
	row.button:SetWidth(552)
	customIconRows[index] = row
	return row
end

local function CreateCustomIconWindow()
	if customIconWindow ~= nil then
		return
	end
	customIconWindow = CreateEmptyWindow("gearSwapCustomIconWindow", "UIParent")
	customIconWindow:SetExtent(620, 470)
	customIconWindow:AddAnchor("CENTER", "UIParent", 0, 0)
	customIconWindow:SetCloseOnEscape(true)
	customIconWindow:EnableDrag(true)
	customIconWindow:Show(false)
	CreateWindowBackground(customIconWindow)

	local title = customIconWindow:CreateChildWidget("label", "gearCustomIconTitle", 0, true)
	title:AddAnchor("TOP", customIconWindow, 0, 11)
	title:SetExtent(540, 24)
	title:SetText("Choose Custom Gear Icon")
	title.style:SetAlign(ALIGN_CENTER)
	title.style:SetFontSize(16)
	title.style:SetColorByKey("title")

	local closeButton = customIconWindow:CreateChildWidget("button", "gearCustomIconClose", 0, true)
	closeButton:AddAnchor("TOPRIGHT", customIconWindow, 3, -3)
	closeButton:SetStyle("btn_close_default")
	closeButton:SetHandler("OnClick", function(_, arg)
		if arg ~= "RightButton" then
			customIconWindow:Show(false)
		end
	end)

	customIconWindow.searchEdit = CreateLocalEditBox(customIconWindow, "gearCustomIconSearch", 480)
	customIconWindow.searchEdit:AddAnchor("TOPLEFT", customIconWindow, 20, 48)
	customIconWindow.searchEdit:SetGuideText("Search equipment name or icon_name.dds")
	customIconWindow.searchEdit:SetHandler("OnTextChanged", function()
		customIconPage = 1
		RefreshCustomIconWindow()
	end)
	customIconWindow.searchEdit:SetHandler("OnEnterPressed", function()
		customIconPage = 1
		RefreshCustomIconWindow()
	end)

	local clearButton = customIconWindow:CreateChildWidget("button", "gearCustomIconClear", 0, true)
	clearButton:AddAnchor("TOPLEFT", customIconWindow, 508, 47)
	clearButton:SetStyle("text_default")
	clearButton:SetAutoResize(false)
	clearButton:SetExtent(92, 28)
	clearButton:SetText("Clear")
	clearButton:SetHandler("OnClick", function(_, arg)
		if arg ~= "RightButton" then
			customIconWindow.searchEdit:SetText("")
			customIconPage = 1
			RefreshCustomIconWindow()
		end
	end)
	clearButton:SetWidth(92)

	local header = customIconWindow:CreateChildWidget("label", "gearCustomIconHeader", 0, true)
	header:AddAnchor("TOPLEFT", customIconWindow, 48, 80)
	header:SetExtent(552, 20)
	header:SetText("Equipment name                                      DDS filename")
	header.style:SetAlign(ALIGN_LEFT)
	header.style:SetColorByKey("default")

	customIconWindow.prevButton = customIconWindow:CreateChildWidget("button", "gearCustomIconPrev", 0, true)
	customIconWindow.prevButton:AddAnchor("BOTTOMLEFT", customIconWindow, 20, -18)
	customIconWindow.prevButton:SetStyle("text_default")
	customIconWindow.prevButton:SetAutoResize(false)
	customIconWindow.prevButton:SetExtent(70, 28)
	customIconWindow.prevButton:SetText("Prev")
	customIconWindow.prevButton:SetHandler("OnClick", function(_, arg)
		if arg ~= "RightButton" and customIconPage > 1 then
			customIconPage = customIconPage - 1
			RefreshCustomIconWindow()
		end
	end)
	customIconWindow.prevButton:SetWidth(70)

	customIconWindow.nextButton = customIconWindow:CreateChildWidget("button", "gearCustomIconNext", 0, true)
	customIconWindow.nextButton:AddAnchor("LEFT", customIconWindow.prevButton, "RIGHT", 6, 0)
	customIconWindow.nextButton:SetStyle("text_default")
	customIconWindow.nextButton:SetAutoResize(false)
	customIconWindow.nextButton:SetExtent(70, 28)
	customIconWindow.nextButton:SetText("Next")
	customIconWindow.nextButton:SetHandler("OnClick", function(_, arg)
		local maxPage = math.max(1, math.ceil(#customIconFiltered / CUSTOM_ICON_ROWS))
		if arg ~= "RightButton" and customIconPage < maxPage then
			customIconPage = customIconPage + 1
			RefreshCustomIconWindow()
		end
	end)
	customIconWindow.nextButton:SetWidth(70)

	customIconWindow.pageLabel = customIconWindow:CreateChildWidget("label", "gearCustomIconPage", 0, true)
	customIconWindow.pageLabel:AddAnchor("BOTTOMRIGHT", customIconWindow, -20, -22)
	customIconWindow.pageLabel:SetExtent(300, 20)
	customIconWindow.pageLabel.style:SetAlign(ALIGN_RIGHT)
	customIconWindow.pageLabel.style:SetColorByKey("default")

	customIconWindow:SetHandler("OnDragStart", function(self)
		self:StartMoving()
		self.moving = true
	end)
	customIconWindow:SetHandler("OnDragStop", function(self)
		self:StopMovingOrSizing()
		self.moving = false
	end)
end

RefreshCustomIconWindow = function()
	CreateCustomIconWindow()
	BuildCustomIconEntries()
	local query = string.lower(tostring(customIconWindow.searchEdit:GetText() or "")):match("^%s*(.-)%s*$")
	customIconFiltered = {}
	for _, entry in ipairs(customIconEntries) do
		if query == "" or string.find(entry.search, query, 1, true) ~= nil then
			table.insert(customIconFiltered, entry)
		end
	end
	local maxPage = math.max(1, math.ceil(#customIconFiltered / CUSTOM_ICON_ROWS))
	customIconPage = math.max(1, math.min(customIconPage, maxPage))
	for rowIndex = 1, CUSTOM_ICON_ROWS do
		local row = EnsureCustomIconRow(rowIndex)
		local entry = customIconFiltered[((customIconPage - 1) * CUSTOM_ICON_ROWS) + rowIndex]
		if entry ~= nil then
			row.button.entry = entry
			row.button.tooltip = entry.name .. "\n" .. entry.icon
			SetIconTexture(row.icon, entry.icon)
			row.icon:Show(true)
			row.button:SetText(entry.name .. "    [" .. entry.filename .. "]")
			row.button:SetWidth(552)
			row.button:Show(true)
		else
			row.button.entry = nil
			row.icon:Show(false)
			row.button:Show(false)
		end
	end
	customIconWindow.pageLabel:SetText(
		string.format("%d/%d   %d icons", customIconPage, maxPage, #customIconFiltered)
	)
end

local function OpenCustomIconWindow()
	if selectedGearName == nil or gears[selectedGearName] == nil then
		aaprint("Select a gear set first.")
		return
	end
	CreateCustomIconWindow()
	customIconWindow.gearName = selectedGearName
	customIconPage = 1
	customIconWindow.searchEdit:SetText("")
	RefreshCustomIconWindow()
	customIconWindow:Show(true)
	customIconWindow.searchEdit:SetFocus()
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

	row.nameButton = settingsWindow:CreateChildWidget("button", "gearSettingsSelect" .. index, index, true)
	row.nameButton:AddAnchor("TOPLEFT", settingsWindow, 50, y)
	row.nameButton:SetAutoResize(false)
	row.nameButton:SetExtent(300, 26)
	row.nameButton:SetStyle("text_default")
	row.nameButton.style:SetEllipsis(true)
	row.nameButton:SetHandler("OnClick", function(self, arg)
		if arg ~= "RightButton" and self.gearName ~= nil then
			selectedGearName = self.gearName
			RefreshSettingsWindow()
		end
	end)
	row.nameButton:SetWidth(300)

	row.moveUpButton = settingsWindow:CreateChildWidget("button", "gearSettingsMoveUp" .. index, index, true)
	row.moveUpButton:AddAnchor("TOPLEFT", settingsWindow, 358, y)
	row.moveUpButton:SetStyle("text_default")
	row.moveUpButton:SetAutoResize(false)
	row.moveUpButton:SetExtent(25, 26)
	row.moveUpButton:SetText("^")
	row.moveUpButton:SetHandler("OnClick", function(self, arg)
		if arg ~= "RightButton" and self.gearName ~= nil then
			MoveGearSet(self.gearName, -1)
		end
	end)
	row.moveUpButton:SetWidth(18)

	row.moveDownButton = settingsWindow:CreateChildWidget("button", "gearSettingsMoveDown" .. index, index, true)
	row.moveDownButton:AddAnchor("TOPLEFT", settingsWindow, 378, y)
	row.moveDownButton:SetStyle("text_default")
	row.moveDownButton:SetAutoResize(false)
	row.moveDownButton:SetExtent(25, 26)
	row.moveDownButton:SetText("v")
	row.moveDownButton:SetHandler("OnClick", function(self, arg)
		if arg ~= "RightButton" and self.gearName ~= nil then
			MoveGearSet(self.gearName, 1)
		end
	end)
	row.moveDownButton:SetWidth(18)

	settingsRows[index] = row
	return row
end

local function EnsureContentRow(index)
	if contentRows[index] ~= nil then
		return contentRows[index]
	end
	local row = {}
	row.icon = settingsWindow:CreateImageDrawable(UNKNOWN_ICON, "artwork")
	row.icon:SetExtent(20, 20)
	row.button = settingsWindow:CreateChildWidget("button", "gearSettingsContent" .. index, index, true)
	row.button:SetStyle("text_default")
	row.button:SetAutoResize(false)
	row.button:SetExtent(191, 24)
	row.button.style:SetEllipsis(true)
	row.button:SetHandler("OnClick", function(self, arg)
		if arg == "RightButton" or self.gearName == nil or self.itemName == nil then
			return
		end
		gearSettings.sets[self.gearName].iconName = self.itemName
		gearSettings.sets[self.gearName].customIcon = nil
		SaveGearSettings()
		createGearList()
		RefreshSettingsWindow()
	end)
	row.button:SetHandler("OnEnter", function(self)
		if self.tooltip ~= nil and SetTooltip ~= nil then
			SetTooltip(self.tooltip, self)
		end
	end)
	row.button:SetWidth(191)
	contentRows[index] = row
	return row
end

local function CreateSettingsWindow()
	if settingsWindow ~= nil then
		return
	end
	settingsWindow = CreateEmptyWindow("gearSwapSettingsWindow", "UIParent")
	settingsWindow:SetExtent(SETTINGS_WIDTH, 180)
	settingsWindow:AddAnchor("CENTER", "UIParent", 0, 0)
	settingsWindow:SetCloseOnEscape(true)
	settingsWindow:EnableDrag(true)
	settingsWindow:Show(false)
	CreateWindowBackground(settingsWindow)

	local title = settingsWindow:CreateChildWidget("label", "gearSettingsTitle", 0, true)
	title:AddAnchor("TOP", settingsWindow, 0, 11)
	title:SetExtent(SETTINGS_WIDTH - 70, 24)
	title:SetText("GearSwap Settings")
	title.style:SetAlign(ALIGN_CENTER)
	title.style:SetFontSize(16)
	title.style:SetColorByKey("title")

	local closeButton = settingsWindow:CreateChildWidget("button", "gearSettingsClose", 0, true)
	closeButton:AddAnchor("TOPRIGHT", settingsWindow, 3, -3)
	closeButton:SetStyle("btn_close_default")
	closeButton:SetHandler("OnClick", function(_, arg)
		if arg ~= "RightButton" then
			settingsWindow:Show(false)
		end
	end)

	local setHeader = settingsWindow:CreateChildWidget("label", "gearSettingsSetHeader", 0, true)
	setHeader:AddAnchor("TOPLEFT", settingsWindow, 50, 42)
	setHeader:SetExtent(300, 20)
	setHeader:SetText("Saved gear set")
	setHeader.style:SetAlign(ALIGN_LEFT)
	setHeader.style:SetColorByKey("default")

	settingsWindow.contentsHeader = settingsWindow:CreateChildWidget("label", "gearSettingsContentsHeader", 0, true)
	settingsWindow.contentsHeader:SetExtent(SETTINGS_WIDTH - 40, 20)
	settingsWindow.contentsHeader.style:SetAlign(ALIGN_LEFT)
	settingsWindow.contentsHeader.style:SetColorByKey("default")

	settingsWindow.addSetButton = settingsWindow:CreateChildWidget("button", "gearSettingsAddSet", 0, true)
	settingsWindow.addSetButton:SetStyle("text_default")
	settingsWindow.addSetButton:SetAutoResize(false)
	settingsWindow.addSetButton:SetExtent(65, 28)
	settingsWindow.addSetButton:SetText("Add")
	settingsWindow.addSetButton:SetHandler("OnClick", function(_, arg)
		if arg ~= "RightButton" then
			OpenAddSetWindow()
		end
	end)
	settingsWindow.addSetButton:SetWidth(65)

	settingsWindow.updateSetButton = settingsWindow:CreateChildWidget("button", "gearSettingsUpdateSet", 0, true)
	settingsWindow.updateSetButton:SetStyle("text_default")
	settingsWindow.updateSetButton:SetAutoResize(false)
	settingsWindow.updateSetButton:SetExtent(75, 28)
	settingsWindow.updateSetButton:SetText("Update")
	settingsWindow.updateSetButton:SetHandler("OnClick", function(_, arg)
		if arg == "RightButton" or selectedGearName == nil then
			return
		end
		saveGear(selectedGearName)
		RefreshSettingsWindow()
	end)
	settingsWindow.updateSetButton:SetWidth(75)

	settingsWindow.removeSetButton = settingsWindow:CreateChildWidget("button", "gearSettingsRemoveSet", 0, true)
	settingsWindow.removeSetButton:SetStyle("text_default")
	settingsWindow.removeSetButton:SetAutoResize(false)
	settingsWindow.removeSetButton:SetExtent(75, 28)
	settingsWindow.removeSetButton:SetText("Remove")
	settingsWindow.removeSetButton:SetHandler("OnClick", function(_, arg)
		if arg == "RightButton" or selectedGearName == nil then
			return
		end
		local removedName = selectedGearName
		selectedGearName = nil
		deleteGear(removedName)
		RefreshSettingsWindow()
	end)
	settingsWindow.removeSetButton:SetWidth(75)

	settingsWindow.customIconButton = settingsWindow:CreateChildWidget("button", "gearSettingsCustomIcon", 0, true)
	settingsWindow.customIconButton:SetStyle("text_default")
	settingsWindow.customIconButton:SetAutoResize(false)
	settingsWindow.customIconButton:SetExtent(100, 28)
	settingsWindow.customIconButton:SetText("Custom icon")
	settingsWindow.customIconButton:SetHandler("OnClick", function(_, arg)
		if arg ~= "RightButton" then
			OpenCustomIconWindow()
		end
	end)
	settingsWindow.customIconButton:SetWidth(100)

	settingsWindow.showContentsButton = settingsWindow:CreateChildWidget("button", "gearSettingsShowContents", 0, true)
	settingsWindow.showContentsButton:SetStyle("text_default")
	settingsWindow.showContentsButton:SetAutoResize(false)
	settingsWindow.showContentsButton:SetExtent(115, 28)
	settingsWindow.showContentsButton:SetText("Show contents")
	settingsWindow.showContentsButton:SetHandler("OnClick", function(_, arg)
		if arg == "RightButton" then
			return
		end
		gearSettings.showContents = not gearSettings.showContents
		SaveGearSettings()
		RefreshSettingsWindow()
	end)
	settingsWindow.showContentsButton:SetWidth(115)

	settingsWindow.showIconsButton = settingsWindow:CreateChildWidget("button", "gearSettingsShowIcons", 0, true)
	settingsWindow.showIconsButton:SetStyle("text_default")
	settingsWindow.showIconsButton:SetAutoResize(false)
	settingsWindow.showIconsButton:SetExtent(95, 28)
	settingsWindow.showIconsButton:SetText("Show icons")
	settingsWindow.showIconsButton:SetHandler("OnClick", function(_, arg)
		if arg == "RightButton" then
			return
		end
		gearSettings.showIcons = not gearSettings.showIcons
		SaveGearSettings()
		createGearList()
		RefreshSettingsWindow()
	end)
	settingsWindow.showIconsButton:SetWidth(95)

	settingsWindow:SetHandler("OnDragStart", function(self)
		self:StartMoving()
		self.moving = true
	end)
	settingsWindow:SetHandler("OnDragStop", function(self)
		self:StopMovingOrSizing()
		self.moving = false
	end)
end

RefreshSettingsWindow = function()
	CreateSettingsWindow()
	local names = GetOrderedGearNames()
	if selectedGearName == nil or gears[selectedGearName] == nil then
		selectedGearName = names[1]
	end
	for index, setName in ipairs(names) do
		local row = EnsureSettingsRow(index)
		row.gearName = setName
		row.nameButton.gearName = setName
		row.moveUpButton.gearName = setName
		row.moveDownButton.gearName = setName
		SetIconTexture(row.icon, GetGearIcon(setName))
		row.icon:Show(true)
		row.nameButton:SetText(setName)
		row.nameButton:SetWidth(300)
		SetButtonFontOneColor(row.nameButton, setName == selectedGearName and COLOR_SELECTED or COLOR_NORMAL)
		row.nameButton:Show(true)
		row.moveUpButton:Show(true)
		row.moveDownButton:Show(true)
	end
	for index = #names + 1, #settingsRows do
		local row = settingsRows[index]
		row.gearName = nil
		row.nameButton.gearName = nil
		row.moveUpButton.gearName = nil
		row.moveDownButton.gearName = nil
		row.icon:Show(false)
		row.nameButton:Show(false)
		row.moveUpButton:Show(false)
		row.moveDownButton:Show(false)
	end

	local afterSetsY = 68 + (#names * SETTINGS_ROW_HEIGHT)
	local visibleContents = 0
	local contentRowsHigh = 0
	if gearSettings.showContents and selectedGearName ~= nil then
		local gearArray = gears[selectedGearName] or {}
		local currentGear = getEquippedGearArray()
		settingsWindow.contentsHeader:RemoveAllAnchors()
		settingsWindow.contentsHeader:AddAnchor("TOPLEFT", settingsWindow, 20, afterSetsY)
		settingsWindow.contentsHeader:SetText("Contents: " .. selectedGearName .. "  (click a piece to use its icon)")
		settingsWindow.contentsHeader:Show(true)
		local contentStartY = afterSetsY + 22
		for itemIndex, item in ipairs(gearArray) do
			local row = EnsureContentRow(itemIndex)
			local column = (itemIndex - 1) % CONTENT_COLUMNS
			local line = math.floor((itemIndex - 1) / CONTENT_COLUMNS)
			local x = 20 + (column * 225)
			local y = contentStartY + (line * CONTENT_ROW_HEIGHT)
			local slotName = GEAR_SLOT_NAMES_BY_ID[tonumber(item.slot)]
				or GEAR_SLOT_NAMES[itemIndex]
				or ("Slot " .. itemIndex)
			row.gearName = selectedGearName
			row.itemName = item.name
			row.button.gearName = selectedGearName
			row.button.itemName = item.name
			row.button.tooltip = slotName .. ": " .. tostring(item.name)
			row.icon:RemoveAllAnchors()
			row.icon:AddAnchor("TOPLEFT", settingsWindow, x, y + 2)
			SetIconTexture(row.icon, GetItemIcon(item.name, item.icon))
			row.icon:Show(true)
			row.button:RemoveAllAnchors()
			row.button:AddAnchor("TOPLEFT", settingsWindow, x + 24, y)
			row.button:SetText(slotName .. ": " .. tostring(item.name))
			row.button:SetWidth(191)
			local itemColor = COLOR_NORMAL
			if IsGearItemCurrentlyEquipped(item, itemIndex, currentGear) then
				itemColor = COLOR_ACTIVE
			elseif item.name == GetGearIconItem(selectedGearName) then
				itemColor = COLOR_SELECTED
			end
			SetButtonFontOneColor(row.button, itemColor)
			row.button:Show(true)
			visibleContents = itemIndex
		end
		contentRowsHigh = math.ceil(#gearArray / CONTENT_COLUMNS)
	else
		settingsWindow.contentsHeader:Show(false)
	end
	for index = visibleContents + 1, #contentRows do
		local row = contentRows[index]
		row.gearName = nil
		row.itemName = nil
		row.button.gearName = nil
		row.button.itemName = nil
		row.icon:Show(false)
		row.button:Show(false)
	end

	local footerY = afterSetsY + (contentRowsHigh * CONTENT_ROW_HEIGHT) + (gearSettings.showContents and 32 or 4)
	settingsWindow.addSetButton:RemoveAllAnchors()
	settingsWindow.addSetButton:AddAnchor("TOPLEFT", settingsWindow, 20, footerY)
	settingsWindow.updateSetButton:RemoveAllAnchors()
	settingsWindow.updateSetButton:AddAnchor("LEFT", settingsWindow.addSetButton, "RIGHT", 6, 0)
	settingsWindow.removeSetButton:RemoveAllAnchors()
	settingsWindow.removeSetButton:AddAnchor("LEFT", settingsWindow.updateSetButton, "RIGHT", 6, 0)
	settingsWindow.customIconButton:RemoveAllAnchors()
	settingsWindow.customIconButton:AddAnchor("LEFT", settingsWindow.removeSetButton, "RIGHT", 6, 0)
	local togglesY = footerY + 34
	settingsWindow.showContentsButton:RemoveAllAnchors()
	settingsWindow.showContentsButton:AddAnchor("TOPLEFT", settingsWindow, 20, togglesY)
	settingsWindow.showIconsButton:RemoveAllAnchors()
	settingsWindow.showIconsButton:AddAnchor("TOPRIGHT", settingsWindow, -20, togglesY)
	SetButtonFontOneColor(
		settingsWindow.showContentsButton,
		gearSettings.showContents and COLOR_ACTIVE or COLOR_NORMAL
	)
	SetButtonFontOneColor(settingsWindow.showIconsButton, gearSettings.showIcons and COLOR_ACTIVE or COLOR_NORMAL)
	settingsWindow:SetExtent(SETTINGS_WIDTH, math.max(179, footerY + 82))
end

local function ToggleSettingsWindow()
	CreateSettingsWindow()
	if settingsWindow:IsVisible() then
		settingsWindow:Show(false)
	else
		RefreshSettingsWindow()
		settingsWindow:Show(true)
	end
end

local settingsButton = gearListWindow:CreateChildWidget("button", "gearSwapSettingsButton", 0, true)
settingsButton:AddAnchor("TOPRIGHT", gearListWindow, 0, -25)
settingsButton:SetStyle("text_default")
settingsButton:SetExtent(35, 25)
settingsButton:SetText("?")
settingsButton:SetHandler("OnClick", ToggleSettingsWindow)
settingsButton:SetWidth(25)

---- Handle chat events
local chatAggroEventListenerEvents = {
	CHAT_MESSAGE = function(_, _, name, message)
		if name == X2Unit:UnitName("player") then --and string.sub(message, 1, 1) == "/" then
			local firstWord = string.match(message, "/%w+")
			local secondWord = string.match(message, "/%w+%s+(.+)")
			if firstWord == "/addset" then
				if secondWord ~= nil then
					saveGear(secondWord)
				else
					X2Chat:DispatchChatMessage(CMF_SYSTEM, "Invalid gearset name. Please use /addset name")
				end
			elseif firstWord == "/removeset" then
				if secondWord ~= nil then
					deleteGear(secondWord)
				else
					X2Chat:DispatchChatMessage(CMF_SYSTEM, "Invalid gearset name. Please use /removeset name")
				end
			elseif firstWord == "/overwriteset" then
				if secondWord ~= nil then
					if gears[secondWord] then
						gears[secondWord] = nil
						saveGear(secondWord)
					else
						X2Chat:DispatchChatMessage(CMF_SYSTEM, "Gearset " .. secondWord .. " not found")
					end
				else
					X2Chat:DispatchChatMessage(CMF_SYSTEM, "Invalid gearset name. Please use /overwriteset name")
				end
			end
		end
	end,
}
--
--make chat listener
local chatEventListenerAggro = CreateEmptyWindow("chatEventListenerAggro", "UIParent")
chatEventListenerAggro:Show(false)
chatEventListenerAggro:SetHandler("OnEvent", function(this, event, ...)
	chatAggroEventListenerEvents[event](...)
end)
local RegistUIEvent = function(window, eventTable)
	for key, _ in pairs(eventTable) do
		window:RegisterEvent(key)
	end
end
RegistUIEvent(chatEventListenerAggro, chatAggroEventListenerEvents)
--
--make draggable window
function gearListWindow:OnDragStart()
	self:StartMoving()
	self.moving = true
end
gearListWindow:SetHandler("OnDragStart", gearListWindow.OnDragStart)
function gearListWindow:OnDragStop()
	self:StopMovingOrSizing()
	self.moving = false
	local offsetX, offsetY = self:GetOffset()
	local uiScale = UIParent:GetUIScale() or 1.0
	local normalizedX = offsetX * uiScale
	local normalizedY = offsetY * uiScale
	SaveWindowPosition(normalizedX, normalizedY)
end
gearListWindow:SetHandler("OnDragStop", gearListWindow.OnDragStop)

LoadGearSettings()
loadGearSetsFromFile()
SyncGearSettings()
SaveGearSettings()
createGearList()
