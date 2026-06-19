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
ADDON:ImportObject(OBJECT_TYPE.ICON_DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.IMAGE_DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.EDITBOX_MULTILINE)

ADDON:ImportAPI(API_TYPE.CHAT.id)
ADDON:ImportAPI(API_TYPE.UNIT.id)
ADDON:ImportAPI(API_TYPE.TEAM.id)
ADDON:ImportAPI(API_TYPE.LOCALE.id)

local SAVE_KEY = "raidmanager_settings"
local MARKS_SAVE_KEY = "raidmanager_saved_marks"
local WINDOW_WIDTH = 690
local WINDOW_HEIGHT = 520
local LEFT_WIDTH = 150
local BUTTON_HEIGHT = 24
local ROW_HEIGHT = 22
local VISIBLE_ROWS = 11
local SCAN_INTERVAL_MS = 10000
local DISTANCE_SCAN_INTERVAL_MS = 1000
local SORT_RAID_INTERVAL_MS = 1000
local MARK_INTERVAL_MS = 1000
local KICK_INTERVAL_MS = 1100
local FIXGARDEN_DISTANCE = 25000
local SELF_NAME = X2Unit:UnitName("player")

local DEFAULT_RAID_BUFFS = {
	drum = { 5700, 32233, 32234, 32235, 32236, 32237, 32238, 32239 },
	statue = { 9002339, 48778, 9002340, 30768, 30765, 30766, 30770, 30760, 30764, 30767, 1, 1 },
	book = { 20552, 21795 },
	ribs = { 685, 693, 597, 689, 693, 21791, 21792, 21793, 21794 },
	goblet = {
		7685,
		21796,
		21801,
		21806,
		21811,
		21819,
		21846,
		7686,
		21797,
		21802,
		21807,
		21812,
		21820,
		7687,
		21798,
		21803,
		21808,
		21813,
		21821,
		7688,
		21799,
		21804,
		21809,
		21814,
		21822,
		7689,
		21800,
		21805,
		21810,
		21815,
		21823,
		24469,
		24470,
		24471,
		24472,
		24473,
		24474,
	},
}

local DEFAULT_SIEGE_BUFFS = {
	catapult = { 31757 },
	clad = { 25088 },
	flamethrower = { 28315 },
}

local DEFAULT_BANNED_CLASSES = {
	"Blade Dancer",
	"Fanatic",
}

local state = {
	settings = {
		kickMode = "blacklist",
		kickEnabled = false,
		kickEntries = {},
		raidBuffs = {},
		siegeBuffs = {},
		bannedClasses = {},
		fixgardenEnabled = false,
		distanceKickEnabled = false,
		distanceKickMeters = 25000,
	},
	kickLookup = {
		player = {},
		guild = {},
	},
	kickQueue = {},
	kickQueued = {},
	classResults = {},
	bannedPlayers = {},
	activeSection = "autokick",
	selectedKickIndex = nil,
	selectedClassIndex = nil,
	selectedBannedClassIndex = nil,
	kickPage = 1,
	scanElapsed = SCAN_INTERVAL_MS,
	distanceElapsed = DISTANCE_SCAN_INTERVAL_MS,
	sortRaidElapsed = SORT_RAID_INTERVAL_MS,
	markElapsed = MARK_INTERVAL_MS,
	kickElapsed = 0,
	sortRaidActive = false,
	markQueue = {},
	markBusy = false,
}

local mainWindow
local contentPanel
local statusLabel
local sectionTitle
local sectionButtons = {}
local sectionWidgets = {}
local kickRows = {}
local kickInput
local kickPageLabel
local kickRemoveButton
local kickModeButton
local kickEnabledButton
local buffCategoryInput
local buffIdInput
local buffMissingRows = {}
local buffMissingResults = {}
local buffMissingOffset = 1
local bannedClassInput
local bannedClassDropdown
local bannedClassLabel
local bannedClassRemoveButton
local bannedClassRows = {}
local allClassNames
local fixgardenButton
local distanceKickButton
local distanceKickInput
local sortRaidStartButton
local sortRaidStopButton
local sortRaidStatusLabel
local autoMarkStatusLabel
local lootRows = {}
local gearRows = {}
local classRows = {}

local function Chat(message)
	X2Chat:DispatchChatMessage(CMF_SYSTEM, "[RaidManager] " .. tostring(message))
end

local function Trim(value)
	if type(value) ~= "string" then
		return ""
	end
	return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function Normalize(value)
	return string.lower(Trim(value))
end

local function CopyTable(value)
	local copy = {}
	if type(value) ~= "table" then
		return copy
	end
	for key, item in pairs(value) do
		if type(item) == "table" then
			copy[key] = CopyTable(item)
		else
			copy[key] = item
		end
	end
	return copy
end

local function SetStatus(message)
	if statusLabel ~= nil then
		statusLabel:SetText(tostring(message or ""))
	end
end

local function SaveSettings()
	ADDON:SaveData(SAVE_KEY, state.settings)
end

local function SortEntries(entries)
	table.sort(entries, function(left, right)
		if left.kind == right.kind then
			return Normalize(left.name) < Normalize(right.name)
		end
		return tostring(left.kind) < tostring(right.kind)
	end)
end

local function RebuildKickLookup()
	state.kickLookup = {
		player = {},
		guild = {},
	}
	for _, entry in ipairs(state.settings.kickEntries) do
		if type(entry) == "table" and entry.kind ~= nil and entry.name ~= nil then
			local normalized = Normalize(entry.name)
			if normalized ~= "" then
				state.kickLookup[entry.kind][normalized] = true
			end
		end
	end
end

local function LoadSettings()
	local loaded = ADDON:LoadData(SAVE_KEY)
	if type(loaded) == "table" then
		if loaded.kickMode == "whitelist" then
			state.settings.kickMode = "whitelist"
		end
		state.settings.kickEnabled = loaded.kickEnabled == true
		if type(loaded.kickEntries) == "table" then
			state.settings.kickEntries = loaded.kickEntries
		end
		if type(loaded.raidBuffs) == "table" then
			state.settings.raidBuffs = loaded.raidBuffs
		end
		if type(loaded.siegeBuffs) == "table" then
			state.settings.siegeBuffs = loaded.siegeBuffs
		end
		if type(loaded.bannedClasses) == "table" then
			state.settings.bannedClasses = loaded.bannedClasses
		end
		state.settings.fixgardenEnabled = loaded.fixgardenEnabled == true
		state.settings.distanceKickEnabled = loaded.distanceKickEnabled == true
		state.settings.distanceKickMeters = tonumber(loaded.distanceKickMeters) or state.settings.distanceKickMeters
	end
	if next(state.settings.raidBuffs) == nil then
		state.settings.raidBuffs = CopyTable(DEFAULT_RAID_BUFFS)
	end
	if next(state.settings.siegeBuffs) == nil then
		state.settings.siegeBuffs = CopyTable(DEFAULT_SIEGE_BUFFS)
	end
	if #state.settings.bannedClasses == 0 then
		state.settings.bannedClasses = CopyTable(DEFAULT_BANNED_CLASSES)
	end
	SortEntries(state.settings.kickEntries)
	RebuildKickLookup()
end

local function ResolveExistingUnitId(candidates)
	for _, unitId in ipairs(candidates) do
		if X2Unit:UnitName(unitId) ~= nil then
			return unitId
		end
	end
	return nil
end

local function GetSingleRaidUnit(memberIndex)
	return ResolveExistingUnitId({
		string.format("team%02d", memberIndex),
		string.format("team%d", memberIndex),
	})
end

local function GetCoRaidUnit(teamIndex, memberIndex)
	return ResolveExistingUnitId({
		string.format("team_%02d_%02d", teamIndex, memberIndex),
		string.format("team_%d_%d", teamIndex, memberIndex),
	})
end

local function GetRaidMode()
	if GetCoRaidUnit(1, 1) ~= nil then
		return true, 2
	end
	if GetSingleRaidUnit(1) ~= nil then
		return false, 1
	end
	return false, 0
end

local function ForEachRaidMember(callback)
	local hasCoRaid, raidCount = GetRaidMode()
	if raidCount == 0 then
		Chat("Not in a raid.")
		return 0
	end
	local count = 0
	for team = 1, raidCount do
		for member = 1, 50 do
			local unitId
			if hasCoRaid then
				unitId = GetCoRaidUnit(team, member)
			else
				unitId = GetSingleRaidUnit(member)
			end
			local playerName = unitId ~= nil and X2Unit:UnitName(unitId) or nil
			if playerName ~= nil then
				count = count + 1
				callback(unitId, playerName, team, member, hasCoRaid)
			end
		end
	end
	return count
end

local function FormatRaidPosition(team, member)
	local party = math.ceil(member / 5)
	local memberWithinParty = ((member - 1) % 5) + 1
	return string.format("raid_%d_%d_%d", team, party, memberWithinParty)
end

local function FindGuildNameInInfo(value, seen)
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
			if
				nestedValue ~= ""
				and (string.find(loweredKey, "guild", 1, true) or string.find(loweredKey, "expedition", 1, true))
			then
				return nestedValue
			end
		end
	end
	for _, nestedValue in pairs(value) do
		local found = FindGuildNameInInfo(nestedValue, seen)
		if found ~= nil then
			return found
		end
	end
	return nil
end

local function GetGuildName(unitId)
	local stringId = X2Unit:GetUnitId(unitId)
	if stringId == nil then
		return nil
	end
	local info = X2Unit:GetUnitInfoById(stringId)
	return FindGuildNameInInfo(info)
end

local function QueueKick(playerName)
	local normalized = Normalize(playerName)
	if normalized == "" or playerName == SELF_NAME or state.kickQueued[normalized] then
		return false
	end
	table.insert(state.kickQueue, playerName)
	state.kickQueued[normalized] = true
	return true
end

local function ShouldKick(unitId, playerName)
	local playerListed = state.kickLookup.player[Normalize(playerName)] == true
	local guildName = GetGuildName(unitId)
	local guildListed = guildName ~= nil and state.kickLookup.guild[Normalize(guildName)] == true
	if state.settings.kickMode == "whitelist" then
		return not playerListed and not guildListed
	end
	return playerListed or guildListed
end

local function ScanKickList(force)
	if state.settings.kickEnabled ~= true and force ~= true then
		return
	end
	local queued = 0
	ForEachRaidMember(function(unitId, playerName)
		if ShouldKick(unitId, playerName) and QueueKick(playerName) then
			queued = queued + 1
		end
	end)
	if queued > 0 then
		SetStatus(string.format("Queued %d raid member(s) for kick.", queued))
	end
end

local function ProcessKickQueue()
	if #state.kickQueue == 0 then
		return
	end
	local teamRoleType = X2Team:GetTeamRoleType()
	if teamRoleType == nil then
		return
	end
	local playerName = table.remove(state.kickQueue, 1)
	state.kickQueued[Normalize(playerName)] = nil
	X2Team:KickTeamMemberByName(playerName, teamRoleType)
	SetStatus("Kick sent for " .. tostring(playerName))
end

local function GetUnitDistanceMeters(unitId)
	local distanceInfo = X2Unit:UnitDistance(unitId)
	if type(distanceInfo) ~= "table" then
		return nil
	end
	return tonumber(distanceInfo.distance)
end

local function QueueDistanceKicks(limitMeters, label)
	local limit = tonumber(limitMeters)
	if limit == nil or limit <= 0 then
		return
	end
	local queued = 0
	local checked = ForEachRaidMember(function(unitId, playerName)
		if playerName == SELF_NAME then
			return
		end
		local distance = GetUnitDistanceMeters(unitId)
		if distance ~= nil and distance > limit and QueueKick(playerName) then
			queued = queued + 1
		end
	end)
	if checked > 0 and queued > 0 then
		SetStatus(string.format("%s queued %d member(s) over %.0fm.", label, queued, limit))
	end
end

local function RefreshDistanceButtons()
	if fixgardenButton ~= nil then
		fixgardenButton:SetText(state.settings.fixgardenEnabled and "Disable" or "Enable")
	end
	if distanceKickButton ~= nil then
		distanceKickButton:SetText(state.settings.distanceKickEnabled and "Disable" or "Enable")
	end
end

local function ToggleFixgarden()
	state.settings.fixgardenEnabled = not state.settings.fixgardenEnabled
	SaveSettings()
	RefreshDistanceButtons()
	if state.settings.fixgardenEnabled then
		QueueDistanceKicks(FIXGARDEN_DISTANCE, "fixgarden")
	end
end

local function ToggleDistanceKick()
	if state.settings.distanceKickEnabled then
		state.settings.distanceKickEnabled = false
	else
		local meters = tonumber(Trim(distanceKickInput:GetText()))
		if meters == nil or meters <= 0 then
			SetStatus("Enter a valid distance in meters.")
			return
		end
		state.settings.distanceKickMeters = meters
		state.settings.distanceKickEnabled = true
		QueueDistanceKicks(meters, "distancekick")
	end
	SaveSettings()
	RefreshDistanceButtons()
end

local function RunDistanceScans()
	if state.settings.fixgardenEnabled then
		QueueDistanceKicks(FIXGARDEN_DISTANCE, "fixgarden")
	end
	if state.settings.distanceKickEnabled then
		QueueDistanceKicks(state.settings.distanceKickMeters, "distancekick")
	end
end

local function TeamCall(methodName, ...)
	if X2Team == nil or type(X2Team[methodName]) ~= "function" then
		return nil
	end
	local args = { ... }
	local ok, result = pcall(function()
		return X2Team[methodName](X2Team, unpack(args))
	end)
	if ok then
		return result
	end
	return nil
end

local function TeamInvoke(methodName, ...)
	if X2Team == nil or type(X2Team[methodName]) ~= "function" then
		return false
	end
	local args = { ... }
	local ok = pcall(function()
		X2Team[methodName](X2Team, unpack(args))
	end)
	return ok
end

local function GetMyJointOrder()
	return tonumber(TeamCall("GetMyTeamJointOrder")) or 0
end

local function GetUnitForMyRaidMember(memberIndex)
	local jointOrder = GetMyJointOrder()
	if jointOrder ~= nil and jointOrder > 0 then
		return ResolveExistingUnitId({
			string.format("team_%02d_%02d", jointOrder, memberIndex),
			string.format("team_%d_%d", jointOrder, memberIndex),
		})
	end
	return GetSingleRaidUnit(memberIndex)
end

local function GetMyMemberIndex()
	local directIndex = tonumber(TeamCall("GetTeamPlayerIndex"))
	if directIndex ~= nil then
		return directIndex
	end
	local playerName = X2Unit:UnitName("player")
	if playerName == nil then
		return nil
	end
	for memberIndex = 1, 50 do
		local unitId = GetUnitForMyRaidMember(memberIndex)
		if unitId ~= nil and X2Unit:UnitName(unitId) == playerName then
			return memberIndex
		end
	end
	return nil
end

local function SetSortRaidStatus(message)
	if sortRaidStatusLabel ~= nil then
		sortRaidStatusLabel:SetText(tostring(message or ""))
	end
	SetStatus(message)
end

local function RefreshSortRaidButtons()
	if sortRaidStartButton ~= nil then
		sortRaidStartButton:Show(state.sortRaidActive ~= true)
	end
	if sortRaidStopButton ~= nil then
		sortRaidStopButton:Show(state.sortRaidActive == true)
	end
end

local function StopSortRaid(message)
	state.sortRaidActive = false
	RefreshSortRaidButtons()
	if message ~= nil then
		SetSortRaidStatus(message)
	end
end

local function CanSortMyRaid()
	local myIndex = GetMyMemberIndex()
	local myJointOrder = GetMyJointOrder()
	if myIndex == nil or myJointOrder == nil then
		return false
	end
	local isOwner = TeamCall("IsTeamOwner", myJointOrder, myIndex)
	if isOwner == nil and X2Unit.UnitTeamAuthority ~= nil then
		local authority = X2Unit:UnitTeamAuthority("player")
		isOwner = authority == "owner" or authority == "leader"
	end
	if isOwner ~= true then
		return false
	end
	return true
end

local function CollectMyRaidMembersByRole()
	local myJointOrder = GetMyJointOrder()
	local members = {}
	local maxMembers = 50
	local maxPartyMembers = tonumber(TeamCall("GetMaxPartyMembers"))
	if maxPartyMembers ~= nil and maxPartyMembers > 0 then
		maxMembers = maxPartyMembers * 10
	end
	for memberIndex = 1, maxMembers do
		local unitId = GetUnitForMyRaidMember(memberIndex)
		local name = unitId ~= nil and X2Unit:UnitName(unitId) or nil
		if name ~= nil then
			local role = tonumber(TeamCall("GetRole", myJointOrder, memberIndex)) or 0
			table.insert(members, {
				index = memberIndex,
				name = name,
				role = role,
			})
		end
	end
	table.sort(members, function(left, right)
		if left.role == right.role then
			return Normalize(left.name) < Normalize(right.name)
		end
		return left.role < right.role
	end)
	return members
end

local function SortRaidStep()
	if state.sortRaidActive ~= true then
		return
	end
	if not CanSortMyRaid() then
		StopSortRaid("SortRaid stopped: you are not the leader of your raid.")
		return
	end

	local desired = CollectMyRaidMembersByRole()
	if #desired <= 1 then
		StopSortRaid("SortRaid stopped: not enough raid members.")
		return
	end

	for targetIndex = 1, #desired do
		local desiredMember = desired[targetIndex]
		local currentUnit = GetUnitForMyRaidMember(targetIndex)
		local currentName = currentUnit ~= nil and X2Unit:UnitName(currentUnit) or nil
		if currentName ~= desiredMember.name then
			if not TeamInvoke("MoveTeamMember", desiredMember.index, targetIndex) then
				StopSortRaid("SortRaid stopped: MoveTeamMember is unavailable.")
				return
			end
			SetSortRaidStatus(
				string.format(
					"Moving %s from slot %d to %d (role %d).",
					desiredMember.name,
					desiredMember.index,
					targetIndex,
					desiredMember.role
				)
			)
			return
		end
	end

	StopSortRaid("SortRaid complete.")
end

local function StartSortRaid()
	if not CanSortMyRaid() then
		SetSortRaidStatus("SortRaid requires leader in your own raid.")
		return
	end
	state.sortRaidActive = true
	state.sortRaidElapsed = SORT_RAID_INTERVAL_MS
	RefreshSortRaidButtons()
	SetSortRaidStatus("SortRaid started.")
	SortRaidStep()
end

local function SetAutoMarkStatus(message)
	if autoMarkStatusLabel ~= nil then
		autoMarkStatusLabel:SetText(tostring(message or ""))
	end
	SetStatus(message)
end

local function GetMarkerCount()
	return tonumber(MAX_OVER_HEAD_MARKER) or 8
end

local function ClearMarkQueue()
	state.markQueue = {}
	state.markBusy = false
end

local function QueueMarkerClear()
	table.insert(state.markQueue, { action = "clear" })
	state.markBusy = true
end

local function QueueMarkerSet(unitId, markerIndex, name)
	table.insert(state.markQueue, {
		action = "set",
		unitId = unitId,
		markerIndex = markerIndex,
		name = name,
	})
	state.markBusy = true
end

local function ProcessMarkQueue()
	if #state.markQueue == 0 then
		state.markBusy = false
		return
	end
	local action = table.remove(state.markQueue, 1)
	if action.action == "clear" then
		X2Unit:RemoveAllOverHeadMarker()
		SetAutoMarkStatus("Removed all overhead markers.")
	elseif action.action == "set" and action.unitId ~= nil and action.markerIndex ~= nil then
		X2Unit:SetOverHeadMarker(action.unitId, action.markerIndex)
		SetAutoMarkStatus(string.format("Mark %d -> %s", action.markerIndex, tostring(action.name or action.unitId)))
	end
	if #state.markQueue == 0 then
		state.markBusy = false
	end
end

local function FindRaidUnitByName(name)
	local foundUnit
	ForEachRaidMember(function(unitId, playerName)
		if foundUnit == nil and Normalize(playerName) == Normalize(name) then
			foundUnit = unitId
		end
	end)
	return foundUnit
end

local function SaveRaidMarks()
	local saved = {}
	local seen = {}
	ForEachRaidMember(function(unitId, playerName)
		local markerIndex = tonumber(X2Unit:GetOverHeadMarker(unitId))
		if markerIndex ~= nil and markerIndex > 0 and not seen[markerIndex] then
			table.insert(saved, {
				markerIndex = markerIndex,
				name = playerName,
			})
			seen[markerIndex] = true
		end
	end)
	table.sort(saved, function(left, right)
		return left.markerIndex < right.markerIndex
	end)
	ADDON:SaveData(MARKS_SAVE_KEY, saved)
	SetAutoMarkStatus(string.format("Saved %d mark(s).", #saved))
end

local function LoadRaidMarks()
	local saved = ADDON:LoadData(MARKS_SAVE_KEY)
	if type(saved) ~= "table" then
		SetAutoMarkStatus("No saved marks found.")
		return
	end
	ClearMarkQueue()
	QueueMarkerClear()
	local queued = 0
	for _, entry in ipairs(saved) do
		if type(entry) == "table" then
			local markerIndex = tonumber(entry.markerIndex)
			local unitId = FindRaidUnitByName(entry.name)
			if markerIndex ~= nil and unitId ~= nil then
				QueueMarkerSet(unitId, markerIndex, entry.name)
				queued = queued + 1
			end
		end
	end
	SetAutoMarkStatus(string.format("Queued %d saved mark(s).", queued))
end

local function AutoMarkSkullknights()
	ClearMarkQueue()
	QueueMarkerClear()
	local skullknights = {}
	ForEachRaidMember(function(unitId, playerName)
		if GetClassKey(unitId) == "name_3_4_5" then
			table.insert(skullknights, {
				unitId = unitId,
				name = playerName,
			})
		end
	end)
	table.sort(skullknights, function(left, right)
		return Normalize(left.name) < Normalize(right.name)
	end)
	local markerCount = GetMarkerCount()
	local queued = 0
	for index, entry in ipairs(skullknights) do
		if index > markerCount then
			break
		end
		QueueMarkerSet(entry.unitId, index, entry.name)
		queued = queued + 1
	end
	SetAutoMarkStatus(string.format("Queued %d Skullknight mark(s).", queued))
end

local function ReadLootPercent(unitId)
	local info = X2Unit:UnitInfo(unitId)
	if type(info) ~= "table" then
		return nil
	end
	return tonumber(info.exp_mul)
end

local function FormatLootPercent(value)
	if value == nil then
		return "?"
	end
	if math.abs(value - math.floor(value + 0.5)) < 0.001 then
		return tostring(math.floor(value + 0.5))
	end
	return string.format("%.2f", value)
end

local function RefreshLootRows(entries)
	entries = entries or {}
	table.sort(entries, function(left, right)
		if left.expMul == right.expMul then
			return Normalize(left.name) < Normalize(right.name)
		end
		if left.expMul == nil then
			return false
		end
		if right.expMul == nil then
			return true
		end
		return left.expMul < right.expMul
	end)
	for index, row in ipairs(lootRows) do
		local entry = entries[index]
		if entry ~= nil then
			row.name = entry.name
			row.nameLabel:SetText(string.format("%s (%s)", entry.name, entry.position))
			row.percentLabel:SetText(FormatLootPercent(entry.expMul))
			row.nameLabel:Show(true)
			row.percentLabel:Show(true)
			row.kickButton:Show(true)
		else
			row.name = nil
			row.nameLabel:SetText("")
			row.percentLabel:SetText("")
			row.nameLabel:Show(false)
			row.percentLabel:Show(false)
			row.kickButton:Show(false)
		end
	end
	if #entries > #lootRows then
		SetStatus(string.format("Showing %d of %d loot%% rows.", #lootRows, #entries))
	else
		SetStatus(string.format("Loaded %d loot%% row(s).", #entries))
	end
end

local function CheckLootPercent()
	local entries = {}
	ForEachRaidMember(function(unitId, playerName, team, member)
		table.insert(entries, {
			name = playerName,
			position = FormatRaidPosition(team, member),
			expMul = ReadLootPercent(unitId),
		})
	end)
	RefreshLootRows(entries)
end

local function ValueContainsText(value, needle)
	if type(value) == "string" then
		return string.find(string.lower(value), needle, 1, true) ~= nil
	end
	if type(value) == "table" then
		for _, nested in pairs(value) do
			if ValueContainsText(nested, needle) then
				return true
			end
		end
	end
	return false
end

local function BuffContainsText(buffInfo, buffTooltip, needle)
	return ValueContainsText(buffInfo, needle) or ValueContainsText(buffTooltip, needle)
end

local function UnitHasHiddenBuffText(unitId, needle)
	local count = X2Unit:UnitHiddenBuffCount(unitId) or 0
	for index = 1, count do
		local buffInfo = X2Unit:UnitHiddenBuff(unitId, index)
		local buffTooltip = X2Unit:UnitHiddenBuffTooltip(unitId, index)
		if BuffContainsText(buffInfo, buffTooltip, needle) then
			return true
		end
	end
	return false
end

local function UnitHasBuffText(unitId, needle)
	local count = X2Unit:UnitBuffCount(unitId) or 0
	for index = 1, count do
		local buffInfo = X2Unit:UnitBuff(unitId, index)
		local buffTooltip = X2Unit:UnitBuffTooltip(unitId, index)
		if BuffContainsText(buffInfo, buffTooltip, needle) then
			return true
		end
	end
	return false
end

local function RefreshGearRows(entries)
	entries = entries or {}
	table.sort(entries, function(left, right)
		return Normalize(left.name) < Normalize(right.name)
	end)
	for index, row in ipairs(gearRows) do
		local entry = entries[index]
		if entry ~= nil then
			row:SetText(string.format("%s (%s): %s", entry.name, entry.position, table.concat(entry.matches, ", ")))
			row:Show(true)
		else
			row:SetText("")
			row:Show(false)
		end
	end
	if #entries > #gearRows then
		SetStatus(string.format("Showing %d of %d gearcheck rows.", #gearRows, #entries))
	else
		SetStatus(string.format("Gearcheck found %d player(s).", #entries))
	end
end

local function CheckGear()
	local entries = {}
	ForEachRaidMember(function(unitId, playerName, team, member)
		local matches = {}
		if UnitHasHiddenBuffText(unitId, "dawnsdrop") then
			table.insert(matches, "Dawnsdrop")
		end
		if UnitHasBuffText(unitId, "yata mask") then
			table.insert(matches, "Yata Mask")
		end
		if UnitHasBuffText(unitId, "swimfins") then
			table.insert(matches, "Swimfins")
		end
		if #matches > 0 then
			local position = FormatRaidPosition(team, member)
			table.insert(entries, {
				name = playerName,
				position = position,
				matches = matches,
			})
			Chat(string.format("%s (%s): %s", playerName, position, table.concat(matches, ", ")))
		end
	end)
	RefreshGearRows(entries)
end

local function BuildBuffIdLookup(ids)
	local lookup = {}
	for _, id in ipairs(ids or {}) do
		lookup[tonumber(id)] = true
	end
	return lookup
end

local function CheckBuffSet(buffSet, useHidden, label)
	local missingByBuff = {}
	local missingPlayers = {}
	local missingLookup = {}
	local outOfRangePlayers = {}
	local lookupByBuff = {}
	for category, ids in pairs(buffSet) do
		missingByBuff[category] = {}
		lookupByBuff[category] = BuildBuffIdLookup(ids)
	end

	local checked = ForEachRaidMember(function(unitId, playerName, team, member)
		local buffCount
		if useHidden then
			buffCount = X2Unit:UnitHiddenBuffCount(unitId) or 0
		else
			buffCount = X2Unit:UnitBuffCount(unitId) or 0
		end
		if buffCount == 0 then
			table.insert(outOfRangePlayers, {
				name = playerName,
				position = FormatRaidPosition(team, member),
				outOfRange = true,
			})
			return
		end
		local hasBuff = {}
		for category in pairs(buffSet) do
			hasBuff[category] = false
		end
		for index = 1, buffCount do
			local buffExtra
			if useHidden then
				buffExtra = X2Unit:UnitHiddenBuff(unitId, index)
			else
				buffExtra = X2Unit:UnitBuff(unitId, index)
			end
			local buffId = type(buffExtra) == "table" and tonumber(buffExtra.buff_id) or nil
			if buffId ~= nil then
				for category, lookup in pairs(lookupByBuff) do
					if lookup[buffId] then
						hasBuff[category] = true
					end
				end
			end
		end
		for category, present in pairs(hasBuff) do
			if not present then
				local position = FormatRaidPosition(team, member)
				table.insert(
					missingByBuff[category],
					string.format("%s (%s)", playerName, position)
				)
				local key = Normalize(playerName)
				if not missingLookup[key] then
					missingLookup[key] = {
						name = playerName,
						position = position,
						missing = {},
						missingLookup = {},
					}
					table.insert(missingPlayers, {
						name = playerName,
						position = position,
						missing = missingLookup[key].missing,
					})
				end
				if not missingLookup[key].missingLookup[category] then
					table.insert(missingLookup[key].missing, "no " .. tostring(category))
					missingLookup[key].missingLookup[category] = true
				end
			end
		end
	end)

	if checked == 0 then
		return
	end
	local anyMissing = false
	for category, missingList in pairs(missingByBuff) do
		if #missingList > 0 then
			anyMissing = true
			Chat(string.format("Missing %s %s: %s", tostring(category), label, table.concat(missingList, ", ")))
		end
	end
	if not anyMissing and #outOfRangePlayers == 0 then
		Chat("Everyone has the checked " .. label .. " buffs.")
	end
	table.sort(outOfRangePlayers, function(left, right)
		if left.position == right.position then
			return Normalize(left.name) < Normalize(right.name)
		end
		return left.position < right.position
	end)
	for _, entry in ipairs(outOfRangePlayers) do
		table.insert(missingPlayers, entry)
	end
	return missingPlayers
end

local function AddRaidBuff()
	local category = Normalize(buffCategoryInput:GetText())
	local buffId = tonumber(Trim(buffIdInput:GetText()))
	if category == "" or buffId == nil then
		SetStatus("Enter a buff category and numeric buff id.")
		return
	end
	state.settings.raidBuffs[category] = state.settings.raidBuffs[category] or {}
	table.insert(state.settings.raidBuffs[category], buffId)
	SaveSettings()
	buffCategoryInput:Clear()
	buffIdInput:Clear()
	SetStatus(string.format("Added buff %d to %s.", buffId, category))
end

local function RenderBuffMissingRows()
	local total = #buffMissingResults
	local visibleRows = #buffMissingRows
	local maxOffset = math.max(1, total - visibleRows + 1)
	if buffMissingOffset > maxOffset then
		buffMissingOffset = maxOffset
	end
	if buffMissingOffset < 1 then
		buffMissingOffset = 1
	end

	for index, row in ipairs(buffMissingRows) do
		local entry = buffMissingResults[buffMissingOffset + index - 1]
		if entry ~= nil then
			row.name = entry.name
			if entry.outOfRange then
				row.label:SetText(string.format("%s (%s): out of range", entry.name, entry.position))
			else
				row.label:SetText(
					string.format("%s (%s): %s", entry.name, entry.position, table.concat(entry.missing or {}, ", "))
				)
			end
			row.label:Show(true)
			row.kickButton:Show(true)
		else
			row.name = nil
			row.label:SetText("")
			row.label:Show(false)
			row.kickButton:Show(false)
		end
	end

	if total > visibleRows then
		local lastShown = math.min(total, buffMissingOffset + visibleRows - 1)
		SetStatus(string.format("Showing %d-%d of %d unbuffed players.", buffMissingOffset, lastShown, total))
	elseif total > 0 then
		SetStatus(string.format("Found %d unbuffed player(s).", total))
	else
		SetStatus("No unbuffed players found.")
	end
end

local function ScrollBuffMissingRows(delta)
	if #buffMissingResults <= #buffMissingRows then
		return
	end
	buffMissingOffset = buffMissingOffset + delta
	RenderBuffMissingRows()
end

local function SetBuffMissingResults(missingPlayers)
	buffMissingResults = missingPlayers or {}
	table.sort(buffMissingResults, function(left, right)
		if left.outOfRange ~= right.outOfRange then
			return right.outOfRange == true
		end
		if left.position == right.position then
			return Normalize(left.name) < Normalize(right.name)
		end
		return left.position < right.position
	end)
	buffMissingOffset = 1
	RenderBuffMissingRows()
end

local function CheckRaidBuffsToPanel()
	local missingPlayers = CheckBuffSet(state.settings.raidBuffs, false, "raid")
	SetBuffMissingResults(missingPlayers)
end

local function GetClassKey(unitId)
	local templates = X2Unit:GetTargetAbilityTemplates(unitId)
	if templates == nil or templates[1] == nil or templates[2] == nil or templates[3] == nil then
		return nil
	end
	local indices = {
		templates[1].index,
		templates[2].index,
		templates[3].index,
	}
	table.sort(indices)
	local key = string.format("name_%d_%d_%d", indices[1], indices[2], indices[3])
	if key == "name_30_30_30" then
		return nil
	end
	return key
end

local function GetClassName(unitId)
	local key = GetClassKey(unitId)
	if key == nil then
		return nil
	end
	return X2Locale:LocalizeUiText(COMBINED_ABILITY_NAME_TEXT, key, "")
end

local function IsBannedClass(className)
	local normalized = Normalize(className)
	for _, bannedClass in ipairs(state.settings.bannedClasses) do
		if Normalize(bannedClass) == normalized then
			return true
		end
	end
	return false
end

local function GetAllClassNames()
	if allClassNames ~= nil then
		return allClassNames
	end
	allClassNames = {}
	local seen = {}
	for first = 1, 14 do
		for second = first + 1, 14 do
			for third = second + 1, 14 do
				local key = string.format("name_%d_%d_%d", first, second, third)
				local className = X2Locale:LocalizeUiText(COMBINED_ABILITY_NAME_TEXT, key, "")
				if className ~= nil and className ~= "" and className ~= key then
					local normalized = Normalize(className)
					if normalized ~= "" and not seen[normalized] then
						seen[normalized] = true
						table.insert(allClassNames, className)
					end
				end
			end
		end
	end
	table.sort(allClassNames)
	return allClassNames
end

local function FindClassSuggestions(query, limit)
	local suggestions = {}
	local normalizedQuery = Normalize(query)
	if normalizedQuery == "" then
		return suggestions
	end
	local classes = GetAllClassNames()
	for _, className in ipairs(classes) do
		if string.find(Normalize(className), normalizedQuery, 1, true) == 1 then
			table.insert(suggestions, className)
			if #suggestions >= limit then
				return suggestions
			end
		end
	end
	for _, className in ipairs(classes) do
		if string.find(Normalize(className), normalizedQuery, 1, true) ~= nil then
			local duplicate = false
			for _, existing in ipairs(suggestions) do
				if existing == className then
					duplicate = true
					break
				end
			end
			if not duplicate then
				table.insert(suggestions, className)
				if #suggestions >= limit then
					return suggestions
				end
			end
		end
	end
	return suggestions
end

local function ResolveClassName(input)
	local normalizedInput = Normalize(input)
	if normalizedInput == "" then
		return nil
	end
	for _, className in ipairs(GetAllClassNames()) do
		if Normalize(className) == normalizedInput then
			return className
		end
	end
	local suggestions = FindClassSuggestions(input, 1)
	return suggestions[1] or Trim(input)
end

local function RefreshBannedClassRows()
	if bannedClassLabel ~= nil then
		bannedClassLabel:SetText(string.format("Banned classes: %d", #state.settings.bannedClasses))
	end
	for index = 1, #bannedClassRows do
		local rowEntry = bannedClassRows[index]
		local className = state.settings.bannedClasses[index]
		if rowEntry ~= nil and rowEntry.label ~= nil and className ~= nil then
			local row = rowEntry.label
			row.entryIndex = index
			row:SetText(className)
			row:Show(true)
			if rowEntry.removeButton ~= nil then
				rowEntry.removeButton.entryIndex = index
				rowEntry.removeButton:Show(true)
			end
			if state.selectedBannedClassIndex == index then
				row.style:SetColor(0.04, 0.50, 0.08, 1)
			elseif row.style.SetColorByKey ~= nil then
				row.style:SetColorByKey("default")
			else
				row.style:SetColor(1, 1, 1, 1)
			end
		elseif rowEntry ~= nil and rowEntry.label ~= nil then
			local row = rowEntry.label
			row.entryIndex = nil
			row:SetText("")
			row:Show(false)
			if rowEntry.removeButton ~= nil then
				rowEntry.removeButton.entryIndex = nil
				rowEntry.removeButton:Show(false)
			end
		end
	end
	if bannedClassRemoveButton ~= nil then
		bannedClassRemoveButton:Show(true)
	end
end

local function RefreshClassRows()
	for index = 1, VISIBLE_ROWS do
		local row = classRows[index]
		local entry = state.classResults[index]
		if row ~= nil and entry ~= nil then
			row:SetText(string.format("%s: %d", entry.name, entry.count))
			row:Show(true)
		elseif row ~= nil then
			row:SetText("")
			row:Show(false)
		end
	end
end

local function CheckClasses()
	local classCounts = {}
	state.bannedPlayers = {}
	local checked = ForEachRaidMember(function(unitId, playerName)
		local className = GetClassName(unitId)
		if className ~= nil and className ~= "" then
			classCounts[className] = (classCounts[className] or 0) + 1
			if IsBannedClass(className) then
				table.insert(state.bannedPlayers, { name = playerName, className = className })
			end
		end
	end)
	if checked == 0 then
		return
	end
	state.classResults = {}
	for className, count in pairs(classCounts) do
		table.insert(state.classResults, { name = className, count = count })
	end
	table.sort(state.classResults, function(left, right)
		if left.count == right.count then
			return left.name < right.name
		end
		return left.count > right.count
	end)
	RefreshClassRows()
	for _, entry in ipairs(state.classResults) do
		Chat(string.format("%s: %d", entry.name, entry.count))
	end
	if #state.bannedPlayers > 0 then
		local names = {}
		for _, entry in ipairs(state.bannedPlayers) do
			table.insert(names, string.format("%s (%s)", entry.name, entry.className))
		end
		Chat("Banned classes found: " .. table.concat(names, ", "))
	else
		Chat("No banned classes found.")
	end
end

local function AddBannedClass()
	local className = ResolveClassName(bannedClassInput:GetText())
	if className == nil or className == "" then
		SetStatus("Enter a class name.")
		return
	end
	if IsBannedClass(className) then
		SetStatus(className .. " is already banned.")
		return
	end
	table.insert(state.settings.bannedClasses, className)
	table.sort(state.settings.bannedClasses)
	SaveSettings()
	bannedClassInput:Clear()
	state.selectedBannedClassIndex = nil
	if bannedClassDropdown ~= nil then
		bannedClassDropdown:HidePreview()
	end
	RefreshBannedClassRows()
	SetStatus("Added banned class: " .. className)
end

local function RemoveBannedClassAt(index)
	if index == nil or state.settings.bannedClasses[index] == nil then
		return false
	end
	local removed = state.settings.bannedClasses[index]
	table.remove(state.settings.bannedClasses, index)
	state.selectedBannedClassIndex = nil
	SaveSettings()
	bannedClassInput:Clear()
	RefreshBannedClassRows()
	SetStatus("Removed banned class: " .. tostring(removed))
	return true
end

local function RemoveBannedClass()
	local index = state.selectedBannedClassIndex
	if index == nil then
		local typedClassName = ResolveClassName(bannedClassInput:GetText())
		local normalizedTyped = Normalize(typedClassName)
		if normalizedTyped ~= "" then
			for classIndex, className in ipairs(state.settings.bannedClasses) do
				if Normalize(className) == normalizedTyped then
					index = classIndex
					break
				end
			end
		end
	end
	if not RemoveBannedClassAt(index) then
		SetStatus("Select or type a banned class to remove.")
	end
end

local function KickBannedClasses()
	if #state.bannedPlayers == 0 then
		CheckClasses()
	end
	local queued = 0
	for _, entry in ipairs(state.bannedPlayers) do
		if QueueKick(entry.name) then
			queued = queued + 1
		end
	end
	SetStatus(string.format("Queued %d banned class member(s).", queued))
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

local function CreateQuestStylePanel(parent, id, left, top, right, bottom, alpha)
	local holder = parent:CreateChildWidget("emptywidget", id, 0, true)
	holder:AddAnchor("TOPLEFT", parent, left, top)
	holder:AddAnchor("BOTTOMRIGHT", parent, right, bottom)
	local ok, bg = pcall(function()
		local drawable = holder:CreateDrawable("ui/common/default.dds", "common_bg", "background")
		if drawable ~= nil and drawable.SetTextureColor ~= nil then
			drawable:SetTextureColor("bg_02")
			return drawable
		end
		if type(CreateContentBackground) == "function" then
			return CreateContentBackground(holder, "TYPE11", "bg_02", "background")
		end
		return drawable
	end)
	if ok and bg ~= nil then
		bg:AddAnchor("TOPLEFT", holder, 0, 0)
		bg:AddAnchor("BOTTOMRIGHT", holder, 0, 0)
	else
		bg = holder:CreateColorDrawable(0.78, 0.73, 0.58, alpha or 0.18, "background")
		bg:AddAnchor("TOPLEFT", holder, 0, 0)
		bg:AddAnchor("BOTTOMRIGHT", holder, 0, 0)
	end
	return holder
end

local function StyleLabel(label, fontSize, align)
	label.style:SetFontSize(fontSize or 13)
	label.style:SetAlign(align or ALIGN_LEFT)
	if label.style.SetColorByKey ~= nil then
		label.style:SetColorByKey("default")
	else
		label.style:SetColor(1, 1, 1, 1)
	end
end

local function SetDefaultTextColor(widget)
	if widget == nil or widget.style == nil then
		return
	end
	if widget.style.SetColorByKey ~= nil then
		widget.style:SetColorByKey("default")
	else
		widget.style:SetColor(1, 1, 1, 1)
	end
end

local function CreateFlatButton(parent, name, text, x, y, width, onClick)
	local button = parent:CreateChildWidget("button", name, 0, true)
	if button.SetStyle ~= nil then
		button:SetStyle("text_default")
	end
	if button.SetAutoResize ~= nil then
		button:SetAutoResize(false)
	end
	if button.SetInset ~= nil then
		button:SetInset(0, 0, 0, 0)
	end
	button:SetExtent(width, BUTTON_HEIGHT)
	button:AddAnchor("TOPLEFT", parent, x, y)
	button:SetText(text)
	StyleLabel(button, 12, ALIGN_CENTER)
	button:SetHandler("OnClick", onClick)
	return button
end

local function CreateInput(parent, name, x, y, width, guideText)
	local edit = parent:CreateChildWidget("editboxmultiline", name, 0, true)
	edit:SetInset(5, 5, 5, 5)
	edit:SetWidth(width)
	edit:SetHeight(BUTTON_HEIGHT)
	edit:AddAnchor("TOPLEFT", parent, x, y)
	edit:SetMaxTextLength(100)
	edit:SetGuideText(guideText or "")
	local bg = edit:CreateDrawable("ui/common/default.dds", "editbox_df", "background")
	if bg == nil then
		bg = parent:CreateColorDrawable(0.78, 0.73, 0.58, 0.16, "background")
	end
	bg:AddAnchor("TOPLEFT", edit, 0, 0)
	bg:AddAnchor("BOTTOMRIGHT", edit, 0, 0)
	return edit
end

local function CreateClassDropdown(parent, edit, width)
	local dropdown = parent:CreateChildWidget("emptywidget", "raidManagerClassDropdown", 0, true)
	dropdown:SetExtent(width, 74)
	dropdown:AddAnchor("TOPLEFT", edit, "BOTTOMLEFT", 0, 1)
	dropdown:Show(false)

	local bg = dropdown:CreateDrawable("ui/common/default.dds", "editbox_df", "background")
	if bg == nil then
		bg = parent:CreateColorDrawable(0.78, 0.73, 0.58, 0.16, "background")
	end
	bg:AddAnchor("TOPLEFT", dropdown, 0, 0)
	bg:AddAnchor("BOTTOMRIGHT", dropdown, 0, 0)

	dropdown.rows = {}
	for i = 1, 3 do
		local row = dropdown:CreateChildWidget("label", "raidManagerClassDropdownRow" .. i, i, true)
		row:SetExtent(width - 10, 22)
		row:AddAnchor("TOPLEFT", dropdown, 5, 3 + ((i - 1) * 23))
		StyleLabel(row, 12, ALIGN_LEFT)

		local rowBg = row:CreateDrawable("ui/common/default.dds", "editbox_df", "background")
		if rowBg == nil then
			rowBg = row:CreateColorDrawable(0.78, 0.73, 0.58, 0.16, "background")
		end
		rowBg:AddAnchor("TOPLEFT", row, 0, 0)
		rowBg:AddAnchor("BOTTOMRIGHT", row, 0, 0)
		rowBg:SetVisible(false)
		row.rowBg = rowBg

		row:SetHandler("OnClick", function(self)
			if self.className == nil then
				return
			end
			bannedClassInput:SetText(self.className)
			dropdown:HidePreview()
		end)
		row:SetHandler("OnEnter", function(self)
			self.rowBg:SetVisible(true)
		end)
		row:SetHandler("OnLeave", function(self)
			self.rowBg:SetVisible(false)
		end)

		dropdown.rows[i] = row
	end

	function dropdown:HidePreview()
		self:Show(false)
		for _, row in ipairs(self.rows) do
			row.className = nil
			row:SetText("")
			row:Show(false)
		end
	end

	function dropdown:Update(query)
		local suggestions = FindClassSuggestions(query, 3)
		for i = 1, 3 do
			local row = self.rows[i]
			local className = suggestions[i]
			if className ~= nil then
				row.className = className
				row:SetText(className)
				row:Show(true)
			else
				row.className = nil
				row:SetText("")
				row:Show(false)
			end
		end
		if #suggestions > 0 and self.Raise ~= nil then
			self:Raise()
		end
		self:Show(#suggestions > 0)
	end

	dropdown:HidePreview()
	return dropdown
end

local function ShowSection(section)
	state.activeSection = section
	for id, widget in pairs(sectionWidgets) do
		widget:Show(id == section)
	end
	for id, button in pairs(sectionButtons) do
		if id == section then
			button.style:SetColor(0.04, 0.50, 0.08, 1)
		else
			SetDefaultTextColor(button)
		end
	end
	if sectionTitle ~= nil then
		sectionTitle:SetText(section)
	end
	if section == "classes" then
		RefreshBannedClassRows()
		RefreshClassRows()
	end
end

local function RefreshKickRows()
	if kickModeButton ~= nil then
		kickModeButton:SetText("Mode: " .. state.settings.kickMode)
	end
	if kickEnabledButton ~= nil then
		kickEnabledButton:SetText(state.settings.kickEnabled and "AutoKick: ON" or "AutoKick: OFF")
	end
	local total = #state.settings.kickEntries
	local maxPage = math.max(1, math.ceil(total / VISIBLE_ROWS))
	if state.kickPage > maxPage then
		state.kickPage = maxPage
	end
	local startIndex = ((state.kickPage - 1) * VISIBLE_ROWS) + 1
	for rowIndex = 1, VISIBLE_ROWS do
		local row = kickRows[rowIndex]
		local entryIndex = startIndex + rowIndex - 1
		local entry = state.settings.kickEntries[entryIndex]
		if entry ~= nil then
			row.entryIndex = entryIndex
			row:SetText(string.format("[%s] %s", entry.kind, entry.name))
			row:Show(true)
			if state.selectedKickIndex == entryIndex then
				row.style:SetColor(0.04, 0.50, 0.08, 1)
			else
				SetDefaultTextColor(row)
			end
		else
			row.entryIndex = nil
			row:SetText("")
			row:Show(false)
		end
	end
	if kickPageLabel ~= nil then
		kickPageLabel:SetText(string.format("Page %d/%d  Entries: %d", state.kickPage, maxPage, total))
	end
	if kickRemoveButton ~= nil then
		kickRemoveButton:Show(state.selectedKickIndex ~= nil)
	end
end

local function AddKickEntry(kind)
	local name = Trim(kickInput:GetText())
	if name == "" then
		SetStatus("Enter a player or guild name.")
		return
	end
	local normalized = Normalize(name)
	for _, entry in ipairs(state.settings.kickEntries) do
		if entry.kind == kind and Normalize(entry.name) == normalized then
			SetStatus(name .. " is already listed.")
			return
		end
	end
	table.insert(state.settings.kickEntries, { kind = kind, name = name })
	SortEntries(state.settings.kickEntries)
	RebuildKickLookup()
	SaveSettings()
	kickInput:Clear()
	state.selectedKickIndex = nil
	RefreshKickRows()
	SetStatus("Added " .. kind .. ": " .. name)
end

local function RemoveKickEntry()
	if state.selectedKickIndex == nil or state.settings.kickEntries[state.selectedKickIndex] == nil then
		return
	end
	local removed = state.settings.kickEntries[state.selectedKickIndex]
	table.remove(state.settings.kickEntries, state.selectedKickIndex)
	state.selectedKickIndex = nil
	RebuildKickLookup()
	SaveSettings()
	RefreshKickRows()
	SetStatus("Removed " .. tostring(removed.name))
end

local function CreateAutokickSection(parent)
	local panel = CreateQuestStylePanel(parent, "raidManagerAutokickPanel", 0, 0, 0, 0, 0.12)
	sectionWidgets.autokick = panel

	kickModeButton = CreateFlatButton(panel, "raidManagerKickMode", "Mode", 18, 18, 120, function()
		state.settings.kickMode = state.settings.kickMode == "blacklist" and "whitelist" or "blacklist"
		SaveSettings()
		RefreshKickRows()
	end)
	kickEnabledButton = CreateFlatButton(panel, "raidManagerKickEnabled", "AutoKick", 148, 18, 120, function()
		state.settings.kickEnabled = not state.settings.kickEnabled
		SaveSettings()
		RefreshKickRows()
		ScanKickList()
	end)
	CreateFlatButton(panel, "raidManagerKickScan", "Scan Now", 278, 18, 90, function()
		ScanKickList(true)
	end)

	kickInput = CreateInput(panel, "raidManagerKickInput", 18, 56, 230, "Player or guild name")
	CreateFlatButton(panel, "raidManagerKickAddPlayer", "Add Player", 258, 56, 92, function()
		AddKickEntry("player")
	end)
	CreateFlatButton(panel, "raidManagerKickAddGuild", "Add Guild", 358, 56, 86, function()
		AddKickEntry("guild")
	end)

	kickPageLabel = panel:CreateChildWidget("label", "raidManagerKickPage", 0, true)
	kickPageLabel:SetExtent(330, 20)
	kickPageLabel:AddAnchor("TOPLEFT", panel, 18, 92)
	StyleLabel(kickPageLabel, 12, ALIGN_LEFT)

	for rowIndex = 1, VISIBLE_ROWS do
		local row = panel:CreateChildWidget("label", "raidManagerKickRow" .. rowIndex, rowIndex, true)
		row:SetExtent(420, ROW_HEIGHT)
		row:AddAnchor("TOPLEFT", panel, 18, 116 + ((rowIndex - 1) * ROW_HEIGHT))
		StyleLabel(row, 12, ALIGN_LEFT)
		row:SetHandler("OnClick", function(self)
			state.selectedKickIndex = self.entryIndex
			RefreshKickRows()
		end)
		kickRows[rowIndex] = row
	end

	CreateFlatButton(panel, "raidManagerKickPrev", "Prev", 18, 370, 64, function()
		if state.kickPage > 1 then
			state.kickPage = state.kickPage - 1
			state.selectedKickIndex = nil
			RefreshKickRows()
		end
	end)
	CreateFlatButton(panel, "raidManagerKickNext", "Next", 90, 370, 64, function()
		state.kickPage = state.kickPage + 1
		state.selectedKickIndex = nil
		RefreshKickRows()
	end)
	kickRemoveButton = CreateFlatButton(panel, "raidManagerKickRemove", "Remove Selected", 300, 370, 130, RemoveKickEntry)
	RefreshKickRows()
end

local function CreateBuffcheckSection(parent)
	local panel = CreateQuestStylePanel(parent, "raidManagerBuffPanel", 0, 0, 0, 0, 0.12)
	sectionWidgets.buffcheck = panel
	CreateFlatButton(panel, "raidManagerBuffCheckRun", "Check Raid Buffs", 18, 18, 130, CheckRaidBuffsToPanel)
	buffCategoryInput = CreateInput(panel, "raidManagerBuffCategory", 18, 58, 130, "Category")
	buffIdInput = CreateInput(panel, "raidManagerBuffId", 158, 58, 100, "Buff id")
	CreateFlatButton(panel, "raidManagerBuffAdd", "Add Buff", 268, 58, 84, AddRaidBuff)

	local y = 104
	for category, ids in pairs(state.settings.raidBuffs) do
		local row = panel:CreateChildWidget("label", "raidManagerBuffRow" .. category, 0, true)
		row:SetExtent(455, ROW_HEIGHT)
		row:AddAnchor("TOPLEFT", panel, 18, y)
		row:SetText(string.format("%s: %s", category, table.concat(ids, ", ")))
		StyleLabel(row, 12, ALIGN_LEFT)
		y = y + ROW_HEIGHT
	end

	local resultTop = 216
	local resultBg = panel:CreateColorDrawable(0.78, 0.73, 0.58, 0.10, "background")
	resultBg:SetExtent(455, 174)
	resultBg:AddAnchor("TOPLEFT", panel, 18, resultTop)

	local resultWheelArea = panel:CreateChildWidget("emptywidget", "raidManagerBuffMissingWheelArea", 0, true)
	resultWheelArea:SetExtent(455, 174)
	resultWheelArea:AddAnchor("TOPLEFT", panel, 18, resultTop)
	resultWheelArea:Show(true)
	resultWheelArea:SetHandler("OnWheelUp", function()
		ScrollBuffMissingRows(-1)
	end)
	resultWheelArea:SetHandler("OnWheelDown", function()
		ScrollBuffMissingRows(1)
	end)

	for rowIndex = 1, 7 do
		local rowNumber = rowIndex
		local rowY = resultTop + 10 + ((rowIndex - 1) * 22)
		local label = panel:CreateChildWidget("label", "raidManagerBuffMissingLabel" .. rowIndex, rowIndex, true)
		label:SetExtent(360, 20)
		label:AddAnchor("TOPLEFT", panel, 28, rowY)
		StyleLabel(label, 12, ALIGN_LEFT)
		label:EnablePick(true)
		label:SetHandler("OnWheelUp", function()
			ScrollBuffMissingRows(-1)
		end)
		label:SetHandler("OnWheelDown", function()
			ScrollBuffMissingRows(1)
		end)
		label:Show(false)

		local kickButton = CreateFlatButton(
			panel,
			"raidManagerBuffMissingKick" .. rowIndex,
			"kick",
			400,
			rowY,
			52,
			function()
				local row = buffMissingRows[rowNumber]
				if row ~= nil and row.name ~= nil and QueueKick(row.name) then
					SetStatus("Queued kick for " .. row.name)
				end
			end
		)
		kickButton:SetHandler("OnWheelUp", function()
			ScrollBuffMissingRows(-1)
		end)
		kickButton:SetHandler("OnWheelDown", function()
			ScrollBuffMissingRows(1)
		end)
		kickButton:Show(false)
		buffMissingRows[rowIndex] = {
			label = label,
			kickButton = kickButton,
			name = nil,
		}
	end
end

local function CreateClassesSection(parent)
	local panel = CreateQuestStylePanel(parent, "raidManagerClassesPanel", 0, 0, 0, 0, 0.12)
	sectionWidgets.classes = panel
	CreateFlatButton(panel, "raidManagerClassesCheck", "Check Classes", 18, 18, 112, CheckClasses)
	CreateFlatButton(panel, "raidManagerClassesKick", "Kick Banned Classes", 140, 18, 150, KickBannedClasses)
	bannedClassInput = CreateInput(panel, "raidManagerBannedClassInput", 18, 58, 180, "Class name")
	bannedClassDropdown = CreateClassDropdown(panel, bannedClassInput, 180)
	bannedClassInput:SetHandler("OnTextChanged", function()
		if bannedClassDropdown ~= nil then
			bannedClassDropdown:Update(bannedClassInput:GetText())
		end
	end)
	CreateFlatButton(panel, "raidManagerBannedClassAdd", "Ban Class", 208, 58, 84, AddBannedClass)
	bannedClassRemoveButton =
		CreateFlatButton(panel, "raidManagerBannedClassRemove", "Remove Class", 302, 58, 104, RemoveBannedClass)

	bannedClassLabel = panel:CreateChildWidget("label", "raidManagerBannedClassesLabel", 0, true)
	bannedClassLabel:SetExtent(180, 20)
	bannedClassLabel:AddAnchor("TOPLEFT", panel, 18, 92)
	StyleLabel(bannedClassLabel, 12, ALIGN_LEFT)

	for rowIndex = 1, 5 do
		local rowNumber = rowIndex
		local row = panel:CreateChildWidget("label", "raidManagerBannedClassRow" .. rowIndex, rowIndex, true)
		row:SetExtent(180, ROW_HEIGHT)
		row:AddAnchor("TOPLEFT", panel, 18, 116 + ((rowIndex - 1) * ROW_HEIGHT))
		StyleLabel(row, 12, ALIGN_LEFT)
		row:SetHandler("OnClick", function(self)
			state.selectedBannedClassIndex = self.entryIndex
			RefreshBannedClassRows()
		end)
		local removeButton = CreateFlatButton(
			panel,
			"raidManagerBannedClassMinus" .. rowIndex,
			"-",
			208,
			115 + ((rowIndex - 1) * ROW_HEIGHT),
			24,
			function()
				RemoveBannedClassAt(rowNumber)
			end
		)
		removeButton:Show(false)
		bannedClassRows[rowIndex] = {
			label = row,
			removeButton = removeButton,
		}
	end

	for rowIndex = 1, VISIBLE_ROWS do
		local row = panel:CreateChildWidget("label", "raidManagerClassRow" .. rowIndex, rowIndex, true)
		row:SetExtent(420, ROW_HEIGHT)
		row:AddAnchor("TOPLEFT", panel, 18, 236 + ((rowIndex - 1) * ROW_HEIGHT))
		StyleLabel(row, 12, ALIGN_LEFT)
		classRows[rowIndex] = row
	end
	RefreshBannedClassRows()
	RefreshClassRows()
end

local function CreateSiegeSection(parent)
	local panel = CreateQuestStylePanel(parent, "raidManagerSiegePanel", 0, 0, 0, 0, 0.12)
	sectionWidgets.siege = panel
	CreateFlatButton(panel, "raidManagerSiegeCheck", "Check Siege Buffs", 18, 18, 132, function()
		CheckBuffSet(state.settings.siegeBuffs, true, "siege")
	end)
	local y = 58
	for category, ids in pairs(state.settings.siegeBuffs) do
		local row = panel:CreateChildWidget("label", "raidManagerSiegeRow" .. category, 0, true)
		row:SetExtent(455, ROW_HEIGHT)
		row:AddAnchor("TOPLEFT", panel, 18, y)
		row:SetText(string.format("%s: %s", category, table.concat(ids, ", ")))
		StyleLabel(row, 12, ALIGN_LEFT)
		y = y + ROW_HEIGHT
	end
end

local function CreateFixgardenSection(parent)
	local panel = CreateQuestStylePanel(parent, "raidManagerFixgardenPanel", 0, 0, 0, 0, 0.12)
	sectionWidgets.fixgarden = panel

	local label = panel:CreateChildWidget("label", "raidManagerFixgardenLabel", 0, true)
	label:SetExtent(420, 24)
	label:AddAnchor("TOPLEFT", panel, 18, 18)
	label:SetText("Kick raid members farther than 25000m every second.")
	StyleLabel(label, 13, ALIGN_LEFT)

	fixgardenButton = CreateFlatButton(panel, "raidManagerFixgardenToggle", "Enable", 18, 58, 100, ToggleFixgarden)
	RefreshDistanceButtons()
end

local function CreateDistanceKickSection(parent)
	local panel = CreateQuestStylePanel(parent, "raidManagerDistanceKickPanel", 0, 0, 0, 0, 0.12)
	sectionWidgets.distancekick = panel

	local label = panel:CreateChildWidget("label", "raidManagerDistanceKickLabel", 0, true)
	label:SetExtent(420, 24)
	label:AddAnchor("TOPLEFT", panel, 18, 18)
	label:SetText("Kick raid members farther than the configured distance every second.")
	StyleLabel(label, 13, ALIGN_LEFT)

	distanceKickInput = CreateInput(panel, "raidManagerDistanceKickInput", 18, 58, 100, "Meters")
	distanceKickInput:SetText(tostring(state.settings.distanceKickMeters or 25000))
	distanceKickButton =
		CreateFlatButton(panel, "raidManagerDistanceKickToggle", "Enable", 130, 58, 100, ToggleDistanceKick)
	RefreshDistanceButtons()
end

local function CreateSortRaidSection(parent)
	local panel = CreateQuestStylePanel(parent, "raidManagerSortRaidPanel", 0, 0, 0, 0, 0.12)
	sectionWidgets.sortraid = panel

	local label = panel:CreateChildWidget("label", "raidManagerSortRaidLabel", 0, true)
	label:SetExtent(430, 44)
	label:AddAnchor("TOPLEFT", panel, 18, 18)
	label:SetText("Sorts your own raid by selected role color, lowest role number first.")
	StyleLabel(label, 13, ALIGN_LEFT)

	sortRaidStartButton = CreateFlatButton(panel, "raidManagerSortRaidStart", "Start", 18, 72, 100, StartSortRaid)
	sortRaidStopButton = CreateFlatButton(panel, "raidManagerSortRaidStop", "Stop", 18, 72, 100, function()
		StopSortRaid("SortRaid stopped.")
	end)

	sortRaidStatusLabel = panel:CreateChildWidget("label", "raidManagerSortRaidStatus", 0, true)
	sortRaidStatusLabel:SetExtent(430, 60)
	sortRaidStatusLabel:AddAnchor("TOPLEFT", panel, 18, 112)
	sortRaidStatusLabel:SetText("Stopped.")
	StyleLabel(sortRaidStatusLabel, 12, ALIGN_LEFT)

	RefreshSortRaidButtons()
end

local function CreateAutoMarkSection(parent)
	local panel = CreateQuestStylePanel(parent, "raidManagerAutoMarkPanel", 0, 0, 0, 0, 0.12)
	sectionWidgets.automark = panel

	local label = panel:CreateChildWidget("label", "raidManagerAutoMarkLabel", 0, true)
	label:SetExtent(430, 44)
	label:AddAnchor("TOPLEFT", panel, 18, 18)
	label:SetText("Save, load, or automatically assign overhead markers for Skullknights.")
	StyleLabel(label, 13, ALIGN_LEFT)

	CreateFlatButton(panel, "raidManagerSaveMarks", "Save Marks", 18, 72, 100, SaveRaidMarks)
	CreateFlatButton(panel, "raidManagerLoadMarks", "Load Marks", 128, 72, 100, LoadRaidMarks)
	CreateFlatButton(panel, "raidManagerAutoMarkSkulls", "AutoMark", 238, 72, 100, AutoMarkSkullknights)

	autoMarkStatusLabel = panel:CreateChildWidget("label", "raidManagerAutoMarkStatus", 0, true)
	autoMarkStatusLabel:SetExtent(430, 80)
	autoMarkStatusLabel:AddAnchor("TOPLEFT", panel, 18, 116)
	autoMarkStatusLabel:SetText("Ready.")
	StyleLabel(autoMarkStatusLabel, 12, ALIGN_LEFT)
end

local function CreateLootSection(parent)
	local panel = CreateQuestStylePanel(parent, "raidManagerLootPanel", 0, 0, 0, 0, 0.12)
	sectionWidgets.loot = panel

	CreateFlatButton(panel, "raidManagerLootRefresh", "Check Loot%", 18, 18, 110, CheckLootPercent)

	local nameHeader = panel:CreateChildWidget("label", "raidManagerLootNameHeader", 0, true)
	nameHeader:SetExtent(250, 20)
	nameHeader:AddAnchor("TOPLEFT", panel, 18, 56)
	nameHeader:SetText("Name")
	StyleLabel(nameHeader, 12, ALIGN_LEFT)

	local percentHeader = panel:CreateChildWidget("label", "raidManagerLootPercentHeader", 0, true)
	percentHeader:SetExtent(70, 20)
	percentHeader:AddAnchor("TOPLEFT", panel, 300, 56)
	percentHeader:SetText("exp_mul")
	StyleLabel(percentHeader, 12, ALIGN_LEFT)

	local resultBg = panel:CreateColorDrawable(0.78, 0.73, 0.58, 0.10, "background")
	resultBg:SetExtent(455, 310)
	resultBg:AddAnchor("TOPLEFT", panel, 18, 78)

	for rowIndex = 1, 13 do
		local rowY = 86 + ((rowIndex - 1) * 22)
		local nameLabel = panel:CreateChildWidget("label", "raidManagerLootName" .. rowIndex, rowIndex, true)
		nameLabel:SetExtent(270, 20)
		nameLabel:AddAnchor("TOPLEFT", panel, 28, rowY)
		StyleLabel(nameLabel, 12, ALIGN_LEFT)
		nameLabel:Show(false)

		local percentLabel = panel:CreateChildWidget("label", "raidManagerLootPercent" .. rowIndex, rowIndex, true)
		percentLabel:SetExtent(60, 20)
		percentLabel:AddAnchor("TOPLEFT", panel, 304, rowY)
		StyleLabel(percentLabel, 12, ALIGN_LEFT)
		percentLabel:Show(false)

		local kickButton = CreateFlatButton(
			panel,
			"raidManagerLootKick" .. rowIndex,
			"kick",
			370,
			rowY,
			52,
			function()
				local row = lootRows[rowIndex]
				if row ~= nil and row.name ~= nil and QueueKick(row.name) then
					SetStatus("Queued kick for " .. row.name)
				end
			end
		)
		kickButton:Show(false)

		lootRows[rowIndex] = {
			nameLabel = nameLabel,
			percentLabel = percentLabel,
			kickButton = kickButton,
			name = nil,
		}
	end
end

local function CreateGearCheckSection(parent)
	local panel = CreateQuestStylePanel(parent, "raidManagerGearPanel", 0, 0, 0, 0, 0.12)
	sectionWidgets.gearcheck = panel

	CreateFlatButton(panel, "raidManagerGearCheckRun", "Check Gear", 18, 18, 100, CheckGear)

	local header = panel:CreateChildWidget("label", "raidManagerGearHeader", 0, true)
	header:SetExtent(430, 20)
	header:AddAnchor("TOPLEFT", panel, 18, 56)
	header:SetText("Players with Dawnsdrop, Yata Mask, or Swimfins")
	StyleLabel(header, 12, ALIGN_LEFT)

	local resultBg = panel:CreateColorDrawable(0.78, 0.73, 0.58, 0.10, "background")
	resultBg:SetExtent(455, 310)
	resultBg:AddAnchor("TOPLEFT", panel, 18, 78)

	for rowIndex = 1, 13 do
		local row = panel:CreateChildWidget("label", "raidManagerGearRow" .. rowIndex, rowIndex, true)
		row:SetExtent(430, 20)
		row:AddAnchor("TOPLEFT", panel, 28, 86 + ((rowIndex - 1) * 22))
		StyleLabel(row, 12, ALIGN_LEFT)
		row:Show(false)
		gearRows[rowIndex] = row
	end
end

local function CreateMainWindow()
	if mainWindow ~= nil then
		return
	end
	mainWindow = CreateEmptyWindow("raidManagerWindow", "UIParent")
	mainWindow:SetExtent(WINDOW_WIDTH, WINDOW_HEIGHT)
	mainWindow:AddAnchor("CENTER", "UIParent", 0, 0)
	mainWindow:SetCloseOnEscape(true)
	mainWindow:EnableDrag(true)
	mainWindow:Show(false)
	CreateWindowBackground(mainWindow)
	mainWindow:SetHandler("OnDragStart", function(self)
		self:StartMoving()
		return true
	end)
	mainWindow:SetHandler("OnDragStop", function(self)
		self:StopMovingOrSizing()
	end)

	local title = mainWindow:CreateChildWidget("label", "raidManagerTitle", 0, true)
	title:SetExtent(280, 30)
	title:AddAnchor("TOP", mainWindow, 0, 14)
	title:SetText("RaidManager")
	title.style:SetFontSize(22)
	title.style:SetAlign(ALIGN_CENTER)
	SetDefaultTextColor(title)

	local closeButton = mainWindow:CreateChildWidget("button", "raidManagerClose", 0, true)
	closeButton:AddAnchor("TOPRIGHT", mainWindow, 3, -3)
	closeButton:SetStyle("btn_close_default")
	closeButton:SetHandler("OnClick", function()
		mainWindow:Show(false)
	end)

	CreateQuestStylePanel(mainWindow, "raidManagerLeftPanel", 16, 62, -(WINDOW_WIDTH - LEFT_WIDTH - 12), -42, 0.16)
	contentPanel = mainWindow:CreateChildWidget("emptywidget", "raidManagerContent", 0, true)
	contentPanel:AddAnchor("TOPLEFT", mainWindow, LEFT_WIDTH + 28, 62)
	contentPanel:AddAnchor("BOTTOMRIGHT", mainWindow, -16, -42)

	sectionTitle = mainWindow:CreateChildWidget("label", "raidManagerSectionTitle", 0, true)
	sectionTitle:SetExtent(260, 22)
	sectionTitle:AddAnchor("TOPLEFT", mainWindow, LEFT_WIDTH + 34, 38)
	StyleLabel(sectionTitle, 14, ALIGN_LEFT)

	local sections = {
		{ id = "autokick", text = "autokick" },
		{ id = "buffcheck", text = "buffcheck" },
		{ id = "classes", text = "classes" },
		{ id = "siege", text = "siege" },
		{ id = "fixgarden", text = "fixgarden" },
		{ id = "distancekick", text = "distancekick" },
		{ id = "sortraid", text = "sortraid" },
		{ id = "automark", text = "automark" },
		{ id = "loot", text = "loot%" },
		{ id = "gearcheck", text = "gearcheck" },
	}
	for index, section in ipairs(sections) do
		local y = 78 + ((index - 1) * 34)
		local button = CreateFlatButton(mainWindow, "raidManagerSection" .. section.id, section.text, 28, y, 126, function()
			ShowSection(section.id)
		end)
		sectionButtons[section.id] = button
	end

	statusLabel = mainWindow:CreateChildWidget("label", "raidManagerStatus", 0, true)
	statusLabel:SetExtent(WINDOW_WIDTH - 40, 22)
	statusLabel:AddAnchor("BOTTOMLEFT", mainWindow, 20, -22)
	StyleLabel(statusLabel, 12, ALIGN_LEFT)

	CreateAutokickSection(contentPanel)
	CreateBuffcheckSection(contentPanel)
	CreateClassesSection(contentPanel)
	CreateSiegeSection(contentPanel)
	CreateFixgardenSection(contentPanel)
	CreateDistanceKickSection(contentPanel)
	CreateSortRaidSection(contentPanel)
	CreateAutoMarkSection(contentPanel)
	CreateLootSection(contentPanel)
	CreateGearCheckSection(contentPanel)
	ShowSection("autokick")
	SetStatus("Ready.")
end

local function ToggleWindow()
	CreateMainWindow()
	local show = not mainWindow:IsVisible()
	mainWindow:Show(show)
	if show then
		mainWindow:Raise()
		RefreshKickRows()
	end
end

local ticker = CreateEmptyWindow("raidManagerTicker", "UIParent")
ticker:Show(true)
ticker:SetHandler("OnUpdate", function(_, dt)
	state.scanElapsed = state.scanElapsed + dt
	state.distanceElapsed = state.distanceElapsed + dt
	state.sortRaidElapsed = state.sortRaidElapsed + dt
	state.markElapsed = state.markElapsed + dt
	state.kickElapsed = state.kickElapsed + dt
	if state.scanElapsed >= SCAN_INTERVAL_MS then
		state.scanElapsed = 0
		ScanKickList()
	end
	if state.distanceElapsed >= DISTANCE_SCAN_INTERVAL_MS then
		state.distanceElapsed = 0
		RunDistanceScans()
	end
	if state.sortRaidElapsed >= SORT_RAID_INTERVAL_MS then
		state.sortRaidElapsed = 0
		SortRaidStep()
	end
	if state.markElapsed >= MARK_INTERVAL_MS then
		state.markElapsed = 0
		ProcessMarkQueue()
	end
	if state.kickElapsed >= KICK_INTERVAL_MS then
		state.kickElapsed = 0
		ProcessKickQueue()
	end
end)

pcall(function()
	UIParent:SetEventHandler(UIEVENT_TYPE.TEAM_MEMBERS_CHANGED, function()
		state.scanElapsed = SCAN_INTERVAL_MS
	end)
end)

LoadSettings()
local launcherButton = CreateSimpleButton("RaidManager", 700, -560)
launcherButton:SetHandler("OnClick", ToggleWindow)
