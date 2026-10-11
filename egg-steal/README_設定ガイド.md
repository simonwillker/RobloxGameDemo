# 卵どろぼう（Egg Thief）設定ガイド

人気の「卵を盗む」系ゲームを参考にした、オリジナルのRobloxゲームです。
マップ・ベース・卵はすべてスクリプトが自動で作るので、Studioでの手作業は **スクリプト3つを置くだけ** です。

## 遊び方
1. 参加すると自分のベース（色つきの囲い）に出現します。
2. 中央の **卵畑** で卵に近づき **E** で拾う → 自分のベースに入ると台に置かれます。
3. 卵は7つのレア度（コモン・普通・レア・エピック・ミシック・神・810）× 5種類の柄 × 4色。レアほど光ったりキラキラし、810の卵は炎をまといます。
4. 自分の台の卵で **E長押し → 開ける**。卵が揺れて割れ、中から **生き物** が生まれます（全21種類）。生き物は卵よりたくさんお金を生みます。
5. 自分の生き物で E長押し → **売る**（まとまったお金）。
6. 他の人のベースの台で **E長押し** → 卵や生き物を **盗む**。持っている間は少し遅くなります。
7. **F** キー（スマホは「押す」ボタン）で近くの人を押す → 持っているものを落とさせる。盗まれたものは持ち主の台に戻ります。
8. 持っているものは **G** キー（または「落とす」ボタン）でいつでもその場に落とせます。
9. 左下の **コード入力欄** に `114514810` と入れて「使う」を押すと、810の卵がもらえます（何回でもOK）。**このコードは管理者専用**です（ゲームの持ち主と、`EggConfig` の `AdminUserIds` に入れた人）。コードは `EggGameServer` の `CODES` で増やせます。
10. 右のボタンで **台を増やす**・**スピードUP**・**ベースをロック**（20秒間だれも入れない）。

### 生き物一覧
| レア度 | 生き物 |
|---|---|
| コモン | ピヨまる、モチうさ、コロイシ |
| 普通 | プルスライム、ツノトカゲ、フワクラゲ |
| レア | ホシネコ、メカクマ、ハナドラ |
| エピック | ヒノトリ、コオリオオカミ、ニジクジラ |
| ミシック | ギャラクシードラゴン、オウサマスライム、コスモノヴァ |
| 神 | カミフクロウ、ライジンリュウ、オーロラウサギ |
| 810 | 810キング、ムゲンスライム、ヤミノカミ |

生き物の形・色・パーツは `EggConfig` の `Config.Species` で自由に変えたり、増やしたりできます。

## Studioでの設定（5分）
1. **New → Baseplate** で新しい場所を作る。
2. Explorer の **ReplicatedStorage** を右クリック → Insert Object → **ModuleScript**。名前を `EggConfig` に変え、中身を [EggConfig.lua](EggConfig.lua) で置き換える。
3. **ServerScriptService** を右クリック → Insert Object → **Script**。名前を `EggGameServer` にし、中身を [EggGameServer.server.lua](EggGameServer.server.lua) で置き換える。
4. **StarterPlayer → StarterPlayerScripts** を右クリック → Insert Object → **LocalScript**。名前を `EggGameClient` にし、中身を [EggGameClient.client.lua](EggGameClient.client.lua) で置き換える。
5. 上部 **File → Game Settings → Places**（または公開後の設定）で **最大人数を 8** にする（ベースが8個のため）。

完成形のExplorer：
```
ReplicatedStorage
  └ EggConfig        (ModuleScript)
ServerScriptService
  └ EggGameServer    (Script)
StarterPlayer
  └ StarterPlayerScripts
      └ EggGameClient (LocalScript)
```
※ 名前の `EggConfig` はスペルを正確に。他の2つの名前は自由です。

## テスト方法
- 1人で確認：上部 **Play**（F5）。卵を拾ってベースに置き、お金が増えるか見る。
- 盗む・押すの確認：**Test** タブ → **Clients and Servers** で人数を **2** にして **Start**。2つのウィンドウで盗み合えます。
- うまく動かないときは **View → Output** を開いて赤い文字を確認してください。

## セーブ（任意）
お金・台・卵を保存できます。Studioで試すには、ゲームを一度 **公開(Publish)** してから
**Game Settings → Security → Enable Studio Access to API Services** をON。
OFFのままでも遊べます（保存されないだけ）。

## 調整したいとき
数字はすべて `EggConfig` にあります。例：
- 卵の出やすさ・収入・色 → `Config.Rarities`
- 生き物の種類・形・収入 → `Config.Species`
- 台の値段 → `SlotCostBase` / `SlotCostGrowth`
- ロック時間 → `LockDuration` / `LockCooldown`
