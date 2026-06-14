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
ADDON:ImportAPI(API_TYPE.LOCALE.id)

-- Create a basic invisible window to attach icons to
local labelAnchor = CreateEmptyWindow("labelAnchor", "UIParent")
labelAnchor:Show(true)
labelAnchor:Enable(true)
local lblDuration = labelAnchor:CreateChildWidget("label", "lblDuration", 0, true)
lblDuration:Show(true)
lblDuration:EnablePick(false)
lblDuration.style:SetColor(1, 0, 0, 1.0)
lblDuration.style:SetFontSize(25)
lblDuration.style:SetOutline(true)
lblDuration.style:SetAlign(ALIGN_RIGHT)
lblDuration:AddAnchor("LEFT", labelAnchor, 0, 0)
lblDuration:SetText("")
local targetDistance = {}
local numericalTargetDistance = 0
local actualDistance = ""
local skipIter = 1
local updateFrequency = 10 -- 1 is hyperfast, 10 is regular
--setting this too high will cause blurry numbers
local turnRedAt = 30

function labelAnchor:OnUpdate(dt)
	local nScrX_Tar, nScrY_Tar, nScrZ_Tar = X2Unit:GetUnitScreenPosition("target")
	if nScrX_Tar == nil or nScrY_Tar == nil or nScrZ_Tar == nil then
		labelAnchor:AddAnchor("TOPLEFT", "UIParent", 5000, 5000)
	elseif nScrZ_Tar > 0 then
		local x = math.floor(0.5 + nScrX_Tar)
		local y = math.floor(0.5 + nScrY_Tar)
		labelAnchor:AddAnchor("TOPLEFT", "UIParent", x - 50, y - 20)
		if skipIter < updateFrequency then
			skipIter = skipIter + 1
			return
		end
		skipIter = 1
		targetDistance = X2Unit:UnitDistance("target")
		--actualDistance = math.floor(targetDistance.distance * 10 + 0.5) / 10
		numericalTargetDistance = math.floor(targetDistance.distance * 10 + 0.5) / 10
		if numericalTargetDistance > turnRedAt then
			lblDuration.style:SetColor(1, 0, 0, 1.0)
		else
			lblDuration.style:SetColor(1, 1, 1, 1.0)
		end
		if targetDistance.distance < 0 then
			targetDistance.distance = 0.0
		end
		actualDistance = string.format("%.1f", math.floor(targetDistance.distance * 10 + 0.5) / 10)

		lblDuration:SetText(actualDistance .. "m")
	end
end

labelAnchor:SetHandler("OnUpdate", labelAnchor.OnUpdate)
