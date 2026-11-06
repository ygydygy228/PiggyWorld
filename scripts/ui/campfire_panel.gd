extends Control
## Костёр: подбросить дерево и приготовить еду.

signal closed

const UiTheme := preload("res://scripts/ui/ui_theme.gd")

const COOK := {"meat": "cooked_meat", "egg": "fried_egg", "carrot": "roasted_carrot", "turnip": "roasted_turnip"}

var fire = null
var _fuel: Label
var _list: VBoxContainer


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS


func setup(obj) -> void:
	fire = obj


func _ready() -> void:
	theme = UiTheme.shared()
	var body := UiTheme.window(self, 306, 0, "Костёр")
	_fuel = UiTheme.label("", UiTheme.GOLD, 10)
	_fuel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(_fuel)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 3)
	_list.custom_minimum_size = Vector2(286, 0)
	body.add_child(_list)
	var close := UiTheme.close_button()
	close.pressed.connect(func() -> void:
		AudioManager.play("ui_click", 0.0)
		closed.emit())
	body.add_child(close)
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
		_fuel.add_theme_color_override("font_color", UiTheme.BAD)
	for c in _list.get_children():
		c.queue_free()
	var wood := Button.new()
	wood.text = "Подбросить дерево (+1:30), есть: %d" % GameState.count("wood")
	wood.disabled = GameState.count("wood") <= 0
	wood.pressed.connect(_add_wood)
	_list.add_child(wood)
	var head := UiTheme.label("Готовка" if lit else "Готовка (нужен огонь)", UiTheme.GOLD, 10)
	_list.add_child(head)
	var any := false
	for raw in COOK:
		var key := str(raw)
		if GameState.count(key) <= 0:
			continue
		any = true
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 5)
		_list.add_child(row)
		row.add_child(UiTheme.icon(str(COOK[raw]), 16))
		var l := UiTheme.label("%s x%d → %s" % [GameState.item_name(key), GameState.count(key), GameState.item_name(str(COOK[raw]))], UiTheme.TEXT, 10)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		var b := Button.new()
		b.text = "Готовить"
		b.custom_minimum_size = Vector2(62, 18)
		b.disabled = not lit
		b.pressed.connect(_cook.bind(key))
		row.add_child(b)
	if not any:
		_list.add_child(UiTheme.label("Нечего готовить: нужны мясо, яйца, морковь или репа", UiTheme.MUTED, 9))


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
