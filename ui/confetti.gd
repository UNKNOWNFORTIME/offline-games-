class_name Confetti
extends RefCounted
## 2D confetti from both screen sides (level complete).

static func spawn(parent: Control) -> void:
	var vp: Vector2 = parent.get_viewport_rect().size
	for side: int in [-1, 1]:
		var p := CPUParticles2D.new()
		p.amount = int(70.0 * Settings.particle_scale()) + 10
		p.lifetime = 2.6
		p.one_shot = true
		p.explosiveness = 0.92
		p.position = Vector2(0.0 if side < 0 else vp.x, vp.y * 0.62)
		p.direction = Vector2(-float(side), -1.6).normalized()
		p.spread = 22.0
		p.initial_velocity_min = 1500.0
		p.initial_velocity_max = 2500.0
		p.gravity = Vector2(0, 2300)
		p.damping_min = 300.0
		p.damping_max = 600.0
		p.angular_velocity_min = -540.0
		p.angular_velocity_max = 540.0
		p.angle_min = 0.0
		p.angle_max = 360.0
		p.scale_amount_min = 16.0
		p.scale_amount_max = 30.0
		var g := Gradient.new()
		g.set_color(0, Palette.PLAYER)
		g.set_color(1, Palette.GOLD)
		g.add_point(0.25, Palette.ENEMY_LIGHT)
		g.add_point(0.5, Palette.UI_ACCENT)
		g.add_point(0.75, Color.WHITE)
		p.color_initial_ramp = g
		parent.add_child(p)
		p.emitting = true
		p.finished.connect(p.queue_free)
