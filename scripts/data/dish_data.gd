class_name DishData
extends Resource
## 料理1種類のデータ。data/dishes/ に .tres として置く。

@export var id: String = ""
@export var display_name: String = ""
## 料理アイコンや完成品置き場に出す短い名前（2文字くらい）
@export var short_name: String = ""
## 販売価格（円）
@export var price: int = 0
## 必要な食材: { 食材id: 個数 }
@export var ingredients: Dictionary = {}
## 調理にかかる時間（秒）
@export var cook_time: float = 5.0
## 表示色（絵ができるまでの代用）
@export var color: Color = Color.WHITE
## 一覧に並べる順番（小さいほど上）
@export var sort_order: int = 0
## 調理の分類（"fry" = 揚げ物、"grill" = 焼き物・炒め物、"simmer" = 煮物・丼）。設備の効果を受けるかどうかに使う
@export var cook_category: String = ""
## 調理の難しさ（1〜3）。厨房のスタッフは、研修のレベルで決まる難しさまでしか作れない（店主はすべて作れる）
@export_range(1, 3) var difficulty: int = 1
## 解放の条件（両方を満たしたら解放）。営業結果のあと、次の営業日について判定する
##   unlock_rank: 必要な店舗ランク（1 なら最初から）
##   unlock_day : この営業日（○日目）以降（0 なら日数の条件なし）
@export var unlock_rank: int = 1
@export var unlock_day: int = 0


## トッピング（ToppingData）なら true
func is_topping() -> bool:
	return false
