extends Node
## Player settings. Stored inside the save file under "settings".

signal changed(key: String)
signal quality_changed(high: bool)

const LOW_RENDER_SCALE: float = 0.75


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	apply_quality()


func _s() -> Dictionary:
	return SaveSystem.data["settings"]


func get_bool(key: String) -> bool:
	return bool(_s().get(key, true))


func set_value(key: String, value: Variant) -> void:
	_s()[key] = value
	SaveSystem.mark_dirty(0.1)
	changed.emit(key)


var sound: bool:
	get:
		return get_bool("sound")
	set(v):
		set_value("sound", v)

var music: bool:
	get:
		return get_bool("music")
	set(v):
		set_value("music", v)

var haptics: bool:
	get:
		return get_bool("haptics")
	set(v):
		set_value("haptics", v)


func is_high() -> bool:
	return str(_s().get("quality", "high")) == "high"


func set_quality(high: bool) -> void:
	if high == is_high():
		return
	set_value("quality", "high" if high else "low")
	Toon.clear_cache()
	apply_quality()
	quality_changed.emit(high)


func quality_checked() -> bool:
	return bool(_s().get("quality_checked", false))


func mark_quality_checked() -> void:
	set_value("quality_checked", true)


func shadows_enabled() -> bool:
	return is_high()


func outlines_enabled() -> bool:
	return is_high()


func max_crowd_visible() -> int:
	return 300 if is_high() else 120


func particle_scale() -> float:
	return 1.0 if is_high() else 0.5


## Applies viewport-level settings (render scale + MSAA).
func apply_quality() -> void:
	var vp: Viewport = get_viewport()
	if vp == null:
		return
	if is_high():
		vp.scaling_3d_scale = 1.0
		vp.msaa_3d = Viewport.MSAA_2X
	else:
		vp.scaling_3d_scale = LOW_RENDER_SCALE
		vp.msaa_3d = Viewport.MSAA_DISABLED
