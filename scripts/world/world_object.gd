extends Node2D
## Объект мира: дерево, камень, куст, цветок, здание, забор. Свойства - в таблице DEFS.

signal destroyed(obj: Node2D)

const Fx := preload("res://scripts/fx/fx.gd")

const DEFS := {
	"tree_oak": {"tex": "tree_oak", "hp": 4, "tool": "axe", "drop": "wood", "n": 3, "col": Vector2(10, 6), "fx": Color("#5aa84e"), "season": true},
	"tree_oak_big": {"tex": "tree_oak_big", "hp": 5, "tool": "axe", "drop": "wood", "n": 4, "col": Vector2(12, 6), "fx": Color("#7fcb68"), "season": true},
	"tree_pine": {"tex": "tree_pine", "hp": 4, "tool": "axe", "drop": "wood", "n": 3, "col": Vector2(8, 6), "fx": Color("#2f7a4a"), "season": true},
	"rock_small": {"tex": "rock_small", "hp": 3, "tool": "pickaxe", "drop": "stone", "n": 2, "col": Vector2(16, 8), "fx": Color("#a9b2b5")},
	"rock_big": {"tex": "rock_big", "hp": 5, "tool": "pickaxe", "drop": "stone", "n": 4, "col": Vector2(22, 10), "fx": Color("#a9b2b5")},
	"bush": {"tex": "bush", "col": Vector2(18, 8), "harvest": true, "season": true, "fx": Color("#4f9e4a")},
	"bush_berries": {"tex": "bush_berries", "col": Vector2(18, 8), "harvest": true, "season": true, "fx": Color("#d63a5a")},
	"flower_red": {"tex": "flower_red", "harvest": true, "ground": true, "season": true},
	"flower_yellow": {"tex": "flower_yellow", "harvest": true, "ground": true, "season": true},
	"flower_blue": {"tex": "flower_blue", "harvest": true, "ground": true, "season": true},
	"flower_white": {"tex": "flower_white", "harvest": true, "ground": true, "season": true},
	"house": {"tex": "house", "col": Vector2(46, 20), "interact": "house"},
	"fence": {"tex": "fence", "col": Vector2(14, 6)},
	"cave": {"tex": "cave", "col": Vector2(44, 14), "interact": "cave"},
	"bridge": {"tex": "bridge", "ground": true},
	"bed": {"tex": "bed", "col": Vector2(38, 16), "interact": "bed"},
	"room_table": {"tex": "table", "col": Vector2(28, 10)},
	"room_shelf": {"tex": "bookshelf", "col": Vector2(26, 8)},
	"clock": {"tex": "clock", "ground": true},
	"armchair": {"tex": "armchair", "hp": 2, "tool": "axe", "drop": "wood", "n": 2, "col": Vector2(18, 8), "fx": Color("#c8453a")},
	"bookshelf": {"tex": "bookshelf", "hp": 2, "tool": "axe", "drop": "wood", "n": 3, "col": Vector2(26, 8), "fx": Color("#a9754a")},
	"plant_pot": {"tex": "plant_pot", "hp": 1, "tool": "axe", "drop": "flower", "n": 2, "col": Vector2(8, 6), "fx": Color("#4f9e4a")},
	"fence_built": {"tex": "fence", "hp": 2, "tool": "axe", "drop": "wood", "n": 1, "col": Vector2(14, 6), "fx": Color("#c79566")},
	"bench": {"tex": "bench", "hp": 2, "tool": "axe", "drop": "wood", "n": 2, "col": Vector2(28, 8), "fx": Color("#c79566")},
	"lamp": {"tex": "lamp", "hp": 2, "tool": "axe", "drop": "wood", "n": 1, "col": Vector2(6, 5), "fx": Color("#5b6272"), "light": true, "radius": 56.0},
	"campfire": {"tex": "campfire", "frames": 4, "hp": 2, "tool": "axe", "drop": "wood", "n": 1, "col": Vector2(10, 6), "fx": Color("#e8803a"), "light": true, "fire": true, "radius": 72.0, "interact": "campfire"},
	"scarecrow": {"tex": "scarecrow", "hp": 2, "tool": "axe", "drop": "wood", "n": 2, "col": Vector2(8, 5), "fx": Color("#e8c868")},
}

var kind: String = ""
var uid: String = ""
var cell: Vector2i = Vector2i.ZERO
var hp: int = 0
var sprite: Sprite2D
var body: StaticBody2D
var light: PointLight2D
var fuel: float = 0.0
var light_radius: float = 0.0


func setup(p_kind: String, p_cell: Vector2i, mat: Material) -> void:
	kind = p_kind
	cell = p_cell
	var d: Dictionary = DEFS[kind]
	hp = int(d.get("hp", 0))
	sprite = Sprite2D.new()
	sprite.centered = false
	sprite.hframes = int(d.get("frames", 1))
	_set_texture(str(d["tex"]))
	if d.get("season", false) and mat != null:
		sprite.material = mat
	add_child(sprite)
	var col: Vector2 = d.get("col", Vector2.ZERO)
	if col != Vector2.ZERO:
		body = StaticBody2D.new()
		var cs := CollisionShape2D.new()
		var sh := RectangleShape2D.new()
		sh.size = col
		cs.shape = sh
		cs.position = Vector2(0, -col.y / 2.0)
		body.add_child(cs)
		add_child(body)
	if d.get("harvest", false):
		add_to_group("harvestable")
	light_radius = float(d.get("radius", 0.0))
	if d.get("light", false):
		_make_light()
		add_to_group("lights")
	if d.get("fire", false):
		fuel = 240.0
		add_to_group("fires")
		add_to_group("campfires")
		light.color = Color(1.0, 0.7, 0.35)
		light.texture_scale = 2.2
		light.position = Vector2(0, -10)
	set_process(light != null)


func _make_light() -> void:
	light = PointLight2D.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 128
	tex.height = 128
	light.texture = tex
	light.color = Color(1.0, 0.85, 0.55)
	light.energy = 0.0
	light.texture_scale = 1.5
	light.position = Vector2(0, -30)
	add_child(light)


func lit_now() -> bool:
	if kind == "campfire":
		return fuel > 0.0
	return kind == "lamp"


func add_fuel(seconds: float) -> void:
	fuel = minf(fuel + seconds, 600.0)


func _process(delta: float) -> void:
	if light == null:
		return
	if kind == "campfire":
		fuel = maxf(0.0, fuel - delta)
		var on := fuel > 0.0
		var t_ms := float(Time.get_ticks_msec())
		sprite.frame = (int(t_ms / 130.0) % 3) if on else 3
		var target := (1.3 + 0.15 * sin(t_ms / 90.0)) if on else 0.0
		light.energy = lerpf(light.energy, target, minf(1.0, delta * 6.0))
	else:
		var dark := 1.0 - clampf(TimeSystem.light_color().get_luminance(), 0.0, 1.0)
		light.energy = lerpf(light.energy, dark * 1.6, minf(1.0, delta * 3.0))


func _set_texture(tex_name: String) -> void:
	var texture_path := "res://assets/objects/%s.png" % tex_name
	var tex: Texture2D
	if ResourceLoader.exists(texture_path):
		tex = load(texture_path)
	else:
		tex = _make_fallback_texture(tex_name)
	sprite.texture = tex
	if kind == "bridge":
		sprite.offset = Vector2(-8, -15)
	else:
		sprite.offset = Vector2(-(tex.get_width() / float(sprite.hframes)) / 2.0, -tex.get_height() + 2.0)



func _make_fallback_texture(tex_name: String) -> Texture2D:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	match tex_name:
		"bed":
			img.fill_rect(Rect2i(3, 12, 26, 16), Color("#684333"))
			img.fill_rect(Rect2i(5, 8, 22, 15), Color("#d8c7a8"))
			img.fill_rect(Rect2i(5, 8, 8, 7), Color("#f1e7d5"))
			img.fill_rect(Rect2i(5, 22, 22, 5), Color("#a94e5c"))
			img.fill_rect(Rect2i(3, 27, 4, 4), Color("#50352b"))
			img.fill_rect(Rect2i(25, 27, 4, 4), Color("#50352b"))
		"table":
			img.fill_rect(Rect2i(3, 9, 26, 5), Color("#a66b3f"))
			img.fill_rect(Rect2i(6, 14, 4, 15), Color("#70452f"))
			img.fill_rect(Rect2i(22, 14, 4, 15), Color("#70452f"))
			img.fill_rect(Rect2i(7, 6, 18, 3), Color("#c48a50"))
		"bookshelf":
			img.fill_rect(Rect2i(4, 2, 24, 29), Color("#70452f"))
			img.fill_rect(Rect2i(7, 5, 18, 23), Color("#bd8b58"))
			for y in [11, 19, 26]:
				img.fill_rect(Rect2i(7, y, 18, 2), Color("#70452f"))
			for x in [9, 14, 20, 24]:
				img.fill_rect(Rect2i(x, 6, 3, 5), Color("#477b69"))
				img.fill_rect(Rect2i(x, 13, 3, 5), Color("#b95d52"))
				img.fill_rect(Rect2i(x, 21, 3, 4), Color("#d5b45e"))
		"clock":
			img.fill_rect(Rect2i(14, 2, 4, 5), Color("#70452f"))
			img.fill_rect(Rect2i(8, 6, 16, 23), Color("#9a603b"))
			img.fill_rect(Rect2i(10, 8, 12, 15), Color("#f0dca6"))
			img.fill_rect(Rect2i(15, 11, 2, 6), Color("#554338"))
			img.fill_rect(Rect2i(15, 15, 5, 2), Color("#554338"))
			img.fill_rect(Rect2i(12, 29, 8, 2), Color("#70452f"))
		_:
			img.fill_rect(Rect2i(4, 8, 24, 18), Color("#8c6b50"))
			img.fill_rect(Rect2i(7, 4, 18, 5), Color("#c69a63"))
	return ImageTexture.create_from_image(img)


func interaction() -> String:
	return str(DEFS[kind].get("interact", ""))


func is_hittable() -> bool:
	return DEFS[kind].has("tool") and hp > 0


func hit(tool_id: String) -> bool:
	var d: Dictionary = DEFS[kind]
	if str(d.get("tool", "")) != tool_id or hp <= 0:
		return false
	hp -= 1
	AudioManager.play("chop" if tool_id == "axe" else "mine")
	Fx.burst(get_parent(), position + Vector2(0, -14), d.get("fx", Color.WHITE), 7)
	_shake()
	if hp <= 0:
		_break(d)
	return true


func _shake() -> void:
	var t := create_tween()
	t.tween_property(sprite, "position:x", 2.0, 0.04)
	t.tween_property(sprite, "position:x", -2.0, 0.06)
	t.tween_property(sprite, "position:x", 0.0, 0.04)


func _break(d: Dictionary) -> void:
	var n := int(d.get("n", 1))
	var drop := str(d["drop"])
	GameState.add_item(drop, n)
	EventBus.message.emit("+%d %s" % [n, GameState.item_name(drop)])
	AudioManager.play("pickup")
	Fx.burst(get_parent(), position + Vector2(0, -10), d.get("fx", Color.WHITE), 18, 75.0, 0.8)
	if body != null:
		body.queue_free()
		body = null
	remove_from_group("harvestable")
	destroyed.emit(self)
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.3)
	t.tween_callback(queue_free)


## Сбор мордочкой. Возвращает реакцию свинки или "".
func harvest() -> String:
	if kind == "bush_berries":
		kind = "bush"
		_set_texture("bush")
		GameState.add_item("berries", 2)
		EventBus.message.emit("+2 %s" % GameState.item_name("berries"))
		Fx.burst(get_parent(), position + Vector2(0, -10), Color("#d63a5a"), 8)
		return "eat"
	if kind.begins_with("flower_"):
		GameState.add_item("flower", 1)
		EventBus.message.emit("+1 %s" % GameState.item_name("flower"))
		AudioManager.play("pickup")
		destroyed.emit(self)
		queue_free()
		return "happy"
	return ""


func regrow() -> void:
	if kind == "bush" and randf() < 0.5:
		kind = "bush_berries"
		_set_texture("bush_berries")
