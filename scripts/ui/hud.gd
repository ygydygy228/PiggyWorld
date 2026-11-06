extends CanvasLayer
## Игровой интерфейс: монеты, время, ресурсы, показатели, панель инструментов, сообщения.

signal menu_requested

const UiTheme := preload("res://scripts/ui/ui_theme.gd")
const RESOURCES: Array[String] = ["wood", "stone", "berries", "flower", "carrot", "turnip", "pumpkin", "egg", "milk", "wool"]

var _money: Label
var _date: Label
var _clock: Label
var _toast: Label
var _toast_panel: PanelContainer
var _slots: Array[Button] = []
var _slot_counts: Array[Label] = []
var _res_labels: Dictionary = {}
var _res_rows: Dictionary = {}
var _res_panel: PanelContainer
var _toast_tween: Tween
var _cancel: Button
var _stats_panel: PanelContainer
var _stats: Dictionary = {}
var _sanity_overlay: ColorRect
var _hurt_overlay: ColorRect


const UI_SIZE := Vector2(480, 270)
const UI_SCALE := 2.0


func _ready() -> void:
	layer = 10
	transform = Transform2D(Vector2(UI_SCALE, 0), Vector2(0, UI_SCALE), Vector2.ZERO)
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.size = UI_SIZE
	root.theme = UiTheme.shared()
	_build_vignette(root)
	_build_overlays(root)
	_build_top(root)
	_build_hotbar(root)
	_build_messages(root)
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


func _build_vignette(root: Control) -> void:
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0))
	g.set_color(1, Color(0.04, 0.02, 0.02, 0.42))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.02, 0.5)
	tex.width = 160
	tex.height = 160
	var v := TextureRect.new()
	v.texture = tex
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	v.stretch_mode = TextureRect.STRETCH_SCALE
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(v)


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


func _build_top(root: Control) -> void:
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 4
	row.offset_top = 4
	row.offset_right = -4
	row.offset_bottom = -4
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(row)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 4)
	left.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	left.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(left)

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiTheme.box(Color(0.17, 0.11, 0.09, 0.82), UiTheme.BORDER, 4.0, 1))
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	card.add_child(v)
	var money_row := HBoxContainer.new()
	money_row.add_theme_constant_override("separation", 3)
	money_row.add_child(UiTheme.icon("coin", 14))
	_money = UiTheme.label("0", UiTheme.GOLD, 13)
	money_row.add_child(_money)
	v.add_child(money_row)
	_date = UiTheme.label("", UiTheme.TEXT, 10)
	v.add_child(_date)
	_clock = UiTheme.label("", UiTheme.MUTED, 10)
	v.add_child(_clock)

	_stats_panel = PanelContainer.new()
	_stats_panel.add_theme_stylebox_override("panel", UiTheme.box(Color(0.17, 0.11, 0.09, 0.82), UiTheme.BORDER, 4.0, 1))
	_stats_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(_stats_panel)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 2)
	_stats_panel.add_child(sv)
	_stat_row(sv, "health", "stat_health", UiTheme.BAD)
	_stat_row(sv, "hunger", "stat_food", Color("#e8903a"))
	_stat_row(sv, "sanity", "stat_sanity", UiTheme.VIOLET)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 4)
	right.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	right.size_flags_horizontal = Control.SIZE_SHRINK_END
	row.add_child(right)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 3)
	buttons.alignment = BoxContainer.ALIGNMENT_END
	right.add_child(buttons)
	var menu := UiTheme.icon_button("ui_menu", 26, "Меню")
	menu.pressed.connect(func() -> void:
		AudioManager.play("ui_click", 0.0)
		menu_requested.emit())
	buttons.add_child(menu)
	var build := UiTheme.icon_button("ui_build", 26, "Строить")
	build.pressed.connect(func() -> void:
		AudioManager.play("ui_click", 0.0)
		EventBus.build_menu_requested.emit())
	buttons.add_child(build)
	var bag := UiTheme.icon_button("ui_bag", 26, "Рюкзак")
	bag.pressed.connect(func() -> void:
		AudioManager.play("ui_click", 0.0)
		EventBus.backpack_requested.emit())
	buttons.add_child(bag)

	_res_panel = PanelContainer.new()
	_res_panel.add_theme_stylebox_override("panel", UiTheme.box(Color(0.17, 0.11, 0.09, 0.82), UiTheme.BORDER, 4.0, 1))
	_res_panel.size_flags_horizontal = Control.SIZE_SHRINK_END
	right.add_child(_res_panel)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 1)
	_res_panel.add_child(grid)
	for id in RESOURCES:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 2)
		h.add_child(UiTheme.icon(id, 14))
		var l := UiTheme.label("0", UiTheme.TEXT, 10)
		l.custom_minimum_size = Vector2(16, 0)
		h.add_child(l)
		grid.add_child(h)
		_res_labels[id] = l
		_res_rows[id] = h


func _stat_row(parent: Node, key: String, icon_id: String, color: Color) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	parent.add_child(row)
	row.add_child(UiTheme.icon(icon_id, 12))
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(54, 6)
	bar.max_value = 100.0
	bar.show_percentage = false
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_theme_stylebox_override("fill", UiTheme.box(color, color, 0.0, 0))
	bar.add_theme_stylebox_override("background", UiTheme.box(Color("#1d1310"), Color("#6a5a48"), 0.0, 1))
	row.add_child(bar)
	var value := UiTheme.label("100", UiTheme.TEXT, 10)
	value.custom_minimum_size = Vector2(20, 0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value)
	_stats[key] = {"bar": bar, "label": value, "color": color}


func _build_hotbar(root: Control) -> void:
	var bar := HBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_top = -36
	bar.offset_bottom = -4
	bar.offset_left = 4
	bar.offset_right = -4
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_theme_constant_override("separation", 3)
	root.add_child(bar)
	for i in range(GameState.TOOLS.size()):
		var id: String = GameState.TOOLS[i]
		var b := Button.new()
		b.custom_minimum_size = Vector2(32, 32)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.icon = GameState.item_icon(id)
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.pressed.connect(GameState.select_tool.bind(i))
		bar.add_child(b)
		var c := UiTheme.label("", UiTheme.TEXT, 9)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(c)
		c.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 2)
		c.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		c.grow_vertical = Control.GROW_DIRECTION_BEGIN
		_slots.append(b)
		_slot_counts.append(c)


func _build_messages(root: Control) -> void:
	var stack := VBoxContainer.new()
	stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.offset_top = 30
	stack.alignment = BoxContainer.ALIGNMENT_BEGIN
	stack.add_theme_constant_override("separation", 4)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(stack)

	_toast_panel = PanelContainer.new()
	_toast_panel.add_theme_stylebox_override("panel", UiTheme.box(Color(0.17, 0.11, 0.09, 0.9), UiTheme.BORDER_DIM, 4.0, 1))
	_toast_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_panel.modulate.a = 0.0
	stack.add_child(_toast_panel)
	_toast = UiTheme.label("", UiTheme.TEXT, 10)
	_toast_panel.add_child(_toast)

	_cancel = Button.new()
	_cancel.text = "Отмена стройки"
	_cancel.visible = false
	_cancel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_cancel.pressed.connect(func() -> void:
		AudioManager.play("ui_click", 0.0)
		EventBus.placement_cancel_requested.emit())
	stack.add_child(_cancel)
	EventBus.placement_changed.connect(func(active: bool, _k: String) -> void: _cancel.visible = active)


func show_toast(text: String) -> void:
	if _toast == null:
		return
	_toast.text = text
	_toast_panel.modulate.a = 1.0
	if _toast_tween != null:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.8)
	_toast_tween.tween_property(_toast_panel, "modulate:a", 0.0, 0.6)


func _refresh() -> void:
	if _money == null:
		return
	_money.text = str(GameState.money)
	_date.text = "День %d · %s" % [TimeSystem.day, TimeSystem.season_name()]
	_clock.text = "%s · %s" % [TimeSystem.clock_text(), TimeSystem.weather_name()]
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
			_slots[i].add_theme_stylebox_override("normal", UiTheme.box(Color("#8a6a3a"), UiTheme.GOLD, 5.0, 2))
		else:
			_slots[i].remove_theme_stylebox_override("normal")
	_refresh_stats()


func _refresh_stats() -> void:
	if _stats_panel == null:
		return
	_stats_panel.visible = GameState.hardcore
	for key in _stats:
		var entry: Dictionary = _stats[key]
		var value := 0.0
		match key:
			"health": value = GameState.health
			"hunger": value = GameState.hunger
			"sanity": value = GameState.sanity
		var bar: ProgressBar = entry["bar"]
		var label: Label = entry["label"]
		bar.value = value
		label.text = str(roundi(value))
		var col: Color = entry["color"]
		label.add_theme_color_override("font_color", col if value > 35.0 else UiTheme.BAD)


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
