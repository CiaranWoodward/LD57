extends CanvasLayer
class_name HUD

signal PauseMenu

func _ready() -> void:
	Global.hud = self

func _on_button_menu_pressed() -> void:
	PauseMenu.emit()

func get_end_turn_button():
	return $End/EndMargin/EndButton
