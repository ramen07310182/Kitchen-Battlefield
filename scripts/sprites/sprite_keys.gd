class_name SpriteKeys
extends RefCounted
## 絵の名前（assets/sprites/ からのパス。拡張子なし）の一覧。
## 絵の置き場所はここで決まる。一覧と推奨サイズは docs/assets.md。

# 店
const FLOOR := "shop/floor"
const WALL := "shop/wall"
const ENTRANCE := "shop/entrance"

# 家具
const CHAIR := "furniture/chair"
## カウンター（横に並べて敷き詰める）・カウンターのイス・4人がけのテーブル
const COUNTER := "furniture/counter"
const STOOL := "furniture/stool"
const TABLE4 := "furniture/table4"

# 厨房
const CHEF := "kitchen/chef"
const STOVE := "kitchen/stove"
const KITCHEN_BACK := "kitchen/background"

# UI
const BUTTON_NORMAL := "ui/button_normal"
const BUTTON_PRESSED := "ui/button_pressed"
const BUTTON_DISABLED := "ui/button_disabled"
const PANEL := "ui/panel"

# アニメーション名（"<名前>_<アニメーション>" の絵を探し、なければ "<名前>" の絵を使う）
const ANIM_IDLE := "idle"
const ANIM_WALK := "walk"
const ANIM_SIT := "sit"
const ANIM_EAT := "eat"
const ANIM_COOK := "cook"

const CUSTOMER_ANIMS: PackedStringArray = ["walk", "sit", "eat"]
const STAFF_ANIMS: PackedStringArray = ["idle", "walk"]
const CHEF_ANIMS: PackedStringArray = ["idle", "cook"]
const STOVE_ANIMS: PackedStringArray = ["idle", "cook"]


static func customer(type_id: String) -> String:
	return "customers/" + type_id


## 料理とトッピングの絵（トッピングも dishes/ に置く）
static func dish(dish_id: String) -> String:
	return "dishes/" + dish_id


## ホールスタッフの絵
static func staff(staff_id: String) -> String:
	return "staff/" + staff_id


## アニメーション付きの名前（"customers/student" + "walk" → "customers/student_walk"）
static func with_anim(key: String, anim: String) -> String:
	return key if anim == "" else "%s_%s" % [key, anim]


## 確認用: ゲームで使うすべての絵の名前と、それぞれのアニメーション
## [{ key: String, anims: PackedStringArray }]
static func all_entries() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for t: CustomerTypeData in Database.customer_types:
		list.append({ "key": customer(t.id), "anims": CUSTOMER_ANIMS })
	for d: DishData in Database.items:
		list.append({ "key": dish(d.id), "anims": PackedStringArray() })
	for s: StaffData in Database.staff:
		list.append({ "key": staff(s.id), "anims": STAFF_ANIMS })
	list.append({ "key": COUNTER, "anims": PackedStringArray() })
	list.append({ "key": STOOL, "anims": PackedStringArray() })
	list.append({ "key": TABLE4, "anims": PackedStringArray() })
	list.append({ "key": CHAIR, "anims": PackedStringArray() })
	list.append({ "key": FLOOR, "anims": PackedStringArray() })
	list.append({ "key": WALL, "anims": PackedStringArray() })
	list.append({ "key": ENTRANCE, "anims": PackedStringArray() })
	list.append({ "key": CHEF, "anims": CHEF_ANIMS })
	list.append({ "key": STOVE, "anims": STOVE_ANIMS })
	list.append({ "key": KITCHEN_BACK, "anims": PackedStringArray() })
	list.append({ "key": BUTTON_NORMAL, "anims": PackedStringArray() })
	list.append({ "key": BUTTON_PRESSED, "anims": PackedStringArray() })
	list.append({ "key": BUTTON_DISABLED, "anims": PackedStringArray() })
	list.append({ "key": PANEL, "anims": PackedStringArray() })
	return list
