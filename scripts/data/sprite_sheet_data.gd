class_name SpriteSheetData
extends Resource
## 絵1枚（PNG）の読み方の設定。data/sprites/ に、絵と同じ名前の .tres として置く。
## 例: 絵 assets/sprites/customers/student_walk.png → 設定 data/sprites/customers/student_walk.tres
## 設定がなければ「1コマの絵・足元（下の中央）が基準点」として読む。
## 詳しくは docs/assets.md。

## 絵のファイル。空なら assets/sprites/<設定と同じ名前>.png を使う
@export_file("*.png") var texture_path: String = ""
## コマ数（スプライトシートは横一列に並べる）。
## 絵の幅に入りきらない分は無視するので、1コマだけの絵を置いても動く
@export_range(1, 64) var frame_count: int = 1
## 1コマの大きさ（px）。(0, 0) なら「絵の幅 ÷ コマ数 × 絵の高さ」
@export var frame_size: Vector2i = Vector2i.ZERO
## 1秒あたりのコマ数
@export_range(0.0, 60.0, 0.5) var fps: float = 6.0
## 最後のコマのあと最初に戻るか（false なら最後のコマで止まる）
@export var loop: bool = true
## 基準点: コマの中のどこを置き場所に合わせるか（0〜1の割合）。
## (0.5, 1.0) = 下の中央（足元）、(0.5, 0.5) = 真ん中
@export var pivot: Vector2 = Vector2(0.5, 1.0)

@export_group("UIの枠・背景")
## 枠として使うとき、伸び縮みさせない端の幅（px）。ナインパッチ（9分割）の余白
@export_range(0, 64) var nine_patch_margin: int = 0
## 枠・背景として使うとき、真ん中を引き伸ばさずに並べる（タイル）
@export var tile: bool = false
