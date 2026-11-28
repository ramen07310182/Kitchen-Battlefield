class_name StaffRow
extends PanelContainer
## 強化画面の「従業員」の1行: 名前（と研修のレベル）・配膳の速さ・毎週の休み・在籍日数・日給と、ボタン。
##   雇っていない人: 「雇う」（面接代がかかる）。人数の上限・退職したばかり（○日後から雇える）・面接代が足りないときは押せない
##   雇っている人:   「研修」（レベルを上げる。速くなり、日給も少し上がる）。最大レベル・代金が足りないときは押せない。退職までの残りの日数を出す
## ボタン以外の所を長押しで詳細（今と次のレベルの比較など）。

signal hire_requested(staff_id: String)
signal train_requested(staff_id: String)
signal detail_requested(staff_id: String)
signal detail_closed

var staff: StaffData

var _icon: TextureRect
var _name_label: Label
var _speed_label: Label
var _info_label: Label
var _wage_label: Label
var _note_label: Label
## 研修の代金（雇っている人だけ）
var _train_label: Label
var _button: Button


func _init() -> void:
	add_theme_stylebox_override("panel", UIColors.card_box())
	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	add_child(hbox)
	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(24, 32)
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(_icon)
	var texts: VBoxContainer = VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 0)
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(texts)
	_name_label = Label.new()
	texts.add_child(_name_label)
	_speed_label = Label.new()
	_speed_label.theme_type_variation = &"SmallLabel"
	_speed_label.add_theme_color_override("font_color", UIColors.TEXT_SUB)
	_speed_label.clip_text = true
	_speed_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	texts.add_child(_speed_label)
	_info_label = Label.new()
	_info_label.theme_type_variation = &"SmallLabel"
	_info_label.add_theme_color_override("font_color", UIColors.TEXT_SUB)
	_info_label.clip_text = true
	_info_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	texts.add_child(_info_label)
	var right: VBoxContainer = VBoxContainer.new()
	right.custom_minimum_size = Vector2(170, 0)
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(right)
	_wage_label = Label.new()
	_wage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(_wage_label)
	_note_label = Label.new()
	_note_label.theme_type_variation = &"SmallLabel"
	_note_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(_note_label)
	_train_label = Label.new()
	_train_label.theme_type_variation = &"SmallLabel"
	_train_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(_train_label)
	_button = Button.new()
	_button.custom_minimum_size = Vector2(96, 40)
	_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_button.pressed.connect(_on_pressed)
	hbox.add_child(_button)
	var long_press: LongPressDetector = LongPressDetector.new()
	add_child(long_press)
	long_press.long_pressed.connect(func() -> void: detail_requested.emit(staff.id))
	long_press.finished.connect(detail_closed.emit)


func setup(data: StaffData) -> void:
	staff = data
	# 絵（assets/sprites/staff/<id>.png）があれば絵、なければ色の四角
	var icon: Texture2D = SpriteLibrary.get_icon(SpriteKeys.staff(data.id))
	_icon.texture = icon if icon != null else UIUtil.color_icon(data.color, 16)


func refresh() -> void:
	var level: int = GameState.get_staff_level(staff.id)
	_name_label.text = "%s　%s" % [staff.display_name, UIText.UPGRADE_STAFF_LEVEL % level]
	_speed_label.text = UIText.UPGRADE_STAFF_SPEED % [StaffRow.speed_name(GameState.get_staff_walk_speed(staff)), GameState.get_staff_pick_time(staff)]
	_info_label.text = "%s　%s" % [StaffRow.days_off_text(staff), UIText.UPGRADE_STAFF_TENURE % staff.tenure_days]
	_wage_label.text = UIText.UPGRADE_STAFF_WAGE % UIText.money(GameState.get_staff_wage(staff))
	if GameState.is_hired(staff.id):
		_refresh_hired(level)
	else:
		_refresh_candidate()


## 雇っている人: 研修のボタンと、退職までの残りの日数・研修の代金
func _refresh_hired(level: int) -> void:
	_button.text = UIText.UPGRADE_STAFF_TRAIN
	var block: GameState.TrainBlock = GameState.get_train_block(staff.id)
	_button.disabled = block != GameState.TrainBlock.NONE
	var days_left: String = UIText.UPGRADE_STAFF_HIRED % GameState.get_staff_days_left(staff.id)
	var train_text: String
	match block:
		GameState.TrainBlock.MAX_LEVEL:
			train_text = UIText.UPGRADE_STAFF_TRAIN_MAX
		GameState.TrainBlock.MONEY:
			train_text = UIText.UPGRADE_STAFF_TRAIN_NEED_MONEY % UIText.money(Database.staff_training.get_price(level) - GameState.money)
		_:
			train_text = UIText.UPGRADE_STAFF_TRAIN_PRICE % [UIText.money(Database.staff_training.get_price(level)), level, level + 1]
	_note_label.text = days_left
	_note_label.add_theme_color_override("font_color", UIColors.PLUS)
	_train_label.visible = true
	_train_label.text = train_text
	_train_label.add_theme_color_override("font_color", UIColors.DANGER if block == GameState.TrainBlock.MONEY else UIColors.TEXT_SUB)


## 雇っていない人: 雇うボタンと、面接代・雇えない理由
func _refresh_candidate() -> void:
	_train_label.visible = false
	_button.text = UIText.UPGRADE_STAFF_HIRE
	var block: GameState.HireBlock = GameState.get_hire_block(staff.id)
	_button.disabled = block != GameState.HireBlock.NONE
	var fee: int = Database.config.staff_interview_fee
	match block:
		GameState.HireBlock.NONE:
			_note_label.text = UIText.UPGRADE_STAFF_FEE % UIText.money(fee)
			_note_label.add_theme_color_override("font_color", UIColors.TEXT_SUB)
		GameState.HireBlock.WAIT:
			_note_label.text = UIText.UPGRADE_STAFF_WAIT % GameState.get_rehire_wait(staff.id)
			_note_label.add_theme_color_override("font_color", UIColors.WARNING)
		GameState.HireBlock.MONEY:
			_note_label.text = UIText.UPGRADE_STAFF_NEED_FEE % UIText.money(fee - GameState.money)
			_note_label.add_theme_color_override("font_color", UIColors.DANGER)
		_:
			if GameState.get_staff_limit() <= 0:
				_note_label.text = UIText.UPGRADE_STAFF_NEED_RANK % Database.get_rank_name(StaffRow.first_rank_with_staff())
			else:
				_note_label.text = UIText.UPGRADE_STAFF_FULL
			_note_label.add_theme_color_override("font_color", UIColors.DANGER)


func _on_pressed() -> void:
	if GameState.is_hired(staff.id):
		train_requested.emit(staff.id)
	else:
		hire_requested.emit(staff.id)


## 詳細（長押し）の行: 速さ・日給・毎週の休み・急な休み・在籍日数・退職まで（雇い直せるまで）・今と次のレベル
static func detail_lines(data: StaffData) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	var level: int = GameState.get_staff_level(data.id)
	var training: StaffTrainingData = Database.staff_training
	lines.append(UIText.UPGRADE_STAFF_DETAIL_DAYS_OFF % UIText.weekday_list(data.days_off))
	lines.append(UIText.UPGRADE_STAFF_DETAIL_ABSENCE % roundi(data.absence_rate * 100.0))
	lines.append(UIText.UPGRADE_STAFF_DETAIL_TENURE % data.tenure_days)
	if GameState.is_hired(data.id):
		lines.append(UIText.UPGRADE_STAFF_DETAIL_DAYS_LEFT % GameState.get_staff_days_left(data.id))
	elif GameState.get_rehire_wait(data.id) > 0:
		lines.append(UIText.UPGRADE_STAFF_DETAIL_WAIT % GameState.get_rehire_wait(data.id))
	lines.append(UIText.UPGRADE_STAFF_DETAIL_LEVEL_NOW % [level, roundi(data.walk_speed * training.get_speed_scale(level)),
		data.pick_time * training.get_pick_scale(level), UIText.money(data.daily_wage + training.get_wage_add(level))])
	if training.get_price(level) >= 0:
		var next: int = level + 1
		lines.append(UIText.UPGRADE_STAFF_DETAIL_LEVEL_NEXT % [next, roundi(data.walk_speed * training.get_speed_scale(next)),
			data.pick_time * training.get_pick_scale(next), UIText.money(data.daily_wage + training.get_wage_add(next)),
			UIText.money(training.get_price(level))])
	else:
		lines.append(UIText.UPGRADE_STAFF_DETAIL_LEVEL_MAX)
	return lines


static func days_off_text(data: StaffData) -> String:
	return UIText.UPGRADE_STAFF_DAYS_OFF % UIText.weekday_list(data.days_off) if not data.days_off.is_empty() \
		else UIText.UPGRADE_STAFF_NO_DAYS_OFF


## 歩く速さの呼び方（ゆっくり・ふつう・速い・とても速い）
static func speed_name(walk_speed: float) -> String:
	if walk_speed < 105.0:
		return UIText.UPGRADE_STAFF_SPEED_NAMES[0]
	if walk_speed < 135.0:
		return UIText.UPGRADE_STAFF_SPEED_NAMES[1]
	if walk_speed < 165.0:
		return UIText.UPGRADE_STAFF_SPEED_NAMES[2]
	return UIText.UPGRADE_STAFF_SPEED_NAMES[3]


## 従業員を雇えるようになる最初のランク
static func first_rank_with_staff() -> int:
	for r: int in range(1, Database.get_max_rank() + 1):
		if Database.get_staff_limit(r) > 0:
			return r
	return Database.get_max_rank()
