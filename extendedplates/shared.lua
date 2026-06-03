if TargetDebuffTrackerShared == nil then
	TargetDebuffTrackerShared = {}
end

local shared = TargetDebuffTrackerShared

shared.dataKeys = shared.dataKeys
	or {
		ui = "extendedplates_ui",
		iconSettings = "extendedplates_icon_settings",
		legacyUi = "targetdebufftracker_ui",
		legacyIconSettings = "targetdebufftracker_icon_settings",
	}

shared.effectFiles = shared.effectFiles
	or {
		target = {
			buff = "buff.lua",
			debuff = "debuff.lua",
			hidden = "hidden_buff.lua",
		},
		self = {
			buff = "self_buff.lua",
			debuff = "self_debuff.lua",
			hidden = "self_hidden_buff.lua",
		},
	}

shared.legacyIconSettingFiles = shared.legacyIconSettingFiles
	or {
		target = "buffIconInfo.txt",
		self = "selfabuffIconInfo.txt",
	}

shared.defaultHiddenBuffs = shared.defaultHiddenBuffs
	or {
		["22969"] = { name = "Defiance", iconPath = "" },
		["23214"] = { name = "Defiance", iconPath = "" },
		["27128"] = { name = "Defiance", iconPath = "" },
		["24405"] = { name = "Defiance", iconPath = "" },
		["32871"] = { name = "Defiance", iconPath = "" },
	}

local function copyTable(source)
	local result = {}
	for key, value in pairs(source) do
		result[key] = value
	end
	return result
end

local function trimTrailingComma(value)
	if value == nil then
		return nil
	end

	return value:gsub(",%s*$", "")
end

local function decodeLuaString(value)
	local trimmed = trimTrailingComma(value)
	if trimmed == nil then
		return ""
	end

	local loader = loadstring or load
	if loader == nil then
		return trimmed:gsub('^"', ""):gsub('"$', "")
	end

	local chunk = loader("return " .. trimmed)
	if chunk == nil then
		return trimmed:gsub('^"', ""):gsub('"$', "")
	end

	local success, decoded = pcall(chunk)
	if success then
		return tostring(decoded or "")
	end

	return trimmed:gsub('^"', ""):gsub('"$', "")
end

local function normalizeTrackedEntry(value)
	if type(value) == "table" then
		return {
			name = tostring(value.name or value[1] or ""),
			iconPath = tostring(value.iconPath or value.icon or value.path or ""),
		}
	end

	return {
		name = tostring(value or ""),
		iconPath = "",
	}
end

local function decodeTrackedValue(value)
	local trimmed = trimTrailingComma(value)
	if trimmed == nil then
		return normalizeTrackedEntry("")
	end

	local loader = loadstring or load
	if loader ~= nil then
		local chunk = loader("return " .. trimmed)
		if chunk ~= nil then
			local success, decoded = pcall(chunk)
			if success then
				return normalizeTrackedEntry(decoded)
			end
		end
	end

	return normalizeTrackedEntry(decodeLuaString(trimmed))
end

local function ensureUiState()
	if shared.uiState ~= nil then
		return shared.uiState
	end

	local saved = nil
	if ADDON ~= nil then
		saved = ADDON:LoadData(shared.dataKeys.ui) or ADDON:LoadData(shared.dataKeys.legacyUi)
	end
	shared.uiState = {
		filterTrackedOnly = true,
		activeScope = "target",
		activeEffect = "buff",
		showGear = true,
		showEquipment = true,
		showClass = true,
		showDistance = true,
		showCastbar = true,
		distanceSettings = {
			x = -6,
			y = 20,
			fontSize = 25,
			turnRedAt = 30,
		},
		gearSettings = {
			x = 90,
			y = 0,
		},
		equipmentSettings = {
			x = 0,
			y = 0,
			iconSize = 25,
			layout = "horizontal",
			showMainhand = true,
			showOffhand = true,
			showGlider = true,
			showRanged = true,
		},
		classSettings = {
			iconX = 90,
			iconY = 24,
			labelX = 114,
			labelY = 24,
			showIcon = true,
			showWords = true,
		},
		castbarSettings = {
			x = -60,
			y = 0,
			width = 120,
			height = 18,
		},
		target = {
			buff = true,
			debuff = true,
			hidden = false,
		},
		self = {
			buff = true,
			debuff = true,
			hidden = true,
		},
	}

	if type(saved) == "table" then
		shared.uiState.filterTrackedOnly = saved.filterTrackedOnly ~= false
		if saved.activeScope == "target" or saved.activeScope == "self" then
			shared.uiState.activeScope = saved.activeScope
		end
		if saved.activeEffect == "buff" or saved.activeEffect == "debuff" or saved.activeEffect == "hidden" then
			shared.uiState.activeEffect = saved.activeEffect
		end
		if shared.uiState.activeScope == "target" and shared.uiState.activeEffect == "hidden" then
			shared.uiState.activeEffect = "buff"
		end
		if saved.showGear ~= nil then
			shared.uiState.showGear = saved.showGear == true
		end
		if saved.showEquipment ~= nil then
			shared.uiState.showEquipment = saved.showEquipment == true
		end
		if saved.showClass ~= nil then
			shared.uiState.showClass = saved.showClass == true
		end
		if saved.showDistance ~= nil then
			shared.uiState.showDistance = saved.showDistance == true
		end
		if saved.showCastbar ~= nil then
			shared.uiState.showCastbar = saved.showCastbar == true
		end
		if type(saved.distanceSettings) == "table" then
			shared.uiState.distanceSettings.x = tonumber(saved.distanceSettings.x) or shared.uiState.distanceSettings.x
			shared.uiState.distanceSettings.y = tonumber(saved.distanceSettings.y) or shared.uiState.distanceSettings.y
			shared.uiState.distanceSettings.fontSize =
				tonumber(saved.distanceSettings.fontSize) or shared.uiState.distanceSettings.fontSize
			shared.uiState.distanceSettings.turnRedAt =
				tonumber(saved.distanceSettings.turnRedAt) or shared.uiState.distanceSettings.turnRedAt
		end
		if type(saved.gearSettings) == "table" then
			shared.uiState.gearSettings.x = tonumber(saved.gearSettings.x) or shared.uiState.gearSettings.x
			shared.uiState.gearSettings.y = tonumber(saved.gearSettings.y) or shared.uiState.gearSettings.y
		end
		if type(saved.equipmentSettings) == "table" then
			shared.uiState.equipmentSettings.x =
				tonumber(saved.equipmentSettings.x) or shared.uiState.equipmentSettings.x
			shared.uiState.equipmentSettings.y =
				tonumber(saved.equipmentSettings.y) or shared.uiState.equipmentSettings.y
			shared.uiState.equipmentSettings.iconSize =
				tonumber(saved.equipmentSettings.iconSize) or shared.uiState.equipmentSettings.iconSize
			if saved.equipmentSettings.layout == "vertical" or saved.equipmentSettings.layout == "horizontal" then
				shared.uiState.equipmentSettings.layout = saved.equipmentSettings.layout
			end
			if saved.equipmentSettings.showMainhand ~= nil then
				shared.uiState.equipmentSettings.showMainhand = saved.equipmentSettings.showMainhand == true
			end
			if saved.equipmentSettings.showOffhand ~= nil then
				shared.uiState.equipmentSettings.showOffhand = saved.equipmentSettings.showOffhand == true
			end
			if saved.equipmentSettings.showGlider ~= nil then
				shared.uiState.equipmentSettings.showGlider = saved.equipmentSettings.showGlider == true
			end
			if saved.equipmentSettings.showRanged ~= nil then
				shared.uiState.equipmentSettings.showRanged = saved.equipmentSettings.showRanged == true
			end
		end
		if type(saved.classSettings) == "table" then
			shared.uiState.classSettings.iconX = tonumber(saved.classSettings.iconX) or shared.uiState.classSettings.iconX
			shared.uiState.classSettings.iconY = tonumber(saved.classSettings.iconY) or shared.uiState.classSettings.iconY
			shared.uiState.classSettings.labelX =
				tonumber(saved.classSettings.labelX) or shared.uiState.classSettings.labelX
			shared.uiState.classSettings.labelY =
				tonumber(saved.classSettings.labelY) or shared.uiState.classSettings.labelY
			if saved.classSettings.showIcon ~= nil then
				shared.uiState.classSettings.showIcon = saved.classSettings.showIcon == true
			end
			if saved.classSettings.showWords ~= nil then
				shared.uiState.classSettings.showWords = saved.classSettings.showWords == true
			end
		end
		if type(saved.castbarSettings) == "table" then
			shared.uiState.castbarSettings.x = tonumber(saved.castbarSettings.x) or shared.uiState.castbarSettings.x
			shared.uiState.castbarSettings.y = tonumber(saved.castbarSettings.y) or shared.uiState.castbarSettings.y
			shared.uiState.castbarSettings.width =
				tonumber(saved.castbarSettings.width) or shared.uiState.castbarSettings.width
			shared.uiState.castbarSettings.height =
				tonumber(saved.castbarSettings.height) or shared.uiState.castbarSettings.height
		end

		for _, scope in ipairs({ "target", "self" }) do
			if type(saved[scope]) == "table" then
				for _, effectType in ipairs({ "buff", "debuff", "hidden" }) do
					if saved[scope][effectType] ~= nil then
						shared.uiState[scope][effectType] = saved[scope][effectType] == true
					end
				end
			end
		end
		shared.uiState.target.hidden = false
	end

	return shared.uiState
end

function shared.SaveUiState()
	local uiState = ensureUiState()
	if ADDON ~= nil then
		ADDON:ClearData(shared.dataKeys.ui)
		ADDON:SaveData(shared.dataKeys.ui, uiState)
	end
end

function shared.GetUiState()
	return ensureUiState()
end

function shared.GetDistanceSettings()
	return ensureUiState().distanceSettings
end

function shared.AdjustDistanceSettings(axis, delta)
	local settings = shared.GetDistanceSettings()
	if axis == "x" then
		settings.x = settings.x + delta
	elseif axis == "y" then
		settings.y = settings.y + delta
	elseif axis == "fontSize" then
		settings.fontSize = math.max(8, settings.fontSize + delta)
	elseif axis == "turnRedAt" then
		settings.turnRedAt = math.max(0, settings.turnRedAt + delta)
	end
	shared.SaveUiState()
	return settings
end

function shared.GetGearSettings()
	return ensureUiState().gearSettings
end

function shared.AdjustGearSettings(axis, delta)
	local settings = shared.GetGearSettings()
	if axis == "x" then
		settings.x = settings.x + delta
	elseif axis == "y" then
		settings.y = settings.y + delta
	end
	shared.SaveUiState()
	return settings
end

function shared.GetEquipmentSettings()
	return ensureUiState().equipmentSettings
end

function shared.AdjustEquipmentSettings(axis, delta)
	local settings = shared.GetEquipmentSettings()
	if axis == "x" then
		settings.x = settings.x + delta
	elseif axis == "y" then
		settings.y = settings.y + delta
	elseif axis == "size" then
		settings.iconSize = math.max(12, settings.iconSize + delta)
	end
	shared.SaveUiState()
	return settings
end

function shared.ToggleEquipmentLayout()
	local settings = shared.GetEquipmentSettings()
	if settings.layout == "vertical" then
		settings.layout = "horizontal"
	else
		settings.layout = "vertical"
	end
	shared.SaveUiState()
	return settings
end

function shared.ToggleEquipmentSetting(flagName)
	local settings = shared.GetEquipmentSettings()
	if
		flagName == "showMainhand"
		or flagName == "showOffhand"
		or flagName == "showGlider"
		or flagName == "showRanged"
	then
		settings[flagName] = not settings[flagName]
		shared.SaveUiState()
	end
	return settings
end

function shared.GetClassSettings()
	return ensureUiState().classSettings
end

function shared.AdjustClassSettings(target, axis, delta)
	local settings = shared.GetClassSettings()
	if target == "icon" then
		if axis == "x" then
			settings.iconX = settings.iconX + delta
		elseif axis == "y" then
			settings.iconY = settings.iconY + delta
		end
	elseif target == "label" then
		if axis == "x" then
			settings.labelX = settings.labelX + delta
		elseif axis == "y" then
			settings.labelY = settings.labelY + delta
		end
	end
	shared.SaveUiState()
	return settings
end

function shared.ToggleClassSetting(flagName)
	local settings = shared.GetClassSettings()
	if flagName == "showIcon" or flagName == "showWords" then
		settings[flagName] = not settings[flagName]
		shared.SaveUiState()
	end
	return settings
end

function shared.GetCastbarSettings()
	return ensureUiState().castbarSettings
end

function shared.AdjustCastbarSettings(axis, delta)
	local settings = shared.GetCastbarSettings()
	if axis == "x" then
		settings.x = settings.x + delta
	elseif axis == "y" then
		settings.y = settings.y + delta
	elseif axis == "width" then
		settings.width = math.max(40, settings.width + delta)
	elseif axis == "height" then
		settings.height = math.max(8, settings.height + delta)
	end
	shared.SaveUiState()
	return settings
end

function shared.SetCastbarSettings(width, height)
	local settings = shared.GetCastbarSettings()
	if tonumber(width) ~= nil then
		settings.width = math.max(40, math.floor(tonumber(width) + 0.5))
	end
	if tonumber(height) ~= nil then
		settings.height = math.max(8, math.floor(tonumber(height) + 0.5))
	end
	shared.SaveUiState()
	return settings
end

local function normalizeIconSettingEntry(value, defaults)
	local growth = "horizontal_right"
	if type(value) == "table" then
		if
			value.growth == "horizontal_right"
			or value.growth == "horizontal_left"
			or value.growth == "vertical_up"
			or value.growth == "vertical_down"
		then
			growth = value.growth
		end
	end

	if type(value) ~= "table" then
		return {
			iconSize = defaults.iconSize,
			x = defaults.x,
			y = defaults.y,
			growth = growth,
		}
	end

	return {
		iconSize = tonumber(value.iconSize) or tonumber(value.size) or defaults.iconSize,
		x = tonumber(value.x) or defaults.x,
		y = tonumber(value.y) or defaults.y,
		growth = growth,
	}
end

local function loadLegacyScopeSettings(scope)
	local defaults = {
		buff = { iconSize = 25, x = 0, y = 0, growth = "horizontal_right" },
		debuff = { iconSize = 25, x = 0, y = 35, growth = "horizontal_right" },
		hidden = { iconSize = 25, x = 0, y = 0, growth = "horizontal_right" },
	}

	local filename = shared.legacyIconSettingFiles[scope]
	local file = filename and io.open(filename, "r") or nil
	if file == nil then
		return defaults
	end

	local line = file:read("*line")
	file:close()

	local iconSize
	local buffsX
	local buffsY
	local debuffsX
	local debuffsY
	if line ~= nil then
		iconSize, buffsX, buffsY, debuffsX, debuffsY =
			line:match("(%-?%d+),(%-?%d+),(%-?%d+),(%-?%d+),(%-?%d+)")
	end

	if iconSize == nil then
		return defaults
	end

	defaults.buff = {
		iconSize = tonumber(iconSize) or 25,
		x = tonumber(buffsX) or 0,
		y = tonumber(buffsY) or 0,
		growth = "horizontal_right",
	}
	defaults.debuff = {
		iconSize = tonumber(iconSize) or 25,
		x = tonumber(debuffsX) or 0,
		y = tonumber(debuffsY) or 35,
		growth = "horizontal_right",
	}

	return defaults
end

local function ensureIconSettings()
	if shared.iconSettings == nil then
		local saved = nil
		if ADDON ~= nil then
			saved = ADDON:LoadData(shared.dataKeys.iconSettings) or ADDON:LoadData(shared.dataKeys.legacyIconSettings)
		end
		local legacyTarget = loadLegacyScopeSettings("target")
		local legacySelf = loadLegacyScopeSettings("self")

		shared.iconSettings = {
			target = {
				buff = normalizeIconSettingEntry(saved and saved.target and saved.target.buff, legacyTarget.buff),
				debuff = normalizeIconSettingEntry(saved and saved.target and saved.target.debuff, legacyTarget.debuff),
				hidden = normalizeIconSettingEntry(saved and saved.target and saved.target.hidden, legacyTarget.hidden),
			},
			self = {
				buff = normalizeIconSettingEntry(saved and saved.self and saved.self.buff, legacySelf.buff),
				debuff = normalizeIconSettingEntry(saved and saved.self and saved.self.debuff, legacySelf.debuff),
				hidden = normalizeIconSettingEntry(saved and saved.self and saved.self.hidden, legacySelf.hidden),
			},
		}
	end

	return shared.iconSettings
end

function shared.SaveIconSettings()
	local settings = ensureIconSettings()
	if ADDON ~= nil then
		ADDON:ClearData(shared.dataKeys.iconSettings)
		ADDON:SaveData(shared.dataKeys.iconSettings, settings)
	end
end

function shared.GetIconSettings(scope, effectType)
	local settings = ensureIconSettings()
	if effectType == nil then
		return settings[scope]
	end

	if settings[scope] == nil then
		return { iconSize = 25, x = 0, y = 0, growth = "horizontal_right" }
	end

	if settings[scope][effectType] == nil then
		settings[scope][effectType] = { iconSize = 25, x = 0, y = 0, growth = "horizontal_right" }
	end

	if
		settings[scope][effectType].growth ~= "horizontal_right"
		and settings[scope][effectType].growth ~= "horizontal_left"
		and settings[scope][effectType].growth ~= "vertical_up"
		and settings[scope][effectType].growth ~= "vertical_down"
	then
		settings[scope][effectType].growth = "horizontal_right"
	end

	return settings[scope][effectType]
end

function shared.GetIconOffsetForIndex(settings, index)
	local iconSize = tonumber(settings and settings.iconSize) or 25
	local spacing = iconSize + 5
	local baseX = tonumber(settings and settings.x) or 0
	local baseY = tonumber(settings and settings.y) or 0
	local growth = settings and settings.growth or "horizontal_right"

	if growth == "horizontal_left" then
		return baseX - (spacing * index), baseY
	end
	if growth == "vertical_up" then
		return baseX, baseY - (spacing * index)
	end
	if growth == "vertical_down" then
		return baseX, baseY + (spacing * index)
	end

	return baseX + (spacing * index), baseY
end

function shared.CycleIconGrowth(scope, effectType)
	local setting = shared.GetIconSettings(scope, effectType)
	if setting.growth == "horizontal_right" then
		setting.growth = "horizontal_left"
	elseif setting.growth == "horizontal_left" then
		setting.growth = "vertical_up"
	elseif setting.growth == "vertical_up" then
		setting.growth = "vertical_down"
	else
		setting.growth = "horizontal_right"
	end
	shared.SaveIconSettings()
	return setting
end

function shared.AdjustIconSettings(scope, effectType, axis, delta)
	local setting = shared.GetIconSettings(scope, effectType)
	if axis == "x" then
		setting.x = setting.x + delta
	elseif axis == "y" then
		setting.y = setting.y + delta
	elseif axis == "size" then
		setting.iconSize = math.max(10, setting.iconSize + delta)
	end
	shared.SaveIconSettings()
	return setting
end

local function loadTrackedTable(scope, effectType)
	if shared.tracked == nil then
		shared.tracked = {}
	end

	shared.tracked[scope] = shared.tracked[scope] or {}
	if shared.tracked[scope][effectType] ~= nil then
		return shared.tracked[scope][effectType]
	end

	local filename = shared.effectFiles[scope][effectType]
	local tracked = {}
	local file = io.open(filename, "r")
	if file ~= nil then
		for line in file:lines() do
			local id, encodedValue = line:match('%["(%d+)"%]%s*=%s*(.+)')
			if id ~= nil and encodedValue ~= nil then
				tracked[id] = decodeTrackedValue(encodedValue)
			end
		end
		file:close()
	elseif effectType == "hidden" then
		tracked = copyTable(shared.defaultHiddenBuffs)
	end

	shared.tracked[scope][effectType] = tracked
	return tracked
end

function shared.GetTracked(scope, effectType)
	return loadTrackedTable(scope, effectType)
end

function shared.SaveTracked(scope, effectType)
	local tracked = loadTrackedTable(scope, effectType)
	local filename = shared.effectFiles[scope][effectType]
	local file = io.open(filename, "w")
	if file == nil then
		X2Chat:DispatchChatMessage(CMF_SYSTEM, "Failed to save " .. filename)
		return false
	end

	file:write("target_" .. effectType .. " = {\n")
	for id, entry in pairs(tracked) do
		local normalized = normalizeTrackedEntry(entry)
		file:write(
			string.format(
				'    ["%s"] = { name = %q, iconPath = %q },\n',
				tostring(id),
				normalized.name,
				normalized.iconPath
			)
		)
	end
	file:write("}\n")
	file:close()
	return true
end

function shared.AddTracked(scope, effectType, effectId, name, iconPath)
	local tracked = loadTrackedTable(scope, effectType)
	tracked[tostring(effectId)] = {
		name = tostring(name or ""),
		iconPath = tostring(iconPath or ""),
	}
	return shared.SaveTracked(scope, effectType)
end

function shared.RemoveTracked(scope, effectType, effectId)
	local tracked = loadTrackedTable(scope, effectType)
	tracked[tostring(effectId)] = nil
	return shared.SaveTracked(scope, effectType)
end

function shared.IsTracked(scope, effectType, effectId)
	local tracked = loadTrackedTable(scope, effectType)
	return tracked[tostring(effectId)] ~= nil
end

function shared.ShouldDisplay(scope, effectType, effectId)
	local uiState = ensureUiState()
	if uiState[scope] == nil or uiState[scope][effectType] ~= true then
		return false
	end

	if uiState.filterTrackedOnly ~= true then
		return true
	end

	return shared.IsTracked(scope, effectType, effectId)
end

function shared.FormatDuration(seconds)
	if seconds == nil or seconds == "" then
		return ""
	end

	local numeric = tonumber(seconds)
	if numeric == nil then
		return tostring(seconds)
	end

	if numeric < 0 then
		return ""
	end

	if numeric < 60 then
		return tostring(math.floor(numeric))
	end

	if numeric < 3600 then
		return string.format("%dm", math.floor(numeric / 60))
	end

	if numeric < 86400 then
		return string.format("%dh", math.floor(numeric / 3600))
	end

	return string.format("%dd", math.floor(numeric / 86400))
end

function shared.FormatStackCount(stacks)
	if stacks == nil or stacks == "" then
		return ""
	end

	local numeric = tonumber(stacks)
	if numeric == nil then
		return tostring(stacks)
	end

	if numeric <= 1 then
		return ""
	end

	if numeric >= 1000 then
		return string.format("%dk", math.floor(numeric / 1000))
	end

	if numeric >= 100 then
		return string.format("%.1fk", math.floor(numeric / 100) / 10)
	end

	return tostring(math.floor(numeric))
end

function shared.GetSortedTrackedEntries(scope, effectType)
	local tracked = loadTrackedTable(scope, effectType)
	local entries = {}
	for id, entry in pairs(tracked) do
		local normalized = normalizeTrackedEntry(entry)
		table.insert(entries, {
			id = tostring(id),
			name = normalized.name,
			iconPath = normalized.iconPath,
		})
	end

	table.sort(entries, function(left, right)
		local leftName = string.lower(left.name ~= "" and left.name or left.id)
		local rightName = string.lower(right.name ~= "" and right.name or right.id)
		if leftName == rightName then
			return tonumber(left.id) < tonumber(right.id)
		end

		return leftName < rightName
	end)

	return entries
end
