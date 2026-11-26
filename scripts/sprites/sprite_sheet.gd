class_name SpriteSheet
extends RefCounted
## 読み込んだ絵1枚分。コマごとのテクスチャと、再生速度・基準点を持つ。
## SpriteLibrary.get_sheet() で作る。

var key: String = ""
var texture: Texture2D
var frames: Array[Texture2D] = []
var frame_size: Vector2i = Vector2i.ZERO
var fps: float = 6.0
var loop: bool = true
## 基準点（コマの左上からのpx）
var pivot_px: Vector2 = Vector2.ZERO
var nine_patch_margin: int = 0
var tile: bool = false


func _init(sheet_key: String, tex: Texture2D, data: SpriteSheetData) -> void:
	key = sheet_key
	texture = tex
	fps = data.fps
	loop = data.loop
	nine_patch_margin = data.nine_patch_margin
	tile = data.tile
	var tex_size: Vector2i = Vector2i(tex.get_size())
	var count: int = maxi(1, data.frame_count)
	frame_size = data.frame_size
	if frame_size.x <= 0 or frame_size.y <= 0:
		frame_size = Vector2i(maxi(1, tex_size.x / count), tex_size.y)
	# 絵の幅に入りきらないコマは使わない（1コマの絵に4コマの設定でも動くように）
	count = clampi(count, 1, maxi(1, tex_size.x / frame_size.x))
	if count == 1 and frame_size == tex_size:
		frames.append(tex)
	else:
		for i: int in count:
			var atlas: AtlasTexture = AtlasTexture.new()
			atlas.atlas = tex
			atlas.region = Rect2(i * frame_size.x, 0, frame_size.x, frame_size.y)
			frames.append(atlas)
	pivot_px = (Vector2(frame_size) * data.pivot).round()


func get_frame_count() -> int:
	return frames.size()


func is_animated() -> bool:
	return frames.size() > 1 and fps > 0.0


## 再生を始めてからの秒数で、表示するコマを返す
func get_frame_at(time: float) -> Texture2D:
	if not is_animated():
		return frames[0]
	var index: int = int(floorf(time * fps))
	if loop:
		index = posmod(index, frames.size())
	else:
		index = mini(index, frames.size() - 1)
	return frames[index]
