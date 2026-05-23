-------------- Cannon Cone Demo --------------
-- Draws a low-resolution dotted cone (~130m) on the player's right side.

if API_TYPE == nil then
    ADDON:ImportAPI(8)
    X2Chat:DispatchChatMessage(CMF_SYSTEM, "Globals folder not found. Please install it at https://github.com/Schiz-n/ArcheRage-addons/tree/master/globals")
    return
end

ADDON:ImportObject(OBJECT_TYPE.TEXT_STYLE)
ADDON:ImportObject(OBJECT_TYPE.BUTTON)
ADDON:ImportObject(OBJECT_TYPE.DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.NINE_PART_DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.COLOR_DRAWABLE)
ADDON:ImportObject(OBJECT_TYPE.WINDOW)
ADDON:ImportObject(OBJECT_TYPE.LABEL)
ADDON:ImportObject(OBJECT_TYPE.EMPTY_WIDGET)
ADDON:ImportAPI(API_TYPE.CHAT.id)
ADDON:ImportAPI(API_TYPE.UNIT.id)

local coneRadius = 130
local coneHalfAngleDeg = 35
local ringStep = 11
local arcStepDeg = 6
local baseZOffset = 1.0
local maxViewDistance = 20000

local coneEnabled = true
local flipSide = false
local facingMode = "angle"
local lastForwardX = 1
local lastForwardY = 0
local angleMapIndex = 1
local angleMapDebugPrinted = false
local angleDebugElapsed = 0
local angleDebugIntervalMs = 1000
local angleOffsetDeg = 0

local coneFrozen = false
local frozenX = nil
local frozenY = nil
local frozenZ = nil
local frozenAngle = nil

local dotWorldOffsets = {}
local dotWidgets = {}
local freezeButton = nil

local updateWidget = UIParent:CreateWidget("emptywidget", "cannonConeUpdater", "UIParent", "")
updateWidget:Show(true)

local function ProjectWorldToScreen(worldX, worldY, worldZ)
    if ConvertWorldToScreen ~= nil then
        local sx, sy, sz = ConvertWorldToScreen(worldX, worldY, worldZ)
        if sx ~= nil and sy ~= nil and sz ~= nil then
            return sx, sy, sz
        end
    end
    return WorldToScreen(worldX, worldY, worldZ)
end

local function BuildConeOffsets()
    dotWorldOffsets = {}

    local angleColumns = {}
    local a = -coneHalfAngleDeg
    while a <= coneHalfAngleDeg + 0.0001 do
        angleColumns[#angleColumns + 1] = a
        a = a + arcStepDeg
    end

    local leftColumnsToSkip = 2
    for col = 1 + leftColumnsToSkip, #angleColumns do
        a = angleColumns[col]
        local radA = math.rad(a)
        local r = ringStep
        while r <= coneRadius + 0.0001 do
            local x = r * math.cos(radA)
            local y = r * math.sin(radA)
            dotWorldOffsets[#dotWorldOffsets + 1] = {x = x, y = y}
            r = r + ringStep
        end
    end

    -- Boundary emphasis only on the right edge (left-most two columns removed).
    local function addBoundary(angleDeg)
        local rad = math.rad(angleDeg)
        local r = 0
        while r <= coneRadius + 0.0001 do
            dotWorldOffsets[#dotWorldOffsets + 1] = {
                x = r * math.cos(rad),
                y = r * math.sin(rad)
            }
            r = r + (ringStep * 0.9)
        end
    end

    addBoundary(coneHalfAngleDeg)
end

local function EnsureDotWidgets()
    for i = 1, #dotWorldOffsets do
        if dotWidgets[i] == nil then
            local container = CreateEmptyWindow("cannonConeDotContainer_" .. i, "UIParent")
            container:Show(true)
            container:Enable(true)
            container:AddAnchor("TOPLEFT", "UIParent", 0, 0)

            local label = container:CreateChildWidget("label", "cannonConeDotLabel_" .. i, 0, true)
            label:SetText(".")
            label:Show(true)
            label:EnablePick(false)
            label.style:SetFontSize(20)
            label.style:SetColor(1, 0.2, 0.2, 1.0)
            label.style:SetOutline(true)
            label.style:SetAlign(ALIGN_CENTER)
            label:SetExtent(40, 30)
            label:AddAnchor("CENTER", container, 0, 0)

            dotWidgets[i] = {container = container, label = label}
        end
    end

    for i = #dotWorldOffsets + 1, #dotWidgets do
        if dotWidgets[i] and dotWidgets[i].container then
            dotWidgets[i].container:Show(false)
        end
    end
end

local function HideAllDots()
    for i = 1, #dotWidgets do
        if dotWidgets[i] and dotWidgets[i].container then
            dotWidgets[i].container:Show(false)
        end
    end
end

local function ForwardFromAngle(angle)
    local adjusted = angle + math.rad(angleOffsetDeg)
    local candidates = {
        { x = math.cos(adjusted),  y = math.sin(adjusted)  },
        { x = math.sin(adjusted),  y = math.cos(adjusted)  },
        { x = -math.cos(adjusted), y = -math.sin(adjusted) },
        { x = -math.sin(adjusted), y = -math.cos(adjusted) },
    }
    local c = candidates[angleMapIndex]
    return c.x, c.y
end

local function ToggleFreezeCone()
    if coneFrozen then
        coneFrozen = false
        frozenX, frozenY, frozenZ, frozenAngle = nil, nil, nil, nil
        X2Chat:DispatchChatMessage(CMF_SYSTEM, "Cone unfrozen")
        return
    end

    local px, py, pz, angle = X2Unit:GetUnitWorldPositionByTarget("player", true)
    if not px or not py or not pz then
        X2Chat:DispatchChatMessage(CMF_SYSTEM, "Could not freeze cone (no player position)")
        return
    end
    coneFrozen = true
    frozenX, frozenY, frozenZ, frozenAngle = px, py, pz, angle
    X2Chat:DispatchChatMessage(CMF_SYSTEM, "Cone frozen in world space")
end

local function CreateFreezeButton()
    if freezeButton ~= nil then
        return
    end
    freezeButton = CreateSimpleButton("Freeze Cone", 700, -300)
    function freezeButton.OnClick()
        ToggleFreezeCone()
    end
    freezeButton:SetHandler("OnClick", freezeButton.OnClick)
end

function updateWidget:OnUpdate(dt)
    angleDebugElapsed = angleDebugElapsed + dt
    if not coneEnabled then
        HideAllDots()
        return
    end

    local px, py, pz, angle
    if coneFrozen then
        px, py, pz, angle = frozenX, frozenY, frozenZ, frozenAngle
    else
        px, py, pz, angle = X2Unit:GetUnitWorldPositionByTarget("player", true)
    end
    if not px or not py or not pz then
        HideAllDots()
        return
    end

    local fx, fy = lastForwardX, lastForwardY

    -- Preferred: server-facing angle from GetUnitWorldPositionByTarget.
    if angle ~= nil then
        if not angleMapDebugPrinted then
            X2Chat:DispatchChatMessage(CMF_SYSTEM, string.format("Cannon cone: received unit angle=%.4f rad", angle))
            angleMapDebugPrinted = true
        end
        fx, fy = ForwardFromAngle(angle)
        facingMode = "angle"
    end

    local flen = math.sqrt((fx * fx) + (fy * fy))
    if flen < 0.0001 then
        HideAllDots()
        return
    end
    fx, fy = fx / flen, fy / flen
    lastForwardX, lastForwardY = fx, fy

    if angle ~= nil and angleDebugElapsed >= angleDebugIntervalMs then
        X2Chat:DispatchChatMessage(
            CMF_SYSTEM,
            string.format(
                "[Cone DEBUG] angle=%.4f rad (%.1f deg) map=%d offset=%d forward=(%.3f, %.3f) mode=%s flip=%s frozen=%s",
                angle,
                math.deg(angle),
                angleMapIndex,
                angleOffsetDeg,
                fx,
                fy,
                facingMode,
                tostring(flipSide),
                tostring(coneFrozen)
            )
        )
        angleDebugElapsed = 0
    elseif angle == nil and angleDebugElapsed >= angleDebugIntervalMs then
        X2Chat:DispatchChatMessage(CMF_SYSTEM, "[Cone DEBUG] angle=nil (no 4th return value)")
        angleDebugElapsed = 0
    end

    -- Horizontal right vector from forward. Flip command swaps side instantly.
    local rx = fy
    local ry = -fx
    if flipSide then
        rx = -rx
        ry = -ry
    end

    -- Up-cone direction uses "right side" as center line.
    local cx = rx
    local cy = ry

    -- Perpendicular in ground plane for angular spread.
    local sx = -cy
    local sy = cx

    for i = 1, #dotWorldOffsets do
        local dot = dotWidgets[i]
        local off = dotWorldOffsets[i]

        local wx = px + (cx * off.x) + (sx * off.y)
        local wy = py + (cy * off.x) + (sy * off.y)
        local wz = pz + baseZOffset

        local screenX, screenY, depth = ProjectWorldToScreen(wx, wy, wz)
        if screenX and screenY and depth and depth > 0 and depth <= maxViewDistance then
            dot.container:AddAnchor("TOPLEFT", "UIParent", math.floor(screenX + 0.5), math.floor(screenY + 0.5))
            dot.container:Show(true)
        else
            dot.container:Show(false)
        end
    end
end
updateWidget:SetHandler("OnUpdate", updateWidget.OnUpdate)

local chatEvents = {
    CHAT_MESSAGE = function(channel, relation, name, message, info)
        if name ~= X2Unit:UnitName("player") then
            return
        end
        if string.sub(message, 1, 1) ~= "!" then
            return
        end

        local command = string.match(message, "!(%w+)")
        if command == "conehelp" then
            X2Chat:DispatchChatMessage(CMF_SYSTEM, "=== Cannon Cone Commands ===")
            X2Chat:DispatchChatMessage(CMF_SYSTEM, "!conehelp - Show commands")
            X2Chat:DispatchChatMessage(CMF_SYSTEM, "!coneon - Show cone")
            X2Chat:DispatchChatMessage(CMF_SYSTEM, "!coneoff - Hide cone")
            X2Chat:DispatchChatMessage(CMF_SYSTEM, "!coneflip - Swap side")
            X2Chat:DispatchChatMessage(CMF_SYSTEM, "!conestatus - Show facing mode/map")
            X2Chat:DispatchChatMessage(CMF_SYSTEM, "!conemap <1-4> - Set angle mapping")
            X2Chat:DispatchChatMessage(CMF_SYSTEM, "!coneoffset <-180..180> - Rotate cone basis")
            X2Chat:DispatchChatMessage(CMF_SYSTEM, "!conefreeze - Toggle freeze in world space")
            X2Chat:DispatchChatMessage(CMF_SYSTEM, "============================")
        elseif command == "coneon" then
            coneEnabled = true
            X2Chat:DispatchChatMessage(CMF_SYSTEM, "Cannon cone enabled")
        elseif command == "coneoff" then
            coneEnabled = false
            X2Chat:DispatchChatMessage(CMF_SYSTEM, "Cannon cone disabled")
        elseif command == "coneflip" then
            flipSide = not flipSide
            X2Chat:DispatchChatMessage(CMF_SYSTEM, string.format("Cannon cone side flipped (%s)", flipSide and "alt" or "default"))
        elseif command == "conestatus" then
            X2Chat:DispatchChatMessage(CMF_SYSTEM, string.format("Cone status: mode=%s angleMap=%d offset=%d flip=%s frozen=%s",
                facingMode, angleMapIndex, angleOffsetDeg, tostring(flipSide), tostring(coneFrozen)))
        elseif command == "conemap" then
            local arg = string.match(message, "!%w+%s+(%d+)")
            local idx = tonumber(arg)
            if idx and idx >= 1 and idx <= 4 then
                angleMapIndex = idx
                X2Chat:DispatchChatMessage(CMF_SYSTEM, string.format("Cannon cone angle map set to %d", angleMapIndex))
            else
                X2Chat:DispatchChatMessage(CMF_SYSTEM, "Usage: !conemap 1|2|3|4")
            end
        elseif command == "coneoffset" then
            local arg = string.match(message, "!%w+%s+(-?%d+)")
            local deg = tonumber(arg)
            if deg and deg >= -180 and deg <= 180 then
                angleOffsetDeg = deg
                X2Chat:DispatchChatMessage(CMF_SYSTEM, string.format("Cone offset set to %d degrees", angleOffsetDeg))
            else
                X2Chat:DispatchChatMessage(CMF_SYSTEM, "Usage: !coneoffset -180..180")
            end
        elseif command == "conefreeze" then
            ToggleFreezeCone()
        end
    end
}

local chatEventListener = CreateEmptyWindow("cannonConeChatListener", "UIParent")
chatEventListener:Show(false)
chatEventListener:SetHandler("OnEvent", function(this, event, ...)
    chatEvents[event](...)
end)

local function RegistUIEvent(window, eventTable)
    for key, _ in pairs(eventTable) do
        window:RegisterEvent(key)
    end
end

BuildConeOffsets()
EnsureDotWidgets()
CreateFreezeButton()
RegistUIEvent(chatEventListener, chatEvents)

X2Chat:DispatchChatMessage(CMF_SYSTEM, string.format("Cannon cone demo loaded (%d dots). !conehelp for commands.", #dotWorldOffsets))
