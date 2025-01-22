class_name Game
extends Node2D

@export var mans_scene: PackedScene = preload("res://scenes/mans.tscn")
@export var flag_scene: PackedScene = preload("res://scenes/flag.tscn")
@onready var game_elements: Node2D = $GameElements
@onready var selection_drawer: Node2D = $SelectionDrawer

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

var team_bases: Dictionary = {} # team_index -> Tent
var team_flags: Dictionary = {}  # team_index -> Flag
var team_scores: Dictionary = {} # team_index -> int (score)

func update_selection_preview() -> void:
	if is_selecting:
		var rect = get_selection_rect()
		for child in game_elements.get_children():
			if child is Mans:
				child.preview_select(rect.has_point(child.position))
		selection_drawer.queue_redraw()

func get_selection_rect() -> Rect2:
	var current_pos = get_global_mouse_position()
	var top_left = Vector2(
		min(selection_start.x, current_pos.x),
		min(selection_start.y, current_pos.y)
	)
	var size = (current_pos - selection_start).abs()
	return Rect2(top_left, size)

func start_group_drag(mouse_pos: Vector2) -> void:
	is_group_dragging = true
	# Start dragging all selected mans
	for mans in selected_mans:
		mans.start_drag_in_group(mouse_pos)
	get_viewport().set_input_as_handled()

func clear_selection() -> void:
	for mans in selected_mans:
		if is_instance_valid(mans):
			mans.deselect()
	selected_mans.clear()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Check if we're clicking on any mans (selected or not)
				var clicking_mans = false
				for child in game_elements.get_children():
					if child is Mans and child.is_hovered:
						clicking_mans = true
						break
				
				if !clicking_mans:
					selection_start = get_global_mouse_position()
					is_selecting = true
					selection_drawer.is_selecting = true
					clear_selection()
			else:
				# End selection or group drag
				if is_selecting:
					is_selecting = false
					selection_drawer.is_selecting = false
					selection_drawer.queue_redraw()
					var rect = get_selection_rect()
					for child in game_elements.get_children():
						if child is Mans:
							child.preview_select(false)
							if rect.has_point(child.position):
								child.select()
								selected_mans.append(child)
				elif is_group_dragging:
					is_group_dragging = false
					for mans in selected_mans:
						if is_instance_valid(mans):
							mans.put_down()
					clear_selection()
		
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			var new_mans = mans_scene.instantiate() as Mans
			new_mans.position = get_global_mouse_position()
			new_mans.game = self;
			
			# Create a unique instance of the class stats
			var random_class = class_resources[randi() % class_resources.size()]
			new_mans.stats = random_class.duplicate()
			
			game_elements.add_child(new_mans)
			
			# Check if team needs a flag
			var team_has_flag = false
			if !team_flags.has(new_mans.team_color_index):
				var flag = spawn_flag(new_mans.team_color_index, new_mans.global_position)
				flag.attach_to(new_mans)
				
			get_viewport().set_input_as_handled()
	
	elif event is InputEventMouseMotion:
		if is_selecting:
			selection_drawer.selection_rect = get_selection_rect()
			update_selection_preview()

	if event.is_action_pressed("delete"):
		if selected_mans.size() > 0:
			for mans in selected_mans:
				if is_instance_valid(mans):
					game_elements.remove_child(mans);
					mans.queue_free();
			selected_mans.clear();

	elif event.is_action_pressed("toggle_battle"):
		Global.toggle_battle_mode()

	elif event.is_action_pressed("toggle_health"):
		Global.toggle_health_bars()

func spawn_flag(team_index: int, pos: Vector2) -> Flag:
	var flag = flag_scene.instantiate() as Flag
	flag.team_color_index = team_index
	flag.global_position = pos
	game_elements.add_child(flag)
	team_flags[team_index] = flag
	return flag

# Helper function for mans to find their team's flag
func get_team_flag(team_index: int) -> Flag:
	return team_flags.get(team_index)

# Log a flag as captured, remove that flag from the game
func capture_flag(team_index: int, flag: Flag) -> void:
	team_flags.erase(team_index);
	flag.queue_free();
	# add 1 or initialize score
	team_scores[team_index] = team_scores.get(team_index, 0) + 1
	
