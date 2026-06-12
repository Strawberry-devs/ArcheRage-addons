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
ADDON:ImportObject(OBJECT_TYPE.LABEL)
ADDON:ImportObject(OBJECT_TYPE.WINDOW)
ADDON:ImportObject(OBJECT_TYPE.ICON_DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.IMAGE_DRAWABLE)

ADDON:ImportAPI(API_TYPE.OPTION.id)
ADDON:ImportAPI(API_TYPE.CHAT.id)

local portalButton = CreateSimpleButton("Portal", 700, -300)
--set color on start
SetButtonFontOneColor(portalButton, { 0.9, 0.333, 0.333, 1 })
if X2Option:GetOptionItemValue(OIT_AUTO_USE_ONLY_MY_PORTAL) == 0 then
	SetButtonFontOneColor(portalButton, { 0.348, 0.609, 0.370, 1 })
end

--change color and setting on click
function portalButton:OnClick()
	local portalOption = X2Option:GetOptionItemValue(OIT_AUTO_USE_ONLY_MY_PORTAL)
	if portalOption == 1 then
		SetButtonFontOneColor(portalButton, { 0.348, 0.609, 0.370, 1 })
		X2Chat:DispatchChatMessage(CMF_SYSTEM, "Using ALL portals.")
		X2Option:SetItemFloatValue(OIT_AUTO_USE_ONLY_MY_PORTAL, 0)
	else
		SetButtonFontOneColor(portalButton, { 0.9, 0.333, 0.333, 1 })
		X2Chat:DispatchChatMessage(CMF_SYSTEM, "Using ONLY YOUR portals.")
		X2Option:SetItemFloatValue(OIT_AUTO_USE_ONLY_MY_PORTAL, 1)
	end
end
portalButton:SetHandler("OnClick", portalButton.OnClick)
