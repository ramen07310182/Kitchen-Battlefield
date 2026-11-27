class_name HallStaff
extends Control
## ホールスタッフ1人。置き場の前（待機場所）で待ち、StaffDispatcher の指示で
## 料理・トッピングを置き場から取り（pick_time 秒）、お客さんの席まで運ぶ。
## 1回に運べるのは、同じお客さんの料理とトッピング（最大2皿）。
## 自分では判断しない（どの料理を誰に運ぶか・運べなかったときどうするかは StaffDispatcher が決める）。
## 絵は staff/<id>.png（なければ図形で代用）。

## 置き場から料理を取り終えた
signal picked(staff: HallStaff)
## お客さんの席に着いた
signal arrived(staff: HallStaff)
## 待機場所に戻った
signal arrived_home(staff: HallStaff)

enum State {
	## 待機場所で手が空いている
	IDLE,
	## 置き場から料理を取っている（置き場の枠は予約中）
	PICKING,
	## 料理を持って、お客さんの席へ歩いている
	CARRYING,
	## 何も持たずに待機場所へ戻っている
	GOING_HOME,
	## 料理を持ったまま待機場所へ戻っている（運び先のお客さんが帰った）
	RETURNING,
	## 料理を持って、置き場が空くのを待っている
	WAITING_SHELF,
}

const SIZE := Vector2(24, 32)
## 1回に運べる皿の数
const MAX_CARRY := 2

var data: StaffData
var state: State = State.IDLE
## 取っている・運んでいる料理・トッピングのid（取っている間は slots と同じ順）
var items: Array[String] = []
## 予約している置き場の枠（取っている間だけ）
var slots: Array[int] = []
## 運び先のお客さん
var target: Customer = null
## 待機場所（客席エリアの座標。左上）
var home: Vector2 = Vector2.ZERO

var _pick_left: float = 0.0
var _tween: Tween

@onready var _figure: SpriteView = %Figure
@onready var _body: ColorRect = %Body
@onready var _carry_boxes: Array[ColorRect] = [%Carry, %Carry2]
@onready var _carry_labels: Array[Label] = [%CarryLabel, %CarryLabel2]


## add_child の後に呼ぶ
func setup(staff_data: StaffData, home_position: Vector2) -> void:
	data = staff_data
	home = home_position
	position = home
	_body.color = data.color
	_figure.set_sprite(SpriteKeys.staff(data.id), SpriteKeys.ANIM_IDLE)
	_show_items()


func is_idle() -> bool:
	return state == State.IDLE


## その料理を取りに行っている・運んでいるか
func is_handling(customer: Customer, item_id: String) -> bool:
	return target == customer and items.has(item_id) \
		and (state == State.PICKING or state == State.CARRYING)


## 待機場所が変わった（画面の大きさが変わったとき）。待機中ならその場所へ移す
func set_home(home_position: Vector2) -> void:
	home = home_position
	if state == State.IDLE or state == State.PICKING or state == State.WAITING_SHELF:
		position = home


## 置き場の枠（予約済み）の料理を取り始める（取り終えたら picked）
func begin_pick(pick_slots: Array[int], pick_items: Array[String], customer: Customer) -> void:
	state = State.PICKING
	slots = pick_slots.duplicate()
	items = pick_items.duplicate()
	target = customer
	_pick_left = data.pick_time
	_figure.animation = SpriteKeys.ANIM_IDLE


## 取った料理を持って、destination（客席エリアの座標）まで歩く（着いたら arrived）
func carry_to(carried: Array[String], destination: Vector2) -> void:
	state = State.CARRYING
	slots.clear()
	items = carried.duplicate()
	_show_items()
	_walk(destination, func() -> void: arrived.emit(self))


## 渡した料理を手から外す
func remove_item(item_id: String) -> void:
	items.erase(item_id)
	_show_items()


## 何も持たずに待機場所へ戻る（持っている料理が残っていれば、持ったまま戻る）
func go_home() -> void:
	target = null
	state = State.RETURNING if not items.is_empty() else State.GOING_HOME
	_walk(home, _on_home)


## 取るのをやめる（予約していた枠は StaffDispatcher が戻す）
func cancel_pick() -> void:
	state = State.IDLE
	slots.clear()
	items.clear()
	target = null


## 料理を1皿、置き場に返し終えた
func returned_item(item_id: String) -> void:
	items.erase(item_id)
	_show_items()
	if items.is_empty() and state == State.WAITING_SHELF:
		state = State.IDLE


func _process(delta: float) -> void:
	if state == State.PICKING:
		_pick_left -= delta
		if _pick_left <= 0.0:
			picked.emit(self)


func _on_home() -> void:
	_figure.animation = SpriteKeys.ANIM_IDLE
	_figure.flip_h = false
	state = State.WAITING_SHELF if not items.is_empty() else State.IDLE
	arrived_home.emit(self)


func _walk(destination: Vector2, on_done: Callable) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_figure.animation = SpriteKeys.ANIM_WALK
	_figure.flip_h = destination.x < position.x
	var duration: float = maxf(0.1, position.distance_to(destination) / maxf(data.walk_speed, 1.0))
	_tween = create_tween()
	_tween.tween_property(self, "position", destination, duration)
	_tween.finished.connect(on_done)


## 頭の上に、持っている料理の色と短い名前を出す（2皿なら2段）
func _show_items() -> void:
	for i: int in _carry_boxes.size():
		var shown: bool = state != State.PICKING and i < items.size()
		var item: DishData = Database.get_dish(items[i]) if shown else null
		_carry_boxes[i].visible = item != null
		if item != null:
			_carry_boxes[i].color = item.color
			_carry_labels[i].text = item.short_name
			_carry_labels[i].add_theme_font_size_override("font_size",
				UIUtil.fit_font_size(item.short_name, _carry_boxes[i].size.x - 2.0, 10))
