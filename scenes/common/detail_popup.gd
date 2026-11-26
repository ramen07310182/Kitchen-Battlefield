class_name DetailPopup
extends Control
## 長押しで出す詳細のポップアップ。行を押している指を離すか、ポップアップの外をタップすると閉じる。
## 押している指と重ならないよう、押した行と反対側の半分（左右）に出す。

## 出す位置
enum Placement { LEFT, RIGHT }

const MARGIN := 8.0

@onready var _catcher: Control = %Catcher
@onready var _panel: PanelContainer = %Panel
@onready var _title_label: Label = %TitleLabel
@onready var _body_label: Label = %BodyLabel


func _ready() -> void:
	var box: StyleBoxFlat = UIUtil.flat_box(Color(0.1, 0.09, 0.09, 0.96), Color(0.85, 0.75, 0.55), 2, 4)
	box.set_content_margin_all(8)
	_panel.add_theme_stylebox_override("panel", box)
	_catcher.gui_input.connect(_on_catcher_input)
	hide()


## 外をタップしたら閉じる
func _on_catcher_input(event: InputEvent) -> void:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null and mb.pressed:
		close()


## title: 見出し、lines: 1行ずつの説明、side: 出す位置（押した行と反対側）
func open(title: String, lines: PackedStringArray, side: Placement) -> void:
	_title_label.text = title
	_body_label.text = "\n".join(lines)
	show()
	# 中身の大きさが決まってから位置を合わせる
	_panel.reset_size()
	await get_tree().process_frame
	if not visible:
		return
	_panel.reset_size()
	var area: Vector2 = size
	var panel_size: Vector2 = _panel.size
	var x: float = MARGIN if side == Placement.LEFT else area.x - panel_size.x - MARGIN
	var y: float = clampf((area.y - panel_size.y) * 0.5, MARGIN, maxf(MARGIN, area.y - panel_size.y - MARGIN))
	_panel.position = Vector2(x, y).round()


func close() -> void:
	hide()


func is_open() -> bool:
	return visible
