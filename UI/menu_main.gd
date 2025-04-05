extends Control

@export var levels: Array[PackedScene]

var game_started : bool = false

var current_level : Node

func show_hud(enable : bool) -> void:
	$HUD.visible = enable
	
func show_menu(enable : bool) -> void:
	$MenuCanvas.visible = enable
	
func _on_resume_pressed() -> void:
	show_menu(false)
	show_hud(true)
	
	get_tree().root.add_child(current_level)


func _on_new_game_pressed() -> void:
	game_started = true
	show_menu(false)
	show_hud(true)
	
	current_level = levels[0].instantiate()
	get_tree().root.add_child(current_level)


func _on_options_pressed() -> void:
	pass # Replace with function body.


func _on_quit_pressed() -> void:
	get_tree().quit()


func _process(delta: float) -> void:
	$MenuCanvas/MainVBox/NewGame.visible = !game_started
	$MenuCanvas/MainVBox/Resume.visible = game_started

func _on_hud_pause_menu() -> void:
	show_menu(true)
	show_hud(false)
	get_tree().root.remove_child(current_level)
