extends SceneTree
## 明るい画面のテーマ（assets/theme/bright_theme.tres）を、UIColors の色から作り直す。
## 色を変えたら、これを実行してテーマを作り直す:
##   Godot --headless --path . --script res://tests/tools/make_bright_theme.gd
## フォントと文字の大きさは assets/theme/main_theme.tres（プロジェクトのテーマ）のものを使う（ここでは色と枠だけ決める）。

const OUT_PATH := "res://assets/theme/bright_theme.tres"


## フォントと文字の大きさを借りるプロジェクトのテーマ
var _project_theme: Theme


func _init() -> void:
	_project_theme = load("res://assets/theme/main_theme.tres") as Theme
	var theme: Theme = Theme.new()
	# 文字
	theme.set_color("font_color", "Label", UIColors.TEXT)
	# 文字の色だけを変えた種類（文字の大きさは元の種類から）
	_variation(theme, "SubLabel", "SmallLabel", UIColors.TEXT_SUB)
	_variation(theme, "InfoLabel", "SmallLabel", UIColors.PLUS)
	_variation(theme, "DangerSmallLabel", "SmallLabel", UIColors.DANGER)
	_variation(theme, "WarningLabel", "Label", UIColors.WARNING)
	_variation(theme, "GoldLargeLabel", "LargeLabel", UIColors.WARNING)
	_variation(theme, "VermilionHeaderLabel", "HeaderLabel", UIColors.VERMILION)
	_variation(theme, "GoodHeaderLabel", "HeaderLabel", UIColors.GOOD)
	_variation(theme, "SectionLabel", "HeaderLabel", UIColors.ACCENT)
	# ボタン（押せる＝藍色、押せない＝薄いベージュ）
	theme.set_stylebox("normal", "Button", _box(UIColors.BUTTON, UIColors.ACCENT_DARK, 6))
	theme.set_stylebox("hover", "Button", _box(UIColors.BUTTON_HOVER, UIColors.ACCENT_DARK, 6))
	theme.set_stylebox("pressed", "Button", _box(UIColors.BUTTON_PRESSED, UIColors.ACCENT_DARK, 6))
	theme.set_stylebox("hover_pressed", "Button", _box(UIColors.BUTTON_PRESSED, UIColors.ACCENT_DARK, 6))
	theme.set_stylebox("disabled", "Button", _box(UIColors.BUTTON_DISABLED, UIColors.BORDER, 6))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		theme.set_color(key, "Button", UIColors.BUTTON_TEXT)
	theme.set_color("font_disabled_color", "Button", UIColors.BUTTON_DISABLED_TEXT)
	# パネル
	theme.set_stylebox("panel", "PanelContainer", _box(UIColors.PANEL, UIColors.BORDER, 6))
	theme.set_stylebox("panel", "Panel", _box(UIColors.PANEL, UIColors.BORDER, 6))
	var err: Error = ResourceSaver.save(theme, OUT_PATH)
	print("[theme] saved %s (%d)" % [OUT_PATH, err])
	quit(0 if err == OK else 1)


## 色だけを変えた種類。テーマをまたぐと元の種類の大きさが引き継がれないので、文字の大きさとフォントも写しておく
func _variation(theme: Theme, name: String, base: String, color: Color) -> void:
	theme.set_type_variation(name, base)
	theme.set_color("font_color", name, color)
	if _project_theme != null:
		if _project_theme.has_font_size("font_size", base):
			theme.set_font_size("font_size", name, _project_theme.get_font_size("font_size", base))
		if _project_theme.has_font("font", base):
			theme.set_font("font", name, _project_theme.get_font("font", base))


func _box(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	box.set_content_margin_all(4)
	return box
