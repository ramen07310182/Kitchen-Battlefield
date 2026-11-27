class_name UIUtil
extends RefCounted
## 絵の素材の代わりに使う、単純な図形やスタイルを作る関数。


## 単色の四角いアイコン
static func color_icon(color: Color, icon_size: int = 10) -> ImageTexture:
	var img: Image = Image.create_empty(icon_size, icon_size, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)


static func flat_box(bg: Color, border: Color = Color.TRANSPARENT, border_width: int = 0, radius: int = 2) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(radius)
	box.set_content_margin_all(3)
	return box


## ボタンの見た目をすべての状態で同じ StyleBox にする（タッチ端末ではホバーに意味がないため）
static func apply_button_style(button: Button, box: StyleBox) -> void:
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		button.add_theme_stylebox_override(state, box)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


## 短い名前を狭い枠に入れるときの文字の大きさ（1文字がおよそ文字の大きさの幅になるので、入りきらなければ小さくする）
static func fit_font_size(text: String, width: float, base: int, min_size: int = 8) -> int:
	if text.length() <= 0:
		return base
	return clampi(floori(width / float(text.length())), min_size, base)
