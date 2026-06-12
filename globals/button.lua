--make simple button
local SIMPLE_BUTTON_REGISTRY_PATHS = {
	"simple_button_slots.txt",
}
local SIMPLE_BUTTON_WIDTH = 80
local SIMPLE_BUTTON_HEIGHT = 25
local SIMPLE_BUTTON_GAP = 4
local SIMPLE_BUTTON_COLUMN_GAP = 6
local SIMPLE_BUTTON_MAX_PER_COLUMN = 12

local function GetSimpleButtonAddonSignature()
	if ADDON == nil or ADDON.GetAddonInfos == nil then
		return "unknown"
	end

	local ok, addons = pcall(function()
		return ADDON:GetAddonInfos()
	end)
	if not ok or addons == nil then
		return "unknown"
	end

	local names = {}
	for _, addon in pairs(addons) do
		if addon ~= nil and addon.enable and addon.name ~= nil then
			table.insert(names, tostring(addon.name))
		end
	end

	table.sort(names)
	return table.concat(names, "|")
end

local function ReadSimpleButtonSlots()
	local slots = {}
	local addonSignature = nil
	if io == nil or io.open == nil then
		return slots, addonSignature
	end

	local file
	for i = 1, #SIMPLE_BUTTON_REGISTRY_PATHS do
		file = io.open(SIMPLE_BUTTON_REGISTRY_PATHS[i], "r")
		if file ~= nil then
			break
		end
	end

	if file == nil then
		return slots, addonSignature
	end

	for line in file:lines() do
		local headerSignature = string.match(line, "^addons=(.*)$")
		if headerSignature ~= nil then
			addonSignature = headerSignature
		else
			local slot, name = string.match(line, "^(%d+)\t(.+)$")
			slot = tonumber(slot)
			if slot ~= nil and name ~= nil and name ~= "" then
				slots[name] = slot
			end
		end
	end

	file:close()
	return slots, addonSignature
end

local function WriteSimpleButtonSlots(slots, addonSignature)
	if io == nil or io.open == nil then
		return false
	end

	local file
	for i = 1, #SIMPLE_BUTTON_REGISTRY_PATHS do
		file = io.open(SIMPLE_BUTTON_REGISTRY_PATHS[i], "w")
		if file ~= nil then
			break
		end
	end

	if file == nil then
		return false
	end

	local rows = {}
	for name, slot in pairs(slots) do
		table.insert(rows, { name = name, slot = slot })
	end

	table.sort(rows, function(left, right)
		if left.slot == right.slot then
			return left.name < right.name
		end
		return left.slot < right.slot
	end)

	file:write(string.format("addons=%s\n", addonSignature or GetSimpleButtonAddonSignature()))
	for i = 1, #rows do
		file:write(string.format("%d\t%s\n", rows[i].slot, rows[i].name))
	end

	file:close()
	return true
end

local function GetFallbackSimpleButtonSlot(y)
	local yOffset = math.abs(tonumber(y) or 0)
	local slot = math.floor((yOffset - 120) / 30) + 1
	if slot < 1 then
		slot = 1
	end
	return slot
end

local function ClaimSimpleButtonSlot(buttonText, y)
	local name = tostring(buttonText or "")
	local currentAddonSignature = GetSimpleButtonAddonSignature()
	local slots, savedAddonSignature = ReadSimpleButtonSlots()

	if savedAddonSignature ~= currentAddonSignature then
		slots = {}
	end

	if slots[name] ~= nil then
		return slots[name]
	end

	local used = {}
	for _, slot in pairs(slots) do
		used[slot] = true
	end

	local slot = 1
	while used[slot] do
		slot = slot + 1
	end

	slots[name] = slot
	if WriteSimpleButtonSlots(slots, currentAddonSignature) then
		return slot
	end

	return GetFallbackSimpleButtonSlot(y)
end

local function SetSimpleButtonSlot(button, slot)
	local index = slot - 1
	local column = math.floor(index / SIMPLE_BUTTON_MAX_PER_COLUMN)
	local row = index % SIMPLE_BUTTON_MAX_PER_COLUMN

	button.simpleButtonX = 8 + column * (SIMPLE_BUTTON_WIDTH + SIMPLE_BUTTON_COLUMN_GAP)
	button.simpleButtonY = 38 + row * (SIMPLE_BUTTON_HEIGHT + SIMPLE_BUTTON_GAP)
end

local function UpdateSimpleButtonPosition(button, force)
	local configX, configY, configW, _, isVisible = ADDON:GetContentMainScriptPosVis(UIC_SYSTEM_CONFIG_FRAME)

	if not isVisible then
		if button.simpleButtonVisible == false and not force then
			return
		end

		button.simpleButtonVisible = false
		button:Show(false)
		return
	end

	if
		not force
		and button.simpleButtonVisible == true
		and button.simpleButtonLastConfigX == configX
		and button.simpleButtonLastConfigY == configY
		and button.simpleButtonLastConfigW == configW
	then
		return
	end

	button.simpleButtonVisible = true
	button.simpleButtonLastConfigX = configX
	button.simpleButtonLastConfigY = configY
	button.simpleButtonLastConfigW = configW

	button:RemoveAllAnchors()
	button:AddAnchor("TOPLEFT", "UIParent", configX + configW + button.simpleButtonX, configY + button.simpleButtonY)
	button:Show(true)
end

local function EnsureSimpleButtonWatcher(button)
	if button.simpleButtonWatcher ~= nil then
		return
	end

	local watcher = UIParent:CreateWidget("window", string.format("%sWatcher", button.simpleButtonWidgetId), "UIParent")
	watcher:SetExtent(1, 1)
	watcher:AddAnchor("TOPLEFT", "UIParent", "BOTTOMRIGHT", 100, 100)
	watcher:Show(true)
	watcher:SetHandler("OnUpdate", function()
		UpdateSimpleButtonPosition(button)
	end)

	button.simpleButtonWatcher = watcher
end

function CreateSimpleButton(buttonText, x, y)
	local slot = ClaimSimpleButtonSlot(buttonText, y)
	local widgetId = string.format("simpleButton%d", slot)

	local newButton = UIParent:CreateWidget("button", widgetId, "UIParent", "")
	newButton.simpleButtonWidgetId = widgetId
	newButton:SetText(buttonText)
	newButton:SetStyle("text_default")
	newButton:SetHeight(SIMPLE_BUTTON_HEIGHT)
	newButton:SetWidth(SIMPLE_BUTTON_WIDTH)
	newButton:Show(false)
	newButton:EnableDrag(false)

	SetSimpleButtonSlot(newButton, slot)
	EnsureSimpleButtonWatcher(newButton)
	UpdateSimpleButtonPosition(newButton, true)

	return newButton
end

------------ generic from rage --------------------
function SetButtonFontColor(button, color)
	local n = color.normal
	local h = color.highlight
	local p = color.pushed
	local d = color.disabled

	button:SetTextColor(n[1], n[2], n[3], n[4])
	button:SetHighlightTextColor(h[1], h[2], h[3], h[4])
	button:SetPushedTextColor(p[1], p[2], p[3], p[4])
	button:SetDisabledTextColor(d[1], d[2], d[3], d[4])
end

function SetButtonFontColorByKey(button, key, useSameColor)
	if useSameColor then
		local color = F_COLOR.GetColor(key)

		button:SetTextColor(color[1], color[2], color[3], color[4])
		button:SetHighlightTextColor(color[1], color[2], color[3], color[4])
		button:SetPushedTextColor(color[1], color[2], color[3], color[4])
		button:SetDisabledTextColor(color[1], color[2], color[3], color[4])
	else
		local color = {
			normal = F_COLOR.GetColor(string.format("%s_df", key)),
			highlight = F_COLOR.GetColor(string.format("%s_ov", key)),
			pushed = F_COLOR.GetColor(string.format("%s_on", key)),
			disabled = F_COLOR.GetColor(string.format("%s_dis", key)),
		}

		local n = color.normal
		local h = color.highlight
		local p = color.pushed
		local d = color.disabled

		button:SetTextColor(n[1], n[2], n[3], n[4])
		button:SetHighlightTextColor(h[1], h[2], h[3], h[4])
		button:SetPushedTextColor(p[1], p[2], p[3], p[4])
		button:SetDisabledTextColor(d[1], d[2], d[3], d[4])
	end
end

function SetButtonFontOneColor(button, color)
	button:SetTextColor(color[1], color[2], color[3], color[4])
	button:SetPushedTextColor(color[1], color[2], color[3], color[4])
	button:SetHighlightTextColor(color[1], color[2], color[3], color[4])
	button:SetDisabledTextColor(color[1], color[2], color[3], color[4])
end

local function InitButton(button)
	button:EnableDrawables("background")

	button.style:SetSnap(true)
	button.style:SetShadow(false)

	SetButtonFontColor(button, GetButtonDefaultFontColor())
end
--------------------------aaaaaaaaaaaaaaaaaaaaaaaAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAaaaaaaaaaaaaaaaaaaaaaaa---------------------------------
local function CreateButtonBgImg(button, drawableType, path, layer, inset)
	local bg = nil

	if drawableType == "drawable" then
		local message =
			string.format("button creating with path: %s %s %s", dump(button), tostring(path), tostring(drawableType))
		X2Chat:DispatchChatMessage(CMF_SYSTEM, message)
		bg = button:CreateImageDrawable(path, layer)
	elseif drawableType == "threePart" then
		bg = button:CreateThreePartDrawable(path, layer)
		bg:SetInset(inset[1], inset[2], inset[3], inset[4])
	elseif drawableType == "ninePart" then
		bg = button:CreateNinePartDrawable(path, layer)
		bg:SetInset(inset[1], inset[2], inset[3], inset[4])
	elseif drawableType == "colorDrawable" then
		bg = button:CreateColorDrawable(1, 1, 1, 1, layer)
	end

	return bg
end

local function AnchorButtonDrawables(button, bgsTable, drawableAnchor, drawableExtent)
	for i = 1, #bgsTable do
		if drawableAnchor ~= nil and drawableExtent ~= nil then
			bgsTable[i]:RemoveAllAnchors()
			bgsTable[i]:AddAnchor(drawableAnchor.anchor, button, drawableAnchor.x, drawableAnchor.y)
			bgsTable[i]:SetExtent(drawableExtent.width, drawableExtent.height)
		else
			local topleftX, topleftY, bottomrightX, bottomrightY = 0, 0, 0, 0
			if drawableAnchor ~= nil and drawableAnchor.offset ~= nil then
				topleftX = drawableAnchor.offset.topleftX
				topleftY = drawableAnchor.offset.topleftY
				bottomrightX = drawableAnchor.offset.bottomrightX
				bottomrightY = drawableAnchor.offset.bottomrightY
			end

			bgsTable[i]:RemoveAllAnchors()
			bgsTable[i]:AddAnchor("TOPLEFT", button, topleftX, topleftY)
			bgsTable[i]:AddAnchor("BOTTOMRIGHT", button, bottomrightX, bottomrightY)
		end
	end
end

local function ApplyButtonDrawablesColor(bgsTable, drawableColor)
	if #bgsTable > 4 then
		return
	end

	bgsTable[1]:SetColor(
		drawableColor.normal[1],
		drawableColor.normal[2],
		drawableColor.normal[3],
		drawableColor.normal[4]
	)
	bgsTable[2]:SetColor(drawableColor.over[1], drawableColor.over[2], drawableColor.over[3], drawableColor.over[4])
	bgsTable[3]:SetColor(drawableColor.click[1], drawableColor.click[2], drawableColor.click[3], drawableColor.click[4])
	bgsTable[4]:SetColor(
		drawableColor.disable[1],
		drawableColor.disable[2],
		drawableColor.disable[3],
		drawableColor.disable[4]
	)
end

function CreateButtonBackGround(button, drawableType, path, layer, count, inset, drawableAnchor, drawableExtent)
	button.bgs = {}

	for i = 1, count do
		button.bgs[i] = CreateButtonBgImg(button, drawableType, path, layer, inset)
	end

	AnchorButtonDrawables(button, button.bgs, drawableAnchor, drawableExtent)
end

local function SetBackGroundsCoords(bgsTable, drawableType, coords)
	if drawableType ~= "colorDrawable" then
		bgsTable[1]:SetCoords(coords.normal[1], coords.normal[2], coords.normal[3], coords.normal[4]) -- #273524 BUTTON, TODO
		bgsTable[2]:SetCoords(coords.over[1], coords.over[2], coords.over[3], coords.over[4])
		bgsTable[3]:SetCoords(coords.click[1], coords.click[2], coords.click[3], coords.click[4])
		bgsTable[4]:SetCoords(coords.disable[1], coords.disable[2], coords.disable[3], coords.disable[4])
	end
end

local function IsValidCoordsKey(path, key, useSameTexture)
	if useSameTexture then
		return UIParent:GetTextureData(path, key) ~= nil
	else
		local statusKey = {
			string.format("%s_df", key),
			string.format("%s_ov", key),
			string.format("%s_on", key),
			string.format("%s_dis", key),
		}

		for i = 1, #statusKey do
			local info = UIParent:GetTextureData(path, statusKey[i])
			if info == nil then
				return false
			end
		end

		return true
	end
end

local function GetCoords(path, key)
	local data = UIParent:GetTextureData(path, key)
	if data == nil then
		return { 0, 0, 16, 16 }
	end

	return data["coords"]
end

local function GetBackGroundsCoordsByKey(path, key, useSameTexture)
	local textureInfoTable = {}

	if useSameTexture then
		local coords = GetCoords(path, key)
		textureInfoTable.normal = coords
		textureInfoTable.over = coords
		textureInfoTable.click = coords
		textureInfoTable.disable = coords
	else
		textureInfoTable.normal = GetCoords(path, string.format("%s_df", key))
		textureInfoTable.over = GetCoords(path, string.format("%s_ov", key))
		textureInfoTable.click = GetCoords(path, string.format("%s_on", key))
		textureInfoTable.disable = GetCoords(path, string.format("%s_dis", key))
	end

	return textureInfoTable
end

local function GetWhiteColors()
	local colorInfo = {
		normal = { 1, 1, 1, 1 },
		over = { 1, 1, 1, 1 },
		click = { 1, 1, 1, 1 },
		disable = { 1, 1, 1, 1 },
	}

	return colorInfo
end

function GetColorFromTexture(path, key, colorKey)
	local info = UIParent:GetTextureData(path, key)
	if info == nil then
		return { 1, 1, 1, 1 }
	end

	local colors = info["colors"]
	if colors == nil then
		return { 1, 1, 1, 1 }
	end

	local color = colors[colorKey]
	if color == nil then
		color = { 1, 1, 1, 1 }
	end

	return color
end

local function GetBackGroundsColorByKey(path, key, colorKey, useSameTexture)
	if colorKey == nil then
		return GetWhiteColors()
	end

	if useSameTexture then
		local color = GetColorFromTexture(path, key, colorKey)

		local colorInfo = {
			normal = color,
			over = color,
			click = color,
			disable = color,
		}

		return colorInfo
	else
		local colorInfo = {
			normal = GetColorFromTexture(path, string.format("%s_df", key), colorKey),
			over = GetColorFromTexture(path, string.format("%s_ov", key), colorKey),
			click = GetColorFromTexture(path, string.format("%s_on", key), colorKey),
			disable = GetColorFromTexture(path, string.format("%s_dis", key), colorKey),
		}

		return colorInfo
	end
end

local function GetBackGroundsColorByDrawableKey(path, key, drawableKey, useSameTexture)
	if useSameTexture then
		local colorInfo = {
			normal = GetColorFromTexture(path, key, drawableKey.normal),
			over = GetColorFromTexture(path, key, drawableKey.over),
			click = GetColorFromTexture(path, key, drawableKey.click),
			disable = GetColorFromTexture(path, key, drawableKey.disable),
		}
		return colorInfo
	else
		local colorInfo = {
			normal = GetColorFromTexture(path, string.format("%s_df", key), drawableKey.normal),
			over = GetColorFromTexture(path, string.format("%s_ov", key), drawableKey.over),
			click = GetColorFromTexture(path, string.format("%s_on", key), drawableKey.click),
			disable = GetColorFromTexture(path, string.format("%s_dis", key), drawableKey.disable),
		}
		return colorInfo
	end
end

local function GetBackgroundExtentByKey(path, key, useSameTexture)
	local formidableKey = key
	if not useSameTexture then
		formidableKey = string.format("%s_df", key)
	end

	local extentTable = {
		width = 0,
		height = 0,
	}

	local textureData = UIParent:GetTextureData(path, formidableKey)
	if textureData ~= nil then
		extentTable.width = textureData["extent"][1]
		extentTable.height = textureData["extent"][2]
	end

	return extentTable
end

local function GetBackGroundsInsetByKey(path, key, useSameTexture)
	local formidableKey = key
	if not useSameTexture then
		formidableKey = string.format("%s_df", key)
	end

	local textureData = UIParent:GetTextureData(path, formidableKey)
	if textureData == nil then
		return 0, 0
	end

	return textureData["inset"]
end

function SetButtonTooltip(button, tooltipText)
	if tooltipText == nil then
		return
	end

	function button:OnEnter()
		SetTooltip(tooltipText, button)
	end
	button:SetHandler("OnEnter", button.OnEnter)
end

-------------------------------------------------------------------------------------------------------------------------------
function ApplyButtonSkin(button, skinInfo)
	if drawable == "drawable" then
		skinInfo.inset = nil
	end

	local drawableType = skinInfo.drawableType
	local path = skinInfo.path
	local inset = skinInfo.inset
	local drawableAnchor = skinInfo.drawableAnchor
	local drawableExtent = skinInfo.drawableExtent
	local count = 4

	local layer = skinInfo.layer
	if layer == nil then
		layer = "background"
	end

	local drawableColor = skinInfo.drawableColor

	if drawableColor == nil then
		drawableColor = {}

		drawableColor.normal = { 1, 1, 1, 1 }
		drawableColor.over = { 1, 1, 1, 1 }
		drawableColor.click = { 1, 1, 1, 1 }
		drawableColor.disable = { 1, 1, 1, 1 }
	end

	local fontSize = skinInfo.fontSize
	if fontSize == nil then
		fontSize = 13
	end

	local fontPath = skinInfo.fontPath
	if fontPath == nil then
		fontPath = "font_main"
	end

	local fontAlign = skinInfo.fontAlign
	if fontAlign == nil then
		fontAlign = ALIGN_CENTER
	end

	local fontInset = skinInfo.fontInset
	if fontInset == nil then
		fontInset = {
			left = 0,
			top = 0,
			bottom = 0,
			right = 0,
		}
	end

	local ellipsis = skinInfo.ellipsis
	if ellipsis == nil then
		ellipsis = false
	end

	local disuseExtent = skinInfo.disuseExtent
	if disuseExtent == nil then
		disuseExtent = false
	end

	local useSameTexture = skinInfo.useSameTexture
	if useSameTexture == nil then
		useSameTexture = false
	end

	if skinInfo.coordsKey ~= nil then
		if IsValidCoordsKey(path, skinInfo.coordsKey, useSameTexture) then
			skinInfo.coords = GetBackGroundsCoordsByKey(path, skinInfo.coordsKey, useSameTexture)
			drawableExtent = GetBackgroundExtentByKey(path, skinInfo.coordsKey, useSameTexture)
			inset = GetBackGroundsInsetByKey(path, skinInfo.coordsKey, useSameTexture)
			drawableColor = GetBackGroundsColorByKey(path, skinInfo.coordsKey, skinInfo.colorKey, useSameTexture)

			if not disuseExtent and skinInfo.width == nil and skinInfo.height == nil then
				skinInfo.width = drawableExtent.width
				skinInfo.height = drawableExtent.height
			end
		else
			drawableType = "drawable"
			path = INVALID_ICON_PATH
			skinInfo.coords = {
				normal = { 0, 0, 40, 40 },
				over = { 0, 0, 40, 40 },
				click = { 0, 0, 40, 40 },
				disable = { 0, 0, 40, 40 },
			}
			skinInfo.width = 40
			skinInfo.height = 40
		end
	end

	if skinInfo.drawableColorKey ~= nil then
		drawableColor =
			GetBackGroundsColorByDrawableKey(path, skinInfo.coordsKey, skinInfo.drawableColorKey, useSameTexture)
	end

	local autoResize = skinInfo.autoResize
	if autoResize == nil then
		autoResize = false
	end

	button.style:SetFont(fontPath, fontSize)

	local str = button:GetText()
	local strWidth = button.style:GetTextWidth(str) or 0
	local compareWidth = strWidth + fontInset.left + fontInset.right
	if autoResize then
		if str == "" or str == nil then
			autoResize = false
		end

		if skinInfo.width == nil then
			autoResize = false
		end

		if skinInfo.width ~= nil and compareWidth < skinInfo.width then
			autoResize = false
		end
	end

	CreateButtonBackGround(button, drawableType, path, layer, count, inset, drawableAnchor, drawableExtent)
	SetButtonBackground(button)
	SetBackGroundsCoords(button.bgs, drawableType, skinInfo.coords)
	ApplyButtonDrawablesColor(button.bgs, drawableColor)

	if skinInfo.width ~= nil and skinInfo.height ~= nil then
		button:SetExtent(skinInfo.width, skinInfo.height)
	end

	if skinInfo.fontColor ~= nil then
		SetButtonFontColor(button, skinInfo.fontColor)
	elseif skinInfo.fontColorKey ~= nil then
		SetButtonFontColorByKey(button, skinInfo.fontColorKey, skinInfo.useSameColor)
	else
		SetButtonFontColor(button, GetButtonDefaultFontColor())
	end

	button.style:SetSnap(true)
	button.style:SetShadow(false)

	if ellipsis then
		F_TEXT.ApplyAutoEllipsisTooltipText(button, fontInset.left + fontInset.right)
	end

	button.style:SetAlign(fontAlign)
	button:SetInset(fontInset.left, fontInset.top, fontInset.right, fontInset.bottom)
	button:SetAutoResize(autoResize)
end

local function ChangeTexturePathTable(bgsTable, path)
	for i = 1, #bgsTable do
		bgsTable[i]:SetTexture(path)
	end
end

function ChangeButtonSkin(button, skinInfo)
	local drawableColor = skinInfo.drawableColor
	if drawableColor == nil then
		drawableColor = {}

		drawableColor.normal = { 1, 1, 1, 1 }
		drawableColor.over = { 1, 1, 1, 1 }
		drawableColor.click = { 1, 1, 1, 1 }
		drawableColor.disable = { 1, 1, 1, 1 }
	end

	ChangeTexturePathTable(button.bgs, skinInfo.path)

	local disuseExtent = skinInfo.disuseExtent
	if disuseExtent == nil then
		disuseExtent = false
	end

	local useSameTexture = skinInfo.useSameTexture
	if useSameTexture == nil then
		useSameTexture = false
	end

	if skinInfo.coordsKey ~= nil then
		skinInfo.coords = GetBackGroundsCoordsByKey(skinInfo.path, skinInfo.coordsKey, useSameTexture)
		skinInfo.drawableExtent = GetBackgroundExtentByKey(skinInfo.path, skinInfo.coordsKey, useSameTexture)
		skinInfo.inset = GetBackGroundsInsetByKey(skinInfo.path, skinInfo.coordsKey, useSameTexture)
		drawableColor = GetBackGroundsColorByKey(skinInfo.path, skinInfo.coordsKey, skinInfo.colorKey, useSameTexture)

		if not disuseExtent and skinInfo.width == nil and skinInfo.height == nil then
			skinInfo.width = skinInfo.drawableExtent.width
			skinInfo.height = skinInfo.drawableExtent.height
		end
	end

	if skinInfo.drawableColorKey ~= nil then
		drawableColor = GetBackGroundsColorByDrawableKey(
			skinInfo.path,
			skinInfo.coordsKey,
			skinInfo.drawableColorKey,
			useSameTexture
		)
	end

	SetBackGroundsCoords(button.bgs, drawableType, skinInfo.coords)
	AnchorButtonDrawables(button, button.bgs, skinInfo.drawableAnchor, skinInfo.drawableExtent)
	ApplyButtonDrawablesColor(button.bgs, drawableColor)

	if skinInfo.width ~= nil and skinInfo.height ~= nil then
		button:SetExtent(skinInfo.width, skinInfo.height)
	end

	if skinInfo.fontColor ~= nil then
		SetButtonFontColor(button, skinInfo.fontColor)
	elseif skinInfo.fontColorKey ~= nil then
		SetButtonFontColorByKey(button, skinInfo.fontColorKey, skinInfo.useSameColor)
	else
		SetButtonFontColor(button, GetButtonDefaultFontColor())
	end

	local fontInset = skinInfo.fontInset
	if fontInset == nil then
		fontInset = {
			left = 0,
			top = 0,
			bottom = 0,
			right = 0,
		}
	end

	local fontSize = skinInfo.fontSize
	if fontSize == nil then
		fontSize = FONT_SIZE.MIDDLE
	end

	local fontPath = skinInfo.fontPath
	if fontPath == nil then
		fontPath = FONT_PATH.DEFAULT
	end

	button.style:SetFont(fontPath, fontSize)

	local autoResize = skinInfo.autoResize
	if autoResize == nil then
		autoResize = false
	end

	local str = button:GetText()
	local strWidth = button.style:GetTextWidth(str) or 0
	local compareWidth = strWidth + fontInset.left + fontInset.right
	if autoResize then
		if str == "" or str == nil then
			autoResize = false
		end

		if skinInfo.width == nil then
			autoResize = false
		end

		if skinInfo.width ~= nil and compareWidth < skinInfo.width then
			autoResize = false
		end
	end
	button:SetAutoResize(autoResize)
	button:SetInset(fontInset.left, fontInset.top, fontInset.right, fontInset.bottom)
end

------------------------------------------------------------------------------------------------------------------------------------------
function AddButtonSkin(button, bgsTable, skinInfo)
	if drawable == "drawable" then
		skinInfo.inset = nil
	end

	local drawableType = skinInfo.drawableType
	local path = skinInfo.path
	local inset = skinInfo.inset
	local drawableAnchor = skinInfo.drawableAnchor
	local drawableExtent = skinInfo.drawableExtent

	local layer = skinInfo.layer
	if layer == nil then
		layer = "artwork"
	end

	local count = 4

	local drawableColor = skinInfo.drawableColor
	if drawableColor == nil then
		drawableColor = {}

		drawableColor.normal = { 1, 1, 1, 1 }
		drawableColor.over = { 1, 1, 1, 1 }
		drawableColor.click = { 1, 1, 1, 1 }
		drawableColor.disable = { 1, 1, 1, 1 }
	end

	local useSameTexture = skinInfo.useSameTexture
	if useSameTexture == nil then
		useSameTexture = false
	end

	if skinInfo.coordsKey ~= nil then
		skinInfo.coords = GetBackGroundsCoordsByKey(path, skinInfo.coordsKey, useSameTexture)
		drawableExtent = GetBackgroundExtentByKey(path, skinInfo.coordsKey, useSameTexture)
	end

	local uiState = {
		UI_BUTTON_NORMAL,
		UI_BUTTON_HIGHLIGHTED,
		UI_BUTTON_PUSHED,
		UI_BUTTON_DISABLED,
	}

	local EnumdrawableType = {
		["drawable"] = UOT_IMAGE_DRAWABLE,
		["threePart"] = UOT_THREE_PART_DRAWABLE,
		["ninePart"] = UOT_NINE_PART_DRAWABLE,
		["colorDrawable"] = UOT_COLOR_DRAWABLE,
	}

	for i = 1, UI_BUTTON_MAX do
		bgsTable[i] = button:CreateStateDrawable(uiState[i], EnumdrawableType[drawableType], path, layer)
	end

	SetBackGroundsCoords(bgsTable, drawableType, skinInfo.coords)
	AnchorButtonDrawables(button, bgsTable, drawableAnchor, drawableExtent)
	ApplyButtonDrawablesColor(bgsTable, drawableColor)
end

function ApplyButtonSkinTable(button, skinInfoTable)
	if #skinInfoTable < 2 or #skinInfoTable > 3 then
		return
	end

	for i = 1, #skinInfoTable do
		if i == 1 then
			ApplyButtonSkin(button, skinInfoTable[i])
		elseif i == 2 then
			button.add_bgs1 = {}
			AddButtonSkin(button, button.add_bgs1, skinInfoTable[i])
		elseif i == 3 then
			button.add_bgs2 = {}
			AddButtonSkin(button, button.add_bgs2, skinInfoTable[i])
		end
	end
end

function ChangeButtonAddSkin(button, bgsTable, skinInfo)
	local drawableColor = skinInfo.drawableColor
	if drawableColor == nil then
		drawableColor = {}

		drawableColor.normal = { 1, 1, 1, 1 }
		drawableColor.over = { 1, 1, 1, 1 }
		drawableColor.click = { 1, 1, 1, 1 }
		drawableColor.disable = { 1, 1, 1, 1 }
	end

	ChangeTexturePathTable(bgsTable, skinInfo.path)

	if skinInfo.coordsKey ~= nil then
		skinInfo.coords = GetBackGroundsCoordsByKey(skinInfo.path, skinInfo.coordsKey)
		skinInfo.drawableExtent = GetBackgroundExtentByKey(skinInfo.path, skinInfo.coordsKey)
	end

	SetBackGroundsCoords(bgsTable, drawableType, skinInfo.coords)
	AnchorButtonDrawables(button, bgsTable, skinInfo.drawableAnchor, skinInfo.drawableExtent)
	ApplyButtonDrawablesColor(bgsTable, drawableColor)
end

function ChangeButtonSkinTable(button, skinInfoTable)
	if #skinInfoTable < 2 or #skinInfoTable > 3 then
		return
	end

	for i = 1, #skinInfoTable do
		if i == 1 then
			ChangeButtonSkin(button, skinInfoTable[i])
		elseif i == 2 then
			ChangeButtonAddSkin(button, button.add_bgs1, skinInfoTable[i])
		elseif i == 3 then
			ChangeButtonAddSkin(button, button.add_bgs2, skinInfoTable[i])
		end
	end
end

function ButtonOnClickHandler(button, leftButtonClickFunc, rightButtonClickFunc)
	local function OnClick(self, arg)
		if arg == "RightButton" then
			if rightButtonClickFunc == nil then
				return
			end

			rightButtonClickFunc(self)
		end

		if arg == "LeftButton" then
			if leftButtonClickFunc == nil then
				return
			end

			leftButtonClickFunc(self)
		end
	end
	button:SetHandler("OnClick", OnClick)

	if rightButtonClickFunc ~= nil then
		button:RegisterForClicks("RightButton")
	end
end

function AdjustBtnLongestTextWidth(buttonTable, fixedWidth)
	if fixedWidth ~= nil and fixedWidth ~= 0 then
		for i = 1, #buttonTable do
			buttonTable[i]:SetAutoResize(false)
			buttonTable[i]:SetWidth(fixedWidth)
		end

		return
	end

	local maxWidth = 0
	for i = 1, #buttonTable do
		if maxWidth < buttonTable[i]:GetWidth() then
			maxWidth = buttonTable[i]:GetWidth()
		end
	end

	for i = 1, #buttonTable do
		buttonTable[i]:SetWidth(maxWidth)
	end

	return maxWidth
end

function ReanchorDefaultTextButtonSet(buttonTable, anchorTarget, bottomOffset)
	if #buttonTable > 2 then
		return
	end

	local maxWidth = AdjustBtnLongestTextWidth(buttonTable)

	local offset = maxWidth / 2
	buttonTable[1]:AddAnchor("BOTTOM", anchorTarget, -offset, bottomOffset)
	buttonTable[2]:AddAnchor("BOTTOM", anchorTarget, offset, bottomOffset)
end

function CreateWindowDefaultTextButtonSet(window, infos, target)
	if infos == nil then
		infos = {}
	end

	if infos.leftButtonStr == nil then
		infos.leftButtonStr = locale.common.ok
	end

	if infos.rightButtonStr == nil then
		infos.rightButtonStr = locale.common.cancel
	end

	if infos.isPopupWindow == nil then
		infos.isPopupWindow = false
	end

	local buttonBottomInset = -MARGIN.WINDOW_SIDE
	if infos.isPopupWindow then
		buttonBottomInset = BUTTON_COMMON_INSET.MESSAGEBOX_BOTTOM
	end

	if infos.buttonBottomInset ~= nil then
		buttonBottomInset = infos.buttonBottomInset
	end

	if infos.fixedWidth ~= nil then
		infos.fixedWidth = 0
	end

	local leftButton = window:CreateChildWidget("button", "leftButton", 0, true)
	leftButton:SetText(infos.leftButtonStr)
	ApplyButtonSkin(leftButton, BUTTON_BASIC.DEFAULT)

	if infos.leftButtonLeftClickFunc ~= nil or infos.leftButtonRightClickFunc ~= nil then
		ButtonOnClickHandler(leftButton, infos.leftButtonLeftClickFunc, infos.leftButtonRightClickFunc)
	end

	local rightButton = window:CreateChildWidget("button", "rightButton", 0, true)
	rightButton:SetText(infos.rightButtonStr)
	ApplyButtonSkin(rightButton, BUTTON_BASIC.DEFAULT)

	if infos.rightButtonLeftClickFunc ~= nil or infos.rightButtonRightClickFunc ~= nil then
		ButtonOnClickHandler(rightButton, infos.rightButtonLeftClickFunc, infos.rightButtonRightClickFunc)
	end

	local buttonTable = { leftButton, rightButton }

	local anchorTarget = window
	if target ~= nil then
		anchorTarget = target
	end

	ReanchorDefaultTextButtonSet(buttonTable, anchorTarget, buttonBottomInset)
end
