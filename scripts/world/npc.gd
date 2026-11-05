extends StaticBody2D
## Житель деревни. Разговор открывает диалог; у лавочницы после диалога — магазин.

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
	EventBus.dialog_requested.emit(str(def["name"]), _lines(def), str(def["action"]))
	return "talk"
