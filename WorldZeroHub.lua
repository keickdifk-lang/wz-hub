-- Divergence - World // Zero hub bundle
-- boot guard: autoexec and queue_on_teleport can both start a copy right after a teleport;
-- only the first one within 20 seconds runs.
do
	local env = getgenv and getgenv() or _G
	if env.__WZ_BOOT_AT and os.clock() - env.__WZ_BOOT_AT < 20 then return end
	env.__WZ_BOOT_AT = os.clock()
end
local Lumen = (function()
--!nocheck
--[[
	LUMEN - sub-chromatic dark UI library.
	Bottom-lit surfaces, 1px hairline rims, and a single luminous horizon line that marks focus.
	Grotesk text for content, mono caps for labels. Radius 7 (controls) / 14 (panels).

	local Lumen = loadstring(readfile("Lumen.lua"))()
	local Window = Lumen:CreateWindow({
		Title = "Drill Hub",           -- top bar text
		Footer = "Bug Evolution",      -- line under the brand, bottom left (defaults to the game's name)
		Keybind = Enum.KeyCode.RightShift,
		Image = "rbxassetid://...",    -- optional faded picture behind the window
	})

	local Main = Window:AddTab("Main")
	local Farm = Main:AddSection("Auto Farm")                  -- collapsed panel; pass { Open = true } to start open
	Farm:AddToggle("AutoFarm", { Text = "Auto Farm", Default = false, Callback = function(on) end })
		:AddKeybind("AutoFarmKey", { Default = Enum.KeyCode.F })
	Farm:AddSlider("Range", { Text = "Range", Min = 0, Max = 100, Default = 50, Decimals = 0, Suffix = " studs" })
	Farm:AddDropdown("Target", { Text = "Target", Values = { "Nearest", "Weakest" }, Default = "Nearest", Multi = false })
	Farm:AddButton("Teleport", function() end):AddButton("Reset", function() end)
	Farm:AddInput("Name", { Text = "Name", Placeholder = "Name..." })
	Farm:AddColorPicker("Color", { Text = "Color", Default = Color3.new(1, 0, 0) })
	Farm:AddKeybind("Dash", { Text = "Dash", Default = Enum.KeyCode.G, Mode = "Toggle", Callback = function(state) end })
	Farm:AddLabel("Some text")

	Window:AddSettingsTab()
	Lumen:Notify({ Title = "Loaded", Text = "RightShift opens the menu", Duration = 4 })

	Lumen.Flags.AutoFarm  /  Lumen.Options.Range:Set(25)  /  Lumen.Options.Range:OnChanged(fn)  /  Lumen:OnUnload(fn)
]]

local cloneref = cloneref or function(o) return o end
local function svc(name) return cloneref(game:GetService(name)) end
local Players = svc("Players")
local UIS = svc("UserInputService")
local TweenService = svc("TweenService")
local RunService = svc("RunService")
local HttpService = svc("HttpService")
local GuiService = svc("GuiService")
local Marketplace = svc("MarketplaceService")
local Stats = svc("Stats")
local LP = Players.LocalPlayer

-- replace a running copy (and the older YuccaUI / KirkUI builds) instead of stacking menus
for _, key in ipairs({ "__Lumen", "__YuccaUI", "__KirkUI" }) do
	local prev = shared[key]
	if prev and prev.Unload then pcall(prev.Unload, prev) end
end

local V2, UD2, OFF, SCL = Vector2.new, UDim2.new, UDim2.fromOffset, UDim2.fromScale
local AUTO_X, AUTO_Y, AUTO_XY = Enum.AutomaticSize.X, Enum.AutomaticSize.Y, Enum.AutomaticSize.XY
local MB1, TOUCH = Enum.UserInputType.MouseButton1, Enum.UserInputType.Touch
local KP = NumberSequenceKeypoint.new

-- luminance only: void / graphite / panel / slate / hairline / muted / fore / lumen
local DEFAULT = {
	Outline = Color3.fromRGB(32, 35, 41),       -- hairline dividers
	Shadow = Color3.fromRGB(4, 5, 7),
	Text = Color3.fromRGB(240, 242, 246),       -- fore
	Border = Color3.fromRGB(62, 66, 75),        -- rims
	Inline = Color3.fromRGB(13, 13, 19),        -- panel
	InactiveText = Color3.fromRGB(148, 153, 164), -- muted
	Gradient = Color3.fromRGB(70, 210, 255),    -- neon cyan, second colour of every glow
	Background = Color3.fromRGB(6, 6, 10),      -- void
	Element = Color3.fromRGB(22, 22, 31),       -- graphite
	Accent = Color3.fromRGB(168, 120, 255),     -- neon violet, first colour of every glow
}

local function preset(accent, gradient)
	local t = table.clone(DEFAULT)
	t.Accent, t.Gradient = accent, gradient
	return t
end

local function pickFont(enumName, family, weight, fallback)
	local ok = pcall(function() return Enum.Font[enumName] end)
	if ok then return Font.new("rbxasset://fonts/families/" .. family .. ".json", weight) end
	return Font.new("rbxasset://fonts/families/" .. fallback .. ".json", weight)
end

local Lumen = {
	Version = "1.0",
	Folder = "Lumen",
	Flags = {},
	Options = {},
	Unloaded = false,
	AutoSave = false,
	Theme = table.clone(DEFAULT),
	ThemeOrder = { "Outline", "Shadow", "Text", "Border", "Inline", "InactiveText", "Gradient", "Background", "Element", "Accent" },
	ThemeNames = {
		Outline = "Hairline", Text = "Fore", Border = "Rim", Inline = "Panel", InactiveText = "Muted",
		Gradient = "Under-light", Background = "Void", Element = "Graphite", Accent = "Lumen",
	},
	Presets = {
		Divergence = table.clone(DEFAULT),
		Graphite = preset(Color3.fromRGB(232, 232, 234), Color3.fromRGB(200, 200, 206)),
		Aurora = preset(Color3.fromRGB(150, 236, 214), Color3.fromRGB(120, 210, 190)),
		Frost = preset(Color3.fromRGB(150, 205, 255), Color3.fromRGB(120, 170, 240)),
		Iris = preset(Color3.fromRGB(196, 178, 255), Color3.fromRGB(160, 140, 240)),
		Ember = preset(Color3.fromRGB(255, 196, 140), Color3.fromRGB(230, 160, 110)),
	},
	PresetOrder = { "Divergence", "Graphite", "Aurora", "Frost", "Iris", "Ember" },
	Font = pickFont("BuilderSans", "BuilderSans", Enum.FontWeight.Medium, "GothamSSm"),
	BoldFont = pickFont("BuilderSans", "BuilderSans", Enum.FontWeight.Bold, "GothamSSm"),
	Mono = pickFont("RobotoMono", "RobotoMono", Enum.FontWeight.Medium, "SourceSansPro"),
	_reg = {},
	_hooks = {},
	_conns = {},
	_unload = {},
	_binds = {},
}
shared.__Lumen = Lumen

local EASE = Enum.EasingStyle.Quart -- close to cubic-bezier(.15,.83,.66,1)

--------------------------------------------------------------------------------
-- helpers
--------------------------------------------------------------------------------

local function new(class, props)
	local o = Instance.new(class)
	if o:IsA("GuiObject") then o.BorderSizePixel = 0 end
	if o:IsA("TextButton") then o.Text = ""; o.AutoButtonColor = false end
	if o:IsA("TextBox") then o.Text = ""; o.FontFace = Lumen.Font; o.TextSize = 15 end
	if props then
		for k, v in pairs(props) do
			if k ~= "Parent" then o[k] = v end
		end
		if props.Parent then o.Parent = props.Parent end
	end
	return o
end

-- props listed here follow the theme
local function paint(o, map)
	for prop, key in pairs(map) do
		table.insert(Lumen._reg, { o, prop, key })
		o[prop] = Lumen.Theme[key]
	end
	return o
end

-- state-dependent colours redraw through hooks
local function hook(fn)
	table.insert(Lumen._hooks, fn)
	fn(true)
	return fn
end

local function tw(o, t, props, style, dir)
	if not t or t <= 0 then
		for k, v in pairs(props) do o[k] = v end
		return
	end
	local tween = TweenService:Create(o, TweenInfo.new(t, style or EASE, dir or Enum.EasingDirection.Out), props)
	tween:Play()
	return tween
end

local function bind(signal, fn)
	local c = signal:Connect(fn)
	table.insert(Lumen._conns, c)
	return c
end

local function corner(o, r)
	return new("UICorner", { CornerRadius = UDim.new(0, r or 7), Parent = o })
end

local function stroke(o, key, thickness, transparency)
	local s = new("UIStroke", { Thickness = thickness or 1, Transparency = transparency or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = o })
	paint(s, { Color = key })
	return s
end

-- 1px rim, lit from above and fading toward the bottom edge
local function rim(o, key)
	local s = stroke(o, key or "Border")
	new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ KP(0, 0), KP(0.5, 0.45), KP(1, 0.7) }), Parent = s })
	return s
end

-- surface fill. Roblox UIGradients band visibly on dark tones over tall frames, so large
-- surfaces are solid (`lift` = nil); small controls get a short bottom-lit gradient.
local function surface(o, key, lift)
	if not lift then
		paint(o, { BackgroundColor3 = key })
		return
	end
	o.BackgroundColor3 = Color3.new(1, 1, 1)
	local g = new("UIGradient", { Rotation = 90, Parent = o })
	hook(function()
		local th = Lumen.Theme
		local base = th[key]
		g.Color = ColorSequence.new(base, base:Lerp(th.Gradient, lift))
	end)
	return g
end

-- the luminous horizon: a 1px line, brightest at the centre, fading out to the ends
local function horizon(parent, width, props)
	local l = new("Frame", { AnchorPoint = V2(0.5, 1), Position = UD2(0.5, 0, 1, 0), Size = UD2(width or 0.7, 0, 0, 1), ZIndex = 2, Parent = parent })
	paint(l, { BackgroundColor3 = "Accent" })
	new("UIGradient", { Transparency = NumberSequence.new({ KP(0, 1), KP(0.22, 0.4), KP(0.5, 0), KP(0.78, 0.4), KP(1, 1) }), Parent = l })
	if props then
		for k, v in pairs(props) do l[k] = v end
	end
	return l
end

local function pad(o, l, r, t, b)
	return new("UIPadding", {
		PaddingLeft = UDim.new(0, l or 0), PaddingRight = UDim.new(0, r or 0),
		PaddingTop = UDim.new(0, t or 0), PaddingBottom = UDim.new(0, b or 0), Parent = o,
	})
end

local function list(o, gap, dir)
	return new("UIListLayout", {
		Padding = UDim.new(0, gap or 0), FillDirection = dir or Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder, Parent = o,
	})
end

local function text(parent, str, size, key, props)
	local l = new("TextLabel", {
		BackgroundTransparency = 1, FontFace = Lumen.Font, TextSize = size or 15, Text = str or "",
		TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
		Size = SCL(1, 1), TextColor3 = Lumen.Theme.Text,
	})
	if props then
		for k, v in pairs(props) do l[k] = v end
	end
	if key then paint(l, { TextColor3 = key }) end
	l.Parent = parent
	return l
end

-- mono caps label (section headers, field captions, meta text)
local function mono(parent, str, size, key, props)
	local l = text(parent, string.upper(str or ""), size or 11, key, props)
	l.FontFace = Lumen.Mono
	return l
end

local function autoX(props)
	props = props or {}
	props.Size = props.Size or UD2(0, 0, 1, 0)
	props.AutomaticSize = AUTO_X
	props.TextTruncate = Enum.TextTruncate.None
	return props
end

-- ">" chevron from two bars; rotate the holder (0 = right, 90 = down). Rotation-safe, no assets.
local function chevron(parent, size, props)
	local holder = new("Frame", { BackgroundTransparency = 1, AnchorPoint = V2(0.5, 0.5), Size = OFF(size, size), Parent = parent })
	if props then
		for k, v in pairs(props) do holder[k] = v end
	end
	local len, thick = size * 0.6, 1.5
	local bars = {}
	for i, r in ipairs({ 45, -45 }) do
		local b = new("Frame", {
			AnchorPoint = V2(0.5, 0.5), Size = OFF(len, thick), Rotation = r,
			Position = UD2(0.5, 0, 0.5, (i == 1 and -1 or 1) * len * 0.35),
			BackgroundColor3 = Lumen.Theme.Text, ZIndex = holder.ZIndex, Parent = holder,
		})
		corner(b, 1)
		bars[i] = b
	end
	local C = { Holder = holder, Bars = bars }
	function C:Set(open, color, instant)
		tw(holder, instant and 0 or 0.3, { Rotation = open and 90 or 0 })
		for _, b in ipairs(bars) do tw(b, instant and 0 or 0.2, { BackgroundColor3 = color }) end
	end
	return C
end

-- soft light bloom from the click point
local function ripple(button)
	pcall(function()
		local s = (Lumen.Window and Lumen.Window.Scale) or 1
		local abs = button.AbsoluteSize
		local rel = (UIS:GetMouseLocation() - button.AbsolutePosition) / s
		local size = math.max(abs.X, abs.Y) / s * 2.2
		local dot = new("Frame", {
			AnchorPoint = V2(0.5, 0.5), Position = OFF(rel.X, rel.Y), Size = OFF(0, 0),
			BackgroundColor3 = Lumen.Theme.Accent, BackgroundTransparency = 0.82, ZIndex = button.ZIndex + 1, Parent = button,
		})
		corner(dot, 999)
		tw(dot, 0.6, { Size = OFF(size, size), BackgroundTransparency = 1 })
		task.delay(0.65, function() dot:Destroy() end)
	end)
end

-- hover/press feedback: callbacks get (hovered, pressed)
local function interact(obj, onChange)
	local hovered, pressed = false, false
	obj.MouseEnter:Connect(function() hovered = true; onChange(hovered, pressed) end)
	obj.MouseLeave:Connect(function() hovered = false; pressed = false; onChange(hovered, pressed) end)
	obj.InputBegan:Connect(function(i)
		if i.UserInputType == MB1 or i.UserInputType == TOUCH then pressed = true; onChange(hovered, pressed) end
	end)
	obj.InputEnded:Connect(function(i)
		if i.UserInputType == MB1 or i.UserInputType == TOUCH then pressed = false; onChange(hovered, pressed) end
	end)
end

local function isPress(input)
	return input.UserInputType == MB1 or input.UserInputType == TOUCH
end

-- screen position that matches AbsolutePosition (the ScreenGui ignores the top-bar inset)
local function pointer(input)
	if input and input.UserInputType == TOUCH then
		local inset = GuiService:GetGuiInset()
		return V2(input.Position.X + inset.X, input.Position.Y + inset.Y)
	end
	return UIS:GetMouseLocation()
end

-- calls onMove while the press that started in `input` is held
local function follow(input, onMove, onEnd)
	local kind = input.UserInputType
	local moveConn, endConn
	moveConn = UIS.InputChanged:Connect(function(i)
		local t = i.UserInputType
		if (kind == TOUCH and t == TOUCH) or (kind ~= TOUCH and t == Enum.UserInputType.MouseMovement) then
			onMove(pointer(i))
		end
	end)
	endConn = UIS.InputEnded:Connect(function(i)
		if i.UserInputType == kind then
			moveConn:Disconnect()
			endConn:Disconnect()
			if onEnd then onEnd() end
		end
	end)
end

local function draggable(frame, handle, onTap)
	handle.InputBegan:Connect(function(input)
		if not isPress(input) then return end
		local start, from, moved = pointer(input), frame.Position, false
		follow(input, function(p)
			local d = p - start
			if d.Magnitude > 5 then moved = true end
			if moved then
				frame.Position = UD2(from.X.Scale, from.X.Offset + d.X, from.Y.Scale, from.Y.Offset + d.Y)
			end
		end, function()
			if not moved and onTap then onTap() end
		end)
	end)
end

local function keyName(input)
	local t = input.UserInputType
	if t == Enum.UserInputType.Keyboard or string.find(t.Name, "Gamepad") then
		if input.KeyCode == Enum.KeyCode.Unknown then return nil end
		return input.KeyCode.Name
	end
	if t == Enum.UserInputType.MouseButton2 then return "MB2" end
	if t == Enum.UserInputType.MouseButton3 then return "MB3" end
	return nil
end

local function normKey(k)
	if typeof(k) == "EnumItem" then return k.Name end
	if type(k) == "string" and k ~= "" then return k end
	return "None"
end

local function trim(s)
	return (string.gsub(s or "", "^%s*(.-)%s*$", "%1"))
end

local function args(flag, o)
	if type(flag) == "table" then
		o = flag
		flag = o.Flag
	end
	o = o or {}
	o.Flag = flag
	o.Text = o.Text or flag
	return flag, o
end

--------------------------------------------------------------------------------
-- files
--------------------------------------------------------------------------------

local function hasFS()
	return type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function"
end

local function ensureFolder(path)
	if type(makefolder) ~= "function" then return end
	local cur = ""
	for part in string.gmatch(path, "[^/]+") do
		cur = cur == "" and part or (cur .. "/" .. part)
		local ok, exists = pcall(function() return isfolder(cur) end)
		if not (ok and exists) then pcall(makefolder, cur) end
	end
end

local function listNames(path)
	local out = {}
	if type(listfiles) ~= "function" then return out end
	local ok, files = pcall(listfiles, path)
	if not ok or type(files) ~= "table" then return out end
	for _, f in ipairs(files) do
		f = string.gsub(f, "\\", "/")
		local name = string.match(f, "([^/]+)%.json$")
		if name and name ~= "autoload" then table.insert(out, name) end
	end
	table.sort(out)
	return out
end

local function readJSON(path)
	if not hasFS() then return nil end
	local okFile, exists = pcall(isfile, path)
	if not (okFile and exists) then return nil end
	local ok, data = pcall(function() return HttpService:JSONDecode(readfile(path)) end)
	if ok and type(data) == "table" then return data end
	return nil
end

local function writeJSON(path, data)
	if not hasFS() then return false end
	ensureFolder(string.match(path, "^(.*)/[^/]+$") or "")
	return (pcall(writefile, path, HttpService:JSONEncode(data)))
end

local function removeFile(path)
	if type(delfile) == "function" then pcall(delfile, path) end
end

--------------------------------------------------------------------------------
-- theme
--------------------------------------------------------------------------------

function Lumen:_applyTheme()
	local th = self.Theme
	for _, r in ipairs(self._reg) do
		r[1][r[2]] = th[r[3]]
	end
	for _, fn in ipairs(self._hooks) do
		pcall(fn, true)
	end
	self:_themeChanged()
end

function Lumen:SetThemeColor(key, color)
	if self.Theme[key] == nil or self.Theme[key] == color then return end
	self.Theme[key] = color
	self:_applyTheme()
end

function Lumen:SetTheme(tbl)
	for _, key in ipairs(self.ThemeOrder) do
		local c = tbl[key]
		if type(c) == "string" then
			local ok, parsed = pcall(Color3.fromHex, c)
			c = ok and parsed or nil
		end
		if typeof(c) == "Color3" then self.Theme[key] = c end
	end
	if self._themePickers then
		for key, picker in pairs(self._themePickers) do picker:Set(self.Theme[key], true) end
	end
	self:_applyTheme()
end

function Lumen:_themeData()
	local out = {}
	for _, key in ipairs(self.ThemeOrder) do out[key] = self.Theme[key]:ToHex() end
	return out
end

function Lumen:_themePath() return self.Folder .. "/themes" end
function Lumen:ListThemes() return listNames(self:_themePath()) end
function Lumen:SaveTheme(name) return writeJSON(self:_themePath() .. "/" .. name .. ".json", self:_themeData()) end
function Lumen:DeleteTheme(name) removeFile(self:_themePath() .. "/" .. name .. ".json") end
function Lumen:LoadTheme(name)
	local data = readJSON(self:_themePath() .. "/" .. name .. ".json")
	if not data then return false end
	self:SetTheme(data)
	return true
end

-- "Autoload Theme" keeps a snapshot of the current colours in themes/autoload.json
function Lumen:_themeChanged()
	if not self._themeAutoload then return end
	self._themeSaveToken = (self._themeSaveToken or 0) + 1
	local token = self._themeSaveToken
	task.delay(0.5, function()
		if self._themeSaveToken == token and self._themeAutoload then
			writeJSON(self:_themePath() .. "/autoload.json", self:_themeData())
		end
	end)
end

--------------------------------------------------------------------------------
-- configs
--------------------------------------------------------------------------------

function Lumen:_cfgPath()
	local W = self.Window
	return self.Folder .. "/" .. (W and W.ConfigFolder or "default") .. "/configs"
end

function Lumen:ListConfigs() return listNames(self:_cfgPath()) end
function Lumen:DeleteConfig(name) removeFile(self:_cfgPath() .. "/" .. name .. ".json") end

function Lumen:SaveConfig(name)
	local data = {}
	for flag, opt in pairs(self.Options) do
		if not opt.NoSave and opt.Serialize then data[flag] = opt:Serialize() end
	end
	local wm = self.Window and self.Window.Watermark
	if wm then
		local p = wm.Position
		data.__WatermarkPos = { p.X.Scale, p.X.Offset, p.Y.Scale, p.Y.Offset }
	end
	return writeJSON(self:_cfgPath() .. "/" .. name .. ".json", data)
end

function Lumen:LoadConfig(name)
	local data = readJSON(self:_cfgPath() .. "/" .. name .. ".json")
	if not data then return false end
	self._loading = true
	for flag, value in pairs(data) do
		local opt = self.Options[flag]
		if opt and not opt.NoSave and opt.Deserialize then pcall(opt.Deserialize, opt, value) end
	end
	local pos, wm = data.__WatermarkPos, self.Window and self.Window.Watermark
	if wm and type(pos) == "table" and #pos == 4 then
		wm.Position = UDim2.new(pos[1], pos[2], pos[3], pos[4])
	end
	self._loading = false
	self.CurrentConfig = name
	return true
end

function Lumen:_dirty()
	if not self.AutoSave or self._loading then return end
	self._saveToken = (self._saveToken or 0) + 1
	local token = self._saveToken
	task.delay(1, function()
		if self._saveToken == token and self.AutoSave and not self.Unloaded then
			self:SaveConfig(self.CurrentConfig or "autosave")
		end
	end)
end

--------------------------------------------------------------------------------
-- options (shared by every element)
--------------------------------------------------------------------------------

local Option = {}
Option.__index = Option

function Option:Get() return self.Value end

function Option:OnChanged(fn)
	table.insert(self._listeners, fn)
	return self
end

function Option:SetVisible(visible)
	self._el.Hidden = not visible
	self._el.Row.Visible = visible
end

function Option:_fire()
	if self.Flag then Lumen.Flags[self.Flag] = self.Value end
	if self.Callback then task.spawn(self.Callback, self.Value) end
	for _, fn in ipairs(self._listeners) do task.spawn(fn, self.Value) end
	if self.Flag and not self.NoSave then Lumen:_dirty() end
end

local function option(o, t)
	t._listeners = {}
	t.Callback = o.Callback
	t.NoSave = o.NoSave
	t.Text = o.Text or t.Text or ""
	return setmetatable(t, Option)
end

local function register(flag, opt)
	if not flag then return end
	opt.Flag = flag
	Lumen.Options[flag] = opt
	Lumen.Flags[flag] = opt.Value
end

--------------------------------------------------------------------------------
-- popups (dropdown lists, colour pickers, keybind modes)
--------------------------------------------------------------------------------

function Lumen:_closePopup()
	local p = self._popup
	if not p then return end
	self._popup = nil
	if p.Conn then p.Conn:Disconnect() end
	if p.OnClose then pcall(p.OnClose) end
	p.Catcher:Destroy()
	local f = p.Frame
	f.Active = false
	tw(f, 0.12, { GroupTransparency = 1 })
	if p.Scaler then tw(p.Scaler, 0.12, { Scale = p.Scaler.Scale * 0.97 }) end
	task.delay(0.13, function() f:Destroy() end)
end

function Lumen:_openPopup(anchor, width, height, align, onClose)
	self:_closePopup()
	local W = self.Window
	local catcher = new("TextButton", { BackgroundTransparency = 1, Size = SCL(1, 1), ZIndex = 1, Parent = W.Overlay })
	local frame = new("CanvasGroup", { Size = OFF(width, height), ZIndex = 2, GroupTransparency = 1, Parent = W.Overlay })
	surface(frame, "Inline")
	corner(frame, 10)
	rim(frame)
	local scaler = new("UIScale", { Scale = W.Scale * 0.96, Parent = frame })
	tw(frame, 0.18, { GroupTransparency = 0 })
	tw(scaler, 0.26, { Scale = W.Scale })
	local p = { Frame = frame, Catcher = catcher, OnClose = onClose, Scaler = scaler }
	self._popup = p

	local function place()
		if not anchor.Parent or not W.Root.Visible then
			self:_closePopup()
			return
		end
		local s = W.Scale
		local ap, as = anchor.AbsolutePosition, anchor.AbsoluteSize
		local h = frame.AbsoluteSize.Y
		local x = align == "right" and (ap.X + as.X - width * s) or ap.X
		local y = ap.Y + as.Y + 6 * s
		if y + h > W.Gui.AbsoluteSize.Y - 8 then y = ap.Y - h - 6 * s end
		frame.Position = OFF(x, y)
	end
	place()
	p.Conn = RunService.RenderStepped:Connect(place)
	catcher.MouseButton1Click:Connect(function() self:_closePopup() end)
	catcher.MouseButton2Click:Connect(function() self:_closePopup() end)
	return frame
end

function Lumen:_tip(obj, str)
	obj.MouseEnter:Connect(function()
		local W = self.Window
		local tip = W.Tip
		tip.Text = str
		tip.Visible = true
		tip.TextTransparency, tip.BackgroundTransparency = 1, 1
		if W.TipStroke then W.TipStroke.Transparency = 1; tw(W.TipStroke, 0.15, { Transparency = 0 }) end
		tw(tip, 0.15, { TextTransparency = 0, BackgroundTransparency = 0.02 })
		if W._tipConn then W._tipConn:Disconnect() end
		W._tipConn = RunService.RenderStepped:Connect(function()
			local m = UIS:GetMouseLocation()
			tip.Position = OFF(m.X + 14, m.Y + 16)
		end)
	end)
	obj.MouseLeave:Connect(function()
		local W = self.Window
		local tip = W.Tip
		tw(tip, 0.1, { TextTransparency = 1, BackgroundTransparency = 1 })
		if W.TipStroke then tw(W.TipStroke, 0.1, { Transparency = 1 }) end
		task.delay(0.1, function()
			if tip.TextTransparency >= 0.99 then tip.Visible = false end
		end)
		if W._tipConn then W._tipConn:Disconnect(); W._tipConn = nil end
	end)
end

--------------------------------------------------------------------------------
-- sections + elements
--------------------------------------------------------------------------------

local Section = {}
Section.__index = Section

function Section:_row(height, name, tip)
	self._n += 1
	local row = new("Frame", { BackgroundTransparency = 1, Size = UD2(1, 0, 0, height), LayoutOrder = self._n, Parent = self.Content })
	local el = { Name = string.lower(name or ""), Row = row, Hidden = false }
	table.insert(self.Elements, el)
	if tip then Lumen:_tip(row, tip) end
	return row, el
end

-- open/close the panel; animated unless `instant` (search filtering, theme redraws)
function Section:_draw(open, instant)
	local changed = self._shown ~= open
	self._shown = open
	local th = Lumen.Theme
	local t = instant and 0 or 0.3
	self.Arrow:Set(open, open and th.Accent or th.InactiveText, instant)
	tw(self.Dot, t, { BackgroundColor3 = open and th.Accent or th.Border, Size = open and OFF(6, 6) or OFF(5, 5) })
	tw(self.Horizon, t, { BackgroundTransparency = open and 0 or 0.75, Size = UD2(open and 0.7 or 0.4, 0, 0, 1) })
	tw(self.TitleLabel, instant and 0 or 0.2, { TextColor3 = open and th.Text or th.InactiveText })

	local body = self.Body
	self._anim = (self._anim or 0) + 1
	local token = self._anim
	if instant or not changed then
		body.ClipsDescendants = false
		body.AutomaticSize = open and AUTO_Y or Enum.AutomaticSize.None
		body.Size = UD2(1, 0, 0, 0)
		body.Visible = open
		return
	end

	local scale = (Lumen.Window and Lumen.Window.Scale) or 1
	body.ClipsDescendants = true
	if open then
		body.AutomaticSize = Enum.AutomaticSize.None
		body.Size = UD2(1, 0, 0, 0)
		body.Visible = true
		task.defer(function() -- measure once the layout has run
			if self._anim ~= token then return end
			local full = self.Content.AbsoluteSize.Y / scale + 1
			tw(body, 0.34, { Size = UD2(1, 0, 0, full) })
			task.delay(0.35, function()
				if self._anim ~= token then return end
				body.ClipsDescendants = false
				body.AutomaticSize = AUTO_Y
				body.Size = UD2(1, 0, 0, 0)
			end)
		end)
	else
		local full = body.AbsoluteSize.Y / scale
		body.AutomaticSize = Enum.AutomaticSize.None
		body.Size = UD2(1, 0, 0, full)
		tw(body, 0.26, { Size = UD2(1, 0, 0, 0) })
		task.delay(0.27, function()
			if self._anim == token then body.Visible = false end
		end)
	end
end

function Section:SetOpen(open)
	self.Open = open
	self:_draw(open)
end

-- returns how many controls matched (used by the window-wide search to count hits per tab)
function Section:_filter(q)
	if q == "" then
		self.Frame.Visible = true
		for _, el in ipairs(self.Elements) do el.Row.Visible = not el.Hidden end
		self:_draw(self.Open, true)
		return 0
	end
	local titleHit = string.find(self.TitleLower, q, 1, true) ~= nil
	local any, n = titleHit, 0
	for _, el in ipairs(self.Elements) do
		local hit = (titleHit or string.find(el.Name, q, 1, true) ~= nil) and not el.Hidden
		el.Row.Visible = hit
		if hit then any = true n += 1 end
	end
	if titleHit and n == 0 then n = 1 end
	self.Frame.Visible = any
	self:_draw(any, true)
	return n
end

-- Toggle: On / Off segmented control ------------------------------------------

function Section:AddToggle(flag, o)
	flag, o = args(flag, o)
	local T = option(o, { Type = "Toggle", Value = o.Default == true })
	local row, el = self:_row(30, T.Text, o.Tooltip)
	T._el = el

	local btn = new("TextButton", { BackgroundTransparency = 1, Size = SCL(1, 1), Parent = row })
	local lab = text(row, T.Text, 15, nil, { Size = UD2(1, -90, 1, 0) })
	local seg = new("Frame", { AnchorPoint = V2(1, 0.5), Position = UD2(1, 0, 0.5, 0), Size = OFF(76, 26), Parent = row })
	paint(seg, { BackgroundColor3 = "Background" })
	corner(seg, 7)
	local segRim = rim(seg)
	local pill = new("Frame", { AnchorPoint = V2(0, 0.5), Position = UD2(0, 3, 0.5, 0), Size = OFF(35, 20), Parent = seg })
	corner(pill, 5)
	local pillRim = rim(pill)
	local pillLine = horizon(pill, 0.6)
	local onL = text(seg, "On", 13, nil, { Position = OFF(3, 0), Size = UD2(0, 35, 1, 0), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 2 })
	local offL = text(seg, "Off", 13, nil, { Position = OFF(38, 0), Size = UD2(0, 35, 1, 0), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 2 })
	local pscale = new("UIScale", { Parent = seg })
	-- switch VFX: an accent ring that expands and fades around the control
	local burst = new("Frame", { BackgroundTransparency = 1, Size = SCL(1, 1), Parent = seg })
	corner(burst, 7)
	local burstStroke = new("UIStroke", { Thickness = 0, Transparency = 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = burst })
	local function switchFx(on)
		burstStroke.Color = on and Lumen.Theme.Accent or Lumen.Theme.Border
		burstStroke.Thickness, burstStroke.Transparency = 1, 0.15
		tw(burstStroke, 0.5, { Thickness = 5, Transparency = 1 }, Enum.EasingStyle.Quad)
		pscale.Scale = 1.07
		tw(pscale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
	end
	T._row, T._label = row, lab
	local hovered = false

	local function draw(instant)
		local th, on = Lumen.Theme, T.Value
		local t = instant and 0 or 0.22
		tw(pill, instant and 0 or 0.38, { Position = UD2(0, on and 3 or 38, 0.5, 0) })
		tw(pill, t, { BackgroundColor3 = on and th.Element:Lerp(th.Accent, 0.16) or th.Element })
		tw(pillLine, t, { BackgroundTransparency = on and 0 or 1 })
		tw(pillRim, t, { Transparency = on and 0 or 0.35 })
		tw(onL, t, { TextColor3 = on and th.Text or th.InactiveText })
		tw(offL, t, { TextColor3 = on and th.InactiveText or th.Text })
		tw(segRim, t, { Transparency = hovered and 0 or 0.3 })
		tw(lab, t, { TextColor3 = (on or hovered) and th.Text or th.InactiveText })
	end
	hook(draw)

	interact(btn, function(h, pressed)
		hovered = h
		draw(false)
		tw(pscale, 0.15, { Scale = pressed and 0.96 or 1 })
	end)

	function T:Set(v, silent)
		v = v == true
		if v == self.Value and not silent then return end
		self.Value = v
		draw(false)
		Lumen:_refreshBinds()
		if not silent then self:_fire() elseif self.Flag then Lumen.Flags[self.Flag] = self.Value end
	end
	function T:Serialize() return self.Value end
	function T:Deserialize(v) self:Set(v == true) end
	function T:AddKeybind(kflag, ko)
		kflag, ko = args(kflag, ko)
		lab.Size = UD2(1, -176, 1, 0)
		Section._keybind(self._section, row, 86, kflag, ko, self)
		return self
	end

	T._section = self
	btn.MouseButton1Click:Connect(function()
		T:Set(not T.Value)
		switchFx(T.Value)
	end)
	register(flag, T)
	return T
end

-- Button -----------------------------------------------------------------------

function Section:AddButton(o, fn)
	if type(o) == "string" then o = { Text = o, Callback = fn } end
	local row, el = self:_row(34, o.Text, o.Tooltip)
	list(row, 8, Enum.FillDirection.Horizontal)
	local B = { _el = el, Buttons = {} }

	local function layout()
		local n = #B.Buttons
		for _, b in ipairs(B.Buttons) do b.Size = UD2(1 / n, -8 * (n - 1) / n, 1, 0) end
	end

	local function add(opts)
		local b = new("TextButton", { LayoutOrder = #B.Buttons + 1, ClipsDescendants = true, Parent = row })
		surface(b, "Element", 0.1)
		corner(b, 7)
		local edge = rim(b)
		local line = horizon(b, 0.7, { BackgroundTransparency = 1 })
		local bscale = new("UIScale", { Parent = b })
		local lab = text(b, opts.Text, 15, "Text", { TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 3 })
		local hovered, armed = false, false
		local function paintBtn(instant)
			local th = Lumen.Theme
			local t = instant and 0 or 0.18
			tw(line, t, { BackgroundTransparency = (hovered or armed) and 0 or 1 })
			tw(edge, t, { Transparency = (hovered or armed) and 0 or 0.25 })
			tw(lab, t, { TextColor3 = armed and th.Accent or th.Text })
		end
		hook(paintBtn)
		interact(b, function(h, pressed)
			hovered = h
			paintBtn(false)
			tw(bscale, pressed and 0.08 or 0.25, { Scale = pressed and 0.97 or 1 })
		end)
		b.MouseButton1Click:Connect(function()
			ripple(b)
			if opts.Confirm and not armed then
				armed = true
				lab.Text = "Click again to confirm"
				paintBtn(false)
				task.delay(3, function()
					if armed then armed = false; lab.Text = opts.Text; paintBtn(false) end
				end)
				return
			end
			armed = false
			lab.Text = opts.Text
			paintBtn(false)
			if opts.Callback then task.spawn(opts.Callback) end
		end)
		table.insert(B.Buttons, b)
		layout()
	end

	function B:AddButton(o2, fn2)
		if type(o2) == "string" then o2 = { Text = o2, Callback = fn2 } end
		el.Name = el.Name .. " " .. string.lower(o2.Text)
		add(o2)
		return self
	end
	B.SetVisible = Option.SetVisible

	add(o)
	return B
end

-- Slider: caption + mono readout over a thin luminous progress line ------------

function Section:AddSlider(flag, o)
	flag, o = args(flag, o)
	local min, max = o.Min or 0, o.Max or 100
	local dec = math.max(0, math.floor(o.Decimals or o.Rounding or 0))
	local S = option(o, { Type = "Slider", Min = min, Max = max, Suffix = o.Suffix or "" })

	local function round(v)
		local m = 10 ^ dec
		return math.clamp(math.floor(v * m + 0.5) / m, min, max)
	end
	local function fmt(v)
		if dec == 0 then return tostring(math.floor(v + 0.5)) end
		local s = string.format("%." .. dec .. "f", v)
		s = string.gsub(s, "0+$", "")
		s = string.gsub(s, "%.$", "")
		return s
	end
	S.Value = round(o.Default or min)

	local row, el = self:_row(40, S.Text, o.Tooltip)
	S._el = el
	local lab = text(row, S.Text, 15, nil, { Size = UD2(1, -100, 0, 20) })
	local box = new("TextBox", {
		AnchorPoint = V2(1, 0), Position = UD2(1, 0, 0, 0), Size = UD2(0, 96, 0, 20), TextSize = 13,
		BackgroundTransparency = 1, ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Right, Parent = row,
	})
	box.FontFace = Lumen.Mono
	paint(box, { TextColor3 = "Text" })

	local hit = new("Frame", { BackgroundTransparency = 1, Position = OFF(0, 22), Size = UD2(1, 0, 0, 18), Active = true, Parent = row })
	local track = new("Frame", { AnchorPoint = V2(0, 0.5), Position = UD2(0, 0, 0.5, 0), Size = UD2(1, 0, 0, 4), Parent = hit })
	paint(track, { BackgroundColor3 = "Element" })
	corner(track, 2)
	local fill = new("Frame", { Size = UD2(0, 0, 1, 0), BackgroundColor3 = Color3.new(1, 1, 1), Parent = track })
	corner(fill, 2)
	local grad = new("UIGradient", { Parent = fill })
	local knob = new("Frame", { AnchorPoint = V2(0.5, 0.5), Size = OFF(8, 8), ZIndex = 2, Parent = hit })
	corner(knob, 99)
	paint(knob, { BackgroundColor3 = "Text" })
	local knobGlow = new("UIStroke", { Thickness = 3, Transparency = 0.75, Parent = knob })
	paint(knobGlow, { Color = "Accent" })

	hook(function()
		local th = Lumen.Theme
		grad.Color = ColorSequence.new(th.Element:Lerp(th.Gradient, 0.35), th.Accent)
	end)

	local dragging, over = false, false
	local function knobSize()
		local big = dragging or over
		tw(knob, 0.18, { Size = big and OFF(12, 12) or OFF(8, 8) })
		tw(knobGlow, 0.18, { Transparency = big and 0.55 or 0.75 })
		tw(lab, 0.18, { TextColor3 = big and Lumen.Theme.Text or Lumen.Theme.InactiveText })
	end
	hook(function() lab.TextColor3 = (dragging or over) and Lumen.Theme.Text or Lumen.Theme.InactiveText end)
	hit.MouseEnter:Connect(function() over = true; knobSize() end)
	hit.MouseLeave:Connect(function() over = false; knobSize() end)

	local function draw(instant)
		local p = max > min and (S.Value - min) / (max - min) or 0
		tw(fill, instant and 0 or 0.16, { Size = UD2(p, 0, 1, 0) })
		tw(knob, instant and 0 or 0.16, { Position = UD2(p, p == 0 and 4 or (p == 1 and -4 or 0), 0.5, 0) })
		if not box:IsFocused() then box.Text = fmt(S.Value) .. S.Suffix end
	end
	draw(true)

	function S:Set(v, silent)
		v = round(tonumber(v) or self.Value)
		if v == self.Value then draw(false); return end
		self.Value = v
		draw(false)
		if not silent then self:_fire() elseif self.Flag then Lumen.Flags[self.Flag] = self.Value end
	end
	function S:Serialize() return self.Value end
	function S:Deserialize(v) self:Set(v) end

	local function fromX(x)
		local a, w = track.AbsolutePosition.X, track.AbsoluteSize.X
		S:Set(min + (max - min) * math.clamp((x - a) / w, 0, 1))
	end
	hit.InputBegan:Connect(function(input)
		if not isPress(input) then return end
		dragging = true
		knobSize()
		fromX(pointer(input).X)
		follow(input, function(p) fromX(p.X) end, function()
			dragging = false
			knobSize()
		end)
	end)
	box.Focused:Connect(function() box.Text = fmt(S.Value) end)
	box.FocusLost:Connect(function()
		local n = tonumber((string.gsub(box.Text, "[^%d%.%-]", "")))
		if n then S:Set(n) end
		box.Text = fmt(S.Value) .. S.Suffix
	end)

	register(flag, S)
	return S
end

-- shared field shell (dropdown, input): mono caption above a rimmed void box
local function field(row, caption, button)
	mono(row, caption, 11, "InactiveText", { Size = UD2(1, 0, 0, 14) })
	local box = new(button and "TextButton" or "Frame", { Position = OFF(0, 20), Size = UD2(1, 0, 0, 36), Parent = row })
	paint(box, { BackgroundColor3 = "Background" })
	corner(box, 7)
	local edge = rim(box)
	edge.Transparency = 0.25
	local line = horizon(box, 0.7, { BackgroundTransparency = 1 })
	return box, edge, line
end

-- Dropdown -----------------------------------------------------------------------

function Section:AddDropdown(flag, o)
	flag, o = args(flag, o)
	local D = option(o, { Type = "Dropdown", Multi = o.Multi == true, Values = o.Values or {} })
	if D.Multi then
		D.Value = {}
		if type(o.Default) == "table" then
			for _, v in ipairs(o.Default) do D.Value[v] = true end
		end
	else
		D.Value = o.Default
		if type(D.Value) == "number" and D.Values[D.Value] ~= nil then D.Value = D.Values[D.Value] end
		if D.Value == nil and not o.AllowNull then D.Value = D.Values[1] end
	end

	local row, el = self:_row(56, D.Text, o.Tooltip)
	D._el = el
	local box, edge, line = field(row, D.Text, true)
	local val = text(box, "", 15, "Text", { Position = OFF(12, 0), Size = UD2(1, -42, 1, 0) })
	local arrow = chevron(box, 11, { Position = UD2(1, -18, 0.5, 0) })
	local open, hovered = false, false

	local function drawArrow(instant)
		local th = Lumen.Theme
		local t = instant and 0 or 0.18
		arrow:Set(open, open and th.Accent or th.InactiveText, instant)
		tw(edge, t, { Transparency = (open or hovered) and 0 or 0.25 })
		tw(line, t, { BackgroundTransparency = open and 0 or (hovered and 0.5 or 1) })
	end
	hook(drawArrow)
	box.MouseEnter:Connect(function() hovered = true; drawArrow(false) end)
	box.MouseLeave:Connect(function() hovered = false; drawArrow(false) end)

	local function display()
		if D.Multi then
			local picked = {}
			for _, v in ipairs(D.Values) do
				if D.Value[v] then table.insert(picked, tostring(v)) end
			end
			val.Text = #picked > 0 and table.concat(picked, ", ") or "None"
		else
			val.Text = D.Value ~= nil and tostring(D.Value) or "None"
		end
	end
	display()

	function D:Set(v, silent)
		if self.Multi then
			local t = {}
			if type(v) == "table" then
				local isDict = false
				for _, x in pairs(v) do
					if x == true then isDict = true break end
				end
				for k, x in pairs(v) do
					if isDict then
						if x then t[k] = true end
					else
						t[x] = true
					end
				end
			end
			self.Value = t
		else
			self.Value = v
		end
		display()
		if self._redraw then self._redraw() end
		if not silent then self:_fire() elseif self.Flag then Lumen.Flags[self.Flag] = self.Value end
	end
	function D:SetValues(values)
		self.Values = values or {}
		if Lumen._popup and Lumen._popup.Owner == self then Lumen:_closePopup() end
		display()
	end
	function D:Serialize()
		if not self.Multi then return self.Value end
		local out = {}
		for _, v in ipairs(self.Values) do
			if self.Value[v] then table.insert(out, v) end
		end
		return out
	end
	function D:Deserialize(v) self:Set(v) end

	box.MouseButton1Click:Connect(function()
		if open then Lumen:_closePopup() return end
		local W = Lumen.Window
		local rows = math.max(1, math.min(#D.Values, 7))
		open = true
		drawArrow()
		local f = Lumen:_openPopup(box, box.AbsoluteSize.X / W.Scale, rows * 30 + 10, nil, function()
			open = false
			D._redraw = nil
			drawArrow()
		end)
		Lumen._popup.Owner = D
		local sc = new("ScrollingFrame", {
			BackgroundTransparency = 1, Position = OFF(0, 5), Size = UD2(1, 0, 1, -10), CanvasSize = OFF(0, 0),
			AutomaticCanvasSize = AUTO_Y, ScrollBarThickness = 2, ZIndex = 3, Parent = f,
		})
		paint(sc, { ScrollBarImageColor3 = "Border" })
		list(sc, 0)
		pad(sc, 5, 5, 0, 0)
		local items = {}
		local function redraw(instant)
			local th = Lumen.Theme
			for _, it in ipairs(items) do
				local picked = D.Multi and D.Value[it.V] or (not D.Multi and D.Value == it.V)
				local t = instant and 0 or 0.15
				tw(it.L, t, { TextColor3 = picked and th.Text or th.InactiveText, Position = OFF(picked and 24 or 12, 0) })
				it.Mark.BackgroundColor3 = th.Accent
				it.Glow.Color = th.Accent
				tw(it.Mark, t, { BackgroundTransparency = picked and 0 or 1, Size = picked and OFF(5, 5) or OFF(0, 0) })
				tw(it.Glow, t, { Transparency = picked and 0.7 or 1 })
			end
		end
		for i, v in ipairs(D.Values) do
			local b = new("TextButton", { Size = UD2(1, 0, 0, 30), BackgroundTransparency = 1, LayoutOrder = i, ZIndex = 3, Parent = sc })
			paint(b, { BackgroundColor3 = "Element" })
			corner(b, 6)
			local mark = new("Frame", { AnchorPoint = V2(0.5, 0.5), Position = UD2(0, 13, 0.5, 0), Size = OFF(0, 0), BackgroundTransparency = 1, ZIndex = 4, Parent = b })
			corner(mark, 99)
			local glow = new("UIStroke", { Thickness = 3, Transparency = 1, Parent = mark })
			local l = text(b, tostring(v), 14, nil, { Position = OFF(12, 0), Size = UD2(1, -30, 1, 0), ZIndex = 3 })
			table.insert(items, { V = v, L = l, Mark = mark, Glow = glow })
			b.MouseEnter:Connect(function() tw(b, 0.12, { BackgroundTransparency = 0 }) end)
			b.MouseLeave:Connect(function() tw(b, 0.12, { BackgroundTransparency = 1 }) end)
			b.MouseButton1Click:Connect(function()
				if D.Multi then
					local t = table.clone(D.Value)
					t[v] = not t[v] or nil
					D:Set(t)
				else
					D:Set(v)
					Lumen:_closePopup()
				end
			end)
		end
		D._redraw = function() redraw(false) end
		redraw(true)
	end)

	register(flag, D)
	return D
end

-- Keybind ------------------------------------------------------------------------

-- shared by standalone keybinds and keybinds attached to a toggle
function Section._keybind(_, row, right, flag, o, toggle)
	local KB = option(o, { Type = "Keybind", Value = normKey(o.Default), Mode = o.Mode or "Toggle", State = false, Toggle = toggle })
	KB.Text = (toggle and toggle.Text) or o.Text or flag or "Keybind"
	KB.Callback = o.ChangedCallback
	KB.Pressed = o.Callback

	local box = new("TextButton", {
		AnchorPoint = V2(1, 0.5), Position = UD2(1, -right, 0.5, 0), Size = OFF(0, 26),
		AutomaticSize = AUTO_X, ZIndex = 2, Parent = row,
	})
	paint(box, { BackgroundColor3 = "Background" })
	corner(box, 7)
	local edge = rim(box)
	edge.Transparency = 0.3
	pad(box, 9, 9, 0, 0)
	local lab = mono(box, "", 11, "InactiveText", autoX({ TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 2 }))
	local function show()
		local capturing = Lumen._capturing == KB
		lab.Text = capturing and "..." or string.upper(KB.Value)
		lab.TextColor3 = capturing and Lumen.Theme.Accent or Lumen.Theme.InactiveText
	end
	show()
	box.MouseEnter:Connect(function() tw(edge, 0.15, { Transparency = 0 }) end)
	box.MouseLeave:Connect(function() tw(edge, 0.2, { Transparency = 0.3 }) end)

	function KB:SetKey(name, silent)
		self.Value = normKey(name)
		show()
		Lumen:_refreshBinds()
		if not silent then self:_fire() elseif self.Flag then Lumen.Flags[self.Flag] = self.Value end
	end
	KB.Set = KB.SetKey
	function KB:SetMode(mode)
		self.Mode = mode
		if mode == "Always" and self.Toggle then self.Toggle:Set(true) end
		Lumen:_refreshBinds()
	end
	function KB:GetState()
		if self.Mode == "Always" then return true end
		if self.Toggle then return self.Toggle.Value end
		return self.State
	end
	function KB:_press(down)
		local m = self.Mode
		if m == "Press" then
			if down and self.Pressed then task.spawn(self.Pressed) end
			return
		end
		if m == "Always" then return end
		if m == "Toggle" then
			if not down then return end
			if self.Toggle then
				self.Toggle:Set(not self.Toggle.Value)
			else
				self.State = not self.State
				if self.Pressed then task.spawn(self.Pressed, self.State) end
			end
		elseif m == "Hold" then
			if self.Toggle then
				self.Toggle:Set(down)
			else
				self.State = down
				if self.Pressed then task.spawn(self.Pressed, down) end
			end
		end
		Lumen:_refreshBinds()
	end
	function KB:Serialize() return { Key = self.Value, Mode = self.Mode } end
	function KB:Deserialize(v)
		if type(v) ~= "table" then return end
		if v.Mode and self.Mode ~= "Press" then self:SetMode(v.Mode) end
		if v.Key then self:SetKey(v.Key) end
	end

	box.MouseButton1Click:Connect(function()
		if Lumen._capturing then return end
		Lumen._capturing = KB
		show()
		local c
		c = UIS.InputBegan:Connect(function(input)
			local t, name = input.UserInputType, nil
			if t == Enum.UserInputType.Keyboard then
				local kc = input.KeyCode
				name = (kc == Enum.KeyCode.Escape or kc == Enum.KeyCode.Backspace) and "None" or kc.Name
			elseif t == MB1 or t == TOUCH then
				name = KB.Value
			else
				name = keyName(input)
			end
			if not name then return end
			c:Disconnect()
			Lumen._lastBind = input
			Lumen._capturing = nil
			KB:SetKey(name)
		end)
	end)

	if not o.NoMode then
		box.MouseButton2Click:Connect(function()
			local modes = { "Toggle", "Hold", "Always" }
			local f = Lumen:_openPopup(box, 110, #modes * 28 + 10, "right")
			local holder = new("Frame", { BackgroundTransparency = 1, Position = OFF(0, 5), Size = UD2(1, 0, 1, -10), ZIndex = 3, Parent = f })
			list(holder, 0)
			for i, m in ipairs(modes) do
				local b = new("TextButton", { Size = UD2(1, 0, 0, 28), BackgroundTransparency = 1, LayoutOrder = i, ZIndex = 3, Parent = holder })
				mono(b, m, 11, KB.Mode == m and "Accent" or "InactiveText", { Position = OFF(14, 0), Size = UD2(1, -28, 1, 0), ZIndex = 3 })
				b.MouseButton1Click:Connect(function()
					KB:SetMode(m)
					Lumen:_closePopup()
				end)
			end
		end)
	end

	table.insert(Lumen._binds, KB)
	register(flag, KB)
	return KB
end

function Section:AddKeybind(flag, o)
	flag, o = args(flag, o)
	local row, el = self:_row(30, o.Text, o.Tooltip)
	text(row, o.Text or "", 15, "Text", { Size = UD2(1, -100, 1, 0) })
	local KB = Section._keybind(self, row, 0, flag, o, nil)
	KB._el = el
	return KB
end

-- Input --------------------------------------------------------------------------

function Section:AddInput(flag, o)
	flag, o = args(flag, o)
	local I = option(o, { Type = "Input", Value = o.Default or "" })
	local row, el = self:_row(56, I.Text, o.Tooltip)
	I._el = el
	local box, edge, line = field(row, I.Text, false)
	local tb = new("TextBox", {
		BackgroundTransparency = 1, Position = OFF(12, 0), Size = UD2(1, -24, 1, 0), Text = I.Value,
		PlaceholderText = o.Placeholder or "", ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd, Parent = box,
	})
	paint(tb, { TextColor3 = "Text", PlaceholderColor3 = "InactiveText" })
	tb.Focused:Connect(function()
		tw(edge, 0.15, { Transparency = 0 })
		tw(line, 0.2, { BackgroundTransparency = 0 })
	end)
	tb.FocusLost:Connect(function()
		tw(edge, 0.2, { Transparency = 0.25 })
		tw(line, 0.25, { BackgroundTransparency = 1 })
	end)

	function I:Set(v, silent)
		v = tostring(v or "")
		if o.Numeric then v = string.gsub(v, "[^%d%.%-]", "") end
		self.Value = v
		tb.Text = v
		if not silent then self:_fire() elseif self.Flag then Lumen.Flags[self.Flag] = self.Value end
	end
	function I:Serialize() return self.Value end
	function I:Deserialize(v) self:Set(v) end

	tb.FocusLost:Connect(function()
		if tb.Text ~= I.Value then I:Set(tb.Text) end
	end)
	if o.Live then
		tb:GetPropertyChangedSignal("Text"):Connect(function()
			if tb:IsFocused() and tb.Text ~= I.Value then I:Set(tb.Text) end
		end)
	end

	register(flag, I)
	return I
end

-- Colour picker --------------------------------------------------------------------

function Section:AddColorPicker(flag, o)
	flag, o = args(flag, o)
	local C = option(o, { Type = "ColorPicker", Value = o.Default or Color3.new(1, 1, 1) })
	local h, s, v = C.Value:ToHSV()
	local row, el = self:_row(28, C.Text, o.Tooltip)
	C._el = el
	text(row, C.Text, 15, "Text", { Size = UD2(1, -110, 1, 0) })
	local hexLab = mono(row, "", 11, "InactiveText", { AnchorPoint = V2(1, 0), Position = UD2(1, -38, 0, 0), Size = UD2(0, 70, 1, 0), TextXAlignment = Enum.TextXAlignment.Right })
	local swatch = new("TextButton", { AnchorPoint = V2(1, 0.5), Position = UD2(1, 0, 0.5, 0), Size = OFF(28, 22), BackgroundColor3 = C.Value, Parent = row })
	corner(swatch, 6)
	rim(swatch)
	local function showHex() hexLab.Text = "#" .. string.upper(C.Value:ToHex()) end
	showHex()

	local function commit()
		C.Value = Color3.fromHSV(h, s, v)
		swatch.BackgroundColor3 = C.Value
		showHex()
		if C._sync then C._sync() end
		C:_fire()
	end

	function C:Set(c, silent)
		if typeof(c) ~= "Color3" then return end
		self.Value = c
		h, s, v = c:ToHSV()
		swatch.BackgroundColor3 = c
		showHex()
		if self._sync then self._sync() end
		if not silent then self:_fire() elseif self.Flag then Lumen.Flags[self.Flag] = self.Value end
	end
	function C:Serialize() return self.Value:ToHex() end
	function C:Deserialize(hex)
		local ok, c = pcall(Color3.fromHex, hex)
		if ok then self:Set(c) end
	end

	swatch.MouseButton1Click:Connect(function()
		local f = Lumen:_openPopup(swatch, 226, 202, "right", function() C._sync = nil end)
		local sv = new("Frame", { Position = OFF(12, 12), Size = OFF(176, 140), Active = true, ZIndex = 3, Parent = f })
		corner(sv, 6)
		local white = new("Frame", { Size = SCL(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 3, Parent = sv })
		corner(white, 6)
		new("UIGradient", { Transparency = NumberSequence.new(0, 1), Parent = white })
		local black = new("Frame", { Size = SCL(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), ZIndex = 3, Parent = sv })
		corner(black, 6)
		new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(1, 0), Parent = black })
		local cur = new("Frame", { AnchorPoint = V2(0.5, 0.5), Size = OFF(10, 10), BackgroundTransparency = 1, ZIndex = 4, Parent = sv })
		corner(cur, 5)
		new("UIStroke", { Thickness = 2, Color = Color3.new(1, 1, 1), Parent = cur })

		local hue = new("Frame", { Position = OFF(198, 12), Size = OFF(16, 140), BackgroundColor3 = Color3.new(1, 1, 1), Active = true, ZIndex = 3, Parent = f })
		corner(hue, 5)
		local keys = {}
		for i = 0, 6 do keys[#keys + 1] = ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(i / 6, 1, 1)) end
		new("UIGradient", { Rotation = 90, Color = ColorSequence.new(keys), Parent = hue })
		local hueCur = new("Frame", { AnchorPoint = V2(0.5, 0.5), Size = UD2(1, 4, 0, 3), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 4, Parent = hue })
		corner(hueCur, 2)

		local hex = new("TextBox", { Position = OFF(12, 162), Size = OFF(202, 28), TextSize = 13, ClearTextOnFocus = false, ZIndex = 3, Parent = f })
		hex.FontFace = Lumen.Mono
		paint(hex, { BackgroundColor3 = "Background", TextColor3 = "Text" })
		corner(hex, 7)
		rim(hex)

		local function sync()
			sv.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
			cur.Position = UD2(s, 0, 1 - v, 0)
			hueCur.Position = UD2(0.5, 0, h, 0)
			if not hex:IsFocused() then hex.Text = "#" .. string.upper(C.Value:ToHex()) end
		end
		C._sync = sync
		sync()

		local function pickSV(p)
			local rel = (p - sv.AbsolutePosition) / sv.AbsoluteSize
			s, v = math.clamp(rel.X, 0, 1), 1 - math.clamp(rel.Y, 0, 1)
			commit()
		end
		local function pickHue(p)
			h = math.clamp((p.Y - hue.AbsolutePosition.Y) / hue.AbsoluteSize.Y, 0, 0.999)
			commit()
		end
		sv.InputBegan:Connect(function(input)
			if not isPress(input) then return end
			pickSV(pointer(input))
			follow(input, pickSV)
		end)
		hue.InputBegan:Connect(function(input)
			if not isPress(input) then return end
			pickHue(pointer(input))
			follow(input, pickHue)
		end)
		hex.FocusLost:Connect(function()
			local ok, c = pcall(Color3.fromHex, (string.gsub(hex.Text, "#", "")))
			if ok then C:Set(c) else sync() end
		end)
	end)

	register(flag, C)
	return C
end

-- Label / divider --------------------------------------------------------------------

function Section:AddLabel(str, o)
	o = o or {}
	local row, el = self:_row(0, str)
	row.AutomaticSize = AUTO_Y
	local l = text(row, str, o.Size or 14, o.Color or "InactiveText", {
		Size = UD2(1, 0, 0, 0), AutomaticSize = AUTO_Y, TextWrapped = true, TextTruncate = Enum.TextTruncate.None,
	})
	local L = { _el = el, Label = l, SetVisible = Option.SetVisible }
	function L:Set(t)
		-- status labels are refreshed on timers; skip identical text so the page isn't re-laid out
		if l.Text == t then return end
		l.Text = t
		el.Name = string.lower(t)
	end
	return L
end

function Section:AddDivider()
	local row = self:_row(9)
	paint(new("Frame", { AnchorPoint = V2(0, 0.5), Position = UD2(0, 0, 0.5, 0), Size = UD2(1, 0, 0, 1), Parent = row }), { BackgroundColor3 = "Outline" })
end

--------------------------------------------------------------------------------
-- containers (tabs and sub tabs)
--------------------------------------------------------------------------------

local Container = {}
Container.__index = Container

local function container(W, holder)
	return setmetatable({ W = W, Holder = holder, Sections = {} }, Container)
end

function Container:_columns()
	if self.Cols then return self.Cols end
	local row = new("Frame", { BackgroundTransparency = 1, Size = UD2(1, 0, 0, 0), AutomaticSize = AUTO_Y, LayoutOrder = 4, Parent = self.Holder })
	local function col(x, off)
		local c = new("Frame", { BackgroundTransparency = 1, Position = UD2(x, off, 0, 0), Size = UD2(0.5, -7, 0, 0), AutomaticSize = AUTO_Y, Parent = row })
		list(c, 14)
		return c
	end
	self.Cols = { Left = col(0, 0), Right = col(0.5, 7), nL = 0, nR = 0 }
	return self.Cols
end

function Container:AddSection(title, side, opts)
	if type(side) == "table" then opts, side = side, nil end
	opts = opts or {}
	local W = self.W
	local cols = self:_columns()
	if side ~= "Left" and side ~= "Right" then side = cols.nL <= cols.nR and "Left" or "Right" end
	if side == "Left" then cols.nL += 1 else cols.nR += 1 end

	local S = setmetatable({ W = W, Title = title, TitleLower = string.lower(title), Open = opts.Open == true, Elements = {}, _n = 0 }, Section)
	-- panel: bottom-lit surface, hairline rim, horizon line along the bottom edge
	local frame = new("Frame", { Size = UD2(1, 0, 0, 0), AutomaticSize = AUTO_Y, LayoutOrder = cols.nL + cols.nR, Parent = cols[side] })
	surface(frame, "Inline")
	corner(frame, 14)
	local frameRim = rim(frame)
	local stack = new("Frame", { BackgroundTransparency = 1, Size = UD2(1, 0, 0, 0), AutomaticSize = AUTO_Y, Parent = frame })
	list(stack, 0).HorizontalAlignment = Enum.HorizontalAlignment.Center
	-- horizon is the last item of the stack so it always sits on the panel's bottom edge
	local hz = horizon(stack, 0.7, { AnchorPoint = V2(0, 0), LayoutOrder = 99 })

	local head = new("TextButton", { Size = UD2(1, 0, 0, 44), BackgroundTransparency = 1, LayoutOrder = 1, Parent = stack })
	local dot = new("Frame", { AnchorPoint = V2(0.5, 0.5), Position = UD2(0, 20, 0.5, 0), Size = OFF(5, 5), Parent = head })
	corner(dot, 99)
	local titleLabel = mono(head, title, 12, nil, { Position = OFF(34, 0), Size = UD2(1, -70, 1, 0) })
	local arrow = chevron(head, 11, { Position = UD2(1, -22, 0.5, 0) })
	local body = new("Frame", { BackgroundTransparency = 1, Size = UD2(1, 0, 0, 0), AutomaticSize = AUTO_Y, LayoutOrder = 2, Parent = stack })
	paint(new("Frame", { Position = OFF(16, 0), Size = UD2(1, -32, 0, 1), Parent = body }), { BackgroundColor3 = "Outline" })
	local content = new("Frame", { BackgroundTransparency = 1, Position = OFF(0, 1), Size = UD2(1, 0, 0, 0), AutomaticSize = AUTO_Y, Parent = body })
	pad(content, 16, 16, 12, 16)
	list(content, 8)

	S.Frame, S.Body, S.Content, S.Arrow, S.Dot, S.Horizon, S.TitleLabel = frame, body, content, arrow, dot, hz, titleLabel
	S._shown = nil
	S:_draw(S.Open, true)
	hook(function() S:_draw(S._shown, true) end)
	frameRim.Transparency = 0.2
	head.MouseEnter:Connect(function() tw(frameRim, 0.15, { Transparency = 0 }) end)
	head.MouseLeave:Connect(function() tw(frameRim, 0.2, { Transparency = 0.2 }) end)
	head.MouseButton1Click:Connect(function()
		if W.SearchBox.Text == "" then S:SetOpen(not S.Open) end
	end)
	table.insert(self.Sections, S)
	return S
end

-- sub tabs: a segmented control ("Live / Quiet / Idle") with a sliding lit pill
function Container:AddSubTab(name)
	local tab, W = self, self.W
	if not tab.Bar then
		local wrap = new("Frame", { BackgroundTransparency = 1, Size = UD2(1, 0, 0, 44), LayoutOrder = 2, Parent = tab.Holder })
		local seg = new("Frame", { Position = OFF(0, 4), Size = UD2(0, 0, 0, 34), AutomaticSize = AUTO_X, Parent = wrap })
		paint(seg, { BackgroundColor3 = "Background" })
		corner(seg, 9)
		rim(seg).Transparency = 0.2
		pad(seg, 3, 3, 3, 3)
		local pill = new("Frame", { Size = OFF(0, 28), Parent = seg })
		surface(pill, "Element", 0.12)
		corner(pill, 7)
		rim(pill)
		horizon(pill, 0.6)
		local btns = new("Frame", { BackgroundTransparency = 1, Size = UD2(0, 0, 1, 0), AutomaticSize = AUTO_X, ZIndex = 2, Parent = seg })
		list(btns, 2, Enum.FillDirection.Horizontal)
		tab.Bar, tab.SubPill, tab.SubSeg, tab.Subs = btns, pill, seg, {}
	end
	local pane = new("Frame", { BackgroundTransparency = 1, Size = UD2(1, 0, 0, 0), AutomaticSize = AUTO_Y, LayoutOrder = 3, Visible = false, Parent = tab.Holder })
	local sub = container(W, pane)
	sub.Name, sub.Pane = name, pane

	local b = new("TextButton", { Size = UD2(0, 0, 1, 0), AutomaticSize = AUTO_X, BackgroundTransparency = 1, LayoutOrder = #tab.Subs + 1, ZIndex = 2, Parent = tab.Bar })
	pad(b, 16, 16, 0, 0)
	local lab = text(b, name, 14, nil, autoX({ TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 2 }))
	sub.Button = b

	sub._paint = function(instant)
		local on, t = tab.ActiveSub == sub, instant and 0 or 0.2
		tw(lab, t, { TextColor3 = on and Lumen.Theme.Text or Lumen.Theme.InactiveText })
	end
	hook(sub._paint)
	b.MouseButton1Click:Connect(function() tab:SelectSubTab(sub) end)
	bind(b:GetPropertyChangedSignal("AbsoluteSize"), function()
		if tab.ActiveSub == sub then tab:_moveSubPill(true) end
	end)
	table.insert(tab.Subs, sub)
	if not tab.ActiveSub then tab:SelectSubTab(sub) end
	return sub
end

function Container:_moveSubPill(instant)
	local sub, pill, seg = self.ActiveSub, self.SubPill, self.SubSeg
	if not sub or not pill then return end
	local s = (self.W.Scaler and self.W.Scaler.Scale) or 1
	if s <= 0 then return end
	local x = (sub.Button.AbsolutePosition.X - seg.AbsolutePosition.X) / s
	local w = sub.Button.AbsoluteSize.X / s
	-- the segment's UIPadding (3px) already offsets the pill
	tw(pill, instant and 0 or 0.36, { Position = OFF(x - 3, 0), Size = OFF(w, 28) })
end

function Container:SelectSubTab(sub)
	Lumen:_closePopup()
	local prev = self.ActiveSub
	self.ActiveSub = sub
	for _, s in ipairs(self.Subs) do
		s.Pane.Visible = s == sub
		s._paint()
	end
	if prev and prev ~= sub then self:_moveSubPill(false) else task.defer(function() self:_moveSubPill(true) end) end
	self.W:_search(self.W.SearchBox.Text)
end

--------------------------------------------------------------------------------
-- window
--------------------------------------------------------------------------------

local Window = {}
Window.__index = Window

function Window:AddTab(name)
	local W = self
	-- each page lives in a CanvasGroup so it can fade/slide in as one piece
	local group = new("CanvasGroup", { BackgroundTransparency = 1, Size = SCL(1, 1), Visible = false, Parent = W.Pages })
	local page = new("ScrollingFrame", {
		BackgroundTransparency = 1, Size = SCL(1, 1), CanvasSize = OFF(0, 0), AutomaticCanvasSize = AUTO_Y,
		ScrollBarThickness = 2, ScrollingDirection = Enum.ScrollingDirection.Y, Parent = group,
	})
	paint(page, { ScrollBarImageColor3 = "Border" })
	pad(page, 0, 14, 0, 14)
	list(page, 12)
	local tab = container(W, page)
	tab.Name, tab.Page, tab.Scroll = name, group, page

	local index = #W.Tabs + 1
	local b = new("TextButton", { Size = UD2(1, 0, 0, 40), BackgroundTransparency = 1, LayoutOrder = index, ZIndex = 2, Parent = W.TabList })
	local idx = mono(b, string.format("%02d", index), 11, nil, { Position = OFF(16, 0), Size = UD2(0, 24, 1, 0), ZIndex = 3 })
	local lab = text(b, name, 15, nil, { Position = OFF(46, 0), Size = UD2(1, -56, 1, 0), ZIndex = 3 })
	local hovered = false
	tab.Button = b

	tab._paint = function(instant)
		local th = Lumen.Theme
		local on, t = W.Current == tab, instant and 0 or 0.3
		-- while searching: the index shows the number of hits in this tab, tabs without hits fade out
		local hits = tab._hits
		idx.Text = hits and (hits > 99 and "99" or tostring(hits)) or string.format("%02d", index)
		tw(lab, t, {
			TextColor3 = on and th.Text or (hovered and th.Text:Lerp(th.InactiveText, 0.4) or th.InactiveText),
			TextTransparency = (hits == 0 and not on) and 0.65 or 0,
			Position = OFF(on and 48 or (hovered and 47 or 46), 0),
		})
		tw(idx, t, {
			TextColor3 = (on or (hits and hits > 0)) and th.Accent or th.Border:Lerp(th.InactiveText, 0.35),
			TextTransparency = hits == 0 and 0.65 or 0,
		})
	end
	hook(tab._paint)
	b.MouseEnter:Connect(function() hovered = true; tab._paint() end)
	b.MouseLeave:Connect(function() hovered = false; tab._paint() end)
	b.MouseButton1Click:Connect(function() W:SelectTab(tab) end)
	table.insert(W.Tabs, tab)
	if not W.Current then W:SelectTab(tab) end
	return tab
end

-- slides the lit pill behind the selected tab button
function Window:_movePill(instant)
	local tab, pill, layer = self.Current, self.TabPill, self.TabLayer
	if not tab or not tab.Button or not pill or not layer then return end
	local s = (self.Scaler and self.Scaler.Scale) or self.Scale or 1
	if s <= 0 then return end
	local y = (tab.Button.AbsolutePosition.Y - layer.AbsolutePosition.Y) / s
	tw(pill, instant and 0 or 0.4, { Position = UD2(0, 0, 0, y) })
end

function Window:SelectTab(tab)
	Lumen:_closePopup()
	local prev = self.Current
	self.Current = tab
	for _, t in ipairs(self.Tabs) do
		if t ~= tab then t.Page.Visible = false end
		t._paint()
	end
	local g = tab.Page
	g.Visible = true
	if prev and prev ~= tab then
		g.GroupTransparency = 1
		g.Position = UD2(0, 0, 0, 12)
		tw(g, 0.36, { GroupTransparency = 0, Position = UD2(0, 0, 0, 0) })
	else
		g.GroupTransparency, g.Position = 0, UD2(0, 0, 0, 0)
	end
	if self.CrumbLabel then self.CrumbLabel.Text = string.upper(tab.Name) end
	if prev then self:_movePill(false) else task.defer(function() self:_movePill(true) end) end
	self:_search(self.SearchBox.Text)
end

-- window-wide search: filters every tab (and sub-tab), shows the hit count next to each tab,
-- dims tabs without hits and jumps to the first tab with hits when the current one has none
function Window:_search(q)
	if self._searching then return end
	q = string.lower(trim(q))
	if not self.Current then return end
	self._searching = true
	local first, counts = nil, {}
	for _, tab in ipairs(self.Tabs) do
		local total, bestSub, bestN = 0, nil, 0
		for _, s in ipairs(tab.Sections) do total += s:_filter(q) end
		for _, sub in ipairs(tab.Subs or {}) do
			local n = 0
			for _, s in ipairs(sub.Sections) do n += s:_filter(q) end
			total += n
			if n > bestN then bestSub, bestN = sub, n end
		end
		counts[tab] = total
		tab._hits = q ~= "" and total or nil
		tab._bestSub = bestSub
		if total > 0 and not first then first = tab end
		if tab._paint then tab._paint(true) end
	end
	local cur = self.Current
	if q ~= "" and counts[cur] == 0 and first then
		self:SelectTab(first)
		cur = first
	end
	-- inside a tab with sub-tabs, show the sub-tab that has the hits
	if q ~= "" and cur.ActiveSub and cur._bestSub and cur._bestSub ~= cur.ActiveSub then
		local n = 0
		for _, s in ipairs(cur.ActiveSub.Sections) do if s.Frame.Visible then n += 1 end end
		if n == 0 then cur:SelectSubTab(cur._bestSub) end
	end
	self._searching = false
end

function Window:_applyScale()
	local cam = workspace.CurrentCamera
	local vp = cam and cam.ViewportSize or V2(1920, 1080)
	local size = self.Root.Size
	local fit = math.min(1, (vp.X - 24) / (size.X.Offset * self.Preset), (vp.Y - 24) / (size.Y.Offset * self.Preset))
	self.Scale = math.max(0.35, self.Preset * fit)
	self.Scaler.Scale = self.Scale
end

function Window:_refreshBackdrop()
	local m, open = self.Menu, self.Open
	tw(self.Darken, math.max(m.FadeSpeed, 0.1), { BackgroundTransparency = (open and m.Darken) and 0.45 or 1 })
	if m.Effect == "Blur" and not self.Blur then
		self.Blur = new("BlurEffect", { Size = 0, Parent = workspace.CurrentCamera })
	end
	if self.Blur then
		tw(self.Blur, math.max(m.FadeSpeed, 0.1), { Size = (open and m.Effect == "Blur") and 16 or 0 })
	end
end

-- opening VFX: the rim lights up in the accent colour and fades back, a light streak crosses the top bar
function Window:_openFx()
	local th = Lumen.Theme
	local rimS = self.RimStroke
	if rimS then
		rimS.Thickness = 4
		tw(rimS, 0.9, { Thickness = 1.5 }, Enum.EasingStyle.Quad)
	end
	local sweep = self._sweep
	if sweep then
		sweep.Position = UD2(-0.3, 0, 0, 0)
		tw(sweep, 0.85, { Position = UD2(1.3, 0, 0, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
	end
end

function Window:SetOpen(open)
	self.Open = open
	self._token = (self._token or 0) + 1
	local token, m = self._token, self.Menu
	local root, cover, scaler = self.Root, self.Cover, self.Scaler
	local small = self.Scale * 0.94
	Lumen:_closePopup()
	if open then
		root.Visible = true
		self:_openFx()
		if m.TweenTime > 0 then
			scaler.Scale = small
			tw(scaler, m.TweenTime, { Scale = self.Scale }, m.Style, m.Direction)
		else
			scaler.Scale = self.Scale
		end
		if m.FadeSpeed > 0 then
			cover.Visible = true
			cover.BackgroundTransparency = 0
			tw(cover, m.FadeSpeed, { BackgroundTransparency = 1 })
			task.delay(m.FadeSpeed, function()
				if self._token == token then cover.Visible = false end
			end)
		else
			cover.Visible = false
		end
	else
		if m.TweenTime > 0 then tw(scaler, m.TweenTime, { Scale = small }, m.Style, m.Direction) end
		if m.FadeSpeed > 0 then
			cover.Visible = true
			cover.BackgroundTransparency = 1
			tw(cover, m.FadeSpeed, { BackgroundTransparency = 0 })
		end
		task.delay(math.max(m.TweenTime, m.FadeSpeed), function()
			if self._token == token then
				root.Visible = false
				cover.Visible = false
			end
		end)
	end
	self:_refreshBackdrop()
end

function Window:Toggle()
	self:SetOpen(not self.Open)
end

function Window:ResetPositions()
	self.Root.Position = SCL(0.5, 0.5)
	self.Watermark.Position = OFF(12, 12)
	self.KeyList.Position = OFF(12, 56)
	self.MenuButton.Position = UD2(0, 12, 0.5, -23)
end

function Window:SetWatermark(on)
	self.Watermark.Visible = on
	if on and not self._wmConn then
		local frames, last = 0, os.clock()
		self:_watermarkText(0)
		self._wmConn = RunService.Heartbeat:Connect(function()
			frames += 1
			local now = os.clock()
			if now - last >= 0.5 then
				local fps = math.floor(frames / (now - last) + 0.5)
				frames, last = 0, now
				self:_watermarkText(fps)
			end
		end)
	elseif not on and self._wmConn then
		self._wmConn:Disconnect()
		self._wmConn = nil
	end
end

function Window:_watermarkText(fps)
	local ping = 0
	pcall(function() ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue() + 0.5) end)
	self.WatermarkLabel.Text = string.format("%s  ·  %d FPS  ·  %d MS  ·  %s", self.Brand, fps, ping, os.date("%H:%M:%S"))
end

-- a status dot with a soft glow; returns the dot
local function statusDot(parent, props)
	local d = new("Frame", { Size = OFF(6, 6), Parent = parent })
	if props then
		for k, v in pairs(props) do d[k] = v end
	end
	corner(d, 99)
	paint(d, { BackgroundColor3 = "Accent" })
	local g = new("UIStroke", { Thickness = 3, Transparency = 0.75, Parent = d })
	paint(g, { Color = "Accent" })
	return d, g
end

-- builds the floating bits outside the window: watermark, keybind list, menu button, notifications, tooltip
local function buildExtras(W, gui)
	local wm = new("Frame", { Position = OFF(12, 12), Size = OFF(0, 32), AutomaticSize = AUTO_X, Visible = false, Active = true, ZIndex = 3, Parent = gui })
	surface(wm, "Inline", 0.08)
	corner(wm, 7)
	rim(wm)
	pad(wm, 12, 14, 0, 0)
	local wl = list(wm, 10, Enum.FillDirection.Horizontal)
	wl.VerticalAlignment = Enum.VerticalAlignment.Center
	statusDot(wm, { LayoutOrder = 1, ZIndex = 3 })
	W.WatermarkLabel = mono(wm, "", 11, "Text", autoX({ LayoutOrder = 2, ZIndex = 3 }))
	draggable(wm, wm)
	W.Watermark = wm

	local kl = new("Frame", { Position = OFF(12, 56), Size = OFF(210, 0), AutomaticSize = AUTO_Y, Visible = false, Active = true, ZIndex = 3, Parent = gui })
	surface(kl, "Inline")
	corner(kl, 10)
	rim(kl)
	local klStack = new("Frame", { BackgroundTransparency = 1, Size = UD2(1, 0, 0, 0), AutomaticSize = AUTO_Y, Parent = kl })
	list(klStack, 0).HorizontalAlignment = Enum.HorizontalAlignment.Center
	mono(klStack, "Keybinds", 11, "InactiveText", { Size = UD2(1, 0, 0, 32), LayoutOrder = 1, TextXAlignment = Enum.TextXAlignment.Center })
	paint(new("Frame", { Size = UD2(1, 0, 0, 1), LayoutOrder = 2, Parent = klStack }), { BackgroundColor3 = "Outline" })
	local body = new("Frame", { BackgroundTransparency = 1, Size = UD2(1, 0, 0, 0), AutomaticSize = AUTO_Y, LayoutOrder = 3, Parent = klStack })
	pad(body, 14, 14, 6, 10)
	list(body, 2)
	horizon(klStack, 0.7, { AnchorPoint = V2(0, 0), LayoutOrder = 4 })
	draggable(kl, kl)
	W.KeyList, W.KeyListBody = kl, body

	local mb = new("TextButton", { Position = UD2(0, 12, 0.5, -23), Size = OFF(46, 46), Visible = UIS.TouchEnabled and not UIS.KeyboardEnabled, ZIndex = 3, Parent = gui })
	surface(mb, "Inline", 0.1)
	corner(mb, 10)
	rim(mb)
	text(mb, "D", 20, "Text", { FontFace = Lumen.BoldFont, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 3 })
	horizon(mb, 0.6)
	draggable(mb, mb, function() W:Toggle() end)
	W.MenuButton = mb

	local notes = new("Frame", { BackgroundTransparency = 1, AnchorPoint = V2(1, 1), Position = UD2(1, -18, 1, -28), Size = UD2(0, 300, 1, -48), ZIndex = 90, Parent = gui })
	local nl = list(notes, 6)
	nl.VerticalAlignment = Enum.VerticalAlignment.Bottom
	W.Notes = notes

	local tip = new("TextLabel", {
		Visible = false, AutomaticSize = AUTO_XY, Size = OFF(0, 0), FontFace = Lumen.Font, TextSize = 13,
		TextWrapped = false, ZIndex = 20, Parent = W.Overlay,
	})
	paint(tip, { BackgroundColor3 = "Inline", TextColor3 = "Text" })
	corner(tip, 7)
	W.TipStroke = stroke(tip, "Border")
	pad(tip, 10, 10, 6, 6)
	W.Tip = tip
end

function Lumen:CreateWindow(cfg)
	cfg = cfg or {}
	local size = cfg.Size or V2(900, 610)
	local brand = cfg.Brand
	if type(brand) == "table" then brand = table.concat(brand) end
	local W = setmetatable({
		Tabs = {},
		Open = true,
		Scale = 1,
		Preset = 1,
		MenuKey = normKey(cfg.Keybind or Enum.KeyCode.RightShift),
		ConfigFolder = cfg.ConfigFolder or tostring(game.GameId),
		Brand = brand or "DIVERGENCE",
		Menu = {
			TweenTime = 0.42, FadeSpeed = 0.24, Style = EASE, Direction = Enum.EasingDirection.Out,
			Darken = true, Effect = "None", Transparency = 0,
		},
	}, Window)
	self.Window = W
	if cfg.Folder then self.Folder = cfg.Folder end

	local gui = new("ScreenGui", {
		Name = string.sub(HttpService:GenerateGUID(false), 1, 8), ResetOnSpawn = false, IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 9999,
	})
	gui.Parent = LP:WaitForChild("PlayerGui")
	W.Gui = gui

	W.Darken = new("Frame", { Size = SCL(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, Parent = gui })

	local root = new("Frame", {
		AnchorPoint = V2(0.5, 0.5), Position = SCL(0.5, 0.5), Size = OFF(size.X, size.Y),
		BackgroundTransparency = W.Menu.Transparency, ClipsDescendants = true, ZIndex = 2, Parent = gui,
	})
	corner(root, 14)
	surface(root, "Background")
	W.RimStroke = rim(root)
	W.Root = root
	-- looping engine tweens (cheaper and smoother than Lua Heartbeat loops); they only play while
	-- the window is visible
	W._loops = {}
	function W:_loop(obj, t, props, style, reverses)
		local tween = TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, reverses ~= false), props)
		table.insert(self._loops, tween)
		if root.Visible then tween:Play() end
		return tween
	end
	bind(root:GetPropertyChangedSignal("Visible"), function()
		for _, tween in ipairs(W._loops) do
			if root.Visible then tween:Play() else tween:Pause() end
		end
	end)
	-- light that slowly travels around the window edge
	do
		local g = W.RimStroke:FindFirstChildOfClass("UIGradient")
		if g then
			W:_loop(g, 6, { Rotation = 450 }, Enum.EasingStyle.Linear, false)
			-- neon rim: the stroke stays white so the gradient alone decides its colours
			W.RimStroke.Thickness = 1.5
			hook(function()
				local th = Lumen.Theme
				W.RimStroke.Color = Color3.new(1, 1, 1)
				g.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, th.Accent), ColorSequenceKeypoint.new(0.5, th.Gradient), ColorSequenceKeypoint.new(1, th.Accent),
				})
				g.Transparency = NumberSequence.new(0)
			end)
		end
	end
	W.Scaler = new("UIScale", { Parent = root })
	new("TextButton", { Modal = true, BackgroundTransparency = 1, Size = OFF(0, 0), Parent = root }) -- frees the mouse in first person

	-- ambience: a drifting aurora along the top and slow rising motes. Engine tweens, and they stop
	-- whenever the window is hidden, so this costs almost nothing.
	do
		local fx = new("Frame", { BackgroundTransparency = 1, Size = SCL(1, 1), ZIndex = 0, ClipsDescendants = true, Parent = root })
		W.Fx = fx
		-- covers the whole window and fades straight down to nothing, so it has no visible edge
		local aurora = new("Frame", { BorderSizePixel = 0, Size = SCL(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.45, ZIndex = 0, Parent = fx })
		local ag = new("UIGradient", {
			Rotation = 90, Offset = V2(0, -0.08),
			Transparency = NumberSequence.new({ KP(0, 0.45), KP(0.5, 0.92), KP(0.8, 1), KP(1, 1) }), Parent = aurora,
		})
		W:_loop(ag, 8, { Offset = V2(0, 0.08) })
		W:_loop(aurora, 5, { BackgroundTransparency = 0.7 })
		local rng, motes = Random.new(), {}
		for i = 1, 26 do
			local size = rng:NextInteger(2, 4)
			local x, y = rng:NextNumber(0.02, 0.98), rng:NextNumber(0.4, 1.02)
			local m = new("Frame", {
				BorderSizePixel = 0, AnchorPoint = V2(0.5, 0.5), Position = SCL(x, y), Size = OFF(size, size),
				BackgroundTransparency = rng:NextNumber(0.2, 0.55), ZIndex = 0, Parent = fx,
			})
			corner(m, 99)
			motes[i] = m
			W:_loop(m, rng:NextNumber(7, 16), { Position = SCL(x + rng:NextNumber(-0.05, 0.05), y - rng:NextNumber(0.35, 0.7)), BackgroundTransparency = 1 }, Enum.EasingStyle.Linear, false)
		end
		hook(function()
			local th = Lumen.Theme
			ag.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, th.Accent), ColorSequenceKeypoint.new(1, th.Gradient) })
			for i, m in ipairs(motes) do m.BackgroundColor3 = (i % 2 == 0) and th.Accent or th.Gradient end
		end)
	end

	if cfg.Image then
		local img = new("ImageLabel", {
			Size = SCL(1, 1), BackgroundTransparency = 1, Image = cfg.Image, ImageTransparency = cfg.ImageTransparency or 0.92,
			ScaleType = Enum.ScaleType.Crop, ZIndex = 0, Parent = root,
		})
		corner(img, 14)
	end

	-- top bar --------------------------------------------------------------------
	local top = new("Frame", { BackgroundTransparency = 1, Size = UD2(1, 0, 0, 54), Active = true, Parent = root })
	-- mark: a rimmed tile with an up-chevron sitting on a horizon
	local badge = new("Frame", { AnchorPoint = V2(0, 0.5), Position = UD2(0, 16, 0.5, 0), Size = OFF(30, 30), Parent = top })
	surface(badge, "Element", 0.14)
	corner(badge, 8)
	rim(badge)
	local mark = chevron(badge, 11, { Position = UD2(0.5, 0, 0.5, -1), Rotation = -90 }) -- ">" turned to "^"
	hook(function() for _, b in ipairs(mark.Bars) do b.BackgroundColor3 = Lumen.Theme.Text end end)
	horizon(badge, 0.6, { Position = UD2(0.5, 0, 1, -7) })

	local titleRow = new("Frame", { BackgroundTransparency = 1, Position = OFF(58, 0), Size = UD2(0.5, 0, 1, 0), Parent = top })
	local tl = list(titleRow, 10, Enum.FillDirection.Horizontal)
	tl.VerticalAlignment = Enum.VerticalAlignment.Center
	mono(titleRow, W.Brand, 12, "Text", autoX({ LayoutOrder = 1 }))
	paint(new("Frame", { Size = OFF(1, 12), LayoutOrder = 2, Parent = titleRow }), { BackgroundColor3 = "Border" })
	mono(titleRow, cfg.Title or "Hub", 12, "InactiveText", autoX({ LayoutOrder = 3 }))

	-- right side: status, crumb, version
	local meta = new("Frame", { BackgroundTransparency = 1, AnchorPoint = V2(1, 0.5), Position = UD2(1, -58, 0.5, 0), Size = UD2(0, 0, 0, 20), AutomaticSize = AUTO_X, Parent = top })
	local ml = list(meta, 14, Enum.FillDirection.Horizontal)
	ml.VerticalAlignment = Enum.VerticalAlignment.Center
	local status = new("Frame", { BackgroundTransparency = 1, Size = UD2(0, 0, 1, 0), AutomaticSize = AUTO_X, LayoutOrder = 1, Parent = meta })
	local sl = list(status, 7, Enum.FillDirection.Horizontal)
	sl.VerticalAlignment = Enum.VerticalAlignment.Center
	local sdot, sglow = statusDot(status, { LayoutOrder = 1 })
	mono(status, "Online", 11, "InactiveText", autoX({ LayoutOrder = 2 }))
	W.CrumbLabel = mono(meta, "", 11, "InactiveText", autoX({ LayoutOrder = 2 }))
	mono(meta, "V " .. Lumen.Version, 11, "InactiveText", autoX({ LayoutOrder = 3 }))
	-- breathing status light (engine tween instead of a per-frame Lua loop)
	sglow.Transparency, sdot.BackgroundTransparency = 0.55, 0
	W:_loop(sglow, 1.4, { Transparency = 0.95 })
	W:_loop(sdot, 1.4, { BackgroundTransparency = 0.25 })
	paint(new("Frame", { Position = UD2(0, 0, 1, -1), Size = UD2(1, 0, 0, 1), Parent = top }), { BackgroundColor3 = "Outline" })

	local close = new("TextButton", { AnchorPoint = V2(1, 0.5), Position = UD2(1, -14, 0.5, 0), Size = OFF(30, 30), Parent = top })
	corner(close, 7)
	paint(close, { BackgroundColor3 = "Element" })
	close.BackgroundTransparency = 1
	local closeRim = rim(close)
	closeRim.Transparency = 1
	local xHolder = new("Frame", { BackgroundTransparency = 1, AnchorPoint = V2(0.5, 0.5), Position = SCL(0.5, 0.5), Size = OFF(14, 14), Parent = close })
	local xBars = {}
	for _, r in ipairs({ 45, -45 }) do
		local bar = new("Frame", { AnchorPoint = V2(0.5, 0.5), Position = SCL(0.5, 0.5), Size = OFF(12, 1.5), Rotation = r, Parent = xHolder })
		corner(bar, 1)
		paint(bar, { BackgroundColor3 = "InactiveText" })
		table.insert(xBars, bar)
	end
	close.MouseEnter:Connect(function()
		tw(close, 0.15, { BackgroundTransparency = 0 })
		tw(closeRim, 0.15, { Transparency = 0 })
		tw(xHolder, 0.35, { Rotation = 90 })
		for _, b in ipairs(xBars) do tw(b, 0.15, { BackgroundColor3 = Lumen.Theme.Text }) end
	end)
	close.MouseLeave:Connect(function()
		tw(close, 0.2, { BackgroundTransparency = 1 })
		tw(closeRim, 0.2, { Transparency = 1 })
		tw(xHolder, 0.35, { Rotation = 0 })
		for _, b in ipairs(xBars) do tw(b, 0.2, { BackgroundColor3 = Lumen.Theme.InactiveText }) end
	end)
	close.MouseButton1Click:Connect(function() W:SetOpen(false) end)
	draggable(root, top)

	-- sidebar ----------------------------------------------------------------------
	mono(root, "Navigation", 10, "InactiveText", { Position = OFF(28, 66), Size = OFF(180, 14) })
	W.TabLayer = new("Frame", { BackgroundTransparency = 1, Position = OFF(12, 88), Size = UD2(0, 196, 1, -166), ClipsDescendants = true, Parent = root })
	local pill = new("Frame", { Size = UD2(1, 0, 0, 40), Parent = W.TabLayer })
	surface(pill, "Element", 0.12)
	corner(pill, 7)
	rim(pill)
	horizon(pill, 0.7)
	W.TabPill = pill

	W.TabList = new("ScrollingFrame", {
		BackgroundTransparency = 1, Position = OFF(12, 88), Size = UD2(0, 196, 1, -166), CanvasSize = OFF(0, 0),
		AutomaticCanvasSize = AUTO_Y, ScrollBarThickness = 0, ZIndex = 2, Parent = root,
	})
	list(W.TabList, 4)
	bind(W.TabList:GetPropertyChangedSignal("CanvasPosition"), function() W:_movePill(true) end)
	bind(W.TabList:GetPropertyChangedSignal("AbsoluteSize"), function() W:_movePill(true) end)

	-- brand block, bottom left
	local foot = new("Frame", { BackgroundTransparency = 1, AnchorPoint = V2(0, 1), Position = UD2(0, 16, 1, -16), Size = OFF(192, 52), Parent = root })
	paint(new("Frame", { Size = UD2(0, 18, 0, 1), Position = OFF(0, 0), Parent = foot }), { BackgroundColor3 = "Border" })
	text(foot, W.Brand, 24, "Text", { FontFace = Lumen.BoldFont, Position = OFF(0, 8), Size = UD2(1, 0, 0, 24) })
	local footer = mono(foot, cfg.Footer or "", 10, "InactiveText", { Position = OFF(0, 36), Size = UD2(1, 0, 0, 14) })
	if not cfg.Footer then
		task.spawn(function()
			local ok, info = pcall(Marketplace.GetProductInfo, Marketplace, game.PlaceId)
			if ok and type(info) == "table" and info.Name then footer.Text = string.upper(info.Name) end
		end)
	end

	paint(new("Frame", { Position = OFF(220, 54), Size = UD2(0, 1, 1, -54), Parent = root }), { BackgroundColor3 = "Outline" })

	-- content ------------------------------------------------------------------------
	local content = new("Frame", { BackgroundTransparency = 1, Position = OFF(236, 66), Size = UD2(1, -248, 1, -66), Parent = root })
	local search = new("Frame", { Size = UD2(1, -14, 0, 40), Parent = content })
	paint(search, { BackgroundColor3 = "Background" })
	corner(search, 7)
	local searchEdge = rim(search)
	searchEdge.Transparency = 0.2
	local searchLine = horizon(search, 0.7, { BackgroundTransparency = 1 })
	local icon = new("Frame", { BackgroundTransparency = 1, AnchorPoint = V2(0, 0.5), Position = UD2(0, 14, 0.5, 0), Size = OFF(16, 16), Parent = search })
	local ring = new("Frame", { BackgroundTransparency = 1, Position = OFF(1, 1), Size = OFF(10, 10), Parent = icon })
	corner(ring, 5)
	stroke(ring, "InactiveText", 1.5)
	paint(new("Frame", { AnchorPoint = V2(0.5, 0.5), Position = OFF(12.5, 12.5), Size = OFF(6, 1.5), Rotation = 45, Parent = icon }), { BackgroundColor3 = "InactiveText" })
	local sbox = new("TextBox", {
		BackgroundTransparency = 1, Position = OFF(40, 0), Size = UD2(1, -110, 1, 0), PlaceholderText = "Search all tabs",
		ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left, Parent = search,
	})
	paint(sbox, { TextColor3 = "Text", PlaceholderColor3 = "InactiveText" })
	local kbd = new("Frame", { AnchorPoint = V2(1, 0.5), Position = UD2(1, -10, 0.5, 0), Size = OFF(0, 22), AutomaticSize = AUTO_X, Parent = search })
	paint(kbd, { BackgroundColor3 = "Element" })
	corner(kbd, 5)
	stroke(kbd, "Outline")
	pad(kbd, 7, 7, 0, 0)
	W.KeyHint = mono(kbd, W.MenuKey, 10, "InactiveText", autoX())
	sbox:GetPropertyChangedSignal("Text"):Connect(function() W:_search(sbox.Text) end)
	sbox.Focused:Connect(function()
		tw(searchEdge, 0.2, { Transparency = 0 })
		tw(searchLine, 0.25, { BackgroundTransparency = 0 })
	end)
	sbox.FocusLost:Connect(function()
		tw(searchEdge, 0.25, { Transparency = 0.2 })
		tw(searchLine, 0.3, { BackgroundTransparency = 1 })
	end)
	W.SearchBox = sbox
	W.Pages = new("Frame", { BackgroundTransparency = 1, Position = OFF(0, 54), Size = UD2(1, 0, 1, -54), ClipsDescendants = true, Parent = content })

	-- the window's own horizon, breathing slowly along the bottom edge
	local winLine = horizon(root, 0.7, { ZIndex = 4 })
	winLine.BackgroundTransparency = 0.15
	W:_loop(winLine, 2.8, { BackgroundTransparency = 0.45 })

	-- opening flash: a light streak runs across the top bar once
	local sweep = new("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0, AnchorPoint = V2(0.5, 0),
		Position = UD2(-0.3, 0, 0, 0), Size = UD2(0.35, 0, 0, 54), ZIndex = 6, Parent = root })
	paint(sweep, { BackgroundColor3 = "Accent" })
	new("UIGradient", { Rotation = 0, Transparency = NumberSequence.new({ KP(0, 1), KP(0.5, 0.82), KP(1, 1) }), Parent = sweep })
	W._sweep = sweep

	-- resize grip: two short hairlines in the corner
	local grip = new("TextButton", { AnchorPoint = V2(1, 1), Position = UD2(1, -4, 1, -4), Size = OFF(14, 14), BackgroundTransparency = 1, ZIndex = 5, Parent = root })
	for i, len in ipairs({ 10, 5 }) do
		local g = new("Frame", { AnchorPoint = V2(0.5, 0.5), Position = UD2(1, -len / 2 - 1 - (i - 1) * 0, 1, -len / 2 - 1), Size = OFF(len * 1.41, 1), Rotation = -45, ZIndex = 5, Parent = grip })
		paint(g, { BackgroundColor3 = "Border" })
	end
	grip.InputBegan:Connect(function(input)
		if not isPress(input) then return end
		local start = pointer(input)
		local fx, fy, from = root.Size.X.Offset, root.Size.Y.Offset, root.Position
		follow(input, function(p)
			local s = W.Scaler.Scale
			local d = (p - start) / s
			local nx, ny = math.max(700, fx + d.X), math.max(460, fy + d.Y)
			root.Size = OFF(nx, ny)
			root.Position = UD2(from.X.Scale, from.X.Offset + (nx - fx) * s / 2, from.Y.Scale, from.Y.Offset + (ny - fy) * s / 2)
		end)
	end)

	W.Cover = new("Frame", { Size = SCL(1, 1), ZIndex = 50, Visible = false, Parent = root })
	paint(W.Cover, { BackgroundColor3 = "Background" })
	corner(W.Cover, 14)

	W.Overlay = new("Frame", { BackgroundTransparency = 1, Size = SCL(1, 1), ZIndex = 100, Parent = gui })
	buildExtras(W, gui)

	W:_applyScale()
	local cam = workspace.CurrentCamera
	if cam then
		bind(cam:GetPropertyChangedSignal("ViewportSize"), function() W:_applyScale() end)
	end
	W:SetWatermark(true)
	-- Silent Load (Configs section): start hidden, with no opening animation; the menu key opens it
	local silent = false
	pcall(function() silent = isfile(self:_cfgPath() .. "/silent.txt") end)
	if silent then
		W.Open = false
		root.Visible = false
		W:_refreshBackdrop()
	else
		W:SetOpen(true)
	end
	return W
end

--------------------------------------------------------------------------------
-- keybind list, notifications, global input
--------------------------------------------------------------------------------

function Lumen:_refreshBinds()
	local W = self.Window
	if not W or not W.KeyListBody then return end
	for _, c in ipairs(W.KeyListBody:GetChildren()) do
		if c:IsA("Frame") then c:Destroy() end
	end
	for i, kb in ipairs(self._binds) do
		if kb.Mode ~= "Press" and kb.Value ~= "None" and kb:GetState() then
			local row = new("Frame", { BackgroundTransparency = 1, Size = UD2(1, 0, 0, 22), LayoutOrder = i, Parent = W.KeyListBody })
			text(row, kb.Text, 14, "Text", { Size = UD2(1, -60, 1, 0) })
			mono(row, kb.Value, 10, "InactiveText", { TextXAlignment = Enum.TextXAlignment.Right })
		end
	end
end

function Lumen:Notify(a, duration)
	local W = self.Window
	if not W then return end
	local o = type(a) == "table" and a or { Text = tostring(a), Duration = duration }
	local dur = o.Duration or 4
	local slot = new("Frame", { BackgroundTransparency = 1, Size = UD2(1, 0, 0, 0), AutomaticSize = AUTO_Y, Parent = W.Notes })
	-- a plain Frame that slides in from off-screen (an auto-sized CanvasGroup rendered stale ghosts)
	local card = new("Frame", { Position = UD2(1, 40, 0, 0), Size = UD2(1, 0, 0, 0), AutomaticSize = AUTO_Y, Parent = slot })
	surface(card, "Inline", 0.05)
	corner(card, 8)
	rim(card)
	-- compact pill: "</> DIVERGENCE  Title" over the message, with a neon bar counting down underneath
	local inner = new("Frame", { BackgroundTransparency = 1, Size = UD2(1, 0, 0, 0), AutomaticSize = AUTO_Y, Parent = card })
	pad(inner, 11, 11, 7, 9)
	list(inner, 2)
	local headRow = new("Frame", { BackgroundTransparency = 1, Size = UD2(1, 0, 0, 14), LayoutOrder = 1, Parent = inner })
	local hl = list(headRow, 7, Enum.FillDirection.Horizontal)
	hl.VerticalAlignment = Enum.VerticalAlignment.Center
	mono(headRow, "</>", 11, "Accent", autoX({ LayoutOrder = 1 }))
	mono(headRow, W.Brand, 10, "InactiveText", autoX({ LayoutOrder = 2 }))
	text(headRow, o.Title or "Notice", 13, "Text", autoX({ LayoutOrder = 3, FontFace = Lumen.BoldFont }))
	if o.Text and o.Text ~= "" then
		text(inner, o.Text, 13, "InactiveText", {
			Size = UD2(1, 0, 0, 0), AutomaticSize = AUTO_Y, TextWrapped = true, TextTruncate = Enum.TextTruncate.None, LayoutOrder = 2,
		})
	end
	local line = new("Frame", { BorderSizePixel = 0, Position = UD2(0, 0, 1, -2), Size = UD2(1, 0, 0, 2), Parent = card })
	corner(line, 2)
	line.BackgroundColor3 = Color3.new(1, 1, 1)
	new("UIGradient", { Color = ColorSequence.new(Lumen.Theme.Accent, Lumen.Theme.Gradient), Parent = line })

	tw(card, 0.5, { Position = UD2(0, 0, 0, 0) })
	tw(line, dur, { Size = UD2(0, 0, 0, 1) }, Enum.EasingStyle.Linear)
	task.delay(dur, function()
		tw(card, 0.35, { Position = UD2(1, 40, 0, 0) }, EASE, Enum.EasingDirection.In)
		task.wait(0.35)
		slot:Destroy()
	end)
end

function Lumen:OnUnload(fn)
	table.insert(self._unload, fn)
end

function Lumen:Unload()
	if self.Unloaded then return end
	self.Unloaded = true
	self:_closePopup()
	for _, fn in ipairs(self._unload) do pcall(fn) end
	for _, c in ipairs(self._conns) do pcall(function() c:Disconnect() end) end
	local W = self.Window
	if W then
		if W._wmConn then W._wmConn:Disconnect() end
		if W._tipConn then W._tipConn:Disconnect() end
		if W.Blur then W.Blur:Destroy() end
		if W.Gui then W.Gui:Destroy() end
	end
	if shared.__Lumen == self then shared.__Lumen = nil end
end

bind(UIS.InputBegan, function(input)
	if Lumen._capturing or input == Lumen._lastBind then return end
	if UIS:GetFocusedTextBox() then return end
	local name = keyName(input)
	if not name then return end
	local W = Lumen.Window
	if W and name == W.MenuKey then W:Toggle() end
	for _, kb in ipairs(Lumen._binds) do
		if kb.Value == name then kb:_press(true) end
	end
end)

bind(UIS.InputEnded, function(input)
	local name = keyName(input)
	if not name then return end
	for _, kb in ipairs(Lumen._binds) do
		if kb.Value == name and kb.Mode == "Hold" then kb:_press(false) end
	end
end)

--------------------------------------------------------------------------------
-- settings tab (Menu / Themes / Configs)
--------------------------------------------------------------------------------

function Window:AddSettingsTab(name)
	local W = self
	local tab = W:AddTab(name or "Settings")
	local menu = tab:AddSubTab("Menu")
	local themes = tab:AddSubTab("Themes")
	local configs = tab:AddSubTab("Configs")

	-- Menu
	local general = menu:AddSection("General", "Left", { Open = true })
	general:AddButton({ Text = "Unload", Confirm = true, Callback = function() Lumen:Unload() end })
	general:AddButton({ Text = "Reset Positions", Callback = function() W:ResetPositions() end })
	general:AddKeybind("Lumen_MenuKeybind", {
		Text = "Menu Keybind", Default = W.MenuKey, Mode = "Press", NoMode = true,
		ChangedCallback = function(key)
			W.MenuKey = key
			if W.KeyHint then W.KeyHint.Text = string.upper(key) end
		end,
	})
	general:AddDropdown("Lumen_Scale", {
		Text = "Menu Scale", Values = { "Small", "Medium", "Large" }, Default = "Medium",
		Callback = function(v)
			W.Preset = ({ Small = 0.85, Medium = 1, Large = 1.15 })[v] or 1
			W:_applyScale()
		end,
	})
	general:AddToggle("Lumen_AutoSave", { Text = "Auto Save Config", Callback = function(v) Lumen.AutoSave = v end })

	local look = menu:AddSection("Appearance", "Right", { Open = true })
	look:AddToggle("Lumen_Watermark", { Text = "Show Watermark", Default = true, Callback = function(v) W:SetWatermark(v) end })
	look:AddToggle("Lumen_Fx", { Text = "Menu Particles & Aurora", Default = true, Callback = function(v) W.Fx.Visible = v end })
	look:AddToggle("Lumen_KeybindList", { Text = "Show Keybind List", Callback = function(v) W.KeyList.Visible = v end })
	look:AddToggle("Lumen_MenuButton", { Text = "Show Menu Button", Default = W.MenuButton.Visible, Callback = function(v) W.MenuButton.Visible = v end })
	look:AddSlider("Lumen_BgTransparency", {
		Text = "Background Transparency", Min = 0, Max = 1, Decimals = 2, Default = W.Menu.Transparency,
		Callback = function(v)
			W.Menu.Transparency = v
			W.Root.BackgroundTransparency = v
		end,
	})
	look:AddToggle("Lumen_Darken", { Text = "Background Darken", Default = W.Menu.Darken, Callback = function(v) W.Menu.Darken = v; W:_refreshBackdrop() end })
	look:AddDropdown("Lumen_Effect", { Text = "Background Effect", Values = { "None", "Blur" }, Default = "None", Callback = function(v) W.Menu.Effect = v; W:_refreshBackdrop() end })
	look:AddSlider("Lumen_TweenTime", { Text = "Menu Tween Time", Min = 0, Max = 1, Decimals = 2, Default = W.Menu.TweenTime, Callback = function(v) W.Menu.TweenTime = v end })
	look:AddSlider("Lumen_FadeSpeed", { Text = "Menu Fade Speed", Min = 0, Max = 1, Decimals = 2, Default = W.Menu.FadeSpeed, Callback = function(v) W.Menu.FadeSpeed = v end })
	local styles = {}
	for _, e in ipairs(Enum.EasingStyle:GetEnumItems()) do table.insert(styles, e.Name) end
	look:AddDropdown("Lumen_TweenStyle", { Text = "Menu Tween Style", Values = styles, Default = EASE.Name, Callback = function(v) W.Menu.Style = Enum.EasingStyle[v] end })
	look:AddDropdown("Lumen_TweenDirection", { Text = "Menu Tween Direction", Values = { "In", "Out", "InOut" }, Default = "Out", Callback = function(v) W.Menu.Direction = Enum.EasingDirection[v] end })

	-- Themes
	local colors = themes:AddSection("Palette · Luminance", "Left", { Open = true })
	Lumen._themePickers = {}
	for _, key in ipairs(Lumen.ThemeOrder) do
		Lumen._themePickers[key] = colors:AddColorPicker("Lumen_Theme_" .. key, {
			Text = Lumen.ThemeNames[key] or key, Default = Lumen.Theme[key], NoSave = true,
			Callback = function(c) Lumen:SetThemeColor(key, c) end,
		})
	end

	local manage = themes:AddSection("Manage", "Right", { Open = true })
	manage:AddDropdown("Lumen_ThemePreset", {
		Text = "Preset", Values = Lumen.PresetOrder, Default = "Divergence", NoSave = true,
		Callback = function(v) if Lumen.Presets[v] then Lumen:SetTheme(Lumen.Presets[v]) end end,
	})
	local themeSelect = manage:AddDropdown("Lumen_ThemeSelect", { Text = "Saved Themes", Values = Lumen:ListThemes(), AllowNull = true, NoSave = true })
	local themeName = manage:AddInput("Lumen_ThemeName", { Text = "Theme Name", Placeholder = "aurora-deck", NoSave = true })
	local function refreshThemes() themeSelect:SetValues(Lumen:ListThemes()) end
	manage:AddButton({ Text = "Load", Callback = function()
		if themeSelect.Value and Lumen:LoadTheme(themeSelect.Value) then Lumen:Notify("Loaded theme " .. themeSelect.Value) end
	end }):AddButton({ Text = "Save", Callback = function()
		if not themeSelect.Value then Lumen:Notify("Pick a theme in Saved Themes first") return end
		Lumen:SaveTheme(themeSelect.Value)
		Lumen:Notify("Saved theme " .. themeSelect.Value)
	end })
	manage:AddButton({ Text = "Create", Callback = function()
		local n = trim(themeName.Value)
		if n == "" then Lumen:Notify("Type a theme name first") return end
		Lumen:SaveTheme(n)
		refreshThemes()
		themeSelect:Set(n, true)
		Lumen:Notify("Created theme " .. n)
	end }):AddButton({ Text = "Delete", Confirm = true, Callback = function()
		if not themeSelect.Value then return end
		Lumen:DeleteTheme(themeSelect.Value)
		themeSelect:Set(nil, true)
		refreshThemes()
	end })
	manage:AddButton({ Text = "Refresh", Callback = refreshThemes })
	local themeAuto = manage:AddToggle("Lumen_ThemeAutoload", {
		Text = "Autoload Theme", NoSave = true,
		Callback = function(v)
			Lumen._themeAutoload = v
			if v then Lumen:_themeChanged() else removeFile(Lumen:_themePath() .. "/autoload.json") end
		end,
	})

	-- Configs
	local cfgSection = configs:AddSection("Config", "Left", { Open = true })
	local cfgName = cfgSection:AddInput("Lumen_ConfigName", { Text = "Config Name", Placeholder = "Config name", NoSave = true })
	local cfgSelect = cfgSection:AddDropdown("Lumen_ConfigSelect", {
		Text = "Config Select", Values = Lumen:ListConfigs(), AllowNull = true, NoSave = true,
		Callback = function(v) Lumen.CurrentConfig = v end,
	})
	local function refreshConfigs() cfgSelect:SetValues(Lumen:ListConfigs()) end
	local autoPath = function() return Lumen:_cfgPath() .. "/autoload.txt" end
	cfgSection:AddButton({ Text = "Load", Callback = function()
		if cfgSelect.Value and Lumen:LoadConfig(cfgSelect.Value) then Lumen:Notify("Loaded config " .. cfgSelect.Value) end
	end }):AddButton({ Text = "Save", Callback = function()
		if not cfgSelect.Value then Lumen:Notify("Pick a config in Config Select first") return end
		Lumen:SaveConfig(cfgSelect.Value)
		Lumen:Notify("Saved config " .. cfgSelect.Value)
	end })
	cfgSection:AddButton({ Text = "Create", Callback = function()
		local n = trim(cfgName.Value)
		if n == "" then Lumen:Notify("Type a config name first") return end
		Lumen:SaveConfig(n)
		refreshConfigs()
		cfgSelect:Set(n)
		Lumen:Notify("Created config " .. n)
	end }):AddButton({ Text = "Delete", Confirm = true, Callback = function()
		if not cfgSelect.Value then return end
		Lumen:DeleteConfig(cfgSelect.Value)
		cfgSelect:Set(nil)
		refreshConfigs()
	end })
	cfgSection:AddButton({ Text = "Refresh", Callback = refreshConfigs })
	local cfgAuto
	cfgAuto = cfgSection:AddToggle("Lumen_ConfigAutoload", {
		Text = "Autoload Config", NoSave = true,
		Callback = function(v)
			if not hasFS() then return end
			if v then
				if not cfgSelect.Value then
					Lumen:Notify("Pick a config in Config Select first")
					cfgAuto:Set(false, true)
					return
				end
				ensureFolder(Lumen:_cfgPath())
				pcall(writefile, autoPath(), cfgSelect.Value)
			else
				removeFile(autoPath())
			end
		end,
	})

	local silentPath = function() return Lumen:_cfgPath() .. "/silent.txt" end
	local silentOn = false
	pcall(function() silentOn = isfile(silentPath()) end)
	cfgSection:AddToggle("Lumen_SilentLoad", {
		Text = "Silent Load", Default = silentOn, NoSave = true,
		Callback = function(v)
			if not hasFS() then return end
			if v then
				ensureFolder(Lumen:_cfgPath())
				pcall(writefile, silentPath(), "1")
			else
				removeFile(silentPath())
			end
		end,
	})
	cfgSection:AddButton({ Text = "Set as Autoload", Callback = function()
		if not hasFS() then return end
		if not cfgSelect.Value then Lumen:Notify("Pick a config in Config Select first") return end
		ensureFolder(Lumen:_cfgPath())
		if pcall(writefile, autoPath(), cfgSelect.Value) then
			cfgAuto:Set(true, true)
			Lumen:Notify(cfgSelect.Value .. " will now load automatically")
		else
			Lumen:Notify("Could not save the autoload setting")
		end
	end })

	-- autoload after the script that built the menu has finished adding its options
	task.defer(function()
		local themeData = readJSON(Lumen:_themePath() .. "/autoload.json")
		if themeData then
			Lumen:SetTheme(themeData)
			Lumen._themeAutoload = true
			themeAuto:Set(true, true)
		end
		if hasFS() then
			local ok, n = pcall(function() return isfile(autoPath()) and readfile(autoPath()) end)
			if ok and type(n) == "string" and n ~= "" then
				cfgSelect:Set(n, true)
				Lumen.CurrentConfig = n
				cfgAuto:Set(true, true)
				Lumen:LoadConfig(n)
			end
		end
	end)

	tab.Configs = configs
	return tab
end

return Lumen

end)()
-- World // Zero - hub (LUMEN)
-- Expects `Lumen` to already be defined (bundled build) or Lumen.lua in the executor workspace.
-- Put the bundled WorldZeroHub.lua into autoexec: every dungeon start/leave is a teleport to a new server.

local Lumen = Lumen or (isfile and isfile("Lumen.lua") and loadstring(readfile("Lumen.lua"))())
assert(Lumen, "LUMEN not loaded: put Lumen.lua in your executor workspace or use the bundled WorldZeroHub.lua")

if not game:IsLoaded() then game.Loaded:Wait() end

-- boss fight recorder (guards itself against running twice in one server)
if isfile and isfile("wz_fight_logger.lua") then
	task.spawn(function() pcall(function() loadstring(readfile("wz_fight_logger.lua"))() end) end)
end

-- re-executing replaces the previous instance
do
	local env = getgenv and getgenv() or _G
	local prev = env.WorldZeroLumen
	if prev and prev ~= Lumen and not prev.Unloaded then pcall(prev.Unload, prev) end
	env.WorldZeroLumen = Lumen
	-- remove windows / HUDs left behind by copies that were unloaded while still starting up
	pcall(function()
		local hui = gethui and gethui() or game:GetService("CoreGui")
		for _, g in ipairs(hui:GetChildren()) do
			if g.Name == "WZ_SessionHUD" then g:Destroy() end
		end
		for _, g in ipairs(game:GetService("Players").LocalPlayer.PlayerGui:GetChildren()) do
			if g:IsA("ScreenGui") and (g:GetAttribute("WZHub") or g.Name:match("^%x%x%x%x%x%x%x%x$")) then
				if g:GetAttribute("WZHub") then
					g:Destroy()
				else
					for _, t in ipairs(g:GetDescendants()) do
						if t:IsA("TextLabel") and t.Text:sub(1, 22) == "Needs WorldZeroHub.lua" then g:Destroy() break end
					end
				end
			end
		end
	end)
end

local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local LP = Players.LocalPlayer
local Remotes = RS:WaitForChild("Remotes")

local function safeRequire(inst)
	if not inst then return nil end
	local ok, m = pcall(require, inst)
	return ok and m or nil
end

local Shared = RS:WaitForChild("Shared")
local MissionData = safeRequire(Shared:FindFirstChild("Missions") and Shared.Missions:FindFirstChild("MissionData")) or {}
local WorldData = safeRequire(Shared:FindFirstChild("Teleport") and Shared.Teleport:FindFirstChild("WorldData")) or {}
local ItemDB = safeRequire(Shared:FindFirstChild("Items")) or {}
local Health = safeRequire(Shared:FindFirstChild("Health"))
local InventoryMod = safeRequire(Shared:FindFirstChild("Inventory"))
local Actions -- client module, required lazily (needs the character / profile to be set up)

local function getActions()
	if not Actions then Actions = safeRequire(RS:FindFirstChild("Client") and RS.Client:FindFirstChild("Actions")) end
	return Actions
end

local function remote(name)
	return Remotes:FindFirstChild(name)
end

local function fire(name, ...)
	local r = remote(name)
	if r then pcall(r.FireServer, r, ...) end
end

local function invoke(name, ...)
	local r = remote(name)
	if not r then return false end
	local args = table.pack(...)
	local ok, res = pcall(function() return r:InvokeServer(table.unpack(args, 1, args.n)) end)
	return ok, res
end

local function notify(title, text, dur)
	Lumen:Notify({ Title = title, Text = text, Duration = dur or 4 })
end

local function root()
	return LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
end

local function humanoid()
	return LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
end

local cleanup = {}
local function onUnload(fn) table.insert(cleanup, fn) end

--------------------------------------------------------------------------------
-- safety: never let anything fire the honeypot remotes
--------------------------------------------------------------------------------
-- Combat_AttackTarget = instant "autofarmer" flag + kick.
-- Combat_Attack must carry 67 as 4th arg (the game's own code does; we never fire it ourselves).
do
	local env = getgenv and getgenv() or _G
	if not env.__WZ_GUARD and hookfunction and newcclosure then
		env.__WZ_GUARD = true
		local BLOCK = { Combat_AttackTarget = true, Admin_DoCommand = true, Admin_ExecuteCommand = true, Admin_DoMission = true }
		local old
		old = hookfunction(Instance.new("RemoteEvent").FireServer, newcclosure(function(self, ...)
			if typeof(self) == "Instance" and BLOCK[self.Name] then return end
			return old(self, ...)
		end))
	end
end

--------------------------------------------------------------------------------
-- where are we
--------------------------------------------------------------------------------

local currentWorld
for _, w in pairs(WorldData) do
	if type(w) == "table" and w.LiveID == game.PlaceId then currentWorld = w break end
end
local missionWorldIds = {}
for _, m in pairs(MissionData) do
	if type(m) == "table" and m.WorldID then missionWorldIds[m.WorldID] = true end
end
local inDungeon = currentWorld ~= nil and missionWorldIds[currentWorld.ID] == true and not currentWorld.IsTown
local inLobby = not inDungeon

local fallenThrone
for _, m in pairs(MissionData) do
	if type(m) == "table" and m.NameTag == "The Fallen Throne" then fallenThrone = m break end
end
local inFallenThrone = fallenThrone ~= nil and currentWorld ~= nil and currentWorld.ID == fallenThrone.WorldID

local infiniteTower
for _, m in pairs(MissionData) do
	if type(m) == "table" and m.IsInfiniteTower then infiniteTower = m break end
end
local inInfiniteTower = infiniteTower ~= nil and currentWorld ~= nil and currentWorld.ID == infiniteTower.WorldID

-- dungeon list for the dropdown
local dungeons, dungeonByLabel = {}, {}
for _, m in pairs(MissionData) do
	if type(m) == "table" and m.ID and not m.Disabled and m.ShowOnProduction ~= false and m.NameTag then
		table.insert(dungeons, m)
	end
end
table.sort(dungeons, function(a, b)
	if (a.LevelRequirement or 0) ~= (b.LevelRequirement or 0) then return (a.LevelRequirement or 0) < (b.LevelRequirement or 0) end
	return a.ID < b.ID
end)
-- The game flags event dungeons itself (MissionData.EventDungeon: North Pole, Fallen Throne,
-- Vane's Lair, The Depths, Cradle of Hearts, Alien Invasion, Easter Arena); OG Tower is
-- NotPublicDungeon and the Heaven Raid needs 6 players. Those only open while their event runs, so
-- starting them outside it does nothing: they are hidden unless "Show event dungeons" is on, and
-- then marked [Event] / [Raid]. Towers and the daily nightmare dungeons are marked too.
local function dungeonKind(m)
	if m.EventDungeon or m.NotPublicDungeon or m.OtherEvent then return "Event" end
	if m.IsRaidDungeon or (m.MinimumPlayers or 1) > 1 then return "Raid" end
	if m.DailyDungeon or m.IsDailyDungeon then return "Daily" end
	if m.IsTowerDungeon then return "Tower" end
	return nil
end
local dungeonLabels, dungeonLabelsAll = {}, {}
for _, m in ipairs(dungeons) do
	local kind = dungeonKind(m)
	local label = string.format("%s%s (Lv %d)", kind and ("[" .. kind .. "] ") or "", m.NameTag, m.LevelRequirement or 0)
	if dungeonByLabel[label] then label = label .. " #" .. m.ID end
	dungeonByLabel[label] = m
	table.insert(dungeonLabelsAll, label)
	if kind ~= "Event" and kind ~= "Raid" then table.insert(dungeonLabels, label) end
end
-- grouped by tag: normal dungeons first, then [Tower], [Daily], [Event], [Raid]; by level inside each group
local KIND_ORDER = { Tower = 1, Daily = 2, Event = 3, Raid = 4 }
local function byGroup(a, b)
	local ma, mb = dungeonByLabel[a], dungeonByLabel[b]
	local ga, gb = KIND_ORDER[dungeonKind(ma)] or 0, KIND_ORDER[dungeonKind(mb)] or 0
	if ga ~= gb then return ga < gb end
	if (ma.LevelRequirement or 0) ~= (mb.LevelRequirement or 0) then return (ma.LevelRequirement or 0) < (mb.LevelRequirement or 0) end
	return ma.ID < mb.ID
end
table.sort(dungeonLabels, byGroup)
table.sort(dungeonLabelsAll, byGroup)

--------------------------------------------------------------------------------
-- window
--------------------------------------------------------------------------------

local Window = Lumen:CreateWindow({
	Title = "World // Zero",
	Brand = "DIVERGENCE",
	Footer = inDungeon and ("Dungeon · " .. tostring(currentWorld and currentWorld.Name or "?")) or "Lobby",
	Keybind = Enum.KeyCode.RightShift,
})

pcall(function() Window.Gui:SetAttribute("WZHub", true) end) -- lets the next start find and remove it

local TabFarm = Window:AddTab("Farm")
local TabDungeon = Window:AddTab("Dungeon")
local TabLobby = Window:AddTab("Lobby")
local TabEvent = Window:AddTab("Event")

local F = Lumen.Flags

--------------------------------------------------------------------------------
-- combat
--------------------------------------------------------------------------------

local function alive(mob)
	if not mob or not mob.Parent or not mob.PrimaryPart then return false end
	if mob:FindFirstChild("IgnorePlayerHits") then return false end
	if Health then
		local ok, hp = pcall(Health.GetHealth, Health, mob)
		if ok and type(hp) == "number" then return hp > 0 end
	end
	return true
end

-- mobs we could not reach (behind walls / unreachable ledges) are skipped for a while
local bannedMobs = setmetatable({}, { __mode = "k" })

local function nearestMob(maxDist)
	local hrp = root()
	local mobs = workspace:FindFirstChild("Mobs")
	if not hrp or not mobs then return nil end
	local best, bestD = nil, maxDist or math.huge
	local now = os.clock()
	for _, m in ipairs(mobs:GetChildren()) do
		if alive(m) and not ((bannedMobs[m] or 0) > now) then
			local d = (m.PrimaryPart.Position - hrp.Position).Magnitude
			if d < bestD then best, bestD = m, d end
		end
	end
	return best, bestD
end

-- runs the game's own code at the privilege level of a normal game script. Some executors
-- (Potassium) otherwise block the game's require() calls: the attack then errors right after marking
-- the player busy, and no attack can ever start again.
local function gamePcall(fn, ...)
	local set, get = setthreadidentity, getthreadidentity
	if not (set and get) then return pcall(fn, ...) end
	local old = get()
	set(2)
	local result = table.pack(pcall(fn, ...))
	set(old)
	return table.unpack(result, 1, result.n)
end

local function useSkill(name)
	if name == "Pet ability" then
		-- same call as the game's PetSkill key; it can wait inside, so never block the fight loop
		local pet = safeRequire(Shared:FindFirstChild("PetSkills"))
		if pet and pet.UseSkill then task.spawn(gamePcall, pet.UseSkill, pet, LP) end
		return
	end
	local A = getActions()
	-- in its own thread: a swing waits partway through, which must not happen inside the frame callback
	if A then task.spawn(gamePcall, A.UseSkill, A, name) end
end

local function ensureDrawn()
	local A = getActions()
	if A and A.IsSheathed then
		local ok, sheathed = pcall(A.IsSheathed, A)
		if ok and sheathed then useSkill("Sheath") end
	end
end

-- movement: walk (Humanoid:MoveTo) or tween; never instant teleports
local tweenObj
local function moveTowards(pos)
	local hrp, hum = root(), humanoid()
	if not hrp or not hum then return end
	if F.MoveMode == "Tween" then
		local dist = (pos - hrp.Position).Magnitude
		if dist < 2 then return end
		if tweenObj then tweenObj:Cancel() end
		local goal = CFrame.new(pos, pos + (pos - hrp.Position) * Vector3.new(1, 0, 1))
		tweenObj = TweenService:Create(hrp, TweenInfo.new(dist / math.max(F.TweenSpeed or 40, 5), Enum.EasingStyle.Linear), { CFrame = goal })
		tweenObj:Play()
	else
		hum:MoveTo(pos)
	end
end

-- safe hover: mob hitboxes only reach about +-10 studs vertically (Combat.CheckHeightLogicForPart),
-- so we glide to a point above the target and hold there. Moves at a capped speed, never snaps.
local hover = { goal = nil, look = nil }
local routeStop = function() end -- tween travel (defined further down)

local function hpRatio()
	local char = LP.Character
	if not char or not Health then return 1 end
	local ok, hp = pcall(Health.GetHealth, Health, char)
	local ok2, mx = pcall(Health.GetMaxHealth, Health, char)
	if ok and ok2 and type(hp) == "number" and type(mx) == "number" and mx > 0 then return hp / mx end
	return 1
end

-- ground height under a point (ignores characters, mobs and coins).
-- Casts from just above the point so roofs / bridges overhead are not picked up.
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true -- the map walks on invisible "Collision" floors under terrain water
pcall(function() rayParams.RespectCanCollide = true end) -- skip trigger volumes / decor without collision
-- the ignore list is rebuilt once a second instead of on every ray (the hover runs 2 rays a frame)
local rayIgnoreAt, rayChar = -1e9, nil
local function groundY(pos, fallback, from)
	local now = os.clock()
	if now - rayIgnoreAt > 1 or rayChar ~= LP.Character then
		rayIgnoreAt, rayChar = now, LP.Character
		local ignore = { LP.Character }
		for _, n in ipairs({ "Characters", "Mobs", "Coins" }) do
			local f = workspace:FindFirstChild(n)
			if f then table.insert(ignore, f) end
		end
		rayParams.FilterDescendantsInstances = ignore
	end
	local up = from or 25
	local hit = workspace:Raycast(pos + Vector3.new(0, up, 0), Vector3.new(0, -(up + 60), 0), rayParams)
	return hit and hit.Position.Y or fallback
end

-- HRP centre height above the feet (R6 rigs report odd HipHeights, so never go below 3)
local function standHeight()
	local hrp, hum = root(), humanoid()
	local h = (hum and hum.HipHeight or 2) + (hrp and hrp.Size.Y * 0.5 or 1)
	return math.max(h, 3) + 0.4
end

do
	local conn = RunService.Heartbeat:Connect(function(dt)
		local goal = hover.goal
		if not goal then return end
		local hrp = root()
		if not hrp then return end
		local pos = hrp.Position
		local delta = goal - pos
		if hover.ground then delta = delta * Vector3.new(1, 0, 1) end -- height comes from the ground below
		local step = math.min(delta.Magnitude, math.max(hover.speed or F.TweenSpeed or 35, 5) * dt)
		local newPos = delta.Magnitude > 0.05 and (pos + delta.Unit * step) or Vector3.new(goal.X, pos.Y, goal.Z)
		if hover.ground then
			-- Follow the floor like walking. The probe always starts at the character itself (never at
			-- a computed foot height, which ended up below the floor after knockbacks and pushed us
			-- under the map). hover.floor = floor height we are standing over.
			local stand = standHeight()
			local floor = hover.floor
			-- fell / got pushed below the floor: put us back on the last safe spot
			if floor and pos.Y < floor - 4 and hover.safe and (hover.safe - pos).Magnitude < 40 then
				hrp.CFrame = CFrame.new(hover.safe) * (hrp.CFrame - hrp.CFrame.Position)
				hrp.AssemblyLinearVelocity = Vector3.zero
				hover.floor = nil
				return
			end
			if not floor or pos.Y < floor then
				-- (re)acquire the floor right under us
				floor = groundY(pos, nil, 1)
				if not floor then return end -- nothing below: let physics handle it this frame
				hover.floor = floor
			end
			local probe = groundY(Vector3.new(newPos.X, pos.Y, newPos.Z), nil, 1)
			local blocked = not probe -- void / hole in the map
				or probe > floor + 3 -- wall or step too high
				or (probe < floor - 12 and os.clock() - (hover.blockedSince or os.clock()) < 3) -- ledge: only drop after 3s stuck
			if blocked then
				hover.blockedSince = hover.blockedSince or os.clock()
				-- hold our height over the known floor; keeping `pos` let gravity sink us a bit
				-- every frame until we slid into pits / water
				newPos = Vector3.new(pos.X, floor + stand + (hover.curLift or 0), pos.Z)
			else
				hover.blockedSince = nil
				hover.floor = probe
				local cur = hover.curLift or 0
				cur += math.clamp((hover.lift or 0) - cur, -30 * dt, 30 * dt)
				hover.curLift = cur
				newPos = Vector3.new(newPos.X, probe + stand + cur, newPos.Z)
				hover.safe = Vector3.new(newPos.X, probe + stand + 0.5, newPos.Z)
			end
		end
		local look = hover.look and (hover.look - newPos) * Vector3.new(1, 0, 1)
		if look and look.Magnitude > 0.1 then
			hrp.CFrame = CFrame.lookAt(newPos, newPos + look)
		else
			hrp.CFrame = CFrame.new(newPos) * (hrp.CFrame - hrp.CFrame.Position)
		end
		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.AssemblyAngularVelocity = Vector3.zero
	end)
	onUnload(function() conn:Disconnect() end)
end

-- per-mob attack reach from Shared.Mobs.Mobs.<Name>.Attacks (AttackDistance + shape size)
local MobDefs = RS.Shared:FindFirstChild("Mobs") and RS.Shared.Mobs:FindFirstChild("Mobs")
local reachCache = {}
local function mobReach(mob)
	local name = mob.Name
	if reachCache[name] then return reachCache[name] end
	local reach = 16 -- fallback when a mob has no readable data
	local def = MobDefs and safeRequire(MobDefs:FindFirstChild(name))
	if type(def) == "table" and type(def.Attacks) == "table" then
		reach = 0
		for _, atk in pairs(def.Attacks) do
			if type(atk) == "table" then
				local shape = math.max(atk.shapeDepth or 0, atk.shapeRadius or 0, atk.shapeLength or 0, atk.Range or 0, atk.Radius or 0)
				reach = math.max(reach, (atk.AttackDistance or 0) + shape)
			end
		end
		if reach == 0 then reach = 16 end
	end
	reachCache[name] = reach
	return reach
end

-- these bosses launch homing skulls whenever a player is more than 40 studs away (flat distance),
-- so fights against them stay inside that
local SKULL_BOSSES = { BOSSFallenKing = true, BOSSFallenQueen = true }

-- how far from this mob to circle (its reach plus the "extra distance" slider)
local function orbitRadius(mob)
	-- these bosses' listed reach is huge, which pinned the distance at the cap and made the slider
	-- do nothing; for them the slider sets the distance directly (always under the 40-stud skull limit)
	if SKULL_BOSSES[mob.Name] then return math.clamp(14 + (F.OrbitMargin or 8), 16, 38) end
	return math.clamp(mobReach(mob) + (F.OrbitMargin or 8), 12, 42)
end

local function stopMoving()
	hover.goal, hover.look, hover.speed, hover.ground, hover.lift, hover.curLift = nil, nil, nil, nil, nil, nil
	hover.floor, hover.blockedSince = nil, nil -- keep hover.safe as a fallback spot
	if tweenObj then tweenObj:Cancel() tweenObj = nil end
	routeStop()
	local hrp, hum = root(), humanoid()
	if hum and hrp then hum:MoveTo(hrp.Position) end
end

local status = { text = "idle" }

-- movement speed for tween approach, orbit and hover (one slider for all of them)
local function moveSpeed()
	return math.max(F.TweenSpeed or 35, 5)
end

-- Tween travel: plays the path waypoints as a chain of linear tweens. Each segment starts the
-- next one the moment it completes, so there is no pause between waypoints.
local route = { pts = nil, idx = 1, tween = nil, id = 0, target = nil }

routeStop = function()
	route.id += 1
	if route.tween then route.tween:Cancel() route.tween = nil end
	route.pts, route.target = nil, nil
end

local function routeActive()
	return route.tween ~= nil and route.tween.PlaybackState == Enum.PlaybackState.Playing
end

local function routeStep(id)
	if id ~= route.id or not route.pts then return end
	local hrp = root()
	local p = route.pts[route.idx]
	if not hrp or not p then route.tween = nil return end
	-- trigger runs stay on the ground: flying over a trigger never touches it
	local lift = (route.ground or F.SafeMode == "Off") and 0 or (F.OrbitHeight or 0)
	local goal = p.Position + Vector3.new(0, standHeight() + lift, 0) -- waypoints sit on the floor
	local flat = (goal - hrp.Position) * Vector3.new(1, 0, 1)
	local cf = flat.Magnitude > 0.1 and CFrame.lookAt(goal, goal + flat) or (CFrame.new(goal) * hrp.CFrame.Rotation)
	local t = TweenService:Create(hrp, TweenInfo.new(math.max((goal - hrp.Position).Magnitude / moveSpeed(), 0.03), Enum.EasingStyle.Linear), { CFrame = cf })
	route.tween = t
	t.Completed:Connect(function(state)
		if state == Enum.PlaybackState.Completed and id == route.id then
			route.idx += 1
			routeStep(id)
		end
	end)
	t:Play()
end

local function routeStart(pts, startIdx, target)
	routeStop()
	route.pts, route.idx, route.target = pts, startIdx, target
	routeStep(route.id)
end

-- no gravity build-up while a tween carries us (otherwise we drop at the end of each segment)
do
	local c = RunService.Heartbeat:Connect(function()
		if routeActive() then
			local hrp = root()
			if hrp then hrp.AssemblyLinearVelocity = Vector3.zero hrp.AssemblyAngularVelocity = Vector3.zero end
		end
	end)
	onUnload(function() c:Disconnect() end)
end

local finished = false -- set when the dungeon ends (farm stops, chests/leave take over)

-- navigation: client-side pathfinding around walls, followed with the same ground glide as Orbit.
-- The path is computed in the background; until it arrives we head straight for the target.
local PathfindingService = game:GetService("PathfindingService")
local nav = { target = nil, points = nil, idx = 1, at = 0, busy = false }

local function navReset()
	nav.target, nav.points, nav.idx = nil, nil, 1
	nav.lastMove, nav.lastPos, nav.jumpTries = nil, nil, 0
end

local function computePath(from, to)
	nav.busy, nav.at = true, os.clock()
	task.spawn(function()
		local path = PathfindingService:CreatePath({
			AgentRadius = 2.5, AgentHeight = 5, AgentCanJump = true, AgentCanClimb = true, WaypointSpacing = 6,
			Costs = { Water = 60 }, -- swimming = drowning / slow: only if there is no other way
		})
		local ok = pcall(function() path:ComputeAsync(from, to) end)
		if ok and path.Status == Enum.PathStatus.Success then
			local pts = path:GetWaypoints()
			-- continue from the waypoint nearest to where we are now, not from the start
			local hrp, best, bestD = root(), 2, math.huge
			if hrp then
				for i, w in ipairs(pts) do
					local d = ((w.Position - hrp.Position) * Vector3.new(1, 0, 1)).Magnitude
					if d < bestD then best, bestD = i, d end
				end
			end
			nav.points, nav.idx = pts, math.min(best + 1, #pts)
		else
			nav.points = nil
		end
		nav.version = (nav.version or 0) + 1
		nav.target, nav.busy = to, false
	end)
end

-- Long-distance travel. "Walk" (default) runs the path with the character's own physics, which
-- handles stairs, slopes, ledges and jumps; "Glide" uses the fast ground glide (straight-ish, can
-- get blocked by steps). Fighting up close always uses Orbit.
local function navTo(pos, look, groundOnly)
	local hrp, hum = root(), humanoid()
	if not hrp or not hum then return end
	local now = os.clock()
	route.ground = groundOnly == true -- read by every tween segment
	local fromFloor = hrp.Position
	local gy = groundY(fromFloor, nil, 1)
	if gy then fromFloor = Vector3.new(fromFloor.X, gy + 2.5, fromFloor.Z) end -- start on the floor, even while lifted
	local tweenMode = (F.TravelMode or "Walk") ~= "Walk" -- "Tween" (old configs: "Glide")
	-- recompute when the target moved, or periodically; in tween mode only while not mid-route
	local refresh = tweenMode and (not routeActive() and now - nav.at > 1.5) or (not tweenMode and now - nav.at > 4)
	if not nav.busy and (not nav.target or (nav.target - pos).Magnitude > 15 or refresh) then
		computePath(fromFloor, pos)
	end
	if tweenMode then
		if hover.goal then
			hover.goal, hover.look, hover.ground, hover.lift, hover.curLift, hover.floor = nil, nil, nil, nil, nil, nil
		end
		if nav.version and nav.version ~= route.version and nav.target and (nav.target - pos).Magnitude <= 15 then
			route.version = nav.version
			if nav.points then
				routeStart(nav.points, nav.idx, pos)
			else
				-- no path found: tween straight at the floor below the target
				local gy2 = groundY(pos, nil, 4)
				routeStart({ { Position = Vector3.new(pos.X, gy2 or (pos.Y - 3), pos.Z) } }, 1, pos)
			end
			route.version = nav.version
		end
		return
	end
	-- current waypoint
	local goal, jump = pos, false
	local pts = nav.points
	if pts and nav.target and (nav.target - pos).Magnitude <= 15 then
		while nav.idx <= #pts do
			local flat = (pts[nav.idx].Position - hrp.Position) * Vector3.new(1, 0, 1)
			if flat.Magnitude < 4 then nav.idx += 1 else break end
		end
		if nav.idx <= #pts then
			goal = pts[nav.idx].Position
			jump = pts[nav.idx].Action == Enum.PathWaypointAction.Jump
		end
	end
	if (F.TravelMode or "Walk") == "Walk" then
		if hover.goal then
			hover.goal, hover.look, hover.ground, hover.lift, hover.curLift, hover.floor = nil, nil, nil, nil, nil, nil
		end
		hum:MoveTo(goal)
		if jump then hum.Jump = true end
		-- not moving for 1.2s: jump, then force a fresh path
		if nav.lastPos and (hrp.Position - nav.lastPos).Magnitude < 0.6 then
			if now - (nav.lastMove or now) > 1.2 then
				hum.Jump = true
				nav.jumpTries = (nav.jumpTries or 0) + 1
				nav.lastMove = now
				if nav.jumpTries >= 2 and not nav.busy then computePath(fromFloor, pos) nav.jumpTries = 0 end
			end
		else
			nav.lastMove = now
		end
		nav.lastPos = hrp.Position
	end
end

-- after dying we respawn somewhere else: forget paths and stuck timers
do
	local function hook(char)
		local hum = char:WaitForChild("Humanoid", 10)
		if hum then hum.Died:Connect(function() navReset() stopMoving() end) end
	end
	if LP.Character then task.spawn(hook, LP.Character) end
	local c = LP.CharacterAdded:Connect(function(ch) navReset() task.spawn(hook, ch) end)
	onUnload(function() c:Disconnect() end)
end

-- "am I getting closer?" per target; true once no progress was made for StuckTime seconds
local prog = { key = nil, best = math.huge, since = 0, last = 0 }
local function noProgress(key, d)
	local now = os.clock()
	-- a gap means we were doing something else (fighting, dodging), so this is a new attempt
	local stale = now - prog.last > 1.5
	prog.last = now
	if prog.key ~= key or stale then
		prog.key, prog.best, prog.since = key, d, now
		return false
	end
	if d < prog.best - 3 then
		prog.best, prog.since = d, now
		return false
	end
	return now - prog.since > (F.StuckTime or 8)
end

-- dungeon progression: the server only reacts to touches on trigger parts in MissionObjects
-- (checkpoints, cutscene / boss triggers, the start gate). With no mobs left we walk to the
-- nearest one we have not been inside yet, which makes the next group spawn.
-- keyed by name + rounded position: the map streams in and out, which recreates the parts,
-- so remembering the instance itself forgot visited triggers and made us walk back and forth
local visitedKeys = {}
local function trigKey(p)
	local q = p.Position / 8
	return string.format("%s@%d,%d,%d", p.Name, math.floor(q.X + 0.5), math.floor(q.Y + 0.5), math.floor(q.Z + 0.5))
end
local visitedTriggers = setmetatable({}, {
	__index = function(_, p) return visitedKeys[trigKey(p)] end,
	__newindex = function(_, p, v) visitedKeys[trigKey(p)] = v end,
})

local function insidePart(p, pos, pad)
	local lp = p.CFrame:PointToObjectSpace(pos)
	local h = p.Size * 0.5
	return math.abs(lp.X) <= h.X + pad and math.abs(lp.Z) <= h.Z + pad and math.abs(lp.Y) <= h.Y + pad + 8
end

-- the game's boss-intro camera target = where the dungeon ends (works in every dungeon that has one)
local function bossArena()
	local MO = workspace:FindFirstChild("MissionObjects")
	local cs = MO and MO:FindFirstChild("Cutscenes")
	local b = cs and cs:FindFirstChild("BossIntro")
	local at = b and (b:FindFirstChild("LookAt") or b:FindFirstChildWhichIsA("BasePart", true))
	return at and at:IsA("BasePart") and at.Position or nil
end

-- Checkpoints only set the respawn point (Missions: RegisterCheckpointPassthrough) and keep their
-- touch trigger forever; they never start a stage. Real stage triggers ("Main", CaveTrigger,
-- CutsceneTrigger, ...) lose their TouchTransmitter once the server has fired them.
-- Going for the nearest trigger of any kind made the run hop checkpoints first, skip the real
-- trigger, idle at the boss and then walk all the way back - so checkpoints are ignored.
local function isCheckpoint(d)
	return d:FindFirstAncestor("Checkpoints") ~= nil or d.Name:find("Checkpoint") ~= nil
end

-- Performance: MissionObjects holds thousands of parts (props, cabbage piles, barriers). Walking all
-- of them 4-6 times a second was the hub's biggest CPU cost in dungeons, so the trigger parts are
-- collected at most every 2 seconds and the loops below only look at that short list.
local trigCache = { list = {}, at = -1e9, mo = nil }

-- Hazards carry touch triggers too (they damage on touch): Dungeon 2-1 has 48 green dart spears
-- (MissionObjects.Darts...MeshPart) and swinging hammer heads, plus a huge invisible "HammerReset"
-- volume. Real stage triggers (Main, CaveTrigger, Room4Trigger, WallsTrigger, Checkpoints) are
-- invisible volumes, hazards are visible parts - so only invisible, non-hazard-named parts count.
local HAZARD_WORDS = { "reset", "trap", "kill", "damage", "hazard", "dart", "hammer", "spike", "lava" }
local function isStageTrigger(p)
	if p.Transparency < 0.9 then return false end
	local n = p.Name:lower()
	for _, w in ipairs(HAZARD_WORDS) do
		if n:find(w, 1, true) then return false end
	end
	-- a hazard's hit part sits inside its model (Darts.Model.Darts.MeshPart); check the ancestors too
	local a = p.Parent
	while a and a ~= workspace and a.Name ~= "MissionObjects" do
		local an = a.Name:lower()
		for _, w in ipairs(HAZARD_WORDS) do
			if an:find(w, 1, true) then return false end
		end
		a = a.Parent
	end
	return true
end
local function triggerParts()
	local MO = workspace:FindFirstChild("MissionObjects")
	if not MO then return {} end
	local now = os.clock()
	if trigCache.mo ~= MO or now - trigCache.at > 2 then
		local list = {}
		for _, d in ipairs(MO:GetDescendants()) do
			if d:IsA("TouchTransmitter") and d.Parent and d.Parent:IsA("BasePart") and isStageTrigger(d.Parent) then table.insert(list, d.Parent) end
		end
		trigCache.list, trigCache.at, trigCache.mo = list, now, MO
	end
	-- drop parts that lost their trigger since the last scan (the server consumed it)
	local out = {}
	for _, d in ipairs(trigCache.list) do
		if d.Parent and d:FindFirstChildOfClass("TouchTransmitter") then table.insert(out, d) end
	end
	return out
end

-- returns the stage trigger we are standing in (distance 0) or the nearest unvisited one.
-- Being inside no longer counts as visited by itself: the run first stands in it (see below).
local function nextTrigger(hrp)
	local best, bestD
	for _, d in ipairs(triggerParts()) do
		if not visitedTriggers[d] and not isCheckpoint(d) then
			if insidePart(d, hrp.Position, 0) then
				return d, 0
			end
			local dist = (d.Position - hrp.Position).Magnitude
			if not bestD or dist < bestD then best, bestD = d, dist end
		end
	end
	return best, bestD
end

local dwell = { trig = nil, since = 0 }

-- triggers we stood in for a second while fighting count as visited too,
-- otherwise the run walks back to them after the boss
local passiveIn = {}
local function markPassiveTriggers(hrp)
	local now = os.clock()
	for _, d in ipairs(triggerParts()) do
		if not visitedTriggers[d] then
			local k = trigKey(d)
			if insidePart(d, hrp.Position, 0) then
				passiveIn[k] = passiveIn[k] or now
				if now - passiveIn[k] >= 1 then visitedTriggers[d] = true end
			else
				passiveIn[k] = nil
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Auto Run Infinite Tower
-- From the tower's mission script: clearing a wave moves workspace.LobbyTeleport into the arena
-- (it is parked at 0,-50,0 otherwise); touching it starts the next floor, or it starts by itself
-- after 25 s. Boss floors wait until someone touches Boss_Gate.Interactions (walls, CanCollide
-- only while waiting). Boss kills spawn chests announced by Chests_SpawnChest.
--------------------------------------------------------------------------------
local tower = { chests = {}, touchedFloor = nil, touchStart = nil, chestWait = 0 }

if inInfiniteTower then
	local r = remote("Chests_SpawnChest")
	if r then
		local c = r.OnClientEvent:Connect(function(_, cf, id)
			if typeof(cf) == "CFrame" and type(id) == "string" then
				table.insert(tower.chests, { id = id, pos = cf.Position, at = os.clock() })
			end
		end)
		onUnload(function() c:Disconnect() end)
	end
end

local function towerFloors()
	local f, s = RS:FindFirstChild("ReplicateTowerFloor"), RS:FindFirstChild("ReplicateTowerStartFloor")
	return f and f.Value, s and s.Value
end

-- same rule as the server's IsBossFloor
local function towerBossFloor(f, s)
	local d = f - s
	return d >= 5 and (d == 5 or f % 5 == 0)
end

local function towerHalt()
	routeStop()
	hover.goal, hover.look, hover.ground, hover.lift, hover.curLift, hover.floor = nil, nil, nil, nil, nil, nil
end

-- walk to goal, then stand there and touch the part; true once we are there
local function towerTouch(hrp, part, goal, label, reach, push)
	local d = ((goal - hrp.Position) * Vector3.new(1, 0, 1)).Magnitude
	if d > (reach or 10) then
		status.text = string.format("%s · %d studs", label, d)
		navTo(goal, nil, true)
		if noProgress(part, d) then navReset() end
		return false
	end
	towerHalt()
	local hum = humanoid()
	if hum then hum:MoveTo(push or goal) end
	if firetouchinterest then
		pcall(firetouchinterest, hrp, part, 0)
		pcall(firetouchinterest, hrp, part, 1)
	end
	status.text = label
	return true
end

local function closestOnPart(p, pos)
	local l = p.CFrame:PointToObjectSpace(pos)
	local h = p.Size * 0.5
	return p.CFrame:PointToWorldSpace(Vector3.new(math.clamp(l.X, -h.X, h.X), math.clamp(l.Y, -h.Y, h.Y), math.clamp(l.Z, -h.Z, h.Z)))
end

-- chests, teleporter and boss gate; true when it handled this tick (no fighting needed)
local function towerStep(hrp)
	local floor, start = towerFloors()
	if not floor or not start then return false end

	-- reset at the chosen wave: start the tower again from inside it. If the server ignores that,
	-- keep playing and try again every 20 s. A wave at or below the run's start floor never resets,
	-- otherwise every new run would end right away.
	local resetAt = F.TowerResetFloor or 200
	if F.TowerReset and infiniteTower and resetAt > start and floor >= resetAt and (#tower.chests == 0 or not F.TowerChests) then
		local since = os.clock() - (tower.resetTried or -1e9)
		if since > 20 then
			if tower.resetTried then notify("Infinite Tower", "Reset did not go through, trying again") end
			tower.resetTried = os.clock()
			towerHalt()
			status.text = "resetting at wave " .. resetAt
			fire("Teleport_PrewarmMission", infiniteTower.ID)
			task.wait(1)
			fire("Teleport_StartRaid", infiniteTower.ID, 1, nil) -- towers always run on difficulty 1
			return true
		elseif since < 5 then
			status.text = "resetting at wave " .. resetAt
			return true
		end
	end
	local now = os.clock()

	if F.TowerChests and #tower.chests > 0 then
		local ch = tower.chests[1]
		if now - ch.at > 20 then
			table.remove(tower.chests, 1)
			return true
		end
		local flat = ((ch.pos - hrp.Position) * Vector3.new(1, 0, 1)).Magnitude
		if flat > 8 then
			status.text = string.format("boss chest · %d studs", flat)
			navTo(ch.pos, nil, true)
			return true
		end
		towerHalt()
		status.text = "opening boss chest"
		if now < tower.chestWait then return true end
		tower.chestWait = now + 1
		table.remove(tower.chests, 1)
		-- the server allows one chest, more with the Extra Drop pass; a "no" means we are done
		local ok, can = invoke("Chests_CheckCondition", ch.id)
		if ok and can ~= false then
			fire("Chests_OpenChest", ch.id)
		else
			tower.chests = {}
		end
		return true
	elseif not F.TowerChests then
		tower.chests = {}
	end

	local lt = workspace:FindFirstChild("LobbyTeleport")
	local part = lt and lt:FindFirstChild("Interaction")
	if part and (lt:GetPivot().Position - Vector3.new(0, -50, 0)).Magnitude > 30 then
		if tower.touchedFloor ~= floor then
			-- after the touch the server moves us; in a party the teleporter stays until everyone
			-- is through, so hold still instead of walking back to it
			if tower.touchStart then
				if now - tower.touchStart > 2 then tower.touchedFloor, tower.touchStart = floor, nil end
				return true
			end
			local top = part.Position + Vector3.new(0, part.Size.Y * 0.5, 0)
			local gy = groundY(top, nil, 2)
			local goal = gy and Vector3.new(top.X, gy + 3, top.Z) or part.Position
			if towerTouch(hrp, part, goal, "next floor") then tower.touchStart = now end
			return true
		end
	else
		tower.touchStart = nil
	end

	-- the fight waits for a touch on the gate walls. Once a boss has been seen on this floor the
	-- gate is done, so we never walk back to it after the kill.
	local bossFloor = towerBossFloor(floor, start)
	local anyMob = nearestMob(math.huge)
	if bossFloor and anyMob then tower.bossFought = floor end
	if bossFloor and tower.bossFought ~= floor and not anyMob then
		local gate = workspace:FindFirstChild("Boss_Gate")
		local inter = gate and gate:FindFirstChild("Interactions")
		local best, bestD, bestGoal
		if inter then
			for _, p in ipairs(inter:GetChildren()) do
				if p:IsA("BasePart") then
					local g = closestOnPart(p, hrp.Position)
					local d = (g - hrp.Position).Magnitude
					if not bestD or d < bestD then best, bestD, bestGoal = p, d, g end
				end
			end
		end
		if best then
			-- walk right into the wall so the game gets a real touch
			local away = (bestGoal - hrp.Position) * Vector3.new(1, 0, 1)
			local push = away.Magnitude > 0.1 and (bestGoal + away.Unit * 6) or bestGoal
			towerTouch(hrp, best, bestGoal, "touching boss wall", 4, push)
			return true
		end
	end
	return false
end

--------------------------------------------------------------------------------
-- Boss dodge. Every warning circle / wedge on the ground is Effects:DoEffect("RadialIndicator" or
-- "ConeIndicator", ...), called with its exact position, size and duration, so we read them right
-- there and stay out of them until they have landed. Works for every mob that draws them.
--------------------------------------------------------------------------------
local dodgeZones = {}
-- Fallen King's curse phase: everyone gets the DeathMark status (dies after about 25 s). Several
-- Fallen Guards (FallenKingMinion) spawn and one of them, unknown to the client, drops a cure well
-- when it dies. The well (radius 16.5) removes DeathMark from anyone standing in it.
local curse = { wellPos = nil, wellUntil = 0, status = safeRequire(Shared:FindFirstChild("Status")) }
local bossDodge = { boss = nil, attack = nil, want = 0, moving = false }
Lumen.DodgeState = bossDodge -- read by the fight recorder
bossDodge.zones = dodgeZones
bossDodge.hover = hover

do
	-- how hard the attack being performed right now hits (share of health, from the mob data).
	-- A mob's animation tracks are named after its attacks. nil = no known attack is playing.
	local function currentAttackRatio()
		local mobs = workspace:FindFirstChild("Mobs")
		local best
		for _, m in ipairs(mobs and mobs:GetChildren() or {}) do
			local def = MobDefs and safeRequire(MobDefs:FindFirstChild(m.Name))
			local animator = type(def) == "table" and type(def.Attacks) == "table" and m:FindFirstChildWhichIsA("Animator", true)
			if animator then
				for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
					local atk = def.Attacks[track.Name]
					local ratio = type(atk) == "table" and atk.HealthDamageRatio
					if type(ratio) == "number" and (not best or ratio > best) then best = ratio end
				end
			end
		end
		return best
	end

	local function addZone(name, a, b, c, d, e, playerOwned)
		if not F.DodgeBoss or playerOwned then return end
		local mode = F.DodgeMode or "Damaging attacks"
		if mode ~= "All circles" then
			local ratio = currentAttackRatio()
			if mode == "Lethal attacks only" then
				-- one-shot range; a huge circle with no known attack behind it is treated as lethal too
				local hugeUnknown = ratio == nil and name == "RadialIndicator" and type(b) == "number" and b >= 60
				if not ((ratio and ratio >= 0.5) or hugeUnknown) then return end
			elseif ratio == 0 then
				return -- the attack deals no damage (summons and similar)
			end
		end
		if name == "RadialIndicator" then
			-- (position, radius, projectile, duration, colour, playerOwned)
			-- radius 150 = the Fallen Clock's pulse: harmless (it only locks skills for 2 s) and impossible
			-- to outrun, so running from it just threw us across the arena every 4 seconds
			if typeof(a) == "Vector3" and type(b) == "number" and b < 150 then
				table.insert(dodgeZones, { pos = a, r = b, t = os.clock() + math.min(type(d) == "number" and d or 10, 10) + 0.3 })
			end
		elseif typeof(a) == "CFrame" and type(b) == "number" and type(c) == "number" then
			-- (cframe at the tip, half angle in degrees, length, duration, colour, playerOwned)
			local look = a.LookVector * Vector3.new(1, 0, 1)
			if look.Magnitude > 0.01 then
				table.insert(dodgeZones, {
					pos = a.Position, r = c, look = look.Unit, half = math.rad(math.abs(b)) + math.rad(12),
					t = os.clock() + math.min(type(d) == "number" and d or 10, 10) + 0.3,
				})
			end
		end
	end
	local Eff = safeRequire(Shared:FindFirstChild("Effects"))
	if Eff and Eff.DoEffect then
		local orig = Eff.DoEffect
		pcall(function()
			Eff.DoEffect = function(self, name, ...)
				-- Potassium can resume game code at executor level after a wait, and the game's effects
				-- require() their scripts; that error killed skills halfway and left the player busy
				if setthreadidentity and getthreadidentity and getthreadidentity() > 2 then setthreadidentity(2) end
				if name == "RadialIndicator" or name == "ConeIndicator" then pcall(addZone, name, ...) end
				if name == "FallenKingSpike" and F.DodgeBoss then
					-- (cframe, seconds it stays, radius, ...): keeps damaging long after its warning circle is gone
					local cf, life, radius = ...
					if typeof(cf) == "CFrame" and type(life) == "number" and type(radius) == "number" then
						table.insert(dodgeZones, { pos = cf.Position, r = radius, t = os.clock() + life + 0.5 })
					end
				end
				if name == "CureFountainFallenKing" then
					local pos, dur = ...
					if typeof(pos) == "Vector3" then
						curse.wellPos, curse.wellUntil = pos, os.clock() + (type(dur) == "number" and dur or 10)
					end
				end
				return orig(self, name, ...)
			end
		end)
		onUnload(function() pcall(function() Eff.DoEffect = orig end) end)
	end
end

local function inZone(p, margin)
	for _, z in ipairs(dodgeZones) do
		local off = (p - z.pos) * Vector3.new(1, 0, 1)
		local d = off.Magnitude
		if d <= z.r + margin then
			if not z.look or d < margin + 3 then return z end
			local ang = math.acos(math.clamp(off.Unit:Dot(z.look), -1, 1))
			if ang <= z.half then return z end
		end
	end
	return nil
end

-- is the straight flight from a to b free of zones? Leaving the zone we start in is fine; once
-- outside, the line must not enter one (a safe spot behind a circle used to mean flying through it)
local function pathClear(a, b)
	local flat = (b - a) * Vector3.new(1, 0, 1)
	local len = flat.Magnitude
	if len < 1 then return true end
	local dir = flat.Unit
	local outside = inZone(a, 4) == nil
	for s = 6, len, 6 do
		local inside = inZone(a + dir * s, 4) ~= nil
		if inside and outside then return false end
		if not inside then outside = true end
	end
	return true
end

local function dodgeUsable(hrp, p)
	local gy = groundY(p, nil, 10)
	if not gy or math.abs(gy - hrp.Position.Y) >= 40 then return false end
	if hover.floor and gy < hover.floor - 12 then return false end -- ground far below ours: outside the arena
	return not workspace:Raycast(hrp.Position, p - hrp.Position, rayParams)
end

local function dodgeMove(hrp, goal, look)
	if route.pts then routeStop() end
	if tweenObj then tweenObj:Cancel() tweenObj = nil end
	hover.goal, hover.look, hover.speed, hover.ground, hover.lift = goal, look, moveSpeed(), true, F.OrbitHeight or 0
	bossDodge.moving = true
end

-- steer without touching the dodge's "moving" flag: that flag makes the next tick call stopMoving,
-- which resets the float height to the ground (the character then dipped and shot back up)
local function hoverTo(hrp, goal, look, lift)
	if route.pts then routeStop() end
	if tweenObj then tweenObj:Cancel() tweenObj = nil end
	hover.goal, hover.look, hover.speed, hover.ground, hover.lift = goal, look, moveSpeed(), true, lift
end

-- Next point on the circle around a mob, kept inside the map. A point is only used if the line from
-- the mob to it hits no wall, the floor continues all the way there, and we can fly to it without
-- crossing a wall. At the edge of the map the orbit turns around and circles back the other way.
bossDodge.orbitDir = 1
function bossDodge.orbitSpot(hrp, mp, ang, lead, radius)
	local here = hrp.Position
	local function pointAt(a, dist)
		return Vector3.new(mp.X + math.cos(a) * dist, here.Y, mp.Z + math.sin(a) * dist)
	end
	local floorY = groundY(mp, nil, 3)
	if not floorY then return pointAt(ang + bossDodge.orbitDir * lead, radius) end -- flying mob with no floor to compare to
	local function reach(a)
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local wall = workspace:Raycast(mp, dir * (radius + 3), rayParams)
		local limit = wall and math.max(wall.Distance - 3, 0) or radius
		local s, good = 0, 0
		repeat
			s = math.min(s + 6, limit)
			local gy = groundY(mp + dir * s, nil, 3)
			if not gy or math.abs(gy - floorY) > 12 then return good end
			good = s
		until s >= limit
		return good
	end
	local function usable(a)
		if reach(a) < radius - 0.5 then return false end
		return not workspace:Raycast(here, pointAt(a, radius) - here, rayParams)
	end
	local dir = bossDodge.orbitDir
	if usable(ang + dir * lead) then return pointAt(ang + dir * lead, radius) end
	if usable(ang - dir * lead) then
		bossDodge.orbitDir = -dir
		return pointAt(ang - dir * lead, radius)
	end
	-- both neighbours blocked: the nearest open part of the circle
	for i = 2, 8 do
		for _, sign in ipairs({ dir, -dir }) do
			local a = ang + sign * i * math.pi / 8
			if usable(a) then
				bossDodge.orbitDir = sign
				return pointAt(a, radius)
			end
		end
	end
	-- no full-distance spot anywhere (mob in a corner): as far out as the map allows
	local bestA, bestR = ang, -1
	for i = 0, 15 do
		local a = i / 16 * math.pi * 2
		local r = reach(a)
		if r > bestR then bestA, bestR = a, r end
	end
	return pointAt(bestA, math.max(bestR, 0))
end

function curse.marked()
	if not F.CureCurse or not curse.status or not LP.Character then return false end
	local ok, on = pcall(curse.status.HasStatus, curse.status, LP.Character, "DeathMark")
	return ok and on and true or false
end

function curse.guard(hrp, name)
	local mobs = workspace:FindFirstChild("Mobs")
	if not mobs then return nil end
	local best, bestD
	for _, m in ipairs(mobs:GetChildren()) do
		if m.Name == name and alive(m) then
			local d = (m.PrimaryPart.Position - hrp.Position).Magnitude
			if not bestD or d < bestD then best, bestD = m, d end
		end
	end
	return best
end

-- Flaming skulls (Effects ProjectileRing): a skull removes itself when its target is within 40
-- studs of the boss at launch, or when it comes within 40 studs of the boss after 2 s. They fly
-- at 100 studs/s, so they can't be outrun: while any exist we go back next to the boss.
local skullsFlying = {}
do
	local function add(m) if m.Name == "FlamingSkull" then skullsFlying[m] = true end end
	for _, m in ipairs(workspace:GetChildren()) do add(m) end
	local c = workspace.ChildAdded:Connect(add)
	onUnload(function() c:Disconnect() end)
end

function curse.skullBoss()
	if not F.DodgeBoss or not next(skullsFlying) then return nil end
	local live = false
	for m in pairs(skullsFlying) do
		if m.Parent then live = true else skullsFlying[m] = nil end
	end
	if not live then return nil end
	local mobs = workspace:FindFirstChild("Mobs")
	if not mobs then return nil end
	for _, m in ipairs(mobs:GetChildren()) do
		if SKULL_BOSSES[m.Name] and alive(m) then return m end
	end
	return nil
end

-- mobs that must die before the boss: the King's curse guards, and the Queen's guards (she heals
-- 1 % per second while any of them lives). Returns the mob, how close to circle it, and a status.
curse.minions = { SpiritHorse = true, GhoulKnight = true, MazeMan = true, FallenKingMinion = true }

function curse.priority(hrp)
	if curse.marked() then
		local m = curse.guard(hrp, "FallenKingMinion")
		if m then return m, math.min(orbitRadius(m), 30), "curse: killing Fallen Guard" end
	end
	if F.QueenMinions then
		local m = curse.guard(hrp, "FallenQueenGuard")
		if m then return m, math.min(orbitRadius(m), 30), "killing Queen's Guard" end
	end
	-- the King's and Queen's other minions come before the boss. Staying close for skulls is last in
	-- this list on purpose: skulls are out for most of the fight and would starve everything below them
	if F.KillMinions and inFallenThrone then
		local mobs = workspace:FindFirstChild("Mobs")
		local best, bestD
		for _, m in ipairs(mobs and mobs:GetChildren() or {}) do
			if curse.minions[m.Name] and alive(m) then
				local d = (m.PrimaryPart.Position - hrp.Position).Magnitude
				if not bestD or d < bestD then best, bestD = m, d end
			end
		end
		if best then return best, math.min(orbitRadius(best), 30), "killing " .. best.Name end
	end
	-- spawns when the Queen drops to 50 %: pulses Darkness (no skills, only basic attacks) until destroyed
	if F.KillClock then
		local m = curse.guard(hrp, "FallenClock")
		if m then return m, 18, "destroying Fallen Clock" end
	end
	if F.KillPrince then
		local m = curse.guard(hrp, "BOSSFallenPrince")
		if m then return m, 36, "killing Fallen Prince" end
	end
	local skullBoss = curse.skullBoss()
	if skullBoss then return skullBoss, 28, "skulls: staying close to the boss" end -- well inside their 40-stud limit
	return nil
end

-- cursed and the well is up: get in and stay until the curse is gone
function curse.toWell(hrp)
	if not curse.wellPos or os.clock() >= curse.wellUntil or not curse.marked() then return false end
	local p = curse.wellPos
	hoverTo(hrp, Vector3.new(p.X, hrp.Position.Y, p.Z), nil, 8) -- the well reaches about 15 studs up; minion swings about 5
	status.text = string.format("going to cure well · %d studs", ((p - hrp.Position) * Vector3.new(1, 0, 1)).Magnitude)
	return true
end

-- cursed and no well yet: kill the Fallen Guards until one of them drops it
function curse.kill(hrp)
	local m, radius, label = curse.priority(hrp)
	if not m then return false end
	local mp = m.PrimaryPart.Position
	if F.SafeMode == "Off" then
		-- no circling: still goes for the priority target, but walks into range and stands there
		if hover.goal then stopMoving() end
		local away = (hrp.Position - mp) * Vector3.new(1, 0, 1)
		local range = F.AttackRange or 25
		if away.Magnitude > range then
			moveTowards(mp + (away.Magnitude > 0.1 and away.Unit or Vector3.new(1, 0, 0)) * (range * 0.6))
		else
			stopMoving()
		end
	elseif radius == 0 then
		-- float right above it: higher than a guard's swing reaches, and the closest target for auto-aim
		hoverTo(hrp, Vector3.new(mp.X, hrp.Position.Y, mp.Z), nil, math.max(F.OrbitHeight or 0, 18))
	else
		local off = (hrp.Position - mp) * Vector3.new(1, 0, 1)
		local a = off.Magnitude > 0.1 and math.atan2(off.Z, off.X) or 0
		hoverTo(hrp, bossDodge.orbitSpot(hrp, mp, a, math.min(moveSpeed() / radius * 0.6, 0.5), radius), mp, F.OrbitHeight or 0)
	end
	status.text = label
	return true
end

-- power orbs (HealthBuffOrb, DamageBuffOrb, UltChargeBuffOrb...): the server gives the buff to
-- anyone standing over one, so we just fly there. Orbs on another floor of the map are skipped,
-- and an orb we could not get within 14 s is left alone.
local powerOrbs = {}
do
	local function add(m)
		if m:IsA("Model") and m.Name:find("BuffOrb", 1, true) then powerOrbs[m] = os.clock() end
	end
	for _, m in ipairs(workspace:GetChildren()) do add(m) end
	local c = workspace.ChildAdded:Connect(add)
	onUnload(function() c:Disconnect() end)
end

local function orbStep(hrp)
	if not F.AutoOrbs then return false end
	local now = os.clock()
	local best, bestD
	for m, seen in pairs(powerOrbs) do
		local p = m.Parent and m.PrimaryPart
		if not p then
			powerOrbs[m] = nil
		elseif now - seen < 14 and math.abs(p.Position.Y - hrp.Position.Y) < 60 then
			local d = ((p.Position - hrp.Position) * Vector3.new(1, 0, 1)).Magnitude
			if d < 250 and (not bestD or d < bestD) then best, bestD = p, d end
		end
	end
	if not best then return false end
	if route.pts then routeStop() end
	if tweenObj then tweenObj:Cancel() tweenObj = nil end
	hover.goal, hover.look, hover.speed, hover.ground, hover.lift = Vector3.new(best.Position.X, hrp.Position.Y, best.Position.Z), nil, moveSpeed(), true, F.OrbitHeight or 0
	status.text = string.format("collecting orb · %d studs", bestD)
	return true
end

local function dodgeActive()
	return #dodgeZones > 0 or bossDodge.moving
end

-- true while it is steering us around warning zones (the normal fight logic is skipped)
local function dodgeStep(hrp)
	local now = os.clock()
	for i = #dodgeZones, 1, -1 do
		if now >= dodgeZones[i].t then table.remove(dodgeZones, i) end
	end
	if #dodgeZones == 0 or not F.DodgeBoss then
		table.clear(dodgeZones)
		bossDodge.boss = nil
		if bossDodge.moving then
			bossDodge.moving = false
			-- still fighting: the fight logic takes over this same tick, so keep the float height
			if not (F.AutoFarm or F.AutoRun or F.AutoTower or (F.AutoFallen and inFallenThrone)) then stopMoving() end
		end
		return false
	end
	local farming = F.AutoFarm or F.AutoRun or F.AutoTower or (F.AutoFallen and inFallenThrone)
	-- "Only dodge below": with more health than this, ignore the circles and keep fighting
	if hpRatio() * 100 > (F.DodgeBelow or 100) then
		bossDodge.boss = nil
		if bossDodge.moving then
			bossDodge.moving = false
			if not farming then stopMoving() end
		end
		return false
	end
	local here = hrp.Position
	-- zones can last 20 s (spikes), so priority targets still get their own distance during them
	local mob, prioRadius = curse.priority(hrp)
	if not mob then mob = nearestMob(150) end
	local danger = inZone(here, 7)
	bossDodge.boss = danger ~= nil or nil
	bossDodge.attack = danger and (danger.look and "cone" or "circle") or nil
	bossDodge.want = danger and danger.r or 0
	if danger then
		-- the closest safe spot; among equally close ones, the one nearest our target
		local best, bestScore, anySafe
		-- don't let a dodge land us on top of the boss; only do that if nothing else is safe
		local keepOff = mob and orbitRadius(mob) * 0.75 or 0
		for _, dist in ipairs({ 18, 30, 45, 60, 80, 105, 130, 160 }) do
			for i = 0, 15 do
				local a = i / 16 * math.pi * 2
				local p = here + Vector3.new(math.cos(a) * dist, 0, math.sin(a) * dist)
				if not inZone(p, 10) and dodgeUsable(hrp, p) then
					anySafe = anySafe or p
					local score = mob and ((p - mob.PrimaryPart.Position) * Vector3.new(1, 0, 1)).Magnitude or 0
					if score >= keepOff and (not bestScore or score < bestScore) and pathClear(here, p) then best, bestScore = p, score end
				end
			end
			if best then break end
		end
		best = best or anySafe
		if best then
			dodgeMove(hrp, best, mob and mob.PrimaryPart.Position or nil)
			status.text = "dodging " .. bossDodge.attack
		end
		return true
	end
	if not farming then
		if bossDodge.moving then bossDodge.moving = false stopMoving() end
		return false
	end
	-- Safety mode Off: nothing to steer around outside a zone, the normal fight logic stands still
	if F.SafeMode == "Off" then
		if bossDodge.moving then bossDodge.moving = false stopMoving() end
		return false
	end
	-- outside every zone: keep moving and fighting, but never let the Orbit path cross into one
	status.text = "avoiding attack zones"
	if mob then
		local mp = mob.PrimaryPart.Position
		local off = (here - mp) * Vector3.new(1, 0, 1)
		local radius = prioRadius or orbitRadius(mob) -- the normal distance, not wherever we happen to be
		local p = Vector3.new(mp.X, here.Y, mp.Z) -- radius 0 = float right above it
		if radius > 0 then
			local a = (off.Magnitude > 0.1 and math.atan2(off.Z, off.X) or 0) + math.min(moveSpeed() / radius * 0.4, 0.5)
			p = Vector3.new(mp.X + math.cos(a) * radius, here.Y, mp.Z + math.sin(a) * radius)
		end
		if not inZone(p, 10) and dodgeUsable(hrp, p) and pathClear(here, p) then
			dodgeMove(hrp, p, mp)
			bossDodge.dbg = mob.Name .. " orbit r=" .. tostring(radius)
		else
			-- the next orbit step is blocked (spikes last up to 20 s): find the nearest safe spot that
			-- is still within attack range of the target instead of standing still out of range
			local best, bestD
			for _, r in ipairs({ math.max(radius, 12), math.max(radius - 10, 10), radius + 8, math.max(radius - 20, 8) }) do
				for i = 0, 23 do
					local ang = i / 24 * math.pi * 2
					local q = Vector3.new(mp.X + math.cos(ang) * r, here.Y, mp.Z + math.sin(ang) * r)
					if not inZone(q, 10) then
						local d = ((q - here) * Vector3.new(1, 0, 1)).Magnitude
						if (not bestD or d < bestD) and dodgeUsable(hrp, q) and pathClear(here, q) then best, bestD = q, d end
					end
				end
				if best then break end
			end
			dodgeMove(hrp, best or here, mp)
			bossDodge.dbg = mob.Name .. " blocked found=" .. tostring(best ~= nil) .. " r=" .. tostring(radius)
		end
	else
		dodgeMove(hrp, here, nil)
		bossDodge.dbg = "no target in 150 studs"
	end
	return true
end

--------------------------------------------------------------------------------
-- Attack loop: presses the basic attack every frame whatever else the run is doing (dodging,
-- travelling, collecting orbs...). A skill can't start during a swing, so when a selected skill is
-- ready the basic attack pauses for that swing, the skill is cast, and attacking carries on.
--------------------------------------------------------------------------------
do
	local SKILLS = { "Skill1", "Skill2", "Skill3", "Ultimate" }
	local nextTry, petAt, drawnAt, holdSince = {}, 0, 0, nil
	local watchedA, busyKey, busyAt = nil, nil, 0
	-- clear a swing left stuck by an earlier failed attack
	do local A0 = getActions() if A0 then pcall(A0.ReleaseBusy, A0, "Swing") end end
	local c = RunService.Heartbeat:Connect(function()
		local fighting = F.AutoFarm or (F.AutoRun and inDungeon) or (F.AutoTower and inInfiniteTower) or (F.AutoFallen and inFallenThrone)
		if not fighting or finished or not root() or not nearestMob(200) then holdSince = nil return end
		local A = getActions()
		if not A then return end
		local now = os.clock()
		-- safety net: remember what last marked us busy; if that never clears, release it
		if A ~= watchedA and A.SetBusy then
			watchedA = A
			local origSet = A.SetBusy
			A.SetBusy = function(self, key, ...)
				busyKey, busyAt = key, os.clock()
				return origSet(self, key, ...)
			end
			onUnload(function() A.SetBusy = origSet end)
		end
		if busyKey and now - busyAt > 6 then
			local okB, isBusy = pcall(A.IsBusy, A)
			if okB and isBusy then pcall(A.ReleaseBusy, A, busyKey) end
			busyKey = nil
		end
		if now - drawnAt > 0.5 then drawnAt = now ensureDrawn() end
		local skills = F.Skills or {}
		if skills["Pet ability"] and now - petAt > 1 and nearestMob(60) then
			petAt = now
			useSkill("Pet ability")
		end
		local ready
		if nearestMob(45) then
			for _, s in ipairs(SKILLS) do
				if skills[s] and now >= (nextTry[s] or 0) then
					local ok, onCd = pcall(A.IsOnCooldown, A, s)
					if ok and not onCd then ready = s break end
				end
			end
		end
		if ready then
			holdSince = holdSince or now
			local ok, busy = pcall(A.IsBusy, A)
			if (ok and not busy) or now - holdSince > 1.2 then
				holdSince = nil
				nextTry[ready] = now + 1.5
				useSkill(ready)
				local s = ready
				-- still off cooldown shortly after = it didn't cast (no target close enough, no ult
				-- charge): stop interrupting the basic attack for it for a while
				task.delay(0.5, function()
					local okCd, stillReady = pcall(A.IsOnCooldown, A, s)
					if okCd and not stillReady then nextTry[s] = os.clock() + 6 end
				end)
			end
			return
		end
		holdSince = nil
		useSkill("Primary")
	end)
	onUnload(function() c:Disconnect() end)
end

-- Last-moment sidestep for a launched skull (100 studs/s, hits within 4 studs, turns worse the
-- longer it flies): checked every frame, because the fight loop is far too slow for this.
local skullEvade = { untilT = 0, goal = nil, count = 0 }
bossDodge.skullEvade = skullEvade
do
	local lastSeen = setmetatable({}, { __mode = "k" })
	local c = RunService.Heartbeat:Connect(function()
		if not F.DodgeBoss or not next(skullsFlying) or hpRatio() * 100 > (F.DodgeBelow or 100) then return end
		local hrp = root()
		if not hrp then return end
		local now = os.clock()
		if now < skullEvade.untilT then return end
		for m in pairs(skullsFlying) do
			local part = m.Parent and m.PrimaryPart
			if part then
				local pos, prev = part.Position, lastSeen[m]
				lastSeen[m] = { pos, now }
				if prev and now > prev[2] then
					local vel = (pos - prev[1]) / (now - prev[2])
					local to = hrp.Position - pos
					if vel.Magnitude > 70 and to.Magnitude < 35 and to.Magnitude > 0.1 and vel.Unit:Dot(to.Unit) > 0.7 then
						local side = Vector3.new(-vel.Z, 0, vel.X)
						side = side.Magnitude > 0.1 and side.Unit or Vector3.new(1, 0, 0)
						local a, b = hrp.Position + side * 35, hrp.Position - side * 35
						local goal = (not inZone(a, 6)) and a or ((not inZone(b, 6)) and b or a)
						hoverTo(hrp, goal, nil, F.OrbitHeight or 0)
						skullEvade.untilT, skullEvade.goal = now + 0.35, goal
						skullEvade.count += 1
						return
					end
				end
			end
		end
	end)
	onUnload(function() c:Disconnect() end)
end

local function triggerGoal(p)
	-- aim at the floor inside the trigger, not its centre (big triggers float in the air)
	local top = Vector3.new(p.Position.X, p.Position.Y + p.Size.Y * 0.5, p.Position.Z)
	local gy = groundY(top, nil, 2)
	return gy and Vector3.new(top.X, gy + 3, top.Z) or p.Position
end

task.spawn(function()
	local lastSkill = {}
	local lastPos, stuckSince, target
	while not Lumen.Unloaded do
		local towerRun = F.AutoTower and inInfiniteTower
		local running = ((F.AutoRun and inDungeon) or (F.AutoFallen and inFallenThrone)) and not towerRun
		if (F.AutoFarm or running or towerRun or dodgeActive()) and not finished then
			local ok, err = pcall(function()
				local hrp = root()
				if not hrp then status.text = "waiting for character" return end
				if os.clock() < skullEvade.untilT then return end -- mid-sidestep: let it finish
				-- orbs come first, before dodging and every other target: the trip takes about a second
				if (F.AutoFarm or running or towerRun) and orbStep(hrp) then return end
				if (F.AutoFarm or running or towerRun) and curse.toWell(hrp) then return end
				if dodgeStep(hrp) then return end
				if not (F.AutoFarm or running or towerRun) then return end
				if curse.kill(hrp) then return end
				if towerRun and towerStep(hrp) then return end
				-- sticky target: keep the current mob until it dies or something is much closer
				if running then markPassiveTriggers(hrp) end
				local searchRange = (running or towerRun) and math.huge or (F.SearchRange or 300)
				local mob, dist
				if target and alive(target) and not ((bannedMobs[target] or 0) > os.clock()) then
					local td = (target.PrimaryPart.Position - hrp.Position).Magnitude
					local nm, nd = nearestMob(searchRange)
					if nm and nm ~= target and nd < td * 0.5 and nd < 45 then
						mob, dist = nm, nd
					else
						mob, dist = target, td
					end
				else
					mob, dist = nearestMob(searchRange)
				end
				if mob ~= target then navReset() end
				if mob then dwell.idleSince = nil end
				target = mob
				if not mob then
					if running then
						-- room cleared: walk into the next trigger so the dungeon continues
						local trig, td = nextTrigger(hrp)
						if trig and td == 0 then
							-- standing in the trigger: stop flying and walk around inside it for a moment,
							-- so the server really registers the touch (tweening straight through, or
							-- passing over it at Orbit height, did not start the next stage)
							routeStop()
							hover.goal, hover.look, hover.ground, hover.lift, hover.curLift, hover.floor = nil, nil, nil, nil, nil, nil
							if dwell.trig ~= trig then dwell.trig, dwell.since = trig, os.clock() end
							local t = os.clock() - dwell.since
							local g = triggerGoal(trig)
							local hum = humanoid()
							if hum then hum:MoveTo(g + Vector3.new(math.cos(t * 3) * 3, 0, math.sin(t * 3) * 3)) end
							if firetouchinterest then
								pcall(firetouchinterest, hrp, trig, 0)
								pcall(firetouchinterest, hrp, trig, 1)
							end
							status.text = "activating " .. trig.Name
							if t > 1.5 then
								visitedTriggers[trig] = true
								dwell.trig = nil
							end
						elseif trig then
							status.text = string.format("next area: %s · %d studs", trig.Name, td)
							navTo(triggerGoal(trig), nil, true) -- on the ground, never over the trigger
							if noProgress(trig, td) then
								visitedTriggers[trig] = true -- unreachable for now, try the next one
								navReset()
							end
						else
							-- nothing left to touch: after a while, head for the boss arena (the game's
							-- boss-intro camera target), in case the boss only appears up close
							dwell.idleSince = dwell.idleSince or os.clock()
							local idle = os.clock() - dwell.idleSince
							local bossAt = bossArena()
							local flat = bossAt and ((bossAt - hrp.Position) * Vector3.new(1, 0, 1)).Magnitude
							-- last resort for dungeons that do spawn something near a checkpoint
							local cp, cpD
							if idle > 40 then
								for _, d in ipairs(triggerParts()) do
									if isCheckpoint(d) and not visitedTriggers[d] then
										local dd = (d.Position - hrp.Position).Magnitude
										if not cpD or dd < cpD then cp, cpD = d, dd end
									end
								end
							end
							if bossAt and idle > 10 and flat > 25 and not dwell.bossTried then
								status.text = string.format("searching boss arena · %d studs", flat)
								navTo(bossAt, nil, true)
								if noProgress("bossArena", flat) then dwell.bossTried = true navReset() end
							elseif cp then
								status.text = string.format("checking %s · %d studs", cp.Name, cpD)
								if insidePart(cp, hrp.Position, 2) or noProgress(cp, cpD) then
									visitedTriggers[cp] = true
									navReset()
								else
									navTo(triggerGoal(cp), nil, true)
								end
							else
								status.text = "waiting for mobs / next stage"
								if hover.goal or route.pts then stopMoving() end
							end
						end
					else
						status.text = towerRun and "waiting for the next wave" or "no mobs in range"
						if hover.goal then stopMoving() end
					end
					return
				end
				status.text = string.format("%s · %d studs", mob.Name, dist)
				local range = F.AttackRange or 25
				local mode = F.SafeMode or "Orbit"
				-- far away: path there first (around walls); give up on mobs we can't get closer to
				if dist > 60 and mode ~= "Off" and inFallenThrone then
					-- open arena: fly straight back at float height. Walking there meant landing among the
					-- minions, whose swings only reach about 5 studs up
					local mp = mob.PrimaryPart.Position
					hoverTo(hrp, Vector3.new(mp.X, hrp.Position.Y, mp.Z), mp, F.OrbitHeight or 0)
					status.text = string.format("flying to %s · %d studs", mob.Name, dist)
					return
				end
				if dist > 60 and mode ~= "Off" then
					navTo(mob.PrimaryPart.Position, mob.PrimaryPart.Position)
					if noProgress(mob, dist) then
						-- long enough that two unreachable mobs can't keep us ping-ponging;
						-- while everything is banned the run explores triggers instead
						-- never give up on a boss: the fight can't continue without it
						if not mob.Name:find("BOSS", 1, true) then bannedMobs[mob] = os.clock() + 45 end
						navReset()
						status.text = "unreachable, skipping " .. mob.Name
					end
					return
				end
				-- close enough to fight: Orbit takes over from the travel tween
				if route.pts then routeStop() end
				-- a leftover flight goal (orb, dodge, skull sidestep) would keep overriding walking
				if mode == "Off" and hover.goal then stopMoving() end
				if mode == "Orbit" or mode == "Hover" then -- "Hover" = old saved configs
					-- circle the target outside its attack reach, faster than it walks.
					-- Orbit height 0 = follow the ground; above 0 = fly the circle that high above the mob.
					local mp = mob.PrimaryPart.Position
					local radius = orbitRadius(mob)
					local h = F.OrbitHeight or 0
					if hpRatio() * 100 < (F.PanicHP or 35) then
						radius = SKULL_BOSSES[mob.Name] and 36 or 44
						if h > 0 then h = math.max(h, 30) end -- climb out of most hitboxes while healing
						status.text = "low HP · " .. status.text
					end
					local off = (hrp.Position - mp) * Vector3.new(1, 0, 1)
					local ang = off.Magnitude > 0.1 and math.atan2(off.Z, off.X) or math.random() * math.pi * 2
					-- lead point ahead on the circle; capped, because at high speed it ended up across the
					-- circle and the straight line to it went through the middle of the mob
					local p = bossDodge.orbitSpot(hrp, mp, ang, math.min(moveSpeed() / radius * 0.6, 0.5), radius)
					hover.goal, hover.look, hover.speed, hover.ground, hover.lift = p, mp, moveSpeed(), true, h
					if tweenObj then tweenObj:Cancel() tweenObj = nil end
					lastPos, stuckSince = nil, nil
					dist = (mp - hrp.Position).Magnitude
				elseif dist > range then
					local mp = mob.PrimaryPart.Position
					local dir = (hrp.Position - mp) * Vector3.new(1, 0, 1)
					dir = dir.Magnitude > 0.1 and dir.Unit or Vector3.new(1, 0, 0)
					moveTowards(mp + dir * (range * 0.6))
					-- stuck check: barely moved for 3s while walking -> jump
					if lastPos and (hrp.Position - lastPos).Magnitude < 1 then
						stuckSince = stuckSince or os.clock()
						if os.clock() - stuckSince > 3 then
							local hum = humanoid()
							if hum then hum.Jump = true end
							stuckSince = nil
						end
					else
						stuckSince = nil
					end
					lastPos = hrp.Position
				else
					stopMoving()
					lastPos, stuckSince = nil, nil
				end
			end)
			if not ok then warn("[WZ] farm: " .. tostring(err)) end
			-- react to new circles quickly: at high speed a 0.2 s delay is 30 studs in the wrong direction
			task.wait(#dodgeZones > 0 and 0.05 or (0.15 + math.random() * 0.1))
		else
			task.wait(0.5)
		end
	end
end)

--------------------------------------------------------------------------------
-- quests: anything under Profile.<...>.Quests.Active with a "Completed" child is claimable
-- (server: Quests.ClaimQuest checks Completed and not Claimed). Covers event quests too.
--------------------------------------------------------------------------------

local claimedAt = {}
-- the quest folders are found once a minute; scanning the whole profile (inventory, pets, ...)
-- every 5 seconds was needless work
local questFolders = { list = {}, at = -1e9 }
local function claimQuests()
	local prof = LP:FindFirstChild("PlayerGui") and LP.PlayerGui:FindFirstChild("Profile")
	if not prof then return 0 end
	if os.clock() - questFolders.at > 60 then
		local list = {}
		for _, d in ipairs(prof:GetDescendants()) do
			if d.Name == "Active" and d:IsA("Folder") and d.Parent and d.Parent.Name == "Quests" then table.insert(list, d) end
		end
		questFolders.list, questFolders.at = list, os.clock()
	end
	local n = 0
	for _, d in ipairs(questFolders.list) do
		if d.Parent then
			for _, q in ipairs(d:GetChildren()) do
				local id = tonumber(q.Name)
				local claimed = q:FindFirstChild("Claimed")
				if id and q:FindFirstChild("Completed") and not (claimed and claimed.Value) and os.clock() - (claimedAt[id] or -1e9) > 30 then
					claimedAt[id] = os.clock()
					fire("Quests_ClaimQuest", id)
					n += 1
					task.wait(0.8 + math.random() * 0.4)
				end
			end
		end
	end
	return n
end

task.spawn(function()
	task.wait(4)
	while not Lumen.Unloaded do
		if F.AutoQuests then
			local ok, n = pcall(claimQuests)
			if ok and n > 0 then notify("Quests", "Claimed " .. n .. " quest(s)") end
		end
		task.wait(5)
	end
end)

--------------------------------------------------------------------------------
-- coins
-- Every drop is a client-side "CoinPart" in workspace.Coins that the game's CoinRenderer
-- (Shared.Drops) picks up once it is next to you (or your pet). We slide the parts onto the
-- character and let the game do the pickup itself (effect, Drops_CoinEvent, cleanup).
--------------------------------------------------------------------------------

task.spawn(function()
	while not Lumen.Unloaded do
		if F.AutoCoins then
			pcall(function()
				local hrp = root()
				local folder = workspace:FindFirstChild("Coins")
				if not hrp or not folder then return end
				local range = F.CoinRange or 50
				local drop = CFrame.new(hrp.Position - Vector3.new(0, 4, 0))
				for _, c in ipairs(folder:GetChildren()) do
					if c:IsA("BasePart") and c.Name == "CoinPart" and (c.Position - hrp.Position).Magnitude <= range then
						c.Anchored = true
						c.CFrame = drop
					end
				end
			end)
		end
		task.wait(F.CoinDelay or 0.4)
	end
end)

--------------------------------------------------------------------------------
-- cutscenes, end of dungeon, chests, leave
--------------------------------------------------------------------------------

local function openChests(count)
	local n = 0
	for _ = 1, (count or F.ChestCount or 2) do
		local ok, res = invoke("Missions_GetMissionPrize", false)
		if ok and res ~= nil and res ~= false then n += 1 end
		task.wait(1 + math.random() * 0.5)
	end
	return n
end

local function leaveDungeon()
	invoke("Party_LeaveParty")
	task.wait(0.3)
	fire("Missions_NotifyReadyToLeave", true)
end

-- same as the "PLAY DUNGEON AGAIN" button: leave choice true = replay this dungeon
-- (false = back to the world, "Next" = next dungeon), then report ready. We stay in our
-- party, the server teleports the party into a fresh run of the same dungeon.
local teleporting = false
do
	local c = LP.OnTeleport:Connect(function() teleporting = true end)
	onUnload(function() c:Disconnect() end)
end

local function currentMission()
	if not currentWorld then return nil end
	for _, m in pairs(MissionData) do
		if type(m) == "table" and m.WorldID == currentWorld.ID then return m end
	end
end

-- The server only accepts "play again" once the run is over. For a run that is still going
-- (or stuck), the party leader can start the same dungeon directly from inside it, same call
-- as the lobby start; the game teleports the party into a fresh run.
local function restartDungeon()
	if finished then
		fire("Missions_LeaveChoice", true)
		task.wait(0.5)
		fire("Missions_NotifyReadyToLeave")
		for _ = 1, 8 do
			task.wait(1)
			if teleporting then return end
		end
	end
	local m = currentMission()
	if not m then notify("Restart", "Could not find this dungeon's ID") return end
	local ok, diff = invoke("Missions_GetDifficulty")
	fire("Teleport_PrewarmMission", m.ID)
	task.wait(1)
	fire("Teleport_StartRaid", m.ID, (ok and tonumber(diff)) or 1, nil)
	notify("Restart", "Starting " .. tostring(m.NameTag) .. " again")
end

-- Next dungeon = the game's "Next" button: Missions:GetNextWorldDungeon(current) is the next
-- normal dungeon in world order (no towers / dailies / events). After the run the leave choice
-- "Next" does it; otherwise (stuck run, choice ignored) start that dungeon directly. Falls back
-- to a restart when there is no next one or your level is too low for it.
local function nextDungeonFor(m)
	local Mi = safeRequire(Shared:FindFirstChild("Missions"))
	local ok, nxt = false, nil
	if Mi and Mi.GetNextWorldDungeon then ok, nxt = pcall(Mi.GetNextWorldDungeon, Mi, m.ID) end
	return ok and type(nxt) == "table" and nxt or nil
end

local function playerLevel()
	local p = LP:FindFirstChild("PlayerGui") and LP.PlayerGui:FindFirstChild("Profile")
	local lv = p and p:FindFirstChild("Level")
	return lv and lv.Value or math.huge
end

-- set further down (needs the difficulty helpers); used after a run when "Best dungeon" is on
local startBestDungeon

local function nextDungeon()
	local m = currentMission()
	local nxt = m and nextDungeonFor(m)
	if not nxt or (nxt.LevelRequirement or 0) > playerLevel() then
		notify("Next dungeon", nxt and ("Level " .. nxt.LevelRequirement .. " needed for " .. nxt.NameTag .. " - restarting instead") or "No next dungeon - restarting instead")
		return restartDungeon()
	end
	local ok, diff = invoke("Missions_GetDifficulty")
	diff = (ok and tonumber(diff)) or 1
	-- "Insane (if possible)" picked: aim for Insane in every dungeon of the chain
	if F.Difficulty == "Insane (if possible)" or F.Difficulty == "Insane (6)" then diff = 6 end
	-- the next dungeon may not have that difficulty: use the highest one it has below it
	if type(nxt.difficulties) == "table" and not (type(nxt.difficulties[diff]) == "table" and next(nxt.difficulties[diff])) then
		local best = 1
		for id, d in pairs(nxt.difficulties) do
			if type(id) == "number" and id < diff and id > best and type(d) == "table" and next(d) then best = id end
		end
		diff = best
	end
	if finished then
		fire("Missions_LeaveChoice", "Next")
		task.wait(0.5)
		fire("Missions_NotifyReadyToLeave")
		for _ = 1, 8 do
			task.wait(1)
			if teleporting then return end
		end
	end
	fire("Teleport_PrewarmMission", nxt.ID)
	task.wait(1)
	fire("Teleport_StartRaid", nxt.ID, diff, nil)
	notify("Next dungeon", "Starting " .. tostring(nxt.NameTag))
end

-- The server skips a cutscene at once when every player has the game's own "Skip Cutscenes"
-- setting on (Missions:VoteToSkipCutscene -> Settings:GetSkipCutscene). Firing only the skip vote
-- 0.6s late was not enough, so turn the real setting on and still vote right away as a backup.
local function applySkipSetting()
	if not F.SkipCutscenes then return end
	local S = safeRequire(Shared:FindFirstChild("Settings"))
	if not S then return end
	local ok, on = pcall(S.GetSkipCutscene, S, LP)
	if not (ok and on) then gamePcall(S.SetSkipCutscenes, S, LP, true) end
end
task.delay(4, applySkipSetting)

do
	local cut = remote("Missions_DoCutscene")
	if cut then
		local c = cut.OnClientEvent:Connect(function()
			if F.SkipCutscenes then
				applySkipSetting()
				fire("Missions_SkippedCutscene")
				for _, d in ipairs({ 0.5, 1.5, 3 }) do
					task.delay(d, function() fire("Missions_SkippedCutscene") end)
				end
			end
		end)
		onUnload(function() c:Disconnect() end)
	end

	local fin = remote("Missions_MissionFinished")
	if fin then
		local c = fin.OnClientEvent:Connect(function()
			if finished then return end
			finished = true
			stopMoving()
			task.spawn(function()
				task.wait(3)
				local fallenChests = F.FallenChests and inFallenThrone
				if F.AutoChests or fallenChests then
					local n = openChests(fallenChests and F.FallenChestCount or nil)
					notify("Dungeon done", "Opened " .. n .. " chest(s)")
				end
				if F.AutoFallen and F.FallenRestart and inFallenThrone then
					pcall(writefile, "wz_fallen_loop.txt", tostring(os.time()))
					task.wait(F.FallenRestartDelay or 4)
					notify("Fallen Throne", "Starting the next run")
					restartDungeon()
				elseif F.AutoBestDungeon and (F.AutoNext or F.AutoRestart) and startBestDungeon then
					-- leveled up into a better dungeon? go there; otherwise restart / next as usual
					task.wait(F.LeaveDelay or 4)
					if not startBestDungeon(true) then
						if F.AutoNext then nextDungeon() else restartDungeon() end
					end
				elseif F.AutoNext then
					task.wait(F.LeaveDelay or 4)
					nextDungeon()
				elseif F.AutoRestart then
					task.wait(F.LeaveDelay or 4)
					restartDungeon()
					notify("Dungeon", "Restarting...")
				end
			end)
		end)
		onUnload(function() c:Disconnect() end)
	end
end

--------------------------------------------------------------------------------
-- lobby: sell, start
--------------------------------------------------------------------------------

local SELL_TYPES = { Weapon = true, Armor = true, Offhand = true }
local RARITY_NAMES = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }

-- perk grades come from the game's own Gear:GetPerkScore(itemName, perk, value) - the same
-- S+ / S / A / B / C letters the inventory shows. Item perks: Perk1..3 StringValues with PerkValue.
local GearMod = safeRequire(Shared:FindFirstChild("Gear"))
local PerkDefs = safeRequire(RS:FindFirstChild("WorldModules") and RS.WorldModules:FindFirstChild("GearPerks")) or {}
local GRADE_RANK = { C = 1, B = 2, A = 3, S = 4, ["S+"] = 5 }

-- dropdown shows the in-game perk names; map them back to the internal ids
local perkByLabel, perkLabels = {}, {}
for id, def in pairs(PerkDefs) do
	if type(def) == "table" and not id:find("^Test") then
		local label = def.DisplayName and def.DisplayName ~= id and (def.DisplayName .. " (" .. id .. ")") or id
		perkByLabel[label] = id
		table.insert(perkLabels, label)
	end
end
table.sort(perkLabels)

local function itemPerks(it)
	local out = {}
	for i = 1, 3 do
		local p = it:FindFirstChild("Perk" .. i)
		if p then
			local v = p:FindFirstChild("PerkValue")
			local grade = "C"
			if GearMod and v then
				local ok, g = pcall(GearMod.GetPerkScore, GearMod, it.Name, p.Value, v.Value)
				if ok and GRADE_RANK[g] then grade = g end
			end
			table.insert(out, { id = p.Value, grade = grade })
		end
	end
	return out
end

-- returns nil if the item may be sold, or the reason it is kept
local function keepReason(it, perks)
	-- multi-select set of grades to keep; an old single-value config ("S") means that grade and better
	local grades = F.KeepGrade
	if type(grades) == "string" then
		local r = GRADE_RANK[grades]
		grades = {}
		if r then for g, gr in pairs(GRADE_RANK) do if gr >= r then grades[g] = true end end end
	end
	grades = grades or {}
	-- favorite perks narrow the grade rule: with favorites picked, only those perks are checked
	-- against the kept grades (a favorite with a grade you did not pick is sold like anything else).
	-- No favorites picked = every perk is checked.
	local favIds = {}
	for label, on in pairs(F.KeepPerks or {}) do
		if on and perkByLabel[label] then favIds[perkByLabel[label]] = true end
	end
	local useFav = next(favIds) ~= nil
	local relevant = {}
	for _, p in ipairs(perks) do
		if not useFav or favIds[p.id] then table.insert(relevant, p) end
	end
	if #relevant > 0 then
		if next(grades) then
			local hit, all = nil, true
			for _, p in ipairs(relevant) do
				if grades[p.grade] then hit = hit or p else all = false end
			end
			if F.KeepMode == "All perks" then
				if all then return (useFav and "favorite perks " or "all perks ") .. "in kept grades" end
			elseif hit then
				return (useFav and "favorite " or "perk ") .. hit.id .. " " .. hit.grade
			end
		elseif useFav then
			return "favorite " .. relevant[1].id .. " (no grade filter)"
		end
	end
	local minPerks = F.KeepMinPerks or 0
	if minPerks > 0 and #perks >= minPerks then return #perks .. " perks" end
	return nil
end

local function gradeText(perks)
	local t = {}
	for _, p in ipairs(perks) do table.insert(t, p.id .. " " .. p.grade) end
	return #t > 0 and table.concat(t, ", ") or "no perks"
end

-- sell list + (for the preview) the kept items with their reasons
local function sellable()
	local inv = LP:FindFirstChild("PlayerGui") and LP.PlayerGui:FindFirstChild("Profile")
	inv = inv and inv:FindFirstChild("Inventory") and inv.Inventory:FindFirstChild("Items")
	if not inv then return {}, {} end
	local list, kept = {}, {}
	local rar = F.SellRarities or {}
	local types = F.SellTypes or {}
	local always = F.AlwaysSellRarities or {}
	for _, it in ipairs(inv:GetChildren()) do
		local info = ItemDB[it.Name]
		-- rarity names as the game colours them: 1 Common .. 5 Legendary (7 = Zero gear, never sold)
		local rarName = type(info) == "table" and RARITY_NAMES[info.Rarity or 0] or ""
		local forced = always[rarName] == true -- "Always sell": ignores the type, rarity and keep rules
		if type(info) == "table" and SELL_TYPES[info.Type] and (forced or (types[info.Type] and rar[rarName])) then
			local locked = false
			if InventoryMod and InventoryMod.ItemIsLocked then
				local ok, l = pcall(InventoryMod.ItemIsLocked, InventoryMod, it)
				locked = ok and l == true
			end
			if not locked then
				local perks = itemPerks(it)
				local why = not forced and keepReason(it, perks) or nil
				if why then
					table.insert(kept, { item = it, why = why, perks = perks })
				else
					table.insert(list, it)
				end
			end
		end
	end
	return list, kept
end

local function sellNow()
	local list = sellable()
	if #list == 0 then return 0 end
	local ok = invoke("Drops_SellItems", list)
	return ok and #list or 0
end

-- difficulty names from Missions (index = difficulty id). Each dungeon only has the ids listed in
-- its MissionData.difficulties with real data (most: Normal + Challenge; nightmare: + Insane;
-- towers have no table and always run on 1).
local DIFF_NAMES = { "Normal", "Hard", "Difficult", "Master", "Challenge", "Insane" }
local function selectedDungeon()
	local m = dungeonByLabel[F.Dungeon]
	if not m and type(F.Dungeon) == "string" then
		-- label from an older config (before the [Tower]/[Daily] tags): match it without the tag
		for label, d in pairs(dungeonByLabel) do
			if label:gsub("^%[%a+%] ", "") == F.Dungeon then m = d break end
		end
	end
	return m
end
local INSANE_IF_POSSIBLE = "Insane (if possible)"
local function availableDifficulties(m)
	local ids = {}
	if m and type(m.difficulties) == "table" then
		for id, d in pairs(m.difficulties) do
			if type(id) == "number" and type(d) == "table" and next(d) then table.insert(ids, id) end
		end
	end
	table.sort(ids)
	if #ids == 0 then ids = { 1 } end
	return ids
end
-- the wanted difficulty if the dungeon has it, otherwise the highest one it has below that
local function resolveDifficulty(m, want)
	local best = 1
	for _, id in ipairs(availableDifficulties(m)) do
		if id == want then return id end
		if id < want and id > best then best = id end
	end
	return best
end
local function difficultyLabels(m)
	local ids = availableDifficulties(m)
	local out = {}
	for _, id in ipairs(ids) do table.insert(out, string.format("%s (%d)", DIFF_NAMES[id] or "Difficulty", id)) end
	-- dungeons without Insane still offer it: it then runs on the highest difficulty they have,
	-- handy with "Start next dungeon" where some dungeons in the chain have Insane and some don't
	if ids[#ids] ~= 6 then table.insert(out, INSANE_IF_POSSIBLE) end
	return out
end
local function difficultyId(m)
	local v = F.Difficulty
	if v == INSANE_IF_POSSIBLE then return m and resolveDifficulty(m, 6) or 6 end
	return tonumber(type(v) == "string" and (v:match("%((%d+)%)") or v) or v) or 1
end

-- best dungeon for the current level: the highest normal dungeon (no tower / daily / event / raid)
-- whose level requirement you meet
local function bestDungeon()
	local lv, best = playerLevel(), nil
	for _, m in ipairs(dungeons) do
		if not dungeonKind(m) and (m.LevelRequirement or 0) <= lv then
			if not best or (m.LevelRequirement or 0) > (best.LevelRequirement or 0)
				or ((m.LevelRequirement or 0) == (best.LevelRequirement or 0) and m.ID > best.ID) then
				best = m
			end
		end
	end
	return best
end

-- afterRun: only switch when the best dungeon differs from the one we are in (returns true if it started one)
startBestDungeon = function(afterRun)
	local b = bestDungeon()
	if not b then return false end
	if afterRun then
		local cur = currentMission()
		if cur and cur.ID == b.ID then return false end
		-- the party leader can start a dungeon from inside one (same as the restart fallback)
	end
	local diff = resolveDifficulty(b, difficultyId(b))
	fire("Teleport_PrewarmMission", b.ID)
	task.wait(1)
	fire("Teleport_StartRaid", b.ID, diff, nil)
	notify("Best dungeon", "Starting " .. tostring(b.NameTag) .. " · " .. (DIFF_NAMES[diff] or tostring(diff)))
	return true
end

local function startDungeon()
	if F.AutoBestDungeon then startBestDungeon(false) return end
	local m = selectedDungeon()
	if not m then notify("Auto Start", "Pick a dungeon first") return end
	fire("Teleport_PrewarmMission", m.ID)
	task.wait(1)
	local diff = resolveDifficulty(m, difficultyId(m))
	fire("Teleport_StartRaid", m.ID, diff, nil)
	notify("Starting", m.NameTag .. " · " .. (DIFF_NAMES[diff] or tostring(diff)))
end

--------------------------------------------------------------------------------
-- UI
--------------------------------------------------------------------------------

-- Everything below runs in its own function: some executors (Potassium) refuse more than 200
-- active locals per function, and the hub as one chunk had 217.
;(function()

local farmSec = TabFarm:AddSection("Auto Farm", { Open = true })
farmSec:AddToggle("AutoFarm", { Text = "Auto Farm", Default = false, Callback = function(on) if not on then stopMoving() end end })
	:AddKeybind("AutoFarmKey", { Default = Enum.KeyCode.F6 })
farmSec:AddDropdown("Skills", { Text = "Skills", Values = { "Skill1", "Skill2", "Skill3", "Ultimate", "Pet ability" }, Default = { "Skill1", "Skill2", "Skill3", "Ultimate", "Pet ability" }, Multi = true })
farmSec:AddSlider("AttackRange", { Text = "Stay within", Min = 8, Max = 40, Default = 22, Decimals = 0, Suffix = " studs" })
farmSec:AddSlider("SearchRange", { Text = "Search mobs within", Min = 50, Max = 1000, Default = 400, Decimals = 0, Suffix = " studs" })
farmSec:AddDropdown("MoveMode", { Text = "Movement", Values = { "Tween", "Walk" }, Default = "Tween" })
farmSec:AddSlider("TweenSpeed", { Text = "Tween speed (approach, orbit, hover)", Min = 10, Max = 150, Default = 30, Decimals = 0, Suffix = " st/s" })
local statusLabel = farmSec:AddLabel("Status: idle")

local safeSec = TabFarm:AddSection("Safety", { Open = true })
safeSec:AddDropdown("SafeMode", { Text = "Safety mode", Values = { "Orbit", "Off" }, Default = "Orbit", Callback = function() stopMoving() end })
safeSec:AddSlider("OrbitMargin", { Text = "Orbit: extra distance", Min = 2, Max = 25, Default = 8, Decimals = 0, Suffix = " studs" })
-- measured live: Boarwolf still hits at 18 studs up, nothing hit at 30. Mage Primary only targets within 45.
safeSec:AddSlider("OrbitHeight", { Text = "Orbit: height (0 = on the ground)", Min = 0, Max = 40, Default = 12, Decimals = 0, Suffix = " studs" })
safeSec:AddSlider("PanicHP", { Text = "Back off below", Min = 0, Max = 90, Default = 35, Decimals = 0, Suffix = " % HP" })
safeSec:AddToggle("DodgeBoss", { Text = "Dodge attack circles", Default = true })
safeSec:AddDropdown("DodgeMode", { Text = "Dodge which attacks", Values = { "All circles", "Damaging attacks", "Lethal attacks only" }, Default = "Damaging attacks" })
safeSec:AddSlider("DodgeBelow", { Text = "Only dodge below", Min = 5, Max = 100, Default = 100, Decimals = 0, Suffix = " % HP" })
safeSec:AddLabel("Orbit circles the target outside its attack reach (read from the game's mob data). Ranged mobs, boss AOEs and crowds can still hit.")

local questSec = TabLobby:AddSection("Quests", { Open = true })
questSec:AddToggle("AutoQuests", { Text = "Auto claim quests", Default = true })
questSec:AddButton("Claim now", function() task.spawn(function() notify("Quests", "Claimed " .. claimQuests()) end) end)

local lootSec = TabFarm:AddSection("Loot", { Open = true })
lootSec:AddToggle("AutoCoins", { Text = "Auto collect coins", Default = true })
lootSec:AddSlider("CoinRange", { Text = "Pickup range", Min = 10, Max = 150, Default = 50, Decimals = 0, Suffix = " studs" })
lootSec:AddSlider("CoinDelay", { Text = "Pickup interval", Min = 0.1, Max = 2, Default = 0.4, Decimals = 1, Suffix = " s" })

local runSec = TabDungeon:AddSection("Auto Run Dungeon", { Open = true })
runSec:AddToggle("AutoRun", { Text = "Auto Run Dungeon", Default = false, Callback = function(on) if not on then stopMoving() end end })
	:AddKeybind("AutoRunKey", { Default = Enum.KeyCode.F7 })
runSec:AddDropdown("TravelMode", { Text = "Travel (long distances)", Values = { "Walk", "Tween" }, Default = "Walk" })
runSec:AddSlider("StuckTime", { Text = "Skip target if stuck for", Min = 4, Max = 20, Default = 10, Decimals = 0, Suffix = " s" })
local runLabel = runSec:AddLabel("Status: -")
runSec:AddLabel("Works without Auto Farm: kills every mob in the dungeon, walks into the next checkpoint / trigger when the area is clear, paths around walls. Uses the Farm tab's skills, Orbit and height settings.")
task.spawn(function()
	while not Lumen.Unloaded do
		pcall(function() runLabel:Set("Status: " .. ((F.AutoRun and inDungeon) and status.text or (inDungeon and "off" or "only in dungeons"))) end)
		task.wait(0.5)
	end
end)

local towerSec = TabDungeon:AddSection("Auto Run Infinite Tower", { Open = true })
towerSec:AddToggle("AutoTower", { Text = "Auto Run Infinite Tower", Default = false, Callback = function(on) if not on then stopMoving() end end })
towerSec:AddToggle("TowerChests", { Text = "Open boss chests", Default = true })
towerSec:AddToggle("TowerReset", { Text = "Reset at wave", Default = false })
towerSec:AddSlider("TowerResetFloor", { Text = "Reset wave", Min = 101, Max = 500, Default = 200, Decimals = 0 })
towerSec:AddLabel("Starts a new run when you reach this wave. Pick one above the wave your run starts on (about your level), or it won't reset.")
local towerLabel = towerSec:AddLabel("Status: -")
towerSec:AddLabel("Works without Auto Farm: kills every wave, walks into the teleporter so you skip the 25 s wait, opens boss arenas and loots the chests. Uses the Farm tab's skills, Orbit and height settings.")
task.spawn(function()
	while not Lumen.Unloaded do
		pcall(function()
			local floor = select(1, towerFloors())
			towerLabel:Set("Status: " .. (not inInfiniteTower and "only in the Infinite Tower" or not F.AutoTower and "off" or ("Floor " .. tostring(floor) .. " · " .. status.text)))
		end)
		task.wait(0.5)
	end
end)

local dunSec = TabDungeon:AddSection("Run", { Open = true })
dunSec:AddToggle("SkipCutscenes", { Text = "Skip cutscenes", Default = true, Callback = function(on) if on then task.spawn(applySkipSetting) end end })
local fallenSec = TabEvent:AddSection("Fallen King & Queen", { Open = true })
fallenSec:AddToggle("AutoFallen", { Text = "Auto run Fallen Throne", Default = false, Callback = function(on) if not on then stopMoving() end end })
fallenSec:AddToggle("FallenRestart", { Text = "Start the next run automatically", Default = true })
fallenSec:AddSlider("FallenRestartDelay", { Text = "Next run delay", Min = 1, Max = 20, Default = 4, Decimals = 0, Suffix = " s" })
fallenSec:AddToggle("FallenChests", { Text = "Auto open chests", Default = true })
fallenSec:AddSlider("FallenChestCount", { Text = "Chests per run", Min = 1, Max = 4, Default = 2, Decimals = 0 })
fallenSec:AddDropdown("FallenDifficulty", { Text = "Difficulty", Values = difficultyLabels(fallenThrone), Default = "Insane (6)" })
local function startFallen()
	if not fallenThrone then notify("Fallen Throne", "Could not find this event") return end
	local diff = tonumber(tostring(F.FallenDifficulty):match("%((%d+)%)")) or 1
	fire("Teleport_PrewarmMission", fallenThrone.ID)
	task.wait(1)
	fire("Teleport_StartRaid", fallenThrone.ID, diff, nil)
	notify("Fallen Throne", "Starting · " .. (DIFF_NAMES[diff] or tostring(diff)))
end
fallenSec:AddButton("Start Fallen Throne", function() task.spawn(startFallen) end)

-- safety net for "Start the next run": the restart from the results screen sometimes sends the party
-- to the lobby instead. A run that just ended leaves a timestamp; landing outside a dungeon soon
-- after it starts the next run from here.
do
	local MARKER = "wz_fallen_loop.txt"
	task.spawn(function()
		task.wait(5) -- let the config autoload apply
		if not (isfile and readfile and isfile(MARKER)) then return end
		local stamp = tonumber(readfile(MARKER))
		if inFallenThrone then pcall(delfile, MARKER) return end -- the normal restart worked
		if not inLobby or not stamp or os.time() - stamp > 180 then return end
		if not (F.AutoFallen and F.FallenRestart) then return end
		pcall(delfile, MARKER)
		notify("Fallen Throne", "Back in the lobby, starting the next run")
		for _ = 1, 3 do
			startFallen()
			task.wait(20) -- still here means the start didn't go through; try again
			if Lumen.Unloaded then return end
		end
	end)
end
local fallenLabel = fallenSec:AddLabel("Status: -")
task.spawn(function()
	while not Lumen.Unloaded do
		-- this mode plays the whole fight itself, so normal Auto Farm stays off while it runs
		if inFallenThrone and F.AutoFallen and F.AutoFarm then pcall(function() Lumen.Options.AutoFarm:Set(false) end) end
		pcall(function() fallenLabel:Set("Status: " .. (not inFallenThrone and "only in the Fallen Throne" or not F.AutoFallen and "off" or status.text)) end)
		task.wait(0.5)
	end
end)
fallenSec:AddToggle("CureCurse", { Text = "Fallen King curse: kill guards, go to cure well", Default = true })
fallenSec:AddToggle("QueenMinions", { Text = "Fallen Queen: kill her healing guards first", Default = true })
fallenSec:AddToggle("KillMinions", { Text = "Kill the bosses' minions first", Default = true })
fallenSec:AddToggle("KillPrince", { Text = "Fallen Queen: kill the Fallen Prince", Default = true })
fallenSec:AddToggle("KillClock", { Text = "Fallen Queen: destroy the Fallen Clock", Default = true })
fallenSec:AddToggle("AutoOrbs", { Text = "Auto collect power orbs", Default = true })
fallenSec:AddLabel("The curse option needs Auto Farm, Auto Run or the tower runner on. Dodge attack circles is in the Safety section of the Farm tab.")
dunSec:AddToggle("AutoCloseLoot", { Text = "Auto close item popup", Default = true })
-- the fullscreen "you got this item" reveal locks camera and movement until it is closed.
-- LootReceived:_Close() is the game's own close; it does nothing while no reveal is ready to close.
task.spawn(function()
	local client = RS:FindFirstChild("Client")
	local guiFolder = client and client:FindFirstChild("Gui")
	local scripts = guiFolder and guiFolder:FindFirstChild("GuiScripts")
	local mod = scripts and scripts:FindFirstChild("LootReceived")
	local loot = mod and safeRequire(mod)
	if not (loot and loot._Close) then return end
	-- don't queue new reveals at all (the item is already yours, this is only the animation).
	-- The _Close loop below is for a reveal that was already showing when the hub loaded.
	local originalAdd = loot.AddItemToQueue
	if originalAdd then
		pcall(function()
			loot.AddItemToQueue = function(self, ...)
				if F.AutoCloseLoot then return end
				return originalAdd(self, ...)
			end
		end)
		onUnload(function() pcall(function() loot.AddItemToQueue = originalAdd end) end)
	end
	while not Lumen.Unloaded do
		if F.AutoCloseLoot then gamePcall(loot._Close, loot) end
		task.wait(0.25)
	end
end)
dunSec:AddToggle("AutoChests", { Text = "Open chests at the end", Default = true })
dunSec:AddSlider("ChestCount", { Text = "Chests per run", Min = 1, Max = 4, Default = 2, Decimals = 0 })
-- restart and next are exclusive: turning one on turns the other off
dunSec:AddToggle("AutoRestart", { Text = "Restart dungeon after the run", Default = false, Callback = function(on)
	if on and F.AutoNext then pcall(function() Lumen.Options.AutoNext:Set(false) end) end
end })
dunSec:AddToggle("AutoNext", { Text = "Start next dungeon after the run", Default = false, Callback = function(on)
	if on and F.AutoRestart then pcall(function() Lumen.Options.AutoRestart:Set(false) end) end
end })
dunSec:AddSlider("LeaveDelay", { Text = "Restart / next delay", Min = 1, Max = 20, Default = 4, Decimals = 0, Suffix = " s" })
dunSec:AddButton("Open chests now", function() notify("Chests", "Opened " .. openChests()) end)
	:AddButton("Restart now", function() task.spawn(restartDungeon) end)
dunSec:AddButton("Next dungeon now", function() task.spawn(nextDungeon) end)
dunSec:AddButton("Return to lobby", leaveDungeon)

local startSec = TabLobby:AddSection("Start (lobby)", { Open = true })
local diffDrop
-- show only the difficulties the picked dungeon really has; keep the current one if it exists there
local function refreshDifficulties()
	if not diffDrop then return end
	local labels = difficultyLabels(selectedDungeon())
	pcall(function() diffDrop:SetValues(labels) end)
	local pick = labels[1]
	if F.Difficulty == INSANE_IF_POSSIBLE then
		-- keep "Insane (if possible)"; on a dungeon that really has Insane, show "Insane (6)"
		pick = table.find(labels, INSANE_IF_POSSIBLE) and INSANE_IF_POSSIBLE or "Insane (6)"
	else
		local want = difficultyId()
		local found = false
		for _, l in ipairs(labels) do if l:match("%((%d+)%)") == tostring(want) then pick, found = l, true end end
		if not found and want == 6 and table.find(labels, INSANE_IF_POSSIBLE) then pick = INSANE_IF_POSSIBLE end
	end
	if F.Difficulty ~= pick then pcall(function() diffDrop:Set(pick) end) end
end
local dungeonDrop = startSec:AddDropdown("Dungeon", { Text = "Dungeon", Values = dungeonLabels, Default = dungeonLabels[1], Callback = function() task.defer(refreshDifficulties) end })
startSec:AddToggle("ShowEventDungeons", { Text = "Show event dungeons", Default = false, Callback = function(on)
	local cur = F.Dungeon
	pcall(function() dungeonDrop:SetValues(on and dungeonLabelsAll or dungeonLabels) end)
	-- an event dungeon picked earlier falls back to the first normal one when they are hidden
	if not on and cur and not table.find(dungeonLabels, cur) then pcall(function() dungeonDrop:Set(dungeonLabels[1]) end) end
end })
diffDrop = startSec:AddDropdown("Difficulty", { Text = "Difficulty", Values = difficultyLabels(dungeonByLabel[dungeonLabels[1]]), Default = difficultyLabels(dungeonByLabel[dungeonLabels[1]])[1] })
task.delay(3, refreshDifficulties) -- after the saved config is loaded
startSec:AddToggle("AutoBestDungeon", { Text = "Best dungeon for my level", Default = false })
local bestLabel = startSec:AddLabel("Best for your level: -")
task.spawn(function()
	while not Lumen.Unloaded do
		local b = bestDungeon()
		pcall(function() bestLabel:Set("Best for your level (" .. tostring(playerLevel()) .. "): " .. (b and (b.NameTag .. " (Lv " .. tostring(b.LevelRequirement) .. ")") or "-") .. ". When on, Start / Auto start use it, and after a run (with Restart or Next on) you move up as soon as you level into a better one.") end)
		task.wait(10)
	end
end)
startSec:AddToggle("AutoStart", { Text = "Auto start from lobby", Default = false })
startSec:AddSlider("StartDelay", { Text = "Start delay", Min = 3, Max = 60, Default = 8, Decimals = 0, Suffix = " s" })
startSec:AddButton("Start now", function() task.spawn(startDungeon) end)

-- one section: what may be sold, then what is always kept, then the buttons
local sellSec = TabLobby:AddSection("Auto Sell", { Open = true })
sellSec:AddToggle("AutoSell", { Text = "Auto sell (lobby + dungeons)", Default = false })
sellSec:AddDropdown("SellTypes", { Text = "Sell types", Values = { "Weapon", "Armor", "Offhand" }, Default = { "Weapon", "Armor" }, Multi = true })
sellSec:AddDropdown("SellRarities", { Text = "Sell rarities", Values = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }, Default = { "Common", "Uncommon" }, Multi = true })
sellSec:AddDropdown("AlwaysSellRarities", { Text = "Always sell rarities", Values = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }, Default = {}, Multi = true })
sellSec:AddDropdown("KeepGrade", { Text = "Keep perk grades", Values = { "S+", "S", "A", "B", "C" }, Default = { "S+", "S" }, Multi = true })
sellSec:AddDropdown("KeepMode", { Text = "Grade must be on", Values = { "Any perk", "All perks" }, Default = "Any perk" })
sellSec:AddDropdown("KeepPerks", { Text = "Favorite perks (only these count)", Values = perkLabels, Default = {}, Multi = true })
sellSec:AddSlider("KeepMinPerks", { Text = "Keep items with at least (0 = off)", Min = 0, Max = 3, Default = 0, Decimals = 0, Suffix = " perks" })

Lumen.SellPreview = function() return sellable() end -- for checking the rules from outside

local function previewSell()
	local list, kept = sellable()
	local sell = {}
	for i, it in ipairs(list) do
		if i > 12 then table.insert(sell, "... +" .. (#list - 12)) break end
		table.insert(sell, it.Name .. " [" .. gradeText(itemPerks(it)) .. "]")
	end
	local keep = {}
	for i, k in ipairs(kept) do
		if i > 8 then table.insert(keep, "... +" .. (#kept - 8)) break end
		table.insert(keep, k.item.Name .. " (" .. k.why .. ")")
	end
	notify("Would sell " .. #list, #sell > 0 and table.concat(sell, "\n") or "nothing", 10)
	notify("Keeping " .. #kept, #keep > 0 and table.concat(keep, "\n") or "nothing", 10)
	print("[WZ] sell: " .. table.concat(sell, " | "))
	print("[WZ] keep: " .. table.concat(keep, " | "))
end
sellSec:AddButton("Preview", previewSell):AddButton("Sell now", function()
	notify("Sold", sellNow() .. " item(s)")
end)
sellSec:AddLabel("Sells items within 'Sell types' and 'Sell rarities' unless a keep rule matches. Keeps an item when a perk has one of the kept grades; with favorite perks picked, only those perks count. Grades are the game's own (S+ = max roll). 'Always sell rarities' ignores every other rule here, even good perks. Locked and equipped items are never sold.")

-- status label
task.spawn(function()
	while not Lumen.Unloaded do
		local where = inDungeon and "dungeon" or "lobby"
		pcall(function() statusLabel:Set("Status (" .. where .. "): " .. (F.AutoFarm and status.text or "off")) end)
		task.wait(0.5)
	end
end)

-- auto sell runs everywhere (lobby, worlds and dungeons), so a full inventory never needs a trip back
task.spawn(function()
	task.wait(3) -- give the config autoload time to apply
	while not Lumen.Unloaded do
		if F.AutoSell then
			local ok, n = pcall(sellNow)
			if ok and n > 0 then notify("Auto Sell", "Sold " .. n .. " item(s)") end
		end
		task.wait(inDungeon and 5 or 2)
	end
end)

-- lobby automation: start a dungeon
if inLobby then
	task.spawn(function()
		task.wait(3)
		local t0 = os.clock()
		while not Lumen.Unloaded do
			if F.AutoStart and os.clock() - t0 >= (F.StartDelay or 8) then
				startDungeon()
				task.wait(20) -- teleport should happen; retry later if it didn't
				t0 = os.clock()
			end
			task.wait(2)
		end
	end)
end

--------------------------------------------------------------------------------
-- extras: rewards, pets, gear, world events
-- Everything goes through the game's own Shared modules (same calls its GUI makes);
-- the server validates every claim, so "nothing to claim" is just a no-op.
--------------------------------------------------------------------------------

local SharedMod = {}
local function mod(name)
	if SharedMod[name] == nil then SharedMod[name] = safeRequire(Shared:FindFirstChild(name)) or false end
	return SharedMod[name] or nil
end

local function profile() return LP:FindFirstChild("PlayerGui") and LP.PlayerGui:FindFirstChild("Profile") end

local function call(m, fn, ...)
	if not m or type(m[fn]) ~= "function" then return false end
	local args = table.pack(...)
	return gamePcall(function() return m[fn](m, table.unpack(args, 1, args.n)) end)
end

local function every(flag, seconds, fn)
	task.spawn(function()
		task.wait(5)
		while not Lumen.Unloaded do
			if F[flag] then
				local ok, err = pcall(fn)
				if not ok then warn("[WZ] " .. flag .. ": " .. tostring(err)) end
				task.wait(seconds)
			else
				task.wait(1)
			end
		end
	end)
end

local TabRewards = Window:AddTab("Rewards")
local TabPets = Window:AddTab("Pets")
local TabGear = Window:AddTab("Gear")

-- passes (starter pass + battle pass): claim every reached free tier (and premium if owned)
-- client side has no pass folder (GetFolder is server-only), so walk the tiers up to the
-- current rank and ask the server which ones are still unclaimed.
local function claimPass(m)
	if not m then return 0 end
	local okR, ready = call(m, "ItemsRedeemable", LP)
	if not (okR and ready) then return 0 end
	local okX, xp = call(m, "GetPlayerExp", LP)
	local per = m.EXP_PER_RANK or 500
	local rank = (okX and type(xp) == "number") and math.floor(xp / per) or 0
	local okP, premium = call(m, "HasPremiumTrack", LP)
	premium = okP and premium
	local n = 0
	for tier = 1, math.min(rank, 100) do
		for _, paid in ipairs(premium and { false, true } or { false }) do
			local okD, done = call(m, "RedeemedItem", LP, tier, paid or nil)
			if okD and done == false then
				call(m, "RedeemItem", LP, tier, paid or nil)
				n += 1
				task.wait(1.2)
			end
		end
	end
	return n
end

local function claimDailies()
	local got = {}
	-- starter pass / battle pass
	local sp = claimPass(mod("Starterpass"))
	if sp > 0 then table.insert(got, sp .. " starter pass tier(s)") end
	local bp = claimPass(mod("Battlepass"))
	if bp > 0 then table.insert(got, bp .. " battle pass tier(s)") end
	-- event + weekly rewards (server checks completion)
	call(mod("Events"), "ClaimReward")
	call(mod("Quests"), "ClaimWeeklyReward")
	-- starter pack daily (only if the pack is owned)
	local SPD = mod("StarterPackDaily")
	local okS, st = call(SPD, "GetState")
	if okS and type(st) == "table" and st.Owned and not st.ClaimedToday then
		call(SPD, "Claim")
		table.insert(got, "starter pack daily")
	end
	-- VIP+ daily crystals
	if LP:GetAttribute("VIPPlus") then
		local okV, res = call(mod("VIP"), "ClaimVIPPlusDailyCrystals")
		if okV and res then table.insert(got, "VIP+ crystals") end
	end
	-- advent calendar (only while it runs; never pays crystals for missed days)
	local AC = mod("AdventCalendar")
	if AC and AC.END_TIME and os.time() < AC.END_TIME then
		local okD, day = call(AC, "GetCalendarDayPast")
		if okD and type(day) == "number" and day > 0 then
			local okC, claimed = call(AC, "DayIsClaimed", day)
			if okC and not claimed then
				call(AC, "ClaimReward", day, false)
				table.insert(got, "advent day " .. day)
			end
		end
	end
	return got
end

local rewSec = TabRewards:AddSection("Auto Claim", { Open = true })
rewSec:AddToggle("AutoDailies", { Text = "Passes, events, weekly, dailies", Default = true })
rewSec:AddButton("Claim now", function()
	task.spawn(function()
		local got = claimDailies()
		notify("Rewards", #got > 0 and table.concat(got, ", ") or "nothing new to claim", 6)
	end)
end)
rewSec:AddLabel("Starter pass and battle pass tiers, event and weekly rewards, starter pack daily (if owned), VIP+ crystals (if VIP+), advent calendar. Premium tracks only if you own them. Never spends crystals.")
every("AutoDailies", 120, function()
	local got = claimDailies()
	if #got > 0 then notify("Rewards", table.concat(got, ", "), 6) end
end)

local codeSec = TabRewards:AddSection("Promo Codes", { Open = true })
codeSec:AddInput("PromoCodes", { Text = "Codes (comma separated)", Placeholder = "CODE1, CODE2" })
codeSec:AddButton("Redeem", function()
	local raw = F.PromoCodes or ""
	task.spawn(function()
		for code in raw:gmatch("[^,%s]+") do
			local ok, a, b = call(mod("PromoCodes"), "RedeemCode", LP, code)
			notify("Code " .. code, ok and tostring(b or a) or "failed", 4)
			task.wait(2)
		end
	end)
end)

-- pets ------------------------------------------------------------------------

local function pickExpedition(PE, teamPower)
	local okA, list = call(PE, "GetAvailableExpeditions")
	local okU, unlocked = call(PE, "GetUnlockedExpeditions", LP)
	if not (okA and type(list) == "table") then return nil end
	local best
	for _, e in ipairs(list) do
		local open = not (okU and type(unlocked) == "table" and unlocked[e.Id] == false)
		if open and (e.RequiredPower or 0) <= teamPower then
			if not best then best = e
			elseif F.ExpeditionPick == "Shortest" and (e.Duration or 0) < (best.Duration or 0) then best = e
			elseif F.ExpeditionPick ~= "Shortest" and (e.RequiredPower or 0) > (best.RequiredPower or 0) then best = e end
		end
	end
	return best
end

local function runExpeditions()
	local PE = mod("PetExpeditions")
	if not PE then return "module missing" end
	local okC, cur = call(PE, "GetCurrentExpedition", LP)
	if okC and type(cur) == "table" then
		local okClaim, success, msg = call(PE, "Claim", cur.Slot or 1)
		if okClaim and success then notify("Expedition", "Claimed rewards") return "claimed" end
		return "running: " .. tostring(msg or "")
	end
	local okP, pets = call(PE, "GetAvailablePets", LP)
	if not (okP and type(pets) == "table") or #pets == 0 then return "no pets available" end
	table.sort(pets, function(a, b) return (a.Power or 0) > (b.Power or 0) end)
	local okCfg, cfg = call(PE, "GetConfig")
	local max = okCfg and type(cfg) == "table" and cfg.MaxPetsPerExpedition or 5
	local team = {}
	for i = 1, math.min(max, #pets) do team[i] = pets[i].Pet end
	local okT, power = call(PE, "GetTeamPower", team)
	power = okT and power or 0
	local e = pickExpedition(PE, power)
	if not e then return "team power " .. power .. " too low" end
	local okS, success, msg = call(PE, "Send", e.Id, team)
	if okS and success then
		notify("Expedition", "Sent " .. #team .. " pet(s) to " .. tostring(e.Name))
		return "sent to " .. tostring(e.Name)
	end
	return "send failed: " .. tostring(msg)
end

local function itemDef(it) return type(ItemDB[it.Name]) == "table" and ItemDB[it.Name] or nil end

local function runIncubator()
	local prof = profile()
	local inc = prof and prof:FindFirstChild("PetIncubator")
	local Pets = mod("Pets")
	if not inc or not Pets then return 0 end
	-- The incubator levels PETS over time (Pets:CanIncubatePet only accepts Type "Pet" below the max
	-- level, which is the player's level). Take pets out once they hit the max, fill free slots with
	-- the highest-level unfinished pets from the inventory.
	local n = 0
	local okM, maxLvl = call(Pets, "GetMaxLevel", nil, LP)
	maxLvl = (okM and type(maxLvl) == "number") and maxLvl or math.huge
	local function lvl(it) return it:FindFirstChild("Level") and it.Level.Value or 1 end
	for _, slot in ipairs(inc:GetChildren()) do
		if slot:IsA("Folder") then
			for _, it in ipairs(slot:GetChildren()) do
				local d = itemDef(it)
				if d and d.Type == "Pet" and lvl(it) >= maxLvl then
					call(Pets, "RemovePetFromIncubator", LP, it)
					n += 1
					task.wait(1)
				end
			end
		end
	end
	local pets = {}
	for _, it in ipairs(prof.Inventory.Items:GetChildren()) do
		local d = itemDef(it)
		if d and d.Type == "Pet" and lvl(it) < maxLvl and not it:FindFirstChild("OnExpedition") then table.insert(pets, it) end
	end
	table.sort(pets, function(a, b) return lvl(a) > lvl(b) end)
	for i = 1, 3 do
		local slot = inc:FindFirstChild("Slot" .. i)
		local owned = i == 1 or (inc:FindFirstChild("PurchasedSlot" .. i) and inc["PurchasedSlot" .. i].Value)
		if slot and owned and #slot:GetChildren() == 0 and #pets > 0 then
			call(Pets, "IncubatePet", LP, table.remove(pets, 1), slot)
			n += 1
			task.wait(1)
		end
	end
	return n
end

local function equippedPet()
	local okE, equips = call(mod("Profile"), "GetPlayerEquips", LP)
	local folder = okE and equips and equips:FindFirstChild("Pet")
	return folder and folder:GetChildren()[1]
end

local function feedCandy()
	local prof = profile()
	local pet = equippedPet()
	local Pets = mod("Pets")
	if not prof or not pet or not Pets then return 0 end
	local d = itemDef(pet)
	if not d or d.Type ~= "Pet" then return 0 end
	local candy = prof.Inventory.Items:FindFirstChild("PetCandy")
	local have = candy and (candy:FindFirstChild("Count") and candy.Count.Value or 1) or 0
	local okM, maxLvl = call(Pets, "GetMaxLevel", pet, LP)
	local lvl = pet:FindFirstChild("Level") and pet.Level.Value or 1
	local need = (okM and type(maxLvl) == "number") and (maxLvl - lvl) or 0
	local n = math.min(have, need)
	if n > 0 then call(Pets, "FeedPetCandy", LP, n) end
	return n
end

-- Hatching = the inventory's "Hatch Egg" action (Inventory GUI EquipEggAndHatch): equip the egg in
-- the Pet slot, then Pets:HatchEgg -> the server rolls the pet and puts it in the Pet slot.
-- Afterwards the pet you had equipped before is equipped again.
local hatching, hatchingManual = false, false
local function hatchEggs()
	if hatching then return 0 end
	if inDungeon and not finished then return 0 end -- don't swap pets mid-fight; after the boss is fine
	local prof, Pets = profile(), mod("Pets")
	local okE, equips = call(mod("Profile"), "GetPlayerEquips", LP)
	local slot = okE and equips and equips:FindFirstChild("Pet")
	if not prof or not Pets or not slot or not InventoryMod then return 0 end
	local skip = F.HatchSkip or {}
	local eggs = {}
	for _, it in ipairs(prof.Inventory.Items:GetChildren()) do
		local d = itemDef(it)
		if d and d.Type == "Egg" and not skip[it.Name] then
			local locked = false
			if InventoryMod.ItemIsLocked then
				local ok, l = pcall(InventoryMod.ItemIsLocked, InventoryMod, it)
				locked = ok and l == true
			end
			if not locked then table.insert(eggs, it) end
		end
	end
	local cur = slot:GetChildren()[1]
	local curDef = cur and itemDef(cur)
	if #eggs == 0 and not (curDef and curDef.Type == "Egg") then return 0 end
	hatching = true
	local before = (curDef and curDef.Type == "Pet") and cur or nil
	local n = 0
	local function waitFor(cond, t)
		local t0 = os.clock()
		while os.clock() - t0 < t do if cond() then return true end task.wait(0.2) end
		return false
	end
	local function hatchEquipped(egg)
		task.wait(1.5) -- the game waits for the pet model (PetDataReadySignal) before hatching
		local okP, pos = call(Pets, "GetPetPosition", LP)
		local hrp = root()
		if not (okP and typeof(pos) == "Vector3") then pos = hrp and hrp.Position or Vector3.zero end
		call(Pets, "HatchEgg", LP, pos)
		if not waitFor(function() return egg.Parent ~= slot end, 3) then
			fire("Pets_Hatch", pos + Vector3.new(0, 5, 0)) -- client HatchEgg needs the pet model; send it directly
		end
		if waitFor(function() return egg.Parent ~= slot end, 10) then n += 1 end
		task.wait(1)
	end
	pcall(function()
		if curDef and curDef.Type == "Egg" then hatchEquipped(cur) end
		for _, egg in ipairs(eggs) do
			if not F.AutoHatch and not hatchingManual then break end
			if egg.Parent then
				pcall(InventoryMod.EquipItemClient, InventoryMod, egg, slot)
				if waitFor(function() return egg.Parent == slot end, 8) then hatchEquipped(egg) end
			end
		end
		-- put the previous pet back
		if before and before.Parent and before.Parent ~= slot and F.HatchReequip ~= false then
			pcall(InventoryMod.EquipItemClient, InventoryMod, before, slot)
		end
	end)
	hatching = false
	return n
end

local eggNames = {}
for name, d in pairs(ItemDB) do
	if type(d) == "table" and d.Type == "Egg" then table.insert(eggNames, name) end
end
table.sort(eggNames)

local hatchSec = TabPets:AddSection("Eggs", { Open = true })
hatchSec:AddToggle("AutoHatch", { Text = "Auto open eggs", Default = false })
hatchSec:AddToggle("HatchReequip", { Text = "Re-equip my pet afterwards", Default = true })
hatchSec:AddDropdown("HatchSkip", { Text = "Don't open these eggs", Values = eggNames, Default = {}, Multi = true })
hatchSec:AddButton("Open all eggs now", function()
	task.spawn(function()
		hatchingManual = true
		local n = hatchEggs()
		hatchingManual = false
		notify("Eggs", n > 0 and ("Hatched " .. n .. " egg(s)") or "No eggs to open")
	end)
end)
hatchSec:AddLabel("Hatches in the lobby / world, or in a dungeon after the boss. Locked eggs are never opened.")
every("AutoHatch", 20, function()
	local n = hatchEggs()
	if n > 0 then notify("Eggs", "Hatched " .. n .. " egg(s)") end
end)

local expSec = TabPets:AddSection("Pet Expeditions", { Open = true })
expSec:AddToggle("AutoExpeditions", { Text = "Auto send + claim", Default = false })
expSec:AddDropdown("ExpeditionPick", { Text = "Pick", Values = { "Best reward", "Shortest" }, Default = "Best reward" })
local expLabel = expSec:AddLabel("Expeditions: -")
expSec:AddLabel("Sends your strongest pets (up to the max) to the hardest (or shortest) adventure they can do, claims when done.")
every("AutoExpeditions", 60, function() expLabel:Set("Expeditions: " .. tostring(runExpeditions())) end)

local petSec = TabPets:AddSection("Incubator + Candy", { Open = true })
petSec:AddToggle("AutoIncubator", { Text = "Auto incubate eggs + collect", Default = false })
petSec:AddToggle("AutoCandy", { Text = "Feed candy to equipped pet", Default = false })
every("AutoIncubator", 30, function()
	local n = runIncubator()
	if n > 0 then notify("Incubator", n .. " action(s)") end
end)
every("AutoCandy", 60, function()
	local n = feedCandy()
	if n > 0 then notify("Pet", "Fed " .. n .. " candy") end
end)

-- gear ------------------------------------------------------------------------

local function gold()
	local prof = profile()
	local cur = prof and prof:FindFirstChild("Currency")
	local g = cur and cur:FindFirstChild("Gold")
	return g and g.Value or 0
end

local function upgradeEquipped()
	local IU = mod("ItemUpgrade")
	local okE, equips = call(mod("Profile"), "GetPlayerEquips", LP)
	if not IU or not (okE and equips) then return 0 end
	local n = 0
	for _, slotName in ipairs({ "Primary", "Weapon", "Armor", "Offhand" }) do
		local slot = equips:FindFirstChild(slotName)
		local item = slot and slot:GetChildren()[1]
		if item then
			local okU, up = call(IU, "GetUpgrade", item)
			local okL, lim = call(IU, "GetUpgradeLimit", item)
			local okC, cost = call(IU, "GetUpgradeCostForItem", item)
			if okU and okL and okC and type(up) == "number" and type(lim) == "number" and up < lim
				and type(cost) == "number" and gold() - cost >= (F.GoldReserve or 0) then
				call(IU, "UpgradeItem", LP, item, false) -- false = pay with gold, never crystals
				n += 1
				task.wait(1.5)
			end
		end
	end
	return n
end

local upSec = TabGear:AddSection("Auto Upgrade", { Open = true })
upSec:AddToggle("AutoUpgrade", { Text = "Upgrade equipped gear with gold", Default = false })
upSec:AddSlider("GoldReserve", { Text = "Keep at least", Min = 0, Max = 200000, Default = 5000, Decimals = 0, Suffix = " gold" })
upSec:AddLabel("Uses gold only, never crystals. Stops at each item's upgrade limit.")
every("AutoUpgrade", 20, function()
	local n = upgradeEquipped()
	if n > 0 then notify("Upgrade", n .. " upgrade attempt(s)") end
end)

local recSec = TabGear:AddSection("Recycler", { Open = true })
recSec:AddToggle("AutoRecycleClaim", { Text = "Claim weekly item when points reach", Default = true })
local recLabel = recSec:AddLabel("Points: -")
recSec:AddLabel("To recycle junk instead of selling it, set Lobby > Auto Sell > Junk action to Recycle.")
every("AutoRecycleClaim", 30, function()
	local R = mod("Recycler")
	local prof = profile()
	local okN, need = call(R, "RequiredPoints", LP)
	local have = prof and prof:FindFirstChild("RecyclePoints") and prof.RecyclePoints.Value or 0
	recLabel:Set(("Points: %d / %s"):format(have, okN and tostring(need) or "?"))
	if okN and type(need) == "number" and have >= need then
		call(R, "Claim", LP)
		notify("Recycler", "Claimed the weekly item")
	end
end)

-- world events: let the server teleport us there when one starts (same as clicking the popup)
local evSec = TabFarm:AddSection("World Events", { Open = true })
evSec:AddToggle("AutoWorldEvents", { Text = "Join world events", Default = false })
evSec:AddLabel("Uses the game's own event teleport when an event starts. Auto Farm then fights there.")
do
	local started = remote("WorldEvents_EventStarted")
	if started then
		local c = started.OnClientEvent:Connect(function(key)
			if not F.AutoWorldEvents or inDungeon then return end
			task.delay(2 + math.random() * 2, function()
				local WE = mod("WorldEvents")
				local okCan, can = call(WE, "CanTeleportToEvent", LP, key)
				if okCan and can then
					call(WE, "TeleportToEvent", LP, key)
					notify("World Event", "Joining " .. tostring(key))
				end
			end)
		end)
		onUnload(function() c:Disconnect() end)
	end
end

--------------------------------------------------------------------------------
-- session HUD: gold earned across dungeon runs, saved to the workspace so it survives
-- every teleport (each dungeon start / leave is a new server and a fresh script)
--------------------------------------------------------------------------------

local SESSION_FILE = "WorldZeroHub_session.json"
local HttpService = game:GetService("HttpService")

local function fmtNum(n)
	n = math.floor(tonumber(n) or 0)
	local neg = n < 0
	local s = tostring(math.abs(n)):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
	return (neg and "-" or "") .. s
end

local function fmtTime(sec)
	sec = math.max(0, math.floor(sec))
	return string.format("%dh %02dm", sec // 3600, (sec % 3600) // 60)
end

local function goldValue()
	local prof = profile()
	local g = prof and prof:FindFirstChild("Currency") and prof.Currency:FindFirstChild("Gold")
	return g
end

local session
local function saveSession()
	if not session or not writefile then return end
	session.lastSeen = os.time()
	pcall(writefile, SESSION_FILE, HttpService:JSONEncode(session))
end

local function newSession(gold)
	local prof = profile()
	session = {
		start = os.time(), startGold = gold, lastGold = gold, earned = 0, spent = 0, runs = 0,
		lastRunGold = 0, startLevel = prof and prof:FindFirstChild("Level") and prof.Level.Value or 0,
	}
	saveSession()
end

local runStartEarned = 0

task.spawn(function()
	local gv
	for _ = 1, 60 do gv = goldValue() if gv then break end task.wait(1) end
	if not gv then return end
	local gold = gv.Value
	if isfile and readfile and isfile(SESSION_FILE) then
		local ok, data = pcall(function() return HttpService:JSONDecode(readfile(SESSION_FILE)) end)
		if ok and type(data) == "table" and data.start then session = data end
	end
	local gapMin = F.SessionGap or 30
	if not session or os.time() - (session.lastSeen or 0) > gapMin * 60 then
		newSession(gold)
	else
		-- gold that arrived while we were teleporting (end-of-run rewards, chests)
		local d = gold - (session.lastGold or gold)
		if d > 0 then session.earned += d elseif d < 0 then session.spent += -d end
		session.lastGold = gold
		saveSession()
	end
	runStartEarned = session.earned
	local c = gv.Changed:Connect(function(v)
		local d = v - (session.lastGold or v)
		if d > 0 then session.earned += d elseif d < 0 then session.spent += -d end
		session.lastGold = v
		saveSession()
	end)
	onUnload(function() c:Disconnect() end)
	-- heartbeat save so "lastSeen" stays fresh while idle
	while not Lumen.Unloaded do task.wait(15) saveSession() end
end)

do
	local fin = remote("Missions_MissionFinished")
	if fin then
		local c = fin.OnClientEvent:Connect(function()
			task.delay(8, function() -- let chest gold land first
				if not session then return end
				session.runs += 1
				session.lastRunGold = session.earned - runStartEarned
				saveSession()
			end)
		end)
		onUnload(function() c:Disconnect() end)
	end
end

-- HUD window
local hudGui = Instance.new("ScreenGui")
hudGui.Name = "WZ_SessionHUD"
hudGui.ResetOnSpawn = false
hudGui.IgnoreGuiInset = true
hudGui.DisplayOrder = 50
pcall(function() hudGui.Parent = (gethui and gethui()) or game:GetService("CoreGui") end)
if not hudGui.Parent then hudGui.Parent = LP:WaitForChild("PlayerGui") end
onUnload(function() hudGui:Destroy() end)

-- session HUD in the LUMEN look: theme colours and fonts, label left, value right, hairline dividers
local hud = Instance.new("Frame")
hud.Size = UDim2.fromOffset(236, 0)
hud.AutomaticSize = Enum.AutomaticSize.Y
hud.AnchorPoint = Vector2.new(1, 0) -- grows to the left, so a bigger HUD stays on screen
hud.Position = UDim2.new(1, -16, 0, 70)
local hudScale = Instance.new("UIScale", hud)
hudScale.Scale = 1.2
hud.BackgroundTransparency = 0.06
hud.BorderSizePixel = 0
hud.Active = true
hud.Parent = hudGui
Instance.new("UICorner", hud).CornerRadius = UDim.new(0, 7)
local hudStroke = Instance.new("UIStroke", hud)
hudStroke.Thickness = 1
hudStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
hudStroke.Thickness = 1.5
hudStroke.Color = Color3.new(1, 1, 1) -- white, so the gradient alone decides the colours
local hudGlow = Instance.new("UIGradient", hudStroke)
do
	local TS = game:GetService("TweenService")
	local spin = TS:Create(hudGlow, TweenInfo.new(6, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1), { Rotation = 360 })
	spin:Play()
	onUnload(function() spin:Cancel() end)
end

-- floating pill at the top of the screen: what the hub is doing right now
local statusPill = Instance.new("Frame")
statusPill.AnchorPoint = Vector2.new(0.5, 0)
statusPill.Position = UDim2.new(0.5, 0, 0, 10)
statusPill.Size = UDim2.fromOffset(0, 26)
statusPill.AutomaticSize = Enum.AutomaticSize.X
statusPill.BackgroundTransparency = 0.06
statusPill.BorderSizePixel = 0
statusPill.Visible = false
statusPill.Parent = hudGui
Instance.new("UICorner", statusPill).CornerRadius = UDim.new(0, 7)
local statusPillStroke = Instance.new("UIStroke", statusPill)
local statusPillPad = Instance.new("UIPadding", statusPill)
statusPillPad.PaddingLeft, statusPillPad.PaddingRight = UDim.new(0, 11), UDim.new(0, 13)
local statusPillList = Instance.new("UIListLayout", statusPill)
statusPillList.FillDirection = Enum.FillDirection.Horizontal
statusPillList.VerticalAlignment = Enum.VerticalAlignment.Center
statusPillList.Padding = UDim.new(0, 8)
local statusDot = Instance.new("Frame")
statusDot.Size = UDim2.fromOffset(6, 6)
statusDot.BorderSizePixel = 0
statusDot.Parent = statusPill
Instance.new("UICorner", statusDot).CornerRadius = UDim.new(1, 0)
local statusPillText = Instance.new("TextLabel")
statusPillText.BackgroundTransparency = 1
statusPillText.AutomaticSize = Enum.AutomaticSize.X
statusPillText.Size = UDim2.fromOffset(0, 26)
statusPillText.FontFace = Lumen.Mono or Lumen.Font
statusPillText.TextSize = 12
statusPillText.Parent = statusPill
task.spawn(function()
	while not Lumen.Unloaded do
		local active = F.StatusPill ~= false and (F.AutoFarm or (F.AutoRun and inDungeon) or (F.AutoTower and inInfiniteTower) or (F.AutoFallen and inFallenThrone))
		statusPill.Visible = active and true or false
		if active then
			local th = Lumen.Theme
			statusPill.BackgroundColor3 = th.Background
			statusPillStroke.Color = th.Outline
			statusDot.BackgroundColor3 = th.Gradient
			statusPillText.TextColor3 = th.Text
			statusPillText.Text = tostring(status.text)
		end
		task.wait(0.25)
	end
end)
local hudPad = Instance.new("UIPadding", hud)
hudPad.PaddingLeft, hudPad.PaddingRight = UDim.new(0, 12), UDim.new(0, 12)
hudPad.PaddingTop, hudPad.PaddingBottom = UDim.new(0, 9), UDim.new(0, 10)
local hudList = Instance.new("UIListLayout", hud)
hudList.SortOrder = Enum.SortOrder.LayoutOrder
hudList.Padding = UDim.new(0, 2)

local hudOrder, hudPaintList = 0, {}
local function hudPlace(o)
	hudOrder += 1
	o.LayoutOrder = hudOrder
	o.Parent = hud
end
local function hudLabel(parent, font, align, themeKey)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.FontFace = font
	t.TextSize = 13
	t.TextXAlignment = align
	t.TextTruncate = Enum.TextTruncate.AtEnd
	t.Text = ""
	t.Parent = parent
	if themeKey then table.insert(hudPaintList, { t, themeKey, "TextColor3" }) end
	return t
end
-- returns the value label; `height` defaults to one normal row
local function hudRow(title, leftFont, leftKey, height)
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.BorderSizePixel = 0
	row.Size = UDim2.new(1, 0, 0, height or 17)
	hudPlace(row)
	local left = hudLabel(row, leftFont or Lumen.Font, Enum.TextXAlignment.Left, leftKey or "InactiveText")
	left.Text = title
	return hudLabel(row, Lumen.Mono or Lumen.Font, Enum.TextXAlignment.Right, "Text"), row, left
end
local function hudDivider()
	local gap = Instance.new("Frame")
	gap.BackgroundTransparency = 1
	gap.BorderSizePixel = 0
	gap.Size = UDim2.new(1, 0, 0, 7)
	hudPlace(gap)
	local line = Instance.new("Frame")
	line.BorderSizePixel = 0
	line.AnchorPoint = Vector2.new(0, 0.5)
	line.Position = UDim2.fromScale(0, 0.5)
	line.Size = UDim2.new(1, 0, 0, 1)
	line.Parent = gap
	table.insert(hudPaintList, { line, "Outline", "BackgroundColor3" })
end

local hudV = {}
hudV.time = hudRow("DIVERGENCE", Lumen.BoldFont or Lumen.Font, "Text", 19)
hudV.time.TextColor3 = Lumen.Theme.InactiveText
hudDivider()
hudV.gold = hudRow("Gold earned")
hudV.hour = hudRow("Per hour")
hudV.net = hudRow("Net")
hudV.run = hudRow("This run")
hudV.runs = hudRow("Runs")
hudV.levels = hudRow("Levels")
hudV.coins = hudRow("Halloween coins")
hudDivider()
hudV.lootCount = hudRow("Chest loot", Lumen.BoldFont or Lumen.Font, "Text")
local hudLoot = {}
for i = 1, 3 do
	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.BorderSizePixel = 0
	row.Size = UDim2.new(1, 0, 0, 16)
	row.Visible = false
	hudPlace(row)
	hudLoot[i] = { row = row, label = hudLabel(row, Lumen.Font, Enum.TextXAlignment.Left, nil) }
end

local hudLootButton = Instance.new("TextButton")
hudLootButton.Size = UDim2.new(1, 0, 0, 22)
hudLootButton.BorderSizePixel = 0
hudLootButton.AutoButtonColor = true
hudLootButton.FontFace = Lumen.Font
hudLootButton.TextSize = 13
hudLootButton.Text = "View all loot"
hudPlace(hudLootButton)
Instance.new("UICorner", hudLootButton).CornerRadius = UDim.new(0, 5)
table.insert(hudPaintList, { hudLootButton, "Element", "BackgroundColor3" })
table.insert(hudPaintList, { hudLootButton, "Text", "TextColor3" })

local function hudPaint()
	local th = Lumen.Theme
	hudScale.Scale = (F.HudScale or 120) / 100
	hud.BackgroundColor3 = th.Background
	hudGlow.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, th.Accent), ColorSequenceKeypoint.new(0.5, th.Gradient), ColorSequenceKeypoint.new(1, th.Accent),
	})
	for _, p in ipairs(hudPaintList) do p[1][p[3]] = th[p[2]] end
	hudV.time.TextColor3 = th.InactiveText
	hudV.gold.TextColor3 = th.Accent
	hudV.coins.TextColor3 = Color3.fromRGB(255, 170, 60)
end
hudPaint()

-- drag
do
	local UIS = game:GetService("UserInputService")
	local dragging, startPos, startInput
	hud.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging, startPos, startInput = true, hud.Position, i.Position
		end
	end)
	local c1 = UIS.InputChanged:Connect(function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			local d = i.Position - startInput
			hud.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end)
	local c2 = UIS.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
	end)
	onUnload(function() c1:Disconnect() c2:Disconnect() end)
end


-- chest loot on the HUD: only the last 3 items, one short line each, so the HUD can't grow
local RARITY_COLORS = { Color3.fromRGB(190, 190, 195), Color3.fromRGB(120, 220, 120), Color3.fromRGB(90, 160, 255), Color3.fromRGB(190, 110, 255), Color3.fromRGB(255, 170, 60) }
local lastLootAt = {}
local function addLoot(item)
	if not session or typeof(item) ~= "Instance" then return end
	local idValue = item:FindFirstChild("ID")
	local id = idValue and idValue.Value or nil
	local key = id or item.Name
	local now = os.clock()
	if now - (lastLootAt[key] or -1e9) < 1 then return end -- same item reported by two events
	lastLootAt[key] = now
	session.loot = session.loot or {}
	table.insert(session.loot, 1, item.Name)
	session.loot[4] = nil
	session.lootAll = session.lootAll or {}
	table.insert(session.lootAll, { n = item.Name, id = id })
	if #session.lootAll > 300 then table.remove(session.lootAll, 1) end
	session.lootCount = (session.lootCount or 0) + 1
	saveSession()
end
do
	local function watch(name, handler)
		local r = remote(name)
		if r then
			local c = r.OnClientEvent:Connect(handler)
			onUnload(function() c:Disconnect() end)
		end
	end
	watch("Inventory_FullscreenItemAwarded", function(item)
		if typeof(item) == "Instance" then addLoot(item) end
	end)
	watch("Missions_PlayerRewarded", function(player, item)
		if player == LP and typeof(item) == "Instance" then addLoot(item) end
	end)
end
-- full session loot list: 3D picture of every item, with SOLD / KEPT above it. An item counts as
-- gone once its unique ID is in neither the inventory nor the equipped gear.
local lootPanel = Instance.new("Frame")
lootPanel.AnchorPoint = Vector2.new(0.5, 0.5)
lootPanel.Position = UDim2.fromScale(0.5, 0.5)
lootPanel.Size = UDim2.fromOffset(500, 400)
lootPanel.BorderSizePixel = 0
lootPanel.Visible = false
lootPanel.Active = true
lootPanel.ZIndex = 5
-- its own layer in PlayerGui, above the black screen and the menu. Item pictures are loaded by the
-- game's own code, which isn't allowed to place models inside hudGui when that sits in CoreGui.
local lootGui = Instance.new("ScreenGui")
lootGui.Name = "WZ_LootWindow"
lootGui.ResetOnSpawn = false
lootGui.IgnoreGuiInset = true
lootGui.DisplayOrder = 10000
lootGui:SetAttribute("WZHub", true)
lootGui.Parent = LP:WaitForChild("PlayerGui")
onUnload(function() lootGui:Destroy() end)
lootPanel.Parent = lootGui
Instance.new("UICorner", lootPanel).CornerRadius = UDim.new(0, 7)
local lootStroke = Instance.new("UIStroke", lootPanel)
local lootTitle = Instance.new("TextLabel")
lootTitle.BackgroundTransparency = 1
lootTitle.Position = UDim2.fromOffset(14, 8)
lootTitle.Size = UDim2.new(1, -60, 0, 24)
lootTitle.FontFace = Lumen.BoldFont or Lumen.Font
lootTitle.TextSize = 15
lootTitle.TextXAlignment = Enum.TextXAlignment.Left
lootTitle.ZIndex = 6
lootTitle.Parent = lootPanel
local lootClose = Instance.new("TextButton")
lootClose.AnchorPoint = Vector2.new(1, 0)
lootClose.Position = UDim2.new(1, -10, 0, 8)
lootClose.Size = UDim2.fromOffset(24, 24)
lootClose.BackgroundTransparency = 1
lootClose.FontFace = Lumen.BoldFont or Lumen.Font
lootClose.TextSize = 15
lootClose.Text = "X"
lootClose.ZIndex = 6
lootClose.Parent = lootPanel
local lootScroll = Instance.new("ScrollingFrame")
lootScroll.BackgroundTransparency = 1
lootScroll.BorderSizePixel = 0
lootScroll.Position = UDim2.fromOffset(12, 40)
lootScroll.Size = UDim2.new(1, -24, 1, -52)
lootScroll.CanvasSize = UDim2.new()
lootScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
lootScroll.ScrollBarThickness = 4
lootScroll.ZIndex = 6
lootScroll.Parent = lootPanel
local lootGrid = Instance.new("UIGridLayout", lootScroll)
lootGrid.CellSize = UDim2.fromOffset(110, 138)
lootGrid.CellPadding = UDim2.fromOffset(8, 8)
lootGrid.SortOrder = Enum.SortOrder.LayoutOrder

-- drag the window by its title area or edges (the item grid keeps scrolling normally)
do
	local UIS = game:GetService("UserInputService")
	local dragging, startPos, startInput
	lootPanel.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging, startPos, startInput = true, lootPanel.Position, i.Position
		end
	end)
	local c1 = UIS.InputChanged:Connect(function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			local d = i.Position - startInput
			lootPanel.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end)
	local c2 = UIS.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
	end)
	onUnload(function() c1:Disconnect() c2:Disconnect() end)
end

local lootCells = {}
local function lootOwnedIds()
	local owned, ownedNames = {}, {}
	local function collect(container)
		for _, d in ipairs(container:GetDescendants()) do
			if d.Name == "ID" and d:IsA("StringValue") then
				owned[d.Value] = true
				local itemName = d.Parent.Name
				ownedNames[itemName] = (ownedNames[itemName] or 0) + 1
			end
		end
	end
	local prof = profile()
	local inv = prof and prof:FindFirstChild("Inventory")
	local items = inv and inv:FindFirstChild("Items")
	if items then collect(items) end
	local equips = RS:FindFirstChild("PlayerEquips")
	local mine = equips and equips:FindFirstChild(LP.Name)
	if mine then collect(mine) end
	return owned, items ~= nil, ownedNames
end

local function lootMakeCell(entry)
	local cell = Instance.new("Frame")
	cell.BorderSizePixel = 0
	cell.ZIndex = 7
	Instance.new("UICorner", cell).CornerRadius = UDim.new(0, 6)
	local function text(y, h, size, font)
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Position = UDim2.fromOffset(4, y)
		t.Size = UDim2.new(1, -8, 0, h)
		t.FontFace = font
		t.TextSize = size
		t.TextWrapped = true
		t.ZIndex = 8
		t.Parent = cell
		return t
	end
	local status = text(4, 16, 12, Lumen.BoldFont or Lumen.Font)
	local nameLabel = text(102, 32, 12, Lumen.Font)
	local info = ItemDB[entry.n]
	nameLabel.Text = tostring(type(info) == "table" and info.DisplayKey or (entry.n:gsub("(%l)(%u)", "%1 %2")))
	nameLabel.TextColor3 = (type(info) == "table" and RARITY_COLORS[info.Rarity or 0]) or Lumen.Theme.Text
	local ok, view = gamePcall(function() return InventoryMod:GetItemViewport(entry.n) end)
	if ok and typeof(view) == "Instance" and view:IsA("ViewportFrame") then
		view.AnchorPoint = Vector2.new(0.5, 0)
		view.Position = UDim2.new(0.5, 0, 0, 22)
		view.Size = UDim2.fromOffset(78, 78)
		view.BackgroundTransparency = 1
		view.Ambient = Color3.new(1, 1, 1)
		view.ZIndex = 8
		view.Parent = cell
	end
	cell.Parent = lootScroll
	return { frame = cell, status = status }
end

local function lootRefreshPanel()
	local th = Lumen.Theme
	lootPanel.BackgroundColor3 = th.Background
	lootStroke.Color = th.Outline
	lootTitle.TextColor3 = th.Text
	lootClose.TextColor3 = th.InactiveText
	local all = session and session.lootAll or {}
	local owned, known, ownedNames = lootOwnedIds()
	local sold = 0
	-- newest first, so when several copies of an item exist the newest ones count as kept
	for i = #all, 1, -1 do
		local entry = all[i]
		local c = lootCells[entry]
		if not c then
			c = lootMakeCell(entry)
			lootCells[entry] = c
		end
		c.frame.LayoutOrder = -i -- newest first
		c.frame.BackgroundColor3 = th.Inline
		-- end-of-run chest rewards arrive as a copy with no ID, so those are matched by item name
		-- only gear can be sold; skins and the like unlock to the account and never sit in the inventory
		local info = ItemDB[entry.n]
		local have = not (type(info) == "table" and SELL_TYPES[info.Type])
		if have then
			-- nothing to check
		elseif entry.id then
			have = owned[entry.id] == true
		elseif (ownedNames[entry.n] or 0) > 0 then
			ownedNames[entry.n] -= 1
			have = true
		end
		if not known then
			c.status.Text, c.status.TextColor3 = "UNKNOWN", th.InactiveText
		elseif have then
			c.status.Text, c.status.TextColor3 = "KEPT", Color3.fromRGB(120, 220, 120)
		else
			c.status.Text, c.status.TextColor3 = "SOLD", Color3.fromRGB(255, 110, 110)
			sold += 1
		end
	end
	lootTitle.Text = string.format("Chest loot this session  ·  %d items  ·  %d sold", #all, sold)
end

hudLootButton.MouseButton1Click:Connect(function()
	lootPanel.Visible = not lootPanel.Visible
	if lootPanel.Visible then lootRefreshPanel() end
end)
lootClose.MouseButton1Click:Connect(function() lootPanel.Visible = false end)

-- corner handle on the HUD: drag it out to make the HUD bigger, in to make it smaller
do
	local UIS = game:GetService("UserInputService")
	local grip = Instance.new("TextButton")
	grip.Text = ""
	grip.AutoButtonColor = false
	grip.Size = UDim2.fromOffset(14, 14)
	grip.BorderSizePixel = 0
	grip.BackgroundTransparency = 1
	grip.ZIndex = 4
	-- part of the HUD itself, so it moves and scales with it with no lag. The zero-height row lets
	-- it sit in the corner without being stacked by the HUD's list layout.
	local gripHolder = Instance.new("Frame")
	gripHolder.BackgroundTransparency = 1
	gripHolder.BorderSizePixel = 0
	gripHolder.Size = UDim2.new(1, 0, 0, 0)
	hudPlace(gripHolder)
	grip.AnchorPoint = Vector2.new(1, 1)
	grip.Position = UDim2.new(1, 8, 0, 6) -- 4 studs in from the card's corner, past the padding
	grip.Parent = gripHolder
	-- same as the LUMEN window's resize grip: two short diagonal hairlines in the corner
	local gripLines = {}
	for i, len in ipairs({ 10, 5 }) do
		local line = Instance.new("Frame")
		line.AnchorPoint = Vector2.new(0.5, 0.5)
		line.Position = UDim2.new(1, -len / 2 - 1, 1, -len / 2 - 1)
		line.Size = UDim2.fromOffset(len * 1.41, 1)
		line.Rotation = -45
		line.BorderSizePixel = 0
		line.ZIndex = 5
		line.Parent = grip
		gripLines[i] = line
	end
	local dragStart, startScale
	grip.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragStart, startScale = i.Position, F.HudScale or 120
		end
	end)
	local c1 = UIS.InputChanged:Connect(function(i)
		if dragStart and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			local d = i.Position - dragStart
			local pct = math.clamp(math.floor(startScale + (d.X + d.Y) * 0.35), 80, 160)
			pcall(function() Lumen.Options.HudScale:Set(pct) end)
			hudScale.Scale = pct / 100
		end
	end)
	local c2 = UIS.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragStart = nil end
	end)
	local c3 = RunService.Heartbeat:Connect(function()
		for _, line in ipairs(gripLines) do line.BackgroundColor3 = Lumen.Theme.Border end
	end)
	onUnload(function() c1:Disconnect() c2:Disconnect() c3:Disconnect() end)
end

local function lootRows()
	local loot = session.loot or {}
if lootPanel.Visible then lootRefreshPanel() end
	hudV.lootCount.Text = (session.lootCount or 0) > 0 and (session.lootCount .. " items") or "none yet"
	for i = 1, 3 do
		local row, name = hudLoot[i], loot[i]
		row.row.Visible = name ~= nil
		if name then
			local info = ItemDB[name]
			local display = type(info) == "table" and info.DisplayKey or nil
			row.label.Text = tostring(display or (name:gsub("(%l)(%u)", "%1 %2")))
			local rgb = type(info) == "table" and RARITY_COLORS[info.Rarity or 0] or nil
			row.label.TextColor3 = rgb or Lumen.Theme.Text
		end
	end
end
task.spawn(function()
	while not Lumen.Unloaded do
		hud.Visible = F.ShowHUD ~= false and not F.Disable3D -- the black screen shows the same stats
		if session and (hud.Visible or F.Disable3D) then
			local t = os.time() - session.start
			local perHour = t > 60 and session.earned / (t / 3600) or 0
			local gv = goldValue()
			local net = gv and (gv.Value - (session.startGold or gv.Value)) or 0
			local prof = profile()
			local lvl = prof and prof:FindFirstChild("Level") and prof.Level.Value or 0
			local avg = session.runs > 0 and session.earned / session.runs or 0
			local inv = prof and prof:FindFirstChild("Inventory")
			local items = inv and inv:FindFirstChild("Items")
			local coinItem = items and items:FindFirstChild("HalloweenCoin")
			local coinCount = coinItem and coinItem:FindFirstChild("Count")
			local coins = coinCount and coinCount.Value or 0
			session.startCoins = session.startCoins or coins
			hudPaint()
			hudV.time.Text = fmtTime(t)
			hudV.gold.Text = fmtNum(session.earned)
			hudV.hour.Text = fmtNum(perHour)
			hudV.net.Text = fmtNum(net)
			hudV.run.Text = fmtNum(session.earned - runStartEarned)
			hudV.runs.Text = session.runs .. "  avg " .. fmtNum(avg)
			hudV.levels.Text = "+" .. math.max(0, lvl - (session.startLevel or lvl)) .. "  (" .. lvl .. ")"
			hudV.coins.Text = "+" .. fmtNum(math.max(0, coins - session.startCoins))
			lootRows()
		end
		task.wait(1)
	end
end)

local hudSec = TabDungeon:AddSection("Session HUD", { Open = true })
hudSec:AddToggle("ShowHUD", { Text = "Show HUD", Default = true })
hudSec:AddToggle("StatusPill", { Text = "Show status pill", Default = true })
hudSec:AddSlider("HudScale", { Text = "HUD size", Min = 80, Max = 160, Default = 120, Decimals = 0, Suffix = " %" })
hudSec:AddSlider("SessionGap", { Text = "New session after offline", Min = 5, Max = 240, Default = 30, Decimals = 0, Suffix = " min" })
hudSec:AddButton("Reset session", function()
	local gv = goldValue()
	if gv then newSession(gv.Value) runStartEarned = 0 notify("HUD", "Session reset") end
end)
hudSec:AddLabel("Counts every gold gain across all runs and teleports. The HUD can be dragged.")

-- auto execute: re-run the hub after every teleport (dungeon start / leave). Its toggle is in Settings > Configs.
do
	local genv = getgenv and getgenv() or _G
	local function queue()
		-- once per server: every hub instance used to queue its own copy, so re-executing in the
		-- same server stacked several loads onto the next teleport
		if genv.__WZ_QUEUED or not F.AutoReexec then return end
		local q = queue_on_teleport or (syn and syn.queue_on_teleport)
		if not q then return end
		genv.__WZ_QUEUED = true
		pcall(q, [[
			if not game:IsLoaded() then game.Loaded:Wait() end
			-- wz_dev.txt marks the developer's PC, which always uses the freshly built local file
			if isfile and isfile("wz_dev.txt") and isfile("WorldZeroHub.lua") then
				loadstring(readfile("WorldZeroHub.lua"))()
			else
				local ok, src = pcall(game.HttpGet, game, "https://raw.githubusercontent.com/keickdifk-lang/wz-hub/main/WorldZeroHub.lua")
				if ok and type(src) == "string" and #src > 1000 then
					loadstring(src)()
				elseif isfile and isfile("WorldZeroHub.lua") then
					loadstring(readfile("WorldZeroHub.lua"))()
				end
			end
		]])
	end
	task.delay(4, queue) -- after the config autoload has set the toggle
	local c = LP.OnTeleport:Connect(function(state)
		if state == Enum.TeleportState.Started then queue() end
	end)
	onUnload(function() c:Disconnect() end)
end

-- Stay put: a copy of the character that exists only on this screen. WASD and the camera follow the
-- copy while the real character keeps farming, hidden from this player's view. Other players and
-- the server still see the real character.
do
	local UIS = game:GetService("UserInputService")
	local active, clone, cloneHum, cloneRoot, conn, controls, anims, playing, lastReal, tick_ = false, nil, nil, nil, nil, nil, nil, nil, nil, 0

	local function setRealHidden(hidden)
		local c = LP.Character
		if not c then return end
		for _, d in ipairs(c:GetDescendants()) do
			if d:IsA("BasePart") or d:IsA("Decal") then d.LocalTransparencyModifier = hidden and 1 or 0 end
		end
	end

	local function play(name)
		if playing == name or not anims then return end
		for key, t in pairs(anims) do
			if key == name then t:Play(0.15) else t:Stop(0.15) end
		end
		playing = name
	end

	local function loadAnims()
		anims, playing = {}, nil
		local animator = cloneHum:FindFirstChildOfClass("Animator") or Instance.new("Animator", cloneHum)
		local mod = safeRequire(RS.Client:FindFirstChild("Animations") or Shared:FindFirstChild("Animations"))
		local ok, sets = pcall(function() return mod:GetAnims() end)
		local prof = profile()
		local cls = prof and prof:FindFirstChild("Class") and prof.Class.Value
		local own = ok and type(sets) == "table" and sets[cls]
		if type(own) ~= "table" then return end
		for _, name in ipairs({ "Idle", "Run", "Fall" }) do
			local src = own[name]
			local anim = typeof(src) == "Instance" and (src:IsA("Animation") and src or (src:IsA("AnimationTrack") and src.Animation)) or (type(src) == "table" and src.Animation)
			if typeof(anim) == "Instance" then
				local ok2, track = pcall(function() return animator:LoadAnimation(anim) end)
				if ok2 then
					track.Looped = true
					anims[name] = track
				end
			end
		end
	end

	local function stop()
		active = false
		if conn then conn:Disconnect() conn = nil end
		if controls then pcall(function() controls:Enable() end) end
		setRealHidden(false)
		local hum = humanoid()
		local cam = workspace.CurrentCamera
		if cam and hum then cam.CameraSubject = hum end
		if clone then clone:Destroy() end
		clone, cloneHum, cloneRoot, anims, playing, lastReal = nil, nil, nil, nil, nil, nil
	end

	local function start()
		local char, real = LP.Character, root()
		if not char or not real then return end
		local flipped = {}
		if not char.Archivable then char.Archivable = true flipped[#flipped + 1] = char end
		for _, d in ipairs(char:GetDescendants()) do
			if not d.Archivable then d.Archivable = true flipped[#flipped + 1] = d end
		end
		local ok, copy = pcall(function() return char:Clone() end)
		for _, d in ipairs(flipped) do d.Archivable = false end
		if not ok or not copy then return end
		for _, d in ipairs(copy:GetDescendants()) do
			if d:IsA("LuaSourceContainer") then
				d:Destroy()
			elseif d:IsA("BasePart") then
				d.Anchored = false
				d.CanQuery, d.CanTouch = false, false -- never interferes with the hub's ground checks
			end
		end
		cloneHum = copy:FindFirstChildOfClass("Humanoid")
		cloneRoot = copy:FindFirstChild("HumanoidRootPart")
		if not cloneHum or not cloneRoot then copy:Destroy() return end
		cloneHum.PlatformStand, cloneHum.Sit = false, false
		copy.Name = "WZ_StayPut"
		clone = copy
		-- starts on the floor below the real character, which may be flying
		local gy = groundY(real.Position, nil, 1)
		local startAt = gy and Vector3.new(real.Position.X, gy + 5, real.Position.Z) or real.Position
		copy:PivotTo(CFrame.new(startAt))
		copy.Parent = workspace
		loadAnims()
		local okC, c = pcall(function() return require(LP.PlayerScripts.PlayerModule):GetControls() end)
		controls = okC and c or nil
		if controls then pcall(function() controls:Disable() end) end
		lastReal = real.Position
		active, tick_ = true, 0
		conn = RunService.RenderStepped:Connect(function()
			if not clone or not clone.Parent then return end
			local cam = workspace.CurrentCamera
			if cam and cam.CameraType == Enum.CameraType.Custom and cam.CameraSubject ~= cloneHum then cam.CameraSubject = cloneHum end
			local dir = Vector3.zero
			if cam and not UIS:GetFocusedTextBox() then
				local look = cam.CFrame.LookVector * Vector3.new(1, 0, 1)
				look = look.Magnitude > 0.01 and look.Unit or Vector3.new(0, 0, -1)
				local right = Vector3.new(-look.Z, 0, look.X)
				if UIS:IsKeyDown(Enum.KeyCode.W) then dir += look end
				if UIS:IsKeyDown(Enum.KeyCode.S) then dir -= look end
				if UIS:IsKeyDown(Enum.KeyCode.D) then dir += right end
				if UIS:IsKeyDown(Enum.KeyCode.A) then dir -= right end
				if UIS:IsKeyDown(Enum.KeyCode.Space) then cloneHum.Jump = true end
			end
			-- the copy inherits whatever speed the real character had when it was made, which can be 0 mid-attack
			if cloneHum.WalkSpeed < 16 then cloneHum.WalkSpeed = 24 end
			cloneHum:Move(dir.Magnitude > 0 and dir.Unit or Vector3.zero, false)
			-- the humanoid doesn't turn this local copy by itself, so face the walking direction here
			if dir.Magnitude > 0 then
				cloneHum.AutoRotate = false
				local p = cloneRoot.Position
				cloneRoot.CFrame = cloneRoot.CFrame:Lerp(CFrame.lookAt(p, p + dir.Unit), 0.35)
			end
			local airborne = cloneHum.FloorMaterial == Enum.Material.Air
			play(airborne and "Fall" or (dir.Magnitude > 0 and "Run" or "Idle"))
			tick_ += 1
			if tick_ % 20 == 0 then setRealHidden(true) end
			local r = root()
			if r then
				-- the real character teleported (new floor, new area) or the copy fell out of the map: bring it along
				local jumped = lastReal and (r.Position - lastReal).Magnitude > 150
				if jumped or cloneRoot.Position.Y < r.Position.Y - 300 then
					local g = groundY(r.Position, nil, 1)
					clone:PivotTo(CFrame.new(g and Vector3.new(r.Position.X, g + 5, r.Position.Z) or r.Position))
					cloneRoot.AssemblyLinearVelocity = Vector3.zero
				end
				lastReal = r.Position
			end
		end)
		setRealHidden(true)
	end

	safeSec:AddToggle("StayPut", { Text = "Stay put (walk a copy of yourself)", Default = false })
	onUnload(function() if active then stop() end end)
	task.spawn(function()
		while not Lumen.Unloaded do
			local wanted = F.StayPut == true
			-- the copy died or was deleted (fell out of the map, respawn...): clear it so it is rebuilt below
			if active and (not clone or not clone.Parent or not cloneHum or cloneHum.Health <= 0 or not cloneRoot or not cloneRoot.Parent) then pcall(stop) end
			if wanted and not active then pcall(start)
			elseif not wanted and active then pcall(stop) end
			task.wait(0.5)
		end
	end)
end

local settingsTab = Window:AddSettingsTab()

do
	local autoSec = settingsTab.Configs:AddSection("Auto Execute", "Right", { Open = true })
	autoSec:AddToggle("AutoReexec", { Text = "Reload hub after teleports", Default = true })
	autoSec:AddLabel("Needs WorldZeroHub.lua or internet access: after a teleport the hub reloads the latest version online.")
end

-- Disable 3D rendering: the world stops being drawn, and a black screen shows the session stats
do
	local blackout = Instance.new("Frame")
	blackout.Size = UDim2.fromScale(1, 1)
	blackout.BackgroundColor3 = Color3.new(0, 0, 0)
	blackout.BorderSizePixel = 0
	blackout.Visible = false
	blackout.ZIndex = 0
	-- its own layer in PlayerGui: above the game's UI but under the Divergence menu (hudGui can sit
	-- in CoreGui, which draws over everything and would hide the menu)
	local blackoutGui = Instance.new("ScreenGui")
	blackoutGui.Name = "WZ_Blackout"
	blackoutGui.ResetOnSpawn = false
	blackoutGui.IgnoreGuiInset = true
	blackoutGui.DisplayOrder = 9998
	blackoutGui:SetAttribute("WZHub", true)
	blackoutGui.Parent = LP:WaitForChild("PlayerGui")
	onUnload(function() blackoutGui:Destroy() end)
	blackout.Parent = blackoutGui
	local column = Instance.new("Frame")
	column.AnchorPoint = Vector2.new(0.5, 0.5)
	column.Position = UDim2.fromScale(0.5, 0.5)
	column.Size = UDim2.fromOffset(440, 0)
	column.AutomaticSize = Enum.AutomaticSize.Y
	column.BackgroundTransparency = 1
	column.Parent = blackout
	local columnList = Instance.new("UIListLayout", column)
	columnList.SortOrder = Enum.SortOrder.LayoutOrder
	columnList.Padding = UDim.new(0, 5)
	local order = 0
	local function line(height)
		order += 1
		local row = Instance.new("Frame")
		row.BackgroundTransparency = 1
		row.BorderSizePixel = 0
		row.Size = UDim2.new(1, 0, 0, height)
		row.LayoutOrder = order
		row.Parent = column
		return row
	end
	local function label(parent, font, size, align)
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(1, 1)
		t.FontFace = font
		t.TextSize = size
		t.TextXAlignment = align
		t.TextTruncate = Enum.TextTruncate.AtEnd
		t.Parent = parent
		return t
	end
	local center = Enum.TextXAlignment.Center
	local title = label(line(40), Lumen.BoldFont or Lumen.Font, 32, center)
	title.Text = "DIVERGENCE"
	local subtitle = label(line(20), Lumen.Mono or Lumen.Font, 13, center)
	subtitle.Text = "3D rendering is off"
	local statusText = label(line(26), Lumen.Mono or Lumen.Font, 13, center)
	local rows = {}
	for _, def in ipairs({
		{ "Session", "time" }, { "Gold earned", "gold" }, { "Per hour", "hour" }, { "Net", "net" }, { "This run", "run" },
		{ "Runs", "runs" }, { "Levels", "levels" }, { "Halloween coins", "coins" }, { "Chest loot", "lootCount" },
	}) do
		local row = line(26)
		local left = label(row, Lumen.Font, 18, Enum.TextXAlignment.Left)
		left.Text = def[1]
		rows[#rows + 1] = { left = left, value = label(row, Lumen.Mono or Lumen.Font, 18, Enum.TextXAlignment.Right), key = def[2] }
	end
	local lootLines = {}
	for i = 1, 3 do
		local row = line(22)
		row.Visible = false
		lootLines[i] = { row = row, label = label(row, Lumen.Font, 16, center) }
	end
	local viewLoot = Instance.new("TextButton")
	order += 1
	viewLoot.LayoutOrder = order
	viewLoot.Size = UDim2.new(1, 0, 0, 34)
	viewLoot.BorderSizePixel = 0
	viewLoot.FontFace = Lumen.Font
	viewLoot.TextSize = 15
	viewLoot.Text = "View all loot"
	viewLoot.Parent = column
	Instance.new("UICorner", viewLoot).CornerRadius = UDim.new(0, 6)
	viewLoot.MouseButton1Click:Connect(function()
		lootPanel.Visible = not lootPanel.Visible
		if lootPanel.Visible then lootRefreshPanel() end
	end)

	local enable3D = Instance.new("TextButton")
	order += 1
	enable3D.LayoutOrder = order
	enable3D.Size = UDim2.new(1, 0, 0, 34)
	enable3D.BorderSizePixel = 0
	enable3D.FontFace = Lumen.BoldFont or Lumen.Font
	enable3D.TextSize = 15
	enable3D.Text = "Enable 3D rendering"
	enable3D.Parent = column
	Instance.new("UICorner", enable3D).CornerRadius = UDim.new(0, 6)
	enable3D.MouseButton1Click:Connect(function()
		pcall(function() Lumen.Options.Disable3D:Set(false) end)
	end)

	local applied = nil
	local function setRender(off)
		applied = off
		pcall(function() RunService:Set3dRenderingEnabled(not off) end)
		blackout.Visible = off
	end
	onUnload(function() pcall(function() RunService:Set3dRenderingEnabled(true) end) end)

	local perfSec = settingsTab:AddSubTab("Performance"):AddSection("Rendering", "Left", { Open = true })
	perfSec:AddToggle("Disable3D", { Text = "Disable 3D rendering", Default = false })
	perfSec:AddLabel("Stops drawing the world to save CPU and GPU. A black screen shows your session stats instead. The hub keeps playing.")

	task.spawn(function()
		while not Lumen.Unloaded do
			local wanted = F.Disable3D == true
			if wanted ~= applied then setRender(wanted) end
			if wanted then
				local th = Lumen.Theme
				title.TextColor3 = th.Accent
				subtitle.TextColor3 = th.InactiveText
				statusText.TextColor3 = th.Gradient
				statusText.Text = tostring(status.text)
				viewLoot.BackgroundColor3, viewLoot.TextColor3 = th.Element, th.Text
				enable3D.BackgroundColor3, enable3D.TextColor3 = th.Accent, th.Background
				for _, r in ipairs(rows) do
					r.left.TextColor3 = th.InactiveText
					r.value.Text = hudV[r.key].Text
					r.value.TextColor3 = hudV[r.key].TextColor3
				end
				for i, l in ipairs(lootLines) do
					l.row.Visible = hudLoot[i].row.Visible
					l.label.Text = hudLoot[i].label.Text
					l.label.TextColor3 = hudLoot[i].label.TextColor3
				end
			end
			task.wait(0.5)
		end
	end)
end

Lumen:OnUnload(function()
	for _, fn in ipairs(cleanup) do pcall(fn) end
	stopMoving()
end)

notify("World // Zero", (inDungeon and "Dungeon" or "Lobby") .. " · RightShift opens the menu", 5)

end)()
