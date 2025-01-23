extends Node

const HIGHLIGHT_COLOR = Color.YELLOW
const TEAM_COLORS = [
	Color(1, 0.3, 0.3),  # Red
	Color(0.3, 0.3, 1),  # Blue
	Color(0.3, 1, 0.3),  # Green
	#Color(1, 1, 0.3),    # Yellow
	#Color(1, 0.3, 1),    # Purple
]

const GAME_W = 1280;
const GAME_H = 720;

var battle_mode_enabled: bool = false
var show_health_bars: bool = false

signal battle_mode_toggled(enabled: bool)
signal health_bars_toggled(enabled: bool)

func toggle_battle_mode() -> void:
	battle_mode_enabled = !battle_mode_enabled
	battle_mode_toggled.emit(battle_mode_enabled)

func toggle_health_bars() -> void:
	show_health_bars = !show_health_bars
	health_bars_toggled.emit(show_health_bars)
