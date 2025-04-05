extends Control

@export var debug : bool = true

#All game levels:
var levels : Array[PackedScene] = [
	load("res://Level/map.tscn")
]

#All music tracks:
var tracks : Array[AudioStreamMP3] = [
		load("res://music/LD76 OST Main Title Loop mp3.mp3"),
		load("res://music/LD57 Level 1 Loop.mp3"),
		load("res://music/LD76 Level 1 Loop (Low Health).mp3")
	]

var bloody_offset : int = (len(tracks)-1)/2

var game_started : bool = false

var current_level : Node

var music_player : AudioStreamPlayer


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	music_player = $Music
	music_track(0)
	music_player.finished.connect(music_loop)

func music_track(track) -> void:
	music_player.stream = tracks[track]
	music_player.play(0)

func music_urgency() -> void:
	music_player.stream

#Loop current track:
func music_loop() -> void:
	music_player.play(0)


#Visibility of main menu:
func show_menu(enable : bool) -> void:
	$MenuMain.visible = enable	
	$BG.visible = enable	
	$HUD.visible = !enable


#Visibility of options menu:
func show_options(enable : bool) -> void:
	$MenuMain.visible = !enable	
	$MenuOptions.visible = enable	

#Resume level:
func _on_menu_main_resume_pressed() -> void:
	show_menu(false)
	get_tree().root.add_child(current_level)


func _on_menu_main_new_game_pressed() -> void:
	
	#Replace 'New Game' button with 'Resume'
	game_started = true
	$MenuMain/MainMargin/MainVBox/MainPanelMargin/MainButtonMargin/MainButtonVBox/NewGame.visible = !game_started
	$MenuMain/MainMargin/MainVBox/MainPanelMargin/MainButtonMargin/MainButtonVBox/Resume.visible = game_started
	
	#Hide menu, enable HUD and show first level:
	show_menu(false)
	current_level = levels[0].instantiate()
	get_tree().root.add_child(current_level)
	
	#Start music for first level:
	music_track(1)


func _on_menu_main_options_pressed() -> void:
	show_options(true)


func _on_menu_options_back_pressed() -> void:
	show_options(false)
	show_menu(true)


func _process(delta: float) -> void:
	
	#Toggle debug menu
	if  (debug == true) and (Input.is_action_just_pressed("debug")) :
		$MenuDebug.visible = !$MenuDebug.visible


func _on_hud_pause_menu() -> void:
	show_menu(true)
	get_tree().root.remove_child(current_level)


func _on_menu_options_vol_changed(volume: Variant) -> void:
	music_player.volume_linear = volume/100
