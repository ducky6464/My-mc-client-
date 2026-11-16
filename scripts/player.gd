extends CharacterBody3D

@export var move_speed: float = 7.0
@export var jump_velocity: float = 5.5
@export var look_sensitivity: float = 0.0035

var move_input: Vector2 = Vector2.ZERO
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var camera_pitch: float = -0.22
var camera_pivot: Node3D
var blaster_camera: Camera3D
var blaster_root: Node3D

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
	blaster_camera = camera
	equip_blaster(0)

func equip_blaster(weapon_id: int) -> void:
	if not is_instance_valid(blaster_camera):
		return
	if is_instance_valid(blaster_root):
		blaster_root.queue_free()
	blaster_root = Node3D.new()
	blaster_root.name = "PixelBlaster_%d" % weapon_id
	blaster_root.position = Vector3(0.43, -0.43, -0.78)
	blaster_root.rotation_degrees = Vector3(-5, -8, 0)
	blaster_camera.add_child(blaster_root)

	var palettes := [
		[Color(0.16, 0.2, 0.27), Color(0.28, 0.34, 0.42), Color(0.12, 0.68, 0.82), Color(0.2, 0.9, 1.0)],
		[Color(0.12, 0.25, 0.18), Color(0.22, 0.4, 0.28), Color(0.35, 0.9, 0.45), Color(0.55, 1.0, 0.58)],
		[Color(0.27, 0.16, 0.32), Color(0.4, 0.25, 0.48), Color(0.78, 0.35, 0.95), Color(0.9, 0.58, 1.0)],
		[Color(0.12, 0.2, 0.34), Color(0.22, 0.34, 0.52), Color(0.28, 0.62, 1.0), Color(0.55, 0.82, 1.0)],
		[Color(0.34, 0.2, 0.12), Color(0.48, 0.3, 0.18), Color(1.0, 0.58, 0.2), Color(1.0, 0.78, 0.35)],
		[Color(0.3, 0.14, 0.12), Color(0.48, 0.22, 0.16), Color(1.0, 0.3, 0.18), Color(1.0, 0.58, 0.3)],
		[Color(0.12, 0.28, 0.3), Color(0.18, 0.42, 0.45), Color(0.2, 0.9, 0.82), Color(0.5, 1.0, 0.9)],
		[Color(0.25, 0.18, 0.34), Color(0.38, 0.26, 0.5), Color(0.72, 0.42, 1.0), Color(0.88, 0.68, 1.0)]
	]
	var palette: Array = palettes[posmod(weapon_id, palettes.size())]
	var body_material := _blaster_material(palette[0])
	var top_material := _blaster_material(palette[1])
	var accent_material := _blaster_material(palette[2])
	var glow_material := _blaster_material(palette[3], true)
	var grip_material := _blaster_material(Color(0.08, 0.11, 0.16))
	var barrel_width := 0.2
	var barrel_length := 0.48
	match weapon_id:
		1:
			barrel_width = 0.15
			barrel_length = 0.34
		2:
			barrel_width = 0.24
			barrel_length = 0.42
		3:
			barrel_width = 0.13
			barrel_length = 0.72
		4:
			barrel_width = 0.32
			barrel_length = 0.28
		5:
			barrel_width = 0.3
			barrel_length = 0.58
		6:
			barrel_width = 0.14
			barrel_length = 0.36
		7:
			barrel_width = 0.28
			barrel_length = 0.3

	# Chunky, nonfunctional voxel-style sci-fi props. Each pickup has its own silhouette and palette.
	_add_blaster_block(blaster_root, Vector3(0.0, 0.0, 0.02), Vector3(0.34, 0.3, 0.62), body_material)
	_add_blaster_block(blaster_root, Vector3(0.0, 0.015, -0.35 - barrel_length * 0.5), Vector3(barrel_width, 0.19, barrel_length), top_material)
	_add_blaster_block(blaster_root, Vector3(0.0, 0.015, -0.35 - barrel_length), Vector3(barrel_width + 0.08, 0.25, 0.16), accent_material)
	_add_blaster_block(blaster_root, Vector3(0.0, 0.015, -0.35 - barrel_length - 0.08), Vector3(barrel_width * 0.62, 0.15, 0.06), glow_material)
	_add_blaster_block(blaster_root, Vector3(0.0, 0.015, 0.43), Vector3(0.3, 0.24, 0.34), top_material)
	_add_blaster_block(blaster_root, Vector3(0.0, 0.19, -0.08), Vector3(0.18, 0.09, 0.25), accent_material)
	_add_blaster_block(blaster_root, Vector3(0.0, 0.27, -0.08), Vector3(0.1, 0.08, 0.1), body_material)
	_add_blaster_block(blaster_root, Vector3(0.0, -0.25, 0.17), Vector3(0.2, 0.38, 0.22), grip_material)
	_add_blaster_block(blaster_root, Vector3(0.0, -0.18, -0.06), Vector3(0.24, 0.08, 0.16), accent_material)
	if weapon_id == 4 or weapon_id == 6:
		_add_blaster_block(blaster_root, Vector3(-0.2, 0.0, -0.05), Vector3(0.12, 0.22, 0.5), top_material)
		_add_blaster_block(blaster_root, Vector3(0.2, 0.0, -0.05), Vector3(0.12, 0.22, 0.5), top_material)
	if weapon_id == 5 or weapon_id == 7:
		_add_blaster_block(blaster_root, Vector3(0.0, 0.22, -0.12), Vector3(0.32, 0.16, 0.3), glow_material)
	if weapon_id == 3:
		_add_blaster_block(blaster_root, Vector3(0.0, 0.3, -0.12), Vector3(0.14, 0.16, 0.42), accent_material)

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
