extends Node2D
## Дождь, снег, падающие листья. Вешается ребёнком камеры.

var _rain: CPUParticles2D
var _snow: CPUParticles2D
var _leaves: CPUParticles2D


func _ready() -> void:
	_rain = _make(260, 0.9, Vector2(-0.25, 1.0), 4.0, 300.0, 340.0, Vector2.ZERO, 1, 5, Color(0.75, 0.88, 1.0, 0.8))
	_snow = _make(140, 6.0, Vector2(0.15, 1.0), 25.0, 14.0, 28.0, Vector2(2, 0), 2, 2, Color(1, 1, 1, 0.95))
	_leaves = _make(14, 8.0, Vector2(0.6, 1.0), 35.0, 10.0, 22.0, Vector2(4, 3), 2, 2, Color(0.9, 0.55, 0.2, 1.0))
	for p in [_rain, _snow, _leaves]:
		p.emitting = false


func _make(amount: int, life: float, dir: Vector2, spread: float, v_min: float, v_max: float, grav: Vector2, w: int, h: int, col: Color) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = amount
	p.lifetime = life
	p.preprocess = life
	p.local_coords = false
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(280, 2)
	p.position = Vector2(0, -160)
	p.direction = dir
	p.spread = spread
	p.initial_velocity_min = v_min
	p.initial_velocity_max = v_max
	p.gravity = grav
	p.z_index = 20
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(col)
	p.texture = ImageTexture.create_from_image(img)
	add_child(p)
	return p


func set_weather(kind: String, season: int) -> void:
	_rain.emitting = kind == "rain"
	_snow.emitting = kind == "snow"
	# листья: весной розовые лепестки, осенью оранжевые
	var leaves_on := (season == 0 or season == 2) and kind == "sunny"
	_leaves.emitting = leaves_on
	if season == 0:
		_leaves.color = Color(1.0, 0.75, 0.85)
	elif season == 2:
		_leaves.color = Color(0.92, 0.5, 0.18)
