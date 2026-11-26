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


static func reputation_delta(level: Level, config: GameConfig) -> int:
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
