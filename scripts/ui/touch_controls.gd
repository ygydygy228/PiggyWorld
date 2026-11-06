extends CanvasLayer
## Сенсорное управление: плавающий джойстик слева, кнопки справа. Поддерживает мультитач.

const RAD_ACTION := 30.0
const RAD_SMALL := 18.0
const JOY_RADIUS := 36.0
const DEADZONE := 0.15

var player = null
var enabled: bool = true : set = _set_enabled
var _canvas: Control
var _touches: Dictionary = {}
var _joy_origin: Vector2 = Vector2.ZERO
var _joy_pos: Vector2 = Vector2.ZERO
var _joy_active: bool = false
var _visible_ui: bool = false


func _ready() -> void:
	layer = 9
	_visible_ui = OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_canvas)
	_canvas.draw.connect(_draw_ui)


func _set_enabled(v: bool) -> void:
	enabled = v
	if not v:
		_release_all()


func _release_all() -> void:
	_touches.clear()
	_joy_active = false
	if player != null:
		player.move_input = Vector2.ZERO
		player.run_held = false


func _vs() -> Vector2:
	return get_viewport().get_visible_rect().size


func _centers() -> Dictionary:
	var vs := _vs()
	return {
		"action": Vector2(vs.x - 50.0, vs.y - 54.0),
		"tool": Vector2(vs.x - 108.0, vs.y - 30.0),
		"run": Vector2(vs.x - 30.0, vs.y - 112.0),
	}


func _radius(role: String) -> float:
	return RAD_ACTION if role == "action" else RAD_SMALL


func _process(_delta: float) -> void:
	if _visible_ui:
		_canvas.queue_redraw()


func _input(event: InputEvent) -> void:
	if not _visible_ui or not enabled or player == null:
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			_on_press(t.index, t.position)
		else:
			_on_release(t.index)
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if _touches.get(d.index, "") == "joy":
			_update_joy(d.position)


func _on_press(index: int, pos: Vector2) -> void:
	var centers := _centers()
	for role in centers:
		if pos.distance_to(centers[role]) <= _radius(role) + 6.0:
			_touches[index] = role
			match role:
				"action":
					player.do_action()
				"tool":
					GameState.cycle_tool()
				"run":
					player.run_held = true
			return
	var vs := _vs()
	var on_hotbar := pos.y > vs.y - 40.0 and absf(pos.x - vs.x * 0.5) < 80.0
	if pos.x < vs.x * 0.5 and pos.y > vs.y * 0.25 and not on_hotbar and not _joy_active:
		_touches[index] = "joy"
		_joy_active = true
		_joy_origin = pos
		_joy_pos = pos
		player.move_input = Vector2.ZERO


func _on_release(index: int) -> void:
	var role: String = _touches.get(index, "")
	_touches.erase(index)
	if role == "joy":
		_joy_active = false
		player.move_input = Vector2.ZERO
	elif role == "run":
		player.run_held = false


func _update_joy(pos: Vector2) -> void:
	var v := (pos - _joy_origin).limit_length(JOY_RADIUS)
	_joy_pos = _joy_origin + v
	var n := v / JOY_RADIUS
	player.move_input = n if n.length() > DEADZONE else Vector2.ZERO


func _draw_ui() -> void:
	if not _visible_ui or not enabled:
		return
	var vs := _vs()
	var font := _canvas.get_theme_default_font()
	var fill := Color(0.23, 0.16, 0.14, 0.7)
	var ring := Color(0.91, 0.76, 0.48, 0.9)
	if _joy_active:
		_canvas.draw_circle(_joy_origin, JOY_RADIUS, Color(1, 1, 1, 0.12))
		_canvas.draw_arc(_joy_origin, JOY_RADIUS, 0.0, TAU, 32, Color(1, 1, 1, 0.35), 2.0)
		_canvas.draw_circle(_joy_pos, 14.0, Color(1, 1, 1, 0.4))
	else:
		var hint := Vector2(64.0, vs.y - 64.0)
		_canvas.draw_arc(hint, JOY_RADIUS * 0.8, 0.0, TAU, 32, Color(1, 1, 1, 0.18), 2.0)
	var centers := _centers()
	for role in centers:
		var c: Vector2 = centers[role]
		var r := _radius(role)
		_canvas.draw_circle(c, r, fill)
		_canvas.draw_arc(c, r, 0.0, TAU, 32, ring, 2.0)
	var ac: Vector2 = centers["action"]
	var tex := GameState.item_icon(GameState.current_tool())
	_canvas.draw_texture_rect(tex, Rect2(ac - Vector2(16, 16), Vector2(32, 32)), false)
	var tc: Vector2 = centers["tool"]
	var list := GameState.slots()
	var next_id: String = list[(GameState.selected_tool + 1) % list.size()]
	_canvas.draw_texture_rect(GameState.item_icon(next_id), Rect2(tc - Vector2(8, 8), Vector2(16, 16)), false)
	var rc: Vector2 = centers["run"]
	if font != null:
		_canvas.draw_string(font, rc + Vector2(-9, 4), "Бег", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#fff3d6"))
