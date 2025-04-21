class_name LevelManager
extends Node2D

signal player_descended(player, from_level, to_level)

# Configuration
@export var level_vertical_offset: float = 800  # Vertical distance between levels
@export var max_active_levels: int = 3  # Maximum number of simultaneously active levels

# Level management
var active_levels: Array[IsometricMap] = []
var level_scene: PackedScene
var level_nodes: Dictionary = {}  # Level index -> IsometricMap node
var current_deepest_level: int = 0

# Tile and entity encoding dictionary
# First character: Tile type
# o = open/floor, s = stone/wall
# Second character (optional): Entity to spawn
# H = Hellbomb, C = Hellbomb Chaser, M = Minion, E = Elite, G = Grunt, B = Boss, P = Player (Heavy), S = Scout, W = Wizard
# X = Exploding Barrel, D = Destructible Wall
var tile_entity_encoding = {
	# Tile types (first character)
	"o": "open_floor",
	"s": "stone_wall",
	
	# Entity types (second character)
	"H": "hellbomb",
	"C": "hellbomb_chaser",
	"M": "minion",
	"E": "elite",
	"G": "grunt",
	"B": "boss",
	"P": "player_heavy",
	"S": "player_scout",
	"W": "player_wizard",
	"X": "exploding_barrel",
	"D": "destructible_wall"
}

var level_maps : Array = [
	[
		["s", "s", "s", "s", "s", "s", "s", "s", "s", "s", "s", "s", "s", "s", "s"],
		["s", "o", "o", "s", "o", "o", "o", "o", "o", "o", "o", "o", "o", "o", "o"],
		["s", "o", "oP", "s", "oS", "oW", "o", "o", "o", "o", "o", "o", "o", "o", "o"],
		["s", "o", "o", "s", "o", "o", "o", "o", "o", "o", "o", "o", "o", "o", "o"],
		["s", "o", "o", "s", "s", "s", "s", "o", "o", "o", "o", "o", "o", "o", "o"],
		["s", "o", "o", "o", "o", "o", "o", "o", "o", "o", "o", "o", "o", "o", "o"],
		["s", "o", "o", "o", "o", "o", "o", "o", "o", "o", "o", "o", "o", "o", "o"],
		["s", "o", "o", "o", "o", "o", "o", "oH","o", "o", "o", "o", "o", "o", "o"],
		["s", "o", "o", "o", "o", "o", "o", "o", "o", "o", "o", "o", "o", "o", "o"],
		["s", "o", "o", "o", "o", "o", "o", "o", "o", "o", "o", "o", "o", "o", "o"],
		["s", "o", "o", "o", "o", "o", "o", "o", "o", "o", "o", "o", "o", "o", "o"],
		["s", "o", "o", "o", "o", "o", "o", "o", "o", "o", "o", "oH", "o", "o", "o"],
		["s", "o", "o", "o", "o", "o", "o", "o", "o", "o", "o", "o", "o", "o", "o"],
		["s", "o", "o", "o", "o", "o", "o", "o", "o", "o", "o", "o", "o", "o", "o"],
		["s", "o", "o", "o", "o", "o", "o", "o", "o", "o", "o", "o", "o", "o", "o"]
	],
	[
		["s", "s", "s", "s", "s", "s", "s", "s", "s", "s", "s", "s", "s", "s", "s"],
		["s", "o", "o", "o", "o", "oD", "o", "o", "o", "o", "o", "o", "o", "o", "o"],
		["s", "o", "s", "o", "o", "oD", "o", "o", "o", "o", "o", "o", "s", "o", "o"],
		["s", "o", "s", "o", "oC", "oD", "o", "o", "o", "o", "o", "o", "s", "o", "o"],
		["s", "o", "s", "o", "o", "oD", "oG", "o", "o", "s", "o", "o", "s", "o", "o"],
		["s", "o", "s", "o", "o", "oD", "o", "o", "o", "s", "o", "o", "s", "o", "o"],
		["s", "o", "o", "o", "o", "s", "o", "s", "o", "o", "o", "o", "o", "o", "o"],
		["s", "o", "o", "o", "o", "s", "o", "s", "o", "o", "o", "o", "o", "o", "o"],
		["s", "o", "s", "o", "o", "oD", "o", "o", "o", "s", "o", "o", "s", "o", "o"],
		["s", "o", "s", "o", "o", "oD", "o", "o", "o", "s", "o", "o", "s", "o", "o"],
		["s", "o", "s", "o", "o", "oD", "o", "o", "o", "o", "o", "o", "s", "oG", "o"],
		["s", "o", "s", "oC", "o", "oD", "o", "o", "o", "o", "o", "o", "s", "o", "o"],
		["s", "o", "o", "o", "o", "oD", "o", "o", "o", "o", "o", "o", "o", "o", "o"],
		["s", "o", "o", "o", "o", "oD", "o", "o", "o", "o", "o", "o", "o", "o", "o"]
	],
	[
		["s", "s", "s", "s", "s", "s", "s", "s", "s", "s", "s", "s", "s", "s", "s"],
		["s", "s", "o", "o", "o", "o", "o", "o", "o", "o", "o", "o", "oD", "o", "o"],
		["s", "oM", "s", "o", "o", "o", "o", "o", "o", "o", "o", "o", "oD", "o", "o"],
		["s", "o", "o", "s", "o", "o", "o", "o", "o", "o", "o", "o", "oD", "o", "o"],
		["s", "o", "o", "o", "s", "o", "o", "o", "o", "o", "o", "o", "oD", "oD", "o"],
		["s", "o", "o", "o", "o", "s", "o", "o", "o", "o", "o", "o", "o", "o", "o"],
		["s", "o", "o", "o", "o", "o", "s", "oD", "oE", "o", "o", "o", "o", "o", "o"],
		["s", "o", "o", "o", "o", "o", "o", "s", "o", "o", "o", "o", "o", "o", "o"],
		["s", "o", "o", "o", "o", "o", "o", "o", "s", "o", "o", "o", "o", "o", "o"],
		["s", "o", "o", "o", "o", "o", "o", "s", "o", "o", "o", "o", "o", "o", "o"],
		["s", "o", "oE", "o", "o", "o", "s", "o", "o", "o", "o", "o", "o", "o", "o"],
		["s", "o", "o", "o", "o", "s", "o", "o", "o", "o", "o", "o", "o", "o", "o"],
		["s", "o", "o", "o", "s", "o", "o", "o", "o", "o", "o", "o", "oG", "o", "o"],
		["s", "o", "o", "o", "o", "o", "o", "o", "o", "o", "o", "o", "o", "o", "o"]
	],
	[
		["s", "s", "s", "s", "s", "s", "s", "s", "s", "s", "s", "s", "s", "s", "s"],
		["s", "o", "o", "o", "s", "s", "o", "o", "s", "s", "o", "o", "o", "o", "o"],
		["s", "o", "o", "o", "s", "o", "o", "o", "o", "oD", "oM", "o", "o", "o", "o"],
		["s", "o", "s", "s", "s", "oE", "o", "o", "o", "oD", "oD", "s", "o", "o", "o"],
		["s", "o", "o", "o", "o", "o", "o", "o", "o", "o", "o", "s", "o", "o", "o"],
		["s", "o", "o", "o", "o", "o", "o", "o", "o", "o", "o", "s", "s", "s", "o"],
		["s", "oC", "s", "s", "s", "o", "o", "oH", "o", "o", "o", "o", "o", "o", "o"],
		["s", "o", "o", "o", "s", "o", "o", "oE", "o", "o", "o", "o", "o", "o", "o"],
		["s", "o", "oX", "o", "s", "o", "o", "o", "o", "o", "o", "s", "s", "s", "o"],
		["s", "o", "o", "o", "s", "o", "o", "o", "o", "o", "o", "s", "o", "o", "o"],
		["s", "o", "o", "o", "s", "oD", "s", "oX", "o", "s", "s", "s", "o", "o", "o"],
		["s", "o", "o", "o", "o", "o", "s", "o", "o", "s", "o", "o", "o", "o", "o"],
		["s", "o", "o", "o", "o", "o", "s", "o", "o", "s", "o", "o", "o", "o", "o"],
		["s", "o", "o", "o", "o", "o", "o", "o", "o", "o", "o", "o", "oE", "o", "o"]
	],
	[
		["s", "s", "s", "s", "s", "s", "s", "s", "s", "s", "s", "s", "s", "s", "s"],
		["s", "o", "o", "o", "o", "o", "o", "o", "o", "o", "o", "o", "o", "o", "s"],
		["s", "o", "oD", "o", "o", "o", "o", "o", "o", "o", "o", "o", "oD", "o", "s"],
		["s", "o", "o", "o", "o", "oE", "o", "o", "o", "oE", "o", "o", "o", "o", "s"],
		["s", "o", "o", "oX", "o", "o", "o", "o", "o", "o", "o", "oX", "o", "o", "s"],
		["s", "o", "o", "o", "o", "o", "o", "o", "o", "o", "o", "o", "o", "o", "s"],
		["s", "o", "oE", "o", "o", "o", "oB", "o", "o", "o", "o", "o", "oE", "o", "s"],
		["s", "o", "o", "o", "o", "o", "o", "o", "o", "o", "o", "o", "o", "o", "s"],
		["s", "o", "o", "oX", "o", "o", "o", "o", "o", "o", "o", "oX", "o", "o", "s"],
		["s", "o", "o", "o", "o", "oE", "o", "o", "o", "oE", "o", "o", "o", "o", "s"],
		["s", "o", "oD", "o", "o", "o", "o", "o", "o", "o", "o", "o", "oD", "o", "s"],
		["s", "o", "o", "o", "o", "o", "o", "oD", "o", "o", "o", "o", "o", "o", "s"],
		["s", "o", "o", "o", "o", "o", "o", "o", "o", "o", "o", "o", "o", "o", "s"],
		["s", "s", "s", "s", "s", "s", "s", "s", "s", "s", "s", "s", "s", "s", "s"]
	],
]

# Function to extract tile type and entity information from a map cell string
func parse_map_cell(cell_string: String) -> Dictionary:
	var result = {
		"tile_type": "open_floor",
		"entity_type": null
	}
	
	print("LevelManager: Parsing cell value: '" + cell_string + "'")
	
	if cell_string.length() > 0:
		# First character is the tile type
		var tile_char = cell_string[0]
		if tile_entity_encoding.has(tile_char):
			result.tile_type = tile_entity_encoding[tile_char]
		
		# Second character (if present) is the entity type
		# This includes all entity types: characters, enemies, and now also
		# environmental objects like exploding barrels (X) and destructible walls (D)
		if cell_string.length() > 1:
			var entity_char = cell_string[1]
			if tile_entity_encoding.has(entity_char):
				result.entity_type = tile_entity_encoding[entity_char]
				print("LevelManager: Found entity code '" + entity_char + "' -> " + result.entity_type)
	
	return result

# Helper function to generate a random patrol path for an enemy
func generate_random_patrol_path(map: IsometricMap, center_pos: Vector2i, patrol_length: int = 4) -> Array:
	var patrol_path = [center_pos]
	var current_pos = center_pos
	var attempt_count = 0
	var max_attempts = 30
	
	while patrol_path.size() < patrol_length and attempt_count < max_attempts:
		attempt_count += 1
		
		# Get valid neighbors
		var neighbors = map.get_neighbors(current_pos)
		var valid_neighbors = []
		
		for neighbor in neighbors:
			if neighbor.is_walkable and not neighbor.grid_position in patrol_path:
				valid_neighbors.append(neighbor)
		
		if valid_neighbors.is_empty():
			# If we hit a dead end, try a different branch from an earlier point
			if patrol_path.size() > 1:
				current_pos = patrol_path[patrol_path.size() - 2]
				patrol_path.remove_at(patrol_path.size() - 1)
			continue
		
		# Choose a random valid neighbor
		var next_tile = valid_neighbors[randi() % valid_neighbors.size()]
		current_pos = next_tile.grid_position
		patrol_path.append(current_pos)
	
	# If we couldn't build a complete path, add some random variation to the existing positions
	if patrol_path.size() < patrol_length:
		var existing_positions = patrol_path.duplicate()
		for i in range(patrol_length - patrol_path.size()):
			if existing_positions.is_empty():
				break
			var random_pos = existing_positions[randi() % existing_positions.size()]
			patrol_path.append(random_pos)
	
	return patrol_path

func _ready():
	# Register initial level scene
	level_scene = load("res://Level/map.tscn")
	
	# Initialize the first level
	initialize_level(0)

# Initialize a level at the specified index
func initialize_level(level_index: int) -> IsometricMap:
	if level_index >= level_maps.size():
		push_error("Level index out of bounds: " + str(level_index) + " There are no available maps")
		return null
		
	if level_nodes.has(level_index):
		return level_nodes[level_index]  # Level already initialized
		
	print("LevelManager: Initializing level " + str(level_index) + " with map size " + 
		str(level_maps[level_index].size()) + "x" + str(level_maps[level_index][0].size()))
	
	# Check for entities in the map before instantiating
	var entity_count = 0
	for y in range(level_maps[level_index].size()):
		for x in range(level_maps[level_index][y].size()):
			var cell = level_maps[level_index][y][x]
			if cell.length() > 1:
				var entity_char = cell[1]
				if tile_entity_encoding.has(entity_char):
					entity_count += 1
					print("LevelManager: Found entity " + tile_entity_encoding[entity_char] + 
						" at position " + str(Vector2i(x, y)) + " in map data")
	
	print("LevelManager: Map data contains " + str(entity_count) + " entities to spawn")
	
	# Instance the level
	var level_instance = level_scene.instantiate() as IsometricMap
	level_instance.set_map_array(level_maps[level_index])
	
	# Position the level based on its depth
	level_instance.position.y = level_index * level_vertical_offset
	level_instance.level_index = level_index
	
	# Add to scene tree
	add_child(level_instance)
	level_instance.z_index = -level_index
	
	# Set initial modulation and visibility based on level index
	if level_index > 0:  # Only the first level starts visible
		level_instance.modulate = Color(0.7, 0.7, 0.7, 0.0)  # Fully transparent
		level_instance.visible = false  # Completely hidden
		level_instance.set_meta("is_visible_to_player", false)
	else:
		# First level is fully visible
		level_instance.modulate = Color(1.0, 1.0, 1.0, 1.0)
		level_instance.visible = true
		level_instance.set_meta("is_visible_to_player", true)
	
	# Track this level
	level_nodes[level_index] = level_instance
	active_levels.append(level_instance)
	
	# Update deepest level if needed
	if level_index > current_deepest_level:
		current_deepest_level = level_index
		
	print("LevelManager: Level " + str(level_index) + " initialized with visibility: " + str(level_instance.visible))
	return level_instance

# Check if a tile position in a level has a valid tile below it for drilling
func has_valid_tile_below(level_index: int, grid_pos: Vector2i) -> bool:
	if level_index >= level_nodes.size() - 1:
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
		
		# Update the Global singleton with the new deepest layer if applicable
		Global.update_deepest_layer(to_level_index)
		
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
