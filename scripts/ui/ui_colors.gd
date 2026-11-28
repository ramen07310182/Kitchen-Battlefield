class_name UIColors
extends RefCounted
## 画面の色をまとめる場所（色はここと assets/theme/ のテーマだけに書く）。
## 準備・結果・強化・ポップアップは明るい「定食屋」の色（生成りの背景・こげ茶の文字・藍と朱のアクセント）。
## 営業画面は暗い色のまま（あとでドット絵に差し替えるため）。上部バーはどちらの背景でも読めるように自分の帯を持つ。

# --- 明るい画面の基本の色 ---
## 背景（生成り）
const BACKGROUND := Color("f3e9d2")
## 一覧を囲むパネル（背景と行の中間の色。枠で囲む）。背景・パネル・行の3段階が見分けられるようにする
const PANEL := Color("faf4e6")
const PANEL_BORDER := Color("c8b28c")
## 一覧の行（白に近いカード。濃い枠線と、下に薄い影）
const ROW := Color("fffdf8")
const CARD := ROW
const CARD_BORDER := Color("a88a5c")
const CARD_SHADOW := Color(0.36, 0.25, 0.1, 0.22)
## 暗くした行（仕込み数0・解放前・空き枠）。カードより少しくすんだ色（背景とは色味と枠で見分ける）
const ROW_DIM := Color("e9e4da")
const ROW_DIM_BORDER := Color("b9a585")
## 枠線（パネルなど）
const BORDER := PANEL_BORDER
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
## 完売の行・廃棄多めの行・不足の行の背景（白いカードの上でも目立つ濃さ）
const SOLD_OUT_BG := Color("fbe29a")
const WASTE_BG := Color("f8cdc4")
## 準備画面の不足の行は白いカードのまま、左端の色の帯と不足の文字だけを色にする
## （足りない＝赤、今は足りないが予定どおり仕入れれば足りる＝山吹）
const STATUS_SHORT := DANGER
const STATUS_PLAN_OK := WARNING

# --- 結果画面の料理ごとの内訳（ベージュから離れた、藍・青灰色の系統） ---
const TABLE_HEADER := Color("2c4a7a")
const TABLE_HEADER_TEXT := Color("ffffff")
const TABLE_ROW_A := Color("eaf0f8")
const TABLE_ROW_B := Color("ffffff")
const TABLE_BORDER := Color("b7c6dc")
## 青い表の上の完売（黄）・廃棄多め（赤）の行と文字
const TABLE_SOLD_OUT_BG := Color("ffe9a6")
const TABLE_SOLD_OUT := Color("8a5a00")
const TABLE_WASTE_BG := Color("fbd2ca")
const TABLE_WASTE := Color("b32a1d")
## 0（プラスでもマイナスでもない）
const ZERO := Color("8a7a66")
## ポップアップの後ろを暗くする色
const DIM := Color(0.2, 0.13, 0.05, 0.45)
## 料理の色の上に出す文字（置き場の枠など）
const ON_ITEM := Color("2a1c0e")

# --- 上部バー（準備・営業の両方で使う。自分の藍色の帯を持つので、どちらの背景でも読める） ---
const TOPBAR := Color("223a63")
const TOPBAR_TEXT := Color("ffffff")
const TOPBAR_SUB := Color("c9d4e8")
const TOPBAR_GAUGE_BG := Color(1, 1, 1, 0.18)
const TOPBAR_GAUGE := Color("f2c14e")
## 上部バー（暗い帯）の上の、マイナスの所持金・残り時間の注意
const TOPBAR_DANGER := Color("ff8f80")
const TOPBAR_WARNING := Color("ffd773")

# --- カレンダー ---
const CAL_TODAY_BORDER := VERMILION
const CAL_HOLIDAY := Color("9c8b74")

# --- グラフ（記録の画面） ---
const CHART_BAR := Color("e0a24a")
const CHART_BAR_SELECTED := Color("c4462c")
const CHART_LINE := Color("1d5fb4")
const CHART_GRID := Color("e3d6bd")
const CHART_AXIS := Color("b8a37f")
const CHART_SELECT := Color(0.23, 0.16, 0.1, 0.45)

# --- 営業画面（暗い背景。あとでドット絵に差し替える） ---
const BIZ_PANEL := Color(0.22, 0.24, 0.26)
const BIZ_PANEL_DARK := Color(0.15, 0.16, 0.17)
const BIZ_ORDER_PANEL := Color(0.12, 0.12, 0.14, 0.95)
const BIZ_SLOT_BORDER := Color(0.35, 0.35, 0.35)
const BIZ_TEXT_SUB := Color(0.75, 0.75, 0.75)
## 置き場で、持っていない枠を暗くする・スタッフが取りに来ている枠を薄くする
const BIZ_DIMMED := Color(0.6, 0.6, 0.6)
const BIZ_RESERVED := Color(1, 1, 1, 0.35)
const BIZ_HELD_BORDER := Color(1, 1, 1)
## 注文状況の行（待ち時間が短い・ふつう・長い）
const BIZ_ORDER_OK := Color(0.2, 0.32, 0.22)
const BIZ_ORDER_WAIT := Color(0.55, 0.45, 0.12)
const BIZ_ORDER_DANGER := Color(0.7, 0.18, 0.15)
## お客さんの待ち時間のゲージ（短い・ふつう・長い）
const BIZ_GAUGE_OK := Color(0.4, 0.85, 0.4)
const BIZ_GAUGE_WAIT := Color(0.95, 0.8, 0.3)
const BIZ_GAUGE_DANGER := Color(0.95, 0.3, 0.25)
## お客さんの上に出る文字（ちがう・満足度・あと○○・会計・怒って帰る）
const BIZ_POPUP_WRONG := Color(1.0, 0.5, 0.4)
const BIZ_POPUP_GOOD := Color(0.6, 1.0, 0.6)
const BIZ_POPUP_PARTIAL := Color(0.85, 0.95, 1.0)
const BIZ_POPUP_PAID := Color(1.0, 0.9, 0.4)
const BIZ_POPUP_ANGRY := Color(1.0, 0.45, 0.4)
## 料理の絵があるときの吹き出しの背景
const BIZ_BUBBLE_WITH_ICON := Color(1, 1, 1, 0.9)
## 配膳できる席を光らせる色
const BIZ_SEAT_HIGHLIGHT := Color(1.0, 0.9, 0.3)
## 絵がないときの家具の代用の色（カウンター・テーブルの天板と脚、イス、テーブルの番号）
const BIZ_COUNTER_TOP := Color(0.62, 0.45, 0.28)
const BIZ_COUNTER_LEG := Color(0.45, 0.32, 0.2)
const BIZ_TABLE_TOP := Color(0.7, 0.5, 0.3)
const BIZ_TABLE_LEG := Color(0.5, 0.35, 0.22)
const BIZ_TABLE_LABEL := Color(0.3, 0.18, 0.1)
const BIZ_STOOL := Color(0.5, 0.36, 0.24)
const BIZ_CHAIR := Color(0.45, 0.3, 0.2)

# --- 一覧のスクロールの棒 ---
## 明るい画面
const SCROLL_BAR := Color(0.23, 0.16, 0.1, 0.4)
const SCROLL_BAR_BG := Color(0.23, 0.16, 0.1, 0.08)
## 営業画面（暗い背景）
const SCROLL_BAR_DARK := Color(1, 1, 1, 0.35)
const SCROLL_BAR_BG_DARK := Color(1, 1, 1, 0.06)


## 一覧の行のカード（白に近い色・濃い枠線・下に薄い影）。color と border で色付きの行（不足・空き枠など）にもする
static func card_box(color: Color = CARD, border: Color = CARD_BORDER, radius: int = 5) -> StyleBoxFlat:
	var box: StyleBoxFlat = UIUtil.flat_box(color, border, 1, radius)
	box.border_width_bottom = 2
	box.shadow_color = CARD_SHADOW
	box.shadow_size = 1
	box.shadow_offset = Vector2(0, 1)
	box.content_margin_left = 6
	box.content_margin_right = 6
	box.content_margin_top = 4
	box.content_margin_bottom = 4
	return box


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
