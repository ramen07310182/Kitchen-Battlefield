class_name CalendarPopup
extends Control
## 月ごとのカレンダー。各日のマスにその日の利益を出す（プラスは青、マイナスは赤、0は灰色）。
## 定休日（水曜日）は灰色で「定休」。今日（これから営業する日）は枠で目立たせ、まだ来ていない日は空欄。
## 左右の矢印で前後の月へ（2027年1月より前と、今日の翌月より先には行けない）。日付を押すと、その日の結果の要約を出す。

const CELL_SIZE := Vector2(58, 34)
const COLOR_PLUS := UIColors.PLUS
const COLOR_MINUS := UIColors.DANGER
const COLOR_ZERO := UIColors.ZERO
const COLOR_HOLIDAY := UIColors.CAL_HOLIDAY
const COLOR_CELL := UIColors.CAL_CELL
const COLOR_CELL_EMPTY := UIColors.CAL_CELL_EMPTY
const COLOR_TODAY_BORDER := UIColors.CAL_TODAY_BORDER

var _year: int = GameCalendar.START_YEAR
var _month: int = GameCalendar.START_MONTH

@onready var _panel: PanelContainer = %Panel
@onready var _prev_button: Button = %PrevButton
@onready var _next_button: Button = %NextButton
@onready var _month_label: Label = %MonthLabel
@onready var _total_label: Label = %TotalLabel
@onready var _close_button: Button = %CloseButton
@onready var _weekdays: GridContainer = %Weekdays
@onready var _grid: GridContainer = %Grid
@onready var _detail_label: Label = %DetailLabel


func _ready() -> void:
	($Dim as ColorRect).color = UIColors.DIM
	var box: StyleBoxFlat = UIUtil.flat_box(UIColors.PANEL, UIColors.ACCENT, 2, 6)
	box.set_content_margin_all(8)
	_panel.add_theme_stylebox_override("panel", box)
	_close_button.text = UIText.CAL_CLOSE
	_prev_button.pressed.connect(func() -> void: _move_month(-1))
	_next_button.pressed.connect(func() -> void: _move_month(1))
	_close_button.pressed.connect(hide)
	for i: int in 7:
		var label: Label = Label.new()
		label.text = UIText.WEEKDAYS[i]
		label.custom_minimum_size = Vector2(CELL_SIZE.x, 0)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.theme_type_variation = &"SmallLabel"
		label.add_theme_color_override("font_color", COLOR_HOLIDAY if i == GameCalendar.HOLIDAY_WEEKDAY else UIColors.TEXT_SUB)
		_weekdays.add_child(label)
	hide()


## 今日の月を開く
func open() -> void:
	var today: Dictionary = GameCalendar.date_for_business_day(GameState.day)
	_year = int(today["year"])
	_month = int(today["month"])
	_detail_label.text = UIText.CAL_HINT
	_rebuild()
	show()


func is_open() -> bool:
	return visible


func get_month() -> Vector2i:
	return Vector2i(_year, _month)


func _move_month(step: int) -> void:
	var index: int = _year * 12 + (_month - 1) + step
	if index < _min_index() or index > _max_index():
		return
	_year = index / 12
	_month = index % 12 + 1
	_detail_label.text = UIText.CAL_HINT
	_rebuild()


func _min_index() -> int:
	return GameCalendar.START_YEAR * 12 + (GameCalendar.START_MONTH - 1)


## 今日の翌月まで
func _max_index() -> int:
	var today: Dictionary = GameCalendar.date_for_business_day(GameState.day)
	return int(today["year"]) * 12 + int(today["month"]) - 1 + 1


func _rebuild() -> void:
	for child: Node in _grid.get_children():
		child.queue_free()
	_month_label.text = UIText.CAL_TITLE % [_year, _month]
	var index: int = _year * 12 + _month - 1
	_prev_button.disabled = index <= _min_index()
	_next_button.disabled = index >= _max_index()

	var first_offset: int = GameCalendar.offset_for_date(_year, _month, 1)
	var first_weekday: int = int(GameCalendar.date_for_offset(first_offset)["weekday"])
	var days: int = GameCalendar.days_in_month(_year, _month)
	for i: int in first_weekday:
		_grid.add_child(_make_blank())
	var total: int = 0
	for d: int in range(1, days + 1):
		var offset: int = first_offset + d - 1
		var cell: Dictionary = describe_offset(offset)
		if cell["kind"] == "done":
			total += int(cell["profit"])
		_grid.add_child(_make_cell(d, offset, cell))
	_total_label.text = UIText.CAL_MONTH_TOTAL % _signed_money(total)
	_total_label.add_theme_color_override("font_color", _profit_color(total))


## その日のマスの中身。kind: "before"（開店前）/"holiday"/"done"（営業済み）/"no_record"/"today"/"future"
static func describe_offset(offset: int) -> Dictionary:
	var business_day: int = GameCalendar.business_day_for_offset(offset)
	if business_day < 0:
		return { "kind": "before" }
	if business_day == 0:
		return { "kind": "holiday" }
	if business_day == GameState.day:
		return { "kind": "today", "day": business_day }
	if business_day > GameState.day:
		return { "kind": "future", "day": business_day }
	var row: PackedInt32Array = GameState.get_history(business_day)
	if row.is_empty():
		return { "kind": "no_record", "day": business_day }
	return { "kind": "done", "day": business_day, "profit": row[GameState.HISTORY_PROFIT], "row": row }


## 利益の短い表示（「+12,300」、10万以上は「+12.3万」）
static func short_profit(value: int) -> String:
	var sign: String = "+" if value > 0 else ("-" if value < 0 else "")
	var a: int = absi(value)
	if a >= 100000:
		return "%s%.1f万" % [sign, float(a) / 10000.0]
	return sign + UIText.money(a).trim_prefix("¥")


static func profit_color(value: int) -> Color:
	if value > 0:
		return COLOR_PLUS
	if value < 0:
		return COLOR_MINUS
	return COLOR_ZERO


func _profit_color(value: int) -> Color:
	return CalendarPopup.profit_color(value)


func _signed_money(value: int) -> String:
	return ("+" if value > 0 else "") + UIText.money(value)


func _make_blank() -> Control:
	var blank: Control = Control.new()
	blank.custom_minimum_size = CELL_SIZE
	return blank


func _make_cell(date_number: int, offset: int, cell: Dictionary) -> Button:
	var kind: String = cell["kind"]
	var button: Button = Button.new()
	button.custom_minimum_size = CELL_SIZE
	var today: bool = kind == "today"
	var bg: Color = COLOR_CELL if kind in ["done", "today", "no_record"] else COLOR_CELL_EMPTY
	UIUtil.apply_button_style(button, UIUtil.flat_box(bg, COLOR_TODAY_BORDER if today else UIColors.CAL_CELL_BORDER, 2 if today else 1, 2))
	var box: VBoxContainer = VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", -2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(box)
	var date_label: Label = Label.new()
	date_label.text = str(date_number)
	date_label.theme_type_variation = &"SmallLabel"
	date_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	date_label.add_theme_color_override("font_color", COLOR_HOLIDAY if kind in ["holiday", "before"] else UIColors.TEXT)
	box.add_child(date_label)
	var value_label: Label = Label.new()
	value_label.theme_type_variation = &"SmallLabel"
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	match kind:
		"holiday":
			value_label.text = UIText.CAL_HOLIDAY
			value_label.add_theme_color_override("font_color", COLOR_HOLIDAY)
		"done":
			value_label.text = CalendarPopup.short_profit(int(cell["profit"]))
			value_label.add_theme_color_override("font_color", _profit_color(int(cell["profit"])))
		_:
			value_label.text = ""
	box.add_child(value_label)
	button.set_meta("value_text", value_label.text)
	button.set_meta("value_color", value_label.get_theme_color("font_color"))
	button.pressed.connect(_on_cell_pressed.bind(offset))
	return button


func _on_cell_pressed(offset: int) -> void:
	var cell: Dictionary = describe_offset(offset)
	var date_text: String = GameCalendar.format_month_day(GameCalendar.date_for_offset(offset))
	match String(cell["kind"]):
		"before":
			_detail_label.text = UIText.CAL_DETAIL_BEFORE % date_text
		"holiday":
			_detail_label.text = UIText.CAL_DETAIL_HOLIDAY % date_text
		"today":
			_detail_label.text = UIText.CAL_DETAIL_TODAY % [date_text, int(cell["day"])]
		"future":
			_detail_label.text = UIText.CAL_DETAIL_FUTURE % [date_text, int(cell["day"])]
		"no_record":
			_detail_label.text = UIText.CAL_DETAIL_NONE % [date_text, int(cell["day"])]
		"done":
			var row: PackedInt32Array = cell["row"]
			var stars10: int = row[GameState.HISTORY_STARS10]
			var stars: String = ("★%.1f" % (float(stars10) / 10.0)) if stars10 >= 0 else UIText.RESULT_NO_RATING
			_detail_label.text = UIText.CAL_DETAIL % [date_text, int(cell["day"]), UIText.money(row[GameState.HISTORY_SALES]),
				_signed_money(row[GameState.HISTORY_PROFIT]), row[GameState.HISTORY_VISITORS], stars,
				UIText.signed(row[GameState.HISTORY_REPUTATION])]
