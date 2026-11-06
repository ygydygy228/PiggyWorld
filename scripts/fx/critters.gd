extends Node2D
## Живая мелочь: днём бабочки, ночью светлячки. Держатся вокруг игрока.

const COUNT := 16
const RADIUS := 220.0

var _player = null
var _items: Array = []
var _day_tex: Array[Texture2D] = []
var _night_tex: Texture2D
var _t: float = 0.0


func setup(player) -> void:
	_player = player


func _ready() -> void:
	z_index = 40
	_day_tex = [_butterfly_tex(0), _butterfly_tex(1)]
	_night_tex = _firefly_tex()
	for i in range(COUNT):
		_items.append(_make_bug(i))


func _process(delta: float) -> void:
	_t += delta
	var night := TimeSystem.is_night()
	var center: Vector2 = _player.global_position if is_instance_valid(_player) else Vector2.ZERO
	var flip := int(_t * 6.0) % 2
	for it in _items:
		var s: Sprite2D = it["sprite"]
		var p: Vector2 = it["pos"]
		var vel: Vector2 = it["vel"]
		vel += Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * 26.0 * delta
		vel = vel.limit_length(it["speed"])
		p += vel * delta
		var drift := Vector2(sin(_t * 2.2 + it["phase"]), cos(_t * 1.7 + it["phase"])) * 0.35
		p += drift
		if p.distance_to(center) > RADIUS:
			p = center + Vector2(randf_range(-RADIUS, RADIUS), randf_range(-RADIUS, RADIUS)) * 0.6
			vel = Vector2.ZERO
		it["pos"] = p
		it["vel"] = vel
		s.global_position = Vector2(round(p.x), round(p.y))
		if night:
			s.texture = _night_tex
			s.visible = it["firefly"]
			s.modulate.a = 0.55 + 0.45 * sin(_t * 3.0 + it["phase"] * 4.0)
			s.modulate = Color(1.0, 1.0, 0.75, s.modulate.a)
		else:
			s.visible = true
			s.texture = _day_tex[flip if it["anim"] else (1 - flip)]
			s.modulate = Color(1, 1, 1, 0.9)


func _make_bug(i: int) -> Dictionary:
	var s := Sprite2D.new()
	s.texture = _day_tex[0]
	s.z_index = 40
	add_child(s)
	var firefly := i % 3 == 0
	return {
		"sprite": s,
		"pos": Vector2.ZERO,
		"vel": Vector2.ZERO,
		"phase": randf() * TAU,
		"speed": randf_range(14.0, 30.0),
		"anim": i % 2 == 0,
		"firefly": firefly,
	}


func _butterfly_tex(frame: int) -> Texture2D:
	# 8x6, крылья вверх/вниз, тело тёмное
	var img := Image.create(8, 6, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var wing := Color("#ffe9a8") if frame == 0 else Color("#f7d27a")
	var wing2 := Color("#ffffff")
	var body := Color("#4a3a2a")
	if frame == 0:
		for x in [0, 1, 6, 7]:
			img.set_pixel(x, 2, wing)
		for x in [0, 1, 2, 5, 6, 7]:
			img.set_pixel(x, 1, wing2)
		for x in [1, 2, 5, 6]:
			img.set_pixel(x, 3, wing)
	else:
		for x in [0, 1, 6, 7]:
			img.set_pixel(x, 1, wing)
		for x in [1, 2, 5, 6]:
			img.set_pixel(x, 2, wing2)
		for x in [1, 2, 5, 6]:
			img.set_pixel(x, 3, wing)
	for y in range(1, 4):
		img.set_pixel(3, y, body)
		img.set_pixel(4, y, body)
	img.set_pixel(3, 4, body)
	img.set_pixel(4, 4, body)
	return ImageTexture.create_from_image(img)


func _firefly_tex() -> Texture2D:
	var img := Image.create(5, 5, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var glow := Color(0.85, 1.0, 0.55, 0.35)
	var core := Color(1.0, 1.0, 0.7, 1.0)
	for p in [Vector2i(1, 2), Vector2i(3, 2), Vector2i(2, 1), Vector2i(2, 3)]:
		img.set_pixel(p.x, p.y, glow)
	img.set_pixel(2, 2, core)
	return ImageTexture.create_from_image(img)
