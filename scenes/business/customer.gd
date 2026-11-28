class_name Customer
extends Control
## お客さん1人。来店 → 着席 → 注文 → 待機 → 食事 → 会計 → 退店 を自分で進める。
## 注文は料理1つと、トッピング1つ（頼まないこともある）。料理とトッピングは別々に出してよく、順番は自由。
## 全部そろったら食べ始める。待ち時間（満足度・怒って帰る判定）は全部そろうまで続く。
## 状態が変わるとシグナルで知らせる。タップは受け取らない（席が受け取る）。

signal order_placed(customer: Customer)
signal paid(customer: Customer)
signal left_angry(customer: Customer)
## 席を立った（席を空けてよい）
signal seat_released(customer: Customer)
## 店を出た（この直後に消える）
signal exited(customer: Customer)

enum State { WALKING_IN, ORDERING, WAITING_FOOD, EATING, LEAVING }
## 料理・トッピングを受け取ったときの結果
enum Receive {
	## 注文していないもの（または、もう受け取ったもの）。ミス
	WRONG,
	## 注文の一部を受け取った。残りを待つ
	PARTIAL,
	## 注文がすべてそろった。食べ始める
	COMPLETE,
}

const GAUGE_WIDTH := 36.0
## 出し終えた料理の吹き出しの薄さ
const SERVED_ALPHA := 0.35

var type_data: CustomerTypeData
var dish: DishData
## 追加で頼んだトッピング（頼んでいなければ null）
var topping: DishData = null
## 座る席（DiningArea の席の番号）
var seat_index: int = -1
var state: State = State.WALKING_IN
## 注文してからの経過時間
var wait_elapsed: float = 0.0
## 注文した順番（注文状況パネルの並び順）
var order_sequence: int = 0
## 料理・トッピングを出し終えたか
var dish_served: bool = false
var topping_served: bool = false
## 全部そろったときの満足度
var satisfaction: Satisfaction.Level = Satisfaction.Level.GOOD

var _config: GameConfig
var _state_time: float = 0.0
var _exit_position: Vector2 = Vector2.ZERO

@onready var _figure: SpriteView = %Figure
@onready var _body: ColorRect = %Body
@onready var _face_label: Label = %FaceLabel
@onready var _bubble: ColorRect = %Bubble
@onready var _bubble_label: Label = %BubbleLabel
@onready var _dish_icon: SpriteView = %DishIcon
@onready var _top_bubble: ColorRect = %TopBubble
@onready var _top_label: Label = %TopBubbleLabel
@onready var _top_icon: SpriteView = %TopIcon
@onready var _gauge_bg: ColorRect = %GaugeBg
@onready var _gauge_fill: ColorRect = %GaugeFill
@onready var _popup_label: Label = %PopupLabel


## add_child の後に呼ぶ。ordered_topping: 追加で頼んだトッピング（なければ null）
func setup(customer_type: CustomerTypeData, ordered_dish: DishData, seat: int, config: GameConfig,
		ordered_topping: DishData = null) -> void:
	type_data = customer_type
	dish = ordered_dish
	topping = ordered_topping
	seat_index = seat
	_config = config
	_body.color = type_data.color
	_figure.set_sprite(SpriteKeys.customer(type_data.id), SpriteKeys.ANIM_WALK)
	_setup_bubble(_bubble, _bubble_label, _dish_icon, dish, dish.short_name)
	if topping != null:
		_setup_bubble(_top_bubble, _top_label, _top_icon, topping, UIText.ORDER_TOPPING % topping.short_name)
	_set_bubble_visible(false)
	_gauge_bg.hide()
	_popup_label.hide()
	_face_label.text = ""


func _setup_bubble(bubble: ColorRect, label: Label, icon: SpriteView, item: DishData, text: String) -> void:
	bubble.color = item.color
	label.text = text
	label.add_theme_font_size_override("font_size", UIUtil.fit_font_size(text, bubble.size.x - 2.0, 11))
	icon.sprite_key = SpriteKeys.dish(item.id)
	if icon.has_sprite():
		# 料理の絵があれば、吹き出しは白い背景にして絵を見せる
		bubble.color = UIColors.BIZ_BUBBLE_WITH_ICON
		bubble.position = icon.position
		bubble.size = icon.size
		label.hide()


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


## その料理・トッピングを、まだ待っているか
func needs_item(item_id: String) -> bool:
	if not is_waiting_food():
		return false
	if item_id == dish.id and not dish_served:
		return true
	return topping != null and item_id == topping.id and not topping_served


## まだ出していない料理・トッピングのid（料理が先）
func get_needed_items() -> Array[String]:
	var result: Array[String] = []
	if not is_waiting_food():
		return result
	if not dish_served:
		result.append(dish.id)
	if topping != null and not topping_served:
		result.append(topping.id)
	return result


## あと何秒くらいで席を立つか（売り切れのあとの売り逃しを数えるときの目安）
func get_estimated_stay() -> float:
	match state:
		State.WAITING_FOOD:
			return minf(maxf(0.0, type_data.patience - wait_elapsed), 8.0) + type_data.eat_time
		State.EATING:
			return maxf(0.0, type_data.eat_time - _state_time)
		State.LEAVING:
			return 0.0
	return _config.missed_stay_time


## 会計の金額（料理＋トッピング）
func get_total_price() -> int:
	return dish.price + (topping.price if topping != null else 0)


## 待ち時間の割合（0〜1）
func get_wait_ratio() -> float:
	return clampf(wait_elapsed / maxf(type_data.patience, 0.01), 0.0, 1.0)


## 料理かトッピングを受け取る。全部そろったら食べ始める（満足度は satisfaction）
func receive(item_id: String) -> Receive:
	if not needs_item(item_id):
		return Receive.WRONG
	if item_id == dish.id and not dish_served:
		dish_served = true
		_bubble.modulate.a = SERVED_ALPHA
		_dish_icon.modulate.a = SERVED_ALPHA
	else:
		topping_served = true
		_top_bubble.modulate.a = SERVED_ALPHA
		_top_icon.modulate.a = SERVED_ALPHA
	if not get_needed_items().is_empty():
		return Receive.PARTIAL
	satisfaction = Satisfaction.from_wait(wait_elapsed, type_data.patience, _config)
	state = State.EATING
	_state_time = 0.0
	_gauge_bg.hide()
	_top_bubble.hide()
	_top_icon.hide()
	_bubble.modulate.a = 1.0
	_dish_icon.modulate.a = 1.0
	_bubble_label.show()
	_bubble_label.text = UIText.EATING
	_bubble_label.add_theme_font_size_override("font_size", 11)
	_figure.animation = SpriteKeys.ANIM_EAT
	_face_label.text = UIText.SATISFACTION_MARKS[satisfaction]
	return Receive.COMPLETE


## 料理だけの注文を受け取る（トッピングなしの注文用。満足度を返す）
func serve() -> Satisfaction.Level:
	receive(dish.id)
	return satisfaction


func show_popup(text: String, color: Color = Color.WHITE) -> void:
	_popup_label.text = text
	_popup_label.modulate = color
	_popup_label.position = Vector2(-28, -60)
	_popup_label.show()
	var tween: Tween = create_tween()
	tween.tween_property(_popup_label, "position:y", -74.0, 0.8)
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
				show_popup(UIText.POPUP_PAID % UIText.money(get_total_price()), UIColors.BIZ_POPUP_PAID)
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
		_gauge_fill.color = UIColors.BIZ_GAUGE_OK
	elif ratio <= _config.good_ratio:
		_gauge_fill.color = UIColors.BIZ_GAUGE_WAIT
	else:
		_gauge_fill.color = UIColors.BIZ_GAUGE_DANGER


func _leave_angry() -> void:
	_face_label.text = UIText.SATISFACTION_MARKS[Satisfaction.Level.ANGRY]
	show_popup(UIText.POPUP_ANGRY, UIColors.BIZ_POPUP_ANGRY)
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
	_dish_icon.visible = on and _dish_icon.has_sprite()
	var show_top: bool = on and topping != null
	_top_bubble.visible = show_top
	_top_icon.visible = show_top and _top_icon.has_sprite()


## 絵は右向きで描くので、左へ歩くときは左右反転する
func _face_towards(target: Vector2) -> void:
	_figure.flip_h = target.x < position.x


func _walk_duration(from: Vector2, to: Vector2) -> float:
	return maxf(0.2, from.distance_to(to) / maxf(_config.walk_speed, 1.0))
