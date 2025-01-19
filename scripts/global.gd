extends Node

const HIGHLIGHT_COLOR = Color.YELLOW;

var battle_mode_enabled: bool = false
var show_health_bars: bool = true

signal battle_mode_toggled(enabled: bool)
signal health_bars_toggled(enabled: bool)

func toggle_battle_mode() -> void:
	battle_mode_enabled = !battle_mode_enabled
	battle_mode_toggled.emit(battle_mode_enabled)

func toggle_health_bars() -> void:
	show_health_bars = !show_health_bars
	health_bars_toggled.emit(show_health_bars)
