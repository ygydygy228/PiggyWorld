extends Node
## Корень игры: меню → мир + интерфейс. Автосохранение и пауза.

const UiTheme := preload("res://scripts/ui/ui_theme.gd")
const MainMenu := preload("res://scripts/ui/main_menu.gd")
const PauseMenu := preload("res://scripts/ui/pause_menu.gd")
const Hud := preload("res://scripts/ui/hud.gd")
const TouchControls := preload("res://scripts/ui/touch_controls.gd")
const World := preload("res://scripts/world/world.gd")

const AUTOSAVE_SECONDS := 60.0

var _menu: MainMenu
var _world: World
var _hud: Hud
var _touch: TouchControls
var _pause: PauseMenu
var _autosave: float = AUTOSAVE_SECONDS


func _ready() -> void:
	get_window().theme = UiTheme.build()
	AudioManager.play_music()
	_show_menu()


func _process(delta: float) -> void:
	if _world == null or get_tree().paused:
		return
	_autosave -= delta
	if _autosave <= 0.0:
		_autosave = AUTOSAVE_SECONDS
		SaveSystem.save_game(_world)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if _world != null:
			SaveSystem.save_game(_world)


func _show_menu() -> void:
	_stop_game()
	_menu = MainMenu.new()
	add_child(_menu)
	_menu.start_requested.connect(_start_game)


func _stop_game() -> void:
	get_tree().paused = false
	for n in [_world, _hud, _touch, _pause, _menu]:
		if n != null and is_instance_valid(n):
			n.queue_free()
	_world = null
	_hud = null
	_touch = null
	_pause = null
	_menu = null


func _start_game(continue_game: bool) -> void:
	if continue_game:
		if not SaveSystem.load_game():
			SaveSystem.new_game()
	else:
		SaveSystem.new_game()
	if _menu != null:
		_menu.queue_free()
		_menu = null
	_world = World.new()
	add_child(_world)
	_hud = Hud.new()
	add_child(_hud)
	_hud.menu_requested.connect(_open_pause)
	_touch = TouchControls.new()
	_touch.player = _world.player
	add_child(_touch)
	_autosave = AUTOSAVE_SECONDS


func _open_pause() -> void:
	if _pause != null or _world == null:
		return
	get_tree().paused = true
	_touch.enabled = false
	_world.player.input_enabled = false
	_pause = PauseMenu.new()
	add_child(_pause)
	_pause.resume_requested.connect(_close_pause)
	_pause.save_requested.connect(_manual_save)
	_pause.menu_requested.connect(_leave_to_menu)


func _close_pause() -> void:
	if _pause != null:
		_pause.queue_free()
		_pause = null
	get_tree().paused = false
	if _touch != null:
		_touch.enabled = true
	if _world != null:
		_world.player.input_enabled = true


func _manual_save() -> void:
	if SaveSystem.save_game(_world):
		EventBus.message.emit("Игра сохранена")
	else:
		EventBus.message.emit("Не удалось сохранить")


func _leave_to_menu() -> void:
	if _world != null:
		SaveSystem.save_game(_world)
	_show_menu()
