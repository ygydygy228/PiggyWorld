extends Control
## Меню паузы: продолжить, сохранить, настройки, выход в главное меню.

signal resume_requested
signal save_requested
signal menu_requested

const UiTheme := preload("res://scripts/ui/ui_theme.gd")
const SettingsPanel := preload("res://scripts/ui/settings_panel.gd")

var _box: VBoxContainer
var _panel: Control
var _settings_layer: CenterContainer
var _settings: PanelContainer


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	theme = UiTheme.shared()
	_box = UiTheme.window(self, 198, 0, "Пауза")
	_panel = _box.get_parent()
	_add("Продолжить", func() -> void: resume_requested.emit())
	_add("Сохранить игру", func() -> void: save_requested.emit())
	_add("Настройки", _open_settings)
	_add("В главное меню", func() -> void: menu_requested.emit())

	_settings_layer = CenterContainer.new()
	_settings_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_settings_layer.visible = false
	add_child(_settings_layer)
	_settings = SettingsPanel.new()
	_settings.closed.connect(func() -> void:
		_settings_layer.visible = false
		_panel.visible = true)
	_settings_layer.add_child(_settings)


func _add(text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(160, 24)
	b.pressed.connect(func() -> void:
		AudioManager.play("ui_click", 0.0)
		cb.call())
	_box.add_child(b)


func _open_settings() -> void:
	_panel.visible = false
	_settings_layer.visible = true
