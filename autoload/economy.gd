extends Node
## Shared coin currency across all games.

signal coins_changed(total: int, delta: int)

const MAX_COINS: int = 999_999_999


var coins: int:
	get:
		return int(SaveSystem.data.get("coins", 0))


func add(amount: int, _reason: String = "") -> void:
	if amount == 0:
		return
	var total: int = clampi(coins + amount, 0, MAX_COINS)
	SaveSystem.data["coins"] = total
	SaveSystem.mark_dirty()
	coins_changed.emit(total, amount)


func can_afford(amount: int) -> bool:
	return coins >= amount


func spend(amount: int) -> bool:
	if amount < 0 or not can_afford(amount):
		return false
	add(-amount, "spend")
	SaveSystem.save_game()
	return true


## cost = base * growth^level, rounded to a "nice" number.
static func upgrade_cost(base: int, level: int, growth: float = 1.15) -> int:
	var raw: float = float(base) * pow(growth, float(level))
	if raw < 100.0:
		return int(roundf(raw))
	if raw < 1000.0:
		return int(roundf(raw / 5.0) * 5.0)
	return int(roundf(raw / 50.0) * 50.0)


static func format(n: int) -> String:
	if n >= 1_000_000:
		return "%.1fM" % (float(n) / 1_000_000.0)
	if n >= 10_000:
		return "%.1fK" % (float(n) / 1000.0)
	return str(n)
