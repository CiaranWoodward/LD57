class_name SoundManager
extends Node

# Sound effect categories with their variants
var sound_effects = {
	"walk": [
		preload("res://sfx/LD57 Walk_1.mp3"),
		preload("res://sfx/LD57 Walk_2.mp3"),
		preload("res://sfx/LD57 Walk_3.mp3"),
		preload("res://sfx/LD57 Walk_4.mp3")
	],
	"die": [
		preload("res://sfx/LD57 Damage taken (definitely not the wilhem scream processed).mp3")
	],
	"drill": [
		preload("res://sfx/LD57 Electro Power Drill.mp3"),
		preload("res://sfx/LD57 Electro Power Drill 2.mp3")
	],
	"fireball": [
		preload("res://sfx/LD57 Fireball.mp3"),
		preload("res://sfx/LD57 Fireball_2.mp3"),
		preload("res://sfx/LD57 Fireball_3.mp3")
	],
	"metal_hit": [
		preload("res://sfx/LD57 Metal hit.mp3")
	],
	"point": [
		preload("res://sfx/LD57 Point.mp3")
	],
	"arrow": [
		preload("res://sfx/LD57 Arrow shot maybe.mp3")
	],
	"powerup": [
		preload("res://sfx/LD57 Digital powerup 3.mp3")
	]
}

# Audio player pool for playing multiple sounds simultaneously
var audio_players = []
const POOL_SIZE = 8

func _ready():
	# Initialize the audio player pool
	for i in range(POOL_SIZE):
		var player = AudioStreamPlayer.new()
		player.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
		player.finished.connect(_on_sound_finished.bind(player))
		player.name = "AudioPlayer_" + str(i)
		add_child(player)
		audio_players.append(player)

# Play a random sound from the specified category with pitch variation
func play_sound(sound_type: String, volume_db: float = 0.0, pitch_variation: float = 0.1):
	if not sound_effects.has(sound_type) or sound_effects[sound_type].size() == 0:
		push_error("SoundManager: Sound type " + sound_type + " not found or has no sounds")
		return
	
	# Select a random sound from the category
	var sounds = sound_effects[sound_type]
	var sound = sounds[randi() % sounds.size()]
	
	# Check if this exact sound is already playing in any player
	for player in audio_players:
		if player.playing and player.stream == sound:
			# Sound is already playing, don't restart it
			return player
	
	# Find an available audio player
	var player = get_available_player()
	if player:
		# Set up the audio player
		player.stream = sound
		player.volume_db = volume_db
		
		# Apply random pitch variation (±pitch_variation)
		var random_pitch = 1.0 + randf_range(-pitch_variation, pitch_variation)
		player.pitch_scale = random_pitch
		
		# Play the sound
		player.play()
		return player
	
	return null

# Get an available audio player from the pool
func get_available_player() -> AudioStreamPlayer:
	for player in audio_players:
		if not player.playing:
			return player
	
	# If all players are busy, use the first one (oldest)
	print("SoundManager: All audio players are busy, reusing the first one")
	audio_players[0].stop()
	return audio_players[0]

# Called when a sound finishes playing
func _on_sound_finished(player: AudioStreamPlayer):
	# Reset the player for reuse
	player.pitch_scale = 1.0
	player.volume_db = 0.0 