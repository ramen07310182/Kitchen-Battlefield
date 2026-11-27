class_name EquipmentData
extends Resource
## 設備1種類のデータ。data/equipment/ に .tres として置く。
## レベルは配列で持つので、段階を増やすときは配列に足すだけでよい。
##   level_values[n]  : レベル n のときの効果の値（0 = まだ買っていない最初の状態）
##   level_prices[n]  : レベル n から n+1 に上げる価格
##   level_ranks[n]   : レベル n から n+1 に上げるのに必要な店舗ランク
## 最大レベル = level_prices の数

enum Effect {
	## 席の数（イスの数。お客さん1人が1席）。値は席の数
	SEATS,
	## 置き場の枠の数。値は枠の数
	SHELF,
	## 調理時間の倍率。値は倍率（0.85 = 15%短い）。cook_category の料理だけに効く（"all" ならすべて）
	COOK_TIME,
}

@export var id: String = ""
@export var display_name: String = ""
## 効果の説明（一覧に出す短い文）
@export var description: String = ""
@export var effect: Effect = Effect.SEATS
## COOK_TIME のとき、効果を受ける料理の分類（DishData.cook_category）。"all" ならすべての料理
@export var cook_category: String = ""
@export var level_values: PackedFloat32Array = PackedFloat32Array([0.0])
@export var level_prices: PackedInt32Array = PackedInt32Array()
@export var level_ranks: PackedInt32Array = PackedInt32Array()
## 一覧に並べる順番（小さいほど上）
@export var sort_order: int = 0


func get_max_level() -> int:
	return level_prices.size()


## レベル level の効果の値（範囲外なら端の値）
func get_value(level: int) -> float:
	if level_values.is_empty():
		return 0.0
	return level_values[clampi(level, 0, level_values.size() - 1)]


## レベル level から上げる価格（最大レベルなら -1）
func get_price(level: int) -> int:
	return level_prices[level] if level >= 0 and level < level_prices.size() else -1


## レベル level から上げるのに必要なランク（指定がなければ1）
func get_required_rank(level: int) -> int:
	return level_ranks[level] if level >= 0 and level < level_ranks.size() else 1


## この設備がその料理の調理時間に効くか
func affects_dish(dish: DishData) -> bool:
	# "all"（炊飯器）は定食・丼だけに効く（トッピングはご飯を使わない）
	if effect != Effect.COOK_TIME:
		return false
	if cook_category == "all":
		return not dish.is_topping()
	return cook_category == dish.cook_category
