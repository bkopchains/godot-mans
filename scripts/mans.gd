class_name Mans
extends RigidBody2D

@onready var shadow: Sprite2D = $Shadow
@onready var sprite: Sprite2D = $Sprite

var is_dragging: bool = false
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

func _ready() -> void:
	prev_position = position
	sprite.modulate = colors[randi() % colors.size()]

func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
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
	
	# Handle number keys for color changes while dragging
	elif event is InputEventKey and is_dragging:
		if event.pressed:
			# Check for number keys 1-5
			var key_num = event.keycode - KEY_1
			if key_num >= 0 and key_num < colors.size():
				sprite.modulate = colors[key_num]

func _physics_process(delta: float) -> void:
	if is_dragging:
		var target = get_global_mouse_position() + drag_offset
		var direction = (target - position)
		linear_velocity = direction * 30
	
	# Calculate rotation based on movement
	if linear_velocity.length() > 1:
		rotation_velocity = lerp(rotation_velocity, linear_velocity.x * 0.005, 0.5)
	else:
		rotation_velocity = lerp(rotation_velocity, 0.0, 0.5)
	
	sprite.rotation = rotation_velocity
	prev_position = position

func pick_up():
	is_dragging = true
	sprite.position.y = -6
	shadow.scale = Vector2(1.5, 1.5)
	Input.set_default_cursor_shape(Input.CURSOR_DRAG)

func put_down():
	is_dragging = false
	sprite.position.y = -4
	shadow.scale = Vector2(1, 1)
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)

func _on_mouse_entered() -> void:
	if !is_dragging:
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)

func _on_mouse_exited() -> void:
	if !is_dragging:
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
