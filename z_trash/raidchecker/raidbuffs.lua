--todo
--statue (red, blue | nuia haranya pirate)
--drum, goblet, food (max rank, table rank, max-1 rank), resi/toughness book
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
	drum = { 5700, 32233, 32234, 32235, 32236, 32237, 32238, 32239 },
	statue = { 9002339, 48778, 9002340, 30768, 30765, 30766, 30770, 30760, 30764, 30767, 1, 1 },
	book = { 20552, 21795 },
	ribs = { 685, 693, 597, 689, 693, 21791, 21792, 21793, 21794 },
	goblet = {
		7685,		21796,		21801,		21806,		21811,		21819,		21846,
		7686,		21797,		21802,		21807,		21812,		21820,
		7687,		21798,		21803,		21808,		21813,		21821,
		7688,		21799,		21804,		21809,		21814,		21822,
		7689,		21800,		21805,		21810,		21815,		21823,
		24469,		24470,		24471,		24472,		24473,		24474,
	},
}
local function formatPlayerName(member)
	local team = math.ceil(member / 5)
	local memberWithinTeam = ((member - 1) % 5) + 1
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
				teamId = string.format("team_%d_%d", team, member)
			else
				teamId = string.format("team%d", member)
			end
			local playerName = X2Unit:UnitName(teamId)
			if playerName then
				local UBuffCount = X2Unit:UnitBuffCount(teamId)
				if UBuffCount > 2 then
					local hasBuff = {}
					for category in pairs(buffsToCheck) do
						hasBuff[category] = false
					end

					for i = 1, UBuffCount do
						local buffExtra = X2Unit:UnitBuff(teamId, i)
						local buffId = buffExtra["buff_id"]

						--X2Chat:DispatchChatMessage(CMF_SYSTEM, tostring(buffId))
						for category, ids in pairs(buffsToCheck) do
							if not hasBuff[category] then
								for _, id in ipairs(ids) do
									if id == buffId then
										--X2Chat:DispatchChatMessage(CMF_SYSTEM, tostring(buffId) .. "found as" .. tostring(id))
										hasBuff[category] = true
										break
									end
								end
							end
						end
					end

					for category, present in pairs(hasBuff) do
						if not present then
							table.insert(
								missingByBuff[category],
								playerName .. " (" .. tostring(team) .. "-" .. formatPlayerName(member) .. ")"
							)
						end
					end
				else
					--out of range handler?
				end
			end
		end
	end

	for category, missingList in pairs(missingByBuff) do
		if #missingList > 0 then
			local message = string.format(
				"The following people are missing the %s buff: %s",
				category,
				table.concat(missingList, ", ")
			)
			X2Chat:DispatchChatMessage(CMF_SYSTEM, message)
		end
	end
end

local raidBuffsButton = CreateSimpleButton("Raid Buffs", 700, -230)

function raidBuffsButton:OnClick()
	checkBuffs()
end
raidBuffsButton:SetHandler("OnClick", raidBuffsButton.OnClick)
