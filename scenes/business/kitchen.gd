class_name Kitchen
extends PanelContainer
## 厨房。料理ボタン（2列に並べ、仕込んだ料理が多いときはスクロールする）をタップすると、その料理の「残り」を1つ使って調理キューに入り、店主が順番に作る。
## 食材は営業開始のときに使っているので、ここでは使わない。
## 置き場の空き枠（調理中・調理待ちを含む）より多くは作れない。
## 「残りに戻す」で、置き場で持っている料理を残りに戻せる（置き場の枠が空く）。

signal dish_cooked(dish_id: String)
signal return_requested

var _dishes: Array[DishData] = []
var _buttons: Dictionary = {}  # 料理id -> Button
var _queue: Array[DishData] = []
var _current: DishData = null
var _elapsed: float = 0.0
var _free_slots: int = 0
var _supply: DishSupply = null
## 置き場の空き枠がなく、これ以上作れない
var _full: bool = false

@onready var _buttons_box: GridContainer = %CookButtons
@onready var _chef_label: Label = %ChefLabel
@onready var _chef_figure: SpriteView = %ChefFigure
@onready var _stove: SpriteView = %Stove
@onready var _status_label: Label = %StatusLabel
@onready var _progress: ProgressBar = %CookProgress
@onready var _queue_label: Label = %QueueLabel
@onready var _return_button: Button = %ReturnButton


func _ready() -> void:
	add_theme_stylebox_override("panel", UISkin.panel_box(SpriteKeys.KITCHEN_BACK, UIUtil.flat_box(Color(0.22, 0.24, 0.26))))
	_chef_label.text = UIText.CHEF
	_return_button.text = UIText.COOK_RETURN
	_return_button.disabled = true
	_return_button.pressed.connect(return_requested.emit)


func setup(menu_dishes: Array[DishData], supply: DishSupply) -> void:
	_dishes = menu_dishes
	_supply = supply
	_supply.changed.connect(_refresh_buttons)
	for dish: DishData in _dishes:
		var button: Button = Button.new()
		button.custom_minimum_size = Vector2(0, 28)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var dish_icon: Texture2D = SpriteLibrary.get_icon(SpriteKeys.dish(dish.id))
		button.icon = dish_icon if dish_icon != null else UIUtil.color_icon(dish.color, 10)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.clip_text = true
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.pressed.connect(_on_cook_pressed.bind(dish))
		_buttons_box.add_child(button)
		_buttons[dish.id] = button
	_refresh_buttons()
	_refresh_status()


## 置き場の空き枠数を知らせてもらう
func set_free_slots(count: int) -> void:
	_free_slots = count
	_refresh_buttons()


## 置き場で料理を持っているときだけ「残りに戻す」を押せる
func set_holding(holding: bool) -> void:
	_return_button.disabled = not holding


## キューに入っている分と作っている分の合計
func get_pending_count() -> int:
	return _queue.size() + (1 if _current != null else 0)


func _process(delta: float) -> void:
	if _current == null and not _queue.is_empty():
		_current = _queue.pop_front()
		_elapsed = 0.0
	if _current != null:
		_elapsed += delta
		if _elapsed >= GameState.get_cook_time(_current):
			var finished_id: String = _current.id
			_current = null
			dish_cooked.emit(finished_id)
			_refresh_buttons()
	_refresh_status()


func _can_cook(dish: DishData) -> bool:
	return _supply.get_remaining(dish.id) > 0 and get_pending_count() < _free_slots


func _on_cook_pressed(dish: DishData) -> void:
	if not _can_cook(dish):
		return
	if not _supply.take_for_cooking(dish.id):
		return
	_queue.append(dish)
	_refresh_buttons()


func _refresh_buttons() -> void:
	if _supply == null:
		return
	var full: bool = get_pending_count() >= _free_slots
	for dish: DishData in _dishes:
		var button: Button = _buttons[dish.id]
		var remaining: int = _supply.get_remaining(dish.id)
		button.disabled = not _can_cook(dish)
		button.text = UIText.COOK_BUTTON % [dish.short_name, remaining]
	_full = full


func _refresh_status() -> void:
	var anim: String = SpriteKeys.ANIM_COOK if _current != null else SpriteKeys.ANIM_IDLE
	_chef_figure.animation = anim
	_stove.animation = anim
	if _current != null:
		_status_label.text = UIText.COOKING % _current.display_name
		_progress.value = clampf(_elapsed / maxf(GameState.get_cook_time(_current), 0.01), 0.0, 1.0)
	else:
		_status_label.text = UIText.COOK_FULL if _full else UIText.COOK_IDLE
		_progress.value = 0.0
	if _queue.is_empty():
		_queue_label.text = UIText.COOK_QUEUE_EMPTY
	else:
		var names: PackedStringArray = PackedStringArray()
		for dish: DishData in _queue:
			names.append(dish.short_name)
		_queue_label.text = UIText.COOK_QUEUE % "・".join(names)
