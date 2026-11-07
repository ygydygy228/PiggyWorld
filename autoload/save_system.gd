extends Node
## Надёжное сохранение прогресса в JSON (user://) с резервной копией.

const PATH := "user://piggyworld_save.json"
const TEMP_PATH := "user://piggyworld_save.json.tmp"
const BACKUP_PATH := "user://piggyworld_save.json.bak"
const SAVE_VERSION := 2

var pending: Dictionary = {}
var _loaded_from_backup: bool = false


func has_save() -> bool:
	return FileAccess.file_exists(PATH) or FileAccess.file_exists(BACKUP_PATH)


func save_game(world: Node) -> bool:
	if world == null or not is_instance_valid(world) or not world.has_method("serialize"):
		push_warning("SaveSystem: невозможно сохранить пустой или некорректный мир")
		return false

	var world_data: Variant = world.call("serialize")
	if typeof(world_data) != TYPE_DICTIONARY:
		push_warning("SaveSystem: мир вернул некорректные данные")
		return false

	var data := {
		"version": SAVE_VERSION,
		"state": GameState.to_dict(),
		"time": TimeSystem.to_dict(),
		"world": world_data,
	}
	var temp_absolute := ProjectSettings.globalize_path(TEMP_PATH)
	var save_absolute := ProjectSettings.globalize_path(PATH)
	var backup_absolute := ProjectSettings.globalize_path(BACKUP_PATH)

	var file := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("SaveSystem: не удалось создать временный файл (код %d)" % FileAccess.get_open_error())
		return false
	file.store_string(JSON.stringify(data))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		DirAccess.remove_absolute(temp_absolute)
		push_warning("SaveSystem: ошибка записи временного файла (код %d)" % write_error)
		return false

	# После восстановления из backup не перезаписываем единственную хорошую копию
	# повреждённым основным файлом.
	if _loaded_from_backup and FileAccess.file_exists(PATH):
		var corrupt_path := PATH + ".corrupt"
		var corrupt_absolute := ProjectSettings.globalize_path(corrupt_path)
		if FileAccess.file_exists(corrupt_path):
			DirAccess.remove_absolute(corrupt_absolute)
		var quarantine_error := DirAccess.rename_absolute(save_absolute, corrupt_absolute)
		if quarantine_error != OK:
			DirAccess.remove_absolute(temp_absolute)
			push_warning("SaveSystem: не удалось изолировать повреждённое сохранение (код %d)" % quarantine_error)
			return false
		var recovered_error := DirAccess.rename_absolute(temp_absolute, save_absolute)
		if recovered_error != OK:
			DirAccess.rename_absolute(corrupt_absolute, save_absolute)
			push_warning("SaveSystem: не удалось записать восстановленное сохранение (код %d)" % recovered_error)
			return false
		DirAccess.remove_absolute(corrupt_absolute)
		_loaded_from_backup = false
		return true

	# Сначала сохраняем предыдущую версию, затем заменяем основной файл.
	if FileAccess.file_exists(PATH):
		if FileAccess.file_exists(BACKUP_PATH):
			DirAccess.remove_absolute(backup_absolute)
		var backup_error := DirAccess.rename_absolute(save_absolute, backup_absolute)
		if backup_error != OK:
			DirAccess.remove_absolute(temp_absolute)
			push_warning("SaveSystem: не удалось создать резервную копию (код %d)" % backup_error)
			return false

	var replace_error := DirAccess.rename_absolute(temp_absolute, save_absolute)
	if replace_error != OK:
		if FileAccess.file_exists(BACKUP_PATH) and not FileAccess.file_exists(PATH):
			DirAccess.rename_absolute(backup_absolute, save_absolute)
		push_warning("SaveSystem: не удалось завершить сохранение (код %d)" % replace_error)
		return false
	_loaded_from_backup = false
	return true


func _read_save(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var data: Dictionary = parsed
	var version := int(data.get("version", 1))
	if version < 1 or version > SAVE_VERSION:
		return {}
	if typeof(data.get("state", {})) != TYPE_DICTIONARY:
		return {}
	if typeof(data.get("time", {})) != TYPE_DICTIONARY:
		return {}
	if typeof(data.get("world", {})) != TYPE_DICTIONARY:
		return {}
	return data


func load_game() -> bool:
	pending = _read_save(PATH)
	_loaded_from_backup = pending.is_empty()
	if _loaded_from_backup:
		pending = _read_save(BACKUP_PATH)
	if pending.is_empty():
		_loaded_from_backup = false
		push_warning("SaveSystem: основное и резервное сохранения отсутствуют или повреждены")
		return false
	GameState.from_dict(pending.get("state", {}))
	TimeSystem.from_dict(pending.get("time", {}))
	return true


func new_game() -> void:
	pending = {}
	GameState.reset()
	TimeSystem.reset()
