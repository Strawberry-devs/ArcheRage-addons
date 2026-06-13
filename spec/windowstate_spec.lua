-- Tests for globals/windowstate.lua
--
-- WindowState is the first addon module whose interface is independent of the
-- live ArcheRage UI API, so it is the first thing the project can test headless.
-- LoadPosition/SavePosition use real temp files; the visibility helpers and
-- TrackPosition are exercised against lightweight mocks of ADDON and a window.

local function tmpPath()
	local path = os.tmpname()
	-- os.tmpname may create the file; start from a clean slate for each test.
	os.remove(path)
	return path
end

describe("WindowState", function()
	setup(function()
		dofile("globals/windowstate.lua")
	end)

	describe("LoadPosition", function()
		it("returns the supplied defaults when the file is missing", function()
			local x, y = WindowState.LoadPosition("/does/not/exist.txt", 12, 34)
			assert.equals(12, x)
			assert.equals(34, y)
		end)

		it("defaults to 0,0 when no defaults are supplied", function()
			local x, y = WindowState.LoadPosition("/does/not/exist.txt")
			assert.equals(0, x)
			assert.equals(0, y)
		end)

		it("falls back to defaults on malformed contents", function()
			local path = tmpPath()
			local f = io.open(path, "w")
			f:write("not a coordinate")
			f:close()

			local x, y = WindowState.LoadPosition(path, 7, 8)
			assert.equals(7, x)
			assert.equals(8, y)
			os.remove(path)
		end)
	end)

	describe("SavePosition / LoadPosition round-trip", function()
		it("preserves a saved position", function()
			local path = tmpPath()
			assert.is_true(WindowState.SavePosition(path, 100, 250))

			local x, y = WindowState.LoadPosition(path)
			assert.equals(100, x)
			assert.equals(250, y)
			os.remove(path)
		end)

		it("restores negative offsets (regression: old %d+ pattern reset them to 0,0)", function()
			local path = tmpPath()
			WindowState.SavePosition(path, -40, -5)

			local x, y = WindowState.LoadPosition(path)
			assert.equals(-40, x)
			assert.equals(-5, y)
			os.remove(path)
		end)

		it("floors fractional offsets", function()
			local path = tmpPath()
			WindowState.SavePosition(path, 10.9, 20.1)

			local x, y = WindowState.LoadPosition(path)
			assert.equals(10, x)
			assert.equals(20, y)
			os.remove(path)
		end)
	end)

	describe("visibility", function()
		before_each(function()
			local store = {}
			_G.ADDON = {
				SaveData = function(_, key, value)
					store[key] = value
				end,
				LoadData = function(_, key)
					return store[key]
				end,
				ClearData = function(_, key)
					store[key] = nil
				end,
			}
		end)

		it("defaults to shown (true) when nothing is saved", function()
			assert.is_true(WindowState.LoadVisibility("widget"))
		end)

		it("honours an explicit default when nothing is saved", function()
			assert.is_false(WindowState.LoadVisibility("widget", false))
		end)

		it("round-trips a saved visibility", function()
			WindowState.SaveVisibility("widget", false)
			assert.is_false(WindowState.LoadVisibility("widget"))

			WindowState.SaveVisibility("widget", true)
			assert.is_true(WindowState.LoadVisibility("widget"))
		end)
	end)

	describe("TrackPosition", function()
		it("anchors at the loaded position and persists on drag stop", function()
			local path = tmpPath()
			WindowState.SavePosition(path, 60, 70)

			local handlers = {}
			local anchored
			local fakeWindow = {
				AddAnchor = function(_, point, relativeTo, x, y)
					anchored = { point, relativeTo, x, y }
				end,
				SetHandler = function(_, name, fn)
					handlers[name] = fn
				end,
				StartMoving = function() end,
				StopMovingOrSizing = function() end,
				GetOffset = function()
					return 111, 222
				end,
			}

			WindowState.TrackPosition(fakeWindow, path, 0, 0)

			assert.same({ "TOPLEFT", "UIParent", 60, 70 }, anchored)
			assert.is_function(handlers.OnDragStart)
			assert.is_function(handlers.OnDragStop)

			-- Simulate the user dragging the window to a new spot.
			handlers.OnDragStop(fakeWindow)

			local x, y = WindowState.LoadPosition(path)
			assert.equals(111, x)
			assert.equals(222, y)
			os.remove(path)
		end)
	end)
end)
