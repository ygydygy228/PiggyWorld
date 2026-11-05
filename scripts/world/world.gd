extends Node2D
## Игровой мир: рельеф на TileMapLayer, объекты, ферма, смена суток/сезонов/погоды.

const WorldObject := preload("res://scripts/world/world_object.gd")
const Player := preload("res://scripts/player/player.gd")
const WeatherFx := preload("res://scripts/fx/weather_fx.gd")
const Fx := preload("res://scripts/fx/fx.gd")
const Animal := preload("res://scripts/animals/animal.gd")
const Npc := preload("res://scripts/world/npc.gd")

const MAP_W := 96
const MAP_H := 72
const TILE := 16
const SEED := 1337

const T_WATER := 0
const T_SAND := 1
const T_GRASS := 2
const T_PATH := 3

const HOUSE_CELL := Vector2i(40, 35)
const SPAWN_CELL := Vector2i(40, 38)
const FARM_RECT := Rect2i(46, 33, 12, 9)
const VILLAGE_RECT := Rect2i(60, 26, 20, 20)
const CAVE_CELL := Vector2i(48, 19)
const LAKE_CENTER := Vector2(52, 52)

## per — сколько дней с поливом нужно на одну стадию роста (всего 3 стадии роста).
const CROPS := {
	"carrot": {"seed": "carrot_seed", "item": "carrot", "per": 1, "max": 2, "fx": Color("#f08a2c")},
	"turnip": {"seed": "turnip_seed", "item": "turnip", "per": 1, "max": 2, "fx": Color("#9a5ab0")},
	"pumpkin": {"seed": "pumpkin_seed", "item": "pumpkin", "per": 2, "max": 1, "fx": Color("#f08a2c")},
}

const ANIMAL_SPOTS := [
	["cow", Vector2i(50, 30)], ["cow", Vector2i(54, 30)], ["sheep", Vector2i(57, 31)], ["sheep", Vector2i(48, 31)],
	["chicken", Vector2i(43, 41)], ["chicken", Vector2i(45, 42)], ["chicken", Vector2i(42, 43)],
	["rabbit", Vector2i(30, 36)], ["rabbit", Vector2i(31, 39)], ["cat", Vector2i(38, 40)], ["dog", Vector2i(63, 44)],
]
const NPC_SPOTS := {"shopkeeper": Vector2i(69, 36), "farmer": Vector2i(61, 37), "granny": Vector2i(70, 40)}

const SEASON_GROUND := [
	{"tint": Color(1.0, 1.0, 1.0), "snow": 0.0},
	{"tint": Color(1.04, 1.07, 0.9), "snow": 0.0},
	{"tint": Color(1.18, 0.95, 0.72), "snow": 0.0},
	{"tint": Color(0.92, 0.97, 1.05), "snow": 0.9},
]
const SEASON_FOLIAGE := [
	{"tint": Color(1.0, 1.0, 1.0), "snow": 0.0},
	{"tint": Color(1.02, 1.06, 0.92), "snow": 0.0},
	{"tint": Color(1.35, 0.85, 0.55), "snow": 0.0},
	{"tint": Color(0.95, 1.0, 1.05), "snow": 0.55},
]

var terrain := PackedByteArray()
var reserved: Dictionary = {}
var occupied: Dictionary = {}
var river_cells: Dictionary = {}
var bridge_cells: Dictionary = {}
var soil: Dictionary = {}
var crops: Dictionary = {}
var crop_nodes: Dictionary = {}
var removed_uids: Dictionary = {}
var animals: Array = []
var rng := RandomNumberGenerator.new()

var tileset: TileSet
var ground_mat: ShaderMaterial
var foliage_mat: ShaderMaterial
var water_layer: TileMapLayer
var sand_layer: TileMapLayer
var grass_layer: TileMapLayer
var path_layer: TileMapLayer
var soil_layer: TileMapLayer
var ground_node: Node2D
var objects_node: Node2D
var light: CanvasModulate
var player: Player
var weather_fx: WeatherFx


func _ready() -> void:
	rng.seed = SEED
	var saved: Dictionary = SaveSystem.pending.get("world", {})
	for u in saved.get("removed", []):
		removed_uids[str(u)] = true
	_make_materials()
	_make_tileset()
	_make_layers()
	_generate_terrain()
	_paint_layers()
	_place_landmarks()
	_scatter_objects()
	_spawn_creatures(saved)
	_restore_farm(saved)
	_spawn_player(saved)
	EventBus.day_started.connect(_on_day_started)
	EventBus.weather_changed.connect(_on_weather_changed)
	_apply_season()
	_on_weather_changed(TimeSystem.weather)
	light.color = TimeSystem.light_color()
	TimeSystem.running = true


func _exit_tree() -> void:
	TimeSystem.running = false
	if EventBus.day_started.is_connected(_on_day_started):
		EventBus.day_started.disconnect(_on_day_started)
	if EventBus.weather_changed.is_connected(_on_weather_changed):
		EventBus.weather_changed.disconnect(_on_weather_changed)


func _process(delta: float) -> void:
	light.color = light.color.lerp(TimeSystem.light_color(), minf(1.0, delta * 2.0))
	AudioManager.set_ambient("ambient_night" if TimeSystem.is_night() else "ambient_day")


# ---------------------------------------------------------------- построение

func _make_materials() -> void:
	var shader: Shader = load("res://assets/shaders/season.gdshader")
	ground_mat = ShaderMaterial.new()
	ground_mat.shader = shader
	foliage_mat = ShaderMaterial.new()
	foliage_mat.shader = shader


func _make_tileset() -> void:
	tileset = TileSet.new()
	tileset.tile_size = Vector2i(TILE, TILE)
	var src := TileSetAtlasSource.new()
	src.texture = load("res://assets/tiles/tileset.png")
	src.texture_region_size = Vector2i(TILE, TILE)
	for y in range(5):
		for x in range(16):
			if y == 0 and x >= 1 and x <= 3:
				continue # кадры анимации воды
			src.create_tile(Vector2i(x, y))
	src.set_tile_animation_frames_count(Vector2i(0, 0), 4)
	src.set_tile_animation_speed(Vector2i(0, 0), 2.5)
	tileset.add_source(src, 0)


func _new_layer(layer_name: String, mat: Material = null) -> TileMapLayer:
	var l := TileMapLayer.new()
	l.name = layer_name
	l.tile_set = tileset
	if mat != null:
		l.material = mat
	add_child(l)
	return l


func _make_layers() -> void:
	water_layer = _new_layer("Water")
	sand_layer = _new_layer("Sand", ground_mat)
	grass_layer = _new_layer("Grass", ground_mat)
	path_layer = _new_layer("Path", ground_mat)
	soil_layer = _new_layer("Soil", ground_mat)
	ground_node = Node2D.new()
	ground_node.name = "Ground"
	add_child(ground_node)
	objects_node = Node2D.new()
	objects_node.name = "Objects"
	objects_node.y_sort_enabled = true
	add_child(objects_node)
	light = CanvasModulate.new()
	add_child(light)


func _idx(c: Vector2i) -> int:
	return c.y * MAP_W + c.x


func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < MAP_W and c.y < MAP_H


func get_t(c: Vector2i) -> int:
	if not in_bounds(c):
		return T_WATER
	return terrain[_idx(c)]


func pos_to_cell(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / TILE), floori(p.y / TILE))


func cell_center(c: Vector2i) -> Vector2:
	return Vector2(c.x * TILE + TILE / 2.0, c.y * TILE + TILE / 2.0)


func is_blocked(p: Vector2) -> bool:
	var c := pos_to_cell(p)
	if not in_bounds(c):
		return true
	return get_t(c) == T_WATER and not bridge_cells.has(c)


func _generate_terrain() -> void:
	terrain.resize(MAP_W * MAP_H)
	var noise := FastNoiseLite.new()
	noise.seed = SEED
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.05
	noise.fractal_octaves = 3
	var center := Vector2(MAP_W * 0.5, MAP_H * 0.5)
	for y in range(MAP_H):
		for x in range(MAP_W):
			var d := Vector2((x - center.x) / (MAP_W * 0.5), (y - center.y) / (MAP_H * 0.5)).length()
			var h := noise.get_noise_2d(x, y) * 0.3 + 0.64 - pow(d, 2.2) * 0.9
			var t := T_GRASS
			if h < 0.12:
				t = T_WATER
			elif h < 0.2:
				t = T_SAND
			if x < 3 or y < 3 or x >= MAP_W - 3 or y >= MAP_H - 3:
				t = T_WATER
			terrain[_idx(Vector2i(x, y))] = t
	# защищённая «ядро»-площадка: дом, ферма, деревня всегда суша
	for rect in [Rect2i(34, 27, 46, 22)]:
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				var c := Vector2i(x, y)
				if get_t(c) != T_GRASS:
					terrain[_idx(c)] = T_GRASS
	# озеро
	for y in range(MAP_H):
		for x in range(MAP_W):
			var dist := Vector2(x, y).distance_to(LAKE_CENTER)
			if dist < 6.0 + noise.get_noise_2d(x * 2.0, y * 2.0) * 2.0:
				terrain[_idx(Vector2i(x, y))] = T_WATER
				river_cells[Vector2i(x, y)] = true
	# речка от озера на запад
	for x in range(14, 47):
		var yc := 52 + int(round(2.0 * sin(x * 0.35)))
		for dy in range(-1, 2):
			var c := Vector2i(x, yc + dy)
			terrain[_idx(c)] = T_WATER
			river_cells[c] = true
	# дорожки
	_carve_path(Vector2i(40, 36), Vector2i(40, 59))
	_carve_path(Vector2i(41, 37), Vector2i(45, 37))
	_carve_path(Vector2i(40, 43), Vector2i(62, 43))
	_carve_path(Vector2i(62, 43), Vector2i(62, 31))
	# резервирование
	_reserve(Rect2i(35, 29, 12, 12))
	_reserve(Rect2i(FARM_RECT.position - Vector2i(1, 1), FARM_RECT.size + Vector2i(2, 2)))
	_reserve(VILLAGE_RECT)
	_reserve(Rect2i(CAVE_CELL - Vector2i(4, 3), Vector2i(9, 6)))
	_reserve(Rect2i(SPAWN_CELL - Vector2i(3, 2), Vector2i(7, 4)))
	_reserve(Rect2i(47, 27, 14, 6))
	_reserve(Rect2i(41, 41, 6, 4))
	_reserve(Rect2i(28, 35, 6, 6))


func _carve_path(a: Vector2i, b: Vector2i) -> void:
	var c := a
	while true:
		var t := get_t(c)
		if t >= T_SAND and t != T_WATER:
			terrain[_idx(c)] = T_PATH
		elif t == T_WATER and river_cells.has(c):
			bridge_cells[c] = true
		reserved[c] = true
		if c == b:
			break
		if c.x != b.x:
			c.x += signi(b.x - c.x)
		else:
			c.y += signi(b.y - c.y)


func _reserve(rect: Rect2i) -> void:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			reserved[Vector2i(x, y)] = true


func _mask(c: Vector2i, level: int) -> int:
	var m := 0
	if get_t(c + Vector2i(0, -1)) < level: m |= 1
	if get_t(c + Vector2i(1, 0)) < level: m |= 2
	if get_t(c + Vector2i(0, 1)) < level: m |= 4
	if get_t(c + Vector2i(-1, 0)) < level: m |= 8
	return m


func _mask_path(c: Vector2i) -> int:
	var m := 0
	if get_t(c + Vector2i(0, -1)) != T_PATH and not bridge_cells.has(c + Vector2i(0, -1)): m |= 1
	if get_t(c + Vector2i(1, 0)) != T_PATH and not bridge_cells.has(c + Vector2i(1, 0)): m |= 2
	if get_t(c + Vector2i(0, 1)) != T_PATH and not bridge_cells.has(c + Vector2i(0, 1)): m |= 4
	if get_t(c + Vector2i(-1, 0)) != T_PATH and not bridge_cells.has(c + Vector2i(-1, 0)): m |= 8
	return m


func _paint_layers() -> void:
	for y in range(MAP_H):
		for x in range(MAP_W):
			var c := Vector2i(x, y)
			var t := get_t(c)
			water_layer.set_cell(c, 0, Vector2i(0, 0))
			if t >= T_SAND:
				sand_layer.set_cell(c, 0, Vector2i(_mask(c, T_SAND), 2))
			if t >= T_GRASS:
				var m := _mask(c, T_GRASS)
				if m == 0:
					grass_layer.set_cell(c, 0, Vector2i(2 + ((x * 7 + y * 13) % 4), 4))
				else:
					grass_layer.set_cell(c, 0, Vector2i(m, 1))
			if t == T_PATH:
				path_layer.set_cell(c, 0, Vector2i(_mask_path(c), 3))


func _spawn(kind: String, cell: Vector2i, uid: String = "", feet: Vector2 = Vector2.ZERO) -> WorldObject:
	if uid == "":
		uid = "%s@%d,%d" % [kind, cell.x, cell.y]
	if removed_uids.has(uid):
		return null
	var def: Dictionary = WorldObject.DEFS[kind]
	var o := WorldObject.new()
	var mat: Material = foliage_mat
	o.setup(kind, cell, mat)
	o.uid = uid
	o.position = feet if feet != Vector2.ZERO else Vector2(cell.x * TILE + TILE / 2.0, cell.y * TILE + TILE - 1)
	var parent: Node = ground_node if def.get("ground", false) else objects_node
	parent.add_child(o)
	o.destroyed.connect(_on_object_destroyed)
	return o


func _place_landmarks() -> void:
	# дом свинки
	_spawn("house", HOUSE_CELL, "house", Vector2(HOUSE_CELL.x * TILE + 8, (HOUSE_CELL.y + 1) * TILE))
	# забор фермы (с проходом слева)
	for x in range(FARM_RECT.position.x, FARM_RECT.end.x):
		_spawn("fence", Vector2i(x, FARM_RECT.position.y))
		_spawn("fence", Vector2i(x, FARM_RECT.end.y - 1))
	for y in range(FARM_RECT.position.y + 1, FARM_RECT.end.y - 1):
		if y != 37 and y != 38:
			_spawn("fence", Vector2i(FARM_RECT.position.x, y))
		_spawn("fence", Vector2i(FARM_RECT.end.x - 1, y))
	# деревня
	var tints := [Color(0.85, 0.95, 1.15), Color(1.1, 1.05, 0.85), Color(0.95, 1.1, 0.95)]
	var cells := [Vector2i(65, 31), Vector2i(73, 34), Vector2i(66, 41)]
	for i in range(cells.size()):
		var h := _spawn("house", cells[i], "village_house_%d" % i, Vector2(cells[i].x * TILE + 8, (cells[i].y + 1) * TILE))
		if h != null:
			h.sprite.modulate = tints[i]
	# вход в пещеру
	_spawn("cave", CAVE_CELL, "cave")
	# мостики
	for c in bridge_cells:
		_spawn("bridge", c, "bridge@%d,%d" % [c.x, c.y])


func _scatter_objects() -> void:
	var forest := FastNoiseLite.new()
	forest.seed = SEED + 1
	forest.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	forest.frequency = 0.07
	var flower_kinds := ["flower_red", "flower_yellow", "flower_blue", "flower_white"]
	for y in range(5, MAP_H - 5):
		for x in range(5, MAP_W - 5):
			var c := Vector2i(x, y)
			var r := rng.randf()
			if get_t(c) != T_GRASS or reserved.has(c) or occupied.has(c):
				continue
			var near_water := false
			for d in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 1), Vector2i(-1, -1)]:
				if get_t(c + d) != T_GRASS:
					near_water = true
			var f := forest.get_noise_2d(x, y)
			var tree_p := 0.38 if f > 0.14 else 0.025
			if r < tree_p and not near_water:
				var kind := "tree_oak"
				var k := rng.randf()
				if x < 34 or y < 24:
					kind = "tree_pine" if k < 0.7 else "tree_oak"
				elif k < 0.35:
					kind = "tree_oak_big"
				_spawn(kind, c)
				_occupy(c, 1)
			elif r < tree_p + 0.014:
				_spawn("rock_big" if (y < 26 and rng.randf() < 0.5) else "rock_small", c)
				_occupy(c, 1)
			elif r < tree_p + 0.014 + 0.02 and not near_water:
				_spawn("bush_berries" if rng.randf() < 0.6 else "bush", c)
				_occupy(c, 1)
			elif r < tree_p + 0.014 + 0.02 + 0.07:
				_spawn(flower_kinds[rng.randi() % flower_kinds.size()], c)
				occupied[c] = true


func _occupy(c: Vector2i, radius: int) -> void:
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			occupied[c + Vector2i(dx, dy)] = true


func _spawn_player(saved: Dictionary) -> void:
	player = Player.new()
	player.world = self
	var pos := cell_center(SPAWN_CELL)
	var pp: Array = saved.get("player", [])
	if pp.size() == 2:
		pos = Vector2(float(pp[0]), float(pp[1]))
	player.position = pos
	objects_node.add_child(player)
	var cam: Camera2D = player.camera
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = MAP_W * TILE
	cam.limit_bottom = MAP_H * TILE
	weather_fx = WeatherFx.new()
	cam.add_child(weather_fx)


# ---------------------------------------------------------------- ферма

func _restore_farm(saved: Dictionary) -> void:
	for s in saved.get("soil", []):
		var c := Vector2i(int(s["x"]), int(s["y"]))
		soil[c] = bool(s["wet"])
		_paint_soil(c)
	for cr in saved.get("crops", []):
		var c := Vector2i(int(cr["x"]), int(cr["y"]))
		var ctype := str(cr.get("type", "carrot"))
		if not CROPS.has(ctype):
			ctype = "carrot"
		var per: int = CROPS[ctype]["per"]
		crops[c] = {"type": ctype, "stage": int(cr["stage"]), "age": int(cr.get("age", int(cr["stage"]) * per)), "watered": bool(cr["watered"])}
		_update_crop_node(c)


func _paint_soil(c: Vector2i) -> void:
	soil_layer.set_cell(c, 0, Vector2i(1 if soil.get(c, false) else 0, 4))


func _update_crop_node(c: Vector2i) -> void:
	var stage := int(crops[c]["stage"])
	var s: Sprite2D = crop_nodes.get(c)
	if s == null:
		s = Sprite2D.new()
		s.centered = false
		s.position = Vector2(c.x * TILE, c.y * TILE)
		ground_node.add_child(s)
		crop_nodes[c] = s
	s.texture = load("res://assets/objects/crop_%s_%d.png" % [crops[c]["type"], clampi(stage, 0, 3)])


func _object_near(p: Vector2, radius: float) -> WorldObject:
	var best: WorldObject = null
	var best_d := radius
	for parent in [objects_node, ground_node]:
		for n in parent.get_children():
			if n is WorldObject:
				var d: float = (n as WorldObject).position.distance_to(p)
				if d < best_d:
					best_d = d
					best = n as WorldObject
	return best


func harvest_at(target: Vector2) -> String:
	var creature = _creature_near(target + Vector2(0, 3), 18.0)
	if creature != null:
		return creature.interact()
	var cell := pos_to_cell(target)
	if crops.has(cell) and int(crops[cell]["stage"]) >= 3:
		var cdef: Dictionary = CROPS[crops[cell]["type"]]
		var amount := 1 + rng.randi() % int(cdef["max"])
		var item := str(cdef["item"])
		GameState.add_item(item, amount)
		EventBus.message.emit("+%d %s" % [amount, GameState.item_name(item)])
		AudioManager.play("pickup")
		Fx.burst(ground_node, cell_center(cell), cdef["fx"], 10, 50.0)
		crop_nodes[cell].queue_free()
		crop_nodes.erase(cell)
		crops.erase(cell)
		return "happy"
	var o := _object_near(target, 14.0)
	if o != null and o.is_in_group("harvestable"):
		var r: String = o.harvest()
		if r != "":
			return r
	if o != null and o.interaction() == "cave":
		EventBus.message.emit("Пещера: вход заперт. Внутрь можно будет попасть в следующем обновлении.")
		AudioManager.play("error")
		return "sad"
	return "none"


func use_tool(tool_id: String, target: Vector2) -> String:
	var cell := pos_to_cell(target)
	match tool_id:
		"axe", "pickaxe":
			var o := _object_near(target, 16.0)
			if o != null and o.is_hittable():
				if o.hit(tool_id):
					return "ok"
				EventBus.message.emit("Нужен другой инструмент")
				AudioManager.play("error")
				return "sad"
			return "none"
		"hoe":
			if get_t(cell) != T_GRASS or soil.has(cell) or _object_near(cell_center(cell), 11.0) != null:
				AudioManager.play("error")
				return "sad"
			soil[cell] = false
			_paint_soil(cell)
			AudioManager.play("plant")
			Fx.burst(ground_node, cell_center(cell), Color("#8a5a3b"), 9, 45.0)
			return "ok"
		"can":
			if not soil.has(cell):
				return "none"
			soil[cell] = true
			_paint_soil(cell)
			if crops.has(cell):
				crops[cell]["watered"] = true
			AudioManager.play("water")
			Fx.burst(ground_node, cell_center(cell), Color("#78bef0"), 10, 35.0)
			return "ok"
		_:
			if tool_id.ends_with("_seed"):
				return _plant(tool_id, cell)
	return "none"


func _on_day_started(_day: int) -> void:
	var raining := TimeSystem.weather == "rain"
	for c in crops:
		var cr: Dictionary = crops[c]
		if raining:
			cr["watered"] = true
		if cr["watered"]:
			cr["age"] = int(cr["age"]) + 1
			var per: int = CROPS[cr["type"]]["per"]
			cr["stage"] = mini(3, int(floor(float(cr["age"]) / per)))
		cr["watered"] = raining
		_update_crop_node(c)
	for c in soil:
		soil[c] = raining
		_paint_soil(c)
	get_tree().call_group("harvestable", "regrow")
	get_tree().call_group("animals", "refill")
	_apply_season()
	EventBus.message.emit("Наступил день %d. %s" % [TimeSystem.day, TimeSystem.season_name()])


func _on_weather_changed(kind: String) -> void:
	if weather_fx != null:
		weather_fx.set_weather(kind, TimeSystem.season_index())


func _apply_season() -> void:
	var s := TimeSystem.season_index()
	var g: Dictionary = SEASON_GROUND[s]
	var f: Dictionary = SEASON_FOLIAGE[s]
	ground_mat.set_shader_parameter("tint", g["tint"])
	ground_mat.set_shader_parameter("snow", g["snow"])
	foliage_mat.set_shader_parameter("tint", f["tint"])
	foliage_mat.set_shader_parameter("snow", f["snow"])
	if weather_fx != null:
		weather_fx.set_weather(TimeSystem.weather, s)


func _on_object_destroyed(obj) -> void:
	removed_uids[obj.uid] = true


func serialize() -> Dictionary:
	var soil_list: Array = []
	for c in soil:
		soil_list.append({"x": c.x, "y": c.y, "wet": soil[c]})
	var crop_list: Array = []
	for c in crops:
		crop_list.append({"x": c.x, "y": c.y, "type": crops[c]["type"], "age": crops[c]["age"], "stage": crops[c]["stage"], "watered": crops[c]["watered"]})
	return {
		"removed": removed_uids.keys(),
		"soil": soil_list,
		"crops": crop_list,
		"animals_ready": animals.map(func(a) -> bool: return a.product_ready),
		"player": [player.position.x, player.position.y],
	}


# ---------------------------------------------------------------- существа

func _spawn_creatures(saved: Dictionary) -> void:
	for spot in ANIMAL_SPOTS:
		var a := Animal.new()
		a.setup(str(spot[0]), cell_center(spot[1]), self)
		objects_node.add_child(a)
		animals.append(a)
	var ready_list: Array = saved.get("animals_ready", [])
	for i in range(mini(ready_list.size(), animals.size())):
		animals[i].product_ready = bool(ready_list[i])
	for npc_id in NPC_SPOTS:
		var n := Npc.new()
		n.setup(str(npc_id), cell_center(NPC_SPOTS[npc_id]))
		objects_node.add_child(n)


func _creature_near(p: Vector2, radius: float):
	var best = null
	var best_d := radius
	for group in ["animals", "npcs"]:
		for n in get_tree().get_nodes_in_group(group):
			var d: float = (n as Node2D).global_position.distance_to(p)
			if d < best_d:
				best_d = d
				best = n
	return best


func _plant(tool_id: String, cell: Vector2i) -> String:
	var crop_type := ""
	for k in CROPS:
		if CROPS[k]["seed"] == tool_id:
			crop_type = str(k)
	if crop_type == "" or not soil.has(cell) or crops.has(cell):
		AudioManager.play("error")
		return "sad"
	if not GameState.remove_item(tool_id):
		EventBus.message.emit("Семена закончились")
		AudioManager.play("error")
		return "sad"
	crops[cell] = {"type": crop_type, "stage": 0, "age": 0, "watered": bool(soil[cell])}
	_update_crop_node(cell)
	AudioManager.play("plant")
	return "ok"
