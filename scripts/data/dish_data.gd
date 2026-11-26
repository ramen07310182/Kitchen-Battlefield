class_name DishData
extends Resource
## 料理1種類のデータ。data/dishes/ に .tres として置く。

@export var id: String = ""
@export var display_name: String = ""
## 料理アイコンや完成品置き場に出す短い名前（2文字くらい）
@export var short_name: String = ""
## 販売価格（円）
@export var price: int = 0
## 必要な食材: { 食材id: 個数 }
@export var ingredients: Dictionary = {}
## 調理にかかる時間（秒）
@export var cook_time: float = 5.0
## 表示色（絵ができるまでの代用）
@export var color: Color = Color.WHITE
## 一覧に並べる順番（小さいほど上）
@export var sort_order: int = 0
## 解放に必要な評判。0 なら最初から使える。営業結果のあと、評判がこの値以上なら解放する
@export var unlock_reputation: int = 0
