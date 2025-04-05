extends CanvasLayer

signal dbg_music_mode

func _on_music_mode_pressed() -> void:
	dbg_music_mode.emit()
