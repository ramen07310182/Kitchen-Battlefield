class_name RecordsChart
extends Control
## 記録の画面のグラフ。日ごとの売上（棒・左の目盛り）と、その日の営業が終わった時点の所持金（折れ線・右の目盛り）を描く。
## 所持金がマイナスの部分は赤で描く。所持金の記録がない日（古いセーブ）は折れ線を描かない。
## グラフをタップ（クリック）すると、いちばん近い日を選んで day_selected で知らせ、その日に縦の線を引く。
## 絵の素材は使わず、_draw で描く。

signal day_selected(row: PackedInt32Array)

const COLOR_BAR := UIColors.CHART_BAR
const COLOR_BAR_SELECTED := UIColors.CHART_BAR_SELECTED
const COLOR_LINE := UIColors.CHART_LINE
const COLOR_LINE_NEGATIVE := UIColors.DANGER
const COLOR_AXIS := UIColors.CHART_AXIS
const COLOR_GRID := UIColors.CHART_GRID
const COLOR_ZERO := UIColors.ZERO
const COLOR_TEXT := UIColors.TEXT_SUB
const COLOR_SELECT := UIColors.CHART_SELECT
## グラフの左右・上下の余白（目盛りの文字のぶん）
const MARGIN_LEFT := 52.0
const MARGIN_RIGHT := 60.0
const MARGIN_TOP := 8.0
const MARGIN_BOTTOM := 16.0
const FONT_SIZE := 10

## 描く日の行（GameState.history の行。日の順）
var _rows: Array[PackedInt32Array] = []
var _selected: int = -1
var _sales_max: float = 1.0
var _money_min: float = 0.0
var _money_max: float = 1.0
var _has_money: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)


## rows: 描く日の行（日の順）
func set_rows(rows: Array[PackedInt32Array]) -> void:
	_rows = rows
	_selected = -1
	_sales_max = 1.0
	_money_min = 0.0
	_money_max = 1.0
	_has_money = false
	for row: PackedInt32Array in _rows:
		_sales_max = maxf(_sales_max, float(row[GameState.HISTORY_SALES]))
		if GameState.has_history_money(row):
			var m: float = float(row[GameState.HISTORY_MONEY])
			if not _has_money:
				_money_min = minf(0.0, m)
				_money_max = maxf(1.0, m)
			_has_money = true
			_money_min = minf(_money_min, m)
			_money_max = maxf(_money_max, m)
	_sales_max = _nice_ceiling(_sales_max)
	# 所持金の目盛りは、0をまたいでもきりのよい数になるように、4等分の幅をきりのよい数にして下と上をそろえる
	var money_step: float = _nice_step((_money_max - _money_min) / 4.0)
	_money_min = floorf(_money_min / money_step) * money_step
	while _money_min + money_step * 4.0 < _money_max:
		money_step = _nice_step(money_step * 1.01)
		_money_min = floorf(minf(_money_min, 0.0) / money_step) * money_step
	_money_max = _money_min + money_step * 4.0
	queue_redraw()


## 選んでいる日の行（選んでいなければ空）
func get_selected_row() -> PackedInt32Array:
	return _rows[_selected] if _selected >= 0 and _selected < _rows.size() else PackedInt32Array()


## index 番目の日を選ぶ（テスト・見た目の確認用にも使う）
func select_index(index: int) -> void:
	if _rows.is_empty():
		return
	_selected = clampi(index, 0, _rows.size() - 1)
	queue_redraw()
	day_selected.emit(_rows[_selected])


func _gui_input(event: InputEvent) -> void:
	var pressed: bool = false
	var pos: Vector2 = Vector2.ZERO
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		pressed = mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT
		pos = mb.position
	elif event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		pressed = touch.pressed
		pos = touch.position
	if pressed and not _rows.is_empty():
		select_index(_index_at(pos.x))
		accept_event()


func _plot_rect() -> Rect2:
	return Rect2(MARGIN_LEFT, MARGIN_TOP, maxf(10.0, size.x - MARGIN_LEFT - MARGIN_RIGHT),
		maxf(10.0, size.y - MARGIN_TOP - MARGIN_BOTTOM))


## index 番目の日の、横の中心の位置
func _x_of(index: int) -> float:
	var plot: Rect2 = _plot_rect()
	var step: float = plot.size.x / maxf(1.0, float(_rows.size()))
	return plot.position.x + step * (index + 0.5)


func _index_at(x: float) -> int:
	var plot: Rect2 = _plot_rect()
	var step: float = plot.size.x / maxf(1.0, float(_rows.size()))
	return clampi(floori((x - plot.position.x) / step), 0, _rows.size() - 1)


func _sales_y(value: float) -> float:
	var plot: Rect2 = _plot_rect()
	return plot.end.y - plot.size.y * clampf(value / _sales_max, 0.0, 1.0)


func _money_y(value: float) -> float:
	var plot: Rect2 = _plot_rect()
	return plot.end.y - plot.size.y * (value - _money_min) / maxf(1.0, _money_max - _money_min)


func _draw() -> void:
	var plot: Rect2 = _plot_rect()
	var font: Font = get_theme_default_font()
	# 目盛りの線（4本）と、左（売上）・右（所持金）の目盛りの文字
	for i: int in 5:
		var y: float = plot.end.y - plot.size.y * i / 4.0
		draw_line(Vector2(plot.position.x, y), Vector2(plot.end.x, y), COLOR_GRID, 1.0)
		_draw_text(font, UIText.money_short(roundi(_sales_max * i / 4.0)), Vector2(2.0, y + 4.0), UIColors.WARNING, MARGIN_LEFT - 6.0, HORIZONTAL_ALIGNMENT_RIGHT)
		if _has_money:
			var money_value: float = _money_min + (_money_max - _money_min) * i / 4.0
			_draw_text(font, UIText.money_short(roundi(money_value)), Vector2(plot.end.x + 4.0, y + 4.0),
				COLOR_LINE_NEGATIVE if money_value < 0.0 else COLOR_LINE, MARGIN_RIGHT - 6.0, HORIZONTAL_ALIGNMENT_LEFT)
	draw_rect(plot, COLOR_AXIS, false, 1.0)
	if _rows.is_empty():
		return
	# 売上の棒
	var step: float = plot.size.x / float(_rows.size())
	var bar_width: float = maxf(1.0, step * 0.7)
	for i: int in _rows.size():
		var top: float = _sales_y(float(_rows[i][GameState.HISTORY_SALES]))
		draw_rect(Rect2(_x_of(i) - bar_width * 0.5, top, bar_width, plot.end.y - top), COLOR_BAR_SELECTED if i == _selected else COLOR_BAR)
	# 所持金の0の線（マイナスがあるとき）
	if _has_money and _money_min < 0.0:
		var zero_y: float = _money_y(0.0)
		draw_dashed_line(Vector2(plot.position.x, zero_y), Vector2(plot.end.x, zero_y), COLOR_ZERO, 1.0, 4.0)
	# 所持金の折れ線（記録のある日どうしをつなぐ。マイナスの部分は赤）
	var prev: Vector2 = Vector2.INF
	var prev_value: float = 0.0
	for i: int in _rows.size():
		if not GameState.has_history_money(_rows[i]):
			prev = Vector2.INF
			continue
		var value: float = float(_rows[i][GameState.HISTORY_MONEY])
		var point: Vector2 = Vector2(_x_of(i), _money_y(value))
		if prev != Vector2.INF:
			_draw_money_segment(prev, prev_value, point, value)
		var dot: float = 2.5 if _rows.size() <= 90 else 1.5
		draw_circle(point, dot, COLOR_LINE_NEGATIVE if value < 0.0 else COLOR_LINE)
		prev = point
		prev_value = value
	# 選んでいる日の縦の線
	if _selected >= 0:
		var x: float = _x_of(_selected)
		draw_line(Vector2(x, plot.position.y), Vector2(x, plot.end.y), COLOR_SELECT, 1.0)


## 2日の間の折れ線。0をまたぐときは、0のところで色を分ける
func _draw_money_segment(a: Vector2, a_value: float, b: Vector2, b_value: float) -> void:
	if (a_value < 0.0) == (b_value < 0.0):
		draw_line(a, b, COLOR_LINE_NEGATIVE if a_value < 0.0 else COLOR_LINE, 2.0)
		return
	var t: float = a_value / (a_value - b_value)
	var mid: Vector2 = a.lerp(b, t)
	draw_line(a, mid, COLOR_LINE_NEGATIVE if a_value < 0.0 else COLOR_LINE, 2.0)
	draw_line(mid, b, COLOR_LINE_NEGATIVE if b_value < 0.0 else COLOR_LINE, 2.0)


func _draw_text(font: Font, text: String, pos: Vector2, color: Color, width: float, align: HorizontalAlignment) -> void:
	draw_string(font, pos, text, align, width, FONT_SIZE, color)


## きりのよい目盛りの幅（1・2・2.5・5 × 10の累乗）に切り上げる
static func _nice_step(value: float) -> float:
	if value <= 0.0:
		return 1.0
	var magnitude: float = pow(10.0, floorf(log(value) / log(10.0)))
	for f: float in [1.0, 2.0, 2.5, 5.0, 10.0]:
		if value <= f * magnitude + 0.0001:
			return f * magnitude
	return 10.0 * magnitude


## 目盛り（4等分）がきりのよい数になるように、上の端を切り上げる（1・2・4・8 × 10の累乗）
static func _nice_ceiling(value: float) -> float:
	if value <= 0.0:
		return 1.0
	var magnitude: float = pow(10.0, floorf(log(value) / log(10.0)))
	for f: float in [1.0, 2.0, 4.0, 8.0, 10.0]:
		if value <= f * magnitude:
			return f * magnitude
	return 10.0 * magnitude
