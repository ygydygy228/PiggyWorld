extends Node
## Звуки, музыка, окружение. Файлы: res://assets/audio/<имя>.wav

const SFX_POOL := 8
const SETTINGS_PATH := "user://settings.cfg"

var music_volume: float = 0.5
var sfx_volume: float = 0.8
var _pool: Array[AudioStreamPlayer] = []
var _music: AudioStreamPlayer
var _ambient: AudioStreamPlayer
var _cache: Dictionary = {}
var _ambient_name: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in SFX_POOL:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	_music = AudioStreamPlayer.new()
	add_child(_music)
	_music.finished.connect(func() -> void: _music.play())
	_ambient = AudioStreamPlayer.new()
	add_child(_ambient)
	_ambient.finished.connect(func() -> void: _ambient.play())
	_load_settings()
	_apply_volumes()


func stop_all() -> void:
	# Останавливаем плееры и отвязываем потоки до очистки кэша.
	for p in _pool:
		if is_instance_valid(p):
			p.stop()
			p.stream = null
	if is_instance_valid(_music):
		_music.stop()
		_music.stream = null
	if is_instance_valid(_ambient):
		_ambient.stop()
		_ambient.stream = null
	_cache.clear()
	_ambient_name = ""


func _exit_tree() -> void:
	stop_all()


func _stream(sound: String) -> AudioStream:
	if not _cache.has(sound):
		var path := "res://assets/audio/%s.wav" % sound
		_cache[sound] = load(path) if ResourceLoader.exists(path) else null
	return _cache[sound]


func play(sound: String, pitch_var: float = 0.06, volume: float = 1.0) -> void:
	var s := _stream(sound)
	if s == null:
		return
	for p in _pool:
		if not p.playing:
			p.stream = s
			p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
			p.volume_db = linear_to_db(maxf(0.001, sfx_volume * volume))
			p.play()
			return


func play_music() -> void:
	var s := _stream("music_farm")
	if s == null or _music.playing:
		return
	_music.stream = s
	_music.play()


func set_ambient(sound: String) -> void:
	if sound == _ambient_name:
		return
	_ambient_name = sound
	if sound == "":
		_ambient.stop()
		_ambient.stream = null
		return
	var s := _stream(sound)
	if s != null:
		_ambient.stream = s
		_ambient.play()


func set_volumes(music: float, sfx: float) -> void:
	music_volume = clampf(music, 0.0, 1.0)
	sfx_volume = clampf(sfx, 0.0, 1.0)
	_apply_volumes()
	_save_settings()


func _apply_volumes() -> void:
	if _music:
		_music.volume_db = linear_to_db(maxf(0.001, music_volume))
	if _ambient:
		_ambient.volume_db = linear_to_db(maxf(0.001, sfx_volume * 0.6))


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		music_volume = float(cfg.get_value("audio", "music", music_volume))
		sfx_volume = float(cfg.get_value("audio", "sfx", sfx_volume))


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.save(SETTINGS_PATH)
