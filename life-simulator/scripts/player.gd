extends CharacterBody3D
class_name LifePlayer

@export var walk_speed := 5.2
@export var run_speed := 8.0
@export var jump_velocity := 4.5
@export var mouse_sensitivity := 0.0025

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var camera_pivot: Node3D
var camera: Camera3D
var mobile_move := Vector2.ZERO
var mobile_run := false
var mobile_jump := false
var arm_pivots: Array[Node3D] = []
var leg_pivots: Array[Node3D] = []

func _ready() -> void:
	_build_character()
	if not OS.has_feature("mobile"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _capsule_part(parent: Node3D, part_name: String, radius: float, height: float, color: Color, local_pos: Vector3) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = part_name
	var capsule := CapsuleMesh.new()
	capsule.radius = radius
	capsule.height = height
	mesh_instance.mesh = capsule
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.78
	mesh_instance.material_override = material
	mesh_instance.position = local_pos
	parent.add_child(mesh_instance)
	return mesh_instance

func _build_character() -> void:
	# A readable third-person human silhouette built from separate articulated parts.
	# The collision capsule remains independent of the visible model.
	_capsule_part(self, "Jacket", 0.31, 0.82, Color(0.12, 0.28, 0.62), Vector3(0, 1.12, 0))
	_capsule_part(self, "Neck", 0.105, 0.22, Color(0.48, 0.29, 0.19), Vector3(0, 1.62, 0))
	var head := MeshInstance3D.new()
	head.name = "Head"
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.235
	head_mesh.height = 0.47
	head.mesh = head_mesh
	head.position = Vector3(0, 1.88, 0)
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color(0.48, 0.29, 0.19)
	head.material_override = skin
	add_child(head)
	var hair := MeshInstance3D.new()
	var hair_mesh := SphereMesh.new()
	hair_mesh.radius = 0.24
	hair_mesh.height = 0.22
	hair.mesh = hair_mesh
	hair.position = Vector3(0, 2.04, -0.025)
	var hair_material := StandardMaterial3D.new()
	hair_material.albedo_color = Color(0.055, 0.04, 0.03)
	hair.material_override = hair_material
	add_child(hair)

	for side in [-1.0, 1.0]:
		var arm := Node3D.new()
		arm.name = "ArmPivot_%s" % str(side)
		arm.position = Vector3(side * 0.39, 1.43, 0)
		add_child(arm)
		_capsule_part(arm, "Sleeve", 0.115, 0.72, Color(0.12, 0.28, 0.62), Vector3(0, -0.34, 0))
		_capsule_part(arm, "Hand", 0.085, 0.19, Color(0.48, 0.29, 0.19), Vector3(0, -0.77, 0))
		arm_pivots.append(arm)
		var leg := Node3D.new()
		leg.name = "LegPivot_%s" % str(side)
		leg.position = Vector3(side * 0.17, 0.78, 0)
		add_child(leg)
		_capsule_part(leg, "Trousers", 0.145, 0.78, Color(0.12, 0.13, 0.17), Vector3(0, -0.34, 0))
		_capsule_part(leg, "Shoe", 0.13, 0.25, Color(0.045, 0.04, 0.035), Vector3(0, -0.76, -0.045))
		leg_pivots.append(leg)

	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.32
	shape.height = 1.85
	collision.shape = shape
	collision.position.y = 0.94
	add_child(collision)

	camera_pivot = Node3D.new()
	camera_pivot.position.y = 1.55
	add_child(camera_pivot)
	camera = Camera3D.new()
	camera.position = Vector3(0, 0.65, 4.8)
	camera.rotation.x = deg_to_rad(-8.0)
	camera.current = true
	camera_pivot.add_child(camera)

func _animate_character() -> void:
	var moving := Vector2(velocity.x, velocity.z).length() > 0.35
	var phase := float(Time.get_ticks_msec()) * (0.012 if mobile_run or Input.is_action_pressed("run") else 0.008)
	var swing := sin(phase) * 0.62 if moving else 0.0
	for i in range(arm_pivots.size()):
		arm_pivots[i].rotation.x = swing * (1.0 if i == 0 else -1.0)
	for i in range(leg_pivots.size()):
		leg_pivots[i].rotation.x = -swing * (1.0 if i == 0 else -1.0)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_rotate_camera(event.relative)
	elif event is InputEventScreenDrag:
		_rotate_camera(event.relative)
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _rotate_camera(relative: Vector2) -> void:
	camera_pivot.rotate_y(-relative.x * mouse_sensitivity)
	camera.rotate_x(-relative.y * mouse_sensitivity)
	camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-50), deg_to_rad(35))

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	if (Input.is_action_just_pressed("jump") or mobile_jump) and is_on_floor():
		velocity.y = jump_velocity
	mobile_jump = false

	var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	input_vector = (input_vector + mobile_move).limit_length(1.0)
	var yaw_basis := Basis(Vector3.UP, camera_pivot.global_rotation.y)
	var direction := (yaw_basis * Vector3(input_vector.x, 0, input_vector.y)).normalized()
	var speed := run_speed if Input.is_action_pressed("run") or mobile_run else walk_speed
	if direction.length() > 0.01:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		look_at(global_position + Vector3(direction.x, 0, direction.z), Vector3.UP)
	else:
		velocity.x = move_toward(velocity.x, 0.0, walk_speed * 5.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, walk_speed * 5.0 * delta)
	move_and_slide()
	_animate_character()
