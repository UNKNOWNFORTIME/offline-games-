class_name SmokeTest
extends Node
## Automated play-through used by CI (`godot -- --smoke --smoke-out=DIR`).
## Visits the Hub, settings, then every built game on autopilot, taking
## screenshots, then quits. CI fails on any script/shader error in the log.

var out_dir: String = ""
var preview_filter: RegEx = null
var _shot_index: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--smoke-out="):
			out_dir = a.substr(12)
		elif a.begins_with("--preview="):
			preview_filter = RegEx.new()
			preview_filter.compile(a.substr(10))
	_run()


func _wait(t: float) -> void:
	await get_tree().create_timer(t, true, false, true).timeout


func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	if out_dir == "":
		return
	var img: Image = get_viewport().get_texture().get_image()
	if img == null:
		return
	var path: String = "%s/%02d_%s.png" % [out_dir, _shot_index, label]
	_shot_index += 1
	img.save_png(path)
	print("SMOKE shot ", path)
	print("SMOKE perf %s draws=%d tris=%d nodes=%d objects=%d quality=%s" % [label,
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)),
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)),
		"high" if Settings.is_high() else "low"])
	if preview_filter != null and preview_filter.search(label) != null:
		var small: Image = img.duplicate() as Image
		small.resize(216, 384, Image.INTERPOLATE_BILINEAR)
		var b64: String = Marshalls.raw_to_base64(small.save_jpg_to_buffer(0.55))
		print("=====BEGIN %s=====" % label)
		var i: int = 0
		while i < b64.length():
			print(b64.substr(i, 4000))
			i += 4000
		print("=====END %s=====" % label)


func _run() -> void:
	print("SMOKE start")
	await _wait(2.5)
	await shot("hub")
	var sp := SettingsPanel.new()
	get_tree().current_scene.add_child(sp)
	await _wait(0.8)
	await shot("settings")
	sp.queue_free()
	await _wait(0.3)

	for g: Dictionary in AppInfo.GAMES:
		var id: String = str(g["id"])
		if str(g["scene"]) == "":
			continue
		var levels: Array = [3, 7] if id == "crowd_rush" else [2]
		for lvl: Variant in levels:
			await _play(id, int(lvl), 55.0)
	# Low quality pass on every game (perf budget check in the log).
	Settings.set_quality(false)
	for g: Dictionary in AppInfo.GAMES:
		if str(g["scene"]) != "":
			await _play(str(g["id"]), 4, 9.0)
	Settings.set_quality(true)
	print("SMOKE TEST PASSED")
	get_tree().quit(0)


func _play(id: String, lvl: int, max_time: float) -> void:
	SaveSystem.game(id)["level"] = lvl
	GameState.start_game(id)
	await _wait(1.6)
	await shot("%s_L%d_ready" % [id, lvl])
	var scene: Node = get_tree().current_scene
	if scene != null and scene.has_method("smoke_start"):
		scene.call("smoke_start")
	var t: float = 0.0
	var next_shot: float = 2.0
	while t < max_time:
		await _wait(0.25)
		t += 0.25
		if t >= next_shot:
			next_shot += 3.5
			await shot("%s_L%d_t%02d" % [id, lvl, int(t)])
		var ends: Array[Node] = get_tree().get_nodes_in_group("end_screen")
		if ends.size() > 0:
			await _wait(2.2)
			await shot("%s_L%d_end" % [id, lvl])
			break
	GameState.go_hub()
	await _wait(1.2)
