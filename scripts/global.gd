extends Node

const HIGHLIGHT_COLOR = Color.YELLOW;

var battle_mode_enabled: bool = false

signal battle_mode_toggled(enabled: bool)

func toggle_battle_mode() -> void:
	battle_mode_enabled = !battle_mode_enabled
	battle_mode_toggled.emit(battle_mode_enabled)
