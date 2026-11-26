extends Control
## お店の強化画面（営業結果のあと、次の日の準備の前）。設備を買って、次の営業から効果を出す。
## 購入は確認ダイアログを出してから。所持金・ランクが足りないものは押せず、理由を出す。行の長押しで詳細（今と次のレベルの比較）。

signal next_day_requested

const EQUIPMENT_ROW_SCENE: PackedScene = preload("res://scenes/upgrade/equipment_row.tscn")

var _rows: Array[EquipmentRow] = []
var _pending_id: String = ""

@onready var _title_label: Label = %TitleLabel
@onready var _help_label: Label = %HelpLabel
@onready var _list: VBoxContainer = %List
@onready var _message_label: Label = %MessageLabel
@onready var _holiday_label: Label = %HolidayLabel
@onready var _next_button: Button = %NextButton
@onready var _dialog: ConfirmDialog = %ConfirmDialog
@onready var _detail: DetailPopup = %DetailPopup


func _ready() -> void:
	_title_label.text = UIText.UPGRADE_TITLE
	_help_label.text = UIText.UPGRADE_HELP
	_next_button.text = UIText.RESULT_NEXT
	_message_label.text = UIText.UPGRADE_HINT
	_holiday_label.text = ResultScreenText.holiday_note(GameState.day)
	_holiday_label.visible = _holiday_label.text != ""
	for e: EquipmentData in Database.equipment:
		var row: EquipmentRow = EQUIPMENT_ROW_SCENE.instantiate() as EquipmentRow
		_list.add_child(row)
		row.setup(e)
		row.buy_requested.connect(_on_buy_requested)
		row.detail_requested.connect(_show_detail)
		row.detail_closed.connect(_detail.close)
		_rows.append(row)
	_dialog.answered.connect(_on_dialog_answered)
	_next_button.pressed.connect(_on_next_pressed)
	GameState.money_changed.connect(_on_money_changed)
	_refresh()


func _on_money_changed(_value: int) -> void:
	_refresh()


func _refresh() -> void:
	for row: EquipmentRow in _rows:
		row.refresh()


func _on_buy_requested(equipment_id: String) -> void:
	if GameState.get_buy_block(equipment_id) != GameState.BuyBlock.NONE:
		return
	var e: EquipmentData = Database.get_equipment(equipment_id)
	var level: int = GameState.get_equipment_level(equipment_id)
	_pending_id = equipment_id
	_dialog.ask(UIText.UPGRADE_CONFIRM % [e.display_name, level, level + 1, UIText.money(e.get_price(level))],
		UIText.UPGRADE_OK, UIText.PREP_CANCEL)


func _on_dialog_answered(ok: bool) -> void:
	var equipment_id: String = _pending_id
	_pending_id = ""
	if not ok or equipment_id == "":
		return
	if GameState.buy_equipment(equipment_id):
		var e: EquipmentData = Database.get_equipment(equipment_id)
		_message_label.text = UIText.UPGRADE_DONE % [e.display_name, GameState.get_equipment_level(equipment_id)]
	_refresh()


## 詳細: 今のレベルと次のレベルの効果の比較
func _show_detail(equipment_id: String) -> void:
	var e: EquipmentData = Database.get_equipment(equipment_id)
	if e == null:
		return
	var level: int = GameState.get_equipment_level(equipment_id)
	var lines: PackedStringArray = PackedStringArray()
	lines.append(e.description)
	lines.append(UIText.UPGRADE_DETAIL_NOW % [level, EquipmentText.effect_text(e, level)])
	if level < e.get_max_level():
		lines.append(UIText.UPGRADE_DETAIL_NEXT % [level + 1, EquipmentText.effect_text(e, level + 1),
			UIText.money(e.get_price(level)), Database.get_rank_name(e.get_required_rank(level))])
	else:
		lines.append(UIText.UPGRADE_DETAIL_MAXED)
	if e.effect == EquipmentData.Effect.COOK_TIME:
		lines.append(UIText.UPGRADE_DETAIL_TARGETS % EquipmentText.target_dishes_text(e))
	_detail.open(e.display_name, lines, DetailPopup.Placement.RIGHT)


func _on_next_pressed() -> void:
	_next_button.disabled = true
	next_day_requested.emit()
