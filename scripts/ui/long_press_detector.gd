class_name LongPressDetector
extends Node
## 親の Control（一覧の行など）の長押しを見つける。指でもマウスの左ボタンでも同じ（ホバーでは反応しない）。
## 押し続けて game_config の long_press_time 秒たつと long_pressed、そのあと離すと finished を出す。
## 押している間に一定の距離（scroll_drag_threshold）以上動いたら取り消す（一覧のスクロールを優先する）。
## 子のボタンを押したときは、ボタンが入力を受け取るので反応しない。

signal long_pressed
## 長押しで出したもの（詳細など）を閉じる合図。指を離したか、取り消されたとき
signal finished

var _target: Control
var _pressing: bool = false
var _shown: bool = false
var _time: float = 0.0
var _start_pos: Vector2 = Vector2.ZERO


func _ready() -> void:
	_target = get_parent() as Control
	_target.gui_input.connect(_on_gui_input)
	set_process(false)


func is_showing() -> bool:
	return _shown


func _on_gui_input(event: InputEvent) -> void:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
		if mb.pressed:
			_pressing = true
			_shown = false
			_time = 0.0
			_start_pos = mb.position
			set_process(true)
		else:
			_end()
		return
	var mm: InputEventMouseMotion = event as InputEventMouseMotion
	if mm != null and _pressing and not _shown:
		if mm.position.distance_to(_start_pos) >= Database.config.scroll_drag_threshold:
			_end()


func _process(delta: float) -> void:
	if not _pressing:
		set_process(false)
		return
	_time += delta
	if not _shown and _time >= Database.config.long_press_time:
		_shown = true
		long_pressed.emit()


func _end() -> void:
	var was_shown: bool = _shown
	_pressing = false
	_shown = false
	set_process(false)
	if was_shown:
		finished.emit()
