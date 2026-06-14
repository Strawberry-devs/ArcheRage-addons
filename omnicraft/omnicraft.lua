-------------- Original Author: Strawberry --------------
----------------- Discord: exec_noir --------------------
------- Extra credit: Ash (slugfanclubchairwoman) -------

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
ADDON:ImportAPI(API_TYPE.ITEM.id)
ADDON:ImportAPI(API_TYPE.STORE.id)
ADDON:ImportAPI(API_TYPE.ABILITY.id)

local WINDOW_WIDTH = 560
local MIN_WINDOW_HEIGHT = 330
local MAX_ROW_COUNT = 12
local ROW_HEIGHT = 22
local ROW_TOP = 272
local FOOTER_HEIGHT = 20
local SAVE_KEY = "omnicraft_last_recipe"
local GOLD_ICON = "Addon/globals/icons/gold.dds"
local SILVER_ICON = "Addon/globals/icons/silver.dds"
local COPPER_ICON = "Addon/globals/icons/copper.dds"
local MONEY_ICON_SIZE = 13
local MONEY_ICON_GAP = 1
local MONEY_UNIT_GAP = 6
local MONEY_DIGIT_W = 7
local BUTTON_HEIGHT = 18
local SMALL_BUTTON_WIDTH = 22
local ROW_NAME_WIDTH = 274
local ROW_QTY_WIDTH = 60
local ROW_UNIT_RIGHT = 445
local ROW_TOTAL_RIGHT = WINDOW_WIDTH - 20
local CRAFTLABELHEIGHT1 = 164
local CRAFTLABELHEIGHT2 = 184
local CRAFTLABELHEIGHT3 = 204
local TRADE_COMMERCE_FOOTER_HEIGHT = 34
local BUY_TOTAL_WINDOW_WIDTH = 460
local BUY_TOTAL_ROW_TOP = 96
local BUY_TOTAL_ROW_HEIGHT = 22
local BUY_TOTAL_MAX_ROWS = 24

local COMPLETE_GREEN = { 0.04, 0.50, 0.08, 1 }
local WARN_ORANGE = { 0.85, 0.40, 0.05, 1 }
local MISSING_RED = { 0.85, 0.15, 0.12, 1 }
local VendorPrices = {
	["Hardtack"] = 2 * 100,
	["Savory Soup"] = 8 * 100,
	["Veiled Flame"] = 4 * 100,
	["Mage's Vapor"] = 6 * 100,
}
local TradeOriginZones = {
	{ prefix = "Gweonid", zone = 1, continent = "Nuia" },
	{ prefix = "Marianople", zone = 2, continent = "Nuia" },
	{ prefix = "Dewstone", zone = 3, continent = "Nuia" },
	{ prefix = "Solzreed", zone = 5, continent = "Nuia" },
	{ prefix = "Lilyut", zone = 6, continent = "Nuia" },
	{ prefix = "Two Crowns", zone = 8, continent = "Nuia" },
	{ prefix = "Airain", zone = 10, continent = "Nuia" },
	{ prefix = "White Arden", zone = 18, continent = "Nuia" },
	{ prefix = "Karkasse", zone = 19, continent = "Nuia" },
	{ prefix = "Cinderstone", zone = 20, continent = "Nuia" },
	{ prefix = "Aubre", zone = 21, continent = "Nuia" },
	{ prefix = "Halcyona", zone = 22, continent = "Nuia" },
	{ prefix = "Hellswamp", zone = 26, continent = "Nuia" },
	{ prefix = "Sanddeep", zone = 27, continent = "Nuia" },
	{ prefix = "Ahnimar", zone = 93, continent = "Nuia" },
	{ prefix = "Solis", zone = 4, continent = "Haranya" },
	{ prefix = "Arcum Iris", zone = 7, continent = "Haranya" },
	{ prefix = "Mahadevi", zone = 9, continent = "Haranya" },
	{ prefix = "Falcorth", zone = 11, continent = "Haranya" },
	{ prefix = "Villanelle", zone = 12, continent = "Haranya" },
	{ prefix = "Sunbite", zone = 13, continent = "Haranya" },
	{ prefix = "Windscour", zone = 14, continent = "Haranya" },
	{ prefix = "Perinoor", zone = 15, continent = "Haranya" },
	{ prefix = "Rookborne", zone = 16, continent = "Haranya" },
	{ prefix = "Ynystere", zone = 17, continent = "Haranya" },
	{ prefix = "Hasla", zone = 23, continent = "Haranya" },
	{ prefix = "Tigerspine", zone = 24, continent = "Haranya" },
	{ prefix = "Silent Forest", zone = 25, continent = "Haranya" },
	{ prefix = "Rokhala", zone = 99, continent = "Haranya" },
	{ prefix = "Exeloch", zone = 54, continent = "Auroria" },
	{ prefix = "Sungold", zone = 56, continent = "Auroria" },
	{ prefix = "Golden Ruins", zone = 57, continent = "Auroria" },
	{ prefix = "Aegis", zone = 102, continent = "Auroria" },
	{ prefix = "Whalesong", zone = 103, continent = "Auroria" },
}
local TradeTargetZones = {
	Nuia = {
		{ name = "Solzreed", fullName = "Solzreed Peninsula", zone = 5 },
		{ name = "Two Crowns", fullName = "Two Crowns", zone = 8 },
		{ name = "Cinderstone", fullName = "Cinderstone Moor", zone = 20 },
	},
	Haranya = {
		{ name = "Solis", fullName = "Solis Headlands", zone = 4 },
		{ name = "Villanelle", fullName = "Villanelle", zone = 12 },
		{ name = "Ynystere", fullName = "Ynystere", zone = 17 },
	},
	Auroria = {
		{ name = "Heedmar", fullName = "Heedmar", zone = 33 },
	},
}
local TradeFreshnessMultipliers = {
	Luxury = 1.30,
	Fine = 1.15,
	Commercial = 1.05,
	Preserved = 1.03,
}

local mainWindow = nil
local buyTotalWindow = nil
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
local tradeTargetDropdown = nil
local tradeTargetButton = nil
local tradeCommerceLabel = nil
local tradeCommerceValueLabel = nil
local tradeCommerceMinusButton = nil
local tradeCommercePlusButton = nil
local rows = {}
local buyTotalRows = {}

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
local priceCheckTimeout = 4
local priceCheckStart = 0
local priceTicker
local recipeCacheByCraftType = {}
local recipeCacheByName = {}
local recipePreviewDropdown = nil
local tradePackInfo = nil
local selectedTradeTarget = nil
local currentTradeRatio = nil
local tradeRatioRequestKey = nil
local tradeRatioPending = false
local tradeRatioDeferred = false
local tradeRatioCooldown = 6
local tradeRatioStart = 0
local tradeMaxFreshness = false
local detectedCommerceSkill = 0
local commerceOverride = nil
local expandedStages = {}
local rowActions = {}
local DEBUG_PLAN = false
local DEBUG_PRICE = false
local DEBUG_BAD = false

OmniCraftCommerceHoldDirection = 0
OmniCraftCommerceHoldNextAt = 0

local function Chat(message)
	pcall(function()
		X2Chat:DispatchChatMessage(CMF_SYSTEM, "[OmniCraft] " .. tostring(message))
	end)
end

local function PrintDebug(message)
	if type(aaprint) == "function" then
		aaprint("[OmniCraft] " .. tostring(message))
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

function OmniCraft_SetDebug(planDebug, priceDebug, badDebug)
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

function OmniCraft_DebugOn()
	OmniCraft_SetDebug(true, true, true)
end

function OmniCraft_DebugOff()
	OmniCraft_SetDebug(false, false, false)
end

local function Trim(value)
	return tostring(value or ""):match("^%s*(.-)%s*$") or ""
end

local function StartsWith(value, prefix)
	value = tostring(value or ""):lower()
	prefix = tostring(prefix or ""):lower()
	return value:sub(1, #prefix) == prefix
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
	if type(OmniCraftCraftIndex) == "table" then
		for name, data in pairs(OmniCraftCraftIndex) do
			if tostring(name):lower() == lower then
				data.name = name
				return data
			end
		end
		for name, data in pairs(OmniCraftCraftIndex) do
			if tostring(name):lower():find(lower, 1, true) ~= nil then
				data.name = name
				return data
			end
		end
	end

	if type(OmniCraftItemTypes) == "table" then
		for name, itemType in pairs(OmniCraftItemTypes) do
			if tostring(name):lower() == lower then
				return { name = name, itemType = itemType }
			end
		end
		for name, itemType in pairs(OmniCraftItemTypes) do
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

local function BuildRecipeSuggestion(name, data)
	data = data or {}
	local craftType = tonumber(data.craftType)
	local itemType = tonumber(data.itemType)
	if craftType ~= nil and (itemType == nil or name == nil) then
		local recipe = LoadLiveRecipe(craftType)
		if recipe ~= nil then
			name = recipe.name or name
			itemType = recipe.itemType or itemType
		end
	end
	if craftType == nil and itemType ~= nil then
		craftType = GetCraftTypeByItemType(itemType)
	end
	return {
		name = name,
		craftType = craftType,
		itemType = itemType,
	}
end

local function FindRecipeSuggestions(query, limit)
	local clean = Trim(query)
	local suggestions = {}
	local seen = {}
	limit = limit or 3
	if clean == "" then
		return suggestions
	end

	local function AddSuggestion(name, data)
		if name == nil then
			return #suggestions >= limit
		end
		local key = tostring(name):lower()
		if seen[key] then
			return #suggestions >= limit
		end
		seen[key] = true
		local suggestion = BuildRecipeSuggestion(tostring(name), data)
		if suggestion.name ~= nil then
			suggestions[#suggestions + 1] = suggestion
		end
		return #suggestions >= limit
	end

	local numeric = tonumber(clean)
	if numeric ~= nil and AddSuggestion(clean, { itemType = numeric, craftType = numeric }) then
		return suggestions
	end

	local lower = clean:lower()
	local function SearchTable(source, mode)
		if type(source) ~= "table" then
			return false
		end
		for name, data in pairs(source) do
			local candidate = tostring(name)
			local candidateLower = candidate:lower()
			local matched
			if mode == "exact" then
				matched = candidateLower == lower
			elseif mode == "prefix" then
				matched = candidateLower:sub(1, #lower) == lower
			else
				matched = candidateLower:find(lower, 1, true) ~= nil
			end
			if matched then
				local suggestionData = data
				if type(data) ~= "table" then
					suggestionData = { itemType = data }
				end
				if AddSuggestion(candidate, suggestionData) then
					return true
				end
			end
		end
		return false
	end

	for _, mode in ipairs({ "exact", "prefix", "contains" }) do
		if SearchTable(OmniCraftCraftIndex, mode) or SearchTable(OmniCraftItemTypes, mode) then
			return suggestions
		end
	end

	return suggestions
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

local CopperToParts

local function FormatMoney(copper)
	local prefix, gold, silver = CopperToParts(copper)
	local out = {}
	if gold > 0 then
		out[#out + 1] = tostring(gold) .. "g"
	end
	if silver > 0 then
		out[#out + 1] = tostring(silver) .. "s"
	end
	if #out == 0 then
		out[#out + 1] = "0s"
	end
	return prefix .. table.concat(out, " ")
end

local function FormatQuantity(value)
	value = tonumber(value) or 0
	if math.abs(value - math.floor(value + 0.5)) < 0.0001 then
		return tostring(math.floor(value + 0.5))
	end
	local text = string.format("%.2f", value)
	text = text:gsub("0+$", ""):gsub("%.$", "")
	return text
end

CopperToParts = function(copper)
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
	if copper >= 50 then
		silver = silver + 1
		if silver >= 100 then
			gold = gold + 1
			silver = silver - 100
		end
	end
	return sign, gold, silver
end

local function MeasureMoneyClusterWidth(copper)
	if copper == nil then
		return 0
	end
	local sign, gold, silver = CopperToParts(copper)
	local width = 0
	local parts = {}
	if sign ~= "" then
		width = width + 7
	end
	if gold > 0 then
		parts[#parts + 1] = gold
	end
	if silver > 0 or #parts == 0 then
		parts[#parts + 1] = silver
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
	local exact = tonumber(auctionPrices[item])
		or tonumber(auctionPrices[trimmed])
		or tonumber(auctionPrices[trimmed:lower()])
		or 0
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
	local line
	local ok = pcall(function()
		if type(CreateLine) == "function" then
			line = CreateLine(parent, "TYPE1", "artwork")
		else
			line = parent:CreateDrawable("ui/common/default.dds", "line_01", "artwork")
			if line ~= nil and line.SetTextureColor ~= nil then
				line:SetTextureColor("default")
			end
		end
	end)
	if not ok or line == nil or line.SetExtent == nil or line.AddAnchor == nil then
		line = parent:CreateColorDrawable(0.42, 0.42, 0.42, 0.28, "artwork")
	end
	line:SetExtent(WINDOW_WIDTH - 36, 2)
	line:AddAnchor("TOPLEFT", parent, 18, y)
	return line
end

local function CreateWindowBackground(window)
	if type(SettingWindowSkin) == "function" then
		local ok = pcall(function()
			SettingWindowSkin(window)
		end)
		if ok then
			return nil
		end
	end
	local bg = window:CreateDrawable("ui/common/default.dds", "main_bg", "background")
	if bg ~= nil and bg.AddAnchor ~= nil then
		bg:AddAnchor("TOPLEFT", window, -5, -5)
		bg:AddAnchor("BOTTOMRIGHT", window, 5, 5)
		return bg
	end
	bg = window:CreateColorDrawable(0.15, 0.15, 0.15, 0.90, "background")
	bg:AddAnchor("TOPLEFT", window, 0, 0)
	bg:AddAnchor("BOTTOMRIGHT", window, 0, 0)
	return bg
end

local function CreateQuestStylePanel(parent, id, top, bottom, alpha)
	local holder = parent:CreateChildWidget("emptywidget", id, 0, true)
	holder:AddAnchor("TOPLEFT", parent, 14, top)
	holder:AddAnchor("BOTTOMRIGHT", parent, -14, bottom)
	local ok, bg = pcall(function()
		local drawable = holder:CreateDrawable("ui/common/default.dds", "common_bg", "background")
		if drawable ~= nil and drawable.SetTextureColor ~= nil then
			drawable:SetTextureColor("bg_02")
			return drawable
		end
		if type(CreateContentBackground) == "function" then
			return CreateContentBackground(holder, "TYPE11", "bg_02", "background")
		end
		return drawable
	end)
	if ok and bg ~= nil then
		bg:AddAnchor("TOPLEFT", holder, 0, 0)
		bg:AddAnchor("BOTTOMRIGHT", holder, 0, 0)
	else
		bg = holder:CreateColorDrawable(0.78, 0.73, 0.58, alpha or 0.18, "background")
		bg:AddAnchor("TOPLEFT", holder, 0, 0)
		bg:AddAnchor("BOTTOMRIGHT", holder, 0, 0)
	end
	return holder
end

local function CreateQuestStyleStrip(parent, id, x, y, width, height, alpha)
	local holder = parent:CreateChildWidget("emptywidget", id, 0, true)
	holder:SetExtent(width, height)
	holder:AddAnchor("TOPLEFT", parent, x, y)
	local ok, bg = pcall(function()
		local drawable = holder:CreateDrawable("ui/common/default.dds", "common_bg", "background")
		if drawable ~= nil and drawable.SetTextureColor ~= nil then
			drawable:SetTextureColor("bg_02")
			return drawable
		end
		if type(CreateContentBackground) == "function" then
			return CreateContentBackground(holder, "TYPE11", "bg_02", "background")
		end
		return drawable
	end)
	if not ok or bg == nil then
		bg = holder:CreateColorDrawable(0.78, 0.73, 0.58, alpha or 0.14, "background")
	end
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
	button:SetStyle("text_default")
	button:SetAutoResize(false)
	button:SetInset(0, 0, 0, 0)
	button.style:SetAlign(ALIGN_CENTER)
	button.style:SetFontSize(12)
end

local function CreateButton(parent, name, text, x, y, width, onClick)
	local button = parent:CreateChildWidget("button", name, 0, true)
	StyleFlatButton(button)
	button:SetExtent(width, BUTTON_HEIGHT)
	button:SetWidth(width)
	button:SetHeight(BUTTON_HEIGHT)
	button:SetText(text)
	button:AddAnchor("TOPLEFT", parent, x, y)
	button:SetHandler("OnClick", onClick)
	button:SetWidth(width)
	return button
end

local function CreateSmallButton(parent, name, text, x, y, onClick)
	local button = parent:CreateChildWidget("button", name, 0, true)
	StyleFlatButton(button)
	button:SetExtent(SMALL_BUTTON_WIDTH, BUTTON_HEIGHT)
	button:SetWidth(SMALL_BUTTON_WIDTH)
	button:SetHeight(BUTTON_HEIGHT)
	button:SetText(text)
	button:AddAnchor("TOPLEFT", parent, x, y)
	button:SetHandler("OnClick", onClick)
	button:SetWidth(SMALL_BUTTON_WIDTH)
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
	if color ~= nil then
		SetTextColor(cluster.sign, color)
		SetTextColor(cluster.gl, color)
		SetTextColor(cluster.sl, color)
		SetTextColor(cluster.cl, color)
	else
		SetTextColorByKey(cluster.sign, "default")
		SetTextColorByKey(cluster.gl, "default")
		SetTextColorByKey(cluster.sl, "default")
		SetTextColorByKey(cluster.cl, "default")
	end
end

ShowMoneyCluster = function(cluster, copper, x, y, color)
	if cluster == nil or mainWindow == nil then
		return 0
	end
	HideMoneyCluster(cluster)
	SetMoneyClusterColor(cluster, color)

	local sign, gold, silver = CopperToParts(copper)
	local parts = {}
	if gold > 0 then
		parts[#parts + 1] = { label = cluster.gl, icon = cluster.gi, value = gold }
	end
	if silver > 0 or #parts == 0 then
		parts[#parts + 1] = { label = cluster.sl, icon = cluster.si, value = silver }
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

local function BuildPlan(finalName, finalCrafts)
	local finalRecipe = ResolveRecipe(finalName)
	if finalRecipe == nil then
		return nil
	end

	local result = { stages = {}, stageByKey = {}, stageByName = {}, finalUnits = 0 }
	local nextStageId = 0

	local function NewStageKey(name)
		nextStageId = nextStageId + 1
		return string.format("%d:%s", nextStageId, tostring(name))
	end

	local function BuildStage(name, requiredUnits, path)
		local recipe = ResolveRecipe(name)
		if recipe == nil then
			return nil
		end
		path = path or {}
		local key = NewStageKey(name)
		local yield = math.max(1, tonumber(recipe.yield) or 1)
		local craftScale = (requiredUnits or 0) / yield
		local stage = {
			key = key,
			name = name,
			crafts = requiredUnits,
			craftFee = craftScale * ((recipe.cost) or 0),
			labor = craftScale * ((recipe.laborcost) or 0),
			lines = {},
		}
		result.stages[#result.stages + 1] = stage
		result.stageByKey[key] = stage
		if result.stageByName[name] == nil then
			result.stageByName[name] = stage
		end

		local nextPath = {}
		for pathName in pairs(path) do
			nextPath[pathName] = true
		end
		nextPath[name] = true

		for _, material in ipairs(recipe.materials or {}) do
			local qty = craftScale * (material.count or 0)
			local kind = "ah"
			local childKey = nil
			if material.fromStage and ResolveRecipe(material.item) ~= nil then
				kind = "craft"
				if not nextPath[material.item] then
					local childStage = BuildStage(material.item, qty, nextPath)
					childKey = childStage and childStage.key or nil
				end
			elseif material.fromVendor then
				kind = "vendor"
			end
			stage.lines[#stage.lines + 1] = {
				item = material.item,
				qty = qty,
				kind = kind,
				childKey = childKey,
			}
			DebugPlan(
				string.format(
					"stage=%s crafts=%s material=%s qty=%s kind=%s",
					tostring(name),
					tostring(requiredUnits),
					tostring(material.item),
					tostring(qty),
					tostring(kind)
				)
			)
		end
		return stage
	end

	result.rootStage = BuildStage(finalName, finalCrafts, {})
	result.finalUnits = finalCrafts

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

local ResizeWindowForRows

local function RenderRowItems(items)
	items = items or {}
	rows.renderItems = items
	rows.scrollOffset = tonumber(rows.scrollOffset) or 0
	local maxOffset = math.max(0, #items - MAX_ROW_COUNT)
	if rows.scrollOffset > maxOffset then
		rows.scrollOffset = maxOffset
	end
	if rows.scrollOffset < 0 then
		rows.scrollOffset = 0
	end
	ClearRows()
	if stepLabel ~= nil then
		if #items > MAX_ROW_COUNT then
			stepLabel:SetText(
				string.format(
					"Rows %d-%d / %d",
					rows.scrollOffset + 1,
					math.min(#items, rows.scrollOffset + MAX_ROW_COUNT),
					#items
				)
			)
		else
			stepLabel:SetText("")
		end
	end
	for visibleIndex = 1, MAX_ROW_COUNT do
		local item = items[rows.scrollOffset + visibleIndex]
		if item == nil then
			break
		end
		if item.kind == "line" then
			RowLine(visibleIndex)
		else
			Row(
				visibleIndex,
				item.left,
				item.mid,
				item.unitPrice,
				item.totalPrice,
				item.color,
				item.onClick
			)
		end
	end
	ResizeWindowForRows(math.min(#items, MAX_ROW_COUNT))
end

local function ScrollBreakdown(delta)
	if rows.renderItems == nil or #rows.renderItems <= MAX_ROW_COUNT then
		return
	end
	rows.scrollOffset = (tonumber(rows.scrollOffset) or 0) + delta
	RenderRowItems(rows.renderItems)
end

ResizeWindowForRows = function(rowCount)
	if mainWindow == nil then
		return
	end
	local height = ROW_TOP + (math.max(1, rowCount or 1) * ROW_HEIGHT) + FOOTER_HEIGHT
	if tradePackInfo ~= nil then
		height = height + TRADE_COMMERCE_FOOTER_HEIGHT
	end
	if height < MIN_WINDOW_HEIGHT then
		height = MIN_WINDOW_HEIGHT
	end
	mainWindow:SetExtent(WINDOW_WIDTH, height)
end

local BuildVisiblePlan
local RenderPlan
local UpdateTradeTargetControl
local GetTradeBasePrice

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

local function DetectTradePack(recipeName)
	if type(recipeName) ~= "string" then
		return nil
	end
	local isKnownTradePack = recipeName:find("Specialty", 1, true) ~= nil
		or recipeName:find(" Pack", 1, true) ~= nil
		or GetTradeBasePrice(5, recipeName) ~= nil
		or GetTradeBasePrice(8, recipeName) ~= nil
		or GetTradeBasePrice(20, recipeName) ~= nil
		or GetTradeBasePrice(4, recipeName) ~= nil
		or GetTradeBasePrice(12, recipeName) ~= nil
		or GetTradeBasePrice(17, recipeName) ~= nil
		or GetTradeBasePrice(33, recipeName) ~= nil
	if not isKnownTradePack then
		return nil
	end
	for _, zone in ipairs(TradeOriginZones) do
		if StartsWith(recipeName, zone.prefix) then
			return {
				name = recipeName,
				originName = zone.prefix,
				originZone = zone.zone,
				continent = zone.continent,
			}
		end
	end
	return nil
end

local function GetAllowedTradeTargets(info)
	if info == nil then
		return {}
	end
	local targets = TradeTargetZones[info.continent] or {}
	local filtered = {}
	for _, target in ipairs(targets) do
		if target.zone ~= info.originZone then
			filtered[#filtered + 1] = target
		end
	end
	return filtered
end

local function FindTargetByZone(zone)
	zone = tonumber(zone)
	for _, targets in pairs(TradeTargetZones) do
		for _, target in ipairs(targets) do
			if target.zone == zone then
				return target
			end
		end
	end
	return nil
end

local function GetDefaultTradeTarget(info)
	local targets = GetAllowedTradeTargets(info)
	return targets[1]
end

GetTradeBasePrice = function(toZone, packName)
	if toZone == 5 and type(SOLZREED_PRICE) == "table" and SOLZREED_PRICE[packName] ~= nil then
		return tonumber(SOLZREED_PRICE[packName][1])
	elseif toZone == 8 and type(TWOCROWNS_PRICE) == "table" and TWOCROWNS_PRICE[packName] ~= nil then
		return tonumber(TWOCROWNS_PRICE[packName][1])
	elseif toZone == 20 and type(CINDERSTONE_MOOR_PRICE) == "table" and CINDERSTONE_MOOR_PRICE[packName] ~= nil then
		return tonumber(CINDERSTONE_MOOR_PRICE[packName][1])
	elseif toZone == 4 and type(SOLIS_HEADLANDS_PRICE) == "table" and SOLIS_HEADLANDS_PRICE[packName] ~= nil then
		return tonumber(SOLIS_HEADLANDS_PRICE[packName][1])
	elseif toZone == 12 and type(VILLANELLE_PRICE) == "table" and VILLANELLE_PRICE[packName] ~= nil then
		return tonumber(VILLANELLE_PRICE[packName][1])
	elseif toZone == 17 and type(YNYSTERE_PRICE) == "table" and YNYSTERE_PRICE[packName] ~= nil then
		return tonumber(YNYSTERE_PRICE[packName][1])
	elseif toZone == 33 and type(HEEDMAR_PRICE) == "table" and HEEDMAR_PRICE[packName] ~= nil then
		return tonumber(HEEDMAR_PRICE[packName][1])
	end
	return nil
end

local function DetectCommerceSkill()
	if X2Ability == nil or type(X2Ability.GetAllMyActabilityInfos) ~= "function" then
		return 0
	end
	local ok, infos = pcall(function()
		return X2Ability:GetAllMyActabilityInfos()
	end)
	if not ok or type(infos) ~= "table" then
		return 0
	end
	for _, info in pairs(infos) do
		if type(info) == "table" and info.name == "Commerce" then
			return (tonumber(info.point) or 0) + (tonumber(info.modifyPoint) or 0)
		end
	end
	return 0
end

local function RefreshDetectedCommerceSkill()
	detectedCommerceSkill = DetectCommerceSkill()
	return detectedCommerceSkill
end

local function GetCommerceSkill()
	if commerceOverride ~= nil then
		return commerceOverride
	end
	return RefreshDetectedCommerceSkill()
end

local function FormatCommerce(value)
	return tostring(math.floor(tonumber(value) or 0))
end

local function GetCommerceLaborDiscount(skill)
	skill = tonumber(skill) or 0
	if skill >= 180000 then
		return 0.40
	elseif skill >= 150000 then
		return 0.30
	elseif skill >= 130000 then
		return 0.25
	elseif skill >= 50000 then
		return 0.20
	elseif skill >= 40000 then
		return 0.15
	elseif skill >= 30000 then
		return 0.10
	elseif skill >= 20000 then
		return 0.05
	end
	return 0
end

local function GetTradePackTurnInLabor()
	local discount = GetCommerceLaborDiscount(GetCommerceSkill())
	return math.ceil(70 * (1 - discount))
end

local function GetFreshnessMultiplier(packName, targetZone)
	if tradeMaxFreshness ~= true then
		return 1
	end
	if targetZone == 33 then
		return 1.30
	end
	for packType, multiplier in pairs(TradeFreshnessMultipliers) do
		if tostring(packName or ""):find(packType, 1, true) ~= nil then
			return multiplier
		end
	end
	return 1
end

local function CalculateTradeTurnIn(packName, targetZone, ratio)
	local basePrice = GetTradeBasePrice(targetZone, packName)
	if basePrice == nil or ratio == nil then
		return nil
	end
	local commerceBonus = 1 + ((GetCommerceSkill() / 10000) * 0.05)
	local freshnessBonus = GetFreshnessMultiplier(packName, targetZone)
	return math.floor((basePrice * ratio) * commerceBonus * freshnessBonus)
end

local function GetTradeRatioKey(info, target)
	if info == nil or target == nil then
		return nil
	end
	return tostring(info.originZone) .. ":" .. tostring(target.zone) .. ":" .. tostring(info.name)
end

local function RequestTradeRatio(force)
	if tradePackInfo == nil or selectedTradeTarget == nil then
		return
	end
	local key = GetTradeRatioKey(tradePackInfo, selectedTradeTarget)
	if key == nil or tradeRatioRequestKey == key or tradePackInfo.originZone == selectedTradeTarget.zone then
		return
	end
	if X2Store == nil or type(X2Store.GetSpecialtyRatioBetween) ~= "function" then
		return
	end
	if force ~= true and tradeRatioStart > 0 and (os.time() - tradeRatioStart) < tradeRatioCooldown then
		tradeRatioDeferred = true
		return
	end
	tradeRatioRequestKey = key
	tradeRatioPending = true
	tradeRatioDeferred = false
	tradeRatioStart = os.time()
	currentTradeRatio = nil
	pcall(function()
		X2Store:GetSpecialtyRatioBetween(tradePackInfo.originZone, selectedTradeTarget.zone)
	end)
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
			if material.kind == "craft" and material.childKey ~= nil and expandedStages[material.childKey] then
				WalkStage(plan.stageByKey[material.childKey])
			elseif material.kind == "vendor" then
				AddNeed(vendorNeed, vendorOrder, material.item, material.qty)
			else
				AddNeed(shopNeed, shopOrder, material.item, material.qty)
			end
		end
	end

	WalkStage(plan.rootStage)

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

	local isTradePack = tradePackInfo ~= nil
	local finalUnitPrice = isTradePack and 0 or GetAuctionUnitPrice(selectedRecipe)
	local visible = BuildVisiblePlan()
	local piecingCostTotal = visible.craftFee or 0
	local missingPrices = {}
	local hasFinalPrice = not isTradePack and finalUnitPrice ~= nil and finalUnitPrice > 0
	local producedUnits = math.max(1, plan.finalUnits or craftCount)
	local outrightCostPerUnit = hasFinalPrice and finalUnitPrice or nil
	DebugPrice(
		string.format(
			"economy final=%s unit=%s units=%s craftFee=%s",
			tostring(selectedRecipe),
			tostring(finalUnitPrice),
			tostring(producedUnits),
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
				piecingCostTotal = piecingCostTotal + (need * unit)
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
			piecingCostTotal = piecingCostTotal + (need * GetVendorUnitPrice(entry.item))
		end
	end

	if #missingPrices > 0 then
		DebugBad("skipped missing prices: " .. table.concat(missingPrices, ", "))
	end

	-- compute per-produced-unit costs (divide total costs by producedUnits)
	local piecingCost = piecingCostTotal / producedUnits
	local laborPerUnit = (visible.totalLabor or 0) / producedUnits
	local difference = nil
	if isTradePack then
		laborPerUnit = laborPerUnit + GetTradePackTurnInLabor()
		local turnIn = nil
		if selectedTradeTarget ~= nil and currentTradeRatio ~= nil then
			turnIn = CalculateTradeTurnIn(selectedRecipe, selectedTradeTarget.zone, currentTradeRatio)
		end
		if turnIn ~= nil then
			difference = turnIn - piecingCost
		end
		return {
			isTradePack = true,
			turnIn = turnIn,
			piecing = piecingCost,
			difference = difference,
			perLabor = (difference ~= nil and laborPerUnit > 0) and (difference / laborPerUnit) or nil,
			labor = laborPerUnit,
			ratioPending = tradeRatioPending == true,
			noTurnIn = turnIn == nil,
		}
	end
	if outrightCostPerUnit ~= nil then
		difference = outrightCostPerUnit - piecingCost
	end
	local craftFeePerUnit = (visible.craftFee or 0) / producedUnits
	if outrightCostPerUnit ~= nil and #(visible.shop or {}) > 0 and piecingCost <= craftFeePerUnit then
		DebugBad(
			string.format(
				"piece cost suspicious: piece=%s craftFee_per_unit=%s shopItems=%s",
				tostring(piecingCost),
				tostring(craftFeePerUnit),
				tostring(#(visible.shop or {}))
			)
		)
	end
	DebugPrice(
		string.format(
			"economy result outright_per_unit=%s piece_per_unit=%s diff_per_unit=%s labor_total=%s",
			tostring(outrightCostPerUnit),
			tostring(piecingCost),
			tostring(difference),
			tostring(visible.totalLabor or 0)
		)
	)
	return {
		outright = outrightCostPerUnit,
		piecing = piecingCost,
		difference = difference,
		perLabor = (difference ~= nil and laborPerUnit > 0) and (difference / laborPerUnit) or nil,
		labor = laborPerUnit,
		noOutright = outrightCostPerUnit == nil,
	}
end

local function UpdateEconomyLabel()
	if economyLabel == nil then
		return
	end
	HideEconomyMoney()

	local economy = CalculateEconomy()
	if economy == nil then
		--economyLabel:SetText("Economy: click Check Prices after opening the Auction House.")
		SetTextColorByKey(economyLabel, "default")
	elseif economy.missing ~= nil then
		--economyLabel:SetText("Economy: missing prices for " .. tostring(#economy.missing) .. " material(s).")
		SetTextColorByKey(economyLabel, "default")
	else
		--economyLabel:SetText("")
		SetTextColorByKey(economyLabel, "default")
		if economyMoney ~= nil then
			for _, label in ipairs(economyMoney.labels or {}) do
				SetTextColorByKey(label, "default")
				label:Show(true)
			end
			economyMoney.outrightText:SetText("Outright: ")
			economyMoney.pieceText:SetText("Piece: ")
			economyMoney.diffText:SetText("Diff: ")
			economyMoney.laborText:SetText("")
			economyMoney.perLaborText:SetText("/L")
			economyMoney.totalOutrightText:SetText(string.format("Outright (%d): ", craftCount))
			economyMoney.totalPieceText:SetText(string.format("Piece (%d): ", craftCount))
			economyMoney.totalOutrightText:Show(false)
			economyMoney.totalPieceText:Show(false)
			HideMoneyCluster(economyMoney.totalOutright)
			HideMoneyCluster(economyMoney.totalPiece)
			if economy.isTradePack == true then
				economyMoney.outrightText:SetText("Turn-in: ")
				economyMoney.pieceText:SetText("Cost: ")
				economyMoney.diffText:SetText("Profit: ")
				economyMoney.laborText:SetText("")
				economyMoney.perLaborText:SetText("/L")
				economyMoney.totalOutrightText:SetText(string.format("Turn-in (%d): ", craftCount))
				economyMoney.totalPieceText:SetText(string.format("Cost (%d): ", craftCount))
				economyMoney.pieceText:Show(true)
				ShowMoneyCluster(economyMoney.piece, economy.piecing, 302, CRAFTLABELHEIGHT1, nil)
				if economy.noTurnIn == true then
					economyMoney.outrightText:Show(false)
					HideMoneyCluster(economyMoney.outright)
					economyMoney.diffText:Show(false)
					HideMoneyCluster(economyMoney.diff)
					economyMoney.laborText:Show(false)
					economyMoney.perLaborText:Show(false)
					HideMoneyCluster(economyMoney.perLabor)
				else
					local profitColor = economy.difference ~= nil and economy.difference < 0 and MISSING_RED or COMPLETE_GREEN
					ShowMoneyCluster(economyMoney.outright, economy.turnIn, 76, CRAFTLABELHEIGHT1, nil)
					ShowMoneyCluster(economyMoney.diff, economy.difference, 62, CRAFTLABELHEIGHT2, profitColor)
					local perLaborWidth =
						ShowMoneyCluster(economyMoney.perLabor, economy.perLabor, 280, CRAFTLABELHEIGHT2, profitColor)
					economyMoney.perLaborText:RemoveAllAnchors()
					economyMoney.perLaborText:AddAnchor("TOPLEFT", mainWindow, 282 + perLaborWidth, CRAFTLABELHEIGHT2)
					if craftCount > 1 then
						economyMoney.totalOutrightText:Show(true)
						ShowMoneyCluster(economyMoney.totalOutright, economy.turnIn * craftCount, 112, CRAFTLABELHEIGHT3, nil)
					end
				end
				if craftCount > 1 then
					economyMoney.totalPieceText:Show(true)
					ShowMoneyCluster(economyMoney.totalPiece, economy.piecing * craftCount, 332, CRAFTLABELHEIGHT3, nil)
				end
			elseif economy.noOutright == true then
				economyMoney.outrightText:Show(false)
				HideMoneyCluster(economyMoney.outright)
				economyMoney.diffText:Show(false)
				HideMoneyCluster(economyMoney.diff)
				economyMoney.laborText:Show(false)
				economyMoney.perLaborText:Show(false)
				HideMoneyCluster(economyMoney.perLabor)
				economyMoney.pieceText:Show(true)
				ShowMoneyCluster(economyMoney.piece, economy.piecing, 76, CRAFTLABELHEIGHT1, nil)
			else
				ShowMoneyCluster(economyMoney.outright, economy.outright, 76, CRAFTLABELHEIGHT1, nil)
				ShowMoneyCluster(economyMoney.piece, economy.piecing, 302, CRAFTLABELHEIGHT1, nil)
				ShowMoneyCluster(economyMoney.diff, economy.difference, 52, CRAFTLABELHEIGHT2, nil)
				local perLaborWidth = ShowMoneyCluster(economyMoney.perLabor, economy.perLabor, 280, CRAFTLABELHEIGHT2, nil)
				economyMoney.perLaborText:RemoveAllAnchors()
				economyMoney.perLaborText:AddAnchor("TOPLEFT", mainWindow, 282 + perLaborWidth, CRAFTLABELHEIGHT2)
			end
			if economy.isTradePack ~= true and craftCount > 1 then
				if economy.noOutright ~= true then
					economyMoney.totalOutrightText:Show(true)
					ShowMoneyCluster(economyMoney.totalOutright, economy.outright * craftCount, 112, CRAFTLABELHEIGHT3, nil)
				end
				economyMoney.totalPieceText:Show(true)
				ShowMoneyCluster(economyMoney.totalPiece, economy.piecing * craftCount, 332, CRAFTLABELHEIGHT3, nil)
			end
		end
	end
end

RenderPlan = function()
	if mainWindow == nil or craftLabel == nil then
		return
	end
	ClearRows()
	if plan == nil or selectedRecipe == nil then
		rows.renderItems = {}
		rows.scrollOffset = 0
		--targetLabel:SetText("Target: none")
		craftLabel:SetText("Crafts: -")
		if stepLabel ~= nil then
			stepLabel:SetText("")
		end
		UpdateTradeTargetControl()
		HideMoneyCluster(craftFeeMoney)
		--economyLabel:SetText("Economy: -")
		HideEconomyMoney()
		--shoppingLabel:SetText("Shopping: -")
		--stepLabel:SetText("No shopping run active.")
		ResizeWindowForRows(1)
		return
	end

	UpdateTradeTargetControl()
	if tradePackInfo ~= nil then
		targetLabel:SetText(
			string.format(
				"Target: %s   Route: %s -> %s",
				tostring(selectedRecipe),
				tostring(tradePackInfo.originName or "-"),
				tostring((selectedTradeTarget and selectedTradeTarget.name) or "-")
			)
		)
	else
		targetLabel:SetText("Target: " .. tostring(selectedRecipe))
	end
	local visible = BuildVisiblePlan()
	local totalLabor = visible.totalLabor or 0
	if tradePackInfo ~= nil then
		totalLabor = totalLabor + (GetTradePackTurnInLabor() * (plan.finalUnits or craftCount))
	end
	craftLabel:SetText(
		string.format(
			"Crafts: %d   Produces: %d   Labor: %d   Craft fee:",
			craftCount,
			plan.finalUnits or craftCount,
			totalLabor
		)
	)
	if craftFeeMoney ~= nil then
		ShowMoneyCluster(craftFeeMoney, visible.craftFee or 0, 345, 134, nil)
	end
	UpdateEconomyLabel()

	local missing = 0
	for _, entry in ipairs(visible.shop or {}) do
		if (entry.buy or 0) > 0 then
			missing = missing + 1
		end
	end
	--shoppingLabel:SetText(string.format("Auction items still needed: %d", missing))

	local displayRows = {}
	local function AddRow(left, mid, unitPrice, totalPrice, color, onClick)
		displayRows[#displayRows + 1] = {
			kind = "row",
			left = left,
			mid = mid,
			unitPrice = unitPrice,
			totalPrice = totalPrice,
			color = color,
			onClick = onClick,
		}
	end
	local function AddLine()
		displayRows[#displayRows + 1] = { kind = "line" }
	end

	local function RenderStage(stage, depth, showHeader)
		if stage == nil then
			return
		end
		local indent = string.rep("  ", depth)
		if showHeader ~= false then
			AddRow(
				indent .. tostring(stage.name),
				FormatQuantity(stage.crafts),
				nil,
				nil,
				nil
			)
		end
		for _, material in ipairs(stage.lines or {}) do
			local isCraft = material.kind == "craft" and material.childKey ~= nil
			local unitPrice = GetVendorUnitPrice(material.item)
			if unitPrice <= 0 then
				unitPrice = GetAuctionUnitPrice(material.item)
			end
			local function Toggle()
				expandedStages[material.childKey] = not expandedStages[material.childKey]
				RebuildBuyQueue()
				RenderPlan()
			end
			local expandPrefix = ""
			if isCraft then
				expandPrefix = expandedStages[material.childKey] and "[-] " or "[+] "
			end
			AddRow(
				indent .. "  " .. expandPrefix .. tostring(material.item),
				FormatQuantity(material.qty),
				unitPrice > 0 and unitPrice or nil,
				unitPrice > 0 and ((material.qty or 0) * unitPrice) or nil,
				nil,
				isCraft and Toggle or nil
			)
			if isCraft and expandedStages[material.childKey] then
				RenderStage(plan.stageByKey[material.childKey], depth + 1, false)
			end
		end
	end

	RenderStage(plan.rootStage, 0, true)

	AddLine()

	if #visible.vendor > 0 then
		AddLine()
		for _, entry in ipairs(visible.vendor) do
			local unitPrice = GetVendorUnitPrice(entry.item)
			AddRow(
				entry.item,
				FormatQuantity(entry.need or 0),
				unitPrice > 0 and unitPrice or nil,
				unitPrice > 0 and ((entry.need or 0) * unitPrice) or nil,
				WARN_ORANGE
			)
		end
	end
	RenderRowItems(displayRows)
end

local function RecomputePlan()
	ScanInventory()
	if selectedRecipe == nil then
		plan = nil
		tradePackInfo = nil
		selectedTradeTarget = nil
		currentTradeRatio = nil
		tradeRatioRequestKey = nil
		tradeRatioPending = false
		tradeRatioDeferred = false
	else
		plan = BuildPlan(selectedRecipe, craftCount)
		local previousTargetZone = selectedTradeTarget and selectedTradeTarget.zone or nil
		local previousKey = tradeRatioRequestKey
		local previousRatio = currentTradeRatio
		local previousPending = tradeRatioPending
		local previousDeferred = tradeRatioDeferred
		tradePackInfo = DetectTradePack(selectedRecipe)
		currentTradeRatio = nil
		tradeRatioRequestKey = nil
		tradeRatioPending = false
		tradeRatioDeferred = false
		if tradePackInfo ~= nil then
			selectedTradeTarget = previousTargetZone and FindTargetByZone(previousTargetZone) or nil
			local allowed = GetAllowedTradeTargets(tradePackInfo)
			local targetAllowed = false
			for _, target in ipairs(allowed) do
				if selectedTradeTarget ~= nil and selectedTradeTarget.zone == target.zone then
					targetAllowed = true
					break
				end
			end
			if not targetAllowed then
				selectedTradeTarget = GetDefaultTradeTarget(tradePackInfo)
			end
			local nextKey = GetTradeRatioKey(tradePackInfo, selectedTradeTarget)
			if previousKey == nextKey then
				tradeRatioRequestKey = previousKey
				currentTradeRatio = previousRatio
				tradeRatioPending = previousPending == true and previousRatio == nil
				tradeRatioDeferred = previousDeferred == true and previousRatio == nil
			else
				RequestTradeRatio()
			end
		else
			selectedTradeTarget = nil
		end
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
		SetStatus("Craft not found.", MISSING_RED)
		return false
	end

	selectedRecipe = recipeName
	recipeEdit:SetText(recipeName)
	if recipeEdit.HideDropdown ~= nil then
		recipeEdit:HideDropdown()
	end
	if recipePreviewDropdown ~= nil then
		recipePreviewDropdown:HidePreview()
	end
	ADDON:SaveData(SAVE_KEY, { recipe = recipeName, count = craftCount })
	currentBuyIndex = 0
	waitingForAuction = false
	RecomputePlan()
	--SetStatus(
	--	inventoryOK and "Craft loaded. Review the list, then click Go to Buy."
	--		or "Craft loaded. Inventory scan unavailable.",
	--	inventoryOK and nil or WARN_ORANGE
	--)
	--stepLabel:SetText("No shopping run active.")
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

local function CreateBuyTotalHeader(parent, id, text, x, width, align)
	local label = parent:CreateChildWidget("label", id, 0, true)
	label:SetExtent(width, 18)
	label:AddAnchor("TOPLEFT", parent, x, 72)
	label:SetText(text)
	StyleLabel(label, 12, align or ALIGN_LEFT, "brown")
	return label
end

local function CreateBuyTotalWindow()
	if buyTotalWindow ~= nil then
		return
	end

	buyTotalWindow = CreateEmptyWindow("omniCraftBuyTotalWindow", "UIParent")
	buyTotalWindow:SetExtent(BUY_TOTAL_WINDOW_WIDTH, 170)
	buyTotalWindow:AddAnchor("CENTER", "UIParent", "CENTER", 0, 0)
	buyTotalWindow:Show(false)
	buyTotalWindow:EnableDrag(true)
	buyTotalWindow:SetCloseOnEscape(true)
	buyTotalWindow:SetHandler("OnDragStart", function(self)
		self:StartMoving()
	end)
	buyTotalWindow:SetHandler("OnDragStop", function(self)
		self:StopMovingOrSizing()
	end)

	CreateWindowBackground(buyTotalWindow)
	CreateCloseButton(buyTotalWindow, "omniCraftBuyTotalClose", function()
		buyTotalWindow:Show(false)
	end)

	local title = buyTotalWindow:CreateChildWidget("label", "omniCraftBuyTotalTitle", 0, true)
	title:SetExtent(220, 24)
	title:AddAnchor("TOPLEFT", buyTotalWindow, 18, 14)
	title:SetText("Buy Total")
	StyleLabel(title, 18, ALIGN_LEFT, "brown")

	local target = buyTotalWindow:CreateChildWidget("label", "omniCraftBuyTotalTarget", 0, true)
	target:SetExtent(BUY_TOTAL_WINDOW_WIDTH - 36, 22)
	target:AddAnchor("TOPLEFT", buyTotalWindow, 18, 42)
	StyleLabel(target, 12, ALIGN_LEFT, "default")
	buyTotalWindow.target = target

	local line = buyTotalWindow:CreateDrawable("ui/common/default.dds", "line_01", "artwork")
	if line ~= nil and line.SetTextureColor ~= nil then
		line:SetTextureColor("default")
	end
	if line == nil or line.SetExtent == nil or line.AddAnchor == nil then
		line = buyTotalWindow:CreateColorDrawable(0.42, 0.42, 0.42, 0.28, "artwork")
	end
	line:SetExtent(BUY_TOTAL_WINDOW_WIDTH - 36, 2)
	line:AddAnchor("TOPLEFT", buyTotalWindow, 18, 66)

	CreateBuyTotalHeader(buyTotalWindow, "omniCraftBuyTotalItemHeader", "Item", 20, 210, ALIGN_LEFT)
	CreateBuyTotalHeader(buyTotalWindow, "omniCraftBuyTotalNeedHeader", "Total", 235, 58, ALIGN_RIGHT)
	CreateBuyTotalHeader(buyTotalWindow, "omniCraftBuyTotalHaveHeader", "Owned", 306, 58, ALIGN_RIGHT)
	CreateBuyTotalHeader(buyTotalWindow, "omniCraftBuyTotalBuyHeader", "To Buy", 377, 58, ALIGN_RIGHT)

	for index = 1, BUY_TOTAL_MAX_ROWS do
		local y = BUY_TOTAL_ROW_TOP + ((index - 1) * BUY_TOTAL_ROW_HEIGHT)
		local item = buyTotalWindow:CreateChildWidget("label", "omniCraftBuyTotalItem" .. tostring(index), index, true)
		item:SetExtent(210, 22)
		item:AddAnchor("TOPLEFT", buyTotalWindow, 20, y)
		StyleLabel(item, 12, ALIGN_LEFT, "default")

		local need = buyTotalWindow:CreateChildWidget("label", "omniCraftBuyTotalNeed" .. tostring(index), index, true)
		need:SetExtent(58, 22)
		need:AddAnchor("TOPLEFT", buyTotalWindow, 235, y)
		StyleLabel(need, 12, ALIGN_RIGHT, "default")

		local have = buyTotalWindow:CreateChildWidget("label", "omniCraftBuyTotalHave" .. tostring(index), index, true)
		have:SetExtent(58, 22)
		have:AddAnchor("TOPLEFT", buyTotalWindow, 306, y)
		StyleLabel(have, 12, ALIGN_RIGHT, "default")

		local buy = buyTotalWindow:CreateChildWidget("label", "omniCraftBuyTotalBuy" .. tostring(index), index, true)
		buy:SetExtent(58, 22)
		buy:AddAnchor("TOPLEFT", buyTotalWindow, 377, y)
		StyleLabel(buy, 12, ALIGN_RIGHT, "default")

		buyTotalRows[index] = { item = item, need = need, have = have, buy = buy }
	end

	local footer = buyTotalWindow:CreateChildWidget("label", "omniCraftBuyTotalFooter", 0, true)
	footer:SetExtent(BUY_TOTAL_WINDOW_WIDTH - 36, 22)
	footer:AddAnchor("BOTTOMLEFT", buyTotalWindow, 18, -24)
	StyleLabel(footer, 12, ALIGN_LEFT, "default")
	buyTotalWindow.footer = footer
end

local function BuildBuyTotalEntries()
	local entries = {}
	local visible = BuildVisiblePlan()
	for _, entry in ipairs(visible.shop or {}) do
		if (entry.need or 0) > 0 then
			entries[#entries + 1] = entry
		end
	end
	for _, entry in ipairs(visible.vendor or {}) do
		if (entry.need or 0) > 0 then
			entries[#entries + 1] = entry
		end
	end
	return entries
end

local function RenderBuyTotalWindow()
	CreateBuyTotalWindow()

	local entries = BuildBuyTotalEntries()
	local visibleRows = math.min(#entries, BUY_TOTAL_MAX_ROWS)
	local height = BUY_TOTAL_ROW_TOP + (math.max(1, visibleRows) * BUY_TOTAL_ROW_HEIGHT) + 52
	if height < 170 then
		height = 170
	end
	buyTotalWindow:SetExtent(BUY_TOTAL_WINDOW_WIDTH, height)
	buyTotalWindow.target:SetText("Target: " .. tostring(selectedRecipe or "-"))

	for index = 1, BUY_TOTAL_MAX_ROWS do
		local row = buyTotalRows[index]
		local entry = entries[index]
		if row ~= nil and entry ~= nil then
			row.item:SetText(tostring(entry.item))
			row.need:SetText(FormatQuantity(entry.need or 0))
			row.have:SetText(FormatQuantity(entry.have or 0))
			row.buy:SetText(FormatQuantity(entry.buy or 0))
			row.item:Show(true)
			row.need:Show(true)
			row.have:Show(true)
			row.buy:Show(true)
			if (entry.buy or 0) <= 0 then
				SetTextColorByKey(row.buy, "default")
			else
				SetTextColorByKey(row.buy, "brown")
			end
		elseif row ~= nil then
			row.item:SetText("")
			row.need:SetText("")
			row.have:SetText("")
			row.buy:SetText("")
			row.item:Show(false)
			row.need:Show(false)
			row.have:Show(false)
			row.buy:Show(false)
		end
	end

	if #entries == 0 then
		buyTotalWindow.footer:SetText("No buy materials for the current craft.")
	elseif #entries > BUY_TOTAL_MAX_ROWS then
		buyTotalWindow.footer:SetText(string.format("+ %d more item(s)", #entries - BUY_TOTAL_MAX_ROWS))
	else
		buyTotalWindow.footer:SetText("")
	end
end

local function ShowBuyTotalWindow()
	ApplyCount()
	if not EnsureInputRecipeLoaded() then
		SetStatus("Craft not found.", MISSING_RED)
		return
	end
	RecomputePlan()
	RenderBuyTotalWindow()
	buyTotalWindow:Show(true)
	buyTotalWindow:Raise()
end

local function SetPreviewIcon(icon, itemType)
	icon:ClearAllTextures()
	if itemType == nil or X2Item == nil or type(X2Item.GetItemIconSet) ~= "function" then
		icon:SetVisible(false)
		return
	end
	local ok, iconInfo = pcall(function()
		return X2Item:GetItemIconSet(itemType, 0)
	end)
	if not ok or type(iconInfo) ~= "table" or iconInfo.icon == nil then
		icon:SetVisible(false)
		return
	end
	icon:AddTexture(iconInfo.icon)
	if iconInfo.overIcon ~= nil then
		icon:AddTexture(iconInfo.overIcon)
	end
	if iconInfo.gradeIcon ~= nil then
		icon:AddTexture(iconInfo.gradeIcon)
	end
	icon:SetVisible(true)
end

local function CreateRecipePreviewDropdown(parent, edit, width)
	local dropdown = parent:CreateChildWidget("emptywidget", "omniCraftRecipePreviewDropdown", 0, true)
	dropdown:SetExtent(width, 74)
	dropdown:AddAnchor("TOPLEFT", edit, "BOTTOMLEFT", 0, 1)
	dropdown:Show(false)

	local bg = dropdown:CreateDrawable("ui/common/default.dds", "editbox_df", "background")
	bg:AddAnchor("TOPLEFT", dropdown, 0, 0)
	bg:AddAnchor("BOTTOMRIGHT", dropdown, 0, 0)

	dropdown.rows = {}
	for i = 1, 3 do
		local row = dropdown:CreateChildWidget("label", string.format("row[%d]", i), 0, true)
		row:SetExtent(width - 10, 22)
		row:AddAnchor("TOPLEFT", dropdown, 5, 3 + ((i - 1) * 23))
		row.style:SetAlign(ALIGN_LEFT)
		SetTextColorByKey(row, "default")

		local rowBg = row:CreateDrawable("ui/common/default.dds", "editbox_df", "background")
		if rowBg == nil then
			rowBg = row:CreateColorDrawable(0.78, 0.73, 0.58, 0.16, "background")
		end
		rowBg:AddAnchor("TOPLEFT", row, 0, 0)
		rowBg:AddAnchor("BOTTOMRIGHT", row, 0, 0)
		rowBg:SetVisible(false)
		row.rowBg = rowBg

		local icon = row:CreateIconDrawable("artwork")
		icon:SetExtent(18, 18)
		icon:AddAnchor("LEFT", row, 4, 0)
		icon:SetVisible(false)

		local text = row:CreateChildWidget("label", "name", 0, true)
		text:SetExtent(width - 32, 18)
		text:AddAnchor("LEFT", row, 28, 0)
		text.style:SetAlign(ALIGN_LEFT)
		SetTextColorByKey(text, "default")
		text:EnablePick(false)
		if text.style.SetEllipsis ~= nil then
			text.style:SetEllipsis(true)
		end

		function row:OnClick()
			if self.suggestion == nil then
				return
			end
			recipeEdit:SetText(self.suggestion.name)
			LoadRecipeFromInput()
		end
		row:SetHandler("OnClick", row.OnClick)
		function row:OnEnter()
			self.rowBg:SetVisible(true)
		end
		row:SetHandler("OnEnter", row.OnEnter)
		function row:OnLeave()
			self.rowBg:SetVisible(false)
		end
		row:SetHandler("OnLeave", row.OnLeave)

		dropdown.rows[i] = {
			row = row,
			icon = icon,
			text = text,
		}
	end

	function dropdown:HidePreview()
		self:Show(false)
		for _, entry in ipairs(self.rows) do
			entry.row.suggestion = nil
			entry.row:Show(false)
		end
	end

	function dropdown:Update(query)
		local suggestions = FindRecipeSuggestions(query, 3)
		for i = 1, 3 do
			local entry = self.rows[i]
			local suggestion = suggestions[i]
			if suggestion ~= nil then
				entry.row.suggestion = suggestion
				entry.text:SetText(suggestion.name)
				SetPreviewIcon(entry.icon, suggestion.itemType)
				entry.row:Show(true)
			else
				entry.row.suggestion = nil
				entry.row:Show(false)
			end
		end
		if #suggestions > 0 and self.Raise ~= nil then
			self:Raise()
		end
		self:Show(#suggestions > 0)
	end

	dropdown:HidePreview()
	return dropdown
end

local function SearchCurrentEntry(entry)
	X2Auction:SearchAuctionArticle(1, 0, 999, 1, 0, false, entry.search or entry.item, "0", "0")
	--SetStatus("Searching: " .. tostring(entry.item) .. ". Buy what you need, then click Next.", nil)
	--stepLabel:SetText(string.format("Step %d/%d: buy %d x %s", currentBuyIndex, #buyQueue, entry.buy or 0, entry.item))
end

local function StartShopping()
	if not EnsureInputRecipeLoaded() then
		--SetStatus("Load a craft first.", MISSING_RED)
		return
	end
	RecomputePlan()
	if #buyQueue == 0 then
		--SetStatus("All Auction House materials are already covered.", COMPLETE_GREEN)
		--stepLabel:SetText("Nothing to buy.")
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

	if tradePackInfo == nil then
		add(selectedRecipe)
	end
	for _, entry in ipairs(BuildVisiblePlan().shop or {}) do
		add(entry.item)
	end
end

local function SearchNextPrice()
	if #priceCheckQueue == 0 then
		priceCheckBusy = false
		currentPriceRequest = nil
		UpdateEconomyLabel()
		--SetStatus("Price check complete.", COMPLETE_GREEN)
		return
	end

	currentPriceRequest = table.remove(priceCheckQueue, 1)
	priceCheckBusy = true
	X2Auction:SearchAuctionArticle(1, 0, 999, 1, 0, false, currentPriceRequest.search, "0", "0")
	priceCheckStart = os.time()
	--SetStatus(
	--	"Checking price: " .. tostring(currentPriceRequest.item) .. " (" .. tostring(#priceCheckQueue) .. " left)",
	--	nil
	--)
	--stepLabel:SetText("Price check: " .. tostring(currentPriceRequest.item))
end

local function StartPriceCheck()
	if not EnsureInputRecipeLoaded() then
		--SetStatus("Load a craft first.", MISSING_RED)
		return
	end
	RecomputePlan()
	BuildPriceCheckQueue()
	if #priceCheckQueue == 0 then
		--SetStatus("Nothing needs an Auction House price check.", WARN_ORANGE)
		UpdateEconomyLabel()
		return
	end
	auctionPrices = {}
	if economyLabel ~= nil then
		--economyLabel:SetText("Economy: checking Auction House prices...")
		SetTextColorByKey(economyLabel, "default")
	end
	--SetStatus("Checking Auction House prices...", nil)
	SearchNextPrice()
end

local function NextShoppingStep()
	if selectedRecipe == nil then
		--SetStatus("Load a craft first.", MISSING_RED)
		return
	end
	if waitingForAuction then
		waitingForAuction = false
	else
		RecomputePlan()
	end

	if #buyQueue == 0 then
		--SetStatus("Shopping list complete.", COMPLETE_GREEN)
		stepLabel:SetText("Done.")
		return
	end

	currentBuyIndex = currentBuyIndex + 1
	if currentBuyIndex > #buyQueue then
		currentBuyIndex = 1
	end

	local entry = buyQueue[currentBuyIndex]
	if entry == nil then
		--SetStatus("Shopping list complete.", COMPLETE_GREEN)
		stepLabel:SetText("Done.")
		return
	end
	SearchCurrentEntry(entry)
end

local function HideTradeTargetDropdown()
	if tradeTargetDropdown ~= nil then
		tradeTargetDropdown:Show(false)
	end
end

local function SetTradeCommerceControlsVisible(visible)
	if not visible then
		StopCommerceHold()
	end
	if tradeCommerceLabel ~= nil then
		tradeCommerceLabel:Show(visible)
	end
	if tradeCommerceValueLabel ~= nil then
		tradeCommerceValueLabel:Show(visible)
	end
	if tradeCommerceMinusButton ~= nil then
		tradeCommerceMinusButton:Show(visible)
	end
	if tradeCommercePlusButton ~= nil then
		tradeCommercePlusButton:Show(visible)
	end
end

local function ChangeCommerceOverride(delta)
	local base = commerceOverride
	if base == nil then
		base = RefreshDetectedCommerceSkill()
	end
	commerceOverride = math.max(0, math.floor((tonumber(base) or 0) + delta))
	if mainWindow ~= nil and mainWindow:IsVisible() then
		RenderPlan()
	end
end

function StopCommerceHold()
	OmniCraftCommerceHoldDirection = 0
	OmniCraftCommerceHoldNextAt = 0
end

local function StartCommerceHold(direction)
	OmniCraftCommerceHoldDirection = direction
	OmniCraftCommerceHoldNextAt = os.clock() + 0.35
	ChangeCommerceOverride(direction * 1000)
end

local function UpdateTradeCommerceControl()
	if tradeCommerceLabel == nil then
		return
	end
	if tradePackInfo == nil then
		SetTradeCommerceControlsVisible(false)
		return
	end
	local detected = RefreshDetectedCommerceSkill()
	local used = commerceOverride or detected
	local suffix = commerceOverride ~= nil and " (manual)" or " (detected)"
	tradeCommerceValueLabel:SetText(
		FormatCommerce(used) .. suffix .. " | turn-in LP " .. tostring(GetTradePackTurnInLabor())
	)
	SetTradeCommerceControlsVisible(true)
end

local function CreateTradeTargetControl(parent)
	if tradeTargetButton ~= nil then
		return
	end
	tradeTargetButton = CreateButton(parent, "omniCraftTradeTarget", "To: -", 214, 80, 90, function()
		if tradeTargetDropdown ~= nil then
			tradeTargetDropdown:Show(not tradeTargetDropdown:IsVisible())
			if tradeTargetDropdown:IsVisible() and tradeTargetDropdown.Raise ~= nil then
				tradeTargetDropdown:Raise()
			end
		end
	end)
	tradeTargetButton:Show(false)

	tradeTargetDropdown = parent:CreateChildWidget("emptywidget", "omniCraftTradeTargetDropdown", 0, true)
	tradeTargetDropdown:SetExtent(136, 118)
	tradeTargetDropdown:AddAnchor("TOPLEFT", tradeTargetButton, "BOTTOMLEFT", 0, 1)
	tradeTargetDropdown:Show(false)
	local bg = tradeTargetDropdown:CreateDrawable("ui/common/default.dds", "editbox_df", "background")
	if bg == nil then
		bg = tradeTargetDropdown:CreateColorDrawable(0.78, 0.73, 0.58, 0.24, "background")
	end
	bg:AddAnchor("TOPLEFT", tradeTargetDropdown, 0, 0)
	bg:AddAnchor("BOTTOMRIGHT", tradeTargetDropdown, 0, 0)

	tradeTargetDropdown.rows = {}
	for index = 1, 6 do
		local row = tradeTargetDropdown:CreateChildWidget("label", "omniCraftTradeTargetRow" .. tostring(index), index, true)
		row:SetExtent(126, 18)
		row:AddAnchor("TOPLEFT", tradeTargetDropdown, 5, 4 + ((index - 1) * 19))
		row.style:SetAlign(ALIGN_LEFT)
		row.style:SetFontSize(12)
		SetTextColorByKey(row, "default")
		local rowBg = row:CreateColorDrawable(0.78, 0.73, 0.58, 0.18, "background")
		rowBg:AddAnchor("TOPLEFT", row, 0, 0)
		rowBg:AddAnchor("BOTTOMRIGHT", row, 0, 0)
		rowBg:SetVisible(false)
		row.rowBg = rowBg
		row:SetHandler("OnEnter", function(self)
			self.rowBg:SetVisible(true)
		end)
		row:SetHandler("OnLeave", function(self)
			self.rowBg:SetVisible(false)
		end)
		row:SetHandler("OnClick", function(self)
			if self.target == nil then
				return
			end
			selectedTradeTarget = self.target
			currentTradeRatio = nil
			tradeRatioRequestKey = nil
			tradeRatioPending = false
			tradeRatioDeferred = false
			HideTradeTargetDropdown()
			RequestTradeRatio()
			RenderPlan()
		end)
		row:Show(false)
		tradeTargetDropdown.rows[index] = row
	end

	tradeCommerceLabel = parent:CreateChildWidget("label", "omniCraftTradeCommerceLabel", 0, true)
	tradeCommerceLabel:SetExtent(92, 18)
	tradeCommerceLabel:AddAnchor("BOTTOMLEFT", parent, 18, -16)
	tradeCommerceLabel:SetText("Commerce:")
	StyleLabel(tradeCommerceLabel, 12, ALIGN_LEFT, "brown")

	tradeCommerceMinusButton = CreateSmallButton(parent, "omniCraftTradeCommerceMinus", "-", 102, 0, function() end)
	tradeCommerceMinusButton:RemoveAllAnchors()
	tradeCommerceMinusButton:AddAnchor("BOTTOMLEFT", parent, 102, -16)
	tradeCommerceMinusButton:SetHandler("OnMouseDown", function()
		StartCommerceHold(-1)
	end)
	tradeCommerceMinusButton:SetHandler("OnMouseUp", StopCommerceHold)
	tradeCommerceMinusButton:SetHandler("OnLeave", StopCommerceHold)

	tradeCommerceValueLabel = parent:CreateChildWidget("label", "omniCraftTradeCommerceValue", 0, true)
	tradeCommerceValueLabel:SetExtent(230, 18)
	tradeCommerceValueLabel:AddAnchor("BOTTOMLEFT", parent, 126, -16)
	StyleLabel(tradeCommerceValueLabel, 12, ALIGN_LEFT, "default")

	tradeCommercePlusButton = CreateSmallButton(parent, "omniCraftTradeCommercePlus", "+", 360, 0, function() end)
	tradeCommercePlusButton:RemoveAllAnchors()
	tradeCommercePlusButton:AddAnchor("BOTTOMLEFT", parent, 360, -16)
	tradeCommercePlusButton:SetHandler("OnMouseDown", function()
		StartCommerceHold(1)
	end)
	tradeCommercePlusButton:SetHandler("OnMouseUp", StopCommerceHold)
	tradeCommercePlusButton:SetHandler("OnLeave", StopCommerceHold)

	SetTradeCommerceControlsVisible(false)
end

UpdateTradeTargetControl = function()
	if tradeTargetButton == nil then
		return
	end
	if tradePackInfo == nil then
		tradeTargetButton:Show(false)
		UpdateTradeCommerceControl()
		HideTradeTargetDropdown()
		return
	end
	UpdateTradeCommerceControl()
	local text = selectedTradeTarget and selectedTradeTarget.name or "-"
	tradeTargetButton:SetText("To: " .. text)
	tradeTargetButton:Show(true)
	local targets = GetAllowedTradeTargets(tradePackInfo)
	for index = 1, 6 do
		local row = tradeTargetDropdown.rows[index]
		local target = targets[index]
		if row ~= nil and target ~= nil then
			row.target = target
			row:SetText(target.fullName or target.name)
			row:Show(true)
			if selectedTradeTarget ~= nil and selectedTradeTarget.zone == target.zone then
				row.style:SetColor(0.04, 0.50, 0.08, 1)
			else
				SetTextColorByKey(row, "default")
			end
		elseif row ~= nil then
			row.target = nil
			row:SetText("")
			row:Show(false)
		end
	end
end

local function CreateMainWindow()
	if mainWindow ~= nil then
		if craftLabel ~= nil then
			return
		end
		mainWindow = nil
	end

	mainWindow = CreateEmptyWindow("omniCraftWindow", "UIParent")
	mainWindow:SetExtent(WINDOW_WIDTH, MIN_WINDOW_HEIGHT)
	mainWindow:AddAnchor("CENTER", "UIParent", 0, 0)
	mainWindow:SetCloseOnEscape(true)
	mainWindow:EnableDrag(true)
	mainWindow:Show(false)

	CreateWindowBackground(mainWindow)
	CreateQuestStylePanel(mainWindow, "omniCraftBodyPanel", 105, -25, 0.20)
	--CreateQuestStyleStrip(mainWindow, "omniCraftSummaryPanel", 18, 146, WINDOW_WIDTH - 36, 68, 0.13)

	mainWindow:SetHandler("OnDragStart", function(self)
		self:StartMoving()
		return true
	end)
	mainWindow:SetHandler("OnDragStop", function(self)
		self:StopMovingOrSizing()
	end)
	mainWindow:SetHandler("OnWheelUp", function()
		ScrollBreakdown(-1)
	end)
	mainWindow:SetHandler("OnWheelDown", function()
		ScrollBreakdown(1)
	end)

	local title = mainWindow:CreateChildWidget("label", "omniCraftTitle", 0, true)
	title:SetExtent(220, 24)
	title:AddAnchor("TOPLEFT", mainWindow, 18, 14)
	title:SetText("OmniCraft")
	StyleLabel(title, 18, ALIGN_LEFT, "brown")

	CreateCloseButton(mainWindow, "omniCraftClose", function()
		if recipePreviewDropdown ~= nil then
			recipePreviewDropdown:HidePreview()
		end
		mainWindow:Show(false)
	end)

	local recipeLabel = mainWindow:CreateChildWidget("label", "omniCraftRecipeLabel", 0, true)
	recipeLabel:SetExtent(80, 22)
	recipeLabel:AddAnchor("TOPLEFT", mainWindow, 18, 48)
	recipeLabel:SetText("Craft")
	StyleLabel(recipeLabel, 13, ALIGN_LEFT, "brown")

	recipeEdit = CreateEditBox(mainWindow, "omniCraftRecipeEdit", 286)
	recipeEdit:AddAnchor("TOPLEFT", mainWindow, 88, 45)
	recipeEdit:SetGuideText("Type craft name or id")
	recipeEdit:SetHandler("OnEnterPressed", LoadRecipeFromInput)
	recipeEdit:SetHandler("OnTextChanged", function()
		if recipePreviewDropdown ~= nil then
			recipePreviewDropdown:Update(recipeEdit:GetText())
		end
	end)
	recipePreviewDropdown = CreateRecipePreviewDropdown(mainWindow, recipeEdit, 286)

	CreateButton(mainWindow, "omniCraftLoad", "Load", 398, 46, 48, LoadRecipeFromInput)
	CreateButton(mainWindow, "omniCraftCheckPrices", "Check Prices", 454, 46, 88, StartPriceCheck)

	local countLabel = mainWindow:CreateChildWidget("label", "omniCraftCountLabel", 0, true)
	countLabel:SetExtent(52, 22)
	countLabel:AddAnchor("TOPLEFT", mainWindow, 18, 82)
	countLabel:SetText("Crafts")
	StyleLabel(countLabel, 13, ALIGN_LEFT, "brown")

	countEdit = CreateEditBox(mainWindow, "omniCraftCountEdit", 60)
	countEdit:AddAnchor("TOPLEFT", mainWindow, 88, 79)
	countEdit:SetText("1")
	countEdit:SetHandler("OnEnterPressed", ApplyCount)
	countEdit:SetHandler("OnEditFocusLost", ApplyCount)

	CreateSmallButton(mainWindow, "omniCraftMinus", "-", 160, 80, function()
		countEdit:SetText(tostring(math.max(1, craftCount - 1)))
		ApplyCount()
	end)
	CreateSmallButton(mainWindow, "omniCraftPlus", "+", 184, 80, function()
		countEdit:SetText(tostring(craftCount + 1))
		ApplyCount()
	end)
	CreateTradeTargetControl(mainWindow)
	CreateButton(mainWindow, "omniCraftBuyTotal", "Buy Total", 312, 80, 84, ShowBuyTotalWindow)
	CreateButton(mainWindow, "omniCraftGoBuy", "Go to Buy", 404, 80, 76, StartShopping)
	CreateButton(mainWindow, "omniCraftNext", "Next", 488, 80, 54, NextShoppingStep)

	CreateSectionLine(mainWindow, "controls", 106)

	statusLabel = mainWindow:CreateChildWidget("label", "omniCraftStatus", 0, true)
	statusLabel:SetExtent(WINDOW_WIDTH - 36, 22)
	statusLabel:AddAnchor("TOPLEFT", mainWindow, 18, 114)
	StyleLabel(statusLabel, 13, ALIGN_LEFT, "default")
	--statusLabel:SetText("Load a craft to start.")

	targetLabel = mainWindow:CreateChildWidget("label", "omniCraftTarget", 0, true)
	targetLabel:SetExtent(WINDOW_WIDTH - 36, 22)
	targetLabel:AddAnchor("TOPLEFT", mainWindow, 18, 114)
	StyleLabel(targetLabel, 13, ALIGN_LEFT, "brown")

	craftLabel = mainWindow:CreateChildWidget("label", "omniCraftCrafts", 0, true)
	craftLabel:SetExtent(WINDOW_WIDTH - 36, 22)
	craftLabel:AddAnchor("TOPLEFT", mainWindow, 18, 134)
	StyleLabel(craftLabel, 13, ALIGN_LEFT, "default")
	craftFeeMoney = CreateMoneyCluster(mainWindow, "omniCraftCraftFeeMoney")

	economyLabel = mainWindow:CreateChildWidget("label", "omniCraftEconomy", 0, true)
	economyLabel:SetExtent(WINDOW_WIDTH - 36, 22)
	economyLabel:AddAnchor("TOPLEFT", mainWindow, 18, 154)
	StyleLabel(economyLabel, 13, ALIGN_LEFT, "default")
	economyMoney = {
		outrightText = CreateMoneyText(mainWindow, "omniCraftOutrightText", "Outright", 18, CRAFTLABELHEIGHT1, 62),
		pieceText = CreateMoneyText(mainWindow, "omniCraftPieceText", "| Piece", 250, CRAFTLABELHEIGHT1, 48),
		diffText = CreateMoneyText(mainWindow, "omniCraftDiffText", "Diff", 18, CRAFTLABELHEIGHT2, 34),
		laborText = CreateMoneyText(mainWindow, "omniCraftLaborText", "|", 264, CRAFTLABELHEIGHT2, 10),
		perLaborText = CreateMoneyText(mainWindow, "omniCraftPerLaborText", "/labor", 360, CRAFTLABELHEIGHT2, 40),
		totalOutrightText = CreateMoneyText(mainWindow, "omniCraftTotalOutrightText", "", 18, CRAFTLABELHEIGHT3, 92),
		totalPieceText = CreateMoneyText(mainWindow, "omniCraftTotalPieceText", "", 250, CRAFTLABELHEIGHT3, 78),
		outright = CreateMoneyCluster(mainWindow, "omniCraftOutrightMoney"),
		piece = CreateMoneyCluster(mainWindow, "omniCraftPieceMoney"),
		diff = CreateMoneyCluster(mainWindow, "omniCraftDiffMoney"),
		perLabor = CreateMoneyCluster(mainWindow, "omniCraftPerLaborMoney"),
		totalOutright = CreateMoneyCluster(mainWindow, "omniCraftTotalOutrightMoney"),
		totalPiece = CreateMoneyCluster(mainWindow, "omniCraftTotalPieceMoney"),
	}
	economyMoney.labels = {
		economyMoney.outrightText,
		economyMoney.pieceText,
		economyMoney.diffText,
		economyMoney.laborText,
		economyMoney.perLaborText,
		economyMoney.totalOutrightText,
		economyMoney.totalPieceText,
	}
	economyMoney.clusters = {
		economyMoney.outright,
		economyMoney.piece,
		economyMoney.diff,
		economyMoney.perLabor,
		economyMoney.totalOutright,
		economyMoney.totalPiece,
	}

	CreateSectionLine(mainWindow, "summary", 246)

	shoppingLabel = mainWindow:CreateChildWidget("label", "omniCraftShopping", 0, true)
	shoppingLabel:SetExtent(270, 22)
	shoppingLabel:AddAnchor("BOTTOMLEFT", mainWindow, 18, -36)
	StyleLabel(shoppingLabel, 13, ALIGN_LEFT, "default")

	stepLabel = mainWindow:CreateChildWidget("label", "omniCraftStep", 0, true)
	stepLabel:SetExtent(250, 22)
	stepLabel:AddAnchor("BOTTOMRIGHT", mainWindow, -18, -36)
	StyleLabel(stepLabel, 13, ALIGN_RIGHT, "default")

	local tableHeaderY = ROW_TOP - 18
	local breakdownHeader = mainWindow:CreateChildWidget("label", "omniCraftBreakdownHeader", 0, true)
	breakdownHeader:SetExtent(240, 18)
	breakdownHeader:AddAnchor("TOPLEFT", mainWindow, 20, tableHeaderY)
	breakdownHeader:SetText("Breakdown")
	StyleLabel(breakdownHeader, 12, ALIGN_LEFT, "brown")

	local qtyHeader = mainWindow:CreateChildWidget("label", "omniCraftQtyHeader", 0, true)
	qtyHeader:SetExtent(60, 18)
	qtyHeader:AddAnchor("TOPLEFT", mainWindow, 20 + ROW_NAME_WIDTH + 10, tableHeaderY)
	qtyHeader:SetText("Qty")
	StyleLabel(qtyHeader, 12, ALIGN_LEFT, "brown")

	local unitHeader = mainWindow:CreateChildWidget("label", "omniCraftUnitHeader", 0, true)
	unitHeader:SetExtent(90, 18)
	unitHeader:AddAnchor("TOPLEFT", mainWindow, ROW_UNIT_RIGHT - 70, tableHeaderY)
	unitHeader:SetText("Unit Price")
	StyleLabel(unitHeader, 12, ALIGN_LEFT, "brown")

	local totalHeader = mainWindow:CreateChildWidget("label", "omniCraftTotalHeader", 0, true)
	totalHeader:SetExtent(90, 18)
	totalHeader:AddAnchor("TOPLEFT", mainWindow, ROW_TOTAL_RIGHT - 70, tableHeaderY)
	totalHeader:SetText("Total Price")
	StyleLabel(totalHeader, 12, ALIGN_LEFT, "brown")

	for index = 1, MAX_ROW_COUNT do
		local y = ROW_TOP + ((index - 1) * ROW_HEIGHT)
		local line = mainWindow:CreateDrawable("ui/common/default.dds", "line_01", "artwork")
		if line ~= nil and line.SetTextureColor ~= nil then
			line:SetTextureColor("default")
		end
		if line == nil or line.SetExtent == nil or line.AddAnchor == nil then
			line = mainWindow:CreateColorDrawable(0.42, 0.42, 0.42, 0.24, "artwork")
		end
		line:SetExtent(WINDOW_WIDTH - 40, 1)
		line:AddAnchor("TOPLEFT", mainWindow, 20, y + math.floor(ROW_HEIGHT / 2))
		line:SetVisible(false)

		local left = mainWindow:CreateChildWidget("label", "omniCraftRowLeft" .. tostring(index), index, true)
		left:SetExtent(ROW_NAME_WIDTH, 22)
		left:AddAnchor("TOPLEFT", mainWindow, 20, y)
		StyleLabel(left, 12, ALIGN_LEFT, "default")
		left:SetHandler("OnWheelUp", function()
			ScrollBreakdown(-1)
		end)
		left:SetHandler("OnWheelDown", function()
			ScrollBreakdown(1)
		end)

		local mid = mainWindow:CreateChildWidget("label", "omniCraftRowMid" .. tostring(index), index, true)
		mid:SetExtent(ROW_QTY_WIDTH, 22)
		mid:AddAnchor("TOPLEFT", mainWindow, 20 + ROW_NAME_WIDTH + 10, y)
		StyleLabel(mid, 12, ALIGN_LEFT, "default")
		mid:SetHandler("OnWheelUp", function()
			ScrollBreakdown(-1)
		end)
		mid:SetHandler("OnWheelDown", function()
			ScrollBreakdown(1)
		end)

		rows[index] = {
			left = left,
			mid = mid,
			unit = CreateMoneyCluster(mainWindow, "omniCraftRowUnitPrice" .. tostring(index)),
			total = CreateMoneyCluster(mainWindow, "omniCraftRowTotalPrice" .. tostring(index)),
			line = line,
			y = y + 3,
		}
	end

	RenderPlan()
	--DONT LOAD FOR NOW ITS KINDA ANNOYING TBH LOL
	--local saved = ADDON:LoadData(SAVE_KEY)
	--if type(saved) == "table" then
	--	if saved.recipe ~= nil then
	--		recipeEdit:SetText(tostring(saved.recipe))
	--	end
	--	if saved.count ~= nil then
	--		countEdit:SetText(tostring(saved.count))
	--		ApplyCount()
	--	end
	--end
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

launcherButton = CreateSimpleButton("OmniCraft", 700, -430)
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
				if mainWindow ~= nil and mainWindow:IsVisible() then
					RenderPlan()
				end
			else
				DebugBad("no exact auction price for " .. tostring(currentPriceRequest.item))
			end
		else
			DebugBad("no auction listings for " .. tostring(currentPriceRequest.item))
		end
		currentPriceRequest = nil
		if #priceCheckQueue == 0 then
			priceCheckBusy = false
			UpdateEconomyLabel()
			if mainWindow ~= nil and mainWindow:IsVisible() then
				RenderPlan()
			end
		end
		return
	end
end

local function OnSpecialtyRatioBetweenInfo(ratioTable)
	if tradeRatioPending ~= true then
		return
	end
	tradeRatioPending = false
	if tradePackInfo == nil or selectedTradeTarget == nil or type(ratioTable) ~= "table" then
		return
	end
	local expectedKey = GetTradeRatioKey(tradePackInfo, selectedTradeTarget)
	for _, data in pairs(ratioTable) do
		local itemInfo = type(data) == "table" and data.itemInfo or nil
		local name = type(itemInfo) == "table" and itemInfo.name or nil
		if name ~= nil and SameItemName(name, tradePackInfo.name) then
			currentTradeRatio = tonumber(data.ratio)
			tradeRatioRequestKey = expectedKey
			if mainWindow ~= nil and mainWindow:IsVisible() then
				RenderPlan()
			end
			return
		end
	end
	currentTradeRatio = nil
	tradeRatioRequestKey = expectedKey
	if mainWindow ~= nil and mainWindow:IsVisible() then
		RenderPlan()
	end
end

pcall(function()
	UIParent:SetEventHandler(UIEVENT_TYPE.BAG_UPDATE, OnBagChanged)
	UIParent:SetEventHandler(UIEVENT_TYPE.AUCTION_ITEM_SEARCHED, OnAuctionSearched)
	UIParent:SetEventHandler(UIEVENT_TYPE.SPECIALTY_RATIO_BETWEEN_INFO, OnSpecialtyRatioBetweenInfo)
end)

local function OnPriceTick()
	if OmniCraftCommerceHoldDirection ~= 0 and os.clock() >= OmniCraftCommerceHoldNextAt then
		ChangeCommerceOverride(OmniCraftCommerceHoldDirection * 1000)
		OmniCraftCommerceHoldNextAt = os.clock() + 0.08
	end
	if tradeRatioDeferred
		and not tradeRatioPending
		and tradeRatioStart > 0
		and (os.time() - tradeRatioStart) >= tradeRatioCooldown
	then
		tradeRatioDeferred = false
		RequestTradeRatio(true)
	end
	if priceCheckBusy
		and currentPriceRequest ~= nil
		and (os.time() - priceCheckStart) >= priceCheckTimeout
	then
		DebugBad("auction price request timed out: " .. tostring(currentPriceRequest.item))
		currentPriceRequest = nil
		if #priceCheckQueue == 0 then
			priceCheckBusy = false
			UpdateEconomyLabel()
			if mainWindow ~= nil and mainWindow:IsVisible() then
				RenderPlan()
			end
		end
	end
	if priceCheckBusy
		and currentPriceRequest == nil
		and #priceCheckQueue > 0
		and (os.time() - priceCheckStart) >= priceCheckCD
	then
		SearchNextPrice()
	end
end

priceTicker = CreateEmptyWindow("omniCraftPriceTicker", "UIParent")
priceTicker:Show(true)
priceTicker:SetHandler("OnUpdate", OnPriceTick)

local eventWindow = CreateEmptyWindow("omniCraftEvents", "UIParent")
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

--Chat("Loaded. Click OmniCraft to plan a craft.")
