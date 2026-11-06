extends PanelContainer
## Настройки громкости (шаг 10%).

signal closed

const UiTheme := preload("res://scripts/ui/ui_theme.gd")

var _music_label: Label
var _sfx_label: Label


func _ready() -> void:
	custom_minimum_size = Vector2(200, 132)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	add_child(box)
	var title := UiTheme.label("Настройки", UiTheme.GOLD, 13)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	box.add_child(UiTheme.rule())
	_music_label = _row(box, "Музыка", true)
	_sfx_label = _row(box, "Звуки", false)
	box.add_child(UiTheme.spacer(2))
	var back := UiTheme.close_button("Назад")
	back.pressed.connect(func() -> void:
		AudioManager.play("ui_click", 0.0)
		closed.emit())
	box.add_child(back)
	_refresh()


func _row(parent: Node, caption: String, is_music: bool) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)
	var name_label := UiTheme.label(caption, UiTheme.TEXT, 10)
	name_label.custom_minimum_size = Vector2(62, 0)
	row.add_child(name_label)
	var minus := Button.new()
	minus.text = "-"
	minus.custom_minimum_size = Vector2(26, 20)
	minus.pressed.connect(_step.bind(is_music, -0.1))
	row.add_child(minus)
	var value := UiTheme.label("", UiTheme.GOLD, 10)
	value.custom_minimum_size = Vector2(38, 0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(value)
	var plus := Button.new()
	plus.text = "+"
	plus.custom_minimum_size = Vector2(26, 20)
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
