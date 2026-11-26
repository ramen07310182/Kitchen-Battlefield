class_name UIText
extends RefCounted
## 画面に表示する文字列をまとめる場所。
## 料理名などデータに属する名前は data/ の各 .tres にある。

# --- 共通 ---
const DAY := "%d日目"
const REPUTATION := "評判 %d"
const TIME_LEFT := "残り %d:%02d"
const TIME_CLOSED := "閉店（店内のお客さんに対応中）"
const SECONDS := "%d秒"

# --- 営業準備 ---
const PREP_MENU_TITLE := "今日のメニュー（仕込み数）"
const PREP_MENU_HELP := "－＋は長押しで速く増減"
const PREP_INGREDIENT_TITLE := "食材の仕入れ（予定を決めて「仕入れる」）"
const PREP_TOTAL := "仕込み数 合計 %d食"
const PREP_DISH_INFO := "原価%s・目安%d食｜%s"
const PREP_LAST_SOLD := "前回 %d食売れた"
const PREP_LAST_SOLD_ALL := "前回 %d食売れた（完売）"
const PREP_LAST_SOLD_MORE := "前回 %d食売れた（あと%d食売れた）"
const PREP_LAST_NOT_SERVED := "前回は出さなかった"
const PREP_SHELF_TITLE := "開店時の置き場（%d / %d枠）"
const PREP_SHELF_HELP := "押して並べる・外す"
const PREP_SHELF_ADD := "%s＋"
const PREP_SHELF_CLEAR := "空にする"
const PREP_STOCK := "在庫 %d ＋予定 %d"
const PREP_STOCK_RESERVED := "在庫 %d（使う %d）＋予定 %d"
const PREP_PURCHASE_STEP := "%+d"
const PREP_PURCHASE_TOTAL := "仕入れ予定 %s"
const PREP_PURCHASE_NONE := "仕入れ予定なし"
const PREP_PURCHASE_SHORT_MONEY := "所持金が %s 足りません"
const PREP_PURCHASE_BUTTON := "仕入れる"
const PREP_PURCHASE_CONFIRM := "食材を合計 %s で仕入れます。\nよろしいですか？"
const PREP_PURCHASE_OK := "仕入れる"
const PREP_PURCHASE_DONE := "食材を仕入れました（%s）"
const PREP_CANCEL := "やめる"
const PREP_START := "営業開始"
const PREP_START_WITH_PLAN := "仕入れ予定が残っています（%s）。\n仕入れずに営業を始めますか？"
const PREP_START_ANYWAY := "仕入れずに開始"
const PREP_NEED_PREP := "出す料理の仕込み数を1つ以上にしてください"
const PREP_HINT := "準備ができたら営業開始！"
const PREP_SHORTAGE_WARNING := "赤い食材は今日の目安に足りません"
const PREP_NEED := "目安 %d"
const PREP_NEED_SHORT_PLAN_OK := "目安 %d（%d不足→予定でOK）"
const PREP_NEED_SHORT := "目安 %d（予定込みでも%d不足）"
const PREP_NEED_UNUSED := "今日のメニューでは使わない"
const PREP_REPEAT := "前回と同じ仕込み"
const PREP_REPEAT_DONE := "仕込み数と置き場を前回と同じにしました"
const PREP_REPEAT_PARTIAL := "食材が足りず、前回の仕込みを一部しか入れられませんでした"
const PREP_PACE := "評判 %d：お客さんが来るペース ×%.2f（平均 %.1f秒ごと）"

# --- 営業 ---
const CHEF := "店主"
const COOK_IDLE := "待機中"
const COOKING := "調理中: %s"
const COOK_QUEUE := "次: %s"
const COOK_QUEUE_EMPTY := "次: なし"
const COOK_BUTTON := "%s %d秒　残り %d"
const COOK_BUTTON_NONE := "%s　残り 0"
const COOK_BUTTON_FULL := "%s 満杯　残り %d"
const COOK_RETURN := "残りに戻す"
const SHELF_TITLE := "置き場"
const HOLDING := "持っている: %s"
const HOLDING_NONE := "料理をタップして持つ"
const ORDER_TITLE := "注文状況"
const ORDER_EMPTY := "注文はまだありません"
const ORDER_ROW := "T%d %s\n待ち %d秒"
const POPUP_WRONG := "ちがう！"
const POPUP_NOT_HOLDING := "料理を持ってね"
const POPUP_PAID := "+%s"
const POPUP_ANGRY := "もういい！"
const BUSINESS_END := "本日の営業終了！"
const SOLD_OUT := "本日分は売り切れです"
const TIME_SOLD_OUT := "売り切れ（店内のお客さんに対応中）"
const EATING := "食事中"
## 満足度ごとの顔マーク（Satisfaction.Level の順）
const SATISFACTION_MARKS: Array[String] = ["◎", "○", "△", "怒"]
const SATISFACTION_NAMES: Array[String] = ["大満足", "満足", "やや不満", "怒って帰った"]

# --- 営業結果 ---
const RESULT_TITLE := "%d日目の営業結果"
const RESULT_SALES := "料理売上"
const RESULT_COST := "食材原価（廃棄分を含む）"
const RESULT_WASTE := "　うち廃棄 %d個"
const RESULT_SOLD_OUT := "売り切れで早めに閉店しました"
const RESULT_DISH_TITLE := "料理ごとの内訳"
const RESULT_DISH_LEGEND := "黄：売り切れて売り逃しあり　赤：廃棄が仕込みの%d%%以上"
const RESULT_DISH_NAME := "料理"
const RESULT_DISH_PREPARED := "仕込み"
const RESULT_DISH_SOLD := "売れた"
const RESULT_DISH_MISSED := "売り逃し"
const RESULT_DISH_WASTE := "廃棄"
const RESULT_DISH_SALES := "売上"
const RESULT_DISH_SOLD_OUT := "売り切れ"
const RESULT_DISH_MANY_WASTE := "廃棄多め"
const RESULT_DISH_NONE := "今日は仕込んだ料理がありません"
const RESULT_OTHER := "その他経費"
const RESULT_PROFIT := "利益"
const RESULT_VISITORS := "来客数"
const RESULT_COMPLETED := "完了した注文"
const RESULT_ANGRY := "帰ってしまった客"
const RESULT_MISTAKES := "ミス"
const RESULT_RATING := "今日の評価"
const RESULT_REPUTATION := "評判"
const RESULT_MONEY := "所持金"
const RESULT_PEOPLE := "%d人"
const RESULT_COUNT := "%d件"
const RESULT_TIMES := "%d回"
const RESULT_NO_RATING := "—"
const RESULT_NEXT := "次の日へ"


## 金額を「¥10,000」の形にする
static func money(value: int) -> String:
	var digits: String = str(absi(value))
	var out: String = ""
	while digits.length() > 3:
		out = "," + digits.substr(digits.length() - 3) + out
		digits = digits.substr(0, digits.length() - 3)
	return ("-" if value < 0 else "") + "¥" + digits + out


static func stars(count: int) -> String:
	return "★".repeat(count) + "☆".repeat(maxi(0, 5 - count))


static func signed(value: int) -> String:
	return ("+%d" % value) if value >= 0 else str(value)
