class_name SkaterLevels
extends RefCounted
## Seeded level generator for Stack Skater with a difficulty curve.
## Feature types (d = distance from start in meters):
##   pickup {x, amount}         coin stack on the track
##   gate   {left, right}       multiplier wall pair (GatePair ops)
##   spikes {side, inner, len}  spike strip from x=inner to the rail on side
##   narrow {half, len}         walls at +-half: wide stacks scrape
## step_cost: coins dropped per finish-ramp step (x2..x10).

const TRACK_HALF: float = 3.0


static func generate(n: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("stack_skater_%d" % n)
	var diff: float = clampf(float(n - 1) / 30.0, 0.0, 1.0)
	var length: float = roundf(lerpf(170.0, 260.0, diff))
	var feats: Array = []
	var d: float = 22.0
	var est: float = 4.0  # estimated stack of a decent player
	var pattern: int = 0
	while d < length - 26.0:
		var roll: float = rng.randf()
		if n <= 1 and pattern < 3:
			roll = 0.1  # first level: mostly pickups to teach the loop
		if roll < 0.42:
			# Row of pickups: straight line, zigzag or wide spread.
			var count: int = rng.randi_range(3, 5)
			var style: int = rng.randi_range(0, 2)
			var base_x: float = rng.randf_range(-1.8, 1.8)
			for i: int in count:
				var x: float = base_x
				if style == 1:
					x = (1.6 if i % 2 == 0 else -1.6) * rng.randf_range(0.7, 1.0)
				elif style == 2:
					x = lerpf(-2.2, 2.2, float(i) / float(count - 1))
				var amt: int = [3, 5, 5, 8, 10][rng.randi_range(0, 4)] + int(diff * 4.0)
				feats.append({"type": "pickup", "d": d + float(i) * 3.2, "x": x, "amount": amt})
				est += float(amt) * 0.7
			d += float(count) * 3.2 + 9.0
		elif roll < 0.6 and n >= 2:
			var side: float = -1.0 if rng.randf() < 0.5 else 1.0
			var inner: float = rng.randf_range(lerpf(1.6, 0.7, diff), 2.0)
			feats.append({"type": "spikes", "d": d, "side": side, "inner": inner, "len": 4.5})
			est *= 0.85
			d += 15.0
		elif roll < 0.76 and n >= 3:
			var half: float = rng.randf_range(lerpf(2.0, 1.2, diff), 2.1)
			var ln: float = rng.randf_range(8.0, 14.0)
			feats.append({"type": "narrow", "d": d, "half": half, "len": ln})
			est = minf(est, (half - 0.3) / 0.078 * 2.0 * 1.4)
			d += ln + 10.0
		else:
			var good: String = "x2" if est < 80.0 or rng.randf() < 0.4 else "+%d" % int(est * 0.4)
			var other: String = "+%d" % rng.randi_range(4, 10)
			if n >= 2 and rng.randf() < 0.5:
				other = "-%d" % maxi(2, int(est * 0.3))
			var left: String = good
			var right: String = other
			if rng.randf() < 0.5:
				left = other
				right = good
			feats.append({"type": "gate", "d": d, "left": left, "right": right})
			est = est * 2.0 if good == "x2" else est + est * 0.4
			d += 16.0
		pattern += 1
	var step_cost: int = maxi(2, int(est * lerpf(0.055, 0.09, diff)))
	return {"length": length, "features": feats, "step_cost": step_cost}
