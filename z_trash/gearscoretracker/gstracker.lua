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

ADDON:ImportAPI(API_TYPE.CHAT.id)
ADDON:ImportAPI(API_TYPE.UNIT.id)

-- Create a basic invisible window to attach icons to
local labelAnchor = CreateEmptyWindow("labelAnchor", "UIParent")
labelAnchor:Show(true)
labelAnchor:Enable(true)
local lblDuration = labelAnchor:CreateChildWidget("label", "lblDuration", 0, true)
lblDuration:Show(true)
lblDuration:EnablePick(false)
lblDuration.style:SetColor(1, 1, 1, 1.0)
lblDuration.style:SetFontSize(15)
lblDuration.style:SetOutline(true)
lblDuration.style:SetAlign(ALIGN_LEFT)
lblDuration:AddAnchor("LEFT", labelAnchor, 0, 0)
lblDuration:SetText("")
local targetGearScore = {}
local numericaltargetGearScore = 0
local actualGearScore = ""
local skipIter = 1
local updateFrequency = 1 -- 1 is hyperfast, 10 is regular

function labelAnchor:OnUpdate(dt)
	local nScrX_Tar, nScrY_Tar, nScrZ_Tar = X2Unit:GetUnitScreenPosition("target")
	if nScrX_Tar == nil or nScrY_Tar == nil or nScrZ_Tar == nil then
		labelAnchor:AddAnchor("TOPLEFT", "UIParent", 5000, 5000)
	elseif nScrZ_Tar > 0 then
		local x = math.floor(0.5 + nScrX_Tar)
		local y = math.floor(0.5 + nScrY_Tar)
		labelAnchor:AddAnchor("TOPLEFT", "UIParent", x + 40, y - 40)
		if skipIter < updateFrequency then
			skipIter = skipIter + 1
			return
		end
		skipIter = 1
		--X2Chat:DispatchChatMessage(CMF_SYSTEM, "gs: " .. tostring(X2Unit:UnitGearScore("target", true)))
		local targetGearScore = X2Unit:UnitGearScore("target", true)
		targetGearScore = tonumber(targetGearScore)

		if targetGearScore <= 10000 then
			lblDuration.style:SetColor(0, 1, 0, 1.0)
		else
			local minGearScore = 10000
			local maxGearScore = 20000
			local t = (targetGearScore - minGearScore) / (maxGearScore - minGearScore)
			t = math.max(0, math.min(1, t))
			local r, g, b
			if t < 0.5 then
				t = t * 2
				r = t
				g = 1
				b = 0
			else
				t = (t - 0.5) * 2
				r = 1
				g = 1 - t
				b = 0
			end
			lblDuration.style:SetColor(r, g, b, 1.0)
		end

		if targetGearScore == 0 then
			targetGearScore = " "
		end
		lblDuration:SetText(tostring(targetGearScore))
	end
end

labelAnchor:SetHandler("OnUpdate", labelAnchor.OnUpdate)
