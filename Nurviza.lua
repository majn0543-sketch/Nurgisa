--[[
DevTools Mobile: touch panel for YOUR OWN Piggy-style game (Roblox Studio).
Put in StarterPlayer > StarterPlayerScripts as a LocalScript.

Tag objects with CollectionService (Tag Editor plugin):
  "Item", "Monster", "Exit"

Buttons on screen: Speed, Noclip, TP Item, ESP, Fullbright, Auto. Top "-" button collapses the panel.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CS = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer

-- Safety: Studio or whitelisted developers only
local DEV_IDS = {} -- add your UserId here
if not (RunService:IsStudio() or table.find(DEV_IDS, player.UserId)) then return end

local state = { speed = false, noclip = false, esp = false, fullbright = false, auto = false }
local NORMAL_SPEED, FAST_SPEED = 16, 60

local function getChar()
	local char = player.Character or player.CharacterAdded:Wait()
	return char, char:WaitForChild("Humanoid"), char:WaitForChild("HumanoidRootPart")
end

local function posOf(obj)
	if obj:IsA("Model") then return obj:GetPivot().Position end
	if obj:IsA("BasePart") then return obj.Position end
end

local function teleportTo(obj)
	local _, _, root = getChar()
	local p = posOf(obj)
	if p then root.CFrame = CFrame.new(p + Vector3.new(0, 4, 0)) end
end

local function applySpeed()
	local _, hum = getChar()
	hum.WalkSpeed = state.speed and FAST_SPEED or NORMAL_SPEED
end

RunService.Stepped:Connect(function()
	if not state.noclip then return end
	local char = player.Character
	if not char then return end
	for _, part in ipairs(char:GetDescendants()) do
		if part:IsA("BasePart") then part.CanCollide = false end
	end
end)

local function nearestItem()
	local _, _, root = getChar()
	local best, bestDist
	for _, item in ipairs(CS:GetTagged("Item")) do
		local p = posOf(item)
		if p then
			local d = (p - root.Position).Magnitude
			if not bestDist or d < bestDist then best, bestDist = item, d end
		end
	end
	return best
end

local ESP_COLORS = {
	Item = Color3.fromRGB(80, 255, 120),
	Monster = Color3.fromRGB(255, 60, 60),
	Exit = Color3.fromRGB(80, 160, 255),
}
local function refreshESP()
	for tag, color in pairs(ESP_COLORS) do
		for _, obj in ipairs(CS:GetTagged(tag)) do
			local h = obj:FindFirstChild("DevESP")
			if state.esp then
				if not h then
					h = Instance.new("Highlight")
					h.Name = "DevESP"
					h.FillColor = color
					h.OutlineColor = color
					h.FillTransparency = 0.6
					h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
					h.Parent = obj
				end
			elseif h then
				h:Destroy()
			end
		end
	end
end
for tag in pairs(ESP_COLORS) do
	CS:GetInstanceAddedSignal(tag):Connect(function() if state.esp then refreshESP() end end)
end

local saved = {}
local function applyFullbright()
	if state.fullbright then
		saved = {
			Brightness = Lighting.Brightness, Ambient = Lighting.Ambient,
			OutdoorAmbient = Lighting.OutdoorAmbient, ClockTime = Lighting.ClockTime,
			FogEnd = Lighting.FogEnd, GlobalShadows = Lighting.GlobalShadows,
		}
		Lighting.Brightness = 2
		Lighting.Ambient = Color3.new(1, 1, 1)
		Lighting.OutdoorAmbient = Color3.new(1, 1, 1)
		Lighting.ClockTime = 14
		Lighting.FogEnd = 1e6
		Lighting.GlobalShadows = false
	else
		for k, v in pairs(saved) do Lighting[k] = v end
	end
end

local function autoComplete()
	state.auto = true
	for _, item in ipairs(CS:GetTagged("Item")) do
		if not state.auto then return end
		teleportTo(item)
		task.wait(0.6)
		local prompt = item:FindFirstChildWhichIsA("ProximityPrompt", true)
		if prompt then fireproximityprompt(prompt) end
	end
	if state.auto then
		local exit = CS:GetTagged("Exit")[1]
		if exit then teleportTo(exit) end
	end
	state.auto = false
end

-- GUI
local gui = Instance.new("ScreenGui")
gui.Name = "DevToolsMobile"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.Size = UDim2.new(0, 130, 0, 6 * 40 + 7 * 6)
panel.Position = UDim2.new(0, 10, 0.5, -130)
panel.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
panel.BackgroundTransparency = 0.3
panel.BorderSizePixel = 0
panel.Parent = gui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 10)

local layout = Instance.new("UIListLayout", panel)
layout.Padding = UDim.new(0, 6)
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
local pad = Instance.new("UIPadding", panel)
pad.PaddingTop = UDim.new(0, 6)

local OFF, ON = Color3.fromRGB(60, 60, 70), Color3.fromRGB(40, 160, 90)
local buttons = {}

local function addButton(name, label, onTap)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, -12, 0, 40)
	b.BackgroundColor3 = OFF
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Font = Enum.Font.GothamBold
	b.TextSize = 15
	b.Text = label
	b.AutoButtonColor = true
	b.Parent = panel
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
	b.Activated:Connect(function()
		onTap()
		for key, btn in pairs(buttons) do
			if state[key] ~= nil then btn.BackgroundColor3 = state[key] and ON or OFF end
		end
	end)
	buttons[name] = b
end

addButton("speed", "Speed", function() state.speed = not state.speed; applySpeed() end)
addButton("noclip", "Noclip", function() state.noclip = not state.noclip end)
addButton("tp", "TP Item", function()
	local item = nearestItem()
	if item then teleportTo(item) end
end)
addButton("esp", "ESP", function() state.esp = not state.esp; refreshESP() end)
addButton("fullbright", "Fullbright", function() state.fullbright = not state.fullbright; applyFullbright() end)
addButton("auto", "Auto", function()
	if state.auto then state.auto = false else task.spawn(autoComplete) end
end)

-- Collapse button
local toggle = Instance.new("TextButton")
toggle.Size = UDim2.new(0, 36, 0, 36)
toggle.Position = UDim2.new(0, 10, 0.5, -172)
toggle.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
toggle.BackgroundTransparency = 0.3
toggle.TextColor3 = Color3.new(1, 1, 1)
toggle.Font = Enum.Font.GothamBold
toggle.TextSize = 20
toggle.Text = "-"
toggle.Parent = gui
Instance.new("UICorner", toggle).CornerRadius = UDim.new(0, 8)
toggle.Activated:Connect(function()
	panel.Visible = not panel.Visible
	toggle.Text = panel.Visible and "-" or "+"
end)

player.CharacterAdded:Connect(function()
	task.wait(0.5)
	applySpeed()
end)

print("[DevToolsMobile] Loaded")
