extends Node2D

@export var mans_scene: PackedScene = preload("res://scenes/mans.tscn")
@export var flag_scene: PackedScene = preload("res://scenes/flag.tscn")

# Add these class preloads
var class_resources = [
	preload("res://resources/classes/man.tres"),
	preload("res://resources/classes/wizard.tres"),
	preload("res://resources/classes/brute.tres"),
	preload("res://resources/classes/dog.tres"),
	preload("res://resources/classes/baby.tres")
]

var selection_start: Vector2
var is_selecting: bool = false
var selected_mans: Array[Mans] = []
var is_group_dragging: bool = false
var team_flags: Dictionary = {}  # team_index -> Flag

func _draw() -> void:
	if is_selecting:
		var rect = get_selection_rect()
		var shadow_rect = Rect2(
			Vector2(rect.position.x+1, rect.position.y+1), 
			rect.size
		)
		draw_rect(shadow_rect, Color(0, 0, 0, 0.2))  # shadow
		draw_rect(rect, Color(Global.HIGHLIGHT_COLOR, 0.2))  # Fill
		draw_rect(rect, Color(Global.HIGHLIGHT_COLOR, 0.8), false)  # Outline
		
		# Preview thickness for mans in selection
		for child in get_children():
			if child is Mans:
				child.preview_select(rect.has_point(child.position))

func get_selection_rect() -> Rect2:
	var current_pos = get_global_mouse_position()
	var top_left = Vector2(
		min(selection_start.x, current_pos.x),
		min(selection_start.y, current_pos.y)
	)
	var size = (current_pos - selection_start).abs()
	return Rect2(top_left, size)

func update_selection_preview() -> void:
	if is_selecting:
		var rect = get_selection_rect()
		for child in get_children():
			if child is Mans:
				child.preview_select(rect.has_point(child.position))

func start_group_drag(mouse_pos: Vector2) -> void:
	is_group_dragging = true
	# Start dragging all selected mans
	for mans in selected_mans:
		mans.start_drag_in_group(mouse_pos)
	get_viewport().set_input_as_handled()

func clear_selection() -> void:
	for mans in selected_mans:
		mans.deselect()
	selected_mans.clear()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Check if we're clicking on any mans (selected or not)
				var clicking_mans = false
				for child in get_children():
					if child is Mans and child.is_hovered:
						clicking_mans = true
						break
				
				if !clicking_mans:
					selection_start = get_global_mouse_position()
					is_selecting = true
					clear_selection()
			else:
				# End selection or group drag
				if is_selecting:
					is_selecting = false
					var rect = get_selection_rect()
					# Reset all preview thicknesses
					for child in get_children():
						if child is Mans:
							child.preview_select(false)
							if rect.has_point(child.position):
								child.select()
								selected_mans.append(child)
				elif is_group_dragging:
					is_group_dragging = false
					for mans in selected_mans:
						mans.put_down()
					clear_selection()
				queue_redraw()
		
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			var new_mans = mans_scene.instantiate() as Mans
			new_mans.position = get_global_mouse_position()
			
			# Create a unique instance of the class stats
			var random_class = class_resources[randi() % class_resources.size()]
			new_mans.stats = random_class.duplicate()
			
			add_child(new_mans)
			
			# Check if team needs a flag
			var team_has_flag = false
			for flag in get_tree().get_nodes_in_group("flags"):
				if flag.team_color_index == new_mans.team_color_index:
					team_has_flag = true
					break
			
			if !team_has_flag:
				var flag = spawn_flag(new_mans.team_color_index, new_mans.global_position)
				flag.attach_to(new_mans)
			get_viewport().set_input_as_handled()
	
	elif event is InputEventMouseMotion:
		if is_selecting:
			update_selection_preview()
			queue_redraw()
			
	if event.is_action_pressed("delete"):
		if selected_mans.size() > 0:
			for mans in selected_mans:
				remove_child(mans);
				mans.queue_free();
			selected_mans.clear();

	elif event.is_action_pressed("toggle_battle"):
		Global.toggle_battle_mode()

	elif event.is_action_pressed("toggle_health"):
		Global.toggle_health_bars()

func spawn_flag(team_index: int, position: Vector2) -> Flag:
	var flag = flag_scene.instantiate() as Flag
	flag.team_color_index = team_index
	flag.global_position = position
	add_child(flag)
	team_flags[team_index] = flag
	return flag

# Helper function for mans to find their team's flag
func get_team_flag(team_index: int) -> Flag:
	return team_flags.get(team_index)
