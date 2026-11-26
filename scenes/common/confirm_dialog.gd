class_name ConfirmDialog
extends Control
## 画面の上に重ねる確認ダイアログ（「OK」「やめる」の2択。必要なら3つめの選択肢も出せる）。
## 開いている間は後ろの画面を押せない。ask() で開き、answered（または alt_chosen）で結果を知らせる。

signal answered(ok: bool)
## 3つめの選択肢（alt_text）を押した
signal alt_chosen

@onready var _panel: PanelContainer = %Panel
@onready var _message_label: Label = %MessageLabel
@onready var _ok_button: Button = %OkButton
@onready var _cancel_button: Button = %CancelButton
@onready var _alt_button: Button = %AltButton


func _ready() -> void:
	var box: StyleBoxFlat = UIUtil.flat_box(Color(0.16, 0.14, 0.13), Color(0.85, 0.75, 0.55), 2, 4)
	box.set_content_margin_all(14)
	_panel.add_theme_stylebox_override("panel", UISkin.panel_box(SpriteKeys.PANEL, box))
	_ok_button.pressed.connect(_answer.bind(true))
	_cancel_button.pressed.connect(_answer.bind(false))
	_alt_button.pressed.connect(_on_alt_pressed)
	hide()


func ask(message: String, ok_text: String, cancel_text: String, alt_text: String = "") -> void:
	_message_label.text = message
	_ok_button.text = ok_text
	_cancel_button.text = cancel_text
	_alt_button.text = alt_text
	_alt_button.visible = alt_text != ""
	show()


func _on_alt_pressed() -> void:
	if not visible:
		return
	hide()
	alt_chosen.emit()


func is_open() -> bool:
	return visible


func _answer(ok: bool) -> void:
	if not visible:
		return
	hide()
	answered.emit(ok)
