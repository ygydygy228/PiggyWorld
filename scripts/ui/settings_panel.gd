extends PanelContainer
## Настройки громкости (шаг 10%).

signal closed

var _music_label: Label
var _sfx_label: Label


func _ready() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	add_child(box)
	var title := Label.new()
	title.text = "Настройки"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	_music_label = _row(box, "Музыка", true)
	_sfx_label = _row(box, "Звуки", false)
	var back := Button.new()
	back.text = "Назад"
	back.pressed.connect(func() -> void:
		AudioManager.play("ui_click", 0.0)
		closed.emit())
	box.add_child(back)
	_refresh()


func _row(parent: Node, caption: String, is_music: bool) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)
	var name_label := Label.new()
	name_label.text = caption
	name_label.custom_minimum_size = Vector2(60, 0)
	row.add_child(name_label)
	var minus := Button.new()
	minus.text = "-"
	minus.custom_minimum_size = Vector2(24, 20)
	minus.pressed.connect(_step.bind(is_music, -0.1))
	row.add_child(minus)
	var value := Label.new()
	value.custom_minimum_size = Vector2(36, 0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(value)
	var plus := Button.new()
	plus.text = "+"
	plus.custom_minimum_size = Vector2(24, 20)
	plus.pressed.connect(_step.bind(is_music, 0.1))
	row.add_child(plus)
	return value


func _step(is_music: bool, delta: float) -> void:
	var m := AudioManager.music_volume
	var s := AudioManager.sfx_volume
	if is_music:
		m += delta
	else:
		s += delta
	AudioManager.set_volumes(m, s)
	AudioManager.play("ui_click", 0.0)
	_refresh()


func _refresh() -> void:
	_music_label.text = "%d%%" % roundi(AudioManager.music_volume * 100.0)
	_sfx_label.text = "%d%%" % roundi(AudioManager.sfx_volume * 100.0)
