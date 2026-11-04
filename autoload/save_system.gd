extends Node
## Сохранение/загрузка прогресса в JSON (user://). Мир сам описывает своё состояние через serialize().

const PATH := "user://piggyworld_save.json"

var pending: Dictionary = {}


func has_save() -> bool:
	return FileAccess.file_exists(PATH)


func save_game(world: Node) -> bool:
	var data := {
		"version": 1,
		"state": GameState.to_dict(),
		"time": TimeSystem.to_dict(),
		"world": world.serialize(),
	}
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		push_warning("SaveSystem: не удалось открыть файл сохранения (код %d)" % FileAccess.get_open_error())
		return false
	f.store_string(JSON.stringify(data))
	f.close()
	return true


func load_game() -> bool:
	pending = {}
	if not has_save():
		return false
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return false
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("SaveSystem: файл сохранения повреждён")
		return false
	pending = parsed
	GameState.from_dict(pending.get("state", {}))
	TimeSystem.from_dict(pending.get("time", {}))
	return true


func new_game() -> void:
	pending = {}
	GameState.reset()
	TimeSystem.reset()
