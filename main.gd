extends Control

@export var levels : Array[PackedScene]

var tracks : Dictionary = {
		"Level1": load("res://music/LD57 Level 1 Loop.mp3")
	}

var game_started : bool = false

var current_level : Node

var music_player : AudioStreamPlayer


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	music_player = $Music
	music_player.finished.connect(music_loop)


#Loop current track:
func music_loop() -> void:
	music_player.play(0)


#Visibility of in-game HUD:
func show_hud(enable : bool) -> void:
	$HUD.visible = enable


#Visibility of main menu:
func show_menu(enable : bool) -> void:
	$MenuMain.visible = enable	


#Visibility of main menu:
func show_options(enable : bool) -> void:
	$MenuOptions.visible = enable	
	
	
func _on_menu_main_resume_pressed() -> void:
	show_menu(false)
	show_hud(true)
	
	get_tree().root.add_child(current_level)


func _on_menu_main_new_game_pressed() -> void:
	game_started = true
	show_menu(false)
	show_hud(true)
	
	current_level = levels[0].instantiate()
	get_tree().root.add_child(current_level)
	music_player.stream = tracks.Level1
	music_player.play(0)


func _on_menu_main_options_pressed() -> void:
	show_menu(false)
	show_options(true)


func _on_menu_options_back_pressed() -> void:
	show_menu(true)
	show_options(false)


func _process(delta: float) -> void:
	$MenuMain/MainVBox/NewGame.visible = !game_started
	$MenuMain/MainVBox/Resume.visible = game_started


func _on_hud_pause_menu() -> void:
	show_menu(true)
	show_hud(false)
	get_tree().root.remove_child(current_level)


func _on_menu_options_vol_changed(volume: Variant) -> void:
	music_player.volume_linear = volume/100
