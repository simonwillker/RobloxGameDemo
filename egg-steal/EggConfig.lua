-- EggConfig (ModuleScript)
-- 置き場所: ReplicatedStorage
-- ゲームのバランス調整はこのファイルの数字を変えるだけでOK。

local Config = {}

-- ベース（陣地）
Config.MaxBases = 8            -- ベースの数 = 1サーバーの最大人数にする
Config.BaseRingRadius = 160    -- 中央の卵畑からベースまでの距離（大きいほど遠い）
Config.BaseSize = 44           -- ベースの床の大きさ
Config.MaxSlots = 10           -- 卵を置ける台の最大数
Config.StartSlots = 3          -- 最初に使える台の数

-- お金とアップグレード
Config.StartCash = 0
Config.SlotCostBase = 50       -- 台を1つ増やす値段（増やすほど高くなる）
Config.SlotCostGrowth = 1.8
Config.MaxSpeedLevel = 5
Config.BaseWalkSpeed = 16
Config.SpeedPerLevel = 3       -- スピードUP 1回で増える速さ
Config.SpeedCostBase = 75
Config.SpeedCostGrowth = 2
Config.SellMultiplier = 20     -- 生き物を売ると「1秒の収入 × この数」のお金になる

-- どろぼう関係
Config.CarrySpeedMultiplier = 0.7  -- 卵を持っている間は遅くなる
Config.StealHoldTime = 1.5         -- 盗む・開ける・売るときにキーを押し続ける秒数
Config.LockDuration = 20           -- ベースロックの効果時間（秒）
Config.LockCooldown = 60           -- ロックを再び使えるまでの時間（秒）
Config.ShoveRange = 8              -- 「押す」が届く距離
Config.ShoveCooldown = 1.5
Config.StunTime = 1.2              -- 押された人が動けない時間

-- 武器
Config.BatRange = 7                -- バットが届く距離
Config.BatCooldown = 0.8           -- バットを振れる間隔（秒）
-- ミニガン（ゲームパス）: create.roblox.com で 100 Robux のゲームパスを作り、その番号をここに入れる
Config.MinigunGamePassId = 0       -- 0 のままだと購入ボタンは「準備中」になる
Config.MinigunPrice = 100
Config.MinigunFireInterval = 0.1   -- 連射の間隔（秒）
Config.MinigunRange = 120          -- 弾が届く距離

-- 管理者（ゲームの持ち主は自動で管理者）。ほかに管理者にしたい人のユーザーIDを入れる
-- 例: Config.AdminUserIds = { 12345678, 87654321 }
Config.AdminUserIds = {}

-- 中央の卵畑
Config.FieldRadius = 30
Config.FieldEggCount = 12      -- 畑に同時に出る卵の数
Config.EggSpawnInterval = 3    -- 何秒ごとに卵が補充されるか

-- セーブ（Studioで使うには「APIサービスへのStudioアクセス」をON）
Config.UseDataStore = true

-- 卵のレア度（7段階）。Weight が大きいほど出やすい。
-- Palettes = 卵の色の組み合わせ（Main=本体、Accent=模様）。柄は5種類 × 色の数だけ見た目ができる。
local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

Config.Rarities = {
	{ Name = "コモン", Color = rgb(220, 220, 220), Income = 1, Weight = 45, Palettes = {
		{ Main = rgb(250, 245, 230), Accent = rgb(200, 200, 200) },
		{ Main = rgb(255, 235, 200), Accent = rgb(170, 140, 110) },
		{ Main = rgb(235, 235, 240), Accent = rgb(140, 160, 190) },
		{ Main = rgb(250, 250, 250), Accent = rgb(255, 190, 200) },
	} },
	{ Name = "普通", Color = rgb(120, 220, 120), Income = 3, Weight = 28, Palettes = {
		{ Main = rgb(200, 240, 200), Accent = rgb(255, 255, 255) },
		{ Main = rgb(255, 235, 170), Accent = rgb(120, 200, 120) },
		{ Main = rgb(170, 230, 170), Accent = rgb(60, 140, 70) },
		{ Main = rgb(255, 210, 180), Accent = rgb(120, 200, 255) },
	} },
	{ Name = "レア", Color = rgb(90, 170, 255), Income = 8, Weight = 15, Palettes = {
		{ Main = rgb(90, 170, 255), Accent = rgb(255, 255, 255) },
		{ Main = rgb(70, 210, 190), Accent = rgb(255, 240, 120) },
		{ Main = rgb(140, 200, 255), Accent = rgb(40, 80, 180) },
		{ Main = rgb(120, 180, 255), Accent = rgb(255, 170, 200) },
	} },
	{ Name = "エピック", Color = rgb(180, 90, 255), Income = 25, Weight = 7, Palettes = {
		{ Main = rgb(170, 90, 255), Accent = rgb(255, 220, 90) },
		{ Main = rgb(255, 110, 200), Accent = rgb(120, 60, 200) },
		{ Main = rgb(60, 40, 120), Accent = rgb(120, 255, 230) },
		{ Main = rgb(230, 200, 255), Accent = rgb(200, 60, 160) },
	} },
	{ Name = "ミシック", Color = rgb(255, 70, 110), Income = 80, Weight = 3.5, Palettes = {
		{ Main = rgb(255, 70, 110), Accent = rgb(120, 240, 255) },
		{ Main = rgb(30, 20, 60), Accent = rgb(255, 70, 200) },
		{ Main = rgb(20, 20, 20), Accent = rgb(120, 255, 120) },
		{ Main = rgb(255, 120, 40), Accent = rgb(255, 240, 150) },
	} },
	{ Name = "神", Color = rgb(255, 210, 40), Income = 300, Weight = 1.2, Palettes = {
		{ Main = rgb(255, 210, 40), Accent = rgb(255, 255, 255) },
		{ Main = rgb(250, 250, 255), Accent = rgb(255, 190, 30) },
		{ Main = rgb(40, 40, 50), Accent = rgb(255, 210, 40) },
		{ Main = rgb(255, 240, 180), Accent = rgb(255, 90, 60) },
	} },
	{ Name = "810", Color = rgb(0, 255, 230), Income = 1000, Weight = 0.3, Palettes = {
		{ Main = rgb(10, 10, 20), Accent = rgb(0, 255, 230) },
		{ Main = rgb(255, 255, 255), Accent = rgb(255, 0, 180) },
		{ Main = rgb(20, 0, 40), Accent = rgb(255, 230, 0) },
		{ Main = rgb(0, 30, 60), Accent = rgb(120, 255, 120) },
	} },
}

-- 卵から生まれる生き物。Species[レア度の番号] の中から Weight で選ばれる。
-- Body: "ball"(まんまる) / "bean"(たまご型) / "block"(しかく) / "worm"(長いからだ)
-- Features で使えるパーツ:
--   beak くちばし, blush ほっぺ, wings 小さい羽, bigWings 大きい羽, feet 足, legs 4本足,
--   ears とがった耳, roundEars まる耳, longEars うさ耳, tail しっぽ, horn ツノ, antenna 触角,
--   spikes 背中のトゲ, crest とさか, fire 炎, fins ひれ, leaf 葉っぱ, halo 天使の輪,
--   crown 王冠, tentacles 足(クラゲ), stars まわりの星
-- Lift = 体を浮かせる高さ、Scale = 大きさ、Income = 1秒の収入（卵のときより高い）
local GLASS = Enum.Material.Glass
Config.Species = {
	[1] = { -- コモン
		{ Name = "ピヨまる", Body = "ball", Color = rgb(255, 225, 80), Accent = rgb(255, 150, 40), Features = { "beak", "wings", "feet", "blush" }, Income = 3, Weight = 40 },
		{ Name = "モチうさ", Body = "bean", Color = rgb(250, 250, 250), Accent = rgb(255, 170, 200), Features = { "longEars", "tail", "blush" }, Income = 4, Weight = 35 },
		{ Name = "コロイシ", Body = "block", Color = rgb(150, 150, 160), Accent = rgb(110, 200, 90), Features = { "legs", "leaf" }, Material = Enum.Material.Slate, Income = 5, Weight = 25 },
	},
	[2] = { -- 普通
		{ Name = "プルスライム", Body = "bean", Color = rgb(80, 200, 255), Accent = rgb(255, 255, 255), Features = { "antenna", "blush" }, Material = GLASS, Transparency = 0.25, Income = 9, Weight = 40 },
		{ Name = "ツノトカゲ", Body = "worm", Color = rgb(90, 190, 90), Accent = rgb(255, 220, 80), Features = { "horn", "legs", "spikes" }, Income = 11, Weight = 35 },
		{ Name = "フワクラゲ", Body = "ball", Color = rgb(210, 170, 255), Accent = rgb(255, 140, 220), Features = { "tentacles", "blush" }, Material = GLASS, Transparency = 0.2, Lift = 1.1, Income = 14, Weight = 25 },
	},
	[3] = { -- レア
		{ Name = "ホシネコ", Body = "ball", Color = rgb(40, 50, 110), Accent = rgb(255, 230, 90), Features = { "ears", "tail", "stars" }, Income = 25, Weight = 40 },
		{ Name = "メカクマ", Body = "block", Color = rgb(190, 195, 205), Accent = rgb(80, 220, 255), Features = { "roundEars", "antenna", "legs" }, Material = Enum.Material.DiamondPlate, Income = 30, Weight = 35 },
		{ Name = "ハナドラ", Body = "worm", Color = rgb(255, 150, 190), Accent = rgb(120, 220, 120), Features = { "wings", "horn", "leaf", "legs" }, Income = 36, Weight = 25 },
	},
	[4] = { -- エピック
		{ Name = "ヒノトリ", Body = "ball", Color = rgb(255, 90, 40), Accent = rgb(255, 220, 60), Features = { "beak", "bigWings", "crest", "fire" }, Scale = 1.2, Income = 75, Weight = 40 },
		{ Name = "コオリオオカミ", Body = "block", Color = rgb(190, 230, 255), Accent = rgb(60, 140, 255), Features = { "ears", "tail", "legs", "spikes" }, Material = Enum.Material.Ice, Scale = 1.2, Income = 90, Weight = 35 },
		{ Name = "ニジクジラ", Body = "bean", Color = rgb(90, 140, 255), Accent = rgb(255, 120, 200), Features = { "fins", "tail", "stars" }, Lift = 0.6, Scale = 1.3, Income = 110, Weight = 25 },
	},
	[5] = { -- ミシック
		{ Name = "ギャラクシードラゴン", Body = "worm", Color = rgb(60, 30, 110), Accent = rgb(255, 80, 220), Features = { "bigWings", "horn", "spikes", "legs" }, Scale = 1.3, Income = 250, Weight = 40 },
		{ Name = "オウサマスライム", Body = "bean", Color = rgb(255, 200, 40), Accent = rgb(255, 60, 90), Features = { "crown", "antenna", "blush" }, Material = GLASS, Transparency = 0.15, Scale = 1.3, Income = 300, Weight = 35 },
		{ Name = "コスモノヴァ", Body = "ball", Color = rgb(20, 20, 40), Accent = rgb(120, 255, 240), Features = { "tentacles", "stars", "ears" }, Lift = 1.1, Scale = 1.3, Income = 350, Weight = 25 },
	},
	[6] = { -- 神
		{ Name = "カミフクロウ", Body = "ball", Color = rgb(250, 250, 255), Accent = rgb(255, 200, 40), Features = { "beak", "bigWings", "halo", "crest" }, Scale = 1.4, Income = 900, Weight = 40 },
		{ Name = "ライジンリュウ", Body = "worm", Color = rgb(255, 220, 60), Accent = rgb(80, 160, 255), Features = { "horn", "spikes", "bigWings", "legs", "fire" }, Scale = 1.4, Income = 1100, Weight = 35 },
		{ Name = "オーロラウサギ", Body = "bean", Color = rgb(230, 255, 255), Accent = rgb(150, 120, 255), Features = { "longEars", "halo", "stars", "blush" }, Scale = 1.4, Income = 1300, Weight = 25 },
	},
	[7] = { -- 810
		{ Name = "810キング", Body = "block", Color = rgb(255, 200, 30), Accent = rgb(0, 255, 230), Features = { "crown", "bigWings", "stars", "legs" }, Material = Enum.Material.Metal, Scale = 1.6, Income = 3000, Weight = 40 },
		{ Name = "ムゲンスライム", Body = "bean", Color = rgb(10, 10, 20), Accent = rgb(255, 0, 180), Features = { "crown", "halo", "stars", "antenna" }, Material = GLASS, Transparency = 0.1, Scale = 1.6, Income = 3500, Weight = 35 },
		{ Name = "ヤミノカミ", Body = "ball", Color = rgb(15, 0, 30), Accent = rgb(255, 230, 0), Features = { "horn", "bigWings", "halo", "tentacles", "fire" }, Lift = 1.1, Scale = 1.6, Income = 4000, Weight = 25 },
	},
}

function Config.SlotCost(currentSlots)
	return math.floor(Config.SlotCostBase * Config.SlotCostGrowth ^ (currentSlots - Config.StartSlots))
end

function Config.SpeedCost(level)
	return math.floor(Config.SpeedCostBase * Config.SpeedCostGrowth ^ level)
end

return Config
