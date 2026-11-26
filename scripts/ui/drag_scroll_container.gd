class_name DragScrollContainer
extends ScrollContainer
## 縦にスクロールする一覧。指でなぞっても、PCのマウスのドラッグ・ホイールでもスクロールできる。
## 押してから一定の距離（game_config の scroll_drag_threshold）以上動いたらスクロールとして扱い、
## 中のボタンの押下や行の長押しを取り消す（離しても押したことにならない）。
## 一覧のスクロールは、CLAUDE.md の「ドラッグ前提の操作にしない」の例外。

## スクロールが始まった（中の長押しなどを取り消すときの目印）
signal drag_started

const BAR_WIDTH := 4.0
const BAR_COLOR := Color(1, 1, 1, 0.35)
const BAR_BG_COLOR := Color(1, 1, 1, 0.06)

var _tracking: bool = false
var _dragging: bool = false
var _start_pos: Vector2 = Vector2.ZERO
var _start_scroll: float = 0.0
## 押下の取り消し用に自分で送った入力を、自分で処理しないための印
var _sending_cancel: bool = false


func _ready() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	# スクロールできることがわかるように、端に細いスクロールバーを出す
	var bar: VScrollBar = get_v_scroll_bar()
	var grabber: StyleBoxFlat = UIUtil.flat_box(BAR_COLOR, Color.TRANSPARENT, 0, 2)
	grabber.set_content_margin_all(0)
	grabber.content_margin_left = BAR_WIDTH * 0.5
	grabber.content_margin_right = BAR_WIDTH * 0.5
	var track: StyleBoxFlat = UIUtil.flat_box(BAR_BG_COLOR, Color.TRANSPARENT, 0, 2)
	track.set_content_margin_all(0)
	track.content_margin_left = BAR_WIDTH * 0.5
	track.content_margin_right = BAR_WIDTH * 0.5
	bar.add_theme_stylebox_override("scroll", track)
	bar.add_theme_stylebox_override("scroll_focus", track)
	bar.add_theme_stylebox_override("grabber", grabber)
	bar.add_theme_stylebox_override("grabber_highlight", grabber)
	bar.add_theme_stylebox_override("grabber_pressed", grabber)
	bar.custom_minimum_size.x = BAR_WIDTH
	add_theme_constant_override("scrollbar_h_separation", 2)


func is_dragging() -> bool:
	return _dragging


func _input(event: InputEvent) -> void:
	if _sending_cancel or not is_visible_in_tree():
		return
	var cfg: GameConfig = Database.config
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null:
		var local: Vector2 = (make_input_local(mb) as InputEventMouseButton).position
		var inside: bool = Rect2(Vector2.ZERO, size).has_point(local)
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if inside and mb.pressed and _can_scroll():
				var dir: float = -1.0 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0
				scroll_vertical = int(scroll_vertical + dir * cfg.scroll_wheel_step * maxf(mb.factor, 1.0))
				get_viewport().set_input_as_handled()
			return
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_tracking = inside
			_dragging = false
			_start_pos = local
			_start_scroll = float(scroll_vertical)
		else:
			if _dragging:
				# スクロールした指を離しただけなので、ボタンには届けない
				get_viewport().set_input_as_handled()
			_tracking = false
			_dragging = false
		return

	var mm: InputEventMouseMotion = event as InputEventMouseMotion
	if mm == null or not _tracking:
		return
	if (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
		_tracking = false
		_dragging = false
		return
	var pos: Vector2 = (make_input_local(mm) as InputEventMouseMotion).position
	var delta: Vector2 = pos - _start_pos
	if not _dragging:
		if delta.length() < cfg.scroll_drag_threshold or not _can_scroll():
			return
		_dragging = true
		_cancel_child_press()
		drag_started.emit()
	scroll_vertical = int(_start_scroll - delta.y)
	get_viewport().set_input_as_handled()


func _can_scroll() -> bool:
	var bar: VScrollBar = get_v_scroll_bar()
	return bar.max_value - bar.page > 0.5


## 押している最中のボタン・行に「指が外へ出て離れた」入力を送り、押下と長押しを取り消す
func _cancel_child_press() -> void:
	var far: Vector2 = Vector2(-100000, -100000)
	_sending_cancel = true
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = far
	motion.global_position = far
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	get_viewport().push_input(motion)
	var release: InputEventMouseButton = InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = far
	release.global_position = far
	get_viewport().push_input(release)
	_sending_cancel = false
