class_name OrderChooser
extends RefCounted
## お客さんが今日のメニューから何を頼むか（料理1つと、確率でトッピング1つ）。
## 来店（CustomerSpawner）と、在庫の目安（DemandEstimator）の両方で同じ確率を使う。


## { 料理id: 頼む確率 }。予算内の料理から、好きな料理ほど選ばれやすい。
## 予算内の料理がなければ、いちばん安い料理を必ず頼む
static func order_probabilities(customer_type: CustomerTypeData, menu: Array[DishData], config: GameConfig) -> Dictionary:
	var result: Dictionary = {}
	if menu.is_empty():
		return result
	var candidates: Array[DishData] = []
	for d: DishData in menu:
		if d.price <= customer_type.budget:
			candidates.append(d)
	if candidates.is_empty():
		var cheapest: DishData = menu[0]
		for d: DishData in menu:
			if d.price < cheapest.price:
				cheapest = d
		result[cheapest.id] = 1.0
		return result
	var total: float = 0.0
	for d: DishData in candidates:
		total += _weight(customer_type, d, config)
	for d: DishData in candidates:
		result[d.id] = _weight(customer_type, d, config) / total
	return result


## 確率に従って1つ選ぶ
static func choose(customer_type: CustomerTypeData, menu: Array[DishData], config: GameConfig) -> DishData:
	var probabilities: Dictionary = order_probabilities(customer_type, menu, config)
	var last: DishData = null
	var roll: float = randf()
	for d: DishData in menu:
		if not probabilities.has(d.id):
			continue
		last = d
		roll -= float(probabilities[d.id])
		if roll <= 0.0:
			return d
	return last


static func _weight(customer_type: CustomerTypeData, dish: DishData, config: GameConfig) -> float:
	return config.favorite_weight if customer_type.favorite_dishes.has(dish.id) else 1.0


## トッピングを頼むと決めたときの { トッピングid: 選ぶ確率 }（好きなトッピングほど選ばれやすい。予算は見ない）
static func topping_probabilities(customer_type: CustomerTypeData, toppings: Array[DishData], config: GameConfig) -> Dictionary:
	var result: Dictionary = {}
	var total: float = 0.0
	for t: DishData in toppings:
		total += _topping_weight(customer_type, t, config)
	if total <= 0.0:
		return result
	for t: DishData in toppings:
		result[t.id] = _topping_weight(customer_type, t, config) / total
	return result


## トッピングを追加で頼むか（客層の確率で決める）
static func wants_topping(customer_type: CustomerTypeData) -> bool:
	return randf() < customer_type.topping_rate


## 頼むトッピングを1つ選ぶ（toppings が空なら null）
static func choose_topping(customer_type: CustomerTypeData, toppings: Array[DishData], config: GameConfig) -> DishData:
	var probabilities: Dictionary = topping_probabilities(customer_type, toppings, config)
	var last: DishData = null
	var roll: float = randf()
	for t: DishData in toppings:
		last = t
		roll -= float(probabilities.get(t.id, 0.0))
		if roll <= 0.0:
			return t
	return last


static func _topping_weight(customer_type: CustomerTypeData, topping: DishData, config: GameConfig) -> float:
	return config.favorite_weight if customer_type.favorite_toppings.has(topping.id) else 1.0
