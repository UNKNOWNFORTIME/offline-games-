class_name CrowdLevels
extends RefCounted
## Level source for Crowd Rush: hand-made levels from JSON, then a seeded
## procedural generator with a difficulty curve. Every generated level is
## verified winnable by simulating the best gate path.

const DATA_PATH: String = "res://data/crowd_rush_levels.json"
const BOSS_HITS_PER_SEC_MIN: float = 14.0
const FIGHT_TIME: float = 2.2

static var _hand: Array = []


static func _load() -> void:
	if _hand.size() > 0:
		return
	var f: FileAccess = FileAccess.open(DATA_PATH, FileAccess.READ)
	if f == null:
		push_warning("CrowdLevels: missing " + DATA_PATH)
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary and (parsed as Dictionary).has("levels"):
		_hand = (parsed as Dictionary)["levels"]


static func hand_count() -> int:
	_load()
	return _hand.size()


## Returns {length, gates:[{d,left,right}], enemy, boss_hp}.
static func get_level(n: int) -> Dictionary:
	_load()
	if n >= 1 and n <= _hand.size():
		return _normalize(_hand[n - 1])
	return generate(n)


static func _normalize(raw: Dictionary) -> Dictionary:
	var gates: Array = []
	for g: Variant in raw.get("gates", []):
		var gd: Dictionary = g
		gates.append({"d": float(gd["d"]), "left": str(gd["left"]), "right": str(gd["right"])})
	return {
		"length": float(raw.get("length", 140)),
		"gates": gates,
		"enemy": int(raw.get("enemy", 10)),
		"boss_hp": int(raw.get("boss_hp", 20)),
	}


## Units the boss's stomps kill during a fight (mirrors CrowdRush rules).
static func stomp_kills(level: int) -> int:
	return mini(2 + level / 4, 10)


static func best_path(level: Dictionary, start: int) -> int:
	var c: int = start
	for g: Variant in level["gates"]:
		var gd: Dictionary = g
		c = maxi(GatePair.apply(str(gd["left"]), c), GatePair.apply(str(gd["right"]), c))
	return c


## Survivors on the best path after the clash and the boss (<=0 = unwinnable).
static func best_margin(level: Dictionary, start: int, level_num: int) -> int:
	var c: int = best_path(level, start)
	var boss_hp: int = int(level["boss_hp"])
	var stomps: int = 2
	return c - int(level["enemy"]) - boss_hp - stomps * stomp_kills(level_num)


static func generate(n: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("crowd_rush_%d" % n)
	# Difficulty 0..1 ramps over levels 4..45 then holds.
	var diff: float = clampf(float(n - 4) / 41.0, 0.0, 1.0)
	var length: float = roundf(lerpf(150.0, 230.0, diff) + rng.randf_range(-10.0, 10.0))
	var gate_count: int = clampi(int((length - 40.0) / 26.0), 4, 8)
	var gates: Array = []
	var c: int = 1
	var spacing: float = (length - 40.0) / float(gate_count)
	for i: int in gate_count:
		var good: String = _good_op(rng, c, diff)
		var other: String
		if rng.randf() < lerpf(0.35, 0.7, diff):
			other = _bad_op(rng, c, diff)
		else:
			other = _good_op(rng, c, diff)
			if other == good:
				other = "+%d" % (GatePair.op_value(good) + rng.randi_range(1, 4))
		var left: String = good
		var right: String = other
		if rng.randf() < 0.5:
			left = other
			right = good
		gates.append({"d": 24.0 + spacing * float(i), "left": left, "right": right})
		c = maxi(GatePair.apply(left, c), GatePair.apply(right, c))
	var best: int = c
	# Share of the best result spent on enemy + boss grows with difficulty.
	var pressure: float = lerpf(0.5, 0.82, diff) + rng.randf_range(-0.04, 0.04)
	var stomp_cost: int = 2 * stomp_kills(n)
	var budget: int = maxi(4, int(float(best) * pressure) - stomp_cost)
	var enemy_share: float = rng.randf_range(0.45, 0.62)
	var enemy: int = maxi(3, int(float(budget) * enemy_share))
	var boss_hp: int = maxi(8, budget - enemy)
	var level: Dictionary = {"length": length, "gates": gates, "enemy": enemy, "boss_hp": boss_hp}
	# Guarantee: best path must leave survivors.
	var min_margin: int = maxi(3, int(float(best) * 0.06))
	while best_margin(level, 1, n) < min_margin:
		if level["boss_hp"] > 8:
			level["boss_hp"] = int(level["boss_hp"]) - maxi(1, int(level["boss_hp"]) / 10)
		elif level["enemy"] > 3:
			level["enemy"] = int(level["enemy"]) - 1
		else:
			break
	# Still not winnable (tiny crowd): add a late x2 rescue gate.
	var guard: int = 0
	while best_margin(level, 1, n) < min_margin and guard < 3:
		var rescue: Dictionary = {"d": length - 10.0 - float(guard) * 0.5, "left": "x2", "right": "+%d" % (4 + n / 4)}
		if rng.randf() < 0.5:
			rescue = {"d": rescue["d"], "left": rescue["right"], "right": "x2"}
		(level["gates"] as Array).append(rescue)
		guard += 1
	return level


static func _good_op(rng: RandomNumberGenerator, c: int, diff: float) -> String:
	# Multipliers early when the crowd is small; additions keep pace later.
	var roll: float = rng.randf()
	if c < 40 and roll < 0.45:
		return "x%d" % rng.randi_range(2, 3)
	if c < 150 and roll < 0.6:
		return "x2"
	if c >= 400 and roll < 0.85:
		return "+%d" % int(float(c) * rng.randf_range(0.15, 0.35))
	var lo: int = 4 + int(diff * 10.0)
	var hi: int = maxi(lo + 2, int(float(c) * 0.5) + 6)
	return "+%d" % rng.randi_range(lo, mini(hi, 300))


static func _bad_op(rng: RandomNumberGenerator, c: int, diff: float) -> String:
	var roll: float = rng.randf()
	if c >= 8 and roll < 0.35:
		return "/%d" % rng.randi_range(2, 3 if diff > 0.5 else 2)
	var v: int = maxi(1, int(float(c) * rng.randf_range(0.3, 0.6 + diff * 0.3)))
	return "-%d" % v
