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

ADDON:ImportAPI(API_TYPE.OPTION.id)
ADDON:ImportAPI(API_TYPE.CHAT.id)
ADDON:ImportAPI(API_TYPE.ACHIEVEMENT.id)
ADDON:ImportAPI(API_TYPE.UNIT.id)
ADDON:ImportAPI(API_TYPE.LOCALE.id)

local shared = TargetDebuffTrackerShared
local buffAnchor = CreateEmptyWindow("targetDebuffTrackerEnemyAnchor", "UIParent")
buffAnchor:Show(true)

local drawableIcons = {}
local drawableDurations = {}
local drawableStacks = {}
local classIcons = {}

local roleIcons = {
	Tank = "ui/icon/icon_skill_adamant15.dds",
	Songer = "ui/icon/icon_skill_romance15.dds",
	Melee = "ui/icon/icon_skill_fight37.dds",
	Archer = "ui/icon/icon_skill_wild35.dds",
	Mage = "ui/icon/icon_skill_magic40.dds",
	Gunner = "ui/icon/icon_skill_madness07.dds",
	Malediction = "ui/icon/icon_skill_hatred25.dds",
	Dancer = "ui/icon/icon_skill_pleasure02.dds",
	Swiftblade = "ui/icon/icon_skill_assassin43.dds",
	Healer = "ui/icon/icon_skill_love01.dds",
	unknown = "ui/icon/top_question_mark.dds",
}

local function createLabel(name, red, green, blue, fontSize)
	local label = buffAnchor:CreateChildWidget("label", name, 0, true)
	label:Show(false)
	label:EnablePick(false)
	label.style:SetColor(red, green, blue, 1)
	label.style:SetFontSize(fontSize)
	label.style:SetOutline(true)
	label.style:SetAlign(ALIGN_LEFT)
	return label
end

local gearLabel = createLabel("gearLabel", 1, 1, 1, 15)
local distanceLabel = createLabel("distanceLabel", 1, 0, 0, 25)
local classLabel = createLabel("classLabel", 1, 1, 1, 13)

local function ensureClassIcon(role)
	local iconPath = roleIcons[role]
	if iconPath == nil then
		return nil
	end

	if classIcons[role] ~= nil then
		return classIcons[role]
	end

	local drawableIcon = buffAnchor:CreateIconDrawable("artwork")
	drawableIcon:SetExtent(22, 22)
	drawableIcon:ClearAllTextures()
	drawableIcon:AddTexture(iconPath)
	drawableIcon:SetVisible(false)
	classIcons[role] = drawableIcon
	return drawableIcon
end

local function hideClassIcons()
	for _, icon in pairs(classIcons) do
		icon:SetVisible(false)
	end
end

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

local function hideMetaWidgets()
	gearLabel:Show(false)
	distanceLabel:Show(false)
	classLabel:Show(false)
	hideClassIcons()
end

local function setGearScoreColor(label, gearScore)
	if gearScore <= 10000 then
		label.style:SetColor(0, 1, 0, 1)
		return
	end

	local minGearScore = 10000
	local maxGearScore = 20000
	local t = (gearScore - minGearScore) / (maxGearScore - minGearScore)
	t = math.max(0, math.min(1, t))
	local red
	local green
	if t < 0.5 then
		t = t * 2
		red = t
		green = 1
	else
		t = (t - 0.5) * 2
		red = 1
		green = 1 - t
	end
	label.style:SetColor(red, green, 0, 1)
end

local function formatGearScore(gearScore)
	local roundedThousands = math.floor((gearScore + 500) / 1000)
	return string.format("%dk", roundedThousands)
end

local function updateGearLabel(uiState)
	if uiState.showGear ~= true then
		gearLabel:Show(false)
		return
	end

	local gearSettings = shared.GetGearSettings()

	local targetGearScore = tonumber(X2Unit:UnitGearScore("target", false) or 0) or 0
	--aaprint(tostring(targetGearScore))
	if targetGearScore <= 0 then
		gearLabel:SetText("")
		gearLabel:Show(false)
		return
	end

	setGearScoreColor(gearLabel, targetGearScore)
	gearLabel:SetText(formatGearScore(targetGearScore))
	gearLabel:RemoveAllAnchors()
	gearLabel:AddAnchor("LEFT", buffAnchor, gearSettings.x, gearSettings.y)
	gearLabel:Show(true)
end

local function updateDistanceLabel(uiState)
	if uiState.showDistance ~= true then
		distanceLabel:Show(false)
		return
	end

	local distanceSettings = shared.GetDistanceSettings()
	distanceLabel.style:SetFontSize(distanceSettings.fontSize)

	local targetDistance = X2Unit:UnitDistance("target")
	local distanceValue = targetDistance and tonumber(targetDistance.distance) or nil
	if distanceValue == nil then
		distanceLabel:SetText("")
		distanceLabel:Show(false)
		return
	end

	if distanceValue < 0 then
		distanceValue = 0
	end

	local roundedDistance = math.floor(distanceValue * 10 + 0.5) / 10
	if roundedDistance > distanceSettings.turnRedAt then
		distanceLabel.style:SetColor(1, 0, 0, 1)
	else
		distanceLabel.style:SetColor(1, 1, 1, 1)
	end
	distanceLabel:SetText(string.format("%.1fm", roundedDistance))
	distanceLabel:RemoveAllAnchors()
	distanceLabel:AddAnchor("LEFT", buffAnchor, distanceSettings.x, distanceSettings.y)
	distanceLabel:Show(true)
end

local function updateClassWidgets(uiState)
	if uiState.showClass ~= true then
		classLabel:Show(false)
		hideClassIcons()
		return
	end

	local templates = X2Unit:GetTargetAbilityTemplates("target")
	if type(templates) ~= "table" or templates[1] == nil or templates[2] == nil or templates[3] == nil then
		classLabel:SetText("")
		classLabel:Show(false)
		hideClassIcons()
		return
	end

	local indices = {
		templates[1].index,
		templates[2].index,
		templates[3].index,
	}
	table.sort(indices)
	local keyStr = string.format("name_%d_%d_%d", indices[1], indices[2], indices[3])
	if keyStr == "name_30_30_30" then
		classLabel:SetText("")
		classLabel:Show(false)
		hideClassIcons()
		return
	end

	local actualClassName = X2Locale:LocalizeUiText(COMBINED_ABILITY_NAME_TEXT, keyStr, "")
	if actualClassName == nil or actualClassName == "" then
		actualClassName = GetUIText(COMBINED_ABILITY_NAME_TEXT, "name_9_9_9")
	end
	if actualClassName == nil or actualClassName == "" then
		classLabel:SetText("")
		classLabel:Show(false)
		hideClassIcons()
		return
	end

	local mappedRole = nameMappings and nameMappings[keyStr] or "unknown"
	local classIcon = ensureClassIcon(mappedRole or "unknown")
	local classSettings = shared.GetClassSettings()
	hideClassIcons()
	if classIcon ~= nil and classSettings.showIcon == true then
		classIcon:RemoveAllAnchors()
		classIcon:AddAnchor("LEFT", buffAnchor, classSettings.iconX, classSettings.iconY)
		classIcon:SetVisible(true)
	end

	if classSettings.showWords == true then
		classLabel:SetText(actualClassName)
		classLabel:RemoveAllAnchors()
		classLabel:AddAnchor("LEFT", buffAnchor, classSettings.labelX, classSettings.labelY)
		classLabel:Show(true)
	else
		classLabel:SetText("")
		classLabel:Show(false)
	end
end

function buffAnchor:OnUpdate()
	local screenX, screenY, screenZ = X2Unit:GetUnitScreenPosition("target")
	if screenX == nil or screenY == nil or screenZ == nil or screenZ <= 0 then
		buffAnchor:AddAnchor("TOPLEFT", "UIParent", 5000, 5000)
		hideUnused({})
		hideMetaWidgets()
		return
	end

	local x = math.floor(0.5 + screenX)
	local y = math.floor(0.5 + screenY)
	local currentIcons = {}
	local uiState = shared.GetUiState()

	buffAnchor:Show(true)
	buffAnchor:Enable(true)
	buffAnchor:AddAnchor("TOPLEFT", "UIParent", x - 50, y - 40)

	if uiState.target.buff then
		local settings = shared.GetIconSettings("target", "buff")
		local buffCounter = 0
		local buffCount = X2Unit:UnitBuffCount("target")
		for i = 1, buffCount do
			local buff = X2Unit:UnitBuffTooltip("target", i)
			local buffExtra = X2Unit:UnitBuff("target", i)
			local buffId = tostring(buffExtra["buff_id"])
			if shared.ShouldDisplay("target", "buff", buffId) then
				local iconId = "buff:" .. buffId .. ":" .. tostring(buff["name"])
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

	if uiState.target.debuff then
		local settings = shared.GetIconSettings("target", "debuff")
		local debuffCounter = 0
		local debuffCount = X2Unit:UnitDeBuffCount("target")
		for i = 1, debuffCount do
			local debuff = X2Unit:UnitDeBuffTooltip("target", i)
			local debuffExtra = X2Unit:UnitDeBuff("target", i)
			local debuffId = tostring(debuffExtra["buff_id"])
			if shared.ShouldDisplay("target", "debuff", debuffId) then
				local iconId = "debuff:" .. debuffId .. ":" .. tostring(debuff["name"])
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

	updateGearLabel(uiState)
	updateDistanceLabel(uiState)
	updateClassWidgets(uiState)
	hideUnused(currentIcons)
end

buffAnchor:SetHandler("OnUpdate", buffAnchor.OnUpdate)
