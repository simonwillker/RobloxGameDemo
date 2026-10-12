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
cashLabel.Size = UDim2.fromOffset(160, 34)
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
codeFrame.Position = UDim2.new(0, 16, 1, -56)
codeFrame.Size = UDim2.fromOffset(160, 28)
codeFrame.BackgroundTransparency = 1
codeFrame.Parent = gui

local codeBox = Instance.new("TextBox")
codeBox.Size = UDim2.new(1, -54, 1, 0)
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
codeButton.Size = UDim2.new(0, 50, 1, 0)
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
panel.Size = UDim2.fromOffset(130, 200)
panel.BackgroundTransparency = 1
panel.Parent = gui
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 5)
layout.Parent = panel

local function makeButton(color)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, 0, 0, 36)
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
	pad.PaddingTop = UDim.new(0, 3)
	pad.PaddingBottom = UDim.new(0, 3)
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
panel.Size = UDim2.fromOffset(130, 210)

local notice = Instance.new("TextLabel")
notice.AnchorPoint = Vector2.new(0.5, 0)
notice.Position = UDim2.new(0.5, 0, 0, 70)
notice.Size = UDim2.fromOffset(400, 34)
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
-- マイクラのクリエイティブ飛行と同じ操作：
-- スティック（WASD）で水平に360度動く（カメラを上下に向けても高さは変わらない）。
-- ジャンプ長押しで上昇、しゃがむ（Ctrl か Q / スマホは「しゃがむ」ボタン長押し）で下降。
-- 体は進む方向へ360度傾く（前のめり・反り返り・横倒し）。後ろへ進んでも振り向かない。
--------------------------------------------------------------------------
local FLY_SPEED = 16 * 12 -- 歩く速さ(16)の12倍
local FLY_SMOOTH = 5 -- 大きいほどすぐ最高速になる（なめらかさ）
local TURN_SMOOTH = 10 -- 体の向きを変える速さ
local MAX_TILT = math.rad(60) -- 体を傾ける最大の角度
local flying = false
local flyVel, flyGyro
local facing = Vector3.new(0, 0, -1)
local controls = nil
task.spawn(function()
	local ok, playerModule = pcall(function()
		return require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"))
	end)
	if ok and playerModule then
		controls = playerModule:GetControls()
	else
		warn("[卵どろぼう] PlayerModule が読めません。キーボードと歩く向きで飛びます")
	end
end)

-- スマホ用「しゃがむ」ボタン（飛んでいる間だけ、ジャンプボタンの左に出る）
local crouchHeld = false
local crouchButton = Instance.new("TextButton")
crouchButton.AnchorPoint = Vector2.new(1, 1)
crouchButton.Position = UDim2.new(1, -180, 1, -30)
crouchButton.Size = UDim2.fromOffset(56, 56)
crouchButton.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
crouchButton.BackgroundTransparency = 0.4
crouchButton.Font = Enum.Font.GothamBold
crouchButton.TextScaled = true
crouchButton.TextColor3 = Color3.new(1, 1, 1)
crouchButton.Text = "しゃがむ"
crouchButton.Visible = false
crouchButton.Parent = gui
Instance.new("UICorner", crouchButton).CornerRadius = UDim.new(1, 0)
crouchButton.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
		crouchHeld = true
	end
end)
crouchButton.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
		crouchHeld = false
	end
end)

-- スマホ用「飛ぶスティック」（飛んでいる間だけ左下に出る。指で押して動かした方向へ進む）
local STICK_SIZE = 120
local stickTouch = nil
local stickMove = Vector3.zero
local stickBase = Instance.new("TextButton")
stickBase.Text = ""
stickBase.AutoButtonColor = false
stickBase.AnchorPoint = Vector2.new(0, 1)
stickBase.Position = UDim2.new(0, 40, 1, -40)
stickBase.Size = UDim2.fromOffset(STICK_SIZE, STICK_SIZE)
stickBase.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
stickBase.BackgroundTransparency = 0.7
stickBase.Visible = false
stickBase.Parent = gui
Instance.new("UICorner", stickBase).CornerRadius = UDim.new(1, 0)
local stickKnob = Instance.new("Frame")
stickKnob.AnchorPoint = Vector2.new(0.5, 0.5)
stickKnob.Position = UDim2.fromScale(0.5, 0.5)
stickKnob.Size = UDim2.fromOffset(50, 50)
stickKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
stickKnob.BackgroundTransparency = 0.2
stickKnob.Parent = stickBase
Instance.new("UICorner", stickKnob).CornerRadius = UDim.new(1, 0)
local function resetStick()
	stickTouch = nil
	stickMove = Vector3.zero
	stickKnob.Position = UDim2.fromScale(0.5, 0.5)
end
stickBase.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
		stickTouch = input
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input == stickTouch then
		resetStick()
	end
end)
local function updateStick()
	if not stickTouch then
		return
	end
	local center = stickBase.AbsolutePosition + stickBase.AbsoluteSize / 2
	local offset = Vector2.new(stickTouch.Position.X, stickTouch.Position.Y) - center
	local radius = STICK_SIZE / 2
	if offset.Magnitude > radius then
		offset = offset.Unit * radius
	end
	stickKnob.Position = UDim2.new(0.5, offset.X, 0.5, offset.Y)
	local v = offset / radius
	stickMove = v.Magnitude > 0.15 and Vector3.new(v.X, 0, v.Y) or Vector3.zero
end

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
	crouchButton.Visible = false
	crouchHeld = false
	stickBase.Visible = false
	resetStick()
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
	local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	facing = look.Magnitude > 0.01 and look.Unit or Vector3.new(0, 0, -1)
	hum.PlatformStand = true
	crouchButton.Visible = UserInputService.TouchEnabled
	stickBase.Visible = UserInputService.TouchEnabled
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
	crouchButton.Visible = false
	crouchHeld = false
	stickBase.Visible = false
	resetStick()
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

RunService.RenderStepped:Connect(function(dt)
	if not flying or not flyVel or not flyVel.Parent then
		if flying then
			stopFly()
		end
		return
	end
	local cam = workspace.CurrentCamera
	-- 移動の入力を読む（飛ぶスティック → いつものスティック → キーボード → キャラの歩く向き）
	updateStick()
	local move = stickMove
	if move.Magnitude < 0.05 and controls then
		local ok, v = pcall(function()
			return controls:GetMoveVector()
		end)
		if ok and typeof(v) == "Vector3" then
			move = v
		end
	end
	if move.Magnitude < 0.05 and not UserInputService:GetFocusedTextBox() then
		local kx, kz = 0, 0
		if UserInputService:IsKeyDown(Enum.KeyCode.W) or UserInputService:IsKeyDown(Enum.KeyCode.Up) then
			kz -= 1
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.S) or UserInputService:IsKeyDown(Enum.KeyCode.Down) then
			kz += 1
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.A) or UserInputService:IsKeyDown(Enum.KeyCode.Left) then
			kx -= 1
		end
		if UserInputService:IsKeyDown(Enum.KeyCode.D) or UserInputService:IsKeyDown(Enum.KeyCode.Right) then
			kx += 1
		end
		move = Vector3.new(kx, 0, kz)
	end
	local worldMove = nil
	if move.Magnitude < 0.05 then
		local hum = flyVel.Parent.Parent and flyVel.Parent.Parent:FindFirstChildOfClass("Humanoid")
		if hum and hum.MoveDirection.Magnitude > 0.05 then
			worldMove = hum.MoveDirection * Vector3.new(1, 0, 1)
		end
	end
	-- カメラの向きを水平にして使う（歩くときと同じ。上下を向いても高さは変わらない）
	local forward = cam.CFrame.LookVector * Vector3.new(1, 0, 1)
	forward = forward.Magnitude > 0.01 and forward.Unit or Vector3.new(0, 0, -1)
	local right = Vector3.new(-forward.Z, 0, forward.X)
	local dir = worldMove or (right * move.X - forward * move.Z)
	if dir.Magnitude > 1 then
		dir = dir.Unit
	end
	-- ジャンプ長押しで上昇、しゃがむ（Ctrl / Q / ボタン）で下降。両方なら止まる
	local up = 0
	if UserInputService:IsKeyDown(Enum.KeyCode.Space) or os.clock() - lastJumpSignal < 0.15 then
		up += 1
	end
	if crouchHeld or UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.Q) then
		up -= 1
	end
	local target = dir * FLY_SPEED + Vector3.new(0, up * FLY_SPEED * 0.5, 0)
	-- だんだん加速・減速して、なめらかに動く
	flyVel.Velocity = flyVel.Velocity:Lerp(target, math.min(1, dt * FLY_SMOOTH))
	-- 体に直接も速さを入れて、確実に動かす
	flyVel.Parent.AssemblyLinearVelocity = flyVel.Velocity

	-- 体はカメラの前を向いたまま（後ろに進んでも振り向かない）、
	-- 進む方向へ体を傾ける：前へ進むと前のめり、後ろは反り返る、横は横に傾く、
	-- 上昇は上向き、下降は下向き。速さに合わせてなめらかに傾く
	facing = facing:Lerp(forward, math.min(1, dt * TURN_SMOOTH))
	facing = facing.Magnitude > 0.01 and facing.Unit or forward
	local pos = flyGyro.Parent.Position
	local base = CFrame.lookAt(pos, pos + facing)
	local localVel = base:VectorToObjectSpace(flyVel.Velocity) / FLY_SPEED
	local pitch = localVel.Z * MAX_TILT + localVel.Y * MAX_TILT * 0.6
	local roll = -localVel.X * MAX_TILT
	pitch = math.clamp(pitch, -MAX_TILT, MAX_TILT)
	flyGyro.CFrame = base * CFrame.Angles(pitch, 0, roll)
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
