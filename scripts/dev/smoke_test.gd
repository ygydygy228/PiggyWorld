extends SceneTree

const WorldObject := preload("res://scripts/world/world_object.gd")
## Запускает главное меню, начинает новую игру и проверяет базовые узлы мира.
## CI: godot --headless --path . -s scripts/dev/smoke_test.gd

func _initialize() -> void:
	call_deferred("_run_smoke_test")


func _run_smoke_test() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	if packed == null:
		push_error("SMOKE_FAILED: cannot load res://scenes/main.tscn")
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
		push_error("SMOKE_FAILED: player was not created in the world")
		quit(1)
		return

	# Проверяем резервное сохранение: повреждённый основной файл должен восстановиться.
	var original_money: int = int(game_state.get("money"))
	if not save_system.call("save_game", world):
		push_error("SMOKE_FAILED: initial save failed")
		quit(1)
		return
	game_state.call("add_money", 7)
	if not SaveSystem.save_game(world):
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
	if not save_system.call("load_game") == false or int(game_state.get("money")) != original_money:
		push_error("SMOKE_FAILED: backup save recovery failed")
		quit(1)
		return

	# Сохранение после восстановления не должно уничтожать рабочую резервную копию.
	game_state.call("add_money", 3)
	if not SaveSystem.save_game(world):
		push_error("SMOKE_FAILED: save after recovery failed")
		quit(1)
		return
	corrupt_file = FileAccess.open(SaveSystem.PATH, FileAccess.WRITE)
	if corrupt_file == null:
		push_error("SMOKE_FAILED: cannot repeat save recovery test")
		quit(1)
		return
	corrupt_file.store_string("{broken again")
	corrupt_file.close()
	if not SaveSystem.load_game() or GameState.money != original_money:
		push_error("SMOKE_FAILED: good backup was lost after recovery save")
		quit(1)
		return

	# Все предметы и объекты должны иметь пригодную текстуру (включая fallback).
	var item_defs: Dictionary = load("res://autoload/game_state.gd").get_script_constant_map().get("ITEMS", {})
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

	# Отрицательные значения не должны добавлять предметы или деньги.
	var money_before_invalid_change: int = int(game_state.get("money"))
	var wood_before_invalid_change: int = int(game_state.call("count", "wood"))
	game_state.call("add_money", -10)
	if game_state.call("spend_money", -10) or int(game_state.get("money")) != money_before_invalid_change:
		push_error("SMOKE_FAILED: invalid money mutation was accepted")
		quit(1)
		return
	game_state.call("add_item", "wood", -1)
	if game_state.call("remove_item", "wood", -1) or int(game_state.call("count", "wood")) != wood_before_invalid_change:
		push_error("SMOKE_FAILED: invalid inventory mutation was accepted")
		quit(1)
		return

	# Даём сценам, анимациям и игровым системам время пройти _ready/_process.
	for frame in range(200):
		await process_frame

	print("SMOKE_OK: menu, world and player initialized; 200 frames processed")

	# Remove the running world first: its _process() updates ambient audio
	# every frame and would otherwise attach ambient_day.wav again after stop_all().
	var audio_manager := root.get_node_or_null("AudioManager")
	main.queue_free()
	await process_frame

	# Stop and detach all streams only after gameplay nodes have left the tree.
	if audio_manager != null and is_instance_valid(audio_manager):
		audio_manager.call("stop_all")
	for frame in range(8):
		await process_frame
	# Даём микшеру реальное время отпустить проигрывания: в headless кадры идут
	# без vsync, и одного счёта кадров не хватает - CI ловил "resources still in use".
	await create_timer(0.3).timeout

	quit(0)
