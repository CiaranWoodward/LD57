extends Node

# Global game state and utility functions
var debug_mode: bool = true
var current_level: int = 1
var hud : HUD = null
var xp: int = 0  # Global XP counter shared between all players

func _ready():
	print("Global singleton initialized")

# Utility function to get a file path
func get_resource_path(resource_name: String) -> String:
	return "res://" + resource_name 

# Add XP to the global counter
func add_xp(amount: int):
	xp += amount
	print("Global: Added " + str(amount) + " XP, new total: " + str(xp))
	
	# Update the HUD if it exists
	if hud:
		hud.update_xp_counter(xp) 
