extends StaticBody2D
## Житель деревни. Разговор открывает диалог; у лавочницы после диалога - магазин.

const DEFS := {
	"shopkeeper": {
		"name": "Мила, лавочница", "action": "shop",
		"lines": ["Привет, свинка! Добро пожаловать в мою лавку.", "Я покупаю урожай, ягоды, яйца, молоко и шерсть.", "А ещё у меня есть семена. Посмотришь?"],
	},
	"farmer": {
		"name": "Борис, фермер", "action": "",
		"lines": ["Доброе утро, малышка! Видела мои грядки? Любимое дело.", "Совет: морковь и репа растут день за днём, если их поливать. Тыква не торопится: ей нужно два дня на стадию.", "@weather"],
	},
	"granny": {
		"name": "Агата, бабушка", "action": "",
		"lines": ["Ох, свинка... Гладь животных каждый день: курочки несут яйца, а коровки и овечки делятся молоком и шерстью.", "Говорят, на севере за лесом есть пещера. Вход заперт, но однажды его откроют.", "Береги себя ночью: всем нужно спать, даже свинкам."],
	},
}

var npc_id: String = "shopkeeper"
var sprite: AnimatedSprite2D
var _talk_t: float = 0.0
var _greet_cd: float = randf_range(3.0, 9.0)


func setup(id: String, pos: Vector2) -> void:
	npc_id = id
	position = pos


func _ready() -> void:
	add_to_group("npcs")
	var sheet: Texture2D = load("res://assets/sprites/npc/%s.png" % npc_id)
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	sf.add_animation("idle")
	sf.set_animation_speed("idle", 1.4)
	sf.set_animation_loop("idle", true)
	sf.add_animation("talk")
	sf.set_animation_speed("talk", 6.0)
	sf.set_animation_loop("talk", true)
	for i in [0, 1]:
		sf.add_frame("idle", _frame(sheet, i))
	for i in [2, 1]:
		sf.add_frame("talk", _frame(sheet, i))
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = sf
	sprite.centered = false
	sprite.offset = Vector2(-12, -31)
	add_child(sprite)
	sprite.play("idle")
	sprite.frame = randi() % 2
	var cs := CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = Vector2(10, 6)
	cs.shape = sh
	cs.position = Vector2(0, -3)
	add_child(cs)


func _frame(sheet: Texture2D, i: int) -> AtlasTexture:
	var at := AtlasTexture.new()
	at.atlas = sheet
	at.region = Rect2(i * 24, 0, 24, 32)
	return at


func _draw() -> void:
	var c := Color(0.0, 0.0, 0.0, 0.22)
	draw_rect(Rect2(-5, -3, 10, 1), c)
	draw_rect(Rect2(-7, -2, 14, 2), c)
	draw_rect(Rect2(-5, 0, 10, 1), c)


func _process(delta: float) -> void:
	if _talk_t > 0.0:
		_talk_t -= delta
		if _talk_t <= 0.0:
			sprite.play("idle")
	_greet_cd -= delta
	if _greet_cd <= 0.0:
		_greet_cd = 1.0
		var p := get_tree().get_first_node_in_group("player")
		if p != null and global_position.distance_to((p as Node2D).global_position) < 36.0:
			_greet_cd = randf_range(25.0, 45.0)
			_greet(p as Node2D)


func _greet(p: Node2D) -> void:
	if _talk_t > 0.0:
		return
	sprite.flip_h = p.global_position.x < global_position.x
	sprite.play("talk")
	_talk_t = 1.6
	AudioManager.play("ui_click", 0.35, 0.4)
	var b := Label.new()
	b.text = "!"
	b.add_theme_color_override("font_color", Color("#ffd26a"))
	b.add_theme_font_size_override("font_size", 12)
	b.position = Vector2(-3, -46)
	b.z_index = 50
	add_child(b)
	var rise := create_tween()
	rise.tween_property(b, "position:y", -58.0, 0.9)
	var fade := create_tween()
	fade.tween_interval(0.35)
	fade.tween_property(b, "modulate:a", 0.0, 0.55)
	fade.tween_callback(b.queue_free)


func _lines(def: Dictionary) -> Array:
	var out: Array = []
	for l in def["lines"]:
		if l == "@weather":
			match TimeSystem.weather:
				"rain":
					out.append("Сегодня дождь: грядки польются сами, лейка отдыхает.")
				"snow":
					out.append("Снег пошёл! Зимой на грядках скучно, зато красиво.")
				_:
					out.append("Погода хорошая. Самое время поработать на ферме!")
		else:
			out.append(l)
	return out


func interact() -> String:
	var def: Dictionary = DEFS[npc_id]
	sprite.play("talk")
	_talk_t = 2.5
	AudioManager.play("ui_click", 0.05, 0.7)
	var hearts := GameState.add_heart(npc_id)
	var lines := _lines(def)
	var action := str(def["action"])
	# лавка работает днём: ночью Мила только извиняется
	if action == "shop" and (TimeSystem.time_of_day < 0.29 or TimeSystem.time_of_day > 0.84):
		action = ""
		lines = ["Ой, уже поздно - лавка закрыта.", "Приходи днём, с семи утра. Я всегда рада тебя видеть!"]
	elif action == "shop" and hearts >= 3:
		lines.append("Кстати, для друзей у меня всегда есть скидка... шучу! Но заходи чаще.")
	EventBus.dialog_requested.emit(str(def["name"]), lines, action, hearts)
	return "talk"
