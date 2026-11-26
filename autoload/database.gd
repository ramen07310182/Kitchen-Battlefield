extends Node
## data/ にある料理・食材・客層・設定を読み込んで提供する（オートロード: Database）。
## 新しい料理などは、対応するフォルダに .tres を追加するだけで読み込まれる。

const CONFIG_PATH := "res://data/game_config.tres"
const DISH_DIR := "res://data/dishes/"
const INGREDIENT_DIR := "res://data/ingredients/"
const CUSTOMER_DIR := "res://data/customers/"
const RANK_DIR := "res://data/ranks/"
const EQUIPMENT_DIR := "res://data/equipment/"

var config: GameConfig
var dishes: Array[DishData] = []
var ingredients: Array[IngredientData] = []
var customer_types: Array[CustomerTypeData] = []
## 店舗ランク（rank の小さい順）
var ranks: Array[RankData] = []
## 設備（sort_order の順）
var equipment: Array[EquipmentData] = []

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

	for res: Resource in _load_dir(RANK_DIR):
		if res is RankData:
			ranks.append(res as RankData)
	for res: Resource in _load_dir(EQUIPMENT_DIR):
		if res is EquipmentData:
			equipment.append(res as EquipmentData)
	ranks.sort_custom(func(a: RankData, b: RankData) -> bool: return a.rank < b.rank)
	equipment.sort_custom(func(a: EquipmentData, b: EquipmentData) -> bool: return a.sort_order < b.sort_order)
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


func get_equipment(id: String) -> EquipmentData:
	for e: EquipmentData in equipment:
		if e.id == id:
			return e
	return null


# ---------------------------------------------------------------
# 店舗ランク（data/ranks/）
# ---------------------------------------------------------------

func get_max_rank() -> int:
	return maxi(1, ranks.size())


func _rank_data(rank: int) -> RankData:
	if ranks.is_empty():
		return null
	return ranks[clampi(rank - 1, 0, ranks.size() - 1)]


func get_rank_name(rank: int) -> String:
	var data: RankData = _rank_data(rank)
	return data.display_name if data != null else ""


## そのランクになるのに必要な評判（ランクの範囲外なら -1）
func get_rank_threshold(rank: int) -> int:
	if rank < 1 or rank > ranks.size():
		return -1
	return ranks[rank - 1].reputation_threshold


## 評判から決まるランク（1始まり。評判が下がってもランクは下げないので、GameState.rank も見ること）
func get_rank_for_reputation(reputation: int) -> int:
	var result: int = 1
	for data: RankData in ranks:
		if reputation >= data.reputation_threshold:
			result = maxi(result, data.rank)
	return result


## その日の点数を、評判の増減に直す（プラスは今のランクの倍率、マイナスは game_config の倍率）
func get_reputation_delta(points: float, rank: int) -> int:
	if points > 0.0:
		var data: RankData = _rank_data(rank)
		return roundi(points * (data.reputation_gain_scale if data != null else 0.5))
	return roundi(points * config.reputation_loss_scale)
