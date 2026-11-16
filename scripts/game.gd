extends Node3D

const PlayerScript = preload("res://scripts/player.gd")
const JoystickScript = preload("res://scripts/touch_joystick.gd")
const ROUND_SECONDS := 180.0
const MAP_SIZE := 220.0
const START_ZONE_RADIUS := 104.0
const FINAL_ZONE_RADIUS := 18.0
const SAVE_PATH := "user://skybound_save.cfg"
const SCOUT_COUNT := 6
const BEACON_COUNT := 24

var player: CharacterBody3D
var joystick: TouchJoystick
var jump_button: Button
var fire_button: Button
var score := 0
var seconds_left := ROUND_SECONDS
var elapsed := 0.0
var best_score := 0
var saved_sensitivity := 0.0035
var score_label: Label
var fps_label: Label
var zone_label: Label
var energy_label: Label
var fps_update_accumulator := 0.0
var last_displayed_second := -1
var message_label: Label
var timer_label: Label
var pause_button: Button
var overlay: ColorRect
var overlay_title: Label
var overlay_button: Button
var menu_settings_button: Button
var settings_label: Label
var sensitivity_slider: HSlider
var round_ended := false
var is_paused := false
var game_started := false
var overlay_mode := "menu"
var energy := 100.0
var zone_radius := START_ZONE_RADIUS
var zone_ring: MeshInstance3D
var beacons: Array[Area3D] = []
var scouts: Array[Node3D] = []
var scout_scores: Array[int] = []
var scout_tagged: Array[bool] = []
var scout_contact_cooldowns: Array[float] = []
var player_tags := 0
var player_tag_cooldown := 0.0
var fire_cooldown := 0.0
var projectiles: Array[Node3D] = []
var projectile_directions: Array[Vector3] = []
var projectile_lifetimes: Array[float] = []
var tagged_bots := 0
var tags_label: Label
var scout_targets: Array[Area3D] = []
var scout_retarget_timer := 0.0
var beacon_mesh: CylinderMesh
var beacon_material: StandardMaterial3D
var tree_trunk_mesh: CylinderMesh
var tree_leaf_mesh: ConeMesh
var building_materials: Array[StandardMaterial3D] = []

func _ready() -> void:
	randomize()
	_load_progress()
	_build_world()
	_build_player()
	_build_ui()
	_show_main_menu()

func _build_world() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.48, 0.69, 0.82)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.78, 0.84, 0.9)
	env.ambient_light_energy = 0.85
	environment.environment = env
	add_child(environment)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -25, 0)
	sun.light_energy = 1.05
	sun.shadow_enabled = false
	add_child(sun)

	var ground := StaticBody3D.new()
	ground.name = "IslandGround"
	var ground_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(MAP_SIZE, MAP_SIZE)
	ground_mesh.mesh = plane
	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_color = Color(0.28, 0.42, 0.29)
	ground_mat.roughness = 1.0
	ground_mesh.material_override = ground_mat
	ground_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ground.add_child(ground_mesh)
	var ground_collision := CollisionShape3D.new()
	var ground_shape := BoxShape3D.new()
	ground_shape.size = Vector3(MAP_SIZE, 0.5, MAP_SIZE)
	ground_collision.shape = ground_shape
	ground_collision.position.y = -0.25
	ground.add_child(ground_collision)
	add_child(ground)

	_add_road(Vector3(0, 0.012, 0), Vector2(12, MAP_SIZE))
	_add_road(Vector3(0, 0.014, 0), Vector2(MAP_SIZE, 10))
	_build_settlement()
	_build_forest()
	_build_zone_ring()
	_build_beacons()
	_build_scouts()

func _add_road(at: Vector3, dimensions: Vector2) -> void:
	var road := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = dimensions
	road.mesh = mesh
	road.position = at
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.24, 0.26, 0.25)
	material.roughness = 1.0
	road.material_override = material
	road.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(road)

func _build_settlement() -> void:
	var positions := [
		Vector3(-48, 0, -42), Vector3(-31, 0, -47), Vector3(-45, 0, -24),
		Vector3(38, 0, -48), Vector3(55, 0, -35), Vector3(43, 0, -20),
		Vector3(-52, 0, 38), Vector3(-34, 0, 48), Vector3(-48, 0, 57),
		Vector3(37, 0, 38), Vector3(53, 0, 48), Vector3(42, 0, 60),
		Vector3(-78, 0, 4), Vector3(78, 0, -5), Vector3(4, 0, 78), Vector3(-8, 0, -78)
	]
	var colors := [
		Color(0.68, 0.52, 0.36), Color(0.61, 0.65, 0.68),
		Color(0.72, 0.66, 0.48), Color(0.49, 0.59, 0.62)
	]
	for i in range(positions.size()):
		var size := Vector3(8.0 + float(i % 3), 5.0 + float(i % 2), 7.0 + float((i + 1) % 3))
		_add_building(positions[i], size, colors[i % colors.size()], i)

func _add_building(at: Vector3, dimensions: Vector3, tint: Color, index: int) -> void:
	var building := StaticBody3D.new()
	building.name = "Cabin_%02d" % index
	building.position = at
	var body_mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = dimensions
	body_mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = 0.95
	body_mesh.material_override = material
	body_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	building.add_child(body_mesh)

	var roof_mesh := MeshInstance3D.new()
	var roof := BoxMesh.new()
	roof.size = Vector3(dimensions.x + 1.2, 0.65, dimensions.z + 1.2)
	roof_mesh.mesh = roof
	roof_mesh.position.y = dimensions.y * 0.5 + 0.28
	var roof_material := StandardMaterial3D.new()
	roof_material.albedo_color = Color(0.25, 0.29, 0.31)
	roof_material.roughness = 1.0
	roof_mesh.material_override = roof_material
	roof_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	building.add_child(roof_mesh)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = dimensions
	collision.shape = shape
	collision.position.y = dimensions.y * 0.5
	building.add_child(collision)
	add_child(building)

func _build_forest() -> void:
	tree_trunk_mesh = CylinderMesh.new()
	tree_trunk_mesh.top_radius = 0.22
	tree_trunk_mesh.bottom_radius = 0.38
	tree_trunk_mesh.height = 2.4
	tree_leaf_mesh = ConeMesh.new()
	tree_leaf_mesh.radius = 1.45
	tree_leaf_mesh.height = 3.6
	var trunk_material := StandardMaterial3D.new()
	trunk_material.albedo_color = Color(0.31, 0.21, 0.13)
	var leaf_material := StandardMaterial3D.new()
	leaf_material.albedo_color = Color(0.12, 0.31, 0.17)
	for i in range(54):
		var x := randf_range(-96.0, 96.0)
		var z := randf_range(-96.0, 96.0)
		if absf(x) < 20.0 or absf(z) < 18.0:
			continue
		if _near_building(Vector2(x, z), 10.0):
			continue
		var tree := Node3D.new()
		tree.position = Vector3(x, 0, z)
		var trunk := MeshInstance3D.new()
		trunk.mesh = tree_trunk_mesh
		trunk.position.y = 1.2
		trunk.material_override = trunk_material
		trunk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		tree.add_child(trunk)
		var leaves := MeshInstance3D.new()
		leaves.mesh = tree_leaf_mesh
		leaves.position.y = 3.25
		leaves.material_override = leaf_material
		leaves.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		tree.add_child(leaves)
		add_child(tree)

func _near_building(point: Vector2, padding: float) -> bool:
	var centers := [
		Vector2(-48, -42), Vector2(-31, -47), Vector2(-45, -24),
		Vector2(38, -48), Vector2(55, -35), Vector2(43, -20),
		Vector2(-52, 38), Vector2(-34, 48), Vector2(-48, 57),
		Vector2(37, 38), Vector2(53, 48), Vector2(42, 60),
		Vector2(-78, 4), Vector2(78, -5), Vector2(4, 78), Vector2(-8, -78)
	]
	for center in centers:
		if point.distance_to(center) < padding:
			return true
	return false

func _build_zone_ring() -> void:
	zone_ring = MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.96
	ring.outer_radius = 1.0
	ring.rings = 8
	ring.ring_segments = 72
	zone_ring.mesh = ring
	zone_ring.position.y = 0.18
	var ring_material := StandardMaterial3D.new()
	ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_material.albedo_color = Color(0.18, 0.78, 1.0, 0.9)
	ring_material.emission_enabled = true
	ring_material.emission = Color(0.08, 0.42, 0.9)
	ring_material.emission_energy_multiplier = 1.2
	zone_ring.material_override = ring_material
	zone_ring.scale = Vector3(START_ZONE_RADIUS, 1.0, START_ZONE_RADIUS)
	zone_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(zone_ring)

func _build_beacons() -> void:
	beacon_mesh = CylinderMesh.new()
	beacon_mesh.top_radius = 0.28
	beacon_mesh.bottom_radius = 0.42
	beacon_mesh.height = 1.1
	beacon_mesh.radial_segments = 6
	beacon_material = StandardMaterial3D.new()
	beacon_material.albedo_color = Color(0.95, 0.72, 0.23)
	beacon_material.emission_enabled = true
	beacon_material.emission = Color(0.45, 0.2, 0.025)
	beacon_material.emission_energy_multiplier = 0.65
	for i in range(BEACON_COUNT):
		var angle := TAU * float(i) / float(BEACON_COUNT) + randf_range(-0.16, 0.16)
		var distance := randf_range(15.0, 92.0)
		var point := Vector2(cos(angle) * distance, sin(angle) * distance)
		if _near_building(point, 8.0):
			point += Vector2(12.0, 9.0)
		_add_beacon(Vector3(point.x, 0.65, point.y), i)

func _add_beacon(at: Vector3, index: int) -> void:
	var beacon := Area3D.new()
	beacon.name = "SupplyBeacon_%02d" % index
	beacon.position = at
	beacon.set_meta("collected", false)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = beacon_mesh
	mesh_instance.material_override = beacon_material
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beacon.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 1.35
	collision.shape = shape
	beacon.add_child(collision)
	beacon.body_entered.connect(_on_beacon_body_entered.bind(beacon))
	add_child(beacon)
	beacons.append(beacon)

func _build_scouts() -> void:
	var scout_materials: Array[Color] = [
		Color(0.9, 0.42, 0.24), Color(0.72, 0.42, 0.9),
		Color(0.9, 0.82, 0.3), Color(0.25, 0.72, 0.55),
		Color(0.85, 0.48, 0.65), Color(0.45, 0.68, 0.92)
	]
	for i in range(SCOUT_COUNT):
		var scout := Node3D.new()
		scout.name = "Scout_%02d" % (i + 1)
		var angle := TAU * float(i) / float(SCOUT_COUNT)
		scout.position = Vector3(cos(angle) * 72.0, 0, sin(angle) * 72.0)
		var body := MeshInstance3D.new()
		var capsule := CapsuleMesh.new()
		capsule.radius = 0.42
		capsule.height = 1.8
		body.mesh = capsule
		var material := StandardMaterial3D.new()
		material.albedo_color = scout_materials[i]
		material.roughness = 0.85
		body.material_override = material
		body.position.y = 0.9
		body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		scout.add_child(body)
		add_child(scout)
		scouts.append(scout)
		scout_scores.append(0)
		scout_tagged.append(false)
		scout_contact_cooldowns.append(0.0)
		scout_targets.append(null)

func _build_player() -> void:
	player = PlayerScript.new()
	player.name = "Player"
	player.position = Vector3(0, 0.2, 0)
	player.look_sensitivity = saved_sensitivity
	add_child(player)
	player.set_physics_process(false)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)

	score_label = Label.new()
	score_label.position = Vector2(24, 18)
	score_label.add_theme_font_size_override("font_size", 24)
	score_label.add_theme_color_override("font_color", Color.WHITE)
	layer.add_child(score_label)

	timer_label = Label.new()
	timer_label.anchor_left = 0.5
	timer_label.anchor_right = 0.5
	timer_label.position = Vector2(-70, 18)
	timer_label.size = Vector2(140, 42)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.add_theme_font_size_override("font_size", 26)
	timer_label.add_theme_color_override("font_color", Color(0.8, 0.96, 1.0))
	layer.add_child(timer_label)

	fps_label = Label.new()
	fps_label.anchor_left = 1.0
	fps_label.anchor_right = 1.0
	fps_label.position = Vector2(-150, 76)
	fps_label.size = Vector2(130, 28)
	fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	fps_label.add_theme_font_size_override("font_size", 17)
	fps_label.add_theme_color_override("font_color", Color(0.72, 0.86, 0.92, 0.9))
	layer.add_child(fps_label)

	message_label = Label.new()
	message_label.anchor_left = 0.5
	message_label.anchor_right = 0.5
	message_label.position = Vector2(-260, 62)
	message_label.size = Vector2(520, 38)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.add_theme_font_size_override("font_size", 18)
	message_label.add_theme_color_override("font_color", Color(0.9, 0.96, 1.0))
	layer.add_child(message_label)

	zone_label = Label.new()
	zone_label.position = Vector2(24, 56)
	zone_label.size = Vector2(260, 30)
	zone_label.add_theme_font_size_override("font_size", 17)
	zone_label.add_theme_color_override("font_color", Color(0.55, 0.88, 1.0))
	layer.add_child(zone_label)

	energy_label = Label.new()
	energy_label.position = Vector2(24, 82)
	energy_label.size = Vector2(260, 30)
	energy_label.add_theme_font_size_override("font_size", 17)
	energy_label.add_theme_color_override("font_color", Color(0.65, 1.0, 0.75))
	layer.add_child(energy_label)

	pause_button = Button.new()
	pause_button.text = "Ⅱ"
	pause_button.anchor_left = 1.0
	pause_button.anchor_right = 1.0
	pause_button.position = Vector2(-76, 16)
	pause_button.size = Vector2(56, 52)
	pause_button.add_theme_font_size_override("font_size", 24)
	pause_button.pressed.connect(_toggle_pause)
	layer.add_child(pause_button)

	joystick = JoystickScript.new()
	joystick.anchor_left = 0.0
	joystick.anchor_top = 1.0
	joystick.anchor_bottom = 1.0
	joystick.position = Vector2(28, -205)
	joystick.size = Vector2(190, 190)
	joystick.visible = false
	layer.add_child(joystick)

	jump_button = Button.new()
	jump_button.text = "JUMP"
	jump_button.anchor_left = 1.0
	jump_button.anchor_top = 1.0
	jump_button.anchor_right = 1.0
	jump_button.anchor_bottom = 1.0
	jump_button.position = Vector2(-150, -132)
	jump_button.size = Vector2(112, 82)
	jump_button.add_theme_font_size_override("font_size", 22)
	jump_button.button_down.connect(_on_jump_pressed)
	jump_button.visible = false
	layer.add_child(jump_button)

	fire_button = Button.new()
	fire_button.text = "FIRE"
	fire_button.anchor_left = 1.0
	fire_button.anchor_top = 1.0
	fire_button.anchor_right = 1.0
	fire_button.anchor_bottom = 1.0
	fire_button.position = Vector2(-150, -220)
	fire_button.size = Vector2(112, 66)
	fire_button.add_theme_font_size_override("font_size", 22)
	fire_button.pressed.connect(_on_fire_pressed)
	fire_button.visible = false
	layer.add_child(tag_button)

	tags_label = Label.new()
	tags_label.position = Vector2(24, 108)
	tags_label.size = Vector2(260, 28)
	tags_label.add_theme_font_size_override("font_size", 17)
	tags_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.48))
	layer.add_child(tags_label)

	overlay = ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.015, 0.035, 0.06, 0.9)
	overlay.visible = false
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(overlay)

	var panel := VBoxContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-220, -170)
	panel.size = Vector2(440, 340)
	panel.add_theme_constant_override("separation", 14)
	overlay.add_child(panel)

	overlay_title = Label.new()
	overlay_title.text = "SKYBOUND SURVIVAL"
	overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_title.add_theme_font_size_override("font_size", 31)
	panel.add_child(overlay_title)

	overlay_button = Button.new()
	overlay_button.text = "DROP IN"
	overlay_button.custom_minimum_size = Vector2(0, 62)
	overlay_button.add_theme_font_size_override("font_size", 24)
	overlay_button.pressed.connect(_on_overlay_button_pressed)
	panel.add_child(overlay_button)

	menu_settings_button = Button.new()
	menu_settings_button.text = "SETTINGS"
	menu_settings_button.custom_minimum_size = Vector2(0, 52)
	menu_settings_button.pressed.connect(_show_settings)
	panel.add_child(menu_settings_button)

	settings_label = Label.new()
	settings_label.text = "Camera sensitivity"
	settings_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	settings_label.visible = false
	panel.add_child(settings_label)

	sensitivity_slider = HSlider.new()
	sensitivity_slider.min_value = 1.0
	sensitivity_slider.max_value = 8.0
	sensitivity_slider.step = 0.5
	sensitivity_slider.value = 3.5
	sensitivity_slider.custom_minimum_size = Vector2(0, 36)
	sensitivity_slider.visible = false
	sensitivity_slider.value_changed.connect(_on_sensitivity_changed)
	panel.add_child(sensitivity_slider)

	var hint := Label.new()
	hint.text = "OFFLINE MATCH • 1 PLAYER + 6 AI SCOUTS\nCollect supplies, use your pixel energy blaster, and stay inside the shrinking safe zone. No internet required."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 16)
	panel.add_child(hint)

func _show_main_menu() -> void:
	overlay_mode = "menu"
	overlay.visible = true
	overlay_title.text = "SKYBOUND SURVIVAL"
	overlay_button.text = "DROP IN"
	overlay_button.visible = true
	menu_settings_button.visible = true
	settings_label.visible = false
	sensitivity_slider.visible = false
	pause_button.visible = false
	joystick.visible = false
	jump_button.visible = false
	fire_button.visible = false
	zone_label.visible = false
	energy_label.visible = false
	tags_label.visible = false
	message_label.text = "Best supply score: %d" % best_score

func _show_settings() -> void:
	overlay_mode = "settings"
	overlay_title.text = "SETTINGS"
	overlay_button.text = "BACK"
	menu_settings_button.visible = false
	settings_label.visible = true
	sensitivity_slider.visible = true
	sensitivity_slider.value = player.look_sensitivity * 1000.0

func _on_sensitivity_changed(value: float) -> void:
	if player:
		player.look_sensitivity = value / 1000.0
		saved_sensitivity = player.look_sensitivity
		_save_progress()

func _start_game() -> void:
	game_started = true
	is_paused = false
	round_ended = false
	elapsed = 0.0
	seconds_left = ROUND_SECONDS
	zone_radius = START_ZONE_RADIUS
	energy = 100.0
	score = 0
	player_tags = 0
	tagged_bots = 0
	player_tag_cooldown = 0.0
	fire_cooldown = 0.0
	for projectile in projectiles:
		if is_instance_valid(projectile):
			projectile.queue_free()
	projectiles.clear()
	projectile_directions.clear()
	projectile_lifetimes.clear()
	scout_retarget_timer = 0.0
	player.position = Vector3(0, 0.2, 0)
	player.velocity = Vector3.ZERO
	player.set_physics_process(true)
	for beacon in beacons:
		if is_instance_valid(beacon):
			beacon.queue_free()
	beacons.clear()
	_build_beacons()
	for i in range(scouts.size()):
		var angle := TAU * float(i) / float(scouts.size())
		scouts[i].position = Vector3(cos(angle) * 72.0, 0, sin(angle) * 72.0)
		scout_scores[i] = 0
		scout_tagged[i] = false
		scout_contact_cooldowns[i] = 0.0
		scouts[i].visible = true
		scout_targets[i] = null
	overlay.visible = false
	pause_button.visible = true
	pause_button.disabled = false
	joystick.visible = true
	jump_button.visible = true
	fire_button.visible = true
	zone_label.visible = true
	energy_label.visible = true
	tags_label.visible = true
	zone_ring.visible = true
	_update_hud()

func _process(delta: float) -> void:
	if game_started and not round_ended and not is_paused:
		elapsed += delta
		seconds_left = maxf(0.0, ROUND_SECONDS - elapsed)
		zone_radius = lerpf(START_ZONE_RADIUS, FINAL_ZONE_RADIUS, clampf(elapsed / ROUND_SECONDS, 0.0, 1.0))
		zone_ring.scale = Vector3(zone_radius, 1.0, zone_radius)
		_update_survival_energy(delta)
		_update_scouts(delta)
		_update_projectiles(delta)
		if seconds_left <= 0.0:
			_finish_round(true)
		_update_timer()
		_update_match_labels()
	if player and joystick and not is_paused and game_started and not round_ended:
		player.set_move_input(joystick.value)
	fps_update_accumulator += delta
	if fps_update_accumulator >= 0.25:
		fps_update_accumulator = 0.0
		fps_label.text = "FPS: %d" % Engine.get_frames_per_second()

func _update_survival_energy(delta: float) -> void:
	var distance_from_center := Vector2(player.global_position.x, player.global_position.z).length()
	if distance_from_center > zone_radius:
		energy = maxf(0.0, energy - delta * 9.0)
		message_label.text = "RETURN TO THE SAFE ZONE!"
		message_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.38))
	else:
		energy = minf(100.0, energy + delta * 2.0)
		if energy > 35.0:
			message_label.text = "Collect supplies and stay ahead of the storm."
			message_label.add_theme_color_override("font_color", Color(0.9, 0.96, 1.0))
	if energy <= 0.0:
		_finish_round(false)

func _update_scouts(delta: float) -> void:
	scout_retarget_timer -= delta
	player_tag_cooldown = maxf(0.0, player_tag_cooldown - delta)
	for i in range(scouts.size()):
		var scout := scouts[i]
		if not is_instance_valid(scout) or scout_tagged[i]:
			continue
		scout_contact_cooldowns[i] = maxf(0.0, scout_contact_cooldowns[i] - delta)
		var distance_to_player := scout.global_position.distance_to(player.global_position)
		var destination: Vector3
		var movement_speed := 3.0
		if distance_to_player < 13.0:
			destination = Vector3(player.global_position.x, 0.0, player.global_position.z)
			movement_speed = 4.0
			if distance_to_player < 1.65 and scout_contact_cooldowns[i] <= 0.0:
				player_tags += 1
				scout_contact_cooldowns[i] = 2.0
				message_label.text = "A scout tagged you! Keep moving!"
				message_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.38))
				_update_match_labels()
				if player_tags >= 3:
					_finish_round(false)
					return
		else:
			var target := scout_targets[i]
			if scout_retarget_timer <= 0.0 or not is_instance_valid(target):
				target = _nearest_available_beacon(scout.global_position)
				scout_targets[i] = target
			if not is_instance_valid(target):
				continue
			destination = Vector3(target.global_position.x, 0.0, target.global_position.z)
		var current := Vector3(scout.position.x, 0.0, scout.position.z)
		var direction := destination - current
		if direction.length() > 0.1:
			scout.position = scout.position.move_toward(destination, movement_speed * delta)
			scout.rotation.y = atan2(direction.x, direction.z)
		if distance_to_player >= 13.0:
			var target := scout_targets[i]
			if is_instance_valid(target) and scout.global_position.distance_to(target.global_position) < 1.6:
				if not bool(target.get_meta("collected", false)):
					target.set_meta("collected", true)
					scout_scores[i] += 1
					target.queue_free()
					beacons.erase(target)
				scout_targets[i] = null
	if scout_retarget_timer <= 0.0:
		scout_retarget_timer = 1.4

func _on_fire_pressed() -> void:
	if not game_started or round_ended or is_paused or fire_cooldown > 0.0:
		return
	fire_cooldown = 0.32
	var camera := player.camera_pivot.get_child(0) as Camera3D
	var direction := -camera.global_transform.basis.z.normalized()
	var projectile := Node3D.new()
	projectile.name = "EnergyBolt"
	var orb := MeshInstance3D.new()
	var orb_mesh := SphereMesh.new()
	orb_mesh.radius = 0.19
	orb_mesh.height = 0.38
	orb.mesh = orb_mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.22, 0.88, 1.0)
	material.emission_enabled = true
	material.emission = Color(0.08, 0.55, 1.0)
	material.emission_energy_multiplier = 2.0
	orb.material_override = material
	projectile.add_child(orb)
	projectile.global_position = camera.global_position + direction * 1.1
	add_child(projectile)
	projectiles.append(projectile)
	projectile_directions.append(direction)
	projectile_lifetimes.append(1.8)

func _update_projectiles(delta: float) -> void:
	fire_cooldown = maxf(0.0, fire_cooldown - delta)
	for i in range(projectiles.size() - 1, -1, -1):
		var projectile := projectiles[i]
		if not is_instance_valid(projectile):
			_remove_projectile(i)
			continue
		projectile.global_position += projectile_directions[i] * 27.0 * delta
		projectile_lifetimes[i] -= delta
		var hit_index := -1
		for scout_index in range(scouts.size()):
			if scout_tagged[scout_index] or not is_instance_valid(scouts[scout_index]):
				continue
			if projectile.global_position.distance_to(scouts[scout_index].global_position + Vector3.UP * 0.9) < 1.0:
				hit_index = scout_index
				break
		if hit_index >= 0:
			scout_tagged[hit_index] = true
			scouts[hit_index].visible = false
			scout_targets[hit_index] = null
			tagged_bots += 1
			message_label.text = "Scout popped! %d of %d bots out." % [tagged_bots, SCOUT_COUNT]
			_update_match_labels()
			_remove_projectile(i)
			if tagged_bots >= SCOUT_COUNT:
				_finish_round(true)
			continue
		if projectile_lifetimes[i] <= 0.0:
			_remove_projectile(i)

func _remove_projectile(index: int) -> void:
	if is_instance_valid(projectiles[index]):
		projectiles[index].queue_free()
	projectiles.remove_at(index)
	projectile_directions.remove_at(index)
	projectile_lifetimes.remove_at(index)

func _nearest_available_beacon(from_position: Vector3) -> Area3D:
	var nearest: Area3D = null
	var nearest_distance := INF
	for beacon in beacons:
		if not is_instance_valid(beacon) or bool(beacon.get_meta("collected", false)):
			continue
		var distance := from_position.distance_squared_to(beacon.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = beacon
	return nearest

func _unhandled_input(event: InputEvent) -> void:
	if not game_started or round_ended or is_paused:
		return
	if event is InputEventScreenDrag and event.position.x > get_viewport().get_visible_rect().size.x * 0.48:
		player.rotate_view(event.relative)
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		player.rotate_view(event.relative)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_toggle_pause()

func _on_jump_pressed() -> void:
	if game_started and not is_paused and not round_ended and player and player.is_on_floor():
		player.velocity.y = player.jump_velocity

func _on_beacon_body_entered(body: Node3D, beacon: Area3D) -> void:
	if body != player or bool(beacon.get_meta("collected", false)) or round_ended or not game_started:
		return
	beacon.set_meta("collected", true)
	score += 1
	beacons.erase(beacon)
	beacon.queue_free()
	_update_hud()
	if beacons.is_empty():
		_finish_round(true)

func _toggle_pause() -> void:
	if not game_started or round_ended:
		return
	is_paused = not is_paused
	get_tree().paused = is_paused
	overlay.visible = is_paused
	pause_button.text = "▶" if is_paused else "Ⅱ"
	if is_paused:
		overlay_mode = "pause"
		overlay_title.text = "PAUSED"
		overlay_button.text = "RESUME"
		menu_settings_button.visible = false
		settings_label.visible = false
		sensitivity_slider.visible = false

func _on_overlay_button_pressed() -> void:
	match overlay_mode:
		"menu":
			_start_game()
		"settings":
			_show_main_menu()
		"pause":
			_toggle_pause()
		"finished":
			get_tree().paused = false
			get_tree().reload_current_scene()

func _finish_round(won: bool) -> void:
	if round_ended:
		return
	round_ended = true
	is_paused = false
	get_tree().paused = false
	overlay_mode = "finished"
	overlay.visible = true
	pause_button.disabled = true
	player.set_physics_process(false)
	joystick.visible = false
	jump_button.visible = false
	fire_button.visible = false
	menu_settings_button.visible = false
	settings_label.visible = false
	sensitivity_slider.visible = false
	var leading_score := 0
	for scout_score in scout_scores:
		leading_score = maxi(leading_score, scout_score)
	var player_won := won and score >= leading_score
	overlay_title.text = "YOU SURVIVED!" if player_won else "SCOUT CREW WINS"
	overlay_button.text = "PLAY AGAIN"
	overlay_button.visible = true
	message_label.text = "Supplies collected: %d | Best scout: %d" % [score, leading_score]
	if score > best_score:
		best_score = score
		_save_progress()

func _update_match_labels() -> void:
	var leading_score := 0
	for scout_score in scout_scores:
		leading_score = maxi(leading_score, scout_score)
	score_label.text = "SUPPLIES: %d  |  SCOUT LEAD: %d" % [score, leading_score]
	tags_label.text = "HITS TAKEN: %d/3  |  BOTS OUT: %d/%d" % [player_tags, tagged_bots, SCOUT_COUNT]
	zone_label.text = "SAFE ZONE: %dm" % int(zone_radius)
	energy_label.text = "STORM ENERGY: %d%%" % int(energy)

func _load_progress() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		best_score = int(config.get_value("progress", "best_score", 0))
		saved_sensitivity = float(config.get_value("settings", "look_sensitivity", 0.0035))

func _save_progress() -> void:
	var config := ConfigFile.new()
	config.set_value("progress", "best_score", best_score)
	config.set_value("settings", "look_sensitivity", saved_sensitivity)
	config.save(SAVE_PATH)

func _update_timer() -> void:
	var whole_seconds := int(ceil(seconds_left))
	if whole_seconds == last_displayed_second:
		return
	last_displayed_second = whole_seconds
	timer_label.text = "%02d:%02d" % [whole_seconds / 60, whole_seconds % 60]
	if seconds_left <= 30.0:
		timer_label.add_theme_color_override("font_color", Color(1.0, 0.72, 0.38))
	else:
		timer_label.add_theme_color_override("font_color", Color(0.8, 0.96, 1.0))

func _update_hud() -> void:
	_update_match_labels()
	_update_timer()
