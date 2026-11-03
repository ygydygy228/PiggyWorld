extends Node2D

const VIEW_SIZE := Vector2(480, 270)
const TILE := 24.0
const ISLAND_RADIUS := Vector2(760.0, 570.0)
const PLAYER_SPEED := 112.0
const SAVE_PATH := "user://piggyworld_save.cfg"

var player_pos: Vector2 = Vector2.ZERO
var facing: Vector2 = Vector2.DOWN
var move_vector: Vector2 = Vector2.ZERO
var joystick_vector: Vector2 = Vector2.ZERO
var joystick_touch: int = -1
var joystick_origin: Vector2 = Vector2.ZERO
var move_target: Vector2 = Vector2(-9999, -9999)
var animation_time: float = 0.0
var wood: int = 0
var stone: int = 0
var berries: int = 0
var coins: int = 0
var world_objects: Array[Dictionary] = []
var inventory_label: Label
var message_label: Label
var action_button: Button
var save_timer: float = 0.0

func _ready() -> void:
    _configure_pixel_view()
    _load_game()
    if world_objects.is_empty():
        _generate_world()
    _build_ui()
    queue_redraw()

func _configure_pixel_view() -> void:
    get_viewport().transparent_bg = false
    get_viewport().canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST

func _process(delta: float) -> void:
    animation_time += delta
    var keyboard: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
    move_vector = joystick_vector if joystick_vector.length() > 0.12 else keyboard
    if move_vector.length() > 0.08:
        move_vector = move_vector.normalized()
        facing = move_vector
        player_pos += move_vector * PLAYER_SPEED * delta
        move_target = Vector2(-9999, -9999)
    elif move_target.x > -9000:
        var difference: Vector2 = move_target - player_pos
        if difference.length() > 5.0:
            facing = difference.normalized()
            player_pos += facing * min(PLAYER_SPEED * delta, difference.length())
        else:
            move_target = Vector2(-9999, -9999)
    var normalized_pos: Vector2 = Vector2(player_pos.x / ISLAND_RADIUS.x, player_pos.y / ISLAND_RADIUS.y)
    if normalized_pos.length() > 0.94:
        player_pos = normalized_pos.normalized() * Vector2(ISLAND_RADIUS.x * 0.94, ISLAND_RADIUS.y * 0.94)
    save_timer += delta
    if save_timer > 20.0:
        save_timer = 0.0
        _save_game()
    queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        if event.pressed:
            if event.position.x < 145.0 and event.position.y > 135.0:
                joystick_touch = event.index
                joystick_origin = event.position
                joystick_vector = Vector2.ZERO
            else:
                var camera_offset: Vector2 = player_pos - VIEW_SIZE * 0.5
                move_target = event.position + camera_offset
        elif event.index == joystick_touch:
            joystick_touch = -1
            joystick_vector = Vector2.ZERO
    elif event is InputEventScreenDrag and event.index == joystick_touch:
        joystick_vector = ((event.position - joystick_origin) / 38.0).limit_length(1.0)

func _generate_world() -> void:
    world_objects.clear()
    var rng := RandomNumberGenerator.new()
    rng.seed = 824671
    for i in range(105):
        var p := Vector2(rng.randf_range(-690.0, 690.0), rng.randf_range(-500.0, 500.0))
        if Vector2(p.x / ISLAND_RADIUS.x, p.y / ISLAND_RADIUS.y).length() > 0.83:
            continue
        if p.length() < 115.0:
            continue
        var kind: String = "tree"
        var roll: float = rng.randf()
        if roll < 0.22:
            kind = "rock"
        elif roll < 0.34:
            kind = "bush"
        world_objects.append({"kind": kind, "pos": p, "variant": rng.randi_range(0, 3)})
    world_objects.append({"kind": "house", "pos": Vector2(-85, -55), "variant": 0})
    world_objects.append({"kind": "house", "pos": Vector2(155, 105), "variant": 1})
    _save_game()

func _draw() -> void:
    var camera_offset: Vector2 = player_pos - VIEW_SIZE * 0.5
    draw_rect(Rect2(Vector2.ZERO, VIEW_SIZE), Color("#397fa0"))
    _draw_water(camera_offset)
    var min_x: int = floori(camera_offset.x / TILE) - 1
    var max_x: int = ceili((camera_offset.x + VIEW_SIZE.x) / TILE) + 1
    var min_y: int = floori(camera_offset.y / TILE) - 1
    var max_y: int = ceili((camera_offset.y + VIEW_SIZE.y) / TILE) + 1
    for ty in range(min_y, max_y):
        for tx in range(min_x, max_x):
            var world: Vector2 = Vector2(tx * TILE, ty * TILE)
            var center: Vector2 = world + Vector2(TILE * 0.5, TILE * 0.5)
            var normalized: Vector2 = Vector2(center.x / ISLAND_RADIUS.x, center.y / ISLAND_RADIUS.y)
            var distance: float = normalized.length()
            var screen: Vector2 = world - camera_offset
            if distance <= 1.035:
                var color: Color
                if distance > 0.965:
                    color = Color("#d8bd79")
                else:
                    var variation: int = absi(tx * 92821 + ty * 68917) % 5
                    var greens: Array[Color] = [Color("#65ad55"), Color("#6db65b"), Color("#5fa44e"), Color("#74ba60"), Color("#68ae55")]
                    color = greens[variation]
                draw_rect(Rect2(screen, Vector2(TILE + 1, TILE + 1)), color)
                if distance < 0.95:
                    _draw_ground_detail(screen, tx, ty)
    _draw_path(camera_offset)
    for i in range(world_objects.size()):
        var item: Dictionary = world_objects[i]
        var screen_pos: Vector2 = item["pos"] - camera_offset
        if screen_pos.x < -45 or screen_pos.x > VIEW_SIZE.x + 45 or screen_pos.y < -60 or screen_pos.y > VIEW_SIZE.y + 60:
            continue
        match String(item["kind"]):
            "tree":
                _draw_tree(screen_pos, int(item["variant"]))
            "rock":
                _draw_rock(screen_pos, int(item["variant"]))
            "bush":
                _draw_bush(screen_pos)
            "house":
                _draw_house(screen_pos, int(item["variant"]))
    _draw_pig(VIEW_SIZE * 0.5)
    _draw_joystick()

func _draw_water(camera_offset: Vector2) -> void:
    for y in range(-1, 12):
        for x in range(-1, 22):
            var p: Vector2 = Vector2(x * 32.0, y * 32.0)
            var n: int = absi(x * 73129 + y * 19391) % 4
            var blues: Array[Color] = [Color("#397fa0"), Color("#3c85a5"), Color("#36799a"), Color("#4289a8")]
            draw_rect(Rect2(p - camera_offset * 0.12, Vector2(32, 32)), blues[n])
            if n == 1:
                draw_rect(Rect2(p + Vector2(9, 12) - camera_offset * 0.12, Vector2(7, 2)), Color("#72b5c3"))

func _draw_ground_detail(screen: Vector2, tx: int, ty: int) -> void:
    var seed_value: int = absi(tx * 19349663 + ty * 83492791)
    if seed_value % 7 == 0:
        draw_rect(Rect2(screen + Vector2(5 + seed_value % 11, 6 + seed_value % 9), Vector2(3, 3)), Color("#a2ce72"))
    elif seed_value % 13 == 0:
        draw_rect(Rect2(screen + Vector2(8, 15), Vector2(2, 5)), Color("#e8d78a"))
        draw_rect(Rect2(screen + Vector2(6, 16), Vector2(6, 2)), Color("#e8d78a"))

func _draw_path(camera_offset: Vector2) -> void:
    for x in range(-34, 35):
        var world_x: float = float(x) * 24.0
        var world_y: float = sin(world_x / 155.0) * 82.0 + 58.0
        var screen: Vector2 = Vector2(world_x, world_y) - camera_offset
        if screen.x > -24 and screen.x < VIEW_SIZE.x + 24 and screen.y > -24 and screen.y < VIEW_SIZE.y + 24:
            draw_rect(Rect2(screen, Vector2(24, 24)), Color("#c9a66b"))
            draw_rect(Rect2(screen + Vector2(4, 5), Vector2(3, 2)), Color("#e0c18a"))

func _draw_tree(p: Vector2, variant: int) -> void:
    draw_rect(Rect2(p + Vector2(-9, 4), Vector2(19, 7)), Color("#3f7442"))
    draw_rect(Rect2(p + Vector2(-4, -13), Vector2(9, 23)), Color("#79502e"))
    draw_rect(Rect2(p + Vector2(-17, -34), Vector2(34, 25)), Color("#286c42"))
    draw_rect(Rect2(p + Vector2(-13, -39), Vector2(26, 25)), Color("#39864b"))
    draw_rect(Rect2(p + Vector2(-7, -43), Vector2(15, 12)), Color("#4c9b53"))
    draw_rect(Rect2(p + Vector2(-12, -29), Vector2(7, 6)), Color("#62ad5a"))
    if variant % 2 == 0:
        draw_rect(Rect2(p + Vector2(5, -22), Vector2(6, 5)), Color("#74b95d"))

func _draw_rock(p: Vector2, variant: int) -> void:
    draw_rect(Rect2(p + Vector2(-12, -3), Vector2(25, 12)), Color("#668078"))
    draw_rect(Rect2(p + Vector2(-9, -9), Vector2(19, 12)), Color("#8fa49a"))
    draw_rect(Rect2(p + Vector2(-5, -12), Vector2(10, 5)), Color("#b2c1b2"))
    if variant % 2 == 0:
        draw_rect(Rect2(p + Vector2(3, -4), Vector2(4, 3)), Color("#d0d6c8"))

func _draw_bush(p: Vector2) -> void:
    draw_rect(Rect2(p + Vector2(-12, -3), Vector2(25, 10)), Color("#347844"))
    draw_rect(Rect2(p + Vector2(-9, -10), Vector2(19, 13)), Color("#4b9b50"))
    for berry in [Vector2(-5, -5), Vector2(4, -7), Vector2(7, 0)]:
        draw_rect(Rect2(p + berry, Vector2(3, 3)), Color("#d94f69"))

func _draw_house(p: Vector2, variant: int) -> void:
    var wall: Color = Color("#e8c58a") if variant == 0 else Color("#d98f78")
    draw_rect(Rect2(p + Vector2(-24, -15), Vector2(48, 28)), Color("#85543d"))
    draw_rect(Rect2(p + Vector2(-22, -18), Vector2(44, 26)), wall)
    draw_rect(Rect2(p + Vector2(-27, -25), Vector2(54, 12)), Color("#9c5147"))
    draw_rect(Rect2(p + Vector2(-22, -30), Vector2(44, 7)), Color("#bd6653"))
    draw_rect(Rect2(p + Vector2(-5, -7), Vector2(10, 15)), Color("#80523b"))
    draw_rect(Rect2(p + Vector2(-17, -11), Vector2(8, 8)), Color("#83c7d2"))
    draw_rect(Rect2(p + Vector2(9, -11), Vector2(8, 8)), Color("#83c7d2"))
    draw_rect(Rect2(p + Vector2(-1, -6), Vector2(2, 2)), Color("#f5d77a"))

func _draw_pig(center: Vector2) -> void:
    var step: int = 1 if move_vector.length() > 0.08 or move_target.x > -9000 else 0
    var leg_shift: int = int(sin(animation_time * 13.0) * 3.0) if step == 1 else 0
    draw_rect(Rect2(center + Vector2(-13, 13), Vector2(27, 5)), Color("#3e7045"))
    draw_rect(Rect2(center + Vector2(-10, -5), Vector2(21, 23)), Color("#e88b9a"))
    draw_rect(Rect2(center + Vector2(-8, -13), Vector2(19, 17)), Color("#f4a7b1"))
    draw_rect(Rect2(center + Vector2(-10, -18), Vector2(7, 9)), Color("#ed8998"))
    draw_rect(Rect2(center + Vector2(4, -18), Vector2(7, 9)), Color("#ed8998"))
    draw_rect(Rect2(center + Vector2(-8, -12), Vector2(4, 5)), Color("#ffd0d0"))
    draw_rect(Rect2(center + Vector2(6, -12), Vector2(4, 5)), Color("#ffd0d0"))
    draw_rect(Rect2(center + Vector2(-5, -4), Vector2(12, 7)), Color("#f7c0c4"))
    draw_rect(Rect2(center + Vector2(-3, -2), Vector2(2, 3)), Color("#a94f68"))
    draw_rect(Rect2(center + Vector2(4, -2), Vector2(2, 3)), Color("#a94f68"))
    draw_rect(Rect2(center + Vector2(-7, 15 + leg_shift), Vector2(6, 5)), Color("#c96f82"))
    draw_rect(Rect2(center + Vector2(3, 15 - leg_shift), Vector2(6, 5)), Color("#c96f82"))
    draw_rect(Rect2(center + Vector2(-13, 2), Vector2(4, 4)), Color("#f4a7b1"))

func _draw_joystick() -> void:
    draw_circle(Vector2(63, 215), 31, Color(0.08, 0.16, 0.17, 0.48))
    draw_circle(Vector2(63, 215), 25, Color(0.78, 0.9, 0.75, 0.3))
    var knob: Vector2 = Vector2(63, 215) + joystick_vector * 15.0
    draw_circle(knob, 10, Color("#f2e7c7"))

func _build_ui() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)
    var panel := PanelContainer.new()
    panel.position = Vector2(8, 7)
    panel.add_theme_stylebox_override("panel", _style(Color("#263f39"), 8))
    layer.add_child(panel)
    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 1)
    panel.add_child(column)
    var title := Label.new()
    title.text = "PIGGY ISLAND"
    title.add_theme_color_override("font_color", Color("#f6e8b8"))
    title.add_theme_font_size_override("font_size", 12)
    column.add_child(title)
    inventory_label = Label.new()
    inventory_label.add_theme_color_override("font_color", Color.WHITE)
    inventory_label.add_theme_font_size_override("font_size", 10)
    column.add_child(inventory_label)
    message_label = Label.new()
    message_label.text = "Собирай ресурсы и обустрой остров!"
    message_label.position = Vector2(8, 54)
    message_label.add_theme_color_override("font_color", Color("#fff3c8"))
    message_label.add_theme_font_size_override("font_size", 10)
    layer.add_child(message_label)
    action_button = _make_button("СОБРАТЬ", Vector2(365, 207), Vector2(105, 28))
    action_button.pressed.connect(_interact)
    layer.add_child(action_button)
    var build_button := _make_button("ПОСТРОИТЬ", Vector2(365, 174), Vector2(105, 28))
    build_button.pressed.connect(_build_small_house)
    layer.add_child(build_button)
    var help := Label.new()
    help.text = "WASD / джойстик • E — действие"
    help.position = Vector2(8, 252)
    help.add_theme_font_size_override("font_size", 8)
    help.add_theme_color_override("font_color", Color("#f8f1d9"))
    layer.add_child(help)
    _refresh_inventory()

func _make_button(text_value: String, pos: Vector2, button_size: Vector2) -> Button:
    var button := Button.new()
    button.text = text_value
    button.position = pos
    button.size = button_size
    button.add_theme_font_size_override("font_size", 10)
    button.add_theme_color_override("font_color", Color("#fff4d6"))
    button.add_theme_stylebox_override("normal", _style(Color("#527b55"), 7))
    button.add_theme_stylebox_override("hover", _style(Color("#68965e"), 7))
    button.add_theme_stylebox_override("pressed", _style(Color("#365c45"), 7))
    return button

func _style(color: Color, radius: int) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = color
    style.set_corner_radius_all(radius)
    style.content_margin_left = 7
    style.content_margin_right = 7
    style.content_margin_top = 4
    style.content_margin_bottom = 4
    style.border_width_bottom = 2
    style.border_color = color.darkened(0.28)
    return style

func _interact() -> void:
    var nearest_index: int = -1
    var nearest_distance: float = 58.0
    for i in range(world_objects.size()):
        var item: Dictionary = world_objects[i]
        var kind: String = String(item["kind"])
        if kind == "house":
            continue
        var distance: float = player_pos.distance_to(item["pos"])
        if distance < nearest_distance:
            nearest_distance = distance
            nearest_index = i
    if nearest_index == -1:
        _show_message("Подойди ближе к дереву, камню или кусту")
        return
    var target: Dictionary = world_objects[nearest_index]
    match String(target["kind"]):
        "tree":
            wood += 3
            _show_message("+3 дерева")
        "rock":
            stone += 2
            _show_message("+2 камня")
        "bush":
            berries += 2
            _show_message("+2 ягоды")
    world_objects.remove_at(nearest_index)
    _refresh_inventory()
    _save_game()
    queue_redraw()

func _build_small_house() -> void:
    if wood < 12 or stone < 5:
        _show_message("Нужно 12 дерева и 5 камня")
        return
    wood -= 12
    stone -= 5
    world_objects.append({"kind": "house", "pos": player_pos + Vector2(42, 8), "variant": 1})
    _refresh_inventory()
    _show_message("Новый дом построен!")
    _save_game()
    queue_redraw()

func _show_message(value: String) -> void:
    if is_instance_valid(message_label):
        message_label.text = value

func _refresh_inventory() -> void:
    if is_instance_valid(inventory_label):
        inventory_label.text = "🪵 %d   камень %d\n🍓 %d   🪙 %d" % [wood, stone, berries, coins]

func _save_game() -> void:
    var config := ConfigFile.new()
    config.set_value("player", "position", player_pos)
    config.set_value("inventory", "wood", wood)
    config.set_value("inventory", "stone", stone)
    config.set_value("inventory", "berries", berries)
    config.set_value("inventory", "coins", coins)
    config.set_value("world", "objects", world_objects)
    config.save(SAVE_PATH)

func _load_game() -> void:
    var config := ConfigFile.new()
    if config.load(SAVE_PATH) != OK:
        return
    player_pos = config.get_value("player", "position", Vector2.ZERO)
    wood = int(config.get_value("inventory", "wood", 0))
    stone = int(config.get_value("inventory", "stone", 0))
    berries = int(config.get_value("inventory", "berries", 0))
    coins = int(config.get_value("inventory", "coins", 0))
    var saved_objects = config.get_value("world", "objects", [])
    if saved_objects is Array:
        world_objects.assign(saved_objects)
