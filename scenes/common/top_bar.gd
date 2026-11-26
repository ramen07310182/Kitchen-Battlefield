class_name TopBar
extends PanelContainer
## 画面上部の情報（日数・所持金・店舗ランクと評判・残り時間）。
## 評判の下に、次のランクまでの進み具合を細いバーで出す。

@export var show_time: bool = true

@onready var _day_label: Label = %DayLabel
@onready var _money_label: Label = %MoneyLabel
@onready var _reputation_label: Label = %ReputationLabel
@onready var _rank_bar: ProgressBar = %RankBar
@onready var _time_label: Label = %TimeLabel


func _ready() -> void:
	add_theme_stylebox_override("panel", UISkin.panel_box(SpriteKeys.PANEL, UIUtil.flat_box(Color(0.12, 0.1, 0.1, 0.9), Color.TRANSPARENT, 0, 2)))
	var bar_bg: StyleBoxFlat = UIUtil.flat_box(Color(1, 1, 1, 0.12), Color.TRANSPARENT, 0, 1)
	bar_bg.set_content_margin_all(0)
	var bar_fill: StyleBoxFlat = UIUtil.flat_box(Color(1.0, 0.82, 0.35), Color.TRANSPARENT, 0, 1)
	bar_fill.set_content_margin_all(0)
	_rank_bar.add_theme_stylebox_override("background", bar_bg)
	_rank_bar.add_theme_stylebox_override("fill", bar_fill)
	_time_label.visible = show_time
	GameState.money_changed.connect(_on_money_changed)
	GameState.reputation_changed.connect(_on_reputation_changed)
	_day_label.text = UIText.DAY % GameState.day
	_on_money_changed(GameState.money)
	_on_reputation_changed(GameState.reputation)


func set_time_left(seconds: float, is_open: bool, sold_out: bool = false) -> void:
	if not is_open:
		_time_label.text = UIText.TIME_SOLD_OUT if sold_out else UIText.TIME_CLOSED
		_time_label.modulate = Color(1.0, 0.6, 0.5)
		return
	var total: int = ceili(seconds)
	_time_label.text = UIText.TIME_LEFT % [total / 60, total % 60]
	_time_label.modulate = Color(1.0, 0.85, 0.4) if total <= 20 else Color.WHITE


func _on_money_changed(value: int) -> void:
	_money_label.text = UIText.money(value)


func _on_reputation_changed(value: int) -> void:
	_reputation_label.text = UIText.REPUTATION_WITH_RANK % [GameState.get_rank_name(), value]
	_rank_bar.value = GameState.get_rank_progress()
