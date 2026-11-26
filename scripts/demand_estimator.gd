class_name DemandEstimator
extends RefCounted
## 今日のメニュー・仕込み数・評判から、料理の注文数と食材の必要数（目安）を見積もる。
## 来店数 = 営業時間 ÷ 平均の来店間隔（評判込み）。席が埋まって来店できない分は考えない（多めの目安）。
## 仕込み数の食材は営業開始のときにまとめて在庫から引くので、
## 「注文の目安どおりに仕込むには、食材がいくつ要るか」を出す。


## 1日の来店数の目安
static func expected_visitors(config: GameConfig, reputation: int) -> float:
	var span: float = maxf(0.0, config.business_duration - config.first_spawn_delay)
	return span / maxf(config.get_average_spawn_interval(reputation), 0.1) + 1.0


## { 料理id: 注文数の目安 }
static func expected_orders(menu: Array[DishData], customer_types: Array[CustomerTypeData], config: GameConfig, reputation: int) -> Dictionary:
	var result: Dictionary = {}
	var total_weight: float = 0.0
	for t: CustomerTypeData in customer_types:
		total_weight += maxf(0.0, t.spawn_weight)
	if total_weight <= 0.0:
		return result
	var visitors: float = expected_visitors(config, reputation)
	for t: CustomerTypeData in customer_types:
		var share: float = maxf(0.0, t.spawn_weight) / total_weight
		var probabilities: Dictionary = OrderChooser.order_probabilities(t, menu, config)
		for dish_id: String in probabilities:
			result[dish_id] = float(result.get(dish_id, 0.0)) + visitors * share * float(probabilities[dish_id])
	return result


## { 食材id: 必要な数の目安 }。料理ごとに「注文の目安」と「仕込み数」の多いほうで数える
## （目安より多く仕込むなら、その分の食材も要る）
static func ingredient_needs(menu: Array[DishData], prep_counts: Dictionary, customer_types: Array[CustomerTypeData], config: GameConfig, reputation: int) -> Dictionary:
	var orders: Dictionary = expected_orders(menu, customer_types, config, reputation)
	var needs: Dictionary = {}
	for d: DishData in menu:
		var count: float = maxf(float(orders.get(d.id, 0.0)), float(prep_counts.get(d.id, 0)))
		for ing_id: String in d.ingredients:
			needs[ing_id] = float(needs.get(ing_id, 0.0)) + count * int(d.ingredients[ing_id])
	for ing_id: String in needs:
		needs[ing_id] = ceili(float(needs[ing_id]) * config.stock_warning_ratio)
	return needs
