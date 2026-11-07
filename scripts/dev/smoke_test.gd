extends SceneTree

const WorldObject := preload("res://scripts/world/world_object.gd")
const GameStateScript := preload("res://autoload/game_state.gd")
## CI: godot --headless --path . -s scripts/dev/smoke_test.gd

func _initialize() -> void:
	call_deferred("_run_smoke_test")


func _run_smoke_test() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	if packed == null:
		push_error("SMOKE_FAILED: cannot load main scene")
		quit(1)
		return

	var main := packed.instantiate()
	root.add_child(main)
	await process_frame

	if not main.has_method("_start_game"):
		push_error("SMOKE_FAILED: Main has no _start_game method")
		quit(1)
		return

	main.call("_start_game", false)
	await process_frame

	var world := main.get("_world") as Node
	var game_state: Node = root.get_node_or_null("GameState")
	var save_system: Node = root.get_node_or_null("SaveSystem")
	if game_state == null or save_system == null:
		push_error("SMOKE_FAILED: autoload nodes are missing")
		quit(1)
		return
	if world == null or not is_instance_valid(world):
		push_error("SMOKE_FAILED: game world was not created")
		quit(1)
		return

	var player := world.get("player") as Node
	if player == null or not is_instance_valid(player):
		push_error("SMOKE_FAILED: player was not created")
		quit(1)
		return

	# Atomic save + backup recovery.
	var original_money: int = int(game_state.get("money"))
	if not bool(save_system.call("save_game", world)):
		push_error("SMOKE_FAILED: initial save failed")
		quit(1)
		return
	game_state.call("add_money", 7)
	if not bool(save_system.call("save_game", world)):
		push_error("SMOKE_FAILED: second save failed")
		quit(1)
		return

	var corrupt_file := FileAccess.open("user://piggyworld_save.json", FileAccess.WRITE)
	if corrupt_file == null:
		push_error("SMOKE_FAILED: cannot prepare save recovery test")
		quit(1)
		return
	corrupt_file.store_string("{broken json")
	corrupt_file.close()

	if not bool(save_system.call("load_game")) or int(game_state.get("money")) != original_money:
		push_error("SMOKE_FAILED: backup save recovery failed")
		quit(1)
		return

	# A save after recovery must preserve the last known-good backup.
	game_state.call("add_money", 3)
	if not bool(save_system.call("save_game", world)):
		push_error("SMOKE_FAILED: save after recovery failed")
		quit(1)
		return
	corrupt_file = FileAccess.open("user://piggyworld_save.json", FileAccess.WRITE)
	if corrupt_file == null:
		push_error("SMOKE_FAILED: cannot repeat save recovery test")
		quit(1)
		return
	corrupt_file.store_string("{broken again")
	corrupt_file.close()
	if not bool(save_system.call("load_game")) or int(game_state.get("money")) != original_money:
		push_error("SMOKE_FAILED: good backup was lost after recovery save")
		quit(1)
		return

	# Verify all item icons and world-object textures, including generated fallbacks.
	var item_defs: Dictionary = GameStateScript.get_script_constant_map().get("ITEMS", {})
	for item_id in item_defs.keys():
		if game_state.call("item_icon", str(item_id)) == null:
			push_error("SMOKE_FAILED: missing item icon: " + str(item_id))
			quit(1)
			return

	var object_defs: Dictionary = WorldObject.get_script_constant_map().get("DEFS", {})
	for object_kind in object_defs.keys():
		var probe = WorldObject.new()
		probe.setup(str(object_kind), Vector2i.ZERO, null)
		if probe.sprite == null or probe.sprite.texture == null:
			push_error("SMOKE_FAILED: missing object texture: " + str(object_kind))
			probe.free()
			quit(1)
			return
		probe.free()

	# Reject invalid negative inventory and currency changes.
	var money_before: int = int(game_state.get("money"))
	var wood_before: int = int(game_state.call("count", "wood"))
	game_state.call("add_money", -10)
	if bool(game_state.call("spend_money", -10)) or int(game_state.get("money")) != money_before:
		push_error("SMOKE_FAILED: invalid money mutation was accepted")
		quit(1)
		return
	game_state.call("add_item", "wood", -1)
	if bool(game_state.call("remove_item", "wood", -1)) or int(game_state.call("count", "wood")) != wood_before:
		push_error("SMOKE_FAILED: invalid inventory mutation was accepted")
		quit(1)
		return

	for frame in range(200):
		await process_frame

	print("SMOKE_OK: menu, world, player, save recovery, economy and assets verified")

	var audio_manager := root.get_node_or_null("AudioManager")
	main.queue_free()
	await process_frame
	if audio_manager != null and is_instance_valid(audio_manager):
		audio_manager.call("stop_all")
	for frame in range(8):
		await process_frame
	await create_timer(0.3).timeout
	quit(0)
