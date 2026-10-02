--[[ Bobaaboba Script v2.1 — исправленная версия для тестирования в Roblox Studio
Установка: LocalScript в StarterPlayer > StarterPlayerScripts.
Aimbot работает, пока зажата правая кнопка мыши. ]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local Camera = workspace.CurrentCamera
local LP = Players.LocalPlayer

local Settings = {
	Aimbot = false,
	ESP = false,
	InfiniteJump = false,
	Fly = false,
	Triggerbot = false,
	FOV = false,
	Hitboxes = false,
	Fling = false,
	Invisible = false,
	FOVSize = 150,
	Target = nil, -- выбранный игрок (слежка / fling)
}

-- Все подключения, чтобы корректно отключить их при закрытии меню
local connections = {}
local function connect(signal, fn)
	local c = signal:Connect(fn)
	table.insert(connections, c)
	return c
end

----------------------------------------------------------------
-- Хелперы
----------------------------------------------------------------
local OriginalHitboxes = {}
local OriginalTransparency = {}

local function getHumanoid(char)
	return char and char:FindFirstChildOfClass("Humanoid")
end

local function stopSpectate()
	Settings.Target = nil
	local hum = getHumanoid(LP.Character)
	if hum then
		Camera.CameraSubject = hum
	end
end

local function startSpectate(player)
	Settings.Target = player
	local hum = getHumanoid(player.Character)
	if hum then
		Camera.CameraSubject = hum -- CameraSubject должен быть Humanoid, а не HRP
	end
end

local function clearESP()
	for _, p in ipairs(Players:GetPlayers()) do
		local tag = p.Character and p.Character:FindFirstChild("ESP")
		if tag then
			tag:Destroy()
		end
	end
end

local function updateESP()
	for _, p in ipairs(Players:GetPlayers()) do
		local hrp = p ~= LP and p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if hrp and not p.Character:FindFirstChild("ESP") then
			local Billboard = Instance.new("BillboardGui")
			Billboard.Name = "ESP"
			Billboard.Size = UDim2.new(0, 100, 0, 30)
			Billboard.AlwaysOnTop = true
			Billboard.Adornee = hrp
			Billboard.Parent = p.Character

			local Frame = Instance.new("Frame")
			Frame.Size = UDim2.new(1, 0, 1, 0)
			Frame.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
			Frame.BackgroundTransparency = 0.5
			Frame.BorderSizePixel = 2
			Frame.BorderColor3 = Color3.fromRGB(255, 255, 255)
			Frame.Parent = Billboard

			local NameLabel = Instance.new("TextLabel")
			NameLabel.Size = UDim2.new(1, 0, 0.5, 0)
			NameLabel.BackgroundTransparency = 1
			NameLabel.Text = p.Name
			NameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
			NameLabel.TextSize = 12
			NameLabel.Font = Enum.Font.GothamBold
			NameLabel.Parent = Frame
		end
	end
end

local function updateHitboxes()
	for _, p in ipairs(Players:GetPlayers()) do
		local hrp = p ~= LP and p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if hrp then
			if not OriginalHitboxes[hrp] then
				OriginalHitboxes[hrp] = {
					Size = hrp.Size,
					Transparency = hrp.Transparency,
					CanCollide = hrp.CanCollide,
				}
			end
			hrp.Size = Vector3.new(10, 10, 10)
			hrp.Transparency = 0.5
			hrp.CanCollide = false
		end
	end
end

local function restoreHitboxes()
	for hrp, data in pairs(OriginalHitboxes) do
		if hrp.Parent then
			hrp.Size = data.Size
			hrp.Transparency = data.Transparency
			hrp.CanCollide = data.CanCollide
		end
	end
	table.clear(OriginalHitboxes)
end

local function setInvisible(state)
	local char = LP.Character
	if not char then
		return
	end
	for _, v in ipairs(char:GetDescendants()) do
		if v:IsA("BasePart") or v:IsA("Decal") then
			if state then
				if OriginalTransparency[v] == nil then
					OriginalTransparency[v] = v.Transparency
				end
				v.Transparency = 1
			elseif OriginalTransparency[v] ~= nil then
				v.Transparency = OriginalTransparency[v]
				OriginalTransparency[v] = nil
			end
		end
	end
	-- CanCollide не трогаем: иначе персонаж провалится сквозь пол
end

-- Ближайшая к курсору цель в радиусе radius (в пикселях)
local function getClosestTarget(radius)
	local mouse = UserInputService:GetMouseLocation()
	local bestPart, bestDist = nil, radius
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= LP and p.Character then
			local hum = getHumanoid(p.Character)
			local part = p.Character:FindFirstChild("Head") or p.Character:FindFirstChild("HumanoidRootPart")
			if hum and hum.Health > 0 and part then
				local pos, onScreen = Camera:WorldToViewportPoint(part.Position)
				if onScreen then
					local d = (Vector2.new(pos.X, pos.Y) - mouse).Magnitude
					if d < bestDist then
						bestPart, bestDist = part, d
					end
				end
			end
		end
	end
	return bestPart
end

----------------------------------------------------------------
-- GUI
----------------------------------------------------------------
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "Bobaaboba"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = LP:WaitForChild("PlayerGui")

-- Отдельный GUI для FOV-круга (IgnoreGuiInset, чтобы координаты совпадали с курсором)
local OverlayGui = Instance.new("ScreenGui")
OverlayGui.Name = "BobaabobaOverlay"
OverlayGui.ResetOnSpawn = false
OverlayGui.IgnoreGuiInset = true
OverlayGui.Parent = LP.PlayerGui

local FOVCircle = Instance.new("Frame")
FOVCircle.AnchorPoint = Vector2.new(0.5, 0.5)
FOVCircle.BackgroundTransparency = 1
FOVCircle.Visible = false
FOVCircle.Parent = OverlayGui

local FOVCorner = Instance.new("UICorner")
FOVCorner.CornerRadius = UDim.new(1, 0)
FOVCorner.Parent = FOVCircle

local FOVStroke = Instance.new("UIStroke")
FOVStroke.Thickness = 2
FOVStroke.Color = Color3.fromRGB(0, 255, 0)
FOVStroke.Parent = FOVCircle

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 350, 0, 500)
MainFrame.Position = UDim2.new(0.5, -175, 0.5, -250)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 35)
MainFrame.BackgroundTransparency = 0.1
MainFrame.BorderSizePixel = 0
MainFrame.Parent = ScreenGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 15)
UICorner.Parent = MainFrame

local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, 40)
TitleBar.BackgroundColor3 = Color3.fromRGB(30, 30, 60)
TitleBar.BorderSizePixel = 0
TitleBar.Parent = MainFrame

local TitleCorner = Instance.new("UICorner")
TitleCorner.CornerRadius = UDim.new(0, 15)
TitleCorner.Parent = TitleBar

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 1, 0)
Title.BackgroundTransparency = 1
Title.Text = "Bobaaboba Script"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 18
Title.Font = Enum.Font.GothamBold
Title.Parent = TitleBar

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 30, 0, 30)
CloseBtn.Position = UDim2.new(1, -35, 0, 5)
CloseBtn.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.TextSize = 14
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.Parent = TitleBar

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 10)
CloseCorner.Parent = CloseBtn

-- Перетаскивание окна
local dragging, dragInput, dragStart, startPos = false, nil, nil, nil

connect(TitleBar.InputBegan, function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = true
		dragStart = input.Position
		startPos = MainFrame.Position
	end
end)

connect(TitleBar.InputChanged, function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement then
		dragInput = input
	end
end)

connect(UserInputService.InputChanged, function(input)
	if input == dragInput and dragging then
		local delta = input.Position - dragStart
		MainFrame.Position = UDim2.new(
			startPos.X.Scale, startPos.X.Offset + delta.X,
			startPos.Y.Scale, startPos.Y.Offset + delta.Y
		)
	end
end)

connect(UserInputService.InputEnded, function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = false
	end
end)

-- Список элементов (UIListLayout, иначе все кнопки наложатся друг на друга)
local ScrollFrame = Instance.new("ScrollingFrame")
ScrollFrame.Size = UDim2.new(1, 0, 1, -50)
ScrollFrame.Position = UDim2.new(0, 0, 0, 45)
ScrollFrame.BackgroundTransparency = 1
ScrollFrame.BorderSizePixel = 0
ScrollFrame.ScrollBarThickness = 5
ScrollFrame.ScrollBarImageColor3 = Color3.fromRGB(255, 255, 255)
ScrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
ScrollFrame.Parent = MainFrame

local Layout = Instance.new("UIListLayout")
Layout.Padding = UDim.new(0, 8)
Layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
Layout.SortOrder = Enum.SortOrder.LayoutOrder
Layout.Parent = ScrollFrame

local ListPadding = Instance.new("UIPadding")
ListPadding.PaddingTop = UDim.new(0, 5)
ListPadding.PaddingBottom = UDim.new(0, 5)
ListPadding.Parent = ScrollFrame

local order = 0
local function nextOrder()
	order += 1
	return order
end

local function CreateButton(text, callback, color)
	local base = color or Color3.fromRGB(40, 40, 80)
	local hover = color or Color3.fromRGB(60, 60, 120)

	local Button = Instance.new("TextButton")
	Button.Size = UDim2.new(0.9, 0, 0, 35)
	Button.BackgroundColor3 = base
	Button.Text = text
	Button.TextColor3 = Color3.fromRGB(255, 255, 255)
	Button.TextSize = 14
	Button.Font = Enum.Font.Gotham
	Button.LayoutOrder = nextOrder()
	Button.Parent = ScrollFrame

	local Corner = Instance.new("UICorner")
	Corner.CornerRadius = UDim.new(0, 10)
	Corner.Parent = Button

	connect(Button.MouseEnter, function()
		TweenService:Create(Button, TweenInfo.new(0.2), { BackgroundColor3 = hover }):Play()
	end)
	connect(Button.MouseLeave, function()
		TweenService:Create(Button, TweenInfo.new(0.2), { BackgroundColor3 = base }):Play()
	end)
	connect(Button.MouseButton1Click, callback)
	return Button
end

-- onOff вызывается при выключении, чтобы убрать следы (ESP, хитбоксы и т.д.)
local function CreateToggle(text, setting, onOff)
	local Toggle = Instance.new("TextButton")
	Toggle.Size = UDim2.new(0.9, 0, 0, 35)
	Toggle.BackgroundColor3 = Color3.fromRGB(40, 40, 80)
	Toggle.Text = text .. " [OFF]"
	Toggle.TextColor3 = Color3.fromRGB(255, 255, 255)
	Toggle.TextSize = 14
	Toggle.Font = Enum.Font.Gotham
	Toggle.LayoutOrder = nextOrder()
	Toggle.Parent = ScrollFrame

	local Corner = Instance.new("UICorner")
	Corner.CornerRadius = UDim.new(0, 10)
	Corner.Parent = Toggle

	connect(Toggle.MouseButton1Click, function()
		Settings[setting] = not Settings[setting]
		Toggle.Text = text .. (Settings[setting] and " [ON]" or " [OFF]")
		Toggle.BackgroundColor3 = Settings[setting] and Color3.fromRGB(0, 200, 100) or Color3.fromRGB(40, 40, 80)
		if not Settings[setting] and onOff then
			onOff()
		end
	end)
	return Toggle
end

local function CreateSlider(text, setting, min, max, default)
	local Frame = Instance.new("Frame")
	Frame.Size = UDim2.new(0.9, 0, 0, 50)
	Frame.BackgroundColor3 = Color3.fromRGB(40, 40, 80)
	Frame.LayoutOrder = nextOrder()
	Frame.Parent = ScrollFrame

	local Corner = Instance.new("UICorner")
	Corner.CornerRadius = UDim.new(0, 10)
	Corner.Parent = Frame

	local Label = Instance.new("TextLabel")
	Label.Size = UDim2.new(1, 0, 0, 20)
	Label.BackgroundTransparency = 1
	Label.Text = text .. ": " .. default
	Label.TextColor3 = Color3.fromRGB(255, 255, 255)
	Label.TextSize = 12
	Label.Font = Enum.Font.Gotham
	Label.Parent = Frame

	local Slider = Instance.new("TextButton")
	Slider.Size = UDim2.new(0.9, 0, 0, 15)
	Slider.Position = UDim2.new(0.05, 0, 0, 25)
	Slider.BackgroundColor3 = Color3.fromRGB(100, 100, 150)
	Slider.Text = ""
	Slider.AutoButtonColor = false
	Slider.Parent = Frame

	local SliderCorner = Instance.new("UICorner")
	SliderCorner.CornerRadius = UDim.new(0, 7)
	SliderCorner.Parent = Slider

	local Fill = Instance.new("Frame")
	Fill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0) -- по реальному значению по умолчанию
	Fill.BackgroundColor3 = Color3.fromRGB(0, 200, 255)
	Fill.BorderSizePixel = 0
	Fill.Parent = Slider

	local FillCorner = Instance.new("UICorner")
	FillCorner.CornerRadius = UDim.new(0, 7)
	FillCorner.Parent = Fill

	Settings[setting] = default

	local sliding = false
	local function update(x)
		local a = math.clamp((x - Slider.AbsolutePosition.X) / Slider.AbsoluteSize.X, 0, 1)
		local value = math.floor(min + (max - min) * a)
		Settings[setting] = value
		Fill.Size = UDim2.new(a, 0, 1, 0)
		Label.Text = text .. ": " .. value
	end

	connect(Slider.InputBegan, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			sliding = true
			update(input.Position.X)
		end
	end)

	-- Слушаем глобально, чтобы слайдер работал, даже если курсор ушёл за его пределы
	connect(UserInputService.InputChanged, function(input)
		if sliding and input.UserInputType == Enum.UserInputType.MouseMovement then
			update(input.Position.X)
		end
	end)

	connect(UserInputService.InputEnded, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			sliding = false
		end
	end)
end

-- Окно выбора игрока для слежки / fling
local function OpenPlayerList()
	local ListGui = Instance.new("ScreenGui")
	ListGui.ResetOnSpawn = false
	ListGui.Parent = LP.PlayerGui

	local ListFrame = Instance.new("Frame")
	ListFrame.Size = UDim2.new(0, 200, 0, 300)
	ListFrame.Position = UDim2.new(0.5, -100, 0.5, -150)
	ListFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 35)
	ListFrame.BorderSizePixel = 0
	ListFrame.Parent = ListGui

	local ListCorner = Instance.new("UICorner")
	ListCorner.CornerRadius = UDim.new(0, 10)
	ListCorner.Parent = ListFrame

	local ListTitle = Instance.new("TextLabel")
	ListTitle.Size = UDim2.new(1, 0, 0, 30)
	ListTitle.BackgroundColor3 = Color3.fromRGB(30, 30, 60)
	ListTitle.Text = "Выберите игрока"
	ListTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
	ListTitle.TextSize = 14
	ListTitle.Font = Enum.Font.GothamBold
	ListTitle.Parent = ListFrame

	local ListCorner2 = Instance.new("UICorner")
	ListCorner2.CornerRadius = UDim.new(0, 10)
	ListCorner2.Parent = ListTitle

	local ListScroll = Instance.new("ScrollingFrame")
	ListScroll.Size = UDim2.new(1, 0, 1, -30)
	ListScroll.Position = UDim2.new(0, 0, 0, 30)
	ListScroll.BackgroundTransparency = 1
	ListScroll.BorderSizePixel = 0
	ListScroll.ScrollBarThickness = 3
	ListScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	ListScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	ListScroll.Parent = ListFrame

	local ListLayout = Instance.new("UIListLayout")
	ListLayout.Padding = UDim.new(0, 5)
	ListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	ListLayout.SortOrder = Enum.SortOrder.LayoutOrder
	ListLayout.Parent = ListScroll

	local function makeBtn(text, color, onClick)
		local b = Instance.new("TextButton")
		b.Size = UDim2.new(0.9, 0, 0, 30)
		b.BackgroundColor3 = color
		b.Text = text
		b.TextColor3 = Color3.fromRGB(255, 255, 255)
		b.TextSize = 12
		b.Font = Enum.Font.Gotham
		b.Parent = ListScroll
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 8)
		c.Parent = b
		b.MouseButton1Click:Connect(onClick)
		return b
	end

	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= LP then
			makeBtn(p.Name, Color3.fromRGB(40, 40, 80), function()
				startSpectate(p)
				ListGui:Destroy()
			end)
		end
	end

	makeBtn("Остановить слежку", Color3.fromRGB(255, 50, 50), function()
		stopSpectate()
		ListGui:Destroy()
	end)
end

local Unload -- определяется ниже, в блоке «Закрытие меню»

-- Элементы меню
CreateToggle("Aimbot (ПКМ)", "Aimbot")
CreateToggle("ESP", "ESP", clearESP)
CreateToggle("Бесконечные прыжки", "InfiniteJump")
CreateToggle("Fly", "Fly")
CreateToggle("Triggerbot", "Triggerbot")
CreateToggle("FOV круг", "FOV")
CreateToggle("Hitboxes", "Hitboxes", restoreHitboxes)
CreateToggle("Fling (по выбранному игроку)", "Fling", function()
	local hrp = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
	if hrp then
		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.AssemblyAngularVelocity = Vector3.zero
	end
end)
CreateToggle("Невидимость", "Invisible", function()
	setInvisible(false)
end)
CreateButton("Слежка за игроками", OpenPlayerList, Color3.fromRGB(80, 50, 150))
CreateSlider("FOV", "FOVSize", 50, 500, 150)
CreateButton("Выгрузить скрипт полностью", function()
	Unload()
end, Color3.fromRGB(150, 40, 40))

----------------------------------------------------------------
-- Закрытие меню: отключаем всё и убираем следы
----------------------------------------------------------------
Unload = function()
	for _, c in ipairs(connections) do
		c:Disconnect()
	end
	RunService:UnbindFromRenderStep("BobaabobaCamera")
	clearESP()
	restoreHitboxes()
	setInvisible(false)
	stopSpectate()
	OverlayGui:Destroy()
	ScreenGui:Destroy()
end

-- Показать / скрыть меню (читы при этом продолжают работать)
local MENU_KEY = Enum.KeyCode.M

local function toggleMenu()
	MainFrame.Visible = not MainFrame.Visible
end

connect(CloseBtn.MouseButton1Click, function()
	MainFrame.Visible = false
end)

connect(UserInputService.InputBegan, function(input, gameProcessed)
	-- gameProcessed = true, если игрок печатает в чате или другом TextBox
	if gameProcessed then
		return
	end
	if input.KeyCode == MENU_KEY then
		toggleMenu()
	end
end)

----------------------------------------------------------------
-- Логика
----------------------------------------------------------------

-- Aimbot: после стандартной камеры, пока зажата ПКМ
RunService:BindToRenderStep("BobaabobaCamera", Enum.RenderPriority.Camera.Value + 1, function()
	if Settings.Aimbot and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
		local part = getClosestTarget(Settings.FOVSize)
		if part then
			Camera.CFrame = CFrame.lookAt(Camera.CFrame.Position, part.Position)
		end
	end
end)

connect(RunService.RenderStepped, function()
	if Settings.ESP then
		updateESP()
	end

	if Settings.Hitboxes then
		updateHitboxes()
	end

	if Settings.Invisible then
		setInvisible(true)
	end

	-- Triggerbot: вместо mouse1click (его нет вне эксплойтов) активируем Tool в руках
	if Settings.Triggerbot and getClosestTarget(50) then
		local tool = LP.Character and LP.Character:FindFirstChildOfClass("Tool")
		if tool then
			tool:Activate()
		end
	end

	-- FOV круг (вместо Drawing.new)
	FOVCircle.Visible = Settings.FOV
	if Settings.FOV then
		local m = UserInputService:GetMouseLocation()
		FOVCircle.Size = UDim2.fromOffset(Settings.FOVSize * 2, Settings.FOVSize * 2)
		FOVCircle.Position = UDim2.fromOffset(m.X, m.Y)
	end
end)

-- Fly и Fling — в Heartbeat, потому что работают с физикой
connect(RunService.Heartbeat, function()
	local char = LP.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end

	if Settings.Fly and not UserInputService:GetFocusedTextBox() then
		local v = Vector3.zero
		if UserInputService:IsKeyDown(Enum.KeyCode.W) then v += Camera.CFrame.LookVector * 50 end
		if UserInputService:IsKeyDown(Enum.KeyCode.S) then v -= Camera.CFrame.LookVector * 50 end
		if UserInputService:IsKeyDown(Enum.KeyCode.A) then v -= Camera.CFrame.RightVector * 50 end
		if UserInputService:IsKeyDown(Enum.KeyCode.D) then v += Camera.CFrame.RightVector * 50 end
		if UserInputService:IsKeyDown(Enum.KeyCode.Space) then v += Vector3.new(0, 50, 0) end
		if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then v -= Vector3.new(0, 50, 0) end
		hrp.AssemblyLinearVelocity = v
	end

	-- Fling: AngularVelocity у BasePart нет — правильное свойство AssemblyAngularVelocity
	if Settings.Fling and Settings.Target and Settings.Target.Character then
		local targetHrp = Settings.Target.Character:FindFirstChild("HumanoidRootPart")
		if targetHrp then
			hrp.CFrame = targetHrp.CFrame * CFrame.new(0, 0, 3)
			hrp.AssemblyLinearVelocity = Vector3.new(0, 500, 0)
			hrp.AssemblyAngularVelocity = Vector3.new(0, 1000, 0)
		end
	end
end)

-- Бесконечные прыжки
connect(UserInputService.JumpRequest, function()
	if Settings.InfiniteJump then
		local hum = getHumanoid(LP.Character)
		if hum then
			hum:ChangeState(Enum.HumanoidStateType.Jumping)
		end
	end
end)

-- Сброс слежки при респавне
connect(LP.CharacterAdded, function()
	Settings.Target = nil
end)

print("Bobaaboba Script загружен! Меню открывается и закрывается клавишей M.")