extends Control
## お店の強化画面（営業結果のあと、次の日の準備の前）。設備を買って、次の営業から効果を出す。
## 「従業員」の区切りでは、ホールスタッフを雇う（雇える人数はランクで決まる。費用は出勤した日の日給だけ）。
## プレイヤーからは辞めさせられない（満足度が低いと、営業結果で辞めてしまうことがある）。行の長押しで詳細（毎週の休みなど）。
## 購入は確認ダイアログを出してから。所持金・ランクが足りないものは押せず、理由を出す。行の長押しで詳細（今と次のレベルの比較）。

signal next_day_requested

const EQUIPMENT_ROW_SCENE: PackedScene = preload("res://scenes/upgrade/equipment_row.tscn")

var _rows: Array[EquipmentRow] = []
var _staff_rows: Array[StaffRow] = []
var _staff_header: Label
var _pending_id: String = ""
## 確認ダイアログで聞いていること（"buy" = 設備の購入、"dismiss" = 従業員にやめてもらう）
var _pending_action: String = ""

@onready var _title_label: Label = %TitleLabel
@onready var _help_label: Label = %HelpLabel
@onready var _list: VBoxContainer = %List
@onready var _message_label: Label = %MessageLabel
@onready var _holiday_label: Label = %HolidayLabel
@onready var _next_button: Button = %NextButton
@onready var _dialog: ConfirmDialog = %ConfirmDialog
@onready var _detail: DetailPopup = %DetailPopup


func _ready() -> void:
	($Background as ColorRect).color = UIColors.BACKGROUND
	_title_label.text = UIText.UPGRADE_TITLE
	_help_label.text = UIText.UPGRADE_HELP
	_next_button.text = UIText.RESULT_NEXT
	_message_label.text = UIText.UPGRADE_HINT
	_holiday_label.text = ResultScreenText.holiday_note(GameState.day)
	_holiday_label.visible = _holiday_label.text != ""
	_list.add_child(_section_label(UIText.UPGRADE_SECTION_EQUIPMENT))
	for e: EquipmentData in Database.equipment:
		var row: EquipmentRow = EQUIPMENT_ROW_SCENE.instantiate() as EquipmentRow
		_list.add_child(row)
		row.setup(e)
		row.buy_requested.connect(_on_buy_requested)
		row.detail_requested.connect(_show_detail)
		row.detail_closed.connect(_detail.close)
		_rows.append(row)
	# 従業員（ホールスタッフ）
	_staff_header = _section_label("")
	_list.add_child(_staff_header)
	var staff_help: Label = Label.new()
	staff_help.theme_type_variation = &"SmallLabel"
	staff_help.text = "\n".join([UIText.UPGRADE_STAFF_HELP, UIText.UPGRADE_STAFF_HELP2])
	staff_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	staff_help.add_theme_color_override("font_color", UIColors.TEXT_SUB)
	_list.add_child(staff_help)
	for data: StaffData in Database.staff:
		var staff_row: StaffRow = StaffRow.new()
		_list.add_child(staff_row)
		staff_row.setup(data)
		staff_row.hire_requested.connect(_on_hire_requested)
		staff_row.detail_requested.connect(_show_staff_detail)
		staff_row.detail_closed.connect(_detail.close)
		_staff_rows.append(staff_row)
	_dialog.answered.connect(_on_dialog_answered)
	_next_button.pressed.connect(_on_next_pressed)
	GameState.money_changed.connect(_on_money_changed)
	_refresh()


func _on_money_changed(_value: int) -> void:
	_refresh()


func _refresh() -> void:
	for row: EquipmentRow in _rows:
		row.refresh()
	for staff_row: StaffRow in _staff_rows:
		staff_row.refresh()
	_staff_header.text = UIText.UPGRADE_SECTION_STAFF % [GameState.hired_staff.size(), GameState.get_staff_limit()]


func _section_label(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.theme_type_variation = &"HeaderLabel"
	label.add_theme_color_override("font_color", UIColors.ACCENT)
	return label


func _on_hire_requested(staff_id: String) -> void:
	if GameState.hire_staff(staff_id):
		_message_label.text = UIText.UPGRADE_STAFF_HIRE_DONE % Database.get_staff(staff_id).display_name
	_refresh()


## 従業員の詳細: 速さ・日給・毎週の休み・急な休み・機嫌
func _show_staff_detail(staff_id: String) -> void:
	var data: StaffData = Database.get_staff(staff_id)
	if data != null:
		_detail.open(data.display_name, StaffRow.detail_lines(data), DetailPopup.Placement.RIGHT)


func _on_buy_requested(equipment_id: String) -> void:
	if GameState.get_buy_block(equipment_id) != GameState.BuyBlock.NONE:
		return
	var e: EquipmentData = Database.get_equipment(equipment_id)
	var level: int = GameState.get_equipment_level(equipment_id)
	_pending_id = equipment_id
	_pending_action = "buy"
	_dialog.ask(UIText.UPGRADE_CONFIRM % [e.display_name, level, level + 1, UIText.money(e.get_price(level))],
		UIText.UPGRADE_OK, UIText.PREP_CANCEL)


func _on_dialog_answered(ok: bool) -> void:
	var equipment_id: String = _pending_id
	_pending_id = ""
	_pending_action = ""
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
