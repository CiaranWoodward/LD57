extends CanvasLayer

signal gameover_menu

func set_victory(state) :
	if (state) :
		$PanelContainer/MenuMargin/MenuVBox/GameOver.text = "Victory"
		$PanelContainer/MenuMargin/MenuVBox/GameOver2.text = "The forces of evil are defeated"
	else :
		$PanelContainer/MenuMargin/MenuVBox/GameOver.text = "Game Over"
		$PanelContainer/MenuMargin/MenuVBox/GameOver2.text = "The forces of evil have prevailed"


func _on_button_pressed() -> void:
	gameover_menu.emit()
