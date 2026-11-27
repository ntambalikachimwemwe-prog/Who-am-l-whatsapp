extends Node2D
## Life Journey — 2D photo-based life simulation.
## Drop approved character portraits into res://assets/characters/ to use them.
## The player portrait path is optional; the game remains playable without it.

const STAGES := [
	{"name":"Primary School","place":"School grounds • classroom • the walk home","npcs":[
		{"name":"Mr. Banda","role":"Teacher","x":820,"y":390,"portrait":"res://assets/characters/teacher.png","line":"Good morning, class. Today we are learning together."},
		{"name":"Thoko","role":"Classmate","x":570,"y":480,"portrait":"res://assets/characters/classmate.png","line":"Come and sit with us before the lesson starts."},
		{"name":"Mother","role":"Family","x":1040,"y":480,"portrait":"res://assets/characters/mother.png","line":"Welcome home. How was school today?"}
	]},
	{"name":"Secondary School","place":"Hostel • classroom • common room","npcs":[
		{"name":"Roommate","role":"Friend","x":570,"y":475,"portrait":"res://assets/characters/roommate.png","line":"Are you coming to the common room?"},
		{"name":"Football Friend","role":"Friend","x":820,"y":470,"portrait":"res://assets/characters/football_friend.png","line":"Let's talk football. Who is your favourite player?"},
		{"name":"House Parent","role":"Teacher","x":1050,"y":400,"portrait":"res://assets/characters/teacher.png","line":"Remember to be back at the hostel on time."}
	]},
	{"name":"University","place":"Lecture theatre • campus • student centre","npcs":[
		{"name":"Lecturer","role":"Lecturer","x":830,"y":385,"portrait":"res://assets/characters/lecturer.png","line":"Who can explain the main idea from our last lecture?"},
		{"name":"Campus Friend","role":"Friend","x":570,"y":480,"portrait":"res://assets/characters/friend.png","line":"Have you finished the assignment?"},
		{"name":"Aisha","role":"Student","x":1050,"y":480,"portrait":"res://assets/characters/girlfriend.png","line":"Hi. How has your day been?"}
	]},
	{"name":"Adult Life","place":"Neighbourhood • workplace • home","npcs":[
		{"name":"Colleague","role":"Colleague","x":820,"y":410,"portrait":"res://assets/characters/colleague.png","line":"How is the project coming along?"},
		{"name":"Neighbour","role":"Neighbour","x":570,"y":475,"portrait":"res://assets/characters/neighbour.png","line":"Good evening. How are things at home?"},
		{"name":"Partner","role":"Partner","x":1050,"y":475,"portrait":"res://assets/characters/girlfriend.png","line":"Let's talk about our plans for the future."}
	]}
]

var stage_index := 0
var player_position := Vector2(280, 500)
var player_speed := 270.0
var player_facing := 1.0
var player_texture: Texture2D
var current_npc: Dictionary = {}
var npc_nodes: Array[Dictionary] = []
var world_layer: Node2D
var player_sprite: Sprite2D
var camera: Camera2D
var hud: CanvasLayer
var stage_title: Label
var stage_subtitle: Label
var prompt: Label
var dialogue_panel: PanelContainer
var dialogue_label: Label
var dialogue_input: LineEdit
var activity_label: Label
var stage_button: Button

func _ready() -> void:
	_load_optional_portraits()
	_build_world()
	_build_player()
	_build_hud()
	_refresh_stage()
	get_viewport().size_changed.connect(_fit_hud)

func _load_optional_portraits() -> void:
	var path := "res://assets/characters/player.png"
	if ResourceLoader.exists(path):
		player_texture = load(path) as Texture2D

func _build_world() -> void:
	world_layer = Node2D.new()
	world_layer.name = "Illustrated2DWorld"
	add_child(world_layer)
	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 5.0
	camera.zoom = Vector2(1, 1)
	add_child(camera)
	camera.make_current()

func _build_player() -> void:
	player_sprite = Sprite2D.new()
	player_sprite.name = "MainCharacter"
	player_sprite.texture = player_texture
	player_sprite.position = player_position
	player_sprite.centered = true
	if player_texture:
		player_sprite.scale = _fit_texture(player_texture, Vector2(100, 190))
	world_layer.add_child(player_sprite)
	camera.position = player_position

func _fit_texture(texture: Texture2D, target: Vector2) -> Vector2:
	var size := texture.get_size()
	var factor := min(target.x / size.x, target.y / size.y)
	return Vector2(factor, factor)

func _build_hud() -> void:
	hud = CanvasLayer.new()
	add_child(hud)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.add_child(root)

	var top := PanelContainer.new()
	top.position = Vector2(18, 16)
	top.custom_minimum_size = Vector2(460, 86)
	root.add_child(top)
	var top_col := VBoxContainer.new()
	top.add_child(top_col)
	stage_title = Label.new()
	stage_title.add_theme_font_size_override("font_size", 24)
	top_col.add_child(stage_title)
	stage_subtitle = Label.new()
	top_col.add_child(stage_subtitle)

	prompt = Label.new()
	prompt.position = Vector2(20, 112)
	prompt.add_theme_font_size_override("font_size", 16)
	root.add_child(prompt)

	stage_button = Button.new()
	stage_button.text = "NEXT LIFE STAGE  ›"
	stage_button.position = Vector2(1030, 22)
	stage_button.custom_minimum_size = Vector2(220, 54)
	stage_button.pressed.connect(_next_stage)
	root.add_child(stage_button)

	activity_label = Label.new()
	activity_label.position = Vector2(20, 620)
	activity_label.text = "Move: WASD / arrows • Talk: E or tap a person • Stage: NEXT"
	root.add_child(activity_label)

	var talk_button := Button.new()
	talk_button.text = "TALK"
	talk_button.position = Vector2(1090, 610)
	talk_button.custom_minimum_size = Vector2(140, 70)
	talk_button.pressed.connect(_talk_nearest)
	root.add_child(talk_button)

	dialogue_panel = PanelContainer.new()
	dialogue_panel.position = Vector2(300, 450)
	dialogue_panel.custom_minimum_size = Vector2(680, 220)
	dialogue_panel.visible = false
	root.add_child(dialogue_panel)
	var dialog_col := VBoxContainer.new()
	dialogue_panel.add_child(dialog_col)
	dialogue_label = Label.new()
	dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue_label.custom_minimum_size = Vector2(640, 90)
	dialog_col.add_child(dialogue_label)
	dialogue_input = LineEdit.new()
	dialogue_input.placeholder_text = "Type what your character says..."
	dialogue_input.text_submitted.connect(_send_dialogue)
	dialog_col.add_child(dialogue_input)
	var actions := HBoxContainer.new()
	dialog_col.add_child(actions)
	var send := Button.new()
	send.text = "SAY IT"
	send.pressed.connect(func(): _send_dialogue(dialogue_input.text))
	actions.add_child(send)
	var close := Button.new()
	close.text = "CLOSE"
	close.pressed.connect(func(): dialogue_panel.hide())
	actions.add_child(close)
	_fit_hud()

func _fit_hud() -> void:
	if dialogue_panel:
		var size := get_viewport_rect().size
		dialogue_panel.position = Vector2(max(12, (size.x - 680) / 2), size.y - 250)
		dialogue_panel.custom_minimum_size.x = min(680, size.x - 24)

func _refresh_stage() -> void:
	for child in world_layer.get_children():
		if child != player_sprite and child != camera:
			child.queue_free()
	npc_nodes.clear()
	var data: Dictionary = STAGES[stage_index]
	stage_title.text = "LIFE JOURNEY  /  " + str(data.name).to_upper()
	stage_subtitle.text = str(data.place)
	prompt.text = "Explore the scene. Walk close to someone to start a conversation."
	_build_backdrop()
	for npc_data in data.npcs:
		_add_npc(npc_data)
	player_position = Vector2(260, 500)
	player_sprite.position = player_position
	camera.position = player_position
	dialogue_panel.hide()
	queue_redraw()

func _build_backdrop() -> void:
	var backdrop := Node2D.new()
	backdrop.name = "SceneBackdrop"
	world_layer.add_child(backdrop)
	backdrop.draw.connect(func(): _draw_stage(backdrop))

func _draw_stage(canvas: Node2D) -> void:
	var w := 1500.0
	var h := 820.0
	var sky := Color("#b9d5e6")
	var ground := Color("#668b58")
	match stage_index:
		0:
			sky = Color("#b7d6e8"); ground = Color("#78945c")
		1:
			sky = Color("#b9c8d0"); ground = Color("#8b8b70")
		2:
			sky = Color("#a9cfe5"); ground = Color("#69915c")
		3:
			sky = Color("#d7c5a6"); ground = Color("#8b9870")
	canvas.draw_rect(Rect2(-1000,-1000,3500,1250), sky)
	canvas.draw_rect(Rect2(-1000,540,3500,500), ground)
	# Distant hills/trees and a wide walking path create a layered 2D scene.
	for i in range(9):
		var x := -100.0 + i * 210.0
		canvas.draw_circle(Vector2(x, 490), 85, Color("#527b4b"))
		canvas.draw_rect(Rect2(x-13,490,26,100), Color("#70513a"))
	canvas.draw_rect(Rect2(-100, 545, 1800, 110), Color("#c9b99b"))
	if stage_index == 0:
		_draw_building(canvas, Vector2(640, 230), Vector2(720, 270), "PRIMARY SCHOOL", Color("#d6b985"))
		canvas.draw_rect(Rect2(450, 270, 380, 130), Color("#294d45"))
		canvas.draw_string(ThemeDB.fallback_font, Vector2(550,340), "CLASSROOM", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color.WHITE)
		for x in range(470, 830, 90):
			canvas.draw_rect(Rect2(x,420,58,45), Color("#79563c"))
	elif stage_index == 1:
		_draw_building(canvas, Vector2(640, 220), Vector2(760, 290), "STUDENT HOSTEL", Color("#d0bda0"))
		for x in range(440, 850, 110):
			canvas.draw_rect(Rect2(x,280,70,70), Color("#6b8795"))
		canvas.draw_rect(Rect2(360, 500, 580, 65), Color("#a38c70"))
		canvas.draw_string(ThemeDB.fallback_font, Vector2(530,545), "COMMON ROOM", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)
	elif stage_index == 2:
		_draw_building(canvas, Vector2(640, 220), Vector2(800, 300), "UNIVERSITY CAMPUS", Color("#d9d4c2"))
		canvas.draw_rect(Rect2(450,270,380,145), Color("#31574d"))
		canvas.draw_string(ThemeDB.fallback_font, Vector2(545,350), "LECTURE THEATRE", HORIZONTAL_ALIGNMENT_LEFT, -1, 25, Color.WHITE)
		canvas.draw_rect(Rect2(180,480,250,80), Color("#c7b99f"))
		canvas.draw_string(ThemeDB.fallback_font, Vector2(235,530), "STUDENT CENTRE", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("#292929"))
	else:
		_draw_building(canvas, Vector2(640, 230), Vector2(520, 270), "WORK & COMMUNITY", Color("#d7c1a2"))
		canvas.draw_rect(Rect2(400,280,480,130), Color("#667c83"))
		canvas.draw_string(ThemeDB.fallback_font, Vector2(550,350), "OFFICE", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color.WHITE)
		canvas.draw_rect(Rect2(0,570,1500,16), Color("#484848"))

func _draw_building(canvas: Node2D, center: Vector2, size: Vector2, sign_text: String, wall: Color) -> void:
	canvas.draw_rect(Rect2(center-size/2, size), wall)
	canvas.draw_rect(Rect2(center.x-size.x/2-18, center.y-size.y/2-28, size.x+36, 34), Color("#72513b"))
	canvas.draw_rect(Rect2(center.x-60, center.y+30, 120, size.y/2-30), Color("#66462f"))
	canvas.draw_string(ThemeDB.fallback_font, Vector2(center.x-160,center.y-size.y/2+65), sign_text, HORIZONTAL_ALIGNMENT_LEFT, 360, 25, Color("#292929"))

func _add_npc(data: Dictionary) -> void:
	var npc := Sprite2D.new()
	npc.name = str(data.name)
	npc.position = Vector2(data.x, data.y)
	var path := str(data.portrait)
	if ResourceLoader.exists(path):
		npc.texture = load(path) as Texture2D
		npc.scale = _fit_texture(npc.texture, Vector2(95, 175))
	else:
		npc.texture = _make_portrait_placeholder(Color("#d5a27c"), Color("#394a62"))
		npc.scale = Vector2(1,1)
	world_layer.add_child(npc)
	npc_nodes.append({"node":npc,"data":data})
	var tag := Label.new()
	tag.text = str(data.name) + " • " + str(data.role)
	tag.position = npc.position + Vector2(-70, 92)
	tag.add_theme_color_override("font_color", Color("#ffffff"))
	tag.add_theme_color_override("font_shadow_color", Color("#202020"))
	tag.add_theme_constant_override("shadow_offset_x", 2)
	tag.add_theme_constant_override("shadow_offset_y", 2)
	world_layer.add_child(tag)
	npc.set_meta("tag", tag)

func _make_portrait_placeholder(skin: Color, shirt: Color) -> Texture2D:
	var image := Image.create(180, 300, false, Image.FORMAT_RGBA8)
	image.fill(Color(0,0,0,0))
	image.fill_rect(Rect2i(55,8,70,78), skin)
	image.fill_rect(Rect2i(42,84,96,150), shirt)
	image.fill_rect(Rect2i(48,230,36,70), Color("#242a35"))
	image.fill_rect(Rect2i(96,230,36,70), Color("#242a35"))
	image.fill_rect(Rect2i(22,110,25,105), shirt)
	image.fill_rect(Rect2i(133,110,25,105), shirt)
	return ImageTexture.create_from_image(image)

func _process(delta: float) -> void:
	if dialogue_panel.visible:
		return
	var direction := Vector2.ZERO
	direction.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	direction.y = Input.get_action_strength("move_back") - Input.get_action_strength("move_forward")
	if Input.is_key_pressed(KEY_RIGHT): direction.x += 1
	if Input.is_key_pressed(KEY_LEFT): direction.x -= 1
	if Input.is_key_pressed(KEY_UP): direction.y -= 1
	if Input.is_key_pressed(KEY_DOWN): direction.y += 1
	direction = direction.normalized()
	player_position += direction * player_speed * delta
	player_position.x = clamp(player_position.x, 80.0, 1420.0)
	player_position.y = clamp(player_position.y, 400.0, 590.0)
	player_sprite.position = player_position
	if direction.x != 0:
		player_facing = sign(direction.x)
		player_sprite.flip_h = player_facing < 0
	camera.position = camera.position.lerp(player_position, min(1.0, delta * 5.0))
	var nearest := _nearest_npc()
	if nearest.is_empty():
		prompt.text = "Explore • Move with WASD or arrow keys • Walk close to someone and press E / TALK"
	else:
		prompt.text = "Nearby: %s — press E or TALK" % nearest.data.name
	if Input.is_action_just_pressed("interact") or Input.is_key_pressed(KEY_E):
		_talk_nearest()

func _nearest_npc() -> Dictionary:
	var nearest := {}
	var best := 125.0
	for entry in npc_nodes:
		var node: Sprite2D = entry.node
		var distance := node.position.distance_to(player_position)
		if distance < best:
			best = distance
			nearest = entry
	return nearest

func _talk_nearest() -> void:
	var entry := _nearest_npc()
	if entry.is_empty():
		prompt.text = "Move closer to a person first."
		return
	current_npc = entry.data
	dialogue_label.text = "%s (%s): %s\n\nWhat would you like to say?" % [current_npc.name, current_npc.role, current_npc.line]
	dialogue_input.clear()
	dialogue_panel.show()
	dialogue_input.grab_focus()

func _send_dialogue(words: String) -> void:
	var text := words.strip_edges()
	if text.is_empty():
		return
	dialogue_label.text = "YOU: %s\n%s: %s" % [text, current_npc.name, _reply(text)]
	dialogue_input.clear()

func _reply(words: String) -> String:
	var message := words.to_lower()
	if message.contains("hello") or message.contains("hi") or message.contains("moni"):
		return "Moni! I'm glad you came over. How are you?"
	if message.contains("football"):
		return "I follow football too. Which player do you think is the best?"
	if message.contains("music") or message.contains("song"):
		return "What have you been listening to lately?"
	if message.contains("lesson") or message.contains("study") or message.contains("assignment"):
		return "Let's discuss it. Which part should we start with?"
	if message.contains("love") or message.contains("girlfriend") or message.contains("date"):
		return "Let's get to know each other first. Tell me what matters to you."
	if message.contains("home") or message.contains("family"):
		return "Family is important. How is everyone at home?"
	if message.contains("work") or message.contains("job") or message.contains("business"):
		return "What are your goals for the next few years?"
	return "I hear you. Tell me more — what happened after that?"

func _next_stage() -> void:
	stage_index = (stage_index + 1) % STAGES.size()
	_refresh_stage()
