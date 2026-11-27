class_name UIText
extends RefCounted
## 画面に表示する文字列をまとめる場所。
## 料理名などデータに属する名前は data/ の各 .tres にある。

# --- 共通 ---
const DAY := "%d日目"
const DATE_FORMAT := "%d/%d/%d（%s）"
const MONTH_DAY_FORMAT := "%d月%d日（%s）"
const WEEKDAYS: Array[String] = ["日", "月", "火", "水", "木", "金", "土"]
const REPUTATION := "評判 %d"
const REPUTATION_WITH_RANK := "%s ★評判 %d"
const TIME_LEFT := "残り %d:%02d"
const TIME_CLOSED := "閉店（店内のお客さんに対応中）"
const SECONDS := "%d秒"

# --- 営業準備 ---
# 手順（①仕込み → ②仕入れ → ③置き場）
const PREP_STEP_NAMES: Array[String] = ["①仕込み", "②仕入れ", "③置き場"]
const PREP_STEP_SEPARATOR := "＞"
const PREP_BACK := "戻る"
const PREP_NEXT := "次へ"
const PREP_MENU_HINT := "仕込み数を決めたら「次へ」"
const PREP_MENU_SHORT := "食材が足りない料理があります（②仕入れで補えます）"
const PREP_PURCHASE_HINT := "仕入れ予定を決めて「仕入れる」で確定"
const PREP_PURCHASE_SHORT := "仕込みに足りない食材があります"
const PREP_PURCHASE_CONFIRM_NEEDED := "「仕入れる」で確定すると、仕込みに足ります"
const PREP_USAGE_TITLE := "仕込みに使う食材\n（必要／在庫）"
const PREP_USAGE_ROW := "%s %d／%d"
const PREP_USAGE_NONE := "仕込み数を決めると、使う食材が出ます"
const PREP_LOCKED := "%s　%sで解放"
const PREP_LOCKED_DAY := "%s　%d日目から解放"
const PREP_LOCKED_BOTH := "%s　%s・%d日目以降に解放"
const PREP_DISH_SHORT := "食材が足りません（%s）"
const PREP_DISH_SHORT_ITEM := "%s %d不足"
const PREP_PLAN_SHORTAGE := "不足分を予定に入れる"
const PREP_PLAN_SHORTAGE_DONE := "足りない分を仕入れ予定に入れました。「仕入れる」で確定してください"
const PREP_SHORTAGE_DIALOG := "食材が足りません（%s）。\nどうしますか？"
const PREP_REDUCE_TO_STOCK := "在庫に合わせて減らす"
const PREP_REDUCED := "仕込み数を在庫に合わせて減らしました"
const PREP_PLAN_LEFT := "仕入れ予定が残っています（%s）。\n仕入れずに次へ進みますか？"
const PREP_PLAN_LEFT_OK := "仕入れずに進む"
const PREP_SHELF_STEP_HELP := "営業開始のときに置き場に並べておく料理を、仕込み数の中から決めます。料理のボタンで並べ、並べた枠を押すと外します"
const PREP_SUMMARY := "今日の仕込み：%s"
const PREP_SUMMARY_ITEM := "%s %d"
const PREP_SUMMARY_NONE := "なし"
const PREP_MENU_TITLE := "今日のメニュー（仕込み数）"
const PREP_MENU_HELP := "行を長押しで詳細　－＋は長押しで続けて増減"
const PREP_INGREDIENT_TITLE := "食材の仕入れ"
const PREP_INGREDIENT_HELP := "予定を決めて「仕入れる」で確定　行を長押しで詳細"
const PREP_TOTAL := "合計 %d食"
const PREP_TOTAL_WITH_TOPPING := "合計 %d食＋%d皿"
const PREP_DISH_INFO := "原価%s・目安%d食｜%s"
const PREP_LAST_SOLD := "前回 %d食売れた"
const PREP_LAST_SOLD_ALL := "前回 %d食売れた（完売）"
const PREP_LAST_SOLD_MORE := "前回 %d食売れた（あと%d食売れた）"
const PREP_LAST_NOT_SERVED := "前回は出さなかった"
const PREP_SHELF_TITLE := "開店時の置き場（%d / %d枠）"
const PREP_SHELF_ADD := "%s＋"
const PREP_SHELF_CLEAR := "空にする"
const PREP_STOCK := "在庫 %d ＋予定 %d"
const PREP_STOCK_RESERVED := "在庫 %d（使う %d）＋予定 %d"
const PREP_PURCHASE_STEP := "%+d"
const PREP_PURCHASE_TOTAL := "仕入れ予定 %s"
const PREP_PURCHASE_NONE := "仕入れ予定なし"
const PREP_PURCHASE_SHORT_MONEY := "仕入れると所持金が %s になります"
const PREP_PURCHASE_BUTTON := "仕入れる"
const PREP_PURCHASE_CONFIRM := "食材を合計 %s で仕入れます。\nよろしいですか？"
const PREP_PURCHASE_CONFIRM_NEGATIVE := "食材を合計 %s で仕入れます。\n仕入れると所持金が %s になります。よろしいですか？"
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
const PREP_REPEAT_PARTIAL := "まだ解放していない料理は、前回と同じにできませんでした"
## 準備①のトッピングの区切り
const PREP_TOPPING_TITLE := "トッピング（注文のときに追加で頼まれる1皿）"
const PREP_PACE := "評判 %d：お客さんが来るペース ×%.2f（平均 %.1f秒ごと）"

# --- 営業準備：長押しの詳細 ---
const DETAIL_DISH_PRICE := "価格 %s　原価 %s　利益 %s"
const DETAIL_DISH_COOK := "調理時間 %d秒"
const DETAIL_DISH_COOK_EQUIPPED := "調理時間 %.1f秒（設備で %d%% 短い）"
const DETAIL_DISH_INGREDIENTS := "必要な食材: %s"
const DETAIL_DISH_EXPECTED := "注文の目安 %d食（すべての料理を出したとき）"
const DETAIL_DISH_PREP := "今日の仕込み数 %d（開店時の置き場 %d）"
const DETAIL_DISH_LAST := "前回: 仕込み %d・売れた %d・売り逃し %d"
const DETAIL_DISH_LAST_NOT_SERVED := "前回: 出さなかった"
const DETAIL_NO_RECORD := "前回: 記録なし"
const DETAIL_ING_PRICE := "仕入れ値 1個 %s"
const DETAIL_ING_STOCK := "在庫 %d（仕込みで使う %d・営業後に残る %d）"
const DETAIL_ING_PLAN := "仕入れ予定 %d個（%s）"
const DETAIL_ING_NEED := "今日の必要数の目安 %d"
const DETAIL_ING_USED_BY := "使う料理:"
const DETAIL_ING_USED_ROW := "・%s ×%d（今日の仕込み %d）"
const DETAIL_ING_UNUSED := "・この食材を使う料理はありません"

# --- 営業 ---
const CHEF := "店主"
const COOK_IDLE := "待機中"
const COOKING := "調理中: %s"
const COOK_QUEUE := "次: %s"
const COOK_QUEUE_EMPTY := "次: なし"
const COOK_BUTTON := "%s 残%d"
const COOK_FULL := "置き場が満杯"
const COOK_RETURN := "残りに戻す"
const SHELF_TITLE := "置き場"
const HOLDING := "持っている: %s"
const HOLDING_NONE := "タップで持つ"
const ORDER_TITLE := "注文状況"
const ORDER_EMPTY := "注文はまだありません"
const ORDER_ROW := "%s %s\n待ち %d秒"
## 注文状況の1行。トッピングは料理の後ろに「＋卵焼き」と出す
const ORDER_TOPPING := "＋%s"
const ORDER_WAIT := "待ち %d秒"
## 席の番号（カウンター C1〜C6、テーブル T1-1〜T3-4）
const SEAT_COUNTER := "C%d"
const SEAT_TABLE := "T%d-%d"
const TABLE_NAME := "T%d"
const POPUP_WRONG := "ちがう！"
## 注文の一部（料理かトッピング）を出した。残りを待っている
const POPUP_PARTIAL := "あと%s"
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
const RESULT_UNLOCK := "新メニュー解放：%s"
const RESULT_RANK_UP := "ランクアップ：%s"
const RESULT_REPUTATION_CHANGE := "評判 %s"
const RESULT_PURCHASE := "今日の仕入れ代"
const RESULT_MONEY_CHANGE := "今日の所持金の増減"
const RESULT_STOCK_CHANGE := "在庫の増減（原価）"
const RESULT_PROFIT_FORMULA := "利益 ＝ 所持金の増減 ＋ 在庫の増減"
const RESULT_SERVICE_LINE := "来客数 %d人　完了した注文 %d件　帰ってしまった客 %d人　ミス %d回　評判 %d"
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
const RESULT_LABOR := "人件費（従業員 %d人）"
## 内訳の表で、トッピングの名前の前に付ける印
const RESULT_TOPPING_NAME := "＋%s"
const RESULT_PROFIT := "利益"
const RESULT_RATING := "今日の評価"
const RESULT_MONEY := "所持金"
const RESULT_NO_RATING := "—"
const RESULT_NEXT := "次の日へ"
const RESULT_UPGRADE := "お店を強化"
const RESULT_HOLIDAY_NEXT := "明日は定休日です（次の営業は%s）"

# --- お店の強化（設備） ---
const UPGRADE_TITLE := "お店を強化"
const UPGRADE_HELP := "設備を買うと、次の営業から効果が出ます。行を長押しで詳細"
const UPGRADE_LEVEL := "Lv %d / %d"
const UPGRADE_BUY := "購入"
const UPGRADE_PRICE := "%s"
const UPGRADE_MAX := "最大レベル"
const UPGRADE_NEED_RANK := "%sで購入できます"
const UPGRADE_NEED_MONEY := "所持金が %s 足りません"
const UPGRADE_RANK_NOTE := "必要なランク：%s"
const UPGRADE_CONFIRM := "%s（Lv %d → %d）を %s で購入します。\nよろしいですか？"
const UPGRADE_OK := "購入する"
const UPGRADE_DONE := "%sを購入しました（Lv %d）"
const UPGRADE_HINT := "強化しない日は、そのまま「次の日へ」"
const UPGRADE_EFFECT_SEATS := "%d席"
const UPGRADE_EFFECT_SEATS_DETAIL := "%d席（カウンター%d・テーブル%d卓）"
const UPGRADE_EFFECT_SHELF := "置き場 %d枠"
const UPGRADE_EFFECT_COOK := "調理時間 %d%% 短い"
const UPGRADE_EFFECT_COOK_NONE := "調理時間 そのまま"
const UPGRADE_EFFECT_CHANGE := "%s → %s"
const UPGRADE_DETAIL_NOW := "今：Lv %d　%s"
const UPGRADE_DETAIL_NEXT := "次：Lv %d　%s（%s・%s）"
const UPGRADE_DETAIL_MAXED := "これ以上は強化できません"
const UPGRADE_DETAIL_TARGETS := "対象の料理：%s"
const UPGRADE_DETAIL_ALL := "すべての定食・丼（トッピングは対象外）"

# --- お店の強化（従業員） ---
const UPGRADE_SECTION_EQUIPMENT := "設備"
const UPGRADE_SECTION_STAFF := "従業員（ホールスタッフ）　雇っている %d / %d人"
const UPGRADE_STAFF_HELP := "置き場の料理を自分で取って、お客さんに運びます。雇うのは無料で、営業した日ごとに日給がかかります"
const UPGRADE_STAFF_SPEED := "歩く速さ %s・料理を取るまで %.1f秒"
const UPGRADE_STAFF_SPEED_NAMES: Array[String] = ["ゆっくり", "ふつう", "速い", "とても速い"]
const UPGRADE_STAFF_WAGE := "日給 %s"
const UPGRADE_STAFF_HIRED := "雇っています"
const UPGRADE_STAFF_HIRE := "雇う"
const UPGRADE_STAFF_DISMISS := "やめてもらう"
const UPGRADE_STAFF_NEED_RANK := "%sで雇えます"
const UPGRADE_STAFF_FULL := "雇える人数がいっぱい"
const UPGRADE_STAFF_HIRE_DONE := "%sを雇いました（次の営業から働きます）"
const UPGRADE_STAFF_DISMISS_CONFIRM := "%sにやめてもらいます。\nよろしいですか？"
const UPGRADE_STAFF_DISMISS_OK := "やめてもらう"
const UPGRADE_STAFF_DISMISS_DONE := "%sにやめてもらいました"

# --- カレンダー ---
const CAL_BUTTON := "カレンダー"
const CAL_TITLE := "%d年%d月"
const CAL_MONTH_TOTAL := "この月の利益 %s"
const CAL_HOLIDAY := "定休"
const CAL_CLOSE := "閉じる"
const CAL_HINT := "日付を押すと、その日の結果が出ます"
const CAL_DETAIL := "%s　%d日目　売上 %s　利益 %s　来客 %d人　評価 %s　評判 %s"
const CAL_DETAIL_NONE := "%s　%d日目　記録がありません"
const CAL_DETAIL_HOLIDAY := "%s　定休日"
const CAL_DETAIL_TODAY := "%s　%d日目　これから営業する日です"
const CAL_DETAIL_FUTURE := "%s　%d日目　まだ来ていない日です"
const CAL_DETAIL_BEFORE := "%s　開店前です"


## マイナスの金額（所持金など）を出すときの色
const COLOR_NEGATIVE_MONEY := Color(1.0, 0.45, 0.4)


## 所持金の表示の色（マイナスなら赤、それ以外は白）
static func money_color(value: int) -> Color:
	return COLOR_NEGATIVE_MONEY if value < 0 else Color.WHITE


## 金額を「¥10,000」の形にする（マイナスは「-¥12,300」）
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
