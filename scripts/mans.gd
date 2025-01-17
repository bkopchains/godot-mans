class_name Mans;
extends Node2D
@onready var shadow: Sprite2D = $Shadow
@onready var sprite: Sprite2D = $Sprite

var is_dragging: bool = false
var drag_offset: Vector2
var target_position: Vector2
var prev_position: Vector2
var rotation_velocity: float = 0.0
var slide_velocity: Vector2 = Vector2.ZERO

func _ready() -> void:
	# Wait one frame to ensure position is set
	await get_tree().process_frame
	target_position = position
	prev_position = position

func _on_area_2d_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				pick_up();
				drag_offset = position - get_global_mouse_position()
		# Handle mouse wheel while dragging
		elif is_dragging and (event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			var direction = 1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1
			sprite.frame = wrapi(sprite.frame + direction, 0, 5)  # 5 is number of frames

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and is_dragging:
			if !event.pressed:
				put_down()
		elif event.button_index == MOUSE_BUTTON_RIGHT and is_dragging:
			if event.pressed:
				get_viewport().set_input_as_handled()  # Prevent new mans from spawning
				queue_free()

func _physics_process(delta: float) -> void:
	if is_dragging:
		target_position = get_global_mouse_position() + drag_offset
		position = position.lerp(target_position, 0.05)  # Only lerp while dragging
	else:
		# Just apply sliding when not dragging, no lerping to target
		position += slide_velocity * delta
		slide_velocity = slide_velocity.lerp(Vector2.ZERO, 2.0 * delta)  # Even slower damping
	
	var velocity = (position - prev_position) / delta
	
	if is_dragging:
		slide_velocity = velocity  # Store amplified velocity while dragging
	
	if !is_dragging:
		rotation_velocity = lerp(rotation_velocity, 0.0, 0.5)
	else:
		rotation_velocity = lerp(rotation_velocity, velocity.x * 0.005, 0.5)
	sprite.rotation = rotation_velocity
	
	prev_position = position
	

func _on_area_2d_mouse_entered() -> void:
	# Show grab cursor when hovering
	if !is_dragging:
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)

func _on_area_2d_mouse_exited() -> void:
	# Reset cursor when not hovering (unless dragging)
	if !is_dragging:
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	
func pick_up():
	is_dragging = true
	sprite.position.y = -6
	shadow.scale = Vector2(1.5, 1.5)
	# Show grabbed cursor while holding
	Input.set_default_cursor_shape(Input.CURSOR_DRAG)
	
func put_down():
	is_dragging = false
	sprite.position.y = -4
	shadow.scale = Vector2(1, 1)
	# Reset cursor
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
