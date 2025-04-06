class_name LevelManager
extends Node2D

signal player_descended(player, from_level, to_level)

# Configuration
@export var level_vertical_offset: float = 800  # Vertical distance between levels
@export var max_active_levels: int = 3  # Maximum number of simultaneously active levels

# Level management
var active_levels: Array[IsometricMap] = []
var level_scenes: Array[PackedScene] = []
var level_nodes: Dictionary = {}  # Level index -> IsometricMap node
var current_deepest_level: int = 0

func _ready():
	# Register initial level scenes
	level_scenes = [
		load("res://Level/map.tscn"),  # Level 1
		load("res://Level/map.tscn")   # Level 2 (for now using the same scene)
	]
	
	# Initialize the first level
	initialize_level(0)

# Initialize a level at the specified index
func initialize_level(level_index: int) -> IsometricMap:
	if level_index >= level_scenes.size():
		push_error("Level index out of bounds: " + str(level_index))
		return null
		
	if level_nodes.has(level_index):
		return level_nodes[level_index]  # Level already initialized
		
	print("LevelManager: Initializing level " + str(level_index))
	
	# Instance the level
	var level_instance = level_scenes[level_index].instantiate() as IsometricMap
	
	# Position the level based on its depth
	level_instance.position.y = level_index * level_vertical_offset
	level_instance.level_index = level_index
	
	# Add to scene tree
	add_child(level_instance)
	level_instance.z_index = -level_index
	
	# Track this level
	level_nodes[level_index] = level_instance
	active_levels.append(level_instance)
	
	# Update deepest level if needed
	if level_index > current_deepest_level:
		current_deepest_level = level_index
		
	print("LevelManager: Level " + str(level_index) + " initialized")
	return level_instance

# Check if a tile position in a level has a valid tile below it for drilling
func has_valid_tile_below(level_index: int, grid_pos: Vector2i) -> bool:
	if level_index >= level_scenes.size() - 1:
		return false  # No level below
		
	var level_below_index = level_index + 1
	
	# Initialize the level below if it's not already active
	if not level_nodes.has(level_below_index):
		initialize_level(level_below_index)
		
	var level_below = level_nodes[level_below_index]
	var tile_below = level_below.get_tile(grid_pos)
	
	return tile_below != null and tile_below.is_walkable

# Handle player descending to the next level
# This will be called when implementing the drilling mechanic
func descend_player(player_entity : PlayerEntity, from_level_index: int, grid_pos: Vector2i) -> bool:
	if not has_valid_tile_below(from_level_index, grid_pos):
		print("LevelManager: No valid tile below for descent")
		return false
		
	var to_level_index = from_level_index + 1
	var to_level : Node2D = level_nodes[to_level_index]
	
	# Get the target tile on the lower level
	var target_tile = to_level.get_tile(grid_pos)
	if not target_tile:
		print("LevelManager: Cannot find target tile on level " + str(to_level_index))
		return false
	
	# Move player to the lower level
	player_entity.descend_to_level(to_level_index, target_tile)
	# Change the parent of the player to the new level
	player_entity.get_parent().remove_child(player_entity)
	to_level.add_child(player_entity)
	
	# Emit signal to notify other systems
	emit_signal("player_descended", player_entity, from_level_index, to_level_index)
	
	print("LevelManager: Player " + player_entity.entity_name + " moved to level " + str(to_level_index))
	return true

# Cleanup levels that are too far above the deepest active level
func cleanup_distant_levels():
	if active_levels.size() <= max_active_levels:
		return
		
	var levels_to_remove = active_levels.size() - max_active_levels
	for i in range(levels_to_remove):
		var oldest_level = active_levels[0]
		var oldest_index = level_nodes.find_key(oldest_level)
		
		print("LevelManager: Removing inactive level " + str(oldest_index))
		active_levels.remove_at(0)
		level_nodes.erase(oldest_index)
		oldest_level.queue_free() 
