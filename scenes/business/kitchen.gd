class_name Kitchen
extends PanelContainer
## 厨房。料理・トッピングのボタン（2列に並べ、仕込んだ料理が多いときはスクロールする）をタップすると、その料理の「残り」を1つ使って
## 調理待ちに入る。
## 調理するのは店主と、厨房担当のスタッフ（いる日だけ。1人まで）。先に手が空いたほうが、調理待ちの先頭から順に作る。
##   ただし、スタッフは作れる難しさ（研修のレベルで決まる）の料理だけを、調理待ちの先頭から探して作る。作れない料理は店主だけが作る
##   スタッフの調理時間は「設備の効果を入れた調理時間 ÷ スタッフの調理の速さ」
## 食材は営業開始のときに使っているので、ここでは使わない。
## 置き場の空き枠（調理中（2人分）・調理待ちを含む）より多くは作れない。
## 「残りに戻す」で、置き場で持っている料理を残りに戻せる（置き場の枠が空く）。

signal dish_cooked(dish_id: String)
signal return_requested

## 調理する人1人分（店主か、厨房担当のスタッフ）
class Cook:
	extends RefCounted
	## null なら店主
	var staff: StaffData = null
	var current: DishData = null
	var elapsed: float = 0.0
	var duration: float = 0.0
	var figure: SpriteView
	var name_label: Label
	var status_label: Label
	var progress: ProgressBar
	var stove: SpriteView = null

	func is_chef() -> bool:
		return staff == null

	## この人がその料理を作れるか（店主はすべて作れる）
	func can_cook(dish: DishData) -> bool:
		return staff == null or GameState.can_staff_cook(staff, dish)

	func cook_time(dish: DishData) -> float:
		return GameState.get_cook_time(dish) if staff == null else GameState.get_staff_cook_time(staff, dish)


## スタッフが厨房にいる日の、調理の表示の幅（店主とスタッフを横に並べる）
const STATUS_WIDTH_TWO := 214.0
## 「店主のみ」の印の幅（ボタンの文字をこの分だけ狭くする）
const CHEF_ONLY_MARK_WIDTH := 30.0

var _dishes: Array[DishData] = []
var _buttons: Dictionary = {}  # 料理id -> Button
var _chef_only_marks: Dictionary = {}  # 料理id -> Label（スタッフが作れない料理の印）
var _queue: Array[DishData] = []
## 店主（0番目）と、厨房担当のスタッフ（いれば1番目）
var _cooks: Array[Cook] = []
var _free_slots: int = 0
var _supply: DishSupply = null
## 置き場の空き枠がなく、これ以上作れない
var _full: bool = false

@onready var _buttons_box: GridContainer = %CookButtons
@onready var _status_box: VBoxContainer = %Status
@onready var _cooks_row: HBoxContainer = %CooksRow
@onready var _chef_label: Label = %ChefLabel
@onready var _chef_figure: SpriteView = %ChefFigure
@onready var _stove: SpriteView = %Stove
@onready var _status_label: Label = %StatusLabel
@onready var _progress: ProgressBar = %CookProgress
@onready var _queue_label: Label = %QueueLabel
@onready var _return_button: Button = %ReturnButton


func _ready() -> void:
	add_theme_stylebox_override("panel", UISkin.panel_box(SpriteKeys.KITCHEN_BACK, UIUtil.flat_box(UIColors.BIZ_PANEL)))
	_chef_label.text = UIText.CHEF
	_return_button.text = UIText.COOK_RETURN
	_return_button.disabled = true
	_return_button.pressed.connect(return_requested.emit)
	var chef: Cook = Cook.new()
	chef.figure = _chef_figure
	chef.name_label = _chef_label
	chef.status_label = _status_label
	chef.progress = _progress
	chef.stove = _stove
	_cooks.append(chef)


## kitchen_staff: 今日厨房に入るスタッフ（いなければ null。店主だけで作る）
func setup(menu_dishes: Array[DishData], supply: DishSupply, kitchen_staff: StaffData = null) -> void:
	_dishes = menu_dishes
	_supply = supply
	_supply.changed.connect(_refresh_buttons)
	if kitchen_staff != null:
		_add_staff_cook(kitchen_staff)
	for dish: DishData in _dishes:
		var button: Button = Button.new()
		button.custom_minimum_size = Vector2(0, 28)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var dish_icon: Texture2D = SpriteLibrary.get_icon(SpriteKeys.dish(dish.id))
		button.icon = dish_icon if dish_icon != null else UIUtil.color_icon(dish.color, 10)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.clip_text = true
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.pressed.connect(_on_cook_pressed.bind(dish))
		_buttons_box.add_child(button)
		_buttons[dish.id] = button
		if kitchen_staff != null and not GameState.can_staff_cook(kitchen_staff, dish):
			_chef_only_marks[dish.id] = _make_chef_only_mark(button)
	_refresh_buttons()
	_refresh_status()


## 厨房担当のスタッフの表示（絵・名前・調理中の料理・進み具合のバー）を店主の横に足す
func _add_staff_cook(data: StaffData) -> void:
	_status_box.custom_minimum_size.x = STATUS_WIDTH_TWO
	var cook: Cook = Cook.new()
	cook.staff = data
	var box: VBoxContainer = VBoxContainer.new()
	box.name = "StaffBox"
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 2)
	_cooks_row.add_child(box)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	box.add_child(row)
	# 絵の差し替え口はホールと同じ staff/<id>.png（なければ体の色の四角）
	var figure: SpriteView = SpriteView.new()
	figure.custom_minimum_size = Vector2(32, 32)
	figure.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var body: ColorRect = ColorRect.new()
	body.position = Vector2(9, 14)
	body.size = Vector2(14, 18)
	body.color = data.color
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	figure.add_child(body)
	var head: ColorRect = ColorRect.new()
	head.position = Vector2(11, 5)
	head.size = Vector2(10, 9)
	head.color = Color(0.98, 0.85, 0.7)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	figure.add_child(head)
	figure.set_sprite(SpriteKeys.staff(data.id), SpriteKeys.ANIM_IDLE)
	row.add_child(figure)
	var texts: VBoxContainer = VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	texts.add_theme_constant_override("separation", 0)
	row.add_child(texts)
	var name_label: Label = Label.new()
	name_label.theme_type_variation = &"SmallLabel"
	name_label.add_theme_color_override("font_color", _chef_label.get_theme_color("font_color"))
	name_label.text = data.display_name
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	texts.add_child(name_label)
	var status: Label = Label.new()
	status.clip_text = true
	status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	texts.add_child(status)
	var progress: ProgressBar = ProgressBar.new()
	progress.custom_minimum_size = Vector2(0, 6)
	progress.max_value = 1.0
	progress.step = 0.0
	progress.show_percentage = false
	box.add_child(progress)
	cook.figure = figure
	cook.name_label = name_label
	cook.status_label = status
	cook.progress = progress
	_cooks.append(cook)


## ボタンの右上に「店主のみ」の小さな印を付ける
func _make_chef_only_mark(button: Button) -> Label:
	var mark: Label = Label.new()
	mark.text = UIText.COOK_CHEF_ONLY
	mark.add_theme_font_size_override("font_size", 8)
	mark.add_theme_color_override("font_color", UIColors.BIZ_CHEF_ONLY_TEXT)
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = UIColors.BIZ_CHEF_ONLY_BG
	box.set_corner_radius_all(2)
	box.content_margin_left = 2.0
	box.content_margin_right = 2.0
	mark.add_theme_stylebox_override("normal", box)
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	mark.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	mark.offset_top = 1.0
	mark.offset_right = -2.0
	button.add_child(mark)
	return mark


## 厨房担当のスタッフ（いなければ null）
func get_kitchen_staff() -> StaffData:
	return _cooks[1].staff if _cooks.size() > 1 else null


## 調理中の料理（店主・スタッフの順。手が空いている人の分は入れない）
func get_cooking() -> Array[DishData]:
	var result: Array[DishData] = []
	for cook: Cook in _cooks:
		if cook.current != null:
			result.append(cook.current)
	return result


## スタッフが作れない料理に「店主のみ」の印が付いているか（テスト用）
func has_chef_only_mark(dish_id: String) -> bool:
	return _chef_only_marks.has(dish_id)


## 置き場の空き枠数を知らせてもらう
func set_free_slots(count: int) -> void:
	_free_slots = count
	_refresh_buttons()


## 置き場で料理を持っているときだけ「残りに戻す」を押せる
func set_holding(holding: bool) -> void:
	_return_button.disabled = not holding


## 調理待ちの分と作っている分（2人分）の合計
func get_pending_count() -> int:
	return _queue.size() + get_cooking().size()


func _process(delta: float) -> void:
	var finished: bool = false
	for cook: Cook in _cooks:
		if cook.current == null:
			_start_next(cook)
		if cook.current == null:
			continue
		cook.elapsed += delta
		if cook.elapsed >= cook.duration:
			var finished_id: String = cook.current.id
			GameState.record_cooked(not cook.is_chef(), cook.duration)
			cook.current = null
			finished = true
			dish_cooked.emit(finished_id)
	if finished:
		_refresh_buttons()
	_refresh_status()


## 手の空いた人に、調理待ちの先頭から（その人が作れる料理を）渡す
func _start_next(cook: Cook) -> void:
	for i: int in _queue.size():
		if cook.can_cook(_queue[i]):
			cook.current = _queue[i]
			_queue.remove_at(i)
			cook.elapsed = 0.0
			cook.duration = cook.cook_time(cook.current)
			return


func _can_cook(dish: DishData) -> bool:
	return _supply.get_remaining(dish.id) > 0 and get_pending_count() < _free_slots


func _on_cook_pressed(dish: DishData) -> void:
	if not _can_cook(dish):
		return
	if not _supply.take_for_cooking(dish.id):
		return
	_queue.append(dish)
	_refresh_buttons()


func _refresh_buttons() -> void:
	if _supply == null:
		return
	var full: bool = get_pending_count() >= _free_slots
	for dish: DishData in _dishes:
		var button: Button = _buttons[dish.id]
		var remaining: int = _supply.get_remaining(dish.id)
		button.disabled = not _can_cook(dish)
		button.text = UIText.COOK_BUTTON % [_button_name(dish), remaining]
		# 名前が長いときは文字を小さくして、残りの数が切れないようにする（「店主のみ」の印の分も空ける）
		if button.size.x > 0.0:
			var room: float = button.size.x - 22.0 - (CHEF_ONLY_MARK_WIDTH if _chef_only_marks.has(dish.id) else 0.0)
			button.add_theme_font_size_override("font_size", UIUtil.fit_font_size(button.text, room, 13, 9))
	_full = full


## トッピングのボタンは「＋卵焼き」のように出す
static func _button_name(dish: DishData) -> String:
	return UIText.ORDER_TOPPING % dish.short_name if dish.is_topping() else dish.short_name


func _refresh_status() -> void:
	var two: bool = _cooks.size() > 1
	for cook: Cook in _cooks:
		var anim: String = SpriteKeys.ANIM_COOK if cook.current != null else SpriteKeys.ANIM_IDLE
		cook.figure.animation = anim
		if cook.stove != null:
			cook.stove.animation = anim
		if cook.current != null:
			# 2人のときは幅が狭いので、料理の短い名前だけを出す
			cook.status_label.text = cook.current.short_name if two else UIText.COOKING % cook.current.display_name
			cook.progress.value = clampf(cook.elapsed / maxf(cook.duration, 0.01), 0.0, 1.0)
		else:
			cook.status_label.text = UIText.COOK_FULL_SHORT if _full and two else (UIText.COOK_FULL if _full else UIText.COOK_IDLE)
			cook.progress.value = 0.0
	if _queue.is_empty():
		_queue_label.text = UIText.COOK_QUEUE_EMPTY
	else:
		var names: PackedStringArray = PackedStringArray()
		for dish: DishData in _queue:
			names.append(dish.short_name)
		_queue_label.text = UIText.COOK_QUEUE % "・".join(names)
