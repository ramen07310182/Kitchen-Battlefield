class_name ConfirmDialog
extends Control
## 画面の上に重ねる確認ダイアログ（「OK」「やめる」の2択）。
## 開いている間は後ろの画面を押せない。ask() で開き、answered で結果を知らせる。

signal answered(ok: bool)

@onready var _panel: PanelContainer = %Panel
@onready var _message_label: Label = %MessageLabel
@onready var _ok_button: Button = %OkButton
@onready var _cancel_button: Button = %CancelButton


func _ready() -> void:
	var box: StyleBoxFlat = UIUtil.flat_box(Color(0.16, 0.14, 0.13), Color(0.85, 0.75, 0.55), 2, 4)
	box.set_content_margin_all(14)
	_panel.add_theme_stylebox_override("panel", UISkin.panel_box(SpriteKeys.PANEL, box))
	_ok_button.pressed.connect(_answer.bind(true))
	_cancel_button.pressed.connect(_answer.bind(false))
	hide()


func ask(message: String, ok_text: String, cancel_text: String) -> void:
	_message_label.text = message
	_ok_button.text = ok_text
	_cancel_button.text = cancel_text
	show()


func is_open() -> bool:
	return visible


func _answer(ok: bool) -> void:
	if not visible:
		return
	hide()
	answered.emit(ok)
