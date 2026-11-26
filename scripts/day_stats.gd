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
## その日の評判の増減（営業結果のときにまとめて反映した値）
var reputation_change: int = 0
## 客ごとの評判の点数の合計（売り逃しの分は含まない。GameState.get_day_reputation_points で合計する）
var reputation_points: float = 0.0
## この営業のあとに上がったランク（上がらなければ 0）
var rank_up: int = 0
## その日の準備を始めた時点の在庫の原価（在庫の増減の説明用）
var day_start_stock_value: int = 0
## 営業終了時に残って捨てた料理（残り・置き場・調理中）の数と原価。原価は ingredient_cost に含まれている
var waste_count: int = 0
var waste_cost: int = 0
## 注文できる料理がなくなって、早めに閉店した
var sold_out: bool = false
## 料理ごとの内訳 { 料理id: 数 }（仕込み数・売れた数・廃棄数・売上）
var dish_prepared: Dictionary = {}
var dish_sold: Dictionary = {}
var dish_waste: Dictionary = {}
var dish_sales: Dictionary = {}
## 料理ごとの売り逃し: その料理を頼みたかったのに頼めなかった人数
## （売り切れのあとに来店しようとした客・その料理が売り切れていて別の料理を頼んだ客）
var dish_missed: Dictionary = {}
## この営業のあとに新しく解放した料理のid
var new_unlocks: Array[String] = []
## その日の準備を始めた時点の所持金と、その日の仕入れ代（所持金の増減の説明用）
var day_start_money: int = 0
var purchase_cost: int = 0

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


static func add_to(counts: Dictionary, key: String, amount: int) -> void:
	counts[key] = int(counts.get(key, 0)) + amount


## 仕込んだ料理のid（データの並び順）
func get_prepared_dish_ids() -> Array[String]:
	var ids: Array[String] = []
	for dish: DishData in Database.dishes:
		if int(dish_prepared.get(dish.id, 0)) > 0:
			ids.append(dish.id)
	return ids


func profit() -> int:
	return sales - ingredient_cost - other_expense
