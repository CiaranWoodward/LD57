# Add reference to our sound manager
onready var sound_manager = preload("res://Global/SoundManager.gd").new()

func _ready():
	# Initialize the sound manager if it doesn't exist yet
	if not has_node("SoundManager"):
		sound_manager.name = "SoundManager"
		add_child(sound_manager) 