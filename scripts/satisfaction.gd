class_name Satisfaction
extends RefCounted
## 満足度の段階と、それに応じた評判・★の計算。

enum Level { GREAT, GOOD, BAD, ANGRY }


static func from_wait(elapsed: float, patience: float, config: GameConfig) -> Level:
	var ratio: float = elapsed / maxf(patience, 0.01)
	if ratio <= config.great_ratio:
		return Level.GREAT
	if ratio <= config.good_ratio:
		return Level.GOOD
	return Level.BAD


## 客1人の評判の点数（その日の分を足して、営業結果のときに評判へ反映する）
static func reputation_points(level: Level, config: GameConfig) -> float:
	match level:
		Level.GREAT:
			return config.reputation_great
		Level.GOOD:
			return config.reputation_good
		Level.BAD:
			return config.reputation_bad
		_:
			return config.reputation_angry


static func stars(level: Level, config: GameConfig) -> float:
	match level:
		Level.GREAT:
			return config.stars_great
		Level.GOOD:
			return config.stars_good
		Level.BAD:
			return config.stars_bad
		_:
			return config.stars_angry
