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
ADDON:ImportObject(OBJECT_TYPE.STATUS_BAR)

ADDON:ImportAPI(API_TYPE.OPTION.id)
ADDON:ImportAPI(API_TYPE.CHAT.id)
ADDON:ImportAPI(API_TYPE.ACHIEVEMENT.id)
ADDON:ImportAPI(API_TYPE.UNIT.id)
ADDON:ImportAPI(API_TYPE.LOCALE.id)
ADDON:ImportAPI(API_TYPE.TEAM.id)

local refreshForcer = CreateEmptyWindow("refreshForcer", "UIParent")
refreshForcer:Show(true)
local dancers = {}
local drawableNmyIcons = {}
local drawableNmyBars = {}
local castTimers = {}
local counter = 0
local DANCER_SCAN_INTERVAL_MS = 10000

local function isDancer(templates)
	if templates == nil or templates[1] == nil or templates[2] == nil or templates[3] == nil then
		return false
	end

	--local templates = X2Unit:GetTargetAbilityTemplates("player")
	local indices = {
		templates[1].index,
		templates[2].index,
		templates[3].index,
	}
	table.sort(indices)
	--X2Chat:DispatchChatMessage(CMF_SYSTEM, keyStr)
	-- if person has dancer class
	if indices[1] == 14 or indices[2] == 14 or indices[3] == 14 then
		return true
	end
	return false
end

local function hideDanceIcon(id)
	if drawableNmyIcons[id] ~= nil then
		drawableNmyIcons[id]:SetVisible(false)
	end
	if drawableNmyBars[id] ~= nil then
		drawableNmyBars[id]:Show(false)
	end
	castTimers[id] = 10000
	drawableNmyIcons[id] = nil
	drawableNmyBars[id] = nil
end

local function updateDancers()
	local currentDancers = {}
	local hasCoRaid = false
	local amountOfRaids = 1
	if X2Unit:UnitName("team_1_1") == nil and X2Unit:UnitName("team1") == nil then
		--X2Chat:DispatchChatMessage(CMF_SYSTEM, "Not in a raid.")
		amountOfRaids = 0
	end
	if X2Unit:UnitName("team_1_1") ~= nil then
		amountOfRaids = 2
		hasCoRaid = true
	end
	for team = 1, amountOfRaids do
		for member = 1, 50 do
			local teamId
			if hasCoRaid then
				teamId = string.format("team_%02d_%02d", team, member)
			else
				teamId = string.format("team%02d", member)
			end
			local playerName = X2Unit:UnitName(teamId)
			local templates = X2Unit:GetTargetAbilityTemplates(teamId)
			--X2Chat:DispatchChatMessage(CMF_SYSTEM, "Checking " .. playerName)
			if playerName ~= nil and isDancer(templates) then
				--X2Chat:DispatchChatMessage(CMF_SYSTEM, "This is a dancer: " .. playerName .. " " .. teamId)
				currentDancers[playerName] = teamId
			end
		end
	end

	for _, oldTeamId in pairs(dancers) do
		local stillTracked = false
		for _, currentTeamId in pairs(currentDancers) do
			if currentTeamId == oldTeamId then
				stillTracked = true
				break
			end
		end
		if not stillTracked then
			hideDanceIcon(oldTeamId)
		end
	end

	dancers = currentDancers
end
-- id = dancer name?
local function drawDanceIcon(id, xOffset, yOffset, dt)
	-- If the icon already exists, don't redraw it, instead update it
	if drawableNmyIcons[id] ~= nil then
		--X2Chat:DispatchChatMessage(CMF_SYSTEM, "Icon already existed, manipulating it")
		if not drawableNmyIcons[id]:IsVisible() then
			drawableNmyIcons[id]:SetVisible(true)
			drawableNmyBars[id]:Show(true)
		end
		drawableNmyIcons[id]:AddAnchor("LEFT", refreshForcer, xOffset - 50, yOffset - 35)
		drawableNmyBars[id]:AddAnchor("LEFT", refreshForcer, xOffset - 25, yOffset - 35)
		castTimers[id] = castTimers[id] - dt
		--drawableNmyBars[id]:SetBarTextureCoords(100,  100, 5000, 2500)
		--statusBar:SetMinMaxValues(0, maxHealth)
		drawableNmyBars[id]:SetValue(castTimers[id])
		--drawableNmyBars[id]:AddAnchor("LEFT", refreshForcer, xOffset-25, yOffset-35)
		return
	end
	--X2Chat:DispatchChatMessage(CMF_SYSTEM, "Doing something")
	-- Create an icon using iconPath
	local drawableIcon = refreshForcer:CreateIconDrawable("artwork")
	drawableIcon:SetExtent(25, 25) -- Width, height
	drawableIcon:ClearAllTextures() -- Every other usage of AddTexture called this first 🤷
	drawableIcon:AddTexture("ui/icon/icon_skill_pleasure14.dds") -- path to dds texture to load
	drawableIcon:SetVisible(true)
	local statusBar = UIParent:CreateWidget("statusbar", "statusBar", refreshForcer)
	statusBar:SetBarTexture("ui/common/hud.dds", "background")
	statusBar:SetBarTextureByKey("casting_status_bar")
	statusBar:SetOrientation("HORIZONTAL")
	statusBar:SetExtent(70, 25) -- Width, height
	statusBar:SetBarColor(1, 1, 0, 1)
	statusBar:Show(true)
	statusBar:SetMinMaxValues(0, 10000)
	statusBar:SetValue(10000)
	drawableNmyIcons[id] = drawableIcon
	drawableNmyBars[id] = statusBar
	castTimers[id] = 10000
end

function refreshForcer:OnUpdate(dt)
	-- check if any dancer is currently dancing
	if next(dancers) ~= nil then
		for playerName, teamId in pairs(dancers) do
			--X2Chat:DispatchChatMessage(CMF_SYSTEM, "Player: " .. playerName .. ", Team ID: " .. teamId)
			local UBuffCount = X2Unit:UnitBuffCount(teamId)
			local stillDancing = false
			for i = 1, UBuffCount do
				local buffExtra = X2Unit:UnitBuff(teamId, i)
				--if playerName == "Strawberry" then
				--    X2Chat:DispatchChatMessage(CMF_SYSTEM, tostring(buffExtra["buff_id"]))
				--end
				if
					buffExtra["buff_id"] == 30098
					or buffExtra["buff_id"] == 30137
					or buffExtra["buff_id"] == 30141
					or buffExtra["buff_id"] == 30142
				then
					--X2Chat:DispatchChatMessage(CMF_SYSTEM, playerName .. " DANCE ID FOUND")
					stillDancing = true
					local nScrX_Tar, nScrY_Tar, nScrZ_Tar = X2Unit:GetUnitScreenPosition(teamId)
					if nScrX_Tar == nil or nScrY_Tar == nil or nScrZ_Tar == nil then
						--X2Chat:DispatchChatMessage(CMF_SYSTEM, "dancing off screen")
						hideDanceIcon(teamId)
						break
					end
					drawDanceIcon(teamId, nScrX_Tar, nScrY_Tar, dt)
					--X2Chat:DispatchChatMessage(CMF_SYSTEM, playerName .. " is dancing ++++++++++")
				end
			end
			if stillDancing == false and drawableNmyIcons[teamId] ~= nil then
				--X2Chat:DispatchChatMessage(CMF_SYSTEM, "Dancing has stopped. Setting all to zero & invisible.")
				hideDanceIcon(teamId)
			end
			--if stillDancing == false then
			--    X2Chat:DispatchChatMessage(CMF_SYSTEM, playerName .. "is not dancing ----------")
			--end
		end
	end
	if counter > DANCER_SCAN_INTERVAL_MS then
		--X2Chat:DispatchChatMessage(CMF_SYSTEM, "Checking dancers.")
		updateDancers()
		counter = 0
	end
	--X2Chat:DispatchChatMessage(CMF_SYSTEM, tostring(counter))
	counter = counter + dt
end

local function RosterChanged(reason)
	if reason == "joined_by_self" or reason == "joined" or reason == "leaved" or reason == "moved" then
		updateDancers()
	elseif reason == "leaved_by_self" or reason == "kicked_by_self" or reason == "dismissed" then
		--empty out dancer, go dormant
		for _, teamId in pairs(dancers) do
			hideDanceIcon(teamId)
		end
		dancers = {}
	end
end

--if this gets triggered, scan all spots for dancers, then track said dancers
UIParent:SetEventHandler(UIEVENT_TYPE.TEAM_MEMBERS_CHANGED, RosterChanged)

updateDancers()
refreshForcer:SetHandler("OnUpdate", refreshForcer.OnUpdate)
