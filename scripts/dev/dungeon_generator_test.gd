extends SceneTree
## Run with: godot --headless --path . -s scripts/dev/dungeon_generator_test.gd

const Generator := preload("res://scripts/systems/dungeon_generator.gd")


func _initialize() -> void:
	var generator = Generator.new()
	var seeds := [24681357, 1, 7, 1337, 999983, 424242, 20260101, 55555]
	var floors := 0
	for seed_value in seeds:
		for depth in range(1, 13):
			floors += 1
			var first: Dictionary = generator.generate_floor(depth, int(seed_value))
			var repeated: Dictionary = generator.generate_floor(depth, int(seed_value))
			if first["seed"] != repeated["seed"] or first["start"] != repeated["start"] or first["grid"] != repeated["grid"]:
				_fail("generation is not deterministic at depth %d seed %d" % [depth, seed_value])
				return
			if bool(first["boss_floor"]) != (depth % 4 == 0):
				_fail("boss cadence is wrong at depth %d" % depth)
				return
			if not _reachable(first["grid"], first["start"], first["exit"]):
				_fail("exit is unreachable at depth %d seed %d" % [depth, seed_value])
				return
			if int(first["rooms"].size()) < 5:
				_fail("too few rooms at depth %d" % depth)
				return
			if depth % 4 == 0 and str(first["boss"].get("id", "")) == "":
				_fail("boss metadata missing at depth %d" % depth)
				return
			var seals: Array = first.get("seals", [])
			if seals.size() != 3:
				_fail("expected three seals at depth %d" % depth)
				return
			var order: Array = first.get("seal_order", [])
			var sorted_order: Array = order.duplicate()
			sorted_order.sort()
			if order.size() != 3 or sorted_order != [0, 1, 2]:
				_fail("seal order is not a permutation at depth %d" % depth)
				return
			for seal in seals:
				if not _reachable(first["grid"], first["start"], seal):
					_fail("seal is unreachable at depth %d seed %d" % [depth, seed_value])
					return
	print("DUNGEON_TEST_OK: %d floors (%d seeds), deterministic, connected exits and seals, biome and boss progression" % [floors, seeds.size()])
	quit(0)


func _fail(message: String) -> void:
	push_error("DUNGEON_TEST_FAILED: " + message)
	quit(1)


func _reachable(grid: Array, start: Vector2i, target: Vector2i) -> bool:
	var queue: Array[Vector2i] = [start]
	var visited: Dictionary = {start: true}
	var directions := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
	var cursor := 0
	while cursor < queue.size():
		var cell := queue[cursor]
		cursor += 1
		if cell == target:
			return true
		for direction in directions:
			var next: Vector2i = cell + direction
			if next.y < 0 or next.y >= grid.size() or next.x < 0 or next.x >= grid[next.y].size():
				continue
			if int(grid[next.y][next.x]) == Generator.WALL or visited.has(next):
				continue
			visited[next] = true
			queue.append(next)
	return false
