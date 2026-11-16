extends Node3D

const PlayerScript = preload("res://scripts/player.gd")
const JoystickScript = preload("res://scripts/touch_joystick.gd")
const ROUND_SECONDS := 180.0
const SAVE_PATH := "user://skybound_save.cfg"

var player: CharacterBody3D
var joystick: TouchJoystick
var jump_button: Button
var score := 0
var total_cores := 12
var seconds_left := ROUND_SECONDS
var best_score := 0
var saved_sensitivity := 0.0035
var score_label: Label
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

func _ready() -> void:
	_load_progress()
	_build_world()
	_build_player()
	_build_ui()
	_show_main_menu()

func _build_world() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = Sky.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.72, 0.86)
	env.ambient_light_energy = 0.8
	environment.environment = env
	add_child(environment)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -28, 0)
	sun.light_energy = 1.15
	add_child(sun)

	var ground := StaticBody3D.new()
	ground.name = "ArenaFloor"
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(100, 100)
	floor_mesh.mesh = plane
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.19, 0.31, 0.28)
	floor_mat.roughness = 1.0
	floor_mesh.material_override = floor_mat
	ground.add_child(floor_mesh)
	var floor_collision := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(100, 0.3, 100)
	floor_collision.shape = floor_shape
	floor_collision.position.y = -0.15
	ground.add_child(floor_collision)
	add_child(ground)

	for i in range(16):
		var angle := TAU * float(i) / 16.0
		var distance := 13.0 + float(i % 3) * 2.0
		_add_rock(Vector3(cos(angle) * distance, 0, sin(angle) * distance), 1.0 + float(i % 4) * 0.25)

	for i in range(total_cores):
		var angle := float(i) * 2.399
		var distance := 4.0 + float((i * 7) % 9)
		_add_core(Vector3(cos(angle) * distance, 0.85, sin(angle) * distance), i)

func _add_rock(at: Vector3, scale_value: float) -> void:
	var rock := StaticBody3D.new()
	rock.position = at
	var mesh_instance := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.8
	mesh.height = 1.5
	mesh_instance.mesh = mesh
	mesh_instance.scale = Vector3(scale_value, scale_value * 0.75, scale_value)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.26, 0.31, 0.34)
	material.roughness = 1.0
	mesh_instance.material_override = material
	rock.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.75 * scale_value
	collision.shape = shape
	collision.position.y = 0.55 * scale_value
	rock.add_child(collision)
	add_child(rock)

func _add_core(at: Vector3, index: int) -> void:
	var core := Area3D.new()
	core.name = "EnergyCore_%02d" % index
	core.add_to_group("rotating_cores")
	core.position = at
	core.set_meta("collected", false)
	var mesh_instance := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.38
	mesh.height = 0.76
	mesh_instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.25, 0.9, 1.0)
	material.emission_enabled = true
	material.emission = Color(0.05, 0.5, 0.9)
	material.emission_energy_multiplier = 1.4
	mesh_instance.material_override = material
	core.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 1.0
	collision.shape = shape
	core.add_child(collision)
	core.body_entered.connect(_on_core_body_entered.bind(core))
	add_child(core)

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
	score_label.add_theme_font_size_override("font_size", 26)
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

	message_label = Label.new()
	message_label.anchor_left = 0.5
	message_label.anchor_right = 0.5
	message_label.position = Vector2(-240, 64)
	message_label.size = Vector2(480, 42)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.add_theme_font_size_override("font_size", 20)
	message_label.add_theme_color_override("font_color", Color(0.75, 0.95, 1.0))
	layer.add_child(message_label)

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

	overlay = ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.015, 0.035, 0.06, 0.9)
	overlay.visible = false
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(overlay)

	var panel := VBoxContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-210, -150)
	panel.size = Vector2(420, 300)
	panel.add_theme_constant_override("separation", 16)
	overlay.add_child(panel)

	overlay_title = Label.new()
	overlay_title.text = "SKYBOUND SURVIVAL"
	overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_title.add_theme_font_size_override("font_size", 32)
	panel.add_child(overlay_title)

	overlay_button = Button.new()
	overlay_button.text = "START"
	overlay_button.custom_minimum_size = Vector2(0, 62)
	overlay_button.add_theme_font_size_override("font_size", 24)
	overlay_button.pressed.connect(_on_overlay_button_pressed)
	panel.add_child(overlay_button)

	menu_settings_button = Button.new()
	menu_settings_button.text = "SETTINGS"
	menu_settings_button.custom_minimum_size = Vector2(0, 54)
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
	hint.text = "Collect all 12 energy cores before the 3-minute timer ends."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 16)
	panel.add_child(hint)

func _show_main_menu() -> void:
	overlay_mode = "menu"
	overlay.visible = true
	overlay_title.text = "SKYBOUND SURVIVAL"
	overlay_button.text = "START"
	overlay_button.visible = true
	menu_settings_button.visible = true
	settings_label.visible = false
	sensitivity_slider.visible = false
	pause_button.visible = false
	joystick.visible = false
	jump_button.visible = false
	message_label.text = "Best collection: %d / %d" % [best_score, total_cores]

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
	seconds_left = ROUND_SECONDS
	score = 0
	player.position = Vector3(0, 0.2, 0)
	player.velocity = Vector3.ZERO
	player.set_physics_process(true)
	overlay.visible = false
	pause_button.visible = true
	pause_button.disabled = false
	joystick.visible = true
	jump_button.visible = true
	_update_hud()

func _process(delta: float) -> void:
	if game_started and not round_ended and not is_paused:
		seconds_left = maxf(0.0, seconds_left - delta)
		if seconds_left <= 0.0:
			_finish_round(false)
		_update_timer()
	if player and joystick and not is_paused and game_started and not round_ended:
		player.set_move_input(joystick.value)
	for node in get_tree().get_nodes_in_group("rotating_cores"):
		node.rotate_y(delta * 1.6)

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

func _on_core_body_entered(body: Node3D, core: Area3D) -> void:
	if body != player or bool(core.get_meta("collected")) or round_ended or not game_started:
		return
	core.set_meta("collected", true)
	score += 1
	core.queue_free()
	_update_hud()
	if score >= total_cores:
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
	round_ended = true
	is_paused = false
	get_tree().paused = false
	overlay_mode = "finished"
	overlay.visible = true
	pause_button.disabled = true
	player.set_physics_process(false)
	joystick.visible = false
	jump_button.visible = false
	menu_settings_button.visible = false
	settings_label.visible = false
	sensitivity_slider.visible = false
	overlay_title.text = "ARENA CLEARED!" if won else "TIME'S UP"
	overlay_button.text = "PLAY AGAIN"
	overlay_button.visible = true
	message_label.text = "You collected every energy core!" if won else "Try again and collect all the cores."
	if score > best_score:
		best_score = score
		_save_progress()

func _load_progress() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		best_score = int(config.get_value("progress", "best_score", 0))
		saved_sensitivity = float(config.get_value("settings", "look_sensitivity", 0.0035))

func _save_progress() -> void:
	var config := ConfigFile.new()
	config.set_value("progress", "best_score", best_score)
	config.save(SAVE_PATH)

func _update_timer() -> void:
	var whole_seconds := int(ceil(seconds_left))
	timer_label.text = "%02d:%02d" % [whole_seconds / 60, whole_seconds % 60]
	if seconds_left <= 30.0:
		timer_label.add_theme_color_override("font_color", Color(1.0, 0.72, 0.38))
	else:
		timer_label.add_theme_color_override("font_color", Color(0.8, 0.96, 1.0))

func _update_hud() -> void:
	score_label.text = "CORES: %d / %d" % [score, total_cores]
	_update_timer()
	if score == 0:
		message_label.text = "Collect every energy core. Avoid the rocks!"
