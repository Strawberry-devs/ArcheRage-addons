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
ADDON:ImportObject(OBJECT_TYPE.EDITBOX)
ADDON:ImportObject(OBJECT_TYPE.EDITBOX_MULTILINE)
ADDON:ImportObject(OBJECT_TYPE.ICON_DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.IMAGE_DRAWABLE)

ADDON:ImportAPI(API_TYPE.CHAT.id)
ADDON:ImportAPI(API_TYPE.UNIT.id)
ADDON:ImportAPI(API_TYPE.LOCALE.id)

local TARGET_UNIT = "target"
local ROW_COUNT = 15
local ROW_HEIGHT = 26
local WINDOW_WIDTH = 650
local WINDOW_HEIGHT = 555
local FOCUSED_WINDOW_WIDTH = 340
local FOCUSED_WINDOW_MIN_HEIGHT = 140
local FOCUSED_ROW_TOP = 42
local FOCUSED_ROW_HEIGHT = 26
local FOCUSED_BOTTOM_PADDING = 68
local RAW_ADD_BUTTON_WIDTH = 25
local SAVE_KEY = "targetstats_focused_stats"
local DEBUG_TARGET_STATS = false
local FONT_SIZE = {
	SMALL = FONT_SIZE and FONT_SIZE.MIDDLE or 13,
	MIDDLE = FONT_SIZE and FONT_SIZE.LARGE or 15,
	LARGE = FONT_SIZE and FONT_SIZE.LARGE or 15,
}

local knownUnitInfoKeys = {
	"str",
	"int",
	"dex",
	"spi",
	"sta",
	"melee_dps",
	"melee_min_dps",
	"melee_max_dps",
	"ranged_dps",
	"ranged_min_dps",
	"ranged_max_dps",
	"spell_dps",
	"heal_dps",
	"armor",
	"armor_percentage",
	"magic_resist",
	"magic_resist_percentage",
	"move_speed",
	"move_speed_rate",
	"casting_time",
	"attack_anim_speed",
	"attack_anim_speed_mul",
	"melee_success_rate",
	"melee_critical_rate",
	"melee_critical_bonus",
	"ranged_speed",
	"ranged_success_rate",
	"ranged_critical_rate",
	"ranged_critical_bonus",
	"spell_success_rate",
	"spell_critical_rate",
	"spell_critical_bonus",
	"backattack_melee_damage_mul",
	"backattack_ranged_damage_mul",
	"backattack_spell_damage_mul",
	"melee_damage_mul",
	"ranged_damage_mul",
	"spell_damage_mul",
	"melee_damage_mul_anti_npc",
	"ranged_damage_mul_anti_npc",
	"spell_damage_mul_anti_npc",
	"melee_damage_mul_anti_pc",
	"ranged_damage_mul_anti_pc",
	"spell_damage_mul_anti_pc",
	"ignore_shield_chance",
	"ignore_armor",
	"magic_penetration",
	"melee_parry_rate",
	"block_rate",
	"dodge_rate",
	"flexibility",
	"flexibility_ratio",
	"flexibility_bonus",
	"battle_resist",
	"battle_resist_rate",
	"health_regen",
	"persistent_health_regen",
	"mana_regen",
	"persistent_mana_regen",
	"heal_critical_rate",
	"heal_critical_bonus",
	"heal_mul",
	"heal_damage_mul",
	"heal_mul_only_heal",
	"heal_damage_mul_anti_npc",
	"incoming_heal_mul",
	"incoming_damage_mul_anti_npc",
	"incoming_melee_damage_mul",
	"incoming_melee_damage_val",
	"incoming_melee_damage_add_anti_npc",
	"incoming_ranged_damage_mul",
	"incoming_ranged_damage_val",
	"incoming_ranged_damage_add_anti_npc",
	"incoming_spell_damage_mul",
	"incoming_spell_damage_val",
	"incoming_spell_damage_add_anti_npc",
	"incoming_siege_damage_mul",
	"incoming_siege_damage_val",
	"exp_mul",
	"drop_rate_mul",
	"loot_gold_mul",
	"detect_stealth_range",
	"detect_stealth_range_mul",
	"bulls_eye",
	"bulls_eye_rate",
}

local knownModifierOnlyKeys = {
	"max_health",
	"max_mana",
	"melee_attack_speed_mul",
	"ranged_attack_speed_mul",
	"melee_critical_mul",
	"ranged_critical_mul",
	"spell_critical_mul",
	"spell_damage_critical_mul",
	"spell_damage_critical_bonus",
	"heal_critical_mul",
	"melee_parry_mul",
	"block_mul",
	"dodge_mul",
	"ignore_shield_bonus",
	"ignore_shield_bonus_mul",
}

local customFocusedStats = {}
local hiddenDefaultFocusedStats = {}

local function SaveFocusedStats()
	ADDON:ClearData(SAVE_KEY)
	ADDON:SaveData(SAVE_KEY, {
		custom = customFocusedStats,
		hiddenDefaults = hiddenDefaultFocusedStats,
	})
end

local function LoadFocusedStats()
	local saved = ADDON:LoadData(SAVE_KEY)
	if type(saved) ~= "table" then
		return
	end
	local custom = saved.custom
	if type(custom) ~= "table" then
		custom = saved
	end
	for _, item in ipairs(custom) do
		if type(item) == "table" and item.key ~= nil and item.label ~= nil then
			customFocusedStats[#customFocusedStats + 1] = {
				key = tostring(item.key),
				label = tostring(item.label),
			}
		end
	end
	if type(saved.hiddenDefaults) == "table" then
		for key, value in pairs(saved.hiddenDefaults) do
			if value == true then
				hiddenDefaultFocusedStats[tonumber(key) or key] = true
			end
		end
	end
end

LoadFocusedStats()

local function SafeApiCall(func)
	local ok, result = pcall(func)
	if ok then
		return result
	end
	return nil
end

local function TableHasAnyValue(t)
	if type(t) ~= "table" then
		return false
	end
	for _ in pairs(t) do
		return true
	end
	return false
end

local function AddKey(keyMap, keys, key)
	if key == nil then
		return
	end
	key = tostring(key)
	if keyMap[key] == nil then
		keyMap[key] = true
		table.insert(keys, key)
	end
end

local function GetTableValue(t, key)
	if type(t) ~= "table" then
		return nil
	end
	local ok, value = pcall(function()
		return t[key]
	end)
	if ok then
		return value
	end
	return nil
end

local function GetStatValue(unitInfo, modifierInfo, key)
	local value = GetTableValue(unitInfo, key)
	if value ~= nil then
		return value
	end
	return GetTableValue(modifierInfo, key)
end

local function FormatValue(value)
	local valueType = type(value)
	if value == nil then
		return "-"
	elseif valueType == "number" then
		if value == math.floor(value) then
			return tostring(value)
		end
		return string.format("%.4f", value)
	elseif valueType == "boolean" then
		return tostring(value)
	elseif valueType == "table" then
		return "<table>"
	end
	return tostring(value)
end

local function SetValueColor(label, value, defaultKey)
	local numberValue = tonumber(value)
	if numberValue ~= nil then
		if numberValue > 0 then
			label.style:SetColorByKey("green")
			return
		elseif numberValue < 0 then
			label.style:SetColorByKey("red")
			return
		end
	end
	label.style:SetColorByKey(defaultKey or "default")
end

local function TrimText(value)
	if value == nil then
		return ""
	end
	return tostring(value):match("^%s*(.-)%s*$") or ""
end

local function DebugPrint(message)
	if DEBUG_TARGET_STATS ~= true then
		return
	end
	local text = "[TargetStats DEBUG] " .. tostring(message)
	if aaprint ~= nil then
		aaprint(text)
	else
		X2Chat:DispatchChatMessage(CMF_SYSTEM, text)
	end
end

local function CreateTextLabel(parent, name, width, height, fontSize, colorKey)
	local label = parent:CreateChildWidget("label", name, 0, true)
	label:SetExtent(width, height)
	label.style:SetAlign(ALIGN_LEFT)
	label.style:SetEllipsis(true)
	label.style:SetFontSize(fontSize or FONT_SIZE.SMALL)
	label.style:SetColorByKey(colorKey or "default")
	return label
end

local function CreateSmallTextButton(parent, name, text)
	local button = parent:CreateChildWidget("button", name, 0, true)
	button:SetStyle("text_default")
	button:SetExtent(35, 25)
	button:SetText(text)
	button:SetWidth(25)
	return button
end

local ShowAddStatPrompt
local pendingAddStatKey = nil

local statWindow = CreateEmptyWindow("targetStatsWindow", "UIParent")
statWindow:SetExtent(WINDOW_WIDTH, WINDOW_HEIGHT)
statWindow:AddAnchor("CENTER", "UIParent", 0, 0)
statWindow:EnableDrag(true)
statWindow:SetCloseOnEscape(true)
statWindow:Show(false)
statWindow.page = 1
statWindow.keys = {}
statWindow.unitInfo = nil
statWindow.modifierInfo = nil
statWindow.targetName = nil
statWindow.lastSnapshot = nil

local bg = statWindow:CreateDrawable("ui/common/default.dds", "main_bg", "background")
bg:AddAnchor("TOPLEFT", statWindow, -5, -5)
bg:AddAnchor("BOTTOMRIGHT", statWindow, 5, 5)

function statWindow:OnDragStart()
	self:StartMoving()
	self.moving = true
end
statWindow:SetHandler("OnDragStart", statWindow.OnDragStart)

function statWindow:OnDragStop()
	self:StopMovingOrSizing()
	self.moving = false
end
statWindow:SetHandler("OnDragStop", statWindow.OnDragStop)

local title = CreateTextLabel(statWindow, "targetStatsTitle", 430, 26, FONT_SIZE.LARGE, "brown")
title:AddAnchor("TOP", statWindow, 0, 16)
title.style:SetAlign(ALIGN_CENTER)
title:SetText("Raw Target Stats")

local closeButton = statWindow:CreateChildWidget("button", "targetStatsCloseButton", 0, true)
closeButton:AddAnchor("TOPRIGHT", statWindow, 3, -3)
closeButton:SetStyle("btn_close_default")
closeButton:SetHandler("OnClick", function()
	statWindow:Show(false)
end)

local status = CreateTextLabel(statWindow, "targetStatsStatus", WINDOW_WIDTH - 50, 20, FONT_SIZE.SMALL, "default")
status:AddAnchor("TOPLEFT", statWindow, 24, 48)
status:SetText("Select a target.")

local keyHeader = CreateTextLabel(statWindow, "targetStatsKeyHeader", 220, 18, FONT_SIZE.SMALL, "title")
keyHeader:AddAnchor("TOPLEFT", statWindow, 26, 76)
keyHeader:SetText("Key")

local infoHeader = CreateTextLabel(statWindow, "targetStatsInfoHeader", 165, 18, FONT_SIZE.SMALL, "title")
infoHeader:AddAnchor("LEFT", keyHeader, "RIGHT", 10, 0)
infoHeader:SetText("UnitInfo(target)")

local modHeader = CreateTextLabel(statWindow, "targetStatsModHeader", 165, 18, FONT_SIZE.SMALL, "title")
modHeader:AddAnchor("LEFT", infoHeader, "RIGHT", 20, 0)
modHeader:SetText("UnitModifierInfo(target)")

statWindow.rows = {}
for i = 1, ROW_COUNT do
	local row = {}
	local y = 98 + ((i - 1) * ROW_HEIGHT)
	row.key = CreateTextLabel(statWindow, "targetStatsKey" .. i, 220, ROW_HEIGHT, FONT_SIZE.SMALL, "default")
	row.key:AddAnchor("TOPLEFT", statWindow, 26, y)
	row.info = CreateTextLabel(statWindow, "targetStatsInfo" .. i, 165, ROW_HEIGHT, FONT_SIZE.SMALL, "default")
	row.info:AddAnchor("LEFT", row.key, "RIGHT", 10, 0)
	row.modifier = CreateTextLabel(statWindow, "targetStatsModifier" .. i, 165, ROW_HEIGHT, FONT_SIZE.SMALL, "default")
	row.modifier:AddAnchor("LEFT", row.info, "RIGHT", 20, 0)
	row.addButton = CreateSmallTextButton(statWindow, "targetStatsAdd" .. i, "+")
	row.addButton:AddAnchor("LEFT", row.modifier, "RIGHT", 6, 0)
	function row.addButton:OnClick()
		DebugPrint("raw + clicked; statKey=" .. tostring(self.statKey))
		if self.statKey ~= nil and ShowAddStatPrompt ~= nil then
			ShowAddStatPrompt(self.statKey)
		else
			DebugPrint("raw + ignored; ShowAddStatPrompt=" .. tostring(ShowAddStatPrompt))
		end
	end
	row.addButton:SetHandler("OnClick", row.addButton.OnClick)
	statWindow.rows[i] = row
end

local pageLabel = CreateTextLabel(statWindow, "targetStatsPageLabel", 150, 24, FONT_SIZE.MIDDLE, "default")
pageLabel:AddAnchor("BOTTOM", statWindow, 0, -18)
pageLabel.style:SetAlign(ALIGN_CENTER)

local refreshButton = statWindow:CreateChildWidget("button", "targetStatsRefreshButton", 0, true)
refreshButton:SetExtent(90, 25)
refreshButton:SetText("Refresh")
refreshButton:SetStyle("text_default")
refreshButton:AddAnchor("BOTTOMLEFT", statWindow, 24, -18)

local prevButton = statWindow:CreateChildWidget("button", "targetStatsPrevButton", 0, true)
prevButton:SetExtent(70, 25)
prevButton:SetText("Prev")
prevButton:SetStyle("text_default")
prevButton:AddAnchor("BOTTOMRIGHT", pageLabel, "BOTTOMLEFT", -12, 0)

local nextButton = statWindow:CreateChildWidget("button", "targetStatsNextButton", 0, true)
nextButton:SetExtent(70, 25)
nextButton:SetText("Next")
nextButton:SetStyle("text_default")
nextButton:AddAnchor("BOTTOMLEFT", pageLabel, "BOTTOMRIGHT", 12, 0)

local focusedButton = statWindow:CreateChildWidget("button", "targetStatsFocusedButton", 0, true)
focusedButton:SetExtent(90, 25)
focusedButton:SetText("Focused")
focusedButton:SetStyle("text_default")
focusedButton:AddAnchor("BOTTOMRIGHT", statWindow, -24, -18)
focusedButton:Show(false)

local focusedWindow = CreateEmptyWindow("targetStatsFocusedWindow", "UIParent")
focusedWindow:SetExtent(FOCUSED_WINDOW_WIDTH, FOCUSED_WINDOW_MIN_HEIGHT)
focusedWindow:AddAnchor("LEFT", statWindow, "RIGHT", 12, 0)
focusedWindow:EnableDrag(true)
focusedWindow:SetCloseOnEscape(true)
focusedWindow:Show(false)

local focusedBg = focusedWindow:CreateDrawable("ui/common/default.dds", "main_bg", "background")
focusedBg:AddAnchor("TOPLEFT", focusedWindow, -5, -5)
focusedBg:AddAnchor("BOTTOMRIGHT", focusedWindow, 5, 5)

function focusedWindow:OnDragStart()
	self:StartMoving()
	self.moving = true
end
focusedWindow:SetHandler("OnDragStart", focusedWindow.OnDragStart)

function focusedWindow:OnDragStop()
	self:StopMovingOrSizing()
	self.moving = false
end
focusedWindow:SetHandler("OnDragStop", focusedWindow.OnDragStop)

local focusedTitle = CreateTextLabel(focusedWindow, "targetStatsFocusedTitle", 260, 24, FONT_SIZE.LARGE, "brown")
focusedTitle:AddAnchor("TOP", focusedWindow, 0, 14)
focusedTitle.style:SetAlign(ALIGN_CENTER)
focusedTitle:SetText("Focused Stats")

local focusedCloseButton = focusedWindow:CreateChildWidget("button", "targetStatsFocusedCloseButton", 0, true)
focusedCloseButton:AddAnchor("TOPRIGHT", focusedWindow, 3, -3)
focusedCloseButton:SetStyle("btn_close_default")
focusedCloseButton:SetHandler("OnClick", function()
	focusedWindow:Show(false)
end)

local rawButton = focusedWindow:CreateChildWidget("button", "targetStatsRawButton", 0, true)
rawButton:SetExtent(70, 25)
rawButton:SetText("Raw")
rawButton:SetStyle("text_default")
rawButton:AddAnchor("BOTTOMRIGHT", focusedWindow, -24, -18)
rawButton:SetHandler("OnClick", function()
	statWindow:Show(true)
	statWindow:RefreshTargetStats(false, true)
end)

local function FormatReceivedDamage(unitInfo, modifierInfo, key)
	local value = tonumber(GetStatValue(unitInfo, modifierInfo, key))
	if value == nil then
		return "-"
	end
	return FormatValue(100 + value)
end

local focusedLayout = {
	{ heading = "Defensives:" },
	{ text = function(unitInfo, modifierInfo)
		return string.format(
			"Pdef: %s (%s %%)",
			FormatValue(GetStatValue(unitInfo, modifierInfo, "armor")),
			FormatValue(GetStatValue(unitInfo, modifierInfo, "armor_percentage"))
		)
	end },
	{ text = function(unitInfo, modifierInfo)
		return string.format(
			"Mdef: %s (%s %%)",
			FormatValue(GetStatValue(unitInfo, modifierInfo, "magic_resist")),
			FormatValue(GetStatValue(unitInfo, modifierInfo, "magic_resist_percentage"))
		)
	end },
	{ text = function(unitInfo, modifierInfo)
		return string.format(
			"Resilience: %s (-%s %%, -%s %%)",
			FormatValue(GetStatValue(unitInfo, modifierInfo, "flexibility")),
			FormatValue(GetStatValue(unitInfo, modifierInfo, "flexibility_bonus")),
			FormatValue(GetStatValue(unitInfo, modifierInfo, "flexibility_ratio"))
		)
	end },
	{ text = function(unitInfo, modifierInfo)
		return string.format(
			"Toughness: %s (%s %%)",
			FormatValue(GetStatValue(unitInfo, modifierInfo, "battle_resist")),
			FormatValue(GetStatValue(unitInfo, modifierInfo, "battle_resist_rate"))
		)
	end },
	{ text = function(unitInfo, modifierInfo)
		return string.format(
			"Received Melee Damage: %s",
			FormatReceivedDamage(unitInfo, modifierInfo, "incoming_melee_damage_mul")
		)
	end },
	{ text = function(unitInfo, modifierInfo)
		return string.format(
			"Received Ranged Damage: %s",
			FormatReceivedDamage(unitInfo, modifierInfo, "incoming_ranged_damage_mul")
		)
	end },
	{ text = function(unitInfo, modifierInfo)
		return string.format(
			"Received Magic Damage: %s",
			FormatReceivedDamage(unitInfo, modifierInfo, "incoming_spell_damage_mul")
		)
	end },
	{ heading = "Offensive:" },
	{ text = function(unitInfo, modifierInfo)
		return string.format(
			"Atkspeed: %s (%s %%)",
			FormatValue(GetStatValue(unitInfo, modifierInfo, "attack_anim_speed")),
			FormatValue(GetStatValue(unitInfo, modifierInfo, "attack_anim_speed_mul"))
		)
	end },
	{ text = function(unitInfo, modifierInfo)
		return string.format(
			"Cast time: %s %%",
			FormatValue(GetStatValue(unitInfo, modifierInfo, "casting_time"))
		)
	end },
	{ text = function(unitInfo, modifierInfo)
		return string.format(
			"Focus: %s (%s %%)",
			FormatValue(GetStatValue(unitInfo, modifierInfo, "bulls_eye")),
			FormatValue(GetStatValue(unitInfo, modifierInfo, "bulls_eye_rate"))
		)
	end },
	{ heading = "Stats:" },
	{ text = function(unitInfo, modifierInfo)
		return string.format("Strength: %s", FormatValue(GetStatValue(unitInfo, modifierInfo, "str")))
	end },
	{ text = function(unitInfo, modifierInfo)
		return string.format("Spirit: %s", FormatValue(GetStatValue(unitInfo, modifierInfo, "spi")))
	end },
	{ text = function(unitInfo, modifierInfo)
		return string.format("Intelligence: %s", FormatValue(GetStatValue(unitInfo, modifierInfo, "int")))
	end },
	{ text = function(unitInfo, modifierInfo)
		return string.format("Stamina: %s", FormatValue(GetStatValue(unitInfo, modifierInfo, "sta")))
	end },
	{ text = function(unitInfo, modifierInfo)
		return string.format("Agility: %s", FormatValue(GetStatValue(unitInfo, modifierInfo, "dex")))
	end },
	{ heading = "Misc:" },
	{ text = function(unitInfo, modifierInfo)
		return string.format("Drop rate: %s", FormatValue(GetStatValue(unitInfo, modifierInfo, "drop_rate_mul")))
	end },
}

focusedWindow.rows = {}

local function EnsureFocusedRow(index)
	if focusedWindow.rows[index] ~= nil then
		return focusedWindow.rows[index]
	end
	local row = {}
	row.label = CreateTextLabel(
		focusedWindow,
		"targetStatsFocusedRow" .. index,
		FOCUSED_WINDOW_WIDTH - 70,
		FOCUSED_ROW_HEIGHT,
		FONT_SIZE.SMALL,
		"default"
	)
	row.label:AddAnchor("TOPLEFT", focusedWindow, 24, FOCUSED_ROW_TOP + ((index - 1) * FOCUSED_ROW_HEIGHT))
	row.removeButton = CreateSmallTextButton(focusedWindow, "targetStatsFocusedRemove" .. index, "-")
	row.removeButton:AddAnchor("LEFT", row.label, "RIGHT", 6, 0)
	row.removeButton:SetHandler("OnClick", function(self)
		if self.customIndex ~= nil then
			table.remove(customFocusedStats, self.customIndex)
			SaveFocusedStats()
			focusedWindow:Render()
		elseif self.defaultIndex ~= nil then
			hiddenDefaultFocusedStats[self.defaultIndex] = true
			SaveFocusedStats()
			focusedWindow:Render()
		end
	end)
	focusedWindow.rows[index] = row
	return row
end

function focusedWindow:Render()
	if statWindow.targetName ~= nil and statWindow.targetName ~= "" then
		focusedTitle:SetText(string.format("Focused Stats (%s)", tostring(statWindow.targetName)))
	else
		focusedTitle:SetText("Focused Stats")
	end
	local rowIndex = 1
	for i = 1, #focusedLayout do
		local item = focusedLayout[i]
		if hiddenDefaultFocusedStats[i] == true then
			item = nil
		end
		if item ~= nil and item.heading == nil then
			local row = EnsureFocusedRow(rowIndex)
			row.label:SetText(item.text(statWindow.unitInfo, statWindow.modifierInfo))
			row.label.style:SetColorByKey("default")
			row.label.style:SetFontSize(FONT_SIZE.SMALL)
			row.removeButton.customIndex = nil
			row.removeButton.defaultIndex = i
			row.removeButton:Show(true)
			row.label:Show(true)
			rowIndex = rowIndex + 1
		end
	end
	for i = 1, #customFocusedStats do
		local item = customFocusedStats[i]
		local row = EnsureFocusedRow(rowIndex)
		row.label:SetText(string.format(
			"%s: %s",
			tostring(item.label),
			FormatValue(GetStatValue(statWindow.unitInfo, statWindow.modifierInfo, item.key))
		))
		row.label.style:SetColorByKey("default")
		row.label.style:SetFontSize(FONT_SIZE.SMALL)
		row.removeButton.customIndex = i
		row.removeButton.defaultIndex = nil
		row.removeButton:Show(true)
		row.label:Show(true)
		rowIndex = rowIndex + 1
	end
	for i = rowIndex, #self.rows do
		self.rows[i].label:Show(false)
		self.rows[i].removeButton.customIndex = nil
		self.rows[i].removeButton.defaultIndex = nil
		self.rows[i].removeButton:Show(false)
	end
	local renderedRows = rowIndex - 1
	self:SetExtent(
		FOCUSED_WINDOW_WIDTH,
		math.max(FOCUSED_WINDOW_MIN_HEIGHT, FOCUSED_ROW_TOP + (renderedRows * FOCUSED_ROW_HEIGHT) + FOCUSED_BOTTOM_PADDING)
	)
end

focusedButton:SetHandler("OnClick", function()
	statWindow:RefreshTargetStats(false)
	focusedWindow:Render()
	focusedWindow:Show(true)
end)

local promptWindow = CreateEmptyWindow("targetStatsAddPromptWindow", "UIParent")
promptWindow:SetExtent(320, 135)
promptWindow:AddAnchor("CENTER", "UIParent", 0, 0)
promptWindow:SetCloseOnEscape(true)
promptWindow:EnableDrag(true)
promptWindow:Show(false)

local promptBg = promptWindow:CreateDrawable("ui/common/default.dds", "main_bg", "background")
promptBg:AddAnchor("TOPLEFT", promptWindow, -5, -5)
promptBg:AddAnchor("BOTTOMRIGHT", promptWindow, 5, 5)

function promptWindow:OnDragStart()
	self:StartMoving()
	self.moving = true
end
promptWindow:SetHandler("OnDragStart", promptWindow.OnDragStart)

function promptWindow:OnDragStop()
	self:StopMovingOrSizing()
	self.moving = false
end
promptWindow:SetHandler("OnDragStop", promptWindow.OnDragStop)

local promptLabel = CreateTextLabel(promptWindow, "targetStatsPromptLabel", 260, 20, FONT_SIZE.MIDDLE, "title")
promptLabel:AddAnchor("TOPLEFT", promptWindow, 20, 18)
promptLabel:SetText("What is this stat called?")

local promptEditBg = promptWindow:CreateColorDrawable(0, 0, 0, 0.45, "background")
promptEditBg:SetExtent(280, 28)
promptEditBg:AddAnchor("TOPLEFT", promptWindow, 20, 48)

local promptEditText = ""
local promptEdit = promptWindow:CreateChildWidget("editboxmultiline", "targetStatsPromptEdit", 0, true)
promptEdit:SetExtent(280, 28)
promptEdit:SetInset(5, 4, 5, 4)
promptEdit:AddAnchor("TOPLEFT", promptWindow, 20, 48)
promptEdit.style:SetAlign(ALIGN_LEFT)
promptEdit.style:SetFontSize(FONT_SIZE.MIDDLE)
promptEdit.style:SetColor(255, 255, 255, 255)

local promptOkButton = promptWindow:CreateChildWidget("button", "targetStatsPromptOk", 0, true)
promptOkButton:SetExtent(70, 25)
promptOkButton:SetText("OK")
promptOkButton:SetStyle("text_default")
promptOkButton:AddAnchor("BOTTOMRIGHT", promptWindow, -95, -16)

local promptCancelButton = promptWindow:CreateChildWidget("button", "targetStatsPromptCancel", 0, true)
promptCancelButton:SetExtent(70, 25)
promptCancelButton:SetText("Cancel")
promptCancelButton:SetStyle("text_default")
promptCancelButton:AddAnchor("BOTTOMRIGHT", promptWindow, -20, -16)

local function ConfirmAddFocusedStat()
	DebugPrint("ConfirmAddFocusedStat entered")
	local editText = ""
	if promptEdit.GetText ~= nil then
		editText = promptEdit:GetText()
	end
	local label = TrimText(editText)
	if label == "" then
		label = TrimText(promptEditText)
	end
	DebugPrint("OK values: label='" .. tostring(label) .. "', editText='" .. tostring(editText) .. "', cachedText='" .. tostring(promptEditText) .. "', pendingAddStatKey=" .. tostring(pendingAddStatKey))
	if label == "" or pendingAddStatKey == nil then
		DebugPrint("OK aborted: missing label or key")
		return
	end
	customFocusedStats[#customFocusedStats + 1] = {
		key = tostring(pendingAddStatKey),
		label = label,
	}
	DebugPrint("custom stat appended; count=" .. tostring(#customFocusedStats))
	DebugPrint("forcing target refresh")
	statWindow:RefreshTargetStats(false, true)
	DebugPrint("rendering focused window")
	focusedWindow:Render()
	focusedWindow:Show(true)
	DebugPrint("hiding prompt")
	promptWindow:Show(false)
	pendingAddStatKey = nil
	DebugPrint("saving focused stats")
	SaveFocusedStats()
	DebugPrint("OK complete")
end

function promptOkButton:OnClick()
	DebugPrint("OK button OnClick fired")
	ConfirmAddFocusedStat()
end
promptOkButton:SetHandler("OnClick", promptOkButton.OnClick)
promptCancelButton:SetHandler("OnClick", function()
	DebugPrint("Cancel clicked")
	pendingAddStatKey = nil
	promptWindow:Show(false)
end)
function promptEdit:OnEnterPressed()
	DebugPrint("editbox OnEnterPressed fired")
	ConfirmAddFocusedStat()
end
promptEdit:SetHandler("OnEnterPressed", promptEdit.OnEnterPressed)
function promptEdit:OnTextChanged(...)
	local text = ""
	if self.GetText ~= nil then
		text = self:GetText()
	end
	if text == "" then
		local args = { ... }
		for i = 1, #args do
			if type(args[i]) == "string" and args[i] ~= "" then
				text = args[i]
				break
			end
		end
	end
	promptEditText = text
	DebugPrint("editbox OnTextChanged; cachedText='" .. tostring(promptEditText) .. "'")
end
promptEdit:SetHandler("OnTextChanged", promptEdit.OnTextChanged)

ShowAddStatPrompt = function(statKey)
	DebugPrint("ShowAddStatPrompt called; statKey=" .. tostring(statKey))
	pendingAddStatKey = statKey
	promptEditText = ""
	promptEdit:SetText("")
	promptWindow:Show(true)
	promptWindow:Raise()
	if promptEdit.SetFocus ~= nil then
		DebugPrint("setting editbox focus")
		promptEdit:SetFocus()
	else
		DebugPrint("editbox SetFocus missing")
	end
end

local function BuildKeys(unitInfo, modifierInfo)
	local keyMap = {}
	local keys = {}
	if type(unitInfo) == "table" then
		for key in pairs(unitInfo) do
			AddKey(keyMap, keys, key)
		end
	end
	if type(modifierInfo) == "table" then
		for key in pairs(modifierInfo) do
			AddKey(keyMap, keys, key)
		end
	end
	for i = 1, #knownUnitInfoKeys do
		local key = knownUnitInfoKeys[i]
		if GetTableValue(unitInfo, key) ~= nil or GetTableValue(modifierInfo, key) ~= nil then
			AddKey(keyMap, keys, key)
		end
	end
	for i = 1, #knownModifierOnlyKeys do
		local key = knownModifierOnlyKeys[i]
		if GetTableValue(unitInfo, key) ~= nil or GetTableValue(modifierInfo, key) ~= nil then
			AddKey(keyMap, keys, key)
		end
	end
	table.sort(keys)
	return keys
end

local function BuildSnapshot(targetName, unitInfo, modifierInfo, keys)
	local parts = { tostring(targetName or "") }
	for i = 1, #keys do
		local key = keys[i]
		table.insert(parts, key)
		table.insert(parts, FormatValue(GetTableValue(unitInfo, key)))
		table.insert(parts, FormatValue(GetTableValue(modifierInfo, key)))
	end
	return table.concat(parts, "\031")
end

function statWindow:RenderPage()
	local maxPage = math.max(1, math.ceil(#self.keys / ROW_COUNT))
	if self.page > maxPage then
		self.page = maxPage
	elseif self.page < 1 then
		self.page = 1
	end

	local startIndex = ((self.page - 1) * ROW_COUNT) + 1
	for i = 1, ROW_COUNT do
		local key = self.keys[startIndex + i - 1]
		local row = self.rows[i]
		if key ~= nil then
			local infoValue = GetTableValue(self.unitInfo, key)
			local modifierValue = GetTableValue(self.modifierInfo, key)
			row.key:SetText(key)
			row.info:SetText(FormatValue(infoValue))
			row.modifier:SetText(FormatValue(modifierValue))
			row.addButton.statKey = key
			row.key.style:SetColorByKey("default")
			SetValueColor(row.info, infoValue, "default")
			SetValueColor(row.modifier, modifierValue, "default")
			row.key:Show(true)
			row.info:Show(true)
			row.modifier:Show(true)
			row.addButton:Show(true)
		else
			row.key:SetText("")
			row.info:SetText("")
			row.modifier:SetText("")
			row.addButton.statKey = nil
			row.key:Show(false)
			row.info:Show(false)
			row.modifier:Show(false)
			row.addButton:Show(false)
		end
	end
	pageLabel:SetText(string.format("Page %d/%d", self.page, maxPage))
	prevButton:Enable(self.page > 1)
	nextButton:Enable(self.page < maxPage)
end

function statWindow:RefreshTargetStats(resetPage, forceRender)
	local targetName = SafeApiCall(function()
		return X2Unit:UnitName(TARGET_UNIT)
	end)
	local unitInfo = SafeApiCall(function()
		return X2Unit:UnitInfo(TARGET_UNIT)
	end)
	local modifierInfo = SafeApiCall(function()
		return X2Unit:UnitModifierInfo(TARGET_UNIT)
	end)
	local keys = BuildKeys(unitInfo, modifierInfo)
	local snapshot = BuildSnapshot(targetName, unitInfo, modifierInfo, keys)

	if forceRender ~= true and snapshot == self.lastSnapshot then
		return
	end

	self.targetName = targetName
	self.unitInfo = unitInfo
	self.modifierInfo = modifierInfo
	self.keys = keys
	self.lastSnapshot = snapshot
	if resetPage ~= false then
		self.page = 1
	end

	local statusText
	if targetName == nil or targetName == "" then
		statusText = "No target selected, or target info is unavailable."
	else
		statusText = string.format("Target: %s  |  Keys: %d", tostring(targetName), #self.keys)
	end

	if not TableHasAnyValue(self.unitInfo) and not TableHasAnyValue(self.modifierInfo) then
		statusText = statusText .. "  |  API returned no enumerable values."
	end
	status:SetText(statusText)

	self:RenderPage()
	if focusedWindow:IsVisible() then
		focusedWindow:Render()
	end
end

refreshButton:SetHandler("OnClick", function()
	statWindow:RefreshTargetStats()
end)

prevButton:SetHandler("OnClick", function()
	statWindow.page = statWindow.page - 1
	statWindow:RenderPage()
end)

nextButton:SetHandler("OnClick", function()
	statWindow.page = statWindow.page + 1
	statWindow:RenderPage()
end)

function statWindow:ShowProc()
	self:RefreshTargetStats(nil, true)
end

local targetStatsUpdater = CreateEmptyWindow("targetStatsUpdater", "UIParent")
targetStatsUpdater:SetExtent(1, 1)
targetStatsUpdater:Show(true)

function targetStatsUpdater:OnUpdate(dt)
	if not statWindow:IsVisible() and not focusedWindow:IsVisible() then
		return
	end
	statWindow:RefreshTargetStats(false, false)
end
targetStatsUpdater:SetHandler("OnUpdate", targetStatsUpdater.OnUpdate)

local openButton = CreateSimpleButton("Stats", 0, -260)

function openButton:OnClick()
	focusedWindow:Show(not focusedWindow:IsVisible())
	if focusedWindow:IsVisible() then
		statWindow:RefreshTargetStats(false, true)
		focusedWindow:Render()
	end
end
openButton:SetHandler("OnClick", openButton.OnClick)

--X2Chat:DispatchChatMessage(CMF_SYSTEM, "Target Stats loaded")
