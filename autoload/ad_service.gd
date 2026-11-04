extends Node
## Ad interface used by all games. Phases 0-5: MOCK implementation that shows
## a fake 2-second overlay. Phase 6 swaps the internals for AdMob while the
## public API stays the same:
##   show_interstitial(), show_rewarded(callback), is_rewarded_ready()
## Interstitial rules (GAME_SPEC 8): only after a completed level, never
## before level 3, at most once per 90 s, never twice without gameplay.

signal ad_started(kind: String)
signal ad_finished(kind: String, rewarded: bool)

const MOCK_DURATION: float = 2.0
# Google's official TEST ids (see docs/ADMOB.md). Replace before release.
const ADMOB_APP_ID: String = "ca-app-pub-3940256099942544~3347511713"
const ADMOB_INTERSTITIAL_ID: String = "ca-app-pub-3940256099942544/1033173712"
const ADMOB_REWARDED_ID: String = "ca-app-pub-3940256099942544/5224354917"
const INTERSTITIAL_COOLDOWN_MS: int = 90_000
const INTERSTITIAL_MIN_LEVEL: int = 3

var showing: bool = false
var _last_interstitial_ms: int = -INTERSTITIAL_COOLDOWN_MS
var _gameplay_since_interstitial: bool = true
var _layer: CanvasLayer
var _label: Label
var _bar: ColorRect


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_layer = CanvasLayer.new()
	_layer.layer = 120
	_layer.visible = false
	add_child(_layer)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.92)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_layer.add_child(bg)
	_label = Label.new()
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 64)
	_layer.add_child(_label)
	_bar = ColorRect.new()
	_bar.color = Palette.UI_ACCENT
	_bar.anchor_top = 1.0
	_bar.anchor_bottom = 1.0
	_bar.offset_top = -24.0
	_layer.add_child(_bar)


func is_rewarded_ready() -> bool:
	return not showing


## callback receives one bool: true if the reward was earned.
func show_rewarded(callback: Callable) -> void:
	if showing:
		callback.call(false)
		return
	await _show_mock("rewarded", "REWARDED AD\n(mock)")
	callback.call(true)
	ad_finished.emit("rewarded", true)


func show_interstitial() -> void:
	if showing:
		return
	_last_interstitial_ms = Time.get_ticks_msec()
	_gameplay_since_interstitial = false
	await _show_mock("interstitial", "AD\n(mock)")
	ad_finished.emit("interstitial", false)


## Applies the interstitial rules. Returns true if an ad will be shown; the
## caller should then `await AdService.ad_finished`.
func should_show_interstitial(completed_level: int) -> bool:
	if completed_level < INTERSTITIAL_MIN_LEVEL:
		return false
	if not _gameplay_since_interstitial:
		return false
	if Time.get_ticks_msec() - _last_interstitial_ms < INTERSTITIAL_COOLDOWN_MS:
		return false
	return true


## Games call this when real gameplay happened (a run started).
func notify_gameplay() -> void:
	_gameplay_since_interstitial = true


func _show_mock(kind: String, text: String) -> void:
	showing = true
	ad_started.emit(kind)
	var was_paused: bool = get_tree().paused
	get_tree().paused = true
	_label.text = text
	_layer.visible = true
	_bar.anchor_right = 0.0
	var t: Tween = create_tween()
	t.tween_property(_bar, "anchor_right", 1.0, MOCK_DURATION)
	await t.finished
	_layer.visible = false
	get_tree().paused = was_paused
	showing = false
