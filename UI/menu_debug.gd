extends CanvasLayer

signal dbg_gameover

signal dbg_win

signal dbg_music_mode

signal dbg_add_xp(value)

signal dbg_kill_all_enemies

func _on_game_over_pressed() -> void:
	dbg_gameover.emit()


func _on_music_mode_pressed() -> void:
	dbg_music_mode.emit()


func _on_add_xp_pressed() -> void:
	dbg_add_xp.emit(100)


func _on_win_pressed() -> void:
	dbg_win.emit()

func _on_kill_all_enemies_pressed() -> void:
	dbg_kill_all_enemies.emit()
