class_name GameConfig
extends Resource
## 調整用の数値をまとめた設定。実体は data/game_config.tres。

@export_group("ゲーム開始時")
@export var start_money: int = 10000
## 開始時の在庫: { 食材id: 個数 }
@export var start_inventory: Dictionary = {}

@export_group("営業")
## 営業時間（秒）
@export var business_duration: float = 120.0
## 営業開始から最初のお客さんが来るまで（秒）
@export var first_spawn_delay: float = 2.0
## 来店間隔（秒）。この範囲でランダム
@export var spawn_interval_min: float = 5.0
@export var spawn_interval_max: float = 9.0
## テーブルの数（1人用）
@export var table_count: int = 4
## お客さんの歩く速さ（px/秒）
@export var walk_speed: float = 160.0
## 着席してから注文するまで（秒）
@export var order_delay: float = 1.5
## 好きな料理が選ばれる重み（好きでない料理は1）
@export var favorite_weight: float = 3.0
## 置き場の枠数（開店時に並べておける数もこれが上限）
@export var shelf_capacity: int = 6
## 営業終了後の画面に切り替わるまで（秒）
@export var end_delay: float = 1.5

@export_group("評判と来店")
## 評判1ポイントごとに、来店間隔をどれだけ縮めるか（0.0039 = 0.39%。評判128前後＝有名店で下限に届く）
@export var interval_reduction_per_reputation: float = 0.0039
## 来店間隔の倍率の下限（0.5 = どれだけ評判が高くても間隔は半分まで）
@export var min_interval_scale: float = 0.5

@export_group("店舗ランク")
## ランクの名前（ランク1から順に）
@export var rank_names: PackedStringArray = PackedStringArray(["無名店", "知る人ぞ知る店", "人気店", "有名店"])
## そのランクになるのに必要な評判（ランク1から順に。ランク1は0）
@export var rank_thresholds: PackedInt32Array = PackedInt32Array([0, 30, 70, 130])

@export_group("評判の増減")
## 客1人ごとの評判の点数（その日の分を足して、営業結果のときにまとめて評判に反映する）
@export var reputation_great: float = 1.0
@export var reputation_good: float = 0.5
@export var reputation_bad: float = -0.5
@export var reputation_angry: float = -2.0
## 売り逃し1人ごとの点数（頼みたかったのに頼めなかった客）
@export var reputation_missed: float = -0.3
## その日の点数がプラスのとき、評判に反映する倍率（今のランクごと。ランクが高いほど上がりにくい）
@export var reputation_gain_by_rank: PackedFloat32Array = PackedFloat32Array([0.5, 0.4, 0.35, 0.3])
## その日の点数がマイナスのとき、評判に反映する倍率
@export var reputation_loss_scale: float = 0.5
## version 6 以前のセーブの評判を、今の範囲に換算する倍率（来店ペースが同じになるように）
@export var legacy_reputation_scale: float = 1.03

@export_group("経費")
## その他経費（1日あたり固定）
@export var other_expense: int = 2000

@export_group("満足度")
## 待ち時間 ÷ 待てる時間 がこの値以下なら大満足
@export var great_ratio: float = 0.35
## この値以下なら満足、超えるとやや不満
@export var good_ratio: float = 0.7
## その日の評価（★）に使う点数
@export var stars_great: float = 5.0
@export var stars_good: float = 4.0
@export var stars_bad: float = 2.0
@export var stars_angry: float = 1.0

@export_group("営業準備")
## 仕入れ予定ボタン1回で増減する個数（小・大）
@export var buy_step_small: int = 1
@export var buy_step_large: int = 5
## 料理1種類あたりの仕込み数の上限
@export var max_prep_per_dish: int = 99
## 「－＋」を長押ししたとき: くり返しが始まるまでの秒数・くり返しの間隔（秒）
@export var hold_repeat_delay: float = 0.4
@export var hold_repeat_interval: float = 0.08
## 長押しをこの秒数続けると、1回に増減する数を hold_fast_step にする
@export var hold_fast_after: float = 1.2
@export var hold_fast_step: int = 5
## 行を長押しして詳細を出すまでの秒数
@export var long_press_time: float = 0.4
## 指（マウス）がこの距離（px、640×360基準）以上動いたら、ボタンの押下や長押しを取り消して一覧のスクロールとして扱う
@export var scroll_drag_threshold: float = 8.0
## マウスホイール1目盛りでスクロールする量（px）
@export var scroll_wheel_step: float = 40.0
## 営業結果の料理ごとの内訳で「廃棄が多い」と色を付ける割合（廃棄数 ÷ 仕込み数 がこれ以上）
@export var waste_warning_ratio: float = 0.3
## 在庫不足の警告: 見積もった必要数にこの倍率をかけた数より在庫が少ないと赤くする
## （1.0 = 見積もりどおり、0.8 = 少し甘め、1.2 = 余裕を持たせる）
@export var stock_warning_ratio: float = 1.0


## 評判から決まるランク（1始まり。評判が下がってもランクは下げないので、GameState.rank も見ること）
func get_rank_for_reputation(reputation: int) -> int:
	var result: int = 1
	for i: int in rank_thresholds.size():
		if reputation >= rank_thresholds[i]:
			result = i + 1
	return result


func get_max_rank() -> int:
	return rank_thresholds.size()


func get_rank_name(rank: int) -> String:
	var index: int = clampi(rank - 1, 0, rank_names.size() - 1)
	return rank_names[index] if not rank_names.is_empty() else ""


## そのランクになるのに必要な評判（最高ランクより上は -1）
func get_rank_threshold(rank: int) -> int:
	if rank < 1 or rank > rank_thresholds.size():
		return -1
	return rank_thresholds[rank - 1]


## その日の点数を、評判の増減に直す（今のランクで上がり方が変わる）
func get_reputation_delta(points: float, rank: int) -> int:
	if points > 0.0:
		var index: int = clampi(rank - 1, 0, reputation_gain_by_rank.size() - 1)
		return roundi(points * reputation_gain_by_rank[index])
	return roundi(points * reputation_loss_scale)


## 評判に応じた来店間隔の倍率（1.0 = 基本のまま、小さいほどよく来る）
func get_spawn_interval_scale(reputation: int) -> float:
	return clampf(1.0 - float(reputation) * interval_reduction_per_reputation, min_interval_scale, 1.0)


## 評判に応じた平均の来店間隔（秒）
func get_average_spawn_interval(reputation: int) -> float:
	return (spawn_interval_min + spawn_interval_max) * 0.5 * get_spawn_interval_scale(reputation)
