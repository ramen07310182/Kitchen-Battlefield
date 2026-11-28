class_name PrepShelfStep
extends VBoxContainer
## 営業準備の手順③「開店時の置き場」: 営業開始の時点で置き場に並べる料理を決める（仕込み数の中から）。
## 右側の「今日のスタッフ」で、雇っているスタッフの出勤／休みを決める（StaffShiftPanel）。

signal notice_requested(text: String)

@onready var _help_label: Label = %HelpLabel
@onready var _shelf_plan: ShelfPlanPanel = %ShelfPlanPanel
@onready var _summary_label: Label = %SummaryLabel
@onready var _staff_scroll: ScrollContainer = %StaffScroll
var _staff_panel: StaffShiftPanel


func _ready() -> void:
	_help_label.text = UIText.PREP_SHELF_STEP_HELP
	_shelf_plan.add_requested.connect(_on_add)
	_shelf_plan.remove_requested.connect(_on_remove)
	_shelf_plan.clear_requested.connect(_on_clear)
	_staff_panel = StaffShiftPanel.new()
	_staff_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_staff_panel.notice_requested.connect(notice_requested.emit)
	_staff_scroll.add_child(_staff_panel)
	_staff_panel.rebuild()


func refresh() -> void:
	_shelf_plan.refresh()
	_staff_panel.refresh()
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
