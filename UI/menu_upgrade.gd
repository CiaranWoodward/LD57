extends CanvasLayer

signal upgrade_exit

func _on_exit_button_pressed() -> void:
	upgrade_exit.emit()
