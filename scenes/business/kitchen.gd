class_name Kitchen
extends PanelContainer
## 厨房。料理ボタンをタップすると食材を使って調理キューに入り、店主が順番に作る。
## 完成品置き場の空き枠より多くは作れない。

signal dish_cooked(dish_id: String)

var _dishes: Array[DishData] = []
var _buttons: Dictionary = {}  # 料理id -> Button
var _queue: Array[DishData] = []
var _current: DishData = null
var _elapsed: float = 0.0
var _free_slots: int = 0

@onready var _buttons_box: VBoxContainer = %CookButtons
@onready var _chef_label: Label = %ChefLabel
@onready var _status_label: Label = %StatusLabel
@onready var _progress: ProgressBar = %CookProgress
@onready var _queue_label: Label = %QueueLabel


func _ready() -> void:
	add_theme_stylebox_override("panel", UIUtil.flat_box(Color(0.22, 0.24, 0.26)))
	_chef_label.text = UIText.CHEF
	GameState.inventory_changed.connect(_refresh_buttons)


func setup(menu_dishes: Array[DishData]) -> void:
	_dishes = menu_dishes
	for dish: DishData in _dishes:
		var button: Button = Button.new()
		button.custom_minimum_size = Vector2(0, 32)
		button.icon = UIUtil.color_icon(dish.color, 10)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_on_cook_pressed.bind(dish))
		_buttons_box.add_child(button)
		_buttons[dish.id] = button
	_refresh_buttons()
	_refresh_status()


## 完成品置き場の空き枠数を知らせてもらう
func set_free_slots(count: int) -> void:
	_free_slots = count
	_refresh_buttons()


## キューに入っている分と作っている分の合計
func get_pending_count() -> int:
	return _queue.size() + (1 if _current != null else 0)


func _process(delta: float) -> void:
	if _current == null and not _queue.is_empty():
		_current = _queue.pop_front()
		_elapsed = 0.0
	if _current != null:
		_elapsed += delta
		if _elapsed >= _current.cook_time:
			var finished_id: String = _current.id
			_current = null
			dish_cooked.emit(finished_id)
			_refresh_buttons()
	_refresh_status()


func _can_cook(dish: DishData) -> bool:
	return GameState.has_ingredients(dish) and get_pending_count() < _free_slots


func _on_cook_pressed(dish: DishData) -> void:
	if not _can_cook(dish):
		return
	GameState.consume_ingredients(dish)
	_queue.append(dish)
	_refresh_buttons()


func _refresh_buttons() -> void:
	var full: bool = get_pending_count() >= _free_slots
	for dish: DishData in _dishes:
		var button: Button = _buttons[dish.id]
		button.disabled = not _can_cook(dish)
		if not GameState.has_ingredients(dish):
			button.text = UIText.COOK_BUTTON_NO_STOCK % dish.display_name
		elif full:
			button.text = UIText.COOK_BUTTON_FULL % dish.display_name
		else:
			button.text = UIText.COOK_BUTTON % [dish.display_name, roundi(dish.cook_time)]


func _refresh_status() -> void:
	if _current != null:
		_status_label.text = UIText.COOKING % _current.display_name
		_progress.value = clampf(_elapsed / maxf(_current.cook_time, 0.01), 0.0, 1.0)
	else:
		_status_label.text = UIText.COOK_IDLE
		_progress.value = 0.0
	if _queue.is_empty():
		_queue_label.text = UIText.COOK_QUEUE_EMPTY
	else:
		var names: PackedStringArray = PackedStringArray()
		for dish: DishData in _queue:
			names.append(dish.short_name)
		_queue_label.text = UIText.COOK_QUEUE % "・".join(names)
