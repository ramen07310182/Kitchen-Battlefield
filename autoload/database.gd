extends Node
## data/ にある料理・食材・客層・設定を読み込んで提供する（オートロード: Database）。
## 新しい料理などは、対応するフォルダに .tres を追加するだけで読み込まれる。

const CONFIG_PATH := "res://data/game_config.tres"
const DISH_DIR := "res://data/dishes/"
const INGREDIENT_DIR := "res://data/ingredients/"
const CUSTOMER_DIR := "res://data/customers/"

var config: GameConfig
var dishes: Array[DishData] = []
var ingredients: Array[IngredientData] = []
var customer_types: Array[CustomerTypeData] = []

var _dish_by_id: Dictionary = {}
var _ingredient_by_id: Dictionary = {}


func _init() -> void:
	config = load(CONFIG_PATH) as GameConfig
	if config == null:
		push_error("設定が読み込めません: " + CONFIG_PATH)
		config = GameConfig.new()

	for res: Resource in _load_dir(DISH_DIR):
		if res is DishData:
			dishes.append(res as DishData)
	for res: Resource in _load_dir(INGREDIENT_DIR):
		if res is IngredientData:
			ingredients.append(res as IngredientData)
	for res: Resource in _load_dir(CUSTOMER_DIR):
		if res is CustomerTypeData:
			customer_types.append(res as CustomerTypeData)

	dishes.sort_custom(func(a: DishData, b: DishData) -> bool: return a.sort_order < b.sort_order)
	ingredients.sort_custom(func(a: IngredientData, b: IngredientData) -> bool: return a.sort_order < b.sort_order)

	for dish: DishData in dishes:
		_dish_by_id[dish.id] = dish
	for ing: IngredientData in ingredients:
		_ingredient_by_id[ing.id] = ing


func get_dish(id: String) -> DishData:
	return _dish_by_id.get(id) as DishData


func get_ingredient(id: String) -> IngredientData:
	return _ingredient_by_id.get(id) as IngredientData


## 料理1つ分の食材原価
func get_dish_cost(dish: DishData) -> int:
	var total: int = 0
	for ing_id: String in dish.ingredients:
		var ing: IngredientData = get_ingredient(ing_id)
		if ing != null:
			total += ing.price * int(dish.ingredients[ing_id])
	return total


## 「米・鶏肉・キャベツ」のような食材の一覧文字列
func get_ingredient_names(dish: DishData) -> String:
	var names: PackedStringArray = PackedStringArray()
	for ing: IngredientData in ingredients:
		if dish.ingredients.has(ing.id):
			var count: int = int(dish.ingredients[ing.id])
			names.append(ing.display_name if count == 1 else "%s×%d" % [ing.display_name, count])
	return "・".join(names)


func _load_dir(path: String) -> Array[Resource]:
	var result: Array[Resource] = []
	# list_directory は書き出し後（.remap になった状態）でも元のファイル名を返す
	for file_name: String in ResourceLoader.list_directory(path):
		if file_name.ends_with("/"):
			continue
		var clean: String = file_name.trim_suffix(".remap")
		if not (clean.ends_with(".tres") or clean.ends_with(".res")):
			continue
		var res: Resource = load(path + clean)
		if res != null:
			result.append(res)
		else:
			push_error("データが読み込めません: " + path + clean)
	return result
