extends Control
## Рюкзак: вещи (съесть, применить) и крафт.

signal closed

const UiTheme := preload("res://scripts/ui/ui_theme.gd")
const Crafting := preload("res://scripts/world/crafting.gd")

var _tab: String = "items"
var _list: VBoxContainer
var _stats: HBoxContainer
var _items_tab: Button
var _craft_tab: Button
var _money: Label


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	theme = UiTheme.shared()
	var body := UiTheme.window(self, 330, 190, "")
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	body.add_child(head)
	var title := UiTheme.label("Рюкзак", UiTheme.GOLD, 13)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(UiTheme.icon("coin", 14))
	_money = UiTheme.label("0", UiTheme.GOLD, 11)
	head.add_child(_money)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	body.add_child(tabs)
	_items_tab = _make_tab(tabs, "Вещи", "items")
	_craft_tab = _make_tab(tabs, "Крафт", "craft")

	var sc := UiTheme.scroll_list(Vector2(304, 104))
	body.add_child(sc[0])
	_list = sc[1]

	_stats = HBoxContainer.new()
	_stats.add_theme_constant_override("separation", 8)
	body.add_child(_stats)
	_stat_chip("stat_health", "ЗД")
	_stat_chip("stat_food", "ЕДА")
	_stat_chip("stat_sanity", "РАЗ")

	var close := UiTheme.close_button()
	close.pressed.connect(func() -> void:
		AudioManager.play("ui_click", 0.0)
		closed.emit())
	body.add_child(close)
	_refresh()


func _stat_chip(icon_id: String, _hint: String) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 2)
	h.add_child(UiTheme.icon(icon_id, 12))
	var l := UiTheme.label("", UiTheme.TEXT, 10)
	l.name = icon_id
	h.add_child(l)
	_stats.add_child(h)


func _make_tab(parent: Node, text: String, tab: String) -> Button:
	var b := Button.new()
	b.text = text
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.toggle_mode = true
	b.custom_minimum_size = Vector2(0, 20)
	b.pressed.connect(func() -> void:
		_tab = tab
		AudioManager.play("ui_click", 0.0)
		_refresh())
	parent.add_child(b)
	return b


func _refresh() -> void:
	_items_tab.button_pressed = _tab == "items"
	_craft_tab.button_pressed = _tab == "craft"
	_money.text = str(GameState.money)
	_stats.visible = GameState.hardcore
	if GameState.hardcore:
		_chip_value("stat_health", str(roundi(GameState.health)))
		_chip_value("stat_food", str(roundi(GameState.hunger)))
		_chip_value("stat_sanity", str(roundi(GameState.sanity)))
	for c in _list.get_children():
		c.queue_free()
	if _tab == "items":
		_fill_items()
	else:
		_fill_recipes()


func _chip_value(icon_id: String, text: String) -> void:
	for h in _stats.get_children():
		for l in h.get_children():
			if l is Label and l.name == icon_id:
				(l as Label).text = text


func _row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	_list.add_child(row)
	return row


func _fill_items() -> void:
	var any := false
	for id in GameState.ITEMS:
		var key := str(id)
		if GameState.TOOLS.has(key) or GameState.count(key) <= 0:
			continue
		any = true
		var def: Dictionary = GameState.ITEMS[key]
		var row := _row()
		row.add_child(UiTheme.icon(key, 16))
		var name_label := UiTheme.label("", UiTheme.TEXT, 10)
		var txt := "%s x%d" % [GameState.item_name(key), GameState.count(key)]
		if key == "spear":
			txt = "Копьё (ударов: %d)" % GameState.spear_uses
		name_label.text = txt
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		if GameState.hardcore and GameState.is_perishable(key):
			var fl := UiTheme.label("", UiTheme.MUTED, 9)
			var f := GameState.freshness(key)
			fl.text = "свежее" if f > 0.66 else ("несвежее" if f > 0.33 else "гниёт")
			fl.add_theme_color_override("font_color", UiTheme.GOOD if f > 0.66 else (UiTheme.GOLD if f > 0.33 else UiTheme.BAD))
			row.add_child(fl)
		if def.has("food") or def.has("heal"):
			var b := Button.new()
			b.text = "Применить" if def.has("heal") else "Съесть"
			b.custom_minimum_size = Vector2(66, 18)
			b.pressed.connect(_use.bind(key))
			row.add_child(b)
	if not any:
		_list.add_child(UiTheme.label("Рюкзак пуст", UiTheme.MUTED, 10))


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
		row.add_child(UiTheme.icon(str(r["icon"]), 16))
		var info := VBoxContainer.new()
		info.add_theme_constant_override("separation", 0)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		info.add_child(UiTheme.label(str(r["name"]), UiTheme.TEXT, 10))
		var d := UiTheme.label("%s · %s" % [str(r["desc"]), Crafting.cost_text(r)], UiTheme.MUTED, 9)
		d.add_theme_color_override("font_color", UiTheme.GOOD if Crafting.can_craft(r) else UiTheme.BAD)
		info.add_child(d)
		var b := Button.new()
		b.text = "Сделать"
		b.custom_minimum_size = Vector2(64, 20)
		b.disabled = not Crafting.can_craft(r)
		b.pressed.connect(_craft.bind(r))
		row.add_child(b)


func _craft(r: Dictionary) -> void:
	if Crafting.craft(r):
		AudioManager.play("build")
	else:
		AudioManager.play("error")
	_refresh()
