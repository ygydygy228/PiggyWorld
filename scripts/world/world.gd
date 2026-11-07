extends Node2D
## Игровой мир: рельеф на TileMapLayer, объекты, ферма, смена суток/сезонов/погоды.

const WorldObject := preload("res://scripts/world/world_object.gd")
const Player := preload("res://scripts/player/player.gd")
const WeatherFx := preload("res://scripts/fx/weather_fx.gd")
const Fx := preload("res://scripts/fx/fx.gd")
const Animal := preload("res://scripts/animals/animal.gd")
const Npc := preload("res://scripts/world/npc.gd")
const Buildings := preload("res://scripts/world/buildings.gd")
const Survival := preload("res://scripts/systems/survival.gd")
const Critters := preload("res://scripts/fx/critters.gd")
const SoilRules := preload("res://scripts/world/soil_rules.gd")

const MAP_W := 176
const MAP_H := 132
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

## per - сколько дней с поливом нужно на одну стадию роста (всего 3 стадии роста).
const CROPS := {
	"carrot": {"seed": "carrot_seed", "item": "carrot", "per": 1, "max": 2, "stages": 3, "fx": Color("#f08a2c")},
	"turnip": {"seed": "turnip_seed", "item": "turnip", "per": 1, "max": 2, "stages": 3, "fx": Color("#9a5ab0")},
	"pumpkin": {"seed": "pumpkin_seed", "item": "pumpkin", "per": 2, "max": 1, "stages": 3, "fx": Color("#f08a2c")},
	"potato": {"seed": "potato_seed", "item": "potato", "per": 2, "max": 3, "stages": 4, "fx": Color("#c49a64")},
}

const ANIMAL_SPOTS := [
	["cow", Vector2i(50, 30)], ["cow", Vector2i(54, 30)], ["sheep", Vector2i(57, 31)], ["sheep", Vector2i(48, 31)],
	["chicken", Vector2i(43, 41)], ["chicken", Vector2i(45, 42)], ["chicken", Vector2i(42, 43)],
	["rabbit", Vector2i(30, 36)], ["rabbit", Vector2i(31, 39)], ["cat", Vector2i(38, 40)], ["dog", Vector2i(63, 44)],
]
const NPC_HOMES := {"shopkeeper": Vector2i(65, 31), "granny": Vector2i(73, 34), "farmer": Vector2i(66, 41)}

const ROOM_ORIGIN := Vector2(4096, 0)
const CAVE_ROOM_ORIGIN := Vector2(4096, 320)
const ROOM_W := 288
const ROOM_H := 176
const HOUSE_DOOR_OUT := Vector2(648, 590)

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
var soil_fertility: Dictionary = {}
var soil_last_crop: Dictionary = {}
var crops: Dictionary = {}
var crop_nodes: Dictionary = {}
var removed_uids: Dictionary = {}
var animals: Array = []
var built: Dictionary = {}
var indoors: bool = false
var in_cave: bool = false
var cave_looted: bool = false
var survival: Survival
var nav: AStarGrid2D
var _transitioning: bool = false
var placing: String = ""
var ghost: Sprite2D
var rng := RandomNumberGenerator.new()

var tileset: TileSet
var world_seed: int = SEED
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
	var saved: Dictionary = SaveSystem.pending.get("world", {})
	# Новый мир каждый раз новый; в сохранении живёт его сид.
	world_seed = int(saved.get("seed", 0))
	cave_looted = bool(saved.get("cave_looted", false))
	if world_seed == 0:
		world_seed = randi()
	rng.seed = world_seed
	for u in saved.get("removed", []):
		removed_uids[str(u)] = true
	_make_materials()
	_make_tileset()
	_make_layers()
	_generate_terrain()
	_paint_layers()
	_place_landmarks()
	_scatter_objects()
	_restore_built(saved)
	_build_nav()
	_spawn_creatures(saved)
	_restore_farm(saved)
	_build_room()
	_build_cave_room()
	_spawn_player(saved)
	var critters := Critters.new()
	critters.setup(player)
	add_child(critters)
	survival = Survival.new()
	survival.setup(self)
	add_child(survival)
	EventBus.day_started.connect(_on_day_started)
	EventBus.weather_changed.connect(_on_weather_changed)
	EventBus.placement_cancel_requested.connect(cancel_placement)
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
	if EventBus.placement_cancel_requested.is_connected(cancel_placement):
		EventBus.placement_cancel_requested.disconnect(cancel_placement)


func _process(delta: float) -> void:
	var target := TimeSystem.light_color()
	if indoors:
		target = target.lerp(Color(1.0, 0.95, 0.86), 0.8)
	light.color = light.color.lerp(target, minf(1.0, delta * 2.0))
	_update_ghost()
	if indoors:
		AudioManager.set_ambient("")
		if not _transitioning and player.position.y > _room_origin().y + ROOM_H - 6.0:
			if in_cave:
				exit_cave()
			else:
				exit_house()
	else:
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
	if indoors:
		return false
	var c := pos_to_cell(p)
	if not in_bounds(c):
		return true
	return get_t(c) == T_WATER and not bridge_cells.has(c)


func _generate_terrain() -> void:
	terrain.resize(MAP_W * MAP_H)
	var noise := FastNoiseLite.new()
	noise.seed = world_seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.05
	noise.fractal_octaves = 3
	# Остров растёт вокруг фермы, а не вокруг геометрического центра карты:
	# за фермой на восток и юг остаётся дикая часть, края уходят под воду.
	var center := Vector2(56, 46)
	var span := Vector2(maxf(center.x, MAP_W - center.x), maxf(center.y, MAP_H - center.y)) * 0.9
	for y in range(MAP_H):
		for x in range(MAP_W):
			var d := Vector2((x - center.x) / span.x, (y - center.y) / span.y).length()
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
	for rect in [Rect2i(34, 27, 58, 32)]:
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
	forest.seed = world_seed + 1
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
			var region := region_at(c)
			var f := forest.get_noise_2d(x, y)
			var tree_p := 0.38 if f > 0.14 else 0.025
			var rock_p := 0.014
			var bush_p := 0.02
			var flower_p := 0.07
			if region == "dark":
				tree_p = 0.34 if f > -0.05 else 0.12
				rock_p = 0.012
				bush_p = 0.035
				flower_p = 0.03
			elif region == "rocky":
				tree_p = 0.02
				rock_p = 0.08
				bush_p = 0.012
				flower_p = 0.01
			if r < tree_p and not near_water:
				var kind := "tree_oak"
				var k := rng.randf()
				if region == "dark":
					kind = "tree_pine" if k < 0.65 else "tree_oak_big"
				elif x < 34 or y < 24:
					kind = "tree_pine" if k < 0.7 else "tree_oak"
				elif k < 0.35:
					kind = "tree_oak_big"
				_spawn(kind, c)
				_occupy(c, 1)
			elif r < tree_p + rock_p:
				var big := region == "rocky" or y < 26
				_spawn("rock_big" if (big and rng.randf() < 0.5) else "rock_small", c)
				_occupy(c, 1)
			elif r < tree_p + rock_p + bush_p and not near_water:
				_spawn("bush_berries" if rng.randf() < 0.6 else "bush", c)
				_occupy(c, 1)
			elif r < tree_p + rock_p + bush_p + flower_p:
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
		soil_fertility[c] = clampi(int(s.get("fertility", 70)), 20, 100)
		var previous_crop := str(s.get("last_crop", ""))
		if CROPS.has(previous_crop):
			soil_last_crop[c] = previous_crop
		_paint_soil(c)
	for cr in saved.get("crops", []):
		var c := Vector2i(int(cr["x"]), int(cr["y"]))
		var ctype := str(cr.get("type", "carrot"))
		if not CROPS.has(ctype):
			ctype = "carrot"
		var per: int = CROPS[ctype]["per"]
		var max_stage := int(CROPS[ctype].get("stages", 3))
		crops[c] = {"type": ctype, "stage": clampi(int(cr["stage"]), 0, max_stage), "age": maxi(0, int(cr.get("age", int(cr["stage"]) * per))), "watered": bool(cr["watered"])}
		_update_crop_node(c)


func _paint_soil(c: Vector2i) -> void:
	soil_layer.set_cell(c, 0, Vector2i(1 if soil.get(c, false) else 0, 4))


func _update_crop_node(c: Vector2i) -> void:
	var crop_type := str(crops[c]["type"])
	var max_stage := int(CROPS[crop_type].get("stages", 3))
	var stage := clampi(int(crops[c]["stage"]), 0, max_stage)
	var s: Sprite2D = crop_nodes.get(c)
	if s == null:
		s = Sprite2D.new()
		s.centered = false
		s.position = Vector2(c.x * TILE, c.y * TILE)
		ground_node.add_child(s)
		crop_nodes[c] = s
	s.texture = load("res://assets/objects/crop_%s_%d.png" % [crop_type, stage])


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
	if crops.has(cell) and int(crops[cell]["stage"]) >= int(CROPS[str(crops[cell]["type"])].get("stages", 3)):
		var crop_type := str(crops[cell]["type"])
		var cdef: Dictionary = CROPS[crop_type]
		var fertility := int(soil_fertility.get(cell, 70))
		var max_yield := maxi(1, int(cdef["max"]) + SoilRules.yield_bonus(fertility))
		var amount := 1 + rng.randi_range(0, max_yield - 1)
		var item := str(cdef["item"])
		GameState.add_item(item, amount)
		EventBus.message.emit("+%d %s" % [amount, GameState.item_name(item)])
		var previous_crop := str(soil_last_crop.get(cell, ""))
		var new_fertility := SoilRules.after_harvest(fertility, previous_crop, crop_type)
		soil_fertility[cell] = new_fertility
		soil_last_crop[cell] = crop_type
		var soil_message := "Плодородие грядки: %d%%" % new_fertility
		if previous_crop == crop_type:
			soil_message += " — повторная посадка истощает почву"
		elif previous_crop != "":
			soil_message += " — севооборот улучшил почву"
		EventBus.message.emit(soil_message)
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
	if o != null and o.interaction() == "campfire" and not (GameState.current_tool() == "axe" and o.fuel <= 0.0):
		EventBus.campfire_requested.emit(o)
		return "talk"
	if o != null and o.interaction() == "cave":
		enter_cave()
		return "talk"
	if o != null and o.interaction() == "chest":
		if not cave_looted:
			cave_looted = true
			GameState.add_money(60)
			GameState.add_item("salve", 1)
			AudioManager.play("coin", 0.03)
			EventBus.message.emit("Старый сундук: +60 монет и мазь")
			return "happy"
		EventBus.message.emit("Сундук пуст - всё уже забрано")
		return "sad"
	if o != null and o.interaction() == "house" and o.uid == "house":
		enter_house()
		return "talk"
	if o != null and o.interaction() == "bed":
		var hour := TimeSystem.hour()
		if hour >= 18 or hour < 5:
			EventBus.dialog_requested.emit("Кровать", ["Свинка зевает. Одеяло выглядит очень уютно..."], "sleep", 0)
			return "talk"
		EventBus.message.emit("Спать пока не хочется (после 18:00)")
		return "sad"
	return "none"


func use_tool(tool_id: String, target: Vector2) -> String:
	var wolf = _wolf_near(target, 20.0)
	if wolf != null:
		wolf.take_hit(GameState.attack_damage(tool_id), player.global_position)
		if tool_id == "spear":
			GameState.use_weapon()
		return "ok"
	var cell := pos_to_cell(target)
	match tool_id:
		"salve":
			if GameState.remove_item("salve", 1):
				GameState.heal(30.0)
				AudioManager.play("pickup")
				EventBus.message.emit("+30 здоровья")
				GameState.keep_selection("salve")
				return "happy"
			return "none"
		"spear":
			AudioManager.play("error")
			return "none"
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
			if not soil_fertility.has(cell):
				soil_fertility[cell] = 70
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
	GameState.decay_food()
	var winter_stop := GameState.hardcore and TimeSystem.season_index() == 3
	for c in crops:
		var cr: Dictionary = crops[c]
		if raining:
			cr["watered"] = true
		if cr["watered"] and not winter_stop:
			cr["age"] = int(cr["age"]) + 1
			var crop_def: Dictionary = CROPS[str(cr["type"])]
			var per: int = int(crop_def["per"])
			var max_stage: int = int(crop_def.get("stages", 3))
			cr["stage"] = mini(max_stage, int(floor(float(cr["age"]) / per)))
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
	_mark_object(obj, false)
	if str(obj.uid).begins_with("built:"):
		built.erase(obj.uid)
	else:
		removed_uids[obj.uid] = true


func serialize() -> Dictionary:
	for n in get_tree().get_nodes_in_group("campfires"):
		if built.has(n.uid):
			built[n.uid]["fuel"] = n.fuel
	var soil_list: Array = []
	for c in soil:
		soil_list.append({"x": c.x, "y": c.y, "wet": soil[c], "fertility": int(soil_fertility.get(c, 70)), "last_crop": str(soil_last_crop.get(c, ""))})
	var crop_list: Array = []
	for c in crops:
		crop_list.append({"x": c.x, "y": c.y, "type": crops[c]["type"], "age": crops[c]["age"], "stage": crops[c]["stage"], "watered": crops[c]["watered"]})
	return {
		"seed": world_seed,
		"cave_looted": cave_looted,
		"removed": removed_uids.keys(),
		"soil": soil_list,
		"crops": crop_list,
		"built": built.values(),
		"animals_ready": animals.map(func(a) -> bool: return a.product_ready),
		"player": [_door_out().x, _door_out().y] if indoors else [player.position.x, player.position.y],
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
	for npc_id in NPC_HOMES:
		var hc: Vector2i = NPC_HOMES[npc_id]
		var n := Npc.new()
		n.setup(str(npc_id), Vector2(hc.x * TILE + 8, (hc.y + 1) * TILE + 12))
		objects_node.add_child(n)


func _creature_near(p: Vector2, radius: float):
	var best = null
	var best_d := radius
	for group in ["animals", "npcs"]:
		for n in get_tree().get_nodes_in_group(group):
			if n is CanvasItem and not (n as CanvasItem).visible:
				continue
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


# ---------------------------------------------------------------- стройка

func _feet(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * TILE + TILE / 2.0, cell.y * TILE + TILE - 1)


func _front_cell() -> Vector2i:
	return pos_to_cell(player.global_position + player.facing * 16.0 + Vector2(0, -4))


func _can_place(cell: Vector2i) -> bool:
	var c := cell_center(cell)
	if indoors:
		if not room_floor_rect().has_point(c):
			return false
	else:
		if not in_bounds(cell) or get_t(cell) != T_GRASS:
			return false
		if soil.has(cell) or crops.has(cell) or bridge_cells.has(cell):
			return false
	if _object_near(c, 13.0) != null or _creature_near(c, 12.0) != null:
		return false
	return player.global_position.distance_to(c) >= 7.0


func start_placement(kind: String) -> void:
	if not Buildings.DEFS.has(kind):
		return
	if not Buildings.allowed(kind, indoors):
		EventBus.message.emit("Здесь это не построить")
		return
	cancel_placement()
	placing = kind
	ghost = Sprite2D.new()
	ghost.centered = false
	ghost.z_index = 5
	var tex: Texture2D = load("res://assets/objects/%s.png" % Buildings.DEFS[kind]["tex"])
	ghost.hframes = int(Buildings.DEFS[kind].get("frames", 1))
	ghost.texture = tex
	ghost.offset = Vector2(-(tex.get_width() / float(ghost.hframes)) / 2.0, -tex.get_height() + 2.0)
	ground_node.add_child(ghost)
	EventBus.placement_changed.emit(true, kind)
	EventBus.message.emit("Выбери место и нажми действие")


func cancel_placement() -> void:
	if ghost != null:
		ghost.queue_free()
		ghost = null
	if placing != "":
		placing = ""
		EventBus.placement_changed.emit(false, "")


func _update_ghost() -> void:
	if ghost == null or player == null:
		return
	var cell := _front_cell()
	ghost.position = _feet(cell)
	ghost.modulate = Color(0.65, 1.0, 0.65, 0.8) if _can_place(cell) else Color(1.0, 0.5, 0.5, 0.7)


## Поставить выбранную постройку перед свинкой. Возвращает реакцию свинки.
func place_current() -> String:
	if placing == "":
		return ""
	var cell := _front_cell()
	var def: Dictionary = Buildings.DEFS[placing]
	if not _can_place(cell):
		EventBus.message.emit("Сюда ставить нельзя")
		AudioManager.play("error")
		return "sad"
	if not Buildings.can_afford(placing):
		EventBus.message.emit("Не хватает ресурсов")
		AudioManager.play("error")
		return "sad"
	Buildings.pay(placing)
	var uid := "built:%s@%d,%d" % [placing, cell.x, cell.y]
	removed_uids.erase(uid)
	var placed := _spawn(placing, cell, uid)
	if placed != null:
		built[uid] = {"kind": placing, "x": cell.x, "y": cell.y}
		_mark_object(placed, true)
	AudioManager.play("build")
	Fx.burst(objects_node, _feet(cell) + Vector2(0, -8), Color("#c79566"), 12, 50.0)
	EventBus.message.emit("Построено: %s" % str(def["name"]))
	if not Buildings.can_afford(placing):
		cancel_placement()
	return "happy"


func _restore_built(saved: Dictionary) -> void:
	for b in saved.get("built", []):
		var kind := str(b.get("kind", ""))
		if not Buildings.DEFS.has(kind):
			continue
		var cell := Vector2i(int(b["x"]), int(b["y"]))
		var uid := "built:%s@%d,%d" % [kind, cell.x, cell.y]
		var restored := _spawn(kind, cell, uid)
		if restored != null:
			built[uid] = {"kind": kind, "x": cell.x, "y": cell.y}
			if b.has("fuel"):
				restored.fuel = float(b["fuel"])
				built[uid]["fuel"] = restored.fuel


# ---------------------------------------------------------------- навигация жителей

func _build_nav() -> void:
	nav = AStarGrid2D.new()
	nav.region = Rect2i(0, 0, MAP_W, MAP_H)
	nav.cell_size = Vector2(TILE, TILE)
	nav.offset = Vector2(TILE / 2.0, TILE / 2.0)
	nav.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	nav.update()
	for y in range(MAP_H):
		for x in range(MAP_W):
			var c := Vector2i(x, y)
			if get_t(c) == T_WATER and not bridge_cells.has(c):
				nav.set_point_solid(c, true)
	for n in objects_node.get_children():
		if n is WorldObject:
			_mark_object(n, true)


func _mark_object(o, solid: bool) -> void:
	if nav == null:
		return
	var col: Vector2 = WorldObject.DEFS[o.kind].get("col", Vector2.ZERO)
	if col == Vector2.ZERO:
		return
	var a := pos_to_cell(o.position + Vector2(-col.x / 2.0, -col.y))
	var b := pos_to_cell(o.position + Vector2(col.x / 2.0 - 0.01, -0.01))
	for y in range(a.y, b.y + 1):
		for x in range(a.x, b.x + 1):
			var c := Vector2i(x, y)
			if in_bounds(c):
				nav.set_point_solid(c, solid)


func find_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	if nav == null:
		return PackedVector2Array()
	var a := pos_to_cell(from)
	var b := pos_to_cell(to)
	if not in_bounds(a) or not in_bounds(b) or nav.is_point_solid(b):
		return PackedVector2Array()
	var was := nav.is_point_solid(a)
	nav.set_point_solid(a, false)
	var p := nav.get_point_path(a, b)
	nav.set_point_solid(a, was)
	return p


func random_walkable_near(center: Vector2, radius_cells: int) -> Vector2:
	if nav == null:
		return Vector2.ZERO
	var base := pos_to_cell(center)
	for i in range(10):
		var c := base + Vector2i(randi_range(-radius_cells, radius_cells), randi_range(-radius_cells, radius_cells))
		if in_bounds(c) and not nav.is_point_solid(c) and get_t(c) >= T_GRASS:
			return cell_center(c)
	return Vector2.ZERO


# ---------------------------------------------------------------- интерьер дома

func room_floor_rect() -> Rect2:
	return Rect2(ROOM_ORIGIN.x + 14, ROOM_ORIGIN.y + 62, ROOM_W - 28, ROOM_H - 64)


func _build_room() -> void:
	var o := ROOM_ORIGIN
	var filler := ColorRect.new()
	filler.color = Color("#150f1a")
	filler.position = o + Vector2(-900, -700)
	filler.size = Vector2(2100, 1600)
	filler.z_index = -20
	add_child(filler)
	var bg := Sprite2D.new()
	bg.texture = _make_room_texture()
	bg.centered = false
	bg.position = o
	bg.z_index = -10
	add_child(bg)
	var walls := StaticBody2D.new()
	add_child(walls)
	var rects := [
		Rect2(o.x - 40, o.y - 40, ROOM_W + 80, 96),
		Rect2(o.x - 40, o.y, 50, ROOM_H + 40),
		Rect2(o.x + ROOM_W - 10, o.y, 50, ROOM_H + 40),
		Rect2(o.x - 40, o.y + ROOM_H, 168, 40),
		Rect2(o.x + 160, o.y + ROOM_H, ROOM_W - 160 + 40, 40),
	]
	for r in rects:
		var cs := CollisionShape2D.new()
		var sh := RectangleShape2D.new()
		sh.size = r.size
		cs.shape = sh
		cs.position = r.position + r.size / 2.0
		walls.add_child(cs)
	_spawn("bed", Vector2i.ZERO, "room_bed", o + Vector2(52, 92))
	_spawn("room_table", Vector2i.ZERO, "room_table", o + Vector2(226, 86))
	_spawn("room_shelf", Vector2i.ZERO, "room_shelf", o + Vector2(124, 58))
	_spawn("clock", Vector2i.ZERO, "room_clock", o + Vector2(176, 38))





func _build_cave_room() -> void:
	var o := CAVE_ROOM_ORIGIN
	var filler := ColorRect.new()
	filler.color = Color("#0a080d")
	filler.position = o + Vector2(-900, -700)
	filler.size = Vector2(2100, 1600)
	filler.z_index = -20
	add_child(filler)
	var bg := Sprite2D.new()
	bg.texture = _make_cave_texture()
	bg.centered = false
	bg.position = o
	bg.z_index = -10
	add_child(bg)
	var walls := StaticBody2D.new()
	add_child(walls)
	var rects := [
		Rect2(o.x - 40, o.y - 40, ROOM_W + 80, 96),
		Rect2(o.x - 40, o.y, 50, ROOM_H + 40),
		Rect2(o.x + ROOM_W - 10, o.y, 50, ROOM_H + 40),
		Rect2(o.x - 40, o.y + ROOM_H, 168, 40),
		Rect2(o.x + 160, o.y + ROOM_H, ROOM_W - 160 + 40, 40),
	]
	for r in rects:
		var cs := CollisionShape2D.new()
		var sh := RectangleShape2D.new()
		sh.size = r.size
		cs.shape = sh
		cs.position = r.position + r.size / 2.0
		walls.add_child(cs)
	# камни для добычи и старый сундук
	var spots := [Vector2(60, 60), Vector2(104, 96), Vector2(150, 62), Vector2(196, 104), Vector2(238, 66), Vector2(84, 132)]
	for i in range(spots.size()):
		var kind := "rock_big" if i % 2 == 0 else "rock_small"
		_spawn(kind, Vector2i.ZERO, "cave_rock_%d" % i, o + spots[i])
	_spawn("chest", Vector2i.ZERO, "cave_chest", o + Vector2(144, 118))


func _make_cave_texture() -> Texture2D:
	var img := Image.create(ROOM_W, ROOM_H, false, Image.FORMAT_RGBA8)
	img.fill(Color("#2a2430"))
	var r := RandomNumberGenerator.new()
	r.seed = 4242
	for y in range(ROOM_H):
		for x in range(ROOM_W):
			if r.randf() < 0.05:
				img.set_pixel(x, y, Color("#221d28"))
			elif r.randf() < 0.03:
				img.set_pixel(x, y, Color("#332c3a"))
	# трещины
	for i in range(14):
		var x := r.randi_range(8, ROOM_W - 8)
		var y := r.randi_range(8, ROOM_H - 8)
		var dx := r.randi_range(-1, 1)
		for k in range(r.randi_range(6, 22)):
			x = clampi(x + dx, 2, ROOM_W - 3)
			y = clampi(y + 1, 2, ROOM_H - 3)
			img.set_pixel(x, y, Color("#1b1620"))
	# светящиеся кристаллы
	for i in range(12):
		var x := r.randi_range(10, ROOM_W - 10)
		var y := r.randi_range(10, ROOM_H - 10)
		img.set_pixel(x, y, Color("#6fd6c8"))
		img.set_pixel(x + 1, y, Color("#3f9a92"))
	# стены-порода по краям
	img.fill_rect(Rect2i(0, 0, ROOM_W, 26), Color("#1c1822"))
	img.fill_rect(Rect2i(0, ROOM_H - 20, ROOM_W, 20), Color("#1c1822"))
	for x in range(0, ROOM_W, 18):
		var h := r.randi_range(18, 40)
		img.fill_rect(Rect2i(x, 0, 12, h), Color("#241f2b"))
	return ImageTexture.create_from_image(img)

func _make_room_texture() -> Texture2D:
	var img := Image.create(ROOM_W, ROOM_H, false, Image.FORMAT_RGBA8)
	img.fill(Color("#76513d"))
	img.fill_rect(Rect2i(0, 0, ROOM_W, 54), Color("#684535"))
	img.fill_rect(Rect2i(0, 54, ROOM_W, ROOM_H - 54), Color("#b8875b"))
	img.fill_rect(Rect2i(8, 8, ROOM_W - 16, 42), Color("#8c5d48"))
	img.fill_rect(Rect2i(12, 58, ROOM_W - 24, ROOM_H - 70), Color("#c99a68"))
	for y in range(66, ROOM_H - 8, 16):
		img.fill_rect(Rect2i(12, y, ROOM_W - 24, 1), Color("#a97850"))
	for x in range(20, ROOM_W - 8, 24):
		img.fill_rect(Rect2i(x, 58, 1, ROOM_H - 70), Color("#b8875b"))
	img.fill_rect(Rect2i(112, 8, 64, 36), Color("#b9d7d0"))
	img.fill_rect(Rect2i(116, 12, 56, 28), Color("#77a9a5"))
	img.fill_rect(Rect2i(142, 12, 3, 28), Color("#e8d6a5"))
	img.fill_rect(Rect2i(116, 25, 56, 3), Color("#e8d6a5"))
	img.fill_rect(Rect2i(0, 50, ROOM_W, 5), Color("#4a3028"))
	return ImageTexture.create_from_image(img)


func _room_origin() -> Vector2:
	return CAVE_ROOM_ORIGIN if in_cave else ROOM_ORIGIN


func _apply_camera_limits() -> void:
	var cam: Camera2D = player.camera
	if indoors:
		# Внутри дома камера приближена: комната целиком влезает в кадр.
		cam.zoom = Vector2(2, 2)
		var vs := get_viewport().get_visible_rect().size / cam.zoom
		var c := _room_origin() + Vector2(ROOM_W, ROOM_H) / 2.0
		# Границы ровно по кадру: маленькая комната жёстко центрируется,
		# иначе Godot сдвигает кадр к краю вырожденных лимитов.
		cam.limit_left = int(c.x - vs.x / 2.0)
		cam.limit_right = int(c.x + vs.x / 2.0)
		cam.limit_top = int(c.y - vs.y / 2.0)
		cam.limit_bottom = int(c.y + vs.y / 2.0)
	else:
		cam.zoom = Vector2(1, 1)
		cam.limit_left = 0
		cam.limit_top = 0
		cam.limit_right = MAP_W * TILE
		cam.limit_bottom = MAP_H * TILE
	cam.reset_smoothing()


func _transition(method: String) -> void:
	_transitioning = true
	if EventBus.fade_requested.get_connections().is_empty():
		call(method)
	else:
		EventBus.fade_requested.emit(Callable(self, method))


func enter_house() -> void:
	if _transitioning or indoors:
		return
	_transition("_do_enter")


func exit_house() -> void:
	if _transitioning or not indoors:
		return
	_transition("_do_exit")


func _do_enter() -> void:
	cancel_placement()
	indoors = true
	_transitioning = false
	player.velocity = Vector2.ZERO
	player.position = ROOM_ORIGIN + Vector2(ROOM_W / 2.0, ROOM_H - 14.0)
	player.facing = Vector2.UP
	weather_fx.visible = false
	_apply_camera_limits()


func _door_out() -> Vector2:
	if in_cave:
		return Vector2(CAVE_CELL) * TILE + Vector2(TILE, TILE) * 1.5
	return HOUSE_DOOR_OUT


func enter_cave() -> void:
	if _transitioning or indoors:
		return
	_transition("_do_enter_cave")


func _do_enter_cave() -> void:
	cancel_placement()
	indoors = true
	in_cave = true
	_transitioning = false
	player.velocity = Vector2.ZERO
	player.position = CAVE_ROOM_ORIGIN + Vector2(ROOM_W / 2.0, ROOM_H - 14.0)
	player.facing = Vector2.UP
	weather_fx.visible = false
	_apply_camera_limits()
	EventBus.message.emit("Пещера: сыро и тихо. Где-то капает вода.")


func exit_cave() -> void:
	if _transitioning or not indoors or not in_cave:
		return
	_transition("_do_exit_cave")


func _do_exit_cave() -> void:
	cancel_placement()
	var out := _door_out()
	indoors = false
	in_cave = false
	_transitioning = false
	player.velocity = Vector2.ZERO
	player.position = out
	player.facing = Vector2.DOWN
	weather_fx.visible = true
	_apply_camera_limits()


func _do_exit() -> void:
	cancel_placement()
	indoors = false
	in_cave = false
	_transitioning = false
	player.velocity = Vector2.ZERO
	player.position = HOUSE_DOOR_OUT
	player.facing = Vector2.DOWN
	weather_fx.visible = true
	_apply_camera_limits()


# ---------------------------------------------------------------- выживание

func region_at(c: Vector2i) -> String:
	if c.y >= 66:
		return "dark"
	if c.x >= 88 and c.y < 62:
		return "rocky"
	return "home"


## Деревня считается безопасной: волки туда не заходят.
func is_safe(p: Vector2) -> bool:
	var r := Rect2(VILLAGE_RECT.position.x * TILE - 48.0, VILLAGE_RECT.position.y * TILE - 48.0, VILLAGE_RECT.size.x * TILE + 96.0, VILLAGE_RECT.size.y * TILE + 96.0)
	return r.has_point(p)


func is_lit(p: Vector2) -> bool:
	if is_safe(p):
		return true
	for n in get_tree().get_nodes_in_group("lights"):
		if (n as Node2D).global_position.distance_to(p) < float(n.light_radius) and n.lit_now():
			return true
	return false


func is_near_fire(p: Vector2) -> bool:
	for n in get_tree().get_nodes_in_group("fires"):
		if n.lit_now() and (n as Node2D).global_position.distance_to(p) < float(n.light_radius):
			return true
	return false


func _wolf_near(p: Vector2, radius: float):
	var best = null
	var best_d := radius
	for w in get_tree().get_nodes_in_group("wolves"):
		var d: float = (w as Node2D).global_position.distance_to(p)
		if d < best_d:
			best_d = d
			best = w
	return best


## Возрождение: свинка просыпается в доме у кровати.
func respawn_at_home() -> void:
	cancel_placement()
	if not indoors:
		_do_enter()
	player.position = ROOM_ORIGIN + Vector2(52, 104)
	player.facing = Vector2.DOWN


func is_grass(c: Vector2i) -> bool:
	return get_t(c) == T_GRASS


func map_size() -> Vector2i:
	return Vector2i(MAP_W, MAP_H)
