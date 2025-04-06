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
	
	# Set initial modulation (grey for non-active levels)
	if level_index > 0:  # Assume first level starts as active
		level_instance.modulate = Color(0.7, 0.7, 0.7, 1.0)
	
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
func descend_player(player_entity: PlayerEntity, from_level_index: int, grid_pos: Vector2i) -> bool:
	print("LevelManager: Player " + player_entity.entity_name + " attempting to descend from level " + 
		  str(from_level_index) + " to level " + str(from_level_index + 1) + " at position " + str(grid_pos))
		  
	if not has_valid_tile_below(from_level_index, grid_pos):
		print("LevelManager: No valid tile below for descent")
		return false
		
	var to_level_index = from_level_index + 1
	var to_level_map: IsometricMap = level_nodes[to_level_index]
	
	# Get the target tile on the lower level
	var target_tile = to_level_map.get_tile(grid_pos)
	if not target_tile:
		print("LevelManager: Cannot find target tile on level " + str(to_level_index))
		return false
		
	if target_tile.is_occupied:
		print("LevelManager: Target tile on level " + str(to_level_index) + " is already occupied by " + 
			 (target_tile.occupying_entity.entity_name if target_tile.occupying_entity else "unknown entity"))
		
		# Try to find a nearby unoccupied tile
		var neighbors = to_level_map.get_neighbors(grid_pos)
		var found_alternative = false
		
		for neighbor_tile in neighbors:
			if neighbor_tile.is_walkable and not neighbor_tile.is_occupied:
				target_tile = neighbor_tile
				found_alternative = true
				print("LevelManager: Found alternative unoccupied tile at " + str(neighbor_tile.grid_position))
				break
				
		if not found_alternative:
			print("LevelManager: All nearby tiles on level " + str(to_level_index) + " are occupied")
			return false
	
	# First, update the entity's level and isometric_map references
	# This will be handled by the entity's descend_to_level method
	var success = player_entity.descend_to_level(to_level_index, target_tile)
	
	if success:
		# Verify the entity is properly set up before switching parents
		if player_entity.current_level != to_level_index:
			push_error("LevelManager: Player level index not updated correctly")
			return false
			
		if player_entity.isometric_map != to_level_map:
			push_error("LevelManager: Player isometric_map reference not updated correctly")
			player_entity.isometric_map = to_level_map
		
		# Only reparent if needed
		if player_entity.get_parent() != to_level_map:
			print("LevelManager: Reparenting player from " + 
				 (player_entity.get_parent().name if player_entity.get_parent() else "null") + 
				 " to " + to_level_map.name)
				 
			player_entity.get_parent().remove_child(player_entity)
			to_level_map.add_child(player_entity)
		
		# Emit signal to notify other systems
		emit_signal("player_descended", player_entity, from_level_index, to_level_index)
		
		print("LevelManager: Player " + player_entity.entity_name + " successfully moved to level " + str(to_level_index))
		return true
	else:
		print("LevelManager: Failed to descend player to level " + str(to_level_index))
		return false

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
