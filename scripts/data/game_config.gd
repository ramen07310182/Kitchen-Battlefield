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
## 評判1ポイントごとに、来店間隔をどれだけ縮めるか（0.004 = 0.4%）
@export var interval_reduction_per_reputation: float = 0.004
## 来店間隔の倍率の下限（0.5 = どれだけ評判が高くても間隔は半分まで）
@export var min_interval_scale: float = 0.5

@export_group("経費")
## その他経費（1日あたり固定）
@export var other_expense: int = 2000

@export_group("満足度")
## 待ち時間 ÷ 待てる時間 がこの値以下なら大満足
@export var great_ratio: float = 0.35
## この値以下なら満足、超えるとやや不満
@export var good_ratio: float = 0.7
## 評判の増減
@export var reputation_great: int = 3
@export var reputation_good: int = 1
@export var reputation_bad: int = -1
@export var reputation_angry: int = -3
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


## 評判に応じた来店間隔の倍率（1.0 = 基本のまま、小さいほどよく来る）
func get_spawn_interval_scale(reputation: int) -> float:
	return clampf(1.0 - float(reputation) * interval_reduction_per_reputation, min_interval_scale, 1.0)


## 評判に応じた平均の来店間隔（秒）
func get_average_spawn_interval(reputation: int) -> float:
	return (spawn_interval_min + spawn_interval_max) * 0.5 * get_spawn_interval_scale(reputation)
