extends SceneTree
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
	if world == null or not is_instance_valid(world):
		push_error("SMOKE_FAILED: game world was not created")
		quit(1)
		return

	var player := world.get("player") as Node
	if player == null or not is_instance_valid(player):
		push_error("SMOKE_FAILED: player was not created in the world")
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
	# без vsync, и одного счёта кадров не хватает — CI ловил "resources still in use".
	await create_timer(0.3).timeout

	quit(0)
