extends Node
## Current game, scene transitions with a fade, global theme.

signal scene_changed(id: String)

const FADE_TIME: float = 0.22

var current_game: String = ""
var _layer: CanvasLayer
var _fade: ColorRect
var _busy: bool = false
var _play_time_acc: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.theme = UiTheme.get_theme()
	_layer = CanvasLayer.new()
	_layer.layer = 110
	add_child(_layer)
	_fade = ColorRect.new()
	_fade.color = Palette.UI_DARK
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.modulate.a = 0.0
	_layer.add_child(_fade)
	# Boot fade-in from the splash color.
	_fade.modulate.a = 1.0
	var t: Tween = create_tween()
	t.tween_interval(0.05)
	t.tween_property(_fade, "modulate:a", 0.0, 0.35)
	get_tree().set_auto_accept_quit(false)
	get_tree().set_quit_on_go_back(false)
	if OS.get_cmdline_user_args().has("--smoke"):
		add_child(SmokeTest.new())


func _process(delta: float) -> void:
	if current_game != "" and not get_tree().paused:
		_play_time_acc += delta
		if _play_time_acc >= 10.0:
			var stats: Dictionary = SaveSystem.data["stats"]
			stats["play_seconds"] = int(stats.get("play_seconds", 0)) + int(_play_time_acc)
			_play_time_acc = 0.0


func go_hub() -> void:
	_change(AppInfo.HUB_SCENE, "")


func start_game(id: String) -> void:
	var info: Dictionary = AppInfo.game_info(id)
	if info.is_empty() or str(info["scene"]) == "":
		return
	_change(str(info["scene"]), id)


func reload() -> void:
	if current_game == "":
		go_hub()
	else:
		start_game(current_game)


func _change(path: String, id: String) -> void:
	if _busy:
		return
	_busy = true
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var t: Tween = create_tween()
	t.tween_property(_fade, "modulate:a", 1.0, FADE_TIME)
	await t.finished
	get_tree().paused = false
	Juice.clear()
	TouchInput.reset()
	AudioManager.stop_all_loops()
	SaveSystem.save_game()
	current_game = id
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame
	scene_changed.emit(id)
	var t2: Tween = create_tween()
	t2.tween_property(_fade, "modulate:a", 0.0, FADE_TIME + 0.08)
	await t2.finished
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		SaveSystem.save_game()
		get_tree().quit()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		# Android back: from a game go to the Hub; from the Hub quit.
		if current_game != "":
			go_hub()
		else:
			SaveSystem.save_game()
			get_tree().quit()
