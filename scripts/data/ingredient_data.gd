class_name IngredientData
extends Resource
## 食材1種類のデータ。data/ingredients/ に .tres として置く。

@export var id: String = ""
@export var display_name: String = ""
## 1個あたりの仕入れ値（円）
@export var price: int = 0
@export var color: Color = Color.WHITE
## 一覧に並べる順番（小さいほど上）
@export var sort_order: int = 0
