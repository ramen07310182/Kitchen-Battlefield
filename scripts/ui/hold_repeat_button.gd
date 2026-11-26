class_name HoldRepeatButton
extends Button
## 押すと1回、押し続けるとくり返し step_requested を出すボタン（「－＋」用）。
## 長く押し続けると、1回に進む数が増える（すばやく99まで増やせる）。タップと長押しだけで使える。

## direction × 個数 を知らせる（例: ＋ボタンなら +1、長押しを続けると +5）
signal step_requested(step: int)

## +1 なら増やすボタン、-1 なら減らすボタン
@export var direction: int = 1

var _held: bool = false
var _held_time: float = 0.0
var _next_repeat: float = 0.0


func _ready() -> void:
	button_down.connect(_on_button_down)
	button_up.connect(_stop)
	set_process(false)


func _on_button_down() -> void:
	_held = true
	_held_time = 0.0
	_next_repeat = Database.config.hold_repeat_delay
	set_process(true)
	step_requested.emit(direction)


func _stop() -> void:
	_held = false
	set_process(false)


func _process(delta: float) -> void:
	if not _held or disabled or not is_pressed():
		_stop()
		return
	var cfg: GameConfig = Database.config
	_held_time += delta
	while _held_time >= _next_repeat:
		_next_repeat += cfg.hold_repeat_interval
		var amount: int = cfg.hold_fast_step if _held_time >= cfg.hold_fast_after else 1
		step_requested.emit(direction * amount)
