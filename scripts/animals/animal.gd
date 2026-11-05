extends CharacterBody2D
## Домашнее животное: бродит возле дома, ест, спит ночью, даёт продукт (яйцо, молоко, шерсть).

const Fx := preload("res://scripts/fx/fx.gd")

const SPECIES := {
	"cow": {"name": "Корова", "speed": 12.0, "radius": 48.0, "product": "milk", "sound": "moo", "body": 5.0},
	"sheep": {"name": "Овечка", "speed": 12.0, "radius": 48.0, "product": "wool", "sound": "baa", "body": 5.0},
	"chicken": {"name": "Курица", "speed": 16.0, "radius": 40.0, "product": "egg", "sound": "cluck", "body": 3.5},
	"rabbit": {"name": "Кролик", "speed": 26.0, "radius": 60.0, "product": "", "sound": "squeak", "body": 3.5},
	"cat": {"name": "Кошка", "speed": 18.0, "radius": 60.0, "product": "", "sound": "meow", "body": 3.5},
	"dog": {"name": "Собака", "speed": 24.0, "radius": 70.0, "product": "", "sound": "bark", "body": 4.0},
}

static var _frames_cache: Dictionary = {}

var species: String = "cow"
var world = null
var home: Vector2 = Vector2.ZERO
var state: String = "idle"
var product_ready: bool = true
var sprite: AnimatedSprite2D
var _t: float = 2.0
var _target: Vector2 = Vector2.ZERO
var _stuck: float = 0.0
var _voice_t: float = 15.0


func setup(p_species: String, p_home: Vector2, p_world) -> void:
	species = p_species
	home = p_home
	world = p_world
	position = p_home


static func _frames(sp: String) -> SpriteFrames:
	if _frames_cache.has(sp):
		return _frames_cache[sp]
	var sheet: Texture2D = load("res://assets/sprites/animals/%s.png" % sp)
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	var rows := [["idle", 0, 4, 3.0], ["walk", 1, 4, 7.0], ["eat", 2, 4, 4.0], ["sleep", 3, 2, 1.5]]
	for r in rows:
		var anim: String = r[0]
		sf.add_animation(anim)
		sf.set_animation_speed(anim, float(r[3]))
		sf.set_animation_loop(anim, true)
		for i in range(int(r[2])):
			var at := AtlasTexture.new()
			at.atlas = sheet
			at.region = Rect2(i * 32, int(r[1]) * 32, 32, 32)
			sf.add_frame(anim, at)
	_frames_cache[sp] = sf
	return sf


func _ready() -> void:
	add_to_group("animals")
	var def: Dictionary = SPECIES[species]
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = _frames(species)
	sprite.centered = false
	sprite.offset = Vector2(-16, -29)
	add_child(sprite)
	var cs := CollisionShape2D.new()
	var sh := CircleShape2D.new()
	sh.radius = float(def["body"])
	cs.shape = sh
	cs.position = Vector2(0, -3)
	add_child(cs)
	_t = randf_range(0.5, 3.0)
	_voice_t = randf_range(10.0, 35.0)
	sprite.play("idle")
	sprite.frame = randi() % 4


func _physics_process(delta: float) -> void:
	_t -= delta
	_voice_t -= delta
	if _voice_t <= 0.0:
		_voice_t = randf_range(18.0, 45.0)
		_speak()
	match state:
		"wander":
			_wander(delta)
		"sleep":
			velocity = Vector2.ZERO
			if not TimeSystem.is_night():
				_choose()
		_:
			velocity = Vector2.ZERO
			if _t <= 0.0:
				_choose()
	_update_anim()


func _wander(delta: float) -> void:
	var to := _target - position
	if to.length() < 3.0 or _t <= 0.0:
		_go("idle", randf_range(1.5, 4.0))
		return
	var dir := to.normalized()
	if world != null and world.is_blocked(global_position + dir * 8.0):
		_go("idle", 1.0)
		return
	velocity = dir * float(SPECIES[species]["speed"])
	move_and_slide()
	if get_slide_collision_count() > 0:
		_stuck += delta
		if _stuck > 0.6:
			_go("idle", 1.5)
	if absf(velocity.x) > 0.1:
		sprite.flip_h = velocity.x < 0.0


func _choose() -> void:
	_stuck = 0.0
	if TimeSystem.is_night() and randf() < 0.85:
		_go("sleep", 30.0)
		return
	var r := randf()
	if r < 0.5:
		var radius := float(SPECIES[species]["radius"])
		var t := home + Vector2(randf_range(-radius, radius), randf_range(-radius * 0.6, radius * 0.6))
		if world != null and world.is_blocked(t):
			t = home
		_target = t
		_go("wander", 8.0)
	elif r < 0.75:
		_go("eat", randf_range(2.0, 4.0))
	else:
		_go("idle", randf_range(2.0, 5.0))


func _go(new_state: String, seconds: float) -> void:
	state = new_state
	_t = seconds


func _update_anim() -> void:
	var anim := "idle"
	match state:
		"wander":
			anim = "walk"
		"eat":
			anim = "eat"
		"sleep":
			anim = "sleep"
	if sprite.animation != anim:
		sprite.play(anim)


func _speak() -> void:
	if world == null or world.player == null:
		return
	var dist := global_position.distance_to(world.player.global_position)
	if dist < 150.0:
		AudioManager.play(str(SPECIES[species]["sound"]), 0.08, clampf(1.0 - dist / 170.0, 0.15, 1.0))


func refill() -> void:
	product_ready = true


## Игрок гладит животное. Возвращает реакцию свинки.
func interact() -> String:
	var def: Dictionary = SPECIES[species]
	_go("idle", 2.0)
	if world != null and world.player != null:
		sprite.flip_h = world.player.global_position.x < global_position.x
	Fx.burst(get_parent(), position + Vector2(0, -22), Color("#eb4664"), 4, 22.0, 0.9)
	AudioManager.play(str(def["sound"]), 0.05, 0.9)
	var prod := str(def["product"])
	if prod != "" and product_ready:
		product_ready = false
		GameState.add_item(prod, 1)
		EventBus.message.emit("+1 %s" % GameState.item_name(prod))
	elif prod != "":
		EventBus.message.emit("%s: заходи завтра" % def["name"])
	else:
		EventBus.message.emit("Ты погладила: %s" % str(def["name"]).to_lower())
	return "happy"
