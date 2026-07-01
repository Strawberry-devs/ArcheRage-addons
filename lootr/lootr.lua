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
ADDON:ImportObject(OBJECT_TYPE.EMPTY_WIDGET)
ADDON:ImportObject(OBJECT_TYPE.LABEL)
ADDON:ImportObject(OBJECT_TYPE.EDITBOX)
ADDON:ImportObject(OBJECT_TYPE.X2_EDITBOX)

ADDON:ImportAPI(API_TYPE.CHAT.id)

local WINDOW_WIDTH = 920
local WINDOW_HEIGHT = 640
local BUTTON_HEIGHT = 20
local FILTER_WIDTH = 50
local NAV_BUTTON_WIDTH = 18
local RESULT_ROWS = 9
local ITEM_ROWS = 18
local RESULT_ROW_HEIGHT = 42
local ITEM_ROW_HEIGHT = 20
local MAX_MATCHES = 250

local COLOR_BLUE = { 0.26, 0.55, 0.88, 1 }
local COLOR_GREEN = { 0.16, 0.72, 0.28, 1 }
local COLOR_GOLD = { 0.88, 0.63, 0.16, 1 }
local COLOR_ORANGE = { 0.88, 0.34, 0.12, 1 }
local COLOR_RED = { 0.86, 0.18, 0.16, 1 }
local COLOR_MUTED = { 0.55, 0.55, 0.55, 1 }
local COLOR_TEXT = { 0.30, 0.27, 0.20, 1 }
local COLOR_SELECTED = { 0.16, 0.30, 0.46, 0.45 }
local COLOR_HOVER = { 0.78, 0.73, 0.58, 0.16 }

local MODE_ALL = "all"
local MODE_ITEM = "item"
local MODE_NPC = "npc"
local MODE_PACK = "pack"

local mainWindow
local launcherButton
local searchEdit
local modeButtons = {}
local statusLabel
local resultPageLabel
local groupPageLabel
local selectedHeader
local selectedSubHeaders = {}
local groupHeader
local hintLabel
local resultRows = {}
local itemRows = {}
local activeMode = MODE_ALL
local matches = {}
local resultOffset = 1
local selectedMatchIndex = nil
local selectedPackId = nil
local groupKeys = {}
local groupOffset = 1

local function Chat(message)
	pcall(function()
		X2Chat:DispatchChatMessage(CMF_SYSTEM, "[Lootr] " .. tostring(message))
	end)
end

local function Trim(value)
	return tostring(value or ""):match("^%s*(.-)%s*$") or ""
end

local function Lower(value)
	return Trim(value):lower()
end

local function Contains(value, needle)
	return tostring(value or ""):lower():find(needle, 1, true) ~= nil
end

local function SetTextColor(widget, color)
	if widget == nil or widget.style == nil or color == nil then
		return
	end
	widget.style:SetColor(color[1], color[2], color[3], color[4])
end

local function StyleLabel(label, fontSize, align, color)
	if label == nil or label.style == nil then
		return
	end
	label.style:SetFontSize(fontSize or 12)
	label.style:SetAlign(align or ALIGN_LEFT)
	SetTextColor(label, color or COLOR_TEXT)
end

local function CreateWindowBackground(window)
	if type(SettingWindowSkin) == "function" then
		local ok = pcall(function()
			SettingWindowSkin(window)
		end)
		if ok then
			return nil
		end
	end
	local bg = window:CreateDrawable("ui/common/default.dds", "main_bg", "background")
	if bg ~= nil and bg.AddAnchor ~= nil then
		bg:AddAnchor("TOPLEFT", window, -5, -5)
		bg:AddAnchor("BOTTOMRIGHT", window, 5, 5)
		return bg
	end
	bg = window:CreateColorDrawable(0.15, 0.15, 0.15, 0.90, "background")
	bg:AddAnchor("TOPLEFT", window, 0, 0)
	bg:AddAnchor("BOTTOMRIGHT", window, 0, 0)
	return bg
end

local function CreatePanel(parent, id, left, top, right, bottom, alpha)
	local holder = parent:CreateChildWidget("emptywidget", id, 0, true)
	holder:AddAnchor("TOPLEFT", parent, left, top)
	holder:AddAnchor("BOTTOMRIGHT", parent, right, bottom)
	local ok, bg = pcall(function()
		local drawable = holder:CreateDrawable("ui/common/default.dds", "common_bg", "background")
		if drawable ~= nil and drawable.SetTextureColor ~= nil then
			drawable:SetTextureColor("bg_02")
		end
		return drawable
	end)
	if not ok or bg == nil then
		bg = holder:CreateColorDrawable(0.78, 0.73, 0.58, alpha or 0.14, "background")
	end
	bg:AddAnchor("TOPLEFT", holder, 0, 0)
	bg:AddAnchor("BOTTOMRIGHT", holder, 0, 0)
	return holder
end

local function CreateLine(parent, id, x, y, width)
	local line = parent:CreateDrawable("ui/common/default.dds", "line_01", "artwork")
	if line == nil or line.SetExtent == nil then
		line = parent:CreateColorDrawable(0.42, 0.42, 0.42, 0.24, "artwork")
	end
	line:SetExtent(width, 1)
	line:AddAnchor("TOPLEFT", parent, x, y)
	return line
end

local function CreateCloseButton(parent, id, onClick)
	local button = parent:CreateChildWidget("button", id, 0, true)
	button:AddAnchor("TOPRIGHT", parent, 3, -3)
	button:SetStyle("btn_close_default")
	button:SetHandler("OnClick", onClick)
	return button
end

local function StyleFlatButton(button)
	button:SetStyle("text_default")
	button:SetAutoResize(false)
	button:SetInset(0, 0, 0, 0)
	button.style:SetAlign(ALIGN_CENTER)
	button.style:SetFontSize(12)
end

local function CreateButton(parent, name, text, x, y, width, onClick)
	local button = parent:CreateChildWidget("button", name, 0, true)
	StyleFlatButton(button)
	button:SetExtent(width, BUTTON_HEIGHT)
	button:SetWidth(width)
	button:SetHeight(BUTTON_HEIGHT)
	button:SetText(text)
	button:AddAnchor("TOPLEFT", parent, x, y)
	button:SetHandler("OnClick", onClick)
	button:SetWidth(width)
	button:SetHeight(BUTTON_HEIGHT)
	return button
end

local function CreateNavButton(parent, name, text, x, y, onClick)
	local button = CreateButton(parent, name, text, x, y, NAV_BUTTON_WIDTH, onClick)
	button.style:SetFontSize(11)
	button:SetWidth(NAV_BUTTON_WIDTH)
	button:SetHeight(BUTTON_HEIGHT)
	return button
end

local function CreateEditBox(parent, id, width)
	local edit = parent:CreateChildWidgetByType(UOT_X2_EDITBOX, id, 0, true)
	edit:SetHeight(BUTTON_HEIGHT)
	edit:SetWidth(width)
	edit:SetInset(5, 4, 5, 4)
	edit:EnableFocus(true)
	edit:UseSelectAllWhenFocused(true)
	edit.style:SetAlign(ALIGN_LEFT)
	edit.style:SetColorByKey("title")

	local bg = edit:CreateDrawable("ui/common/default.dds", "editbox_df", "background")
	bg:AddAnchor("TOPLEFT", edit, 0, 0)
	bg:AddAnchor("BOTTOMRIGHT", edit, 0, 0)
	return edit
end

local function FormatPercent(value)
	value = tonumber(value) or 0
	if value >= 1 then
		return string.format("%.2f%%", value)
	end
	if value >= 0.01 then
		return string.format("%.4f%%", value)
	end
	if value <= 0 then
		return "0%"
	end
	local text = string.format("%.8f%%", value)
	text = text:gsub("0+%%$", "%%")
	return text
end

local function PercentColor(value)
	value = tonumber(value) or 0
	if value >= 50 then
		return COLOR_GREEN
	elseif value >= 5 then
		return COLOR_GOLD
	elseif value >= 1 then
		return COLOR_ORANGE
	end
	return COLOR_RED
end

local function GroupRatePercent(group)
	if group == nil or group.r == nil then
		return nil
	end
	local pct = (tonumber(group.r) or 0) / 100000
	if pct > 100 then
		pct = 100
	end
	return pct
end

local function QuantityText(item)
	local minQty = tonumber(item.mn) or 1
	local maxQty = tonumber(item.mx) or minQty
	if minQty == maxQty then
		return tostring(minQty)
	end
	return tostring(minQty) .. "-" .. tostring(maxQty)
end

local function SortGroupKeys(pack)
	local keys = {}
	if pack ~= nil and type(pack.g) == "table" then
		for key in pairs(pack.g) do
			keys[#keys + 1] = key
		end
		table.sort(keys)
	end
	return keys
end

local function PackNpcText(pack)
	if pack == nil or type(pack.n) ~= "table" or #pack.n == 0 then
		return "no NPC source"
	end
	local names = {}
	for i = 1, #pack.n do
		names[#names + 1] = string.format("#%s %s", tostring(pack.n[i].i), tostring(pack.n[i].nm))
	end
	return table.concat(names, ", ")
end

local function SplitText(text, maxChars, maxLines)
	text = Trim(text)
	maxChars = maxChars or 60
	maxLines = maxLines or 2
	local lines = {}
	while text ~= "" and #lines < maxLines do
		if #text <= maxChars then
			lines[#lines + 1] = text
			text = ""
		else
			local take = maxChars
			for i = maxChars, math.max(1, maxChars - 18), -1 do
				if text:sub(i, i) == " " or text:sub(i, i) == "," then
					take = i
					break
				end
			end
			local line = Trim(text:sub(1, take))
			if line:sub(-1) == "," then
				line = line:sub(1, -2)
			end
			lines[#lines + 1] = line
			text = Trim(text:sub(take + 1))
		end
	end
	if text ~= "" and #lines > 0 then
		local last = lines[#lines]
		if #last > maxChars - 3 then
			last = last:sub(1, maxChars - 3)
		end
		lines[#lines] = last .. "..."
	end
	return lines
end

local function SetSplitLabels(labels, text, maxChars)
	local lines = SplitText(text, maxChars, #labels)
	for i = 1, #labels do
		labels[i]:SetText(lines[i] or "")
	end
end

local function MatchPack(packId, pack, query, numeric, mode)
	local highlight = nil
	if mode == MODE_PACK then
		return tostring(packId) == query, nil
	end
	if mode == MODE_NPC or mode == MODE_ALL then
		for _, npc in ipairs(pack.n or {}) do
			if (numeric and tostring(npc.i) == query) or (not numeric and Contains(npc.nm, query)) then
				return true, "npc:" .. tostring(npc.i)
			end
		end
	end
	if mode == MODE_ITEM or mode == MODE_ALL then
		for _, group in pairs(pack.g or {}) do
			for _, item in ipairs(group.it or {}) do
				if (numeric and tostring(item.item) == query) or (not numeric and Contains(item.nm, query)) then
					highlight = "item:" .. tostring(item.item)
					return true, highlight
				end
			end
		end
	end
	if mode == MODE_ALL then
		if numeric and tostring(packId) == query then
			return true, nil
		end
		if not numeric and Contains(pack.p, query) then
			return true, nil
		end
	end
	return false, highlight
end

local function Search()
	local query = Lower(searchEdit ~= nil and searchEdit:GetText() or "")
	matches = {}
	resultOffset = 1
	selectedMatchIndex = nil
	selectedPackId = nil
	groupOffset = 1

	if query == "" then
		statusLabel:SetText(string.format("Ready - %s packs loaded.", tostring(LootrData and LootrData.packCount or 0)))
		return
	end

	local mode = activeMode
	if mode == MODE_ALL then
		local prefix, rest = query:match("^(%a+):(%d+)$")
		if prefix == MODE_PACK or prefix == MODE_NPC or prefix == MODE_ITEM then
			mode = prefix
			query = rest
		end
	end

	local numeric = query:match("^%d+$") ~= nil
	local total = 0
	for packId, pack in pairs(LootrData.packs or {}) do
		local ok, highlight = MatchPack(packId, pack, query, numeric, mode)
		if ok then
			total = total + 1
			if #matches < MAX_MATCHES then
				matches[#matches + 1] = {
					packId = packId,
					pack = pack,
					highlight = highlight,
				}
			end
		end
	end

	table.sort(matches, function(left, right)
		return left.packId < right.packId
	end)

	if matches[1] ~= nil then
		selectedMatchIndex = 1
		selectedPackId = matches[1].packId
	end

	if total > MAX_MATCHES then
		statusLabel:SetText(string.format("Found %d packs. Showing first %d; refine your search.", total, MAX_MATCHES))
	elseif total == 1 then
		statusLabel:SetText("Found 1 pack.")
	else
		statusLabel:SetText(string.format("Found %d packs.", total))
	end
end

local Refresh

local function SetMode(mode)
	activeMode = mode
	for key, button in pairs(modeButtons) do
		if key == mode then
			SetButtonFontOneColor(button, COLOR_BLUE)
		else
			SetButtonFontOneColor(button, COLOR_MUTED)
		end
	end
	Search()
	Refresh()
end

local function SelectMatch(index)
	if matches[index] == nil then
		return
	end
	selectedMatchIndex = index
	selectedPackId = matches[index].packId
	groupOffset = 1
	Refresh()
end

local function MoveResultPage(delta)
	if #matches == 0 then
		return
	end
	resultOffset = resultOffset + (delta * RESULT_ROWS)
	if resultOffset < 1 then
		resultOffset = 1
	end
	local maxOffset = math.max(1, (#matches - RESULT_ROWS) + 1)
	if resultOffset > maxOffset then
		resultOffset = maxOffset
	end
	Refresh()
end

local function MoveGroupPage(delta)
	if #groupKeys == 0 then
		return
	end
	groupOffset = groupOffset + delta
	if groupOffset < 1 then
		groupOffset = 1
	elseif groupOffset > #groupKeys then
		groupOffset = #groupKeys
	end
	Refresh()
end

local function RenderResults()
	for i = 1, RESULT_ROWS do
		local row = resultRows[i]
		local matchIndex = resultOffset + i - 1
		local match = matches[matchIndex]
		if match == nil then
			row.button:Show(false)
			row.button.matchIndex = nil
			row.packLabel:Show(false)
			row.npcLabel:Show(false)
			row.npcMoreLabel:Show(false)
			row.bg:SetVisible(false)
		else
			local npcLines = SplitText(PackNpcText(match.pack), 35, 2)
			row.matchIndex = matchIndex
			row.button.matchIndex = matchIndex
			row.button:Show(true)
			row.packLabel:Show(true)
			row.npcLabel:Show(true)
			row.npcMoreLabel:Show(true)
			row.packLabel:SetText(string.format("Pack #%s", tostring(match.packId)))
			row.npcLabel:SetText(npcLines[1] or "")
			row.npcMoreLabel:SetText(npcLines[2] or "")
			row.bg:SetVisible(matchIndex == selectedMatchIndex)
			if match.highlight ~= nil then
				SetTextColor(row.npcLabel, COLOR_BLUE)
				SetTextColor(row.npcMoreLabel, COLOR_BLUE)
			else
				SetTextColor(row.npcLabel, COLOR_TEXT)
				SetTextColor(row.npcMoreLabel, COLOR_MUTED)
			end
		end
	end
	local last = math.min(#matches, resultOffset + RESULT_ROWS - 1)
	if #matches == 0 then
		resultPageLabel:SetText("0 / 0")
	else
		resultPageLabel:SetText(string.format("%d-%d / %d", resultOffset, last, #matches))
	end
end

local function RenderItems()
	local selectedPack = selectedPackId ~= nil and LootrData.packs[selectedPackId] or nil
	groupKeys = SortGroupKeys(selectedPack)

	for i = 1, ITEM_ROWS do
		local row = itemRows[i]
		row.name:SetText("")
		row.item:SetText("")
		row.qty:SetText("")
		row.level:SetText("")
		row.chance:SetText("")
		row.bg:SetVisible(false)
	end

	if selectedPack == nil then
		selectedHeader:SetText("No pack selected")
		SetSplitLabels(selectedSubHeaders, "Search by item, NPC, pack ID, or prefix like item:43177.", 84)
		groupHeader:SetText("")
		groupPageLabel:SetText("0 / 0")
		return
	end

	selectedHeader:SetText(string.format("Pack #%s", tostring(selectedPackId)))
	SetSplitLabels(
		selectedSubHeaders,
		(selectedPack.p ~= "" and selectedPack.p or "no pack name") .. "  |  " .. PackNpcText(selectedPack),
		84
	)

	if groupOffset > #groupKeys then
		groupOffset = #groupKeys
	end
	if groupOffset < 1 then
		groupOffset = 1
	end

	local groupId = groupKeys[groupOffset]
	local group = groupId ~= nil and selectedPack.g[groupId] or nil
	if group == nil then
		groupHeader:SetText("No groups")
		groupPageLabel:SetText("0 / 0")
		return
	end

	local rate = GroupRatePercent(group)
	local rateText = rate ~= nil and (" - group rate " .. FormatPercent(rate)) or ""
	local sum = 0
	for _, item in ipairs(group.it or {}) do
		sum = sum + (tonumber(item.dr) or 0)
	end
	local groupKind = groupId == 0 and "Independent rolls" or "Pick 1 from group"
	groupHeader:SetText(
		string.format("Group %s - %s%s - weight sum %s", tostring(groupId), groupKind, rateText, tostring(sum))
	)
	groupPageLabel:SetText(string.format("%d / %d", groupOffset, #groupKeys))

	local selectedHighlight = selectedMatchIndex ~= nil
		and matches[selectedMatchIndex]
		and matches[selectedMatchIndex].highlight
	for i = 1, ITEM_ROWS do
		local item = (group.it or {})[i]
		local row = itemRows[i]
		if item ~= nil then
			row.item:SetText(tostring(item.item))
			row.name:SetText(tostring(item.nm))
			row.level:SetText(item.lv ~= "" and ("Lv." .. tostring(item.lv)) or "")
			row.qty:SetText(QuantityText(item))
			row.chance:SetText(FormatPercent(item.pct))
			SetTextColor(row.chance, PercentColor(item.pct))
			row.bg:SetVisible(selectedHighlight == ("item:" .. tostring(item.item)))
		end
	end
end

Refresh = function()
	if mainWindow == nil then
		return
	end
	RenderResults()
	RenderItems()
end

local function CreateMainWindow()
	if mainWindow ~= nil then
		return
	end

	mainWindow = CreateEmptyWindow("lootrWindow", "UIParent")
	mainWindow:SetExtent(WINDOW_WIDTH, WINDOW_HEIGHT)
	mainWindow:AddAnchor("CENTER", "UIParent", 0, 0)
	mainWindow:SetCloseOnEscape(true)
	mainWindow:EnableDrag(true)
	mainWindow:Show(false)

	CreateWindowBackground(mainWindow)
	CreatePanel(mainWindow, "lootrSearchPanel", 14, 44, -14, -542, 0.16)
	CreatePanel(mainWindow, "lootrResultsPanel", 14, 102, -598, -42, 0.13)
	CreatePanel(mainWindow, "lootrDetailPanel", 336, 102, -14, -42, 0.13)

	mainWindow:SetHandler("OnDragStart", function(self)
		self:StartMoving()
		return true
	end)
	mainWindow:SetHandler("OnDragStop", function(self)
		self:StopMovingOrSizing()
	end)
	mainWindow:SetHandler("OnWheelUp", function()
		MoveGroupPage(-1)
	end)
	mainWindow:SetHandler("OnWheelDown", function()
		MoveGroupPage(1)
	end)

	local title = mainWindow:CreateChildWidget("label", "lootrTitle", 0, true)
	title:SetExtent(58, 24)
	title:AddAnchor("TOPLEFT", mainWindow, 18, 14)
	title:SetText("Lootr")
	StyleLabel(title, 18, ALIGN_LEFT, COLOR_TEXT)

	local warning = mainWindow:CreateChildWidget("label", "lootrWarning", 0, true)
	warning:SetExtent(620, 20)
	warning:AddAnchor("TOPLEFT", mainWindow, 78, 17)
	warning:SetText("Numbers are from 10.2. ArcheRage custom not included. Some bosses you have to x10.")
	StyleLabel(warning, 12, ALIGN_LEFT, COLOR_ORANGE)

	CreateCloseButton(mainWindow, "lootrClose", function()
		mainWindow:Show(false)
	end)

	searchEdit = CreateEditBox(mainWindow, "lootrSearchEdit", 438)
	searchEdit:AddAnchor("TOPLEFT", mainWindow, 80, 58)
	searchEdit:SetGuideText("Search name or ID")
	searchEdit:SetHandler("OnEnterPressed", function()
		Search()
		Refresh()
	end)

	local searchLabel = mainWindow:CreateChildWidget("label", "lootrSearchLabel", 0, true)
	searchLabel:SetExtent(58, 20)
	searchLabel:AddAnchor("TOPLEFT", mainWindow, 22, 58)
	searchLabel:SetText("Search")
	StyleLabel(searchLabel, 13, ALIGN_LEFT, COLOR_TEXT)

	CreateButton(mainWindow, "lootrSearchButton", "Search", 528, 58, 56, function()
		Search()
		Refresh()
	end)

	local x = 620
	modeButtons[MODE_ALL] = CreateButton(mainWindow, "lootrModeAll", "All", x, 58, FILTER_WIDTH, function()
		SetMode(MODE_ALL)
	end)
	modeButtons[MODE_ITEM] = CreateButton(mainWindow, "lootrModeItem", "Item", x + 54, 58, FILTER_WIDTH, function()
		SetMode(MODE_ITEM)
	end)
	modeButtons[MODE_NPC] = CreateButton(mainWindow, "lootrModeNpc", "NPC", x + 108, 58, FILTER_WIDTH, function()
		SetMode(MODE_NPC)
	end)
	modeButtons[MODE_PACK] = CreateButton(mainWindow, "lootrModePack", "Pack", x + 162, 58, FILTER_WIDTH, function()
		SetMode(MODE_PACK)
	end)

	statusLabel = mainWindow:CreateChildWidget("label", "lootrStatus", 0, true)
	statusLabel:SetExtent(650, 20)
	statusLabel:AddAnchor("TOPLEFT", mainWindow, 22, 82)
	StyleLabel(statusLabel, 12, ALIGN_LEFT, COLOR_MUTED)

	hintLabel = mainWindow:CreateChildWidget("label", "lootrHint", 0, true)
	hintLabel:SetExtent(210, 20)
	hintLabel:AddAnchor("TOPRIGHT", mainWindow, -24, 82)
	hintLabel:SetText("pack:12316  npc:18653  item:44913")
	StyleLabel(hintLabel, 11, ALIGN_RIGHT, COLOR_MUTED)

	local resultsTitle = mainWindow:CreateChildWidget("label", "lootrResultsTitle", 0, true)
	resultsTitle:SetExtent(160, 20)
	resultsTitle:AddAnchor("TOPLEFT", mainWindow, 26, 116)
	resultsTitle:SetText("Results")
	StyleLabel(resultsTitle, 13, ALIGN_LEFT, COLOR_TEXT)

	CreateNavButton(mainWindow, "lootrPrevResults", "<", 252, 116, function()
		MoveResultPage(-1)
	end)
	CreateNavButton(mainWindow, "lootrNextResults", ">", 274, 116, function()
		MoveResultPage(1)
	end)
	resultPageLabel = mainWindow:CreateChildWidget("label", "lootrResultPage", 0, true)
	resultPageLabel:SetExtent(102, 20)
	resultPageLabel:AddAnchor("TOPLEFT", mainWindow, 140, 116)
	StyleLabel(resultPageLabel, 11, ALIGN_RIGHT, COLOR_MUTED)

	for i = 1, RESULT_ROWS do
		local y = 146 + ((i - 1) * RESULT_ROW_HEIGHT)
		local button = mainWindow:CreateChildWidget("emptywidget", "lootrResultHit" .. tostring(i), i, true)
		button:SetExtent(290, RESULT_ROW_HEIGHT - 2)
		button:AddAnchor("TOPLEFT", mainWindow, 24, y)
		button:Show(false)
		button:EnablePick(true)

		local bg = button:CreateColorDrawable(
			COLOR_SELECTED[1],
			COLOR_SELECTED[2],
			COLOR_SELECTED[3],
			COLOR_SELECTED[4],
			"background"
		)
		bg:AddAnchor("TOPLEFT", button, 0, 0)
		bg:AddAnchor("BOTTOMRIGHT", button, 0, 0)
		bg:SetVisible(false)
		button.bg = bg

		local packLabel = button:CreateChildWidget("label", "lootrResultPack" .. tostring(i), i, true)
		packLabel:SetExtent(90, 24)
		packLabel:AddAnchor("TOPLEFT", button, 6, 2)
		packLabel:SetText("")
		packLabel:EnablePick(false)
		StyleLabel(packLabel, 12, ALIGN_LEFT, COLOR_BLUE)

		local npcLabel = button:CreateChildWidget("label", "lootrResultNpc" .. tostring(i), i, true)
		npcLabel:SetExtent(184, 18)
		npcLabel:AddAnchor("TOPLEFT", button, 98, 2)
		npcLabel:SetText("")
		npcLabel:EnablePick(false)
		StyleLabel(npcLabel, 11, ALIGN_LEFT, COLOR_TEXT)

		local npcMoreLabel = button:CreateChildWidget("label", "lootrResultNpcMore" .. tostring(i), i, true)
		npcMoreLabel:SetExtent(276, 18)
		npcMoreLabel:AddAnchor("TOPLEFT", button, 6, 20)
		npcMoreLabel:SetText("")
		npcMoreLabel:EnablePick(false)
		StyleLabel(npcMoreLabel, 10, ALIGN_LEFT, COLOR_MUTED)

		button:SetHandler("OnClick", function(self)
			SelectMatch(self.matchIndex)
		end)
		button:SetHandler("OnEnter", function(self)
			if self.matchIndex ~= selectedMatchIndex then
				self.bg:SetColor(COLOR_HOVER[1], COLOR_HOVER[2], COLOR_HOVER[3], COLOR_HOVER[4])
				self.bg:SetVisible(true)
			end
		end)
		button:SetHandler("OnLeave", function(self)
			self.bg:SetColor(COLOR_SELECTED[1], COLOR_SELECTED[2], COLOR_SELECTED[3], COLOR_SELECTED[4])
			self.bg:SetVisible(self.matchIndex == selectedMatchIndex)
		end)

		resultRows[i] =
			{ button = button, bg = bg, packLabel = packLabel, npcLabel = npcLabel, npcMoreLabel = npcMoreLabel }
	end

	selectedHeader = mainWindow:CreateChildWidget("label", "lootrSelectedHeader", 0, true)
	selectedHeader:SetExtent(250, 22)
	selectedHeader:AddAnchor("TOPLEFT", mainWindow, 350, 116)
	StyleLabel(selectedHeader, 15, ALIGN_LEFT, COLOR_BLUE)

	CreateNavButton(mainWindow, "lootrPrevGroup", "<", 800, 116, function()
		MoveGroupPage(-1)
	end)
	CreateNavButton(mainWindow, "lootrNextGroup", ">", 822, 116, function()
		MoveGroupPage(1)
	end)
	groupPageLabel = mainWindow:CreateChildWidget("label", "lootrGroupPage", 0, true)
	groupPageLabel:SetExtent(60, 20)
	groupPageLabel:AddAnchor("TOPLEFT", mainWindow, 732, 116)
	StyleLabel(groupPageLabel, 11, ALIGN_RIGHT, COLOR_MUTED)

	for i = 1, 3 do
		local label = mainWindow:CreateChildWidget("label", "lootrSelectedSub" .. tostring(i), i, true)
		label:SetExtent(532, 16)
		label:AddAnchor("TOPLEFT", mainWindow, 350, 138 + ((i - 1) * 14))
		StyleLabel(label, 10, ALIGN_LEFT, COLOR_MUTED)
		selectedSubHeaders[i] = label
	end

	groupHeader = mainWindow:CreateChildWidget("label", "lootrGroupHeader", 0, true)
	groupHeader:SetExtent(540, 20)
	groupHeader:AddAnchor("TOPLEFT", mainWindow, 350, 184)
	StyleLabel(groupHeader, 12, ALIGN_LEFT, COLOR_TEXT)

	CreateLine(mainWindow, "lootrItemHeaderLine", 350, 212, 536)

	local headers = {
		{ "Item ID", 350, 86, ALIGN_LEFT },
		{ "Name", 436, 260, ALIGN_LEFT },
		{ "Level", 696, 54, ALIGN_LEFT },
		{ "Qty", 750, 44, ALIGN_LEFT },
		{ "Drop Chance", 794, 90, ALIGN_RIGHT },
	}
	for i = 1, #headers do
		local h = headers[i]
		local label = mainWindow:CreateChildWidget("label", "lootrHeader" .. tostring(i), i, true)
		label:SetExtent(h[3], 18)
		label:AddAnchor("TOPLEFT", mainWindow, h[2], 218)
		label:SetText(h[1])
		StyleLabel(label, 11, h[4], COLOR_MUTED)
	end

	for i = 1, ITEM_ROWS do
		local y = 240 + ((i - 1) * ITEM_ROW_HEIGHT)
		local bg = mainWindow:CreateColorDrawable(
			COLOR_SELECTED[1],
			COLOR_SELECTED[2],
			COLOR_SELECTED[3],
			COLOR_SELECTED[4],
			"background"
		)
		bg:SetExtent(536, ITEM_ROW_HEIGHT)
		bg:AddAnchor("TOPLEFT", mainWindow, 350, y)
		bg:SetVisible(false)

		local itemId = mainWindow:CreateChildWidget("label", "lootrItemId" .. tostring(i), i, true)
		itemId:SetExtent(80, 18)
		itemId:AddAnchor("TOPLEFT", mainWindow, 350, y + 1)
		StyleLabel(itemId, 11, ALIGN_LEFT, COLOR_MUTED)

		local name = mainWindow:CreateChildWidget("label", "lootrItemName" .. tostring(i), i, true)
		name:SetExtent(254, 18)
		name:AddAnchor("TOPLEFT", mainWindow, 436, y + 1)
		StyleLabel(name, 12, ALIGN_LEFT, COLOR_TEXT)

		local level = mainWindow:CreateChildWidget("label", "lootrItemLevel" .. tostring(i), i, true)
		level:SetExtent(48, 18)
		level:AddAnchor("TOPLEFT", mainWindow, 696, y + 1)
		StyleLabel(level, 11, ALIGN_LEFT, COLOR_MUTED)

		local qty = mainWindow:CreateChildWidget("label", "lootrItemQty" .. tostring(i), i, true)
		qty:SetExtent(38, 18)
		qty:AddAnchor("TOPLEFT", mainWindow, 750, y + 1)
		StyleLabel(qty, 11, ALIGN_LEFT, COLOR_MUTED)

		local chance = mainWindow:CreateChildWidget("label", "lootrItemChance" .. tostring(i), i, true)
		chance:SetExtent(90, 18)
		chance:AddAnchor("TOPLEFT", mainWindow, 794, y + 1)
		StyleLabel(chance, 12, ALIGN_RIGHT, COLOR_GREEN)

		itemRows[i] = { bg = bg, item = itemId, name = name, level = level, qty = qty, chance = chance }
	end

	SetMode(MODE_ALL)
	Search()
	Refresh()
end

local function ToggleWindow()
	CreateMainWindow()
	local show = not mainWindow:IsVisible()
	mainWindow:Show(show)
	if show then
		mainWindow:Raise()
	end
end

launcherButton = CreateSimpleButton("Lootr", 700, -460)
launcherButton:SetHandler("OnClick", ToggleWindow)

function Lootr_Search(text)
	CreateMainWindow()
	searchEdit:SetText(tostring(text or ""))
	Search()
	Refresh()
	mainWindow:Show(true)
	mainWindow:Raise()
end
