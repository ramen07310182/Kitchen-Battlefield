class_name StaffRow
extends PanelContainer
## 強化画面の「従業員」の1行: 名前・配膳の速さ・毎週の休み・日給と「雇う」ボタン。
## 雇っている人には機嫌を出す（プレイヤーからは辞めさせられないので「やめてもらう」はない）。
## 雇えないとき（ランクの人数の上限）は、ボタンを押せなくして理由を出す。ボタン以外の所を長押しで詳細。

signal hire_requested(staff_id: String)
signal detail_requested(staff_id: String)
signal detail_closed

var staff: StaffData

var _icon: TextureRect
var _name_label: Label
var _speed_label: Label
var _wage_label: Label
var _note_label: Label
var _button: Button


func _init() -> void:
	add_theme_stylebox_override("panel", UIColors.card_box())
	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	add_child(hbox)
	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(24, 32)
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(_icon)
	var texts: VBoxContainer = VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 0)
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(texts)
	_name_label = Label.new()
	texts.add_child(_name_label)
	_speed_label = Label.new()
	_speed_label.theme_type_variation = &"SmallLabel"
	_speed_label.add_theme_color_override("font_color", UIColors.TEXT_SUB)
	texts.add_child(_speed_label)
	var right: VBoxContainer = VBoxContainer.new()
	right.custom_minimum_size = Vector2(150, 0)
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(right)
	_wage_label = Label.new()
	_wage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(_wage_label)
	_note_label = Label.new()
	_note_label.theme_type_variation = &"SmallLabel"
	_note_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(_note_label)
	_button = Button.new()
	_button.custom_minimum_size = Vector2(96, 40)
	_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_button.text = UIText.UPGRADE_STAFF_HIRE
	_button.pressed.connect(func() -> void: hire_requested.emit(staff.id))
	hbox.add_child(_button)
	var long_press: LongPressDetector = LongPressDetector.new()
	add_child(long_press)
	long_press.long_pressed.connect(func() -> void: detail_requested.emit(staff.id))
	long_press.finished.connect(detail_closed.emit)


func setup(data: StaffData) -> void:
	staff = data
	# 絵（assets/sprites/staff/<id>.png）があれば絵、なければ色の四角
	var icon: Texture2D = SpriteLibrary.get_icon(SpriteKeys.staff(data.id))
	_icon.texture = icon if icon != null else UIUtil.color_icon(data.color, 16)
	_name_label.text = data.display_name
	_speed_label.text = "%s　%s" % [UIText.UPGRADE_STAFF_SPEED % [StaffRow.speed_name(data), data.pick_time], StaffRow.days_off_text(data)]
	_wage_label.text = UIText.UPGRADE_STAFF_WAGE % UIText.money(data.daily_wage)


func refresh() -> void:
	if GameState.is_hired(staff.id):
		var level: StaffMood.Level = GameState.get_staff_mood_level(staff.id)
		_button.visible = false
		_note_label.text = UIText.UPGRADE_STAFF_HIRED % ("%s %s" % [UIText.STAFF_MOOD_MARKS[level], UIText.STAFF_MOOD_NAMES[level]])
		_note_label.add_theme_color_override("font_color", UIColors.STAFF_MOOD[level])
		return
	_button.visible = true
	_button.disabled = not GameState.can_hire(staff.id)
	if GameState.can_hire(staff.id):
		_note_label.text = ""
	elif GameState.get_staff_limit() <= 0:
		_note_label.text = UIText.UPGRADE_STAFF_NEED_RANK % Database.get_rank_name(StaffRow.first_rank_with_staff())
		_note_label.add_theme_color_override("font_color", UIColors.DANGER)
	else:
		_note_label.text = UIText.UPGRADE_STAFF_FULL
		_note_label.add_theme_color_override("font_color", UIColors.DANGER)


## 詳細（長押し）の行
static func detail_lines(data: StaffData) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	lines.append(UIText.UPGRADE_STAFF_DETAIL_SPEED % [StaffRow.speed_name(data), roundi(data.walk_speed), data.pick_time])
	lines.append(UIText.UPGRADE_STAFF_DETAIL_WAGE % UIText.money(data.daily_wage))
	lines.append(UIText.UPGRADE_STAFF_DETAIL_DAYS_OFF % UIText.weekday_list(data.days_off))
	lines.append(UIText.UPGRADE_STAFF_DETAIL_ABSENCE % roundi(data.absence_rate * 100.0))
	if GameState.is_hired(data.id):
		var level: StaffMood.Level = GameState.get_staff_mood_level(data.id)
		lines.append(UIText.UPGRADE_STAFF_DETAIL_MOOD % [UIText.STAFF_MOOD_MARKS[level], UIText.STAFF_MOOD_NAMES[level]])
	else:
		lines.append(UIText.UPGRADE_STAFF_DETAIL_NOT_HIRED)
	return lines


static func days_off_text(data: StaffData) -> String:
	return UIText.UPGRADE_STAFF_DAYS_OFF % UIText.weekday_list(data.days_off) if not data.days_off.is_empty() \
		else UIText.UPGRADE_STAFF_NO_DAYS_OFF


## 歩く速さの呼び方（ゆっくり・ふつう・速い・とても速い）
static func speed_name(data: StaffData) -> String:
	if data.walk_speed < 105.0:
		return UIText.UPGRADE_STAFF_SPEED_NAMES[0]
	if data.walk_speed < 135.0:
		return UIText.UPGRADE_STAFF_SPEED_NAMES[1]
	if data.walk_speed < 165.0:
		return UIText.UPGRADE_STAFF_SPEED_NAMES[2]
	return UIText.UPGRADE_STAFF_SPEED_NAMES[3]


## 従業員を雇えるようになる最初のランク
static func first_rank_with_staff() -> int:
	for r: int in range(1, Database.get_max_rank() + 1):
		if Database.get_staff_limit(r) > 0:
			return r
	return Database.get_max_rank()
