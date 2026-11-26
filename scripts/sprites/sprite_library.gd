class_name SpriteLibrary
extends RefCounted
## 絵の読み込み口。名前（例: "customers/student_walk"）から絵を探す。
##   絵:   assets/sprites/<名前>.png
##   設定: data/sprites/<名前>.tres（SpriteSheetData。なければ1コマ・足元基準）
## 絵がなければ null を返すので、呼ぶ側は今の図形（代用品）を表示する。
## ドット絵はぼかさずに表示する（Nearest）。プロジェクトの既定は文字とUIのために Linear なので、
## アイコンや枠として渡すテクスチャは、Nearest を指定した CanvasTexture に包んで返す。

const SPRITE_DIR := "res://assets/sprites/"
const DATA_DIR := "res://data/sprites/"

## 名前 -> SpriteSheet。絵がなかった名前は null を入れて、何度も探さないようにする
static var _cache: Dictionary = {}
## 名前 -> Nearest 指定の1コマ目（アイコン・枠用）
static var _pixel_cache: Dictionary = {}


## 絵を探す。なければ null
static func get_sheet(key: String) -> SpriteSheet:
	if key == "":
		return null
	if _cache.has(key):
		return _cache[key] as SpriteSheet
	var data: SpriteSheetData = _load_data(key)
	var path: String = data.texture_path if data.texture_path != "" else SPRITE_DIR + key + ".png"
	var tex: Texture2D = _load_texture(path)
	var sheet: SpriteSheet = SpriteSheet.new(key, tex, data) if tex != null else null
	_cache[key] = sheet
	return sheet


## 候補を順に探し、最初に見つかった絵を返す（例: "客_歩き" → "客"）
static func find_sheet(keys: PackedStringArray) -> SpriteSheet:
	for key: String in keys:
		var sheet: SpriteSheet = get_sheet(key)
		if sheet != null:
			return sheet
	return null


## 1コマ目のテクスチャ（ボタンのアイコンなど）。ぼかさずに表示される。なければ null
static func get_icon(key: String) -> Texture2D:
	var sheet: SpriteSheet = get_sheet(key)
	return _pixel_first_frame(sheet) if sheet != null else null


## UIの枠・背景用の StyleBox。絵がなければ null
static func get_style_box(key: String) -> StyleBoxTexture:
	var sheet: SpriteSheet = get_sheet(key)
	if sheet == null:
		return null
	var box: StyleBoxTexture = StyleBoxTexture.new()
	box.texture = _pixel_first_frame(sheet)
	box.set_texture_margin_all(sheet.nine_patch_margin)
	box.set_content_margin_all(maxf(3.0, float(sheet.nine_patch_margin)))
	if sheet.tile:
		box.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
		box.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	return box


## 絵の置き場所（確認用の画面や報告で使う）
static func get_texture_path(key: String) -> String:
	var data: SpriteSheetData = _load_data(key)
	return data.texture_path if data.texture_path != "" else SPRITE_DIR + key + ".png"


static func get_data_path(key: String) -> String:
	return DATA_DIR + key + ".tres"


## 読み込み済みの絵を忘れる（絵を置き直したあとに読み直したいとき）
static func clear_cache() -> void:
	_cache.clear()
	_pixel_cache.clear()


## 1コマ目を、Nearest を指定した CanvasTexture にして返す（置いたノードのフィルタ設定に関係なくぼかさない）
static func _pixel_first_frame(sheet: SpriteSheet) -> Texture2D:
	if _pixel_cache.has(sheet.key):
		return _pixel_cache[sheet.key] as Texture2D
	var base: Texture2D = sheet.frames[0]
	if base is AtlasTexture:
		# コマを切り出した画像にする（CanvasTexture は AtlasTexture の切り出しを使えないため）
		var region: Rect2i = Rect2i((base as AtlasTexture).region)
		var image: Image = sheet.texture.get_image()
		if image != null and not image.is_empty():
			base = ImageTexture.create_from_image(image.get_region(region))
	var pixel: CanvasTexture = CanvasTexture.new()
	pixel.diffuse_texture = base
	pixel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_pixel_cache[sheet.key] = pixel
	return pixel


static func _load_data(key: String) -> SpriteSheetData:
	var path: String = get_data_path(key)
	if ResourceLoader.exists(path):
		var data: SpriteSheetData = load(path) as SpriteSheetData
		if data != null:
			return data
		push_warning("絵の設定が読み込めません: " + path)
	return SpriteSheetData.new()


static func _load_texture(path: String) -> Texture2D:
	# ふつうはエディタがインポートした絵を使う
	if ResourceLoader.exists(path):
		var tex: Texture2D = load(path) as Texture2D
		if tex != null:
			return tex
	# エディタを開かずに起動した（まだインポートされていない）ときは、PNGを直接読む。
	# 書き出したアプリではこの読み方はできないので、絵を置いたら一度エディタを開くこと
	if FileAccess.file_exists(path):
		var image: Image = Image.load_from_file(path)
		if image != null and not image.is_empty():
			push_warning("インポートされていない絵を直接読みました（エディタを開くとインポートされます）: " + path)
			return ImageTexture.create_from_image(image)
	return null
