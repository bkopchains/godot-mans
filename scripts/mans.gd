class_name Mans
extends RigidBody2D

@onready var shadow: Sprite2D = $Shadow
@onready var sprite: Sprite2D = $Sprite
@onready var dust_particles: CPUParticles2D = $"Dust Particles"
@onready var attack_timer: Timer = $"Attack Timer"

var is_dragging: bool = false
var is_selected: bool = false
var is_hovered: bool = false
var drag_offset: Vector2
var prev_position: Vector2
var rotation_velocity: float = 0.0

var colors = [
	Color(1, 0.3, 0.3),  # Red
	Color(0.3, 0.3, 1),  # Blue
	Color(0.3, 1, 0.3),  # Green
	Color(1, 1, 0.3),    # Yellow
	Color(1, 0.3, 1),    # Purple
]

# Reference to the class data
@export var stats: MansClass

# Damage multiplier when hit by weakness
const WEAKNESS_MULTIPLIER: float = 1.5

# Add these near the top with other variables
var team_color_index: int
var current_target: Mans = null
var lunge_cooldown: bool = false
var attack_cooldown: bool = false
const ATTACK_FORCE: float = 25.0

# Add these variables near the top
var is_lunging: bool = false
const LUNGE_DURATION: float = 1  # How long each lunge movement lasts
const LUNGE_FORCE: float = 50.0   # Increased force for quick lunges
const BASE_DAMP: float = 1.0      # Normal linear damping
const LUNGE_DAMP: float = 0.75     # Reduced damping during lunges

# Add these constants near the top
const SCREEN_MARGIN: float = 10.0  # Distance from edge to start avoiding
const EDGE_FORCE: float = 200.0     # Force to apply when near edges

func _ready() -> void:
	add_to_group("mans")
	prev_position = position
	var material = sprite.material as ShaderMaterial
	
	# Match sprite frame to class type
	sprite.frame = stats.class_type
	
	# Set color based on team (using the same index system)
	team_color_index = randi() % colors.size()
	material.set_shader_parameter("modulate", colors[team_color_index])
	
	update_outline()
	linear_damp = BASE_DAMP
	print("Stats: [Name: %s, HP: %d/%d, Attack: %d, Speed: %.1f, Type: %d, Weak vs: %d]" % [stats.name, stats.hp, stats.max_hp, stats.attack_power, stats.speed, stats.class_type, stats.weak_against])

func update_outline() -> void:
	var material = sprite.material as ShaderMaterial
	if material:
		material.set_shader_parameter("enabled", is_selected or is_hovered)
		material.set_shader_parameter("outline_color", Color.WHITE if is_hovered else Global.HIGHLIGHT_COLOR)
		material.set_shader_parameter("outline_width", 1.0)

func select() -> void:
	is_selected = true
	update_outline()

func deselect() -> void:
	is_selected = false
	update_outline()

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if is_selected:
					# If we're part of a selection, tell main to handle group drag
					get_parent().start_group_drag(get_global_mouse_position())
				else:
					# Otherwise just drag this mans
					pick_up()
					drag_offset = position - get_global_mouse_position()
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			var direction = 1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1
			sprite.frame = wrapi(sprite.frame + direction, 0, 5)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and is_dragging:
			if !event.pressed:
				put_down()
		elif event.button_index == MOUSE_BUTTON_RIGHT and is_dragging:
			if event.pressed:
				get_viewport().set_input_as_handled()
				queue_free()
	
	# Handle number keys for color changes while hovering or selected
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_0:  # Random color on 0 key
			if is_hovered or is_selected:
				var material = sprite.material as ShaderMaterial
				material.set_shader_parameter("modulate", colors[randi() % colors.size()])
		else:
			var key_num = event.keycode - KEY_1
			if key_num >= 0 and key_num < colors.size():
				if is_hovered or is_selected:
					var material = sprite.material as ShaderMaterial
					material.set_shader_parameter("modulate", colors[key_num])

func _physics_process(delta: float) -> void:
	if is_dragging:
		var target = get_global_mouse_position() + drag_offset
		var direction = (target - position)
		linear_velocity = direction * 30
	else:
		if Global.battle_mode_enabled:
			handle_combat()
		else:
			handle_peaceful()
		
		check_off_screen()
	
	# Calculate rotation based on movement
	if linear_velocity.length() > 1:
		rotation_velocity = lerp(rotation_velocity, linear_velocity.x * 0.005, 0.5)
	else:
		rotation_velocity = lerp(rotation_velocity, 0.0, 0.5)
	
	sprite.rotation = rotation_velocity
	prev_position = position

func check_off_screen() -> void:
	var camera = get_viewport().get_camera_2d()
	if !camera:
		return
		
	var viewport_size = get_viewport_rect().size
	var screen_center = camera.global_position
	var margin = 50
	
	var left = screen_center.x - viewport_size.x/2 - margin
	var right = screen_center.x + viewport_size.x/2 + margin
	var top = screen_center.y - viewport_size.y/2 - margin
	var bottom = screen_center.y + viewport_size.y/2 + margin
	
	if position.x < left or position.x > right or \
	   position.y < top or position.y > bottom:
		queue_free()

func pick_up():
	is_dragging = true
	is_hovered = true
	sprite.position.y = -6
	shadow.scale = Vector2(1.5, 1.5)
	Input.set_default_cursor_shape(Input.CURSOR_DRAG)
	update_outline()

func put_down():
	is_dragging = false
	is_hovered = false
	sprite.position.y = -4
	shadow.scale = Vector2(1, 1)
	dust_particles.emitting = true;
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	update_outline()

func _on_mouse_entered() -> void:
	if !is_dragging:
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
		is_hovered = true
		update_outline()

func _on_mouse_exited() -> void:
	if !is_dragging:
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
		is_hovered = false
		update_outline()

# Called by main when starting a group drag
func start_drag_in_group(mouse_pos: Vector2) -> void:
	is_dragging = true
	is_hovered = true
	sprite.position.y = -6
	shadow.scale = Vector2(1.5, 1.5)
	drag_offset = position - mouse_pos
	update_outline()

func preview_select(enabled: bool) -> void:
	var material = sprite.material as ShaderMaterial
	if material:
		material.set_shader_parameter("enabled", enabled or is_selected or is_hovered)
		material.set_shader_parameter("outline_color", Color.WHITE if is_hovered else Global.HIGHLIGHT_COLOR)
		#material.set_shader_parameter("outline_width", 2.0 if enabled else 1.0)

func take_damage(amount: int, attacker_type: MansClass.ClassType) -> void:
	var final_damage = amount
	if attacker_type == stats.weak_against:
		final_damage = int(float(amount) * WEAKNESS_MULTIPLIER)
	stats.hp = max(0, stats.hp - final_damage)
	if is_dead():
		remove_from_group("mans")
		queue_free();

func is_dead() -> bool:
	return stats.hp <= 0

func heal(amount: int) -> void:
	stats.hp = min(stats.max_hp, stats.hp + amount)

func apply_edge_avoidance() -> void:
	var camera = get_viewport().get_camera_2d()
	if !camera:
		return
		
	var viewport_size = get_viewport_rect().size
	var screen_center = camera.global_position
	
	var left = screen_center.x - viewport_size.x/2
	var right = screen_center.x + viewport_size.x/2
	var top = screen_center.y - viewport_size.y/2
	var bottom = screen_center.y + viewport_size.y/2
	
	var force = Vector2.ZERO
	
	# Check each edge and apply appropriate force
	if position.x - left < SCREEN_MARGIN:
		force.x = (SCREEN_MARGIN - (position.x - left)) * (EDGE_FORCE/SCREEN_MARGIN)
	elif right - position.x < SCREEN_MARGIN:
		force.x = -((SCREEN_MARGIN - (right - position.x)) * (EDGE_FORCE/SCREEN_MARGIN))
		
	if position.y - top < SCREEN_MARGIN:
		force.y = (SCREEN_MARGIN - (position.y - top)) * (EDGE_FORCE/SCREEN_MARGIN)
	elif bottom - position.y < SCREEN_MARGIN:
		force.y = -((SCREEN_MARGIN - (bottom - position.y)) * (EDGE_FORCE/SCREEN_MARGIN))
	
	if force != Vector2.ZERO:
		apply_central_force(force)

func handle_combat() -> void:
	if is_dead():
		return
		
	# Only find target and start lunge if we're not currently lunging
	if !is_lunging:
		if !current_target or current_target.is_dead():
			find_nearest_enemy()
			if !current_target:
				return
		
		if !lunge_cooldown:
			start_lunge()
	
	# Only apply edge avoidance
	apply_edge_avoidance()

func find_nearest_enemy() -> void:
	var shortest_distance = INF
	current_target = null
	
	for mans in get_tree().get_nodes_in_group("mans"):
		if mans != self and mans.team_color_index != team_color_index and !mans.is_dead():
			var distance = position.distance_to(mans.position)
			if distance < shortest_distance:
				shortest_distance = distance
				current_target = mans

# Add this new collision handler
func _on_body_entered(body: Node2D) -> void:
	if !Global.battle_mode_enabled or attack_cooldown:
		return
		
	if body is Mans and body.team_color_index != team_color_index:
		attack(body)

func attack(target: Mans) -> void:
	if !attack_cooldown:
		target.take_damage(stats.attack_power, stats.class_type)
		attack_cooldown = true
		attack_timer.start(1.0 / stats.speed)  # Attack speed based on speed stat

func _on_attack_timer_timeout() -> void:
	attack_cooldown = false

# Add this to handle battle mode changes
func _on_battle_mode_toggled(enabled: bool) -> void:
	if !enabled:
		current_target = null
		lunge_cooldown = false
		is_lunging = false
		linear_velocity = Vector2.ZERO
	else:
		linear_velocity = Vector2.ZERO

func handle_peaceful() -> void:
	if is_dead():
		return
		
	var same_team_center = Vector2.ZERO
	var count = 0
	var max_force = 100.0
	var repulsion_distance = 10.0
	
	# Debug print to check group size
	#print("Finding teammates from group size: ", get_tree().get_nodes_in_group("mans").size())
	
	for mans in get_tree().get_nodes_in_group("mans"):
		if mans != self and !mans.is_dead() and mans.team_color_index == team_color_index:
			same_team_center += mans.position
			count += 1
			
			# Add repulsion force if too close
			var distance = position.distance_to(mans.position)
			if distance < repulsion_distance:
				var repulsion = (position - mans.position).normalized()
				apply_central_force(repulsion * max_force * (1.0 - distance/repulsion_distance))
	
	if count > 0:
		same_team_center /= count
		var direction = (same_team_center - position).normalized()
		var distance_to_center = position.distance_to(same_team_center)
		
		# Stronger attraction force when far from center
		var attraction_force = max_force * (distance_to_center / 100.0)
		attraction_force = min(attraction_force, max_force)
		
		# Apply attraction force
		apply_central_force(direction * attraction_force * stats.speed)
	
	apply_edge_avoidance()

func start_lunge() -> void:
	is_lunging = true
	lunge_cooldown = true
	
	# Reduce damping during lunge for more sliding
	linear_damp = LUNGE_DAMP
	
	# Calculate direction to target
	var direction = (current_target.position - position).normalized()
	# Apply a single strong impulse
	apply_central_impulse(direction * LUNGE_FORCE * stats.speed)
	dust_particles.emitting = true
	
	# Create a timer for ending the lunge
	var lunge_timer = get_tree().create_timer(stats.speed)
	lunge_timer.timeout.connect(_on_lunge_timer_timeout)

func _on_lunge_timer_timeout() -> void:
	is_lunging = false
	lunge_cooldown = false
	# Restore normal damping
	linear_damp = BASE_DAMP
