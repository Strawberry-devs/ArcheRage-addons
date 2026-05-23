if API_TYPE == nil then
	ADDON:ImportAPI(8)
	X2Chat:DispatchChatMessage(
		CMF_SYSTEM,
		"Globals folder not found. Please install it at https://github.com/Schiz-n/ArcheRage-addons/tree/master/globals"
	)
	return
end

ADDON:ImportObject(OBJECT_TYPE.TEXT_STYLE)
ADDON:ImportObject(OBJECT_TYPE.WINDOW)
ADDON:ImportObject(OBJECT_TYPE.BUTTON)
ADDON:ImportObject(OBJECT_TYPE.DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.COLOR_DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.ICON_DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.LABEL)
ADDON:ImportObject(OBJECT_TYPE.EDITBOX)
ADDON:ImportObject(OBJECT_TYPE.X2_EDITBOX)

ADDON:ImportAPI(API_TYPE.CHAT.id)
ADDON:ImportAPI(API_TYPE.UNIT.id)
ADDON:ImportAPI(API_TYPE.INPUT.id)

local DATA_KEY = "customraid_state"
local TOP_LAYER = "system"

local defaults = {
	x = 120,
	y = -120,
	width = 300,
	height = 470,
	locked = false,
	showDuration = false,
	iconSize = 16,
	iconOffsetX = 0,
	iconOffsetY = 0,
	trackedBuffIds = { 30098 },
}

local state = {
	x = defaults.x,
	y = defaults.y,
	width = defaults.width,
	height = defaults.height,
	locked = defaults.locked,
	showDuration = defaults.showDuration,
	iconSize = defaults.iconSize,
	iconOffsetX = defaults.iconOffsetX,
	iconOffsetY = defaults.iconOffsetY,
	trackedBuffIds = { 30098 },
}

local SPECIAL_ICON_PATHS = {
	[30098] = "ui/icon/icon_skill_pleasure14.dds",
}

local function cloneTrackedIds(ids)
	local result = {}
	if type(ids) ~= "table" then
		return result
	end
	for i = 1, #ids do
		local id = tonumber(ids[i])
		if id ~= nil and id > 0 then
			result[#result + 1] = math.floor(id)
		end
	end
	return result
end

local saved = ADDON:LoadData(DATA_KEY)
if type(saved) == "table" then
	state.x = tonumber(saved.x) or state.x
	state.y = tonumber(saved.y) or state.y
	state.width = tonumber(saved.width) or state.width
	state.height = tonumber(saved.height) or state.height
	if saved.locked ~= nil then
		state.locked = saved.locked == true
	end
	if saved.showDuration ~= nil then
		state.showDuration = saved.showDuration == true
	end
	state.iconSize = tonumber(saved.iconSize) or state.iconSize
	state.iconOffsetX = tonumber(saved.iconOffsetX) or state.iconOffsetX
	state.iconOffsetY = tonumber(saved.iconOffsetY) or state.iconOffsetY
	local loadedIds = cloneTrackedIds(saved.trackedBuffIds)
	if #loadedIds > 0 then
		state.trackedBuffIds = loadedIds
	end
end

local function saveState()
	ADDON:SaveData(DATA_KEY, state)
end

local frame = CreateEmptyWindow("customRaidOverlay", "UIParent")
frame:Show(true)
frame:Enable(true)
frame:Clickable(true)
frame:EnableDrag(true)
frame:SetUILayer(TOP_LAYER)

local background = frame:CreateColorDrawable(0.02, 0.05, 0.12, 0.65, "background")
background:AddAnchor("TOPLEFT", frame, 0, 0)
background:AddAnchor("BOTTOMRIGHT", frame, 0, 0)

local showGrid = true
local groupHeaders = {}
local slots = {}
local controls = {}
local frameToggleButton = nil
local frameLockButton = nil

local groupsPerRow = 5
local totalGroups = 10
local membersPerGroup = 5
local totalSlots = totalGroups * membersPerGroup
local WIDTH_STEP = 6
local HEIGHT_STEP = 16
local ICON_SIZE_STEP = 2
local ICON_OFFSET_STEP = 1

local function clamp(value, minValue, maxValue)
	if value < minValue then
		return minValue
	end
	if value > maxValue then
		return maxValue
	end
	return value
end

local function formatDuration(seconds)
	if seconds == nil then
		return ""
	end
	local value = tonumber(seconds)
	if value == nil then
		return ""
	end
	if value < 0 then
		value = 0
	end
	value = math.floor(value)
	if value >= 60 then
		local minutes = math.floor(value / 60)
		local remain = value % 60
		if remain < 10 then
			return tostring(minutes) .. ":0" .. tostring(remain)
		end
		return tostring(minutes) .. ":" .. tostring(remain)
	end
	return tostring(value)
end

local function trackedIdsToString()
	local parts = {}
	for i = 1, #state.trackedBuffIds do
		parts[#parts + 1] = tostring(state.trackedBuffIds[i])
	end
	return table.concat(parts, ",")
end

local function parseTrackedIds(text)
	local result = {}
	local seen = {}
	if type(text) ~= "string" then
		return result
	end
	for token in string.gmatch(text, "[^,%s]+") do
		local id = tonumber(token)
		if id ~= nil then
			id = math.floor(id)
			if id > 0 and not seen[id] then
				seen[id] = true
				result[#result + 1] = id
			end
		end
	end
	return result
end

for groupIndex = 1, totalGroups do
	local header = frame:CreateChildWidget("label", "customRaidGroupHeader" .. tostring(groupIndex), 0, true)
	header:EnablePick(false)
	header:Show(true)
	header.style:SetColor(0.95, 0.75, 0.30, 1)
	header.style:SetOutline(true)
	header.style:SetAlign(ALIGN_LEFT)
	header:SetText(tostring(groupIndex))
	groupHeaders[groupIndex] = header
end

for slotIndex = 1, totalSlots do
	local slotBg = frame:CreateColorDrawable(0.05, 0.23, 0.49, 0.75, "artwork")
	slots[slotIndex] = {
		bg = slotBg,
		icons = {},
		durations = {},
		iconPaths = {},
		activeCount = 0,
	}
end

local function ensureSlotWidgets(slot, index)
	if slot.icons[index] == nil then
		local icon = frame:CreateIconDrawable("artwork")
		icon:SetVisible(false)
		slot.icons[index] = icon
	end

	if slot.durations[index] == nil then
		local durationLabel = frame:CreateChildWidget("label", "customRaidDuration" .. tostring(index), 0, true)
		durationLabel:EnablePick(false)
		durationLabel:Show(false)
		durationLabel.style:SetColor(1, 1, 1, 1)
		durationLabel.style:SetOutline(true)
		durationLabel.style:SetAlign(ALIGN_CENTER)
		durationLabel.style:SetFontSize(11)
		slot.durations[index] = durationLabel
	end

	return slot.icons[index], slot.durations[index]
end

local function hideSlotIcons(slot, fromIndex)
	for i = fromIndex, #slot.icons do
		slot.iconPaths[i] = nil
		slot.icons[i]:ClearAllTextures()
		slot.icons[i]:SetVisible(false)
		slot.durations[i]:SetText("")
		slot.durations[i]:Show(false)
	end
end

local function layoutSlotIcons(slot)
	local count = slot.activeCount or 0
	if count <= 0 then
		hideSlotIcons(slot, 1)
		return
	end

	local iconSize = clamp(state.iconSize, 8, 64)
	local spacing = 2
	local totalWidth = (count * iconSize) + ((count - 1) * spacing)
	local start = -math.floor(totalWidth / 2) + math.floor(iconSize / 2)

	for i = 1, count do
		local icon, durationLabel = ensureSlotWidgets(slot, i)
		local xOffset = start + ((i - 1) * (iconSize + spacing)) + state.iconOffsetX
		local yOffset = state.iconOffsetY

		icon:RemoveAllAnchors()
		icon:AddAnchor("CENTER", slot.bg, xOffset, yOffset)
		icon:SetExtent(iconSize, iconSize)

		durationLabel:RemoveAllAnchors()
		durationLabel:AddAnchor("TOP", icon, 0, 0)
		durationLabel:SetExtent(iconSize + 6, 12)
		if durationLabel.Raise ~= nil then
			durationLabel:Raise()
		end

		if state.showDuration then
			durationLabel:Show(true)
		else
			durationLabel:Show(false)
		end
	end

	if count < #slot.icons then
		hideSlotIcons(slot, count + 1)
	end
end

local function createFrameButton(name, text)
	local button = frame:CreateChildWidget("button", name, 0, true)
	button:SetStyle("text_default")
	button:SetText(text)
	button:SetHeight(22)
	button:SetWidth(68)
	button:Show(true)
	return button
end

controls.box = createFrameButton("customRaidBoxButton", "Box")
controls.wider = createFrameButton("customRaidWiderButton", "Wider")
controls.narrower = createFrameButton("customRaidNarrowerButton", "Narrower")
controls.taller = createFrameButton("customRaidTallerButton", "Taller")
controls.shorter = createFrameButton("customRaidShorterButton", "Shorter")
controls.lock = createFrameButton("customRaidLockButton", "Lock")
controls.configure = createFrameButton("customRaidConfigureButton", "Configure")

local configWindow = CreateEmptyWindow("customRaidConfigWindow", "UIParent")
configWindow:AddAnchor("CENTER", "UIParent", 0, 0)
configWindow:SetExtent(420, 340)
configWindow:Show(false)
configWindow:EnableDrag(true)
configWindow:SetUILayer(TOP_LAYER)

local configBg = configWindow:CreateColorDrawable(0.08, 0.06, 0.04, 0.92, "background")
configBg:AddAnchor("TOPLEFT", configWindow, 0, 0)
configBg:AddAnchor("BOTTOMRIGHT", configWindow, 0, 0)

local configTitle = configWindow:CreateChildWidget("label", "customRaidConfigTitle", 0, true)
configTitle:AddAnchor("TOPLEFT", configWindow, 14, 10)
configTitle:SetExtent(280, 24)
configTitle.style:SetOutline(true)
configTitle.style:SetAlign(ALIGN_LEFT)
configTitle.style:SetFontSize(18)
configTitle.style:SetColor(1, 0.97, 0.92, 1)
configTitle:SetText("Custom Raid Configure")

local configClose = configWindow:CreateChildWidget("button", "customRaidConfigClose", 0, true)
configClose:SetStyle("text_default")
configClose:SetText("X")
configClose:SetExtent(30, 24)
configClose:AddAnchor("TOPRIGHT", configWindow, -10, 10)

local configStatus = configWindow:CreateChildWidget("label", "customRaidConfigStatus", 0, true)
configStatus:AddAnchor("TOPLEFT", configWindow, 14, 42)
configStatus:SetExtent(392, 70)
configStatus.style:SetAlign(ALIGN_LEFT)
configStatus.style:SetOutline(true)
configStatus.style:SetFontSize(13)
configStatus.style:SetColor(1, 1, 1, 1)

local function createConfigButton(name, text, x, y, width)
	local button = configWindow:CreateChildWidget("button", name, 0, true)
	button:SetStyle("text_default")
	button:SetText(text)
	button:SetExtent(width or 90, 24)
	button:AddAnchor("TOPLEFT", configWindow, x, y)
	return button
end

local iconBiggerBtn = createConfigButton("customRaidIconBigger", "Icon +", 14, 120, 70)
local iconSmallerBtn = createConfigButton("customRaidIconSmaller", "Icon -", 90, 120, 70)
local moveLeftBtn = createConfigButton("customRaidMoveLeft", "Left", 170, 120, 60)
local moveRightBtn = createConfigButton("customRaidMoveRight", "Right", 236, 120, 60)
local moveUpBtn = createConfigButton("customRaidMoveUp", "Up", 302, 120, 50)
local moveDownBtn = createConfigButton("customRaidMoveDown", "Down", 358, 120, 50)

local durationBtn = createConfigButton("customRaidDurationToggle", "Duration: OFF", 14, 152, 140)

local buffIdLabel = configWindow:CreateChildWidget("label", "customRaidBuffIdLabel", 0, true)
buffIdLabel:AddAnchor("TOPLEFT", configWindow, 14, 190)
buffIdLabel:SetExtent(392, 18)
buffIdLabel.style:SetAlign(ALIGN_LEFT)
buffIdLabel.style:SetOutline(true)
buffIdLabel.style:SetFontSize(12)
buffIdLabel.style:SetColor(0.95, 0.90, 0.78, 1)
buffIdLabel:SetText("Tracked buff IDs (comma-separated):")

local function createLocalEditBox(parent, id, width)
	local edit = parent:CreateChildWidgetByType(UOT_X2_EDITBOX, id, 0, true)
	edit:SetHeight(26)
	edit:SetWidth(width)
	edit:SetInset(5, 5, 5, 5)
	edit:EnableFocus(true)
	edit:UseSelectAllWhenFocused(true)
	edit.style:SetAlign(ALIGN_LEFT)
	edit.style:SetColorByKey("title")

	local bg = edit:CreateDrawable("ui/common/default.dds", "editbox_df", "background")
	if bg ~= nil and bg.AddAnchor ~= nil then
		bg:AddAnchor("TOPLEFT", edit, 0, 0)
		bg:AddAnchor("BOTTOMRIGHT", edit, 0, 0)
	end
	return edit
end

local buffIdEdit = createLocalEditBox(configWindow, "customRaidBuffIdEdit", 300)
buffIdEdit:AddAnchor("TOPLEFT", configWindow, 14, 212)

local buffIdApplyBtn = createConfigButton("customRaidApplyIds", "Apply IDs", 322, 212, 86)

local helpLabel = configWindow:CreateChildWidget("label", "customRaidHelp", 0, true)
helpLabel:AddAnchor("TOPLEFT", configWindow, 14, 248)
helpLabel:SetExtent(392, 78)
helpLabel.style:SetAlign(ALIGN_LEFT)
helpLabel.style:SetOutline(true)
helpLabel.style:SetFontSize(12)
helpLabel.style:SetColor(0.85, 0.87, 0.92, 1)
helpLabel:SetText(
	"Example: 30098,30768,30770"
)

local function refreshConfigUi()
	configStatus:SetText(
		string.format(
			"Icon Size: %d\nIcon Offset X: %d   Y: %d\nShow Duration: %s",
			state.iconSize,
			state.iconOffsetX,
			state.iconOffsetY,
			state.showDuration and "ON" or "OFF"
		)
	)
	durationBtn:SetText(state.showDuration and "Duration: ON" or "Duration: OFF")
	buffIdEdit:SetText(trackedIdsToString())
end

local function applyLockState()
	frame:EnableDrag(not state.locked)
	if state.locked then
		if frame.EnablePick ~= nil then
			frame:EnablePick(false, true)
		end
		if frame.Clickable ~= nil then
			frame:Clickable(false, true)
		end
	else
		if frame.EnablePick ~= nil then
			frame:EnablePick(true, true)
		end
		if frame.Clickable ~= nil then
			frame:Clickable(true, true)
		end
	end
	controls.lock:SetText(state.locked and "Unlock" or "Lock")
end

local function applyGridVisibility()
	background:SetVisible(showGrid)
	for i = 1, totalGroups do
		groupHeaders[i]:Show(showGrid)
	end
	for i = 1, totalSlots do
		slots[i].bg:SetVisible(showGrid)
	end
	controls.wider:Show(showGrid)
	controls.narrower:Show(showGrid)
	controls.taller:Show(showGrid)
	controls.shorter:Show(showGrid)
	controls.lock:Show(showGrid)
	controls.configure:Show(showGrid)
	if frameLockButton ~= nil then
		frameLockButton:Show(true)
	end
	if frameToggleButton ~= nil then
		frameToggleButton:Show(true)
	end
	controls.box:Show(true)
end

local function layoutControls()
	local controlPad = 8
	local controlGap = 6
	local rowGap = 4

	controls.wider:RemoveAllAnchors()
	controls.wider:AddAnchor("TOPLEFT", frame, "BOTTOMLEFT", controlPad, 8)

	controls.narrower:RemoveAllAnchors()
	controls.narrower:AddAnchor("LEFT", controls.wider, "RIGHT", controlGap, 0)

	controls.taller:RemoveAllAnchors()
	controls.taller:AddAnchor("LEFT", controls.narrower, "RIGHT", controlGap, 0)

	controls.shorter:RemoveAllAnchors()
	controls.shorter:AddAnchor("LEFT", controls.taller, "RIGHT", controlGap, 0)

	controls.box:RemoveAllAnchors()
	controls.box:AddAnchor("TOPLEFT", controls.wider, "BOTTOMLEFT", 0, rowGap)

	controls.lock:RemoveAllAnchors()
	controls.lock:AddAnchor("LEFT", controls.box, "RIGHT", controlGap, 0)

	controls.configure:RemoveAllAnchors()
	controls.configure:AddAnchor("LEFT", controls.lock, "RIGHT", controlGap, 0)
end

local function applyLayout()
	frame:RemoveAllAnchors()
	frame:AddAnchor("TOPLEFT", "UIParent", state.x, state.y)
	frame:SetExtent(state.width, state.height)

	local outerPad = 10
	local rowGap = 20
	local groupGap = 6
	local headerHeight = 16
	local memberGap = 2

	local contentWidth = state.width - (outerPad * 2)
	local groupWidth = math.floor((contentWidth - (groupGap * (groupsPerRow - 1))) / groupsPerRow)
	groupWidth = math.max(30, groupWidth)

	local contentHeight = state.height - (outerPad * 2)
	local rowHeight = math.floor((contentHeight - rowGap) / 2)
	rowHeight = math.max(50, rowHeight)

	local slotHeight = math.floor((rowHeight - headerHeight - (memberGap * (membersPerGroup - 1))) / membersPerGroup)
	slotHeight = math.max(10, slotHeight)

	for groupIndex = 1, totalGroups do
		local row = math.floor((groupIndex - 1) / groupsPerRow)
		local col = (groupIndex - 1) % groupsPerRow
		local groupX = outerPad + (col * (groupWidth + groupGap))
		local groupY = outerPad + (row * (rowHeight + rowGap))

		local header = groupHeaders[groupIndex]
		header:RemoveAllAnchors()
		header:AddAnchor("TOPLEFT", frame, groupX + 2, groupY)

		for memberIndex = 1, membersPerGroup do
			local slotIndex = ((groupIndex - 1) * membersPerGroup) + memberIndex
			local slot = slots[slotIndex]
			local slotX = groupX
			local slotY = groupY + headerHeight + ((memberIndex - 1) * (slotHeight + memberGap))

			slot.bg:RemoveAllAnchors()
			slot.bg:AddAnchor("TOPLEFT", frame, slotX, slotY)
			slot.bg:SetExtent(groupWidth, slotHeight)
			layoutSlotIcons(slot)
		end
	end

	layoutControls()
	applyGridVisibility()
end

local function getRaidUnitPrefix()
	if X2Unit:UnitName("team_1_1") ~= nil then
		return "team_1_"
	end
	if X2Unit:UnitName("team1") ~= nil then
		return "team"
	end
	return nil
end

local function collectTrackedBuffs(unitId)
	local wanted = {}
	for i = 1, #state.trackedBuffIds do
		wanted[state.trackedBuffIds[i]] = true
	end

	local foundById = {}
	local buffCount = X2Unit:UnitBuffCount(unitId) or 0
	for i = 1, buffCount do
		local buffExtra = X2Unit:UnitBuff(unitId, i)
		if type(buffExtra) == "table" then
			local buffId = tonumber(buffExtra["buff_id"])
			if buffId ~= nil and wanted[buffId] then
				local iconPath = SPECIAL_ICON_PATHS[buffId] or buffExtra["path"] or ""
				local durationText = ""
				local tooltip = X2Unit:UnitBuffTooltip(unitId, i)
				if type(tooltip) == "table" then
					durationText = formatDuration(tooltip["timeLeft"] and math.floor(tooltip["timeLeft"] / 1000) or nil)
				end
				foundById[buffId] = {
					iconPath = iconPath,
					durationText = durationText,
				}
			end
		end
	end

	local ordered = {}
	for i = 1, #state.trackedBuffIds do
		local id = state.trackedBuffIds[i]
		if foundById[id] ~= nil then
			ordered[#ordered + 1] = foundById[id]
		end
	end
	return ordered
end

local function clearSlot(slot)
	slot.activeCount = 0
	hideSlotIcons(slot, 1)
end

local function updateSlotIcons(slot, entries)
	local count = #entries
	slot.activeCount = count
	for i = 1, count do
		local icon, durationLabel = ensureSlotWidgets(slot, i)
		local iconPath = entries[i].iconPath
		if slot.iconPaths[i] ~= iconPath then
			icon:ClearAllTextures()
			if iconPath ~= nil and iconPath ~= "" then
				icon:AddTexture(iconPath)
			end
			slot.iconPaths[i] = iconPath
		end
		icon:SetVisible(iconPath ~= nil and iconPath ~= "")
		durationLabel:SetText(entries[i].durationText or "")
	end
	layoutSlotIcons(slot)
end

local function refreshRaidBuffs()
	local unitPrefix = getRaidUnitPrefix()
	if unitPrefix == nil then
		for i = 1, totalSlots do
			clearSlot(slots[i])
		end
		return
	end

	for slotIndex = 1, totalSlots do
		local unitId = unitPrefix .. tostring(slotIndex)
		if X2Unit:UnitName(unitId) ~= nil then
			updateSlotIcons(slots[slotIndex], collectTrackedBuffs(unitId))
		else
			clearSlot(slots[slotIndex])
		end
	end
end

function frame:OnDragStart()
	self:StartMoving()
end
frame:SetHandler("OnDragStart", frame.OnDragStart)

function frame:OnDragStop()
	self:StopMovingOrSizing()
	local offsetX, offsetY = self:GetOffset()
	if offsetX ~= nil and offsetY ~= nil then
		state.x = math.floor(offsetX)
		state.y = math.floor(offsetY)
		saveState()
	end
end
frame:SetHandler("OnDragStop", frame.OnDragStop)

local function resizeFromWheel(direction)
	if X2Input:IsControlKeyDown() then
		state.width = clamp(state.width + (direction * WIDTH_STEP), 180, 900)
		applyLayout()
		saveState()
		return
	end

	if X2Input:IsShiftKeyDown() then
		state.height = clamp(state.height + (direction * HEIGHT_STEP), 220, 1200)
		applyLayout()
		saveState()
	end
end

function frame:OnWheelUp(delta)
	resizeFromWheel(1)
end
frame:SetHandler("OnWheelUp", frame.OnWheelUp)

function frame:OnWheelDown(delta)
	resizeFromWheel(-1)
end
frame:SetHandler("OnWheelDown", frame.OnWheelDown)

function configWindow:OnDragStart()
	self:StartMoving()
	return true
end
configWindow:SetHandler("OnDragStart", configWindow.OnDragStart)

function configWindow:OnDragStop()
	self:StopMovingOrSizing()
end
configWindow:SetHandler("OnDragStop", configWindow.OnDragStop)

function configClose:OnClick()
	configWindow:Show(false)
end
configClose:SetHandler("OnClick", configClose.OnClick)

function iconBiggerBtn:OnClick()
	state.iconSize = clamp(state.iconSize + ICON_SIZE_STEP, 8, 64)
	applyLayout()
	refreshRaidBuffs()
	refreshConfigUi()
	saveState()
end
iconBiggerBtn:SetHandler("OnClick", iconBiggerBtn.OnClick)

function iconSmallerBtn:OnClick()
	state.iconSize = clamp(state.iconSize - ICON_SIZE_STEP, 8, 64)
	applyLayout()
	refreshRaidBuffs()
	refreshConfigUi()
	saveState()
end
iconSmallerBtn:SetHandler("OnClick", iconSmallerBtn.OnClick)

function moveLeftBtn:OnClick()
	state.iconOffsetX = state.iconOffsetX - ICON_OFFSET_STEP
	applyLayout()
	refreshRaidBuffs()
	refreshConfigUi()
	saveState()
end
moveLeftBtn:SetHandler("OnClick", moveLeftBtn.OnClick)

function moveRightBtn:OnClick()
	state.iconOffsetX = state.iconOffsetX + ICON_OFFSET_STEP
	applyLayout()
	refreshRaidBuffs()
	refreshConfigUi()
	saveState()
end
moveRightBtn:SetHandler("OnClick", moveRightBtn.OnClick)

function moveUpBtn:OnClick()
	state.iconOffsetY = state.iconOffsetY - ICON_OFFSET_STEP
	applyLayout()
	refreshRaidBuffs()
	refreshConfigUi()
	saveState()
end
moveUpBtn:SetHandler("OnClick", moveUpBtn.OnClick)

function moveDownBtn:OnClick()
	state.iconOffsetY = state.iconOffsetY + ICON_OFFSET_STEP
	applyLayout()
	refreshRaidBuffs()
	refreshConfigUi()
	saveState()
end
moveDownBtn:SetHandler("OnClick", moveDownBtn.OnClick)

function durationBtn:OnClick()
	state.showDuration = not state.showDuration
	applyLayout()
	refreshRaidBuffs()
	refreshConfigUi()
	saveState()
end
durationBtn:SetHandler("OnClick", durationBtn.OnClick)

local function applyBuffIdsFromEdit()
	local parsed = parseTrackedIds(buffIdEdit:GetText() or "")
	if #parsed == 0 then
		X2Chat:DispatchChatMessage(CMF_SYSTEM, "CustomRaid: enter at least one numeric buff ID.")
		return
	end
	state.trackedBuffIds = parsed
	refreshConfigUi()
	refreshRaidBuffs()
	saveState()
end

function buffIdApplyBtn:OnClick()
	applyBuffIdsFromEdit()
end
buffIdApplyBtn:SetHandler("OnClick", buffIdApplyBtn.OnClick)
buffIdEdit:SetHandler("OnEnterPressed", applyBuffIdsFromEdit)

function controls.box:OnClick()
	showGrid = not showGrid
	applyGridVisibility()
end
controls.box:SetHandler("OnClick", controls.box.OnClick)

function controls.wider:OnClick()
	state.width = clamp(state.width + WIDTH_STEP, 180, 900)
	applyLayout()
	saveState()
end
controls.wider:SetHandler("OnClick", controls.wider.OnClick)

function controls.narrower:OnClick()
	state.width = clamp(state.width - WIDTH_STEP, 180, 900)
	applyLayout()
	saveState()
end
controls.narrower:SetHandler("OnClick", controls.narrower.OnClick)

function controls.taller:OnClick()
	state.height = clamp(state.height + HEIGHT_STEP, 220, 1200)
	applyLayout()
	saveState()
end
controls.taller:SetHandler("OnClick", controls.taller.OnClick)

function controls.shorter:OnClick()
	state.height = clamp(state.height - HEIGHT_STEP, 220, 1200)
	applyLayout()
	saveState()
end
controls.shorter:SetHandler("OnClick", controls.shorter.OnClick)

function controls.lock:OnClick()
	state.locked = not state.locked
	applyLockState()
	saveState()
end
controls.lock:SetHandler("OnClick", controls.lock.OnClick)

function controls.configure:OnClick()
	refreshConfigUi()
	local shouldShow = not configWindow:IsVisible()
	configWindow:Show(shouldShow)
	if shouldShow then
		configWindow:SetUILayer(TOP_LAYER)
		configWindow:Raise()
	end
end
controls.configure:SetHandler("OnClick", controls.configure.OnClick)

frameToggleButton = CreateSimpleButton("CR Frame", 700, -290)
function frameToggleButton:OnClick()
	frame:Show(not frame:IsVisible())
end
frameToggleButton:SetHandler("OnClick", frameToggleButton.OnClick)

frameLockButton = CreateSimpleButton("CR Lock", 790, -290)
function frameLockButton:OnClick()
	state.locked = not state.locked
	applyLockState()
	saveState()
end
frameLockButton:SetHandler("OnClick", frameLockButton.OnClick)

local elapsed = 0
local raiseElapsed = 0
function frame:OnUpdate(dt)
	local delta = tonumber(dt) or 0
	elapsed = elapsed + delta
	raiseElapsed = raiseElapsed + delta
	if raiseElapsed >= 200 then
		raiseElapsed = 0
		if frame:IsVisible() then
			frame:SetUILayer(TOP_LAYER)
			frame:Raise()
		end
		if configWindow:IsVisible() then
			configWindow:SetUILayer(TOP_LAYER)
			configWindow:Raise()
		end
	end
	if elapsed < 50 then
		return
	end
	elapsed = 0
	refreshRaidBuffs()
end
frame:SetHandler("OnUpdate", frame.OnUpdate)

applyLayout()
refreshConfigUi()
refreshRaidBuffs()
applyLockState()
