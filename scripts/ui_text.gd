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
const PREP_MENU_TITLE := "今日のメニュー（－＋：営業前に作る数）"
const PREP_INGREDIENT_TITLE := "食材の仕入れ"
const PREP_ON := "出す"
const PREP_OFF := "出さない"
const PREP_TOTAL := "仕込み合計 %d / %d枠"
const PREP_DISH_INFO := "%s 原価%s"
const PREP_STOCK := "在庫 %d"
const PREP_STOCK_RESERVED := "在庫 %d（仕込 %d）"
const PREP_BUY := "+%d"
const PREP_START := "営業開始"
const PREP_NEED_MENU := "メニューを1つ以上「出す」にしてください"
const PREP_HINT := "準備ができたら営業開始！"
const PREP_SHORTAGE_WARNING := "赤い食材は今日の分が足りなさそうです"
const PREP_NEED := "目安 %d"
const PREP_NEED_SHORT := "目安 %d（%d 不足）"
const PREP_NEED_UNUSED := "今日のメニューでは使わない"
const PREP_REPEAT := "前回と同じ仕込み"
const PREP_REPEAT_DONE := "前回と同じ仕込みにしました"
const PREP_REPEAT_PARTIAL := "食材が足りず、前回の仕込みを一部しか入れられませんでした"
const PREP_PACE := "評判 %d：お客さんが来るペース ×%.2f（平均 %.1f秒ごと）"

# --- 営業 ---
const CHEF := "店主"
const COOK_IDLE := "待機中"
const COOKING := "調理中: %s"
const COOK_QUEUE := "次: %s"
const COOK_QUEUE_EMPTY := "次: なし"
const COOK_BUTTON := "%s（%d秒）"
const COOK_BUTTON_NO_STOCK := "%s（食材不足）"
const COOK_BUTTON_FULL := "%s（置き場が満杯）"
const SHELF_TITLE := "完成品置き場"
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
const EATING := "食事中"
## 満足度ごとの顔マーク（Satisfaction.Level の順）
const SATISFACTION_MARKS: Array[String] = ["◎", "○", "△", "怒"]
const SATISFACTION_NAMES: Array[String] = ["大満足", "満足", "やや不満", "怒って帰った"]

# --- 営業結果 ---
const RESULT_TITLE := "%d日目の営業結果"
const RESULT_SALES := "料理売上"
const RESULT_COST := "食材原価"
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
