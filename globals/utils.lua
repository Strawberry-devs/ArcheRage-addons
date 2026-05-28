---------------- Original Author: Gryz -----------------
----------------- Discord: grace.dev -------------------
--------------- Additions by Strawberry ----------------
----------------- Discord: exec.noir -------------------

local buttonSkinInset = { left = 11, right = 11, top = 0, bottom = 0 }

local color = {
	normal = UIParent:GetFontColor("btn_df"),
	highlight = UIParent:GetFontColor("btn_ov"),
	pushed = UIParent:GetFontColor("btn_on"),
	disabled = UIParent:GetFontColor("btn_dis"),
}

function CreateSkin(path, coordsKey, fontColor, inset)
	return {
		drawableType = "ninePart",
		path = path,
		coordsKey = coordsKey,
		autoResize = true,
		fontColor = fontColor or color,
		fontInset = inset or { left = 0, right = 0, top = 0, bottom = 0 },
	}
end

local function ApplyMouseHandlers(widget, handlers)
	for event, fn in pairs(handlers) do
		widget:SetHandler(event, fn)
	end
end

function CreateActionButton(config)
	local btn = config.parent:CreateChildWidget("button", config.name, 1, true)
	btn:AddAnchor(config.anchor, config.anchorTarget, config.offsetX, config.offsetY)
	btn:SetText(config.text or "")
	btn:SetStyle("text_default")
	--Apply-ButtonSkin(btn, config.skin)
	ApplyMouseHandlers(btn, config.handlers or {})
	btn:SetExtent(config.width, config.height)
	return btn
end

function CreateBasicWindow(id, windowTitle, width, height, positionReference, positionX, positionY)
	local closebtnskin = CreateSkin("ui/common/default.dds", "btn_close", color)

	local window = CreateEmptyWindow(id, "UIParent")
	window:AddAnchor(positionReference, positionX, positionY)
	window:SetExtent(width or 700, height or 700)
	window:EnableDrag(true)
	window:Clickable(true)
	window:SetCloseOnEscape(true)

	local title = window:CreateChildWidget("label", id .. "_title", 0, false)
	title:SetText(windowTitle)
	title:AddAnchor("TOP", window, 0, 20)
	title.style:SetAlign(ALIGN_CENTER)

	if isUserDarkMode() then
		title.style:SetColor(184 / 255, 208 / 255, 229 / 255, 1)
	else
		title.style:SetColor(102 / 255, 64 / 255, 11 / 255, 1)
	end

	title.style:SetFontSize(20)

	CreateActionButton({
		parent = window,
		name = id .. "_closeViewer",
		anchor = "TOPRIGHT",
		anchorTarget = window,
		offsetX = 0,
		offsetY = 0,
		skin = closebtnskin,
		width = 44,
		height = 38,
		handlers = {
			OnClick = function()
				window:Show(false)
			end,
		},
	})

	window:SetHandler("OnShow", function()
		if window.ShowProc then
			window:ShowProc()
		end
		SettingWindowSkin(window)
		window:SetStartAnimation(true, true)
	end)

	window:SetHandler("OnDragStart", function(self)
		self:StartMoving()
		self.moving = true
	end)
	return window
end

function isUserDarkMode() -- By Noir <3
	local isDarkMode = false
	local commonFilePath = "../Documents/Addon/ui/common/default.g"
	local commonFile = io.open(commonFilePath, "r")
	--no file = standard UI
	if not commonFile then
		return isDarkMode
	end

	--skip to line 6
	local line
	for i = 1, 6 do
		line = commonFile:read("*l")
		if not line then
			break
		end
	end
	commonFile:close()

	if line then
		--X2Chat:DispatchChatMessage(CMF_SYSTEM, line)
		if line:find("bg_01%s*%(%s*15,%s*22,%s*29,%s*255%s*%)") then
			isDarkMode = true
		end
	end
	return isDarkMode
end
