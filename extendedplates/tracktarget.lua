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
ADDON:ImportObject(OBJECT_TYPE.EDITBOX)
ADDON:ImportObject(OBJECT_TYPE.EDITBOX_MULTILINE)
ADDON:ImportObject(OBJECT_TYPE.X2_EDITBOX)

ADDON:ImportAPI(API_TYPE.OPTION.id)
ADDON:ImportAPI(API_TYPE.CHAT.id)
ADDON:ImportAPI(API_TYPE.ACHIEVEMENT.id)
ADDON:ImportAPI(API_TYPE.UNIT.id)
ADDON:ImportAPI(API_TYPE.LOCALE.id)
ADDON:ImportAPI(API_TYPE.EQUIPMENT.id)

local shared = TargetDebuffTrackerShared
local AA_DEBUG = false
local SIMPLE_BUTTON_WIDTH = 80
local SIMPLE_BUTTON_HEIGHT = 25
local SECONDARY_BUTTON_WIDTH = 45
local LEFT_BUTTON_X = 20
local SECONDARY_BUTTON_X = 160
local LEFT_BUTTON_START_Y = 88
local LEFT_BUTTON_ROW_SPACING = 33
local LEFT_BUTTON_GROUP_GAP = 10

local function LeftButtonY(index)
	return LEFT_BUTTON_START_Y + ((index - 1) * LEFT_BUTTON_ROW_SPACING)
end

local function LowerLeftButtonY(index)
	return LeftButtonY(index) + LEFT_BUTTON_GROUP_GAP
end

local function DebugPrint(message)
	if AA_DEBUG ~= true then
		return
	end

	local text = "[BuffTracker] " .. tostring(message)
	if aaprint ~= nil then
		aaprint(text)
	else
		X2Chat:DispatchChatMessage(CMF_SYSTEM, text)
	end
end

local function CreateLauncherButtonSafe(text, x, y)
	if CreateSimpleButton ~= nil then
		return CreateSimpleButton(text, x, y)
	end

	DebugPrint("CreateSimpleButton missing; using fallback button")
	local button = UIParent:CreateWidget("button", "targetDebuffTrackerFallbackButton", "UIParent", "")
	button:SetText(text)
	button:SetStyle("text_default")
	button:SetHeight(25)
	button:SetWidth(100)
	button:AddAnchor("BOTTOM", "UIParent", x, y)
	button:Show(true)
	return button
end

local function ApplyLocalButtonStyle(button)
	if button == nil then
		return
	end

	if button.SetStyle ~= nil then
		button:SetStyle("text_default")
	end

	if button.style ~= nil and button.style.SetAlign ~= nil then
		button.style:SetAlign(ALIGN_CENTER)
	end

	if button.SetInset ~= nil then
		button:SetInset(8, 0, 8, 0)
	end
end

local function CreateWindowBackground(window)
	local bg = window:CreateDrawable("ui/common/default.dds", "main_bg", "background")
	bg:AddAnchor("TOPLEFT", window, -5, -5)
	bg:AddAnchor("BOTTOMRIGHT", window, 5, 5)
	return bg
end

local function CreateCloseButton(parent, id, onClick)
	local button = parent:CreateChildWidget("button", id, 0, true)
	button:AddAnchor("TOPRIGHT", parent, 3, -3)
	button:SetStyle("btn_close_default")
	button:SetHandler("OnClick", onClick)
	return button
end

local function SetSecondaryButtonExtent(button)
	button:SetExtent(SECONDARY_BUTTON_WIDTH, SIMPLE_BUTTON_HEIGHT)
	button:SetWidth(SECONDARY_BUTTON_WIDTH)
end

local function ApplyLocalLabelStyle(widget, fontSize, align, red, green, blue)
	if widget == nil or widget.style == nil then
		return
	end

	if widget.style.SetFontSize ~= nil then
		widget.style:SetFontSize(fontSize)
	end

	if widget.style.SetAlign ~= nil then
		widget.style:SetAlign(align or ALIGN_LEFT)
	end
	if widget.style.SetColor ~= nil then
		widget.style:SetColor(red or 1, green or 1, blue or 1, 1)
	end
end

local function SetWidgetTextColorByKey(widget, colorKey)
	if widget == nil or colorKey == nil or widget.style == nil or widget.style.SetColorByKey == nil then
		return
	end

	widget.style:SetColorByKey(colorKey)
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

local function CreateLocalMultiLineEdit(parent, id, width, height)
	local edit = parent:CreateChildWidgetByType(UOT_EDITBOX_MULTILINE, id, 0, true)
	edit:SetInset(10, 10, 15, 0)
	edit:SetWidth(width)
	edit:SetHeight(height)
	edit:EnableFocus(true)
	edit:SetMaxTextLength(65535)
	edit.style:SetAlign(ALIGN_TOP_LEFT)
	edit.guideTextStyle:SetAlign(ALIGN_TOP_LEFT)
	local bg = edit:CreateDrawable("ui/common/default.dds", "editbox_df", "background")
	bg:AddAnchor("TOPLEFT", edit, 0, 0)
	bg:AddAnchor("BOTTOMRIGHT", edit, 0, 0)
	edit.bg = bg
	return edit
end

local function SetRowIcon(iconWidget, iconPath)
	if iconWidget == nil then
		return
	end

	iconWidget:ClearAllTextures()
	if iconPath == nil or iconPath == "" then
		iconWidget:SetVisible(false)
		return
	end

	iconWidget:AddTexture(iconPath)
	iconWidget:SetVisible(true)
end

local function GetPreviewIconPath(effectType)
	if effectType == "debuff" then
		return "Game/ui/icon/icon_item_0060.dds"
	elseif effectType == "hidden" then
		return "Game/ui/icon/icon_skill_buff381.dds"
	end
	return "Game/ui/icon/icon_skill_buff26.dds"
end

local function GetPreviewLayout(effectType)
	if effectType == "hidden" then
		return {
			originX = 98,
			originY = 54,
			nameplateX = -78,
			nameplateY = 10,
			nameplateWidth = 80,
			nameplateHeight = 30,
		}
	end

	return {
		originX = 34,
		originY = 30,
		nameplateX = 14,
		nameplateY = 10,
		nameplateWidth = 80,
		nameplateHeight = 30,
	}
end

local drawLinesEnabled = false
local drawLinesSettingsWindow = nil
local drawLinesButton = nil
local drawLinesSettingsButton = nil
local drawLinesPairButtons = {}
local targetLineModeButton = nil
local trackLineModeButton = nil
local drawLinesMinLabel = nil
local drawLinesMaxLabel = nil
local drawLinesDotSizeLabel = nil
local drawLinesDotAlphaLabel = nil
local drawLinesMinDotCount = 8
local drawLinesMaxDotCount = 64
local drawLinesDotFontSize = 15
local drawLinesDotAlpha = 1.0
local targetToTargetLineFromPlayer = false
local watchToTargetLineFromPlayer = true
local showTracktargetAggro = false
local lockTracktargetAggro = false
local tracktargetAggroWindow = nil
local tracktargetAggroLabel = nil
local tracktargetAggroBackground = nil
local showTracktargetDistance = false
local lockTracktargetDistance = false
local tracktargetDistanceWindow = nil
local tracktargetDistanceLabel = nil
local tracktargetDistanceBackground = nil
local drawLinesPairs = {
	target = false,
	targetoftarget = false,
	watchtarget = false,
	watchtargettarget = false,
}

local drawLinesDotSets = {}
local drawLinesPairOrder = { "target", "targetoftarget", "watchtarget", "watchtargettarget" }
local drawLinesDebug = false
local drawLinesDebugElapsed = 0
local drawLinesDebugIntervalMs = 1000
local drawLinesPairMeta = {
	target = { fromUnit = "player", toUnit = "target", color = { 0.25, 1.0, 0.25 } },
	targetoftarget = { fromUnit = "target", toUnit = "targettarget", color = { 1.0, 0.25, 0.25 } },
	watchtarget = { fromUnit = "player", toUnit = "watchtarget", color = { 0.25, 0.8, 1.0 } },
	watchtargettarget = { fromUnit = "player", toUnit = "watchtargettarget", color = { 1.0, 0.85, 0.25 } },
}

local function SaveDrawLinesSettings()
	ADDON:ClearData("extendedplates_drawlines")
	ADDON:SaveData("extendedplates_drawlines", {
		enabled = drawLinesEnabled,
		minDots = drawLinesMinDotCount,
		maxDots = drawLinesMaxDotCount,
		dotFontSize = drawLinesDotFontSize,
		dotAlpha = drawLinesDotAlpha,
		targetToTargetLineFromPlayer = targetToTargetLineFromPlayer,
		watchToTargetLineFromPlayer = watchToTargetLineFromPlayer,
		showTracktargetAggro = showTracktargetAggro,
		lockTracktargetAggro = lockTracktargetAggro,
		showTracktargetDistance = showTracktargetDistance,
		lockTracktargetDistance = lockTracktargetDistance,
		pairs = drawLinesPairs,
	})
end

local function LoadDrawLinesSettings()
	local stored = ADDON:LoadData("extendedplates_drawlines")
	if stored == nil then
		return
	end
	if stored.enabled ~= nil then
		drawLinesEnabled = stored.enabled and true or false
	end
	if tonumber(stored.minDots) ~= nil then
		drawLinesMinDotCount = math.max(1, math.floor(tonumber(stored.minDots)))
	end
	if tonumber(stored.maxDots) ~= nil then
		drawLinesMaxDotCount = math.max(drawLinesMinDotCount, math.floor(tonumber(stored.maxDots)))
	end
	if tonumber(stored.dotFontSize) ~= nil then
		drawLinesDotFontSize = math.max(8, math.floor(tonumber(stored.dotFontSize)))
	end
	if tonumber(stored.dotAlpha) ~= nil then
		local alpha = tonumber(stored.dotAlpha)
		if alpha < 0.1 then
			alpha = 0.1
		elseif alpha > 1.0 then
			alpha = 1.0
		end
		drawLinesDotAlpha = alpha
	end
	if stored.targetToTargetLineFromPlayer ~= nil then
		targetToTargetLineFromPlayer = stored.targetToTargetLineFromPlayer and true or false
	end
	if stored.watchToTargetLineFromPlayer ~= nil then
		watchToTargetLineFromPlayer = stored.watchToTargetLineFromPlayer and true or false
	end
	if stored.showTracktargetAggro ~= nil then
		showTracktargetAggro = stored.showTracktargetAggro and true or false
	end
	if stored.lockTracktargetAggro ~= nil then
		lockTracktargetAggro = stored.lockTracktargetAggro and true or false
	end
	if stored.showTracktargetDistance ~= nil then
		showTracktargetDistance = stored.showTracktargetDistance and true or false
	end
	if stored.lockTracktargetDistance ~= nil then
		lockTracktargetDistance = stored.lockTracktargetDistance and true or false
	end
	if type(stored.pairs) == "table" then
		for _, key in ipairs(drawLinesPairOrder) do
			if stored.pairs[key] ~= nil then
				drawLinesPairs[key] = stored.pairs[key] and true or false
			end
		end
	end
end

local function DrawLinesButtonText()
	return "Draw Lines [" .. (drawLinesEnabled and "ON" or "OFF") .. "]"
end

local function TracktargetAggroButtonText()
	return "Show Tracktarget Aggro [" .. (showTracktargetAggro and "ON" or "OFF") .. "]"
end

local function TracktargetDistanceButtonText()
	return "Show Distance to Tracktarget [" .. (showTracktargetDistance and "ON" or "OFF") .. "]"
end

local function DrawPairButtonText(key)
	local label = key
	if key == "targetoftarget" then
		label = "targetoftarget"
	end
	return label .. " [" .. (drawLinesPairs[key] and "ON" or "OFF") .. "]"
end

local function DrawLinesHideDots(dotSet)
	for i = 1, #dotSet do
		dotSet[i].container:Show(false)
	end
end

local function DrawLinesProjectWorldToScreen(x, y, z)
	if ConvertWorldToScreen ~= nil then
		local sx, sy, sz = ConvertWorldToScreen(x, y, z)
		if sx ~= nil and sy ~= nil and sz ~= nil then
			return sx, sy, sz
		end
	end
	if WorldToScreen ~= nil then
		return WorldToScreen(x, y, z)
	end
	return nil, nil, nil
end

local function SaveTracktargetAggroWindowPos(x, y)
	ADDON:ClearData("extendedplates_tracktarget_aggro_pos")
	ADDON:SaveData("extendedplates_tracktarget_aggro_pos", { x = x, y = y })
end

local function LoadTracktargetAggroWindowPos()
	local pos = ADDON:LoadData("extendedplates_tracktarget_aggro_pos")
	if pos ~= nil then
		return tonumber(pos.x) or 0, tonumber(pos.y) or 0
	end
	return 0, 0
end

local function SaveTracktargetDistanceWindowPos(x, y)
	ADDON:ClearData("extendedplates_tracktarget_distance_pos")
	ADDON:SaveData("extendedplates_tracktarget_distance_pos", { x = x, y = y })
end

local function LoadTracktargetDistanceWindowPos()
	local pos = ADDON:LoadData("extendedplates_tracktarget_distance_pos")
	if pos ~= nil then
		return tonumber(pos.x) or 0, tonumber(pos.y) or 0
	end
	return 0, 0
end

local function ApplyTracktargetAggroLockState()
	if tracktargetAggroWindow == nil then
		return
	end
	if lockTracktargetAggro then
		tracktargetAggroWindow:EnableDrag(false)
		if tracktargetAggroWindow.EnablePick ~= nil then
			tracktargetAggroWindow:EnablePick(false)
		end
	else
		tracktargetAggroWindow:EnableDrag(true)
		if tracktargetAggroWindow.EnablePick ~= nil then
			tracktargetAggroWindow:EnablePick(true)
		end
	end
	if tracktargetAggroBackground ~= nil and tracktargetAggroBackground.SetColor ~= nil then
		if lockTracktargetAggro then
			tracktargetAggroBackground:SetColor(0.12, 0.12, 0.12, 0.0)
		else
			tracktargetAggroBackground:SetColor(0.12, 0.12, 0.12, 0.60)
		end
	end
	if tracktargetAggroLabel ~= nil and tracktargetAggroLabel.EnablePick ~= nil then
		tracktargetAggroLabel:EnablePick(false)
	end
end

local function ApplyTracktargetDistanceLockState()
	if tracktargetDistanceWindow == nil then
		return
	end
	if lockTracktargetDistance then
		tracktargetDistanceWindow:EnableDrag(false)
		if tracktargetDistanceWindow.EnablePick ~= nil then
			tracktargetDistanceWindow:EnablePick(false)
		end
	else
		tracktargetDistanceWindow:EnableDrag(true)
		if tracktargetDistanceWindow.EnablePick ~= nil then
			tracktargetDistanceWindow:EnablePick(true)
		end
	end
	if tracktargetDistanceBackground ~= nil and tracktargetDistanceBackground.SetColor ~= nil then
		if lockTracktargetDistance then
			tracktargetDistanceBackground:SetColor(0.12, 0.12, 0.12, 0.0)
		else
			tracktargetDistanceBackground:SetColor(0.12, 0.12, 0.12, 0.60)
		end
	end
	if tracktargetDistanceLabel ~= nil and tracktargetDistanceLabel.EnablePick ~= nil then
		tracktargetDistanceLabel:EnablePick(false)
	end
end

local function DrawLinesEnsureDots()
	for _, pairKey in ipairs(drawLinesPairOrder) do
		local pair = drawLinesPairMeta[pairKey]
		if drawLinesDotSets[pairKey] == nil then
			drawLinesDotSets[pairKey] = {}
		end
		local dotSet = drawLinesDotSets[pairKey]
		for i = 1, drawLinesMaxDotCount do
			if dotSet[i] == nil then
				local container = CreateEmptyWindow("extendedPlatesLineDot_" .. pairKey .. "_" .. i, "UIParent")
				container:Show(false)
				container:AddAnchor("TOPLEFT", "UIParent", 0, 0)
				local label = container:CreateChildWidget("label", "dotLabel", 0, true)
				label:SetText(".")
				label:SetExtent(18, 18)
				label.style:SetFontSize(drawLinesDotFontSize)
				label.style:SetColor(pair.color[1], pair.color[2], pair.color[3], drawLinesDotAlpha)
				label.style:SetOutline(true)
				label.style:SetAlign(ALIGN_CENTER)
				label:AddAnchor("CENTER", container, 0, 0)
				label:EnablePick(false)
				dotSet[i] = { container = container, label = label }
			end
		end
	end
end

local function DrawLinesRenderPair(pairKey)
	local pair = drawLinesPairMeta[pairKey]
	local dotSet = drawLinesDotSets[pairKey]
	if pair == nil or dotSet == nil then
		return 0
	end
	local fromUnit = pair.fromUnit
	local toUnit = pair.toUnit
	if pairKey == "targetoftarget" then
		if targetToTargetLineFromPlayer then
			fromUnit = "player"
		else
			fromUnit = "target"
		end
	elseif pairKey == "watchtargettarget" then
		if watchToTargetLineFromPlayer then
			fromUnit = "player"
		else
			fromUnit = "watchtarget"
		end
	end
	if drawLinesPairs[pairKey] ~= true then
		DrawLinesHideDots(dotSet)
		return 0
	end

	local x1, y1, z1 = X2Unit:GetUnitWorldPositionByTarget(fromUnit, false)
	local x2, y2, z2 = X2Unit:GetUnitWorldPositionByTarget(toUnit, false)
	if x1 == nil or y1 == nil or z1 == nil or x2 == nil or y2 == nil or z2 == nil then
		if drawLinesDebug and drawLinesDebugElapsed >= drawLinesDebugIntervalMs then
			X2Chat:DispatchChatMessage(
				CMF_SYSTEM,
				string.format(
					"[ExtPlates DrawLines DEBUG] %s worldpos missing | %s=(%s,%s,%s) %s=(%s,%s,%s)",
					pairKey,
					fromUnit,
					tostring(x1),
					tostring(y1),
					tostring(z1),
					toUnit,
					tostring(x2),
					tostring(y2),
					tostring(z2)
				)
			)
		end
		DrawLinesHideDots(dotSet)
		return 0
	end

	-- Preferred endpoint projection: unit API screen coordinates.
	local sx1, sy1, d1 = X2Unit:GetUnitScreenPosition(fromUnit)
	local sx2, sy2, d2 = X2Unit:GetUnitScreenPosition(toUnit)
	if sx1 == nil or sy1 == nil or sx2 == nil or sy2 == nil then
		-- Fallback to world projection if screen-position API has no coords.
		sx1, sy1, d1 = DrawLinesProjectWorldToScreen(x1, y1, z1 + 1.0)
		sx2, sy2, d2 = DrawLinesProjectWorldToScreen(x2, y2, z2 + 1.0)
	end
	if sx1 == nil or sy1 == nil or d1 == nil or sx2 == nil or sy2 == nil or d2 == nil or d1 <= 0 or d2 <= 0 then
		if drawLinesDebug and drawLinesDebugElapsed >= drawLinesDebugIntervalMs then
			X2Chat:DispatchChatMessage(
				CMF_SYSTEM,
				string.format(
					"[ExtPlates DrawLines DEBUG] %s endpoint projection blocked | a=(%s,%s,%s) b=(%s,%s,%s)",
					pairKey,
					tostring(sx1),
					tostring(sy1),
					tostring(d1),
					tostring(sx2),
					tostring(sy2),
					tostring(d2)
				)
			)
		end
		DrawLinesHideDots(dotSet)
		return 0
	end

	local dx = sx2 - sx1
	local dy = sy2 - sy1
	local screenDistance = math.sqrt((dx * dx) + (dy * dy))
	local dotCount = math.floor(screenDistance / 24)
	if dotCount < drawLinesMinDotCount then
		dotCount = drawLinesMinDotCount
	elseif dotCount > drawLinesMaxDotCount then
		dotCount = drawLinesMaxDotCount
	end

	local visible = 0
	local projectedFailed = 0
	for i = 1, dotCount do
		local t = i / dotCount
		local sx = sx1 + ((sx2 - sx1) * t)
		local sy = sy1 + ((sy2 - sy1) * t)
		dotSet[i].container:RemoveAllAnchors()
		dotSet[i].container:AddAnchor("TOPLEFT", "UIParent", math.floor(sx + 0.5), math.floor(sy + 0.5))
		dotSet[i].container:Show(true)
		visible = visible + 1
	end

	for i = dotCount + 1, #dotSet do
		dotSet[i].container:Show(false)
	end
	if drawLinesDebug and drawLinesDebugElapsed >= drawLinesDebugIntervalMs then
		X2Chat:DispatchChatMessage(
			CMF_SYSTEM,
			string.format(
				"[ExtPlates DrawLines DEBUG] %s rendered %d/%d (failed=%d) from=%s to=%s",
				pairKey,
				visible,
				dotCount,
				projectedFailed,
				fromUnit,
				toUnit
			)
		)
	end
	return visible
end
local function GrowthModeLabel(growth)
	if growth == "horizontal_left" then
		return "Horizontal L"
	end
	if growth == "vertical_up" then
		return "Vertical ^"
	end
	if growth == "vertical_down" then
		return "Vertical v"
	end
	return "Horizontal R"
end

local buffAnchor = CreateEmptyWindow("targetDebuffTrackerWatchTargetAnchor", "UIParent")
buffAnchor:Show(true)
DebugPrint("tracktarget.lua loaded")

local drawableIcons = {}
local drawableDurations = {}
local drawableStacks = {}

local function hideUnused(currentIcons)
	for id, icon in pairs(drawableIcons) do
		if not currentIcons[id] and icon:IsVisible() then
			drawableDurations[id]:Show(false)
			drawableStacks[id]:Show(false)
			icon:SetVisible(false)
		end
	end
end

local function drawIcon(parent, iconId, iconPath, xOffset, yOffset, duration, stacks, iconSize)
	local stackText = shared.FormatStackCount(stacks)

	if drawableIcons[iconId] ~= nil then
		if not drawableIcons[iconId]:IsVisible() then
			drawableIcons[iconId]:SetVisible(true)
			drawableDurations[iconId]:Show(true)
			drawableStacks[iconId]:Show(true)
		end
		drawableIcons[iconId]:AddAnchor("LEFT", parent, xOffset, yOffset)
		drawableIcons[iconId]:SetExtent(iconSize, iconSize)
		drawableDurations[iconId]:AddAnchor("LEFT", parent, xOffset, yOffset)
		drawableDurations[iconId]:SetText(duration)
		drawableStacks[iconId]:AddAnchor("LEFT", parent, xOffset + 5, yOffset - 10)
		drawableStacks[iconId]:SetText(stackText)
		return
	end

	local drawableIcon = parent:CreateIconDrawable("artwork")
	drawableIcon:SetExtent(iconSize, iconSize)
	drawableIcon:ClearAllTextures()
	drawableIcon:AddTexture(iconPath)
	drawableIcon:SetVisible(true)

	local lblDuration = parent:CreateChildWidget("label", "lblDuration", 0, true)
	lblDuration:Show(true)
	lblDuration:EnablePick(false)
	lblDuration.style:SetColor(1, 1, 1, 1)
	lblDuration.style:SetOutline(true)
	lblDuration.style:SetAlign(ALIGN_LEFT)
	lblDuration:SetText(duration)

	local lblStacks = parent:CreateChildWidget("label", "lblStacks", 0, true)
	lblStacks:Show(true)
	lblStacks:EnablePick(false)
	lblStacks.style:SetColor(0, 1, 1, 1)
	lblStacks.style:SetOutline(true)
	lblStacks.style:SetAlign(ALIGN_RIGHT)
	lblStacks:SetText(stackText)

	drawableIcons[iconId] = drawableIcon
	drawableDurations[iconId] = lblDuration
	drawableStacks[iconId] = lblStacks
end

function buffAnchor:OnUpdate()
	local screenX, screenY, screenZ = X2Unit:GetUnitScreenPosition("watchtarget")
	if screenX == nil or screenY == nil or screenZ == nil or screenZ <= 0 then
		buffAnchor:AddAnchor("TOPLEFT", "UIParent", 5000, 5000)
		hideUnused({})
		return
	end

	local x = math.floor(0.5 + screenX)
	local y = math.floor(0.5 + screenY)
	local currentIcons = {}

	buffAnchor:Show(true)
	buffAnchor:Enable(true)
	buffAnchor:AddAnchor("TOPLEFT", "UIParent", x - 50, y - 40)

	if shared.GetUiState().target.buff then
		local settings = shared.GetIconSettings("target", "buff")
		local buffCounter = 0
		local buffCount = X2Unit:UnitBuffCount("watchtarget")
		for i = 1, buffCount do
			local buff = X2Unit:UnitBuffTooltip("watchtarget", i)
			local buffExtra = X2Unit:UnitBuff("watchtarget", i)
			local buffId = tostring(buffExtra["buff_id"])
			if shared.ShouldDisplay("target", "buff", buffId) then
				local iconId = "watchbuff:" .. buffId .. ":" .. tostring(buff["name"])
				local iconX, iconY = shared.GetIconOffsetForIndex(settings, buffCounter)
				currentIcons[iconId] = true
				drawIcon(
					buffAnchor,
					iconId,
					buffExtra["path"],
					iconX,
					iconY,
					shared.FormatDuration(buff["timeLeft"] and math.floor(buff["timeLeft"] / 1000) or ""),
					buff["stack"],
					settings.iconSize
				)
				buffCounter = buffCounter + 1
			end
		end
	end

	if shared.GetUiState().target.debuff then
		local settings = shared.GetIconSettings("target", "debuff")
		local debuffCounter = 0
		local debuffCount = X2Unit:UnitDeBuffCount("watchtarget")
		for i = 1, debuffCount do
			local debuff = X2Unit:UnitDeBuffTooltip("watchtarget", i)
			local debuffExtra = X2Unit:UnitDeBuff("watchtarget", i)
			local debuffId = tostring(debuffExtra["buff_id"])
			if shared.ShouldDisplay("target", "debuff", debuffId) then
				local iconId = "watchdebuff:" .. debuffId .. ":" .. tostring(debuff["name"])
				local iconX, iconY = shared.GetIconOffsetForIndex(settings, debuffCounter)
				currentIcons[iconId] = true
				drawIcon(
					buffAnchor,
					iconId,
					debuffExtra["path"],
					iconX,
					iconY,
					shared.FormatDuration(debuff["timeLeft"] and math.floor(debuff["timeLeft"] / 1000) or ""),
					debuff["stack"],
					settings.iconSize
				)
				debuffCounter = debuffCounter + 1
			end
		end
	end

	hideUnused(currentIcons)
end

buffAnchor:SetHandler("OnUpdate", buffAnchor.OnUpdate)

local function categoryTitle(scope, effectType)
	local scopeTitle = scope == "target" and "Target" or "Self"
	local effectTitle = "Buffs"
	if effectType == "debuff" then
		effectTitle = "Debuffs"
	elseif effectType == "hidden" then
		effectTitle = "Hidden Buffs"
	end

	return scopeTitle .. " " .. effectTitle
end

local function liveSectionTitle(scope, effectType)
	if scope == "target" then
		if effectType == "hidden" then
			return "Target's Hidden Buffs"
		elseif effectType == "debuff" then
			return "Target's Debuffs"
		end
		return "Target's Buffs"
	end

	if effectType == "hidden" then
		return "Self Hidden Buffs"
	elseif effectType == "debuff" then
		return "Self Debuffs"
	end
	return "Self Buffs"
end

local function getLiveEffects(scope, effectType)
	DebugPrint(string.format("getLiveEffects start scope=%s effectType=%s", tostring(scope), tostring(effectType)))
	if scope == "target" and effectType == "hidden" then
		return {}
	end

	local unit = scope == "target" and "target" or "player"
	local entries = {}
	local seen = {}

	if effectType == "buff" then
		local count = X2Unit:UnitBuffCount(unit) or 0
		DebugPrint(string.format("UnitBuffCount(%s)=%s", tostring(unit), tostring(count)))
		for i = 1, count do
			local effect = X2Unit:UnitBuffTooltip(unit, i)
			local extra = X2Unit:UnitBuff(unit, i)
			local effectId = extra and tostring(extra["buff_id"]) or nil
			if effect ~= nil and effectId ~= nil and not seen[effectId] then
				seen[effectId] = true
				table.insert(entries, {
					id = effectId,
					name = tostring(effect["name"] or ""),
					iconPath = extra["path"],
				})
			end
		end
	elseif effectType == "debuff" then
		local count = X2Unit:UnitDeBuffCount(unit) or 0
		DebugPrint(string.format("UnitDeBuffCount(%s)=%s", tostring(unit), tostring(count)))
		for i = 1, count do
			local effect = X2Unit:UnitDeBuffTooltip(unit, i)
			local extra = X2Unit:UnitDeBuff(unit, i)
			local effectId = extra and tostring(extra["buff_id"]) or nil
			if effect ~= nil and effectId ~= nil and not seen[effectId] then
				seen[effectId] = true
				table.insert(entries, {
					id = effectId,
					name = tostring(effect["name"] or ""),
					iconPath = extra["path"],
				})
			end
		end
	else
		local count = X2Unit:UnitHiddenBuffCount(unit) or 0
		DebugPrint(string.format("UnitHiddenBuffCount(%s)=%s", tostring(unit), tostring(count)))
		for i = 1, count do
			local effect = X2Unit:UnitHiddenBuffTooltip(unit, i)
			local extra = X2Unit:UnitHiddenBuff(unit, i)
			local effectId = extra and tostring(extra["buff_id"]) or nil
			if effect ~= nil and effectId ~= nil and not seen[effectId] then
				seen[effectId] = true
				table.insert(entries, {
					id = effectId,
					name = tostring(effect["name"] or ""),
					iconPath = extra["path"],
				})
			end
		end
	end

	table.sort(entries, function(left, right)
		local leftName = string.lower(left.name ~= "" and left.name or left.id)
		local rightName = string.lower(right.name ~= "" and right.name or right.id)
		if leftName == rightName then
			return tonumber(left.id) < tonumber(right.id)
		end
		return leftName < rightName
	end)

	DebugPrint(string.format("getLiveEffects done entries=%s", tostring(#entries)))
	return entries
end

local function formatEntry(entry)
	local name = entry.name ~= "" and entry.name or "Unknown"
	return string.format("%s [%s]", name, entry.id)
end

local function categoryButtonText(scope, effectType)
	local scopeTitle = scope == "target" and "Target" or "Self"
	if effectType == "buff" then
		return scopeTitle .. " Buffs"
	elseif effectType == "debuff" then
		return scopeTitle .. " Debuffs"
	end
	return scopeTitle .. " Hidden"
end

local function clampPage(page, rowCount, itemCount)
	local maxPage = math.max(1, math.ceil(math.max(itemCount, 1) / rowCount))
	if page < 1 then
		return 1, maxPage
	end
	if page > maxPage then
		return maxPage, maxPage
	end
	return page, maxPage
end

local managerButton = nil
local managerWindow = nil
local positionButton = nil
local positionWindow
local positionModeScope = "target"
local positionModeEffect = "buff"
local uiState = shared.GetUiState()
local trackedPage = 1
local availablePage = 1
local trackedRows = {}
local availableRows = {}
local categoryButtons = {}
local toggleButtons = {}
local headerLabel = nil
local trackedTitle = nil
local availableTitle = nil
local trackedPageLabel = nil
local availablePageLabel = nil
local trackedPrevButton = nil
local trackedNextButton = nil
local availablePrevButton = nil
local availableNextButton = nil
local addByIdButton = nil
local exportButton = nil
local importButton = nil
local showGearButton = nil
local showEquipmentButton = nil
local showClassButton = nil
local showDistanceButton = nil
local showCastbarButton = nil
local showGearSettingsButton = nil
local showEquipmentSettingsButton = nil
local showClassSettingsButton = nil
local showDistanceSettingsButton = nil
local showCastbarSettingsButton = nil
local positionModeButtons = {}
local infoSettingsWindow = nil
local infoSettingsTitle = nil
local infoSettingsStatus = nil
local infoSettingsMessage = nil
local distanceSettingsPreview = nil
local gearSettingsPreview = nil
local equipmentSettingsPreview = {}
local classSettingsPreviewIcon = nil
local classSettingsPreviewLabel = nil
local castbarSettingsPreview = nil
local castbarSettingsPreviewFill = nil
local castbarSettingsPreviewSpell = nil
local castbarSettingsPreviewTime = nil
local castbarWidthEdit = nil
local castbarHeightEdit = nil
local infoSettingsMode = "distance"
local drawLinesUpdater = nil
local addByIdWindow = nil
local addByIdNameEdit = nil
local addByIdIdEdit = nil
local importExportWindow = nil
local importExportTitle = nil
local importExportMessage = nil
local importExportEdit = nil
local importExportActionButton = nil
local importExportMode = "export"
local refreshWindow = nil
local positionStatusLabel
local positionGrowthButton
local positionPreviewOrigin
local positionPreviewBox
local positionPreviewName
local positionPreviewIcons = {}

LoadDrawLinesSettings()

local initOk, initErr = pcall(function()
	DebugPrint("init: before CreateSimpleButton")
	managerButton = CreateLauncherButtonSafe("Ext Plates", 700, -250)
	DebugPrint("init: after CreateSimpleButton")

	DebugPrint("init: before CreateWindow")
	managerWindow = CreateEmptyWindow("targetDebuffTrackerWindow", "UIParent")
	managerWindow:SetCloseOnEscape(true)
	DebugPrint("init: after CreateEmptyWindow")

managerWindow:AddAnchor("CENTER", "UIParent", 0, 0)
DebugPrint("init: after window anchor")
managerWindow:SetExtent(720, 684)
DebugPrint("init: after window extent")
	managerWindow:Show(false)
	DebugPrint("init: after window hide")

	local background = CreateWindowBackground(managerWindow)
	DebugPrint("init: after background")

	DebugPrint("init: after borders")

	DebugPrint("init: after titleBar")

	local titleLabel = managerWindow:CreateChildWidget("label", "windowTitle", 0, true)
	titleLabel:AddAnchor("TOPLEFT", managerWindow, 20, 12)
	titleLabel:SetExtent(300, 24)
	ApplyLocalLabelStyle(titleLabel, 16, ALIGN_LEFT, 1, 0.97, 0.92)
	SetWidgetTextColorByKey(titleLabel, "brown")
	titleLabel:SetText("Extended Plates")
	DebugPrint("init: after titleLabel")

	local closeButton = CreateCloseButton(managerWindow, "closeButton", function()
		managerWindow:Show(false)
		DebugPrint("closeButton clicked")
	end)
	DebugPrint("init: after closeButton")

	managerWindow:EnableDrag(true)
	managerWindow:SetHandler("OnDragStart", function(self)
		self:StartMoving()
		return true
	end)
	managerWindow:SetHandler("OnDragStop", function(self)
		self:StopMovingOrSizing()
	end)
	DebugPrint("init: after drag handlers")

	headerLabel = managerWindow:CreateChildWidget("label", "headerLabel", 0, true)
	DebugPrint("init: after headerLabel")
	headerLabel:AddAnchor("TOPLEFT", managerWindow, 245, 54)
	headerLabel:SetExtent(390, 28)
	ApplyLocalLabelStyle(headerLabel, 16, ALIGN_LEFT, 1, 0.97, 0.92)
	SetWidgetTextColorByKey(headerLabel, "brown")

	trackedTitle = managerWindow:CreateChildWidget("label", "trackedTitle", 0, true)
	DebugPrint("init: after trackedTitle")
	trackedTitle:AddAnchor("TOPLEFT", managerWindow, 245, 90)
	trackedTitle:SetExtent(300, 22)
	ApplyLocalLabelStyle(trackedTitle, 14, ALIGN_LEFT, 0.96, 0.90, 0.78)
	SetWidgetTextColorByKey(trackedTitle, "brown")

	availableTitle = managerWindow:CreateChildWidget("label", "availableTitle", 0, true)
	DebugPrint("init: after availableTitle")
	availableTitle:AddAnchor("TOPLEFT", managerWindow, 245, 304)
	availableTitle:SetExtent(300, 22)
	ApplyLocalLabelStyle(availableTitle, 14, ALIGN_LEFT, 0.96, 0.90, 0.78)
	SetWidgetTextColorByKey(availableTitle, "brown")

	trackedPageLabel = managerWindow:CreateChildWidget("label", "trackedPageLabel", 0, true)
	DebugPrint("init: after trackedPageLabel")
	trackedPageLabel:AddAnchor("TOPRIGHT", managerWindow, -72, 92)
	trackedPageLabel:SetExtent(60, 20)
	ApplyLocalLabelStyle(trackedPageLabel, 14, ALIGN_RIGHT, 1, 1, 1)
	SetWidgetTextColorByKey(trackedPageLabel, "default")

	availablePageLabel = managerWindow:CreateChildWidget("label", "availablePageLabel", 0, true)
	DebugPrint("init: after availablePageLabel")
	availablePageLabel:AddAnchor("TOPRIGHT", managerWindow, -72, 306)
	availablePageLabel:SetExtent(60, 20)
	ApplyLocalLabelStyle(availablePageLabel, 14, ALIGN_RIGHT, 1, 1, 1)
	SetWidgetTextColorByKey(availablePageLabel, "default")

	trackedPrevButton = managerWindow:CreateChildWidget("button", "trackedPrevButton", 0, true)
	DebugPrint("init: after trackedPrevButton")
	trackedPrevButton:SetText("<")
	ApplyLocalButtonStyle(trackedPrevButton)
	trackedPrevButton:SetExtent(30, 24)
	trackedPrevButton:AddAnchor("TOPRIGHT", managerWindow, -150, 88)

	trackedNextButton = managerWindow:CreateChildWidget("button", "trackedNextButton", 0, true)
	DebugPrint("init: after trackedNextButton")
	trackedNextButton:SetText(">")
	ApplyLocalButtonStyle(trackedNextButton)
	trackedNextButton:SetExtent(30, 24)
	trackedNextButton:AddAnchor("TOPRIGHT", managerWindow, -18, 88)

	availablePrevButton = managerWindow:CreateChildWidget("button", "availablePrevButton", 0, true)
	DebugPrint("init: after availablePrevButton")
	availablePrevButton:SetText("<")
	ApplyLocalButtonStyle(availablePrevButton)
	availablePrevButton:SetExtent(30, 24)
	availablePrevButton:AddAnchor("TOPRIGHT", managerWindow, -150, 302)

availableNextButton = managerWindow:CreateChildWidget("button", "availableNextButton", 0, true)
DebugPrint("init: after availableNextButton")
availableNextButton:SetText(">")
ApplyLocalButtonStyle(availableNextButton)
availableNextButton:SetExtent(30, 24)
availableNextButton:AddAnchor("TOPRIGHT", managerWindow, -18, 302)

addByIdButton = managerWindow:CreateChildWidget("button", "addByIdButton", 0, true)
ApplyLocalButtonStyle(addByIdButton)
addByIdButton:SetExtent(96, 24)
addByIdButton:AddAnchor("TOPRIGHT", managerWindow, -226, 622)
addByIdButton:SetText("Add by ID")

exportButton = managerWindow:CreateChildWidget("button", "exportButton", 0, true)
ApplyLocalButtonStyle(exportButton)
exportButton:SetExtent(96, 24)
exportButton:AddAnchor("TOPRIGHT", managerWindow, -122, 622)
exportButton:SetText("Export")

importButton = managerWindow:CreateChildWidget("button", "importButton", 0, true)
ApplyLocalButtonStyle(importButton)
importButton:SetExtent(96, 24)
importButton:AddAnchor("TOPRIGHT", managerWindow, -18, 622)
importButton:SetText("Import")

positionButton = managerWindow:CreateChildWidget("button", "positionButton", 0, true)
ApplyLocalButtonStyle(positionButton)
positionButton:SetExtent(SIMPLE_BUTTON_WIDTH, SIMPLE_BUTTON_HEIGHT)
positionButton:AddAnchor("TOPLEFT", managerWindow, LEFT_BUTTON_X, LowerLeftButtonY(6))
positionButton:SetText("Position")
end)

if not initOk then
	DebugPrint("init failed: " .. tostring(initErr))
	return
end

DebugPrint("init: manager base widgets complete")

local function createCategoryRow(index, scope, effectType)
	local y = LeftButtonY(index)
	local key = scope .. "_" .. effectType

	local selectButton = managerWindow:CreateChildWidget("button", "categoryButton", index, true)
	ApplyLocalButtonStyle(selectButton)
	selectButton:SetExtent(SIMPLE_BUTTON_WIDTH, SIMPLE_BUTTON_HEIGHT)
	selectButton:AddAnchor("TOPLEFT", managerWindow, LEFT_BUTTON_X, y)
	categoryButtons[key] = selectButton

	local toggleButton = managerWindow:CreateChildWidget("button", "toggleButton", index, true)
	ApplyLocalButtonStyle(toggleButton)
	SetSecondaryButtonExtent(toggleButton)
	toggleButton:AddAnchor("TOPLEFT", managerWindow, SECONDARY_BUTTON_X, y)
	toggleButtons[key] = toggleButton

	selectButton:SetHandler("OnClick", function()
		uiState.activeScope = scope
		uiState.activeEffect = effectType
		trackedPage = 1
		availablePage = 1
		shared.SaveUiState()
	end)

	toggleButton:SetHandler("OnClick", function()
		uiState[scope][effectType] = not uiState[scope][effectType]
		shared.SaveUiState()
	end)
end

createCategoryRow(1, "target", "buff")
createCategoryRow(2, "target", "debuff")
createCategoryRow(3, "self", "buff")
createCategoryRow(4, "self", "debuff")
createCategoryRow(5, "self", "hidden")

local filterButton = managerWindow:CreateChildWidget("button", "filterButton", 0, true)
ApplyLocalButtonStyle(filterButton)
filterButton:SetExtent(SIMPLE_BUTTON_WIDTH, SIMPLE_BUTTON_HEIGHT)
filterButton:AddAnchor("TOPLEFT", managerWindow, LEFT_BUTTON_X, LowerLeftButtonY(7))
filterButton:SetHandler("OnClick", function()
	uiState.filterTrackedOnly = not uiState.filterTrackedOnly
	shared.SaveUiState()
end)

showGearButton = managerWindow:CreateChildWidget("button", "showGearButton", 0, true)
ApplyLocalButtonStyle(showGearButton)
showGearButton:SetExtent(SIMPLE_BUTTON_WIDTH, SIMPLE_BUTTON_HEIGHT)
showGearButton:AddAnchor("TOPLEFT", managerWindow, LEFT_BUTTON_X, LowerLeftButtonY(8))
showGearButton:SetHandler("OnClick", function()
	uiState.showGear = not uiState.showGear
	shared.SaveUiState()
end)

showGearSettingsButton = managerWindow:CreateChildWidget("button", "showGearSettingsButton", 0, true)
ApplyLocalButtonStyle(showGearSettingsButton)
SetSecondaryButtonExtent(showGearSettingsButton)
showGearSettingsButton:AddAnchor("TOPLEFT", managerWindow, SECONDARY_BUTTON_X, LowerLeftButtonY(8))
showGearSettingsButton:SetText("...")
showGearSettingsButton:SetHandler("OnClick", function()
	infoSettingsMode = "gear"
	if infoSettingsWindow ~= nil then
		infoSettingsWindow:Show(true)
	end
end)

showClassButton = managerWindow:CreateChildWidget("button", "showClassButton", 0, true)
ApplyLocalButtonStyle(showClassButton)
showClassButton:SetExtent(SIMPLE_BUTTON_WIDTH, SIMPLE_BUTTON_HEIGHT)
showClassButton:AddAnchor("TOPLEFT", managerWindow, LEFT_BUTTON_X, LowerLeftButtonY(9))
showClassButton:SetHandler("OnClick", function()
	uiState.showClass = not uiState.showClass
	shared.SaveUiState()
end)

showClassSettingsButton = managerWindow:CreateChildWidget("button", "showClassSettingsButton", 0, true)
ApplyLocalButtonStyle(showClassSettingsButton)
SetSecondaryButtonExtent(showClassSettingsButton)
showClassSettingsButton:AddAnchor("TOPLEFT", managerWindow, SECONDARY_BUTTON_X, LowerLeftButtonY(9))
showClassSettingsButton:SetText("...")
showClassSettingsButton:SetHandler("OnClick", function()
	infoSettingsMode = "class"
	if infoSettingsWindow ~= nil then
		infoSettingsWindow:Show(true)
	end
end)

showDistanceButton = managerWindow:CreateChildWidget("button", "showDistanceButton", 0, true)
ApplyLocalButtonStyle(showDistanceButton)
showDistanceButton:SetExtent(SIMPLE_BUTTON_WIDTH, SIMPLE_BUTTON_HEIGHT)
showDistanceButton:AddAnchor("TOPLEFT", managerWindow, LEFT_BUTTON_X, LowerLeftButtonY(10))
showDistanceButton:SetHandler("OnClick", function()
	uiState.showDistance = not uiState.showDistance
	shared.SaveUiState()
end)

showDistanceSettingsButton = managerWindow:CreateChildWidget("button", "showDistanceSettingsButton", 0, true)
ApplyLocalButtonStyle(showDistanceSettingsButton)
SetSecondaryButtonExtent(showDistanceSettingsButton)
showDistanceSettingsButton:AddAnchor("TOPLEFT", managerWindow, SECONDARY_BUTTON_X, LowerLeftButtonY(10))
showDistanceSettingsButton:SetText("...")
showDistanceSettingsButton:SetHandler("OnClick", function()
	infoSettingsMode = "distance"
	if infoSettingsWindow ~= nil then
		infoSettingsWindow:Show(true)
	end
end)

showCastbarButton = managerWindow:CreateChildWidget("button", "showCastbarButton", 0, true)
ApplyLocalButtonStyle(showCastbarButton)
showCastbarButton:SetExtent(SIMPLE_BUTTON_WIDTH, SIMPLE_BUTTON_HEIGHT)
showCastbarButton:AddAnchor("TOPLEFT", managerWindow, LEFT_BUTTON_X, LowerLeftButtonY(11))
showCastbarButton:SetHandler("OnClick", function()
	uiState.showCastbar = not uiState.showCastbar
	shared.SaveUiState()
end)

showCastbarSettingsButton = managerWindow:CreateChildWidget("button", "showCastbarSettingsButton", 0, true)
ApplyLocalButtonStyle(showCastbarSettingsButton)
SetSecondaryButtonExtent(showCastbarSettingsButton)
showCastbarSettingsButton:AddAnchor("TOPLEFT", managerWindow, SECONDARY_BUTTON_X, LowerLeftButtonY(11))
showCastbarSettingsButton:SetText("...")
showCastbarSettingsButton:SetHandler("OnClick", function()
	infoSettingsMode = "castbar"
	local settings = shared.GetCastbarSettings()
	castbarWidthEdit:SetText(tostring(settings.width))
	castbarHeightEdit:SetText(tostring(settings.height))
	if infoSettingsWindow ~= nil then
		infoSettingsWindow:Show(true)
	end
end)

showEquipmentButton = managerWindow:CreateChildWidget("button", "showEquipmentButton", 0, true)
ApplyLocalButtonStyle(showEquipmentButton)
showEquipmentButton:SetExtent(SIMPLE_BUTTON_WIDTH, SIMPLE_BUTTON_HEIGHT)
showEquipmentButton:AddAnchor("TOPLEFT", managerWindow, LEFT_BUTTON_X, LowerLeftButtonY(12))
showEquipmentButton:SetHandler("OnClick", function()
	uiState.showEquipment = not uiState.showEquipment
	shared.SaveUiState()
end)

showEquipmentSettingsButton = managerWindow:CreateChildWidget("button", "showEquipmentSettingsButton", 0, true)
ApplyLocalButtonStyle(showEquipmentSettingsButton)
SetSecondaryButtonExtent(showEquipmentSettingsButton)
showEquipmentSettingsButton:AddAnchor("TOPLEFT", managerWindow, SECONDARY_BUTTON_X, LowerLeftButtonY(12))
showEquipmentSettingsButton:SetText("...")
showEquipmentSettingsButton:SetHandler("OnClick", function()
	infoSettingsMode = "equipment"
	if infoSettingsWindow ~= nil then
		infoSettingsWindow:Show(true)
	end
end)

drawLinesButton = managerWindow:CreateChildWidget("button", "drawLinesButton", 0, true)
ApplyLocalButtonStyle(drawLinesButton)
drawLinesButton:SetExtent(SIMPLE_BUTTON_WIDTH, SIMPLE_BUTTON_HEIGHT)
drawLinesButton:AddAnchor("TOPLEFT", managerWindow, LEFT_BUTTON_X, LowerLeftButtonY(13))
drawLinesButton:SetHandler("OnClick", function()
	drawLinesEnabled = not drawLinesEnabled
	SaveDrawLinesSettings()
end)

drawLinesSettingsButton = managerWindow:CreateChildWidget("button", "drawLinesSettingsButton", 0, true)
ApplyLocalButtonStyle(drawLinesSettingsButton)
SetSecondaryButtonExtent(drawLinesSettingsButton)
drawLinesSettingsButton:AddAnchor("TOPLEFT", managerWindow, SECONDARY_BUTTON_X, LowerLeftButtonY(13))
drawLinesSettingsButton:SetText("...")
drawLinesSettingsButton:SetHandler("OnClick", function()
	if drawLinesSettingsWindow ~= nil then
		drawLinesSettingsWindow:Show(true)
	end
end)

positionWindow = CreateEmptyWindow("targetDebuffTrackerPositionWindow", "UIParent")
positionWindow:SetCloseOnEscape(true)
positionWindow:AddAnchor("CENTER", "UIParent", 300, 0)
positionWindow:SetExtent(260, 430)
positionWindow:Show(false)

addByIdWindow = CreateEmptyWindow("extendedPlatesAddByIdWindow", "UIParent")
addByIdWindow:SetCloseOnEscape(true)
addByIdWindow:AddAnchor("CENTER", "UIParent", 180, 40)
addByIdWindow:SetExtent(260, 170)
addByIdWindow:Show(false)

importExportWindow = CreateEmptyWindow("extendedPlatesImportExportWindow", "UIParent")
importExportWindow:SetCloseOnEscape(true)
importExportWindow:AddAnchor("CENTER", "UIParent", 200, 20)
importExportWindow:SetExtent(470, 340)
importExportWindow:Show(false)

infoSettingsWindow = CreateEmptyWindow("extendedPlatesInfoSettingsWindow", "UIParent")
infoSettingsWindow:SetCloseOnEscape(true)
infoSettingsWindow:AddAnchor("CENTER", "UIParent", 300, 0)
infoSettingsWindow:SetExtent(320, 470)
infoSettingsWindow:Show(false)

drawLinesSettingsWindow = CreateEmptyWindow("extendedPlatesDrawLinesSettingsWindow", "UIParent")
drawLinesSettingsWindow:SetCloseOnEscape(true)
drawLinesSettingsWindow:AddAnchor("CENTER", "UIParent", 340, 0)
drawLinesSettingsWindow:SetExtent(320, 560)
drawLinesSettingsWindow:Show(false)

tracktargetAggroWindow = CreateEmptyWindow("extendedPlatesTracktargetAggroWindow", "UIParent")
tracktargetAggroWindow:SetExtent(230, 52)
local aggroX, aggroY = LoadTracktargetAggroWindowPos()
if aggroX ~= 0 or aggroY ~= 0 then
	tracktargetAggroWindow:AddAnchor("TOPLEFT", "UIParent", aggroX, aggroY)
else
	tracktargetAggroWindow:AddAnchor("TOPLEFT", "UIParent", 440, 260)
end
tracktargetAggroWindow:Show(false)
tracktargetAggroWindow:EnableDrag(true)
tracktargetAggroWindow:SetHandler("OnDragStart", function(self)
	self:StartMoving()
end)
tracktargetAggroWindow:SetHandler("OnDragStop", function(self)
	self:StopMovingOrSizing()
	local offsetX, offsetY = self:GetOffset()
	local uiScale = UIParent:GetUIScale() or 1.0
	SaveTracktargetAggroWindowPos(offsetX * uiScale, offsetY * uiScale)
end)
tracktargetAggroBackground = tracktargetAggroWindow:CreateColorDrawable(0.12, 0.12, 0.12, 0.60, "background")
tracktargetAggroBackground:AddAnchor("TOPLEFT", tracktargetAggroWindow, 0, 0)
tracktargetAggroBackground:AddAnchor("BOTTOMRIGHT", tracktargetAggroWindow, 0, 0)
tracktargetAggroLabel = tracktargetAggroWindow:CreateChildWidget("label", "tracktargetAggroLabel", 0, true)
tracktargetAggroLabel:AddAnchor("TOPLEFT", tracktargetAggroWindow, 10, 12)
tracktargetAggroLabel:SetExtent(210, 28)
ApplyLocalLabelStyle(tracktargetAggroLabel, 18, ALIGN_LEFT, 1, 1, 1)
tracktargetAggroLabel:SetText("none")
tracktargetAggroLabel:EnablePick(false)
ApplyTracktargetAggroLockState()

tracktargetDistanceWindow = CreateEmptyWindow("extendedPlatesTracktargetDistanceWindow", "UIParent")
tracktargetDistanceWindow:SetExtent(300, 52)
local distX, distY = LoadTracktargetDistanceWindowPos()
if distX ~= 0 or distY ~= 0 then
	tracktargetDistanceWindow:AddAnchor("TOPLEFT", "UIParent", distX, distY)
else
	tracktargetDistanceWindow:AddAnchor("TOPLEFT", "UIParent", 440, 320)
end
tracktargetDistanceWindow:Show(false)
tracktargetDistanceWindow:EnableDrag(true)
tracktargetDistanceWindow:SetHandler("OnDragStart", function(self)
	self:StartMoving()
end)
tracktargetDistanceWindow:SetHandler("OnDragStop", function(self)
	self:StopMovingOrSizing()
	local offsetX, offsetY = self:GetOffset()
	local uiScale = UIParent:GetUIScale() or 1.0
	SaveTracktargetDistanceWindowPos(offsetX * uiScale, offsetY * uiScale)
end)
tracktargetDistanceBackground = tracktargetDistanceWindow:CreateColorDrawable(0.12, 0.12, 0.12, 0.60, "background")
tracktargetDistanceBackground:AddAnchor("TOPLEFT", tracktargetDistanceWindow, 0, 0)
tracktargetDistanceBackground:AddAnchor("BOTTOMRIGHT", tracktargetDistanceWindow, 0, 0)
tracktargetDistanceLabel = tracktargetDistanceWindow:CreateChildWidget("label", "tracktargetDistanceLabel", 0, true)
tracktargetDistanceLabel:AddAnchor("TOPLEFT", tracktargetDistanceWindow, 10, 12)
tracktargetDistanceLabel:SetExtent(280, 28)
ApplyLocalLabelStyle(tracktargetDistanceLabel, 18, ALIGN_LEFT, 1, 1, 1)
tracktargetDistanceLabel:SetText("Distance: none")
tracktargetDistanceLabel:EnablePick(false)
ApplyTracktargetDistanceLockState()

do
	CreateWindowBackground(addByIdWindow)

	local title = addByIdWindow:CreateChildWidget("label", "title", 0, true)
	title:AddAnchor("TOPLEFT", addByIdWindow, 16, 12)
	title:SetExtent(160, 24)
	ApplyLocalLabelStyle(title, 18, ALIGN_LEFT, 1, 0.97, 0.92)
	SetWidgetTextColorByKey(title, "brown")
	title:SetText("Add by ID")

	CreateCloseButton(addByIdWindow, "closeButton", function()
		addByIdWindow:Show(false)
	end)

	addByIdWindow:EnableDrag(true)
	addByIdWindow:SetHandler("OnDragStart", function(self)
		self:StartMoving()
		return true
	end)
	addByIdWindow:SetHandler("OnDragStop", function(self)
		self:StopMovingOrSizing()
	end)

	local nameLabel = addByIdWindow:CreateChildWidget("label", "nameLabel", 0, true)
	nameLabel:AddAnchor("TOPLEFT", addByIdWindow, 16, 48)
	nameLabel:SetExtent(80, 20)
	ApplyLocalLabelStyle(nameLabel, 13, ALIGN_LEFT, 1, 1, 1)
	SetWidgetTextColorByKey(nameLabel, "default")
	nameLabel:SetText("Name")

	addByIdNameEdit = CreateLocalEditBox(addByIdWindow, "addByIdNameEdit", 148)
	addByIdNameEdit:AddAnchor("TOPLEFT", addByIdWindow, 96, 42)

	local idLabel = addByIdWindow:CreateChildWidget("label", "idLabel", 0, true)
	idLabel:AddAnchor("TOPLEFT", addByIdWindow, 16, 86)
	idLabel:SetExtent(80, 20)
	ApplyLocalLabelStyle(idLabel, 13, ALIGN_LEFT, 1, 1, 1)
	SetWidgetTextColorByKey(idLabel, "default")
	idLabel:SetText("ID")

	addByIdIdEdit = CreateLocalEditBox(addByIdWindow, "addByIdIdEdit", 148)
	addByIdIdEdit:AddAnchor("TOPLEFT", addByIdWindow, 96, 80)

	local function submitAddById()
		local scope = uiState.activeScope
		local effectType = uiState.activeEffect
		local name = tostring(addByIdNameEdit:GetText() or ""):match("^%s*(.-)%s*$")
		local effectId = tostring(addByIdIdEdit:GetText() or ""):match("^%s*(.-)%s*$")

		if name == nil or name == "" then
			X2Chat:DispatchChatMessage(CMF_SYSTEM, "Extended Plates: enter a name.")
			return
		end
		if effectId == nil or effectId == "" or not effectId:match("^%d+$") then
			X2Chat:DispatchChatMessage(CMF_SYSTEM, "Extended Plates: enter a numeric ID.")
			return
		end

		shared.AddTracked(scope, effectType, effectId, name, "")
		addByIdNameEdit:SetText("")
		addByIdIdEdit:SetText("")
		addByIdWindow:Show(false)
		refreshWindow()
	end

	local submitButton = addByIdWindow:CreateChildWidget("button", "submitButton", 0, true)
	ApplyLocalButtonStyle(submitButton)
	submitButton:SetExtent(100, 28)
	submitButton:AddAnchor("BOTTOM", addByIdWindow, 0, -18)
	submitButton:SetText("Submit")
	submitButton:SetHandler("OnClick", submitAddById)
	addByIdNameEdit:SetHandler("OnEnterPressed", function()
		addByIdIdEdit:SetFocus()
	end)
	addByIdIdEdit:SetHandler("OnEnterPressed", submitAddById)
end

do
	local baseImportExportHeight = 340
	local baseImportExportEditHeight = 210
	CreateWindowBackground(importExportWindow)

	importExportTitle = importExportWindow:CreateChildWidget("label", "title", 0, true)
	importExportTitle:AddAnchor("TOPLEFT", importExportWindow, 16, 12)
	importExportTitle:SetExtent(220, 24)
	ApplyLocalLabelStyle(importExportTitle, 18, ALIGN_LEFT, 1, 0.97, 0.92)
	SetWidgetTextColorByKey(importExportTitle, "brown")

	CreateCloseButton(importExportWindow, "closeButton", function()
		importExportWindow:Show(false)
	end)

	importExportWindow:EnableDrag(true)
	importExportWindow:SetHandler("OnDragStart", function(self)
		self:StartMoving()
		return true
	end)
	importExportWindow:SetHandler("OnDragStop", function(self)
		self:StopMovingOrSizing()
	end)
	importExportWindow:UseResizing(true)
	importExportWindow:SetMinResizingExtent(470, 340)
	importExportWindow:SetMaxResizingExtent(470, 1200)

	local resizeButton = importExportWindow:CreateChildWidget("button", "resizeButton", 0, true)
	ApplyLocalButtonStyle(resizeButton)
	resizeButton:SetExtent(32, 24)
	resizeButton:AddAnchor("BOTTOMRIGHT", importExportWindow, -8, -8)
	resizeButton:SetText("///")
	resizeButton:EnableDrag(true)
	resizeButton:SetHandler("OnDragStart", function()
		importExportWindow:StartSizing("BOTTOMRIGHT")
		return true
	end)
	resizeButton:SetHandler("OnDragStop", function()
		importExportWindow:StopMovingOrSizing()
	end)

	importExportMessage = importExportWindow:CreateChildWidget("label", "message", 0, true)
	importExportMessage:AddAnchor("TOPLEFT", importExportWindow, 16, 44)
	importExportMessage:SetExtent(438, 36)
	ApplyLocalLabelStyle(importExportMessage, 13, ALIGN_LEFT, 1, 1, 1)
	SetWidgetTextColorByKey(importExportMessage, "default")

	importExportEdit = CreateLocalMultiLineEdit(importExportWindow, "importExportEdit", 438, 210)
	importExportEdit:AddAnchor("TOPLEFT", importExportWindow, 16, 84)

	local function ApplyImportExportLayout(height)
		importExportEdit:SetHeight(baseImportExportEditHeight + (height - baseImportExportHeight))
	end

	function importExportWindow:SetDynamicHeight(height)
		self:SetExtent(470, height)
		ApplyImportExportLayout(height)
	end

	function importExportWindow:OnUpdate(dt)
		local height = self:GetHeight()
		if height ~= self.lastAppliedHeight then
			self.lastAppliedHeight = height
			ApplyImportExportLayout(height)
		end
	end
	importExportWindow:SetHandler("OnUpdate", importExportWindow.OnUpdate)

	local function encodeTransferValue(value)
		return tostring(value or ""):gsub("([^%w%._%-%/])", function(char)
			return string.format("%%%02X", string.byte(char))
		end)
	end

	local function decodeTransferValue(value)
		return tostring(value or ""):gsub("%%(%x%x)", function(hex)
			return string.char(tonumber(hex, 16))
		end)
	end

	local function wrapTransferString(text, lineLength)
		local pieces = {}
		local index = 1
		while index <= string.len(text) do
			pieces[#pieces + 1] = string.sub(text, index, index + lineLength - 1)
			index = index + lineLength
		end
		return table.concat(pieces, "\n")
	end

	local function buildExportString(scope, effectType)
		local entries = shared.GetSortedTrackedEntries(scope, effectType)
		local encodedEntries = {}
		for i = 1, #entries do
			local entry = entries[i]
			encodedEntries[#encodedEntries + 1] = string.format(
				"%s|%s|%s",
				tostring(entry.id),
				encodeTransferValue(entry.name or ""),
				encodeTransferValue(entry.iconPath or "")
			)
		end
		return wrapTransferString("EP1:" .. table.concat(encodedEntries, ";"), 110)
	end

	local function decodeCompactImportString(text)
		local flattened = tostring(text or ""):gsub("%s+", "")
		if string.sub(flattened, 1, 4) ~= "EP1:" then
			return nil
		end

		local payload = string.sub(flattened, 5)
		local normalized = {}
		local foundAny = false

		for entry in payload:gmatch("([^;]+)") do
			local effectId, encodedName, encodedIcon = entry:match("^(%d+)|([^|]*)|([^|]*)$")
			if effectId ~= nil then
				normalized[effectId] = {
					name = decodeTransferValue(encodedName),
					iconPath = decodeTransferValue(encodedIcon),
				}
				foundAny = true
			end
		end

		if not foundAny then
			return nil
		end

		return normalized
	end

	local function decodeBlockImportString(text)
		local normalized = {}
		local current = nil
		local foundAny = false

		for line in tostring(text or ""):gmatch("[^\r\n]+") do
			local trimmed = tostring(line):match("^%s*(.-)%s*$")
			if trimmed ~= "" then
				if trimmed == "--" then
					if current ~= nil and current.id ~= nil and current.id:match("^%d+$") then
						normalized[current.id] = {
							name = current.name or "",
							iconPath = current.iconPath or "",
						}
						foundAny = true
					end
					current = nil
				else
					local key, value = trimmed:match("^(%a+)%=(.*)$")
					if key ~= nil then
						if current == nil then
							current = { name = "", iconPath = "" }
						end
						if key == "id" then
							current.id = tostring(value or ""):match("^%s*(.-)%s*$")
						elseif key == "name" then
							current.name = tostring(value or "")
						elseif key == "icon" then
							current.iconPath = tostring(value or "")
						end
					end
				end
			end
		end

		if current ~= nil and current.id ~= nil and current.id:match("^%d+$") then
			normalized[current.id] = {
				name = current.name or "",
				iconPath = current.iconPath or "",
			}
			foundAny = true
		end

		if not foundAny then
			return nil
		end

		return normalized
	end

	local function decodeImportString(text)
		local compactDecoded = decodeCompactImportString(text)
		if compactDecoded ~= nil then
			return compactDecoded
		end

		local blockDecoded = decodeBlockImportString(text)
		if blockDecoded ~= nil then
			return blockDecoded
		end

		local trimmed = tostring(text or ""):match("^%s*(.-)%s*$")
		if trimmed == nil or trimmed == "" then
			return nil
		end

		local loader = loadstring or load
		if loader == nil then
			return nil
		end

		local chunk = loader("return " .. trimmed)
		if chunk == nil then
			chunk = loader(trimmed)
		end
		if chunk == nil then
			return nil
		end

		local ok, decoded = pcall(chunk)
		if not ok or type(decoded) ~= "table" then
			return nil
		end

		local normalized = {}
		for key, value in pairs(decoded) do
			local effectId
			local name
			local iconPath

			if type(value) == "table" then
				effectId = value.id ~= nil and tostring(value.id) or tostring(key)
				name = tostring(value.name or value[1] or "")
				iconPath = tostring(value.iconPath or value.icon or value.path or "")
			else
				effectId = tostring(key)
				name = tostring(value or "")
			end

			if effectId ~= nil and effectId:match("^%d+$") then
				normalized[effectId] = {
					name = name,
					iconPath = iconPath,
				}
			end
		end

		if next(normalized) == nil then
			return nil
		end

		return normalized
	end

	local function applyImportString()
		local scope = uiState.activeScope
		local effectType = uiState.activeEffect
		local decoded = decodeImportString(importExportEdit:GetText())
		if decoded == nil then
			X2Chat:DispatchChatMessage(CMF_SYSTEM, "Extended Plates: invalid import string.")
			return
		end

		local tracked = shared.GetTracked(scope, effectType)
		for key in pairs(tracked) do
			tracked[key] = nil
		end
		for effectId, entry in pairs(decoded) do
			tracked[effectId] = {
				name = tostring(entry.name or ""),
				iconPath = tostring(entry.iconPath or ""),
			}
		end
		shared.SaveTracked(scope, effectType)
		importExportWindow:Show(false)
		refreshWindow()
	end

	importExportActionButton = importExportWindow:CreateChildWidget("button", "actionButton", 0, true)
	ApplyLocalButtonStyle(importExportActionButton)
	importExportActionButton:SetExtent(120, 30)
	importExportActionButton:AddAnchor("BOTTOM", importExportWindow, 0, -16)
	importExportActionButton:SetHandler("OnClick", function()
		if importExportMode == "import" then
			applyImportString()
		else
			importExportWindow:Show(false)
		end
	end)

	function importExportWindow:ShowExport()
		local scope = uiState.activeScope
		local effectType = uiState.activeEffect
		local entryCount = #shared.GetSortedTrackedEntries(scope, effectType)
		local extraHeight = math.max(0, entryCount - 5) * 20
		importExportMode = "export"
		self:SetDynamicHeight(baseImportExportHeight + extraHeight)
		importExportTitle:SetText("Export")
		importExportMessage:SetText("Please Ctrl+A, Ctrl+C this.")
		importExportEdit:SetText(buildExportString(scope, effectType))
		importExportActionButton:SetText("Close")
		self:Show(true)
	end

	function importExportWindow:ShowImport()
		importExportMode = "import"
		self:SetDynamicHeight(baseImportExportHeight)
		importExportTitle:SetText("Import")
		importExportMessage:SetText("Please Ctrl+A, Ctrl+V this, resize if box is too small.")
		importExportEdit:SetText("")
		importExportActionButton:SetText("Import")
		self:Show(true)
	end
end

do
	CreateWindowBackground(infoSettingsWindow)

	infoSettingsTitle = infoSettingsWindow:CreateChildWidget("label", "title", 0, true)
	infoSettingsTitle:AddAnchor("TOPLEFT", infoSettingsWindow, 16, 12)
	infoSettingsTitle:SetExtent(230, 24)
	ApplyLocalLabelStyle(infoSettingsTitle, 18, ALIGN_LEFT, 1, 0.97, 0.92)
	SetWidgetTextColorByKey(infoSettingsTitle, "brown")
	infoSettingsTitle:SetText("Distance Settings")

	CreateCloseButton(infoSettingsWindow, "closeButton", function()
		infoSettingsWindow:Show(false)
	end)

	infoSettingsWindow:EnableDrag(true)
	infoSettingsWindow:SetHandler("OnDragStart", function(self)
		self:StartMoving()
		return true
	end)
	infoSettingsWindow:SetHandler("OnDragStop", function(self)
		self:StopMovingOrSizing()
	end)

	infoSettingsStatus = infoSettingsWindow:CreateChildWidget("label", "status", 0, true)
	infoSettingsStatus:AddAnchor("TOPLEFT", infoSettingsWindow, 16, 46)
	infoSettingsStatus:SetExtent(288, 110)
	ApplyLocalLabelStyle(infoSettingsStatus, 14, ALIGN_LEFT, 0.96, 0.90, 0.78)
	SetWidgetTextColorByKey(infoSettingsStatus, "brown")

	infoSettingsMessage = infoSettingsWindow:CreateChildWidget("label", "message", 0, true)
	infoSettingsMessage:AddAnchor("TOPLEFT", infoSettingsWindow, 16, 156)
	infoSettingsMessage:SetExtent(288, 36)
	ApplyLocalLabelStyle(infoSettingsMessage, 13, ALIGN_LEFT, 1, 1, 1)
	SetWidgetTextColorByKey(infoSettingsMessage, "default")
	infoSettingsMessage:SetText("")

	local previewBg = infoSettingsWindow:CreateColorDrawable(0.12, 0.10, 0.08, 0.65, "background")
	previewBg:AddAnchor("TOPLEFT", infoSettingsWindow, 16, 202)
	previewBg:SetExtent(288, 92)
	local previewPlate = infoSettingsWindow:CreateColorDrawable(0.28, 0.42, 0.18, 0.95, "artwork")
	previewPlate:SetExtent(80, 30)
	previewPlate:AddAnchor("TOPLEFT", infoSettingsWindow, 120, 232)
	local previewName = infoSettingsWindow:CreateChildWidget("label", "previewName", 0, true)
	previewName:AddAnchor("TOPLEFT", previewPlate, 6, 6)
	previewName:SetExtent(68, 18)
	ApplyLocalLabelStyle(previewName, 13, ALIGN_CENTER, 1, 1, 1)
	previewName:SetText("Strawberry")

	distanceSettingsPreview = infoSettingsWindow:CreateChildWidget("label", "distancePreview", 0, true)
	ApplyLocalLabelStyle(distanceSettingsPreview, 25, ALIGN_LEFT, 1, 0, 0)
	distanceSettingsPreview:SetText("23.4m")
	distanceSettingsPreview:AddAnchor("LEFT", previewPlate, -90, 0)

	gearSettingsPreview = infoSettingsWindow:CreateChildWidget("label", "gearPreview", 0, true)
	ApplyLocalLabelStyle(gearSettingsPreview, 15, ALIGN_LEFT, 1, 1, 1)
	gearSettingsPreview:SetText("15432")
	gearSettingsPreview:AddAnchor("LEFT", previewPlate, 90, 0)

	for i = 1, 4 do
		local icon = infoSettingsWindow:CreateIconDrawable("artwork")
		icon:SetExtent(25, 25)
		icon:SetVisible(false)

		local gradeIcon = infoSettingsWindow:CreateIconDrawable("artwork")
		gradeIcon:SetExtent(25, 25)
		gradeIcon:SetVisible(false)
		gradeIcon:AddAnchor("CENTER", icon, 0, 0)

		equipmentSettingsPreview[i] = {
			icon = icon,
			gradeIcon = gradeIcon,
		}
	end

	local function setEquipmentPreviewSlot(index, slotId, xOffset, yOffset, visible)
		local preview = equipmentSettingsPreview[index]
		if preview == nil then
			return
		end

		preview.icon:RemoveAllAnchors()
		preview.icon:AddAnchor("CENTER", previewPlate, xOffset, yOffset)
		preview.gradeIcon:RemoveAllAnchors()
		preview.gradeIcon:AddAnchor("CENTER", preview.icon, 0, 0)

		if visible ~= true then
			preview.icon:SetVisible(false)
			preview.icon:ClearAllTextures()
			preview.gradeIcon:SetVisible(false)
			preview.gradeIcon:ClearAllTextures()
			return
		end

		local item = X2Equipment:GetEquippedItemTooltipInfo(slotId, false)
		if item == nil or item.icon == nil or item.icon == "" then
			preview.icon:SetVisible(false)
			preview.icon:ClearAllTextures()
			preview.gradeIcon:SetVisible(false)
			preview.gradeIcon:ClearAllTextures()
			return
		end

		preview.icon:ClearAllTextures()
		preview.icon:AddTexture(item.icon)
		preview.icon:SetVisible(true)

		preview.gradeIcon:ClearAllTextures()
		if item.gradeIcon ~= nil and item.gradeIcon ~= "" then
			preview.gradeIcon:AddTexture(item.gradeIcon)
			preview.gradeIcon:SetVisible(true)
		else
			preview.gradeIcon:SetVisible(false)
		end
	end

	local function hideEquipmentPreview()
		for i = 1, #equipmentSettingsPreview do
			equipmentSettingsPreview[i].icon:SetVisible(false)
			equipmentSettingsPreview[i].gradeIcon:SetVisible(false)
		end
	end

	local function setEquipmentPreviewLayout(settings)
		local pitch = (settings.iconSize or 25) + 2
		local previewEntries = {
			{ slotId = ES_BACKPACK, visible = settings.showGlider == true },
			{ slotId = ES_MAINHAND, visible = settings.showMainhand == true },
			{ slotId = ES_OFFHAND, visible = settings.showOffhand == true },
			{ slotId = ES_RANGED, visible = settings.showRanged == true },
		}

		for i = 1, #previewEntries do
			local preview = equipmentSettingsPreview[i]
			if preview ~= nil then
				preview.icon:SetExtent(settings.iconSize, settings.iconSize)
				preview.gradeIcon:SetExtent(settings.iconSize, settings.iconSize)
			end

			local offsetX = settings.x - (pitch * i)
			local offsetY = settings.y
			if settings.layout == "vertical" then
				offsetX = settings.x
				offsetY = settings.y + (pitch * (i - 1))
			end

			setEquipmentPreviewSlot(i, previewEntries[i].slotId, offsetX, offsetY, previewEntries[i].visible)
		end
	end

	classSettingsPreviewIcon = infoSettingsWindow:CreateIconDrawable("artwork")
	classSettingsPreviewIcon:SetExtent(22, 22)
	classSettingsPreviewIcon:AddTexture("ui/icon/icon_skill_pleasure02.dds")
	classSettingsPreviewIcon:SetVisible(true)
	classSettingsPreviewIcon:AddAnchor("LEFT", previewPlate, 90, 24)

	classSettingsPreviewLabel = infoSettingsWindow:CreateChildWidget("label", "classPreview", 0, true)
	ApplyLocalLabelStyle(classSettingsPreviewLabel, 13, ALIGN_LEFT, 1, 1, 1)
	classSettingsPreviewLabel:SetText("Blade Dancer")
	classSettingsPreviewLabel:AddAnchor("LEFT", previewPlate, 114, 24)

	castbarSettingsPreview = infoSettingsWindow:CreateColorDrawable(0.10, 0.08, 0.05, 0.98, "artwork")
	castbarSettingsPreview:SetExtent(120, 18)
	castbarSettingsPreview:AddAnchor("TOPLEFT", infoSettingsWindow, 100, 266)

	castbarSettingsPreviewFill = infoSettingsWindow:CreateColorDrawable(0.86, 0.68, 0.18, 0.95, "overlay")
	castbarSettingsPreviewFill:SetExtent(72, 12)
	castbarSettingsPreviewFill:AddAnchor("TOPLEFT", castbarSettingsPreview, 4, 3)

	castbarSettingsPreviewSpell = infoSettingsWindow:CreateChildWidget("label", "castbarSpellPreview", 0, true)
	ApplyLocalLabelStyle(castbarSettingsPreviewSpell, 13, ALIGN_LEFT, 1, 1, 1)
	castbarSettingsPreviewSpell:SetText("Meteo..")
	castbarSettingsPreviewSpell:AddAnchor("TOPLEFT", castbarSettingsPreview, 0, 20)

	castbarSettingsPreviewTime = infoSettingsWindow:CreateChildWidget("label", "castbarTimePreview", 0, true)
	ApplyLocalLabelStyle(castbarSettingsPreviewTime, 13, ALIGN_RIGHT, 1, 1, 1)
	castbarSettingsPreviewTime:SetText("1.2 / 2.0")
	castbarSettingsPreviewTime:AddAnchor("RIGHT", castbarSettingsPreview, -6, 0)

	local controlButtons = {}
	local castbarControls = {}
	local equipmentToggleButtons = {}
	local equipmentLayoutButton = nil

	local function setCastbarControlVisible(visible)
		for i = 1, #castbarControls do
			castbarControls[i]:Show(visible)
		end
	end

	local function makeInfoAdjustButton(name, text, x, y, mode, handler)
		local button = infoSettingsWindow:CreateChildWidget("button", name, 0, true)
		ApplyLocalButtonStyle(button)
		button:SetExtent(88, 30)
		button:AddAnchor("TOPLEFT", infoSettingsWindow, x, y)
		button:SetText(text)
		button:SetHandler("OnClick", function()
			if infoSettingsMode == mode then
				handler()
			end
		end)
		controlButtons[#controlButtons + 1] = { button = button, mode = mode }
		return button
	end

	makeInfoAdjustButton("distanceFontUpButton", "Font ^", 16, 310, "distance", function()
		shared.AdjustDistanceSettings("fontSize", 1)
	end)
	makeInfoAdjustButton("distanceFontDownButton", "Font v", 112, 310, "distance", function()
		shared.AdjustDistanceSettings("fontSize", -1)
	end)
	makeInfoAdjustButton("distanceRedUpButton", "Red ^", 208, 310, "distance", function()
		shared.AdjustDistanceSettings("turnRedAt", 1)
	end)
	makeInfoAdjustButton("distanceRedDownButton", "Red v", 16, 346, "distance", function()
		shared.AdjustDistanceSettings("turnRedAt", -1)
	end)
	makeInfoAdjustButton("distanceUpButton", "^", 112, 346, "distance", function()
		shared.AdjustDistanceSettings("y", -5)
	end)
	makeInfoAdjustButton("distanceLeftButton", "<", 16, 382, "distance", function()
		shared.AdjustDistanceSettings("x", -5)
	end)
	makeInfoAdjustButton("distanceDownButton", "v", 112, 382, "distance", function()
		shared.AdjustDistanceSettings("y", 5)
	end)
	makeInfoAdjustButton("distanceRightButton", ">", 208, 382, "distance", function()
		shared.AdjustDistanceSettings("x", 5)
	end)

	makeInfoAdjustButton("gearUpButton", "^", 112, 346, "gear", function()
		shared.AdjustGearSettings("y", -5)
	end)
	makeInfoAdjustButton("gearLeftButton", "<", 16, 382, "gear", function()
		shared.AdjustGearSettings("x", -5)
	end)
	makeInfoAdjustButton("gearDownButton", "v", 112, 382, "gear", function()
		shared.AdjustGearSettings("y", 5)
	end)
	makeInfoAdjustButton("gearRightButton", ">", 208, 382, "gear", function()
		shared.AdjustGearSettings("x", 5)
	end)

	equipmentToggleButtons.mainhand = makeInfoAdjustButton("equipmentMainhandButton", "Mainhand", 16, 310, "equipment", function()
		shared.ToggleEquipmentSetting("showMainhand")
	end)
	equipmentToggleButtons.offhand = makeInfoAdjustButton("equipmentOffhandButton", "Offhand", 112, 310, "equipment", function()
		shared.ToggleEquipmentSetting("showOffhand")
	end)
	equipmentToggleButtons.glider = makeInfoAdjustButton("equipmentGliderButton", "Glider", 208, 310, "equipment", function()
		shared.ToggleEquipmentSetting("showGlider")
	end)
	equipmentToggleButtons.ranged = makeInfoAdjustButton("equipmentRangedButton", "Ranged", 16, 346, "equipment", function()
		shared.ToggleEquipmentSetting("showRanged")
	end)
	equipmentLayoutButton = makeInfoAdjustButton("equipmentLayoutButton", "Horizontal", 208, 346, "equipment", function()
		shared.ToggleEquipmentLayout()
	end)
	makeInfoAdjustButton("equipmentUpButton", "^", 112, 346, "equipment", function()
		shared.AdjustEquipmentSettings("y", -5)
	end)
	makeInfoAdjustButton("equipmentLeftButton", "<", 16, 382, "equipment", function()
		shared.AdjustEquipmentSettings("x", -5)
	end)
	makeInfoAdjustButton("equipmentDownButton", "v", 112, 382, "equipment", function()
		shared.AdjustEquipmentSettings("y", 5)
	end)
	makeInfoAdjustButton("equipmentRightButton", ">", 208, 382, "equipment", function()
		shared.AdjustEquipmentSettings("x", 5)
	end)
	makeInfoAdjustButton("equipmentBiggerButton", "Bigger", 16, 418, "equipment", function()
		shared.AdjustEquipmentSettings("size", 5)
	end)
	makeInfoAdjustButton("equipmentSmallerButton", "Smaller", 112, 418, "equipment", function()
		shared.AdjustEquipmentSettings("size", -5)
	end)

	makeInfoAdjustButton("classIconToggleButton", "Icon On/Off", 16, 310, "class", function()
		shared.ToggleClassSetting("showIcon")
	end)
	makeInfoAdjustButton("classWordsToggleButton", "Words On/Off", 208, 310, "class", function()
		shared.ToggleClassSetting("showWords")
	end)
	makeInfoAdjustButton("classIconUpButton", "Icon ^", 16, 346, "class", function()
		shared.AdjustClassSettings("icon", "y", -5)
	end)
	makeInfoAdjustButton("classIconLeftButton", "Icon <", 16, 382, "class", function()
		shared.AdjustClassSettings("icon", "x", -5)
	end)
	makeInfoAdjustButton("classIconDownButton", "Icon v", 16, 418, "class", function()
		shared.AdjustClassSettings("icon", "y", 5)
	end)
	makeInfoAdjustButton("classIconRightButton", "Icon >", 112, 382, "class", function()
		shared.AdjustClassSettings("icon", "x", 5)
	end)
	makeInfoAdjustButton("classWordsUpButton", "Words ^", 208, 346, "class", function()
		shared.AdjustClassSettings("label", "y", -5)
	end)
	makeInfoAdjustButton("classWordsLeftButton", "Words <", 208, 382, "class", function()
		shared.AdjustClassSettings("label", "x", -5)
	end)
	makeInfoAdjustButton("classWordsDownButton", "Words v", 208, 418, "class", function()
		shared.AdjustClassSettings("label", "y", 5)
	end)
	makeInfoAdjustButton("classWordsRightButton", "Words >", 112, 418, "class", function()
		shared.AdjustClassSettings("label", "x", 5)
	end)

	makeInfoAdjustButton("castbarUpButton", "^", 112, 382, "castbar", function()
		shared.AdjustCastbarSettings("y", -5)
	end)
	makeInfoAdjustButton("castbarLeftButton", "<", 16, 418, "castbar", function()
		shared.AdjustCastbarSettings("x", -5)
	end)
	makeInfoAdjustButton("castbarDownButton", "v", 112, 418, "castbar", function()
		shared.AdjustCastbarSettings("y", 5)
	end)
	makeInfoAdjustButton("castbarRightButton", ">", 208, 418, "castbar", function()
		shared.AdjustCastbarSettings("x", 5)
	end)

	local widthLabel = infoSettingsWindow:CreateChildWidget("label", "castbarWidthLabel", 0, true)
	widthLabel:AddAnchor("TOPLEFT", infoSettingsWindow, 16, 318)
	widthLabel:SetExtent(54, 24)
	ApplyLocalLabelStyle(widthLabel, 13, ALIGN_LEFT, 1, 1, 1)
	SetWidgetTextColorByKey(widthLabel, "default")
	widthLabel:SetText("Width")
	castbarControls[#castbarControls + 1] = widthLabel

	castbarWidthEdit = CreateLocalEditBox(infoSettingsWindow, "castbarWidthEdit", 70)
	castbarWidthEdit:AddAnchor("TOPLEFT", infoSettingsWindow, 76, 310)
	castbarControls[#castbarControls + 1] = castbarWidthEdit

	local heightLabel = infoSettingsWindow:CreateChildWidget("label", "castbarHeightLabel", 0, true)
	heightLabel:AddAnchor("TOPLEFT", infoSettingsWindow, 160, 318)
	heightLabel:SetExtent(54, 24)
	ApplyLocalLabelStyle(heightLabel, 13, ALIGN_LEFT, 1, 1, 1)
	SetWidgetTextColorByKey(heightLabel, "default")
	heightLabel:SetText("Height")
	castbarControls[#castbarControls + 1] = heightLabel

	castbarHeightEdit = CreateLocalEditBox(infoSettingsWindow, "castbarHeightEdit", 70)
	castbarHeightEdit:AddAnchor("TOPLEFT", infoSettingsWindow, 224, 310)
	castbarControls[#castbarControls + 1] = castbarHeightEdit

	local applyCastbarButton = infoSettingsWindow:CreateChildWidget("button", "applyCastbarButton", 0, true)
	ApplyLocalButtonStyle(applyCastbarButton)
	applyCastbarButton:SetExtent(88, 30)
	applyCastbarButton:AddAnchor("TOPLEFT", infoSettingsWindow, 16, 346)
	applyCastbarButton:SetText("Apply Size")
	castbarControls[#castbarControls + 1] = applyCastbarButton

	local function applyCastbarSize()
		local width = tonumber(castbarWidthEdit:GetText() or "")
		local height = tonumber(castbarHeightEdit:GetText() or "")
		if width == nil or height == nil then
			X2Chat:DispatchChatMessage(CMF_SYSTEM, "Extended Plates castbar size must use numbers.")
			return
		end

		local settings = shared.SetCastbarSettings(width, height)
		castbarWidthEdit:SetText(tostring(settings.width))
		castbarHeightEdit:SetText(tostring(settings.height))
	end

	applyCastbarButton:SetHandler("OnClick", function()
		if infoSettingsMode == "castbar" then
			applyCastbarSize()
		end
	end)
	castbarWidthEdit:SetHandler("OnEnterPressed", applyCastbarSize)
	castbarHeightEdit:SetHandler("OnEnterPressed", applyCastbarSize)

	function infoSettingsWindow:OnUpdate(dt)
		if not self:IsVisible() then
			return
		end

		self.elapsed = (self.elapsed or 0) + dt
		if self.elapsed < 0.15 then
			return
		end
		self.elapsed = 0

		if infoSettingsMode == "distance" then
			local settings = shared.GetDistanceSettings()
			infoSettingsTitle:SetText("Distance Settings")
			infoSettingsStatus:SetText(
				string.format(
					"Font Size: %d\nTurn Red At: %d\nPosition X: %d\nPosition Y: %d",
					settings.fontSize,
					settings.turnRedAt,
					settings.x,
					settings.y
				)
			)
			infoSettingsMessage:SetText("Use the buttons below to tune the target distance label.")
			distanceSettingsPreview.style:SetFontSize(settings.fontSize)
			if 23.4 > settings.turnRedAt then
				distanceSettingsPreview.style:SetColor(1, 0, 0, 1)
			else
				distanceSettingsPreview.style:SetColor(1, 1, 1, 1)
			end
			distanceSettingsPreview:RemoveAllAnchors()
			distanceSettingsPreview:AddAnchor("LEFT", previewPlate, settings.x, settings.y)
			distanceSettingsPreview:Show(true)
			gearSettingsPreview:Show(false)
			hideEquipmentPreview()
			classSettingsPreviewIcon:SetVisible(false)
			classSettingsPreviewLabel:Show(false)
			castbarSettingsPreview:Show(false)
			castbarSettingsPreviewFill:Show(false)
			castbarSettingsPreviewSpell:Show(false)
			castbarSettingsPreviewTime:Show(false)
			setCastbarControlVisible(false)
		elseif infoSettingsMode == "gear" then
			local settings = shared.GetGearSettings()
			infoSettingsTitle:SetText("Gear Settings")
			infoSettingsStatus:SetText(
				string.format(
					"Position X: %d\nPosition Y: %d",
					settings.x,
					settings.y
				)
			)
			infoSettingsMessage:SetText("Use the arrows below to move the gearscore label.")
			distanceSettingsPreview:Show(false)
			gearSettingsPreview:RemoveAllAnchors()
			gearSettingsPreview:AddAnchor("LEFT", previewPlate, settings.x, settings.y)
			gearSettingsPreview:Show(true)
			hideEquipmentPreview()
			classSettingsPreviewIcon:SetVisible(false)
			classSettingsPreviewLabel:Show(false)
			castbarSettingsPreview:Show(false)
			castbarSettingsPreviewFill:Show(false)
			castbarSettingsPreviewSpell:Show(false)
			castbarSettingsPreviewTime:Show(false)
			setCastbarControlVisible(false)
		elseif infoSettingsMode == "equipment" then
			local settings = shared.GetEquipmentSettings()
			infoSettingsTitle:SetText("Equipment Settings")
			infoSettingsStatus:SetText(
				string.format(
					"Position X: %d\nPosition Y: %d\nSize: %d  Layout: %s\nMH: %s  OH: %s\nGL: %s  RG: %s",
					settings.x,
					settings.y,
					settings.iconSize,
					settings.layout,
					settings.showMainhand and "ON" or "OFF",
					settings.showOffhand and "ON" or "OFF",
					settings.showGlider and "ON" or "OFF",
					settings.showRanged and "ON" or "OFF"
				)
			)
			infoSettingsMessage:SetText("Move the self equipment icons and toggle which slots are shown.")
			distanceSettingsPreview:Show(false)
			gearSettingsPreview:Show(false)
			setEquipmentPreviewLayout(settings)
			classSettingsPreviewIcon:SetVisible(false)
			classSettingsPreviewLabel:Show(false)
			castbarSettingsPreview:Show(false)
			castbarSettingsPreviewFill:Show(false)
			castbarSettingsPreviewSpell:Show(false)
			castbarSettingsPreviewTime:Show(false)
			setCastbarControlVisible(false)
			equipmentToggleButtons.mainhand:SetText("Mainhand [" .. (settings.showMainhand and "ON" or "OFF") .. "]")
			equipmentToggleButtons.offhand:SetText("Offhand [" .. (settings.showOffhand and "ON" or "OFF") .. "]")
			equipmentToggleButtons.glider:SetText("Glider [" .. (settings.showGlider and "ON" or "OFF") .. "]")
			equipmentToggleButtons.ranged:SetText("Ranged [" .. (settings.showRanged and "ON" or "OFF") .. "]")
			equipmentLayoutButton:SetText(settings.layout == "vertical" and "Vertical" or "Horizontal")
		elseif infoSettingsMode == "class" then
			local settings = shared.GetClassSettings()
			infoSettingsTitle:SetText("Class Settings")
			infoSettingsStatus:SetText(
				string.format(
					"Icon: %s\nX: %d  Y: %d\nWords: %s\nX: %d  Y: %d",
					settings.showIcon and "ON" or "OFF",
					settings.iconX,
					settings.iconY,
					settings.showWords and "ON" or "OFF",
					settings.labelX,
					settings.labelY
				)
			)
			infoSettingsMessage:SetText("Move icon and words separately, or toggle them off.")
			distanceSettingsPreview:Show(false)
			gearSettingsPreview:Show(false)
			hideEquipmentPreview()
			classSettingsPreviewIcon:RemoveAllAnchors()
			classSettingsPreviewIcon:AddAnchor("LEFT", previewPlate, settings.iconX, settings.iconY)
			classSettingsPreviewIcon:SetVisible(settings.showIcon == true)
			classSettingsPreviewLabel:RemoveAllAnchors()
			classSettingsPreviewLabel:AddAnchor("LEFT", previewPlate, settings.labelX, settings.labelY)
			classSettingsPreviewLabel:Show(settings.showWords == true)
			castbarSettingsPreview:Show(false)
			castbarSettingsPreviewFill:Show(false)
			castbarSettingsPreviewSpell:Show(false)
			castbarSettingsPreviewTime:Show(false)
			setCastbarControlVisible(false)
		else
			local settings = shared.GetCastbarSettings()
			infoSettingsTitle:SetText("Castbar Settings")
			infoSettingsStatus:SetText(
				string.format(
					"Width: %d\nHeight: %d\nPosition X: %d\nPosition Y: %d",
					settings.width,
					settings.height,
					settings.x,
					settings.y
				)
			)
			infoSettingsMessage:SetText("Use the input fields for size and arrows to move the castbar on the nameplate.")
			distanceSettingsPreview:Show(false)
			gearSettingsPreview:Show(false)
			hideEquipmentPreview()
			classSettingsPreviewIcon:SetVisible(false)
			classSettingsPreviewLabel:Show(false)
			castbarSettingsPreview:RemoveAllAnchors()
			castbarSettingsPreview:SetExtent(settings.width, settings.height)
			castbarSettingsPreview:AddAnchor("TOPLEFT", previewPlate, settings.x, 34 + settings.y)
			castbarSettingsPreviewFill:RemoveAllAnchors()
			castbarSettingsPreviewFill:SetExtent(
				math.max(8, math.floor((settings.width - 8) * 0.6)),
				math.max(6, settings.height - 6)
			)
			castbarSettingsPreviewFill:AddAnchor("TOPLEFT", castbarSettingsPreview, 4, 3)
			castbarSettingsPreviewSpell:RemoveAllAnchors()
			castbarSettingsPreviewSpell:AddAnchor("TOPLEFT", castbarSettingsPreview, 0, 20)
			castbarSettingsPreviewSpell:SetExtent(settings.width, 18)
			castbarSettingsPreviewTime:RemoveAllAnchors()
			castbarSettingsPreviewTime:AddAnchor("RIGHT", castbarSettingsPreview, -6, 0)
			castbarSettingsPreviewTime:SetExtent(72, 18)
			castbarSettingsPreview:Show(true)
			castbarSettingsPreviewFill:Show(true)
			castbarSettingsPreviewSpell:Show(true)
			castbarSettingsPreviewTime:Show(true)
			setCastbarControlVisible(true)
		end

		for i = 1, #controlButtons do
			local entry = controlButtons[i]
			entry.button:Show(entry.mode == infoSettingsMode)
		end
	end

	infoSettingsWindow:SetHandler("OnUpdate", infoSettingsWindow.OnUpdate)
end

do
	CreateWindowBackground(drawLinesSettingsWindow)

	local title = drawLinesSettingsWindow:CreateChildWidget("label", "title", 0, true)
	title:AddAnchor("TOPLEFT", drawLinesSettingsWindow, 16, 12)
	title:SetExtent(220, 24)
	ApplyLocalLabelStyle(title, 18, ALIGN_LEFT, 1, 0.97, 0.92)
	SetWidgetTextColorByKey(title, "brown")
	title:SetText("Draw Lines")

	CreateCloseButton(drawLinesSettingsWindow, "closeButton", function()
		drawLinesSettingsWindow:Show(false)
	end)

	drawLinesSettingsWindow:EnableDrag(true)
	drawLinesSettingsWindow:SetHandler("OnDragStart", function(self)
		self:StartMoving()
		return true
	end)
	drawLinesSettingsWindow:SetHandler("OnDragStop", function(self)
		self:StopMovingOrSizing()
	end)

	local function makePairButton(index, key, text)
		local button = drawLinesSettingsWindow:CreateChildWidget("button", "pairButton", index, true)
		ApplyLocalButtonStyle(button)
		button:SetExtent(286, 28)
		button:AddAnchor("TOPLEFT", drawLinesSettingsWindow, 16, 46 + ((index - 1) * 34))
		button:SetText(text)
		button:SetHandler("OnClick", function()
			drawLinesPairs[key] = not drawLinesPairs[key]
			SaveDrawLinesSettings()
		end)
		drawLinesPairButtons[key] = button
	end

	makePairButton(1, "target", "target")
	makePairButton(2, "targetoftarget", "targetoftarget")
	makePairButton(3, "watchtarget", "watchtarget")
	makePairButton(4, "watchtargettarget", "watchtargettarget")

	targetLineModeButton = drawLinesSettingsWindow:CreateChildWidget("button", "targetLineModeButton", 0, true)
	ApplyLocalButtonStyle(targetLineModeButton)
	targetLineModeButton:SetExtent(286, 28)
	targetLineModeButton:AddAnchor("TOPLEFT", drawLinesSettingsWindow, 16, 182)
	targetLineModeButton:SetHandler("OnClick", function()
		targetToTargetLineFromPlayer = not targetToTargetLineFromPlayer
		SaveDrawLinesSettings()
	end)

	trackLineModeButton = drawLinesSettingsWindow:CreateChildWidget("button", "trackLineModeButton", 0, true)
	ApplyLocalButtonStyle(trackLineModeButton)
	trackLineModeButton:SetExtent(286, 28)
	trackLineModeButton:AddAnchor("TOPLEFT", drawLinesSettingsWindow, 16, 214)
	trackLineModeButton:SetHandler("OnClick", function()
		watchToTargetLineFromPlayer = not watchToTargetLineFromPlayer
		SaveDrawLinesSettings()
	end)

	local densityTitle = drawLinesSettingsWindow:CreateChildWidget("label", "densityTitle", 0, true)
	densityTitle:AddAnchor("TOPLEFT", drawLinesSettingsWindow, 16, 248)
	densityTitle:SetExtent(200, 22)
	ApplyLocalLabelStyle(densityTitle, 14, ALIGN_LEFT, 0.96, 0.90, 0.78)
	SetWidgetTextColorByKey(densityTitle, "brown")
	densityTitle:SetText("Line density")

	local minText = drawLinesSettingsWindow:CreateChildWidget("label", "minText", 0, true)
	minText:AddAnchor("TOPLEFT", drawLinesSettingsWindow, 16, 278)
	minText:SetExtent(50, 22)
	ApplyLocalLabelStyle(minText, 14, ALIGN_LEFT, 1, 1, 1)
	SetWidgetTextColorByKey(minText, "default")
	minText:SetText("Min:")

	drawLinesMinLabel = drawLinesSettingsWindow:CreateChildWidget("label", "minValue", 0, true)
	drawLinesMinLabel:AddAnchor("TOPLEFT", drawLinesSettingsWindow, 62, 278)
	drawLinesMinLabel:SetExtent(60, 22)
	ApplyLocalLabelStyle(drawLinesMinLabel, 14, ALIGN_LEFT, 1, 1, 1)
	SetWidgetTextColorByKey(drawLinesMinLabel, "default")

	local minMinus = drawLinesSettingsWindow:CreateChildWidget("button", "minMinus", 0, true)
	ApplyLocalButtonStyle(minMinus)
	minMinus:SetExtent(34, 24)
	minMinus:AddAnchor("TOPLEFT", drawLinesSettingsWindow, 132, 276)
	minMinus:SetText("-")
	minMinus:SetHandler("OnClick", function()
		drawLinesMinDotCount = math.max(1, drawLinesMinDotCount - 1)
		if drawLinesMaxDotCount < drawLinesMinDotCount then
			drawLinesMaxDotCount = drawLinesMinDotCount
		end
		SaveDrawLinesSettings()
	end)

	local minPlus = drawLinesSettingsWindow:CreateChildWidget("button", "minPlus", 0, true)
	ApplyLocalButtonStyle(minPlus)
	minPlus:SetExtent(34, 24)
	minPlus:AddAnchor("TOPLEFT", drawLinesSettingsWindow, 222, 276)
	minPlus:SetText("+")
	minPlus:SetHandler("OnClick", function()
		drawLinesMinDotCount = drawLinesMinDotCount + 1
		if drawLinesMaxDotCount < drawLinesMinDotCount then
			drawLinesMaxDotCount = drawLinesMinDotCount
		end
		SaveDrawLinesSettings()
	end)

	local maxText = drawLinesSettingsWindow:CreateChildWidget("label", "maxText", 0, true)
	maxText:AddAnchor("TOPLEFT", drawLinesSettingsWindow, 16, 312)
	maxText:SetExtent(50, 22)
	ApplyLocalLabelStyle(maxText, 14, ALIGN_LEFT, 1, 1, 1)
	SetWidgetTextColorByKey(maxText, "default")
	maxText:SetText("Max:")

	drawLinesMaxLabel = drawLinesSettingsWindow:CreateChildWidget("label", "maxValue", 0, true)
	drawLinesMaxLabel:AddAnchor("TOPLEFT", drawLinesSettingsWindow, 62, 312)
	drawLinesMaxLabel:SetExtent(60, 22)
	ApplyLocalLabelStyle(drawLinesMaxLabel, 14, ALIGN_LEFT, 1, 1, 1)
	SetWidgetTextColorByKey(drawLinesMaxLabel, "default")

	local maxMinus = drawLinesSettingsWindow:CreateChildWidget("button", "maxMinus", 0, true)
	ApplyLocalButtonStyle(maxMinus)
	maxMinus:SetExtent(34, 24)
	maxMinus:AddAnchor("TOPLEFT", drawLinesSettingsWindow, 132, 310)
	maxMinus:SetText("-")
	maxMinus:SetHandler("OnClick", function()
		drawLinesMaxDotCount = math.max(drawLinesMinDotCount, drawLinesMaxDotCount - 1)
		SaveDrawLinesSettings()
	end)

	local maxPlus = drawLinesSettingsWindow:CreateChildWidget("button", "maxPlus", 0, true)
	ApplyLocalButtonStyle(maxPlus)
	maxPlus:SetExtent(34, 24)
	maxPlus:AddAnchor("TOPLEFT", drawLinesSettingsWindow, 222, 310)
	maxPlus:SetText("+")
	maxPlus:SetHandler("OnClick", function()
		drawLinesMaxDotCount = drawLinesMaxDotCount + 1
		SaveDrawLinesSettings()
	end)

	local dotSizeText = drawLinesSettingsWindow:CreateChildWidget("label", "dotSizeText", 0, true)
	dotSizeText:AddAnchor("TOPLEFT", drawLinesSettingsWindow, 16, 338)
	dotSizeText:SetExtent(70, 22)
	ApplyLocalLabelStyle(dotSizeText, 14, ALIGN_LEFT, 1, 1, 1)
	SetWidgetTextColorByKey(dotSizeText, "default")
	dotSizeText:SetText("Dot size:")

	drawLinesDotSizeLabel = drawLinesSettingsWindow:CreateChildWidget("label", "dotSizeValue", 0, true)
	drawLinesDotSizeLabel:AddAnchor("TOPLEFT", drawLinesSettingsWindow, 88, 338)
	drawLinesDotSizeLabel:SetExtent(60, 22)
	ApplyLocalLabelStyle(drawLinesDotSizeLabel, 14, ALIGN_LEFT, 1, 1, 1)
	SetWidgetTextColorByKey(drawLinesDotSizeLabel, "default")

	local dotSizeMinus = drawLinesSettingsWindow:CreateChildWidget("button", "dotSizeMinus", 0, true)
	ApplyLocalButtonStyle(dotSizeMinus)
	dotSizeMinus:SetExtent(34, 24)
	dotSizeMinus:AddAnchor("TOPLEFT", drawLinesSettingsWindow, 132, 336)
	dotSizeMinus:SetText("-")
	dotSizeMinus:SetHandler("OnClick", function()
		drawLinesDotFontSize = math.max(8, drawLinesDotFontSize - 1)
		SaveDrawLinesSettings()
	end)

	local dotSizePlus = drawLinesSettingsWindow:CreateChildWidget("button", "dotSizePlus", 0, true)
	ApplyLocalButtonStyle(dotSizePlus)
	dotSizePlus:SetExtent(34, 24)
	dotSizePlus:AddAnchor("TOPLEFT", drawLinesSettingsWindow, 222, 336)
	dotSizePlus:SetText("+")
	dotSizePlus:SetHandler("OnClick", function()
		drawLinesDotFontSize = drawLinesDotFontSize + 1
		SaveDrawLinesSettings()
	end)

	local dotAlphaText = drawLinesSettingsWindow:CreateChildWidget("label", "dotAlphaText", 0, true)
	dotAlphaText:AddAnchor("TOPLEFT", drawLinesSettingsWindow, 16, 372)
	dotAlphaText:SetExtent(80, 22)
	ApplyLocalLabelStyle(dotAlphaText, 14, ALIGN_LEFT, 1, 1, 1)
	SetWidgetTextColorByKey(dotAlphaText, "default")
	dotAlphaText:SetText("Transp:")

	drawLinesDotAlphaLabel = drawLinesSettingsWindow:CreateChildWidget("label", "dotAlphaValue", 0, true)
	drawLinesDotAlphaLabel:AddAnchor("TOPLEFT", drawLinesSettingsWindow, 88, 372)
	drawLinesDotAlphaLabel:SetExtent(60, 22)
	ApplyLocalLabelStyle(drawLinesDotAlphaLabel, 14, ALIGN_LEFT, 1, 1, 1)
	SetWidgetTextColorByKey(drawLinesDotAlphaLabel, "default")

	local dotAlphaMinus = drawLinesSettingsWindow:CreateChildWidget("button", "dotAlphaMinus", 0, true)
	ApplyLocalButtonStyle(dotAlphaMinus)
	dotAlphaMinus:SetExtent(34, 24)
	dotAlphaMinus:AddAnchor("TOPLEFT", drawLinesSettingsWindow, 132, 370)
	dotAlphaMinus:SetText("-")
	dotAlphaMinus:SetHandler("OnClick", function()
		drawLinesDotAlpha = drawLinesDotAlpha - 0.1
		if drawLinesDotAlpha < 0.1 then
			drawLinesDotAlpha = 0.1
		end
		drawLinesDotAlpha = math.floor((drawLinesDotAlpha * 10) + 0.5) / 10
		SaveDrawLinesSettings()
	end)

	local dotAlphaPlus = drawLinesSettingsWindow:CreateChildWidget("button", "dotAlphaPlus", 0, true)
	ApplyLocalButtonStyle(dotAlphaPlus)
	dotAlphaPlus:SetExtent(34, 24)
	dotAlphaPlus:AddAnchor("TOPLEFT", drawLinesSettingsWindow, 222, 370)
	dotAlphaPlus:SetText("+")
	dotAlphaPlus:SetHandler("OnClick", function()
		drawLinesDotAlpha = drawLinesDotAlpha + 0.1
		if drawLinesDotAlpha > 1.0 then
			drawLinesDotAlpha = 1.0
		end
		drawLinesDotAlpha = math.floor((drawLinesDotAlpha * 10) + 0.5) / 10
		SaveDrawLinesSettings()
	end)

	local showTrackAggroInPaneButton = drawLinesSettingsWindow:CreateChildWidget("button", "showTrackAggroInPaneButton", 0, true)
	ApplyLocalButtonStyle(showTrackAggroInPaneButton)
	showTrackAggroInPaneButton:SetExtent(286, 28)
	showTrackAggroInPaneButton:AddAnchor("TOPLEFT", drawLinesSettingsWindow, 16, 406)
	showTrackAggroInPaneButton:SetHandler("OnClick", function()
		showTracktargetAggro = not showTracktargetAggro
		SaveDrawLinesSettings()
	end)

	local lockAggroButton = drawLinesSettingsWindow:CreateChildWidget("button", "lockAggroButton", 0, true)
	ApplyLocalButtonStyle(lockAggroButton)
	lockAggroButton:SetExtent(286, 28)
	lockAggroButton:AddAnchor("TOPLEFT", drawLinesSettingsWindow, 16, 438)
	lockAggroButton:SetHandler("OnClick", function()
		lockTracktargetAggro = not lockTracktargetAggro
		ApplyTracktargetAggroLockState()
		SaveDrawLinesSettings()
	end)

	local showTrackDistanceButton = drawLinesSettingsWindow:CreateChildWidget("button", "showTrackDistanceButton", 0, true)
	ApplyLocalButtonStyle(showTrackDistanceButton)
	showTrackDistanceButton:SetExtent(286, 28)
	showTrackDistanceButton:AddAnchor("TOPLEFT", drawLinesSettingsWindow, 16, 470)
	showTrackDistanceButton:SetHandler("OnClick", function()
		showTracktargetDistance = not showTracktargetDistance
		SaveDrawLinesSettings()
	end)

	local lockTrackDistanceButton = drawLinesSettingsWindow:CreateChildWidget("button", "lockTrackDistanceButton", 0, true)
	ApplyLocalButtonStyle(lockTrackDistanceButton)
	lockTrackDistanceButton:SetExtent(286, 28)
	lockTrackDistanceButton:AddAnchor("TOPLEFT", drawLinesSettingsWindow, 16, 502)
	lockTrackDistanceButton:SetHandler("OnClick", function()
		lockTracktargetDistance = not lockTracktargetDistance
		ApplyTracktargetDistanceLockState()
		SaveDrawLinesSettings()
	end)

	function drawLinesSettingsWindow:OnUpdate(dt)
		if not self:IsVisible() then
			return
		end
		for _, key in ipairs(drawLinesPairOrder) do
			local btn = drawLinesPairButtons[key]
			if btn ~= nil then
				btn:SetText(DrawPairButtonText(key))
			end
		end
		if targetLineModeButton ~= nil then
			targetLineModeButton:SetText(
				targetToTargetLineFromPlayer and "TargetLineFromPlayer" or "TargetLineFromTarget"
			)
		end
		if trackLineModeButton ~= nil then
			trackLineModeButton:SetText(
				watchToTargetLineFromPlayer and "TrackLineFromPlayer" or "TrackLineFromTarget"
			)
		end
		drawLinesMinLabel:SetText(tostring(drawLinesMinDotCount))
		drawLinesMaxLabel:SetText(tostring(drawLinesMaxDotCount))
		if drawLinesDotSizeLabel ~= nil then
			drawLinesDotSizeLabel:SetText(tostring(drawLinesDotFontSize))
		end
		if drawLinesDotAlphaLabel ~= nil then
			drawLinesDotAlphaLabel:SetText(string.format("%.1f", drawLinesDotAlpha))
		end
		showTrackAggroInPaneButton:SetText("Show Tracktarget Aggro [" .. (showTracktargetAggro and "ON" or "OFF") .. "]")
		lockAggroButton:SetText("Lock Tracktarget Aggro [" .. (lockTracktargetAggro and "ON" or "OFF") .. "]")
		showTrackDistanceButton:SetText(TracktargetDistanceButtonText())
		lockTrackDistanceButton:SetText("Lock Distance to Tracktarget [" .. (lockTracktargetDistance and "ON" or "OFF") .. "]")
	end
	drawLinesSettingsWindow:SetHandler("OnUpdate", drawLinesSettingsWindow.OnUpdate)
end

do
	CreateWindowBackground(positionWindow)

	local title = positionWindow:CreateChildWidget("label", "title", 0, true)
	title:AddAnchor("TOPLEFT", positionWindow, 16, 12)
	title:SetExtent(150, 24)
	ApplyLocalLabelStyle(title, 18, ALIGN_LEFT, 1, 0.97, 0.92)
	SetWidgetTextColorByKey(title, "brown")
	title:SetText("Position")

	CreateCloseButton(positionWindow, "closeButton", function()
		positionWindow:Show(false)
	end)

	positionWindow:EnableDrag(true)
	positionWindow:SetHandler("OnDragStart", function(self)
		self:StartMoving()
		return true
	end)
	positionWindow:SetHandler("OnDragStop", function(self)
		self:StopMovingOrSizing()
	end)

	local function makePositionModeButton(index, scope, effectType, text)
		local button = positionWindow:CreateChildWidget("button", "modeButton", index, true)
		ApplyLocalButtonStyle(button)
		button:SetExtent(SIMPLE_BUTTON_WIDTH, SIMPLE_BUTTON_HEIGHT)
		local col = (index - 1) % 2
		local row = math.floor((index - 1) / 2)
		button:AddAnchor("TOPLEFT", positionWindow, 16 + (col * 116), 48 + (row * 34))
		button:SetText(text)
		button:SetHandler("OnClick", function()
			positionModeScope = scope
			positionModeEffect = effectType
		end)
		positionModeButtons[#positionModeButtons + 1] = {
			button = button,
			scope = scope,
			effectType = effectType,
			baseText = text,
		}
	end

	makePositionModeButton(1, "target", "buff", "Target Buffs")
	makePositionModeButton(2, "target", "debuff", "Target Debuffs")
	makePositionModeButton(3, "self", "buff", "Self Buffs")
	makePositionModeButton(4, "self", "debuff", "Self Debuffs")
	makePositionModeButton(5, "self", "hidden", "Self Hidden")

	positionStatusLabel = positionWindow:CreateChildWidget("label", "status", 0, true)
	positionStatusLabel:AddAnchor("TOPLEFT", positionWindow, 16, 156)
	positionStatusLabel:SetExtent(228, 24)
	ApplyLocalLabelStyle(positionStatusLabel, 14, ALIGN_LEFT, 0.96, 0.90, 0.78)
	SetWidgetTextColorByKey(positionStatusLabel, "brown")

	positionGrowthButton = positionWindow:CreateChildWidget("button", "growthButton", 0, true)
	ApplyLocalButtonStyle(positionGrowthButton)
	positionGrowthButton:SetExtent(228, 24)
	positionGrowthButton:AddAnchor("TOPLEFT", positionWindow, 16, 182)
	positionGrowthButton:SetText("Horizontal R")
	positionGrowthButton:SetHandler("OnClick", function()
		shared.CycleIconGrowth(positionModeScope, positionModeEffect)
	end)

	local previewOffsetX = 16
	local previewOffsetY = 206

	local previewBg = positionWindow:CreateColorDrawable(0.12, 0.10, 0.08, 0.65, "background")
	previewBg:AddAnchor("TOPLEFT", positionWindow, previewOffsetX, previewOffsetY)
	previewBg:SetExtent(228, 86)

	positionPreviewOrigin = CreateEmptyWindow("targetDebuffTrackerPositionPreviewOrigin", "UIParent")
	positionPreviewOrigin:SetExtent(1, 1)
	positionPreviewOrigin:AddAnchor("TOPLEFT", positionWindow, previewOffsetX + 34, previewOffsetY + 30)
	positionPreviewOrigin:Show(true)

	positionPreviewBox = positionWindow:CreateColorDrawable(0.28, 0.42, 0.18, 0.95, "artwork")
	positionPreviewBox:SetExtent(80, 30)
	positionPreviewBox:AddAnchor("TOPLEFT", positionPreviewOrigin, 14, 10)

	local previewBoxBorderTop = positionWindow:CreateColorDrawable(0.84, 0.88, 0.74, 0.9, "overlay")
	previewBoxBorderTop:SetExtent(80, 1)
	previewBoxBorderTop:AddAnchor("TOPLEFT", positionPreviewBox, 0, 0)
	local previewBoxBorderBottom = positionWindow:CreateColorDrawable(0.20, 0.26, 0.14, 0.9, "overlay")
	previewBoxBorderBottom:SetExtent(80, 1)
	previewBoxBorderBottom:AddAnchor("BOTTOMLEFT", positionPreviewBox, 0, 0)
	local previewBoxBorderLeft = positionWindow:CreateColorDrawable(0.84, 0.88, 0.74, 0.9, "overlay")
	previewBoxBorderLeft:SetExtent(1, 30)
	previewBoxBorderLeft:AddAnchor("TOPLEFT", positionPreviewBox, 0, 0)
	local previewBoxBorderRight = positionWindow:CreateColorDrawable(0.20, 0.26, 0.14, 0.9, "overlay")
	previewBoxBorderRight:SetExtent(1, 30)
	previewBoxBorderRight:AddAnchor("TOPRIGHT", positionPreviewBox, 0, 0)

	positionPreviewName = positionWindow:CreateChildWidget("label", "previewName", 0, true)
	positionPreviewName:AddAnchor("TOPLEFT", positionPreviewBox, 6, 6)
	positionPreviewName:SetExtent(68, 18)
	ApplyLocalLabelStyle(positionPreviewName, 13, ALIGN_CENTER, 1, 1, 1)
	positionPreviewName:SetText("Strawberry")

	for i = 1, 4 do
		local icon = positionWindow:CreateIconDrawable("artwork")
		icon:SetExtent(25, 25)
		icon:SetVisible(true)
		positionPreviewIcons[i] = icon
	end

	local function makeAdjustButton(name, text, x, y, axis, delta)
		local button = positionWindow:CreateChildWidget("button", name, 0, true)
		ApplyLocalButtonStyle(button)
		button:SetExtent(70, 28)
		button:AddAnchor("TOPLEFT", positionWindow, x, y)
		button:SetText(text)
		button:SetHandler("OnClick", function()
			shared.AdjustIconSettings(positionModeScope, positionModeEffect, axis, delta)
		end)
	end

	makeAdjustButton("upButton", "^", 94, 304, "y", -5)
	makeAdjustButton("leftButton", "<", 16, 338, "x", -5)
	makeAdjustButton("rightButton", ">", 172, 338, "x", 5)
	makeAdjustButton("downButton", "v", 94, 372, "y", 5)
	makeAdjustButton("biggerButton", "Bigger", 16, 400, "size", 5)
	makeAdjustButton("smallerButton", "Smaller", 126, 400, "size", -5)

	function positionWindow:OnUpdate(dt)
		if not self:IsVisible() then
			return
		end

		self.elapsed = (self.elapsed or 0) + dt
		if self.elapsed < 0.15 then
			return
		end
		self.elapsed = 0

		local current = shared.GetIconSettings(positionModeScope, positionModeEffect)
		local layout = GetPreviewLayout(positionModeEffect)
		positionStatusLabel:SetText(
			string.format(
				"%s  X: %d  Y: %d  Size: %d",
				categoryTitle(positionModeScope, positionModeEffect),
				current.x,
				current.y,
				current.iconSize
			)
		)
		positionGrowthButton:SetText(GrowthModeLabel(current.growth))

		local previewTexture = GetPreviewIconPath(positionModeEffect)
		positionPreviewOrigin:RemoveAllAnchors()
		positionPreviewOrigin:AddAnchor(
			"TOPLEFT",
			positionWindow,
			previewOffsetX + layout.originX,
			previewOffsetY + layout.originY
		)

		positionPreviewBox:RemoveAllAnchors()
		positionPreviewBox:SetExtent(layout.nameplateWidth, layout.nameplateHeight)
		positionPreviewBox:AddAnchor(
			"TOPLEFT",
			positionPreviewOrigin,
			layout.nameplateX,
			layout.nameplateY
		)

		positionPreviewName:SetExtent(layout.nameplateWidth - 12, 18)
		for i = 1, #positionPreviewIcons do
			local icon = positionPreviewIcons[i]
			local iconX, iconY = shared.GetIconOffsetForIndex(current, i - 1)
			icon:ClearAllTextures()
			icon:AddTexture(previewTexture)
			icon:SetExtent(current.iconSize, current.iconSize)
			icon:RemoveAllAnchors()
			icon:AddAnchor("LEFT", positionPreviewOrigin, iconX, iconY)
		end

		for i = 1, #positionModeButtons do
			local entry = positionModeButtons[i]
			local active = entry.scope == positionModeScope and entry.effectType == positionModeEffect
			entry.button:SetText((active and "> " or "") .. entry.baseText)
		end
	end

	positionWindow:SetHandler("OnUpdate", positionWindow.OnUpdate)
end

for i = 1, 8 do
	local rowY = 122 + ((i - 1) * 22)
	local icon = managerWindow:CreateIconDrawable("artwork")
	icon:SetExtent(18, 18)
	icon:AddAnchor("TOPLEFT", managerWindow, 245, rowY)
	icon:SetVisible(false)

	local label = managerWindow:CreateChildWidget("label", "trackedRowLabel", i, true)
	label:AddAnchor("TOPLEFT", managerWindow, 269, rowY)
	label:SetExtent(350, 20)
	ApplyLocalLabelStyle(label, 14, ALIGN_LEFT, 1, 1, 1)
	SetWidgetTextColorByKey(label, "default")

	local button = managerWindow:CreateChildWidget("button", "trackedRowButton", i, true)
	button:SetText("-")
	ApplyLocalButtonStyle(button)
	button:SetExtent(78, 22)
	button:AddAnchor("TOPRIGHT", managerWindow, -18, rowY - 2)

	trackedRows[i] = {
		icon = icon,
		label = label,
		button = button,
		entry = nil,
	}
end

for i = 1, 10 do
	local rowY = 336 + ((i - 1) * 22)
	local icon = managerWindow:CreateIconDrawable("artwork")
	icon:SetExtent(18, 18)
	icon:AddAnchor("TOPLEFT", managerWindow, 245, rowY)
	icon:SetVisible(false)

	local label = managerWindow:CreateChildWidget("label", "availableRowLabel", i, true)
	label:AddAnchor("TOPLEFT", managerWindow, 269, rowY)
	label:SetExtent(350, 20)
	ApplyLocalLabelStyle(label, 14, ALIGN_LEFT, 1, 1, 1)
	SetWidgetTextColorByKey(label, "default")

	local button = managerWindow:CreateChildWidget("button", "availableRowButton", i, true)
	ApplyLocalButtonStyle(button)
	button:SetExtent(78, 22)
	button:AddAnchor("TOPRIGHT", managerWindow, -18, rowY - 2)

	availableRows[i] = {
		icon = icon,
		label = label,
		button = button,
		entry = nil,
	}
end

local function clearRow(row)
	row.entry = nil
	row.label:SetText("")
	SetRowIcon(row.icon, nil)
	row.button:Show(false)
end

function refreshWindow()
	DebugPrint("refreshWindow start")
	uiState = shared.GetUiState()
	local scope = uiState.activeScope
	local effectType = uiState.activeEffect
	DebugPrint(
		string.format(
			"refreshWindow state scope=%s effect=%s trackedOnly=%s",
			tostring(scope),
			tostring(effectType),
			tostring(uiState.filterTrackedOnly)
		)
	)
	local trackedEntries = shared.GetSortedTrackedEntries(scope, effectType)
	local liveEntries = getLiveEffects(scope, effectType)
	DebugPrint(string.format("refreshWindow data tracked=%s live=%s", tostring(#trackedEntries), tostring(#liveEntries)))

	local liveById = {}
	for i = 1, #liveEntries do
		liveById[liveEntries[i].id] = liveEntries[i]
	end

	headerLabel:SetText(categoryTitle(scope, effectType))
	trackedTitle:SetText("Tracked " .. categoryTitle(scope, effectType))
	availableTitle:SetText(liveSectionTitle(scope, effectType))
	filterButton:SetText("Show All [" .. (uiState.filterTrackedOnly and "OFF" or "ON") .. "]")
	showGearButton:SetText("Show Gear [" .. (uiState.showGear and "ON" or "OFF") .. "]")
	showEquipmentButton:SetText("Show Equipment [" .. (uiState.showEquipment and "ON" or "OFF") .. "]")
	showClassButton:SetText("Show Class [" .. (uiState.showClass and "ON" or "OFF") .. "]")
	showDistanceButton:SetText("Show Distance [" .. (uiState.showDistance and "ON" or "OFF") .. "]")
	showCastbarButton:SetText("Show Castbar [" .. (uiState.showCastbar and "ON" or "OFF") .. "]")
	if drawLinesButton ~= nil then
		drawLinesButton:SetText(DrawLinesButtonText())
	end

	for _, scopeName in ipairs({ "target", "self" }) do
		local effectNames = scopeName == "target" and { "buff", "debuff" } or { "buff", "debuff", "hidden" }
		for _, effectName in ipairs(effectNames) do
			local key = scopeName .. "_" .. effectName
			local isActive = scope == scopeName and effectType == effectName
			categoryButtons[key]:SetText(categoryButtonText(scopeName, effectName))
			toggleButtons[key]:SetText(uiState[scopeName][effectName] and "ON" or "OFF")
			if isActive then
				categoryButtons[key]:SetText("> " .. categoryButtonText(scopeName, effectName))
			end
		end
	end

	local localTrackedMaxPage
	local localAvailableMaxPage
	trackedPage, localTrackedMaxPage = clampPage(trackedPage, #trackedRows, #trackedEntries)
	availablePage, localAvailableMaxPage = clampPage(availablePage, #availableRows, #liveEntries)
	trackedPageLabel:SetText(string.format("%d/%d", trackedPage, localTrackedMaxPage))
	availablePageLabel:SetText(string.format("%d/%d", availablePage, localAvailableMaxPage))

	local trackedStartIndex = ((trackedPage - 1) * #trackedRows) + 1
	for i = 1, #trackedRows do
		local row = trackedRows[i]
		local entry = trackedEntries[trackedStartIndex + i - 1]
		if entry == nil then
			clearRow(row)
		else
			local liveEntry = liveById[entry.id]
			row.entry = entry
			row.label:SetText(formatEntry(entry))
			SetRowIcon(row.icon, entry.iconPath ~= "" and entry.iconPath or (liveEntry and liveEntry.iconPath or nil))
			row.label.style:SetColor(0.20, 0.75, 0.20, 1)
			row.button:Show(true)
			row.button:SetText("Remove")
			row.button:SetHandler("OnClick", function()
				shared.RemoveTracked(scope, effectType, entry.id)
				refreshWindow()
			end)
		end
	end

	local liveStartIndex = ((availablePage - 1) * #availableRows) + 1
	for i = 1, #availableRows do
		local row = availableRows[i]
		local entry = liveEntries[liveStartIndex + i - 1]
		if entry == nil then
			clearRow(row)
		else
			local tracked = shared.IsTracked(scope, effectType, entry.id)
			row.entry = entry
			row.label:SetText(formatEntry(entry))
			SetRowIcon(row.icon, entry.iconPath)
			if tracked then
				row.label.style:SetColor(0.20, 0.75, 0.20, 1)
				row.button:SetText("Remove")
				row.button:SetHandler("OnClick", function()
					shared.RemoveTracked(scope, effectType, entry.id)
					refreshWindow()
				end)
			else
				SetWidgetTextColorByKey(row.label, "default")
				row.button:SetText("Track")
				row.button:SetHandler("OnClick", function()
					shared.AddTracked(scope, effectType, entry.id, entry.name, entry.iconPath)
					refreshWindow()
				end)
			end
			row.button:Show(true)
		end
	end

	if #trackedEntries == 0 then
		trackedRows[1].label:SetText("No tracked entries yet.")
		SetWidgetTextColorByKey(trackedRows[1].label, "default")
		SetRowIcon(trackedRows[1].icon, nil)
	end

	if #liveEntries == 0 then
		availableRows[1].label:SetText(scope == "target" and "No target effects available." or "No self effects available.")
		SetWidgetTextColorByKey(availableRows[1].label, "default")
		SetRowIcon(availableRows[1].icon, nil)
	end

	DebugPrint("refreshWindow done")
end

trackedPrevButton:SetHandler("OnClick", function()
	trackedPage = trackedPage - 1
	DebugPrint(string.format("trackedPrevButton clicked trackedPage=%s", tostring(trackedPage)))
end)

trackedNextButton:SetHandler("OnClick", function()
	trackedPage = trackedPage + 1
	DebugPrint(string.format("trackedNextButton clicked trackedPage=%s", tostring(trackedPage)))
end)

availablePrevButton:SetHandler("OnClick", function()
	availablePage = availablePage - 1
	DebugPrint(string.format("availablePrevButton clicked availablePage=%s", tostring(availablePage)))
end)

availableNextButton:SetHandler("OnClick", function()
	availablePage = availablePage + 1
	DebugPrint(string.format("availableNextButton clicked availablePage=%s", tostring(availablePage)))
end)

addByIdButton:SetHandler("OnClick", function()
	addByIdNameEdit:SetText("")
	addByIdIdEdit:SetText("")
	addByIdWindow:Show(true)
	addByIdNameEdit:SetFocus()
end)

exportButton:SetHandler("OnClick", function()
	importExportWindow:ShowExport()
end)

importButton:SetHandler("OnClick", function()
	importExportWindow:ShowImport()
end)

function managerWindow:OnUpdate(dt)
	if not self:IsVisible() then
		return
	end

	self.elapsed = (self.elapsed or 0) + dt
	if self.elapsed < 0.25 then
		return
	end

	self.elapsed = 0
	DebugPrint("managerWindow OnUpdate refresh tick")
	refreshWindow()
end

managerWindow:SetHandler("OnUpdate", managerWindow.OnUpdate)
managerWindow.ShowProc = refreshWindow

DrawLinesEnsureDots()
drawLinesUpdater = CreateEmptyWindow("extendedPlatesDrawLinesUpdater", "UIParent")
drawLinesUpdater:Show(true)
function drawLinesUpdater:OnUpdate(dt)
	drawLinesDebugElapsed = drawLinesDebugElapsed + dt
	if showTracktargetAggro and tracktargetAggroWindow ~= nil then
		local name = X2Unit:UnitName("watchtargettarget") or "none"
		tracktargetAggroLabel:SetText(name)
		tracktargetAggroWindow:Show(true)
	else
		if tracktargetAggroWindow ~= nil then
			tracktargetAggroWindow:Show(false)
		end
	end
	if showTracktargetDistance and tracktargetDistanceWindow ~= nil then
		local distInfo = X2Unit:UnitDistance("watchtarget")
		if distInfo ~= nil and distInfo.distance ~= nil then
			local distanceValue = tonumber(distInfo.distance) or 0
			tracktargetDistanceLabel:SetText(string.format("%.1fm", distanceValue))
			if distanceValue >= 200 then
				tracktargetDistanceLabel.style:SetColor(1.0, 0.2, 0.2, 1)
			elseif distanceValue >= 150 then
				tracktargetDistanceLabel.style:SetColor(1.0, 0.6, 0.1, 1)
			else
				tracktargetDistanceLabel.style:SetColor(1.0, 1.0, 1.0, 1)
			end
		else
			tracktargetDistanceLabel:SetText("")
			tracktargetDistanceLabel.style:SetColor(1.0, 1.0, 1.0, 1)
		end
		tracktargetDistanceWindow:Show(true)
	else
		if tracktargetDistanceWindow ~= nil then
			tracktargetDistanceWindow:Show(false)
		end
	end
	DrawLinesEnsureDots()
	for _, key in ipairs(drawLinesPairOrder) do
		local dotSet = drawLinesDotSets[key]
		if dotSet ~= nil then
			for i = 1, #dotSet do
				if dotSet[i] ~= nil and dotSet[i].label ~= nil and dotSet[i].label.style ~= nil then
					dotSet[i].label.style:SetFontSize(drawLinesDotFontSize)
					local pair = drawLinesPairMeta[key]
					if pair ~= nil then
						dotSet[i].label.style:SetColor(pair.color[1], pair.color[2], pair.color[3], drawLinesDotAlpha)
					end
				end
			end
		end
	end
	if drawLinesEnabled ~= true then
		for _, key in ipairs(drawLinesPairOrder) do
			local dotSet = drawLinesDotSets[key]
			if dotSet ~= nil then
				DrawLinesHideDots(dotSet)
			end
		end
		return
	end
	for _, key in ipairs(drawLinesPairOrder) do
		DrawLinesRenderPair(key)
	end
	if drawLinesDebugElapsed >= drawLinesDebugIntervalMs then
		drawLinesDebugElapsed = 0
	end
end
drawLinesUpdater:SetHandler("OnUpdate", drawLinesUpdater.OnUpdate)

managerButton:SetHandler("OnClick", function()
	DebugPrint(string.format("managerButton clicked visibleBefore=%s", tostring(managerWindow:IsVisible())))
	managerWindow:Show(not managerWindow:IsVisible())
	DebugPrint(string.format("managerButton toggled visibleAfter=%s", tostring(managerWindow:IsVisible())))
	if managerWindow:IsVisible() then
		refreshWindow()
	end
end)

positionButton:SetHandler("OnClick", function()
	positionWindow:Show(not positionWindow:IsVisible())
end)

DebugPrint("tracktarget.lua init complete")
