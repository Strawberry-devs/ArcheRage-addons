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

local buffAnchor = CreateEmptyWindow("buffAnchor", "UIParent")
buffAnchor:Show(true)
buffAnchor:AddAnchor("TOPLEFT", "UIParent", 10, -100)
local lblCapReached = buffAnchor:CreateChildWidget("label", "lblCapReached", 10, true)
lblCapReached:Show(false)
lblCapReached:EnablePick(false)
lblCapReached.style:SetColor(1, 0, 0, 1.0)
lblCapReached.style:SetFontSize(30)
lblCapReached.style:SetOutline(true)
lblCapReached.style:SetAlign(ALIGN_LEFT)
lblCapReached:AddAnchor("LEFT", buffAnchor, (UIParent:GetScreenWidth() / 2) - 115, (UIParent:GetScreenHeight() / 3))
lblCapReached:SetText("BUFF CAPPED")

local UPDATE_INTERVAL_MS = 500
local elapsedSinceCheck = UPDATE_INTERVAL_MS

function buffAnchor:OnUpdate(dt)
	elapsedSinceCheck = elapsedSinceCheck + dt
	if elapsedSinceCheck < UPDATE_INTERVAL_MS then
		return
	end
	elapsedSinceCheck = 0

	local UBuffCount = X2Unit:UnitBuffCount("player")
	if UBuffCount == 32 then
		lblCapReached:Show(true)
	else
		lblCapReached:Show(false)
	end
end
buffAnchor:SetHandler("OnUpdate", buffAnchor.OnUpdate)
