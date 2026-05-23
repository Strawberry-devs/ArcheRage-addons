-- 9
function CreateTitleBar(id, parent, showInHud)
    local title = SetViewOfTitleBar(id, parent, showInHud)
    title:EnableDrag(true)
    
    local function AddCloseEvent(button, parent)
        local function OnClick(self, arg)
            if arg == "RightButton" then
                return
            end

            if self.Init ~= nil then
                self:Init()
            end

            if parent.OnClose ~= nil then
                parent:OnClose()
            end            
            parent:Show(false)
        end
        button:SetHandler("OnClick", OnClick)
    end    
    AddCloseEvent(title.closeButton, parent)
    
    local function OnDragStart()
        parent:StartMoving()

        return true
    end
    title:SetHandler("OnDragStart", OnDragStart)

    local function OnDragStop()
        parent:StopMovingOrSizing()
    end
    title:SetHandler("OnDragStop", OnDragStop)

    function title:HideCloseButton()
        self.closeButton:Show(false)
    end

    return title
end

function CreateEmptyWindow(id, parent, category)
    local window = CreateBaseWindow(id, parent, category, false)
    window.titleStyle:SetColorByKey("white")
    window.titleStyle:SetSnap(true)

    function window:EnableUIAnimation()
        SetWindowUIAnimation(self)
        self:ReleaseHandler("OnShow")
        
        function self:OnShow()
            self:SetStartAnimation(true, true)
            
            if self.ShowProc ~= nil then
                self:ShowProc()
            end
        end
        self:SetHandler("OnShow", self.OnShow)
    end
    
    function window:OnShow()
        if self.ShowProc ~= nil then
            self:ShowProc()
        end
    end
    window:SetHandler("OnShow", window.OnShow)
        
    return window
end

function InitForStackInWindow(window)
    if window.titleBar == nil then
        return
    end

    local moduleTypeStr = "moduleType"
    local widgetStr = "widget"
    local keyStr = "key"

    local stack = {}
    local defaultHeight = 165

    local function Find(key)
        for i, v in ipairs(stack) do
            if v[keyStr] == key then
                return true
            end
        end

        return false
    end
    
    function window:RegisterStack(widget, offset)
        local stackCount = #stack

        local moduleType = nil
        if widget.GetModuleType ~= nil then
            moduleType = widget:GetModuleType()
        end

        local key = widget:GetId()

        local calcOffset = offset or 0
        if stackCount == 0 then
            widget:AddAnchor("TOP", window, 0, (self.titleBar:GetHeight() + 5) + calcOffset)
        else
            if Find(key) then
                UIParent:DevLog(string.format("[window stack system] the widget is already added. check please, widget name: %s", widget:GetName()))
                return widget
            end

            local prevStackInfo = stack[#stack]
            if moduleType ~= nil and prevStackInfo[moduleTypeStr] ~= nil and calcOffset == 0 then
                calcOffset = W_MODULE:AnchorOffset(moduleType, prevStackInfo[moduleTypeStr])
            end

            widget:AddAnchor("TOP", prevStackInfo[widgetStr], "BOTTOM", 0, calcOffset)
        end

        table.insert(stack, {
            [moduleTypeStr] = moduleType,
            [widgetStr] = widget,
            [keyStr] = key,
        })

        return widget
    end

    function window:FooterStackGap()
        return 20
    end

    function window:BottomInset()
        return MARGIN.WINDOW_SIDE
    end

    function window:GetAutoHeightByStack(ignoreDefault)
        if #stack == 0 then
            return defaultHeight
        end

        local _, yOffset = F_LAYOUT.GetExtentWidgets(self.titleBar, stack[#stack][widgetStr])

        local bottomInset = window:BottomInset()
        local height = yOffset + bottomInset
        local lastStackWidget = stack[#stack][widgetStr]

        if ignoreDefault ~= true and height < defaultHeight then
            height = defaultHeight

            lastStackWidget:RemoveAllAnchors()
            lastStackWidget:AddAnchor("BOTTOM", window, 0, -bottomInset)
        else
            if stack[#stack][moduleTypeStr] == W_MODULE.TYPES.BUTTON_SET then
                lastStackWidget:RemoveAllAnchors()
                lastStackWidget:AddAnchor("TOP", stack[#stack - 1][widgetStr], "BOTTOM", 0, self:FooterStackGap())

                _, yOffset = F_LAYOUT.GetExtentWidgets(self.titleBar, stack[#stack][widgetStr], true)
                height = yOffset + bottomInset
            end
        end

        return height
    end

    function window:ApplyAutoHeightByStack(ignoreDefault)
        if ignoreDefault == nil then
            ignoreDefault = false
        end

        self:SetHeight(self:GetAutoHeightByStack(ignoreDefault))
    end
end

function CreateWindow(id, parent, category, tabInfo)
    local window = CreateBaseWindow(id, parent, category, true, false)
    window:SetSounds("dialog_common")
    window:SetCloseOnEscape(true)

    SetWindowUIAnimation(window)
    W_MODULE:InitForManagement(window)

    local function OnShow()
        if window.ShowProc ~= nil then
            window:ShowProc()
        end
        
        SettingWindowSkin(window)
        window:SetStartAnimation(true, true)
    end
    window:SetHandler("OnShow", OnShow)

    if tabInfo ~= nil then
        local tabListTitles = {}
        local tabListInfo = {}
        for i = 1, #tabInfo do
            if tabInfo[i].validationCheckFunc() then
                table.insert(tabListTitles, tabInfo[i].title)
                table.insert(tabListInfo, tabInfo[i])
            end
        end
        
        if #tabListTitles > 0 then
            local tab = W_TAB.CreateTab("tab", window)
            tab:AddTabs(tabListTitles)
            
            for i = 1, #tab.window do
                if tabListInfo[i].subWindowConstructor ~= nil then
                    tabListInfo[i].subWindowConstructor(tab.window[i], i)
                end
            end
        end
    end

    return window
end

-- 7
function CreateSubOptionWindow(id, parent)
    local window = SetViewOfSubOptionWindow(id, parent)
    
    function window.closeButton:OnClick()
        if window:IsVisible() then
            window:Show(false)
        end
    end

    window.closeButton:SetHandler("OnClick", window.closeButton.OnClick)

    local function OnClick()
    
    end
    window:SetHandler("OnClick", OnClick)

    return window
end

-- 5
function CreateSplitItemWindow(id, parent)
    local window = SetViewOfSplitItemWindow(id, parent)

    function window:SetEnable(enable)
        self.spinner:SetEnable(enable)
        self:Enable(enable)
    end

    function window:ShowProc()
        self.spinner:SetFocus()
    end

    function window:SetMinMaxValues(_min, max)
        self.spinner:SetMinMaxValues(_min, max)
    end

    local function OnClick()
        if window.SplitProc ~= nil then
            window:SplitProc(window.spinner:GetCurValue())
        end

        window:Show(false)
    end

    window.buttonSet:UpdateButton("ok", {
        ["clickFunc"] = OnClick
    })

    function window.spinner:OnSpinnerEnterPressed()
        OnClick()
    end

    return window
end

-- 2
function CreateCheckGroupWindow(id, parent, info)
    local window = SetViewOfCheckGroupWindow(id, parent, info)
    
    local function GetCheckedAllChild()
        local checkItems = {}
        
        for j = 1, #window.subChecks do
            local button = window.subChecks[j]
            
            checkItems[j] = button:GetChecked()
        end
        
        for i = 1, #checkItems do
            if not checkItems[i] then
                return false
            end
        end

        return true
    end

    for i = 1, #window.checks do
        local button = window.checks[i]
        
        function button:CheckBtnCheckChagnedProc(checked)
            if window.subChecks == nil then
                return
            end 
               
            for j = 1, #window.subChecks do
                window.subChecks[j]:SetChecked(checked)
            end
            
            if window.ChildCheckProcedure ~= nil then
                window:ChildCheckProcedure(self, checked)
            end
        end
    end
    
    for j = 1, #window.subChecks do
        local button = window.subChecks[j]

        function button:CheckBtnCheckChagnedProc(checked)
            self.parentCheck:SetChecked(GetCheckedAllChild(), false)
            
            if window.ChildCheckProcedure ~= nil then
                window:ChildCheckProcedure(self, checked)
            end
        end
    end

    return window
end