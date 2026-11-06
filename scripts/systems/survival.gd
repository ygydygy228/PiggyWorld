extends Node
## Режим выживания (хардкор): голод, рассудок, тьма, холод, волки, смерть и возрождение.

const Wolf := preload("res://scripts/animals/wolf.gd")

const HUNGER_RATE := 0.07
const STARVE_DPS := 0.5
const DARK_DELAY := 12.0
const WILD_WOLVES := 3
const MAX_WOLVES := 7

var world = null
var _dark_t: float = 0.0
var _dark_hit: float = 0.0
var _cold_t: float = 0.0
var _wave_t: float = 45.0
var _tick: float = 0.0
var _dead: bool = false
var _dusk_warned: bool = false
var _say_cd: Dictionary = {}


func setup(p_world) -> void:
	world = p_world
	EventBus.day_started.connect(_on_day_started)
	if GameState.hardcore:
		for i in range(WILD_WOLVES):
			_spawn_wild()


func _exit_tree() -> void:
	if EventBus.day_started.is_connected(_on_day_started):
		EventBus.day_started.disconnect(_on_day_started)


func _process(delta: float) -> void:
	if not GameState.hardcore or world == null or world.player == null or _dead:
		return
	var p: Vector2 = world.player.global_position
	var indoors: bool = world.indoors
	var night := TimeSystem.is_night()
	var lit: bool = indoors or world.is_lit(p)

	# голод
	GameState.hunger = maxf(0.0, GameState.hunger - HUNGER_RATE * delta)
	if GameState.hunger <= 0.0:
		_damage(STARVE_DPS * delta)
		_say("starve", "Ты голодаешь! Нужна еда.")
	elif GameState.hunger < 20.0:
		_say("hungry", "Живот урчит. Пора поесть.")

	# рассудок
	var ds := 0.0
	if indoors:
		ds += 0.12
	elif lit:
		ds += 0.04
	if night and not lit:
		ds -= 0.18
	if not indoors and world.region_at(world.pos_to_cell(p)) == "dark":
		ds -= 0.06
	ds -= 0.12 * float(_wolves_near(p, 90.0))
	GameState.sanity = clampf(GameState.sanity + ds * delta, 0.0, 100.0)
	if GameState.sanity <= 0.0:
		_damage(0.4 * delta)
		_say("insane", "Разум помутился...")
	elif GameState.sanity < 30.0:
		_say("shaky", "Тебе мерещатся тени...")

	# тьма
	if night and not lit:
		_dark_t += delta
	else:
		_dark_t = maxf(0.0, _dark_t - delta * 2.0)
	if _dark_t > 4.0:
		_say("dark", "Слишком темно! Найди костёр или фонарь.")
	if _dark_t > DARK_DELAY:
		_dark_hit -= delta
		if _dark_hit <= 0.0:
			_dark_hit = 2.0
			_damage(5.0, "Тьма кусает!", true)

	# холод
	var freezing: bool = TimeSystem.season_index() == 3 and not indoors and not world.is_near_fire(p)
	if freezing:
		_cold_t += delta
	else:
		_cold_t = maxf(0.0, _cold_t - delta * 2.0)
	if _cold_t > 15.0:
		_damage(0.35 * delta * (0.3 if GameState.has_vest else 1.0))
		_say("cold", "Ты мёрзнешь! Согрейся у костра.")

	# волны волков
	if night and not indoors:
		_wave_t -= delta
		if _wave_t <= 0.0:
			_wave_t = randf_range(50.0, 90.0)
			_spawn_wave(p)
	else:
		_wave_t = maxf(_wave_t, 25.0)

	# вечернее предупреждение
	var h := TimeSystem.hour()
	if h == 17 and not _dusk_warned and not indoors:
		_dusk_warned = true
		_say("dusk", "Темнеет. Ночью выходят волки: приготовь костёр.")
	elif h != 17:
		_dusk_warned = false

	if GameState.health <= 0.0:
		_die()
		return
	_tick += delta
	if _tick > 0.2:
		_tick = 0.0
		EventBus.stats_changed.emit()


func _say(key: String, text: String) -> void:
	var now := Time.get_ticks_msec()
	if now - int(_say_cd.get(key, -100000)) < 25000:
		return
	_say_cd[key] = now
	EventBus.message.emit(text)


func _damage(amount: float, msg: String = "", flash: bool = false) -> void:
	GameState.health = maxf(0.0, GameState.health - amount)
	if msg != "":
		EventBus.message.emit(msg)
	if flash:
		EventBus.player_hurt.emit()
		AudioManager.play("hurt", 0.05)


## Урон от монстра. from_pos — откуда ударили (для отбрасывания).
func hit(amount: float, from_pos: Vector2) -> void:
	if _dead or not GameState.hardcore:
		return
	_damage(amount, "", true)
	if world != null and world.player != null:
		world.player.knockback_from(from_pos)


func _wolves_near(p: Vector2, radius: float) -> int:
	var n := 0
	for w in get_tree().get_nodes_in_group("wolves"):
		if (w as Node2D).global_position.distance_to(p) < radius:
			n += 1
	return n


func _spawn_ok(pos: Vector2) -> bool:
	if world.nav == null:
		return false
	var c: Vector2i = world.pos_to_cell(pos)
	return world.in_bounds(c) and world.is_grass(c) and not world.nav.is_point_solid(c) and not world.is_safe(pos)


func _add_wolf(pos: Vector2, mode: String) -> void:
	var w := Wolf.new()
	w.setup(world, pos, mode)
	world.objects_node.add_child(w)


func _spawn_wave(p: Vector2) -> void:
	var existing := get_tree().get_nodes_in_group("wolves").size()
	var n := clampi(1 + floori(TimeSystem.day / 6.0), 1, 4)
	var spawned := 0
	for i in range(n):
		if existing + spawned >= MAX_WOLVES:
			break
		for tries in range(12):
			var pos := p + Vector2.from_angle(randf() * TAU) * randf_range(170.0, 240.0)
			if _spawn_ok(pos):
				_add_wolf(pos, "hunt")
				spawned += 1
				break
	if spawned > 0:
		AudioManager.play("howl", 0.04, 0.9)
		EventBus.message.emit("Слышен вой волков!")


func _spawn_wild() -> void:
	for tries in range(40):
		var size: Vector2i = world.map_size()
		var c := Vector2i(randi_range(10, size.x - 10), randi_range(66, size.y - 8))
		var pos: Vector2 = world.cell_center(c)
		if _spawn_ok(pos):
			_add_wolf(pos, "wild")
			return


func _on_day_started(_day: int) -> void:
	if not GameState.hardcore:
		return
	var wild := 0
	for w in get_tree().get_nodes_in_group("wolves"):
		if w.mode == "wild":
			wild += 1
	if wild < WILD_WOLVES:
		_spawn_wild()


func _die() -> void:
	_dead = true
	EventBus.player_died.emit()


## Возрождение дома: часть вещей и денег потеряна.
func respawn() -> void:
	_dead = false
	GameState.health = 50.0
	GameState.hunger = maxf(GameState.hunger, 50.0)
	GameState.sanity = maxf(GameState.sanity, 50.0)
	GameState.money = GameState.money - int(GameState.money * 0.3)
	for id in GameState.inventory.keys():
		var key := str(id)
		if GameState.TOOLS.has(key) or key.ends_with("_seed"):
			continue
		var n := GameState.count(key)
		GameState.inventory[key] = n - floori(n / 2.0)
	GameState.spear_uses = 0
	GameState.inventory["spear"] = 0
	for w in get_tree().get_nodes_in_group("wolves"):
		if w.mode == "hunt":
			w.queue_free()
	_dark_t = 0.0
	_cold_t = 0.0
	EventBus.money_changed.emit(GameState.money)
	EventBus.inventory_changed.emit()
	EventBus.stats_changed.emit()
