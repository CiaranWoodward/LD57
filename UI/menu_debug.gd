extends CanvasLayer

signal dbg_gameover

signal dbg_win

signal dbg_music_mode

signal dbg_add_xp(value)

func _on_game_over_pressed() -> void:
	dbg_gameover.emit()


func _on_music_mode_pressed() -> void:
	dbg_music_mode.emit()


func _on_add_xp_pressed() -> void:
	dbg_add_xp.emit(100)


func _on_win_pressed() -> void:
	dbg_win.emit()
