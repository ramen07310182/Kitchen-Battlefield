extends Control
## 営業結果画面。今日の集計と料理ごとの内訳を表示し、「次の日へ」で次の営業準備に進む。
## お金は「利益」と「所持金」の2つを大きく出し、内訳は小さく出す。
##   利益 ＝ 所持金の増減 ＋ 在庫の増減（原価）（仕入れた日と使った日がずれると、2つの数字が違う）
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
const COLOR_PLUS := Color(0.6, 1.0, 0.6)
const COLOR_MINUS := Color(1.0, 0.5, 0.45)

@onready var _title_label: Label = %TitleLabel
@onready var _reputation_change_label: Label = %ReputationChangeLabel
@onready var _rating_label: Label = %RatingLabel
@onready var _news: HBoxContainer = %News
@onready var _rank_up_label: Label = %RankUpLabel
@onready var _unlock_label: Label = %UnlockLabel
@onready var _note_label: Label = %NoteLabel
@onready var _profit_grid: GridContainer = %ProfitGrid
@onready var _money_grid: GridContainer = %MoneyGrid
@onready var _service_label: Label = %ServiceLabel
@onready var _dish_title: Label = %DishTitle
@onready var _dish_legend: Label = %DishLegend
@onready var _dish_table: VBoxContainer = %DishTable
@onready var _next_button: Button = %NextButton


func _ready() -> void:
	var stats: DayStats = GameState.today
	_title_label.text = UIText.RESULT_TITLE % GameState.day
	_next_button.text = UIText.RESULT_NEXT

	# 評判の増減と評価
	var rep: int = stats.reputation_change
	_reputation_change_label.text = UIText.RESULT_REPUTATION_CHANGE % UIText.signed(rep)
	_reputation_change_label.add_theme_color_override("font_color", COLOR_PLUS if rep > 0 else (COLOR_MINUS if rep < 0 else COLOR_SUB))
	if stats.has_ratings():
		_rating_label.text = "%s  %s" % [UIText.RESULT_RATING, UIText.stars(stats.rounded_stars())]
	else:
		_rating_label.text = "%s  %s" % [UIText.RESULT_RATING, UIText.RESULT_NO_RATING]

	# ランクアップ・新メニュー解放・売り切れ
	_rank_up_label.visible = stats.rank_up > 0
	if stats.rank_up > 0:
		_rank_up_label.text = UIText.RESULT_RANK_UP % Database.get_rank_name(stats.rank_up)
	var names: PackedStringArray = PackedStringArray()
	for dish_id: String in stats.new_unlocks:
		names.append(Database.get_dish(dish_id).display_name)
	_unlock_label.text = UIText.RESULT_UNLOCK % "・".join(names)
	_unlock_label.visible = not names.is_empty()
	_note_label.text = UIText.RESULT_SOLD_OUT
	_note_label.visible = stats.sold_out
	_news.visible = _rank_up_label.visible or _unlock_label.visible or _note_label.visible

	# 利益（大）と内訳（小）
	var profit: int = stats.profit()
	_add_row(_profit_grid, UIText.RESULT_PROFIT, UIText.money(profit), COLOR_PLUS if profit >= 0 else COLOR_MINUS, true)
	_add_row(_profit_grid, UIText.RESULT_SALES, UIText.money(stats.sales))
	_add_row(_profit_grid, UIText.RESULT_COST, UIText.money(-stats.ingredient_cost))
	if stats.waste_count > 0:
		_add_row(_profit_grid, UIText.RESULT_WASTE % stats.waste_count, UIText.money(-stats.waste_cost), COLOR_WASTE)
	_add_row(_profit_grid, UIText.RESULT_OTHER, UIText.money(-stats.other_expense))

	# 所持金（大）と、利益との関係（小）
	var money_change: int = GameState.money - stats.day_start_money
	var stock_change: int = GameState.get_stock_value() - stats.day_start_stock_value
	_add_row(_money_grid, UIText.RESULT_MONEY, UIText.money(GameState.money), Color.WHITE, true)
	_add_row(_money_grid, UIText.RESULT_MONEY_CHANGE, _signed_money(money_change), COLOR_PLUS if money_change >= 0 else COLOR_MINUS)
	_add_row(_money_grid, UIText.RESULT_PURCHASE, UIText.money(-stats.purchase_cost))
	_add_row(_money_grid, UIText.RESULT_STOCK_CHANGE, _signed_money(stock_change))
	_add_row(_money_grid, UIText.RESULT_PROFIT_FORMULA, "", COLOR_SUB)

	_service_label.text = UIText.RESULT_SERVICE_LINE % [stats.visitors, stats.completed_orders, stats.left_angry,
		stats.mistakes, GameState.reputation]

	_build_dish_table(stats)
	_next_button.pressed.connect(_on_next_pressed)


## big: 大きく出す行（利益・所持金）。そうでない行は小さい文字で、少し下げて出す
func _add_row(grid: GridContainer, name_text: String, value_text: String, value_color: Color = Color.WHITE, big: bool = false) -> void:
	var name_label: Label = Label.new()
	name_label.text = name_text if big else "　" + name_text
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.theme_type_variation = &"MediumLabel" if big else &"SmallLabel"
	if not big:
		name_label.modulate = Color(0.85, 0.85, 0.85)
	grid.add_child(name_label)
	var value_label: Label = Label.new()
	value_label.text = value_text
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.theme_type_variation = &"MediumLabel" if big else &"SmallLabel"
	value_label.modulate = value_color
	grid.add_child(value_label)


func _signed_money(value: int) -> String:
	return ("+" if value > 0 else "") + UIText.money(value)


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
