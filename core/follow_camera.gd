class_name FollowCamera
extends Camera3D
## Smooth follow camera with slight lag, look-ahead, FOV kick and Juice
## screen shake. Games set `target` every frame.

var target: Vector3 = Vector3.ZERO
var offset: Vector3 = Vector3(0, 10.5, 10.0)
var look_offset: Vector3 = Vector3(0, 0, -6.0)
var follow_speed: float = 6.0
var lateral_follow: float = 0.45
var base_fov: float = 58.0
var zoom: float = 1.0

var _pos: Vector3 = Vector3.ZERO
var _look: Vector3 = Vector3.ZERO
var _fov_kick: float = 0.0
var _initialized: bool = false


func _ready() -> void:
	fov = base_fov
	near = 0.3
	far = 220.0


func snap() -> void:
	_pos = _desired_pos()
	_look = _desired_look()
	_initialized = true
	_apply()


## +degrees, decays back to base (spec: +6 on boost / big crowd growth).
func kick_fov(degrees: float = 6.0) -> void:
	_fov_kick = maxf(_fov_kick, degrees)


func _desired_pos() -> Vector3:
	var t: Vector3 = Vector3(target.x * lateral_follow, target.y, target.z)
	return t + offset * zoom


func _desired_look() -> Vector3:
	return Vector3(target.x * lateral_follow, target.y, target.z) + look_offset


func _process(delta: float) -> void:
	if not _initialized:
		snap()
	var k: float = 1.0 - exp(-follow_speed * delta)
	_pos = _pos.lerp(_desired_pos(), k)
	_look = _look.lerp(_desired_look(), minf(1.0, k * 1.4))
	_fov_kick = move_toward(_fov_kick, 0.0, delta * 9.0)
	_apply()


func _apply() -> void:
	var shake: Vector3 = Juice.shake_offset()
	global_position = _pos + shake
	look_at(_look + shake * 0.5, Vector3.UP)
	rotate_object_local(Vector3.FORWARD, Juice.shake_roll())
	fov = lerpf(fov, base_fov + _fov_kick, 0.25)
