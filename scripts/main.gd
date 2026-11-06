extends Node
## Корень игры: меню → мир + интерфейс. Автосохранение, пауза, диалоги, магазин, стройка, сон.
## Все окна поверх игры лежат на отдельном CanvasLayer, иначе камера мира сдвигает их за экран.

const UiTheme := preload("res://scripts/ui/ui_theme.gd")
const MainMenu := preload("res://scripts/ui/main_menu.gd")
const PauseMenu := preload("res://scripts/ui/pause_menu.gd")
const Hud := preload("res://scripts/ui/hud.gd")
const TouchControls := preload("res://scripts/ui/touch_controls.gd")
const World := preload("res://scripts/world/world.gd")
const DialogBox := preload("res://scripts/ui/dialog_box.gd")
const ShopPanel := preload("res://scripts/ui/shop_panel.gd")
const BuildMenu := preload("res://scripts/ui/build_menu.gd")
const BackpackPanel := preload("res://scripts/ui/backpack_panel.gd")
const CampfirePanel := preload("res://scripts/ui/campfire_panel.gd")

const AUTOSAVE_SECONDS := 60.0

const UI_SIZE := Vector2(480, 270)
const UI_SCALE := 2.0

var _ui: CanvasLayer
var _ui_root: Control
var _menu: MainMenu
var _world: World
var _hud: Hud
var _touch: TouchControls
var _pause: PauseMenu
var _overlay: Control
var _autosave: float = AUTOSAVE_SECONDS
var _sleeping: bool = false


func _ready() -> void:
	get_window().theme = UiTheme.build()
	_ui = CanvasLayer.new()
	_ui.layer = 30
	_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	# Интерфейс рисуем в координатах 480x270 и растягиваем 2x: мир при этом виден шире.
	_ui.transform = Transform2D(Vector2(UI_SCALE, 0), Vector2(0, UI_SCALE), Vector2.ZERO)
	add_child(_ui)
	_ui_root = Control.new()
	_ui_root.size = UI_SIZE
	_ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_ui_root)
	AudioManager.play_music()
	EventBus.dialog_requested.connect(_on_dialog)
	EventBus.build_menu_requested.connect(_on_build_menu)
	EventBus.fade_requested.connect(_on_fade)
	EventBus.backpack_requested.connect(_on_backpack)
	EventBus.campfire_requested.connect(_on_campfire)
	EventBus.player_died.connect(_on_player_died)
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
	_ui_root.add_child(_menu)
	_menu.start_requested.connect(_start_game)


func _stop_game() -> void:
	get_tree().paused = false
	for n in [_world, _hud, _touch, _pause, _overlay, _menu]:
		if n != null and is_instance_valid(n):
			n.queue_free()
	_world = null
	_hud = null
	_touch = null
	_pause = null
	_overlay = null
	_menu = null
	_sleeping = false


func _start_game(continue_game: bool, hardcore: bool = false) -> void:
	if continue_game:
		if not SaveSystem.load_game():
			SaveSystem.new_game()
	else:
		SaveSystem.new_game()
		GameState.hardcore = hardcore
		EventBus.stats_changed.emit()
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


func _busy() -> bool:
	return _pause != null or _overlay != null or _sleeping or _world == null


func _set_paused(on: bool) -> void:
	get_tree().paused = on
	if _touch != null:
		_touch.enabled = not on
	if _world != null:
		_world.player.input_enabled = not on


# ---------------------------------------------------------------- пауза

func _open_pause() -> void:
	if _busy():
		return
	_set_paused(true)
	_pause = PauseMenu.new()
	_ui_root.add_child(_pause)
	_pause.resume_requested.connect(_close_pause)
	_pause.save_requested.connect(_manual_save)
	_pause.menu_requested.connect(_leave_to_menu)


func _close_pause() -> void:
	if _pause != null:
		_pause.queue_free()
		_pause = null
	_set_paused(false)


func _manual_save() -> void:
	if SaveSystem.save_game(_world):
		EventBus.message.emit("Игра сохранена")
	else:
		EventBus.message.emit("Не удалось сохранить")


func _leave_to_menu() -> void:
	if _world != null:
		SaveSystem.save_game(_world)
	_show_menu()


# ---------------------------------------------------------------- диалоги и магазин

func _on_dialog(speaker: String, lines: Array, action: String) -> void:
	if _busy():
		return
	_set_paused(true)
	var choices: Array = []
	if action == "sleep":
		choices = ["Лечь спать", "Ещё нет"]
	var d := DialogBox.new()
	d.setup(speaker, lines, choices)
	# сигналы подключаем до add_child: _ready может сразу завершить диалог
	_overlay = d
	if choices.is_empty():
		d.finished.connect(_on_dialog_finished.bind(action))
	else:
		d.chosen.connect(_on_dialog_choice.bind(action))
	_ui_root.add_child(d)


func _on_dialog_finished(action: String) -> void:
	_overlay = null
	if action.begins_with("shop:"):
		var shop := ShopPanel.new()
		shop.setup(action.substr(5))
		_overlay = shop
		shop.closed.connect(_close_overlay)
		_ui_root.add_child(shop)
	else:
		_set_paused(false)


func _on_dialog_choice(index: int, action: String) -> void:
	_overlay = null
	if action == "sleep" and index == 0:
		_do_sleep()
	elif action == "respawn":
		_run_fade(_respawn_mid, _respawn_after)
	else:
		_set_paused(false)


func _close_overlay() -> void:
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null
	_set_paused(false)


# ---------------------------------------------------------------- стройка

func _on_build_menu() -> void:
	if _busy():
		return
	_set_paused(true)
	var m := BuildMenu.new()
	m.indoors = _world.indoors
	_overlay = m
	m.closed.connect(_close_overlay)
	m.chosen.connect(_on_build_chosen)
	_ui_root.add_child(m)


func _on_build_chosen(kind: String) -> void:
	_close_overlay()
	if _world != null:
		_world.start_placement(kind)


# ---------------------------------------------------------------- затемнение, переходы, сон

func _on_fade(mid: Callable) -> void:
	if _world == null or _sleeping:
		mid.call()
		return
	_run_fade(mid)


func _run_fade(mid: Callable, after: Callable = Callable()) -> void:
	_sleeping = true
	_set_paused(true)
	var fade := ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_STOP
	_ui_root.add_child(fade)
	var t := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	t.tween_property(fade, "color:a", 1.0, 0.45)
	await t.finished
	if _world != null:
		mid.call()
	var t2 := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	t2.tween_property(fade, "color:a", 0.0, 0.5)
	await t2.finished
	fade.queue_free()
	_sleeping = false
	if _world != null:
		_set_paused(false)
	if after.is_valid():
		after.call()


func _do_sleep() -> void:
	_run_fade(_sleep_mid, _sleep_after)


func _sleep_mid() -> void:
	TimeSystem.sleep_until_morning()
	if GameState.hardcore:
		GameState.hunger = maxf(0.0, GameState.hunger - 22.0)
		GameState.sanity = minf(100.0, GameState.sanity + 45.0)
		GameState.health = minf(100.0, GameState.health + 20.0)
		EventBus.stats_changed.emit()
	if _world != null:
		SaveSystem.save_game(_world)


func _sleep_after() -> void:
	EventBus.message.emit("Доброе утро! День %d" % TimeSystem.day)


# ---------------------------------------------------------------- рюкзак, костёр, смерть

func _on_backpack() -> void:
	if _busy():
		return
	_set_paused(true)
	var b := BackpackPanel.new()
	_overlay = b
	b.closed.connect(_close_overlay)
	_ui_root.add_child(b)


func _on_campfire(fire: Node) -> void:
	if _busy():
		return
	_set_paused(true)
	var c := CampfirePanel.new()
	c.setup(fire)
	_overlay = c
	c.closed.connect(_close_overlay)
	_ui_root.add_child(c)


func _on_player_died() -> void:
	if _world == null or _sleeping:
		return
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null
	if _pause != null:
		_pause.queue_free()
		_pause = null
	_set_paused(true)
	var d := DialogBox.new()
	d.setup("Конец дня", ["Свинка теряет сознание...", "Голод, холод или волчьи клыки взяли своё. Но утро всё равно наступит.", "Ты очнёшься дома. Часть вещей и монет потеряна."], ["Очнуться дома"])
	_ui_root.add_child(d)
	_overlay = d
	d.chosen.connect(_on_dialog_choice.bind("respawn"))


func _respawn_mid() -> void:
	TimeSystem.sleep_until_morning()
	if _world != null:
		_world.respawn_at_home()
		_world.survival.respawn()


func _respawn_after() -> void:
	EventBus.message.emit("Ты очнулась дома. Будь осторожнее!")
