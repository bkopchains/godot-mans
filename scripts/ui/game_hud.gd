extends Control
@export var game: Game;
@export var drag_layer: CanvasLayer;  # Reference to a higher CanvasLayer

@onready var man_button: Button = %ManButton
@onready var brute_button: Button = %BruteButton
@onready var wizard_button: Button = %WizardButton
@onready var dog_button: Button = %DogButton
@onready var baby_button: Button = %BabyButton
@onready var menu_toggle_button: Button = %MenuToggleButton
@onready var menu_buttons: VBoxContainer = %VBoxMenuButtons
@onready var buttons_container: NinePatchRect = $PopupMenu/VBoxMenuButtons/BaseMenuScreen/NinePatchRect

var menu_tween: Tween
var button_to_class_index = {
	"ManButton": 0,
	"BruteButton": 2,
	"WizardButton": 1,
	"DogButton": 3,
	"BabyButton": 4
}

func _ready() -> void:
	# Set up initial menu state
	var hidden_y = get_viewport_rect().size.y + 20
	menu_buttons.position.y = hidden_y
	menu_buttons.modulate.a = 0
	
	# Connect button signals
	for button: Button in [man_button, brute_button, wizard_button, dog_button, baby_button]:
		button.button_down.connect(_on_class_button_down.bind(button))
		button.modulate = Global.TEAM_COLORS[Global.player_team]
		

func _on_class_button_down(button: Button) -> void:
	var class_index = button_to_class_index[button.name]
	
	# Get the screen position directly
	var screen_position = get_viewport().get_mouse_position()
	
	# Spawn a new mans
	var new_mans = game.mans_scene.instantiate() as Mans
	new_mans.game = game
	new_mans.from_drawer = true;
	new_mans.stats = game.class_resources[class_index].duplicate()
	
	if !Global.admin_mode:
		new_mans.team_color_index = Global.player_team
	
	drag_layer.add_child(new_mans)
	new_mans.position = screen_position  # Use screen coordinates for CanvasLayer
	
	# Simulate the input event to start dragging
	var event = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	new_mans._on_input_event(get_viewport(), event, 0)

func _on_menu_toggle_pressed() -> void:
	if menu_tween:
		menu_tween.kill()
	
	menu_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	var visible_y = get_viewport_rect().size.y - menu_buttons.size.y
	var hidden_y = get_viewport_rect().size.y + 20
	
	if menu_buttons.modulate.a == 0:  # Menu is hidden
		# Show menu
		menu_tween.parallel().tween_property(menu_buttons, "modulate:a", 1.0, 0.3)
		menu_tween.parallel().tween_property(menu_buttons, "position:y", visible_y, 0.3)
	else:
		# Hide menu
		menu_tween.parallel().tween_property(menu_buttons, "modulate:a", 0.0, 0.3)
		menu_tween.parallel().tween_property(menu_buttons, "position:y", hidden_y, 0.3)
