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

local gearListWindow = CreateEmptyWindow("gearListWindow", "UIParent")
gearListWindow:SetExtent(0, 0)
--gearListWindow:AddAnchor("RIGHT", "UIParent", -100, -200)
gearListWindow:EnableDrag(true)
gearListWindow:Show(true)

local gearWidgets = {}

WindowState.TrackPosition(gearListWindow, "GearWindowPos.txt", 0, 0)

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
	local equippedIndex = 0
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
	getGearFromInventory()
	return true
end
local function getEquippedGearArray()
	local items = {}
	local gear_pieces = { 1, 3, 4, 8, 6, 9, 5, 7, 15, 2, 10, 11, 12, 13, 16, 17, 18, 19, 28 }
	for _, i in ipairs(gear_pieces) do
		local item = X2Equipment:GetEquippedItemTooltipInfo(i, true)
		if item ~= nil then
			local new_item = { name = item.name, grade = item.itemGrade }
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
			if item.alternative then
				file:write(string.format('    {name = "%s", grade = %d, alternative = true},\n', item.name, item.grade))
			else
				file:write(
					string.format('    {name = "%s", grade = %d, alternative = false},\n', item.name, item.grade)
				)
			end
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

local function createGearList()
	-- clear existing buttons
	for _, widget in ipairs(gearWidgets) do
		widget:SetText("")
		widget:AddAnchor("TOPLEFT", gearListWindow, 9999, 9999) -- don't think about this too much :)
	end
	gearWidgets = {}

	local yOffset = 10
	local buttonSpacing = 25
	-- button size settings
	local xSize = 80
	local ySize = 30
	local currentGear = getEquippedGearArray()

	local totalGears = 0
	for gearName, gearArray in pairs(gears) do
		totalGears = totalGears + 1
		local gearButton = gearListWindow:CreateChildWidget(
			"button",
			"gearButton_" .. gearName .. tostring(totalGears),
			totalGears,
			true
		)
		gearButton:AddAnchor("TOPLEFT", gearListWindow, 10, yOffset)
		gearButton:SetText(gearName)

		--X2Chat:DispatchChatMessage(CMF_SYSTEM, dump(currentGear))
		--X2Chat:DispatchChatMessage(CMF_SYSTEM, dump(gearArray))

		if isGearNameEqual(currentGear, gearArray) then
			gearButton:SetStyle("text_default")
			SetButtonFontOneColor(gearButton, { 0.348, 0.609, 0.370, 1 })
		else
			gearButton:SetStyle("text_default")
			SetButtonFontOneColor(gearButton, { 0.2, 0.2, 0.2, 1 })
		end

		gearButton:SetExtent(xSize, ySize)
		gearButton:SetHandler("OnClick", function()
			local gearCheck = equipGear(gearName)
			if gearCheck == true then
				-- set to green and others to normal
				gearButton:SetStyle("text_default") --ApplyButtonSkin(gearButton, buttonskin_selected)
				SetButtonFontOneColor(gearButton, { 0.348, 0.609, 0.370, 1 })
				gearButton:SetExtent(xSize, ySize)
				for _, otherButton in ipairs(gearWidgets) do
					if otherButton ~= gearButton then
						otherButton:SetStyle("text_default") --ApplyButtonSkin(otherButton, buttonskin)
						SetButtonFontOneColor(otherButton, { 0.2, 0.2, 0.2, 1 })
						otherButton:SetExtent(xSize, ySize)
					end
				end
			end
		end)
		table.insert(gearWidgets, gearButton)
		yOffset = yOffset + buttonSpacing
	end

	local windowWidth = 100
	local windowHeight = totalGears * buttonSpacing + 25
	gearListWindow:SetExtent(windowWidth, windowHeight)
end

--X2Chat:DispatchChatMessage(CMF_SYSTEM,"Loading gear sets")
loadGearSetsFromFile()
--X2Chat:DispatchChatMessage(CMF_SYSTEM, "Creating list")
createGearList()
--X2Chat:DispatchChatMessage(CMF_SYSTEM, "end")

------------- dirt zone -----------------------

--
--
--
--
--
local function deleteGear(setName)
	if gears[setName] then
		gears[setName] = nil
		saveGearsToFile()
		createGearList()
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
	saveGearsToFile()
	createGearList()
end

---- Handle chat events
local chatAggroEventListenerEvents = {
	CHAT_MESSAGE = function(channel, relation, name, message, info)
		--X2Chat:DispatchChatMessage(CMF_SYSTEM, "x2name: " .. X2Unit:UnitName("player") .. " name: ".. name) --.. " fchar: "..string.sub(message, 1, 1) )
		if name == X2Unit:UnitName("player") then --and string.sub(message, 1, 1) == "/" then
			local firstWord = string.match(message, "/%w+")
			local secondWord = string.match(message, "/%w+%s+(%w+)")
			if firstWord == "/addset" then
				if secondWord ~= nil then
					gearName = secondWord
					saveGear(gearName)
				else
					X2Chat:DispatchChatMessage(CMF_SYSTEM, "Invalid gearset name. Please use /addset name")
				end
			elseif firstWord == "/removeset" then
				if secondWord ~= nil then
					gearName = secondWord
					deleteGear(gearName)
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
-- Window position is persisted by WindowState.TrackPosition (see top of file).
