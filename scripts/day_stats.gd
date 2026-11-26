class_name DayStats
extends RefCounted
## 1日分の営業の集計。

var sales: int = 0
var ingredient_cost: int = 0
var other_expense: int = 0
var visitors: int = 0
var completed_orders: int = 0
var left_angry: int = 0
var mistakes: int = 0
var reputation_change: int = 0

var _star_total: float = 0.0
var _star_count: int = 0


func add_rating(star_value: float) -> void:
	_star_total += star_value
	_star_count += 1


func has_ratings() -> bool:
	return _star_count > 0


func average_stars() -> float:
	if _star_count == 0:
		return 0.0
	return _star_total / float(_star_count)


## ★1〜5に丸めた評価
func rounded_stars() -> int:
	return clampi(roundi(average_stars()), 1, 5)


func profit() -> int:
	return sales - ingredient_cost - other_expense
