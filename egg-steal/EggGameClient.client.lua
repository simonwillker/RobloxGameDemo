-- EggGameClient (LocalScript)
-- 置き場所: StarterPlayer > StarterPlayerScripts
-- 画面のボタン（台を増やす・スピードUP・ロック・押す）と通知を作ります。

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local MarketplaceService = game:GetService("MarketplaceService")

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
local minigunButton = makeButton(Color3.fromRGB(140, 60, 220))
panel.Size = UDim2.fromOffset(200, 400)

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

minigunButton.Activated:Connect(function()
	if player:GetAttribute("HasMinigun") then
		return
	end
	if Config.MinigunGamePassId == 0 then
		notice.Text = "ミニガンは準備中です（ゲームパス番号が未設定）"
		notice.TextTransparency = 0
		notice.BackgroundTransparency = 0.3
		task.delay(2.5, function()
			notice.TextTransparency = 1
			notice.BackgroundTransparency = 1
		end)
		return
	end
	MarketplaceService:PromptGamePassPurchase(player, Config.MinigunGamePassId)
end)

-- ミニガン：押している間、マウスの方向へ連射
local firing = false
local mouse = player:GetMouse()
local function watchTool(tool)
	if tool:IsA("Tool") and tool.Name == "ミニガン" then
		tool.Activated:Connect(function()
			firing = true
		end)
		tool.Deactivated:Connect(function()
			firing = false
		end)
		tool.Unequipped:Connect(function()
			firing = false
		end)
	end
end
local function watchCharacter(char)
	firing = false
	char.ChildAdded:Connect(watchTool)
end
if player.Character then
	watchCharacter(player.Character)
end
player.CharacterAdded:Connect(watchCharacter)
task.spawn(function()
	while true do
		if firing then
			remotes.MinigunFire:FireServer(mouse.Hit.Position)
		end
		task.wait(Config.MinigunFireInterval)
	end
end)

dropButton.Activated:Connect(function()
	remotes.DropItem:FireServer()
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
	if player:GetAttribute("HasMinigun") then
		minigunButton.Text = "ミニガン 所持中"
	else
		minigunButton.Text = "ミニガンを買う\nR$" .. Config.MinigunPrice
	end

	task.wait(0.2)
end
