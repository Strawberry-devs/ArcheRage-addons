-------------- Original Author: Strawberry --------------
----------------- Discord: exec_noir --------------------

if API_TYPE == nil then
    ADDON:ImportAPI(8)
    X2Chat:DispatchChatMessage(CMF_SYSTEM, "EasyPull: globals folder missing")
    return
end

ADDON:ImportObject(OBJECT_TYPE.TEXT_STYLE)
ADDON:ImportObject(OBJECT_TYPE.BUTTON)
ADDON:ImportObject(OBJECT_TYPE.COLOR_DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.NINE_PART_DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.IMAGE_DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.WINDOW)
ADDON:ImportObject(OBJECT_TYPE.LABEL)
ADDON:ImportObject(OBJECT_TYPE.EMPTY_WIDGET)
ADDON:ImportAPI(API_TYPE.CHAT.id)
ADDON:ImportAPI(API_TYPE.UNIT.id)

local saveKey = "easypull_settings"
local defaultDotCount = 48
local dotZOffset = 0.25
local maxViewDistance = 20000
local minRadius = 5
local maxRadius = 200
local minDots = 12
local maxDots = 160
local maxCircles = 8
local defaultDotColor = { r = 1, g = 0, b = 0, a = 1 }
local radiusStep = 1.25

local colorOptions = {
    { name = "Red", r = 1, g = 0, b = 0 },
    { name = "Green", r = 0, g = 1, b = 0 },
    { name = "Blue", r = 0, g = 0.35, b = 1 },
    { name = "White", r = 1, g = 1, b = 1 },
    { name = "Black", r = 0, g = 0, b = 0 }
}

local circles = {}
local dotWidgets = {}
local menuRows = {}
local menuButton = nil
local menuWindow = nil
local densityLabel = nil
local offsetLabel = nil
local selectedOffsetCircle = nil

local updateWidget = UIParent:CreateWidget("emptywidget", "easyPullUpdater", "UIParent", "")
updateWidget:Show(true)

local function Clamp(value, minValue, maxValue)
    return math.max(minValue, math.min(maxValue, value))
end

local function ProjectWorldToScreen(worldX, worldY, worldZ)
    if ConvertWorldToScreen ~= nil then
        local sx, sy, sz = ConvertWorldToScreen(worldX, worldY, worldZ)
        if sx ~= nil and sy ~= nil and sz ~= nil then
            return sx, sy, sz
        end
    end

    if WorldToScreen ~= nil then
        return WorldToScreen(worldX, worldY, worldZ)
    end

    return nil
end

local function ForwardRightFromAngle(angle)
    if angle == nil then
        return 1, 0, 0, -1
    end

    local forwardX = math.cos(angle)
    local forwardY = math.sin(angle)
    local rightX = forwardY
    local rightY = -forwardX
    return forwardX, forwardY, rightX, rightY
end

local function NewPlayerCircle(radius)
    return {
        radius = radius or 30,
        unit = "player",
        dotCount = defaultDotCount,
        offsetForward = 0,
        offsetRight = 0,
        color = {
            r = defaultDotColor.r,
            g = defaultDotColor.g,
            b = defaultDotColor.b,
            a = defaultDotColor.a
        }
    }
end

local function SaveSettings()
    ADDON:ClearData(saveKey)
    ADDON:SaveData(saveKey, {
        circles = circles
    })
end

local function LoadSettings()
    local stored = ADDON:LoadData(saveKey)
    local legacyDotCount = nil
    if stored ~= nil then
        local storedDotCount = tonumber(stored.dotCount)
        if storedDotCount ~= nil then
            legacyDotCount = Clamp(math.floor(storedDotCount), minDots, maxDots)
        end

        if stored.circles ~= nil then
            for i = 1, math.min(#stored.circles, maxCircles) do
                local circle = stored.circles[i]
                local radius = tonumber(circle.radius)
                local unit = circle.unit == "target" and "target" or "player"
                local color = circle.color or stored.dotColor or defaultDotColor
                if radius ~= nil then
                    local loadedCircle = {
                        radius = Clamp(radius, minRadius, maxRadius),
                        unit = unit,
                        dotCount = Clamp(
                            math.floor(tonumber(circle.dotCount) or legacyDotCount or defaultDotCount),
                            minDots,
                            maxDots
                        ),
                        offsetForward = tonumber(circle.offsetForward) or 0,
                        offsetRight = tonumber(circle.offsetRight) or 0,
                        color = {
                            r = tonumber(color.r) or defaultDotColor.r,
                            g = tonumber(color.g) or defaultDotColor.g,
                            b = tonumber(color.b) or defaultDotColor.b,
                            a = tonumber(color.a) or defaultDotColor.a
                        }
                    }
                    circles[#circles + 1] = loadedCircle
                end
            end
        end
    end

    if #circles == 0 then
        circles[1] = NewPlayerCircle(30)
    end
end

local function ApplyCircleDotColor(circleIndex)
    local circle = circles[circleIndex]
    local circleDots = dotWidgets[circleIndex]
    if circle == nil or circleDots == nil then
        return
    end

    for dotIndex = 1, #circleDots do
        if circleDots[dotIndex] ~= nil and circleDots[dotIndex].label ~= nil then
            circleDots[dotIndex].label.style:SetColor(
                circle.color.r,
                circle.color.g,
                circle.color.b,
                circle.color.a
            )
        end
    end
end

local function ColorNameForCircle(circle)
    if circle == nil or circle.color == nil then
        return "Red"
    end

    for i = 1, #colorOptions do
        local color = colorOptions[i]
        if color.r == circle.color.r and color.g == circle.color.g and color.b == circle.color.b then
            return color.name
        end
    end

    return "Custom"
end

local function FormatRadius(radius)
    if radius == math.floor(radius) then
        return string.format("%dm", radius)
    end

    return string.format("%.2fm", radius)
end

local function EnsureCircleColor(circle)
    if circle.color == nil then
        circle.color = {
            r = defaultDotColor.r,
            g = defaultDotColor.g,
            b = defaultDotColor.b,
            a = defaultDotColor.a
        }
    else
        circle.color.r = tonumber(circle.color.r) or defaultDotColor.r
        circle.color.g = tonumber(circle.color.g) or defaultDotColor.g
        circle.color.b = tonumber(circle.color.b) or defaultDotColor.b
        circle.color.a = tonumber(circle.color.a) or defaultDotColor.a
    end
end

local function EnsureCircleDotCount(circle)
    circle.dotCount = Clamp(math.floor(tonumber(circle.dotCount) or defaultDotCount), minDots, maxDots)
end

local function EnsureAllCircleConfig()
    for circleIndex = 1, #circles do
        EnsureCircleColor(circles[circleIndex])
        EnsureCircleDotCount(circles[circleIndex])
    end
end

local function HideCircleDots(circleIndex)
    local circleDots = dotWidgets[circleIndex]
    if circleDots == nil then
        return
    end

    for dotIndex = 1, #circleDots do
        if circleDots[dotIndex] ~= nil and circleDots[dotIndex].container ~= nil then
            circleDots[dotIndex].container:Show(false)
        end
    end
end

local function HideUnusedCircleDots()
    for circleIndex = #circles + 1, #dotWidgets do
        HideCircleDots(circleIndex)
    end
end

local function EnsureCircleDotWidgets(circleIndex)
    local circle = circles[circleIndex]
    if circle == nil then
        return
    end
    EnsureCircleColor(circle)
    EnsureCircleDotCount(circle)

    if dotWidgets[circleIndex] == nil then
        dotWidgets[circleIndex] = {}
    end

    local circleDots = dotWidgets[circleIndex]
    for dotIndex = 1, circle.dotCount do
        if circleDots[dotIndex] == nil then
            local widgetName = "easyPullDotContainer_" .. circleIndex .. "_" .. dotIndex
            local labelName = "easyPullDotLabel_" .. circleIndex .. "_" .. dotIndex
            local container = CreateEmptyWindow(widgetName, "UIParent")
            container:Show(true)
            container:Enable(true)
            container:AddAnchor("TOPLEFT", "UIParent", 0, 0)

            local label = container:CreateChildWidget("label", labelName, 0, true)
            label:SetText(".")
            label:Show(true)
            label:EnablePick(false)
            label.style:SetFontSize(22)
            label.style:SetColor(circle.color.r, circle.color.g, circle.color.b, circle.color.a)
            label.style:SetOutline(true)
            label.style:SetAlign(ALIGN_CENTER)
            label:SetExtent(34, 28)
            label:AddAnchor("CENTER", container, 0, 0)

            circleDots[dotIndex] = { container = container, label = label }
        end
    end

    for dotIndex = circle.dotCount + 1, #circleDots do
        if circleDots[dotIndex] ~= nil and circleDots[dotIndex].container ~= nil then
            circleDots[dotIndex].container:Show(false)
        end
    end
end

local function EnsureAllDotWidgets()
    for circleIndex = 1, #circles do
        EnsureCircleDotWidgets(circleIndex)
    end
    HideUnusedCircleDots()
end

local function UpdateDensityLabel()
    if densityLabel ~= nil then
        local circle = selectedOffsetCircle ~= nil and circles[selectedOffsetCircle] or nil
        if circle == nil then
            densityLabel:SetText("Dots: select")
        else
            densityLabel:SetText(string.format("Dots %d: %d", selectedOffsetCircle, circle.dotCount))
        end
    end
end

local function UpdateOffsetLabel()
    if offsetLabel == nil then
        return
    end

    local circle = selectedOffsetCircle ~= nil and circles[selectedOffsetCircle] or nil
    if circle == nil then
        offsetLabel:SetText("Offset: select a circle")
        return
    end

    offsetLabel:SetText(string.format(
        "Offset %d: F%d R%d",
        selectedOffsetCircle,
        circle.offsetForward,
        circle.offsetRight
    ))
end

local function UpdateMenuRows()
    if menuWindow == nil then
        return
    end

    if selectedOffsetCircle == nil and #circles > 0 then
        selectedOffsetCircle = 1
    end

    for rowIndex = 1, #menuRows do
        menuRows[rowIndex].container:Show(rowIndex <= #circles)
        if rowIndex <= #circles then
            local circle = circles[rowIndex]
            menuRows[rowIndex].label:SetText(string.format(
                "%d. %s %s D%d %s",
                rowIndex,
                circle.unit,
                FormatRadius(circle.radius),
                circle.dotCount,
                ColorNameForCircle(circle)
            ))
            menuRows[rowIndex].unitButton:SetText(circle.unit == "player" and "Player" or "Target")
        end
    end

    UpdateOffsetLabel()
    UpdateDensityLabel()
end

local function SetDensity(newDotCount)
    local circle = selectedOffsetCircle ~= nil and circles[selectedOffsetCircle] or nil
    if circle == nil then
        return
    end

    circle.dotCount = Clamp(math.floor(newDotCount), minDots, maxDots)
    EnsureCircleDotWidgets(selectedOffsetCircle)
    UpdateDensityLabel()
    UpdateMenuRows()
    SaveSettings()
end

local function SetDotColor(color)
    local circle = selectedOffsetCircle ~= nil and circles[selectedOffsetCircle] or nil
    if circle == nil then
        return
    end

    circle.color = { r = color.r, g = color.g, b = color.b, a = 1 }
    ApplyCircleDotColor(selectedOffsetCircle)
    UpdateMenuRows()
    SaveSettings()
end

local function SetCircleRadius(circleIndex, newRadius)
    if circles[circleIndex] == nil then
        return
    end

    circles[circleIndex].radius = Clamp(newRadius, minRadius, maxRadius)
    UpdateMenuRows()
    SaveSettings()
end

local function ToggleCircleUnit(circleIndex)
    if circles[circleIndex] == nil then
        return
    end

    circles[circleIndex].unit = circles[circleIndex].unit == "player" and "target" or "player"
    UpdateMenuRows()
    SaveSettings()
end

local function SetSelectedOffsetCircle(circleIndex)
    if circles[circleIndex] == nil then
        return
    end

    selectedOffsetCircle = circleIndex
    UpdateOffsetLabel()
    UpdateDensityLabel()
end

local function OffsetSelectedCircle(forwardDelta, rightDelta)
    local circle = selectedOffsetCircle ~= nil and circles[selectedOffsetCircle] or nil
    if circle == nil then
        return
    end

    circle.offsetForward = Clamp(math.floor(circle.offsetForward + forwardDelta), -100, 100)
    circle.offsetRight = Clamp(math.floor(circle.offsetRight + rightDelta), -100, 100)
    UpdateMenuRows()
    SaveSettings()
end

local function ResetSelectedOffset()
    local circle = selectedOffsetCircle ~= nil and circles[selectedOffsetCircle] or nil
    if circle == nil then
        return
    end

    circle.offsetForward = 0
    circle.offsetRight = 0
    UpdateMenuRows()
    SaveSettings()
end

local function AddCircle()
    if #circles >= maxCircles then
        return
    end

    circles[#circles + 1] = NewPlayerCircle(30)
    EnsureAllDotWidgets()
    UpdateMenuRows()
    SaveSettings()
end

local function RemoveCircle(circleIndex)
    if #circles <= 1 or circles[circleIndex] == nil then
        return
    end

    table.remove(circles, circleIndex)
    if selectedOffsetCircle == circleIndex then
        selectedOffsetCircle = nil
    elseif selectedOffsetCircle ~= nil and selectedOffsetCircle > circleIndex then
        selectedOffsetCircle = selectedOffsetCircle - 1
    end
    HideUnusedCircleDots()
    UpdateMenuRows()
    SaveSettings()
end

local function CreateMenuButton(parent, name, text, x, y, width, onClick)
    local button = parent:CreateChildWidget("button", name, 0, true)
    button:SetText(text)
    button:SetStyle("text_default")
    button:SetExtent(width, 26)
    button:AddAnchor("TOPLEFT", parent, x, y)
    button:SetHandler("OnClick", onClick)
    return button
end

local function CreateMenuLabel(parent, name, x, y, width, colorKey)
    local label = parent:CreateChildWidget("label", name, 0, true)
    label:SetExtent(width, 24)
    label:AddAnchor("TOPLEFT", parent, x, y)
    label.style:SetFontSize(14)
    label.style:SetColorByKey(colorKey or "default")
    label.style:SetOutline(true)
    label.style:SetAlign(ALIGN_CENTER)
    return label
end

local function CreateMenuBackground(window)
    local bg = window:CreateDrawable("ui/common/default.dds", "main_bg", "background")
    bg:AddAnchor("TOPLEFT", window, -5, -5)
    bg:AddAnchor("BOTTOMRIGHT", window, 5, 5)
end

local function CreateCircleRow(rowIndex)
    local row = menuWindow:CreateChildWidget("emptywidget", "easyPullCircleRow", rowIndex, true)
    row:SetExtent(390, 30)
    row:AddAnchor("TOPLEFT", menuWindow, 8, 104 + ((rowIndex - 1) * 32))
    row:Show(rowIndex <= #circles)

    local label = row:CreateChildWidget("label", "easyPullCircleLabel_" .. rowIndex, 0, true)
    label:SetExtent(150, 24)
    label:AddAnchor("TOPLEFT", row, 0, 3)
    label.style:SetFontSize(13)
    label.style:SetColor(1, 1, 1, 1)
    label.style:SetOutline(true)
    label.style:SetAlign(ALIGN_LEFT)

    local minusButton = CreateMenuButton(row, "easyPullCircleRemove_" .. rowIndex, "-", 154, 2, 24, function()
        RemoveCircle(rowIndex)
    end)

    local unitButton = CreateMenuButton(row, "easyPullCircleUnit_" .. rowIndex, "Player", 182, 2, 56, function()
        ToggleCircleUnit(rowIndex)
    end)

    local radiusMinusButton = CreateMenuButton(
        row,
        "easyPullCircleRadiusMinus_" .. rowIndex,
        "- R",
        244,
        2,
        42,
        function()
            if circles[rowIndex] ~= nil then
                SetCircleRadius(rowIndex, circles[rowIndex].radius - radiusStep)
            end
        end
    )

    local radiusPlusButton = CreateMenuButton(
        row,
        "easyPullCircleRadiusPlus_" .. rowIndex,
        "+ R",
        286,
        2,
        42,
        function()
            if circles[rowIndex] ~= nil then
                SetCircleRadius(rowIndex, circles[rowIndex].radius + radiusStep)
            end
        end
    )

    local offsetButton = CreateMenuButton(row, "easyPullCircleOffset_" .. rowIndex, "Edit", 328, 2, 58, function()
        SetSelectedOffsetCircle(rowIndex)
    end)

    menuRows[rowIndex] = {
        container = row,
        label = label,
        minusButton = minusButton,
        unitButton = unitButton,
        radiusMinusButton = radiusMinusButton,
        radiusPlusButton = radiusPlusButton,
        offsetButton = offsetButton
    }
end

local function CreateEasyPullMenu()
    if menuWindow ~= nil then
        return
    end

    menuWindow = CreateEmptyWindow("easyPullMenuWindow", "UIParent")
    menuWindow:SetExtent(406, 476)
    if menuButton ~= nil then
        menuWindow:AddAnchor("TOP", menuButton, 0, 32)
    else
        menuWindow:AddAnchor("BOTTOM", "UIParent", 700, -362)
    end
    menuWindow:EnableDrag(true)
    menuWindow:SetCloseOnEscape(true)
    menuWindow:Show(false)

    CreateMenuBackground(menuWindow)

    function menuWindow:OnDragStart()
        self:StartMoving()
        self.moving = true
    end
    menuWindow:SetHandler("OnDragStart", menuWindow.OnDragStart)

    function menuWindow:OnDragStop()
        self:StopMovingOrSizing()
        self.moving = false
    end
    menuWindow:SetHandler("OnDragStop", menuWindow.OnDragStop)

    local title = CreateMenuLabel(menuWindow, "easyPullMenuTitle", 88, 15, 230, "brown")
    title.style:SetFontSize(18)
    title:SetText("EasyPull")

    local closeButton = menuWindow:CreateChildWidget("button", "easyPullCloseButton", 0, true)
    closeButton:AddAnchor("TOPRIGHT", menuWindow, 3, -3)
    closeButton:SetStyle("btn_close_default")
    closeButton:SetHandler("OnClick", function()
        menuWindow:Show(false)
    end)

    CreateMenuButton(menuWindow, "easyPullAddCircle", "+ Circle", 12, 48, 82, AddCircle)

    densityLabel = CreateMenuLabel(menuWindow, "easyPullDensityLabel", 116, 49, 92)
    CreateMenuButton(menuWindow, "easyPullDensityMinus", "- Dots", 268, 48, 58, function()
        local circle = selectedOffsetCircle ~= nil and circles[selectedOffsetCircle] or nil
        if circle ~= nil then
            SetDensity(circle.dotCount - 12)
        end
    end)
    CreateMenuButton(menuWindow, "easyPullDensityPlus", "+ Dots", 334, 48, 58, function()
        local circle = selectedOffsetCircle ~= nil and circles[selectedOffsetCircle] or nil
        if circle ~= nil then
            SetDensity(circle.dotCount + 12)
        end
    end)

    for i = 1, #colorOptions do
        local color = colorOptions[i]
        local x = 12 + ((i - 1) * 64)
        CreateMenuButton(menuWindow, "easyPullColor" .. color.name, color.name, x, 76, 58, function()
            SetDotColor(color)
        end)
    end

    for rowIndex = 1, maxCircles do
        CreateCircleRow(rowIndex)
    end

    offsetLabel = CreateMenuLabel(menuWindow, "easyPullOffsetLabel", 12, 364, 160)
    CreateMenuButton(menuWindow, "easyPullOffsetUp", "^", 198, 356, 38, function()
        OffsetSelectedCircle(1, 0)
    end)
    CreateMenuButton(menuWindow, "easyPullOffsetLeft", "<", 156, 386, 38, function()
        OffsetSelectedCircle(0, -1)
    end)
    CreateMenuButton(menuWindow, "easyPullOffsetReset", "0", 198, 386, 38, ResetSelectedOffset)
    CreateMenuButton(menuWindow, "easyPullOffsetRight", ">", 240, 386, 38, function()
        OffsetSelectedCircle(0, 1)
    end)
    CreateMenuButton(menuWindow, "easyPullOffsetDown", "v", 198, 416, 38, function()
        OffsetSelectedCircle(-1, 0)
    end)

    UpdateDensityLabel()
    UpdateMenuRows()
end

local function CreateEasyPullButton()
    if menuButton ~= nil then
        return
    end

    menuButton = CreateSimpleButton("EasyPull", 700, -330)
    menuButton:SetHandler("OnClick", function()
        CreateEasyPullMenu()
        menuWindow:Show(not menuWindow:IsVisible())
    end)
end

function updateWidget:OnUpdate(dt)
    for circleIndex = 1, #circles do
        EnsureCircleDotWidgets(circleIndex)

        local circle = circles[circleIndex]
        local px, py, pz, unitAngle
        if circle.unit == "target" then
            px, py, pz, unitAngle = X2Unit:GetUnitWorldPositionByTarget("target", true)
        else
            px, py, pz, unitAngle = X2Unit:GetUnitWorldPositionByTarget("player", true)
        end

        if px == nil or py == nil or pz == nil then
            HideCircleDots(circleIndex)
        else
            local forwardX, forwardY, rightX, rightY = ForwardRightFromAngle(unitAngle)
            local centerX = px + (forwardX * circle.offsetForward) + (rightX * circle.offsetRight)
            local centerY = py + (forwardY * circle.offsetForward) + (rightY * circle.offsetRight)
            local circleDots = dotWidgets[circleIndex]
            for dotIndex = 1, circle.dotCount do
                local angle = ((dotIndex - 1) / circle.dotCount) * math.pi * 2
                local offsetX = math.cos(angle) * circle.radius
                local offsetY = math.sin(angle) * circle.radius
                local screenX, screenY, depth = ProjectWorldToScreen(
                    centerX + offsetX,
                    centerY + offsetY,
                    pz + dotZOffset
                )

                if screenX ~= nil and screenY ~= nil and depth ~= nil and depth > 0 and depth <= maxViewDistance then
                    circleDots[dotIndex].container:AddAnchor(
                        "TOPLEFT",
                        "UIParent",
                        math.floor(screenX + 0.5),
                        math.floor(screenY + 0.5)
                    )
                    circleDots[dotIndex].container:Show(true)
                else
                    circleDots[dotIndex].container:Show(false)
                end
            end
        end
    end

    HideUnusedCircleDots()
end

LoadSettings()
EnsureAllCircleConfig()
EnsureAllDotWidgets()
CreateEasyPullButton()
updateWidget:SetHandler("OnUpdate", updateWidget.OnUpdate)

X2Chat:DispatchChatMessage(CMF_SYSTEM, "EasyPull loaded")
