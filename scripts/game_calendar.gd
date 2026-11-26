class_name GameCalendar
extends RefCounted
## ゲームの日付。営業日（○日目）とカレンダーの日付を相互に変換する。
## 1日目 = 2027年1月1日（金）。毎週水曜日は定休日で、営業日に数えない。
## 日付の計算（年またぎ・うるう年）は Godot の Time の関数に任せる（UTC で計算する）。

const START_YEAR := 2027
const START_MONTH := 1
const START_DAY := 1
## 定休日の曜日（0 = 日曜 … 3 = 水曜 … 6 = 土曜）
const HOLIDAY_WEEKDAY := 3
const SECONDS_PER_DAY := 86400

static var _start_unix: int = -1
static var _start_weekday: int = -1


static func _ensure_start() -> void:
	if _start_unix >= 0:
		return
	_start_unix = Time.get_unix_time_from_datetime_dict({
		"year": START_YEAR, "month": START_MONTH, "day": START_DAY, "hour": 0, "minute": 0, "second": 0,
	})
	_start_weekday = int(Time.get_datetime_dict_from_unix_time(_start_unix)["weekday"])


## 1週間のうち、定休日がゲーム開始日から何日目の位置にあるか（0〜6）
static func _holiday_position() -> int:
	_ensure_start()
	return posmod(HOLIDAY_WEEKDAY - _start_weekday, 7)


## 営業日（1始まり）→ ゲーム開始日からの日数（0始まり）
static func offset_for_business_day(business_day: int) -> int:
	var n: int = maxi(1, business_day) - 1
	var weeks: int = n / 6
	var r: int = n % 6
	var pos: int = r if r < _holiday_position() else r + 1
	return weeks * 7 + pos


## ゲーム開始日からの日数 → 営業日（1始まり）。定休日なら 0、開始日より前なら -1
static func business_day_for_offset(offset: int) -> int:
	if offset < 0:
		return -1
	var pos: int = offset % 7
	var holiday: int = _holiday_position()
	if pos == holiday:
		return 0
	var r: int = pos if pos < holiday else pos - 1
	return (offset / 7) * 6 + r + 1


## ゲーム開始日からの日数 → 日付 { year, month, day, weekday }
static func date_for_offset(offset: int) -> Dictionary:
	_ensure_start()
	return Time.get_datetime_dict_from_unix_time(_start_unix + offset * SECONDS_PER_DAY)


## 営業日 → 日付 { year, month, day, weekday }
static func date_for_business_day(business_day: int) -> Dictionary:
	return date_for_offset(offset_for_business_day(business_day))


## 日付 → ゲーム開始日からの日数（開始日より前は負）
static func offset_for_date(year: int, month: int, day: int) -> int:
	_ensure_start()
	var unix: int = Time.get_unix_time_from_datetime_dict({
		"year": year, "month": month, "day": day, "hour": 0, "minute": 0, "second": 0,
	})
	return int(floor(float(unix - _start_unix) / SECONDS_PER_DAY))


## その営業日の次の日が定休日か（火曜日の営業のあと）
static func is_holiday_next(business_day: int) -> bool:
	return offset_for_business_day(business_day + 1) - offset_for_business_day(business_day) > 1


## その月の日数（うるう年も Time で計算する）
static func days_in_month(year: int, month: int) -> int:
	var next_year: int = year + (1 if month == 12 else 0)
	var next_month: int = 1 if month == 12 else month + 1
	return offset_for_date(next_year, next_month, 1) - offset_for_date(year, month, 1)


## 「2027/1/1（金）」
static func format_date(date: Dictionary) -> String:
	return UIText.DATE_FORMAT % [int(date["year"]), int(date["month"]), int(date["day"]), UIText.WEEKDAYS[int(date["weekday"])]]


## 「1月7日（木）」
static func format_month_day(date: Dictionary) -> String:
	return UIText.MONTH_DAY_FORMAT % [int(date["month"]), int(date["day"]), UIText.WEEKDAYS[int(date["weekday"])]]
