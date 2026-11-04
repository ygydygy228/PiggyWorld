extends CharacterBody2D
## Свинка: движение, анимации, действия (сбор, инструменты).

const PigMeta := preload("res://scripts/art/pig_meta.gd")
const PigFrames := preload("res://scripts/art/pig_frames.gd")
const Fx := preload("res://scripts/fx/fx.gd")

const WALK_SPEED := 56.0
const RUN_SPEED := 96.0
const SLEEP_AFTER := 25.0

var world = null
var camera: Camera2D
var sprite: AnimatedSprite2D
var facing: Vector2 = Vector2.DOWN
var move_input: Vector2 = Vector2.ZERO
var run_held: bool = false
var lock_time: float = 0.0
var lock_anim: String = ""
var idle_time: float = 0.0
var input_enabled: bool = true
var _step_timer: float = 0.0
var _oink_timer: float = 10.0
var _pending_t: float = 0.0
var _pending_target: Vector2 = Vector2.ZERO


func _ready() -> void:
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = PigFrames.build()
	sprite.centered = false
	sprite.offset = Vector2(-PigMeta.FRAME_W / 2.0, -PigMeta.GROUND_Y)
	add_child(sprite)
	var cs := CollisionShape2D.new()
	var sh := CircleShape2D.new()
	sh.radius = 5.0
	cs.shape = sh
	cs.position = Vector2(0, -4)
	add_child(cs)
	camera = Camera2D.new()
	camera.position = Vector2(0, -12)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	add_child(camera)
	camera.make_current()
	sprite.play("idle_down")


func _draw() -> void:
	# мягкая пиксельная тень под свинкой
	var c := Color(0.0, 0.0, 0.0, 0.22)
	draw_rect(Rect2(-6, -3, 12, 1), c)
	draw_rect(Rect2(-9, -2, 18, 2), c)
	draw_rect(Rect2(-6, 0, 12, 1), c)


func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if event.is_action_pressed("act"):
		do_action()
	elif event.is_action_pressed("tool_next"):
		GameState.cycle_tool()
	elif event is InputEventKey:
		var ke := event as InputEventKey
		if ke.pressed and not ke.echo and ke.physical_keycode >= KEY_1 and ke.physical_keycode <= KEY_5:
			GameState.select_tool(ke.physical_keycode - KEY_1)


func _physics_process(delta: float) -> void:
	lock_time = maxf(0.0, lock_time - delta)
	if _pending_t > 0.0:
		_pending_t -= delta
		if _pending_t <= 0.0:
			_finish_tool_use()
	var dir := _read_input()
	if lock_time > 0.0 or not input_enabled:
		dir = Vector2.ZERO
	var running := run_held or Input.is_action_pressed("run")
	var moving := dir.length() > 0.1
	if moving:
		dir = dir.limit_length(1.0)
		facing = _snap_dir(dir)
		velocity = dir * (RUN_SPEED if running else WALK_SPEED)
		idle_time = 0.0
		_oink_timer = 10.0
	else:
		velocity = Vector2.ZERO
		idle_time += delta
		_oink_timer -= delta
		if _oink_timer <= 0.0:
			_oink_timer = randf_range(10.0, 22.0)
			AudioManager.play("oink", 0.1, 0.7)
	_block_water()
	move_and_slide()
	_update_anim(moving, running)
	if moving:
		_footsteps(delta, running)


func _read_input() -> Vector2:
	var kb := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	return kb if kb.length() > 0.1 else move_input


func _snap_dir(v: Vector2) -> Vector2:
	if absf(v.x) > absf(v.y):
		return Vector2(signf(v.x), 0.0)
	return Vector2(0.0, signf(v.y))


func _block_water() -> void:
	if world == null:
		return
	if velocity.x != 0.0 and world.is_blocked(global_position + Vector2(signf(velocity.x) * 5.0, 0.0)):
		velocity.x = 0.0
	if velocity.y != 0.0 and world.is_blocked(global_position + Vector2(0.0, signf(velocity.y) * 4.0)):
		velocity.y = 0.0


func _update_anim(moving: bool, running: bool) -> void:
	var view := "down"
	if facing.y < 0.0:
		view = "up"
	elif facing.y == 0.0:
		view = "side"
	sprite.flip_h = facing.x < 0.0
	var base := "idle"
	if lock_time > 0.0:
		base = lock_anim
	elif moving:
		base = "run" if running else "walk"
	elif idle_time > SLEEP_AFTER:
		base = "sleep"
	var anim := base if base == "sleep" else "%s_%s" % [base, view]
	if sprite.animation != anim:
		sprite.play(anim)


func _footsteps(delta: float, running: bool) -> void:
	_step_timer -= delta
	if _step_timer <= 0.0:
		_step_timer = 0.2 if running else 0.34
		AudioManager.play("step", 0.15, 0.6)
		if running:
			Fx.burst(get_parent(), position + Vector2(0, -1), Color(0.78, 0.7, 0.55, 0.8), 3, 18.0, 0.35)


func start_lock(anim: String, seconds: float) -> void:
	lock_anim = anim
	lock_time = seconds
	idle_time = 0.0


func react(kind: String) -> void:
	match kind:
		"eat":
			start_lock("eat", 1.0)
		"happy":
			start_lock("happy", 0.95)
			AudioManager.play("oink_happy", 0.05, 0.8)
		"sad":
			start_lock("sad", 0.85)


## Кнопка действия: сначала сбор, иначе применить выбранный инструмент.
func do_action() -> void:
	if lock_time > 0.0 or world == null or not input_enabled:
		return
	var target := global_position + facing * 14.0 + Vector2(0, -3)
	var r: String = world.harvest_at(target)
	if r != "none":
		react(r)
		return
	start_lock("interact", 0.4)
	_pending_t = 0.18
	_pending_target = target


func _finish_tool_use() -> void:
	if world == null:
		return
	var r: String = world.use_tool(GameState.current_tool(), _pending_target)
	if r == "sad":
		react("sad")
	elif r == "none":
		EventBus.message.emit("Здесь нечего делать")
