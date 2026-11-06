extends Control
## Меню строительства: выбор постройки, затем размещение в мире.

signal chosen(kind: String)
signal closed

const UiTheme := preload("res://scripts/ui/ui_theme.gd")
const Buildings := preload("res://scripts/world/buildings.gd")

var indoors: bool = false


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	theme = UiTheme.shared()
	var body := UiTheme.window(self, 340, 218, "Обустройство дома" if indoors else "Стройка")
	var hint := UiTheme.label("Поставить: кнопка действия. Разобрать: топором.", UiTheme.MUTED, 9)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(hint)
	var sc := UiTheme.scroll_list(Vector2(312, 138))
	body.add_child(sc[0])
	var list: VBoxContainer = sc[1]
	for kind in Buildings.available(indoors):
		_row(list, str(kind))
	var close := UiTheme.close_button()
	close.pressed.connect(func() -> void:
		AudioManager.play("ui_click", 0.0)
		closed.emit())
	body.add_child(close)


func _row(parent: Node, kind: String) -> void:
	var def: Dictionary = Buildings.DEFS[kind]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)
	var icon := TextureRect.new()
	var full: Texture2D = load("res://assets/objects/%s.png" % def["tex"])
	if def.has("frames"):
		var at := AtlasTexture.new()
		at.atlas = full
		at.region = Rect2(0, 0, full.get_width() / float(def["frames"]), full.get_height())
		icon.texture = at
	else:
		icon.texture = full
	icon.custom_minimum_size = Vector2(32, 32)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 0)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	info.add_child(UiTheme.label(str(def["name"]), UiTheme.TEXT, 10))
	var ok := Buildings.can_afford(kind)
	var cost := UiTheme.label(Buildings.cost_text(kind), UiTheme.GOOD if ok else UiTheme.BAD, 9)
	info.add_child(cost)
	var b := Button.new()
	b.text = "Выбрать"
	b.custom_minimum_size = Vector2(68, 20)
	b.disabled = not ok
	b.pressed.connect(func() -> void:
		AudioManager.play("ui_click", 0.0)
		chosen.emit(kind))
	row.add_child(b)
