extends Node
## SFX voice pool (8 voices), music crossfade, bus volumes/mute.
## Files in res://audio/sfx/<name>.(ogg|wav) override the synth placeholders.
## Music files: res://audio/music/<name>.ogg (hub, crowd_rush, stack_skater,
## overtake, last_barricade). Missing music = silence.

const VOICES: int = 8
const SFX_DIR: String = "res://audio/sfx/"
const MUSIC_DIR: String = "res://audio/music/"
const MUSIC_DB: float = -8.0

var _voices: Array[AudioStreamPlayer] = []
var _next_voice: int = 0
var _streams: Dictionary = {}
var _last_played: Dictionary = {}
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_current: String = ""
var _loops: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
	for i: int in VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_voices.append(p)
	_music_a = _make_music_player()
	_music_b = _make_music_player()
	_load_streams()
	Settings.changed.connect(_on_setting_changed)
	_apply_mutes()


func _make_music_player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = "Music"
	p.volume_db = -80.0
	add_child(p)
	return p


func _setup_buses() -> void:
	for bus_name: String in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			var idx: int = AudioServer.bus_count
			AudioServer.add_bus(idx)
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")


func _load_streams() -> void:
	var missing: Array = []
	for sfx_name: String in SfxSynth.RECIPES.keys():
		var file_stream: AudioStream = _try_load(SFX_DIR + sfx_name)
		if file_stream != null:
			_streams[sfx_name] = file_stream
		else:
			missing.append(sfx_name)
	# Synthesize placeholders off the main thread so boot stays instant on
	# low-end phones. Sounds requested before they're ready are skipped.
	if missing.size() > 0:
		WorkerThreadPool.add_task(_synth_worker.bind(missing), false, "sfx_synth")


func _synth_worker(names: Array) -> void:
	var out: Dictionary = {}
	for n: Variant in names:
		out[n] = SfxSynth.make(SfxSynth.RECIPES[n])
	call_deferred("_on_synth_done", out)


func _on_synth_done(out: Dictionary) -> void:
	for n: Variant in out.keys():
		if not _streams.has(n):
			_streams[n] = out[n]
	for p: Variant in _loops.values():
		var lp: AudioStreamPlayer = p as AudioStreamPlayer
		if lp.stream == null:
			for n: Variant in _loops.keys():
				if _loops[n] == lp:
					lp.stream = _streams.get(n, null)


func _try_load(base_path: String) -> AudioStream:
	for ext: String in [".ogg", ".wav", ".mp3"]:
		if ResourceLoader.exists(base_path + ext):
			return load(base_path + ext) as AudioStream
	return null


## Plays a one-shot SFX with ±pitch_var random pitch (spec: ±8% on repeats).
func play(sfx_name: String, pitch_var: float = 0.0, volume_db: float = 0.0, min_interval: float = 0.03, pitch: float = 1.0) -> void:
	if not Settings.sound:
		return
	if not _streams.has(sfx_name):
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	var last: float = float(_last_played.get(sfx_name, -10.0))
	if now - last < min_interval:
		return
	_last_played[sfx_name] = now
	var p: AudioStreamPlayer = _voices[_next_voice]
	_next_voice = (_next_voice + 1) % VOICES
	p.stream = _streams[sfx_name]
	p.pitch_scale = pitch * (1.0 + randf_range(-pitch_var, pitch_var))
	p.volume_db = volume_db
	p.play()


## Starts/stops a looping SFX on a dedicated player (engines etc).
func set_loop(sfx_name: String, playing: bool, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	var p: AudioStreamPlayer = _loops.get(sfx_name, null)
	if p == null:
		if not playing:
			return
		p = AudioStreamPlayer.new()
		p.bus = "SFX"
		p.stream = _streams.get(sfx_name, null)
		add_child(p)
		_loops[sfx_name] = p
	if p.stream == null:
		return
	p.pitch_scale = pitch
	p.volume_db = volume_db
	if playing and Settings.sound and not p.playing:
		p.play()
	elif not playing and p.playing:
		p.stop()


func stop_all_loops() -> void:
	for p: Variant in _loops.values():
		(p as AudioStreamPlayer).stop()


func play_music(track: String, fade: float = 0.8) -> void:
	if track == _music_current:
		return
	_music_current = track
	var stream: AudioStream = _try_load(MUSIC_DIR + track)
	var old_p: AudioStreamPlayer = _music_a if _music_a.playing else _music_b
	var new_p: AudioStreamPlayer = _music_b if old_p == _music_a else _music_a
	if old_p.playing:
		var t_out: Tween = create_tween()
		t_out.tween_property(old_p, "volume_db", -80.0, fade)
		t_out.tween_callback(old_p.stop)
	if stream == null:
		return
	new_p.stream = stream
	new_p.volume_db = -80.0
	new_p.play()
	var t_in: Tween = create_tween()
	t_in.tween_property(new_p, "volume_db", MUSIC_DB, fade)


func _on_setting_changed(key: String) -> void:
	if key == "sound" or key == "music":
		_apply_mutes()
		if key == "sound" and not Settings.sound:
			stop_all_loops()


func _apply_mutes() -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("SFX"), not Settings.sound)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), not Settings.music)
