class_name OrderChooser
extends RefCounted
## お客さんが今日のメニューから何を頼むか。
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
