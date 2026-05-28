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

local buffAnchor = CreateEmptyWindow("buffAnchor", "UIParent")
buffAnchor:Show(true)
buffAnchor:AddAnchor("TOPLEFT", "UIParent", 10, -100)

local drawableIcon = buffAnchor:CreateIconDrawable("artwork")
drawableIcon:SetExtent(35, 35) -- Width, height
drawableIcon:ClearAllTextures() -- Every other usage of AddTexture called this first 🤷
drawableIcon:AddTexture("ui/icon/icon_item_blade_2h_0082.dds") -- path to dds texture to load
drawableIcon:SetVisible(false)
drawableIcon:AddAnchor("LEFT", buffAnchor, (UIParent:GetScreenWidth() / 2) - 50, (UIParent:GetScreenHeight() / 3))

local lblCapReached2 = buffAnchor:CreateChildWidget("label", "lblCapReached2", 10, true)
lblCapReached2:Show(true)
lblCapReached2:EnablePick(false)
lblCapReached2.style:SetColor(1, 0, 0, 1.0)
lblCapReached2.style:SetFontSize(20)
lblCapReached2.style:SetOutline(true)
lblCapReached2.style:SetAlign(ALIGN_LEFT)
lblCapReached2:AddAnchor("LEFT", buffAnchor, (UIParent:GetScreenWidth() / 2) - 50, (UIParent:GetScreenHeight() / 3))
--lblCapReached2:SetText("BUFF CAPPED")
local start_time = 0
local wait_duration = 45
local end_time = 0



function buffAnchor:OnUpdate(dt)
	local UBuffCount = X2Unit:UnitHiddenBuffCount("target")
	--lblCapReached2:SetText(tostring(UBuffCount))
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
		buffAllString = buffAllString .. strBuffId .. ":" .. buff["name"] .. " - " .. buff["description"] .. "\n"
	end
	if buffAllString ~= lastbuffString then
		X2Chat:DispatchChatMessage(CMF_SYSTEM, "----- Hidden Buffs: -----" .. "\n" .. buffAllString)
		lastbuffString = buffAllString
	end
end
--buffAnchor:SetHandler("OnUpdate", buffAnchor.OnUpdate)
