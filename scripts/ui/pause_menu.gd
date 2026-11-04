extends Control
## Меню паузы: продолжить, сохранить, настройки, выход в главное меню.

signal resume_requested
signal save_requested
signal menu_requested

const SettingsPanel := preload("res://scripts/ui/settings_panel.gd")

var _box: VBoxContainer
var _settings: PanelContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel := PanelContainer.new()
	add_child(panel)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 6)
	panel.add_child(_box)
	var title := Label.new()
	title.text = "Пауза"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(title)
	_add("Продолжить", func() -> void: resume_requested.emit())
	_add("Сохранить игру", func() -> void: save_requested.emit())
	_add("Настройки", _open_settings)
	_add("В главное меню", func() -> void: menu_requested.emit())
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	_settings = SettingsPanel.new()
	_settings.visible = false
	_settings.closed.connect(func() -> void:
		_settings.visible = false
		panel.visible = true)
	add_child(_settings)
	_settings.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)


func _add(text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(150, 24)
	b.pressed.connect(func() -> void:
		AudioManager.play("ui_click", 0.0)
		cb.call())
	_box.add_child(b)


func _open_settings() -> void:
	_box.get_parent().visible = false
	_settings.visible = true
