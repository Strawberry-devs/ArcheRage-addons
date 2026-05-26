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

ADDON:ImportObject(OBJECT_TYPE.TEXT_STYLE)
ADDON:ImportObject(OBJECT_TYPE.BUTTON)
ADDON:ImportObject(OBJECT_TYPE.DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.NINE_PART_DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.COLOR_DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.WINDOW)
ADDON:ImportObject(OBJECT_TYPE.LABEL)
ADDON:ImportObject(OBJECT_TYPE.ICON_DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.IMAGE_DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.STATUS_BAR)

ADDON:ImportAPI(API_TYPE.CHAT.id)
ADDON:ImportAPI(API_TYPE.UNIT.id)

-- ============================================================
-- Constants
-- ============================================================
local WINDOW_W        = 300
local ROW_H           = 24
local HEADER_H        = 30
local MAX_ROWS        = 10
local MAX_DETAIL_ROWS = 15
local PAD             = 4
local RESET_TIMEOUT   = 10    -- seconds of no damage before fight is over
local UPDATE_MS       = 500   -- ms between display refreshes
local SELF_NAME 	  = X2Unit:UnitName("player")
local MODE_ORDER      = { "Damage", "DamageT", "Heal", "HealT" }
local MODE_RATE_LABEL = {
	Damage = "dps",
	DamageT = "dtps",
	Heal = "hps",
	HealT = "htps"
}
local SETTINGS_FILE = "dpsmeter_settings.txt"
local TITLE_PAD_RIGHT = 140
local DETAIL_TITLE_PAD_RIGHT = 80
local DETAIL_VIEW_ORDER = { "Spell", "Target" }
local NAME_COL_RATIO = 0.50
local VALUE_COL_RATIO = 0.46
local VALUE_MIN_W = 95
local VALUE_RIGHT_PAD = 22
local DEFAULT_MAIN_X = 100
local DEFAULT_MAIN_Y = 200
local DEFAULT_DETAIL_X = DEFAULT_MAIN_X + WINDOW_W + 8
local DEFAULT_DETAIL_Y = DEFAULT_MAIN_Y
local MIN_MAIN_W = 220
local MIN_MAIN_H = HEADER_H + ROW_H + PAD * 2
local MIN_DETAIL_W = 240
local MIN_DETAIL_H = HEADER_H + ROW_H + PAD * 2

-- ============================================================
-- Fight state
-- ============================================================
local statsByMode = {
	Damage = {},
	DamageT = {},
	Heal = {},
	HealT = {}
}
local activeModeIndex = 1
local activeMode = MODE_ORDER[activeModeIndex]
local detailViewIndex = 1
local detailViewMode = DETAIL_VIEW_ORDER[detailViewIndex]
local combatStart = nil
local lastHitTime = nil
local fightDone   = false
local fightElapsed = 0
local saveCurrentSettings -- forward declaration; assigned after windows are created
local miniButton -- forward declaration; assigned after main window buttons are created
local detailFrame -- forward declaration; assigned when the detail window is created
local positionMiniButtonNearHide -- forward declaration; assigned after mini button is created

local function findIndex(list, value, fallback)
	for i = 1, #list do
		if list[i] == value then
			return i
		end
	end
	return fallback
end

local function clampMin(value, minValue)
	if value < minValue then
		return minValue
	end
	return value
end

local function loadSettings()
	local settings = {
		main_x = DEFAULT_MAIN_X,
		main_y = DEFAULT_MAIN_Y,
		main_w = WINDOW_W,
		main_h = HEADER_H + MAX_ROWS * ROW_H + PAD * 2,
		detail_x = DEFAULT_DETAIL_X,
		detail_y = DEFAULT_DETAIL_Y,
		detail_w = 320,
		detail_h = HEADER_H + MAX_DETAIL_ROWS * ROW_H + PAD * 2,
		active_mode = MODE_ORDER[1],
		detail_view = DETAIL_VIEW_ORDER[1],
		is_hidden = 0,
		mini_x = DEFAULT_MAIN_X,
		mini_y = DEFAULT_MAIN_Y
	}

	local file = io.open(SETTINGS_FILE, "r")
	if not file then
		return settings
	end

	for line in file:lines() do
		local key, value = line:match("^([%w_]+)=(.+)$")
		if key and value then
			if key == "active_mode" or key == "detail_view" then
				settings[key] = value
			else
				local numValue = tonumber(value)
				if numValue then
					settings[key] = numValue
				end
			end
		end
	end
	file:close()

	settings.main_w = clampMin(settings.main_w, MIN_MAIN_W)
	settings.main_h = clampMin(settings.main_h, MIN_MAIN_H)
	settings.detail_w = clampMin(settings.detail_w, MIN_DETAIL_W)
	settings.detail_h = clampMin(settings.detail_h, MIN_DETAIL_H)
	return settings
end

local loadedSettings = loadSettings()
activeModeIndex = findIndex(MODE_ORDER, loadedSettings.active_mode, 1)
activeMode = MODE_ORDER[activeModeIndex]
detailViewIndex = findIndex(DETAIL_VIEW_ORDER, loadedSettings.detail_view, 1)
detailViewMode = DETAIL_VIEW_ORDER[detailViewIndex]
local isMeterHidden = loadedSettings.is_hidden == 1

local function resetFight()
	statsByMode.Damage  = {}
	statsByMode.DamageT = {}
	statsByMode.Heal    = {}
	statsByMode.HealT   = {}
	combatStart  = nil
	lastHitTime  = nil
	fightDone    = false
	fightElapsed = 0
end

local function getActiveStats()
	return statsByMode[activeMode]
end

local function cycleActiveMode()
	activeModeIndex = activeModeIndex + 1
	if activeModeIndex > #MODE_ORDER then
		activeModeIndex = 1
	end
	activeMode = MODE_ORDER[activeModeIndex]
	if saveCurrentSettings then
		saveCurrentSettings()
	end
end

local function cycleDetailViewMode()
	detailViewIndex = detailViewIndex + 1
	if detailViewIndex > #DETAIL_VIEW_ORDER then
		detailViewIndex = 1
	end
	detailViewMode = DETAIL_VIEW_ORDER[detailViewIndex]
	if saveCurrentSettings then
		saveCurrentSettings()
	end
end

local function addStat(modeKey, playerName, abilityName, amount, counterpartName)
	if playerName == nil or playerName == "" or amount < 1 then
		return
	end

	if statsByMode[modeKey][playerName] == nil then
		statsByMode[modeKey][playerName] = { damage = 0, abilities = {}, targets = {} }
	end

	local counterpartKey = (counterpartName and counterpartName ~= "") and counterpartName or "Unknown"
	local p = statsByMode[modeKey][playerName]
	p.damage = p.damage + amount
	p.abilities[abilityName] = (p.abilities[abilityName] or 0) + amount
	p.targets[counterpartKey] = (p.targets[counterpartKey] or 0) + amount
end

-- ============================================================
-- Main window
-- ============================================================
local TOTAL_H = HEADER_H + MAX_ROWS * ROW_H + PAD * 2

local mainFrame = CreateEmptyWindow("dpsMeterWindow", "UIParent")
mainFrame:SetExtent(loadedSettings.main_w, loadedSettings.main_h)
mainFrame:AddAnchor("TOPLEFT", "UIParent", loadedSettings.main_x, loadedSettings.main_y)
mainFrame:Show(not isMeterHidden)
mainFrame:EnableDrag(true)

mainFrame:SetHandler("OnDragStart", function(self)
	self:StartMoving()
	return true
end)
mainFrame:SetHandler("OnDragStop", function(self)
	self:StopMovingOrSizing()
	if saveCurrentSettings then
		saveCurrentSettings()
	end
end)

local bg = mainFrame:CreateColorDrawable(0.05, 0.05, 0.05, 0.88, "background")
bg:AddAnchor("TOPLEFT", mainFrame, 0, 0)
bg:AddAnchor("BOTTOMRIGHT", mainFrame, 0, 0)

local headerBg = mainFrame:CreateColorDrawable(0.1, 0.15, 0.3, 0.95, "background")
headerBg:SetExtent(WINDOW_W, HEADER_H)
headerBg:AddAnchor("TOPLEFT", mainFrame, 0, 0)

local titleLabel = mainFrame:CreateChildWidget("label", "dpsMeterTitle", 0, true)
titleLabel:AddAnchor("TOPLEFT", mainFrame, 6, 8)
titleLabel:SetExtent(WINDOW_W - TITLE_PAD_RIGHT, HEADER_H - 8)
titleLabel:EnablePick(true)
titleLabel.style:SetColor(1, 1, 1, 1)
titleLabel.style:SetFontSize(13)
titleLabel.style:SetAlign(ALIGN_LEFT)
titleLabel:SetText("DPS Meter")
titleLabel:Show(true)
titleLabel:SetHandler("OnClick", function()
	cycleActiveMode()
end)

local resetBtn = mainFrame:CreateChildWidget("button", "dpsResetBtn", 1, true)
resetBtn:SetText("RST")
resetBtn:SetStyle("text_default")
resetBtn:SetExtent(58, HEADER_H - 8)
resetBtn:AddAnchor("TOPRIGHT", mainFrame, -2, 4)
resetBtn:Show(true)
resetBtn:SetHandler("OnClick", function()
	resetFight()
end)

local hideBtn = mainFrame:CreateChildWidget("button", "dpsHideBtn", 1, true)
hideBtn:SetText("Hide")
hideBtn:SetStyle("text_default")
hideBtn:SetExtent(58, HEADER_H - 8)
hideBtn:AddAnchor("TOPRIGHT", resetBtn, "TOPLEFT", -2, 0)
hideBtn:Show(true)
hideBtn:SetHandler("OnClick", function()
	isMeterHidden = true
	if positionMiniButtonNearHide then
		positionMiniButtonNearHide()
	end
	mainFrame:Show(false)
	detailFrame:Show(false)
	if miniButton ~= nil then
		miniButton:Show(true)
	end
	if saveCurrentSettings then
		saveCurrentSettings()
	end
end)

miniButton = UIParent:CreateWidget("button", "dpsMeterMiniButton", "UIParent", "")
miniButton:SetText("dpsmeter")
miniButton:SetStyle("text_default")
miniButton:SetHeight(25)
miniButton:SetWidth(80)
miniButton:AddAnchor("TOPLEFT", "UIParent", loadedSettings.mini_x, loadedSettings.mini_y)
miniButton:Show(isMeterHidden)
miniButton:EnableDrag(true)
miniButton:SetHandler("OnDragStart", function(self)
	self:StartMoving()
	self.moving = true
end)
miniButton:SetHandler("OnDragStop", function(self)
	self:StopMovingOrSizing()
	self.moving = false
	if saveCurrentSettings then
		saveCurrentSettings()
	end
end)
miniButton:SetHandler("OnClick", function()
	isMeterHidden = false
	mainFrame:Show(true)
	miniButton:Show(false)
	if saveCurrentSettings then
		saveCurrentSettings()
	end
end)

positionMiniButtonNearHide = function()
	if miniButton == nil then
		return
	end

	local mainX, mainY = mainFrame:GetOffset()
	local mainW = mainFrame:GetWidth() or WINDOW_W
	local x = (mainX or 0) + mainW - 120
	local y = (mainY or 0) + 4

	miniButton:RemoveAllAnchors()
	miniButton:AddAnchor("TOPLEFT", "UIParent", x, y)
end

-- ============================================================
-- Main window rows (pre-created, shown/hidden per update)
-- ============================================================
local rows = {}
local showDetailWindow    -- forward declaration; assigned after detail window is built
local updateDetailDisplay -- forward declaration for detail view toggle callback

for i = 1, MAX_ROWS do
	local yOff = HEADER_H + PAD + (i - 1) * ROW_H

	local rowBg = mainFrame:CreateColorDrawable(0.12, 0.12, 0.12, 0.75, "background")
	rowBg:SetExtent(WINDOW_W - PAD * 2, ROW_H - 3)
	rowBg:AddAnchor("TOPLEFT", mainFrame, PAD, yOff)

	local bar = UIParent:CreateWidget("statusbar", "dpsMeterBar" .. i, mainFrame)
	bar:AddAnchor("TOPLEFT", mainFrame, PAD, yOff)
	bar:SetExtent(WINDOW_W - PAD * 2, ROW_H - 3)
	bar:SetBarTexture("ui/common/hud.dds", "background")
	bar:SetBarTextureByKey("casting_status_bar")
	bar:SetBarColor(0.2, 0.5, 0.9, 0.85)
	bar:SetOrientation("HORIZONTAL")
	bar:SetMinMaxValues(0, 100)
	bar:SetValue(0)
	bar:Show(false)

	local nameLbl = mainFrame:CreateChildWidget("label", "dpsMeterNameLbl" .. i, 0, true)
	nameLbl:AddAnchor("TOPLEFT", bar, 5, 4)
	nameLbl:SetExtent((WINDOW_W - PAD * 2 - 10) * NAME_COL_RATIO, ROW_H - 4)
	nameLbl:EnablePick(true)
	nameLbl:Raise()
	nameLbl.style:SetColor(1, 1, 1, 1)
	nameLbl.style:SetFontSize(11)
	nameLbl.style:SetOutline(true)
	nameLbl.style:SetAlign(ALIGN_LEFT)
	nameLbl:SetText("")
	nameLbl:Show(false)

	local valueLbl = mainFrame:CreateChildWidget("label", "dpsMeterValueLbl" .. i, 0, true)
	valueLbl:AddAnchor("TOPRIGHT", bar, -VALUE_RIGHT_PAD, 4)
	valueLbl:SetExtent(math.max((WINDOW_W - PAD * 2 - 10) * VALUE_COL_RATIO, VALUE_MIN_W), ROW_H - 4)
	valueLbl:EnablePick(true)
	valueLbl:Raise()
	valueLbl.style:SetColor(1, 1, 1, 1)
	valueLbl.style:SetFontSize(11)
	valueLbl.style:SetOutline(true)
	valueLbl.style:SetAlign(ALIGN_RIGHT)
	valueLbl:SetText("")
	valueLbl:Show(false)

	local rowIdx = i
	local onRowClick = function()
		if rows[rowIdx].currentPlayer and showDetailWindow then
			showDetailWindow(rows[rowIdx].currentPlayer)
		end
	end
	nameLbl:SetHandler("OnClick", onRowClick)
	valueLbl:SetHandler("OnClick", onRowClick)

	rows[i] = { bar = bar, nameLabel = nameLbl, valueLabel = valueLbl, rowBg = rowBg, currentPlayer = nil }
end

-- ============================================================
-- Resize handle (bottom-right corner)
-- ============================================================
local resizeHandle = mainFrame:CreateChildWidget("button", "dpsResizeHandle", 0, true)
resizeHandle:SetExtent(14, 14)
resizeHandle:AddAnchor("BOTTOMRIGHT", mainFrame, -2, -2)
resizeHandle:EnableDrag(true)
resizeHandle:Show(true)

local resizeIcon = resizeHandle:CreateColorDrawable(0.55, 0.55, 0.55, 0.85, "background")
resizeIcon:AddAnchor("TOPLEFT", resizeHandle, 0, 0)
resizeIcon:AddAnchor("BOTTOMRIGHT", resizeHandle, 0, 0)

resizeHandle:SetHandler("OnDragStart", function(self)
	mainFrame:StartSizing("BOTTOMRIGHT")
	return true
end)
resizeHandle:SetHandler("OnDragStop", function(self)
	mainFrame:StopMovingOrSizing()
	if saveCurrentSettings then
		saveCurrentSettings()
	end
end)

-- ============================================================
-- Detail window (ability breakdown per player)
-- ============================================================
local DETAIL_W     = 320
local DETAIL_H     = HEADER_H + MAX_DETAIL_ROWS * ROW_H + PAD * 2
local detailPlayer = nil

detailFrame = CreateEmptyWindow("dpsMeterDetailWindow", "UIParent")
detailFrame:SetExtent(loadedSettings.detail_w, loadedSettings.detail_h)
detailFrame:AddAnchor("TOPLEFT", "UIParent", loadedSettings.detail_x, loadedSettings.detail_y)
detailFrame:Show(false)
detailFrame:EnableDrag(true)

detailFrame:SetHandler("OnDragStart", function(self)
	self:StartMoving()
	return true
end)
detailFrame:SetHandler("OnDragStop", function(self)
	self:StopMovingOrSizing()
	if saveCurrentSettings then
		saveCurrentSettings()
	end
end)

local detailBg = detailFrame:CreateColorDrawable(0.05, 0.05, 0.05, 0.88, "background")
detailBg:AddAnchor("TOPLEFT", detailFrame, 0, 0)
detailBg:AddAnchor("BOTTOMRIGHT", detailFrame, 0, 0)

local detailHeaderBg = detailFrame:CreateColorDrawable(0.2, 0.1, 0.3, 0.95, "background")
detailHeaderBg:SetExtent(DETAIL_W, HEADER_H)
detailHeaderBg:AddAnchor("TOPLEFT", detailFrame, 0, 0)

local detailTitle = detailFrame:CreateChildWidget("label", "dpsMeterDetailTitle", 0, true)
detailTitle:AddAnchor("TOPLEFT", detailFrame, 6, 8)
detailTitle:SetExtent(DETAIL_W - DETAIL_TITLE_PAD_RIGHT, HEADER_H - 8)
detailTitle:EnablePick(true)
detailTitle.style:SetColor(1, 1, 1, 1)
detailTitle.style:SetFontSize(13)
detailTitle.style:SetAlign(ALIGN_LEFT)
detailTitle:SetText("Breakdown")
detailTitle:Show(true)
detailTitle:SetHandler("OnClick", function()
	cycleDetailViewMode()
	updateDetailDisplay()
end)

local closeBtn = detailFrame:CreateChildWidget("button", "dpsMeterCloseBtn", 1, true)
closeBtn:SetText("X")
closeBtn:SetStyle("text_default")
closeBtn:SetExtent(58, HEADER_H - 8)
closeBtn:AddAnchor("TOPRIGHT", detailFrame, -2, 4)
closeBtn:Show(true)
closeBtn:SetHandler("OnClick", function()
	detailFrame:Show(false)
	detailPlayer = nil
end)

local detailRows = {}
for i = 1, MAX_DETAIL_ROWS do
	local yOff = HEADER_H + PAD + (i - 1) * ROW_H

	local rowBg = detailFrame:CreateColorDrawable(0.12, 0.12, 0.12, 0.75, "background")
	rowBg:SetExtent(DETAIL_W - PAD * 2, ROW_H - 3)
	rowBg:AddAnchor("TOPLEFT", detailFrame, PAD, yOff)

	local bar = UIParent:CreateWidget("statusbar", "dpsMeterDetailBar" .. i, detailFrame)
	bar:AddAnchor("TOPLEFT", detailFrame, PAD, yOff)
	bar:SetExtent(DETAIL_W - PAD * 2, ROW_H - 3)
	bar:SetBarTexture("ui/common/hud.dds", "background")
	bar:SetBarTextureByKey("casting_status_bar")
	bar:SetBarColor(0.5, 0.2, 0.8, 0.85)
	bar:SetOrientation("HORIZONTAL")
	bar:SetMinMaxValues(0, 100)
	bar:SetValue(0)
	bar:Show(false)

	local nameLbl = detailFrame:CreateChildWidget("label", "dpsMeterDetailNameLbl" .. i, 0, true)
	nameLbl:AddAnchor("TOPLEFT", bar, 5, 4)
	nameLbl:SetExtent((DETAIL_W - PAD * 2 - 10) * NAME_COL_RATIO, ROW_H - 4)
	nameLbl:EnablePick(false)
	nameLbl:Raise()
	nameLbl.style:SetColor(1, 1, 1, 1)
	nameLbl.style:SetFontSize(11)
	nameLbl.style:SetOutline(true)
	nameLbl.style:SetAlign(ALIGN_LEFT)
	nameLbl:SetText("")
	nameLbl:Show(false)

	local valueLbl = detailFrame:CreateChildWidget("label", "dpsMeterDetailValueLbl" .. i, 0, true)
	valueLbl:AddAnchor("TOPRIGHT", bar, -VALUE_RIGHT_PAD, 4)
	valueLbl:SetExtent(math.max((DETAIL_W - PAD * 2 - 10) * VALUE_COL_RATIO, VALUE_MIN_W), ROW_H - 4)
	valueLbl:EnablePick(false)
	valueLbl:Raise()
	valueLbl.style:SetColor(1, 1, 1, 1)
	valueLbl.style:SetFontSize(11)
	valueLbl.style:SetOutline(true)
	valueLbl.style:SetAlign(ALIGN_RIGHT)
	valueLbl:SetText("")
	valueLbl:Show(false)

	detailRows[i] = { bar = bar, nameLabel = nameLbl, valueLabel = valueLbl, rowBg = rowBg }
end

-- Detail window resize handle
local detailResizeHandle = detailFrame:CreateChildWidget("button", "dpsDetailResizeHandle", 0, true)
detailResizeHandle:SetExtent(14, 14)
detailResizeHandle:AddAnchor("BOTTOMRIGHT", detailFrame, -2, -2)
detailResizeHandle:EnableDrag(true)
detailResizeHandle:Show(true)

local detailResizeIcon = detailResizeHandle:CreateColorDrawable(0.55, 0.55, 0.55, 0.85, "background")
detailResizeIcon:AddAnchor("TOPLEFT", detailResizeHandle, 0, 0)
detailResizeIcon:AddAnchor("BOTTOMRIGHT", detailResizeHandle, 0, 0)

detailResizeHandle:SetHandler("OnDragStart", function(self)
	detailFrame:StartSizing("BOTTOMRIGHT")
	return true
end)
detailResizeHandle:SetHandler("OnDragStop", function(self)
	detailFrame:StopMovingOrSizing()
	if saveCurrentSettings then
		saveCurrentSettings()
	end
end)

local function getUIScaleFactor()
	return UIParent:GetUIScale() or 1.0
end

saveCurrentSettings = function()
	local mainX, mainY = mainFrame:GetOffset()
	local detailX, detailY = detailFrame:GetOffset()
	local miniX, miniY = miniButton:GetOffset()
	local uiScale = getUIScaleFactor()

	-- Save normalized offsets so positions remain stable with UI scale changes.
	mainX = math.floor((mainX or 0) / uiScale)
	mainY = math.floor((mainY or 0) / uiScale)
	detailX = math.floor((detailX or 0) / uiScale)
	detailY = math.floor((detailY or 0) / uiScale)
	miniX = math.floor((miniX or 0) / uiScale)
	miniY = math.floor((miniY or 0) / uiScale)

	local file = io.open(SETTINGS_FILE, "w")
	if not file then
		return
	end

	file:write(string.format("main_x=%d\n", mainX))
	file:write(string.format("main_y=%d\n", mainY))
	file:write(string.format("main_w=%d\n", math.floor(mainFrame:GetWidth() or WINDOW_W)))
	file:write(string.format("main_h=%d\n", math.floor(mainFrame:GetHeight() or TOTAL_H)))
	file:write(string.format("detail_x=%d\n", detailX))
	file:write(string.format("detail_y=%d\n", detailY))
	file:write(string.format("detail_w=%d\n", math.floor(detailFrame:GetWidth() or DETAIL_W)))
	file:write(string.format("detail_h=%d\n", math.floor(detailFrame:GetHeight() or DETAIL_H)))
	file:write(string.format("active_mode=%s\n", activeMode))
	file:write(string.format("detail_view=%s\n", detailViewMode))
	file:write(string.format("is_hidden=%d\n", isMeterHidden and 1 or 0))
	file:write(string.format("mini_x=%d\n", miniX))
	file:write(string.format("mini_y=%d\n", miniY))
	file:close()
end

-- ============================================================
-- Display helpers
-- ============================================================
local function formatNum(n)
	if n >= 1000000 then
		return string.format("%.1fM", n / 1000000)
	elseif n >= 1000 then
		return string.format("%.1fk", n / 1000)
	end
	return string.format("%d", math.floor(n))
end

local function truncateLabel(text, maxChars)
	text = tostring(text or "")
	if utf8 and utf8.len and utf8.offset then
		local len = utf8.len(text)
		if len and len > maxChars then
			local cut = utf8.offset(text, maxChars + 1)
			if cut then
				return string.sub(text, 1, cut - 1) .. "..."
			end
		end
		return text
	end

	if string.len(text) > maxChars then
		return string.sub(text, 1, maxChars) .. "..."
	end
	return text
end

updateDetailDisplay = function()
	local modeStats = getActiveStats()
	if not detailPlayer or not modeStats[detailPlayer] then
		detailTitle:SetText(string.format("(%s/%s)", activeMode, detailViewMode))
		for i = 1, MAX_DETAIL_ROWS do
			detailRows[i].bar:Show(false)
			detailRows[i].rowBg:SetVisible(false)
			detailRows[i].nameLabel:Show(false)
			detailRows[i].valueLabel:Show(false)
		end
		return
	end

	-- Sync widths to current detail window size
	local dWinW = detailFrame:GetWidth()
	local dBarW = dWinW - PAD * 2
	detailHeaderBg:SetExtent(dWinW, HEADER_H)
	detailTitle:SetExtent(dWinW - DETAIL_TITLE_PAD_RIGHT, HEADER_H - 8)
	for i = 1, MAX_DETAIL_ROWS do
		detailRows[i].rowBg:SetExtent(dBarW, ROW_H - 3)
		detailRows[i].bar:SetExtent(dBarW, ROW_H - 3)
		detailRows[i].nameLabel:SetExtent(math.floor((dBarW - 10) * NAME_COL_RATIO), ROW_H - 4)
		detailRows[i].valueLabel:SetExtent(math.max(math.floor((dBarW - 10) * VALUE_COL_RATIO), VALUE_MIN_W), ROW_H - 4)
	end

	local data = modeStats[detailPlayer]
	detailTitle:SetText(string.format("(%s/%s): %s", activeMode, detailViewMode, detailPlayer))

	local sorted = {}
	local breakdownData = (detailViewMode == "Target") and data.targets or data.abilities
	for keyName, amount in pairs(breakdownData) do
		table.insert(sorted, { name = keyName, damage = amount })
	end
	table.sort(sorted, function(a, b) return a.damage > b.damage end)

	-- How many rows fit in the current detail window height
	local dWinH      = detailFrame:GetHeight()
	local dAvailH    = dWinH - HEADER_H - PAD * 2
	local dMaxVisible = math.max(0, math.floor(dAvailH / ROW_H))

	local numShow = math.min(#sorted, MAX_DETAIL_ROWS, dMaxVisible)
	for i = 1, MAX_DETAIL_ROWS do
		if i <= numShow then
			local entry = sorted[i]
			local pct   = (data.damage > 0) and (entry.damage / data.damage * 100) or 0
			detailRows[i].bar:SetValue(pct)
			detailRows[i].bar:Show(true)
			detailRows[i].rowBg:SetVisible(true)
			detailRows[i].nameLabel:SetText(truncateLabel(entry.name, 20))
			detailRows[i].valueLabel:SetText(string.format("%s  %.0f%%", formatNum(entry.damage), pct))
			detailRows[i].nameLabel:Show(true)
			detailRows[i].valueLabel:Show(true)
		else
			detailRows[i].bar:Show(false)
			detailRows[i].rowBg:SetVisible(false)
			detailRows[i].nameLabel:Show(false)
			detailRows[i].valueLabel:Show(false)
		end
	end
end

showDetailWindow = function(playerName)
	detailPlayer = playerName
	detailFrame:Show(true)
	updateDetailDisplay()
end

local function updateDisplay()
	local now = os.clock()
	local elapsed

	if fightDone then
		elapsed = fightElapsed
	elseif combatStart ~= nil then
		elapsed = now - combatStart
	else
		elapsed = 0
	end

	-- Sync widths to current window size
	local winW = mainFrame:GetWidth()
	local barW = winW - PAD * 2
	headerBg:SetExtent(winW, HEADER_H)
	titleLabel:SetExtent(winW - TITLE_PAD_RIGHT, HEADER_H - 8)
	for i = 1, MAX_ROWS do
		rows[i].rowBg:SetExtent(barW, ROW_H - 3)
		rows[i].bar:SetExtent(barW, ROW_H - 3)
		rows[i].nameLabel:SetExtent(math.floor((barW - 10) * NAME_COL_RATIO), ROW_H - 4)
		rows[i].valueLabel:SetExtent(math.max(math.floor((barW - 10) * VALUE_COL_RATIO), VALUE_MIN_W), ROW_H - 4)
	end

	-- How many rows fit in the current window height
	local winH       = mainFrame:GetHeight()
	local availH     = winH - HEADER_H - PAD * 2
	local maxVisible = math.max(0, math.floor(availH / ROW_H))

	-- Build sorted player list
	local modeStats   = getActiveStats()
	local sorted      = {}
	local totalDamage = 0
	local rateLabel   = MODE_RATE_LABEL[activeMode] or "dps"

	for name, data in pairs(modeStats) do
		local dps = data.damage / math.max(1, elapsed)
		table.insert(sorted, { name = name, dps = dps, damage = data.damage })
		totalDamage = totalDamage + data.damage
	end

	table.sort(sorted, function(a, b) return a.dps > b.dps end)
	for rank, entry in ipairs(sorted) do
		entry.rank = rank
	end

	local maxDps = (#sorted > 0) and sorted[1].dps or 0
	local displayList = {}
	local selfEntry = nil

	for _, entry in ipairs(sorted) do
		if entry.name == SELF_NAME then
			selfEntry = entry
			break
		end
	end
	if selfEntry ~= nil then
		table.insert(displayList, selfEntry)
	end
	for _, entry in ipairs(sorted) do
		if entry.name ~= SELF_NAME then
			table.insert(displayList, entry)
		end
	end

	-- Title
	if elapsed > 0 then
		local suffix = fightDone and " [done]" or ""
		titleLabel:SetText(string.format("[%s]  %.0fs%s", activeMode, elapsed, suffix))
	else
		titleLabel:SetText(string.format("[%s]", activeMode))
	end

	-- Rows
	local numShow = math.min(#displayList, MAX_ROWS, maxVisible)

	for i = 1, MAX_ROWS do
		if i <= numShow then
			local entry  = displayList[i]
			local pct    = (maxDps > 0) and (entry.dps / maxDps * 100) or 0
			local dmgPct = (totalDamage > 0) and (entry.damage / totalDamage * 100) or 0
			local rankLabel

			if entry.rank > MAX_ROWS and entry.name == SELF_NAME then
				rankLabel = "10+"
			else
				rankLabel = tostring(entry.rank)
			end

			if entry.name == SELF_NAME then
				rows[i].bar:SetBarColor(1.0, 0.75, 0.0, 0.9)
			else
				rows[i].bar:SetBarColor(0.2, 0.5, 0.9, 0.85)
			end

			rows[i].bar:SetValue(pct)
			rows[i].bar:Show(true)
			rows[i].rowBg:SetVisible(true)
			rows[i].currentPlayer = entry.name

			rows[i].nameLabel:SetText(string.format(
				"%s. %s", rankLabel, truncateLabel(entry.name, 20)
			))
			rows[i].valueLabel:SetText(string.format("%s %s  %.0f%%", formatNum(entry.dps), rateLabel, dmgPct))
			rows[i].nameLabel:Show(true)
			rows[i].valueLabel:Show(true)
		else
			rows[i].bar:Show(false)
			rows[i].rowBg:SetVisible(false)
			rows[i].nameLabel:Show(false)
			rows[i].valueLabel:Show(false)
			rows[i].currentPlayer = nil
		end
	end

	-- Keep detail window current
	if detailFrame:IsVisible() then
		updateDetailDisplay()
	end
end

-- ============================================================
-- Combat event
-- ============================================================
local function onCombatMsg(unitId, eventType, sourceName, targetName, abilityId, abilityName, damageType, effectType, isActive, more, more2, more3, more4, more5)
	local isMeleeDamage = string.find(eventType, "MELEE_DAMAGE") ~= nil
	local isSpellDamage = string.find(eventType, "SPELL_DAMAGE") ~= nil
	local isSpellHealed = string.find(eventType, "SPELL_HEALED") ~= nil

	if not isMeleeDamage and not isSpellDamage and not isSpellHealed then
		return
	end

	local amount = 0
	local abilityKey
	if abilityName == "HEALTH" then
		abilityName = "Melee"
	end

	if isSpellHealed then
		amount     = math.abs(tonumber(effectType) or 0)
		abilityKey = (abilityName and abilityName ~= "") and abilityName or ("Heal_" .. tostring(abilityId))
	elseif isSpellDamage then
		amount     = math.abs(tonumber(effectType) or 0)
		abilityKey = (abilityName and abilityName ~= "") and abilityName or ("Spell_" .. tostring(abilityId))
	elseif isMeleeDamage then
		amount     = math.abs(tonumber(abilityId) or 0)
		abilityKey = (abilityName and abilityName ~= "") and abilityName or "Melee Attack"
	end

	if amount < 1 then
		return
	end

	local now = os.clock()
	if fightDone or combatStart == nil then
		resetFight()
		combatStart = now
	end
	lastHitTime = now

	if isSpellHealed then
		addStat("Heal", sourceName, abilityKey, amount, targetName)
		addStat("HealT", targetName, abilityKey, amount, sourceName)
	else
		addStat("Damage", sourceName, abilityKey, amount, targetName)
		addStat("DamageT", targetName, abilityKey, amount, sourceName)
	end
end

UIParent:SetEventHandler(UIEVENT_TYPE.COMBAT_MSG, onCombatMsg)

-- ============================================================
-- Update loop
-- ============================================================
local updateTimer = 0

function mainFrame:OnUpdate(dt)
	-- Detect end of fight
	if lastHitTime ~= nil and not fightDone then
		if (os.clock() - lastHitTime) >= RESET_TIMEOUT then
			fightDone    = true
			fightElapsed = lastHitTime - combatStart
		end
	end

	-- Refresh display
	updateTimer = updateTimer + dt
	if updateTimer >= UPDATE_MS then
		updateTimer = 0
		updateDisplay()
	end
end

mainFrame:SetHandler("OnUpdate", mainFrame.OnUpdate)

X2Chat:DispatchChatMessage(CMF_SYSTEM, "DPS Meter loaded.")
