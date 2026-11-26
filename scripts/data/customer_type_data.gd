class_name CustomerTypeData
extends Resource
## 客層1種類のデータ。data/customers/ に .tres として置く。

@export var id: String = ""
@export var display_name: String = ""
## 注文してから料理を待てる時間（秒）。超えると怒って帰る
@export var patience: float = 30.0
## 好きな料理のid。注文時に選ばれやすくなる
@export var favorite_dishes: PackedStringArray = PackedStringArray()
## 予算（円）。これより高い料理は基本的に頼まない
@export var budget: int = 1000
## 食事にかかる時間（秒）
@export var eat_time: float = 5.0
## 来店しやすさの重み
@export var spawn_weight: float = 1.0
## 体の色（絵ができるまでの代用）
@export var color: Color = Color.GRAY
