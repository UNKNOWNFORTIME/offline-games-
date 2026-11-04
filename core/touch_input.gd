extends Node
## Unified touch/mouse input for every game (GAME_SPEC 3).
## Emits drag deltas (runners), swipes (lanes), hold state (boost/fire),
## taps, and a 3-finger tap (debug overlay). Mouse works via the
## project setting "emulate_touch_from_mouse"; arrow keys also drag on desktop.
## Controls in the group "touch_block" (pause buttons...) never start a gesture.

signal pressed(pos: Vector2)
signal released(pos: Vector2)
signal dragged(delta: Vector2, pos: Vector2)
signal tapped(pos: Vector2)
signal swiped(dir: Vector2i)
signal three_finger_tap

const SWIPE_MIN_PX: float = 70.0
const SWIPE_MAX_TIME: float = 0.35
const TAP_MAX_PX: float = 24.0
const TAP_MAX_TIME: float = 0.3
const HOLD_DELAY: float = 0.12
const KEY_DRAG_SPEED: float = 1100.0

var is_down: bool = false
var hold_time: float = 0.0
var position: Vector2 = Vector2.ZERO
var enabled: bool = true

var _touches: Dictionary = {}
var _primary: int = -1
var _start_pos: Vector2 = Vector2.ZERO
var _start_ms: int = 0
var _travel: float = 0.0
var _swipe_sent: bool = false
var _key_delta: Vector2 = Vector2.ZERO


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## True while a finger is held long enough to count as "holding".
func is_holding() -> bool:
	return is_down and hold_time >= HOLD_DELAY


## Total finger travel (px) since the current press began.
func travel() -> float:
	return _travel if is_down else 0.0


func reset() -> void:
	_touches.clear()
	_primary = -1
	is_down = false
	hold_time = 0.0


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var st: InputEventScreenTouch = event as InputEventScreenTouch
		if st.pressed:
			_touches[st.index] = st.position
			if _touches.size() == 3:
				three_finger_tap.emit()
			if _primary == -1 and enabled and not is_over_ui(st.position):
				_primary = st.index
				is_down = true
				hold_time = 0.0
				position = st.position
				_start_pos = st.position
				_start_ms = Time.get_ticks_msec()
				_travel = 0.0
				_swipe_sent = false
				pressed.emit(st.position)
		else:
			_touches.erase(st.index)
			if st.index == _primary:
				_end_gesture(st.position)
	elif event is InputEventScreenDrag:
		var sd: InputEventScreenDrag = event as InputEventScreenDrag
		_touches[sd.index] = sd.position
		if sd.index == _primary:
			position = sd.position
			_travel += sd.relative.length()
			dragged.emit(sd.relative, sd.position)
			_check_swipe(sd.position, false)


func _end_gesture(pos: Vector2) -> void:
	var dt: float = float(Time.get_ticks_msec() - _start_ms) / 1000.0
	if not _swipe_sent:
		_check_swipe(pos, true)
	if not _swipe_sent and _travel < TAP_MAX_PX and dt < TAP_MAX_TIME:
		tapped.emit(pos)
	_primary = -1
	is_down = false
	hold_time = 0.0
	released.emit(pos)


func _check_swipe(pos: Vector2, final: bool) -> void:
	if _swipe_sent:
		return
	var d: Vector2 = pos - _start_pos
	var dt: float = float(Time.get_ticks_msec() - _start_ms) / 1000.0
	if dt > SWIPE_MAX_TIME and not final:
		return
	if d.length() < SWIPE_MIN_PX or dt > SWIPE_MAX_TIME:
		return
	_swipe_sent = true
	if absf(d.x) > absf(d.y):
		swiped.emit(Vector2i(signi(int(d.x)), 0))
	else:
		swiped.emit(Vector2i(0, signi(int(d.y))))


func _process(delta: float) -> void:
	if is_down:
		hold_time += delta
	# Desktop convenience: arrow keys / A-D behave like a horizontal drag.
	var kx: float = 0.0
	if Input.is_physical_key_pressed(KEY_LEFT) or Input.is_physical_key_pressed(KEY_A):
		kx -= 1.0
	if Input.is_physical_key_pressed(KEY_RIGHT) or Input.is_physical_key_pressed(KEY_D):
		kx += 1.0
	if kx != 0.0 and enabled:
		_key_delta.x = kx * KEY_DRAG_SPEED * delta
		dragged.emit(_key_delta, position)


func _unhandled_key_input(event: InputEvent) -> void:
	var k: InputEventKey = event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if k.physical_keycode == KEY_F3:
		three_finger_tap.emit()
	elif k.physical_keycode == KEY_SPACE and enabled:
		tapped.emit(get_viewport().get_visible_rect().size * 0.5)
		pressed.emit(get_viewport().get_visible_rect().size * 0.5)
		released.emit(get_viewport().get_visible_rect().size * 0.5)


## Is a screen position over an interactive, visible control that should
## swallow the touch (group "touch_block") or over any open modal?
func is_over_ui(pos: Vector2) -> bool:
	for n: Node in get_tree().get_nodes_in_group("touch_block"):
		var c: Control = n as Control
		if c != null and c.is_visible_in_tree() and c.get_global_rect().has_point(pos):
			return true
	return false
