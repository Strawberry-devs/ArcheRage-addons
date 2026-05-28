function SetButtonFontOneColor(button, color)
	button:SetTextColor(color[1], color[2], color[3], color[4])
	button:SetPushedTextColor(color[1], color[2], color[3], color[4])
	button:SetHighlightTextColor(color[1], color[2], color[3], color[4])
	button:SetDisabledTextColor(color[1], color[2], color[3], color[4])
end
function SetBGPushed(self, on, color)
	if on == true then
		self.bgs[BUTTON_STATE.NORMAL]:SetVisible(false)
		self.bgs[BUTTON_STATE.HIGHLIGHTED]:SetVisible(false)
		self:SetNormalBackground(self.bgs[BUTTON_STATE.PUSHED])
		self:SetHighlightBackground(self.bgs[BUTTON_STATE.PUSHED])
		-- self:SetInset(0, 2, 0, 0)

		if color ~= nil then
			self:SetTextColor(color.pushed[1], color.pushed[2], color.pushed[3], color.pushed[4])
			self:SetHighlightTextColor(color.pushed[1], color.pushed[2], color.pushed[3], color.pushed[4])
		end
	else
		self:SetNormalBackground(self.bgs[BUTTON_STATE.NORMAL])
		self:SetHighlightBackground(self.bgs[BUTTON_STATE.HIGHLIGHTED])
		-- self:SetInset(0, 0, 0, 0)

		if color ~= nil then
			self:SetTextColor(color.normal[1], color.normal[2], color.normal[3], color.normal[4])
			self:SetHighlightTextColor(color.highlight[1], color.highlight[2], color.highlight[3], color.highlight[4])
		end
	end
end

function SetBGHighlighted(self, on, color)
	if on == true then
		self.bgs[BUTTON_STATE.NORMAL]:SetVisible(false)
		self:SetNormalBackground(self.bgs[BUTTON_STATE.HIGHLIGHTED])

		if color ~= nil then
			self:SetTextColor(color.highlight[1], color.highlight[2], color.highlight[3], color.highlight[4])
			self:SetHighlightTextColor(color.highlight[1], color.highlight[2], color.highlight[3], color.highlight[4])
		end
	else
		self:SetNormalBackground(self.bgs[BUTTON_STATE.NORMAL])

		if color ~= nil then
			self:SetTextColor(color.normal[1], color.normal[2], color.normal[3], color.normal[4])
			self:SetHighlightTextColor(color.highlight[1], color.highlight[2], color.highlight[3], color.highlight[4])
		end
	end
end

function SetBGHighlighted_table(self, on, button_style_table)
	local fontColor = button_style_table[1].fontColor

	SetBGHighlighted(self, on, fontColor)

	if self.add_bgs1 ~= nil then
		local coords = button_style_table[2].coords

		if on == true then
			self.add_bgs1[BUTTON_STATE.NORMAL]:SetCoords(coords.over[1], coords.over[2], coords.over[3], coords.over[4]) -- #273524 BUTTON, TODO
		else
			self.add_bgs1[BUTTON_STATE.NORMAL]:SetCoords(
				coords.normal[1],
				coords.normal[2],
				coords.normal[3],
				coords.normal[4]
			)
		end
	end

	if self.add_bgs2 ~= nil then
		local coords = button_style_table[3].coords

		if on == true then
			self.add_bgs2[BUTTON_STATE.NORMAL]:SetCoords(coords.over[1], coords.over[2], coords.over[3], coords.over[4])
		else
			self.add_bgs2[BUTTON_STATE.NORMAL]:SetCoords(
				coords.normal[1],
				coords.normal[2],
				coords.normal[3],
				coords.normal[4]
			)
		end
	end
end
--------------------------------------------------------------------------------------------------------------------------
function ButtonInit(button)
	button:EnableDrawables("background")
	button.style:SetShadow(false)

	SetButtonFontColor(button, GetButtonDefaultFontColor())
end
--------------------------------------------------------------------------------------------------------------------------
function SetViewOfEmptyButton(id, parent)
	local button = UIParent:CreateWidget("button", id, parent)
	button.style:SetSnap(true)

	SetButtonFontColor(button, GetButtonDefaultFontColor())

	return button
end

function CreateEmptyButton(id, parent)
	local button = SetViewOfEmptyButton(id, parent)

	return button
end
--------------------------------------------------------------------------------------------------------------------------
function SetButtonBackground(button)
	button:SetNormalBackground(button.bgs[1])
	button:SetHighlightBackground(button.bgs[2])
	button:SetPushedBackground(button.bgs[3])
	button:SetDisabledBackground(button.bgs[4])

	if button.bgs[5] ~= nil then
		button:SetCheckedBackground(button.bgs[5])
	end

	if button.bgs[6] ~= nil then
		button:SetDisabledCheckedBackground(button.bgs[6])
	end
end

ICON_BUTTON_OVERLAY_COLOR = {
	NONE = 1,
	BLACK = 2,
	YELLOW = 3,
	RED = 4,
}
