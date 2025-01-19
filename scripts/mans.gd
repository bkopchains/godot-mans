class_name Mans
extends RigidBody2D

@onready var shadow: Sprite2D = $Shadow
@onready var sprite: Sprite2D = $Sprite
@onready var dust_particles: CPUParticles2D = $"Dust Particles"

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

func _ready() -> void:
	prev_position = position
	var material = sprite.material as ShaderMaterial
	material.set_shader_parameter("modulate", colors[randi() % colors.size()])
	sprite.frame = randi() % sprite.hframes  # Randomize frame
	
	update_outline()

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

func is_dead() -> bool:
	return stats.hp <= 0

func heal(amount: int) -> void:
	stats.hp = min(stats.max_hp, stats.hp + amount)
