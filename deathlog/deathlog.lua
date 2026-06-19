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
ADDON:ImportObject(OBJECT_TYPE.COLOR_DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.NINE_PART_DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.IMAGE_DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.EMPTY_WIDGET)
ADDON:ImportObject(OBJECT_TYPE.ICON_DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.LABEL)
ADDON:ImportObject(OBJECT_TYPE.WINDOW)
ADDON:ImportAPI(API_TYPE.CHAT.id)
ADDON:ImportAPI(API_TYPE.UNIT.id)

local SELF_NAME = X2Unit:UnitName("player")
local DEBUG_DEATHLOG = false
local DAMAGE_THRESHOLD = 1000
local MAX_DAMAGE_LOG = 5
local POLL_INTERVAL_MS = 250
local DEBUFF_SAMPLE_INTERVAL_MS = 100
local PANEL_WIDTH = 300
local PANEL_HEIGHT = 198
local DEBUFF_SAMPLE_LOOKBACK_MS = 100
local MAX_DEBUFF_ICONS = 10
local DEBUFF_ICON_SIZE = 24

local combatLog = {}
local deathLog = {}
local debuffSamples = {}
local deathDebuffs = {}
local deathLogPanel
local deathLogBackground
local debuffDetailPanel
local debuffDetailIcon
local debuffDetailName
local deathLogRows = {}
local debuffIconSlots = {}
local pollElapsed = POLL_INTERVAL_MS
local debuffSampleElapsed = DEBUFF_SAMPLE_INTERVAL_MS
local debuffSampleClock = 0
local panelVisible = false
local lastDeathWindowX
local lastDeathWindowY
local lastDeathWindowW
local lastPanelX
local lastPanelY
local lastDebugVisibility
local debugElapsed = 0
local selectedDeathDebuffIndex

local function Debug(message)
	if DEBUG_DEATHLOG ~= true then
		return
	end
	local text = "[DeathLog] " .. tostring(message)
	if type(aaprint) == "function" then
		aaprint(text)
	else
		X2Chat:DispatchChatMessage(CMF_SYSTEM, text)
	end
end

local function Trim(value)
	if type(value) ~= "string" then
		return ""
	end
	return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function AddDamageEntry(entry)
	table.insert(combatLog, entry)
	while #combatLog > MAX_DAMAGE_LOG do
		table.remove(combatLog, 1)
	end
	Debug("damage added, combatLog=" .. tostring(#combatLog) .. " entry=" .. tostring(entry))
end

local function CopyLastDamageEntries()
	deathLog = {}
	local startIndex = math.max(1, #combatLog - MAX_DAMAGE_LOG + 1)
	for index = startIndex, #combatLog do
		table.insert(deathLog, combatLog[index])
	end
	Debug("copied deathLog=" .. tostring(#deathLog) .. " from combatLog=" .. tostring(#combatLog))
end

local function CaptureCurrentDebuffs()
	local debuffs = {}
	local count = tonumber(X2Unit:UnitDeBuffCount("player")) or 0
	for index = 1, count do
		local tooltip = X2Unit:UnitDeBuffTooltip("player", index)
		local extra = X2Unit:UnitDeBuff("player", index)
		if type(tooltip) == "table" and type(extra) == "table" then
			table.insert(debuffs, {
				name = tostring(tooltip.name or ""),
				path = extra.path,
				tooltip = tooltip,
				stack = tooltip.stack,
			})
		end
	end
	table.insert(debuffSamples, {
		time = debuffSampleClock,
		debuffs = debuffs,
	})
	while #debuffSamples > 10 do
		table.remove(debuffSamples, 1)
	end
	Debug("sampled debuffs count=" .. tostring(#debuffs) .. " samples=" .. tostring(#debuffSamples))
end

local function CopyDeathDebuffs()
	deathDebuffs = {}
	local targetTime = debuffSampleClock - DEBUFF_SAMPLE_LOOKBACK_MS
	local selected = nil
	for _, sample in ipairs(debuffSamples) do
		if sample.time <= targetTime then
			selected = sample
		end
	end
	if selected == nil then
		selected = debuffSamples[#debuffSamples]
	end
	if selected ~= nil then
		for _, debuff in ipairs(selected.debuffs) do
			table.insert(deathDebuffs, debuff)
		end
	end
	Debug(
		"copied deathDebuffs="
			.. tostring(#deathDebuffs)
			.. " targetTime="
			.. tostring(targetTime)
			.. " samples="
			.. tostring(#debuffSamples)
	)
end

local function StyleLabel(label, fontSize, align)
	label.style:SetFontSize(fontSize or 12)
	label.style:SetAlign(align or ALIGN_LEFT)
	if label.style.SetColorByKey ~= nil then
		label.style:SetColorByKey("default")
	else
		label.style:SetColor(1, 1, 1, 1)
	end
end

local function CreateWindowBackground(window)
	local bg = window:CreateDrawable("ui/common/default.dds", "main_bg", "background")
	Debug(
		"CreateWindowBackground bg="
			.. tostring(bg)
			.. " addAnchor="
			.. tostring(bg ~= nil and bg.AddAnchor ~= nil)
	)
	if bg ~= nil and bg.AddAnchor ~= nil then
		bg:AddAnchor("TOPLEFT", window, -5, -5)
		bg:AddAnchor("BOTTOMRIGHT", window, 5, 5)
	end
	return bg
end

local function EnsureDebuffDetailPanel()
	if debuffDetailPanel ~= nil then
		return
	end
	debuffDetailPanel = deathLogPanel:CreateChildWidget("emptywidget", "deathLogDebuffDetail", 0, true)
	debuffDetailPanel:SetExtent(PANEL_WIDTH - 16, 34)
	debuffDetailPanel:AddAnchor("TOPLEFT", deathLogPanel, 8, PANEL_HEIGHT - 40)
	debuffDetailPanel:Show(false)
	debuffDetailPanel:Enable(true)

	local bg = debuffDetailPanel:CreateDrawable("ui/common/default.dds", "editbox_df", "background")
	if bg ~= nil and bg.AddAnchor ~= nil then
		bg:AddAnchor("TOPLEFT", debuffDetailPanel, 0, 0)
		bg:AddAnchor("BOTTOMRIGHT", debuffDetailPanel, 0, 0)
	end

	debuffDetailIcon = debuffDetailPanel:CreateIconDrawable("artwork")
	debuffDetailIcon:SetExtent(28, 28)
	debuffDetailIcon:AddAnchor("LEFT", debuffDetailPanel, 4, 0)
	debuffDetailIcon:SetVisible(false)

	debuffDetailName = debuffDetailPanel:CreateChildWidget("label", "deathLogDebuffDetailName", 0, true)
	debuffDetailName:SetExtent(PANEL_WIDTH - 56, 26)
	debuffDetailName:AddAnchor("LEFT", debuffDetailPanel, 38, 0)
	debuffDetailName:SetText("")
	StyleLabel(debuffDetailName, 12, ALIGN_LEFT)

	debuffDetailPanel:SetHandler("OnClick", function()
		selectedDeathDebuffIndex = nil
		debuffDetailPanel:Show(false)
	end)
end

local function ToggleDebuffDetail(index)
	EnsureDebuffDetailPanel()
	local debuff = deathDebuffs[index]
	if debuff == nil then
		return
	end
	if selectedDeathDebuffIndex == index and debuffDetailPanel:IsVisible() then
		selectedDeathDebuffIndex = nil
		debuffDetailPanel:Show(false)
		return
	end
	selectedDeathDebuffIndex = index
	debuffDetailIcon:ClearAllTextures()
	if debuff.path ~= nil then
		debuffDetailIcon:AddTexture(debuff.path)
		debuffDetailIcon:SetVisible(true)
	else
		debuffDetailIcon:SetVisible(false)
	end
	debuffDetailName:SetText(debuff.name ~= "" and debuff.name or "Unknown debuff")
	debuffDetailPanel:Show(true)
end

local function EnsureDeathLogPanel()
	if deathLogPanel ~= nil then
		return
	end

	Debug("creating panel")
	deathLogPanel = CreateEmptyWindow("deathLogPanel", "UIParent")
	deathLogPanel:SetExtent(PANEL_WIDTH, PANEL_HEIGHT)
	deathLogPanel:Enable(false)

	local title = deathLogPanel:CreateChildWidget("label", "deathLogTitle", 0, true)
	title:SetExtent(PANEL_WIDTH - 16, 22)
	title:AddAnchor("TOPLEFT", deathLogPanel, 8, 6)
	title:SetText("DeathLog")
	StyleLabel(title, 13, ALIGN_LEFT)

	for index = 1, MAX_DAMAGE_LOG do
		local row = deathLogPanel:CreateChildWidget("label", "deathLogRow" .. index, index, true)
		row:SetExtent(PANEL_WIDTH - 16, 20)
		row:AddAnchor("TOPLEFT", deathLogPanel, 8, 30 + ((index - 1) * 20))
		StyleLabel(row, 11, ALIGN_LEFT)
		deathLogRows[index] = row
	end

	local debuffTitle = deathLogPanel:CreateChildWidget("label", "deathLogDebuffTitle", 0, true)
	debuffTitle:SetExtent(PANEL_WIDTH - 16, 20)
	debuffTitle:AddAnchor("TOPLEFT", deathLogPanel, 8, 132)
	debuffTitle:SetText("Debuffs on Death")
	StyleLabel(debuffTitle, 12, ALIGN_LEFT)

	for index = 1, MAX_DEBUFF_ICONS do
		local slot = deathLogPanel:CreateChildWidget("emptywidget", "deathLogDebuffSlot" .. index, index, true)
		slot:SetExtent(DEBUFF_ICON_SIZE, DEBUFF_ICON_SIZE)
		slot:AddAnchor("TOPLEFT", deathLogPanel, 8 + ((index - 1) * (DEBUFF_ICON_SIZE + 3)), 150)
		slot:Enable(true)
		slot:Show(false)

		local icon = slot:CreateIconDrawable("artwork")
		icon:SetExtent(DEBUFF_ICON_SIZE, DEBUFF_ICON_SIZE)
		icon:AddAnchor("TOPLEFT", slot, 0, 0)
		icon:SetVisible(false)
		slot.icon = icon

		slot:SetHandler("OnClick", function(self)
			if self.debuffIndex ~= nil then
				ToggleDebuffDetail(self.debuffIndex)
			end
		end)
		debuffIconSlots[index] = slot
	end
	Debug("panel created rows=" .. tostring(#deathLogRows))
end

local function RefreshDeathLogPanel()
	EnsureDeathLogPanel()
	if #deathLog == 0 and #combatLog > 0 then
		CopyLastDamageEntries()
	end
	for rowIndex = 1, MAX_DAMAGE_LOG do
		local entry = deathLog[rowIndex]
		local row = deathLogRows[rowIndex]
		if row ~= nil then
			if entry ~= nil then
				row:SetText(entry)
			elseif rowIndex == 1 and #deathLog == 0 then
				row:SetText("No recent big hits.")
			else
				row:SetText("")
			end
		end
	end
	for index = 1, MAX_DEBUFF_ICONS do
		local slot = debuffIconSlots[index]
		local debuff = deathDebuffs[index]
		if slot ~= nil and debuff ~= nil and debuff.path ~= nil then
			slot.debuffIndex = index
			slot.icon:ClearAllTextures()
			slot.icon:AddTexture(debuff.path)
			slot.icon:SetVisible(true)
			slot:Show(true)
		elseif slot ~= nil then
			slot.debuffIndex = nil
			slot.icon:ClearAllTextures()
			slot.icon:SetVisible(false)
			slot:Show(false)
		end
	end
	if selectedDeathDebuffIndex ~= nil and deathDebuffs[selectedDeathDebuffIndex] == nil and debuffDetailPanel ~= nil then
		selectedDeathDebuffIndex = nil
		debuffDetailPanel:Show(false)
	end
	Debug(
		"refreshed panel deathLog="
			.. tostring(#deathLog)
			.. " combatLog="
			.. tostring(#combatLog)
			.. " deathDebuffs="
			.. tostring(#deathDebuffs)
	)
end

local function SetPanelVisible(visible)
	if panelVisible == visible then
		return
	end
	panelVisible = visible
	if deathLogPanel ~= nil then
		deathLogPanel:Show(visible)
	end
	Debug("panel visible=" .. tostring(visible) .. " panelExists=" .. tostring(deathLogPanel ~= nil))
end

local function IsDeathWindowVisible()
	local x, y, width, _, isVisible = ADDON:GetContentMainScriptPosVis(UIC_DEATH_AND_RESURRECTION_WND)
	if DEBUG_DEATHLOG == true and lastDebugVisibility ~= isVisible then
		lastDebugVisibility = isVisible
		Debug(
			"death wnd vis changed visible="
				.. tostring(isVisible)
				.. " x="
				.. tostring(x)
				.. " y="
				.. tostring(y)
				.. " w="
				.. tostring(width)
		)
	end
	if isVisible ~= true then
		return false
	end
	return true, x, y, width
end

local function PositionDeathLogPanel(x, y, width)
	EnsureDeathLogPanel()
	lastDeathWindowX = x
	lastDeathWindowY = y
	lastDeathWindowW = width
	local screenWidth = UIParent:GetScreenWidth()
	local panelX = x + width + 8
	local panelY = y
	if screenWidth ~= nil and panelX + PANEL_WIDTH > screenWidth then
		panelX = x - PANEL_WIDTH - 8
	end
	if panelX < 0 then
		panelX = 0
	end
	if lastPanelX == panelX and lastPanelY == panelY then
		return
	end
	lastPanelX = panelX
	lastPanelY = panelY
	if deathLogPanel.RemoveAllAnchors ~= nil then
		deathLogPanel:RemoveAllAnchors()
	end
	deathLogPanel:AddAnchor("TOPLEFT", "UIParent", panelX, panelY)
	if deathLogBackground == nil then
		deathLogBackground = CreateWindowBackground(deathLogPanel)
	end
	if DEBUG_DEATHLOG == true and debugElapsed >= 1000 then
		Debug(
			"position panel x="
				.. tostring(panelX)
				.. " y="
				.. tostring(panelY)
				.. " deathX="
				.. tostring(x)
				.. " deathW="
				.. tostring(width)
				.. " screenW="
				.. tostring(screenWidth)
				.. " bg="
				.. tostring(deathLogBackground)
				.. " bgAnchor="
				.. tostring(deathLogBackground ~= nil and deathLogBackground.AddAnchor ~= nil)
		)
	end
end

local function YouDiedNotice(info1)
	Debug("UNIT_DEAD_NOTICE info1=" .. tostring(info1) .. " self=" .. tostring(SELF_NAME))
	if SELF_NAME ~= nil and info1 == SELF_NAME then
		CopyLastDamageEntries()
		CopyDeathDebuffs()
	end
end

local function FormatDamage(sourceName, abilityName, damageNumber)
	sourceName = Trim(sourceName)
	abilityName = Trim(abilityName)
	if sourceName == "" then
		sourceName = "Unknown"
	end
	if abilityName == "" then
		abilityName = "Unknown"
	end
	return string.format("%s - %s: %d", sourceName, abilityName, damageNumber)
end

local function OnCombatMessage(
	_,
	eventType,
	sourceName,
	targetName,
	abilityId,
	abilityName,
	damageType,
	effectType
)
	if targetName ~= SELF_NAME or type(eventType) ~= "string" then
		return
	end
	Debug("combat target self event=" .. tostring(eventType))

	local damageNumber = 0
	local damagedBy = "Unknown"
	if string.find(eventType, "ENVIRONMENTAL_DAMAGE", 1, true) ~= nil then
		damageNumber = tonumber(damageType) or 0
		damagedBy = tostring(abilityId or "Environment")
	elseif string.find(eventType, "SPELL_DAMAGE", 1, true) ~= nil then
		damageNumber = math.abs(tonumber(effectType) or 0)
		damagedBy = tostring(abilityName or "Unknown")
	end

	if damageNumber >= DAMAGE_THRESHOLD then
		AddDamageEntry(FormatDamage(sourceName, damagedBy, math.floor(damageNumber + 0.5)))
	else
		Debug("damage ignored amount=" .. tostring(damageNumber) .. " damagedBy=" .. tostring(damagedBy))
	end
end

local updater = UIParent:CreateWidget("emptywidget", "deathLogUpdater", "UIParent", "")
updater:Show(true)
updater:SetHandler("OnUpdate", function(_, dt)
	debugElapsed = debugElapsed + dt
	debuffSampleClock = debuffSampleClock + dt
	debuffSampleElapsed = debuffSampleElapsed + dt
	if debuffSampleElapsed >= DEBUFF_SAMPLE_INTERVAL_MS then
		debuffSampleElapsed = 0
		CaptureCurrentDebuffs()
	end

	local visible, x, y, width = IsDeathWindowVisible()
	if visible ~= true then
		SetPanelVisible(false)
		pollElapsed = POLL_INTERVAL_MS
		if DEBUG_DEATHLOG == true and debugElapsed >= 5000 then
			debugElapsed = 0
			Debug("update hidden, no panel work")
		end
		return
	end

	PositionDeathLogPanel(x, y, width)
	pollElapsed = pollElapsed + dt
	if panelVisible ~= true or pollElapsed >= POLL_INTERVAL_MS then
		pollElapsed = 0
		RefreshDeathLogPanel()
	end
	SetPanelVisible(true)
	if DEBUG_DEATHLOG == true and debugElapsed >= 1000 then
		debugElapsed = 0
		Debug("update visible done panelVisible=" .. tostring(panelVisible))
	end
end)

UIParent:SetEventHandler(UIEVENT_TYPE.UNIT_DEAD_NOTICE, YouDiedNotice)
UIParent:SetEventHandler(UIEVENT_TYPE.COMBAT_MSG, OnCombatMessage)
Debug("loaded self=" .. tostring(SELF_NAME) .. " uic=" .. tostring(UIC_DEATH_AND_RESURRECTION_WND))
