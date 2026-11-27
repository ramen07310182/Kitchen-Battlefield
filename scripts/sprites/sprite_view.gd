class_name SpriteView
extends Control
## 絵を表示する場所。絵（PNG）があれば絵を描き、なければ子ノード（図形の代用品）を表示する。
## 代用品の図形は、このノードの子として置く。
##
## 置き方（mode）:
##   ANCHOR: 絵の基準点（足元など）を、このノードの anchor_ratio の位置に合わせて、等倍で描く
##   TILE:   このノードの大きさいっぱいに、絵を並べて敷き詰める（床・壁）

enum Mode { ANCHOR, TILE }

## 絵の名前（assets/sprites/ からのパス。拡張子なし）。例: "furniture/table4"
@export var sprite_key: String = "":
	set(value):
		if sprite_key == value:
			return
		sprite_key = value
		_reload()
## 再生するアニメーション。"<名前>_<アニメーション>" の絵を探し、なければ "<名前>" の絵を使う
@export var animation: String = "":
	set(value):
		if animation == value:
			return
		animation = value
		_reload()
@export var mode: Mode = Mode.ANCHOR
## 絵の基準点を合わせる位置（このノードの大きさに対する割合）。(0.5, 1.0) = 下の中央
@export var anchor_ratio: Vector2 = Vector2(0.5, 1.0)
## 絵がないときは場所ごと隠す（コンロなど、代用品の図形がなく、絵がなければ何も出さないもの）
@export var collapse_when_missing: bool = false
## 左右反転（右向きの絵を左向きにする）
@export var flip_h: bool = false:
	set(value):
		flip_h = value
		queue_redraw()

var _sheet: SpriteSheet = null
var _time: float = 0.0
var _frame: Texture2D = null


func _ready() -> void:
	# 絵はドット絵なので、拡大してもぼやけないようにする（文字はテーマのフォントでなめらか）
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reload()


## 名前とアニメーションをまとめて変える
func set_sprite(key: String, anim: String = "") -> void:
	sprite_key = key
	animation = anim


## 絵が見つかって表示しているか
func has_sprite() -> bool:
	return _sheet != null


func get_sheet() -> SpriteSheet:
	return _sheet


func _process(delta: float) -> void:
	if _sheet == null or not _sheet.is_animated():
		return
	_time += delta
	var frame: Texture2D = _sheet.get_frame_at(_time)
	if frame != _frame:
		_frame = frame
		queue_redraw()


func _reload() -> void:
	if not is_inside_tree():
		return
	var candidates: PackedStringArray = PackedStringArray()
	if animation != "":
		candidates.append(SpriteKeys.with_anim(sprite_key, animation))
	candidates.append(sprite_key)
	var sheet: SpriteSheet = SpriteLibrary.find_sheet(candidates)
	if sheet != _sheet:
		_sheet = sheet
		_time = 0.0
	_frame = _sheet.get_frame_at(_time) if _sheet != null else null
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED if mode == Mode.TILE else CanvasItem.TEXTURE_REPEAT_PARENT_NODE
	set_process(_sheet != null and _sheet.is_animated())
	# 絵があるときは代用品の図形を隠す
	for child: Node in get_children():
		if child is CanvasItem:
			(child as CanvasItem).visible = _sheet == null
	if collapse_when_missing:
		visible = _sheet != null
	queue_redraw()


func _draw() -> void:
	if _sheet == null or _frame == null:
		return
	match mode:
		Mode.TILE:
			# 並べるときはコマに分けず、1枚目の絵をそのまま使う
			draw_texture_rect(_sheet.frames[0] if _sheet.frames[0] is not AtlasTexture else _sheet.texture, Rect2(Vector2.ZERO, size), true)
		Mode.ANCHOR:
			var origin: Vector2 = (size * anchor_ratio).round()
			draw_set_transform(origin, 0.0, Vector2(-1.0 if flip_h else 1.0, 1.0))
			draw_texture_rect(_frame, Rect2(-_sheet.pivot_px, Vector2(_sheet.frame_size)), false)
			draw_set_transform(Vector2.ZERO)
