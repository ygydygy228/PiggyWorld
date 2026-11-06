extends SceneTree
## Проверка: магазин открывается из диалога жителя, сон перематывает день.

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in range(6):
		await process_frame
	main.call("_start_game", false, false)
	for i in range(30):
		await process_frame

	# --- магазин ---
	var shop_npc = null
	for n in get_nodes_in_group("npcs"):
		if n.npc_id == "shopkeeper":
			shop_npc = n
	print("shop npc found: ", shop_npc != null)
	shop_npc.interact()
	await create_timer(0.4).timeout
	var dlg = main.get("_overlay")
	print("dialog overlay: ", dlg.get_script().resource_path if dlg != null else "null")
	for i in range(8):
		if not is_instance_valid(dlg):
			break
		dlg.set("_typing", false)
		dlg.call("_advance")
		await process_frame
	var overlay = main.get("_overlay")
	var path := ""
	if overlay != null:
		path = overlay.get_script().resource_path
	print("after dialog overlay: ", path, " paused=", paused)
	if not path.ends_with("shop_panel.gd"):
		push_error("shop did not open, got %s" % path)
		quit(1)
		return

	# закрываем магазин
	main.call("_close_overlay")
	await process_frame

	# --- сон ---
	var ts = root.get_node("/root/TimeSystem")
	var day_before: int = ts.day
	main.call("_on_dialog_choice", 0, "sleep")
	await create_timer(1.6).timeout
	print("day ", day_before, " -> ", ts.day, " time=", ts.time_of_day, " paused=", paused)
	if ts.day != day_before + 1:
		push_error("sleep did not advance the day")
		quit(1)
		return
	if paused:
		push_error("game stayed paused after sleep")
		quit(1)
		return
	print("SHOP_SLEEP_OK")
	quit(0)
