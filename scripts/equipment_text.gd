class_name EquipmentText
extends RefCounted
## 設備の効果を、画面に出す文にする。


## レベル level の効果（「10席」「置き場 7枠」「調理時間 15% 短い」）
static func effect_text(e: EquipmentData, level: int) -> String:
	var value: float = e.get_value(level)
	match e.effect:
		EquipmentData.Effect.SEATS:
			return UIText.UPGRADE_EFFECT_SEATS % int(value)
		EquipmentData.Effect.SHELF:
			return UIText.UPGRADE_EFFECT_SHELF % int(value)
		_:
			var percent: int = roundi((1.0 - value) * 100.0)
			return UIText.UPGRADE_EFFECT_COOK % percent if percent > 0 else UIText.UPGRADE_EFFECT_COOK_NONE


## 調理時間の設備の対象になる料理（解放済みかどうかに関係なく、すべて）
static func target_dishes_text(e: EquipmentData) -> String:
	if e.cook_category == "all":
		return UIText.UPGRADE_DETAIL_ALL
	var names: PackedStringArray = PackedStringArray()
	for dish: DishData in Database.dishes:
		if e.affects_dish(dish):
			names.append(dish.display_name)
	return "・".join(names)
