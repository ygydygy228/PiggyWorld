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


func _ready() -> void:
	layer = 10
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_top_left(root)
	_build_top_right(root)
	_build_hotbar(root)
	_build_toast(root)
	EventBus.money_changed.connect(func(_m: int) -> void: _refresh())
	EventBus.inventory_changed.connect(_refresh)
	EventBus.tool_changed.connect(func(_i: int) -> void: _refresh())
	EventBus.clock_changed.connect(func(_d: int, _h: int, _m: int) -> void: _refresh())
	EventBus.weather_changed.connect(func(_k: String) -> void: _refresh())
	EventBus.day_started.connect(func(_d: int) -> void: _refresh())
	EventBus.message.connect(show_toast)
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
