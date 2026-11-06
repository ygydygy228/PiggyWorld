extends Control
## Рюкзак: вещи (съесть, применить) и крафт.

signal closed

const Crafting := preload("res://scripts/world/crafting.gd")

var _tab: String = "items"
var _list: VBoxContainer
var _stats: Label
var _items_tab: Button
var _craft_tab: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel := PanelContainer.new()
	add_child(panel)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 5)
	panel.add_child(root)
	var title := Label.new()
	title.text = "Рюкзак"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)
	_stats = Label.new()
	_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stats.add_theme_color_override("font_color", Color("#ffd26a"))
	root.add_child(_stats)
	var tabs := HBoxContainer.new()
	root.add_child(tabs)
	_items_tab = _make_tab(tabs, "Вещи", "items")
	_craft_tab = _make_tab(tabs, "Крафт", "craft")
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(350, 150)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 3)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	var close := Button.new()
	close.text = "Закрыть"
	close.pressed.connect(func() -> void:
		AudioManager.play("ui_click", 0.0)
		closed.emit())
	root.add_child(close)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	_refresh()


func _make_tab(parent: Node, text: String, tab: String) -> Button:
	var b := Button.new()
	b.text = text
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.toggle_mode = true
	b.pressed.connect(func() -> void:
		_tab = tab
		AudioManager.play("ui_click", 0.0)
		_refresh())
	parent.add_child(b)
	return b


func _refresh() -> void:
	_items_tab.button_pressed = _tab == "items"
	_craft_tab.button_pressed = _tab == "craft"
	if GameState.hardcore:
		_stats.text = "Здоровье %d   Сытость %d   Рассудок %d" % [roundi(GameState.health), roundi(GameState.hunger), roundi(GameState.sanity)]
		_stats.visible = true
	else:
		_stats.visible = false
	for c in _list.get_children():
		c.queue_free()
	if _tab == "items":
		_fill_items()
	else:
		_fill_recipes()


func _row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_list.add_child(row)
	return row


func _icon(parent: Node, id: String) -> void:
	var icon := TextureRect.new()
	icon.texture = GameState.item_icon(id)
	icon.custom_minimum_size = Vector2(16, 16)
	parent.add_child(icon)


func _fill_items() -> void:
	var any := false
	for id in GameState.ITEMS:
		var key := str(id)
		if GameState.TOOLS.has(key) or GameState.count(key) <= 0:
			continue
		any = true
		var def: Dictionary = GameState.ITEMS[key]
		var row := _row()
		_icon(row, key)
		var name_label := Label.new()
		var txt := "%s x%d" % [GameState.item_name(key), GameState.count(key)]
		if key == "spear":
			txt = "Копьё (ударов: %d)" % GameState.spear_uses
		name_label.text = txt
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		if GameState.hardcore and GameState.is_perishable(key):
			var fl := Label.new()
			var f := GameState.freshness(key)
			fl.text = "свежее" if f > 0.66 else ("несвежее" if f > 0.33 else "гниёт")
			fl.add_theme_color_override("font_color", Color("#9fd78a") if f > 0.66 else (Color("#e8c868") if f > 0.33 else Color("#d98a8a")))
			row.add_child(fl)
		if def.has("food") or def.has("heal"):
			var b := Button.new()
			b.text = "Применить" if def.has("heal") else "Съесть"
			b.custom_minimum_size = Vector2(70, 20)
			b.pressed.connect(_use.bind(key))
			row.add_child(b)
	if not any:
		var l := Label.new()
		l.text = "Рюкзак пуст"
		_list.add_child(l)


func _use(id: String) -> void:
	var def: Dictionary = GameState.ITEMS[id]
	if def.has("heal"):
		if GameState.remove_item(id, 1):
			GameState.heal(float(def["heal"]))
			AudioManager.play("pickup")
			EventBus.message.emit("+%d здоровья" % int(def["heal"]))
	elif GameState.eat(id):
		AudioManager.play("eat")
		EventBus.message.emit("Вкусно!")
	_refresh()


func _fill_recipes() -> void:
	for r in Crafting.RECIPES:
		var row := _row()
		_icon(row, str(r["icon"]))
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		var n := Label.new()
		n.text = str(r["name"])
		info.add_child(n)
		var d := Label.new()
		d.text = "%s. Нужно: %s" % [str(r["desc"]), Crafting.cost_text(r)]
		d.add_theme_color_override("font_color", Color("#9fd78a") if Crafting.can_craft(r) else Color("#d98a8a"))
		info.add_child(d)
		var b := Button.new()
		b.text = "Сделать"
		b.custom_minimum_size = Vector2(70, 22)
		b.disabled = not Crafting.can_craft(r)
		b.pressed.connect(_craft.bind(r))
		row.add_child(b)


func _craft(r: Dictionary) -> void:
	if Crafting.craft(r):
		AudioManager.play("build")
	else:
		AudioManager.play("error")
	_refresh()
