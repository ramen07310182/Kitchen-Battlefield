class_name EquipmentRow
extends PanelContainer
## 強化画面の1行: 設備の名前・説明・今のレベル・次のレベルの効果と価格・必要なランク・購入ボタン。
## 買えないとき（所持金・ランクが足りない・最大レベル）は、ボタンを押せなくして理由を出す。ボタン以外の所を長押しで詳細。

signal buy_requested(equipment_id: String)
signal detail_requested(equipment_id: String)
signal detail_closed

const COLOR_OK := Color(0.85, 0.85, 0.85)
const COLOR_BLOCKED := Color(1.0, 0.5, 0.45)

var equipment: EquipmentData

@onready var _icon: TextureRect = %Icon
@onready var _name_label: Label = %NameLabel
@onready var _description_label: Label = %DescriptionLabel
@onready var _effect_label: Label = %EffectLabel
@onready var _price_label: Label = %PriceLabel
@onready var _note_label: Label = %NoteLabel
@onready var _buy_button: Button = %BuyButton
@onready var _long_press: LongPressDetector = %LongPress


func _ready() -> void:
	add_theme_stylebox_override("panel", UIUtil.flat_box(Color(0.2, 0.17, 0.15)))
	_buy_button.text = UIText.UPGRADE_BUY
	_buy_button.pressed.connect(func() -> void: buy_requested.emit(equipment.id))
	_long_press.long_pressed.connect(func() -> void: detail_requested.emit(equipment.id))
	_long_press.finished.connect(detail_closed.emit)


## add_child の後に呼ぶ
func setup(data: EquipmentData) -> void:
	equipment = data
	# 絵（assets/sprites/equipment/<id>.png）があれば絵、なければ色の四角
	var icon: Texture2D = SpriteLibrary.get_icon("equipment/" + data.id)
	_icon.texture = icon if icon != null else UIUtil.color_icon(Color(0.85, 0.7, 0.45), 16)
	_description_label.text = data.description


func refresh() -> void:
	var level: int = GameState.get_equipment_level(equipment.id)
	var max_level: int = equipment.get_max_level()
	_name_label.text = "%s　%s" % [equipment.display_name, UIText.UPGRADE_LEVEL % [level, max_level]]
	var block: GameState.BuyBlock = GameState.get_buy_block(equipment.id)
	if level >= max_level:
		_effect_label.text = EquipmentText.effect_text(equipment, level)
		_price_label.text = ""
		_note_label.text = UIText.UPGRADE_MAX
		_note_label.modulate = COLOR_OK
	else:
		_effect_label.text = UIText.UPGRADE_EFFECT_CHANGE % [EquipmentText.effect_text(equipment, level), EquipmentText.effect_text(equipment, level + 1)]
		_price_label.text = UIText.money(equipment.get_price(level))
		match block:
			GameState.BuyBlock.RANK:
				_note_label.text = UIText.UPGRADE_NEED_RANK % Database.get_rank_name(equipment.get_required_rank(level))
				_note_label.modulate = COLOR_BLOCKED
			GameState.BuyBlock.MONEY:
				_note_label.text = UIText.UPGRADE_NEED_MONEY % UIText.money(equipment.get_price(level) - GameState.money)
				_note_label.modulate = COLOR_BLOCKED
			_:
				_note_label.text = UIText.UPGRADE_RANK_NOTE % Database.get_rank_name(equipment.get_required_rank(level))
				_note_label.modulate = COLOR_OK
	_buy_button.disabled = block != GameState.BuyBlock.NONE
