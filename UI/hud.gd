extends CanvasLayer

signal PauseMenu

func _on_button_menu_pressed() -> void:
	PauseMenu.emit()
