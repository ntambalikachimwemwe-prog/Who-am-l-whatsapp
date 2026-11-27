extends Node3D

const PLAYER_SCRIPT = preload("res://scripts/player.gd")
const STAGES := ["Primary School", "Secondary School", "University", "Adult Life"]
const STAGE_DESCRIPTIONS := [
	"Class lessons, school breaks and family life",
	"Hostel life, friendships, music and football",
	"Lectures, campus life, friendships and relationships",
	"Work, home, neighbourhood and everyday responsibilities"
]
var player: CharacterBody3D
var prompt_label: Label
var dialogue_panel: PanelContainer
var dialogue_input: LineEdit
var dialogue_text: Label
var stage_label: Label
var stage_description: Label
var stage_container: Node3D
var current_npc := ""
var life_stage_index := 0
var stage_npcs: Array[Node3D] = []
var touch_buttons: Array[Button] = []

func _ready() -> void:
	_build_environment()
	stage_container = Node3D.new()
	stage_container.name = "CurrentWorld"
	add_child(stage_container)
	_build_player()
	_build_hud()
	_build_stage_world()
	_update_stage()

func _build_environment() -> void:
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = Sky.new()
	env.sky.sky_material = ProceduralSkyMaterial.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.72, 0.78, 0.9)
	env.ambient_light_energy = 0.7
	world_env.environment = env
	add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -30, 0)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	add_child(sun)

func _material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.88
	return mat

func _box(parent: Node3D, label: String, pos: Vector3, size: Vector3, color: Color, solid := true) -> Node3D:
	var holder: Node3D
	if solid:
		holder = StaticBody3D.new()
	else:
		holder = Node3D.new()
	holder.name = label
	holder.position = pos
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _material(color)
	holder.add_child(mesh_instance)
	if solid:
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		holder.add_child(collision)
	parent.add_child(holder)
	return holder

func _sphere(parent: Node3D, label: String, pos: Vector3, radius: float, color: Color) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = label
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	mesh.mesh = sphere
	mesh.material_override = _material(color)
	mesh.position = pos
	parent.add_child(mesh)

func _tree(parent: Node3D, pos: Vector3) -> void:
	_box(parent, "Tree trunk", pos + Vector3(0, 1, 0), Vector3(0.45, 2, 0.45), Color(0.25, 0.14, 0.08))
	_sphere(parent, "Tree crown", pos + Vector3(0, 3, 0), 1.45, Color(0.12, 0.34, 0.13))

func _build_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Player"
	player.set_script(PLAYER_SCRIPT)
	player.position = Vector3(0, 0.2, 6)
	add_child(player)

func _person_part(parent: Node3D, part_name: String, radius: float, height: float, color: Color, local_pos: Vector3) -> void:
	var part := MeshInstance3D.new()
	part.name = part_name
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	part.mesh = mesh
	part.material_override = _material(color)
	part.position = local_pos
	parent.add_child(part)

func _spawn_npc(npc_name: String, pos: Vector3, color: Color, role: String) -> void:
	var npc := StaticBody3D.new()
	npc.name = npc_name
	npc.position = pos
	# Separate head, torso, arms and legs make people easier to recognise at game distance.
	_person_part(npc, "Shirt", 0.31, 0.82, color, Vector3(0, 1.12, 0))
	_person_part(npc, "Neck", 0.10, 0.20, Color(0.48, 0.29, 0.19), Vector3(0, 1.62, 0))
	var head := MeshInstance3D.new()
	head.name = "Head"
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.235
	head_mesh.height = 0.47
	head.mesh = head_mesh
	head.position.y = 1.88
	head.material_override = _material(Color(0.48, 0.29, 0.19))
	npc.add_child(head)
	var hair := MeshInstance3D.new()
	var hair_mesh := SphereMesh.new()
	hair_mesh.radius = 0.24
	hair_mesh.height = 0.22
	hair.mesh = hair_mesh
	hair.position = Vector3(0, 2.04, -0.025)
	hair.material_override = _material(Color(0.055, 0.04, 0.03))
	npc.add_child(hair)
	for side in [-1.0, 1.0]:
		_person_part(npc, "Arm", 0.115, 0.72, color, Vector3(side * 0.39, 1.08, 0))
		_person_part(npc, "Hand", 0.08, 0.18, Color(0.48, 0.29, 0.19), Vector3(side * 0.39, 0.62, 0))
		_person_part(npc, "Trousers", 0.145, 0.78, Color(0.12, 0.13, 0.17), Vector3(side * 0.17, 0.36, 0))
		_person_part(npc, "Shoe", 0.13, 0.22, Color(0.045, 0.04, 0.035), Vector3(side * 0.17, 0.04, -0.04))
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.34
	shape.height = 1.85
	collision.shape = shape
	collision.position.y = 0.94
	npc.add_child(collision)
	var name_tag := Label3D.new()
	name_tag.text = npc_name
	name_tag.position.y = 2.35
	name_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_tag.font_size = 32
	npc.add_child(name_tag)
	stage_container.add_child(npc)
	npc.set_meta("npc_name", npc_name)
	npc.set_meta("role", role)
	stage_npcs.append(npc)

func _clear_stage() -> void:
	for child in stage_container.get_children():
		child.queue_free()
	stage_npcs.clear()
	player.global_position = Vector3(0, 0.2, 6)
	player.velocity = Vector3.ZERO

func _build_stage_world() -> void:
	_clear_stage()
	match life_stage_index:
		0: _build_primary_world()
		1: _build_secondary_world()
		2: _build_university_world()
		3: _build_adult_world()

func _build_primary_world() -> void:
	_box(stage_container, "School grounds", Vector3(0, -0.25, 0), Vector3(66, 0.5, 66), Color(0.25, 0.39, 0.22))
	_box(stage_container, "Primary school", Vector3(0, 2, -14), Vector3(19, 4, 6), Color(0.78, 0.68, 0.48))
	_box(stage_container, "Classroom door", Vector3(0, 1, -10.8), Vector3(2, 2, 0.2), Color(0.28, 0.16, 0.08))
	_box(stage_container, "Blackboard", Vector3(0, 2.2, -16.9), Vector3(5, 1.5, 0.12), Color(0.04, 0.14, 0.1))
	for i in range(5):
		_box(stage_container, "Class desk", Vector3(-6 + i * 3, 0.65, -5), Vector3(1.5, 0.2, 0.8), Color(0.42, 0.25, 0.13))
	for i in range(8):
		_tree(stage_container, Vector3(-17 + i * 5, 0, 9 + (i % 2) * 4))
	_spawn_npc("Teacher", Vector3(0, 0, -8), Color(0.2, 0.35, 0.72), "teacher")
	_spawn_npc("Classmate", Vector3(4, 0, -3), Color(0.15, 0.55, 0.34), "student")
	_spawn_npc("Friend", Vector3(-5, 0, -1), Color(0.68, 0.32, 0.2), "friend")
	_spawn_npc("Headteacher", Vector3(8, 0, -10), Color(0.35, 0.25, 0.18), "teacher")
	_spawn_npc("Mother", Vector3(0, 0, 16), Color(0.65, 0.25, 0.38), "family")
	_box(stage_container, "Family home", Vector3(0, 2, 23), Vector3(11, 4, 9), Color(0.72, 0.55, 0.38))
	_box(stage_container, "Home door", Vector3(0, 1, 18.4), Vector3(1.8, 2, 0.15), Color(0.25, 0.13, 0.07))

func _build_secondary_world() -> void:
	_box(stage_container, "Hostel courtyard", Vector3(0, -0.25, 0), Vector3(70, 0.5, 70), Color(0.38, 0.42, 0.3))
	_box(stage_container, "Boys hostel", Vector3(-11, 2, -10), Vector3(17, 4, 12), Color(0.72, 0.62, 0.48))
	_box(stage_container, "Girls hostel", Vector3(12, 2, -10), Vector3(17, 4, 12), Color(0.72, 0.62, 0.48))
	_box(stage_container, "Common room", Vector3(0, 1.8, 9), Vector3(20, 3.6, 10), Color(0.55, 0.58, 0.52))
	for x in [-16.0, -10.0, -4.0, 4.0, 10.0, 16.0]:
		_tree(stage_container, Vector3(x, 0, 22))
	for i in range(4):
		_box(stage_container, "Dorm bed", Vector3(-15 + i * 3, 0.55, -8), Vector3(2.2, 0.4, 1.0), Color(0.25, 0.36, 0.58))
	_spawn_npc("Roommate", Vector3(-8, 0, -2), Color(0.2, 0.48, 0.38), "friend")
	_spawn_npc("Football Friend", Vector3(3, 0, 2), Color(0.62, 0.34, 0.18), "friend")
	_spawn_npc("Music Friend", Vector3(7, 0, 5), Color(0.34, 0.28, 0.62), "friend")
	_spawn_npc("Senior Student", Vector3(-15, 0, 2), Color(0.25, 0.35, 0.68), "student")
	_spawn_npc("House Parent", Vector3(12, 0, -2), Color(0.6, 0.3, 0.22), "teacher")

func _build_university_world() -> void:
	_box(stage_container, "Campus lawn", Vector3(0, -0.25, 0), Vector3(85, 0.5, 85), Color(0.25, 0.42, 0.25))
	_box(stage_container, "Lecture block", Vector3(0, 2.5, -17), Vector3(24, 5, 10), Color(0.78, 0.76, 0.66))
	_box(stage_container, "Lecture blackboard", Vector3(0, 2.3, -11.85), Vector3(7, 1.5, 0.15), Color(0.04, 0.14, 0.1))
	for row in range(3):
		for col in range(4):
			_box(stage_container, "Lecture desk", Vector3(-7 + col * 4.5, 0.65, -5 + row * 3), Vector3(2.2, 0.25, 1), Color(0.42, 0.28, 0.16))
	_box(stage_container, "Student centre", Vector3(-18, 2, 7), Vector3(13, 4, 10), Color(0.72, 0.6, 0.43))
	_box(stage_container, "Library", Vector3(19, 2, 7), Vector3(13, 4, 10), Color(0.66, 0.7, 0.74))
	for x in [-30.0, -20.0, 20.0, 30.0]:
		_tree(stage_container, Vector3(x, 0, 20))
	_spawn_npc("Lecturer", Vector3(0, 0, -9), Color(0.18, 0.3, 0.68), "teacher")
	_spawn_npc("Campus Friend", Vector3(-8, 0, 1), Color(0.15, 0.55, 0.34), "friend")
	_spawn_npc("Study Partner", Vector3(7, 0, 0), Color(0.65, 0.35, 0.2), "student")
	_spawn_npc("Student", Vector3(14, 0, 10), Color(0.32, 0.38, 0.62), "student")
	_spawn_npc("Aisha", Vector3(3, 0, 8), Color(0.68, 0.3, 0.42), "romance")

func _build_adult_world() -> void:
	_box(stage_container, "Town road", Vector3(0, -0.22, 0), Vector3(90, 0.45, 90), Color(0.32, 0.34, 0.32))
	_box(stage_container, "Road lane", Vector3(0, 0.02, 0), Vector3(7, 0.04, 90), Color(0.15, 0.16, 0.17), false)
	_box(stage_container, "Home", Vector3(-18, 2, -12), Vector3(13, 4, 11), Color(0.72, 0.52, 0.38))
	_box(stage_container, "Office", Vector3(17, 3, -15), Vector3(17, 6, 12), Color(0.58, 0.66, 0.72))
	_box(stage_container, "Shop", Vector3(17, 2, 12), Vector3(12, 4, 10), Color(0.72, 0.68, 0.48))
	_box(stage_container, "Bus stop", Vector3(-18, 1.3, 13), Vector3(7, 2.6, 1), Color(0.28, 0.36, 0.42))
	for x in [-32.0, -24.0, 25.0, 33.0]:
		_tree(stage_container, Vector3(x, 0, 25))
	_spawn_npc("Neighbour", Vector3(-10, 0, 5), Color(0.3, 0.52, 0.36), "friend")
	_spawn_npc("Colleague", Vector3(10, 0, -5), Color(0.2, 0.35, 0.72), "student")
	_spawn_npc("Shopkeeper", Vector3(18, 0, 18), Color(0.65, 0.36, 0.18), "worker")
	_spawn_npc("Partner", Vector3(-18, 0, -2), Color(0.68, 0.3, 0.42), "romance")

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)
	stage_label = Label.new()
	stage_label.position = Vector2(20, 12)
	stage_label.add_theme_font_size_override("font_size", 22)
	root.add_child(stage_label)
	stage_description = Label.new()
	stage_description.position = Vector2(20, 42)
	root.add_child(stage_description)
	prompt_label = Label.new()
	prompt_label.position = Vector2(20, 70)
	prompt_label.text = "WASD / arrows move • Mouse look • Shift run • Space jump • E talk • N change stage"
	root.add_child(prompt_label)

	dialogue_panel = PanelContainer.new()
	dialogue_panel.position = Vector2(20, 490)
	dialogue_panel.size = Vector2(700, 190)
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
	dialogue_input.text_submitted.connect(func(_value: String): _send_dialogue())
	layout.add_child(dialogue_input)
	var send := Button.new()
	send.text = "Say it"
	send.pressed.connect(_send_dialogue)
	layout.add_child(send)
	var close := Button.new()
	close.text = "Close conversation"
	close.pressed.connect(func(): dialogue_panel.hide())
	layout.add_child(close)

	_add_touch_button(root, "▲", Vector2(1040, 530), Vector2(68, 62), func(): player.mobile_move = Vector2(0, -1), func(): player.mobile_move = Vector2.ZERO)
	_add_touch_button(root, "▼", Vector2(1040, 652), Vector2(68, 62), func(): player.mobile_move = Vector2(0, 1), func(): player.mobile_move = Vector2.ZERO)
	_add_touch_button(root, "◀", Vector2(968, 590), Vector2(68, 62), func(): player.mobile_move = Vector2(-1, 0), func(): player.mobile_move = Vector2.ZERO)
	_add_touch_button(root, "▶", Vector2(1112, 590), Vector2(68, 62), func(): player.mobile_move = Vector2(1, 0), func(): player.mobile_move = Vector2.ZERO)
	_add_touch_button(root, "RUN", Vector2(850, 630), Vector2(90, 54), func(): player.mobile_run = true, func(): player.mobile_run = false)
	_add_touch_button(root, "JUMP", Vector2(850, 565), Vector2(90, 54), func(): player.mobile_jump = true, func(): player.mobile_jump = false)
	_add_touch_button(root, "TALK", Vector2(850, 500), Vector2(90, 54), func(): _talk_to_nearest(), func(): pass)
	_add_touch_button(root, "NEXT", Vector2(1080, 20), Vector2(110, 48), func(): _next_stage(), func(): pass)

func _add_touch_button(parent: Control, caption: String, pos: Vector2, button_size: Vector2, down: Callable, up: Callable) -> void:
	var button := Button.new()
	button.text = caption
	button.position = pos
	button.size = button_size
	button.modulate = Color(1, 1, 1, 0.78)
	button.button_down.connect(down)
	button.button_up.connect(up)
	parent.add_child(button)
	touch_buttons.append(button)

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("next_stage"):
		_next_stage()
	if Input.is_action_just_pressed("interact"):
		_talk_to_nearest()
	if player == null or dialogue_panel.visible:
		return
	var nearest: Node3D
	var best := 3.2
	for npc in stage_npcs:
		if is_instance_valid(npc):
			var distance := player.global_position.distance_to(npc.global_position)
			if distance < best:
				best = distance
				nearest = npc
	if nearest:
		prompt_label.text = "Nearby: %s • Press E / TALK" % nearest.get_meta("npc_name")
	else:
		prompt_label.text = "Explore the area • Find people to talk to • N / NEXT changes life stage"

func _talk_to_nearest() -> void:
	if dialogue_panel.visible:
		return
	var nearest: Node3D
	var best := 3.5
	for npc in stage_npcs:
		if is_instance_valid(npc):
			var distance := player.global_position.distance_to(npc.global_position)
			if distance < best:
				best = distance
				nearest = npc
	if nearest:
		current_npc = str(nearest.get_meta("npc_name"))
		dialogue_text.text = "%s is listening. Type what you want your character to say." % current_npc
		dialogue_panel.show()
		dialogue_input.grab_focus()

func _next_stage() -> void:
	life_stage_index = (life_stage_index + 1) % STAGES.size()
	_build_stage_world()
	_update_stage()
	dialogue_panel.hide()

func _update_stage() -> void:
	stage_label.text = "LIFE JOURNEY  •  " + STAGES[life_stage_index]
	stage_description.text = STAGE_DESCRIPTIONS[life_stage_index]

func _send_dialogue() -> void:
	var words := dialogue_input.text.strip_edges()
	if words.is_empty():
		return
	dialogue_text.text = "You: %s\n%s: %s" % [words, current_npc, _npc_reply(current_npc, words)]
	dialogue_input.clear()

func _npc_reply(npc_name: String, words: String) -> String:
	var message := words.to_lower()
	if message.contains("hello") or message.contains("hi") or message.contains("moni"):
		return "Moni! How are you today?"
	if message.contains("football") or message.contains("soccer"):
		return "I enjoy football too. Which team or player do you support?"
	if message.contains("music") or message.contains("song"):
		return "What kind of music have you been listening to lately?"
	if message.contains("love") or message.contains("girlfriend") or message.contains("date"):
		if npc_name == "Aisha" or npc_name == "Partner":
			return "I would like to know you better first. What do you enjoy doing?"
		return "Relationships take time. Let's get to know each other first."
	if message.contains("lesson") or message.contains("study") or message.contains("class"):
		return "Let's work through it together. Which part do you find difficult?"
	if message.contains("home") or message.contains("family"):
		return "Family matters. How has everything been at home?"
	if message.contains("work") or message.contains("job") or message.contains("business"):
		return "What are you working on at the moment?"
	if npc_name.to_lower().contains("teacher") or npc_name.to_lower().contains("lecturer") or npc_name.to_lower().contains("headteacher"):
		return "Good question. Think it through and tell me what you understand."
	return "I hear you. Tell me a little more — what happened next?"
