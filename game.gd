extends Node3D

const PIG_SPEED := 6.0
const JUMP_VELOCITY := 7.5
const WORLD_LIMIT := 48.0

var pig: CharacterBody3D
var camera: Camera3D
var joystick_touch := -1
var joystick_origin := Vector2.ZERO
var joystick_vector := Vector2.ZERO
var jump_requested := false
var coins := 0
var coin_nodes: Array[Node3D] = []
var coin_label: Label
var hint_label: Label
var audio_player: AudioStreamPlayer

func _ready() -> void:
    randomize()
    _build_world()
    _build_player()
    _build_ui()
    _setup_audio()

func _process(delta: float) -> void:
    if is_instance_valid(pig):
        camera.global_position = camera.global_position.lerp(
            pig.global_position + Vector3(0, 7.5, 11.5), min(delta * 4.0, 1.0))
        camera.look_at(pig.global_position + Vector3(0, 1.2, 0), Vector3.UP)
    for c in coin_nodes:
        if is_instance_valid(c):
            c.rotate_y(delta * 2.2)
    _check_coin_pickups()

func _physics_process(delta: float) -> void:
    if pig == null:
        return
    var input_dir := Vector2(
        Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
        Input.get_action_strength("move_back") - Input.get_action_strength("move_forward")
    )
    if joystick_vector.length() > 0.08:
        input_dir = joystick_vector
    input_dir = input_dir.limit_length(1.0)
    var direction := Vector3(input_dir.x, 0, input_dir.y)
    if direction.length() > 0.05:
        pig.velocity.x = direction.x * PIG_SPEED
        pig.velocity.z = direction.z * PIG_SPEED
        pig.rotation.y = lerp_angle(pig.rotation.y, atan2(direction.x, direction.z), delta * 10.0)
    else:
        pig.velocity.x = move_toward(pig.velocity.x, 0.0, PIG_SPEED * 5.0 * delta)
        pig.velocity.z = move_toward(pig.velocity.z, 0.0, PIG_SPEED * 5.0 * delta)
    if not pig.is_on_floor():
        pig.velocity.y -= 20.0 * delta
    elif jump_requested or Input.is_action_just_pressed("jump"):
        pig.velocity.y = JUMP_VELOCITY
        _play_sound("jump")
    jump_requested = false
    pig.move_and_slide()
    pig.global_position.x = clamp(pig.global_position.x, -WORLD_LIMIT, WORLD_LIMIT)
    pig.global_position.z = clamp(pig.global_position.z, -WORLD_LIMIT, WORLD_LIMIT)

func _build_world() -> void:
    var world_env := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_SKY
    env.sky = Sky.new()
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.75, 0.82, 0.95)
    env.ambient_light_energy = 0.8
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    world_env.environment = env
    add_child(world_env)

    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-52, -30, 0)
    sun.light_energy = 1.25
    sun.shadow_enabled = true
    add_child(sun)

    _add_box(self, Vector3(0, -0.55, 0), Vector3(110, 1, 110), Color(0.35, 0.68, 0.27), true)
    # Winding paths
    for i in range(8):
        var z := -35.0 + i * 10.0
        _add_box(self, Vector3(0, -0.02, z), Vector3(8, 0.08, 5), Color(0.78, 0.65, 0.43), false)
    # Pond
    _add_cylinder(self, Vector3(22, -0.02, -15), Vector2(8, 0.12), Color(0.2, 0.65, 0.88), false)
    # Trees in clusters
    for i in range(42):
        var x := randf_range(-43, 43)
        var z := randf_range(-43, 43)
        if Vector2(x, z).length() < 12.0 or (abs(x) < 6 and abs(z) < 40):
            continue
        _make_tree(Vector3(x, 0, z))
    # Little farm houses
    _make_house(Vector3(-19, 0, -18), Color(0.93, 0.72, 0.42))
    _make_house(Vector3(18, 0, 25), Color(0.82, 0.48, 0.39))
    _make_house(Vector3(-31, 0, 22), Color(0.62, 0.73, 0.9))
    # Rocks and fences
    for i in range(18):
        var rock := _make_sphere(self, Vector3(randf_range(-42,42), 0.35, randf_range(-42,42)),
            Vector3(randf_range(0.4,0.9), randf_range(0.3,0.7), randf_range(0.4,0.9)),
            Color(0.48,0.5,0.48), true)
    for i in range(9):
        _add_box(self, Vector3(-8 + i * 2, 0.55, -9), Vector3(0.16,1.1,0.16), Color(0.48,0.27,0.12), true)
    # Coins
    for i in range(24):
        var p := Vector3(randf_range(-38,38), 0.9, randf_range(-38,38))
        if Vector2(p.x,p.z).length() < 7: p.x += 13
        var coin := _make_coin(p)
        coin_nodes.append(coin)

func _build_player() -> void:
    pig = CharacterBody3D.new()
    pig.name = "Pig"
    pig.position = Vector3(0, 0.15, 0)
    add_child(pig)
    var collider := CollisionShape3D.new()
    var shape := CapsuleShape3D.new()
    shape.radius = 0.62
    shape.height = 1.8
    collider.shape = shape
    collider.position.y = 0.9
    pig.add_child(collider)

    var body := _make_sphere(pig, Vector3(0,0.95,0), Vector3(0.72,0.68,0.95), Color(1.0,0.48,0.58), false)
    _make_sphere(pig, Vector3(0,1.55,-0.48), Vector3(0.57,0.56,0.56), Color(1.0,0.55,0.63), false)
    # Snout
    _make_sphere(pig, Vector3(0,1.42,0.05), Vector3(0.38,0.25,0.22), Color(1.0,0.68,0.72), false)
    _make_sphere(pig, Vector3(-0.14,1.43,0.245), Vector3(0.055,0.09,0.035), Color(0.35,0.12,0.16), false)
    _make_sphere(pig, Vector3(0.14,1.43,0.245), Vector3(0.055,0.09,0.035), Color(0.35,0.12,0.16), false)
    # Eyes
    for x in [-0.22,0.22]:
        _make_sphere(pig, Vector3(x,1.68,-0.02), Vector3(0.075,0.09,0.06), Color(0.12,0.08,0.08), false)
        _make_sphere(pig, Vector3(x*1.45,2.0,-0.58), Vector3(0.19,0.3,0.12), Color(1.0,0.48,0.58), false)
    # Legs
    for x in [-0.42,0.42]:
        for z in [-0.55,0.55]:
            _make_cylinder(pig, Vector3(x,0.38,z), Vector2(0.16,0.48), Color(0.91,0.35,0.45), false)
    # Tail curl
    var tail := _make_cylinder(pig, Vector3(0,1.05,-0.96), Vector2(0.07,0.42), Color(1.0,0.48,0.58), false)
    tail.rotation.x = PI/2
    camera = Camera3D.new()
    camera.position = Vector3(0,7.5,11.5)
    camera.fov = 68
    add_child(camera)
    camera.current = true
    camera.look_at(pig.global_position + Vector3(0,1,0), Vector3.UP)

func _build_ui() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)
    var panel := PanelContainer.new()
    panel.position = Vector2(18,18)
    panel.add_theme_stylebox_override("panel", _panel_style(Color(0.08,0.12,0.15,0.72)))
    layer.add_child(panel)
    var v := VBoxContainer.new()
    panel.add_child(v)
    coin_label = Label.new()
    coin_label.text = "🪙  Монеты: 0 / 24"
    coin_label.add_theme_font_size_override("font_size", 25)
    v.add_child(coin_label)
    hint_label = Label.new()
    hint_label.text = "Исследуй остров и собирай монеты!"
    hint_label.add_theme_font_size_override("font_size", 17)
    v.add_child(hint_label)

    var controls := Label.new()
    controls.anchor_left = 0.0
    controls.anchor_top = 1.0
    controls.anchor_bottom = 1.0
    controls.position = Vector2(24,-58)
    controls.text = "ПК: WASD — движение   ПРОБЕЛ — прыжок     Телефон: слева — движение, справа — прыжок"
    controls.add_theme_font_size_override("font_size", 16)
    controls.add_theme_color_override("font_color", Color.WHITE)
    layer.add_child(controls)

    var jump := Button.new()
    jump.text = "ПРЫЖОК"
    jump.anchor_left = 1.0
    jump.anchor_top = 1.0
    jump.anchor_right = 1.0
    jump.anchor_bottom = 1.0
    jump.position = Vector2(-168,-138)
    jump.size = Vector2(142,92)
    jump.add_theme_font_size_override("font_size", 21)
    jump.button_down.connect(func(): jump_requested = true)
    layer.add_child(jump)

    var joystick := Label.new()
    joystick.text = "◉"
    joystick.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    joystick.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    joystick.anchor_left = 0.0
    joystick.anchor_top = 1.0
    joystick.anchor_bottom = 1.0
    joystick.position = Vector2(30,-150)
    joystick.size = Vector2(125,125)
    joystick.add_theme_font_size_override("font_size", 66)
    joystick.add_theme_color_override("font_color", Color(1,1,1,0.7))
    layer.add_child(joystick)

func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        if event.pressed:
            if event.position.x < get_viewport().get_visible_rect().size.x * 0.55:
                joystick_touch = event.index
                joystick_origin = event.position
                joystick_vector = Vector2.ZERO
            else:
                jump_requested = true
        elif event.index == joystick_touch:
            joystick_touch = -1
            joystick_vector = Vector2.ZERO
    elif event is InputEventScreenDrag and event.index == joystick_touch:
        var drag_delta := (event.position - joystick_origin) / 65.0
        joystick_vector = Vector2(drag_delta.x, drag_delta.y).limit_length(1.0)

func _check_coin_pickups() -> void:
    for c in coin_nodes:
        if is_instance_valid(c) and pig.global_position.distance_to(c.global_position) < 1.45:
            c.queue_free()
            coins += 1
            coin_label.text = "🪙  Монеты: %d / 24" % coins
            _play_sound("coin")
            if coins == 24:
                hint_label.text = "Ура! Все монеты собраны! Ты настоящий чемпион!"
            elif coins == 8:
                hint_label.text = "Отлично! Продолжай исследовать мир!"

func _make_tree(pos: Vector3) -> void:
    _make_cylinder(self, pos + Vector3(0,1.0,0), Vector2(0.22,2.0), Color(0.38,0.22,0.12), true)
    var green := [Color(0.16,0.52,0.2), Color(0.22,0.62,0.24), Color(0.32,0.68,0.28)][randi()%3]
    _make_sphere(self, pos + Vector3(0,2.45,0), Vector3(1.15,1.35,1.1), green, true)
    _make_sphere(self, pos + Vector3(-0.55,2.0,0.1), Vector3(0.75,0.85,0.75), green, true)

func _make_house(pos: Vector3, color: Color) -> void:
    _add_box(self, pos + Vector3(0,1.5,0), Vector3(5,3,4), color, true)
    var roof := _add_box(self, pos + Vector3(0,3.55,0), Vector3(5.8,0.45,4.8), Color(0.55,0.2,0.16), true)
    roof.rotation.z = 0.0
    _add_box(self, pos + Vector3(0,0.9,2.03), Vector3(1.0,1.8,0.12), Color(0.35,0.18,0.1), false)
    for x in [-1.45,1.45]:
        _add_box(self, pos + Vector3(x,1.9,2.06), Vector3(0.8,0.8,0.1), Color(0.55,0.82,0.96), false)

func _make_coin(pos: Vector3) -> Node3D:
    var n := Node3D.new()
    n.position = pos
    add_child(n)
    var mesh := MeshInstance3D.new()
    var cylinder := CylinderMesh.new()
    cylinder.top_radius = 0.42
    cylinder.bottom_radius = 0.42
    cylinder.height = 0.12
    mesh.mesh = cylinder
    mesh.rotation.x = PI/2
    mesh.material_override = _mat(Color(1.0,0.76,0.12), 0.7, 0.25)
    n.add_child(mesh)
    var glow := OmniLight3D.new()
    glow.light_color = Color(1.0,0.75,0.2)
    glow.light_energy = 0.35
    glow.omni_range = 2.5
    n.add_child(glow)
    return n

func _make_sphere(parent: Node, pos: Vector3, scale: Vector3, color: Color, collision: bool) -> MeshInstance3D:
    var m := MeshInstance3D.new()
    var s := SphereMesh.new()
    s.radius = 0.5
    s.height = 1.0
    m.mesh = s
    m.position = pos
    m.scale = scale
    m.material_override = _mat(color)
    parent.add_child(m)
    return m

func _make_cylinder(parent: Node, pos: Vector3, dims: Vector2, color: Color, collision: bool) -> MeshInstance3D:
    var m := MeshInstance3D.new()
    var c := CylinderMesh.new()
    c.top_radius = dims.x
    c.bottom_radius = dims.x
    c.height = dims.y
    m.mesh = c
    m.position = pos
    m.material_override = _mat(color)
    parent.add_child(m)
    return m

func _add_box(parent: Node, pos: Vector3, size: Vector3, color: Color, collision: bool) -> MeshInstance3D:
    var m := MeshInstance3D.new()
    var b := BoxMesh.new()
    b.size = size
    m.mesh = b
    m.position = pos
    m.material_override = _mat(color)
    parent.add_child(m)
    if collision:
        var body := StaticBody3D.new()
        body.position = pos
        parent.add_child(body)
        var col := CollisionShape3D.new()
        var shape := BoxShape3D.new()
        shape.size = size
        col.shape = shape
        body.add_child(col)
    return m

func _mat(color: Color, metallic := 0.0, roughness := 0.85) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.metallic = metallic
    m.roughness = roughness
    return m

func _panel_style(color: Color) -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color = color
    s.set_corner_radius_all(14)
    s.content_margin_left = 14
    s.content_margin_right = 14
    s.content_margin_top = 8
    s.content_margin_bottom = 8
    return s

func _setup_audio() -> void:
    audio_player = AudioStreamPlayer.new()
    add_child(audio_player)
    # Short original tones generated in-game: no external audio assets required.

func _play_sound(kind: String) -> void:
    var sample_rate := 22050
    var duration := 0.16 if kind == "coin" else 0.22
    var frequency := 880.0 if kind == "coin" else 330.0
    var data := PackedByteArray()
    var count := int(sample_rate * duration)
    for i in range(count):
        var t := float(i) / sample_rate
        var envelope := (1.0 - float(i) / count)
        var freq := frequency * (1.0 + (0.5 * sin(t * 24.0) if kind == "jump" else 0.0))
        var sample := sin(TAU * freq * t) * envelope * 0.28
        var value := int(clamp(sample, -1.0, 1.0) * 32767.0)
        data.append(value & 0xff)
        data.append((value >> 8) & 0xff)
    var stream := AudioStreamWAV.new()
    stream.format = AudioStreamWAV.FORMAT_16_BITS
    stream.mix_rate = sample_rate
    stream.stereo = false
    stream.data = data
    audio_player.stream = stream
    audio_player.play()
