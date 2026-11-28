extends Control
## 営業結果画面。今日の集計と料理ごとの内訳を表示し、「次の日へ」で次の営業準備に進む。
## お金は「利益」と「所持金」の2つを大きく出し、内訳は小さく出す。
##   利益 ＝ 所持金の増減 ＋ 在庫の増減（原価）（仕入れた日と使った日がずれると、2つの数字が違う）
## 内訳の表は藍・青灰色の系統（見出しは藍色の帯、行は薄い青と白を交互）。
## 完売した料理（黄：廃棄0で、仕込んだ分が全部売れた）と、廃棄が多かった料理（赤）に色を付ける。
## 売り逃しの数は画面には出さない（評判の計算にだけ使う）。

signal next_day_requested
## 「お店を強化」を押した（強化画面へ進む）
signal upgrade_requested

## 内訳の表の列の幅（仕込み数・売れた数・廃棄数・売上）
const COLUMN_WIDTHS: Array[int] = [52, 52, 46, 72]
const COLUMN_SOLD := 1
const COLUMN_WASTE := 2
const COLOR_SOLD_OUT := UIColors.TABLE_SOLD_OUT
const COLOR_SOLD_OUT_BG := UIColors.TABLE_SOLD_OUT_BG
const COLOR_WASTE := UIColors.TABLE_WASTE
const COLOR_WASTE_BG := UIColors.TABLE_WASTE_BG
const COLOR_SUB := UIColors.TEXT_SUB
const COLOR_PLUS := UIColors.PLUS
const COLOR_MINUS := UIColors.DANGER

@onready var _title_label: Label = %TitleLabel
@onready var _reputation_change_label: Label = %ReputationChangeLabel
@onready var _rating_label: Label = %RatingLabel
@onready var _news: HFlowContainer = %News
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
@onready var _upgrade_button: Button = %UpgradeButton
@onready var _holiday_label: Label = %HolidayLabel


func _ready() -> void:
	($Background as ColorRect).color = UIColors.BACKGROUND
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
	# 在籍日数が終わって退職したスタッフ
	for staff_id: String in stats.staff_retired:
		var staff: StaffData = Database.get_staff(staff_id)
		var retire_label: Label = Label.new()
		retire_label.text = UIText.RESULT_STAFF_RETIRED % (staff.display_name if staff != null else staff_id)
		retire_label.add_theme_color_override("font_color", UIColors.DANGER)
		retire_label.name = "StaffRetired"
		_news.add_child(retire_label)
	_news.visible = _rank_up_label.visible or _unlock_label.visible or _note_label.visible or not stats.staff_retired.is_empty()

	# 利益（大）と内訳（小）
	var profit: int = stats.profit()
	_add_row(_profit_grid, UIText.RESULT_PROFIT, UIText.money(profit), COLOR_PLUS if profit >= 0 else COLOR_MINUS, true)
	_add_row(_profit_grid, UIText.RESULT_SALES, UIText.money(stats.sales))
	_add_row(_profit_grid, UIText.RESULT_COST, UIText.money(-stats.ingredient_cost))
	if stats.waste_count > 0:
		_add_row(_profit_grid, UIText.RESULT_WASTE % stats.waste_count, UIText.money(-stats.waste_cost), COLOR_WASTE)
	_add_row(_profit_grid, UIText.RESULT_OTHER, UIText.money(-stats.other_expense))
	if stats.labor_cost > 0 or stats.staff_count > 0:
		_add_row(_profit_grid, UIText.RESULT_LABOR % stats.staff_count, UIText.money(-stats.labor_cost))

	# 所持金（大）と、利益との関係（小）
	var money_change: int = GameState.money - stats.day_start_money
	var stock_change: int = GameState.get_stock_value() - stats.day_start_stock_value
	_add_row(_money_grid, UIText.RESULT_MONEY, UIText.money(GameState.money), UIText.money_color(GameState.money), true)
	_add_row(_money_grid, UIText.RESULT_MONEY_CHANGE, _signed_money(money_change), COLOR_PLUS if money_change >= 0 else COLOR_MINUS)
	_add_row(_money_grid, UIText.RESULT_PURCHASE, UIText.money(-stats.purchase_cost))
	_add_row(_money_grid, UIText.RESULT_STOCK_CHANGE, _signed_money(stock_change))
	_add_row(_money_grid, UIText.RESULT_PROFIT_FORMULA, "", COLOR_SUB)

	_service_label.text = UIText.RESULT_SERVICE_LINE % [stats.visitors, stats.completed_orders, stats.left_angry,
		stats.mistakes, GameState.reputation]

	_build_dish_table(stats)
	_upgrade_button.text = UIText.RESULT_UPGRADE
	_holiday_label.text = ResultScreenText.holiday_note(GameState.day)
	_holiday_label.visible = _holiday_label.text != ""
	_next_button.pressed.connect(_on_next_pressed)
	_upgrade_button.pressed.connect(_on_upgrade_pressed)


## big: 大きく出す行（利益・所持金）。そうでない行は小さい文字で、少し下げて出す
func _add_row(grid: GridContainer, name_text: String, value_text: String, value_color: Color = UIColors.TEXT, big: bool = false) -> void:
	var name_label: Label = Label.new()
	name_label.text = name_text if big else "　" + name_text
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.theme_type_variation = &"MediumLabel" if big else &"SmallLabel"
	if not big:
		name_label.add_theme_color_override("font_color", UIColors.TEXT_SUB)
	grid.add_child(name_label)
	var value_label: Label = Label.new()
	value_label.text = value_text
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.theme_type_variation = &"MediumLabel" if big else &"SmallLabel"
	value_label.add_theme_color_override("font_color", value_color)
	grid.add_child(value_label)


func _signed_money(value: int) -> String:
	return ("+" if value > 0 else "") + UIText.money(value)


# ---------------------------------------------------------------
# 料理ごとの内訳
# ---------------------------------------------------------------

func _build_dish_table(stats: DayStats) -> void:
	_dish_title.text = UIText.RESULT_DISH_TITLE
	# 凡例: 表の行と同じ色の小さな見本と、同じ色の文字
	_dish_legend.text = UIText.RESULT_DISH_LEGEND
	_dish_legend.add_theme_color_override("font_color", COLOR_SOLD_OUT)
	_dish_legend.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_dish_legend.clip_text = false
	_dish_legend.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	var legend_parent: Node = _dish_legend.get_parent()
	legend_parent.add_child(_legend_chip(COLOR_SOLD_OUT_BG, COLOR_SOLD_OUT))
	legend_parent.move_child(legend_parent.get_child(legend_parent.get_child_count() - 1), _dish_legend.get_index())
	legend_parent.add_child(_legend_chip(COLOR_WASTE_BG, COLOR_WASTE))
	var waste_legend: Label = Label.new()
	waste_legend.theme_type_variation = &"SmallLabel"
	waste_legend.text = UIText.RESULT_DISH_LEGEND_WASTE % roundi(Database.config.waste_warning_ratio * 100.0)
	waste_legend.add_theme_color_override("font_color", COLOR_WASTE)
	waste_legend.size_flags_vertical = Control.SIZE_SHRINK_END
	legend_parent.add_child(waste_legend)
	var header_box: StyleBoxFlat = UIUtil.flat_box(UIColors.TABLE_HEADER, UIColors.TABLE_HEADER, 0, 4)
	header_box.content_margin_left = 12
	var header: PanelContainer = _make_table_row(
		UIText.RESULT_DISH_NAME, "",
		[UIText.RESULT_DISH_PREPARED, UIText.RESULT_DISH_SOLD, UIText.RESULT_DISH_WASTE, UIText.RESULT_DISH_SALES],
		header_box, UIColors.TABLE_HEADER_TEXT, true)
	_dish_table.add_child(header)

	var ids: Array[String] = stats.get_prepared_dish_ids()
	if ids.is_empty():
		var none: Label = Label.new()
		none.text = UIText.RESULT_DISH_NONE
		none.add_theme_color_override("font_color", COLOR_SUB)
		_dish_table.add_child(none)
		return
	for row_index: int in ids.size():
		var dish_id: String = ids[row_index]
		var dish: DishData = Database.get_dish(dish_id)
		var prepared: int = int(stats.dish_prepared.get(dish_id, 0))
		var sold: int = int(stats.dish_sold.get(dish_id, 0))
		var waste: int = int(stats.dish_waste.get(dish_id, 0))
		var sales: int = int(stats.dish_sales.get(dish_id, 0))
		var tag: String = ""
		# 行は薄い青と白を交互に
		var bg: Color = UIColors.TABLE_ROW_A if row_index % 2 == 0 else UIColors.TABLE_ROW_B
		var accent: Color = Color.TRANSPARENT
		var text_color: Color = UIColors.TEXT
		if waste == 0 and sold >= prepared and prepared > 0:
			# 仕込んだ分が全部売れた（完売）
			tag = UIText.RESULT_DISH_SOLD_OUT
			bg = COLOR_SOLD_OUT_BG
			accent = COLOR_SOLD_OUT
			text_color = COLOR_SOLD_OUT
		elif float(waste) / float(prepared) >= Database.config.waste_warning_ratio:
			tag = UIText.RESULT_DISH_MANY_WASTE
			bg = COLOR_WASTE_BG
			accent = COLOR_WASTE
			text_color = COLOR_WASTE
		var box: StyleBoxFlat = UIUtil.flat_box(bg, accent if accent.a > 0.0 else UIColors.TABLE_BORDER, 2 if accent.a > 0.0 else 1)
		box.border_width_left = 6
		box.content_margin_left = 12
		box.border_color = dish.color if accent.a <= 0.0 else accent
		var row_name: String = UIText.RESULT_TOPPING_NAME % dish.display_name if dish.is_topping() else dish.display_name
		var row: PanelContainer = _make_table_row(
			row_name, tag,
			[str(prepared), str(sold), str(waste), UIText.money(sales)],
			box, text_color, false)
		_dish_table.add_child(row)


## 表の1行。values は 仕込み数・売れた数・廃棄数・売上 の順
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
		name_label.add_theme_color_override("font_color", tag_color)
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
			value_label.add_theme_color_override("font_color", tag_color)
		elif i == COLUMN_WASTE and tag_color == COLOR_WASTE:
			value_label.add_theme_color_override("font_color", COLOR_WASTE)
		elif i == COLUMN_SOLD and tag_color == COLOR_SOLD_OUT:
			value_label.add_theme_color_override("font_color", COLOR_SOLD_OUT)
		hbox.add_child(value_label)
	return row


## 凡例の色の見本（表の行と同じ背景と枠）
func _legend_chip(bg: Color, border: Color) -> Control:
	var chip: Panel = Panel.new()
	chip.custom_minimum_size = Vector2(14, 12)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.add_theme_stylebox_override("panel", UIUtil.flat_box(bg, border, 2, 2))
	return chip


func _on_next_pressed() -> void:
	_next_button.disabled = true
	_upgrade_button.disabled = true
	next_day_requested.emit()


func _on_upgrade_pressed() -> void:
	_next_button.disabled = true
	_upgrade_button.disabled = true
	upgrade_requested.emit()
