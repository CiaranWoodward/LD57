class_name StoneWallTile
extends IsometricTile

func _init():
	type = "stone_wall"
	is_walkable = false  # Cannot walk through walls
	movement_cost = 0.0  # Not applicable for walls

func _ready():
	super._ready()
	# Additional initialization for stone wall tile 