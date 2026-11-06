extends CanvasLayer
## Игровой интерфейс: деньги, время, ресурсы, панель инструментов, всплывающие сообщения.

signal menu_requested

const UiTheme := preload("res://scripts/ui/ui_theme.gd")
const RESOURCES: Array[String] = ["wood", "stone", "berries", "flower", "carrot", "turnip", "pumpkin", "egg", "milk", "wool"]

var _money: Label
var _date: Label
var _clock: Label
var _toast: Label
var _slots: Array[Button] = []
var _slot_counts: Array[Label] = []
var _res_labels: Dictionary = {}
var _res_rows: Dictionary = {}
var _res_panel: PanelContainer
var _toast_tween: Tween
var _cancel: Button
var _stats_box: VBoxContainer
var _bar_health: ProgressBar
var _bar_hunger: ProgressBar
var _bar_sanity: ProgressBar
var _sanity_overlay: ColorRect
var _hurt_overlay: ColorRect


func _ready() -> void:
	layer = 10
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_overlays(root)
	_build_top_left(root)
	_build_top_right(root)
	_build_hotbar(root)
	_build_toast(root)
	_build_cancel(root)
	EventBus.money_changed.connect(func(_m: int) -> void: _refresh())
	EventBus.inventory_changed.connect(_refresh)
	EventBus.tool_changed.connect(func(_i: int) -> void: _refresh())
	EventBus.clock_changed.connect(func(_d: int, _h: int, _m: int) -> void: _refresh())
	EventBus.weather_changed.connect(func(_k: String) -> void: _refresh())
	EventBus.day_started.connect(func(_d: int) -> void: _refresh())
	EventBus.message.connect(show_toast)
	EventBus.stats_changed.connect(_refresh_stats)
	EventBus.player_hurt.connect(_flash_hurt)
	_refresh()


func _icon(id: String) -> TextureRect:
	var t := TextureRect.new()
	t.texture = GameState.item_icon(id)
	t.custom_minimum_size = Vector2(16, 16)
	t.stretch_mode = TextureRect.STRETCH_KEEP
	return t


func _build_top_left(root: Control) -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(4, 4)
	root.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	panel.add_child(v)
	var row := HBoxContainer.new()
	row.add_child(_icon("coin"))
	_money = Label.new()
	row.add_child(_money)
	v.add_child(row)
	_date = Label.new()
	v.add_child(_date)
	_clock = Label.new()
	v.add_child(_clock)
	_build_stats(v)


func _build_top_right(root: Control) -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	root.add_child(v)
	var menu := Button.new()
	menu.text = "Меню"
	menu.custom_minimum_size = Vector2(0, 22)
	menu.pressed.connect(func() -> void:
		AudioManager.play("ui_click", 0.0)
		menu_requested.emit())
	v.add_child(menu)
	var build := Button.new()
	build.text = "Строить"
	build.custom_minimum_size = Vector2(0, 22)
	build.pressed.connect(func() -> void:
		AudioManager.play("ui_click", 0.0)
		EventBus.build_menu_requested.emit())
	v.add_child(build)
	var bag := Button.new()
	bag.text = "Рюкзак"
	bag.custom_minimum_size = Vector2(0, 22)
	bag.pressed.connect(func() -> void:
		AudioManager.play("ui_click", 0.0)
		EventBus.backpack_requested.emit())
	v.add_child(bag)
	var panel := PanelContainer.new()
	_res_panel = panel
	v.add_child(panel)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	panel.add_child(grid)
	for id in RESOURCES:
		var h := HBoxContainer.new()
		h.add_child(_icon(id))
		var l := Label.new()
		l.custom_minimum_size = Vector2(18, 0)
		h.add_child(l)
		grid.add_child(h)
		_res_labels[id] = l
		_res_rows[id] = h
	v.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 4)
	v.grow_horizontal = Control.GROW_DIRECTION_BEGIN


func _build_hotbar(root: Control) -> void:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 3)
	root.add_child(bar)
	for i in range(GameState.TOOLS.size()):
		var id: String = GameState.TOOLS[i]
		var b := Button.new()
		b.custom_minimum_size = Vector2(28, 28)
		b.icon = GameState.item_icon(id)
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.pressed.connect(GameState.select_tool.bind(i))
		bar.add_child(b)
		var c := Label.new()
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(c)
		c.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 3)
		c.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		c.grow_vertical = Control.GROW_DIRECTION_BEGIN
		_slots.append(b)
		_slot_counts.append(c)
	bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 4)
	bar.grow_horizontal = Control.GROW_DIRECTION_BOTH


func _build_toast(root: Control) -> void:
	_toast = Label.new()
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_toast.offset_top = 34
	_toast.offset_bottom = 52
	_toast.modulate.a = 0.0
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_toast)


func _build_cancel(root: Control) -> void:
	_cancel = Button.new()
	_cancel.text = "Отмена стройки"
	_cancel.visible = false
	_cancel.pressed.connect(func() -> void:
		AudioManager.play("ui_click", 0.0)
		EventBus.placement_cancel_requested.emit())
	root.add_child(_cancel)
	_cancel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 4)
	_cancel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	EventBus.placement_changed.connect(func(active: bool, _k: String) -> void: _cancel.visible = active)


func show_toast(text: String) -> void:
	_toast.text = text
	_toast.modulate.a = 1.0
	if _toast_tween != null:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.8)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.6)


func _refresh() -> void:
	if _money == null:
		return
	_money.text = str(GameState.money)
	_date.text = "День %d  %s" % [TimeSystem.day, TimeSystem.season_name()]
	_clock.text = "%s  %s" % [TimeSystem.clock_text(), TimeSystem.weather_name()]
	var any_res := false
	for id in _res_labels:
		var n := GameState.count(id)
		(_res_labels[id] as Label).text = str(n)
		(_res_rows[id] as Control).visible = n > 0
		any_res = any_res or n > 0
	_res_panel.visible = any_res
	for i in range(_slots.size()):
		var id: String = GameState.TOOLS[i]
		_slot_counts[i].text = str(GameState.count(id)) if id.ends_with("_seed") else ""
		if i == GameState.selected_tool:
			_slots[i].add_theme_stylebox_override("normal", UiTheme.box(Color("#8a6a3a"), Color("#fff3d6"), 4.0))
		else:
			_slots[i].remove_theme_stylebox_override("normal")
	_refresh_stats()


func _build_overlays(root: Control) -> void:
	_sanity_overlay = ColorRect.new()
	_sanity_overlay.color = Color(0.35, 0.1, 0.5, 0.0)
	_sanity_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sanity_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_sanity_overlay)
	_hurt_overlay = ColorRect.new()
	_hurt_overlay.color = Color(0.85, 0.1, 0.1, 0.0)
	_hurt_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hurt_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_hurt_overlay)


func _build_stats(parent: Node) -> void:
	_stats_box = VBoxContainer.new()
	_stats_box.add_theme_constant_override("separation", 2)
	parent.add_child(_stats_box)
	_bar_health = _bar(_stats_box, "ЗД", Color("#d9453f"))
	_bar_hunger = _bar(_stats_box, "ЕДА", Color("#e8903a"))
	_bar_sanity = _bar(_stats_box, "РАЗ", Color("#9a6ad8"))


func _bar(parent: Node, caption: String, color: Color) -> ProgressBar:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	parent.add_child(row)
	var l := Label.new()
	l.text = caption
	l.custom_minimum_size = Vector2(26, 0)
	row.add_child(l)
	var b := ProgressBar.new()
	b.custom_minimum_size = Vector2(64, 8)
	b.max_value = 100.0
	b.show_percentage = false
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.add_theme_stylebox_override("fill", UiTheme.box(color, color, 0.0, 0))
	b.add_theme_stylebox_override("background", UiTheme.box(Color("#2a1d19"), Color("#e8c27a"), 0.0, 1))
	row.add_child(b)
	return b


func _refresh_stats() -> void:
	if _stats_box == null:
		return
	_stats_box.visible = GameState.hardcore
	_bar_health.value = GameState.health
	_bar_hunger.value = GameState.hunger
	_bar_sanity.value = GameState.sanity


func _flash_hurt() -> void:
	_hurt_overlay.color.a = 0.35
	create_tween().tween_property(_hurt_overlay, "color:a", 0.0, 0.35)


func _process(_delta: float) -> void:
	if _sanity_overlay == null:
		return
	var a := 0.0
	if GameState.hardcore and GameState.sanity < 35.0:
		a = clampf((35.0 - GameState.sanity) / 35.0, 0.0, 1.0) * (0.26 + 0.08 * sin(float(Time.get_ticks_msec()) / 400.0))
	_sanity_overlay.color.a = a
