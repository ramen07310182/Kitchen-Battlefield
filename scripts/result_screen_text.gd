class_name ResultScreenText
extends RefCounted
## 結果画面・強化画面で共通に使う文。


## 火曜日の営業のあとなら「明日は定休日です（次の営業は1月7日（木））」。そうでなければ空
static func holiday_note(business_day: int) -> String:
	if not GameCalendar.is_holiday_next(business_day):
		return ""
	var next_date: Dictionary = GameCalendar.date_for_business_day(business_day + 1)
	return UIText.RESULT_HOLIDAY_NEXT % GameCalendar.format_month_day(next_date)
