class_name RankData
extends Resource
## 店舗ランク1段分のデータ。data/ranks/ に .tres として置く（ファイルを足すだけでランクを増やせる）。

## ランクの番号（1始まり。小さい順に並べて使う）
@export var rank: int = 1
@export var display_name: String = ""
## このランクになるのに必要な評判
@export var reputation_threshold: int = 0
## このランクのとき、その日の評判の点数がプラスなら、この倍率をかけて評判に反映する（高いランクほど小さく）
@export var reputation_gain_scale: float = 0.5
## このランクで雇えるホールスタッフの人数
@export var staff_limit: int = 0
## 常連さんの分の評判（1営業日あたり。小数でよい）。その日の評判の増え方がこれより少ない日（下手な日・マイナスの日）は、
## 増減をこの値に置き換える（常連さんが来てくれるので、悪い日でも少しずつ育つ）。小数の分は持ち越して足していく
@export var regular_reputation: float = 0.0
