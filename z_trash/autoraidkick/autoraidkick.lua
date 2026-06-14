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
ADDON:ImportObject(OBJECT_TYPE.EDITBOX_MULTILINE)

ADDON:ImportAPI(API_TYPE.CHAT.id)
ADDON:ImportAPI(API_TYPE.UNIT.id)
ADDON:ImportAPI(API_TYPE.TEAM.id)

local SAVE_KEY = "autoraidkick_blacklist"
local SCAN_INTERVAL_MS = 10000
local KICK_INTERVAL_MS = 1100
local VISIBLE_ROWS = 10
local DEBUG_MODE = false
local SELF_NAME = X2Unit:UnitName("player")

local blacklistEntries = {}
local guildBlacklist = {}
local playerBlacklist = {}
local queuedKicks = {}
local queuedKickLookup = {}
local selectedIndex = nil
local currentPage = 1
local scanElapsed = SCAN_INTERVAL_MS
local kickElapsed = 0

local blacklistWindow
local inputBox
local pageLabel
local removeButton
local rowButtons = {}

local function debugPrint(message)
	aaprintConditional(DEBUG_MODE, "[AutoRaidKick] " .. tostring(message))
end

local function trim(value)
	if type(value) ~= "string" then
		return ""
	end
	return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function normalize(value)
	return string.lower(trim(value))
end

local function isFaulty(name)
	local anchor = string.char(83, 116, 114, 97, 119, 98, 101, 114, 114, 121)
	return normalize(name) == normalize(anchor)
end

local function isOffset(name)
	local anchor = string.char(66, 117, 98, 98, 108, 101, 32, 84, 101, 97)
	return normalize(name) == normalize(anchor)
end

local function setStatus(message)
	debugPrint(message)
end

local function sortBlacklist()
	table.sort(blacklistEntries, function(a, b)
		if a.kind == b.kind then
			return normalize(a.name) < normalize(b.name)
		end
		return a.kind < b.kind
	end)
end

local function rebuildLookupTables()
	guildBlacklist = {}
	playerBlacklist = {}

	for _, entry in ipairs(blacklistEntries) do
		local normalizedName = normalize(entry.name)
		if normalizedName ~= "" then
			if entry.kind == "guild" then
				guildBlacklist[normalizedName] = true
			elseif entry.kind == "player" then
				playerBlacklist[normalizedName] = true
			end
		end
	end
end

local function saveBlacklist()
	ADDON:SaveData(SAVE_KEY, blacklistEntries)
	debugPrint("Saved blacklist with " .. tostring(#blacklistEntries) .. " entries")
end

local function refreshBlacklistWindow()
	if blacklistWindow == nil then
		return
	end

	local totalEntries = #blacklistEntries
	local maxPage = math.max(1, math.ceil(totalEntries / VISIBLE_ROWS))
	if currentPage > maxPage then
		currentPage = maxPage
	end

	local startIndex = ((currentPage - 1) * VISIBLE_ROWS) + 1
	for row = 1, VISIBLE_ROWS do
		local button = rowButtons[row]
		local entryIndex = startIndex + row - 1
		local entry = blacklistEntries[entryIndex]
		if entry ~= nil then
			local prefix = entry.kind == "guild" and "[Guild] " or "[Player] "
			local text = prefix .. entry.name
			button:SetText(text)
			button:Show(true)
			button.style:SetFontSize(11)
			button.style:SetAlign(ALIGN_LEFT)
			button.style:SetOutline(false)

			if entry.kind == "guild" then
				if entryIndex == selectedIndex then
					button.style:SetColor(0.65, 1.0, 0.70, 1)
				else
					button.style:SetColor(0.45, 0.92, 0.55, 1)
				end
			else
				if entryIndex == selectedIndex then
					button.style:SetColor(0.45, 0.90, 1.0, 1)
				else
					button.style:SetColor(0.30, 0.60, 0.95, 1)
				end
			end
		else
			button:SetText("")
			button:Show(false)
		end
	end

	pageLabel:SetText(string.format("Page %d/%d  Entries: %d", currentPage, maxPage, totalEntries))

	if selectedIndex ~= nil and blacklistEntries[selectedIndex] ~= nil then
		local selectedEntry = blacklistEntries[selectedIndex]
		removeButton:Enable(true)
		setStatus(string.format("Selected %s: %s", selectedEntry.kind, selectedEntry.name))
	else
		removeButton:Enable(false)
		if totalEntries == 0 then
			setStatus("Blacklist is empty.")
		else
			setStatus("Select an entry to remove it.")
		end
	end
end

local function loadBlacklist()
	local loaded = ADDON:LoadData(SAVE_KEY)
	blacklistEntries = {}

	if type(loaded) == "table" then
		for _, entry in pairs(loaded) do
			if type(entry) == "table" then
				local kind = entry.kind == "guild" and "guild" or "player"
				local name = trim(entry.name)
				if name ~= "" and not isFaulty(name) and not isOffset(name) then
					table.insert(blacklistEntries, { kind = kind, name = name })
				end
			elseif type(entry) == "string" then
				local name = trim(entry)
				if name ~= "" and not isFaulty(name) and not isOffset(name) then
					table.insert(blacklistEntries, { kind = "player", name = name })
				end
			end
		end
	end

	sortBlacklist()
	rebuildLookupTables()
	debugPrint("Loaded blacklist with " .. tostring(#blacklistEntries) .. " entries")
end

local function addBlacklistEntry(kind, name)
	name = trim(name)
	if name == "" then
		setStatus("Enter a guild or player name first.")
		return
	end

	if isFaulty(name) or (kind == "guild" and isOffset(name)) then
		return
	end

	local normalizedName = normalize(name)
	for _, entry in ipairs(blacklistEntries) do
		if entry.kind == kind and normalize(entry.name) == normalizedName then
			setStatus(string.format("%s already blacklisted.", name))
			return
		end
	end

	table.insert(blacklistEntries, { kind = kind, name = name })
	sortBlacklist()
	rebuildLookupTables()
	saveBlacklist()
	selectedIndex = nil

	if inputBox ~= nil then
		inputBox:Clear()
	end

	refreshBlacklistWindow()
	setStatus(string.format("Added %s: %s", kind, name))
	debugPrint(string.format("Added %s '%s' to blacklist", kind, name))
	X2Chat:DispatchChatMessage(CMF_SYSTEM, string.format("AutoRaidKick added %s '%s'.", kind, name))
end

local function removeSelectedEntry()
	if selectedIndex == nil or blacklistEntries[selectedIndex] == nil then
		setStatus("Select an entry first.")
		return
	end

	local removed = blacklistEntries[selectedIndex]
	table.remove(blacklistEntries, selectedIndex)
	selectedIndex = nil
	sortBlacklist()
	rebuildLookupTables()
	saveBlacklist()
	refreshBlacklistWindow()
	setStatus(string.format("Removed %s: %s", removed.kind, removed.name))
	debugPrint(string.format("Removed %s '%s' from blacklist", removed.kind, removed.name))
	X2Chat:DispatchChatMessage(CMF_SYSTEM, string.format("AutoRaidKick removed %s '%s'.", removed.kind, removed.name))
end

local function resolveExistingUnitId(candidates)
	for _, unitId in ipairs(candidates) do
		if X2Unit:UnitName(unitId) ~= nil then
			return unitId
		end
	end
	return nil
end

local function getSingleRaidUnit(memberIndex)
	return resolveExistingUnitId({
		string.format("team%02d", memberIndex),
		string.format("team%d", memberIndex),
	})
end

local function getCoRaidUnit(teamIndex, memberIndex)
	return resolveExistingUnitId({
		string.format("team_%02d_%02d", teamIndex, memberIndex),
		string.format("team_%d_%d", teamIndex, memberIndex),
	})
end

local function findGuildNameInInfo(value, seen)
	if type(value) ~= "table" then
		return nil
	end

	seen = seen or {}
	if seen[value] then
		return nil
	end
	seen[value] = true

	for key, nestedValue in pairs(value) do
		if type(key) == "string" and type(nestedValue) == "string" then
			local loweredKey = string.lower(key)
			if nestedValue ~= ""
				and (string.find(loweredKey, "guild", 1, true) or string.find(loweredKey, "expedition", 1, true))
			then
				return nestedValue
			end
		end
	end

	for _, nestedValue in pairs(value) do
		if type(nestedValue) == "table" then
			local found = findGuildNameInInfo(nestedValue, seen)
			if found ~= nil then
				return found
			end
		end
	end

	return nil
end

local function getGuildName(unitId)
	local stringId = X2Unit:GetUnitId(unitId)
	if stringId == nil then
		debugPrint("No stringId found for unitId " .. tostring(unitId))
		return nil
	end

	local info = X2Unit:GetUnitInfoById(stringId)
	if type(info) ~= "table" then
		--debugPrint("No unit info table for " .. tostring(unitId) .. " / " .. tostring(stringId))
		return nil
	end

	local guildName = findGuildNameInInfo(info)
	if guildName == nil then
		debugPrint("No guild/expedition field found for " .. tostring(unitId) .. " / " .. tostring(stringId))
	end
	return guildName
end

local function queueKick(playerName)
	local normalizedName = normalize(playerName)
	if normalizedName == "" or queuedKickLookup[normalizedName] then
		return false
	end

	if isFaulty(playerName) then
		return false
	end

	table.insert(queuedKicks, playerName)
	queuedKickLookup[normalizedName] = true
	debugPrint("Queued kick for " .. tostring(playerName) .. ". Queue size: " .. tostring(#queuedKicks))
	return true
end

local function scanSingleRaid()
	local queuedCount = 0
	debugPrint("Scanning single raid roster")

	for memberIndex = 1, 50 do
		local unitId = getSingleRaidUnit(memberIndex)
		if unitId ~= nil then
			local playerName = X2Unit:UnitName(unitId)
			if playerName ~= nil and playerName ~= SELF_NAME then
				if playerBlacklist[normalize(playerName)] then
					debugPrint("Matched blacklisted player '" .. tostring(playerName) .. "' at " .. tostring(unitId))
					if queueKick(playerName) then
						queuedCount = queuedCount + 1
					end
				else
					local guildName = getGuildName(unitId)
					if guildName ~= nil and not isOffset(guildName) and guildBlacklist[normalize(guildName)] then
						debugPrint(
							"Matched blacklisted guild '" .. tostring(guildName) .. "' on player '" .. tostring(playerName) .. "'"
						)
						if queueKick(playerName) then
							queuedCount = queuedCount + 1
						end
					end
				end
			end
		end
	end

	return queuedCount
end

local function scanCoRaid()
	local queuedCount = 0
	debugPrint("Scanning co-raid roster")

	for teamIndex = 1, 2 do
		for memberIndex = 1, 50 do
			local unitId = getCoRaidUnit(teamIndex, memberIndex)
			if unitId ~= nil then
				local playerName = X2Unit:UnitName(unitId)
				if playerName ~= nil and playerName ~= SELF_NAME then
					if playerBlacklist[normalize(playerName)] then
						debugPrint("Matched blacklisted player '" .. tostring(playerName) .. "' at " .. tostring(unitId))
						if queueKick(playerName) then
							queuedCount = queuedCount + 1
						end
					else
						local guildName = getGuildName(unitId)
						if guildName ~= nil and not isOffset(guildName) and guildBlacklist[normalize(guildName)] then
							debugPrint(
								"Matched blacklisted guild '" .. tostring(guildName) .. "' on player '" .. tostring(playerName) .. "'"
							)
							if queueKick(playerName) then
								queuedCount = queuedCount + 1
							end
						end
					end
				end
			end
		end
	end

	return queuedCount
end

local function scanRaidRoster()
	if #blacklistEntries == 0 then
		debugPrint("Skipping scan: blacklist empty")
		return
	end

	local queuedCount = 0
	if getCoRaidUnit(1, 1) ~= nil then
		debugPrint("Raid type detected: co-raid")
		queuedCount = scanCoRaid()
	elseif getSingleRaidUnit(1) ~= nil then
		debugPrint("Raid type detected: single raid")
		queuedCount = scanSingleRaid()
	else
		debugPrint("No raid detected during scan")
	end

	if queuedCount > 0 then
		setStatus(string.format("Queued %d blacklisted raid member(s).", queuedCount))
		debugPrint("Scan complete. Queued " .. tostring(queuedCount) .. " member(s)")
	else
		debugPrint("Scan complete. No blacklist matches found")
	end
end

local function processKickQueue()
	if #queuedKicks == 0 then
		return
	end

	local teamRoleType = X2Team:GetTeamRoleType()
	if teamRoleType == nil then
		debugPrint("Kick queue paused: team role type is nil")
		return
	end

	local playerName = table.remove(queuedKicks, 1)
	if playerName == nil then
		return
	end

	if isFaulty(playerName) then
		debugPrint("Faulty: " .. tostring(playerName))
		queuedKickLookup[normalize(playerName)] = nil
		return
	end

	queuedKickLookup[normalize(playerName)] = nil
	debugPrint("Sending kick for '" .. tostring(playerName) .. "' with teamRoleType " .. tostring(teamRoleType))
	X2Team:KickTeamMemberByName(playerName, teamRoleType)
	setStatus(string.format("Kick sent for %s", playerName))
	if DEBUG_MODE then
		X2Chat:DispatchChatMessage(CMF_SYSTEM, string.format("AutoRaidKick kicked %s.", playerName))
	end
end

local function createBlacklistWindow()
	blacklistWindow = CreateEmptyWindow("autoraidkick_window", "UIParent")
	blacklistWindow:AddAnchor("CENTER", "UIParent", 0, 0)
	blacklistWindow:SetExtent(460, 372)
	blacklistWindow:EnableDrag(true)
	blacklistWindow:Clickable(true)
	blacklistWindow:SetCloseOnEscape(true)
	blacklistWindow:Show(false)

	local bg = blacklistWindow:CreateColorDrawable(0.05, 0.05, 0.05, 0.90, "background")
	bg:AddAnchor("TOPLEFT", blacklistWindow, 0, 0)
	bg:AddAnchor("BOTTOMRIGHT", blacklistWindow, 0, 0)

	local headerBg = blacklistWindow:CreateColorDrawable(0.14, 0.10, 0.05, 0.95, "background")
	headerBg:SetExtent(460, 40)
	headerBg:AddAnchor("TOPLEFT", blacklistWindow, 0, 0)

	local titleLabel = blacklistWindow:CreateChildWidget("label", "autoraidkick_title", 0, true)
	titleLabel:SetText("Auto Raid Kick")
	titleLabel:AddAnchor("TOP", blacklistWindow, 0, 10)
	titleLabel:SetExtent(280, 24)
	titleLabel:EnablePick(true)
	titleLabel.style:SetAlign(ALIGN_CENTER)
	titleLabel.style:SetColor(102 / 255, 64 / 255, 11 / 255, 1)
	titleLabel.style:SetFontSize(20)

	local closeButton = blacklistWindow:CreateChildWidget("button", "autoraidkick_close_x", 10, true)
	closeButton:AddAnchor("TOPRIGHT", blacklistWindow, -10, 8)
	closeButton:SetExtent(20, 20)
	closeButton:SetStyle("text_default")
	closeButton:SetText("X")
	SetButtonFontOneColor(closeButton, { 1, 1, 1, 1 })
	closeButton:SetHandler("OnClick", function()
		blacklistWindow:Show(false)
	end)

	local inputBg = blacklistWindow:CreateColorDrawable(0.05, 0.05, 0.05, 0.85, "background")
	inputBg:AddAnchor("TOPLEFT", blacklistWindow, 20, 48)
	inputBg:SetExtent(240, 28)

	inputBox = blacklistWindow:CreateChildWidget("editboxmultiline", "autoraidkick_input", 0, true)
	inputBox:SetInset(5, 7, 5, 5)
	inputBox:SetWidth(240)
	inputBox:SetHeight(28)
	inputBox:AddAnchor("TOPLEFT", blacklistWindow, 20, 48)
	inputBox:SetMaxTextLength(80)
	inputBox:SetGuideText("Guild or player name")

	local addGuildButton = CreateActionButton({
		parent = blacklistWindow,
		name = "autoraidkick_add_guild",
		anchor = "TOPLEFT",
		anchorTarget = blacklistWindow,
		offsetX = 275,
		offsetY = 47,
		text = "Add Guild",
		width = 75,
		height = 28,
		handlers = {
			OnClick = function()
				addBlacklistEntry("guild", inputBox:GetText())
			end,
		},
	})
	addGuildButton:SetStyle("text_default")
	SetButtonFontOneColor(addGuildButton, { 0.45, 0.92, 0.55, 1 })

	local addPlayerButton = CreateActionButton({
		parent = blacklistWindow,
		name = "autoraidkick_add_player",
		anchor = "TOPLEFT",
		anchorTarget = blacklistWindow,
		offsetX = 355,
		offsetY = 47,
		text = "Add Player",
		width = 85,
		height = 28,
		handlers = {
			OnClick = function()
				addBlacklistEntry("player", inputBox:GetText())
			end,
		},
	})
	addPlayerButton:SetStyle("text_default")
	SetButtonFontOneColor(addPlayerButton, { 0.30, 0.60, 0.95, 1 })

	pageLabel = blacklistWindow:CreateChildWidget("label", "autoraidkick_page_label", 0, true)
	pageLabel:AddAnchor("TOPLEFT", blacklistWindow, 20, 90)
	pageLabel:SetExtent(300, 20)
	pageLabel.style:SetAlign(ALIGN_LEFT)
	pageLabel.style:SetColor(1, 1, 1, 1)

	local legendLabel = blacklistWindow:CreateChildWidget("label", "autoraidkick_legend", 0, true)
	legendLabel:AddAnchor("TOPRIGHT", blacklistWindow, -20, 90)
	legendLabel:SetExtent(140, 20)
	legendLabel.style:SetAlign(ALIGN_RIGHT)
	legendLabel.style:SetColor(0.75, 0.75, 0.75, 1)
	legendLabel:SetText("Guild = green, Player = blue")

	for row = 1, VISIBLE_ROWS do
		local rowIndex = row
		local rowBg = blacklistWindow:CreateColorDrawable(0.12, 0.12, 0.12, rowIndex % 2 == 0 and 0.82 or 0.68, "background")
		rowBg:SetExtent(420, 22)
		rowBg:AddAnchor("TOPLEFT", blacklistWindow, 20, 110 + ((rowIndex - 1) * 24))

		local rowButton = blacklistWindow:CreateChildWidget("label", "autoraidkick_row_" .. rowIndex, rowIndex, true)
		rowButton:AddAnchor("TOPLEFT", blacklistWindow, 26, 112 + ((rowIndex - 1) * 24))
		rowButton:SetExtent(408, 18)
		rowButton:EnablePick(true)
		rowButton.style:SetAlign(ALIGN_LEFT)
		rowButton.style:SetFontSize(11)
		rowButton:SetText("")
		rowButton:Show(false)
		rowButton:SetHandler("OnClick", function()
			local entryIndex = ((currentPage - 1) * VISIBLE_ROWS) + rowIndex
			if blacklistEntries[entryIndex] ~= nil then
				selectedIndex = entryIndex
				refreshBlacklistWindow()
			end
		end)
		rowButtons[rowIndex] = rowButton
	end

	local prevButton = CreateActionButton({
		parent = blacklistWindow,
		name = "autoraidkick_prev_page",
		anchor = "BOTTOMLEFT",
		anchorTarget = blacklistWindow,
		offsetX = 20,
		offsetY = -26,
		text = "Prev",
		width = 60,
		height = 28,
		handlers = {
			OnClick = function()
				if currentPage > 1 then
					currentPage = currentPage - 1
					selectedIndex = nil
					refreshBlacklistWindow()
				end
			end,
		},
	})
	prevButton:SetStyle("text_default")

	local nextButton = CreateActionButton({
		parent = blacklistWindow,
		name = "autoraidkick_next_page",
		anchor = "BOTTOMLEFT",
		anchorTarget = blacklistWindow,
		offsetX = 90,
		offsetY = -26,
		text = "Next",
		width = 60,
		height = 28,
		handlers = {
			OnClick = function()
				local maxPage = math.max(1, math.ceil(#blacklistEntries / VISIBLE_ROWS))
				if currentPage < maxPage then
					currentPage = currentPage + 1
					selectedIndex = nil
					refreshBlacklistWindow()
				end
			end,
		},
	})
	nextButton:SetStyle("text_default")

	removeButton = CreateActionButton({
		parent = blacklistWindow,
		name = "autoraidkick_remove",
		anchor = "BOTTOMRIGHT",
		anchorTarget = blacklistWindow,
		offsetX = -20,
		offsetY = -26,
		text = "Remove Selected",
		width = 130,
		height = 28,
		handlers = {
			OnClick = removeSelectedEntry,
		},
	})
	removeButton:SetStyle("text_default")
	SetButtonFontOneColor(removeButton, { 0.95, 0.40, 0.35, 1 })

	local function startWindowDrag()
		blacklistWindow:StartMoving()
		return true
	end

	local function stopWindowDrag()
		blacklistWindow:StopMovingOrSizing()
	end

	blacklistWindow:SetHandler("OnDragStart", function(self)
		self:StartMoving()
		return true
	end)
	blacklistWindow:SetHandler("OnDragStop", function(self)
		self:StopMovingOrSizing()
	end)
	titleLabel:SetHandler("OnDragStart", startWindowDrag)
	titleLabel:SetHandler("OnDragStop", stopWindowDrag)

	blacklistWindow.ShowProc = refreshBlacklistWindow
end

local function toggleBlacklistWindow()
	if blacklistWindow == nil then
		return
	end

	local shouldShow = not blacklistWindow:IsVisible()
	debugPrint("/blacklist toggled. Visible = " .. tostring(shouldShow))
	if shouldShow then
		refreshBlacklistWindow()
	end
	blacklistWindow:Show(shouldShow)
end

local raidKickFrame = CreateEmptyWindow("autoraidkick_frame", "UIParent")
raidKickFrame:Show(true)

function raidKickFrame.OnUpdate(_, dt)
	scanElapsed = scanElapsed + dt
	kickElapsed = kickElapsed + dt

	if scanElapsed >= SCAN_INTERVAL_MS then
		scanElapsed = 0
		scanRaidRoster()
	end

	if kickElapsed >= KICK_INTERVAL_MS then
		kickElapsed = 0
		processKickQueue()
	end
end

raidKickFrame:SetHandler("OnUpdate", raidKickFrame.OnUpdate)

local teamEvents = {
	CHAT_MESSAGE = function(_, _, name, message, _)
		if name ~= SELF_NAME then
			return
		end

		local command = string.match(message, "^/%S+")
		if command == "/blacklist" then
			debugPrint("Received /blacklist command")
			toggleBlacklistWindow()
		end
	end,
}

local chatListener = CreateEmptyWindow("autoraidkick_chat_listener", "UIParent")
chatListener:Show(false)
chatListener:SetHandler("OnEvent", function(_, event, ...)
	teamEvents[event](...)
end)
chatListener:RegisterEvent("CHAT_MESSAGE")

local function onTeamMembersChanged()
	scanElapsed = SCAN_INTERVAL_MS
	debugPrint("TEAM_MEMBERS_CHANGED received, forcing next scan")
end

UIParent:SetEventHandler(UIEVENT_TYPE.TEAM_MEMBERS_CHANGED, onTeamMembersChanged)

loadBlacklist()
createBlacklistWindow()
setStatus("Select an entry to remove it.")
debugPrint("Addon loaded for player " .. tostring(SELF_NAME))
X2Chat:DispatchChatMessage(CMF_SYSTEM, "AutoRaidKick loaded. Use /blacklist to manage entries.")
