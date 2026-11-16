extends CharacterBody3D

@export var move_speed: float = 7.0
@export var jump_velocity: float = 5.5
@export var look_sensitivity: float = 0.0035

var move_input: Vector2 = Vector2.ZERO
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var camera_pitch: float = -0.22
var camera_pivot: Node3D

func _ready() -> void:
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.42
	capsule.height = 1.8
	collision.shape = capsule
	collision.position.y = 0.9
	add_child(collision)

	var body_mesh := MeshInstance3D.new()
	var capsule_mesh := CapsuleMesh.new()
	capsule_mesh.radius = 0.42
	capsule_mesh.height = 1.8
	body_mesh.mesh = capsule_mesh
	body_mesh.position.y = 0.9
	var body_material := StandardMaterial3D.new()
	body_material.albedo_color = Color(0.12, 0.62, 0.82)
	body_material.roughness = 0.85
	body_mesh.material_override = body_material
	add_child(body_mesh)

	camera_pivot = Node3D.new()
	camera_pivot.position = Vector3(0, 1.55, 0)
	camera_pivot.rotation.x = camera_pitch
	add_child(camera_pivot)

	var camera := Camera3D.new()
	camera.position = Vector3(0, 2.2, 6.5)
	camera.current = true
	camera.fov = 75.0
	camera_pivot.add_child(camera)
	_add_pixel_blaster(camera)

func _add_pixel_blaster(camera: Camera3D) -> void:
	var blaster := Node3D.new()
	blaster.name = "PixelEnergyBlaster"
	blaster.position = Vector3(0.43, -0.43, -0.78)
	blaster.rotation_degrees = Vector3(-5, -8, 0)
	camera.add_child(blaster)
	var body_material := _blaster_material(Color(0.12, 0.48, 0.72))
	var bright_material := _blaster_material(Color(0.18, 0.86, 0.96))
	var dark_material := _blaster_material(Color(0.12, 0.16, 0.22))
	var glow_material := _blaster_material(Color(0.2, 0.9, 1.0), true)
	_add_blaster_block(blaster, Vector3(0.0, 0.0, 0.0), Vector3(0.28, 0.25, 0.72), body_material)
	_add_blaster_block(blaster, Vector3(0.0, 0.13, -0.08), Vector3(0.22, 0.13, 0.38), bright_material)
	_add_blaster_block(blaster, Vector3(0.0, -0.22, 0.16), Vector3(0.18, 0.34, 0.22), dark_material)
	_add_blaster_block(blaster, Vector3(0.0, 0.0, -0.43), Vector3(0.34, 0.28, 0.18), dark_material)
	_add_blaster_block(blaster, Vector3(0.0, 0.0, -0.54), Vector3(0.2, 0.16, 0.05), glow_material)
	_add_blaster_block(blaster, Vector3(0.18, 0.04, 0.08), Vector3(0.1, 0.12, 0.3), bright_material)

func _blaster_material(tint: Color, glowing: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = 0.8
	if glowing:
		material.emission_enabled = true
		material.emission = tint
		material.emission_energy_multiplier = 1.4
	return material

func _add_blaster_block(parent: Node3D, at: Vector3, dimensions: Vector3, material: Material) -> void:
	var block := MeshInstance3D.new()
	var cube := BoxMesh.new()
	cube.size = dimensions
	block.mesh = cube
	block.position = at
	block.material_override = material
	block.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(block)

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity

	var input_vector := move_input
	if input_vector.length() < 0.05:
		input_vector = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		input_vector.y = -input_vector.y
	input_vector = input_vector.limit_length(1.0)

	var camera_yaw := camera_pivot.global_rotation.y
	var forward := Vector3(sin(camera_yaw), 0.0, cos(camera_yaw))
	var right := Vector3(forward.z, 0.0, -forward.x)
	var direction := (right * input_vector.x - forward * input_vector.y).normalized()

	velocity.x = direction.x * move_speed
	velocity.z = direction.z * move_speed
	move_and_slide()

func rotate_view(delta_pixels: Vector2) -> void:
	camera_pivot.rotation.y -= delta_pixels.x * look_sensitivity
	camera_pitch = clamp(camera_pitch - delta_pixels.y * look_sensitivity, -0.95, 0.25)
	camera_pivot.rotation.x = camera_pitch

func set_move_input(value: Vector2) -> void:
	move_input = value
