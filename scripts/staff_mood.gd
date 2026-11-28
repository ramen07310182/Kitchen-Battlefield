class_name StaffMood
extends RefCounted
## 従業員（ホールスタッフ）の満足度の計算（数値とのしきい値は game_config の「従業員の満足度」）。
## 1人分の状態は Dictionary で持ち、GameState がセーブする:
##   mood: 満足度（0〜100）、streak: つづけて出勤した日数、bench: 出られるのに出勤しなかった日がつづいた日数、
##   reasons: { 理由: 最近の下がり方の合計（日ごとに少しずつ薄れる） }、last_shift: 前回の営業で出勤したか、
##   absent_day: 急な休みの営業日（なければ 0）

## 満足度が下がる理由
const REASON_STREAK := "streak"
const REASON_BUSY := "busy"
const REASON_BENCH := "bench"
const REASONS: Array[String] = [REASON_STREAK, REASON_BUSY, REASON_BENCH]
## 理由ごとの下がり方を、日ごとに薄れさせる割合
const REASON_DECAY := 0.85

## 機嫌の段階（ごきげん・ふつう・疲れ気味・限界）
enum Level { GOOD, NORMAL, TIRED, LIMIT }


static func new_state(config: GameConfig) -> Dictionary:
	return { "mood": config.staff_mood_start, "streak": 0, "bench": 0, "reasons": {}, "last_shift": true, "absent_day": 0 }


static func level(mood: float, config: GameConfig) -> Level:
	if mood >= config.staff_mood_good:
		return Level.GOOD
	if mood > config.staff_mood_warn:
		return Level.NORMAL
	if mood >= config.staff_mood_quit:
		return Level.TIRED
	return Level.LIMIT


## いちばん大きく満足度を下げている理由（なければ ""）
static func main_reason(state: Dictionary) -> String:
	var reasons: Dictionary = state.get("reasons", {})
	var best: String = ""
	var best_value: float = 0.0
	for r: String in REASONS:
		if float(reasons.get(r, 0.0)) > best_value:
			best_value = float(reasons.get(r, 0.0))
			best = r
	return best


## 1営業日分の満足度を更新する。worked: 出勤したか、available: 出られる日だったか、
## angry: その日に怒って帰った客の人数、deliveries: そのスタッフの配膳の皿数、rank_up: その日にランクが上がったか
static func update_day(state: Dictionary, worked: bool, available: bool, angry: int, deliveries: int,
		rank_up: bool, config: GameConfig) -> void:
	var mood: float = float(state.get("mood", config.staff_mood_start))
	var reasons: Dictionary = state.get("reasons", {})
	for r: String in REASONS:
		reasons[r] = float(reasons.get(r, 0.0)) * REASON_DECAY
	var streak: int = int(state.get("streak", 0))
	var bench: int = int(state.get("bench", 0))
	if worked:
		streak += 1
		bench = 0
		if streak >= config.staff_streak_days:
			mood -= config.staff_streak_penalty
			reasons[REASON_STREAK] = float(reasons[REASON_STREAK]) + config.staff_streak_penalty
		if angry >= config.staff_busy_angry or deliveries >= config.staff_busy_deliveries:
			mood -= config.staff_busy_penalty
			reasons[REASON_BUSY] = float(reasons[REASON_BUSY]) + config.staff_busy_penalty
		elif angry == 0 and deliveries <= config.staff_calm_deliveries:
			mood += config.staff_calm_bonus
	else:
		# 出勤のあとの休み（固定の休み・急な休みも含む）はほどよい休み
		if streak > 0:
			mood += config.staff_rest_bonus
		streak = 0
		if available:
			bench += 1
			if bench >= config.staff_bench_days:
				mood -= config.staff_bench_penalty
				reasons[REASON_BENCH] = float(reasons[REASON_BENCH]) + config.staff_bench_penalty
	if rank_up:
		mood += config.staff_rank_up_bonus
	state["mood"] = clampf(mood, 0.0, 100.0)
	state["streak"] = streak
	state["bench"] = bench
	state["reasons"] = reasons
	state["last_shift"] = worked if available else bool(state.get("last_shift", true))
