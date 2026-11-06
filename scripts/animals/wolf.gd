extends CharacterBody2D
## Волк (режим выживания): ночью охотится на свинку, днём уходит. Боится огня и деревни.

const Fx := preload("res://scripts/fx/fx.gd")

const SPEED := 62.0

var world = null
var mode: String = "hunt"
var hp: int = 4
var sprite: AnimatedSprite2D
var _home: Vector2 = Vector2.ZERO
var _bite_cd: float = 1.0
var _kb: Vector2 = Vector2.ZERO
var _flee_t: float = 0.0
var _wander_t: float = 0.0
var _wander_dir: Vector2 = Vector2.ZERO
var _dying: bool = false


func setup(p_world, pos: Vector2, p_mode: String) -> void:
	world = p_world
	position = pos
	mode = p_mode
	_home = pos


static func _frames() -> SpriteFrames:
	var sheet: Texture2D = load("res://assets/sprites/animals/wolf.png")
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	var rows := [["idle", 0, 4.0], ["walk", 1, 9.0], ["attack", 2, 10.0]]
	for r in rows:
		var anim: String = r[0]
		sf.add_animation(anim)
		sf.set_animation_speed(anim, float(r[2]))
		sf.set_animation_loop(anim, true)
		for i in range(4):
			var at := AtlasTexture.new()
			at.atlas = sheet
			at.region = Rect2(i * 32, int(r[1]) * 32, 32, 32)
			sf.add_frame(anim, at)
	return sf


func _ready() -> void:
	add_to_group("wolves")
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = _frames()
	sprite.centered = false
	sprite.offset = Vector2(-16, -29)
	add_child(sprite)
	sprite.play("idle")
	var cs := CollisionShape2D.new()
	var sh := CircleShape2D.new()
	sh.radius = 4.5
	cs.shape = sh
	cs.position = Vector2(0, -3)
	add_child(cs)
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.6)


func _physics_process(delta: float) -> void:
	if world == null or world.player == null or _dying:
		return
	_bite_cd -= delta
	if _kb.length() > 5.0:
		velocity = _kb
		move_and_slide()
		_kb = _kb.move_toward(Vector2.ZERO, 420.0 * delta)
		_anim("walk")
		return
	var p: Vector2 = world.player.global_position
	var to := p - global_position
	var dist := to.length()
	var away := -to.normalized() if dist > 0.01 else Vector2.RIGHT
	var daytime := not TimeSystem.is_night()
	var aggro := 260.0 if mode == "hunt" else 110.0
	var dir := Vector2.ZERO
	var state := "idle"
	if mode == "hunt" and daytime:
		dir = away
		state = "walk"
		_flee_t += delta
		if _flee_t > 4.0:
			_vanish()
			return
	elif world.indoors:
		dir = _wander(delta)
	elif world.is_lit(global_position):
		dir = away
	elif dist < aggro:
		if dist < 14.0:
			state = "attack"
			if _bite_cd <= 0.0:
				_bite_cd = 1.3
				AudioManager.play("bite", 0.05)
				world.survival.hit(10.0, global_position)
		else:
			dir = to.normalized()
	elif mode == "wild" and global_position.distance_to(_home) > 24.0:
		dir = (_home - global_position).normalized()
	else:
		dir = _wander(delta)
	if dir != Vector2.ZERO:
		var nxt := global_position + dir * 10.0
		if world.is_safe(nxt) or world.is_blocked(nxt) or (world.is_lit(nxt) and not world.is_lit(global_position)):
			dir = Vector2.ZERO
		elif state != "attack":
			state = "walk"
	velocity = dir * SPEED
	if dir != Vector2.ZERO:
		move_and_slide()
		sprite.flip_h = dir.x < 0.0
	elif state == "walk":
		state = "idle"
	_anim(state)


func _wander(delta: float) -> Vector2:
	_wander_t -= delta
	if _wander_t <= 0.0:
		_wander_t = randf_range(1.5, 4.0)
		_wander_dir = Vector2.from_angle(randf() * TAU) if randf() < 0.6 else Vector2.ZERO
	return _wander_dir


func _anim(anim: String) -> void:
	if sprite.animation != anim:
		sprite.play(anim)


func take_hit(dmg: int, from_pos: Vector2) -> void:
	if _dying:
		return
	hp -= dmg
	_kb = (global_position - from_pos).normalized() * 150.0
	AudioManager.play("hurt", 0.1, 0.8)
	Fx.burst(get_parent(), position + Vector2(0, -12), Color("#d9605a"), 6)
	sprite.modulate = Color(1.0, 0.4, 0.4)
	create_tween().tween_property(sprite, "modulate", Color.WHITE, 0.25)
	if hp <= 0:
		_die()


func _die() -> void:
	_dying = true
	collision_layer = 0
	collision_mask = 0
	var n := 1 + randi() % 2
	GameState.add_item("meat", n)
	EventBus.message.emit("+%d %s" % [n, GameState.item_name("meat")])
	AudioManager.play("pickup")
	Fx.burst(get_parent(), position + Vector2(0, -10), Color("#8a8f99"), 14, 70.0, 0.8)
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.3)
	t.tween_callback(queue_free)


func _vanish() -> void:
	_dying = true
	collision_layer = 0
	collision_mask = 0
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.6)
	t.tween_callback(queue_free)
