extends Control

@export var debug_en : bool = true
var debug_mode : bool = false

var paused : bool = true

#All game levels:
var levels : Array[PackedScene] = [
	load("res://Level/MultiLevelGame.tscn")
]

#All music tracks:
var tracks : Array[AudioStreamMP3] = [
		load("res://music/LD76 OST Main Title Loop mp3.mp3"),
		load("res://music/LD57 Level 1 Loop.mp3"),
		load("res://music/LD76 Level 1 Loop (Low Health).mp3")
	]

var music_player : Array[AudioStreamPlayer]
var current_stream_player : int = 0
var current_track : int = 0
var music_volume : float = 0.08
var music_urgency : bool = false
var bloody_offset : int = (len(tracks)-1)/2

var game_started : bool = false
var current_level : Node


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	music_player.resize(2)
	music_player[0] = $Music0
	music_player[1] = $Music1
	music_player[0].volume_linear = music_volume
	music_player[1].volume_linear = music_volume
	music_track(0)
	music_player[0].finished.connect(music_loop)
	music_player[1].finished.connect(music_loop)

func music_track(track) -> void:
	current_track = track
	music_player[current_stream_player].stream = tracks[track]
	music_player[current_stream_player].play(0)
	
func music_fade(track) -> void:
	pass

func music_fade_in(music_player, track, start_point) :
	music_player.stream = tracks[track]
	music_player.volume_linear = 0
	music_player.play(start_point)
	var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	tween.tween_property(music_player, "volume_linear", music_volume, 2)
	
func music_fade_out(music_player) :
	var tween = create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	tween.tween_property(music_player, "volume_linear", 0, 2)
	
#Toggle music urgency:
func music_toggle_urgency() -> void:
	
	var start_point = music_player[current_stream_player].get_playback_position()
	if (music_urgency) :
		current_track = current_track - bloody_offset
	else :
		current_track = current_track + bloody_offset
		
	music_urgency = !music_urgency
	
	music_fade_out(music_player[current_stream_player])
	if current_stream_player == 0 :
		current_stream_player = 1
	else :
		current_stream_player = 0
	music_fade_in(music_player[current_stream_player],current_track,start_point)

#Loop current track:
func music_loop() -> void:
	music_player[current_stream_player].play(0)
		

#Visibility of main menu:
func show_menu(enable : bool) -> void:	
	$MenuMain.visible = enable


#Visibility of options menu:
func show_options(enable : bool) -> void:
	$MenuOptions.visible = enable	


#Visibility of ingame HUD:
func show_hud(enable : bool) -> void :
	$HUD.visible = enable
	
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
	music_volume = volume/1000
	music_player[current_stream_player].volume_linear = music_volume


func _on_menu_debug_dbg_music_mode() -> void:
	music_toggle_urgency()
