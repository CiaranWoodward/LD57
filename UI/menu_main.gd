extends CanvasLayer

signal new_game_pressed
signal resume_pressed
signal options_pressed

func _on_new_game_pressed() -> void:
	new_game_pressed.emit()
	
func _on_resume_pressed() -> void:
	resume_pressed.emit()

func _on_options_pressed() -> void:
	options_pressed.emit()

#Quit game:
func _on_quit_pressed() -> void:
	get_tree().quit()
