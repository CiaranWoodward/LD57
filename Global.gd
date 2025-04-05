extends Node

# Global game state and utility functions
var debug_mode: bool = true
var current_level: int = 1

func _ready():
	print("Global singleton initialized")

# Utility function to get a file path
func get_resource_path(resource_name: String) -> String:
	return "res://" + resource_name 