class_name AppInfo
extends RefCounted
## Change the product name here (and in project.godot application/config/name
## + export_presets.cfg package/name).

const GAME_NAME: String = "Arcade Rush"
const VERSION: String = "0.2.0"

## Game registry used by the Hub. `scene` empty = not built yet (locked card).
const GAMES: Array = [
	{"id": "crowd_rush", "title": "Crowd Rush", "tagline": "Grow your crowd. Crush the boss.", "scene": "res://games/crowd_rush/crowd_rush.tscn", "color": Color("#2F80FF")},
	{"id": "stack_skater", "title": "Stack Skater", "tagline": "Stack coins. Mind the spikes.", "scene": "res://games/stack_skater/stack_skater.tscn", "color": Color("#FFC531")},
	{"id": "overtake", "title": "Overtake", "tagline": "Weave traffic. Upgrade. Go further.", "scene": "res://games/overtake/overtake.tscn", "color": Color("#FF3B3B")},
	{"id": "last_barricade", "title": "Last Barricade", "tagline": "Hold the line until dawn.", "scene": "", "color": Color("#36D399")},
]

const HUB_SCENE: String = "res://hub/hub.tscn"


static func game_info(id: String) -> Dictionary:
	for g: Dictionary in GAMES:
		if str(g["id"]) == id:
			return g
	return {}
