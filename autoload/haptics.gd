extends Node
## Wrapper around Input.vibrate_handheld(). Respects the settings toggle.
## Presets per GAME_SPEC: light 15ms, medium 30ms, heavy 60ms.

const LIGHT_MS: int = 15
const MEDIUM_MS: int = 30
const HEAVY_MS: int = 60
const MIN_GAP_MS: int = 45

var _last_ms: int = -1000
var _is_mobile: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_is_mobile = OS.has_feature("mobile")


func light() -> void:
	_vibrate(LIGHT_MS)


func medium() -> void:
	_vibrate(MEDIUM_MS)


func heavy() -> void:
	_vibrate(HEAVY_MS, true)


func _vibrate(ms: int, force: bool = false) -> void:
	if not Settings.haptics or not _is_mobile:
		return
	var now: int = Time.get_ticks_msec()
	if not force and now - _last_ms < MIN_GAP_MS:
		return
	_last_ms = now
	Input.vibrate_handheld(ms)
