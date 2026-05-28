-------------- Original Author: Strawberry --------------
----------------- Discord: exec_noir --------------------
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

-- Create a basic invisible window to attach icons to
local buffAnchor = CreateEmptyWindow("buffAnchor", "UIParent")
buffAnchor:Show(true)

local target_buffs = {}
local target_buffDebugMessages = false
local showAllBuffs = true

local buffAllString = ""
local lastBuffString = ""
local debuffAllString = ""
local lastdeBuffString = ""

local drawableNmyIcons = {} -- Table to store drawn icons, must be global
local drawableNmyLabels = {} -- Table to store drawn counters, must be global
local drawableNmyLabels_stacks = {} -- stacks


------------------------ Icon drawing function ------------------------
local function drawIcon(w, iconPath, id, xOffset, yOffset, duration, stacks)
	-- If the icon already exists, don't redraw it, instead update it
	if drawableNmyIcons[id] ~= nil then
		if not drawableNmyIcons[id]:IsVisible() then
			drawableNmyIcons[id]:SetVisible(true)
			drawableNmyLabels[id]:Show(true)
			drawableNmyLabels_stacks[id]:Show(true)
		end
		drawableNmyIcons[id]:AddAnchor("LEFT", w, xOffset, yOffset)
		drawableNmyLabels[id]:AddAnchor("LEFT", w, xOffset, yOffset)
		drawableNmyLabels[id]:SetText(duration)
		drawableNmyLabels_stacks[id]:AddAnchor("LEFT", w, xOffset + 5, yOffset - 10)
		drawableNmyLabels_stacks[id]:SetText(stacks)
		return
	end
	-- Create an icon using iconPath
	local drawableIcon = w:CreateIconDrawable("artwork")
	drawableIcon:SetExtent(25, 25) -- Width, height
	drawableIcon:ClearAllTextures() -- Every other usage of AddTexture called this first 🤷
	drawableIcon:AddTexture(iconPath) -- path to dds texture to load
	drawableIcon:SetVisible(true)
	-- Add a timer label using duration
	local lblDuration = w:CreateChildWidget("label", "lblDuration", 0, true)
	lblDuration:Show(true)
	lblDuration:EnablePick(false)
	lblDuration.style:SetColor(1, 1, 1, 1.0)
	lblDuration.style:SetOutline(true)
	lblDuration.style:SetAlign(ALIGN_LEFT)
	lblDuration:SetText(duration)
	-- Add a timer label using stacks
	local lblStacks = w:CreateChildWidget("label", "lblStacks", 0, true)
	lblStacks:Show(true)
	lblStacks:EnablePick(false)
	lblStacks.style:SetColor(0, 1, 1, 1.0)
	lblStacks.style:SetOutline(true)
	lblStacks.style:SetAlign(ALIGN_RIGHT)
	lblStacks:SetText(stacks)
	-- Save the drawn icon to the global object array
	drawableNmyLabels[id] = lblDuration
	drawableNmyLabels_stacks[id] = lblStacks
	drawableNmyIcons[id] = drawableIcon
end

------------------------ Function called perpetually ------------------------
function buffAnchor:OnUpdate(dt)
	-- Find coordinates of nameplate
	local nScrX_Tar, nScrY_Tar, nScrZ_Tar = X2Unit:GetUnitScreenPosition("target")
	if nScrX_Tar == nil or nScrY_Tar == nil or nScrZ_Tar == nil then
		buffAnchor:AddAnchor("TOPLEFT", "UIParent", 5000, 5000)
	elseif nScrZ_Tar > 0 then
		local x = math.floor(0.5 + nScrX_Tar)
		local y = math.floor(0.5 + nScrY_Tar)
		buffAnchor:Show(true)
		buffAnchor:Enable(true)
		buffAnchor:AddAnchor("TOPLEFT", "UIParent", x - 50, y - 40)

		-- Handle buffs
		buffAllString = ""
		debuffAllString = ""
		local UBuffCount = X2Unit:UnitHiddenBuffCount("target")
		local buffCounter = 0
		local currentBuffs = {}
		for i = 1, UBuffCount do
			local buff = X2Unit:UnitHiddenBuffTooltip("target", i)
			local buffExtra = X2Unit:UnitHiddenBuff("target", i)
			strBuffId = tostring(buffExtra["buff_id"])
			X2Chat:DispatchChatMessage(CMF_SYSTEM, strBuffId)
			if target_buffs[strBuffId] ~= nil or showAllBuffs then
				currentBuffs[buff["name"]] = true
				--local iconPath = target_buffs[buff["name"]]
				iconPath = buffExtra["path"]
				local duration = buff["timeLeft"] and tostring(math.floor(buff["timeLeft"] / 1000)) or ""
				local stacks = tostring(buff["stack"] or "")
				drawIcon(buffAnchor, iconPath, buff["name"], 30 * buffCounter, 0, duration, stacks)
				buffCounter = buffCounter + 1
			end
		end
	end
end
buffAnchor:SetHandler("OnUpdate", buffAnchor.OnUpdate)
