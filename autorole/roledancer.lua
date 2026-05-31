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
ADDON:ImportAPI(API_TYPE.TEAM.id)

local classnumberRu = {
	["Mage"] = 0,
	["Malediction"] = 0,
	["Tank"] = 1,
	["Songer"] = 1,
	["Dancer"] = 1,
	["Healer"] = 2,
	["Gunner"] = 4,
	["Archer"] = 3,
	["Melee"] = 3,
	["Swiftblade"] = 3,
	["unknown"] = 0,
}

local classnumberNa = {
	["Mage"] = 4,
	["Malediction"] = 4,
	["Tank"] = 1,
	["Songer"] = 1,
	["Dancer"] = 3,
	["Healer"] = 2,
	["Gunner"] = 1,
	["Archer"] = 1,
	["Melee"] = 1,
	["Swiftblade"] = 1,
	["unknown"] = 0,
}

local classnumber = classnumberRu
if playerIsOnRuServer ~= nil and playerIsOnRuServer() ~= true then
	classnumber = classnumberNa
end
local spellDanceNames = {
	["[Dance] Dance of Sacrifice"] = true,
	["[舞蹈]牺牲之舞"] = true,
	["Танец Наимы"] = true,
	["[Danse] Danse du sacrifice"] = true,
}
local refreshForcer = CreateEmptyWindow("refreshForcer", "UIParent")
refreshForcer:Show(true)
local defaultRole = 0
local discoRole = 0
local counter = 0
local isDancing = false
local danceEnded = false
function refreshForcer:OnUpdate(dt)
	--X2Chat:DispatchChatMessage(CMF_SYSTEM, tostring(counter))
	if counter > 510 then
		if isDancing == true then
			X2Team:SetRole(discoRole)
			discoRole = (discoRole + 1) % 4
		end
		if danceEnded then
			X2Team:SetRole(defaultRole)
			danceEnded = false
		end
		counter = 0
	end
	counter = counter + dt
	--    counter = counter + 1
end

local function getCurrentRole()
	local templates = X2Unit:GetTargetAbilityTemplates("player")
	local indices = {
		templates[1].index,
		templates[2].index,
		templates[3].index,
	}
	table.sort(indices)
	local keyStr = string.format("name_%d_%d_%d", indices[1], indices[2], indices[3])
	--X2Chat:DispatchChatMessage(CMF_SYSTEM, keyStr)
	local fakeClassName = nameMappings[keyStr] or "unknown"
	if fakeClassName == "unknown" then
		X2Chat:DispatchChatMessage(
			CMF_SYSTEM,
			"Your class " .. keyStr .. " is not known, please add it to globals/classmappings.lua."
		)
	end
	--X2Chat:DispatchChatMessage(CMF_SYSTEM, fakeClassName .. classnumber[fakeClassName])
	return classnumber[fakeClassName]
end

local function StartCast(spellName, castingTime, caster, castingUseable)
	if spellDanceNames[spellName] and caster == "player" then
		--X2Chat:DispatchChatMessage(CMF_SYSTEM, "Dancing " .. spellName .. tostring(castingTime) .. caster)
		isDancing = true
		danceEnded = false
	end

	--isDancing = true
end
local function StopCast(caster)
	--X2Chat:DispatchChatMessage(CMF_SYSTEM, "Dancing end".. caster)
	if isDancing and caster == "player" then
		isDancing = false
		danceEnded = true
	end
end
local function EndCast(caster)
	--X2Chat:DispatchChatMessage(CMF_SYSTEM, "Dancing end" .. caster)
	if isDancing and caster == "player" then
		isDancing = false
		danceEnded = true
	end
end

local function ChangeClass()
	defaultRole = getCurrentRole()
	X2Team:SetRole(defaultRole)
end
local function JoinedRaid(reason)
	if reason == "joined_by_self" then
		defaultRole = getCurrentRole()
		X2Team:SetRole(defaultRole)
	end
end

defaultRole = getCurrentRole()

UIParent:SetEventHandler(UIEVENT_TYPE.ABILITY_SET_CHANGED, ChangeClass)
UIParent:SetEventHandler(UIEVENT_TYPE.ABILITY_CHANGED, ChangeClass)
UIParent:SetEventHandler(UIEVENT_TYPE.TEAM_MEMBERS_CHANGED, JoinedRaid)

UIParent:SetEventHandler(UIEVENT_TYPE.SPELLCAST_START, StartCast)
UIParent:SetEventHandler(UIEVENT_TYPE.SPELLCAST_STOP, StopCast)
UIParent:SetEventHandler(UIEVENT_TYPE.SPELLCAST_SUCCEEDED, EndCast)

refreshForcer:SetHandler("OnUpdate", refreshForcer.OnUpdate)
