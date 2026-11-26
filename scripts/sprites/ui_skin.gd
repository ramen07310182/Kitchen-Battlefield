class_name UISkin
extends RefCounted
## UIの絵（ボタン・枠）があれば、テーマに入れて全画面のボタンに使う。なければ今の見た目のまま。
## 色で状態を表すボタン（完成品置き場の枠など）は、各画面で個別に色を付けているので対象外。


## 起動時に1回呼ぶ（main.gd）
static func apply_to_project_theme() -> void:
	var theme: Theme = ThemeDB.get_project_theme()
	if theme == null:
		return
	var normal: StyleBoxTexture = SpriteLibrary.get_style_box(SpriteKeys.BUTTON_NORMAL)
	if normal == null:
		return
	var pressed: StyleBox = SpriteLibrary.get_style_box(SpriteKeys.BUTTON_PRESSED)
	var disabled: StyleBox = SpriteLibrary.get_style_box(SpriteKeys.BUTTON_DISABLED)
	if pressed == null:
		pressed = normal
	if disabled == null:
		var dim: StyleBoxTexture = normal.duplicate() as StyleBoxTexture
		dim.modulate_color = Color(0.6, 0.6, 0.6)
		disabled = dim
	# タッチ端末ではホバーに意味がないので、ホバー中も同じ見た目にする
	theme.set_stylebox("normal", "Button", normal)
	theme.set_stylebox("hover", "Button", normal)
	theme.set_stylebox("pressed", "Button", pressed)
	theme.set_stylebox("hover_pressed", "Button", pressed)
	theme.set_stylebox("disabled", "Button", disabled)
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())


## 枠・背景: 絵があれば絵の枠、なければ代わりの StyleBox
static func panel_box(key: String, fallback: StyleBox) -> StyleBox:
	var box: StyleBoxTexture = SpriteLibrary.get_style_box(key)
	return box if box != null else fallback
