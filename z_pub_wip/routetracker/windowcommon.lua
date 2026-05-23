
WINDOW_WIDTH_300 = 1
WINDOW_WIDTH_350 = 2
WINDOW_WIDTH_430 = 3
WINDOW_WIDTH_450 = 4
WINDOW_WIDTH_510 = 5
WINDOW_WIDTH_600 = 6
WINDOW_WIDTH_680 = 7
WINDOW_WIDTH_800 = 8
WINDOW_WIDTH_900 = 9
WINDOW_WIDTH_1200 = 10

local windowWidths = {
    [WINDOW_WIDTH_300] = 300,
    [WINDOW_WIDTH_350] = 350,
    [WINDOW_WIDTH_430] = 430,
    [WINDOW_WIDTH_450] = 450,
    [WINDOW_WIDTH_510] = 510,
    [WINDOW_WIDTH_600] = 600,
    [WINDOW_WIDTH_680] = 680,
    [WINDOW_WIDTH_800] = 800,
    [WINDOW_WIDTH_900] = 900,
    [WINDOW_WIDTH_1200] = 1200,
}

local function GetWindowWidth(index)
    return windowWidths[index]
end

function SettingWindowSkin(window)
    local width = math.floor(window:GetWidth() + 0.5)
    local height = math.floor(window:GetHeight() + 0.5)
    local inset = {
        [GetWindowWidth(WINDOW_WIDTH_300)] = 4,
        [GetWindowWidth(WINDOW_WIDTH_350)] = 4,
        [GetWindowWidth(WINDOW_WIDTH_430)] = 6,
        [GetWindowWidth(WINDOW_WIDTH_450)] = 6,
        [GetWindowWidth(WINDOW_WIDTH_510)] = 7,
        [GetWindowWidth(WINDOW_WIDTH_600)] = 8,
        [GetWindowWidth(WINDOW_WIDTH_680)] = 9,
        [GetWindowWidth(WINDOW_WIDTH_800)] = 12,
        [GetWindowWidth(WINDOW_WIDTH_900)] = 14,
        [GetWindowWidth(WINDOW_WIDTH_1200)] = 20,
    }

    local invalidInset = -20
    local anchorValue = invalidInset
    if (inset[width] ~= nil) then
        anchorValue = inset[width]
    end

    if anchorValue == invalidInset then
        X2Util:RaiseLuaCallStack(string.format("invalid width - %d", width))
    end

    if window.titleBar ~= nil then
        window.titleBar:SetTitleInset(0, 0, 0, 10)
    end

    local coordSize
    local adjustSize = false
    if width < 680 then
        coordSize = 'small'

        if height <= 249 then
            adjustSize = true
        end
    else
        coordSize = 'big'

        if height <= 331 then
            adjustSize = true
        end
    end

    -- bg_top_small, bg_bottom_small_left, bg_bottom_small_right
    -- bg_top_big, bg_bottom_big_left, bg_bottom_big_right
    local upperCoords = UIParent:GetTextureData("ui/common/default.dds", string.format("bg_top_%s", coordSize))["coords"]
    local lowerCoords_l = UIParent:GetTextureData("ui/common/default.dds", string.format("bg_bottom_%s_left", coordSize))["coords"]
    local lowerCoords_r = UIParent:GetTextureData("ui/common/default.dds", string.format("bg_bottom_%s_right", coordSize))["coords"]

    if adjustSize == true then
        local temp_value = math.floor((height / 2) + 0.5) + 55

        upperCoords[4] = temp_value

        lowerCoords_l[2] = lowerCoords_l[2] + lowerCoords_l[4] - temp_value
        lowerCoords_l[4] = temp_value

        lowerCoords_r[2] = lowerCoords_r[2] + lowerCoords_r[4] - temp_value
        lowerCoords_r[4] = temp_value
    end

    local path = "ui/common/default.dds"
    if window.colorTexture == nil then
        window.colorTexture = window:CreateDrawable(path, "window_color_texture_bg", "background")
        window.colorTexture:AddAnchor("TOPLEFT", window, 0, 0)
        window.colorTexture:AddAnchor("BOTTOMRIGHT", window, 0, 0)
    end

    if window.upperTexture == nil then
        window.upperTexture = window:CreateImageDrawable(path, "background")
        window.upperTexture:SetCoords(upperCoords[1], upperCoords[2], upperCoords[3], upperCoords[4])
        window.upperTexture:SetHeight(upperCoords[4]) 
        window.upperTexture:AddAnchor("TOPLEFT", window, -anchorValue, -11)
        window.upperTexture:AddAnchor("TOPRIGHT", window, anchorValue, -11)
    else
        window.upperTexture:SetCoords(upperCoords[1], upperCoords[2], upperCoords[3], upperCoords[4])
        window.upperTexture:SetHeight(upperCoords[4]) 
        window.upperTexture:RemoveAllAnchors()
        window.upperTexture:AddAnchor("TOPLEFT", window, -anchorValue, -11)
        window.upperTexture:AddAnchor("TOPRIGHT", window, anchorValue, -11)
    end

    if window.lowerTexture_left == nil then
        window.lowerTexture_left = window:CreateImageDrawable(path, "background")
        window.lowerTexture_left:SetCoords(lowerCoords_l[1], lowerCoords_l[2], lowerCoords_l[3], lowerCoords_l[4])
        window.lowerTexture_left:SetExtent(width / 2 + anchorValue, lowerCoords_l[4])
        window.lowerTexture_left:AddAnchor("BOTTOMLEFT", window, -anchorValue, 11)
    else
        window.lowerTexture_left:SetCoords(lowerCoords_l[1], lowerCoords_l[2], lowerCoords_l[3], lowerCoords_l[4])
        window.lowerTexture_left:SetExtent(width / 2 + anchorValue, lowerCoords_l[4])
        window.lowerTexture_left:RemoveAllAnchors()
        window.lowerTexture_left:AddAnchor("BOTTOMLEFT", window, -anchorValue, 11)
    end
 
    if window.lowerTexture_right == nil then
        window.lowerTexture_right = window:CreateImageDrawable(path, "background")
        window.lowerTexture_right:SetCoords(lowerCoords_r[1], lowerCoords_r[2], lowerCoords_r[3], lowerCoords_r[4])
        window.lowerTexture_right:SetExtent(width / 2 + anchorValue, lowerCoords_r[4])
        window.lowerTexture_right:AddAnchor("BOTTOMRIGHT", window, anchorValue, 11)
    else
        window.lowerTexture_right:SetCoords(lowerCoords_r[1], lowerCoords_r[2], lowerCoords_r[3], lowerCoords_r[4])
        window.lowerTexture_right:SetExtent(width / 2 + anchorValue, lowerCoords_r[4])
        window.lowerTexture_right:RemoveAllAnchors()
        window.lowerTexture_right:AddAnchor("BOTTOMRIGHT", window, anchorValue, 11)
    end
end

function SetWindowUIAnimation(window)
    local time = 0.1
    window:SetAlphaAnimation(0.0, 1.0, time, time)
end

function CreateBaseWindow(id, parent, category, useTitleBar, showInHud)
    if category == nil then
        category = ""
    end

    local window = UIParent:CreateWidget("window", id, parent, category)
    window:Show(false)

    if useTitleBar then
        local titleBar = CreateTitleBar("titleBar", window, showInHud)
        window.titleBar = titleBar

        function window:SetTitle(text)
            titleBar:SetTitleText(text)
        end

        InitForStackInWindow(window)
    end

    local persmissionHandler = {
        ["system_message"] = function (v)
            AddMessageToSysMsgWindow(v)
        end
    }
    
    local function OnPermissionChanged(self, infos)
        for k, v in pairs(infos) do
            if (persmissionHandler[k]) ~= nil then
                persmissionHandler[k](v)
            end
        end
    end
    window:SetHandler("OnPermissionChanged", OnPermissionChanged)

    return window
end
