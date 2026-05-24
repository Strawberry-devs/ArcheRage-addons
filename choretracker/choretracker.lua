-------------- Original Author: Strawberry --------------
----------------- Discord: exec_noir --------------------
if API_TYPE == nil then
	ADDON:ImportAPI(8)
	X2Chat:DispatchChatMessage(CMF_SYSTEM,"Globals folder not found. Please install it at https://github.com/Schiz-n/ArcheRage-addons/tree/master/globals")
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

ADDON:ImportAPI(API_TYPE.CHAT.id)
ADDON:ImportAPI(API_TYPE.QUEST.id)

local SAVE_KEY = "choretracker_groups_v2"
local LEGACY_GROUP_KEY = "choretracker_groups"
local LEGACY_CHORES_KEY = "choretracker_chores"

local RACE_QUESTS = CHORETRACKER_RACE_QUESTS or {}
local DAILY_QUESTS = CHORETRACKER_DAILY_QUESTS or {}
local WEEKLY_QUESTS = CHORETRACKER_WEEKLY_QUESTS or {}
local GROUPS_DAILIES = {}
local GROUPS_WEEKLIES = {}
local UNGROUPED_QUESTS = {}
local UNGROUPED_EXPANDED = true
local MODE_DAILIES = "dailies"
local MODE_WEEKLIES = "weeklies"
local activeMode = MODE_DAILIES

local WINDOW_WIDTH = 430
local WINDOW_PADDING = 20
local ROW_HEIGHT = 26
local ROW_GAP = 4
local ADD_BUTTON_WIDTH = 86
local REMOVE_BUTTON_WIDTH = 25
local REMOVE_BUTTON_GAP = 4
local MOVE_BUTTON_WIDTH = 25
local MOVE_BUTTON_GAP = 3

local ACTIVE_WINDOW_WIDTH = 360
local ACTIVE_QUEST_COLUMNS = 2
local ACTIVE_QUEST_BUTTON_WIDTH = 155
local ACTIVE_QUEST_BUTTON_HEIGHT = 24
local ACTIVE_QUEST_COLUMN_GAP = 6
local ACTIVE_QUEST_ROW_GAP = 4
local ACTIVE_QUEST_TEXT_COLOR = { 0.20, 0.13, 0.05, 1 }

local STATUS_COLORS = {
	notStarted = { 0.85, 0.15, 0.12, 1 },
	inProgress = { 0.85, 0.40, 0.05, 1 },
	complete = { 0.20, 0.75, 0.20, 1 },
}

local mainRows = {}
local mainSubRows = {}
local mainSubRemoveButtons = {}
local activeQuestRows = {}
local elapsed = 0
local selectedGroupIndexByMode = {
	[MODE_DAILIES] = nil,
	[MODE_WEEKLIES] = nil,
}

local choreTrackerButton, choreTrackerWindow
local summaryLabel, groupTitleEdit, makeGroupButton, dailiesButton, weekliesButton, popoutButton, lockPopButton
local activeQuestWindow, activeQuestTitleLabel, activeQuestSummaryLabel, activeQuestCloseButton
local activeQuestIdEdit, activeQuestIdAddButton
local choreTrackerCloseButton
local titleLabel, background, activeQuestBackground
local removeConfirmWindow, removeConfirmLabel, removeConfirmYesButton, removeConfirmNoButton
local removeConfirmAction = nil
local popoutWindow, popoutBackground
local popoutLabels = {}
local popoutVisible = false
local popoutLocked = false
local popoutPosX = 460
local popoutPosY = 0

local RefreshMain
local RefreshActiveQuests
local RefreshPopout

local function GetGroupsForMode(mode)
	if mode == MODE_WEEKLIES then
		return GROUPS_WEEKLIES
	end
	return GROUPS_DAILIES
end

local function GetActiveGroups()
	return GetGroupsForMode(activeMode)
end

local function GetSelectedGroupIndex()
	return selectedGroupIndexByMode[activeMode]
end

local function SetSelectedGroupIndex(index)
	selectedGroupIndexByMode[activeMode] = index
end

local function SetWidgetTextColor(widget, color)
	if widget == nil or color == nil then
		return
	end

	local red = color[1] or 1
	local green = color[2] or 1
	local blue = color[3] or 1
	local alpha = color[4] or 1

	-- Prefer the style API (same pattern used in extendedplates labels/buttons).
	if widget.style ~= nil and widget.style.SetColor ~= nil then
		widget.style:SetColor(red, green, blue, alpha)
	end

	-- Fallback for widget types that expose direct text color methods.
	if widget.SetTextColor ~= nil then
		widget:SetTextColor(red, green, blue, alpha)
	end
	if widget.SetHighlightTextColor ~= nil then
		widget:SetHighlightTextColor(red, green, blue, alpha)
	end
	if widget.SetPushedTextColor ~= nil then
		widget:SetPushedTextColor(red, green, blue, alpha)
	end
	if widget.SetDisabledTextColor ~= nil then
		widget:SetDisabledTextColor(red, green, blue, alpha)
	end
end

local function ShowRemoveConfirm(message, onConfirm)
	removeConfirmAction = onConfirm
	removeConfirmLabel:SetText(tostring(message or "Remove?"))
	removeConfirmWindow:Show(true)
	removeConfirmWindow:Raise()
end

local function RefreshModeButtons()
	if dailiesButton == nil or weekliesButton == nil then
		return
	end
	if activeMode == MODE_DAILIES then
		SetWidgetTextColor(dailiesButton, STATUS_COLORS.complete)
		SetWidgetTextColor(weekliesButton, ACTIVE_QUEST_TEXT_COLOR)
	else
		SetWidgetTextColor(dailiesButton, ACTIVE_QUEST_TEXT_COLOR)
		SetWidgetTextColor(weekliesButton, STATUS_COLORS.complete)
	end
end

local function GetQuestTitle(questId, fallbackName)
	local title = X2Quest:GetQuestContextMainTitle(questId)
	if title == nil or title == "" then
		title = fallbackName
	end
	if title == nil or title == "" then
		title = "Quest " .. tostring(questId)
	end
	return title
end

local function IsQuestKnown(questId)
	return DAILY_QUESTS[questId] == true or WEEKLY_QUESTS[questId] == true or RACE_QUESTS[questId] == true
end

local function GetShortQuestTitle(title)
	title = tostring(title or "")
	if string.len(title) <= 17 then
		return title
	end
	return string.sub(title, 1, 12) .. ".." .. string.sub(title, -5)
end

local function GetActiveQuestIndex(questId)
	local count = X2Quest:GetActiveQuestListCount()
	for index = 1, count do
		if X2Quest:GetActiveQuestType(index) == questId then
			return index
		end
	end
	return nil
end

local function IsQuestInProgress(questId)
	return GetActiveQuestIndex(questId) ~= nil and X2Quest:IsCompleted(questId) ~= true
end

local function IsRaceQuest(questId)
	return RACE_QUESTS[questId] == true
end

local function IsQuestAllowedForMode(questId)
	if activeMode == MODE_DAILIES then
		return DAILY_QUESTS[questId] == true
	end
	if activeMode == MODE_WEEKLIES then
		return WEEKLY_QUESTS[questId] == true
	end
	return false
end

local function HasQuestInList(list, questId)
	for _, id in ipairs(list) do
		if id == questId then
			return true
		end
	end
	return false
end

local function RemoveQuestFromList(list, questId)
	for i = #list, 1, -1 do
		if list[i] == questId then
			table.remove(list, i)
			return true
		end
	end
	return false
end

local function SaveData()
	ADDON:ClearData(SAVE_KEY)
	ADDON:SaveData(SAVE_KEY, {
		dailiesGroups = GROUPS_DAILIES,
		weekliesGroups = GROUPS_WEEKLIES,
		ungrouped = UNGROUPED_QUESTS,
		ungroupedExpanded = UNGROUPED_EXPANDED,
		popout = {
			visible = popoutVisible,
			locked = popoutLocked,
			x = popoutPosX,
			y = popoutPosY,
		},
	})
end

local function NormalizeQuestArray(values)
	local out = {}
	if type(values) ~= "table" then
		return out
	end
	for _, value in ipairs(values) do
		local id = tonumber(value)
		if id ~= nil then
			out[#out + 1] = id
		end
	end
	return out
end

local function NormalizeGroups(values)
	local out = {}
	if type(values) ~= "table" then
		return out
	end
	for _, group in ipairs(values) do
		if type(group) == "table" then
			out[#out + 1] = {
				title = tostring(group.title or "Group"),
				quests = NormalizeQuestArray(group.quests),
				expanded = group.expanded ~= false,
			}
		end
	end
	return out
end

local function LoadLegacyIntoUngrouped()
	local legacy = ADDON:LoadData(LEGACY_CHORES_KEY)
	if type(legacy) ~= "table" then
		return
	end
	for _, chore in ipairs(legacy) do
		local questId = nil
		if type(chore) == "number" then
			questId = tonumber(chore)
		elseif type(chore) == "table" then
			questId = tonumber(chore.id)
		end
		if questId ~= nil and not HasQuestInList(UNGROUPED_QUESTS, questId) then
			UNGROUPED_QUESTS[#UNGROUPED_QUESTS + 1] = questId
		end
	end
end

local function LoadData()
	local saved = ADDON:LoadData(SAVE_KEY)
	if type(saved) == "table" then
		if saved.dailiesGroups ~= nil or saved.weekliesGroups ~= nil then
			GROUPS_DAILIES = NormalizeGroups(saved.dailiesGroups)
			GROUPS_WEEKLIES = NormalizeGroups(saved.weekliesGroups)
		else
			GROUPS_DAILIES = NormalizeGroups(saved.groups)
			GROUPS_WEEKLIES = {}
		end
		UNGROUPED_QUESTS = NormalizeQuestArray(saved.ungrouped)
		UNGROUPED_EXPANDED = saved.ungroupedExpanded ~= false
		if type(saved.popout) == "table" then
			popoutVisible = saved.popout.visible == true
			popoutLocked = saved.popout.locked == true
			popoutPosX = tonumber(saved.popout.x) or popoutPosX
			popoutPosY = tonumber(saved.popout.y) or popoutPosY
		end
		return
	end

	local oldGroups = ADDON:LoadData(LEGACY_GROUP_KEY)
	if type(oldGroups) == "table" then
		local normalized = NormalizeGroups(oldGroups)
		if #normalized == 1 and normalized[1].title == "Imported" then
			UNGROUPED_QUESTS = normalized[1].quests
			GROUPS_DAILIES = {}
		else
			GROUPS_DAILIES = normalized
			UNGROUPED_QUESTS = {}
		end
		GROUPS_WEEKLIES = {}
		UNGROUPED_EXPANDED = true
		LoadLegacyIntoUngrouped()
		SaveData()
		return
	end

	local defaults = CHORETRACKER_DEFAULT_SETTINGS
	if type(defaults) == "table" then
		GROUPS_DAILIES = NormalizeGroups(defaults.dailiesGroups)
		GROUPS_WEEKLIES = NormalizeGroups(defaults.weekliesGroups)
		UNGROUPED_QUESTS = {}
		UNGROUPED_EXPANDED = true
		SaveData()
		return
	end

	GROUPS_DAILIES = {}
	GROUPS_WEEKLIES = {}
	UNGROUPED_QUESTS = {}
	UNGROUPED_EXPANDED = true
	LoadLegacyIntoUngrouped()
	SaveData()
end

local function GetQuestStatusColorAndPrefix(questId)
	if X2Quest:IsCompleted(questId) == true then
		return STATUS_COLORS.complete, "[x]"
	end
	if IsQuestInProgress(questId) then
		return STATUS_COLORS.inProgress, "[~]"
	end
	return STATUS_COLORS.notStarted, "[ ]"
end

local function GetGroupStatus(group)
	local total = #group.quests
	if total == 0 then
		return "not_started"
	end

	local completedCount = 0
	local inProgressCount = 0
	for _, questId in ipairs(group.quests) do
		if X2Quest:IsCompleted(questId) == true then
			completedCount = completedCount + 1
		elseif IsQuestInProgress(questId) then
			inProgressCount = inProgressCount + 1
		end
	end

	if completedCount == total then
		return "complete"
	end
	if inProgressCount > 0 then
		return "in_progress"
	end
	return "not_started"
end

local function GetGroupCompletionCount(group)
	local completedCount = 0
	for _, questId in ipairs(group.quests) do
		if X2Quest:IsCompleted(questId) == true then
			completedCount = completedCount + 1
		end
	end
	return completedCount, #group.quests
end

local function SetPopoutLockState(locked)
	popoutLocked = locked == true
	if lockPopButton ~= nil then
		lockPopButton:SetText(popoutLocked and "Lock pop [ON]" or "Lock pop [OFF]")
	end
	if popoutWindow ~= nil then
		popoutWindow:EnableDrag(not popoutLocked)
		if popoutWindow.EnablePick ~= nil then
			popoutWindow:EnablePick(not popoutLocked)
		end
		popoutWindow:Clickable(not popoutLocked)
	end
	if popoutBackground ~= nil and popoutBackground.SetColor ~= nil then
		if popoutLocked then
			popoutBackground:SetColor(0.15, 0.15, 0.15, 0.0)
		else
			popoutBackground:SetColor(0.15, 0.15, 0.15, 0.75)
		end
	end
	for _, label in ipairs(popoutLabels) do
		if label ~= nil and label.EnablePick ~= nil then
			label:EnablePick(false)
		end
	end
end

local function EnsurePopoutRows(count)
	for index = 1, count do
		if popoutLabels[index] == nil then
			local label = popoutWindow:CreateChildWidget("label", "popoutLabel" .. tostring(index), index, true)
			label:SetExtent(260, 22)
			label.style:SetAlign(ALIGN_LEFT)
			label.style:SetFontSize(14)
			label:EnablePick(false)
			popoutLabels[index] = label
		end
	end
end

local function CreateLocalEditBox(parent, id, width)
	local edit = parent:CreateChildWidgetByType(UOT_X2_EDITBOX, id, 0, true)
	edit:SetHeight(26)
	edit:SetWidth(width)
	edit:SetInset(5, 5, 5, 5)
	edit:EnableFocus(true)
	edit:UseSelectAllWhenFocused(true)
	edit.style:SetAlign(ALIGN_LEFT)
	edit.style:SetColorByKey("title")

	local bg = edit:CreateDrawable("ui/common/default.dds", "editbox_df", "background")
	bg:AddAnchor("TOPLEFT", edit, 0, 0)
	bg:AddAnchor("BOTTOMRIGHT", edit, 0, 0)
	edit.bg = bg
	return edit
end

local function EnsureMainRows(count)
	for index = 1, count do
		if mainRows[index] == nil then
			local row = {}

			row.titleLabel = choreTrackerWindow:CreateChildWidget("label", "mainTitleLabel" .. tostring(index), index, true)
			row.titleLabel:SetExtent(WINDOW_WIDTH - (WINDOW_PADDING * 2) - ADD_BUTTON_WIDTH - 8, ROW_HEIGHT)
			row.titleLabel.style:SetAlign(ALIGN_LEFT)
			row.titleLabel.style:SetFontSize(13)
			row.titleLabel:EnablePick(true)

			row.addButton = choreTrackerWindow:CreateChildWidget("button", "mainAddButton" .. tostring(index), index, true)
			row.addButton:SetStyle("text_default")
			row.addButton:SetAutoResize(false)
			row.addButton:SetExtent(ADD_BUTTON_WIDTH, ROW_HEIGHT)
			row.addButton:SetText("Add quests")

			row.removeButton = choreTrackerWindow:CreateChildWidget("button", "mainRemoveButton" .. tostring(index), index, true)
			row.removeButton:SetStyle("text_default")
			row.removeButton:SetAutoResize(false)
			row.removeButton:SetExtent(35, ROW_HEIGHT)
			row.removeButton:SetText("-")
			row.removeButton:SetWidth(REMOVE_BUTTON_WIDTH)

			row.moveUpButton = choreTrackerWindow:CreateChildWidget("button", "mainMoveUpButton" .. tostring(index), index, true)
			row.moveUpButton:SetStyle("text_default")
			row.moveUpButton:SetAutoResize(false)
			row.moveUpButton:SetExtent(35, ROW_HEIGHT)
			row.moveUpButton:SetText("^")
			row.moveUpButton:SetWidth(MOVE_BUTTON_WIDTH)

			row.moveDownButton =
				choreTrackerWindow:CreateChildWidget("button", "mainMoveDownButton" .. tostring(index), index, true)
			row.moveDownButton:SetStyle("text_default")
			row.moveDownButton:SetAutoResize(false)
			row.moveDownButton:SetExtent(35, ROW_HEIGHT)
			row.moveDownButton:SetText("v")
			row.moveDownButton:SetWidth(MOVE_BUTTON_WIDTH)

			function row.titleLabel:OnClick(arg)
				if arg == "RightButton" then
					return
				end
				local groups = GetActiveGroups()
				if self.groupIndex ~= nil and groups[self.groupIndex] ~= nil then
					groups[self.groupIndex].expanded = not groups[self.groupIndex].expanded
					SaveData()
					RefreshMain()
				end
			end
			row.titleLabel:SetHandler("OnClick", row.titleLabel.OnClick)

			function row.addButton:OnClick(arg)
				if arg == "RightButton" then
					return
				end
				local groups = GetActiveGroups()
				if self.groupIndex == nil or groups[self.groupIndex] == nil then
					return
				end
				SetSelectedGroupIndex(self.groupIndex)
				activeQuestWindow:Show(true)
				activeQuestTitleLabel:SetText(
					string.format(
						"%s -> %s",
						activeMode == MODE_DAILIES and "Dailies" or "Weeklies",
						tostring(groups[GetSelectedGroupIndex()].title)
					)
				)
				RefreshActiveQuests()
				activeQuestWindow:Raise()
			end
			row.addButton:SetHandler("OnClick", row.addButton.OnClick)

			function row.removeButton:OnClick(arg)
				if arg == "RightButton" then
					return
				end
				local groups = GetActiveGroups()
				if self.groupIndex == nil or groups[self.groupIndex] == nil then
					return
				end
				local groupIndex = self.groupIndex
				local title = tostring(groups[groupIndex].title or ("Group " .. tostring(groupIndex)))
				ShowRemoveConfirm("Remove category '" .. title .. "'?", function()
					local activeGroups = GetActiveGroups()
					table.remove(activeGroups, groupIndex)
					local selectedGroupIndex = GetSelectedGroupIndex()
					if selectedGroupIndex ~= nil then
						if selectedGroupIndex == groupIndex then
							SetSelectedGroupIndex(nil)
							activeQuestWindow:Show(false)
						elseif selectedGroupIndex > groupIndex then
							SetSelectedGroupIndex(selectedGroupIndex - 1)
						end
					end
					SaveData()
					RefreshMain()
				end)
			end
			row.removeButton:SetHandler("OnClick", row.removeButton.OnClick)

			function row.moveUpButton:OnClick(arg)
				if arg == "RightButton" then
					return
				end
				local groups = GetActiveGroups()
				if self.groupIndex == nil or groups[self.groupIndex] == nil or self.groupIndex <= 1 then
					return
				end
				local i = self.groupIndex
				groups[i], groups[i - 1] = groups[i - 1], groups[i]

				local selectedGroupIndex = GetSelectedGroupIndex()
				if selectedGroupIndex ~= nil then
					if selectedGroupIndex == i then
						SetSelectedGroupIndex(i - 1)
					elseif selectedGroupIndex == i - 1 then
						SetSelectedGroupIndex(i)
					end
				end

				SaveData()
				RefreshMain()
			end
			row.moveUpButton:SetHandler("OnClick", row.moveUpButton.OnClick)

			function row.moveDownButton:OnClick(arg)
				if arg == "RightButton" then
					return
				end
				local groups = GetActiveGroups()
				if self.groupIndex == nil or groups[self.groupIndex] == nil or self.groupIndex >= #groups then
					return
				end
				local i = self.groupIndex
				groups[i], groups[i + 1] = groups[i + 1], groups[i]

				local selectedGroupIndex = GetSelectedGroupIndex()
				if selectedGroupIndex ~= nil then
					if selectedGroupIndex == i then
						SetSelectedGroupIndex(i + 1)
					elseif selectedGroupIndex == i + 1 then
						SetSelectedGroupIndex(i)
					end
				end

				SaveData()
				RefreshMain()
			end
			row.moveDownButton:SetHandler("OnClick", row.moveDownButton.OnClick)

			mainRows[index] = row
		end
	end
end

local function EnsureMainSubRows(count)
	for index = 1, count do
		if mainSubRows[index] == nil then
			local label = choreTrackerWindow:CreateChildWidget("label", "mainSubLabel" .. tostring(index), index, true)
			label:SetExtent(WINDOW_WIDTH - (WINDOW_PADDING * 2) - 12, ROW_HEIGHT)
			label.style:SetAlign(ALIGN_LEFT)
			label.style:SetFontSize(12)
			label:EnablePick(true)

			function label:OnClick(arg)
				if arg == "RightButton" then
					return
				end
				if self.questId ~= nil then
					local idx = GetActiveQuestIndex(self.questId)
					if idx ~= nil then
						X2Quest:SetTrackingActiveQuest(idx)
					end
				end
			end
			label:SetHandler("OnClick", label.OnClick)
			mainSubRows[index] = label

			local removeButton =
				choreTrackerWindow:CreateChildWidget("button", "mainSubRemoveButton" .. tostring(index), index, true)
			removeButton:SetStyle("text_default")
			removeButton:SetAutoResize(false)
			removeButton:SetExtent(35, ROW_HEIGHT)
			removeButton:SetText("-")
			removeButton:SetWidth(REMOVE_BUTTON_WIDTH)
			function removeButton:OnClick(arg)
				if arg == "RightButton" then
					return
				end
				if self.questId == nil then
					return
				end
				local groupIndex = self.groupIndex
				local questId = self.questId
				local groups = GetActiveGroups()
				if groupIndex == nil or groups[groupIndex] == nil then
					return
				end
				ShowRemoveConfirm("Remove quest '" .. GetQuestTitle(questId) .. "'?", function()
					local activeGroups = GetActiveGroups()
					local list = activeGroups[groupIndex] and activeGroups[groupIndex].quests or nil
					if list == nil then
						return
					end
					if RemoveQuestFromList(list, questId) then
						SaveData()
						RefreshMain()
						if activeQuestWindow:IsVisible() then
							RefreshActiveQuests()
						end
					end
				end)
			end
			removeButton:SetHandler("OnClick", removeButton.OnClick)
			mainSubRemoveButtons[index] = removeButton
		end
	end
end

local function EnsureActiveQuestRows(count)
	for index = 1, count do
		if activeQuestRows[index] == nil then
			local row = activeQuestWindow:CreateChildWidget("button", "activeQuestRow" .. tostring(index), index, true)
			row:SetStyle("text_default")
			row:SetAutoResize(false)
			row:SetExtent(ACTIVE_QUEST_BUTTON_WIDTH, ACTIVE_QUEST_BUTTON_HEIGHT)
			row:SetWidth(ACTIVE_QUEST_BUTTON_WIDTH)
			row:SetHeight(ACTIVE_QUEST_BUTTON_HEIGHT)
			row:AddAnchor(
				"TOPLEFT",
				activeQuestWindow,
				WINDOW_PADDING
					+ (((index - 1) % ACTIVE_QUEST_COLUMNS) * (ACTIVE_QUEST_BUTTON_WIDTH + ACTIVE_QUEST_COLUMN_GAP)),
				102
					+ (math.floor((index - 1) / ACTIVE_QUEST_COLUMNS) * (ACTIVE_QUEST_BUTTON_HEIGHT + ACTIVE_QUEST_ROW_GAP))
			)
			row:Show(true)

			function row:OnClick(arg)
				if arg == "RightButton" then
					return
				end
				local groups = GetActiveGroups()
				local selectedGroupIndex = GetSelectedGroupIndex()
				if selectedGroupIndex == nil or groups[selectedGroupIndex] == nil then
					return
				end
				local list = groups[selectedGroupIndex].quests

				if self.isTracked == true then
					if RemoveQuestFromList(list, self.questId) then
						self.isTracked = false
						SetWidgetTextColor(self, ACTIVE_QUEST_TEXT_COLOR)
						SaveData()
						RefreshMain()
					end
				elseif not HasQuestInList(list, self.questId) then
					list[#list + 1] = self.questId
					self.isTracked = true
					SetWidgetTextColor(self, STATUS_COLORS.complete)
					SaveData()
					RefreshMain()
				end
			end
			row:SetHandler("OnClick", row.OnClick)

			activeQuestRows[index] = row
		end
	end
end

RefreshActiveQuests = function()
	local count = X2Quest:GetActiveQuestListCount()
	EnsureActiveQuestRows(count)
	local visibleCount = 0

	local groups = GetActiveGroups()
	local selectedGroupIndex = GetSelectedGroupIndex()
	if selectedGroupIndex == nil or groups[selectedGroupIndex] == nil then
		for index = 1, #activeQuestRows do
			activeQuestRows[index]:Show(false)
		end
		activeQuestSummaryLabel:SetText("Pick a group first.")
		activeQuestWindow:SetExtent(ACTIVE_WINDOW_WIDTH, 120)
		return
	end

	for index = 1, count do
		local questId = X2Quest:GetActiveQuestType(index)
		local title = GetQuestTitle(questId)
		local inProgress = IsQuestInProgress(questId)
		local tracked = HasQuestInList(groups[selectedGroupIndex].quests, questId)

		if inProgress and not IsRaceQuest(questId) and IsQuestAllowedForMode(questId) then
			visibleCount = visibleCount + 1
			local row = activeQuestRows[visibleCount]
			row.questId = questId
			row.isTracked = tracked
			row:SetText(GetShortQuestTitle(title))
			if tracked then
				SetWidgetTextColor(row, STATUS_COLORS.complete)
			else
				SetWidgetTextColor(row, ACTIVE_QUEST_TEXT_COLOR)
			end
			row:Show(true)
		end
	end

	for index = visibleCount + 1, #activeQuestRows do
		activeQuestRows[index]:Show(false)
	end

	if visibleCount == 0 then
		activeQuestSummaryLabel:SetText("No in-progress quests.")
	else
		activeQuestSummaryLabel:SetText("Click quests to toggle in target.")
	end

	local visibleRows = math.max(math.ceil(visibleCount / ACTIVE_QUEST_COLUMNS), 1)
	local height = 126 + (visibleRows * (ACTIVE_QUEST_BUTTON_HEIGHT + ACTIVE_QUEST_ROW_GAP))
	activeQuestWindow:SetExtent(ACTIVE_WINDOW_WIDTH, height)
end

RefreshMain = function()
	local groups = GetActiveGroups()
	RefreshModeButtons()
	local rowCount = #groups
	EnsureMainRows(rowCount)

	local subCount = 0
	for _, group in ipairs(groups) do
		if group.expanded ~= false then
			subCount = subCount + #group.quests
		end
	end
	EnsureMainSubRows(subCount)

	local y = 105
	local mainIndex = 0
	local subIndex = 0
	local completeGroups = 0

	local function renderMainRow(titleText, color, targetType, groupIndex)
		mainIndex = mainIndex + 1
		local row = mainRows[mainIndex]

		row.titleLabel:RemoveAllAnchors()
		row.titleLabel:AddAnchor("TOPLEFT", choreTrackerWindow, WINDOW_PADDING, y)
		row.titleLabel:SetText(titleText)
		SetWidgetTextColor(row.titleLabel, color)
		row.titleLabel.targetType = targetType
		row.titleLabel.groupIndex = groupIndex
		row.titleLabel:Show(true)

		local addX = WINDOW_PADDING + (WINDOW_WIDTH - (WINDOW_PADDING * 2) - ADD_BUTTON_WIDTH)
		row.addButton:RemoveAllAnchors()
		row.addButton:AddAnchor("TOPLEFT", choreTrackerWindow, addX, y)
		row.addButton.groupIndex = groupIndex
		row.addButton:Show(true)

		row.removeButton:RemoveAllAnchors()
		row.removeButton:AddAnchor("TOPLEFT", choreTrackerWindow, addX - REMOVE_BUTTON_WIDTH - REMOVE_BUTTON_GAP, y)
		row.removeButton.groupIndex = groupIndex
		row.removeButton:Show(targetType == "group")

		row.moveUpButton:RemoveAllAnchors()
		row.moveUpButton:AddAnchor(
			"TOPLEFT",
			choreTrackerWindow,
			addX - REMOVE_BUTTON_WIDTH - REMOVE_BUTTON_GAP - MOVE_BUTTON_WIDTH - MOVE_BUTTON_GAP,
			y
		)
		row.moveUpButton.groupIndex = groupIndex
		row.moveUpButton:Show(targetType == "group")

		row.moveDownButton:RemoveAllAnchors()
		row.moveDownButton:AddAnchor(
			"TOPLEFT",
			choreTrackerWindow,
			addX - REMOVE_BUTTON_WIDTH - REMOVE_BUTTON_GAP - ((MOVE_BUTTON_WIDTH + MOVE_BUTTON_GAP) * 2),
			y
		)
		row.moveDownButton.groupIndex = groupIndex
		row.moveDownButton:Show(targetType == "group")

		y = y + ROW_HEIGHT + ROW_GAP
	end

	local function renderSubQuest(questId, groupIndex)
		subIndex = subIndex + 1
		local label = mainSubRows[subIndex]
		local removeButton = mainSubRemoveButtons[subIndex]
		local color, prefix = GetQuestStatusColorAndPrefix(questId)
		label.questId = questId
		label:RemoveAllAnchors()
		label:AddAnchor("TOPLEFT", choreTrackerWindow, WINDOW_PADDING + 30, y)
		label:SetText(string.format("%s %s", prefix, GetQuestTitle(questId)))
		SetWidgetTextColor(label, color)
		label:Show(true)

		removeButton.questId = questId
		removeButton.groupIndex = groupIndex
		removeButton:RemoveAllAnchors()
		removeButton:AddAnchor("TOPLEFT", choreTrackerWindow, WINDOW_PADDING + 2, y)
		removeButton:Show(true)

		y = y + ROW_HEIGHT + ROW_GAP
	end

	for groupIndex, group in ipairs(groups) do
		local status = GetGroupStatus(group)
		local color = STATUS_COLORS.notStarted
		local prefix = "[ ]"
		if status == "complete" then
			color = STATUS_COLORS.complete
			prefix = "[x]"
			completeGroups = completeGroups + 1
		elseif status == "in_progress" then
			color = STATUS_COLORS.inProgress
			prefix = "[~]"
		end
		local isOpen = group.expanded ~= false
		local open = isOpen and "-" or "+"
		local completedCount, totalCount = GetGroupCompletionCount(group)
		local title = string.format(
			"%s %s (%d/%d) [%s]",
			prefix,
			tostring(group.title),
			completedCount,
			totalCount,
			open
		)
		renderMainRow(title, color, "group", groupIndex)
		if isOpen then
			for _, questId in ipairs(group.quests) do
				renderSubQuest(questId, groupIndex)
			end
		end
	end

	for i = mainIndex + 1, #mainRows do
		mainRows[i].titleLabel:Show(false)
		mainRows[i].addButton:Show(false)
		mainRows[i].removeButton:Show(false)
		mainRows[i].moveUpButton:Show(false)
		mainRows[i].moveDownButton:Show(false)
	end
	for i = subIndex + 1, #mainSubRows do
		mainSubRows[i]:Show(false)
		mainSubRemoveButtons[i]:Show(false)
	end

	summaryLabel:SetText(
		string.format(
			"%s Groups: %d / %d complete",
			activeMode == MODE_DAILIES and "Dailies" or "Weeklies",
			completeGroups,
			#groups
		)
	)
	popoutButton:RemoveAllAnchors()
	popoutButton:AddAnchor("TOPLEFT", choreTrackerWindow, WINDOW_PADDING, y)
	popoutButton:Show(true)

	lockPopButton:RemoveAllAnchors()
	lockPopButton:AddAnchor("TOPLEFT", choreTrackerWindow, WINDOW_PADDING + 116, y)
	lockPopButton:Show(true)

	local height = y + ROW_HEIGHT + WINDOW_PADDING
	choreTrackerWindow:SetExtent(WINDOW_WIDTH, height)
	RefreshPopout()
end

local function MakeGroup()
	local groups = GetActiveGroups()
	local title = tostring(groupTitleEdit:GetText() or ""):match("^%s*(.-)%s*$")
	if title == nil or title == "" then
		title = "Group " .. tostring(#groups + 1)
	end
	groups[#groups + 1] = {
		title = title,
		quests = {},
		expanded = true,
	}
	SaveData()
	groupTitleEdit:SetText("Group")
	RefreshMain()
end

choreTrackerButton = CreateSimpleButton("chores", 700, -380)
choreTrackerWindow = CreateEmptyWindow("choreTrackerWindow", "UIParent")
choreTrackerWindow:SetCloseOnEscape(true)
choreTrackerWindow:SetExtent(WINDOW_WIDTH, 200)
choreTrackerWindow:AddAnchor("CENTER", "UIParent", 0, 0)
choreTrackerWindow:Show(false)
choreTrackerWindow:Enable(true)
choreTrackerWindow:Clickable(true)
choreTrackerWindow:EnableDrag(true)
choreTrackerWindow:SetUILayer("system")

background = choreTrackerWindow:CreateColorDrawable(0.05, 0.05, 0.05, 0.90, "background")
background:AddAnchor("TOPLEFT", choreTrackerWindow, 0, 0)
background:AddAnchor("BOTTOMRIGHT", choreTrackerWindow, 0, 0)

local mainBorderTop = choreTrackerWindow:CreateColorDrawable(0.65, 0.55, 0.35, 0.9, "artwork")
mainBorderTop:AddAnchor("TOPLEFT", choreTrackerWindow, 0, 0)
mainBorderTop:SetExtent(WINDOW_WIDTH, 2)
local mainBorderBottom = choreTrackerWindow:CreateColorDrawable(0.65, 0.55, 0.35, 0.9, "artwork")
mainBorderBottom:AddAnchor("BOTTOMLEFT", choreTrackerWindow, 0, 0)
mainBorderBottom:SetExtent(WINDOW_WIDTH, 2)
local mainBorderLeft = choreTrackerWindow:CreateColorDrawable(0.65, 0.55, 0.35, 0.9, "artwork")
mainBorderLeft:AddAnchor("TOPLEFT", choreTrackerWindow, 0, 0)
mainBorderLeft:AddAnchor("BOTTOMLEFT", choreTrackerWindow, 0, 0)
mainBorderLeft:SetExtent(2, 0)
local mainBorderRight = choreTrackerWindow:CreateColorDrawable(0.65, 0.55, 0.35, 0.9, "artwork")
mainBorderRight:AddAnchor("TOPRIGHT", choreTrackerWindow, 0, 0)
mainBorderRight:AddAnchor("BOTTOMRIGHT", choreTrackerWindow, 0, 0)
mainBorderRight:SetExtent(2, 0)

local mainTitleBar = choreTrackerWindow:CreateColorDrawable(0.16, 0.10, 0.05, 0.95, "artwork")
mainTitleBar:AddAnchor("TOPLEFT", choreTrackerWindow, 2, 2)
mainTitleBar:SetExtent(WINDOW_WIDTH - 4, 34)

function choreTrackerWindow:OnDragStart()
	self:StartMoving()
	return true
end
choreTrackerWindow:SetHandler("OnDragStart", choreTrackerWindow.OnDragStart)

function choreTrackerWindow:OnDragStop()
	self:StopMovingOrSizing()
end
choreTrackerWindow:SetHandler("OnDragStop", choreTrackerWindow.OnDragStop)

titleLabel = choreTrackerWindow:CreateChildWidget("label", "titleLabel", 0, true)
titleLabel:SetExtent(WINDOW_WIDTH - (WINDOW_PADDING * 2), 22)
titleLabel:AddAnchor("TOPLEFT", choreTrackerWindow, WINDOW_PADDING, 10)
titleLabel.style:SetAlign(ALIGN_LEFT)
titleLabel.style:SetFontSize(16)
titleLabel.style:SetColor(1, 1, 1, 1)
titleLabel:SetText("ChoreTracker")

summaryLabel = choreTrackerWindow:CreateChildWidget("label", "summaryLabel", 0, true)
summaryLabel:SetExtent(WINDOW_WIDTH - (WINDOW_PADDING * 2), 20)
summaryLabel:AddAnchor("TOPLEFT", choreTrackerWindow, WINDOW_PADDING, 45)
summaryLabel.style:SetAlign(ALIGN_LEFT)
summaryLabel.style:SetFontSize(14)
summaryLabel.style:SetColor(1, 1, 1, 1)

groupTitleEdit = CreateLocalEditBox(choreTrackerWindow, "groupTitleEdit", 215)
groupTitleEdit:AddAnchor("TOPLEFT", choreTrackerWindow, WINDOW_PADDING, 70)
groupTitleEdit:SetText("Group")

makeGroupButton = choreTrackerWindow:CreateChildWidget("button", "makeGroupButton", 0, true)
makeGroupButton:SetStyle("text_default")
makeGroupButton:SetAutoResize(false)
makeGroupButton:SetExtent(110, 26)
makeGroupButton:AddAnchor("TOPLEFT", choreTrackerWindow, WINDOW_PADDING + 222, 70)
makeGroupButton:SetText("Make Group")

dailiesButton = choreTrackerWindow:CreateChildWidget("button", "dailiesButton", 0, true)
dailiesButton:SetStyle("text_default")
dailiesButton:SetAutoResize(false)
dailiesButton:SetExtent(78, 22)
dailiesButton:AddAnchor("TOPRIGHT", choreTrackerWindow, -102, 44)
dailiesButton:SetText("Dailies")

weekliesButton = choreTrackerWindow:CreateChildWidget("button", "weekliesButton", 0, true)
weekliesButton:SetStyle("text_default")
weekliesButton:SetAutoResize(false)
weekliesButton:SetExtent(78, 22)
weekliesButton:AddAnchor("TOPRIGHT", choreTrackerWindow, -20, 44)
weekliesButton:SetText("Weeklies")

popoutButton = choreTrackerWindow:CreateChildWidget("button", "popoutButton", 0, true)
popoutButton:SetStyle("text_default")
popoutButton:SetAutoResize(false)
popoutButton:SetExtent(110, 26)
popoutButton:SetText("Popout")

lockPopButton = choreTrackerWindow:CreateChildWidget("button", "lockPopButton", 0, true)
lockPopButton:SetStyle("text_default")
lockPopButton:SetAutoResize(false)
lockPopButton:SetExtent(110, 26)
lockPopButton:SetText("Lock pop [OFF]")

choreTrackerCloseButton = choreTrackerWindow:CreateChildWidget("button", "choreTrackerCloseButton", 0, true)
choreTrackerCloseButton:SetStyle("text_default")
choreTrackerCloseButton:SetAutoResize(false)
choreTrackerCloseButton:SetExtent(30, 24)
choreTrackerCloseButton:AddAnchor("TOPRIGHT", choreTrackerWindow, -12, 7)
choreTrackerCloseButton:SetText("X")

activeQuestWindow = CreateEmptyWindow("choreTrackerActiveQuestWindow", "UIParent")
activeQuestWindow:SetCloseOnEscape(true)
activeQuestWindow:SetExtent(ACTIVE_WINDOW_WIDTH, 120)
activeQuestWindow:AddAnchor("CENTER", "UIParent", 290, 0)
activeQuestWindow:Show(false)
activeQuestWindow:Enable(true)
activeQuestWindow:Clickable(true)
activeQuestWindow:EnableDrag(true)
activeQuestWindow:SetUILayer("system")

activeQuestBackground = activeQuestWindow:CreateColorDrawable(0.05, 0.05, 0.05, 0.92, "background")
activeQuestBackground:AddAnchor("TOPLEFT", activeQuestWindow, 0, 0)
activeQuestBackground:AddAnchor("BOTTOMRIGHT", activeQuestWindow, 0, 0)

local activeBorderTop = activeQuestWindow:CreateColorDrawable(0.65, 0.55, 0.35, 0.9, "artwork")
activeBorderTop:AddAnchor("TOPLEFT", activeQuestWindow, 0, 0)
activeBorderTop:SetExtent(ACTIVE_WINDOW_WIDTH, 2)
local activeBorderBottom = activeQuestWindow:CreateColorDrawable(0.65, 0.55, 0.35, 0.9, "artwork")
activeBorderBottom:AddAnchor("BOTTOMLEFT", activeQuestWindow, 0, 0)
activeBorderBottom:SetExtent(ACTIVE_WINDOW_WIDTH, 2)
local activeBorderLeft = activeQuestWindow:CreateColorDrawable(0.65, 0.55, 0.35, 0.9, "artwork")
activeBorderLeft:AddAnchor("TOPLEFT", activeQuestWindow, 0, 0)
activeBorderLeft:AddAnchor("BOTTOMLEFT", activeQuestWindow, 0, 0)
activeBorderLeft:SetExtent(2, 0)
local activeBorderRight = activeQuestWindow:CreateColorDrawable(0.65, 0.55, 0.35, 0.9, "artwork")
activeBorderRight:AddAnchor("TOPRIGHT", activeQuestWindow, 0, 0)
activeBorderRight:AddAnchor("BOTTOMRIGHT", activeQuestWindow, 0, 0)
activeBorderRight:SetExtent(2, 0)
local activeTitleBar = activeQuestWindow:CreateColorDrawable(0.16, 0.10, 0.05, 0.95, "artwork")
activeTitleBar:AddAnchor("TOPLEFT", activeQuestWindow, 2, 2)
activeTitleBar:SetExtent(ACTIVE_WINDOW_WIDTH - 4, 34)

function activeQuestWindow:OnDragStart()
	self:StartMoving()
	return true
end
activeQuestWindow:SetHandler("OnDragStart", activeQuestWindow.OnDragStart)

function activeQuestWindow:OnDragStop()
	self:StopMovingOrSizing()
end
activeQuestWindow:SetHandler("OnDragStop", activeQuestWindow.OnDragStop)

activeQuestTitleLabel = activeQuestWindow:CreateChildWidget("label", "activeQuestTitleLabel", 0, true)
activeQuestTitleLabel:SetExtent(ACTIVE_WINDOW_WIDTH - 80, 22)
activeQuestTitleLabel:AddAnchor("TOPLEFT", activeQuestWindow, WINDOW_PADDING, 15)
activeQuestTitleLabel.style:SetAlign(ALIGN_LEFT)
activeQuestTitleLabel.style:SetFontSize(16)
activeQuestTitleLabel.style:SetColor(1, 1, 1, 1)
activeQuestTitleLabel:SetText("Active Quests")

activeQuestCloseButton = activeQuestWindow:CreateChildWidget("button", "activeQuestCloseButton", 0, true)
activeQuestCloseButton:SetStyle("text_default")
activeQuestCloseButton:SetAutoResize(false)
activeQuestCloseButton:SetExtent(24, 22)
activeQuestCloseButton:AddAnchor("TOPRIGHT", activeQuestWindow, -WINDOW_PADDING, 14)
activeQuestCloseButton:SetText("X")

activeQuestSummaryLabel = activeQuestWindow:CreateChildWidget("label", "activeQuestSummaryLabel", 0, true)
activeQuestSummaryLabel:SetExtent(ACTIVE_WINDOW_WIDTH - (WINDOW_PADDING * 2), 20)
activeQuestSummaryLabel:AddAnchor("TOPLEFT", activeQuestWindow, WINDOW_PADDING, 45)
activeQuestSummaryLabel.style:SetAlign(ALIGN_LEFT)
activeQuestSummaryLabel.style:SetFontSize(13)
activeQuestSummaryLabel.style:SetColor(1, 1, 1, 1)

activeQuestIdEdit = CreateLocalEditBox(activeQuestWindow, "activeQuestIdEdit", 90)
activeQuestIdEdit:AddAnchor("TOPLEFT", activeQuestWindow, WINDOW_PADDING, 68)
activeQuestIdEdit:SetText("")

activeQuestIdAddButton = activeQuestWindow:CreateChildWidget("button", "activeQuestIdAddButton", 0, true)
activeQuestIdAddButton:SetStyle("text_default")
activeQuestIdAddButton:SetAutoResize(false)
activeQuestIdAddButton:SetExtent(70, 26)
activeQuestIdAddButton:AddAnchor("TOPLEFT", activeQuestWindow, WINDOW_PADDING + 96, 68)
activeQuestIdAddButton:SetText("Add ID")

popoutWindow = CreateEmptyWindow("choreTrackerPopoutWindow", "UIParent")
popoutWindow:SetCloseOnEscape(false)
popoutWindow:SetExtent(280, 140)
popoutWindow:AddAnchor("TOPLEFT", "UIParent", popoutPosX, popoutPosY)
popoutWindow:Show(popoutVisible)
popoutWindow:Enable(true)
popoutWindow:Clickable(true)
popoutWindow:EnableDrag(true)
popoutWindow:SetUILayer("system")

popoutBackground = popoutWindow:CreateColorDrawable(0.15, 0.15, 0.15, 0.75, "background")
popoutBackground:AddAnchor("TOPLEFT", popoutWindow, 0, 0)
popoutBackground:AddAnchor("BOTTOMRIGHT", popoutWindow, 0, 0)

function popoutWindow:OnDragStart()
	if popoutLocked then
		return
	end
	self:StartMoving()
	return true
end
popoutWindow:SetHandler("OnDragStart", popoutWindow.OnDragStart)

function popoutWindow:OnDragStop()
	if popoutLocked then
		return
	end
	self:StopMovingOrSizing()
	local x, y = self:GetOffset()
	popoutPosX = tonumber(x) or popoutPosX
	popoutPosY = tonumber(y) or popoutPosY
	SaveData()
end
popoutWindow:SetHandler("OnDragStop", popoutWindow.OnDragStop)

removeConfirmWindow = CreateEmptyWindow("choreTrackerRemoveConfirmWindow", "UIParent")
removeConfirmWindow:SetCloseOnEscape(true)
removeConfirmWindow:SetExtent(280, 112)
removeConfirmWindow:AddAnchor("CENTER", "UIParent", 0, 0)
removeConfirmWindow:Show(false)
removeConfirmWindow:Enable(true)
removeConfirmWindow:Clickable(true)
removeConfirmWindow:SetUILayer("system")

local removeConfirmBackground = removeConfirmWindow:CreateColorDrawable(0.05, 0.05, 0.05, 0.95, "background")
removeConfirmBackground:AddAnchor("TOPLEFT", removeConfirmWindow, 0, 0)
removeConfirmBackground:AddAnchor("BOTTOMRIGHT", removeConfirmWindow, 0, 0)

local removeBorderTop = removeConfirmWindow:CreateColorDrawable(0.65, 0.55, 0.35, 0.9, "artwork")
removeBorderTop:AddAnchor("TOPLEFT", removeConfirmWindow, 0, 0)
removeBorderTop:SetExtent(280, 2)
local removeBorderBottom = removeConfirmWindow:CreateColorDrawable(0.65, 0.55, 0.35, 0.9, "artwork")
removeBorderBottom:AddAnchor("BOTTOMLEFT", removeConfirmWindow, 0, 0)
removeBorderBottom:SetExtent(280, 2)
local removeBorderLeft = removeConfirmWindow:CreateColorDrawable(0.65, 0.55, 0.35, 0.9, "artwork")
removeBorderLeft:AddAnchor("TOPLEFT", removeConfirmWindow, 0, 0)
removeBorderLeft:SetExtent(2, 112)
local removeBorderRight = removeConfirmWindow:CreateColorDrawable(0.65, 0.55, 0.35, 0.9, "artwork")
removeBorderRight:AddAnchor("TOPRIGHT", removeConfirmWindow, 0, 0)
removeBorderRight:SetExtent(2, 112)
local removeTitleBar = removeConfirmWindow:CreateColorDrawable(0.16, 0.10, 0.05, 0.95, "artwork")
removeTitleBar:AddAnchor("TOPLEFT", removeConfirmWindow, 2, 2)
removeTitleBar:SetExtent(276, 30)

removeConfirmLabel = removeConfirmWindow:CreateChildWidget("label", "removeConfirmLabel", 0, true)
removeConfirmLabel:SetExtent(248, 40)
removeConfirmLabel:AddAnchor("TOPLEFT", removeConfirmWindow, 16, 16)
removeConfirmLabel.style:SetAlign(ALIGN_LEFT)
removeConfirmLabel.style:SetFontSize(13)
removeConfirmLabel.style:SetColor(1, 1, 1, 1)
removeConfirmLabel:SetText("Remove?")

removeConfirmYesButton = removeConfirmWindow:CreateChildWidget("button", "removeConfirmYesButton", 0, true)
removeConfirmYesButton:SetStyle("text_default")
removeConfirmYesButton:SetAutoResize(false)
removeConfirmYesButton:SetExtent(64, 24)
removeConfirmYesButton:AddAnchor("BOTTOMRIGHT", removeConfirmWindow, -84, -14)
removeConfirmYesButton:SetText("Yes")

removeConfirmNoButton = removeConfirmWindow:CreateChildWidget("button", "removeConfirmNoButton", 0, true)
removeConfirmNoButton:SetStyle("text_default")
removeConfirmNoButton:SetAutoResize(false)
removeConfirmNoButton:SetExtent(64, 24)
removeConfirmNoButton:AddAnchor("BOTTOMRIGHT", removeConfirmWindow, -16, -14)
removeConfirmNoButton:SetText("No")

function makeGroupButton:OnClick(arg)
	if arg == "RightButton" then
		return
	end
	MakeGroup()
end
makeGroupButton:SetHandler("OnClick", makeGroupButton.OnClick)

function dailiesButton:OnClick(arg)
	if arg == "RightButton" then
		return
	end
	activeMode = MODE_DAILIES
	RefreshModeButtons()
	RefreshMain()
	if activeQuestWindow:IsVisible() then
		local groups = GetActiveGroups()
		local selectedGroupIndex = GetSelectedGroupIndex()
		if selectedGroupIndex ~= nil and groups[selectedGroupIndex] ~= nil then
			activeQuestTitleLabel:SetText("Dailies -> " .. tostring(groups[selectedGroupIndex].title))
			RefreshActiveQuests()
		else
			activeQuestWindow:Show(false)
		end
	end
end
dailiesButton:SetHandler("OnClick", dailiesButton.OnClick)

function weekliesButton:OnClick(arg)
	if arg == "RightButton" then
		return
	end
	activeMode = MODE_WEEKLIES
	RefreshModeButtons()
	RefreshMain()
	if activeQuestWindow:IsVisible() then
		local groups = GetActiveGroups()
		local selectedGroupIndex = GetSelectedGroupIndex()
		if selectedGroupIndex ~= nil and groups[selectedGroupIndex] ~= nil then
			activeQuestTitleLabel:SetText("Weeklies -> " .. tostring(groups[selectedGroupIndex].title))
			RefreshActiveQuests()
		else
			activeQuestWindow:Show(false)
		end
	end
end
weekliesButton:SetHandler("OnClick", weekliesButton.OnClick)

function popoutButton:OnClick(arg)
	if arg == "RightButton" then
		return
	end
	popoutVisible = not popoutVisible
	popoutWindow:Show(popoutVisible)
	SaveData()
	RefreshPopout()
end
popoutButton:SetHandler("OnClick", popoutButton.OnClick)

function lockPopButton:OnClick(arg)
	if arg == "RightButton" then
		return
	end
	SetPopoutLockState(not popoutLocked)
	SaveData()
end
lockPopButton:SetHandler("OnClick", lockPopButton.OnClick)

function activeQuestCloseButton:OnClick(arg)
	if arg == "RightButton" then
		return
	end
	activeQuestWindow:Show(false)
end
activeQuestCloseButton:SetHandler("OnClick", activeQuestCloseButton.OnClick)

function choreTrackerCloseButton:OnClick(arg)
	if arg == "RightButton" then
		return
	end
	choreTrackerWindow:Show(false)
	activeQuestWindow:Show(false)
	removeConfirmWindow:Show(false)
end
choreTrackerCloseButton:SetHandler("OnClick", choreTrackerCloseButton.OnClick)

function activeQuestIdAddButton:OnClick(arg)
	if arg == "RightButton" then
		return
	end

	local groups = GetActiveGroups()
	local selectedGroupIndex = GetSelectedGroupIndex()
	if selectedGroupIndex == nil or groups[selectedGroupIndex] == nil then
		activeQuestSummaryLabel:SetText("Pick a group first.")
		return
	end

	local raw = tostring(activeQuestIdEdit:GetText() or ""):match("^%s*(.-)%s*$")
	local questId = tonumber(raw)
	if questId == nil then
		activeQuestSummaryLabel:SetText("Enter a numeric quest ID.")
		return
	end

	if IsRaceQuest(questId) then
		activeQuestSummaryLabel:SetText("That quest is race-only.")
		return
	end

	if not IsQuestAllowedForMode(questId) then
		activeQuestSummaryLabel:SetText(
			activeMode == MODE_DAILIES and "ID is not in known dailies." or "ID is not in known weeklies."
		)
		return
	end

	if not IsQuestKnown(questId) then
		activeQuestSummaryLabel:SetText("Unknown quest ID.")
		return
	end

	local list = groups[selectedGroupIndex].quests
	if HasQuestInList(list, questId) then
		activeQuestSummaryLabel:SetText("Already in this group.")
		return
	end

	list[#list + 1] = questId
	SaveData()
	RefreshMain()
	RefreshActiveQuests()
	activeQuestIdEdit:SetText("")
	activeQuestSummaryLabel:SetText("Added quest ID " .. tostring(questId) .. ".")
end
activeQuestIdAddButton:SetHandler("OnClick", activeQuestIdAddButton.OnClick)

function removeConfirmYesButton:OnClick(arg)
	if arg == "RightButton" then
		return
	end
	local action = removeConfirmAction
	removeConfirmAction = nil
	removeConfirmWindow:Show(false)
	if action ~= nil then
		action()
	end
end
removeConfirmYesButton:SetHandler("OnClick", removeConfirmYesButton.OnClick)

function removeConfirmNoButton:OnClick(arg)
	if arg == "RightButton" then
		return
	end
	removeConfirmAction = nil
	removeConfirmWindow:Show(false)
end
removeConfirmNoButton:SetHandler("OnClick", removeConfirmNoButton.OnClick)

function choreTrackerWindow:OnUpdate(dt)
	elapsed = elapsed + dt
	if elapsed < 1000 then
		return
	end
	elapsed = 0
	RefreshMain()
end
choreTrackerWindow:SetHandler("OnUpdate", choreTrackerWindow.OnUpdate)

RefreshPopout = function()
	if popoutWindow == nil then
		return
	end

	popoutButton:SetText(popoutVisible and "Popout [ON]" or "Popout [OFF]")
	SetPopoutLockState(popoutLocked)

	if popoutVisible ~= true then
		popoutWindow:Show(false)
		return
	end

	popoutWindow:Show(true)
	local groups = GROUPS_DAILIES
	local count = #groups
	EnsurePopoutRows(count)

	local y = 10
	for index, group in ipairs(groups) do
		local label = popoutLabels[index]
		local status = GetGroupStatus(group)
		local color = STATUS_COLORS.notStarted
		local prefix = "[ ]"
		if status == "complete" then
			color = STATUS_COLORS.complete
			prefix = "[x]"
		elseif status == "in_progress" then
			color = STATUS_COLORS.inProgress
			prefix = "[~]"
		end

		local completedCount, totalCount = GetGroupCompletionCount(group)
		local open = group.expanded ~= false and "+" or "-"
		label:RemoveAllAnchors()
		label:AddAnchor("TOPLEFT", popoutWindow, 12, y)
		label:SetText(string.format("%s %s (%d/%d) [%s]", prefix, tostring(group.title), completedCount, totalCount, open))
		SetWidgetTextColor(label, color)
		label:Show(true)
		y = y + 24
	end

	for index = count + 1, #popoutLabels do
		popoutLabels[index]:Show(false)
	end

	popoutWindow:SetExtent(280, math.max(36, y + 10))
end

function choreTrackerButton:OnClick()
	choreTrackerWindow:Show(not choreTrackerWindow:IsVisible())
	RefreshMain()
	if choreTrackerWindow:IsVisible() then
		choreTrackerWindow:Raise()
	end
end
choreTrackerButton:SetHandler("OnClick", choreTrackerButton.OnClick)

LoadData()
SetPopoutLockState(popoutLocked)
RefreshMain()
