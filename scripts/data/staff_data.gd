class_name StaffData
extends Resource
## 雇える従業員（ホールスタッフ）1人分のデータ。data/staff/ に .tres として置く。
## ホールスタッフは、置き場にある料理・トッピングのうち、まだ出していない注文と合うものを自分で取って運び、配膳する。
## 速い人ほど日給が高い。日給は出勤した日ごとにかかる。在籍日数が終わると退職する（研修のレベルは辞めても残る）。

@export var id: String = ""
@export var display_name: String = ""
## 歩く速さ（px/秒、640×360基準）
@export var walk_speed: float = 70.0
## 置き場から料理を取るまでの時間（秒）
@export var pick_time: float = 1.0
## 日給（円）
@export var daily_wage: int = 3000
## 毎週の休み（固定の休み）の曜日（0 = 日曜 … 6 = 土曜。水曜はお店の定休日）
@export var days_off: PackedInt32Array = PackedInt32Array()
## 急な休みになる確率（営業日ごと）
@export var absence_rate: float = 0.05
## 在籍日数（雇った日から数えた営業日。この日数に達した日の営業結果で退職する。定休日は数えない・休みにした日は数える）
@export var tenure_days: int = 60
## 体の色（絵ができるまでの代用）
@export var color: Color = Color(0.9, 0.5, 0.3)
## 一覧に並べる順番（小さいほど上）
@export var sort_order: int = 0
