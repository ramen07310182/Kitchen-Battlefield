extends Control
## 営業結果画面。今日の集計を表示し、「次の日へ」で次の営業準備に進む。

signal next_day_requested

@onready var _title_label: Label = %TitleLabel
@onready var _money_grid: GridContainer = %MoneyGrid
@onready var _service_grid: GridContainer = %ServiceGrid
@onready var _rating_label: Label = %RatingLabel
@onready var _note_label: Label = %NoteLabel
@onready var _next_button: Button = %NextButton


func _ready() -> void:
	var stats: DayStats = GameState.today
	_title_label.text = UIText.RESULT_TITLE % GameState.day
	_next_button.text = UIText.RESULT_NEXT

	_add_row(_money_grid, UIText.RESULT_SALES, UIText.money(stats.sales))
	_add_row(_money_grid, UIText.RESULT_COST, UIText.money(-stats.ingredient_cost))
	if stats.waste_count > 0:
		_add_row(_money_grid, UIText.RESULT_WASTE % stats.waste_count, UIText.money(-stats.waste_cost),
			Color(1.0, 0.7, 0.5))
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


func _on_next_pressed() -> void:
	_next_button.disabled = true
	next_day_requested.emit()
