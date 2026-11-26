class_name PrepPurchaseStep
extends VBoxContainer
## 営業準備の手順②「仕入れ」: 解放済みの料理で使う食材の仕入れ予定を決める（「仕入れる」で確定）。
## 「不足分を予定に入れる」で、①の仕込み数に足りない分をまとめて予定に入れる。

## 行の長押し（kind は "ingredient"）／指を離した
signal detail_requested(kind: String, id: String)
signal detail_closed
signal notice_requested(text: String)

const INGREDIENT_ROW_SCENE: PackedScene = preload("res://scenes/prep/ingredient_row.tscn")

var _ingredient_rows: Array[IngredientRow] = []

@onready var _help_label: Label = %HelpLabel
@onready var _plan_button: Button = %PlanShortageButton
@onready var _ingredient_list: VBoxContainer = %IngredientList


func _ready() -> void:
	_help_label.text = UIText.PREP_INGREDIENT_HELP
	_plan_button.text = UIText.PREP_PLAN_SHORTAGE
	_plan_button.pressed.connect(_on_plan_shortage_pressed)
	for ing: IngredientData in GameState.get_unlocked_ingredients():
		var row: IngredientRow = INGREDIENT_ROW_SCENE.instantiate() as IngredientRow
		_ingredient_list.add_child(row)
		row.setup(ing)
		row.purchase_changed.connect(_on_purchase_changed)
		row.detail_requested.connect(func(ing_id: String) -> void: detail_requested.emit("ingredient", ing_id))
		row.detail_closed.connect(detail_closed.emit)
		_ingredient_rows.append(row)


func refresh() -> void:
	var needs: Dictionary = GameState.get_ingredient_needs()
	for row: IngredientRow in _ingredient_rows:
		row.refresh(needs)
	# 仕込みに足りない分が、まだ予定に入っていないときだけ押せる
	var shortage: Dictionary = GameState.get_prep_shortage()
	var can_plan: bool = false
	for ing_id: String in shortage:
		if GameState.get_planned_purchase(ing_id) < int(shortage[ing_id]):
			can_plan = true
	_plan_button.disabled = not can_plan


## 目安に対して確定した在庫が足りない食材があるか（赤い行があるか）
func has_estimate_shortage() -> bool:
	var needs: Dictionary = GameState.get_ingredient_needs()
	for row: IngredientRow in _ingredient_rows:
		if GameState.get_shortage(row.ingredient.id, needs) > 0:
			return true
	return false


func _on_purchase_changed(ingredient_id: String, delta: int) -> void:
	notice_requested.emit("")
	GameState.change_purchase(ingredient_id, delta)


func _on_plan_shortage_pressed() -> void:
	if GameState.plan_prep_shortage():
		notice_requested.emit(UIText.PREP_PLAN_SHORTAGE_DONE)
