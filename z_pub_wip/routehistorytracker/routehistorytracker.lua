if API_TYPE == nil then
    ADDON:ImportAPI(8)
    X2Chat:DispatchChatMessage(
        CMF_SYSTEM,
        "Globals folder not found. Please install it at https://github.com/Schiz-n/ArcheRage-addons/tree/master/globals"
    )
    return
end

ADDON:ImportObject(OBJECT_TYPE.WINDOW)
ADDON:ImportObject(OBJECT_TYPE.DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.IMAGE_DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.LABEL)
ADDON:ImportObject(OBJECT_TYPE.BUTTON)
ADDON:ImportAPI(API_TYPE.CHAT.id)
ADDON:ImportAPI(API_TYPE.UNIT.id)

local SETTINGS_FILE = "RouteHistoryTrackerSettings.txt"
local MAP_TEXTURE = "ui/map/map_resources/instance_wonderland.dds"
local MAP_TEXTURE_SIZE = 1024

local DEFAULTS = {
    x = 250,
    y = 180,
    w = 500,
    h = 500,
    scale = 0.11,
    angle_offset = 0,
}

local MIN_W = 260
local MIN_H = 260
local MAP_PADDING = 8
local MARKER_SIZE = 12
local SAMPLE_DISTANCE = 1.8
local MAX_DOTS = 2500

local function clamp(value, minValue)
    if value < minValue then
        return minValue
    end
    return value
end

local function loadSettings()
    local cfg = {
        x = DEFAULTS.x,
        y = DEFAULTS.y,
        w = DEFAULTS.w,
        h = DEFAULTS.h,
        scale = DEFAULTS.scale,
        angle_offset = DEFAULTS.angle_offset,
    }

    local file = io.open(SETTINGS_FILE, "r")
    if not file then
        return cfg
    end

    for line in file:lines() do
        local key, value = line:match("^([%w_]+)=(.+)$")
        if key and value then
            local num = tonumber(value)
            if num then
                cfg[key] = num
            end
        end
    end

    file:close()
    cfg.w = clamp(cfg.w, MIN_W)
    cfg.h = clamp(cfg.h, MIN_H)
    return cfg
end

local function saveSettings(cfg)
    local file = io.open(SETTINGS_FILE, "w")
    if not file then
        return
    end

    file:write(string.format("x=%d\n", math.floor(cfg.x)))
    file:write(string.format("y=%d\n", math.floor(cfg.y)))
    file:write(string.format("w=%d\n", math.floor(cfg.w)))
    file:write(string.format("h=%d\n", math.floor(cfg.h)))
    file:write(string.format("scale=%.6f\n", cfg.scale))
    file:write(string.format("angle_offset=%d\n", math.floor(cfg.angle_offset)))
    file:close()
end

local settings = loadSettings()
local routeScale = settings.scale
local angleOffsetDeg = settings.angle_offset

local mainFrame = CreateEmptyWindow("routeHistoryTrackerMain", "UIParent")
mainFrame:SetExtent(settings.w, settings.h)
mainFrame:AddAnchor("TOPLEFT", "UIParent", settings.x, settings.y)
mainFrame:Show(true)
mainFrame:EnableDrag(true)

local frameBg = mainFrame:CreateColorDrawable(0.02, 0.02, 0.02, 0.88, "background")
frameBg:AddAnchor("TOPLEFT", mainFrame, 0, 0)
frameBg:AddAnchor("BOTTOMRIGHT", mainFrame, 0, 0)

local titleBg = mainFrame:CreateColorDrawable(0.12, 0.2, 0.3, 0.95, "background")
titleBg:AddAnchor("TOPLEFT", mainFrame, 0, 0)
titleBg:AddAnchor("TOPRIGHT", mainFrame, 0, 0)
titleBg:SetHeight(24)

local title = mainFrame:CreateChildWidget("label", "routeHistoryTrackerTitle", 0, true)
title:AddAnchor("LEFT", titleBg, 8, 0)
title:SetText("Route History Tracker")
title.style:SetFontSize(13)
title.style:SetColor(1, 1, 1, 1)
title.style:SetAlign(ALIGN_LEFT)
title:Show(true)

local help = mainFrame:CreateChildWidget("label", "routeHistoryTrackerHelp", 0, true)
help:AddAnchor("RIGHT", titleBg, -8, 0)
help:SetText("Click map to calibrate")
help.style:SetFontSize(11)
help.style:SetColor(0.85, 0.95, 1, 1)
help.style:SetAlign(ALIGN_RIGHT)
help:Show(true)

local mapHost = UIParent:CreateWidget("emptywidget", "routeHistoryMapHost", mainFrame)
mapHost:AddAnchor("TOPLEFT", mainFrame, MAP_PADDING, 24 + MAP_PADDING)
mapHost:AddAnchor("BOTTOMRIGHT", mainFrame, -MAP_PADDING, -MAP_PADDING)
mapHost:Show(true)

local mapImage = mapHost:CreateImageDrawable(MAP_TEXTURE, "background")
mapImage:SetCoords(0, 0, MAP_TEXTURE_SIZE, MAP_TEXTURE_SIZE)
mapImage:AddAnchor("TOPLEFT", mapHost, 0, 0)
mapImage:AddAnchor("BOTTOMRIGHT", mapHost, 0, 0)

local currentMarker = mapHost:CreateChildWidget("label", "routeHistoryCurrentMarker", 0, true)
currentMarker:SetText("+")
currentMarker:SetExtent(MARKER_SIZE, MARKER_SIZE)
currentMarker.style:SetFontSize(16)
currentMarker.style:SetColor(1, 0.3, 0.3, 1)
currentMarker.style:SetAlign(ALIGN_CENTER)
currentMarker:Show(false)

local resizeHandle = mainFrame:CreateChildWidget("button", "routeHistoryResizeHandle", 0, true)
resizeHandle:SetExtent(14, 14)
resizeHandle:AddAnchor("BOTTOMRIGHT", mainFrame, -2, -2)
resizeHandle:EnableDrag(true)
resizeHandle:Show(true)
local resizeIcon = resizeHandle:CreateColorDrawable(0.75, 0.75, 0.75, 0.9, "background")
resizeIcon:AddAnchor("TOPLEFT", resizeHandle, 0, 0)
resizeIcon:AddAnchor("BOTTOMRIGHT", resizeHandle, 0, 0)

local trailDots = {}
local trailCount = 0
local anchorWorldX = nil
local anchorWorldY = nil
local anchorAngle = nil
local anchorMapX = nil
local anchorMapY = nil
local lastSampleX = nil
local lastSampleY = nil

local function saveWindowState()
    local x, y = mainFrame:GetOffset()
    settings.x = x
    settings.y = y
    settings.w = clamp(mainFrame:GetWidth(), MIN_W)
    settings.h = clamp(mainFrame:GetHeight(), MIN_H)
    settings.scale = routeScale
    settings.angle_offset = angleOffsetDeg
    saveSettings(settings)
end

mainFrame:SetHandler("OnDragStart", function(self)
    self:StartMoving()
    return true
end)

mainFrame:SetHandler("OnDragStop", function(self)
    self:StopMovingOrSizing()
    saveWindowState()
end)

resizeHandle:SetHandler("OnDragStart", function(self)
    mainFrame:StartSizing("BOTTOMRIGHT")
    return true
end)

resizeHandle:SetHandler("OnDragStop", function(self)
    mainFrame:StopMovingOrSizing()
    local w = clamp(mainFrame:GetWidth(), MIN_W)
    local h = clamp(mainFrame:GetHeight(), MIN_H)
    mainFrame:SetExtent(w, h)
    saveWindowState()
end)

local function clearTrail()
    for i = 1, #trailDots do
        trailDots[i]:Show(false)
    end
    trailCount = 0
    lastSampleX = nil
    lastSampleY = nil
end

local function ensureDot(index)
    if trailDots[index] ~= nil then
        return trailDots[index]
    end
    local dot = mapHost:CreateChildWidget("label", "routeHistoryDot" .. index, 0, true)
    dot:SetText(".")
    dot:SetExtent(8, 8)
    dot.style:SetFontSize(13)
    dot.style:SetColor(0.15, 1.0, 0.15, 1)
    dot.style:SetAlign(ALIGN_CENTER)
    dot:Show(false)
    trailDots[index] = dot
    return dot
end

local function toMapPoint(worldX, worldY)
    if anchorWorldX == nil or anchorWorldY == nil or anchorMapX == nil or anchorMapY == nil then
        return nil, nil
    end

    local dx = worldX - anchorWorldX
    local dy = worldY - anchorWorldY

    local angle = (anchorAngle or 0) + math.rad(angleOffsetDeg)
    local cosA = math.cos(-angle)
    local sinA = math.sin(-angle)

    local localX = (dx * cosA) - (dy * sinA)
    local localY = (dx * sinA) + (dy * cosA)

    local px = anchorMapX + (localX * routeScale)
    local py = anchorMapY - (localY * routeScale)
    return px, py
end

local function setCurrentMarker(px, py)
    if not px or not py then
        currentMarker:Show(false)
        return
    end

    currentMarker:RemoveAllAnchors()
    currentMarker:AddAnchor("TOPLEFT", mapHost, math.floor(px - MARKER_SIZE / 2), math.floor(py - MARKER_SIZE / 2))
    currentMarker:Show(true)
end

local function addTrailPoint(px, py)
    if not px or not py then
        return
    end

    if px < 0 or py < 0 or px > mapHost:GetWidth() or py > mapHost:GetHeight() then
        return
    end

    if trailCount >= MAX_DOTS then
        return
    end

    trailCount = trailCount + 1
    local dot = ensureDot(trailCount)
    dot:RemoveAllAnchors()
    dot:AddAnchor("TOPLEFT", mapHost, math.floor(px), math.floor(py))
    dot:Show(true)
end

mapHost:SetHandler("OnClick", function(self)
    local px, py, _, angle = X2Unit:GetUnitWorldPositionByTarget("player", true)
    if not px or not py then
        return
    end

    local clickX = nil
    local clickY = nil
    if self.GetLastMouseCoord ~= nil then
        clickX, clickY = self:GetLastMouseCoord()
    end
    if not clickX or not clickY then
        clickX = self:GetWidth() / 2
        clickY = self:GetHeight() / 2
    end

    anchorWorldX = px
    anchorWorldY = py
    anchorAngle = angle or 0
    anchorMapX = clickX
    anchorMapY = clickY
    lastSampleX = nil
    lastSampleY = nil

    clearTrail()
    setCurrentMarker(anchorMapX, anchorMapY)
    addTrailPoint(anchorMapX, anchorMapY)

    X2Chat:DispatchChatMessage(
        CMF_SYSTEM,
        string.format("Route tracker calibrated. scale=%.3f angleOffset=%d", routeScale, angleOffsetDeg)
    )
end)

local updater = UIParent:CreateWidget("emptywidget", "routeHistoryUpdater", "UIParent", "")
updater:Show(true)

updater:SetHandler("OnUpdate", function(self, dt)
    local px, py = X2Unit:GetUnitWorldPositionByTarget("player", true)
    if not px or not py then
        return
    end

    local mapX, mapY = toMapPoint(px, py)
    setCurrentMarker(mapX, mapY)

    if mapX == nil or mapY == nil then
        return
    end

    if lastSampleX == nil or lastSampleY == nil then
        lastSampleX = px
        lastSampleY = py
        return
    end

    local dx = px - lastSampleX
    local dy = py - lastSampleY
    local dist = math.sqrt((dx * dx) + (dy * dy))

    if dist >= SAMPLE_DISTANCE then
        addTrailPoint(mapX, mapY)
        lastSampleX = px
        lastSampleY = py
    end
end)

local chatEvents = {
    CHAT_MESSAGE = function(channel, relation, name, message, info)
        if name ~= X2Unit:UnitName("player") then
            return
        end
        if string.sub(message, 1, 1) ~= "!" then
            return
        end

        local command = string.match(message, "!(%w+)")
        if command == "routehelp" then
            X2Chat:DispatchChatMessage(CMF_SYSTEM, "!routehelp !routeclear !routescale <n> !routeangle <-180..180>")
        elseif command == "routeclear" then
            clearTrail()
            X2Chat:DispatchChatMessage(CMF_SYSTEM, "Route trail cleared")
        elseif command == "routescale" then
            local arg = string.match(message, "!%w+%s+([%d%.]+)")
            local s = tonumber(arg)
            if s and s > 0 then
                routeScale = s
                saveWindowState()
                X2Chat:DispatchChatMessage(CMF_SYSTEM, string.format("Route scale set to %.3f", routeScale))
            else
                X2Chat:DispatchChatMessage(CMF_SYSTEM, "Usage: !routescale 0.01+")
            end
        elseif command == "routeangle" then
            local arg = string.match(message, "!%w+%s+(-?%d+)")
            local a = tonumber(arg)
            if a and a >= -180 and a <= 180 then
                angleOffsetDeg = a
                saveWindowState()
                X2Chat:DispatchChatMessage(CMF_SYSTEM, string.format("Route angle offset set to %d", angleOffsetDeg))
            else
                X2Chat:DispatchChatMessage(CMF_SYSTEM, "Usage: !routeangle -180..180")
            end
        end
    end,
}

local listener = CreateEmptyWindow("routeHistoryChatListener", "UIParent")
listener:Show(false)
listener:SetHandler("OnEvent", function(this, event, ...)
    chatEvents[event](...)
end)
for key, _ in pairs(chatEvents) do
    listener:RegisterEvent(key)
end

X2Chat:DispatchChatMessage(CMF_SYSTEM, "Route History Tracker loaded. Click map to set start point. !routehelp")
