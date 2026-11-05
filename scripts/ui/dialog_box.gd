extends Control
## Окно диалога: печатает текст, по нажатию листает реплики.

signal finished

var speaker: String = ""
var lines: Array = []
var _index: int = 0
var _label: Label
var _typing: bool = true
var _chars: float = 0.0
var _born: int = 0


func setup(p_speaker: String, p_lines: Array) -> void:
	speaker = p_speaker
	lines = p_lines


func _ready() -> void:
	_born = Time.get_ticks_msec()
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	var name_label := Label.new()
	name_label.text = speaker
	name_label.add_theme_color_override("font_color", Color("#ffd26a"))
	box.add_child(name_label)
	_label = Label.new()
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.custom_minimum_size = Vector2(300, 40)
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(_label)
	var hint := Label.new()
	hint.text = "нажми, чтобы продолжить"
	hint.add_theme_color_override("font_color", Color("#b89c78"))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(hint)
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.offset_left = 10
	panel.offset_right = -10
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.offset_top = -92
	panel.offset_bottom = -8
	_show_line()


func _show_line() -> void:
	_label.text = str(lines[_index])
	_label.visible_characters = 0
	_chars = 0.0
	_typing = true


func _process(delta: float) -> void:
	if _typing:
		_chars += delta * 45.0
		_label.visible_characters = int(_chars)
		if int(_chars) >= _label.text.length():
			_typing = false
			_label.visible_characters = -1


func _advance() -> void:
	if Time.get_ticks_msec() - _born < 250:
		return
	AudioManager.play("ui_click", 0.0, 0.6)
	if _typing:
		_typing = false
		_label.visible_characters = -1
		return
	_index += 1
	if _index >= lines.size():
		finished.emit()
		queue_free()
	else:
		_show_line()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_advance()
			accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("act"):
		_advance()
		get_viewport().set_input_as_handled()
