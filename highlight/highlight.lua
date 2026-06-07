-------------- Original Author: Strawberry --------------
----------------- Discord: exec.noir --------------------
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

local SAVE_KEY = "highlight_settings"

local function SetCVar(name, value)
	X2Option:SetConsoleVariable(name, tostring(value))
end

local function RoundToOneDecimal(value)
	return math.floor((value * 10) + 0.5) / 10
end

local scopeLabels = {
	[0] = "Unit & Object",
	[1] = "Unit",
	[2] = "Object",
}

local state = {
	useSilhouette = 1,
	silhouetteSize = 1.0,
	silhouetteColorAmount = 2.0,
	silhouetteScope = 1,
	silhouetteQuality = 2,
}

local function SaveSettings()
	ADDON:ClearData(SAVE_KEY)
	ADDON:SaveData(SAVE_KEY, state)
end

local function ReadSavedNumber(tbl, key, fallback)
	if tbl == nil or tbl[key] == nil then
		return fallback
	end
	return tonumber(tbl[key]) or fallback
end

local function ReadSavedEnum(tbl, key, fallback, allowed)
	local value = ReadSavedNumber(tbl, key, fallback)
	for i = 1, #allowed do
		if value == allowed[i] then
			return value
		end
	end
	return fallback
end

local function ReadSavedMin(tbl, key, fallback, minValue)
	local value = ReadSavedNumber(tbl, key, fallback)
	if value < minValue then
		return minValue
	end
	return value
end

local function LoadSettings()
	local loaded = ADDON:LoadData(SAVE_KEY)
	if loaded == nil then
		return
	end

	state.useSilhouette = ReadSavedEnum(loaded, "useSilhouette", 1, { 0, 1 })
	state.silhouetteScope = ReadSavedEnum(loaded, "silhouetteScope", 1, { 0, 1, 2 })
	state.silhouetteQuality = ReadSavedEnum(loaded, "silhouetteQuality", 2, { 1, 2 })
	state.silhouetteSize = RoundToOneDecimal(ReadSavedMin(loaded, "silhouetteSize", 1.0, 0))
	state.silhouetteColorAmount = RoundToOneDecimal(ReadSavedMin(loaded, "silhouetteColorAmount", 2.0, 0))
end

local function ApplyStateToCVars()
	SetCVar("r_usesilhouette", state.useSilhouette)
	SetCVar("r_silhouetteSize", state.silhouetteSize)
	SetCVar("r_silhouetteColorAmount", state.silhouetteColorAmount)
	SetCVar("e_decals_update_silhouette_scope", state.silhouetteScope)
	SetCVar("r_silhouetteQuality", state.silhouetteQuality)
end

local function CreateWindowBackground(window)
	local bg = window:CreateDrawable("ui/common/default.dds", "main_bg", "background")
	bg:AddAnchor("TOPLEFT", window, -5, -5)
	bg:AddAnchor("BOTTOMRIGHT", window, 5, 5)
	return bg
end

local function SetWidgetTextColorByKey(widget, colorKey)
	if widget == nil or colorKey == nil or widget.style == nil or widget.style.SetColorByKey == nil then
		return
	end

	widget.style:SetColorByKey(colorKey)
end

local function CreateCloseButton(parent, id, onClick)
	local button = parent:CreateChildWidget("button", id, 0, true)
	button:AddAnchor("TOPRIGHT", parent, 3, -3)
	button:SetStyle("btn_close_default")
	button:SetHandler("OnClick", onClick)
	return button
end

LoadSettings()
ApplyStateToCVars()

local menuWindow = CreateEmptyWindow("highlightConfigWindow", "UIParent")
menuWindow:SetCloseOnEscape(true)
menuWindow:SetExtent(395, 270)
menuWindow:AddAnchor("BOTTOM", "UIParent", 700, -520)
menuWindow:Show(false)
menuWindow:Enable(true)
menuWindow:Clickable(true)
menuWindow:EnableDrag(true)
menuWindow:SetUILayer("system")

local menuBackground = CreateWindowBackground(menuWindow)

function menuWindow:OnDragStart()
	self:StartMoving()
	return true
end
menuWindow:SetHandler("OnDragStart", menuWindow.OnDragStart)

function menuWindow:OnDragStop()
	self:StopMovingOrSizing()
end
menuWindow:SetHandler("OnDragStop", menuWindow.OnDragStop)

local titleLabel = menuWindow:CreateChildWidget("label", "titleLabel", 0, true)
titleLabel:Show(true)
titleLabel.style:SetAlign(ALIGN_LEFT)
titleLabel.style:SetFontSize(16)
SetWidgetTextColorByKey(titleLabel, "brown")
titleLabel:AddAnchor("TOPLEFT", menuWindow, 15, 15)
titleLabel:SetText("Highlight Settings")

CreateCloseButton(menuWindow, "highlightCloseButton", function()
	menuWindow:Show(false)
end)

local LABEL_X = 20
local CONTROL_X = 185
local VALUE_X = 215
local STACK_X = 280
local ROW_USE = 45
local ROW_SIZE = 80
local ROW_COLOR = 128
local ROW_SCOPE = 176
local ROW_QUALITY = 209

local function CreateRowLabel(id, text, rowY)
	local label = menuWindow:CreateChildWidget("label", id, 0, true)
	label:Show(true)
	label.style:SetAlign(ALIGN_LEFT)
	label.style:SetFontSize(14)
	SetWidgetTextColorByKey(label, "default")
	label:SetHeight(24)
	label:AddAnchor("TOPLEFT", menuWindow, LABEL_X, rowY + 2)
	label:SetText(text)
	return label
end

local function CreateTextButton(id, rowY, width)
	local button = menuWindow:CreateChildWidget("button", id, 0, true)
	button:SetStyle("text_default")
	button:SetAutoResize(false)
	button:SetExtent(width, 24)
	button:SetWidth(width)
	button:AddAnchor("TOPLEFT", menuWindow, CONTROL_X, rowY)
	return button
end

local function CreateAdjustButton(id, text, x, y)
	local button = menuWindow:CreateChildWidget("button", id, 0, true)
	button:SetStyle("text_default")
	button:SetAutoResize(false)
	button:SetExtent(26, 24)
	button:SetWidth(26)
	button:SetText(text)
	button:AddAnchor("TOPLEFT", menuWindow, x, y)
	return button
end

local function CreateValueLabel(id, rowY)
	local label = menuWindow:CreateChildWidget("label", id, 0, true)
	label:Show(true)
	label.style:SetAlign(ALIGN_CENTER)
	label.style:SetFontSize(14)
	SetWidgetTextColorByKey(label, "default")
	label:SetWidth(42)
	label:SetHeight(24)
	label:AddAnchor("TOPLEFT", menuWindow, VALUE_X, rowY)
	return label
end

local useSilhouetteLabel = CreateRowLabel("useSilhouetteLabel", "Use Silhouettes", ROW_USE)
local useSilhouetteButton = CreateTextButton("useSilhouetteButton", ROW_USE, 82)

local sizeLabel = CreateRowLabel("sizeLabel", "Silhouette Size", ROW_SIZE)
local sizeValueLabel = CreateValueLabel("sizeValueLabel", ROW_SIZE)
local sizeUpButton = CreateAdjustButton("sizeUpButton", "+", STACK_X, ROW_SIZE - 13)
local sizeDownButton = CreateAdjustButton("sizeDownButton", "-", STACK_X, ROW_SIZE + 13)

local colorAmountLabel = CreateRowLabel("colorAmountLabel", "Silhouette Color Size", ROW_COLOR)
local colorValueLabel = CreateValueLabel("colorValueLabel", ROW_COLOR)
local colorUpButton = CreateAdjustButton("colorUpButton", "+", STACK_X, ROW_COLOR - 13)
local colorDownButton = CreateAdjustButton("colorDownButton", "-", STACK_X, ROW_COLOR + 13)

local scopeLabel = CreateRowLabel("scopeLabel", "Silhouette Scope", ROW_SCOPE)
local scopeButton = CreateTextButton("scopeButton", ROW_SCOPE, 82)

local qualityLabel = CreateRowLabel("qualityLabel", "Silhouette Type", ROW_QUALITY)
local qualityButton = CreateTextButton("qualityButton", ROW_QUALITY, 82)

local function RefreshTexts()
	if state.useSilhouette == 1 then
		useSilhouetteButton:SetText("On")
	else
		useSilhouetteButton:SetText("Off")
	end

	sizeValueLabel:SetText(string.format("%.1f", state.silhouetteSize))
	colorValueLabel:SetText(string.format("%.1f", state.silhouetteColorAmount))
	scopeButton:SetText(scopeLabels[state.silhouetteScope])

	if state.silhouetteQuality == 2 then
		qualityButton:SetText("Type 1")
	else
		qualityButton:SetText("Type 2")
	end
end

local function CommitAndRefresh(cvar, value)
	SetCVar(cvar, value)
	SaveSettings()
	RefreshTexts()
end
function useSilhouetteButton:OnClick()
	if state.useSilhouette == 1 then
		state.useSilhouette = 0
	else
		state.useSilhouette = 1
	end
	CommitAndRefresh("r_usesilhouette", state.useSilhouette)
end
useSilhouetteButton:SetHandler("OnClick", useSilhouetteButton.OnClick)

function sizeDownButton:OnClick()
	state.silhouetteSize = RoundToOneDecimal(math.max(0, state.silhouetteSize - 0.1))
	CommitAndRefresh("r_silhouetteSize", state.silhouetteSize)
end
sizeDownButton:SetHandler("OnClick", sizeDownButton.OnClick)

function sizeUpButton:OnClick()
	state.silhouetteSize = RoundToOneDecimal(state.silhouetteSize + 0.1)
	CommitAndRefresh("r_silhouetteSize", state.silhouetteSize)
end
sizeUpButton:SetHandler("OnClick", sizeUpButton.OnClick)

function colorDownButton:OnClick()
	state.silhouetteColorAmount = RoundToOneDecimal(math.max(0, state.silhouetteColorAmount - 0.2))
	CommitAndRefresh("r_silhouetteColorAmount", state.silhouetteColorAmount)
end
colorDownButton:SetHandler("OnClick", colorDownButton.OnClick)

function colorUpButton:OnClick()
	state.silhouetteColorAmount = RoundToOneDecimal(state.silhouetteColorAmount + 0.2)
	CommitAndRefresh("r_silhouetteColorAmount", state.silhouetteColorAmount)
end
colorUpButton:SetHandler("OnClick", colorUpButton.OnClick)

function scopeButton:OnClick()
	state.silhouetteScope = (state.silhouetteScope + 1) % 3
	CommitAndRefresh("e_decals_update_silhouette_scope", state.silhouetteScope)
end
scopeButton:SetHandler("OnClick", scopeButton.OnClick)

function qualityButton:OnClick()
	if state.silhouetteQuality == 2 then
		state.silhouetteQuality = 1
	else
		state.silhouetteQuality = 2
	end
	CommitAndRefresh("r_silhouetteQuality", state.silhouetteQuality)
end
qualityButton:SetHandler("OnClick", qualityButton.OnClick)

local highlightButton = CreateSimpleButton("Highlight", 700, -260)
function highlightButton:OnClick()
	local shouldShow = not menuWindow:IsVisible()
	menuWindow:Show(shouldShow)
	if shouldShow then
		menuWindow:SetUILayer("system")
		menuWindow:Raise()
	end
end
highlightButton:SetHandler("OnClick", highlightButton.OnClick)

RefreshTexts()
