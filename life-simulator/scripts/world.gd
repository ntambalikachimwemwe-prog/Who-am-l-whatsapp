extends Node3D

const PLAYER_SCRIPT = preload("res://scripts/player.gd")
var player: CharacterBody3D
var prompt_label: Label
var dialogue_panel: PanelContainer
var dialogue_input: LineEdit
var dialogue_text: Label
var current_npc := ""
var life_stage := "Primary School"

func _ready() -> void:
    _build_environment()
    _build_schoolyard()
    _build_player()
    _build_hud()
    _spawn_npc("Teacher", Vector3(0, 0, -7), Color(0.2, 0.35, 0.72))
    _spawn_npc("Classmate", Vector3(4, 0, -3), Color(0.15, 0.55, 0.34))
    _spawn_npc("Friend", Vector3(-5, 0, -1), Color(0.68, 0.32, 0.2))

func _build_environment() -> void:
    var world_env := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_SKY
    env.sky = Sky.new()
    env.sky.sky_material = ProceduralSkyMaterial.new()
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.72, 0.78, 0.9)
    env.ambient_light_energy = 0.65
    world_env.environment = env
    add_child(world_env)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-48, -30, 0)
    sun.light_energy = 1.2
    sun.shadow_enabled = true
    add_child(sun)

func _box(parent: Node3D, label: String, pos: Vector3, size: Vector3, color: Color) -> StaticBody3D:
    var body := StaticBody3D.new()
    body.name = label
    body.position = pos
    var mesh_instance := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    mesh_instance.mesh = mesh
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = 0.9
    mesh_instance.material_override = material
    body.add_child(mesh_instance)
    var collision := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = size
    collision.shape = shape
    body.add_child(collision)
    parent.add_child(body)
    return body

func _build_schoolyard() -> void:
    _box(self, "Ground", Vector3(0, -0.25, 0), Vector3(65, 0.5, 65), Color(0.25, 0.39, 0.22))
    _box(self, "School building", Vector3(0, 2, -14), Vector3(19, 4, 5), Color(0.78, 0.68, 0.48))
    _box(self, "Classroom entrance", Vector3(0, 1.1, -11.35), Vector3(2.2, 2.2, 0.2), Color(0.28, 0.18, 0.1))
    _box(self, "Blackboard", Vector3(0, 2.1, -16.45), Vector3(5, 1.4, 0.12), Color(0.06, 0.15, 0.12))
    for i in range(5):
        _box(self, "Desk_%d" % i, Vector3(-6 + i * 3, 0.7, -5), Vector3(1.5, 0.2, 0.8), Color(0.42, 0.25, 0.13))
    for i in range(8):
        var tree := _box(self, "Tree trunk %d" % i, Vector3(-17 + i * 5, 1, 7 + (i % 2) * 4), Vector3(0.45, 2, 0.45), Color(0.25, 0.14, 0.08))
        var crown := MeshInstance3D.new()
        var sphere := SphereMesh.new()
        sphere.radius = 1.5
        sphere.height = 3
        crown.mesh = sphere
        var green := StandardMaterial3D.new()
        green.albedo_color = Color(0.12, 0.34, 0.13)
        crown.material_override = green
        crown.position = Vector3(0, 2, 0)
        tree.add_child(crown)

func _build_player() -> void:
    player = CharacterBody3D.new()
    player.name = "Player"
    player.set_script(PLAYER_SCRIPT)
    player.position = Vector3(0, 0.2, 5)
    add_child(player)

func _spawn_npc(npc_name: String, pos: Vector3, color: Color) -> void:
    var npc := StaticBody3D.new()
    npc.name = npc_name
    npc.position = pos
    var mesh := MeshInstance3D.new()
    var capsule := CapsuleMesh.new()
    capsule.radius = 0.34
    capsule.height = 1.7
    mesh.mesh = capsule
    mesh.position.y = 0.85
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mesh.material_override = mat
    npc.add_child(mesh)
    var collision := CollisionShape3D.new()
    var shape := CapsuleShape3D.new()
    shape.radius = 0.34
    shape.height = 1.7
    collision.shape = shape
    collision.position.y = 0.85
    npc.add_child(collision)
    add_child(npc)
    npc.set_meta("npc_name", npc_name)

func _build_hud() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)
    var root := Control.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    layer.add_child(root)
    var title := Label.new()
    title.text = "LIFE JOURNEY  •  " + life_stage
    title.position = Vector2(20, 16)
    title.add_theme_font_size_override("font_size", 22)
    root.add_child(title)
    prompt_label = Label.new()
    prompt_label.text = "WASD move  •  Mouse look  •  Shift run  •  Space jump  •  E talk"
    prompt_label.position = Vector2(20, 52)
    root.add_child(prompt_label)
    dialogue_panel = PanelContainer.new()
    dialogue_panel.position = Vector2(20, 520)
    dialogue_panel.size = Vector2(650, 170)
    dialogue_panel.visible = false
    root.add_child(dialogue_panel)
    var layout := VBoxContainer.new()
    dialogue_panel.add_child(layout)
    dialogue_text = Label.new()
    dialogue_text.text = "What would you like to say?"
    dialogue_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    layout.add_child(dialogue_text)
    dialogue_input = LineEdit.new()
    dialogue_input.placeholder_text = "Type what your character should say..."
    layout.add_child(dialogue_input)
    var send := Button.new()
    send.text = "Say it"
    send.pressed.connect(_send_dialogue)
    layout.add_child(send)
    var close := Button.new()
    close.text = "Close conversation"
    close.pressed.connect(func(): dialogue_panel.hide())
    layout.add_child(close)

func _process(_delta: float) -> void:
    if player == null:
        return
    var nearest: Node3D
    var best := 3.0
    for node in get_children():
        if node is StaticBody3D and node.has_meta("npc_name"):
            var d: float = player.global_position.distance_to(node.global_position)
            if d < best:
                best = d
                nearest = node
    if nearest:
        prompt_label.text = "Nearby: %s  •  Press E to talk" % nearest.get_meta("npc_name")
        if Input.is_action_just_pressed("interact"):
            current_npc = str(nearest.get_meta("npc_name"))
            dialogue_text.text = "%s is listening. Type your own words below." % current_npc
            dialogue_panel.show()
    else:
        prompt_label.text = "WASD move  •  Mouse look  •  Shift run  •  Space jump  •  E talk"

func _send_dialogue() -> void:
    var words := dialogue_input.text.strip_edges()
    if words.is_empty():
        return
    dialogue_text.text = "You: %s\n%s: (conversation response system will be connected here)" % [words, current_npc]
    dialogue_input.clear()
