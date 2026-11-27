class_name ToppingData
extends DishData
## トッピング（追加の1皿）1種類のデータ。data/toppings/ に .tres として置く。
## 料理と同じ項目（名前・短い名前・価格・食材・調理時間・表示色・解放の条件）を持ち、
## 仕込み・仕入れ・置き場・調理・配膳は料理と同じ仕組みで扱う。
## お客さんは料理を1つ選んだあと、客層ごとの確率でトッピングを1つ追加で頼む（CustomerTypeData.topping_rate）。


func is_topping() -> bool:
	return true
