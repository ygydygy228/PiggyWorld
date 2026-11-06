extends Control
## Костёр: подбросить дерево и приготовить еду.

signal closed

const COOK := {"meat": "cooked_meat", "egg": "fried_egg", "carrot": "roasted_carrot", "turnip": "roasted_turnip"}

var fire = null
var _fuel: Label
var _list: VBoxContainer


func setup(obj) -> void:
	fire = obj


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
	title.text = "Костёр"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)
	_fuel = Label.new()
	_fuel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_fuel)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 4)
	_list.custom_minimum_size = Vector2(300, 0)
	root.add_child(_list)
	var close := Button.new()
	close.text = "Закрыть"
	close.pressed.connect(func() -> void:
		AudioManager.play("ui_click", 0.0)
		closed.emit())
	root.add_child(close)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	_refresh()


func _refresh() -> void:
	if fire == null or not is_instance_valid(fire):
		closed.emit()
		return
	var lit: bool = fire.fuel > 0.0
	if lit:
		_fuel.text = "Огонь горит ещё %d:%02d" % [int(fire.fuel) / 60, int(fire.fuel) % 60]
	else:
		_fuel.text = "Костёр потух. Подбрось дерево!"
	for c in _list.get_children():
		c.queue_free()
	var wood := Button.new()
	wood.text = "Подбросить дерево (+1:30), есть: %d" % GameState.count("wood")
	wood.disabled = GameState.count("wood") <= 0
	wood.pressed.connect(_add_wood)
	_list.add_child(wood)
	var head := Label.new()
	head.text = "Готовка" if lit else "Готовка (нужен огонь)"
	head.add_theme_color_override("font_color", Color("#ffd26a"))
	_list.add_child(head)
	var any := false
	for raw in COOK:
		var key := str(raw)
		if GameState.count(key) <= 0:
			continue
		any = true
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		_list.add_child(row)
		var icon := TextureRect.new()
		icon.texture = GameState.item_icon(str(COOK[raw]))
		icon.custom_minimum_size = Vector2(16, 16)
		row.add_child(icon)
		var l := Label.new()
		l.text = "%s x%d  >  %s" % [GameState.item_name(key), GameState.count(key), GameState.item_name(str(COOK[raw]))]
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		var b := Button.new()
		b.text = "Готовить"
		b.custom_minimum_size = Vector2(66, 20)
		b.disabled = not lit
		b.pressed.connect(_cook.bind(key))
		row.add_child(b)
	if not any:
		var none := Label.new()
		none.text = "Нечего готовить: нужны мясо, яйца, морковь или репа"
		none.add_theme_color_override("font_color", Color("#b89c78"))
		_list.add_child(none)


func _add_wood() -> void:
	if fire != null and GameState.remove_item("wood", 1):
		fire.add_fuel(90.0)
		AudioManager.play("plant")
	_refresh()


func _cook(raw: String) -> void:
	if fire == null or fire.fuel <= 0.0:
		return
	if GameState.remove_item(raw, 1):
		var cooked := str(COOK[raw])
		GameState.add_item(cooked, 1)
		AudioManager.play("pickup")
		EventBus.message.emit("+1 %s" % GameState.item_name(cooked))
	_refresh()
