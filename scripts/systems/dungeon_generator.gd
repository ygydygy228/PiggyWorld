extends RefCounted
class_name DungeonGenerator
## Deterministic room-and-corridor generator for PiggyWorld's expedition caves.
## The same seed, depth and dimensions always produce the same floor.

const WALL := 0
const FLOOR := 1
const WATER := 2
const CRYSTAL := 3
const MUSHROOM := 4
const ASH := 5

const DEFAULT_WIDTH := 64
const DEFAULT_HEIGHT := 40
const MIN_ROOM_SIZE := Vector2i(7, 6)
const MAX_ROOM_SIZE := Vector2i(13, 10)
const ROOM_PADDING := 2
const MAX_ROOM_ATTEMPTS := 180

const BIOMES := {
	"moss_grotto": {
		"name": "Мшистые гроты",
		"depths": Vector2i(1, 4),
		"wall": Color("#263b35"),
		"floor": Color("#536b50"),
		"accent": Color("#91b96b"),
		"boss": "root_guardian",
		"boss_name": "Хранитель корней",
		"boss_lore": "Старый страж охраняет источник, питающий подземные растения."
	},
	"crystal_depths": {
		"name": "Хрустальные глубины",
		"depths": Vector2i(5, 8),
		"wall": Color("#252d49"),
		"floor": Color("#46577a"),
		"accent": Color("#83d9e8"),
		"boss": "crystal_warden",
		"boss_name": "Кристальный хранитель",
		"boss_lore": "Существо связано с огромным кристаллом в центре древней шахты."
	},
	"ember_hollows": {
		"name": "Пепельные пустоты",
		"depths": Vector2i(9, 12),
		"wall": Color("#432b2a"),
		"floor": Color("#755044"),
		"accent": Color("#e69b62"),
		"boss": "ember_keeper",
		"boss_name": "Смотритель углей",
		"boss_lore": "Он поддерживает жар подземных недр и проверяет тех, кто дошёл до глубины."
	}
}

const ROOM_TYPES := ["normal", "treasure", "puzzle", "rest"]


func biome_for_depth(depth: int) -> String:
	if depth <= 4:
		return "moss_grotto"
	if depth <= 8:
		return "crystal_depths"
	return "ember_hollows"


func generate_floor(depth: int, seed_value: int, width: int = DEFAULT_WIDTH, height: int = DEFAULT_HEIGHT) -> Dictionary:
	var safe_depth := maxi(1, depth)
	var w := maxi(40, width)
	var h := maxi(28, height)
	var biome_id := biome_for_depth(safe_depth)
	var biome: Dictionary = BIOMES[biome_id]
	var floor_seed := _floor_seed(seed_value, safe_depth)
	var rng := RandomNumberGenerator.new()
	rng.seed = floor_seed

	var grid: Array = []
	for y in range(h):
		var row := PackedByteArray()
		row.resize(w)
		for x in range(w):
			row[x] = WALL
		grid.append(row)

	var rooms: Array[Rect2i] = []
	for attempt in range(MAX_ROOM_ATTEMPTS):
		if rooms.size() >= 10:
			break
		var rw := rng.randi_range(MIN_ROOM_SIZE.x, MAX_ROOM_SIZE.x)
		var rh := rng.randi_range(MIN_ROOM_SIZE.y, MAX_ROOM_SIZE.y)
		var room := Rect2i(
			rng.randi_range(2, w - rw - 3),
			rng.randi_range(2, h - rh - 3),
			rw,
			rh
		)
		var overlaps := false
		for existing in rooms:
			if existing.grow(ROOM_PADDING).intersects(room):
				overlaps = true
				break
		if not overlaps:
			rooms.append(room)

	if rooms.size() < 5:
		push_warning("DungeonGenerator: fewer than five rooms; using the valid rooms generated")

	# Stable left-to-right ordering makes the main route understandable.
	rooms.sort_custom(func(a: Rect2i, b: Rect2i) -> bool: return a.get_center().x < b.get_center().x)
	for room in rooms:
		_carve_room(grid, room)

	# A connected backbone: every room is joined to the next one.
	for i in range(rooms.size() - 1):
		var a := Vector2i(rooms[i].get_center())
		var b := Vector2i(rooms[i + 1].get_center())
		_carve_corridor(grid, a, b, rng)

	# The final room always has a clear route to the surface exit at the south edge.
	var exit_cell := Vector2i(w / 2, h - 2)
	_carve_corridor(grid, Vector2i(rooms[rooms.size() - 1].get_center()), exit_cell, rng)

	var boss_floor := safe_depth % 4 == 0
	var room_data: Array[Dictionary] = []
	for i in range(rooms.size()):
		var kind := "normal"
		if i == 0:
			kind = "start"
		elif i == rooms.size() - 1:
			kind = "boss" if boss_floor else "exit"
		elif i == rooms.size() / 2:
			kind = "treasure"
		else:
			kind = ROOM_TYPES[rng.randi_range(0, ROOM_TYPES.size() - 1)]
		room_data.append({
			"rect": rooms[i],
			"center": Vector2i(rooms[i].get_center()),
			"type": kind
		})

	# Decoration is walkable: it changes the mood and route readability, not connectivity.
	_decorate(grid, rooms, biome_id, rng)

	var start_cell: Vector2i = room_data[0]["center"]
	var start_rect: Rect2i = rooms[0]
	# Три печати в стартовой комнате: порядок активации задаёт rng и подсказка на стене.
	var seal_offsets := [Vector2i(-2, 0), Vector2i(0, -2), Vector2i(2, 0)]
	var seals: Array = []
	for off in seal_offsets:
		var cell: Vector2i = start_cell + off
		cell.x = clampi(cell.x, start_rect.position.x + 1, start_rect.end.x - 2)
		cell.y = clampi(cell.y, start_rect.position.y + 1, start_rect.end.y - 2)
		seals.append(cell)
	var seal_order := [0, 1, 2]
	for i in range(seal_order.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = seal_order[i]
		seal_order[i] = seal_order[j]
		seal_order[j] = tmp
	var final_room: Dictionary = room_data[room_data.size() - 1]
	var final_center: Vector2i = final_room["center"]

	var boss: Dictionary = {}
	if boss_floor:
		boss = {
			"id": str(biome["boss"]),
			"name": str(biome["boss_name"]),
			"lore": str(biome["boss_lore"]),
			"cell": final_center,
			"encounter": "environmental_puzzle"
		}

	return {
		"seed": floor_seed,
		"depth": safe_depth,
		"biome_id": biome_id,
		"biome": biome,
		"width": w,
		"height": h,
		"grid": grid,
		"rooms": room_data,
		"start": start_cell,
		"seals": seals,
		"seal_order": seal_order,
		"exit": exit_cell,
		"boss_floor": boss_floor,
		"boss": boss,
		"has_treasure_room": true,
		"generation_version": 1
	}


func _floor_seed(world_seed: int, depth: int) -> int:
	# Integer mixing keeps each depth independent while remaining reproducible.
	return int(abs((world_seed * 1103515245 + depth * 12345 + 1013904223) % 2147483647)) + 1


func _carve_room(grid: Array, room: Rect2i) -> void:
	for y in range(room.position.y, room.end.y):
		for x in range(room.position.x, room.end.x):
			grid[y][x] = FLOOR


func _carve_corridor(grid: Array, from: Vector2i, to: Vector2i, rng: RandomNumberGenerator) -> void:
	var horizontal_first := rng.randf() < 0.5
	var p := from
	if horizontal_first:
		while p.x != to.x:
			_carve_wide_cell(grid, p)
			p.x += 1 if to.x > p.x else -1
		while p.y != to.y:
			_carve_wide_cell(grid, p)
			p.y += 1 if to.y > p.y else -1
	else:
		while p.y != to.y:
			_carve_wide_cell(grid, p)
			p.y += 1 if to.y > p.y else -1
		while p.x != to.x:
			_carve_wide_cell(grid, p)
			p.x += 1 if to.x > p.x else -1
	_carve_wide_cell(grid, to)


func _carve_wide_cell(grid: Array, cell: Vector2i) -> void:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var x := cell.x + dx
			var y := cell.y + dy
			if y >= 1 and y < grid.size() - 1 and x >= 1 and x < grid[y].size() - 1:
				grid[y][x] = FLOOR


func _decorate(grid: Array, rooms: Array[Rect2i], biome_id: String, rng: RandomNumberGenerator) -> void:
	var chance := 0.045
	var decoration := WATER
	if biome_id == "crystal_depths":
		chance = 0.065
		decoration = CRYSTAL
	elif biome_id == "ember_hollows":
		chance = 0.055
		decoration = ASH
	else:
		decoration = MUSHROOM

	for y in range(1, grid.size() - 1):
		for x in range(1, grid[y].size() - 1):
			if grid[y][x] != FLOOR or rng.randf() > chance:
				continue
			# Keep the main route and room centers clear.
			var near_center := false
			for room in rooms:
				if room.grow(1).has_point(Vector2i(x, y)):
					near_center = true
					break
			if not near_center:
				grid[y][x] = decoration


func _is_floor(grid: Array, cell: Vector2i) -> bool:
	if cell.y < 0 or cell.y >= grid.size() or cell.x < 0 or cell.x >= grid[cell.y].size():
		return false
	return grid[cell.y][cell.x] != WALL
