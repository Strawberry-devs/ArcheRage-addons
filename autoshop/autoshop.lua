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
ADDON:ImportObject(OBJECT_TYPE.EMPTY_WIDGET)
ADDON:ImportObject(OBJECT_TYPE.LABEL)
ADDON:ImportObject(OBJECT_TYPE.EDITBOX)
ADDON:ImportObject(OBJECT_TYPE.X2_EDITBOX)
ADDON:ImportObject(OBJECT_TYPE.ICON_DRAWABLE)

ADDON:ImportAPI(API_TYPE.CHAT.id)
ADDON:ImportAPI(API_TYPE.AUCTION.id)
ADDON:ImportAPI(API_TYPE.BAG.id)
ADDON:ImportAPI(API_TYPE.CRAFT.id)

local WINDOW_WIDTH = 560
local MIN_WINDOW_HEIGHT = 330
local MAX_ROW_COUNT = 24
local ROW_HEIGHT = 22
local ROW_TOP = 248
local FOOTER_HEIGHT = 58
local SAVE_KEY = "autoshop_last_recipe"
local GOLD_ICON = "Addon/autoshop/icons/gold.dds"
local SILVER_ICON = "Addon/autoshop/icons/silver.dds"
local COPPER_ICON = "Addon/autoshop/icons/copper.dds"
local MONEY_ICON_SIZE = 13
local MONEY_ICON_GAP = 1
local MONEY_UNIT_GAP = 6
local MONEY_DIGIT_W = 7
local BUTTON_HEIGHT = 18
local SMALL_BUTTON_WIDTH = 16
local ROW_NAME_WIDTH = 274
local ROW_QTY_WIDTH = 60
local ROW_UNIT_RIGHT = 445
local ROW_TOTAL_RIGHT = WINDOW_WIDTH - 20

local COMPLETE_GREEN = { 0.04, 0.50, 0.08, 1 }
local WARN_ORANGE = { 0.85, 0.40, 0.05, 1 }
local MISSING_RED = { 0.85, 0.15, 0.12, 1 }
local VendorPrices = {
	["Hardtack"] = 2 * 100,
	["Savory Soup"] = 8 * 100,
	["Veiled Flame"] = 4 * 100,
	["Mage's Vapor"] = 6 * 100,
}

local mainWindow = nil
local launcherButton
local recipeEdit = nil
local countEdit = nil
local statusLabel = nil
local targetLabel = nil
local craftLabel = nil
local economyLabel = nil
local craftFeeMoney = nil
local economyMoney = nil
local shoppingLabel = nil
local stepLabel = nil
local rows = {}

local selectedRecipe = nil
local craftCount = 1
local owned = {}
local inventoryOK = false
local plan = nil
local buyQueue = {}
local currentBuyIndex = 0
local waitingForAuction = false
local auctionPrices = {}
local priceCheckQueue = {}
local currentPriceRequest = nil
local priceCheckBusy = false
local priceCheckCD = 1.2
local priceCheckStart = 0
local priceTicker
local recipeCacheByCraftType = {}
local recipeCacheByName = {}
local expandedStages = {}
local rowActions = {}
local DEBUG_PLAN = false
local DEBUG_PRICE = true
local DEBUG_BAD = true

local function Chat(message)
	pcall(function()
		X2Chat:DispatchChatMessage(CMF_SYSTEM, "[AutoShop] " .. tostring(message))
	end)
end

local function PrintDebug(message)
	if type(aaprint) == "function" then
		aaprint("[AutoShop] " .. tostring(message))
	else
		Chat(message)
	end
end

local function DebugPlan(message)
	if DEBUG_PLAN then
		PrintDebug("[plan] " .. tostring(message))
	end
end

local function DebugPrice(message)
	if DEBUG_PRICE then
		PrintDebug("[price] " .. tostring(message))
	end
end

local function DebugBad(message)
	if DEBUG_BAD then
		PrintDebug("[bad] " .. tostring(message))
	end
end

function AutoShop_SetDebug(planDebug, priceDebug, badDebug)
	DEBUG_PLAN = planDebug == true
	DEBUG_PRICE = priceDebug == true
	if badDebug ~= nil then
		DEBUG_BAD = badDebug == true
	end
	PrintDebug(
		"Debug plan="
			.. tostring(DEBUG_PLAN)
			.. " price="
			.. tostring(DEBUG_PRICE)
			.. " bad="
			.. tostring(DEBUG_BAD)
	)
end

function AutoShop_DebugOn()
	AutoShop_SetDebug(true, true, true)
end

function AutoShop_DebugOff()
	AutoShop_SetDebug(false, false, false)
end

local function Trim(value)
	return tostring(value or ""):match("^%s*(.-)%s*$") or ""
end

local function ParseCopper(value)
	if type(value) == "number" then
		return value
	end
	if type(value) ~= "string" then
		return nil
	end
	local lower = value:lower()
	if lower:find("[gsc]") ~= nil then
		local total = 0
		local matched = false
		for amount, unit in lower:gmatch("(%d+)%s*([gsc])") do
			local number = tonumber(amount) or 0
			if unit == "g" then
				total = total + (number * 10000)
			elseif unit == "s" then
				total = total + (number * 100)
			else
				total = total + number
			end
			matched = true
		end
		if matched then
			return total
		end
	end
	local digits = value:gsub("[^%d]", "")
	if digits == "" then
		return nil
	end
	return tonumber(digits)
end

local function SameItemName(a, b)
	return Trim(a):lower() == Trim(b):lower()
end

local function ReadItemName(info)
	if type(info) ~= "table" then
		return nil
	end
	return info.name or info.item_name or info.itemName
end

local function ReadItemType(info)
	if type(info) ~= "table" then
		return nil
	end
	return tonumber(info.itemType or info.item_type or info.type)
end

local function ReadMaterialRequiredCount(material)
	if type(material) ~= "table" then
		return 0
	end
	return tonumber(
		material.amount or material.required or material.requiredAmount or material.need or material.count
	) or 0
end

local function GetCraftTypeByItemType(itemType)
	itemType = tonumber(itemType)
	if itemType == nil or itemType <= 0 or X2Craft == nil or type(X2Craft.GetCraftTypeByItemType) ~= "function" then
		return nil
	end
	local ok, craftType = pcall(function()
		return X2Craft:GetCraftTypeByItemType(itemType)
	end)
	if ok then
		return tonumber(craftType)
	end
	return nil
end

local function ResolveIndexedRecipe(query)
	local clean = Trim(query)
	if clean == "" then
		return nil
	end

	local numeric = tonumber(clean)
	if numeric ~= nil then
		return { name = clean, itemType = numeric, craftType = numeric }
	end

	local lower = clean:lower()
	if type(AutoShopCraftIndex) == "table" then
		for name, data in pairs(AutoShopCraftIndex) do
			if tostring(name):lower() == lower then
				data.name = name
				return data
			end
		end
		for name, data in pairs(AutoShopCraftIndex) do
			if tostring(name):lower():find(lower, 1, true) ~= nil then
				data.name = name
				return data
			end
		end
	end

	if type(AutoShopItemTypes) == "table" then
		for name, itemType in pairs(AutoShopItemTypes) do
			if tostring(name):lower() == lower then
				return { name = name, itemType = itemType }
			end
		end
		for name, itemType in pairs(AutoShopItemTypes) do
			if tostring(name):lower():find(lower, 1, true) ~= nil then
				return { name = name, itemType = itemType }
			end
		end
	end

	return nil
end

local function ResolveCraftType(query)
	local indexed = ResolveIndexedRecipe(query)
	if indexed == nil then
		return nil, nil
	end

	local craftType = GetCraftTypeByItemType(indexed.itemType)
	if craftType == nil then
		craftType = tonumber(indexed.craftType)
	end
	if craftType == nil or craftType <= 0 then
		return nil, indexed.name
	end
	return craftType, indexed.name or query
end

local function LoadLiveRecipe(craftType)
	craftType = tonumber(craftType)
	if craftType == nil or craftType <= 0 then
		return nil
	end
	if recipeCacheByCraftType[craftType] ~= nil then
		return recipeCacheByCraftType[craftType]
	end

	local okBase, baseInfo = pcall(function()
		return X2Craft:GetCraftBaseInfo(craftType)
	end)
	local okProduct, productInfo = pcall(function()
		return X2Craft:GetCraftProductInfo(craftType)
	end)
	local okMaterials, materialInfo = pcall(function()
		return X2Craft:GetCraftMaterialInfo(craftType)
	end)
	if not okBase or not okProduct or not okMaterials or type(productInfo) ~= "table" or type(materialInfo) ~= "table" then
		return nil
	end

	local product = productInfo[1] or {}
	local productName = product.item_name or product.name or tostring(craftType)
	local recipe = {
		name = productName,
		craftType = craftType,
		itemType = tonumber(product.itemType),
		yield = tonumber(product.amount) or 1,
		cost = (type(baseInfo) == "table" and tonumber(baseInfo.cost)) or 0,
		laborcost = (type(baseInfo) == "table" and tonumber(baseInfo.needed_lp or baseInfo.consume_lp)) or 0,
		materials = {},
	}

	for _, material in ipairs(materialInfo) do
		local itemInfo = material.item_info or material.itemInfo or material
		local itemName = ReadItemName(itemInfo) or material.item_name or material.name
		local itemType = ReadItemType(itemInfo) or ReadItemType(material)
		if itemName ~= nil then
			local materialCraftType = GetCraftTypeByItemType(itemType)
			local required = ReadMaterialRequiredCount(material)
			if required <= 0 then
				DebugBad(
					string.format(
						"material quantity is zero: craft=%s material=%s count=%s amount=%s",
						tostring(productName),
						tostring(itemName),
						tostring(material.count),
						tostring(material.amount)
					)
				)
			end
			DebugPlan(
				string.format(
					"material %s itemType=%s craftType=%s count=%s amount=%s required=%s",
					tostring(itemName),
					tostring(itemType),
					tostring(materialCraftType),
					tostring(material.count),
					tostring(material.amount),
					tostring(required)
				)
			)
			recipe.materials[#recipe.materials + 1] = {
				item = itemName,
				itemType = itemType,
				count = required,
				fromStage = materialCraftType ~= nil,
				fromVendor = type(VendorPrices) == "table" and VendorPrices[itemName] ~= nil,
				craftType = materialCraftType,
			}
		end
	end

	recipeCacheByCraftType[craftType] = recipe
	recipeCacheByName[productName] = recipe
	return recipe
end

local function ResolveRecipe(name)
	if recipeCacheByName[name] ~= nil then
		return recipeCacheByName[name]
	end
	local craftType = ResolveCraftType(name)
	if craftType == nil then
		return nil
	end
	return LoadLiveRecipe(craftType)
end

local function FormatMoney(copper)
	copper = math.floor(tonumber(copper) or 0)
	local prefix = ""
	if copper < 0 then
		prefix = "-"
		copper = math.abs(copper)
	end
	local gold = math.floor(copper / 10000)
	copper = copper - (gold * 10000)
	local silver = math.floor(copper / 100)
	copper = copper - (silver * 100)
	local out = {}
	if gold > 0 then
		out[#out + 1] = tostring(gold) .. "g"
	end
	if silver > 0 then
		out[#out + 1] = tostring(silver) .. "s"
	end
	if copper > 0 or #out == 0 then
		out[#out + 1] = tostring(copper) .. "c"
	end
	return prefix .. table.concat(out, " ")
end

local function CopperToParts(copper)
	copper = math.floor(tonumber(copper) or 0)
	local sign = ""
	if copper < 0 then
		sign = "-"
		copper = math.abs(copper)
	end
	local gold = math.floor(copper / 10000)
	copper = copper - (gold * 10000)
	local silver = math.floor(copper / 100)
	copper = copper - (silver * 100)
	return sign, gold, silver, copper
end

local function MeasureMoneyClusterWidth(copper)
	if copper == nil then
		return 0
	end
	local sign, gold, silver, copperPart = CopperToParts(copper)
	local width = 0
	local parts = {}
	if sign ~= "" then
		width = width + 7
	end
	if gold > 0 then
		parts[#parts + 1] = gold
	end
	if silver > 0 then
		parts[#parts + 1] = silver
	end
	if copperPart > 0 or #parts == 0 then
		parts[#parts + 1] = copperPart
	end
	for index, value in ipairs(parts) do
		width = width + ((#tostring(value) * MONEY_DIGIT_W) + 1) + MONEY_ICON_GAP + MONEY_ICON_SIZE
		if index < #parts then
			width = width + MONEY_UNIT_GAP
		end
	end
	return width
end

local ShowMoneyCluster

local function ShowMoneyClusterRight(cluster, copper, rightEdge, y, color)
	local width = MeasureMoneyClusterWidth(copper)
	if width <= 0 then
		HideMoneyCluster(cluster)
		return 0
	end
	return ShowMoneyCluster(cluster, copper, rightEdge - width, y, color)
end

local function GetAuctionUnitPrice(item)
	if item == nil then
		return 0
	end
	local trimmed = Trim(item)
	local exact = tonumber(auctionPrices[item]) or tonumber(auctionPrices[trimmed]) or tonumber(auctionPrices[trimmed:lower()]) or 0
	if exact > 0 then
		return exact
	end
	for name, price in pairs(auctionPrices) do
		if SameItemName(name, item) then
			local parsed = tonumber(price) or 0
			if parsed > 0 then
				return parsed
			end
		end
	end
	return 0
end

local function SetTextColor(widget, color)
	if widget == nil or widget.style == nil or widget.style.SetColor == nil or color == nil then
		return
	end
	widget.style:SetColor(color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1)
end

local function SetTextColorByKey(widget, colorKey)
	if widget == nil or widget.style == nil or widget.style.SetColorByKey == nil then
		return
	end
	widget.style:SetColorByKey(colorKey or "default")
end

local function CreateSectionLine(parent, id, y)
	local line = parent:CreateColorDrawable(0.55, 0.36, 0.10, 0.35, "artwork")
	line:SetExtent(WINDOW_WIDTH - 36, 2)
	line:AddAnchor("TOPLEFT", parent, 18, y)
	return line
end

local function CreateWindowBackground(window)
	local bg = window:CreateDrawable("ui/common/default.dds", "main_bg", "background")
	if bg ~= nil and bg.AddAnchor ~= nil then
		bg:AddAnchor("TOPLEFT", window, -5, -5)
		bg:AddAnchor("BOTTOMRIGHT", window, 5, 5)
		return bg
	end
	bg = window:CreateColorDrawable(0.92, 0.86, 0.66, 0.95, "background")
	bg:AddAnchor("TOPLEFT", window, 0, 0)
	bg:AddAnchor("BOTTOMRIGHT", window, 0, 0)
	return bg
end

local function CreateQuestStylePanel(parent, id, top, bottom, alpha)
	local holder = parent:CreateChildWidget("emptywidget", id, 0, true)
	holder:AddAnchor("TOPLEFT", parent, 14, top)
	holder:AddAnchor("BOTTOMRIGHT", parent, -14, bottom)
	local ok, bg = pcall(function()
		if type(CreateContentBackground) == "function" then
			return CreateContentBackground(holder, "TYPE11", "bg_02", "background")
		end
		return nil
	end)
	if ok and bg ~= nil then
		bg:AddAnchor("TOPLEFT", holder, 0, 0)
		bg:AddAnchor("BOTTOMRIGHT", holder, 0, 0)
	else
		bg = holder:CreateColorDrawable(0.74, 0.64, 0.43, alpha or 0.22, "background")
		bg:AddAnchor("TOPLEFT", holder, 0, 0)
		bg:AddAnchor("BOTTOMRIGHT", holder, 0, 0)
	end
	return holder
end

local function CreateQuestStyleStrip(parent, id, x, y, width, height, alpha)
	local holder = parent:CreateChildWidget("emptywidget", id, 0, true)
	holder:SetExtent(width, height)
	holder:AddAnchor("TOPLEFT", parent, x, y)
	local bg = holder:CreateColorDrawable(0.74, 0.64, 0.43, alpha or 0.16, "background")
	bg:AddAnchor("TOPLEFT", holder, 0, 0)
	bg:AddAnchor("BOTTOMRIGHT", holder, 0, 0)
	return holder
end

local function CreateCloseButton(parent, id, onClick)
	local button = parent:CreateChildWidget("button", id, 0, true)
	button:AddAnchor("TOPRIGHT", parent, 3, -3)
	button:SetStyle("btn_close_default")
	button:SetHandler("OnClick", onClick)
	return button
end

local function StyleLabel(label, fontSize, align, colorKey)
	if label == nil or label.style == nil then
		return
	end
	label.style:SetFontSize(fontSize or 13)
	label.style:SetAlign(align or ALIGN_LEFT)
	SetTextColorByKey(label, "default")
end

local function StyleFlatButton(button)
	if button == nil then
		return
	end
	button.style:SetAlign(ALIGN_CENTER)
	button.style:SetFontSize(12)
	button.style:SetColor(0.35, 0.18, 0.02, 1)
end

local function CreateButton(parent, name, text, x, y, width, onClick)
	local button = parent:CreateChildWidget("label", name, 0, true)
	button:SetExtent(width, BUTTON_HEIGHT)
	button:AddAnchor("TOPLEFT", parent, x, y)
	button:SetText(text)
	StyleFlatButton(button)
	local bg = button:CreateColorDrawable(0.76, 0.59, 0.32, 0.30, "background")
	bg:AddAnchor("TOPLEFT", button, 0, 0)
	bg:AddAnchor("BOTTOMRIGHT", button, 0, 0)
	button:SetHandler("OnClick", onClick)
	return button
end

local function CreateSmallButton(parent, name, text, x, y, onClick)
	local button = parent:CreateChildWidget("label", name, 0, true)
	button:SetExtent(SMALL_BUTTON_WIDTH, BUTTON_HEIGHT)
	button:AddAnchor("TOPLEFT", parent, x, y)
	button:SetText(text)
	StyleFlatButton(button)
	local bg = button:CreateColorDrawable(0.76, 0.59, 0.32, 0.30, "background")
	bg:AddAnchor("TOPLEFT", button, 0, 0)
	bg:AddAnchor("BOTTOMRIGHT", button, 0, 0)
	button:SetHandler("OnClick", onClick)
	return button
end

local function CreateEditBox(parent, id, width)
	local edit = parent:CreateChildWidgetByType(UOT_X2_EDITBOX, id, 0, true)
	edit:SetHeight(BUTTON_HEIGHT)
	edit:SetWidth(width)
	edit:SetInset(5, 5, 5, 5)
	edit:EnableFocus(true)
	edit:UseSelectAllWhenFocused(true)
	edit.style:SetAlign(ALIGN_LEFT)
	edit.style:SetColorByKey("title")

	local bg = edit:CreateDrawable("ui/common/default.dds", "editbox_df", "background")
	bg:AddAnchor("TOPLEFT", edit, 0, 0)
	bg:AddAnchor("BOTTOMRIGHT", edit, 0, 0)
	return edit
end

local function CreateMoneyLabel(parent, id)
	local label = parent:CreateChildWidget("label", id, 0, true)
	label:EnablePick(false)
	label:SetAutoResize(false)
	label:SetHeight(18)
	label.style:SetAlign(ALIGN_LEFT)
	label.style:SetFontSize(12)
	label:Show(false)
	return label
end

local function CreateMoneyIcon(parent, path)
	local icon = parent:CreateIconDrawable("artwork")
	icon:SetExtent(MONEY_ICON_SIZE, MONEY_ICON_SIZE)
	icon:ClearAllTextures()
	icon:AddTexture(path)
	icon:SetVisible(false)
	return icon
end

local function CreateMoneyCluster(parent, prefix)
	return {
		sign = CreateMoneyLabel(parent, prefix .. "Sign"),
		gl = CreateMoneyLabel(parent, prefix .. "Gold"),
		gi = CreateMoneyIcon(parent, GOLD_ICON),
		sl = CreateMoneyLabel(parent, prefix .. "Silver"),
		si = CreateMoneyIcon(parent, SILVER_ICON),
		cl = CreateMoneyLabel(parent, prefix .. "Copper"),
		ci = CreateMoneyIcon(parent, COPPER_ICON),
	}
end

local function CreateMoneyText(parent, id, text, x, y, width)
	local label = parent:CreateChildWidget("label", id, 0, true)
	label:SetExtent(width, 18)
	label:AddAnchor("TOPLEFT", parent, x, y)
	label:SetText(text or "")
	StyleLabel(label, 12, ALIGN_LEFT, "default")
	label:Show(false)
	return label
end

local function HideMoneyCluster(cluster)
	if cluster == nil then
		return
	end
	cluster.sign:Show(false)
	cluster.gl:Show(false)
	cluster.gi:SetVisible(false)
	cluster.sl:Show(false)
	cluster.si:SetVisible(false)
	cluster.cl:Show(false)
	cluster.ci:SetVisible(false)
end

local function HideEconomyMoney()
	if economyMoney == nil then
		return
	end
	for _, cluster in ipairs(economyMoney.clusters or {}) do
		HideMoneyCluster(cluster)
	end
	for _, label in ipairs(economyMoney.labels or {}) do
		label:Show(false)
	end
end

local function SetMoneyClusterColor(cluster, color)
	if cluster == nil then
		return
	end
	SetTextColorByKey(cluster.sign, "default")
	SetTextColorByKey(cluster.gl, "default")
	SetTextColorByKey(cluster.sl, "default")
	SetTextColorByKey(cluster.cl, "default")
end

ShowMoneyCluster = function(cluster, copper, x, y, color)
	if cluster == nil or mainWindow == nil then
		return 0
	end
	HideMoneyCluster(cluster)
	SetMoneyClusterColor(cluster, color or { 0.45, 0.25, 0.02, 1 })

	local sign, gold, silver, copperPart = CopperToParts(copper)
	local parts = {}
	if gold > 0 then
		parts[#parts + 1] = { label = cluster.gl, icon = cluster.gi, value = gold }
	end
	if silver > 0 then
		parts[#parts + 1] = { label = cluster.sl, icon = cluster.si, value = silver }
	end
	if copperPart > 0 or #parts == 0 then
		parts[#parts + 1] = { label = cluster.cl, icon = cluster.ci, value = copperPart }
	end

	local curX = x
	if sign ~= "" then
		cluster.sign:SetText(sign)
		cluster.sign:SetWidth(6)
		cluster.sign:RemoveAllAnchors()
		cluster.sign:AddAnchor("TOPLEFT", mainWindow, curX, y)
		cluster.sign:Show(true)
		curX = curX + 7
	end

	for index, part in ipairs(parts) do
		local text = tostring(part.value)
		local width = (#text * MONEY_DIGIT_W) + 1
		part.label:SetText(text)
		part.label:SetWidth(width)
		part.label:RemoveAllAnchors()
		part.label:AddAnchor("TOPLEFT", mainWindow, curX, y)
		part.label:Show(true)

		part.icon:RemoveAllAnchors()
		part.icon:AddAnchor("LEFT", part.label, width + MONEY_ICON_GAP, 0)
		part.icon:SetVisible(true)

		curX = curX + width + MONEY_ICON_GAP + MONEY_ICON_SIZE
		if index < #parts then
			curX = curX + MONEY_UNIT_GAP
		end
	end

	return curX - x
end

local function ReadStack(info)
	return tonumber(info.stackCount or info.stack or info.count or info.itemCount or info.amount or 1) or 0
end

local function ScanInventory()
	owned = {}
	inventoryOK = false
	if X2Bag == nil then
		return
	end

	local function BagSize()
		if type(X2Bag.GetBagNumSlots) == "function" then
			local ok, count = pcall(function()
				return X2Bag:GetBagNumSlots(1)
			end)
			if ok and type(count) == "number" and count > 0 then
				return count
			end
		end
		for _, method in ipairs({ "GetBagItemCount", "GetBagSize", "GetInventoryItemCount" }) do
			if type(X2Bag[method]) == "function" then
				local ok, count = pcall(function()
					return X2Bag[method]()
				end)
				if ok and type(count) == "number" and count > 0 then
					return count
				end
			end
		end
		return 300
	end

	local count = BagSize()
	local found = 0
	local tmp = {}
	if type(X2Bag.GetBagItemInfo) == "function" then
		for index = 1, count do
			local ok, info = pcall(function()
				return X2Bag:GetBagItemInfo(1, index)
			end)
			if ok and type(info) == "table" and info.name ~= nil then
				tmp[info.name] = (tmp[info.name] or 0) + ReadStack(info)
				found = found + 1
			end
		end
	end
	if found > 0 then
		owned = tmp
		inventoryOK = true
	end
end

local function FindRecipe(query)
	local clean = Trim(query)
	if clean == "" then
		return nil
	end

	local craftType, name = ResolveCraftType(clean)
	if craftType ~= nil then
		local recipe = LoadLiveRecipe(craftType)
		if recipe ~= nil then
			return recipe.name or name or clean
		end
	end

	return nil
end

local function CollectTree(name, visited, order)
	if visited[name] then
		return
	end
	visited[name] = true
	local recipe = ResolveRecipe(name)
	if recipe ~= nil then
		for _, material in ipairs(recipe.materials or {}) do
			if material.fromStage and ResolveRecipe(material.item) ~= nil then
				CollectTree(material.item, visited, order)
			end
		end
	end
	order[#order + 1] = name
end

local function BuildPlan(finalName, finalCrafts)
	if ResolveRecipe(finalName) == nil then
		return nil
	end

	local order = {}
	CollectTree(finalName, {}, order)

	local crafts = {}
	local unitsNeeded = {}
	for index = #order, 1, -1 do
		local name = order[index]
		local recipe = ResolveRecipe(name)
		local craftAmount
		if name == finalName then
			craftAmount = finalCrafts
		else
			local net = (unitsNeeded[name] or 0) - (owned[name] or 0)
			if net < 0 then
				net = 0
			end
			craftAmount = math.ceil(net / ((recipe and recipe.yield) or 1))
		end
		crafts[name] = craftAmount
		for _, material in ipairs((recipe and recipe.materials) or {}) do
			if material.fromStage and ResolveRecipe(material.item) ~= nil then
				unitsNeeded[material.item] = (unitsNeeded[material.item] or 0) + (craftAmount * material.count)
			end
		end
	end

	local result = { stages = {}, stageByName = {}, shop = {}, vendor = {}, totalLabor = 0, craftFee = 0, finalUnits = 0 }
	local totalNeed = {}
	local vendorNeed = {}
	local seenOrder = {}
	local seen = {}

	local function AddNeed(bucket, item, qty)
		bucket[item] = (bucket[item] or 0) + qty
		if seen[item] ~= true then
			seen[item] = true
			seenOrder[#seenOrder + 1] = item
		end
	end

	for _, name in ipairs(order) do
		local recipe = ResolveRecipe(name)
		local craftAmount = crafts[name] or 0
		if name == finalName then
			result.finalUnits = craftAmount * ((recipe and recipe.yield) or 1)
		end
		local stage = {
			name = name,
			crafts = craftAmount,
			craftFee = craftAmount * ((recipe.cost) or 0),
			labor = math.floor(craftAmount * ((recipe.laborcost) or 0) + 0.5),
			lines = {},
		}
		result.totalLabor = result.totalLabor + stage.labor
		result.craftFee = result.craftFee + stage.craftFee
		for _, material in ipairs(recipe.materials or {}) do
			local qty = craftAmount * (material.count or 0)
			local kind = "ah"
			if material.fromStage and ResolveRecipe(material.item) ~= nil then
				kind = "craft"
			elseif material.fromVendor then
				kind = "vendor"
				AddNeed(vendorNeed, material.item, qty)
			else
				AddNeed(totalNeed, material.item, qty)
			end
			stage.lines[#stage.lines + 1] = { item = material.item, qty = qty, kind = kind }
			DebugPlan(
				string.format(
					"stage=%s crafts=%s material=%s qty=%s kind=%s",
					tostring(name),
					tostring(craftAmount),
					tostring(material.item),
					tostring(qty),
					tostring(kind)
				)
			)
		end
		result.stages[#result.stages + 1] = stage
		result.stageByName[name] = stage
	end

	for _, item in ipairs(seenOrder) do
		local need = totalNeed[item] or 0
		if need > 0 then
			local have = owned[item] or 0
			local buy = need - have
			if buy < 0 then
				buy = 0
			end
			result.shop[#result.shop + 1] = { item = item, need = need, have = have, buy = buy, search = item }
		end
		local vendorQty = vendorNeed[item] or 0
		if vendorQty > 0 then
			local have = owned[item] or 0
			local buy = vendorQty - have
			if buy < 0 then
				buy = 0
			end
			result.vendor[#result.vendor + 1] = { item = item, need = vendorQty, have = have, buy = buy }
		end
	end

	return result
end

local function SetStatus(text, color)
	statusLabel:SetText(text or "")
	SetTextColorByKey(statusLabel, "default")
end

local function ClearRows()
	for index = 1, #rows do
		rowActions[index] = nil
		rows[index].left:SetText("")
		rows[index].mid:SetText("")
		HideMoneyCluster(rows[index].unit)
		HideMoneyCluster(rows[index].total)
		if rows[index].line ~= nil then
			rows[index].line:SetVisible(false)
		end
		rows[index].left:SetHandler("OnClick", function() end)
		rows[index].mid:SetHandler("OnClick", function() end)
		rows[index].left:Show(false)
		rows[index].mid:Show(false)
	end
end

local function Row(index, left, mid, unitPrice, totalPrice, color, onClick)
	local row = rows[index]
	if row == nil then
		return
	end
	rowActions[index] = onClick
	row.left:SetText(left or "")
	row.mid:SetText(mid or "")
	HideMoneyCluster(row.unit)
	HideMoneyCluster(row.total)
	SetTextColorByKey(row.left, "default")
	SetTextColorByKey(row.mid, "default")
	if unitPrice ~= nil then
		ShowMoneyClusterRight(row.unit, unitPrice, ROW_UNIT_RIGHT, row.y, color)
	end
	if totalPrice ~= nil then
		ShowMoneyClusterRight(row.total, totalPrice, ROW_TOTAL_RIGHT, row.y, color)
	end
	local function HandleClick()
		if rowActions[index] ~= nil then
			rowActions[index]()
		end
	end
	row.left:SetHandler("OnClick", HandleClick)
	row.mid:SetHandler("OnClick", HandleClick)
	row.left:Show(true)
	row.mid:Show(true)
end

local function RowLine(index)
	local row = rows[index]
	if row == nil then
		return
	end
	rowActions[index] = nil
	row.left:SetText("")
	row.mid:SetText("")
	HideMoneyCluster(row.unit)
	HideMoneyCluster(row.total)
	row.left:Show(false)
	row.mid:Show(false)
	row.line:SetVisible(true)
end

local function ResizeWindowForRows(rowCount)
	if mainWindow == nil then
		return
	end
	local height = ROW_TOP + (math.max(1, rowCount or 1) * ROW_HEIGHT) + FOOTER_HEIGHT
	if height < MIN_WINDOW_HEIGHT then
		height = MIN_WINDOW_HEIGHT
	end
	mainWindow:SetExtent(WINDOW_WIDTH, height)
end

local BuildVisiblePlan

local function RebuildBuyQueue()
	buyQueue = {}
	if plan == nil then
		return
	end
	for _, entry in ipairs(BuildVisiblePlan().shop or {}) do
		if (entry.buy or 0) > 0 then
			buyQueue[#buyQueue + 1] = entry
		end
	end
end

local function GetVendorUnitPrice(item)
	if type(VendorPrices) == "table" then
		return tonumber(VendorPrices[item]) or 0
	end
	return 0
end

function BuildVisiblePlan()
	local result = { shop = {}, vendor = {}, craftFee = 0, totalLabor = 0 }
	if plan == nil or selectedRecipe == nil then
		return result
	end

	local shopNeed = {}
	local vendorNeed = {}
	local shopOrder = {}
	local vendorOrder = {}

	local function AddNeed(bucket, order, item, qty)
		if item == nil or (qty or 0) <= 0 then
			return
		end
		if bucket[item] == nil then
			order[#order + 1] = item
			bucket[item] = 0
		end
		bucket[item] = bucket[item] + qty
	end

	local function WalkStage(stage)
		if stage == nil then
			return
		end
		result.craftFee = result.craftFee + (stage.craftFee or 0)
		result.totalLabor = result.totalLabor + (stage.labor or 0)
		for _, material in ipairs(stage.lines or {}) do
			if material.kind == "craft" and expandedStages[material.item] then
				WalkStage(plan.stageByName[material.item])
			elseif material.kind == "vendor" then
				AddNeed(vendorNeed, vendorOrder, material.item, material.qty)
			else
				AddNeed(shopNeed, shopOrder, material.item, material.qty)
			end
		end
	end

	local stages = plan.stages or {}
	WalkStage(plan.stageByName[selectedRecipe] or stages[#stages])

	for _, item in ipairs(shopOrder) do
		local need = shopNeed[item] or 0
		local have = owned[item] or 0
		local buy = need - have
		if buy < 0 then
			buy = 0
		end
		result.shop[#result.shop + 1] = { item = item, need = need, have = have, buy = buy, search = item }
	end

	for _, item in ipairs(vendorOrder) do
		local need = vendorNeed[item] or 0
		local have = owned[item] or 0
		local buy = need - have
		if buy < 0 then
			buy = 0
		end
		result.vendor[#result.vendor + 1] = { item = item, need = need, have = have, buy = buy }
	end

	return result
end

local function CalculateEconomy()
	if plan == nil or selectedRecipe == nil then
		return nil
	end

	local finalUnitPrice = GetAuctionUnitPrice(selectedRecipe)
	if finalUnitPrice == nil or finalUnitPrice <= 0 then
		return nil
	end

	local outrightCost = finalUnitPrice * math.max(1, plan.finalUnits or craftCount)
	local visible = BuildVisiblePlan()
	local piecingCost = visible.craftFee or 0
	local missingPrices = {}
	DebugPrice(
		string.format(
			"economy final=%s unit=%s units=%s craftFee=%s",
			tostring(selectedRecipe),
			tostring(finalUnitPrice),
			tostring(plan.finalUnits or craftCount),
			tostring(visible.craftFee or 0)
		)
	)

	for _, entry in ipairs(visible.shop or {}) do
		local need = entry.need or 0
		if need > 0 then
			local unit = GetAuctionUnitPrice(entry.item)
			DebugPrice(
				string.format(
					"shop item=%s need=%s have=%s buy=%s unit=%s",
					tostring(entry.item),
					tostring(entry.need),
					tostring(entry.have),
					tostring(entry.buy),
					tostring(unit)
				)
			)
			if unit == nil or unit <= 0 then
				missingPrices[#missingPrices + 1] = entry.item
			else
				piecingCost = piecingCost + (need * unit)
			end
		end
	end

	for _, entry in ipairs(visible.vendor or {}) do
		local need = entry.need or 0
		if need > 0 then
			DebugPrice(
				string.format(
					"vendor item=%s need=%s have=%s buy=%s unit=%s",
					tostring(entry.item),
					tostring(entry.need),
					tostring(entry.have),
					tostring(entry.buy),
					tostring(GetVendorUnitPrice(entry.item))
				)
			)
			piecingCost = piecingCost + (need * GetVendorUnitPrice(entry.item))
		end
	end

	if #missingPrices > 0 then
		DebugBad("missing prices: " .. table.concat(missingPrices, ", "))
		return { missing = missingPrices }
	end

	local difference = outrightCost - piecingCost
	local labor = math.max(1, visible.totalLabor or 0)
	if #(visible.shop or {}) > 0 and piecingCost <= (visible.craftFee or 0) then
		DebugBad(
			string.format(
				"piece cost suspicious: piece=%s craftFee=%s shopItems=%s",
				tostring(piecingCost),
				tostring(visible.craftFee or 0),
				tostring(#(visible.shop or {}))
			)
		)
	end
	DebugPrice(
		string.format(
			"economy result outright=%s piece=%s diff=%s labor=%s",
			tostring(outrightCost),
			tostring(piecingCost),
			tostring(difference),
			tostring(visible.totalLabor or 0)
		)
	)
	return {
		outright = outrightCost,
		piecing = piecingCost,
		difference = difference,
		perLabor = difference / labor,
		labor = visible.totalLabor or 0,
	}
end

local function UpdateEconomyLabel()
	if economyLabel == nil then
		return
	end
	HideEconomyMoney()

	local economy = CalculateEconomy()
	if economy == nil then
		economyLabel:SetText("Economy: click Check Prices after opening the Auction House.")
		SetTextColorByKey(economyLabel, "default")
	elseif economy.missing ~= nil then
		economyLabel:SetText("Economy: missing prices for " .. tostring(#economy.missing) .. " material(s).")
		SetTextColorByKey(economyLabel, "default")
	else
		economyLabel:SetText("")
		SetTextColorByKey(economyLabel, "default")
		if economyMoney ~= nil then
			economyMoney.outrightText:SetText("Outright")
			economyMoney.pieceText:SetText("| Piece")
			economyMoney.diffText:SetText("| Diff")
			economyMoney.laborText:SetText("|")
			economyMoney.perLaborText:SetText("/labor")
			for _, label in ipairs(economyMoney.labels or {}) do
				SetTextColorByKey(label, "default")
				label:Show(true)
			end
			ShowMoneyCluster(economyMoney.outright, economy.outright, 76, 184, nil)
			ShowMoneyCluster(economyMoney.piece, economy.piecing, 302, 184, nil)
			ShowMoneyCluster(economyMoney.diff, economy.difference, 52, 204, nil)
			local perLaborWidth = ShowMoneyCluster(economyMoney.perLabor, economy.perLabor, 280, 204, nil)
			economyMoney.perLaborText:RemoveAllAnchors()
			economyMoney.perLaborText:AddAnchor("TOPLEFT", mainWindow, 282 + perLaborWidth, 204)
		end
	end
end

local function RenderPlan()
	ClearRows()
	if plan == nil or selectedRecipe == nil then
		targetLabel:SetText("Target: none")
		craftLabel:SetText("Crafts: -")
		HideMoneyCluster(craftFeeMoney)
		economyLabel:SetText("Economy: -")
		HideEconomyMoney()
		shoppingLabel:SetText("Shopping: -")
		stepLabel:SetText("No shopping run active.")
		ResizeWindowForRows(1)
		return
	end

	targetLabel:SetText("Target: " .. tostring(selectedRecipe))
	local visible = BuildVisiblePlan()
	craftLabel:SetText(
		string.format(
			"Crafts: %d   Produces: %d   Labor: %d   Craft fee:",
			craftCount,
			plan.finalUnits or craftCount,
			visible.totalLabor or 0
		)
	)
	if craftFeeMoney ~= nil then
		ShowMoneyCluster(craftFeeMoney, visible.craftFee or 0, 345, 162, { 0.45, 0.25, 0.02, 1 })
	end
	UpdateEconomyLabel()

	local missing = 0
	for _, entry in ipairs(visible.shop or {}) do
		if (entry.buy or 0) > 0 then
			missing = missing + 1
		end
	end
	shoppingLabel:SetText(string.format("Auction items still needed: %d", missing))

	local rowIndex = 1

	local function RenderStage(stage, depth, showHeader)
		if stage == nil or rowIndex > MAX_ROW_COUNT then
			return
		end
		local indent = string.rep("  ", depth)
		if showHeader ~= false then
			Row(
				rowIndex,
				indent .. tostring(stage.name),
				tostring(stage.crafts),
				nil,
				nil,
				nil
			)
			rowIndex = rowIndex + 1
		end
		for _, material in ipairs(stage.lines or {}) do
			if rowIndex > MAX_ROW_COUNT then
				return
			end
			local isCraft = material.kind == "craft"
			local color = isCraft and WARN_ORANGE or nil
			local unitPrice = GetVendorUnitPrice(material.item)
			if unitPrice <= 0 then
				unitPrice = GetAuctionUnitPrice(material.item)
			end
			local function Toggle()
				expandedStages[material.item] = not expandedStages[material.item]
				RebuildBuyQueue()
				RenderPlan()
			end
			Row(
				rowIndex,
				indent .. "  " .. tostring(material.item),
				tostring(material.qty),
				unitPrice > 0 and unitPrice or nil,
				unitPrice > 0 and ((material.qty or 0) * unitPrice) or nil,
				color,
				isCraft and Toggle or nil
			)
			rowIndex = rowIndex + 1
			if isCraft and expandedStages[material.item] then
				RenderStage(plan.stageByName[material.item], depth + 1, false)
			end
		end
	end

	local stages = plan.stages or {}
	RenderStage(plan.stageByName[selectedRecipe] or stages[#stages], 0, true)

	if rowIndex <= MAX_ROW_COUNT then
		RowLine(rowIndex)
		rowIndex = rowIndex + 1
	end

	if #visible.vendor > 0 and rowIndex <= MAX_ROW_COUNT then
		RowLine(rowIndex)
		rowIndex = rowIndex + 1
	end

	if #visible.vendor > 0 and rowIndex <= MAX_ROW_COUNT then
		for _, entry in ipairs(visible.vendor) do
			if rowIndex > MAX_ROW_COUNT then
				break
			end
			local unitPrice = GetVendorUnitPrice(entry.item)
			Row(
				rowIndex,
				entry.item,
				tostring(entry.need or 0),
				unitPrice > 0 and unitPrice or nil,
				unitPrice > 0 and ((entry.need or 0) * unitPrice) or nil,
				WARN_ORANGE
			)
			rowIndex = rowIndex + 1
		end
	end
	ResizeWindowForRows(rowIndex - 1)
end

local function RecomputePlan()
	ScanInventory()
	if selectedRecipe == nil then
		plan = nil
	else
		plan = BuildPlan(selectedRecipe, craftCount)
	end
	RebuildBuyQueue()
	RenderPlan()
end

local function LoadRecipeFromInput()
	local recipeName = FindRecipe(recipeEdit:GetText())
	if recipeName == nil then
		selectedRecipe = nil
		plan = nil
		RenderPlan()
		SetStatus("Craft not found. Type an exact or partial craft name, item id, or craft id.", MISSING_RED)
		return false
	end

	selectedRecipe = recipeName
	recipeEdit:SetText(recipeName)
	ADDON:SaveData(SAVE_KEY, { recipe = recipeName, count = craftCount })
	currentBuyIndex = 0
	waitingForAuction = false
	RecomputePlan()
	SetStatus(
		inventoryOK and "Craft loaded. Review the list, then click Go to Buy."
			or "Craft loaded. Inventory scan unavailable.",
		inventoryOK and nil or WARN_ORANGE
	)
	stepLabel:SetText("No shopping run active.")
	return true
end

local function EnsureInputRecipeLoaded()
	local typed = Trim(recipeEdit:GetText())
	if typed ~= "" and (selectedRecipe == nil or not SameItemName(typed, selectedRecipe)) then
		return LoadRecipeFromInput()
	end
	return selectedRecipe ~= nil
end

local function ApplyCount()
	local nextCount = math.floor(tonumber(countEdit:GetText() or "") or 1)
	if nextCount < 1 then
		nextCount = 1
	end
	craftCount = nextCount
	countEdit:SetText(tostring(craftCount))
	if selectedRecipe ~= nil then
		ADDON:SaveData(SAVE_KEY, { recipe = selectedRecipe, count = craftCount })
	end
	RecomputePlan()
end

local function SearchCurrentEntry(entry)
	X2Auction:SearchAuctionArticle(1, 0, 999, 1, 0, false, entry.search or entry.item, "0", "0")
	SetStatus("Searching: " .. tostring(entry.item) .. ". Buy what you need, then click Next.", nil)
	stepLabel:SetText(string.format("Step %d/%d: buy %d x %s", currentBuyIndex, #buyQueue, entry.buy or 0, entry.item))
end

local function StartShopping()
	if not EnsureInputRecipeLoaded() then
		SetStatus("Load a craft first.", MISSING_RED)
		return
	end
	RecomputePlan()
	if #buyQueue == 0 then
		SetStatus("All Auction House materials are already covered.", COMPLETE_GREEN)
		stepLabel:SetText("Nothing to buy.")
		return
	end
	waitingForAuction = false
	currentBuyIndex = 1
	ADDON:ShowContent(UIC_AUCTION, true)
	SearchCurrentEntry(buyQueue[currentBuyIndex])
end

local function BuildPriceCheckQueue()
	priceCheckQueue = {}
	currentPriceRequest = nil
	if selectedRecipe == nil or plan == nil then
		return
	end

	local seen = {}
	local function add(item)
		if item ~= nil and seen[item] ~= true then
			seen[item] = true
			priceCheckQueue[#priceCheckQueue + 1] = { item = item, search = item }
		end
	end

	add(selectedRecipe)
	for _, entry in ipairs(BuildVisiblePlan().shop or {}) do
		add(entry.item)
	end
end

local function SearchNextPrice()
	if #priceCheckQueue == 0 then
		priceCheckBusy = false
		currentPriceRequest = nil
		UpdateEconomyLabel()
		SetStatus("Price check complete.", COMPLETE_GREEN)
		return
	end

	currentPriceRequest = table.remove(priceCheckQueue, 1)
	priceCheckBusy = true
	X2Auction:SearchAuctionArticle(1, 0, 999, 1, 0, false, currentPriceRequest.search, "0", "0")
	priceCheckStart = os.time()
	SetStatus(
		"Checking price: " .. tostring(currentPriceRequest.item) .. " (" .. tostring(#priceCheckQueue) .. " left)",
		nil
	)
	stepLabel:SetText("Price check: " .. tostring(currentPriceRequest.item))
end

local function StartPriceCheck()
	if not EnsureInputRecipeLoaded() then
		SetStatus("Load a craft first.", MISSING_RED)
		return
	end
	RecomputePlan()
	BuildPriceCheckQueue()
	if #priceCheckQueue == 0 then
		SetStatus("Nothing needs an Auction House price check.", WARN_ORANGE)
		UpdateEconomyLabel()
		return
	end
	auctionPrices = {}
	if economyLabel ~= nil then
		economyLabel:SetText("Economy: checking Auction House prices...")
		SetTextColorByKey(economyLabel, "default")
	end
	SetStatus("Checking Auction House prices...", nil)
	SearchNextPrice()
end

local function NextShoppingStep()
	if selectedRecipe == nil then
		SetStatus("Load a craft first.", MISSING_RED)
		return
	end
	if waitingForAuction then
		waitingForAuction = false
	else
		RecomputePlan()
	end

	if #buyQueue == 0 then
		SetStatus("Shopping list complete.", COMPLETE_GREEN)
		stepLabel:SetText("Done.")
		return
	end

	currentBuyIndex = currentBuyIndex + 1
	if currentBuyIndex > #buyQueue then
		currentBuyIndex = 1
	end

	local entry = buyQueue[currentBuyIndex]
	if entry == nil then
		SetStatus("Shopping list complete.", COMPLETE_GREEN)
		stepLabel:SetText("Done.")
		return
	end
	SearchCurrentEntry(entry)
end

local function CreateMainWindow()
	if mainWindow ~= nil then
		return
	end

	mainWindow = CreateEmptyWindow("autoShopWindow", "UIParent")
	mainWindow:SetExtent(WINDOW_WIDTH, MIN_WINDOW_HEIGHT)
	mainWindow:AddAnchor("CENTER", "UIParent", 0, 0)
	mainWindow:SetCloseOnEscape(true)
	mainWindow:EnableDrag(true)
	mainWindow:Show(false)

	CreateWindowBackground(mainWindow)
	CreateQuestStylePanel(mainWindow, "autoShopBodyPanel", 112, -54, 0.20)
	CreateQuestStyleStrip(mainWindow, "autoShopSummaryPanel", 18, 146, WINDOW_WIDTH - 36, 68, 0.13)

	mainWindow:SetHandler("OnDragStart", function(self)
		self:StartMoving()
		return true
	end)
	mainWindow:SetHandler("OnDragStop", function(self)
		self:StopMovingOrSizing()
	end)

	local title = mainWindow:CreateChildWidget("label", "autoShopTitle", 0, true)
	title:SetExtent(220, 24)
	title:AddAnchor("TOPLEFT", mainWindow, 18, 14)
	title:SetText("AutoShop")
	StyleLabel(title, 18, ALIGN_LEFT, "brown")

	CreateCloseButton(mainWindow, "autoShopClose", function()
		mainWindow:Show(false)
	end)

	local recipeLabel = mainWindow:CreateChildWidget("label", "autoShopRecipeLabel", 0, true)
	recipeLabel:SetExtent(80, 22)
	recipeLabel:AddAnchor("TOPLEFT", mainWindow, 18, 48)
	recipeLabel:SetText("Craft")
	StyleLabel(recipeLabel, 13, ALIGN_LEFT, "brown")

	recipeEdit = CreateEditBox(mainWindow, "autoShopRecipeEdit", 286)
	recipeEdit:AddAnchor("TOPLEFT", mainWindow, 88, 45)
	recipeEdit:SetGuideText("Type craft name or id")
	recipeEdit:SetHandler("OnEnterPressed", LoadRecipeFromInput)

	CreateButton(mainWindow, "autoShopLoad", "Load", 398, 46, 48, LoadRecipeFromInput)
	CreateButton(mainWindow, "autoShopCheckPrices", "Check Prices", 454, 46, 88, StartPriceCheck)

	local countLabel = mainWindow:CreateChildWidget("label", "autoShopCountLabel", 0, true)
	countLabel:SetExtent(52, 22)
	countLabel:AddAnchor("TOPLEFT", mainWindow, 18, 82)
	countLabel:SetText("Crafts")
	StyleLabel(countLabel, 13, ALIGN_LEFT, "brown")

	countEdit = CreateEditBox(mainWindow, "autoShopCountEdit", 60)
	countEdit:AddAnchor("TOPLEFT", mainWindow, 88, 79)
	countEdit:SetText("1")
	countEdit:SetHandler("OnEnterPressed", ApplyCount)
	countEdit:SetHandler("OnEditFocusLost", ApplyCount)

	CreateSmallButton(mainWindow, "autoShopMinus", "-", 160, 80, function()
		countEdit:SetText(tostring(math.max(1, craftCount - 1)))
		ApplyCount()
	end)
	CreateSmallButton(mainWindow, "autoShopPlus", "+", 184, 80, function()
		countEdit:SetText(tostring(craftCount + 1))
		ApplyCount()
	end)
	CreateButton(mainWindow, "autoShopRefresh", "Refresh Bag", 312, 80, 84, function()
		RecomputePlan()
		SetStatus("Inventory refreshed.", nil)
	end)
	CreateButton(mainWindow, "autoShopGoBuy", "Go to Buy", 404, 80, 76, StartShopping)
	CreateButton(mainWindow, "autoShopNext", "Next", 488, 80, 54, NextShoppingStep)

	CreateSectionLine(mainWindow, "controls", 106)

	statusLabel = mainWindow:CreateChildWidget("label", "autoShopStatus", 0, true)
	statusLabel:SetExtent(WINDOW_WIDTH - 36, 22)
	statusLabel:AddAnchor("TOPLEFT", mainWindow, 18, 114)
	StyleLabel(statusLabel, 13, ALIGN_LEFT, "default")
	statusLabel:SetText("Load a craft to start.")

	targetLabel = mainWindow:CreateChildWidget("label", "autoShopTarget", 0, true)
	targetLabel:SetExtent(WINDOW_WIDTH - 36, 22)
	targetLabel:AddAnchor("TOPLEFT", mainWindow, 18, 140)
	StyleLabel(targetLabel, 13, ALIGN_LEFT, "brown")

	craftLabel = mainWindow:CreateChildWidget("label", "autoShopCrafts", 0, true)
	craftLabel:SetExtent(WINDOW_WIDTH - 36, 22)
	craftLabel:AddAnchor("TOPLEFT", mainWindow, 18, 162)
	StyleLabel(craftLabel, 13, ALIGN_LEFT, "default")
	craftFeeMoney = CreateMoneyCluster(mainWindow, "autoShopCraftFeeMoney")

	economyLabel = mainWindow:CreateChildWidget("label", "autoShopEconomy", 0, true)
	economyLabel:SetExtent(WINDOW_WIDTH - 36, 22)
	economyLabel:AddAnchor("TOPLEFT", mainWindow, 18, 184)
	StyleLabel(economyLabel, 13, ALIGN_LEFT, "default")
	economyMoney = {
		outrightText = CreateMoneyText(mainWindow, "autoShopOutrightText", "Outright", 18, 184, 62),
		pieceText = CreateMoneyText(mainWindow, "autoShopPieceText", "| Piece", 250, 184, 48),
		diffText = CreateMoneyText(mainWindow, "autoShopDiffText", "Diff", 18, 204, 34),
		laborText = CreateMoneyText(mainWindow, "autoShopLaborText", "|", 264, 204, 10),
		perLaborText = CreateMoneyText(mainWindow, "autoShopPerLaborText", "/labor", 360, 204, 40),
		outright = CreateMoneyCluster(mainWindow, "autoShopOutrightMoney"),
		piece = CreateMoneyCluster(mainWindow, "autoShopPieceMoney"),
		diff = CreateMoneyCluster(mainWindow, "autoShopDiffMoney"),
		perLabor = CreateMoneyCluster(mainWindow, "autoShopPerLaborMoney"),
	}
	economyMoney.labels = {
		economyMoney.outrightText,
		economyMoney.pieceText,
		economyMoney.diffText,
		economyMoney.laborText,
		economyMoney.perLaborText,
	}
	economyMoney.clusters = {
		economyMoney.outright,
		economyMoney.piece,
		economyMoney.diff,
		economyMoney.perLabor,
	}

	CreateSectionLine(mainWindow, "summary", 226)

	shoppingLabel = mainWindow:CreateChildWidget("label", "autoShopShopping", 0, true)
	shoppingLabel:SetExtent(270, 22)
	shoppingLabel:AddAnchor("BOTTOMLEFT", mainWindow, 18, -36)
	StyleLabel(shoppingLabel, 13, ALIGN_LEFT, "default")

	stepLabel = mainWindow:CreateChildWidget("label", "autoShopStep", 0, true)
	stepLabel:SetExtent(250, 22)
	stepLabel:AddAnchor("BOTTOMRIGHT", mainWindow, -18, -36)
	StyleLabel(stepLabel, 13, ALIGN_RIGHT, "default")

	local tableHeaderY = ROW_TOP - 18
	local breakdownHeader = mainWindow:CreateChildWidget("label", "autoShopBreakdownHeader", 0, true)
	breakdownHeader:SetExtent(240, 18)
	breakdownHeader:AddAnchor("TOPLEFT", mainWindow, 20, tableHeaderY)
	breakdownHeader:SetText("Breakdown")
	StyleLabel(breakdownHeader, 12, ALIGN_LEFT, "brown")

	local qtyHeader = mainWindow:CreateChildWidget("label", "autoShopQtyHeader", 0, true)
	qtyHeader:SetExtent(60, 18)
	qtyHeader:AddAnchor("TOPLEFT", mainWindow, 20 + ROW_NAME_WIDTH + 10, tableHeaderY)
	qtyHeader:SetText("Qty")
	StyleLabel(qtyHeader, 12, ALIGN_LEFT, "brown")

	local unitHeader = mainWindow:CreateChildWidget("label", "autoShopUnitHeader", 0, true)
	unitHeader:SetExtent(90, 18)
	unitHeader:AddAnchor("TOPLEFT", mainWindow, ROW_UNIT_RIGHT - 70, tableHeaderY)
	unitHeader:SetText("Unit Price")
	StyleLabel(unitHeader, 12, ALIGN_LEFT, "brown")

	local totalHeader = mainWindow:CreateChildWidget("label", "autoShopTotalHeader", 0, true)
	totalHeader:SetExtent(90, 18)
	totalHeader:AddAnchor("TOPLEFT", mainWindow, ROW_TOTAL_RIGHT - 70, tableHeaderY)
	totalHeader:SetText("Total Price")
	StyleLabel(totalHeader, 12, ALIGN_LEFT, "brown")

	for index = 1, MAX_ROW_COUNT do
		local y = ROW_TOP + ((index - 1) * ROW_HEIGHT)
		local line = mainWindow:CreateColorDrawable(0.55, 0.36, 0.10, 0.30, "artwork")
		line:SetExtent(WINDOW_WIDTH - 40, 1)
		line:AddAnchor("TOPLEFT", mainWindow, 20, y + math.floor(ROW_HEIGHT / 2))
		line:SetVisible(false)

		local left = mainWindow:CreateChildWidget("label", "autoShopRowLeft" .. tostring(index), index, true)
		left:SetExtent(ROW_NAME_WIDTH, 22)
		left:AddAnchor("TOPLEFT", mainWindow, 20, y)
		StyleLabel(left, 12, ALIGN_LEFT, "default")

		local mid = mainWindow:CreateChildWidget("label", "autoShopRowMid" .. tostring(index), index, true)
		mid:SetExtent(ROW_QTY_WIDTH, 22)
		mid:AddAnchor("TOPLEFT", mainWindow, 20 + ROW_NAME_WIDTH + 10, y)
		StyleLabel(mid, 12, ALIGN_LEFT, "default")

		rows[index] = {
			left = left,
			mid = mid,
			unit = CreateMoneyCluster(mainWindow, "autoShopRowUnitPrice" .. tostring(index)),
			total = CreateMoneyCluster(mainWindow, "autoShopRowTotalPrice" .. tostring(index)),
			line = line,
			y = y + 3,
		}
	end

	RenderPlan()

	local saved = ADDON:LoadData(SAVE_KEY)
	if type(saved) == "table" then
		if saved.recipe ~= nil then
			recipeEdit:SetText(tostring(saved.recipe))
		end
		if saved.count ~= nil then
			countEdit:SetText(tostring(saved.count))
			ApplyCount()
		end
	end
end

local function ToggleWindow()
	CreateMainWindow()
	local show = not mainWindow:IsVisible()
	mainWindow:Show(show)
	if show then
		mainWindow:Raise()
		if selectedRecipe == nil and Trim(recipeEdit:GetText()) ~= "" then
			LoadRecipeFromInput()
		else
			RecomputePlan()
		end
	end
end

launcherButton = CreateSimpleButton("AutoShop", 700, -430)
launcherButton:SetHandler("OnClick", ToggleWindow)

local function OnBagChanged()
	if mainWindow ~= nil and mainWindow:IsVisible() then
		RecomputePlan()
	end
end

local function ReadAuctionPrice(info, expectedName)
	if type(info) ~= "table" or info.name == nil or not SameItemName(info.name, expectedName) then
		return nil
	end

	local fields = {
		"bidPriceStr",
		"bidPrice",
	}

	for _, field in ipairs(fields) do
		local parsed = ParseCopper(info[field])
		DebugPrice(
			string.format(
				"auction row name=%s expected=%s field=%s raw=%s parsed=%s",
				tostring(info.name),
				tostring(expectedName),
				tostring(field),
				tostring(info[field]),
				tostring(parsed)
			)
		)
		if parsed ~= nil and parsed > 0 then
			return parsed
		end
	end
	return nil
end

local function OnAuctionSearched()
	if priceCheckBusy and currentPriceRequest ~= nil then
		local count = 0
		pcall(function()
			count = X2Auction:GetSearchedItemCount() or 0
		end)
		DebugPrice("auction results for " .. tostring(currentPriceRequest.item) .. ": " .. tostring(count))
		if count > 0 then
			local foundPrice = nil
			for index = 1, count do
				local info = X2Auction:GetSearchedItemInfo(index)
				if DEBUG_PRICE and type(info) == "table" then
					DebugPrice(
						string.format(
							"result[%s] name=%s bidPrice=%s bidPriceStr=%s",
							tostring(index),
							tostring(info.name),
							tostring(info.bidPrice),
							tostring(info.bidPriceStr)
						)
					)
				end
				local price = ReadAuctionPrice(info, currentPriceRequest.item)
				if price ~= nil then
					foundPrice = price
					break
				end
			end
			if foundPrice ~= nil then
				local key = Trim(currentPriceRequest.item)
				auctionPrices[currentPriceRequest.item] = foundPrice
				auctionPrices[key] = foundPrice
				auctionPrices[key:lower()] = foundPrice
				SetStatus("Price found: " .. tostring(currentPriceRequest.item) .. " = " .. FormatMoney(foundPrice), COMPLETE_GREEN)
				if mainWindow ~= nil and mainWindow:IsVisible() then
					RenderPlan()
				end
			else
				DebugBad("no exact auction price for " .. tostring(currentPriceRequest.item))
				SetStatus("No exact price found for " .. tostring(currentPriceRequest.item) .. ".", WARN_ORANGE)
			end
		else
			DebugBad("no auction listings for " .. tostring(currentPriceRequest.item))
			SetStatus("No auction listings found for " .. tostring(currentPriceRequest.item) .. ".", WARN_ORANGE)
		end
		currentPriceRequest = nil
		if #priceCheckQueue == 0 then
			priceCheckBusy = false
			UpdateEconomyLabel()
			if mainWindow ~= nil and mainWindow:IsVisible() then
				RenderPlan()
			end
			SetStatus("Price check complete.", COMPLETE_GREEN)
		else
			stepLabel:SetText(string.format("Price check: waiting %.1fs cooldown", priceCheckCD))
		end
		return
	end

	if mainWindow ~= nil
		and mainWindow:IsVisible()
		and currentBuyIndex > 0
		and buyQueue[currentBuyIndex] ~= nil
	then
		SetStatus(
			"Auction results loaded. Buy "
				.. tostring(buyQueue[currentBuyIndex].buy)
				.. " x "
				.. tostring(buyQueue[currentBuyIndex].item)
				.. ", then click Next.",
			nil
		)
	end
end

pcall(function()
	UIParent:SetEventHandler(UIEVENT_TYPE.BAG_UPDATE, OnBagChanged)
	UIParent:SetEventHandler(UIEVENT_TYPE.AUCTION_ITEM_SEARCHED, OnAuctionSearched)
end)

local function OnPriceTick()
	if priceCheckBusy
		and currentPriceRequest == nil
		and #priceCheckQueue > 0
		and (os.time() - priceCheckStart) >= priceCheckCD
	then
		SearchNextPrice()
	end
end

priceTicker = CreateEmptyWindow("autoShopPriceTicker", "UIParent")
priceTicker:Show(true)
priceTicker:SetHandler("OnUpdate", OnPriceTick)

local eventWindow = CreateEmptyWindow("autoShopEvents", "UIParent")
eventWindow:Show(true)
eventWindow:SetHandler("OnEvent", function(self, event)
	if event == "ADDED_ITEM" or event == "REMOVED_ITEM" or event == "BAG_ITEM_CONFIRMED" then
		OnBagChanged()
	end
end)

pcall(function()
	eventWindow:RegisterEvent("ADDED_ITEM")
	eventWindow:RegisterEvent("REMOVED_ITEM")
	eventWindow:RegisterEvent("BAG_ITEM_CONFIRMED")
end)

Chat("Loaded. Click AutoShop to plan a craft.")
