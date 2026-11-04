class_name SfxSynth
extends RefCounted
## Tiny sfxr-style synthesizer. Every SFX slot gets a generated placeholder
## at startup, so the game has real sound with zero audio files. Drop a file
## named audio/sfx/<name>.ogg (or .wav) and it replaces the synth version.

const RATE: int = 22050

enum Wave { SINE, SQUARE, SAW, TRIANGLE, NOISE }

## name -> recipe. Keys: w (Wave), f0, f1 (Hz), dur (s), vol, att (s),
## curve (pitch slide curve), arp (Array of freq multipliers), step (s per
## arp note), decay (envelope exponent), duty (square), loop (bool), sub (adds
## an octave-down sine for weight).
const RECIPES: Dictionary = {
	"ui_click": {"w": Wave.SQUARE, "f0": 980.0, "f1": 640.0, "dur": 0.05, "vol": 0.28, "duty": 0.3},
	"gate_good": {"w": Wave.SQUARE, "f0": 523.0, "f1": 523.0, "dur": 0.32, "vol": 0.3, "arp": [1.0, 1.26, 1.5, 2.0], "step": 0.06, "duty": 0.25, "decay": 1.5},
	"gate_bad": {"w": Wave.SAW, "f0": 330.0, "f1": 110.0, "dur": 0.34, "vol": 0.32, "curve": 0.6, "sub": true},
	"unit_pop": {"w": Wave.SINE, "f0": 620.0, "f1": 1300.0, "dur": 0.07, "vol": 0.3, "curve": 0.5},
	"coin_pick": {"w": Wave.SQUARE, "f0": 1320.0, "f1": 1320.0, "dur": 0.16, "vol": 0.22, "arp": [1.0, 1.5], "step": 0.05, "duty": 0.5},
	"coin_count_tick": {"w": Wave.SQUARE, "f0": 1760.0, "f1": 1900.0, "dur": 0.03, "vol": 0.14, "duty": 0.5},
	"boss_hit": {"w": Wave.NOISE, "f0": 900.0, "f1": 180.0, "dur": 0.13, "vol": 0.4, "sub": true},
	"boss_die": {"w": Wave.SAW, "f0": 260.0, "f1": 35.0, "dur": 0.9, "vol": 0.42, "curve": 0.7, "sub": true, "decay": 0.8},
	"win": {"w": Wave.SQUARE, "f0": 523.0, "f1": 523.0, "dur": 0.85, "vol": 0.28, "arp": [1.0, 1.26, 1.5, 2.0, 2.52, 3.0], "step": 0.09, "duty": 0.35, "decay": 0.7},
	"fail": {"w": Wave.TRIANGLE, "f0": 440.0, "f1": 440.0, "dur": 0.9, "vol": 0.4, "arp": [1.0, 0.94, 0.84, 0.66], "step": 0.2, "decay": 0.6},
	"spike_break": {"w": Wave.NOISE, "f0": 3200.0, "f1": 900.0, "dur": 0.16, "vol": 0.3},
	"engine_loop": {"w": Wave.SAW, "f0": 92.0, "f1": 92.0, "dur": 1.0, "vol": 0.18, "loop": true, "sub": true, "decay": 0.0},
	"boost": {"w": Wave.NOISE, "f0": 200.0, "f1": 1600.0, "dur": 0.5, "vol": 0.25, "att": 0.08},
	"near_miss": {"w": Wave.NOISE, "f0": 2400.0, "f1": 500.0, "dur": 0.28, "vol": 0.25, "att": 0.05},
	"crash": {"w": Wave.NOISE, "f0": 1400.0, "f1": 60.0, "dur": 0.7, "vol": 0.5, "sub": true, "decay": 0.9},
	"gun_pistol": {"w": Wave.NOISE, "f0": 2200.0, "f1": 260.0, "dur": 0.13, "vol": 0.38, "sub": true},
	"gun_smg": {"w": Wave.NOISE, "f0": 2600.0, "f1": 600.0, "dur": 0.07, "vol": 0.32},
	"gun_shotgun": {"w": Wave.NOISE, "f0": 1300.0, "f1": 90.0, "dur": 0.32, "vol": 0.5, "sub": true},
	"gun_rifle": {"w": Wave.NOISE, "f0": 3200.0, "f1": 180.0, "dur": 0.22, "vol": 0.45, "sub": true},
	"enemy_pop": {"w": Wave.SINE, "f0": 380.0, "f1": 900.0, "dur": 0.11, "vol": 0.35, "curve": 0.5},
	"barricade_hit": {"w": Wave.NOISE, "f0": 420.0, "f1": 70.0, "dur": 0.22, "vol": 0.45, "sub": true},
	"pickup": {"w": Wave.SQUARE, "f0": 660.0, "f1": 660.0, "dur": 0.3, "vol": 0.26, "arp": [1.0, 1.5, 2.0], "step": 0.07, "duty": 0.4},
	"whoosh": {"w": Wave.NOISE, "f0": 500.0, "f1": 1800.0, "dur": 0.25, "vol": 0.18, "att": 0.1},
	"stomp": {"w": Wave.NOISE, "f0": 300.0, "f1": 40.0, "dur": 0.35, "vol": 0.55, "sub": true},
}


static func make(recipe: Dictionary) -> AudioStreamWAV:
	var wave: int = int(recipe.get("w", Wave.SQUARE))
	var f0: float = float(recipe.get("f0", 440.0))
	var f1: float = float(recipe.get("f1", f0))
	var dur: float = float(recipe.get("dur", 0.2))
	var vol: float = float(recipe.get("vol", 0.3))
	var att: float = float(recipe.get("att", 0.004))
	var curve: float = float(recipe.get("curve", 1.0))
	var decay: float = float(recipe.get("decay", 1.2))
	var duty: float = float(recipe.get("duty", 0.5))
	var looped: bool = bool(recipe.get("loop", false))
	var sub: bool = bool(recipe.get("sub", false))
	var arp: Array = recipe.get("arp", [])
	var step: float = float(recipe.get("step", 0.1))

	var n: int = int(dur * RATE)
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	var phase: float = 0.0
	var sub_phase: float = 0.0
	var noise_val: float = 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(recipe))
	var inv_rate: float = 1.0 / float(RATE)
	for i: int in n:
		var t: float = float(i) * inv_rate
		var k: float = t / dur
		var f: float = lerpf(f0, f1, pow(k, curve))
		if arp.size() > 0:
			var idx: int = mini(int(t / step), arp.size() - 1)
			f *= float(arp[idx])
		var prev_phase: float = phase
		phase += f * inv_rate
		var fr: float = phase - floorf(phase)
		var s: float = 0.0
		match wave:
			Wave.SINE:
				s = sin(TAU * phase)
			Wave.SQUARE:
				s = 1.0 if fr < duty else -1.0
			Wave.SAW:
				s = 2.0 * fr - 1.0
			Wave.TRIANGLE:
				s = 4.0 * absf(fr - 0.5) - 1.0
			Wave.NOISE:
				if floorf(phase * 2.0) != floorf(prev_phase * 2.0):
					noise_val = rng.randf_range(-1.0, 1.0)
				s = noise_val
		if sub:
			sub_phase += f * 0.5 * inv_rate
			s = s * 0.7 + sin(TAU * sub_phase) * 0.5
		var env: float = 1.0
		if not looped:
			env = minf(1.0, t / maxf(att, 0.0001))
			if decay > 0.0:
				env *= pow(maxf(0.0, 1.0 - k), decay)
		var v: float = clampf(s * env * vol, -1.0, 1.0)
		bytes.encode_s16(i * 2, int(v * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = bytes
	if looped:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = n
	return stream
