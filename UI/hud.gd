extends CanvasLayer
class_name HUD

signal PauseMenu
signal UpgradeMenu

func _ready() -> void:
	Global.hud = self

func _on_button_menu_pressed() -> void:
	PauseMenu.emit()
	
func _on_button_upgrade_pressed() -> void:
	UpgradeMenu.emit()

func get_end_turn_button():
	return $End/EndMargin/EndButton
