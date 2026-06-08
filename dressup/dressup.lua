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
---------------- Thanks to Michaelqt --------------------
ADDON:ImportObject(OBJECT_TYPE.TEXT_STYLE)
ADDON:ImportObject(OBJECT_TYPE.BUTTON)
ADDON:ImportObject(OBJECT_TYPE.DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.NINE_PART_DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.COLOR_DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.WINDOW)
ADDON:ImportObject(OBJECT_TYPE.LABEL)
ADDON:ImportObject(OBJECT_TYPE.ICON_DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.IMAGE_DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.EDITBOX)
ADDON:ImportObject(OBJECT_TYPE.EDITBOX_MULTILINE)
ADDON:ImportObject(OBJECT_TYPE.X2_EDITBOX)
ADDON:ImportObject(OBJECT_TYPE.MODEL_VIEW)

ADDON:ImportAPI(API_TYPE.CHAT.id)
ADDON:ImportAPI(API_TYPE.UNIT.id)
ADDON:ImportAPI(API_TYPE.ITEM.id)
ADDON:ImportAPI(API_TYPE.EQUIPMENT.id)

local dressUpWindow = CreateEmptyWindow("dressUpWindow", "UIParent")
dressUpWindow:AddAnchor("RIGHT", -1000, 0)
local turnLeft = false
local turnRight = false
local zoomOutBool = false
local zoomInBool = false
local fov = 30
local RELAX_ANIMATION_NAME = "fist_ba_relaxed_rand_idle"

local color = {}
color.normal = UIParent:GetFontColor("btn_df")
color.highlight = UIParent:GetFontColor("btn_ov")
color.pushed = UIParent:GetFontColor("btn_on")
color.disabled = UIParent:GetFontColor("btn_dis")

local buttonskin = {
	drawableType = "ninePart",
	path = "ui/common/default.dds",
	coordsKey = "btn",
	autoResize = true,
	fontColor = color,
	fontInset = {
		left = 11,
		right = 11,
		top = 0,
		bottom = 0,
	},
}
function dressUpWindow:OnUpdate(dt)
	local modelViewer = dressUpWindow.modelViewer
	if turnLeft == true then
		modelViewer:AddRotation(200 * dt / 1000)
	elseif turnRight == true then
		modelViewer:AddRotation(-200 * dt / 1000)
	elseif zoomInBool == true then
		modelViewer:SetFov(fov)
		fov = fov - 0.3
	elseif zoomOutBool == true then
		modelViewer:SetFov(fov)
		fov = fov + 0.3
	end
end

local controlBarYOffset = 0
local modelViewer = nil
modelViewer = dressUpWindow:CreateChildWidget("modelview", "modelViewer", 0, true)
local background = modelViewer:CreateColorDrawable(0, 0, 0, 0.1, "background")
background:AddAnchor("TOPLEFT", modelViewer, 0, 0)
background:AddAnchor("BOTTOMRIGHT", modelViewer, 0, 0)

local function CreateButton(parent, name, anchor, xOffset, yOffset, text, onMouseDown, onMouseUp, onLeave, onClick)
	local button = parent:CreateChildWidget("button", name, 0, true)
	button:AddAnchor(anchor, parent, xOffset, yOffset)
	button:SetStyle("text_default")
	--A-pplyButtonSkin(button, buttonskin)
	button:SetExtent(35, 35)
	button:SetText(text)
	button:SetWidth(35)
	if onMouseDown then
		function button:OnMouseDown(arg)
			onMouseDown()
		end
		button:SetHandler("OnMouseDown", button.OnMouseDown)
	end
	if onMouseUp then
		function button:OnMouseUp(arg)
			onMouseUp()
		end
		button:SetHandler("OnMouseUp", button.OnMouseUp)
	end
	if onLeave then
		function button:OnLeave(arg)
			onLeave()
		end
		button:SetHandler("OnLeave", button.OnLeave)
	end
	if onClick then
		function button:OnClick(arg)
			onClick()
		end
		button:SetHandler("OnClick", button.OnClick)
	end
	return button
end

local showCostume = false

local function TrimText(text)
	return tostring(text or ""):match("^%s*(.-)%s*$") or ""
end

local function LowerText(text)
	return string.lower(tostring(text or ""))
end

local function EquipBaseItem(itemId)
	if itemId == nil then
		return
	end

	dressUpWindow:Show(true)
	modelViewer:Init("player", true)
	modelViewer:EquipItem(tonumber(itemId))
	modelViewer:PlayAnimation(RELAX_ANIMATION_NAME, true)
end

local itemBrowserWindow = nil
local itemBrowserRows = {}
local itemBrowserData = {}
local itemBrowserFiltered = {}
local itemBrowserLoaded = {}
local itemBrowserCategory = "armors"
local itemBrowserSearchText = ""
local itemBrowserSortKey = "name"
local itemBrowserSortAsc = true
local itemBrowserPage = 1
local itemBrowserVisible = false
local ITEM_BROWSER_ROWS = 11
local ITEM_BROWSER_FILES = {
	armors = "armors.txt",
	weapons = "weapons.txt",
	costumes = "costumes.txt",
}

local function ApplyDressupLabelStyle(label, fontSize, align, r, g, b)
	if label == nil or label.style == nil then
		return
	end

	label.style:SetAlign(align or ALIGN_LEFT)
	label.style:SetColor(r or 1, g or 1, b or 1, 1)
	label.style:SetFontSize(fontSize or 12)
end

local function SetWidgetTextColorByKey(widget, colorKey)
	if widget == nil or colorKey == nil or widget.style == nil or widget.style.SetColorByKey == nil then
		return
	end

	widget.style:SetColorByKey(colorKey)
end

local function CreateWindowBackground(window)
	local bg = window:CreateDrawable("ui/common/default.dds", "main_bg", "background")
	bg:AddAnchor("TOPLEFT", window, -5, -5)
	bg:AddAnchor("BOTTOMRIGHT", window, 5, 5)
	return bg
end

local function CreateCloseButton(parent, id, onClick)
	local button = parent:CreateChildWidget("button", id, 0, true)
	button:AddAnchor("TOPRIGHT", parent, 3, -3)
	button:SetStyle("btn_close_default")
	button:SetHandler("OnClick", onClick)
	return button
end

local function ApplyDressupButtonStyle(button)
	if button == nil then
		return
	end

	button:SetStyle("text_default")
	if button.SetAutoResize ~= nil then
		button:SetAutoResize(false)
	end
	if button.style ~= nil and button.style.SetAlign ~= nil then
		button.style:SetAlign(ALIGN_CENTER)
	end
end

local function CreateDressupEditBox(parent, id, width)
	local edit = parent:CreateChildWidgetByType(UOT_X2_EDITBOX, id, 0, true)
	edit:SetHeight(26)
	edit:SetWidth(width)
	edit:SetInset(5, 5, 5, 5)
	edit:EnableFocus(true)
	edit:UseSelectAllWhenFocused(true)
	edit.style:SetAlign(ALIGN_LEFT)
	edit.style:SetColorByKey("title")

	local bg = edit:CreateDrawable("ui/common/default.dds", "editbox_df", "background")
	if bg ~= nil then
		bg:AddAnchor("TOPLEFT", edit, 0, 0)
		bg:AddAnchor("BOTTOMRIGHT", edit, 0, 0)
	end
	return edit
end

local function SetDrawableVisible(drawable, visible)
	if drawable ~= nil and drawable.SetVisible ~= nil then
		drawable:SetVisible(visible)
	end
end

local function ToClientIconPath(iconPath)
	local path = tostring(iconPath or ""):gsub("%.png$", "")
	return path:gsub("^icons/", "ui/icon/")
end

local function ReadItemBrowserFile(category)
	if itemBrowserLoaded[category] == true then
		return itemBrowserData[category] or {}
	end

	local data = {}
	local filename = ITEM_BROWSER_FILES[category]
	local paths = {
		"dressup/resources/" .. filename,
		"resources/" .. filename,
		"../Documents/Addon/dressup/resources/" .. filename,
	}
	local file = nil
	for i = 1, #paths do
		file = io.open(paths[i], "r")
		if file ~= nil then
			break
		end
	end

	if file == nil then
		X2Chat:DispatchChatMessage(CMF_SYSTEM, "Dressup: could not open resources/" .. filename)
		itemBrowserData[category] = data
		itemBrowserLoaded[category] = true
		return data
	end

	for line in file:lines() do
		local itemId, name, icon, itemCategory = line:match("^([^;]*);([^;]*);([^;]*);(.*)$")
		if itemId ~= nil and itemId ~= "" then
			data[#data + 1] = {
				id = tonumber(itemId) or 0,
				name = name or "",
				icon = icon or "",
				category = itemCategory or "",
				search = LowerText((itemId or "") .. " " .. (name or "") .. " " .. (itemCategory or "")),
			}
		end
	end
	file:close()

	itemBrowserData[category] = data
	itemBrowserLoaded[category] = true
	return data
end

local function SortItemBrowserData(data)
	table.sort(data, function(a, b)
		local av = a[itemBrowserSortKey] or ""
		local bv = b[itemBrowserSortKey] or ""
		if itemBrowserSortKey == "id" then
			av = tonumber(av) or 0
			bv = tonumber(bv) or 0
		else
			av = LowerText(av)
			bv = LowerText(bv)
		end
		if av == bv then
			return (a.id or 0) < (b.id or 0)
		end
		if itemBrowserSortAsc then
			return av < bv
		end
		return av > bv
	end)
end

local function RefreshItemBrowser()
	if itemBrowserWindow == nil then
		return
	end

	local source = ReadItemBrowserFile(itemBrowserCategory)
	local query = LowerText(TrimText(itemBrowserSearchText))
	itemBrowserFiltered = {}
	for i = 1, #source do
		local item = source[i]
		if item.category ~= "Synthesis Materials" and (query == "" or string.find(item.search, query, 1, true) ~= nil) then
			itemBrowserFiltered[#itemBrowserFiltered + 1] = item
		end
	end
	SortItemBrowserData(itemBrowserFiltered)

	local maxPage = math.max(1, math.ceil(#itemBrowserFiltered / ITEM_BROWSER_ROWS))
	if itemBrowserPage > maxPage then
		itemBrowserPage = maxPage
	end
	if itemBrowserPage < 1 then
		itemBrowserPage = 1
	end

	for rowIndex = 1, ITEM_BROWSER_ROWS do
		local row = itemBrowserRows[rowIndex]
		local item = itemBrowserFiltered[((itemBrowserPage - 1) * ITEM_BROWSER_ROWS) + rowIndex]
		row.item = item
		if item ~= nil then
			row.button:Show(true)
			row.nameLabel:Show(true)
			row.categoryLabel:Show(true)
			row.idLabel:Show(true)
			SetDrawableVisible(row.iconBg, true)
			SetDrawableVisible(row.icon, true)
			row.nameLabel:SetText(item.name)
			row.categoryLabel:SetText(item.category)
			row.idLabel:SetText(tostring(item.id))
			if item.icon ~= "" and row.icon.SetTexture ~= nil then
				pcall(function()
					row.icon:SetTexture(ToClientIconPath(item.icon))
					if row.icon.SetCoords ~= nil then
						row.icon:SetCoords(0, 0, 32, 32)
					end
				end)
			end
		else
			row.button:Show(false)
			row.nameLabel:Show(false)
			row.categoryLabel:Show(false)
			row.idLabel:Show(false)
			SetDrawableVisible(row.iconBg, false)
			SetDrawableVisible(row.icon, false)
		end
	end

	itemBrowserWindow.pageLabel:SetText(string.format("%d/%d  %d items", itemBrowserPage, maxPage, #itemBrowserFiltered))
	itemBrowserWindow.sortLabel:SetText(
		string.format("Sort: %s %s", itemBrowserSortKey, itemBrowserSortAsc and "asc" or "desc")
	)
end

local function SetItemBrowserCategory(category)
	itemBrowserCategory = category
	itemBrowserPage = 1
	RefreshItemBrowser()
end

local function SetItemBrowserSort(sortKey)
	if itemBrowserSortKey == sortKey then
		itemBrowserSortAsc = not itemBrowserSortAsc
	else
		itemBrowserSortKey = sortKey
		itemBrowserSortAsc = true
	end
	itemBrowserPage = 1
	RefreshItemBrowser()
end

local function CreateItemBrowserWindow()
	if itemBrowserWindow ~= nil then
		return itemBrowserWindow
	end

	itemBrowserWindow = CreateEmptyWindow("dressupItemBrowserWindow", "UIParent")
	itemBrowserWindow:AddAnchor("CENTER", "UIParent", 0, 0)
	itemBrowserWindow:SetExtent(590, 480)
	itemBrowserWindow:EnableDrag(true)
	itemBrowserWindow:Clickable(true)
	itemBrowserWindow:SetCloseOnEscape(true)
	itemBrowserWindow:Show(false)

	local bg = CreateWindowBackground(itemBrowserWindow)

	local title = itemBrowserWindow:CreateChildWidget("label", "dressupItemBrowserTitle", 0, true)
	title:AddAnchor("TOPLEFT", itemBrowserWindow, 16, 12)
	title:SetExtent(260, 24)
	title:SetText("Dressup Items")
	ApplyDressupLabelStyle(title, 16, ALIGN_LEFT, 1, 0.95, 0.78)
	SetWidgetTextColorByKey(title, "brown")

	CreateCloseButton(itemBrowserWindow, "dressupItemBrowserClose", function()
		itemBrowserVisible = false
		itemBrowserWindow:Show(false)
	end)

	local searchEdit = CreateDressupEditBox(itemBrowserWindow, "dressupItemBrowserSearch", 390)
	searchEdit:AddAnchor("TOPLEFT", itemBrowserWindow, 16, 46)
	searchEdit:SetGuideText("Search name, id, category")
	itemBrowserWindow.searchEdit = searchEdit

	local function updateSearch()
		itemBrowserSearchText = searchEdit:GetText()
		itemBrowserPage = 1
		RefreshItemBrowser()
	end
	searchEdit:SetHandler("OnTextChanged", updateSearch)
	searchEdit:SetHandler("OnEnterPressed", updateSearch)

	local clearButton = itemBrowserWindow:CreateChildWidget("button", "dressupItemBrowserClearButton", 0, true)
	clearButton:AddAnchor("TOPLEFT", itemBrowserWindow, 416, 45)
	clearButton:SetExtent(76, 28)
	clearButton:SetWidth(76)
	clearButton:SetText("Clear")
	ApplyDressupButtonStyle(clearButton)
	clearButton:SetHandler("OnClick", function()
		searchEdit:SetText("")
		itemBrowserSearchText = ""
		itemBrowserPage = 1
		RefreshItemBrowser()
	end)

	local function createTopButton(name, text, x, width, onClick)
		local button = itemBrowserWindow:CreateChildWidget("button", name, 0, true)
		button:AddAnchor("TOPLEFT", itemBrowserWindow, x, 82)
		button:SetExtent(width, 28)
		button:SetWidth(width)
		button:SetText(text)
		ApplyDressupButtonStyle(button)
		button:SetHandler("OnClick", onClick)
		return button
	end

	createTopButton("dressupBrowserArmors", "Armor", 16, 86, function()
		SetItemBrowserCategory("armors")
	end)
	createTopButton("dressupBrowserWeapons", "Weapons", 110, 86, function()
		SetItemBrowserCategory("weapons")
	end)
	createTopButton("dressupBrowserCostumes", "Costumes", 204, 86, function()
		SetItemBrowserCategory("costumes")
	end)
	createTopButton("dressupBrowserSortName", "Sort Name", 298, 86, function()
		SetItemBrowserSort("name")
	end)
	createTopButton("dressupBrowserSortCategory", "Sort Cat", 392, 86, function()
		SetItemBrowserSort("category")
	end)
	createTopButton("dressupBrowserSortId", "Sort ID", 486, 88, function()
		SetItemBrowserSort("id")
	end)

	itemBrowserWindow.sortLabel = itemBrowserWindow:CreateChildWidget("label", "dressupItemBrowserSortLabel", 0, true)
	itemBrowserWindow.sortLabel:AddAnchor("TOPLEFT", itemBrowserWindow, 16, 116)
	itemBrowserWindow.sortLabel:SetExtent(260, 18)
	ApplyDressupLabelStyle(itemBrowserWindow.sortLabel, 11, ALIGN_LEFT, 0.80, 0.80, 0.80)
	SetWidgetTextColorByKey(itemBrowserWindow.sortLabel, "default")

	local header = itemBrowserWindow:CreateChildWidget("label", "dressupItemBrowserHeader", 0, true)
	header:AddAnchor("TOPLEFT", itemBrowserWindow, 58, 138)
	header:SetExtent(500, 18)
	header:SetText("Name                                                Category")
	ApplyDressupLabelStyle(header, 12, ALIGN_LEFT, 0.95, 0.90, 0.70)
	SetWidgetTextColorByKey(header, "brown")

	for rowIndex = 1, ITEM_BROWSER_ROWS do
		local y = 160 + ((rowIndex - 1) * 24)
		local row = {}
		row.bg = itemBrowserWindow:CreateColorDrawable(0.45, 0.33, 0.16, rowIndex % 2 == 0 and 0.12 or 0.07, "background")
		row.bg:AddAnchor("TOPLEFT", itemBrowserWindow, 16, y)
		row.bg:SetExtent(558, 22)

		row.button = itemBrowserWindow:CreateChildWidget("label", "dressupItemBrowserRowButton" .. rowIndex, rowIndex, true)
		row.button:AddAnchor("TOPLEFT", itemBrowserWindow, 16, y)
		row.button:SetExtent(558, 22)
		row.button:SetText("")
		row.button:EnablePick(true)
		row.button:SetHandler("OnClick", function()
			if row.item ~= nil then
				EquipBaseItem(row.item.id)
			end
		end)

		row.iconBg = itemBrowserWindow:CreateColorDrawable(0, 0, 0, 0.45, "overlay")
		row.iconBg:AddAnchor("TOPLEFT", itemBrowserWindow, 20, y + 2)
		row.iconBg:SetExtent(18, 18)

		row.icon = itemBrowserWindow:CreateImageDrawable("icons/icon_unknown_item.dds", "overlay")
		row.icon:AddAnchor("TOPLEFT", itemBrowserWindow, 21, y + 3)
		row.icon:SetExtent(16, 16)

		row.nameLabel = itemBrowserWindow:CreateChildWidget("label", "dressupItemBrowserName" .. rowIndex, rowIndex, true)
		row.nameLabel:AddAnchor("TOPLEFT", itemBrowserWindow, 44, y + 3)
		row.nameLabel:SetExtent(300, 18)
		row.nameLabel:EnablePick(false)
		ApplyDressupLabelStyle(row.nameLabel, 12, ALIGN_LEFT, 1, 1, 1)
		SetWidgetTextColorByKey(row.nameLabel, "default")

		row.categoryLabel = itemBrowserWindow:CreateChildWidget("label", "dressupItemBrowserCategory" .. rowIndex, rowIndex, true)
		row.categoryLabel:AddAnchor("TOPLEFT", itemBrowserWindow, 354, y + 3)
		row.categoryLabel:SetExtent(130, 18)
		row.categoryLabel:EnablePick(false)
		ApplyDressupLabelStyle(row.categoryLabel, 12, ALIGN_LEFT, 0.82, 0.90, 1)
		SetWidgetTextColorByKey(row.categoryLabel, "default")

		row.idLabel = itemBrowserWindow:CreateChildWidget("label", "dressupItemBrowserId" .. rowIndex, rowIndex, true)
		row.idLabel:AddAnchor("TOPRIGHT", itemBrowserWindow, -22, y + 3)
		row.idLabel:SetExtent(70, 18)
		row.idLabel:EnablePick(false)
		ApplyDressupLabelStyle(row.idLabel, 11, ALIGN_RIGHT, 0.72, 0.72, 0.72)
		SetWidgetTextColorByKey(row.idLabel, "default")

		itemBrowserRows[rowIndex] = row
	end

	local prevButton = itemBrowserWindow:CreateChildWidget("button", "dressupItemBrowserPrev", 0, true)
	prevButton:AddAnchor("BOTTOMLEFT", itemBrowserWindow, 16, -18)
	prevButton:SetExtent(70, 28)
	prevButton:SetWidth(70)
	prevButton:SetText("Prev")
	ApplyDressupButtonStyle(prevButton)
	prevButton:SetHandler("OnClick", function()
		if itemBrowserPage > 1 then
			itemBrowserPage = itemBrowserPage - 1
			RefreshItemBrowser()
		end
	end)

	local nextButton = itemBrowserWindow:CreateChildWidget("button", "dressupItemBrowserNext", 0, true)
	nextButton:AddAnchor("BOTTOMLEFT", itemBrowserWindow, 94, -18)
	nextButton:SetExtent(70, 28)
	nextButton:SetWidth(70)
	nextButton:SetText("Next")
	ApplyDressupButtonStyle(nextButton)
	nextButton:SetHandler("OnClick", function()
		local maxPage = math.max(1, math.ceil(#itemBrowserFiltered / ITEM_BROWSER_ROWS))
		if itemBrowserPage < maxPage then
			itemBrowserPage = itemBrowserPage + 1
			RefreshItemBrowser()
		end
	end)

	itemBrowserWindow.pageLabel = itemBrowserWindow:CreateChildWidget("label", "dressupItemBrowserPage", 0, true)
	itemBrowserWindow.pageLabel:AddAnchor("BOTTOMRIGHT", itemBrowserWindow, -36, -22)
	itemBrowserWindow.pageLabel:SetExtent(220, 20)
	ApplyDressupLabelStyle(itemBrowserWindow.pageLabel, 12, ALIGN_RIGHT, 1, 1, 1)
	SetWidgetTextColorByKey(itemBrowserWindow.pageLabel, "default")

	itemBrowserWindow:SetHandler("OnDragStart", function(self)
		self:StartMoving()
		return true
	end)
	itemBrowserWindow:SetHandler("OnDragStop", function(self)
		self:StopMovingOrSizing()
	end)

	itemBrowserWindow:SetHandler("OnShow", function()
		itemBrowserVisible = true
		RefreshItemBrowser()
	end)
	itemBrowserWindow:SetHandler("OnHide", function()
		itemBrowserVisible = false
	end)

	return itemBrowserWindow
end

local function ToggleItemBrowser()
	local browser = CreateItemBrowserWindow()
	itemBrowserVisible = not itemBrowserVisible
	browser:Show(itemBrowserVisible)
end

local rotateRight = CreateButton(modelViewer, "rotateRight", "LEFT", 5, controlBarYOffset, "L", function()
	turnRight = true
end, function()
	turnRight = false
end, function()
	turnRight = false
end)

local rotateLeft = CreateButton(modelViewer, "rotateLeft", "RIGHT", -5, controlBarYOffset, "R", function()
	turnLeft = true
end, function()
	turnLeft = false
end, function()
	turnLeft = false
end)

local ZoomInButt = CreateButton(modelViewer, "ZoomInButt", "LEFT", 5, controlBarYOffset - 170, "+", function()
	zoomInBool = true
end, function()
	zoomInBool = false
end, function()
	zoomInBool = false
end)

local ZoomOutButt = CreateButton(modelViewer, "ZoomOutButt", "LEFT", 5, controlBarYOffset - 135, "-", function()
	zoomOutBool = true
end, function()
	zoomOutBool = false
end, function()
	zoomOutBool = false
end)

local closeViewer = CreateButton(
	modelViewer,
	"closeViewer",
	"TOPRIGHT",
	-5,
	controlBarYOffset,
	"X",
	nil,
	nil,
	nil,
	function()
		dressUpWindow:Show(false)
	end
)

local GoUp = CreateButton(modelViewer, "GoUp", "TOPRIGHT", -90, controlBarYOffset, "^", nil, nil, nil, function()
	modelViewer:AdjustCameraPos(0, 0, -0.1)
end)

local GoDown = CreateButton(
	modelViewer,
	"GoDown",
	"TOPRIGHT",
	-90,
	controlBarYOffset + 60,
	"v",
	nil,
	nil,
	nil,
	function()
		modelViewer:AdjustCameraPos(0, 0, 0.1)
	end
)

local Zoomer2 = CreateButton(
	modelViewer,
	"Zoomer2",
	"TOPRIGHT",
	-60,
	controlBarYOffset + 30,
	">",
	nil,
	nil,
	nil,
	function()
		modelViewer:AdjustCameraPos(-0.1, 0, 0)
	end
)

local Zoomer3 = CreateButton(
	modelViewer,
	"Zoomer3",
	"TOPRIGHT",
	-120,
	controlBarYOffset + 30,
	"<",
	nil,
	nil,
	nil,
	function()
		modelViewer:AdjustCameraPos(0.1, 0, 0)
	end
)

local StopButton = CreateButton(
	modelViewer,
	"StopButton",
	"TOPRIGHT",
	-220,
	controlBarYOffset,
	"S",
	nil,
	nil,
	nil,
	function()
		modelViewer:StopAnimation()
	end
)

local Cookbutton = CreateButton(
	modelViewer,
	"Cookbutton",
	"TOPRIGHT",
	-280,
	controlBarYOffset,
	"1",
	nil,
	nil,
	nil,
	function()
		modelViewer:SetBeautyShopMode(true)
	end
)
local Cookbutton2 = CreateButton(
	modelViewer,
	"Cookbutton2",
	"TOPRIGHT",
	-320,
	controlBarYOffset,
	"2",
	nil,
	nil,
	nil,
	function()
		modelViewer:SetIngameShopCamMode(true)
	end
)
local Cookbutton3 = CreateButton(
	modelViewer,
	"Cookbutton3",
	"TOPRIGHT",
	-360,
	controlBarYOffset,
	"3",
	nil,
	nil,
	nil,
	function()
		modelViewer:SetDisableColorGrading(true)
	end
)

--local resetButton = CreateButton(modelViewer, "resetButton", "TOPLEFT", 5, controlBarYOffset + 15, "Reset",
--    nil, nil, nil,
--    function()
--      modelViewer:ApplyModel()
--    end)

--local showHelm = CreateButton(modelViewer, "showHelm", "TOPLEFT", 5, controlBarYOffset + 50, "Helm",
--    nil, nil, nil,
--    function() modelViewer:ApplyModel() end)
--
--local alt = CreateButton(modelViewer, "alt", "TOPLEFT", 5, controlBarYOffset + 85, "alt",
--    nil, nil, nil,
--    function()
--      modelViewer:SetSmile(true)
--      X2Chat:DispatchChatMessage(CMF_SYSTEM, tostring("blu"))
--    end)

local costume = CreateButton(
	modelViewer,
	"costume",
	"TOPLEFT",
	5,
	controlBarYOffset + 120,
	"cos",
	nil,
	nil,
	nil,
	function()
		modelViewer:ToggleCosplayEquipped(showCostume)
		showCostume = not showCostume
	end
)

local itemBrowserButton = CreateButton(
	modelViewer,
	"itemBrowser",
	"TOPLEFT",
	5,
	controlBarYOffset + 160,
	"items",
	nil,
	nil,
	nil,
	function()
		ToggleItemBrowser()
	end
)
itemBrowserButton:SetExtent(55, 35)
itemBrowserButton:SetWidth(55)

local dressUpModelViewerX = 800
local dressUpModelViewerY = 800
local thenumber = 4096
local function IniitalizeDressup()
	modelViewer:SetExtent(dressUpModelViewerX, dressUpModelViewerY)
	modelViewer:SetTextureSize(thenumber, thenumber)
	local width = dressUpModelViewerX * thenumber / dressUpModelViewerY
	modelViewer:SetModelViewExtent(width, thenumber)
	modelViewer:SetModelViewCoords((thenumber - width) / 8, 0, width / 4, thenumber / 4)
	modelViewer:AddAnchor("LEFT", dressUpWindow, 5, 20)
	modelViewer:AdjustCameraPos(0, 0, 0)
	dressUpWindow:Show(false)
end

function modelViewer:OnWheelDown()
	--X2Chat:DispatchChatMessage(CMF_SYSTEM, "down")
	fov = fov + 3
	modelViewer:SetFov(fov)
	--modelViewer:ZoomInOutBeautyShop(1)
end
modelViewer:SetHandler("OnWheelDown", modelViewer.OnWheelDown)
function modelViewer:OnWheelUp()
	--X2Chat:DispatchChatMessage(CMF_SYSTEM, "up")
	fov = fov - 3
	modelViewer:SetFov(fov)
	--modelViewer:ZoomInOutBeautyShop(-1)
end
modelViewer:SetHandler("OnWheelUp", modelViewer.OnWheelUp)

IniitalizeDressup()

---------- Chat listener -----------
local chatAggroEventListenerEvents = {
	CHAT_MESSAGE = function(channel, relation, name, message, info)
		if name == X2Unit:UnitName("player") then
			local firstWord = string.match(message, "/%w+")
			local secondWord = string.match(message, "/[%w_]+%s+([^%s]+)")
			if firstWord == "/dressup" then
				dressUpWindow:Show(true)
				modelViewer:Init("player", true)
				modelViewer:PlayAnimation(RELAX_ANIMATION_NAME, true)
			elseif firstWord == "/closedressup" then
				dressUpWindow:Show(false)
			elseif firstWord == "/animate" then
				if secondWord ~= nil then
					X2Chat:DispatchChatMessage(CMF_SYSTEM, tostring(secondWord))
					modelViewer:Init("player", true)
					modelViewer:PlayAnimation(tostring(secondWord), true)
				else
					X2Chat:DispatchChatMessage(CMF_SYSTEM, "/animate <animationname>")
				end
			elseif firstWord == "/equipbase" then
				if secondWord ~= nil then
					local equipThisItem = secondWord
					if secondWord:sub(1, 1) == "|" then
						equipThisItem = secondWord:match("i(%d+),")
					end
					EquipBaseItem(equipThisItem)
				else
					X2Chat:DispatchChatMessage(CMF_SYSTEM, "/equipbase <itemid>")
				end
			elseif firstWord == "/equip" then
				if secondWord ~= nil then
					local linkText = secondWord:match(".*,([^,;]+);")
					local itemInfo = X2Item:InfoFromLink(linkText, "auction")
					local alembicSkin = itemInfo.lookType
					dressUpWindow:Show(true)
					modelViewer:Init("player", true)
					modelViewer:EquipItem(tonumber(alembicSkin))
					modelViewer:PlayAnimation(RELAX_ANIMATION_NAME, true)
				else
					X2Chat:DispatchChatMessage(CMF_SYSTEM, "/equip <itemid>")
				end
			end
		end
	end,
}

--make chat listener
local chatEventListenerAggro = CreateEmptyWindow("chatEventListenerAggro", "UIParent")
chatEventListenerAggro:Show(false)
chatEventListenerAggro:SetHandler("OnEvent", function(this, event, ...)
	chatAggroEventListenerEvents[event](...)
end)
local RegistUIEvent = function(window, eventTable)
	for key, _ in pairs(eventTable) do
		window:RegisterEvent(key)
	end
end
RegistUIEvent(chatEventListenerAggro, chatAggroEventListenerEvents)

dressUpWindow:SetHandler("OnUpdate", dressUpWindow.OnUpdate)
