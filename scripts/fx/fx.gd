extends RefCounted
## Разовые визуальные эффекты (частицы).


static func burst(parent: Node, pos: Vector2, color: Color, count: int = 8, speed: float = 40.0, life: float = 0.6) -> void:
	if parent == null:
		return
	var p := CPUParticles2D.new()
	p.position = pos
	p.z_index = 10
	p.one_shot = true
	p.amount = count
	p.lifetime = life
	p.explosiveness = 1.0
	p.direction = Vector2(0, -1)
	p.spread = 75.0
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = Vector2(0, 140)
	p.color = color
	p.texture = _px_texture(2, 2, Color.WHITE)
	parent.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


static func _px_texture(w: int, h: int, c: Color) -> Texture2D:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(c)
	return ImageTexture.create_from_image(img)
