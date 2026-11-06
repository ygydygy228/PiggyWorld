extends Control
## Меню строительства: выбор постройки, затем размещение в мире.

signal chosen(kind: String)
signal closed

const Buildings := preload("res://scripts/world/buildings.gd")

var indoors: bool = false


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
	title.text = "Обустройство дома" if indoors else "Стройка"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)
	var hint := Label.new()
	hint.text = "Поставить: кнопка действия. Разобрать: топором."
	hint.add_theme_color_override("font_color", Color("#b89c78"))
	root.add_child(hint)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(330, 150)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 4)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for kind in Buildings.available(indoors):
		_row(list, str(kind))
	var close := Button.new()
	close.text = "Закрыть"
	close.pressed.connect(func() -> void:
		AudioManager.play("ui_click", 0.0)
		closed.emit())
	root.add_child(close)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)


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
	icon.custom_minimum_size = Vector2(34, 34)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	var name_label := Label.new()
	name_label.text = str(def["name"])
	info.add_child(name_label)
	var cost := Label.new()
	cost.text = Buildings.cost_text(kind)
	var ok := Buildings.can_afford(kind)
	cost.add_theme_color_override("font_color", Color("#9fd78a") if ok else Color("#d98a8a"))
	info.add_child(cost)
	var b := Button.new()
	b.text = "Выбрать"
	b.custom_minimum_size = Vector2(72, 22)
	b.disabled = not ok
	b.pressed.connect(func() -> void:
		AudioManager.play("ui_click", 0.0)
		chosen.emit(kind))
	row.add_child(b)
