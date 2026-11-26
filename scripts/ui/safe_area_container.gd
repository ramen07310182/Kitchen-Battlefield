class_name SafeAreaContainer
extends MarginContainer
## ノッチやホームバーを避けるため、セーフエリアに合わせて余白を付けるコンテナ。
## スマホ・タブレットでのみ DisplayServer.get_display_safe_area() を使う。

@export var base_margin: int = 4


func _ready() -> void:
	get_viewport().size_changed.connect(_update_margins)
	_update_margins()


func _update_margins() -> void:
	var left: int = base_margin
	var top: int = base_margin
	var right: int = base_margin
	var bottom: int = base_margin
	if OS.has_feature("mobile"):
		var safe: Rect2i = DisplayServer.get_display_safe_area()
		var window_size: Vector2i = DisplayServer.window_get_size()
		var visible_size: Vector2 = get_viewport().get_visible_rect().size
		if window_size.x > 0 and window_size.y > 0 and safe.size.x > 0 and safe.size.y > 0:
			var scale_x: float = visible_size.x / float(window_size.x)
			var scale_y: float = visible_size.y / float(window_size.y)
			left += ceili(safe.position.x * scale_x)
			top += ceili(safe.position.y * scale_y)
			right += ceili(maxf(0.0, window_size.x - safe.end.x) * scale_x)
			bottom += ceili(maxf(0.0, window_size.y - safe.end.y) * scale_y)
	add_theme_constant_override("margin_left", left)
	add_theme_constant_override("margin_top", top)
	add_theme_constant_override("margin_right", right)
	add_theme_constant_override("margin_bottom", bottom)
