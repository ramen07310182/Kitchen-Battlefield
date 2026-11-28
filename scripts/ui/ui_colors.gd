class_name UIColors
extends RefCounted
## 画面の色をまとめる場所（色はここと assets/theme/ のテーマだけに書く）。
## 準備・結果・強化・ポップアップは明るい「定食屋」の色（生成りの背景・こげ茶の文字・藍と朱のアクセント）。
## 営業画面は暗い色のまま（あとでドット絵に差し替えるため）。上部バーはどちらの背景でも読めるように自分の帯を持つ。

# --- 明るい画面の基本の色 ---
## 背景（生成り）
const BACKGROUND := Color("f3e9d2")
## パネル（背景より少し白い）
const PANEL := Color("fbf6ea")
## 一覧の行（明るい木目）
const ROW := Color("efe1c4")
## 暗くした行（今日は出さない料理など）
const ROW_DIM := Color("e6dccb")
## 枠線
const BORDER := Color("c8b28c")
## 文字（こげ茶）と、控えめな文字
const TEXT := Color("3b2a1a")
const TEXT_SUB := Color("6b5844")
## まだ解放していない・使えない物の文字
const TEXT_DISABLED := Color("9c8b74")
## 見出し・ボタンのアクセント（藍色）と、強調（朱色）
const ACCENT := Color("2c4a7a")
const ACCENT_DARK := Color("1f3559")
const ACCENT_LIGHT := Color("d9e2f0")
const VERMILION := Color("c4462c")
## ボタン（押せる・押している・押せない）
const BUTTON := Color("2f5088")
const BUTTON_HOVER := Color("3a5f9c")
const BUTTON_PRESSED := Color("1f3559")
const BUTTON_TEXT := Color("ffffff")
const BUTTON_DISABLED := Color("ddd3c1")
const BUTTON_DISABLED_TEXT := Color("9c8b74")
## 押していない切り替えボタン（休み・期間の選ばれていない方など）
const BUTTON_OFF := Color("f7efdf")
const BUTTON_OFF_TEXT := Color("2c4a7a")

# --- 意味を持つ色（明るい背景で読める濃さ） ---
## 利益のプラス（青）
const PLUS := Color("1d5fb4")
## マイナス・不足・危ない（赤）
const DANGER := Color("bf3326")
## 注意・予定でOK・完売（濃い黄＝山吹）
const WARNING := Color("9a6400")
## よい・足りている（緑）
const GOOD := Color("2e7a32")
## 完売の行・廃棄多めの行・不足の行の背景
const SOLD_OUT_BG := Color("f8e6ad")
const WASTE_BG := Color("f6d4cc")
const SHORT_BG := Color("f6d4cc")
## スタッフの機嫌（ごきげん・ふつう・疲れ気味・限界。StaffMood.Level の順）
const STAFF_MOOD: Array[Color] = [Color("2e7a32"), Color("1d5fb4"), Color("b06200"), Color("bf3326")]
## 0（プラスでもマイナスでもない）
const ZERO := Color("8a7a66")


## 角の丸いパネル（枠線つき）
static func panel_box(color: Color, radius: int = 6, border: Color = BORDER) -> StyleBoxFlat:
	var box: StyleBoxFlat = UIUtil.flat_box(color, border, 1, radius)
	box.content_margin_left = 6
	box.content_margin_right = 6
	box.content_margin_top = 4
	box.content_margin_bottom = 4
	return box


## 切り替えボタン（出勤／休み・期間など）の見た目。on なら藍色、off なら明るい色に藍の文字
static func apply_toggle_style(button: Button, on: bool) -> void:
	var normal: StyleBoxFlat = UIUtil.flat_box(BUTTON if on else BUTTON_OFF, ACCENT, 1, 6)
	var disabled: StyleBoxFlat = UIUtil.flat_box(BUTTON_DISABLED, BUTTON_DISABLED, 1, 6)
	for state: String in ["normal", "hover", "pressed", "focus"]:
		button.add_theme_stylebox_override(state, normal)
	button.add_theme_stylebox_override("disabled", disabled)
	for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(key, BUTTON_TEXT if on else BUTTON_OFF_TEXT)
	button.add_theme_color_override("font_disabled_color", BUTTON_DISABLED_TEXT)


## 金額の色（マイナスは赤、それ以外はふつうの文字の色）
static func money(value: int) -> Color:
	return DANGER if value < 0 else TEXT


## 利益の色（プラスは青、マイナスは赤、0は灰色）
static func profit(value: int) -> Color:
	if value > 0:
		return PLUS
	if value < 0:
		return DANGER
	return ZERO
