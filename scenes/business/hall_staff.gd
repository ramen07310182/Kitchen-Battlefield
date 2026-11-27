class_name HallStaff
extends Control
## ホールスタッフ1人。置き場の前（待機場所）で待ち、StaffDispatcher の指示で
## 料理・トッピングを置き場から取り（pick_time 秒）、お客さんの席まで運ぶ。
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

var data: StaffData
var state: State = State.IDLE
## 運んでいる（取っている）料理・トッピングのid
var item_id: String = ""
## 取っている置き場の枠
var slot_index: int = -1
## 運び先のお客さん
var target: Customer = null
## 待機場所（客席エリアの座標。左上）
var home: Vector2 = Vector2.ZERO

var _pick_left: float = 0.0
var _tween: Tween

@onready var _figure: SpriteView = %Figure
@onready var _body: ColorRect = %Body
@onready var _carry: ColorRect = %Carry
@onready var _carry_label: Label = %CarryLabel


## add_child の後に呼ぶ
func setup(staff_data: StaffData, home_position: Vector2) -> void:
	data = staff_data
	home = home_position
	position = home
	_body.color = data.color
	_figure.set_sprite(SpriteKeys.staff(data.id), SpriteKeys.ANIM_IDLE)
	_set_item("")


func is_idle() -> bool:
	return state == State.IDLE


## 料理（またはトッピング）を持っているか
func is_holding_item() -> bool:
	return state == State.CARRYING or state == State.RETURNING or state == State.WAITING_SHELF


## 待機場所が変わった（画面の大きさが変わったとき）。待機中ならその場所へ移す
func set_home(home_position: Vector2) -> void:
	home = home_position
	if state == State.IDLE or state == State.PICKING or state == State.WAITING_SHELF:
		position = home


## 置き場の slot の料理を取り始める（取り終えたら picked）
func begin_pick(slot: int, item: String, customer: Customer) -> void:
	state = State.PICKING
	slot_index = slot
	item_id = item
	target = customer
	_pick_left = data.pick_time
	_figure.animation = SpriteKeys.ANIM_IDLE


## 取った料理を持って、destination（客席エリアの座標）まで歩く（着いたら arrived）
func carry_to(destination: Vector2) -> void:
	state = State.CARRYING
	slot_index = -1
	_set_item(item_id)
	_walk(destination, func() -> void: arrived.emit(self))


## 料理を渡し終えたので、何も持たずに待機場所へ戻る
func go_home() -> void:
	state = State.GOING_HOME
	target = null
	_set_item("")
	_walk(home, _on_home)


## 料理を持ったまま待機場所へ戻る（戻ったら置き場に返す）
func return_with_item() -> void:
	state = State.RETURNING
	target = null
	_walk(home, _on_home)


## 取るのをやめる（予約していた枠は StaffDispatcher が戻す）
func cancel_pick() -> void:
	state = State.IDLE
	slot_index = -1
	item_id = ""
	target = null


## 置き場に返し終えた
func clear_item() -> void:
	item_id = ""
	target = null
	_set_item("")
	if state == State.WAITING_SHELF:
		state = State.IDLE


func _process(delta: float) -> void:
	if state == State.PICKING:
		_pick_left -= delta
		if _pick_left <= 0.0:
			picked.emit(self)


func _on_home() -> void:
	_figure.animation = SpriteKeys.ANIM_IDLE
	_figure.flip_h = false
	state = State.WAITING_SHELF if item_id != "" else State.IDLE
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


## 頭の上に、持っている料理の色と短い名前を出す
func _set_item(id: String) -> void:
	var item: DishData = Database.get_dish(id) if id != "" else null
	_carry.visible = item != null
	if item != null:
		_carry.color = item.color
		_carry_label.text = item.short_name
		_carry_label.add_theme_font_size_override("font_size", UIUtil.fit_font_size(item.short_name, _carry.size.x - 2.0, 10))
