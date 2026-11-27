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

func _ready() -> void:
	_build_character()
	if not OS.has_feature("mobile"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _build_character() -> void:
	var body_mesh := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.36
	capsule.height = 1.72
	body_mesh.mesh = capsule
	body_mesh.position.y = 0.9
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color(0.48, 0.29, 0.19)
	skin.roughness = 0.82
	body_mesh.material_override = skin
	add_child(body_mesh)

	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.36
	shape.height = 1.72
	collision.shape = shape
	collision.position.y = 0.9
	add_child(collision)

	camera_pivot = Node3D.new()
	camera_pivot.position.y = 1.55
	add_child(camera_pivot)
	camera = Camera3D.new()
	camera.position = Vector3(0, 0.65, 4.8)
	camera.rotation.x = deg_to_rad(-8.0)
	camera.current = true
	camera_pivot.add_child(camera)

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
