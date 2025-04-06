extends Control

@export var debug_en : bool = true
var debug_mode : bool = false

var paused : bool = true

#All game levels:
var levels : Array[PackedScene] = [
	load("res://Level/Game.tscn")
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
	music_player.volume_linear = 0.08
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


#Visibility of options menu:
func show_options(enable : bool) -> void:
	$MenuOptions.visible = enable	


#Visibility of ingame HUD:
func show_hud(enable : bool) -> void :
	pass#$HUD.visible = enable
	
func show_bg(enable : bool) -> void :
	$BG.visible = enable	


func set_paused(en) -> void:
	paused = en
	show_bg(en)
	show_hud(!en)
	show_menu(en)
	if (en) :
		get_tree().root.remove_child(current_level)
	else :
		get_tree().root.add_child(current_level)
		show_options(en)


#Resume level:
func _on_menu_main_resume_pressed() -> void:
	set_paused(0)


func _on_menu_main_new_game_pressed() -> void:
	
	#Replace 'New Game' button with 'Resume'
	game_started = true
	$MenuMain/MainMargin/MainVBox/MainPanelMargin/MainButtonMargin/MainButtonVBox/NewGame.visible = !game_started
	$MenuMain/MainMargin/MainVBox/MainPanelMargin/MainButtonMargin/MainButtonVBox/Resume.visible = game_started
	
	set_paused(0)
	
	#Hide menu, enable HUD and show first level:
	current_level = levels[0].instantiate()
	set_paused(0)
	
	#Start music for first level:
	music_track(1)


func _on_menu_main_options_pressed() -> void:
	show_menu(false)
	show_options(true)


func _on_menu_options_back_pressed() -> void:
	show_menu(true)
	show_options(false)	


func _process(delta: float) -> void:
	
	#Pause menu:
	if  (game_started == true) && (Input.is_action_just_pressed("menu")) :
		set_paused(not paused)
	
	#Toggle debug menu:
	if  (debug_en == true) and (Input.is_action_just_pressed("debug")) :
		if (debug_mode) :
			debug_mode = false
			$MenuDebug.visible = 0
		else :
			debug_mode = true
			$MenuDebug.visible = 1


func _on_hud_pause_menu() -> void:
	set_paused(1)


func _on_menu_options_vol_changed(volume: Variant) -> void:
	print(volume/100/10)
	music_player.volume_linear = volume/1000
