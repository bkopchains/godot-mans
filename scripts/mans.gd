class_name Mans
extends RigidBody2D

@onready var shadow: Sprite2D = $Shadow
@onready var sprite: Sprite2D = $Sprite
@onready var dust_particles: CPUParticles2D = $"Dust Particles"
@onready var attack_timer: Timer = $"Attack Timer"
@onready var health_fill: ColorRect = $HealthBar/Fill
@onready var health_bar: Node2D = $HealthBar

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
const WEAKNESS_MULTIPLIER: float = 2

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

# Add near other variables
var carried_flag: Flag = null
var team_flag_carrier: Mans = null  # Track who has our flag

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
	#print("Stats: [Name: %s, HP: %d/%d, Attack: %d, Speed: %.1f, Type: %d, Weak vs: %d]" % [stats.name, stats.hp, stats.max_hp, stats.attack_power, stats.speed, stats.class_type, stats.weak_against])
	update_health_bar()
	Global.health_bars_toggled.connect(_on_health_bars_toggled)
	health_bar.visible = Global.show_health_bars

	var our_flag = get_parent().get_team_flag(team_color_index)
	if our_flag:
		our_flag.flag_dropped.connect(_on_team_flag_dropped)
		our_flag.flag_captured.connect(_on_team_flag_captured)

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
				var idx = randi() % colors.size();
				material.set_shader_parameter("modulate", colors[idx]);
				team_color_index = idx;
		else:
			var key_num = event.keycode - KEY_1
			if key_num >= 0 and key_num < colors.size():
				if is_hovered or is_selected:
					var material = sprite.material as ShaderMaterial
					material.set_shader_parameter("modulate", colors[key_num]);
					team_color_index = key_num;

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

func update_health_bar() -> void:
	if health_fill:
		var health_percent = float(stats.hp) / float(stats.max_hp)
		health_fill.size.x = 10.0 * health_percent
		health_fill.position.x = -5.0
		
		# Optional: Change color based on health
		var g = clamp(health_percent * 2, 0, 1)  # Goes from 1 to 0
		var r = clamp(2 - health_percent * 2, 0, 1)  # Goes from 0 to 1
		health_fill.color = Color(r, g, 0.2, 0.8)

func take_damage(amount: int, attacker_type: MansClass.ClassType) -> void:
	var final_damage = amount
	if attacker_type == stats.weak_against:
		final_damage = int(float(amount) * WEAKNESS_MULTIPLIER)
	stats.hp = max(0, stats.hp - final_damage)
	update_health_bar()
	
	if is_dead():
		# First disconnect signals
		var our_flag = get_parent().get_team_flag(team_color_index)
		if our_flag:
			if our_flag.flag_dropped.is_connected(_on_team_flag_dropped):
				our_flag.flag_dropped.disconnect(_on_team_flag_dropped)
			if our_flag.flag_captured.is_connected(_on_team_flag_captured):
				our_flag.flag_captured.disconnect(_on_team_flag_captured)
		
		# Then handle flag detachment and cleanup
		if carried_flag:
			carried_flag.detach()
		remove_from_group("mans")
		queue_free()

func is_dead() -> bool:
	return stats.hp <= 0

func heal(amount: int) -> void:
	stats.hp = min(stats.max_hp, stats.hp + amount)
	update_health_bar()

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
		var our_flag = get_parent().get_team_flag(team_color_index)
		
		# First priority: Get back our dropped flag
		if our_flag and !our_flag.carrier and !carried_flag:
			current_target = null
			var direction = (our_flag.position - position).normalized()
			apply_central_force(direction * LUNGE_FORCE * stats.speed)
			return
			
		# Second priority: Chase enemy carrying our flag
		if team_flag_carrier and team_flag_carrier.team_color_index != team_color_index:
			current_target = team_flag_carrier
			if !lunge_cooldown:
				start_lunge()
			return
			
		# Third priority: Normal combat targeting
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
	
	# First check for dropped flags
	if !carried_flag:  # Only look for flags if not carrying one
		for flag in get_tree().get_nodes_in_group("flags"):
			if !flag.carrier:  # Flag is dropped
				var distance = position.distance_to(flag.position)
				if distance < shortest_distance:
					shortest_distance = distance
					current_target = null  # Clear enemy target
					# Move towards flag
					var direction = (flag.position - position).normalized()
					apply_central_force(direction * LUNGE_FORCE * stats.speed)
					return
	
	# If no dropped flags found, look for enemies
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
		
	var target_pos = Vector2.ZERO
	var our_flag = get_parent().get_team_flag(team_color_index)
	
	if our_flag and our_flag.carrier:
		target_pos = calculate_grid_position(our_flag)
		var direction = (target_pos - position)
		var distance = direction.length()
		
		if distance > 2.0:  # Increased threshold to reduce jitter
			direction = direction.normalized()
			# Smoother movement
			linear_velocity = linear_velocity.lerp(direction * stats.speed * 50, 0.2)
		else:
			# Gradual stop when close to position
			linear_velocity = linear_velocity.lerp(Vector2.ZERO, 0.3)
	
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
	dust_particles.restart();
	dust_particles.emitting = true;
	
	# Create a timer for ending the lunge
	var lunge_timer = get_tree().create_timer(stats.speed)
	lunge_timer.timeout.connect(_on_lunge_timer_timeout)

func _on_lunge_timer_timeout() -> void:
	is_lunging = false
	lunge_cooldown = false
	# Restore normal damping
	linear_damp = BASE_DAMP

func _on_health_bars_toggled(enabled: bool) -> void:
	health_bar.visible = enabled

# Add helper function to find flags
func get_all_flags() -> Array[Flag]:
	return get_tree().get_nodes_in_group("flags") as Array[Flag]

func _on_team_flag_dropped(_flag: Flag) -> void:
	team_flag_carrier = null

func _on_team_flag_captured(_flag: Flag, by_team: int) -> void:
	team_flag_carrier = _flag.carrier

func _exit_tree() -> void:
	var our_flag = get_parent().get_team_flag(team_color_index)
	if our_flag:
		our_flag.flag_dropped.disconnect(_on_team_flag_dropped)
		our_flag.flag_captured.disconnect(_on_team_flag_captured)

func calculate_grid_position(our_flag: Flag) -> Vector2:
	var team_members = []
	for mans in get_tree().get_nodes_in_group("mans"):
		if mans.team_color_index == team_color_index:
			team_members.append(mans)
	
	# Find flag carrier
	var carrier_pos: Vector2
	var carrier_index: int = -1
	for mans in team_members:
		if mans.carried_flag == our_flag:
			carrier_pos = mans.position
			carrier_index = team_members.find(mans)
			if mans == self:  # If we're the carrier, stay at origin
				return carrier_pos
			break
	
	if carrier_pos == Vector2.ZERO:
		return our_flag.position
		
	var total_mans = team_members.size()
	if total_mans <= 1:
		return carrier_pos
	
	var grid_width = ceil(sqrt(total_mans))
	var index = team_members.find(self)
	
	# Calculate position in grid, accounting for carrier being at 0,0
	if index == carrier_index:
		return carrier_pos
	elif index < carrier_index:
		index += 1  # Shift up by one to leave 0,0 for carrier
	
	var grid_x = float((index) % int(grid_width))
	var grid_y = floor(float(index) / grid_width)
	
	var spacing = 15.0
	var offset = Vector2(
		grid_x * spacing,
		grid_y * spacing
	)
	
	return carrier_pos + offset
