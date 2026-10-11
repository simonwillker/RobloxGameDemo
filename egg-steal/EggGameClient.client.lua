-- EggGameClient (LocalScript)
-- 置き場所: StarterPlayer > StarterPlayerScripts
-- 画面のボタン（台を増やす・スピードUP・ロック・押す）と通知を作ります。

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local Config = require(ReplicatedStorage:WaitForChild("EggConfig"))
local remotes = ReplicatedStorage:WaitForChild("EggRemotes")

local function formatNumber(n)
	if n >= 1e9 then
		return string.format("%.1fB", n / 1e9)
	elseif n >= 1e6 then
		return string.format("%.1fM", n / 1e6)
	elseif n >= 1e3 then
		return string.format("%.1fK", n / 1e3)
	end
	return tostring(math.floor(n))
end

--------------------------------------------------------------------------
-- 画面作成
--------------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "EggGameUI"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local cashLabel = Instance.new("TextLabel")
cashLabel.AnchorPoint = Vector2.new(0, 1)
cashLabel.Position = UDim2.new(0, 16, 1, -16)
cashLabel.Size = UDim2.fromOffset(240, 50)
cashLabel.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
cashLabel.BackgroundTransparency = 0.2
cashLabel.Font = Enum.Font.GothamBold
cashLabel.TextScaled = true
cashLabel.TextColor3 = Color3.fromRGB(120, 255, 120)
cashLabel.Text = "$0"
cashLabel.Parent = gui
Instance.new("UICorner", cashLabel).CornerRadius = UDim.new(0, 10)

-- コード入力欄（お金の上）
local codeFrame = Instance.new("Frame")
codeFrame.AnchorPoint = Vector2.new(0, 1)
codeFrame.Position = UDim2.new(0, 16, 1, -76)
codeFrame.Size = UDim2.fromOffset(240, 40)
codeFrame.BackgroundTransparency = 1
codeFrame.Parent = gui

local codeBox = Instance.new("TextBox")
codeBox.Size = UDim2.new(1, -76, 1, 0)
codeBox.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
codeBox.PlaceholderText = "コードを入力"
codeBox.Text = ""
codeBox.ClearTextOnFocus = false
codeBox.Font = Enum.Font.GothamBold
codeBox.TextScaled = true
codeBox.TextColor3 = Color3.fromRGB(30, 30, 30)
codeBox.Parent = codeFrame
Instance.new("UICorner", codeBox).CornerRadius = UDim.new(0, 8)

local codeButton = Instance.new("TextButton")
codeButton.AnchorPoint = Vector2.new(1, 0)
codeButton.Position = UDim2.new(1, 0, 0, 0)
codeButton.Size = UDim2.new(0, 70, 1, 0)
codeButton.BackgroundColor3 = Color3.fromRGB(255, 170, 40)
codeButton.Font = Enum.Font.GothamBold
codeButton.TextScaled = true
codeButton.TextColor3 = Color3.new(1, 1, 1)
codeButton.Text = "使う"
codeButton.Parent = codeFrame
Instance.new("UICorner", codeButton).CornerRadius = UDim.new(0, 8)

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(1, 0.5)
panel.Position = UDim2.new(1, -16, 0.5, 0)
panel.Size = UDim2.fromOffset(200, 260)
panel.BackgroundTransparency = 1
panel.Parent = gui
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 8)
layout.Parent = panel

local function makeButton(color)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, 0, 0, 56)
	b.BackgroundColor3 = color
	b.Font = Enum.Font.GothamBold
	b.TextScaled = true
	b.TextColor3 = Color3.new(1, 1, 1)
	b.AutoButtonColor = true
	b.Parent = panel
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 10)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 6)
	pad.PaddingRight = UDim.new(0, 6)
	pad.PaddingTop = UDim.new(0, 4)
	pad.PaddingBottom = UDim.new(0, 4)
	pad.Parent = b
	return b
end

local slotButton = makeButton(Color3.fromRGB(60, 140, 230))
local speedButton = makeButton(Color3.fromRGB(60, 180, 100))
local lockButton = makeButton(Color3.fromRGB(220, 70, 70))
local shoveButton = makeButton(Color3.fromRGB(230, 150, 40))
shoveButton.Text = "押す [F]"
local dropButton = makeButton(Color3.fromRGB(120, 120, 140))
dropButton.Text = "落とす [G]"
dropButton.Visible = false -- 何か持っているときだけ表示
panel.Size = UDim2.fromOffset(200, 330)

local notice = Instance.new("TextLabel")
notice.AnchorPoint = Vector2.new(0.5, 0)
notice.Position = UDim2.new(0.5, 0, 0, 70)
notice.Size = UDim2.fromOffset(520, 44)
notice.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
notice.BackgroundTransparency = 1
notice.Font = Enum.Font.GothamBold
notice.TextScaled = true
notice.TextColor3 = Color3.new(1, 1, 1)
notice.TextTransparency = 1
notice.Text = ""
notice.Parent = gui
Instance.new("UICorner", notice).CornerRadius = UDim.new(0, 10)

--------------------------------------------------------------------------
-- ボタン操作
--------------------------------------------------------------------------
slotButton.Activated:Connect(function()
	remotes.BuyUpgrade:FireServer("Slot")
end)
speedButton.Activated:Connect(function()
	remotes.BuyUpgrade:FireServer("Speed")
end)
lockButton.Activated:Connect(function()
	remotes.LockBase:FireServer()
end)
shoveButton.Activated:Connect(function()
	remotes.Shove:FireServer()
end)
local function sendCode()
	if codeBox.Text ~= "" then
		remotes.RedeemCode:FireServer(codeBox.Text)
		codeBox.Text = ""
	end
end
codeButton.Activated:Connect(sendCode)
codeBox.FocusLost:Connect(function(enterPressed)
	if enterPressed then
		sendCode()
	end
end)

dropButton.Activated:Connect(function()
	remotes.DropItem:FireServer()
end)

--------------------------------------------------------------------------
-- 飛ぶ（コード「うんこです」・管理者専用）
-- ジャンプを2回すばやく押すと飛ぶ / もう一度2回押すと着地。
-- 移動キー/スティックでカメラの向きへ飛ぶ。スペースで上昇、Q で下降。
--------------------------------------------------------------------------
local FLY_SPEED = 50
local flying = false
local flyVel, flyGyro
local controls = nil
task.spawn(function()
	local ok, playerModule = pcall(function()
		return require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"))
	end)
	if ok then
		controls = playerModule:GetControls()
	end
end)

local function stopFly()
	flying = false
	if flyVel then
		flyVel:Destroy()
		flyVel = nil
	end
	if flyGyro then
		flyGyro:Destroy()
		flyGyro = nil
	end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.PlatformStand = false
	end
end

local function startFly()
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not root or not hum or hum.Health <= 0 then
		return
	end
	flying = true
	flyVel = Instance.new("BodyVelocity")
	flyVel.MaxForce = Vector3.new(1e6, 1e6, 1e6)
	flyVel.Velocity = Vector3.zero
	flyVel.Parent = root
	flyGyro = Instance.new("BodyGyro")
	flyGyro.MaxTorque = Vector3.new(1e6, 1e6, 1e6)
	flyGyro.P = 1e4
	flyGyro.CFrame = root.CFrame
	flyGyro.Parent = root
	hum.PlatformStand = true
end

local function toggleFly()
	if not player:GetAttribute("CanFly") then
		return
	end
	if flying then
		stopFly()
	else
		startFly()
	end
end
player.CharacterAdded:Connect(function()
	flying = false
	flyVel, flyGyro = nil, nil
end)

-- ジャンプの2回押しを見分ける（押しっぱなしは1回と数える。スマホのジャンプボタンでもOK）
local lastJumpSignal = 0
local lastJumpPress = 0
UserInputService.JumpRequest:Connect(function()
	local t = os.clock()
	local isNewPress = t - lastJumpSignal > 0.12
	lastJumpSignal = t
	if not isNewPress then
		return
	end
	if t - lastJumpPress < 0.35 then
		lastJumpPress = 0
		toggleFly()
	else
		lastJumpPress = t
	end
end)

RunService.RenderStepped:Connect(function()
	if not flying or not flyVel or not flyVel.Parent then
		if flying then
			stopFly()
		end
		return
	end
	local cam = workspace.CurrentCamera
	local move = controls and controls:GetMoveVector() or Vector3.zero
	local dir = cam.CFrame:VectorToWorldSpace(move)
	if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
		dir += Vector3.new(0, 1, 0)
	elseif UserInputService:IsKeyDown(Enum.KeyCode.Q) then
		dir -= Vector3.new(0, 1, 0)
	end
	if dir.Magnitude > 1 then
		dir = dir.Unit
	end
	flyVel.Velocity = dir * FLY_SPEED
	local look = cam.CFrame.LookVector * Vector3.new(1, 0, 1)
	if look.Magnitude > 0.01 then
		local pos = flyGyro.Parent.Position
		flyGyro.CFrame = CFrame.lookAt(pos, pos + look)
	end
end)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.F then
		remotes.Shove:FireServer()
	elseif input.KeyCode == Enum.KeyCode.G then
		remotes.DropItem:FireServer()
	end
end)

local noticeId = 0
remotes.Notify.OnClientEvent:Connect(function(text)
	noticeId += 1
	local myId = noticeId
	notice.Text = text
	notice.TextTransparency = 0
	notice.BackgroundTransparency = 0.3
	task.delay(2.5, function()
		if myId == noticeId then
			local info = TweenInfo.new(0.5)
			TweenService:Create(notice, info, { TextTransparency = 1, BackgroundTransparency = 1 }):Play()
		end
	end)
end)

--------------------------------------------------------------------------
-- 自分の卵は「開ける」、自分の生き物は「売る」、他人のものは「盗む」と表示する
--------------------------------------------------------------------------
local stealPrompts = {}
local function track(obj)
	if obj:IsA("ProximityPrompt") and obj:GetAttribute("StealPrompt") then
		table.insert(stealPrompts, obj)
	end
end
task.spawn(function()
	local map = workspace:WaitForChild("EggMap")
	for _, d in ipairs(map:GetDescendants()) do
		track(d)
	end
	map.DescendantAdded:Connect(track)
end)

--------------------------------------------------------------------------
-- 表示の更新
--------------------------------------------------------------------------
while true do
	local leaderstats = player:FindFirstChild("leaderstats")
	local cash = leaderstats and leaderstats:FindFirstChild("お金")
	local money = cash and cash.Value or 0
	cashLabel.Text = "$" .. formatNumber(money)

	local slots = player:GetAttribute("Slots") or Config.StartSlots
	if slots >= Config.MaxSlots then
		slotButton.Text = "台 MAX"
	else
		slotButton.Text = "台を増やす " .. slots .. "/" .. Config.MaxSlots .. "\n$" .. formatNumber(Config.SlotCost(slots))
	end

	local level = player:GetAttribute("SpeedLevel") or 0
	if level >= Config.MaxSpeedLevel then
		speedButton.Text = "スピード MAX"
	else
		speedButton.Text = "スピードUP Lv" .. level .. "\n$" .. formatNumber(Config.SpeedCost(level))
	end

	local t = workspace:GetServerTimeNow()
	local lockedUntil = player:GetAttribute("LockedUntil") or 0
	local cooldownEnd = player:GetAttribute("LockCooldownEnd") or 0
	if t < lockedUntil then
		lockButton.Text = "ロック中 " .. math.ceil(lockedUntil - t) .. "秒"
	elseif t < cooldownEnd then
		lockButton.Text = "ロック準備中 " .. math.ceil(cooldownEnd - t) .. "秒"
	else
		lockButton.Text = "ベースをロック\n(" .. Config.LockDuration .. "秒)"
	end

	for _, prompt in ipairs(stealPrompts) do
		if prompt:GetAttribute("OwnerUserId") ~= player.UserId then
			prompt.ActionText = "盗む"
		elseif prompt:GetAttribute("ItemKind") == "egg" then
			prompt.ActionText = "開ける"
		else
			prompt.ActionText = "売る"
		end
	end

	dropButton.Visible = player:GetAttribute("Carrying") ~= nil

	task.wait(0.2)
end
