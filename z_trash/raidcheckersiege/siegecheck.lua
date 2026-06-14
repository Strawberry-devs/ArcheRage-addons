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

--https://wiki.archerage.to/ru-en/search/q is your friend
local buffsToCheck = {
	catapult = { 31757 },
	clad = { 25088 },
	flamethrower = { 28315 },
}
local function formatPlayerName(member)
	local team = math.ceil(member / 5)
	local memberWithinTeam = member % 5
	return string.format("%d-%d", team, memberWithinTeam)
end
function checkBuffs()
	local missingByBuff = {}
	for category in pairs(buffsToCheck) do
		missingByBuff[category] = {}
	end

	local hasCoRaid = false
	local amountOfRaids = 1
	if X2Unit:UnitName("team_1_1") == nil and X2Unit:UnitName("team1") == nil then
		X2Chat:DispatchChatMessage(CMF_SYSTEM, "Not in a raid.")
		amountOfRaids = 0
	end
	if X2Unit:UnitName("team_1_1") ~= nil then
		amountOfRaids = 2
		hasCoRaid = true
	end

	for team = 1, amountOfRaids do
		for member = 1, 50 do
			local teamId = ""
			if hasCoRaid then
				teamId = string.format("team_%02d_%02d", team, member)
			else
				teamId = string.format("team%02d", member)
			end
			local playerName = X2Unit:UnitName(teamId)
			if playerName then
				local UBuffCount = X2Unit:UnitHiddenBuffCount(teamId)
				if UBuffCount > 2 then
					local hasBuff = {}
					for category in pairs(buffsToCheck) do
						hasBuff[category] = false
					end

					for i = 1, UBuffCount do
						local buffExtra = X2Unit:UnitHiddenBuff(teamId, i)
						local buffId = buffExtra["buff_id"]

						--X2Chat:DispatchChatMessage(CMF_SYSTEM, tostring(buffId))
						for category, ids in pairs(buffsToCheck) do
							for _, id in ipairs(ids) do
								if id == buffId then
									X2Chat:DispatchChatMessage(CMF_SYSTEM, playerName .. " has " .. tostring(category)) -- tostring(buffId) .. "found as" .. tostring(id))
									hasBuff[category] = true
									break
								end
							end
							if hasBuff[category] then
								break
							end
						end
					end

					for category, present in pairs(hasBuff) do
						if not present then
							table.insert(
								missingByBuff[category],
								playerName .. tostring(team) .. "-" .. formatPlayerName(member)
							)
						end
					end
				else
					--out of range handler?
				end
			end
		end
	end
end

local siegeCheckerButton = CreateSimpleButton("Siege Equips", 700, -200)

function siegeCheckerButton:OnClick()
	checkBuffs()
end
siegeCheckerButton:SetHandler("OnClick", siegeCheckerButton.OnClick)
