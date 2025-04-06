extends CanvasLayer

signal gameover_menu

func _on_button_pressed() -> void:
	gameover_menu.emit()
