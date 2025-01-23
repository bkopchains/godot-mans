extends Camera2D

const SCROLL_MARGIN = 10  # How close to the edge before camera starts moving
const MAX_SCROLL_SPEED = 300  # Maximum movement speed (reduced from 500)
const SMOOTHING = 0.01    # Lower = smoother camera movement
const MIN_ZOOM = 0.25    # Changed to allow zooming out to 1/4x
const MAX_ZOOM = 1.0     # Normal zoom is now max
const ZOOM_SPEED = 0.05

var target_position = Vector2.ZERO
var target_zoom = Vector2.ONE
var viewport_size = Vector2.ZERO

func _ready() -> void:
	# Start at center (0,0)
	#position = Vector2.ZERO
	target_position = position
	
	# Get the actual viewport size
	viewport_size = get_viewport_rect().size

func get_movement_bounds(for_zoom: Vector2) -> Dictionary:
	# Calculate visible game area based on provided zoom
	var visible_width = viewport_size.x / for_zoom.x
	var visible_height = viewport_size.y / for_zoom.y
	
	# Calculate maximum movement allowed
	var max_x = max(0.0, (Global.GAME_W - visible_width) / 2.0)
	var max_y = max(0.0, (Global.GAME_H - visible_height) / 2.0)
	
	return {
		"left": -max_x,
		"right": max_x,
		"top": -max_y,
		"bottom": max_y
	}

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		# Calculate new zoom first
		var new_zoom = target_zoom
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			new_zoom = (target_zoom - Vector2.ONE * ZOOM_SPEED).clamp(Vector2.ONE * MIN_ZOOM, Vector2.ONE)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			new_zoom = (target_zoom + Vector2.ONE * ZOOM_SPEED).clamp(Vector2.ONE * MIN_ZOOM, Vector2.ONE)
			
		# Calculate bounds for new zoom before applying it
		var bounds = get_movement_bounds(new_zoom)
		var new_position = Vector2(
			clamp(target_position.x, bounds.left, bounds.right),
			clamp(target_position.y, bounds.top, bounds.bottom)
		)
		
		# Apply both changes together
		target_zoom = new_zoom
		target_position = new_position

func _process(delta: float) -> void:
	var mouse_pos = get_viewport().get_mouse_position()
	var screen_size = viewport_size
	var move_vec = Vector2.ZERO
	
	var x_scroll_percent = 0.0
	var y_scroll_percent = 0.0
	
	if mouse_pos.x < SCROLL_MARGIN:
		x_scroll_percent = 1.0 - (mouse_pos.x / SCROLL_MARGIN)
		move_vec.x = -1
	elif mouse_pos.x > screen_size.x - SCROLL_MARGIN:
		x_scroll_percent = 1.0 - ((screen_size.x - mouse_pos.x) / SCROLL_MARGIN)
		move_vec.x = 1
		
	if mouse_pos.y < SCROLL_MARGIN:
		y_scroll_percent = 1.0 - (mouse_pos.y / SCROLL_MARGIN)
		move_vec.y = -1
	elif mouse_pos.y > screen_size.y - SCROLL_MARGIN:
		y_scroll_percent = 1.0 - ((screen_size.y - mouse_pos.y) / SCROLL_MARGIN)
		move_vec.y = 1
	
	if move_vec != Vector2.ZERO:
		var speed = Vector2(
			MAX_SCROLL_SPEED * x_scroll_percent if move_vec.x != 0 else 0,
			MAX_SCROLL_SPEED * y_scroll_percent if move_vec.y != 0 else 0
		)
		target_position += move_vec * speed * delta
	
	# Always clamp to bounds, regardless of movement
	var bounds = get_movement_bounds(zoom)
	target_position.x = clamp(target_position.x, bounds.left, bounds.right)
	target_position.y = clamp(target_position.y, bounds.top, bounds.bottom)
	
	position = position.lerp(target_position, SMOOTHING)
	zoom = zoom.lerp(target_zoom, SMOOTHING)
