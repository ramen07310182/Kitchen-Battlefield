class_name PrepShelfStep
extends VBoxContainer
## 営業準備の手順③「開店時の置き場」: 営業開始の時点で置き場に並べる料理を決める（仕込み数の中から）。

signal notice_requested(text: String)

@onready var _help_label: Label = %HelpLabel
@onready var _shelf_plan: ShelfPlanPanel = %ShelfPlanPanel
@onready var _summary_label: Label = %SummaryLabel


func _ready() -> void:
	_help_label.text = UIText.PREP_SHELF_STEP_HELP
	_shelf_plan.add_requested.connect(_on_add)
	_shelf_plan.remove_requested.connect(_on_remove)
	_shelf_plan.clear_requested.connect(_on_clear)


func refresh() -> void:
	_shelf_plan.refresh()
	var parts: PackedStringArray = PackedStringArray()
	for dish: DishData in GameState.get_menu_items():
		parts.append(UIText.PREP_SUMMARY_ITEM % [dish.short_name, GameState.get_prep_count(dish.id)])
	_summary_label.text = UIText.PREP_SUMMARY % ("・".join(parts) if not parts.is_empty() else UIText.PREP_SUMMARY_NONE)


func _on_add(dish_id: String) -> void:
	notice_requested.emit("")
	GameState.add_to_shelf_plan(dish_id)


func _on_remove(index: int) -> void:
	notice_requested.emit("")
	GameState.remove_from_shelf_plan(index)


func _on_clear() -> void:
	notice_requested.emit("")
	GameState.clear_shelf_plan()
