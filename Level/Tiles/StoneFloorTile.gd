class_name StoneFloorTile
extends IsometricTile

func _init():
	type = "stone_floor"
	is_walkable = true
	movement_cost = 1.0

func _ready():
	super._ready()
	# Additional initialization for stone floor tile 
