-------------- Original Author: Strawberry --------------
----------------- Discord: exec_noir --------------------
-- Window state persistence: where a window sits on screen, and whether it is
-- shown or hidden. This absorbs the per-addon file IO, drag wiring, and
-- UI-scale handling that was previously copy-pasted into each addon.
--
-- Position is stored as a "x,y" pair in a per-addon text file. Visibility is
-- stored against an addon-chosen key via ADDON:SaveData.

WindowState = WindowState or {}

-- Reads a saved "x,y" TOPLEFT offset from filePath. Returns defaultX, defaultY
-- (each defaulting to 0) when the file is missing, empty, or malformed.
function WindowState.LoadPosition(filePath, defaultX, defaultY)
	defaultX = defaultX or 0
	defaultY = defaultY or 0

	local file = io.open(filePath, "r")
	if not file then
		return defaultX, defaultY
	end

	local line = file:read("*line")
	file:close()

	if line == nil then
		return defaultX, defaultY
	end

	local x, y = line:match("(%-?%d+),(%-?%d+)")
	if x and y then
		return tonumber(x), tonumber(y)
	end

	return defaultX, defaultY
end

-- Writes a TOPLEFT offset to filePath as "x,y". Returns true on success.
function WindowState.SavePosition(filePath, x, y)
	local file = io.open(filePath, "w")
	if not file then
		return false
	end

	file:write(string.format("%d,%d", math.floor(x or 0), math.floor(y or 0)))
	file:close()
	return true
end

-- Anchors window at its saved position (or the supplied default) and persists
-- the position to filePath whenever the user finishes dragging the window.
-- The window must already have drag enabled (window:EnableDrag(true)).
function WindowState.TrackPosition(window, filePath, defaultX, defaultY)
	local x, y = WindowState.LoadPosition(filePath, defaultX, defaultY)
	window:AddAnchor("TOPLEFT", "UIParent", x, y)

	window:SetHandler("OnDragStart", function(self)
		self:StartMoving()
		self.moving = true
	end)

	window:SetHandler("OnDragStop", function(self)
		self:StopMovingOrSizing()
		self.moving = false
		local offsetX, offsetY = self:GetOffset()
		WindowState.SavePosition(filePath, offsetX or 0, offsetY or 0)
	end)
end

-- Returns the saved shown/hidden state for key, or default (which itself
-- defaults to true) when nothing has been saved yet.
function WindowState.LoadVisibility(key, default)
	local saved = ADDON:LoadData(key)
	if saved ~= nil and saved.shown ~= nil then
		return saved.shown == true
	end

	if default == nil then
		return true
	end
	return default == true
end

-- Persists the shown/hidden state for key.
function WindowState.SaveVisibility(key, shown)
	ADDON:ClearData(key)
	ADDON:SaveData(key, { shown = shown == true })
end
