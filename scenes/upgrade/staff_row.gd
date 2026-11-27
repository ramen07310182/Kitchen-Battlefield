class_name StaffRow
extends PanelContainer
## 強化画面の「従業員」の1行: 名前・配膳の速さ・日給と、「雇う」または「やめてもらう」のボタン。
## 雇えないとき（ランクの人数の上限）は、ボタンを押せなくして理由を出す。

signal hire_requested(staff_id: String)
signal dismiss_requested(staff_id: String)

const COLOR_OK := Color(0.85, 0.85, 0.85)
const COLOR_BLOCKED := Color(1.0, 0.5, 0.45)
const COLOR_HIRED := Color(0.6, 1.0, 0.6)

var staff: StaffData

var _icon: TextureRect
var _name_label: Label
var _speed_label: Label
var _wage_label: Label
var _note_label: Label
var _button: Button


func _init() -> void:
	add_theme_stylebox_override("panel", UIUtil.flat_box(Color(0.2, 0.17, 0.15)))
	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	add_child(hbox)
	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(24, 32)
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(_icon)
	var texts: VBoxContainer = VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 0)
	hbox.add_child(texts)
	_name_label = Label.new()
	texts.add_child(_name_label)
	_speed_label = Label.new()
	_speed_label.theme_type_variation = &"SmallLabel"
	_speed_label.modulate = COLOR_OK
	texts.add_child(_speed_label)
	var right: VBoxContainer = VBoxContainer.new()
	right.custom_minimum_size = Vector2(150, 0)
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_child(right)
	_wage_label = Label.new()
	_wage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(_wage_label)
	_note_label = Label.new()
	_note_label.theme_type_variation = &"SmallLabel"
	_note_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_note_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(_note_label)
	_button = Button.new()
	_button.custom_minimum_size = Vector2(96, 40)
	_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_button.pressed.connect(_on_pressed)
	hbox.add_child(_button)


func setup(data: StaffData) -> void:
	staff = data
	# 絵（assets/sprites/staff/<id>.png）があれば絵、なければ色の四角
	var icon: Texture2D = SpriteLibrary.get_icon(SpriteKeys.staff(data.id))
	_icon.texture = icon if icon != null else UIUtil.color_icon(data.color, 16)
	_name_label.text = data.display_name
	_speed_label.text = UIText.UPGRADE_STAFF_SPEED % [StaffRow.speed_name(data), data.pick_time]
	_wage_label.text = UIText.UPGRADE_STAFF_WAGE % UIText.money(data.daily_wage)


func refresh() -> void:
	var hired: bool = GameState.is_hired(staff.id)
	if hired:
		_button.text = UIText.UPGRADE_STAFF_DISMISS
		_button.disabled = false
		_note_label.text = UIText.UPGRADE_STAFF_HIRED
		_note_label.modulate = COLOR_HIRED
		return
	_button.text = UIText.UPGRADE_STAFF_HIRE
	_button.disabled = not GameState.can_hire(staff.id)
	if GameState.can_hire(staff.id):
		_note_label.text = ""
	elif GameState.get_staff_limit() <= 0:
		_note_label.text = UIText.UPGRADE_STAFF_NEED_RANK % Database.get_rank_name(StaffRow.first_rank_with_staff())
		_note_label.modulate = COLOR_BLOCKED
	else:
		_note_label.text = UIText.UPGRADE_STAFF_FULL
		_note_label.modulate = COLOR_BLOCKED


func _on_pressed() -> void:
	if GameState.is_hired(staff.id):
		dismiss_requested.emit(staff.id)
	else:
		hire_requested.emit(staff.id)


## 歩く速さの呼び方（ゆっくり・ふつう・速い・とても速い）
static func speed_name(data: StaffData) -> String:
	if data.walk_speed < 60.0:
		return UIText.UPGRADE_STAFF_SPEED_NAMES[0]
	if data.walk_speed < 85.0:
		return UIText.UPGRADE_STAFF_SPEED_NAMES[1]
	if data.walk_speed < 110.0:
		return UIText.UPGRADE_STAFF_SPEED_NAMES[2]
	return UIText.UPGRADE_STAFF_SPEED_NAMES[3]


## 従業員を雇えるようになる最初のランク
static func first_rank_with_staff() -> int:
	for r: int in range(1, Database.get_max_rank() + 1):
		if Database.get_staff_limit(r) > 0:
			return r
	return Database.get_max_rank()
