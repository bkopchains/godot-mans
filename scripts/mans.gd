class_name Mans
extends RigidBody2D

@onready var shadow: Sprite2D = $Shadow
@onready var sprite: Sprite2D = $Sprite
@onready var dust_particles: CPUParticles2D = $"Dust Particles"
@onready var attack_timer: Timer = $"Attack Timer"
@onready var health_fill: ColorRect = $HealthBar/Fill
@onready var health_bar: Node2D = $HealthBar

@export var game: Game;

var is_dragging: bool = false
var is_selected: bool = false
var is_hovered: bool = false
var drag_offset: Vector2
var prev_position: Vector2
var rotation_velocity: float = 0.0

# Reference to the class data
@export var stats: MansClass

# Damage multiplier when hit by weakness
const WEAKNESS_MULTIPLIER: float = 2

# Add these near the top with other variables
var team_color_index: int = -1;
var current_target: Mans = null
var attack_cooldown: bool = false

# Battle-related constants
const LUNGE_FORCE: float = 50.0   # Force for quick lunges
const LUNGE_DURATION: float = 1.0  # How long each lunge movement lasts
const BASE_DAMP: float = 1.0      # Normal linear damping
const LUNGE_DAMP: float = 0.75    # Reduced damping during lunges
const ATTACK_FORCE: float = 25.0
const SCREEN_MARGIN: float = 10.0  # Distance from edge to start avoiding
const EDGE_FORCE: float = 200.0    # Force to apply when near edges

# Battle state
var is_lunging: bool = false

# Add these variables near the top
var carried_flag: Flag = null
var team_flag_carrier: Mans = null  # Track who has our flag

func _ready() -> void:
	add_to_group("mans")
	prev_position = position
	var mat = sprite.material as ShaderMaterial
	
	# Assign random class if none exists
	if !stats:
		var random_class = game.class_resources[randi() % game.class_resources.size()]
		stats = random_class.duplicate()
	
	# Match sprite frame to class type
	sprite.frame = stats.class_type
	
	# Set color based on team (using the same index system)
	if(team_color_index < 0):
		team_color_index = randi() % Global.TEAM_COLORS.size()
	mat.set_shader_parameter("modulate", Global.TEAM_COLORS[team_color_index])
	
	update_outline()
	linear_damp = BASE_DAMP
	update_health_bar()
	Global.health_bars_toggled.connect(_on_health_bars_toggled)
	health_bar.visible = Global.show_health_bars

	# Connect flag signals if flag exists
	connect_flag_signals()

func connect_flag_signals() -> void:
	var our_flag = game.get_team_flag(team_color_index)
	if our_flag:
		# Only connect if not already connected
		if !our_flag.flag_dropped.is_connected(_on_team_flag_dropped):
			our_flag.flag_dropped.connect(_on_team_flag_dropped)
		if !our_flag.flag_captured.is_connected(_on_team_flag_captured):
			our_flag.flag_captured.connect(_on_team_flag_captured)

func update_outline() -> void:
	var mat = sprite.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("enabled", is_selected or is_hovered)
		mat.set_shader_parameter("outline_color", Color.WHITE if is_hovered else Global.HIGHLIGHT_COLOR)
		mat.set_shader_parameter("outline_width", 1.0)

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
					game.start_group_drag(get_global_mouse_position())
				else:
					# Otherwise just drag this mans
					pick_up()
					drag_offset = position - get_global_mouse_position()
		elif Global.admin_mode and (event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			var direction = 1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1
			var new_frame = wrapi(sprite.frame + direction, 0, 5)
			sprite.frame = new_frame
			# Update the class stats to match the new type
			if game and game.class_resources:
				stats = game.class_resources[new_frame].duplicate()
				update_health_bar()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and is_dragging:
			if !event.pressed:
				put_down()
		elif event.button_index == MOUSE_BUTTON_RIGHT and is_dragging:
			if event.pressed:
				get_viewport().set_input_as_handled()
				queue_free()
	
	# Only allow team/class changes in admin mode
	if Global.admin_mode:
		# Handle number keys for color changes while hovering or selected
		if event is InputEventKey and event.pressed:
			if event.keycode == KEY_0:  # Random color on 0 key
				if is_hovered or is_selected:
					var mat = sprite.material as ShaderMaterial
					var idx = randi() % Global.TEAM_COLORS.size()
					mat.set_shader_parameter("modulate", Global.TEAM_COLORS[idx])
					team_color_index = idx
			else:
				var key_num = event.keycode - KEY_1
				if key_num >= 0 and key_num < Global.TEAM_COLORS.size():
					if is_hovered or is_selected:
						var mat = sprite.material as ShaderMaterial
						mat.set_shader_parameter("modulate", Global.TEAM_COLORS[key_num])
						team_color_index = key_num

func _physics_process(_delta: float) -> void:
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

func get_game_bounds(margin: float = 0.0) -> Dictionary:
	return {
		"left": -Global.GAME_W/2.0 - margin,
		"right": Global.GAME_W/2.0 + margin,
		"top": -Global.GAME_H/2.0 - margin,
		"bottom": Global.GAME_H/2.0 + margin
	}

func check_off_screen() -> void:
	var bounds = get_game_bounds(SCREEN_MARGIN)
	if position.x < bounds.left or position.x > bounds.right or \
	   position.y < bounds.top or position.y > bounds.bottom:
		queue_free()

func pick_up():
	is_dragging = true
	is_hovered = true
	sprite.position.y = 0
	shadow.scale = Vector2(1.5, 1.5)
	Input.set_default_cursor_shape(Input.CURSOR_DRAG)
	update_outline()

func put_down():
	is_dragging = false
	is_hovered = false
	sprite.position.y = 4
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
	sprite.position.y = 0
	shadow.scale = Vector2(1.5, 1.5)
	drag_offset = position - mouse_pos
	update_outline()

func preview_select(enabled: bool) -> void:
	var mat = sprite.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("enabled", enabled or is_selected or is_hovered)
		mat.set_shader_parameter("outline_color", Color.WHITE if is_hovered else Global.HIGHLIGHT_COLOR)
		#mat.set_shader_parameter("outline_width", 2.0 if enabled else 1.0)

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
		var our_flag = game.get_team_flag(team_color_index)
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
	var bounds = get_game_bounds(SCREEN_MARGIN)
	var force = Vector2.ZERO
	
	# Check each edge and apply appropriate force
	if position.x - bounds.left < SCREEN_MARGIN:
		force.x = (SCREEN_MARGIN - (position.x - bounds.left)) * (EDGE_FORCE/SCREEN_MARGIN)
	elif bounds.right - position.x < SCREEN_MARGIN:
		force.x = -((SCREEN_MARGIN - (bounds.right - position.x)) * (EDGE_FORCE/SCREEN_MARGIN))
		
	if position.y - bounds.top < SCREEN_MARGIN:
		force.y = (SCREEN_MARGIN - (position.y - bounds.top)) * (EDGE_FORCE/SCREEN_MARGIN)
	elif bounds.bottom - position.y < SCREEN_MARGIN:
		force.y = -((SCREEN_MARGIN - (bounds.bottom - position.y)) * (EDGE_FORCE/SCREEN_MARGIN))
	
	if force != Vector2.ZERO:
		apply_central_force(force)

func handle_combat() -> void:
	if is_dead():
		return
		
	if !is_lunging:
		var target_pos = get_battle_target()
		
		# If we have a valid target position different from our current position
		if target_pos != position:
			var direction = (target_pos - position).normalized()
			if !is_lunging:
				start_lunge(target_pos)
	
	apply_edge_avoidance()

func get_battle_target() -> Vector2:
	# Priority 1: If carrying enemy flag, head to own base
	if carried_flag:
		var own_tent = get_own_tent()
		if own_tent:
			return own_tent.global_position
	
	# Priority 2: Get our dropped flag
	var our_flag = game.get_team_flag(team_color_index)
	if our_flag and !our_flag.carrier and !carried_flag:
		return our_flag.position
	
	# Priority 3: Chase enemy with our flag
	if team_flag_carrier and team_flag_carrier.team_color_index != team_color_index:
		return team_flag_carrier.position
	
	# Priority 4: Split between flag capture and combat based on class
	if should_chase_flag():
		# Look for enemy flag to capture
		for flag in get_all_flags():
			if flag.team_color_index != team_color_index and \
			(!flag.carrier or (flag.carrier and flag.carrier.team_color_index != team_color_index)):
				return flag.position
			
		# spawn camping
		#var enemy_bases = game.team_bases.values().filter(func(base): return base.team_color_index != team_color_index)
		#if enemy_bases.size() > 0:
			#return enemy_bases.pick_random().global_position
	
	# Priority 5: Normal combat - find nearest enemy
	if !current_target or current_target.is_dead():
		find_nearest_enemy()
	if current_target:
		return current_target.position
	
	return position

func should_chase_flag() -> bool:
	# DOG and BABY are the fastest units, best suited for flag capture
	# BRUTE and WIZARD are slower and might focus more on combat
	return stats.class_type in [MansClass.ClassType.DOG, MansClass.ClassType.BABY] and \
		   randf() < 0.7  # 70% chance for eligible classes to chase flag

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
					apply_central_force(direction * LUNGE_FORCE * (1.0/stats.speed))
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
		is_lunging = false
		linear_velocity = Vector2.ZERO
	else:
		linear_velocity = Vector2.ZERO

func handle_peaceful() -> void:
	if is_dead():
		return
		
	var target_pos = Vector2.ZERO
	var our_flag = game.get_team_flag(team_color_index)
	
	if our_flag and our_flag.carrier:
		target_pos = calculate_grid_position(our_flag)
		var direction = (target_pos - position)
		var distance = direction.length()
		
		if distance > 2.0:  # Increased threshold to reduce jitter
			direction = direction.normalized()
			# Smoother movement
			linear_velocity = linear_velocity.lerp(direction * (1.0/stats.speed) * 50, 0.2)
		else:
			# Gradual stop when close to position
			linear_velocity = linear_velocity.lerp(Vector2.ZERO, 0.3)
	
	apply_edge_avoidance()

func start_lunge(target_pos: Vector2) -> void:
	is_lunging = true
	
	# Reduce damping during lunge for more sliding
	linear_damp = LUNGE_DAMP
	
	# Apply a single strong impulse toward target
	var direction = (target_pos - position).normalized()
	apply_central_impulse(direction * LUNGE_FORCE * (1.0/stats.speed))
	
	# Visual feedback
	dust_particles.restart()
	dust_particles.emitting = true
	
	# Create a timer for ending the lunge
	var lunge_timer = get_tree().create_timer(LUNGE_DURATION / stats.speed)
	lunge_timer.timeout.connect(_on_lunge_timer_timeout)

func _on_lunge_timer_timeout() -> void:
	is_lunging = false
	linear_damp = BASE_DAMP

func _on_health_bars_toggled(enabled: bool) -> void:
	health_bar.visible = enabled

# Add helper function to find flags
func get_all_flags():
	return game.team_flags.values();
	
func get_own_tent() -> Tent:
	return game.team_bases[team_color_index];

func _on_team_flag_dropped(_flag: Flag) -> void:
	team_flag_carrier = null

func _on_team_flag_captured(_flag: Flag, _by_team: int) -> void:
	team_flag_carrier = _flag.carrier

func _exit_tree() -> void:
	var our_flag = game.get_team_flag(team_color_index)
	if our_flag:
		# Only disconnect if actually connected
		if our_flag.flag_dropped.is_connected(_on_team_flag_dropped):
			our_flag.flag_dropped.disconnect(_on_team_flag_dropped)
		if our_flag.flag_captured.is_connected(_on_team_flag_captured):
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
