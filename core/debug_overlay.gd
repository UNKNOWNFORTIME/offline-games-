extends CanvasLayer
## Debug overlay: FPS, frame time, draw calls, primitives, node count,
## pooled objects. Toggle with a 3-finger tap (F3 on desktop).

var _label: Label
var _acc: float = 0.0


func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	var bg := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.6)
	sb.set_corner_radius_all(16)
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	bg.add_theme_stylebox_override("panel", sb)
	bg.position = Vector2(24, 260)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 30)
	_label.add_theme_constant_override("outline_size", 0)
	bg.add_child(_label)
	visible = false
	TouchInput.three_finger_tap.connect(toggle)


func toggle() -> void:
	visible = not visible


func _process(delta: float) -> void:
	if not visible:
		return
	_acc += delta
	if _acc < 0.25:
		return
	_acc = 0.0
	var fps: float = Performance.get_monitor(Performance.TIME_FPS)
	var ms: float = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var draws: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var prims: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	var nodes: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var mem: float = Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0
	_label.text = "FPS %d  (cpu %.1f ms)\nDraw calls %d\nTris %dk\nNodes %d\nPooled active %d\nMem %.0f MB\nQuality %s  scale %.2f" % [
		int(fps), ms, draws, prims / 1000, nodes, Pool.total_active(), mem,
		"HIGH" if Settings.is_high() else "LOW", get_viewport().scaling_3d_scale]
