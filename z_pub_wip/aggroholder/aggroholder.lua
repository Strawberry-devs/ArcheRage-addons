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
ADDON:ImportObject(OBJECT_TYPE.COLOR_DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.WINDOW)
ADDON:ImportObject(OBJECT_TYPE.LABEL)
ADDON:ImportObject(OBJECT_TYPE.EMPTY_WIDGET)

ADDON:ImportAPI(API_TYPE.UNIT.id)
ADDON:ImportAPI(API_TYPE.CHAT.id)

local greenDots = {}
local redDots = {}
local minSegmentDotCount = 8
local maxSegmentDotCount = 64
local debugElapsed = 0
local debugIntervalMs = 1000

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
  return nil, nil, nil
end

local function EnsureSegmentDots(dotTable, prefix, r, g, b)
  for i = 1, maxSegmentDotCount do
    if dotTable[i] == nil then
      local container = CreateEmptyWindow(prefix .. "Container_" .. i, "UIParent")
      container:Show(false)
      container:AddAnchor("TOPLEFT", "UIParent", 0, 0)

      local label = container:CreateChildWidget("label", prefix .. "Label_" .. i, 0, true)
      label:SetText(".")
      label:SetExtent(20, 20)
      label.style:SetFontSize(16)
      label.style:SetColor(r, g, b, 1)
      label.style:SetOutline(true)
      label.style:SetAlign(ALIGN_CENTER)
      label:EnablePick(false)
      label:AddAnchor("CENTER", container, 0, 0)

      dotTable[i] = { container = container, label = label }
    end
  end
end

local function EnsureLineDots()
  EnsureSegmentDots(greenDots, "aggroHolderGreenDot", 0.2, 1, 0.2)
  EnsureSegmentDots(redDots, "aggroHolderRedDot", 1, 0.2, 0.2)
end

local function HideDotSet(dotTable)
  for i = 1, #dotTable do
    dotTable[i].container:Show(false)
  end
end

local function HideLineDots()
  HideDotSet(greenDots)
  HideDotSet(redDots)
end

local function DrawDotsFromScreenLine(dotTable, x1, y1, x2, y2)
  local visibleCount = 0
  if x1 == nil or y1 == nil or x2 == nil or y2 == nil then
    HideDotSet(dotTable)
    return 0
  end

  local dx = x2 - x1
  local dy = y2 - y1
  local screenDistance = math.sqrt((dx * dx) + (dy * dy))
  local dotCount = math.floor(screenDistance / 24)
  if dotCount < minSegmentDotCount then
    dotCount = minSegmentDotCount
  elseif dotCount > maxSegmentDotCount then
    dotCount = maxSegmentDotCount
  end

  for i = 1, dotCount do
    local t = i / dotCount
    local sx = x1 + (x2 - x1) * t
    local sy = y1 + (y2 - y1) * t
    dotTable[i].container:RemoveAllAnchors()
    dotTable[i].container:AddAnchor("TOPLEFT", "UIParent", math.floor(sx + 0.5), math.floor(sy + 0.5))
    dotTable[i].container:Show(true)
    visibleCount = visibleCount + 1
  end

  for i = dotCount + 1, maxSegmentDotCount do
    dotTable[i].container:Show(false)
  end

  return visibleCount
end

local function DrawDotsFromWorldLine(dotTable, x1, y1, z1, x2, y2, z2)
  local visibleCount = 0
  if x1 == nil or y1 == nil or z1 == nil or x2 == nil or y2 == nil or z2 == nil then
    HideDotSet(dotTable)
    return 0
  end

  local dotCount = minSegmentDotCount
  local s1x, s1y = ProjectWorldToScreen(x1, y1, z1 + 1.0)
  local s2x, s2y = ProjectWorldToScreen(x2, y2, z2 + 1.0)
  if s1x ~= nil and s1y ~= nil and s2x ~= nil and s2y ~= nil then
    local dx = s2x - s1x
    local dy = s2y - s1y
    local d = math.sqrt((dx * dx) + (dy * dy))
    dotCount = math.floor(d / 24)
  end
  if dotCount < minSegmentDotCount then
    dotCount = minSegmentDotCount
  elseif dotCount > maxSegmentDotCount then
    dotCount = maxSegmentDotCount
  end

  for i = 1, dotCount do
    local t = i / dotCount
    local wx = x1 + (x2 - x1) * t
    local wy = y1 + (y2 - y1) * t
    local wz = z1 + (z2 - z1) * t + 1.0
    local sx, sy, depth = ProjectWorldToScreen(wx, wy, wz)
    if sx ~= nil and sy ~= nil and depth ~= nil and depth > 0 then
      dotTable[i].container:RemoveAllAnchors()
      dotTable[i].container:AddAnchor("TOPLEFT", "UIParent", math.floor(sx + 0.5), math.floor(sy + 0.5))
      dotTable[i].container:Show(true)
      visibleCount = visibleCount + 1
    else
      dotTable[i].container:Show(false)
    end
  end

  for i = dotCount + 1, maxSegmentDotCount do
    dotTable[i].container:Show(false)
  end

  return visibleCount
end

local function GetWorldPosSafe(unit)
  local x, y, z = X2Unit:GetUnitWorldPositionByTarget(unit, false)
  if x ~= nil and y ~= nil and z ~= nil then
    return x, y, z
  end
  return X2Unit:GetUnitWorldPositionByTarget(unit, true)
end

local function SaveWindowPosition(x, y)
  local settings = { x = x, y = y }
  ADDON:ClearData("aggroholder_window_pos")
  ADDON:SaveData("aggroholder_window_pos", settings)
end

local function LoadWindowPosition()
  local settings = ADDON:LoadData("aggroholder_window_pos")
  if settings ~= nil then
    return tonumber(settings.x) or 0, tonumber(settings.y) or 0
  end
  return 0, 0
end

local aggroWindow = CreateEmptyWindow("aggroHolderWindow", "UIParent")
aggroWindow:SetExtent(320, 110)

local savedX, savedY = LoadWindowPosition()
if savedX ~= 0 or savedY ~= 0 then
  aggroWindow:AddAnchor("TOPLEFT", "UIParent", savedX, savedY)
else
  aggroWindow:AddAnchor("TOPLEFT", "UIParent", 420, 360)
end

aggroWindow:EnableDrag(true)

local background = aggroWindow:CreateColorDrawable(0.3, 0.3, 0.3, 0.6, "background")
background:AddAnchor("TOPLEFT", aggroWindow, 0, 0)
background:AddAnchor("BOTTOMRIGHT", aggroWindow, 0, 0)

local nameLabel = aggroWindow:CreateChildWidget("label", "aggroHolderNameLabel", 0, true)
nameLabel:AddAnchor("TOPLEFT", aggroWindow, 10, 10)
nameLabel:SetExtent(300, 38)
nameLabel.style:SetAlign(ALIGN_LEFT)
nameLabel.style:SetColor(1, 1, 1, 1)
nameLabel.style:SetFontSize(20)
nameLabel:EnablePick(false)

local aggroLabel = aggroWindow:CreateChildWidget("label", "aggroHolderAggroLabel", 0, true)
aggroLabel:AddAnchor("TOPLEFT", aggroWindow, 10, 54)
aggroLabel:SetExtent(300, 40)
aggroLabel.style:SetAlign(ALIGN_LEFT)
aggroLabel.style:SetColor(1, 1, 1, 1)
aggroLabel.style:SetFontSize(20)
aggroLabel:EnablePick(false)

local elapsed = 0
function aggroWindow:OnUpdate(dt)
  debugElapsed = debugElapsed + dt

  local px, py, pz = GetWorldPosSafe("player")
  local wx, wy, wz = GetWorldPosSafe("watchtarget")
  local tx, ty, tz = GetWorldPosSafe("watchtargettarget")

  local greenVisible = DrawDotsFromWorldLine(greenDots, px, py, pz, wx, wy, wz)
  if greenVisible == 0 then
    local psx, psy = X2Unit:GetUnitScreenPosition("player")
    local wsx, wsy = X2Unit:GetUnitScreenPosition("watchtarget")
    greenVisible = DrawDotsFromScreenLine(greenDots, psx, psy, wsx, wsy)
  end

  local redVisible = DrawDotsFromWorldLine(redDots, wx, wy, wz, tx, ty, tz)
  if redVisible == 0 then
    local wsx, wsy = X2Unit:GetUnitScreenPosition("watchtarget")
    local tsx, tsy = X2Unit:GetUnitScreenPosition("watchtargettarget")
    redVisible = DrawDotsFromScreenLine(redDots, wsx, wsy, tsx, tsy)
  end

  if debugElapsed >= debugIntervalMs then
    X2Chat:DispatchChatMessage(
      CMF_SYSTEM,
      string.format(
        "[AggroHolder DEBUG] line update | wt=%s wtt=%s green=%d/%d red=%d/%d",
        tostring(X2Unit:UnitName("watchtarget")),
        tostring(X2Unit:UnitName("watchtargettarget")),
        greenVisible,
        maxSegmentDotCount,
        redVisible,
        maxSegmentDotCount
      )
    )
    debugElapsed = 0
  end

  elapsed = elapsed + dt
  if elapsed >= 200 then
    elapsed = 0
    local wtName = X2Unit:UnitName("watchtarget") or "none"
    local wttName = X2Unit:UnitName("watchtargettarget") or "none"
    nameLabel:SetText(wtName .. " aggro:")
    aggroLabel:SetText(wttName)
  end
end
aggroWindow:SetHandler("OnUpdate", aggroWindow.OnUpdate)

function aggroWindow:OnDragStart()
  self:StartMoving()
  self.moving = true
end
aggroWindow:SetHandler("OnDragStart", aggroWindow.OnDragStart)

function aggroWindow:OnDragStop()
  self:StopMovingOrSizing()
  self.moving = false
  local offsetX, offsetY = self:GetOffset()
  local uiScale = UIParent:GetUIScale() or 1.0
  local normalizedX = offsetX * uiScale
  local normalizedY = offsetY * uiScale
  SaveWindowPosition(normalizedX, normalizedY)
end
aggroWindow:SetHandler("OnDragStop", aggroWindow.OnDragStop)

aggroWindow:Show(true)
EnsureLineDots()

local toggleButton = CreateSimpleButton("aggroholder", 700, -330)
function toggleButton.OnClick()
  aggroWindow:Show(not aggroWindow:IsVisible())
end
toggleButton:SetHandler("OnClick", toggleButton.OnClick)
