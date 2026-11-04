extends Node
## Persists everything to user://save.json with a versioned schema.
## Writes are atomic (temp file + rename) so a crash never corrupts a save.

signal saved
signal loaded

const PATH: String = "user://save.json"
const TMP_PATH: String = "user://save.json.tmp"
const VERSION: int = 1

var data: Dictionary = {}
var _dirty: bool = false
var _autosave_timer: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_game()


func _process(delta: float) -> void:
	if _dirty:
		_autosave_timer -= delta
		if _autosave_timer <= 0.0:
			save_game()


func default_data() -> Dictionary:
	return {
		"version": VERSION,
		"coins": 0,
		"settings": {
			"sound": true,
			"music": true,
			"haptics": true,
			"quality": "high",
			"quality_checked": false,
			"language": "en",
		},
		"games": {
			"crowd_rush": {"level": 1, "best_level": 1, "start_crowd": 0},
			"stack_skater": {"level": 1, "best_level": 1},
			"overtake": {"level": 1, "best_level": 1, "upgrades": {"stamina": 0, "power": 0, "income": 0}},
			"last_barricade": {"level": 1, "best_level": 1},
		},
		"daily": {"streak": 0, "last_claim": ""},
		"stats": {"levels_completed": 0, "play_seconds": 0},
	}


func load_game() -> void:
	var defaults: Dictionary = default_data()
	data = defaults
	if FileAccess.file_exists(PATH):
		var f: FileAccess = FileAccess.open(PATH, FileAccess.READ)
		if f != null:
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			f.close()
			if parsed is Dictionary:
				var loaded_data: Dictionary = _migrate(parsed as Dictionary)
				data = _merge(defaults, loaded_data)
			else:
				push_warning("SaveSystem: save file unreadable, starting fresh.")
	loaded.emit()


func save_game() -> void:
	_dirty = false
	data["version"] = VERSION
	var f: FileAccess = FileAccess.open(TMP_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("SaveSystem: cannot write save (%d)" % FileAccess.get_open_error())
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	var dir: DirAccess = DirAccess.open("user://")
	if dir != null:
		if dir.file_exists("save.json"):
			dir.remove("save.json")
		dir.rename("save.json.tmp", "save.json")
	saved.emit()


## Mark data changed; it is written shortly after (coalesces many changes).
func mark_dirty(delay: float = 0.5) -> void:
	if not _dirty:
		_autosave_timer = delay
	_dirty = true


func game(id: String) -> Dictionary:
	var games: Dictionary = data["games"]
	if not games.has(id):
		games[id] = {"level": 1, "best_level": 1}
	return games[id]


func get_int(dict: Dictionary, key: String, fallback: int = 0) -> int:
	if dict.has(key):
		return int(dict[key])
	return fallback


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED \
			or what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_GO_BACK_REQUEST:
		save_game()


## Upgrades old schemas step by step. Add a branch per version bump.
func _migrate(d: Dictionary) -> Dictionary:
	var v: int = int(d.get("version", 0))
	if v < 1:
		# v0 (pre-release) stored coins at top level only; nothing else to move.
		d["version"] = 1
	return d


## Deep-merge: keeps loaded values, fills in any keys added since.
func _merge(defaults: Dictionary, loaded_data: Dictionary) -> Dictionary:
	var out: Dictionary = defaults.duplicate(true)
	for key: Variant in loaded_data.keys():
		var lv: Variant = loaded_data[key]
		if out.has(key) and out[key] is Dictionary and lv is Dictionary:
			out[key] = _merge(out[key] as Dictionary, lv as Dictionary)
		else:
			out[key] = lv
	return out
