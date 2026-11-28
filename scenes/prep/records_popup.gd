class_name RecordsPopup
extends Control
## 通算の記録の画面（準備画面の「記録」ボタンで開く）。
## 上に通算の数字（営業日数・売上・利益・来客数・評価の平均）、下にグラフ（所持金の折れ線と日ごとの売上の棒）。
## 期間は「30日・90日・全期間」で切り替える。グラフをタップすると、その日の日付と金額を下に出す。

## 期間ごとの日数（0 = 全期間）
const PERIODS: Array[int] = [30, 90, 0]

var _period: int = 0
var _period_buttons: Array[Button] = []

@onready var _panel: PanelContainer = %Panel
@onready var _title_label: Label = %TitleLabel
@onready var _period_box: HBoxContainer = %PeriodBox
@onready var _close_button: Button = %CloseButton
@onready var _stats_grid: GridContainer = %StatsGrid
@onready var _chart: RecordsChart = %Chart
@onready var _legend_label: Label = %LegendLabel
@onready var _detail_label: Label = %DetailLabel
@onready var _empty_label: Label = %EmptyLabel


func _ready() -> void:
	var box: StyleBoxFlat = UIUtil.flat_box(Color(0.12, 0.11, 0.1, 0.98), Color(0.85, 0.75, 0.55), 2, 4)
	box.set_content_margin_all(8)
	_panel.add_theme_stylebox_override("panel", box)
	_title_label.text = UIText.REC_TITLE
	_close_button.text = UIText.CAL_CLOSE
	_close_button.pressed.connect(hide)
	_legend_label.text = UIText.REC_LEGEND
	_empty_label.text = UIText.REC_EMPTY
	for i: int in PERIODS.size():
		var button: Button = Button.new()
		button.text = UIText.REC_PERIODS[i]
		button.custom_minimum_size = Vector2(64, 30)
		button.toggle_mode = true
		button.pressed.connect(_set_period.bind(i))
		_period_box.add_child(button)
		_period_buttons.append(button)
	_chart.day_selected.connect(_on_day_selected)
	hide()


func open() -> void:
	_rebuild_stats()
	_set_period(_period)
	show()


func is_open() -> bool:
	return visible


func _set_period(index: int) -> void:
	_period = index
	for i: int in _period_buttons.size():
		_period_buttons[i].button_pressed = i == index
	var rows: Array[PackedInt32Array] = _rows_for_period(PERIODS[index])
	_chart.set_rows(rows)
	_empty_label.visible = rows.is_empty()
	_detail_label.text = UIText.REC_HINT if not rows.is_empty() else ""


## 期間の行（日の順）。days が 0 なら全期間
func _rows_for_period(days: int) -> Array[PackedInt32Array]:
	var all_days: Array[int] = GameState.get_history_days()
	if days > 0 and all_days.size() > days:
		all_days = all_days.slice(all_days.size() - days)
	var rows: Array[PackedInt32Array] = []
	for d: int in all_days:
		rows.append(GameState.get_history(d))
	return rows


## 通算の数字（期間に関係なく、すべての営業日）
func _rebuild_stats() -> void:
	for child: Node in _stats_grid.get_children():
		child.queue_free()
	var days: int = 0
	var sales: int = 0
	var profit: int = 0
	var visitors: int = 0
	var star_total: int = 0
	var star_days: int = 0
	for row: PackedInt32Array in GameState.history:
		days += 1
		sales += row[GameState.HISTORY_SALES]
		profit += row[GameState.HISTORY_PROFIT]
		visitors += row[GameState.HISTORY_VISITORS]
		if row[GameState.HISTORY_STARS10] >= 0:
			star_total += row[GameState.HISTORY_STARS10]
			star_days += 1
	var stars_text: String = UIText.REC_STARS % (float(star_total) / 10.0 / star_days) if star_days > 0 else UIText.RESULT_NO_RATING
	_add_stat(UIText.REC_DAYS, UIText.REC_DAYS_VALUE % days, Color.WHITE)
	_add_stat(UIText.REC_SALES, UIText.money(sales), Color.WHITE)
	_add_stat(UIText.REC_PROFIT, UIText.money(profit), UIText.money_color(profit))
	_add_stat(UIText.REC_VISITORS, UIText.REC_VISITORS_VALUE % visitors, Color.WHITE)
	_add_stat(UIText.REC_RATING, stars_text, Color(1.0, 0.85, 0.4))


func _add_stat(name_text: String, value_text: String, color: Color) -> void:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_label: Label = Label.new()
	name_label.text = name_text
	name_label.theme_type_variation = &"SmallLabel"
	name_label.modulate = Color(0.75, 0.75, 0.75)
	box.add_child(name_label)
	var value_label: Label = Label.new()
	value_label.text = value_text
	value_label.add_theme_color_override("font_color", color)
	box.add_child(value_label)
	_stats_grid.add_child(box)


## グラフでタップした日: 日付・売上・所持金（記録がなければ「記録なし」）
func _on_day_selected(row: PackedInt32Array) -> void:
	var business_day: int = row[GameState.HISTORY_DAY]
	var date_text: String = GameCalendar.format_date(GameCalendar.date_for_business_day(business_day))
	var money_text: String = UIText.money(row[GameState.HISTORY_MONEY]) if GameState.has_history_money(row) else UIText.REC_NO_MONEY
	_detail_label.text = UIText.REC_DETAIL % [date_text, business_day, UIText.money(row[GameState.HISTORY_SALES]), money_text]
	var negative: bool = GameState.has_history_money(row) and row[GameState.HISTORY_MONEY] < 0
	_detail_label.add_theme_color_override("font_color", UIText.COLOR_NEGATIVE_MONEY if negative else Color.WHITE)
