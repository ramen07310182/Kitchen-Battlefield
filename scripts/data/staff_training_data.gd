class_name StaffTrainingData
extends Resource
## スタッフの研修（強化）のレベルごとのデータ。data/staff_training.tres に置く（全員に同じ表を使う）。
## 配列の n 番目がレベル n+1（Lv1 = 雇ったときのまま）。
##   speed_scales[n] : 歩く速さの倍率（1.2 = 2割速い）
##   pick_scales[n]  : 料理を取るまでの時間の倍率（0.8 = 2割短い）
##   wage_adds[n]    : 日給に足す金額（円）
##   prices[n]       : レベル n+1 から n+2 に上げる研修の価格（最大レベルの分はない）
## 研修のレベルは、辞めたあとも残る（雇い直すと引き継ぐ）。

@export var speed_scales: PackedFloat32Array = PackedFloat32Array([1.0])
@export var pick_scales: PackedFloat32Array = PackedFloat32Array([1.0])
@export var wage_adds: PackedInt32Array = PackedInt32Array([0])
@export var prices: PackedInt32Array = PackedInt32Array()


func get_max_level() -> int:
	return speed_scales.size()


func get_speed_scale(level: int) -> float:
	return speed_scales[clampi(level - 1, 0, speed_scales.size() - 1)]


func get_pick_scale(level: int) -> float:
	return pick_scales[clampi(level - 1, 0, pick_scales.size() - 1)]


func get_wage_add(level: int) -> int:
	return wage_adds[clampi(level - 1, 0, wage_adds.size() - 1)]


## レベル level から上げる研修の価格（最大レベルなら -1）
func get_price(level: int) -> int:
	return prices[level - 1] if level >= 1 and level - 1 < prices.size() else -1
