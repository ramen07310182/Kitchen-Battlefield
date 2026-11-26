extends Control
## 営業結果画面。今日の集計と料理ごとの内訳を表示し、「次の日へ」で次の営業準備に進む。
## 内訳では、売り切れて売り逃しが出た料理（黄）と、廃棄が多かった料理（赤）に色を付ける。

signal next_day_requested

## 内訳の表の列の幅（仕込み数・売れた数・売り逃し・廃棄数・売上）
const COLUMN_WIDTHS: Array[int] = [46, 46, 56, 40, 68]
const COLUMN_SOLD := 1
const COLUMN_MISSED := 2
const COLUMN_WASTE := 3
const COLOR_ROW := Color(0.2, 0.17, 0.15)
const COLOR_SOLD_OUT := Color(1.0, 0.82, 0.35)
const COLOR_SOLD_OUT_BG := Color(0.33, 0.27, 0.1)
const COLOR_WASTE := Color(1.0, 0.5, 0.42)
const COLOR_WASTE_BG := Color(0.34, 0.15, 0.13)
const COLOR_SUB := Color(0.7, 0.7, 0.7)

@onready var _title_label: Label = %TitleLabel
@onready var _money_grid: GridContainer = %MoneyGrid
@onready var _service_grid: GridContainer = %ServiceGrid
@onready var _rating_label: Label = %RatingLabel
@onready var _note_label: Label = %NoteLabel
@onready var _dish_title: Label = %DishTitle
@onready var _dish_legend: Label = %DishLegend
@onready var _dish_table: VBoxContainer = %DishTable
@onready var _next_button: Button = %NextButton


func _ready() -> void:
	var stats: DayStats = GameState.today
	_title_label.text = UIText.RESULT_TITLE % GameState.day
	_next_button.text = UIText.RESULT_NEXT

	_add_row(_money_grid, UIText.RESULT_SALES, UIText.money(stats.sales))
	_add_row(_money_grid, UIText.RESULT_COST, UIText.money(-stats.ingredient_cost))
	if stats.waste_count > 0:
		_add_row(_money_grid, UIText.RESULT_WASTE % stats.waste_count, UIText.money(-stats.waste_cost), COLOR_WASTE)
	_add_row(_money_grid, UIText.RESULT_OTHER, UIText.money(-stats.other_expense))
	var profit: int = stats.profit()
	_add_row(_money_grid, UIText.RESULT_PROFIT, UIText.money(profit),
		Color(0.6, 1.0, 0.6) if profit >= 0 else Color(1.0, 0.5, 0.45))
	_add_row(_money_grid, UIText.RESULT_MONEY, UIText.money(GameState.money))

	_add_row(_service_grid, UIText.RESULT_VISITORS, UIText.RESULT_PEOPLE % stats.visitors)
	_add_row(_service_grid, UIText.RESULT_COMPLETED, UIText.RESULT_COUNT % stats.completed_orders)
	_add_row(_service_grid, UIText.RESULT_ANGRY, UIText.RESULT_PEOPLE % stats.left_angry)
	_add_row(_service_grid, UIText.RESULT_MISTAKES, UIText.RESULT_TIMES % stats.mistakes)
	_add_row(_service_grid, UIText.RESULT_REPUTATION,
		"%d（%s）" % [GameState.reputation, UIText.signed(stats.reputation_change)])

	if stats.has_ratings():
		_rating_label.text = "%s  %s" % [UIText.RESULT_RATING, UIText.stars(stats.rounded_stars())]
	else:
		_rating_label.text = "%s  %s" % [UIText.RESULT_RATING, UIText.RESULT_NO_RATING]
	_note_label.text = UIText.RESULT_SOLD_OUT if stats.sold_out else ""
	_note_label.visible = stats.sold_out

	_build_dish_table(stats)
	_next_button.pressed.connect(_on_next_pressed)


func _add_row(grid: GridContainer, name_text: String, value_text: String, value_color: Color = Color.WHITE) -> void:
	var name_label: Label = Label.new()
	name_label.text = name_text
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(name_label)
	var value_label: Label = Label.new()
	value_label.text = value_text
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.modulate = value_color
	grid.add_child(value_label)


# ---------------------------------------------------------------
# 料理ごとの内訳
# ---------------------------------------------------------------

func _build_dish_table(stats: DayStats) -> void:
	_dish_title.text = UIText.RESULT_DISH_TITLE
	_dish_legend.text = UIText.RESULT_DISH_LEGEND % roundi(Database.config.waste_warning_ratio * 100.0)
	var header: PanelContainer = _make_table_row(
		UIText.RESULT_DISH_NAME, "",
		[UIText.RESULT_DISH_PREPARED, UIText.RESULT_DISH_SOLD, UIText.RESULT_DISH_MISSED, UIText.RESULT_DISH_WASTE, UIText.RESULT_DISH_SALES],
		StyleBoxEmpty.new(), COLOR_SUB, true)
	_dish_table.add_child(header)

	var ids: Array[String] = stats.get_prepared_dish_ids()
	if ids.is_empty():
		var none: Label = Label.new()
		none.text = UIText.RESULT_DISH_NONE
		none.modulate = COLOR_SUB
		_dish_table.add_child(none)
		return
	for dish_id: String in ids:
		var dish: DishData = Database.get_dish(dish_id)
		var prepared: int = int(stats.dish_prepared.get(dish_id, 0))
		var sold: int = int(stats.dish_sold.get(dish_id, 0))
		var waste: int = int(stats.dish_waste.get(dish_id, 0))
		var sales: int = int(stats.dish_sales.get(dish_id, 0))
		var missed: int = int(stats.dish_missed.get(dish_id, 0))
		var tag: String = ""
		var bg: Color = COLOR_ROW
		var accent: Color = Color.TRANSPARENT
		var text_color: Color = Color.WHITE
		if waste == 0 and missed > 0:
			# 仕込んだ分が全部売れて、まだ頼みたい客がいた
			tag = UIText.RESULT_DISH_SOLD_OUT
			bg = COLOR_SOLD_OUT_BG
			accent = COLOR_SOLD_OUT
			text_color = COLOR_SOLD_OUT
		elif float(waste) / float(prepared) >= Database.config.waste_warning_ratio:
			tag = UIText.RESULT_DISH_MANY_WASTE
			bg = COLOR_WASTE_BG
			accent = COLOR_WASTE
			text_color = COLOR_WASTE
		var box: StyleBoxFlat = UIUtil.flat_box(bg, accent, 1 if accent.a > 0.0 else 0)
		box.border_width_left = 6
		box.content_margin_left = 12
		box.border_color = dish.color if accent.a <= 0.0 else accent
		var row: PanelContainer = _make_table_row(
			dish.display_name, tag,
			[str(prepared), str(sold), str(missed), str(waste), UIText.money(sales)],
			box, text_color, false)
		_dish_table.add_child(row)


## 表の1行。values は 仕込み数・売れた数・売り逃し・廃棄数・売上 の順
func _make_table_row(name_text: String, tag: String, values: Array, box: StyleBox, tag_color: Color,
		is_header: bool) -> PanelContainer:
	var row: PanelContainer = PanelContainer.new()
	row.add_theme_stylebox_override("panel", box)
	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	row.add_child(hbox)

	var name_label: Label = Label.new()
	name_label.text = name_text
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if is_header:
		name_label.theme_type_variation = &"SmallLabel"
		name_label.modulate = COLOR_SUB
	hbox.add_child(name_label)

	if tag != "":
		var tag_label: Label = Label.new()
		tag_label.text = tag
		tag_label.theme_type_variation = &"SmallLabel"
		tag_label.add_theme_color_override("font_color", tag_color)
		tag_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hbox.add_child(tag_label)

	for i: int in values.size():
		var value_label: Label = Label.new()
		value_label.text = str(values[i])
		value_label.custom_minimum_size = Vector2(COLUMN_WIDTHS[i], 0)
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		if is_header:
			value_label.theme_type_variation = &"SmallLabel"
			value_label.modulate = COLOR_SUB
		elif i == COLUMN_WASTE and tag_color == COLOR_WASTE:
			value_label.add_theme_color_override("font_color", COLOR_WASTE)
		elif (i == COLUMN_SOLD or i == COLUMN_MISSED) and tag_color == COLOR_SOLD_OUT:
			value_label.add_theme_color_override("font_color", COLOR_SOLD_OUT)
		hbox.add_child(value_label)
	return row


func _on_next_pressed() -> void:
	_next_button.disabled = true
	next_day_requested.emit()
