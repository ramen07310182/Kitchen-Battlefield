class_name StaffShiftPanel
extends PanelContainer
## 準備画面③の「今日のスタッフ」。雇っているスタッフごとに、名前と研修のレベル・退職までの残りの日数・
## 出勤／休み・出られない理由を出す。
## 出勤／休みのボタンで切り替える（はじめは前回と同じ）。出られない日（固定の休み・急な休み）は休みのまま押せない。
## 退職が近いスタッフ（残りが game_config の staff_retire_notice_days より少ない）には、退職の予告を出す。

signal notice_requested(text: String)

var _title_label: Label
var _rows_box: VBoxContainer
var _notices_box: VBoxContainer
var _buttons: Dictionary = {}  # 従業員id -> Button


func _init() -> void:
	add_theme_stylebox_override("panel", UIColors.panel_box(UIColors.PANEL))
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	add_child(vbox)
	_title_label = Label.new()
	_title_label.theme_type_variation = &"HeaderLabel"
	vbox.add_child(_title_label)
	_rows_box = VBoxContainer.new()
	_rows_box.add_theme_constant_override("separation", 3)
	vbox.add_child(_rows_box)
	_notices_box = VBoxContainer.new()
	_notices_box.add_theme_constant_override("separation", 0)
	vbox.add_child(_notices_box)


## 雇っているスタッフの行を作り直す
func rebuild() -> void:
	for child: Node in _rows_box.get_children():
		child.queue_free()
	_buttons.clear()
	if GameState.hired_staff.is_empty():
		var none: Label = Label.new()
		none.text = UIText.PREP_STAFF_NONE
		none.theme_type_variation = &"SmallLabel"
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		none.add_theme_color_override("font_color", UIColors.TEXT_SUB)
		_rows_box.add_child(none)
	for data: StaffData in GameState.get_hired_staff():
		_rows_box.add_child(_make_row(data))
	refresh()


func _make_row(data: StaffData) -> Control:
	var row: PanelContainer = PanelContainer.new()
	row.add_theme_stylebox_override("panel", UIColors.card_box())
	row.name = data.id
	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	row.add_child(hbox)
	var texts: VBoxContainer = VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", -2)
	hbox.add_child(texts)
	var line: HBoxContainer = HBoxContainer.new()
	line.add_theme_constant_override("separation", 8)
	texts.add_child(line)
	var name_label: Label = Label.new()
	name_label.name = "NameLabel"
	line.add_child(name_label)
	var days_label: Label = Label.new()
	days_label.name = "DaysLabel"
	days_label.theme_type_variation = &"SmallLabel"
	days_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(days_label)
	var status: Label = Label.new()
	status.name = "StatusLabel"
	status.theme_type_variation = &"SmallLabel"
	status.clip_text = true
	status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	status.custom_minimum_size = Vector2(80, 0)
	texts.add_child(status)
	var button: Button = Button.new()
	button.custom_minimum_size = Vector2(60, 36)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(_on_toggle.bind(data.id))
	hbox.add_child(button)
	_buttons[data.id] = button
	return row


func refresh() -> void:
	var working: Array[StaffData] = GameState.get_working_staff()
	var wage: int = 0
	for data: StaffData in working:
		wage += GameState.get_staff_wage(data)
	_title_label.text = UIText.PREP_STAFF_TITLE % [working.size(), GameState.hired_staff.size(), UIText.money(wage)]
	for data: StaffData in GameState.get_hired_staff():
		var row: Node = _rows_box.get_node_or_null(NodePath(data.id))
		if row == null:
			continue
		var name_label: Label = row.find_child("NameLabel", true, false) as Label
		name_label.text = UIText.PREP_STAFF_NAME % [data.display_name, GameState.get_staff_level(data.id)]
		var days_label: Label = row.find_child("DaysLabel", true, false) as Label
		days_label.text = UIText.PREP_STAFF_DAYS_LEFT % GameState.get_staff_days_left(data.id)
		days_label.add_theme_color_override("font_color",
			UIColors.DANGER if GameState.is_staff_retiring_soon(data.id) else UIColors.TEXT_SUB)
		var status: Label = row.find_child("StatusLabel", true, false) as Label
		var button: Button = _buttons[data.id]
		var absence: String = GameState.get_staff_absence(data.id)
		if absence == "fixed":
			status.text = UIText.PREP_STAFF_OFF_FIXED % UIText.weekday_list(data.days_off)
			status.add_theme_color_override("font_color", UIColors.TEXT_SUB)
		elif absence == "sudden":
			status.text = UIText.PREP_STAFF_OFF_SUDDEN
			status.add_theme_color_override("font_color", UIColors.WARNING)
		else:
			status.text = UIText.PREP_STAFF_WAGE % UIText.money(GameState.get_staff_wage(data))
			status.add_theme_color_override("font_color", UIColors.TEXT_SUB)
		var on: bool = GameState.is_on_shift(data.id)
		button.text = UIText.PREP_STAFF_ON if on else UIText.PREP_STAFF_OFF
		button.disabled = absence != ""
		UIColors.apply_toggle_style(button, on)
	# 退職の予告
	for child: Node in _notices_box.get_children():
		child.queue_free()
	for data: StaffData in GameState.get_hired_staff():
		if not GameState.is_staff_retiring_soon(data.id):
			continue
		var days_left: int = GameState.get_staff_days_left(data.id)
		var label: Label = Label.new()
		label.theme_type_variation = &"SmallLabel"
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.text = UIText.PREP_STAFF_RETIRE_TODAY % data.display_name if days_left <= 1 \
			else UIText.PREP_STAFF_RETIRE_NOTICE % [data.display_name, days_left]
		label.add_theme_color_override("font_color", UIColors.DANGER)
		_notices_box.add_child(label)


func _on_toggle(staff_id: String) -> void:
	notice_requested.emit("")
	GameState.set_shift(staff_id, not GameState.is_on_shift(staff_id))
	refresh()
