extends SceneTree
## res://icon.svg から iOS 用の 1024×1024 のアイコン（透明なし）を作る。
## 使い方: godot --headless --path . --script res://tests/tools/make_ios_icon.gd

const SRC: String = "res://icon.svg"
const OUT: String = "res://assets/icon/icon_1024.png"
const SIZE: int = 1024


func _init() -> void:
	var svg: String = FileAccess.get_file_as_string(SRC)
	var image: Image = Image.new()
	var err: Error = image.load_svg_from_string(svg, float(SIZE) / 128.0)
	if err != OK:
		push_error("icon.svg を読めません: %d" % err)
		quit(1)
		return
	image.resize(SIZE, SIZE, Image.INTERPOLATE_LANCZOS)
	# iOS のアイコンは透明を使えないので、RGB にする
	image.convert(Image.FORMAT_RGB8)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT.get_base_dir()))
	err = image.save_png(OUT)
	print("saved %s (%d)" % [OUT, err])
	quit(0 if err == OK else 1)
