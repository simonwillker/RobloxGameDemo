-- EggGameServer (Script)
-- 置き場所: ServerScriptService
-- マップ・ベース・卵・生き物・お金・どろぼう処理をすべてここで作ります。

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local Debris = game:GetService("Debris")
local CollectionService = game:GetService("CollectionService")

print("[卵どろぼう] サーバースクリプト起動")
local Config = require(ReplicatedStorage:WaitForChild("EggConfig"))
print("[卵どろぼう] EggConfig 読み込みOK")

local S = Config.BaseSize
local HALF = S / 2

--------------------------------------------------------------------------
-- RemoteEvents（クライアントとの通信）
--------------------------------------------------------------------------
local remotes = ReplicatedStorage:FindFirstChild("EggRemotes")
if remotes then
	remotes:Destroy()
end
remotes = Instance.new("Folder")
remotes.Name = "EggRemotes"
remotes.Parent = ReplicatedStorage

local function makeRemote(name)
	local r = Instance.new("RemoteEvent")
	r.Name = name
	r.Parent = remotes
	return r
end

local BuyUpgrade = makeRemote("BuyUpgrade")
local LockBase = makeRemote("LockBase")
local Shove = makeRemote("Shove")
local Notify = makeRemote("Notify")
local DropItem = makeRemote("DropItem")
local RedeemCode = makeRemote("RedeemCode")

local function notify(player, text)
	if player and player.Parent then
		Notify:FireClient(player, text)
	end
end

local function now()
	return workspace:GetServerTimeNow()
end

--------------------------------------------------------------------------
-- アイテム（卵 / 生き物）
-- item = { k = "egg", r = レア度, s = 柄の番号 }  または  { k = "pet", r = レア度, s = 種類の番号 }
--------------------------------------------------------------------------
local EGG_PATTERNS = { "sprinkle", "stripes", "dots", "band", "tiara" }

local function eggStyleCount(r)
	return #EGG_PATTERNS * #Config.Rarities[r].Palettes
end

local function itemInfo(item)
	local rar = Config.Rarities[item.r]
	if item.k == "pet" then
		local sp = Config.Species[item.r][item.s]
		return sp.Name, sp.Income
	end
	return rar.Name .. "の卵", rar.Income
end

local function validItem(v)
	if type(v) == "number" and Config.Rarities[v] then
		return { k = "egg", r = v, s = 1 } -- 古いセーブデータ用
	end
	if type(v) ~= "table" or not Config.Rarities[v.r] or type(v.s) ~= "number" then
		return nil
	end
	if v.k == "egg" and v.s >= 1 and v.s <= eggStyleCount(v.r) then
		return { k = "egg", r = v.r, s = v.s }
	end
	if v.k == "pet" and Config.Species[v.r] and Config.Species[v.r][v.s] then
		return { k = "pet", r = v.r, s = v.s }
	end
	return nil
end

--------------------------------------------------------------------------
-- セーブデータ
--------------------------------------------------------------------------
local store = nil
if Config.UseDataStore then
	local ok, ds = pcall(function()
		return DataStoreService:GetDataStore("EggStealData_v2")
	end)
	if ok then
		store = ds
	end
end

local function loadData(player)
	if not store then
		return nil
	end
	local ok, data = pcall(function()
		return store:GetAsync("p_" .. player.UserId)
	end)
	if ok then
		return data
	end
	warn("セーブデータを読み込めませんでした: " .. tostring(data))
	return nil
end

local function saveData(player, st)
	if not store then
		return
	end
	local items = {}
	for i = 1, Config.MaxSlots do
		items[i] = st.items[i] or 0
	end
	local index = {}
	for key in pairs(st.index or {}) do
		table.insert(index, key)
	end
	local data = {
		cash = st.cash,
		slots = st.slots,
		speedLevel = st.speedLevel,
		eggs = items,
		index = index,
		usedCodes = st.usedCodes or {},
		cage = st.cage or {},
	}
	local ok, err = pcall(function()
		store:SetAsync("p_" .. player.UserId, data)
	end)
	if not ok then
		warn("セーブできませんでした: " .. tostring(err))
	end
end

--------------------------------------------------------------------------
-- 便利関数
--------------------------------------------------------------------------
local function makePart(props, className)
	local p = Instance.new(className or "Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props.Shape then
		p.Shape = props.Shape -- 形を先に決めてからサイズを入れる
	end
	for k, v in pairs(props) do
		if k ~= "Shape" and k ~= "Parent" then
			p[k] = v
		end
	end
	p.Parent = props.Parent
	return p
end

local function makeLabel(parent, text, color, size, offsetY, maxDistance)
	local bb = Instance.new("BillboardGui")
	bb.Size = size
	bb.StudsOffset = Vector3.new(0, offsetY, 0)
	bb.MaxDistance = maxDistance
	bb.AlwaysOnTop = false
	bb.Parent = parent
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeTransparency = 0
	label.Text = text
	label.Parent = bb
	return label
end

local function formatNumber(n)
	if n >= 1e15 then
		return string.format("%.1fQa", n / 1e15)
	elseif n >= 1e12 then
		return string.format("%.1fT", n / 1e12)
	elseif n >= 1e9 then
		return string.format("%.1fB", n / 1e9)
	elseif n >= 1e6 then
		return string.format("%.1fM", n / 1e6)
	elseif n >= 1e3 then
		return string.format("%.1fK", n / 1e3)
	end
	return tostring(math.floor(n))
end

local function weightedPick(list)
	local total = 0
	for _, v in ipairs(list) do
		total += v.Weight
	end
	local n = math.random() * total
	for i, v in ipairs(list) do
		n -= v.Weight
		if n <= 0 then
			return i
		end
	end
	return 1
end

--------------------------------------------------------------------------
-- 見た目づくり（外部アセットなし。すべて Part の組み合わせ）
--------------------------------------------------------------------------
local SMOOTH = Enum.Material.SmoothPlastic
local NEON = Enum.Material.Neon
local WHITE = Color3.new(1, 1, 1)
local DARK = Color3.fromRGB(25, 25, 30)

local function deco(model, props, className)
	props.CanCollide = false
	props.Parent = model
	return makePart(props, className)
end

local function ball(model, d, pos, color, mat)
	return deco(model, { Shape = Enum.PartType.Ball, Size = Vector3.new(d, d, d), Position = pos, Color = color, Material = mat or SMOOTH })
end

local function ellipsoid(model, size, cf, color, mat)
	local p = deco(model, { Size = size, CFrame = cf, Color = color, Material = mat or SMOOTH })
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

local function block(model, size, cf, color, mat)
	return deco(model, { Size = size, CFrame = cf, Color = color, Material = mat or SMOOTH })
end

-- 縦向きの円柱（length = 高さ）
local function vcyl(model, length, diameter, cf, color, mat)
	return deco(model, {
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(length, diameter, diameter),
		CFrame = cf * CFrame.Angles(0, 0, math.pi / 2),
		Color = color,
		Material = mat or SMOOTH,
	})
end

-- 虹色に光るパーツ（下の虹色ループが色を変え続ける）
local RAINBOW_TAG = "EggRainbow"
local function makeRainbow(part, offset)
	part:SetAttribute("RainbowOffset", offset or math.random())
	CollectionService:AddTag(part, RAINBOW_TAG)
end
task.spawn(function()
	while true do
		local t = os.clock() * 0.25
		for _, part in ipairs(CollectionService:GetTagged(RAINBOW_TAG)) do
			if part:IsDescendantOf(workspace) then
				part.Color = Color3.fromHSV((t + (part:GetAttribute("RainbowOffset") or 0)) % 1, 0.75, 1)
			end
		end
		task.wait(0.1)
	end
end)

-- 虹色のオーラ（光る殻＋虹色の粒）
local function addRainbowAura(model, root, size, center)
	local aura = ellipsoid(model, size, center, Color3.new(1, 0, 0), NEON)
	aura.Transparency = 0.65
	aura.CastShadow = false
	makeRainbow(aura, 0)
	local att = Instance.new("Attachment")
	att.Parent = root
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 60, 60)),
		ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 200, 40)),
		ColorSequenceKeypoint.new(0.4, Color3.fromRGB(80, 255, 80)),
		ColorSequenceKeypoint.new(0.6, Color3.fromRGB(60, 200, 255)),
		ColorSequenceKeypoint.new(0.8, Color3.fromRGB(120, 80, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 80, 220)),
	})
	e.LightEmission = 1
	e.Size = NumberSequence.new(0.5, 0)
	e.Speed = NumberRange.new(2, 5)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Lifetime = NumberRange.new(1, 2)
	e.Rate = 30
	e.Parent = att
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 120, 255)
	light.Range = 14
	light.Brightness = 3
	light.Parent = root
	return aura
end

-- 卵（中心が基準点）
local function buildEgg(r, s)
	local rar = Config.Rarities[r]
	local pattern = EGG_PATTERNS[(s - 1) % #EGG_PATTERNS + 1]
	local pal = rar.Palettes[math.floor((s - 1) / #EGG_PATTERNS) % #rar.Palettes + 1]
	local accentMat = r >= 5 and NEON or SMOOTH
	local model = Instance.new("Model")
	model.Name = "Egg"

	local root = ellipsoid(model, Vector3.new(2, 2.6, 2), CFrame.new(), pal.Main)
	root.Reflectance = 0.08

	local function surf(theta, h, out)
		local k = math.sqrt(math.max(0, 1 - (h / 1.3) ^ 2)) * (1 + (out or 0))
		return Vector3.new(math.cos(theta) * k, h, math.sin(theta) * k)
	end
	local function ring(h, thick, color, mat)
		local k = math.sqrt(math.max(0, 1 - (h / 1.3) ^ 2))
		vcyl(model, thick, 2 * k + 0.08, CFrame.new(0, h, 0), color, mat)
	end

	if pattern == "sprinkle" then
		local rng = Random.new(s * 7 + r)
		for _ = 1, 14 do
			ball(model, 0.22, surf(rng:NextNumber(0, math.pi * 2), rng:NextNumber(-1.0, 1.0)), pal.Accent, accentMat)
		end
	elseif pattern == "stripes" then
		ring(-0.55, 0.22, pal.Accent, accentMat)
		ring(0, 0.22, pal.Accent, accentMat)
		ring(0.55, 0.22, pal.Accent, accentMat)
	elseif pattern == "dots" then
		for k = 0, 3 do
			ball(model, 0.5, surf(k * math.pi / 2, -0.4), pal.Accent, accentMat)
			ball(model, 0.45, surf(k * math.pi / 2 + math.pi / 4, 0.45), pal.Accent, accentMat)
		end
	elseif pattern == "band" then
		ring(-0.1, 0.5, pal.Accent, accentMat)
		for k = 0, 3 do
			ball(model, 0.35, surf(k * math.pi / 2 + math.pi / 4, -0.1, 0.12), WHITE, NEON)
		end
	else -- tiara
		ring(0.75, 0.18, pal.Accent, accentMat)
		for k = 0, 4 do
			ball(model, 0.3, surf(k * math.pi * 2 / 5, 0.95, 0.05), pal.Accent, accentMat)
		end
		ball(model, 0.4, Vector3.new(0, 1.3, 0), pal.Accent, NEON)
	end

	-- つやのハイライト
	local gloss = ball(model, 0.45, surf(-math.pi / 2 - 0.5, 0.6, 0.02), WHITE)
	gloss.Transparency = 0.45

	if r >= 4 then
		local light = Instance.new("PointLight")
		light.Color = pal.Accent
		light.Range = 10
		light.Brightness = 2
		light.Parent = root
	end
	if r >= 5 then
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = pal.Accent
		sparkles.Parent = root
	end
	if rar.Rainbow then
		addRainbowAura(model, root, Vector3.new(2.8, 3.4, 2.8), CFrame.new())
	end
	if r >= Config.Rarity810 then
		-- 810以上は炎のオーラ
		local fire = Instance.new("Fire")
		fire.Color = pal.Accent
		fire.SecondaryColor = pal.Main
		fire.Size = 3
		fire.Heat = 3
		fire.Parent = root
	end

	model.WorldPivot = CFrame.new()
	return model, root, 2.4
end

-- 生き物（足元が基準点、正面は -Z）
local function buildCreature(r, s)
	local sp = Config.Species[r][s]
	local model = Instance.new("Model")
	model.Name = sp.Name
	local main, accent = sp.Color, sp.Accent
	local mat = sp.Material or SMOOTH
	local lift = sp.Lift or 0
	local feats = {}
	for _, f in ipairs(sp.Features) do
		feats[f] = true
	end
	local function P(x, y, z)
		return Vector3.new(x, y + lift, z)
	end
	local function CF(x, y, z)
		return CFrame.new(P(x, y, z))
	end

	local bodyParts = {}
	local root, d
	if sp.Body == "bean" then
		root = ellipsoid(model, Vector3.new(2.2, 2.6, 2.0), CF(0, 1.3, 0), main, mat)
		d = { cy = 1.3, top = 2.6, side = 1.1, back = 1.0, eyeY = 1.6, eyeZ = -0.9, headZ = 0 }
	elseif sp.Body == "block" then
		root = block(model, Vector3.new(2.4, 2, 2), CF(0, 1, 0), main, mat)
		d = { cy = 1, top = 2, side = 1.2, back = 1, eyeY = 1.3, eyeZ = -1.0, headZ = 0 }
	elseif sp.Body == "worm" then
		root = ball(model, 1.8, P(0, 0.9, -1.1), main, mat)
		table.insert(bodyParts, ball(model, 1.6, P(0, 0.8, 0.2), main, mat))
		table.insert(bodyParts, ball(model, 1.3, P(0, 0.65, 1.4), main, mat))
		d = { cy = 0.8, top = 1.8, side = 0.9, back = 2.05, eyeY = 1.1, eyeZ = -1.88, headZ = -1.1 }
	else -- ball
		root = ball(model, 2.2, P(0, 1.1, 0), main, mat)
		d = { cy = 1.1, top = 2.2, side = 1.1, back = 1.1, eyeY = 1.35, eyeZ = -1.0, headZ = 0 }
	end
	table.insert(bodyParts, root)
	if sp.Transparency then
		for _, p in ipairs(bodyParts) do
			p.Transparency = sp.Transparency
		end
	end
	local wingZ = sp.Body == "worm" and 0.2 or 0.1
	local glow = r >= 5 and NEON or SMOOTH

	-- 目
	for _, sx in ipairs({ -1, 1 }) do
		ball(model, 0.55, P(sx * 0.38, d.eyeY, d.eyeZ + 0.12), WHITE)
		ball(model, 0.3, P(sx * 0.38, d.eyeY, d.eyeZ - 0.1), DARK)
		ball(model, 0.1, P(sx * 0.38 + 0.07, d.eyeY + 0.07, d.eyeZ - 0.24), WHITE, NEON)
	end
	-- 口 / くちばし
	if feats.beak then
		block(model, Vector3.new(0.5, 0.35, 0.5), CF(0, d.eyeY - 0.4, d.eyeZ - 0.1) * CFrame.Angles(0, math.rad(45), 0), Color3.fromRGB(255, 160, 40))
	else
		block(model, Vector3.new(0.45, 0.1, 0.2), CF(0, d.eyeY - 0.45, d.eyeZ - 0.1), DARK)
	end

	for _, sx in ipairs({ -1, 1 }) do
		if feats.blush then
			ball(model, 0.35, P(sx * 0.65, d.eyeY - 0.3, d.eyeZ + 0.15), Color3.fromRGB(255, 140, 170))
		end
		if feats.wings then
			block(model, Vector3.new(0.2, 1.0, 1.4), CF(sx * (d.side + 0.05), d.cy + 0.1, wingZ) * CFrame.Angles(0, 0, -sx * math.rad(25)), accent)
		end
		if feats.bigWings then
			local w = block(model, Vector3.new(0.2, 2.4, 2.0), CF(sx * (d.side + 0.7), d.cy + 1.0, wingZ + 0.3) * CFrame.Angles(0, 0, -sx * math.rad(40)), accent, glow)
			w.Transparency = 0.1
		end
		if feats.feet then
			block(model, Vector3.new(0.5, 0.2, 0.7), CF(sx * 0.45, 0.1, -0.2), Color3.fromRGB(255, 160, 40))
		end
		if feats.legs then
			local zs = sp.Body == "worm" and { -1.1, 0.2, 1.4 } or { -0.6, 0.6 }
			for _, z in ipairs(zs) do
				vcyl(model, 0.7, 0.45, CF(sx * d.side * 0.75, 0.35, z), main:Lerp(Color3.new(0, 0, 0), 0.25), mat)
			end
		end
		if feats.ears then
			block(model, Vector3.new(0.6, 0.6, 0.25), CF(sx * 0.6, d.top - 0.05, d.headZ) * CFrame.Angles(0, 0, math.rad(45)), main, mat)
			block(model, Vector3.new(0.35, 0.35, 0.1), CF(sx * 0.6, d.top - 0.05, d.headZ - 0.14) * CFrame.Angles(0, 0, math.rad(45)), accent)
		end
		if feats.roundEars then
			ball(model, 0.75, P(sx * 0.7, d.top - 0.1, d.headZ), main, mat)
			ball(model, 0.4, P(sx * 0.7, d.top - 0.1, d.headZ - 0.22), accent)
		end
		if feats.longEars then
			local cf = CF(sx * 0.4, d.top + 0.65, d.headZ) * CFrame.Angles(0, 0, -sx * math.rad(12))
			ellipsoid(model, Vector3.new(0.5, 1.7, 0.35), cf, main, mat)
			ellipsoid(model, Vector3.new(0.25, 1.2, 0.1), cf * CFrame.new(0, 0, -0.15), accent)
		end
		if feats.antenna then
			vcyl(model, 0.9, 0.1, CF(sx * 0.35, d.top + 0.35, d.headZ) * CFrame.Angles(0, 0, -sx * math.rad(15)), DARK)
			ball(model, 0.35, P(sx * 0.47, d.top + 0.8, d.headZ), accent, NEON)
		end
		if feats.fins then
			block(model, Vector3.new(1.2, 0.2, 0.8), CF(sx * (d.side + 0.45), d.cy - 0.2, 0) * CFrame.Angles(0, 0, sx * math.rad(20)), accent)
		end
	end

	if feats.tail then
		ball(model, 0.8, P(0, d.cy - 0.2, d.back + 0.15), accent)
	end
	-- ゾウ：大きな耳・長い鼻・きば
	if feats.elephant then
		for _, sx in ipairs({ -1, 1 }) do
			local earCF = CF(sx * (d.side + 0.15), d.eyeY + 0.1, d.headZ + 0.1) * CFrame.Angles(0, sx * math.rad(20), 0)
			ellipsoid(model, Vector3.new(0.25, 1.7, 1.5), earCF, main, mat)
			ellipsoid(model, Vector3.new(0.1, 1.2, 1.0), earCF * CFrame.new(-sx * 0.1, 0, 0), Color3.fromRGB(255, 170, 190))
			block(model, Vector3.new(0.15, 0.15, 0.6), CF(sx * 0.35, d.eyeY - 0.75, d.eyeZ - 0.15) * CFrame.Angles(math.rad(30), 0, 0), WHITE)
		end
		local trunk = {
			{ 0.5, d.eyeY - 0.5, d.eyeZ - 0.2 },
			{ 0.45, d.eyeY - 0.85, d.eyeZ - 0.35 },
			{ 0.4, d.eyeY - 1.15, d.eyeZ - 0.45 },
			{ 0.35, d.eyeY - 1.4, d.eyeZ - 0.6 },
		}
		for _, t in ipairs(trunk) do
			table.insert(bodyParts, ball(model, t[1], P(0, t[2], t[3]), main, mat))
		end
	end
	-- フクロウのお顔（目のまわりの白い丸）
	if feats.owlFace then
		ellipsoid(model, Vector3.new(1.7, 1.1, 0.3), CF(0, d.eyeY, d.eyeZ + 0.1), accent)
		for _, sx in ipairs({ -1, 1 }) do
			block(model, Vector3.new(0.5, 0.12, 0.12), CF(sx * 0.4, d.eyeY + 0.45, d.eyeZ + 0.05) * CFrame.Angles(0, 0, sx * math.rad(20)), DARK)
		end
	end
	-- いちご：つぶつぶとへたの葉っぱ
	if feats.strawberry then
		local rng = Random.new(810)
		for _ = 1, 26 do
			local theta = rng:NextNumber(0, math.pi * 2)
			-- 顔（正面）にはつけない
			if math.abs(((theta + math.pi / 2 + math.pi) % (math.pi * 2)) - math.pi) > 0.7 then
				local h = rng:NextNumber(-1.0, 1.0)
				local k = math.sqrt(math.max(0, 1 - (h / 1.3) ^ 2))
				ball(model, 0.18, P(math.cos(theta) * 1.1 * k, d.cy + h, math.sin(theta) * 1.0 * k), accent, NEON)
			end
		end
		local green = Color3.fromRGB(70, 190, 70)
		for k = 0, 5 do
			local a = k * math.pi / 3
			ellipsoid(model, Vector3.new(1.1, 0.15, 0.45), CF(math.cos(a) * 0.45, d.top + 0.02, d.headZ + math.sin(a) * 0.45) * CFrame.Angles(0, -a, math.rad(-15)), green)
		end
		vcyl(model, 0.5, 0.2, CF(0, d.top + 0.25, d.headZ), Color3.fromRGB(60, 140, 50))
	end
	if feats.horn then
		block(model, Vector3.new(0.35, 1.1, 0.35), CF(0, d.top + 0.35, d.headZ - 0.3) * CFrame.Angles(math.rad(-25), 0, 0), accent, glow)
	end
	if feats.spikes then
		for i = -1, 1 do
			local pos = sp.Body == "worm" and CF(0, 1.55, 0.3 + i * 0.6) or CF(0, d.top - 0.05, 0.2 + i * 0.55)
			block(model, Vector3.new(0.45, 0.45, 0.45), pos * CFrame.Angles(math.rad(45), 0, 0), accent, glow)
		end
	end
	if feats.crest then
		for k = -1, 1 do
			block(model, Vector3.new(0.15, 0.9, 0.4), CF(k * 0.25, d.top + 0.3, d.headZ) * CFrame.Angles(0, 0, -k * math.rad(20)), accent, NEON)
		end
	end
	if feats.leaf then
		vcyl(model, 0.3, 0.1, CF(0, d.top + 0.05, d.headZ), Color3.fromRGB(120, 80, 40))
		ellipsoid(model, Vector3.new(1.0, 0.2, 0.55), CF(0.35, d.top + 0.2, d.headZ) * CFrame.Angles(0, 0, math.rad(20)), Color3.fromRGB(110, 200, 90))
	end
	if feats.halo then
		local h = vcyl(model, 0.12, 1.5, CF(0, d.top + 0.7, d.headZ), Color3.fromRGB(255, 240, 150), NEON)
		h.Transparency = 0.2
	end
	if feats.crown then
		vcyl(model, 0.5, 1.1, CF(0, d.top + 0.15, d.headZ), Color3.fromRGB(255, 200, 40), Enum.Material.Metal)
		for k = 0, 3 do
			local a = k * math.pi / 2
			ball(model, 0.25, P(math.cos(a) * 0.55, d.top + 0.45, d.headZ + math.sin(a) * 0.55), accent, NEON)
		end
	end
	if feats.tentacles then
		for k = 0, 4 do
			local a = k * math.pi * 2 / 5
			vcyl(model, 1.2, 0.18, CF(math.cos(a) * 0.6, -0.4, math.sin(a) * 0.6), accent)
		end
	end
	if feats.stars then
		ball(model, 0.35, P(-1.7, d.cy + 0.9, 0), accent, NEON)
		ball(model, 0.3, P(1.6, d.cy + 0.4, 0.3), accent, NEON)
		ball(model, 0.25, P(0.4, d.top + 1.0, 0.6), accent, NEON)
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = accent
		sparkles.Parent = root
	end
	if feats.fire then
		local fire = Instance.new("Fire")
		fire.Color = accent
		fire.SecondaryColor = main
		fire.Size = 3
		fire.Heat = 4
		fire.Parent = root
	end
	if r >= 5 then
		local light = Instance.new("PointLight")
		light.Color = accent
		light.Range = 12
		light.Brightness = 2
		light.Parent = root
	end

	if sp.Rainbow then
		-- からだを虹色に＋虹色のオーラ
		for i, p in ipairs(bodyParts) do
			makeRainbow(p, i * 0.05)
		end
		addRainbowAura(model, root, Vector3.new(4, 4.4, 4), CF(0, d.cy, 0))
	end

	-- 名前ラベルの高さ（頭の上）
	local extra = (feats.longEars or feats.halo or feats.antenna or feats.bigWings) and 1.2 or 0
	local labelOffset = d.top + lift - root.Position.Y + 1.5 + extra

	model.WorldPivot = CFrame.new()
	local scale = sp.Scale or 1
	if scale ~= 1 then
		model:ScaleTo(scale)
	end
	return model, root, labelOffset * scale
end

local function buildItem(item)
	local model, root, labelOffset
	if item.k == "pet" then
		model, root, labelOffset = buildCreature(item.r, item.s)
	else
		model, root, labelOffset = buildEgg(item.r, item.s)
	end
	local name, income = itemInfo(item)
	makeLabel(root, name .. "\n+" .. formatNumber(income) .. "/秒", Config.Rarities[item.r].Color, UDim2.fromOffset(140, 44), labelOffset, 50)
	return model, root
end

-- groundCF = 地面（台の上など）の位置。卵は中心、生き物は足元を合わせる。
local function placeItem(model, item, groundCF)
	if item.k == "egg" then
		model:PivotTo(groundCF * CFrame.new(0, 1.3, 0))
	else
		model:PivotTo(groundCF)
	end
end

--------------------------------------------------------------------------
-- マップ作成
--------------------------------------------------------------------------
local old = workspace:FindFirstChild("EggMap")
if old then
	old:Destroy()
end
local map = Instance.new("Folder")
map.Name = "EggMap"
map.Parent = workspace

-- 地面を芝生にする
local GRASS_COLOR = Color3.fromRGB(90, 160, 80)
local baseplate = workspace:FindFirstChild("Baseplate")
if baseplate and baseplate:IsA("BasePart") then
	for _, child in ipairs(baseplate:GetChildren()) do
		if child:IsA("Texture") or child:IsA("Decal") then
			child:Destroy() -- 灰色のマス目模様を消す
		end
	end
	baseplate.Material = Enum.Material.Grass
	baseplate.Color = GRASS_COLOR
else
	makePart({
		Name = "Ground",
		Size = Vector3.new(420, 2, 420),
		Position = Vector3.new(0, -1, 0),
		Color = GRASS_COLOR,
		Material = Enum.Material.Grass,
		Parent = map,
	})
end

-- 中央の卵畑
makePart({
	Name = "EggField",
	Shape = Enum.PartType.Cylinder,
	Size = Vector3.new(1, Config.FieldRadius * 2 + 8, Config.FieldRadius * 2 + 8),
	CFrame = CFrame.new(0, 0.5, 0) * CFrame.Angles(0, 0, math.pi / 2),
	Color = Color3.fromRGB(230, 200, 140),
	Material = Enum.Material.Sand,
	Parent = map,
})
local fieldSign = makePart({
	Name = "FieldSign",
	Size = Vector3.new(1, 1, 1),
	Position = Vector3.new(0, 1, 0),
	Transparency = 1,
	CanCollide = false,
	Parent = map,
})
makeLabel(fieldSign, "卵畑", Color3.fromRGB(255, 240, 180), UDim2.fromOffset(200, 60), 14, 300)

local fieldFolder = Instance.new("Folder")
fieldFolder.Name = "FieldEggs"
fieldFolder.Parent = map

local baseColors = {
	Color3.fromRGB(230, 80, 80),
	Color3.fromRGB(80, 140, 240),
	Color3.fromRGB(90, 200, 110),
	Color3.fromRGB(240, 200, 60),
	Color3.fromRGB(170, 100, 230),
	Color3.fromRGB(240, 140, 60),
	Color3.fromRGB(70, 200, 210),
	Color3.fromRGB(240, 120, 190),
}

local states = {} -- [player] = プレイヤーの状態

--------------------------------------------------------------------------
-- インデックス（生き物図鑑）
-- 卵を開けて生まれた生き物（と、持っていた生き物）が登録される。
-- 全部そろうと、ごほうびのコード INDEX_REWARD_CODE が見られる。
--------------------------------------------------------------------------
local INDEX_REWARD_CODE = "2895sh21"
local INDEX_TOTAL = 0
for r, list in ipairs(Config.Species) do
	if not Config.Rarities[r].Limited then -- 限定（OG）は数えない
		INDEX_TOTAL += #list
	end
end

local function indexCount(st)
	local n = 0
	for _ in pairs(st.index) do
		n += 1
	end
	return n
end

local function isIndexComplete(st)
	return indexCount(st) >= INDEX_TOTAL
end

-- クライアントに見せる（"1_3,2_1,..." の形）
local function syncIndex(player, st)
	local keys = {}
	for key in pairs(st.index) do
		table.insert(keys, key)
	end
	player:SetAttribute("IndexData", table.concat(keys, ","))
	player:SetAttribute("IndexCode", isIndexComplete(st) and INDEX_REWARD_CODE or nil)
end

local function discover(player, st, item)
	if not item or item.k ~= "pet" or Config.Rarities[item.r].Limited then
		return
	end
	local key = item.r .. "_" .. item.s
	if st.index[key] then
		return
	end
	local wasComplete = isIndexComplete(st)
	st.index[key] = true
	syncIndex(player, st)
	if not wasComplete and isIndexComplete(st) then
		notify(player, "インデックスが全部そろった！ごほうびコード：" .. INDEX_REWARD_CODE)
	end
end
local bases = {}

-- 前方宣言
local startCarry
local refreshSlot
local hatchSlot
local moveToCage

-- 管理者 = ゲームの持ち主（グループのゲームならグループのオーナー）＋ EggConfig.AdminUserIds の人
local function isAdmin(player)
	for _, id in ipairs(Config.AdminUserIds) do
		if player.UserId == id then
			return true
		end
	end
	if game.CreatorType == Enum.CreatorType.User then
		return player.UserId == game.CreatorId
	end
	local ok, rank = pcall(function()
		return player:GetRankInGroup(game.CreatorId)
	end)
	return ok and rank == 255
end

local function onSlotPrompt(base, slot, player)
	local owner = base.owner
	local ownerState = owner and states[owner]
	local item = ownerState and ownerState.items[slot]
	local st = states[player]
	if not item or not st or base.busy[slot] then
		return
	end
	local name, income = itemInfo(item)

	if player == owner then
		if item.k == "egg" then
			hatchSlot(base, slot, player) -- 自分の卵 → 開ける
		else
			-- 自分の生き物 → 売る
			ownerState.items[slot] = nil
			refreshSlot(base, slot)
			local price = income * Config.SellMultiplier
			st.cash += price
			st.cashValue.Value = st.cash
			notify(player, name .. "を $" .. formatNumber(price) .. " で売った")
		end
		return
	end

	-- 他人のもの → 盗む
	if now() < base.lockedUntil then
		notify(player, "このベースはロック中！")
		return
	end
	if st.carrying then
		notify(player, "1個しか持てない！")
		return
	end
	ownerState.items[slot] = nil
	refreshSlot(base, slot)
	startCarry(player, item, { owner = owner, slot = slot })
	notify(player, name .. "を盗んだ！自分のベースへ運ぼう")
	notify(owner, player.DisplayName .. " に " .. name .. "を盗まれた！押して取り返そう [F]")
end

local function buildBase(index)
	local angle = (index - 1) / Config.MaxBases * math.pi * 2
	local center = Vector3.new(math.cos(angle) * Config.BaseRingRadius, 0, math.sin(angle) * Config.BaseRingRadius)
	local cf = CFrame.lookAt(center, Vector3.new(0, 0, 0)) -- 入口(-Z)が中央を向く
	local color = baseColors[(index - 1) % #baseColors + 1]

	local model = Instance.new("Model")
	model.Name = "Base" .. index
	model.Parent = map

	local base = {
		index = index,
		cf = cf,
		color = color,
		model = model,
		owner = nil,
		lockedUntil = 0,
		slotParts = {},
		slotModels = {},
		busy = {},
	}

	makePart({
		Name = "Floor",
		Size = Vector3.new(S, 1, S),
		CFrame = cf * CFrame.new(0, 0.5, 0),
		Color = Color3.fromRGB(200, 200, 200),
		Material = Enum.Material.Concrete,
		Parent = model,
	})

	local function wall(size, offset)
		return makePart({ Name = "Wall", Size = size, CFrame = cf * offset, Color = color, Parent = model })
	end
	-- 窓のある壁（横の長さ length、真ん中が wallCF。窓は windowCount 個、高さ4〜8の間）
	local function windowWall(length, wallCF, windowCount)
		local winW, winBottom, winTop = 6, 4, 8 -- 窓の幅・下の高さ・上の高さ（床からの高さ）
		local function piece(width, height, x, y)
			if width > 0.05 then
				makePart({ Name = "Wall", Size = Vector3.new(width, height, 1), CFrame = wallCF * CFrame.new(x, y - 6, 0), Color = color, Parent = model })
			end
		end
		piece(length, winBottom - 1, 0, (1 + winBottom) / 2) -- 窓の下
		piece(length, 11 - winTop, 0, (winTop + 11) / 2) -- 窓の上
		local gap = length / windowCount
		local left = -length / 2
		for w = 1, windowCount do
			local cx = -length / 2 + gap * (w - 0.5)
			piece(cx - winW / 2 - left, winTop - winBottom, (left + cx - winW / 2) / 2, (winBottom + winTop) / 2)
			left = cx + winW / 2
			-- ガラス
			makePart({
				Name = "Window",
				Size = Vector3.new(winW, winTop - winBottom, 0.3),
				CFrame = wallCF * CFrame.new(cx, (winBottom + winTop) / 2 - 6, 0),
				Color = Color3.fromRGB(170, 220, 255),
				Material = Enum.Material.Glass,
				Transparency = 0.5,
				Parent = model,
			})
			-- 窓わく（白）
			makePart({
				Name = "WindowSill",
				Size = Vector3.new(winW + 1, 0.4, 1.6),
				CFrame = wallCF * CFrame.new(cx, winBottom - 6 - 0.2, 0),
				Color = WHITE,
				Parent = model,
			})
			makePart({
				Name = "WindowBar",
				Size = Vector3.new(0.3, winTop - winBottom, 1.2),
				CFrame = wallCF * CFrame.new(cx, (winBottom + winTop) / 2 - 6, 0),
				Color = WHITE,
				Parent = model,
			})
		end
		piece(length / 2 - left, winTop - winBottom, (left + length / 2) / 2, (winBottom + winTop) / 2)
	end
	windowWall(S, cf * CFrame.new(0, 6, HALF), 3) -- 後ろの壁
	windowWall(S, cf * CFrame.new(-HALF, 6, 0) * CFrame.Angles(0, math.pi / 2, 0), 3) -- 左の壁
	windowWall(S, cf * CFrame.new(HALF, 6, 0) * CFrame.Angles(0, math.pi / 2, 0), 3) -- 右の壁
	local frontWidth = HALF - 6
	wall(Vector3.new(frontWidth, 10, 1), CFrame.new(-(6 + frontWidth / 2), 6, -HALF))
	wall(Vector3.new(frontWidth, 10, 1), CFrame.new(6 + frontWidth / 2, 6, -HALF))
	wall(Vector3.new(12, 3, 1), CFrame.new(0, 9.5, -HALF)) -- 入口の上

	-- 屋根（天井の板＋三角屋根）
	local roofColor = color:Lerp(Color3.new(0, 0, 0), 0.35)
	makePart({
		Name = "Ceiling",
		Size = Vector3.new(S + 2, 1, S + 2),
		CFrame = cf * CFrame.new(0, 11.5, 0),
		Color = Color3.fromRGB(235, 235, 235),
		Parent = model,
	})
	local pitch = math.rad(25)
	local slope = (HALF + 2) / math.cos(pitch)
	local rise = (HALF + 2) * math.tan(pitch)
	for _, side in ipairs({ -1, 1 }) do
		makePart({
			Name = "Roof",
			Size = Vector3.new(slope, 1, S + 4),
			CFrame = cf * CFrame.new(side * (HALF + 2) / 2, 12 + rise / 2, 0) * CFrame.Angles(0, 0, -side * pitch),
			Color = roofColor,
			Material = Enum.Material.Slate,
			Parent = model,
		})
	end
	-- 屋根の三角の部分（前と後ろ）
	for _, z in ipairs({ -HALF - 1, HALF + 1 }) do
		for _, side in ipairs({ -1, 1 }) do
			local wedge = makePart({
				Name = "Gable",
				Size = Vector3.new(1, rise, HALF + 1),
				Color = color,
				Parent = model,
			}, "WedgePart")
			-- 高い方を真ん中に向ける
			wedge.CFrame = cf * CFrame.new(side * (HALF + 1) / 2, 12 + rise / 2, z) * CFrame.Angles(0, -side * math.pi / 2, 0)
		end
	end

	-- ロック時に見える赤いバリア（通過はでき、侵入者はサーバーが外に出す）
	base.barrier = makePart({
		Name = "LockBarrier",
		Size = Vector3.new(12, 10, 0.5),
		CFrame = cf * CFrame.new(0, 6, -HALF),
		Color = Color3.fromRGB(255, 40, 40),
		Material = Enum.Material.ForceField,
		Transparency = 1,
		CanCollide = false,
		Parent = model,
	})

	local signAnchor = makePart({
		Name = "Sign",
		Size = Vector3.new(1, 1, 1),
		CFrame = cf * CFrame.new(0, 1, 0),
		Transparency = 1,
		CanCollide = false,
		Parent = model,
	})
	base.signLabel = makeLabel(signAnchor, "空きベース", WHITE, UDim2.fromOffset(260, 60), 16, 300)

	for i = 1, Config.MaxSlots do
		local row = math.floor((i - 1) / 5)
		local col = (i - 1) % 5
		local ped = makePart({
			Name = "Slot" .. i,
			Size = Vector3.new(4, 2, 4),
			CFrame = cf * CFrame.new(-16 + col * 8, 2, 6 + row * 8),
			Color = Color3.fromRGB(120, 120, 120),
			Material = Enum.Material.Marble,
			Transparency = 0.75,
			Parent = model,
		})
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "StealPrompt"
		prompt.ActionText = "盗む"
		prompt.HoldDuration = Config.StealHoldTime
		prompt.MaxActivationDistance = 8
		prompt.RequiresLineOfSight = false
		prompt.Enabled = false
		prompt:SetAttribute("StealPrompt", true)
		prompt:SetAttribute("OwnerUserId", 0)
		prompt:SetAttribute("ItemKind", "")
		prompt.Parent = ped
		prompt.Triggered:Connect(function(player)
			onSlotPrompt(base, i, player)
		end)
		-- 自分の生き物を檻に入れる（持ち主にだけ見える。R キー）
		local cagePrompt = Instance.new("ProximityPrompt")
		cagePrompt.Name = "CagePrompt"
		cagePrompt.ActionText = "檻に入れる"
		cagePrompt.KeyboardKeyCode = Enum.KeyCode.R
		cagePrompt.GamepadKeyCode = Enum.KeyCode.ButtonY
		cagePrompt.HoldDuration = 0.3
		cagePrompt.MaxActivationDistance = 8
		cagePrompt.RequiresLineOfSight = false
		cagePrompt.UIOffset = Vector2.new(0, 90)
		cagePrompt.Enabled = false
		cagePrompt:SetAttribute("CagePrompt", true)
		cagePrompt:SetAttribute("OwnerUserId", 0)
		cagePrompt.Parent = ped
		cagePrompt.Triggered:Connect(function(player)
			moveToCage(base, i, player)
		end)
		base.slotParts[i] = ped
	end

	-- ペット小屋（ベースの裏。屋根なしの大きい檻。入口はベース側のまんなか）
	local C = Config.CageSize
	local cageCF = cf * CFrame.new(0, 0, HALF + 8 + C / 2)
	base.cageCF = cageCF
	base.cagePets = {}
	base.cageModel = Instance.new("Model")
	base.cageModel.Name = "Cage"
	base.cageModel.Parent = model
	makePart({
		Name = "CageFloor",
		Size = Vector3.new(C, 1, C),
		CFrame = cageCF * CFrame.new(0, 0.5, 0),
		Color = Color3.fromRGB(110, 190, 90),
		Material = Enum.Material.Grass,
		Parent = model,
	})
	local barColor = Color3.fromRGB(70, 70, 80)
	local GATE = 8
	for _, side in ipairs({ "front", "back", "left", "right" }) do
		for k = 0, math.floor(C / 2.5) do
			local u = -C / 2 + k * 2.5
			if not (side == "front" and math.abs(u) < GATE / 2) then
				local x, z
				if side == "front" then
					x, z = u, -C / 2
				elseif side == "back" then
					x, z = u, C / 2
				elseif side == "left" then
					x, z = -C / 2, u
				else
					x, z = C / 2, u
				end
				makePart({ Name = "CageBar", Size = Vector3.new(0.4, 8, 0.4), CFrame = cageCF * CFrame.new(x, 5, z), Color = barColor, Material = Enum.Material.Metal, Parent = model })
			end
		end
	end
	-- 上の手すり（屋根はなし）
	for _, r in ipairs({
		{ Vector3.new(C, 0.5, 0.5), CFrame.new(0, 9, C / 2) },
		{ Vector3.new(0.5, 0.5, C), CFrame.new(-C / 2, 9, 0) },
		{ Vector3.new(0.5, 0.5, C), CFrame.new(C / 2, 9, 0) },
		{ Vector3.new((C - GATE) / 2, 0.5, 0.5), CFrame.new(-(GATE + C) / 4, 9, -C / 2) },
		{ Vector3.new((C - GATE) / 2, 0.5, 0.5), CFrame.new((GATE + C) / 4, 9, -C / 2) },
	}) do
		makePart({ Name = "CageRail", Size = r[1], CFrame = cageCF * r[2], Color = barColor, Material = Enum.Material.Metal, Parent = model })
	end
	local cageSign = makePart({
		Name = "CageSign",
		Size = Vector3.new(1, 1, 1),
		CFrame = cageCF * CFrame.new(0, 1, -C / 2),
		Transparency = 1,
		CanCollide = false,
		Parent = model,
	})
	base.cageLabel = makeLabel(cageSign, "ペット小屋", WHITE, UDim2.fromOffset(200, 40), 11, 200)

	return base
end

for i = 1, Config.MaxBases do
	bases[i] = buildBase(i)
end
print("[卵どろぼう] マップ作成OK")

local function insideBase(base, pos)
	local p = base.cf:PointToObjectSpace(pos)
	return math.abs(p.X) < HALF and math.abs(p.Z) < HALF and p.Y > -5 and p.Y < 30
end

local function slotTopCF(base, i)
	local ped = base.slotParts[i]
	return ped.CFrame * CFrame.new(0, ped.Size.Y / 2, 0)
end

function refreshSlot(base, i)
	local ped = base.slotParts[i]
	local st = base.owner and states[base.owner]
	local unlocked = st ~= nil and i <= st.slots
	ped.Transparency = unlocked and 0 or 0.75
	ped.Color = unlocked and base.color:Lerp(WHITE, 0.4) or Color3.fromRGB(120, 120, 120)

	if base.slotModels[i] then
		base.slotModels[i]:Destroy()
		base.slotModels[i] = nil
	end
	local item = st and st.items[i]
	if item then
		local model = buildItem(item)
		placeItem(model, item, slotTopCF(base, i))
		model.Parent = base.model
		base.slotModels[i] = model
	end
	local prompt = ped.StealPrompt
	prompt.Enabled = item ~= nil and not base.busy[i]
	prompt.ObjectText = item and (itemInfo(item)) or ""
	prompt:SetAttribute("ItemKind", item and item.k or "")
	ped.CagePrompt.Enabled = item ~= nil and item.k == "pet" and not base.busy[i]
end

--------------------------------------------------------------------------
-- ペット小屋（檻）：生き物が中を歩きまわる。檻の生き物もお金を生む。
-- 持ち主は E で台に戻せる。ほかの人は E 長押しで盗める（ロック中は盗めない）。
--------------------------------------------------------------------------
local onCagePrompt
local function refreshCage(base)
	for _, e in ipairs(base.cagePets) do
		e.model:Destroy()
	end
	base.cagePets = {}
	local st = base.owner and states[base.owner]
	if not st then
		base.cageLabel.Text = "ペット小屋"
		return
	end
	local half = Config.CageSize / 2 - 4
	for _, item in ipairs(st.cage) do
		local model, root = buildItem(item)
		local pos = Vector3.new(math.random() * 2 * half - half, 0, math.random() * 2 * half - half)
		local entry = { item = item, model = model, pos = pos, target = pos, yaw = math.random() * math.pi * 2, wait = math.random() * 2, phase = math.random() * 6 }
		placeItem(model, item, base.cageCF * CFrame.new(pos.X, 1, pos.Z) * CFrame.Angles(0, entry.yaw, 0))
		local sp = Config.Species[item.r][item.s]
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "StealPrompt"
		prompt.ActionText = "盗む"
		prompt.ObjectText = (itemInfo(item))
		prompt.HoldDuration = Config.StealHoldTime
		prompt.MaxActivationDistance = 8 + 2 * (sp.Scale or 1)
		prompt.RequiresLineOfSight = false
		prompt:SetAttribute("StealPrompt", true)
		prompt:SetAttribute("OwnerUserId", base.owner.UserId)
		prompt:SetAttribute("ItemKind", "pet")
		prompt:SetAttribute("Cage", true)
		prompt.Parent = root
		prompt.Triggered:Connect(function(player)
			onCagePrompt(base, item, player)
		end)
		model.Parent = base.cageModel
		table.insert(base.cagePets, entry)
	end
	base.cageLabel.Text = base.owner.DisplayName .. " のペット小屋 " .. #st.cage .. "/" .. Config.CageMax
end

local function freeSlot(st)
	for i = 1, st.slots do
		if st.items[i] == nil and not st.base.busy[i] then
			return i
		end
	end
	return nil
end

function moveToCage(base, slot, player)
	local st = states[player]
	if not st or base.owner ~= player or base.busy[slot] then
		return
	end
	local item = st.items[slot]
	if not item or item.k ~= "pet" then
		return
	end
	if #st.cage >= Config.CageMax then
		notify(player, "檻がいっぱい！（" .. Config.CageMax .. "匹まで）")
		return
	end
	st.items[slot] = nil
	table.insert(st.cage, item)
	refreshSlot(base, slot)
	refreshCage(base)
	notify(player, itemInfo(item) .. "を檻に入れた！")
end

function onCagePrompt(base, item, player)
	local owner = base.owner
	local ownerState = owner and states[owner]
	local st = states[player]
	if not ownerState or not st then
		return
	end
	local idx = table.find(ownerState.cage, item)
	if not idx then
		return
	end
	local name = itemInfo(item)
	if player == owner then
		-- 台に戻す
		local free = freeSlot(st)
		if not free then
			notify(player, "台がいっぱい！")
			return
		end
		table.remove(st.cage, idx)
		st.items[free] = item
		refreshSlot(base, free)
		refreshCage(base)
		notify(player, name .. "を台に戻した")
		return
	end
	if now() < base.lockedUntil then
		notify(player, "このベースはロック中！")
		return
	end
	if st.carrying then
		notify(player, "1個しか持てない！")
		return
	end
	table.remove(ownerState.cage, idx)
	refreshCage(base)
	startCarry(player, item, { owner = owner, cage = true })
	notify(player, name .. "を盗んだ！自分のベースへ運ぼう")
	notify(owner, player.DisplayName .. " に檻の " .. name .. "を盗まれた！押して取り返そう [F]")
end

-- 檻の生き物を歩かせる
task.spawn(function()
	local half = Config.CageSize / 2 - 4
	while true do
		local dt = task.wait(0.05)
		for _, base in ipairs(bases) do
			for _, e in ipairs(base.cagePets) do
				if e.model.Parent then
					local hop = 0
					if e.wait > 0 then
						e.wait -= dt
					else
						local d = e.target - e.pos
						if d.Magnitude < 0.3 then
							e.wait = 1 + math.random() * 3
							e.target = Vector3.new(math.random() * 2 * half - half, 0, math.random() * 2 * half - half)
						else
							e.pos += d.Unit * math.min(d.Magnitude, Config.CagePetSpeed * dt)
							e.yaw = math.atan2(-d.X, -d.Z)
							hop = math.abs(math.sin(os.clock() * 8 + e.phase)) * 0.4
						end
					end
					placeItem(e.model, e.item, base.cageCF * CFrame.new(e.pos.X, 1 + hop, e.pos.Z) * CFrame.Angles(0, e.yaw, 0))
				end
			end
		end
	end
end)

local function refreshBase(base)
	for i = 1, Config.MaxSlots do
		refreshSlot(base, i)
	end
	base.signLabel.Text = base.owner and (base.owner.DisplayName .. " のベース") or "空きベース"
	local ownerId = base.owner and base.owner.UserId or 0
	for _, ped in ipairs(base.slotParts) do
		ped.StealPrompt:SetAttribute("OwnerUserId", ownerId)
		ped.CagePrompt:SetAttribute("OwnerUserId", ownerId)
	end
	refreshCage(base)
end

--------------------------------------------------------------------------
-- 卵を開ける（孵化）
--------------------------------------------------------------------------
function hatchSlot(base, slot, player)
	local st = states[player]
	local item = st.items[slot]
	local model = base.slotModels[slot]
	if not model then
		return
	end
	base.busy[slot] = true
	base.slotParts[slot].StealPrompt.Enabled = false
	local rar = Config.Rarities[item.r]

	-- ぶるぶる揺れる
	local origin = model:GetPivot()
	for i = 1, 10 do
		if not model.Parent then
			break
		end
		local a = math.rad((i % 2 == 0 and 1 or -1) * (6 + i * 1.5))
		model:PivotTo(origin * CFrame.Angles(0, 0, a))
		task.wait(0.07)
	end
	-- 途中でプレイヤーが抜けたら中止
	if base.owner ~= player or st.items[slot] ~= item then
		base.busy[slot] = nil
		return
	end
	model:PivotTo(origin)

	-- 光ってから割れる
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Material = NEON
			p.Color = WHITE
		end
	end
	task.wait(0.15)
	local center = origin.Position
	local shellColor = rar.Palettes[math.floor((item.s - 1) / #EGG_PATTERNS) % #rar.Palettes + 1].Main
	model:Destroy()
	base.slotModels[slot] = nil

	-- 殻のかけら
	for _ = 1, 8 do
		local shell = makePart({
			Size = Vector3.new(0.6, 0.15, 0.5),
			CFrame = CFrame.new(center) * CFrame.Angles(math.random() * 6, math.random() * 6, 0),
			Color = shellColor,
			Anchored = false,
			Parent = workspace,
		})
		shell.AssemblyLinearVelocity = Vector3.new(math.random(-12, 12), math.random(15, 25), math.random(-12, 12))
		Debris:AddItem(shell, 2)
	end
	-- キラキラ
	local burst = makePart({ Size = Vector3.new(1, 1, 1), Position = center, Transparency = 1, CanCollide = false, Parent = workspace })
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(rar.Color)
	emitter.LightEmission = 1
	emitter.Speed = NumberRange.new(8, 16)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Lifetime = NumberRange.new(0.6, 1.2)
	emitter.Size = NumberSequence.new(0.6, 0)
	emitter.Rate = 0
	emitter.Parent = burst
	emitter:Emit(40)
	Debris:AddItem(burst, 2)

	-- 生き物の誕生
	local speciesIndex = weightedPick(Config.Species[item.r])
	local pet = { k = "pet", r = item.r, s = speciesIndex }
	st.items[slot] = pet
	base.busy[slot] = nil
	refreshSlot(base, slot)

	-- ポンッと大きくなる
	local petModel = base.slotModels[slot]
	if petModel then
		local target = petModel:GetScale()
		for _, f in ipairs({ 0.2, 0.5, 0.85, 1.15, 1 }) do
			if petModel.Parent then
				petModel:ScaleTo(target * f)
			end
			task.wait(0.05)
		end
	end
	local name, income = itemInfo(pet)
	notify(player, rar.Name .. "の卵から " .. name .. " が生まれた！ +" .. formatNumber(income) .. "/秒")
	discover(player, st, pet)
end

--------------------------------------------------------------------------
-- 卵畑 / 落ちているアイテム
--------------------------------------------------------------------------
local function groundBelow(pos)
	local params = RaycastParams.new()
	local exclude = { fieldFolder }
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then
			table.insert(exclude, p.Character)
		end
	end
	params.FilterDescendantsInstances = exclude
	params.FilterType = Enum.RaycastFilterType.Exclude
	local hit = workspace:Raycast(pos + Vector3.new(0, 3, 0), Vector3.new(0, -60, 0), params)
	return hit and hit.Position or nil
end

local function spawnFieldItem(item, groundPos, scale)
	if not groundPos then
		local a = math.random() * math.pi * 2
		local d = math.sqrt(math.random()) * Config.FieldRadius
		groundPos = Vector3.new(math.cos(a) * d, 1, math.sin(a) * d)
	end
	local model, root = buildItem(item)
	placeItem(model, item, CFrame.new(groundPos) * CFrame.Angles(0, math.random() * math.pi * 2, 0))
	if scale and scale ~= 1 then
		-- 大きくする（地面にうまるので、そのぶん持ち上げる）
		model:ScaleTo(model:GetScale() * scale)
		placeItem(model, item, CFrame.new(groundPos + Vector3.new(0, 1.3 * (scale - 1), 0)))
		for _, bb in ipairs(model:GetDescendants()) do
			if bb:IsA("BillboardGui") then
				bb.StudsOffset *= scale
				bb.MaxDistance = 300
			end
		end
	end

	local name = itemInfo(item)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "拾う"
	prompt.ObjectText = name
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10 + 1.5 * (scale or 1)
	prompt.RequiresLineOfSight = false
	prompt.Parent = root
	prompt.Triggered:Connect(function(player)
		local st = states[player]
		if not model.Parent or not st then
			return
		end
		if st.carrying then
			notify(player, "1個しか持てない！")
			return
		end
		model:Destroy()
		startCarry(player, item, nil)
		notify(player, name .. "をゲット！自分のベースへ運ぼう")
	end)
	model.Parent = fieldFolder
	return model
end

-- 今の天気イベントの効果（イベントがないときはすべて1）
local weather = { incomeMult = 1, spawnMult = 1, rareBoost = 1 }

-- 810の卵（いちばんレアな卵）は、卵畑には1日に1個だけ出る（日本時間の0時でリセット）。
-- セーブが使えるときは全サーバー合わせて1日1個、使えないときはサーバーごとに1日1個。
-- 管理者のコード「114514810」はこの制限と関係なく使える。
local TOP_RARITY = Config.Rarity810
local globalStore = nil
if Config.UseDataStore then
	local ok, ds = pcall(function()
		return DataStoreService:GetDataStore("EggStealGlobal_v1")
	end)
	if ok then
		globalStore = ds
	end
end
local localTopDay = nil
local function todayJST()
	return math.floor((os.time() + 9 * 3600) / 86400)
end
local function claimTopEggToday()
	local day = todayJST()
	if localTopDay == day then
		return false
	end
	if globalStore then
		local claimed = false
		local ok = pcall(function()
			globalStore:UpdateAsync("Egg810Day", function(old)
				if old == day then
					claimed = false
					return nil -- 今日はもう出た
				end
				claimed = true
				return day
			end)
		end)
		if ok then
			if claimed then
				localTopDay = day
			end
			return claimed
		end
	end
	localTopDay = day
	return true
end

local function pickFieldRarity()
	local list = Config.Rarities
	if weather.rareBoost > 1 then
		-- 太陽イベント：レア以上が出やすい
		list = {}
		for i, v in ipairs(Config.Rarities) do
			list[i] = { Weight = i >= 3 and v.Weight * weather.rareBoost or v.Weight }
		end
	end
	local r = weightedPick(list)
	if r == TOP_RARITY and not claimTopEggToday() then
		-- 今日の810はもう出たので、810以外から選び直す
		local others = {}
		for i = 1, TOP_RARITY - 1 do
			others[i] = list[i]
		end
		r = weightedPick(others)
	end
	return r
end

task.spawn(function()
	while true do
		if #fieldFolder:GetChildren() < Config.FieldEggCount * weather.spawnMult then
			local r = pickFieldRarity()
			spawnFieldItem({ k = "egg", r = r, s = math.random(1, eggStyleCount(r)) })
		end
		task.wait(Config.EggSpawnInterval / weather.spawnMult)
	end
end)

--------------------------------------------------------------------------
-- 運ぶ
--------------------------------------------------------------------------
local function getHumanoid(player)
	local char = player.Character
	return char and char:FindFirstChildOfClass("Humanoid")
end

local function getRoot(player)
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart")
end

local function updateSpeed(player)
	local st = states[player]
	local hum = getHumanoid(player)
	if not st or not hum then
		return
	end
	if now() < st.stunnedUntil then
		hum.WalkSpeed = 0
		return
	end
	local speed = Config.BaseWalkSpeed + st.speedLevel * Config.SpeedPerLevel
	if st.carrying then
		speed *= Config.CarrySpeedMultiplier
	end
	hum.WalkSpeed = speed
end

function startCarry(player, item, from)
	local st = states[player]
	st.carrying = { item = item, from = from }
	local char = player.Character
	local head = char and char:FindFirstChild("Head")
	if head then
		local model, root = buildItem(item)
		if item.k == "pet" then
			-- 大きい生き物は頭の上で大きすぎないように小さくする
			local sp = Config.Species[item.r][item.s]
			model:ScaleTo(model:GetScale() * 0.7 * math.min(1, 1.6 / (sp.Scale or 1)))
		end
		placeItem(model, item, head.CFrame * CFrame.new(0, head.Size.Y / 2 + 0.1, 0))
		for _, p in ipairs(model:GetDescendants()) do
			if p:IsA("BasePart") then
				p.Massless = true
				p.CanCollide = false
				p.CanQuery = false
				p.CanTouch = false
				if p ~= root then
					local w = Instance.new("WeldConstraint")
					w.Part0 = root
					w.Part1 = p
					w.Parent = p
				end
			end
		end
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = head
		weld.Part1 = root
		weld.Parent = root
		model.Parent = char
		for _, p in ipairs(model:GetDescendants()) do
			if p:IsA("BasePart") then
				p.Anchored = false
			end
		end
		st.carryModel = model
	end
	player:SetAttribute("Carrying", item.k)
	updateSpeed(player)
end

local function stopCarry(player)
	local st = states[player]
	if st.carryModel then
		st.carryModel:Destroy()
		st.carryModel = nil
	end
	st.carrying = nil
	player:SetAttribute("Carrying", nil)
	updateSpeed(player)
end

-- 押された / 倒れた / 退出したときに落とす
-- byChoice = true のときは自分で落とした（その場の地面に置く）
local function dropCarry(player, byChoice)
	local st = states[player]
	local c = st and st.carrying
	if not c then
		return
	end
	local root = getRoot(player)
	local pos = root and root.Position
	if byChoice and root then
		pos = (root.CFrame * CFrame.new(0, 0, -3)).Position -- 少し前に置く
	end
	stopCarry(player)

	-- 押されて落としたときは、盗まれたものは持ち主の台に戻る
	local from = c.from
	if not byChoice and from and from.owner.Parent then
		local ownerState = states[from.owner]
		if ownerState and from.cage then
			if #ownerState.cage < Config.CageMax then
				table.insert(ownerState.cage, c.item)
				refreshCage(ownerState.base)
				notify(from.owner, itemInfo(c.item) .. "を取り返した！")
				return
			end
		elseif ownerState and ownerState.items[from.slot] == nil and from.slot <= ownerState.slots then
			ownerState.items[from.slot] = c.item
			refreshSlot(ownerState.base, from.slot)
			notify(from.owner, itemInfo(c.item) .. "を取り返した！")
			return
		end
	end
	spawnFieldItem(c.item, pos and groundBelow(pos) or nil)
end

--------------------------------------------------------------------------
-- プレイヤー参加 / 退出
--------------------------------------------------------------------------
local function onCharacterAdded(player, char)
	local st = states[player]
	if not st then
		return
	end
	st.carrying = nil
	st.carryModel = nil
	player:SetAttribute("Carrying", nil)
	local hum = char:WaitForChild("Humanoid")
	char:WaitForChild("HumanoidRootPart")
	task.wait(0.1)
	char:PivotTo(st.base.cf * CFrame.new(0, 4, -HALF + 6))
	updateSpeed(player)
	hum.Died:Connect(function()
		dropCarry(player)
	end)
end

local function onPlayerAdded(player)
	local base = nil
	for _, b in ipairs(bases) do
		if not b.owner then
			base = b
			break
		end
	end
	if not base then
		notify(player, "ベースが満員です")
		return
	end

	local data = loadData(player) or {}
	local st = {
		base = base,
		cash = tonumber(data.cash) or Config.StartCash,
		slots = math.clamp(tonumber(data.slots) or Config.StartSlots, Config.StartSlots, Config.MaxSlots),
		speedLevel = math.clamp(tonumber(data.speedLevel) or 0, 0, isAdmin(player) and math.huge or Config.MaxSpeedLevel),
		items = {},
		carrying = nil,
		carryModel = nil,
		lastShove = 0,
		stunnedUntil = 0,
		lockCooldownEnd = 0,
		index = {},
		usedCodes = {},
		cage = {},
	}
	if type(data.eggs) == "table" then
		for i = 1, st.slots do
			st.items[i] = validItem(data.eggs[i])
		end
	end
	if type(data.index) == "table" then
		for _, key in ipairs(data.index) do
			local r, sIdx = string.match(tostring(key), "^(%d+)_(%d+)$")
			r, sIdx = tonumber(r), tonumber(sIdx)
			if r and sIdx and Config.Species[r] and Config.Species[r][sIdx] and not Config.Rarities[r].Limited then
				st.index[key] = true
			end
		end
	end
	if type(data.usedCodes) == "table" then
		for k, v in pairs(data.usedCodes) do
			if v == true and type(k) == "string" then
				st.usedCodes[k] = true
			end
		end
	end
	if type(data.cage) == "table" then
		for _, v in ipairs(data.cage) do
			local it = validItem(v)
			if it and it.k == "pet" and #st.cage < Config.CageMax then
				table.insert(st.cage, it)
			end
		end
	end
	for _, it in ipairs(st.cage) do
		if not Config.Rarities[it.r].Limited then
			st.index[it.r .. "_" .. it.s] = true
		end
	end
	-- 台にいる生き物もインデックスに登録
	for i = 1, st.slots do
		local it = st.items[i]
		if it and it.k == "pet" and not Config.Rarities[it.r].Limited then
			st.index[it.r .. "_" .. it.s] = true
		end
	end
	syncIndex(player, st)

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player
	local cashValue = Instance.new("IntValue")
	cashValue.Name = "お金"
	cashValue.Value = st.cash
	cashValue.Parent = leaderstats
	st.cashValue = cashValue

	player:SetAttribute("Slots", st.slots)
	player:SetAttribute("SpeedLevel", st.speedLevel)
	player:SetAttribute("IsAdmin", isAdmin(player)) -- 管理者はスピードの上限なし
	player:SetAttribute("LockedUntil", 0)
	player:SetAttribute("LockCooldownEnd", 0)

	states[player] = st
	base.owner = player
	refreshBase(base)

	player.CharacterAdded:Connect(function(char)
		onCharacterAdded(player, char)
	end)
	player.CharacterRemoving:Connect(function()
		dropCarry(player)
	end)
	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end
	notify(player, "中央の卵畑から卵を持ち帰ろう！")
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, p)
end

Players.PlayerRemoving:Connect(function(player)
	local st = states[player]
	if not st then
		return
	end
	dropCarry(player)
	saveData(player, st)
	states[player] = nil
	st.base.owner = nil
	st.base.lockedUntil = 0
	st.base.busy = {}
	refreshBase(st.base)
end)

game:BindToClose(function()
	for player, st in pairs(states) do
		saveData(player, st)
	end
end)

--------------------------------------------------------------------------
-- ボタン操作（アップグレード / ロック / 押す）
--------------------------------------------------------------------------
BuyUpgrade.OnServerEvent:Connect(function(player, kind)
	local st = states[player]
	if not st then
		return
	end
	if kind == "Slot" then
		if st.slots >= Config.MaxSlots then
			return
		end
		local cost = Config.SlotCost(st.slots)
		if st.cash < cost then
			notify(player, "お金が足りない！")
			return
		end
		st.cash -= cost
		st.slots += 1
		player:SetAttribute("Slots", st.slots)
		refreshSlot(st.base, st.slots)
		notify(player, "台が増えた！")
	elseif kind == "Speed" then
		if st.speedLevel >= Config.MaxSpeedLevel and not isAdmin(player) then
			return
		end
		local cost = Config.SpeedCost(st.speedLevel)
		if st.cash < cost then
			notify(player, "お金が足りない！")
			return
		end
		st.cash -= cost
		st.speedLevel += 1
		player:SetAttribute("SpeedLevel", st.speedLevel)
		updateSpeed(player)
		notify(player, "足が速くなった！")
	end
	st.cashValue.Value = st.cash
end)

LockBase.OnServerEvent:Connect(function(player)
	local st = states[player]
	if not st then
		return
	end
	local t = now()
	if t < st.lockCooldownEnd then
		return
	end
	st.base.lockedUntil = t + Config.LockDuration
	st.lockCooldownEnd = t + Config.LockCooldown
	player:SetAttribute("LockedUntil", st.base.lockedUntil)
	player:SetAttribute("LockCooldownEnd", st.lockCooldownEnd)
	notify(player, "ベースを " .. Config.LockDuration .. " 秒ロックした！")
end)

-- コード入力（コードはサーバーだけに置くので、プレイヤーからは見えない）
-- 何回でも使える。卵は空いている台に置かれる。ADMIN_ONLY_CODES に入れたコードは管理者だけ。
-- 810の卵をわたす。わたせたら true
local function give810Egg(player, st)
	local r = Config.Rarity810
	local egg = { k = "egg", r = r, s = math.random(1, eggStyleCount(r)) }
	for i = 1, st.slots do
		if st.items[i] == nil and not st.base.busy[i] then
			st.items[i] = egg
			refreshSlot(st.base, i)
			return true, "コード成功！" .. Config.Rarities[r].Name .. "の卵を台に置いたよ"
		end
	end
	if not st.carrying then
		startCarry(player, egg, nil)
		return true, "コード成功！台がいっぱいなので、" .. Config.Rarities[r].Name .. "の卵を持たせたよ"
	end
	return false, "台がいっぱい！台を空けてからもう一度入力してね"
end

local CODES = {
	["114514810"] = function(player, st)
		local _, message = give810Egg(player, st)
		return message
	end,
	-- インデックスを全部そろえた人だけ、1人1回だけ使える
	[INDEX_REWARD_CODE] = function(player, st)
		if st.usedCodes[INDEX_REWARD_CODE] then
			return "このコードはもう使ったよ（1回だけ）"
		end
		if not isIndexComplete(st) then
			return "インデックスを全部そろえると使えるコードだよ（今 " .. indexCount(st) .. "/" .. INDEX_TOTAL .. "）"
		end
		local ok, message = give810Egg(player, st)
		if ok then
			st.usedCodes[INDEX_REWARD_CODE] = true
			task.spawn(saveData, player, st)
		end
		return message
	end,
	-- 飛べるようになる（この回のプレイ中ずっと）
	["うんこです"] = function(player, st)
		if player:GetAttribute("CanFly") then
			return "もう飛べるよ！ジャンプを2回押してね"
		end
		player:SetAttribute("CanFly", true)
		return "コード成功！ジャンプを2回押すと飛べる（もう一度2回押すと着地）"
	end,
	-- 毎秒の収入が2倍（この回のプレイ中ずっと。重ねがけはできない）
	["インムキング"] = function(player, st)
		if st.incomeMultiplier == 2 then
			return "もう収入2倍になっているよ"
		end
		st.incomeMultiplier = 2
		player:SetAttribute("IncomeBoost", 2)
		return "コード成功！毎秒の収入が2倍になった！"
	end,
}

-- 管理者だけが使えるコード
local ADMIN_ONLY_CODES = {
	["114514810"] = true,
	["うんこです"] = true,
}


RedeemCode.OnServerEvent:Connect(function(player, code)
	local st = states[player]
	if not st or type(code) ~= "string" then
		return
	end
	local t = now()
	if t - (st.lastCode or 0) < 1 then
		return -- 連打防止
	end
	st.lastCode = t
	local cleaned = string.gsub(string.gsub(code, "%s", ""), "　", "")
	local reward = CODES[cleaned] or CODES[string.lower(cleaned)]
	if reward and ADMIN_ONLY_CODES[cleaned] and not isAdmin(player) then
		notify(player, "このコードは管理者しか使えません")
		return
	end
	if reward then
		notify(player, reward(player, st))
	else
		notify(player, "そのコードは使えません")
	end
end)

DropItem.OnServerEvent:Connect(function(player)
	local st = states[player]
	if st and st.carrying then
		local name = itemInfo(st.carrying.item)
		dropCarry(player, true)
		notify(player, name .. "を落とした")
	end
end)

Shove.OnServerEvent:Connect(function(player)
	local st = states[player]
	local root = getRoot(player)
	if not st or not root then
		return
	end
	local t = now()
	if t - st.lastShove < Config.ShoveCooldown or t < st.stunnedUntil then
		return
	end
	st.lastShove = t

	local target, bestDist = nil, Config.ShoveRange
	for _, other in ipairs(Players:GetPlayers()) do
		local otherRoot = getRoot(other)
		local otherHum = getHumanoid(other)
		if other ~= player and otherRoot and otherHum and otherHum.Health > 0 and states[other] then
			local d = (otherRoot.Position - root.Position).Magnitude
			if d < bestDist then
				target, bestDist = other, d
			end
		end
	end
	if not target then
		return
	end

	local tst = states[target]
	local hadItem = tst.carrying ~= nil
	dropCarry(target)
	tst.stunnedUntil = t + Config.StunTime
	local hum = getHumanoid(target)
	if hum then
		hum.Sit = true
	end
	updateSpeed(target)
	task.delay(Config.StunTime, function()
		if target.Parent then
			updateSpeed(target)
		end
	end)
	notify(target, player.DisplayName .. " に押された！")
	if hadItem then
		notify(player, target.DisplayName .. " に落とさせた！")
	end
end)

--------------------------------------------------------------------------
-- メインループ
--------------------------------------------------------------------------
-- ベースに置く / ロック中の侵入者を外に出す（0.2秒ごと）
task.spawn(function()
	while true do
		task.wait(0.2)
		local t = now()
		for player, st in pairs(states) do
			local root = getRoot(player)
			if st.carrying and root and insideBase(st.base, root.Position) then
				local free = nil
				for i = 1, st.slots do
					if st.items[i] == nil and not st.base.busy[i] then
						free = i
						break
					end
				end
				if free then
					local item = st.carrying.item
					stopCarry(player)
					st.items[free] = item
					refreshSlot(st.base, free)
					if item.k == "egg" then
						notify(player, "卵を置いた！台でEを長押しすると開けられるよ")
					else
						notify(player, itemInfo(item) .. "を置いた！")
						discover(player, st, item)
					end
				elseif t - (st.fullWarned or 0) > 3 then
					st.fullWarned = t
					notify(player, "台がいっぱい！台を増やすか、生き物を売ろう")
				end
			end
		end
		for _, base in ipairs(bases) do
			local locked = base.owner ~= nil and t < base.lockedUntil
			base.barrier.Transparency = locked and 0.3 or 1
			if locked then
				for _, other in ipairs(Players:GetPlayers()) do
					local root = getRoot(other)
					if other ~= base.owner and root and insideBase(base, root.Position) then
						other.Character:PivotTo(base.cf * CFrame.new(0, 4, -HALF - 10))
						notify(other, "ロック中のベースには入れない！")
					end
				end
			end
		end
	end
end)

-- 収入（1秒ごと）
task.spawn(function()
	while true do
		task.wait(1)
		for _, st in pairs(states) do
			local income = 0
			for i = 1, st.slots do
				local item = st.items[i]
				if item then
					local _, inc = itemInfo(item)
					income += inc
				end
			end
			for _, item in ipairs(st.cage) do
				local _, inc = itemInfo(item)
				income += inc
			end
			income = math.floor(income * (st.incomeMultiplier or 1) * weather.incomeMult)
			if income > 0 then
				st.cash += income
				st.cashValue.Value = st.cash
			end
		end
	end
end)

-- 自動セーブ（60秒ごと）
task.spawn(function()
	while true do
		task.wait(60)
		for player, st in pairs(states) do
			task.spawn(saveData, player, st)
		end
	end
end)

--------------------------------------------------------------------------
-- 天気イベント（1時間に1回、5分間）
-- 雪：卵畑に卵がたくさん、速く出る      異変 → もっとたくさん
-- 雨：毎秒の収入が1.5倍                  異変 → 3倍
-- 雷：ときどき雷が落ち、近くの人は持っている物を落とす  異変 → 雷がたくさん＆広い
-- 太陽：レア以上の卵が出やすい（2倍）    異変 → 5倍
-- 時間・確率は EggConfig の EventInterval / EventDuration / EventAnomalyChance で変えられる
--------------------------------------------------------------------------
local Lighting = game:GetService("Lighting")

local EVENTS = {
	{ Name = "雪", Icon = "❄", Text = "卵畑に卵がたくさん出る！" },
	{ Name = "雨", Icon = "☔", Text = "毎秒の収入がアップ！" },
	{ Name = "雷", Icon = "⚡", Text = "雷に当たると持っている物を落とすぞ！" },
	{ Name = "太陽", Icon = "☀", Text = "レアな卵が出やすい！" },
}

local function notifyAll(text)
	for _, p in ipairs(Players:GetPlayers()) do
		notify(p, text)
	end
end

-- 空から降るもの（雪・雨）
local function makeSky(kind, strong)
	local sky = makePart({
		Name = "WeatherSky",
		Size = Vector3.new(Config.BaseRingRadius * 2 + 120, 1, Config.BaseRingRadius * 2 + 120),
		Position = Vector3.new(0, 90, 0),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Parent = workspace,
	})
	local e = Instance.new("ParticleEmitter")
	e.EmissionDirection = Enum.NormalId.Bottom
	e.SpreadAngle = Vector2.new(5, 5)
	if kind == "雪" then
		e.Color = ColorSequence.new(Color3.new(1, 1, 1))
		e.Size = NumberSequence.new(0.6)
		e.Speed = NumberRange.new(12, 18)
		e.Lifetime = NumberRange.new(6, 8)
		e.Rate = strong and 1200 or 600
		e.RotSpeed = NumberRange.new(-60, 60)
	elseif kind == "雨" then
		e.Color = ColorSequence.new(Color3.fromRGB(170, 200, 255))
		e.Size = NumberSequence.new(0.15)
		e.Squash = NumberSequence.new(3)
		e.Transparency = NumberSequence.new(0.3)
		e.Speed = NumberRange.new(80, 100)
		e.Lifetime = NumberRange.new(1, 1.2)
		e.Rate = strong and 2500 or 1200
		e.Orientation = Enum.ParticleOrientation.VelocityParallel
	end
	e.Parent = sky
	return sky
end

-- 雷を1回落とす
local function strikeLightning(radius)
	local a = math.random() * math.pi * 2
	local d = math.sqrt(math.random()) * radius
	local pos = Vector3.new(math.cos(a) * d, 0, math.sin(a) * d)
	local bolt = makePart({
		Name = "Lightning",
		Size = Vector3.new(1.5, 160, 1.5),
		Position = pos + Vector3.new(0, 80, 0),
		Color = Color3.fromRGB(255, 255, 160),
		Material = Enum.Material.Neon,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Parent = workspace,
	})
	local light = Instance.new("PointLight")
	light.Brightness = 10
	light.Range = 60
	light.Color = Color3.fromRGB(255, 255, 200)
	light.Parent = bolt
	Debris:AddItem(bolt, 0.25)
	for player, st in pairs(states) do
		local root = getRoot(player)
		if root and st.carrying and (Vector3.new(root.Position.X, 0, root.Position.Z) - pos).Magnitude < 12 then
			dropCarry(player)
			notify(player, "⚡ 雷に打たれて落としてしまった！")
		end
	end
end

local currentEvent = nil
local function runEvent()
	if currentEvent then
		return false
	end
	local ev = EVENTS[math.random(1, #EVENTS)]
	local anomaly = math.random() < Config.EventAnomalyChance
	currentEvent = ev

	-- 空の見た目を覚えておく（終わったら戻す）
	local saved = {
		ClockTime = Lighting.ClockTime,
		Brightness = Lighting.Brightness,
		Ambient = Lighting.Ambient,
		OutdoorAmbient = Lighting.OutdoorAmbient,
	}
	local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
	local savedAtmo = atmo and { Density = atmo.Density, Color = atmo.Color, Haze = atmo.Haze }

	local sky = nil
	local running = true
	if ev.Name == "雪" then
		weather.spawnMult = anomaly and 3 or 2
		sky = makeSky("雪", anomaly)
		Lighting.OutdoorAmbient = Color3.fromRGB(200, 210, 230)
		if atmo then
			atmo.Density = 0.45
			atmo.Color = Color3.fromRGB(230, 235, 245)
		end
	elseif ev.Name == "雨" then
		weather.incomeMult = anomaly and 3 or 1.5
		sky = makeSky("雨", anomaly)
		Lighting.Brightness = math.min(saved.Brightness, 1)
		if atmo then
			atmo.Density = 0.4
			atmo.Color = Color3.fromRGB(150, 160, 175)
		end
	elseif ev.Name == "雷" then
		Lighting.ClockTime = 20
		if atmo then
			atmo.Density = 0.5
			atmo.Color = Color3.fromRGB(90, 90, 110)
		end
		task.spawn(function()
			while running do
				strikeLightning(anomaly and Config.BaseRingRadius + 20 or Config.FieldRadius + 30)
				task.wait(anomaly and 1 or 3)
			end
		end)
	elseif ev.Name == "太陽" then
		weather.rareBoost = anomaly and 5 or 2
		Lighting.ClockTime = 12
		Lighting.Brightness = 4
		if atmo then
			atmo.Density = 0.2
			atmo.Color = Color3.fromRGB(255, 240, 200)
		end
	end
	if anomaly then
		-- 異変：空があやしい色になる
		Lighting.Ambient = Color3.fromRGB(120, 0, 120)
		Lighting.OutdoorAmbient = Color3.fromRGB(180, 40, 160)
		if atmo then
			atmo.Color = Color3.fromRGB(200, 60, 180)
		end
	end
	local title = (anomaly and "【異変】" or "") .. ev.Icon .. ev.Name .. "イベント"
	workspace:SetAttribute("WeatherEvent", title)
	workspace:SetAttribute("EventEndsAt", workspace:GetServerTimeNow() + Config.EventDuration)
	notifyAll(title .. "スタート！" .. ev.Text .. (anomaly and "（異変で効果がパワーアップ！）" or ""))

	task.wait(Config.EventDuration)

	running = false
	weather.incomeMult, weather.spawnMult, weather.rareBoost = 1, 1, 1
	if sky then
		sky:Destroy()
	end
	for k, v in pairs(saved) do
		Lighting[k] = v
	end
	if atmo and savedAtmo then
		for k, v in pairs(savedAtmo) do
			atmo[k] = v
		end
	end
	workspace:SetAttribute("WeatherEvent", nil)
	workspace:SetAttribute("EventEndsAt", nil)
	notifyAll(title .. "がおわった")
	currentEvent = nil
	return true
end

task.spawn(function()
	while true do
		-- 画面のカウントダウン用に、次のイベントの時刻を知らせる
		workspace:SetAttribute("NextEventAt", workspace:GetServerTimeNow() + Config.EventInterval)
		task.wait(Config.EventInterval)
		runEvent()
	end
end)

-- 管理者用：コード「イベント」ですぐにイベントを始める（テスト用）
CODES["イベント"] = function(player, st)
	if currentEvent then
		return "今はイベント中だよ"
	end
	task.spawn(runEvent)
	return "イベントを始めたよ"
end
ADMIN_ONLY_CODES["イベント"] = true

--------------------------------------------------------------------------
-- OGイベント（マップの端のボタン。管理者だけが押せる）
-- 10分間、卵畑に大きな虹色の「OGの卵」が出る。だれかが取ると、少したって次が出る。
-- OGの卵からは「いちごゾウ」（毎秒 10B 稼ぐ）が生まれる。
--------------------------------------------------------------------------
local OG_RARITY = nil
for i, rar in ipairs(Config.Rarities) do
	if rar.Name == "OG" then
		OG_RARITY = i
	end
end

local ogActive = false
local function runOGEvent()
	if ogActive or not OG_RARITY then
		return false
	end
	ogActive = true
	local endsAt = workspace:GetServerTimeNow() + Config.OGEventDuration
	workspace:SetAttribute("OGEventEndsAt", endsAt)
	notifyAll("🌈 OGイベントスタート！10分間だけ、卵畑に虹色のOGの卵が出る！")

	local ogModel = nil
	local nextSpawn = 0
	while workspace:GetServerTimeNow() < endsAt do
		local t = workspace:GetServerTimeNow()
		if ogModel and not ogModel.Parent then
			-- だれかが取った
			ogModel = nil
			nextSpawn = t + Config.OGEggRespawn
		end
		if not ogModel and t >= nextSpawn then
			local item = { k = "egg", r = OG_RARITY, s = math.random(1, eggStyleCount(OG_RARITY)) }
			ogModel = spawnFieldItem(item, nil, Config.OGEggScale)
			notifyAll("🌈 卵畑にOGの卵があらわれた！")
		end
		task.wait(0.5)
	end

	if ogModel and ogModel.Parent then
		ogModel:Destroy()
	end
	workspace:SetAttribute("OGEventEndsAt", nil)
	notifyAll("🌈 OGイベントがおわった")
	ogActive = false
	return true
end

-- ボタン（ベースとベースの間、マップの外側）
do
	local angle = math.pi * 2 / Config.MaxBases / 2 -- 1番目と2番目のベースの間
	local dist = Config.BaseRingRadius + HALF + 30
	local pos = Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist)
	local cf = CFrame.lookAt(pos, Vector3.new(0, 0, 0))
	local stand = makePart({
		Name = "OGEventStand",
		Size = Vector3.new(6, 3, 6),
		CFrame = cf * CFrame.new(0, 1.5, 0),
		Color = Color3.fromRGB(40, 40, 50),
		Material = Enum.Material.Metal,
		Parent = map,
	})
	local button = makePart({
		Name = "OGEventButton",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1, 4, 4),
		CFrame = cf * CFrame.new(0, 3.5, 0) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Color3.fromRGB(255, 60, 200),
		Material = Enum.Material.Neon,
		Parent = map,
	})
	makeRainbow(button, 0)
	makeLabel(stand, "🌈 OGイベント\n（管理者専用）", Color3.fromRGB(255, 200, 255), UDim2.fromOffset(200, 60), 6, 120)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "OGイベント開始"
	prompt.ObjectText = "管理者専用"
	prompt.HoldDuration = 1
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = button
	prompt.Triggered:Connect(function(player)
		if not isAdmin(player) then
			notify(player, "このボタンは管理者しか押せません")
			return
		end
		if ogActive then
			notify(player, "今はOGイベント中だよ")
			return
		end
		task.spawn(runOGEvent)
	end)
end
