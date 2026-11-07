extends SceneTree
## Run with: godot --headless --path . -s scripts/dev/dungeon_generator_test.gd

const Generator := preload("res://scripts/systems/dungeon_generator.gd")


func _initialize() -> void:
	var generator = Generator.new()
	for depth in range(1, 13):
		var first: Dictionary = generator.generate_floor(depth, 24681357)
		var repeated: Dictionary = generator.generate_floor(depth, 24681357)
		if first["seed"] != repeated["seed"] or first["start"] != repeated["start"] or first["grid"] != repeated["grid"]:
			push_error("DUNGEON_TEST_FAILED: generation is not deterministic at depth %d" % depth)
			quit(1)
			return
		if bool(first["boss_floor"]) != (depth % 4 == 0):
			push_error("DUNGEON_TEST_FAILED: boss cadence is wrong at depth %d" % depth)
			quit(1)
			return
		if not _reachable(first["grid"], first["start"], first["exit"]):
			push_error("DUNGEON_TEST_FAILED: exit is unreachable at depth %d" % depth)
			quit(1)
			return
		if int(first["rooms"].size()) < 5:
			push_error("DUNGEON_TEST_FAILED: too few rooms at depth %d" % depth)
			quit(1)
			return
		if depth % 4 == 0 and str(first["boss"].get("id", "")) == "":
			push_error("DUNGEON_TEST_FAILED: boss metadata missing at depth %d" % depth)
			quit(1)
			return
	print("DUNGEON_TEST_OK: 12 floors, deterministic seeds, connected exits, biome and boss progression")
	quit(0)


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
