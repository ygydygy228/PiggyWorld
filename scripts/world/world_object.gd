extends Node2D
## Объект мира: дерево, камень, куст, цветок, здание, забор. Свойства — в таблице DEFS.

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
	"house": {"tex": "house", "col": Vector2(46, 20)},
	"fence": {"tex": "fence", "col": Vector2(14, 6)},
	"cave": {"tex": "cave", "col": Vector2(44, 14), "interact": "cave"},
	"bridge": {"tex": "bridge", "ground": true},
}

var kind: String = ""
var uid: String = ""
var cell: Vector2i = Vector2i.ZERO
var hp: int = 0
var sprite: Sprite2D
var body: StaticBody2D


func setup(p_kind: String, p_cell: Vector2i, mat: Material) -> void:
	kind = p_kind
	cell = p_cell
	var d: Dictionary = DEFS[kind]
	hp = int(d.get("hp", 0))
	sprite = Sprite2D.new()
	sprite.centered = false
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


func _set_texture(tex_name: String) -> void:
	var tex: Texture2D = load("res://assets/objects/%s.png" % tex_name)
	sprite.texture = tex
	if kind == "bridge":
		sprite.offset = Vector2(-8, -15)
	else:
		sprite.offset = Vector2(-tex.get_width() / 2.0, -tex.get_height() + 2.0)


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
