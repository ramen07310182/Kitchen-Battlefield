class_name Customer
extends Control
## お客さん1人。来店 → 着席 → 注文 → 待機 → 食事 → 会計 → 退店 を自分で進める。
## 状態が変わるとシグナルで知らせる。タップは受け取らない（テーブルが受け取る）。

signal order_placed(customer: Customer)
signal paid(customer: Customer)
signal left_angry(customer: Customer)
## 席を立った（テーブルを空けてよい）
signal seat_released(customer: Customer)
## 店を出た（この直後に消える）
signal exited(customer: Customer)

enum State { WALKING_IN, ORDERING, WAITING_FOOD, EATING, LEAVING }

const GAUGE_WIDTH := 36.0

var type_data: CustomerTypeData
var dish: DishData
var table_index: int = -1
var state: State = State.WALKING_IN
## 注文してからの経過時間
var wait_elapsed: float = 0.0
## 注文した順番（注文状況パネルの並び順）
var order_sequence: int = 0

var _config: GameConfig
var _state_time: float = 0.0
var _exit_position: Vector2 = Vector2.ZERO

@onready var _figure: SpriteView = %Figure
@onready var _body: ColorRect = %Body
@onready var _face_label: Label = %FaceLabel
@onready var _bubble: ColorRect = %Bubble
@onready var _bubble_label: Label = %BubbleLabel
@onready var _dish_icon: SpriteView = %DishIcon
@onready var _gauge_bg: ColorRect = %GaugeBg
@onready var _gauge_fill: ColorRect = %GaugeFill
@onready var _popup_label: Label = %PopupLabel


## add_child の後に呼ぶ
func setup(customer_type: CustomerTypeData, ordered_dish: DishData, table: int, config: GameConfig) -> void:
	type_data = customer_type
	dish = ordered_dish
	table_index = table
	_config = config
	_body.color = type_data.color
	_figure.set_sprite(SpriteKeys.customer(type_data.id), SpriteKeys.ANIM_WALK)
	_bubble.color = dish.color
	_bubble_label.text = dish.short_name
	_dish_icon.sprite_key = SpriteKeys.dish(dish.id)
	if _dish_icon.has_sprite():
		# 料理の絵があれば、吹き出しは白い背景にして絵を見せる
		_bubble.color = Color(1, 1, 1, 0.9)
		_bubble.position = _dish_icon.position
		_bubble.size = _dish_icon.size
		_bubble_label.hide()
	_set_bubble_visible(false)
	_gauge_bg.hide()
	_popup_label.hide()
	_face_label.text = ""


## 入口から席まで歩く
func start(entrance: Vector2, seat: Vector2) -> void:
	position = entrance
	_exit_position = entrance
	state = State.WALKING_IN
	_face_towards(seat)
	var tween: Tween = create_tween()
	tween.tween_property(self, "position", seat, _walk_duration(entrance, seat))
	tween.finished.connect(_on_arrived_at_seat)


func is_waiting_food() -> bool:
	return state == State.WAITING_FOOD


## 待てる時間に対する経過の割合（0〜1）
func get_wait_ratio() -> float:
	return clampf(wait_elapsed / maxf(type_data.patience, 0.01), 0.0, 1.0)


## 料理を受け取る。満足度を返す
func serve() -> Satisfaction.Level:
	var level: Satisfaction.Level = Satisfaction.from_wait(wait_elapsed, type_data.patience, _config)
	state = State.EATING
	_state_time = 0.0
	_gauge_bg.hide()
	_bubble_label.text = UIText.EATING
	_figure.animation = SpriteKeys.ANIM_EAT
	_face_label.text = UIText.SATISFACTION_MARKS[level]
	return level


func show_popup(text: String, color: Color = Color.WHITE) -> void:
	_popup_label.text = text
	_popup_label.modulate = color
	_popup_label.position = Vector2(-28, -44)
	_popup_label.show()
	var tween: Tween = create_tween()
	tween.tween_property(_popup_label, "position:y", -58.0, 0.8)
	tween.parallel().tween_property(_popup_label, "modulate:a", 0.0, 0.8).set_delay(0.3)
	tween.finished.connect(_popup_label.hide)


func _process(delta: float) -> void:
	match state:
		State.ORDERING:
			_state_time += delta
			if _state_time >= _config.order_delay:
				_place_order()
		State.WAITING_FOOD:
			wait_elapsed += delta
			_update_gauge()
			if wait_elapsed >= type_data.patience:
				_leave_angry()
		State.EATING:
			_state_time += delta
			if _state_time >= type_data.eat_time:
				paid.emit(self)
				show_popup(UIText.POPUP_PAID % UIText.money(dish.price), Color(1.0, 0.9, 0.4))
				_leave()


func _on_arrived_at_seat() -> void:
	state = State.ORDERING
	_figure.animation = SpriteKeys.ANIM_SIT
	_figure.flip_h = false
	_state_time = 0.0


func _place_order() -> void:
	state = State.WAITING_FOOD
	wait_elapsed = 0.0
	_set_bubble_visible(true)
	_gauge_bg.show()
	_update_gauge()
	order_placed.emit(self)


func _update_gauge() -> void:
	var ratio: float = get_wait_ratio()
	_gauge_fill.size.x = GAUGE_WIDTH * (1.0 - ratio)
	if ratio <= _config.great_ratio:
		_gauge_fill.color = Color(0.4, 0.85, 0.4)
	elif ratio <= _config.good_ratio:
		_gauge_fill.color = Color(0.95, 0.8, 0.3)
	else:
		_gauge_fill.color = Color(0.95, 0.3, 0.25)


func _leave_angry() -> void:
	_face_label.text = UIText.SATISFACTION_MARKS[Satisfaction.Level.ANGRY]
	show_popup(UIText.POPUP_ANGRY, Color(1.0, 0.45, 0.4))
	left_angry.emit(self)
	_leave()


func _leave() -> void:
	state = State.LEAVING
	_set_bubble_visible(false)
	_gauge_bg.hide()
	_figure.animation = SpriteKeys.ANIM_WALK
	_face_towards(_exit_position)
	seat_released.emit(self)
	var tween: Tween = create_tween()
	tween.tween_property(self, "position", _exit_position, _walk_duration(position, _exit_position))
	tween.finished.connect(_on_exited)


func _on_exited() -> void:
	exited.emit(self)
	queue_free()


func _set_bubble_visible(on: bool) -> void:
	_bubble.visible = on
	_dish_icon.visible = on


## 絵は右向きで描くので、左へ歩くときは左右反転する
func _face_towards(target: Vector2) -> void:
	_figure.flip_h = target.x < position.x


func _walk_duration(from: Vector2, to: Vector2) -> float:
	return maxf(0.2, from.distance_to(to) / maxf(_config.walk_speed, 1.0))
