class_name StaffData
extends Resource
## 雇える従業員（ホールスタッフ）1人分のデータ。data/staff/ に .tres として置く。
## ホールスタッフは、置き場にある料理・トッピングのうち、まだ出していない注文と合うものを自分で取って運び、配膳する。
## 速い人ほど日給が高い。日給は営業した日ごとにかかる（定休日はかからない）。

@export var id: String = ""
@export var display_name: String = ""
## 歩く速さ（px/秒、640×360基準）
@export var walk_speed: float = 70.0
## 置き場から料理を取るまでの時間（秒）
@export var pick_time: float = 1.0
## 日給（円）
@export var daily_wage: int = 3000
## 体の色（絵ができるまでの代用）
@export var color: Color = Color(0.9, 0.5, 0.3)
## 一覧に並べる順番（小さいほど上）
@export var sort_order: int = 0
