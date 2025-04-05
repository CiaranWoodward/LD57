class_name IsometricMap
extends Node2D

# Map properties
@export var map_width: int = 10
@export var map_height: int = 10
@export var tile_width: int = 128  # Width of tile in pixels
@export var tile_height: int = 64  # Height of tile in pixels
@export var tile_scene: PackedScene  # Reference to the tile scene to instantiate

# References
var tiles: Dictionary = {}  # Dictionary of Vector2i -> IsometricTile
var selected_tile: IsometricTile = null

# Signals
signal tile_selected(tile)

func _ready():
	print("IsometricMap: Initializing")
	
	generate_map()

# Generates the isometric map
func generate_map():
	print("IsometricMap: Generating map " + str(map_width) + "x" + str(map_height))
	# Clear existing tiles if any
	for child in get_children():
		if child is IsometricTile:
			if child.is_connected("tile_clicked", Callable(self, "_on_tile_clicked")):
				child.disconnect("tile_clicked", Callable(self, "_on_tile_clicked"))
			child.queue_free()
	
	tiles.clear()
	print("IsometricMap: Cleared existing tiles")
	
	# Wait for next frame to ensure all old tiles are removed
	await get_tree().process_frame
	
	# Create new tiles
	var total_tiles = map_width * map_height
	var created_tiles = 0
	
	print("IsometricMap: Creating " + str(total_tiles) + " tiles")
	for x in range(map_width):
		for y in range(map_height):
			var grid_pos = Vector2i(x, y)
			
			# Determine tile type - this is a simple example pattern
			var tile_type = "stone_floor"
			
			# Create walls around the perimeter
			if x == 0 or x == map_width - 1 or y == 0 or y == map_height - 1:
				tile_type = "stone_wall"
			
			# Create some additional wall structures for demonstration
			if (x == 3 and y >= 3 and y <= 6) or (y == 3 and x >= 3 and x <= 6):
				tile_type = "stone_wall"
				
			var tile = create_tile(grid_pos, tile_type)
			tiles[grid_pos] = tile
			created_tiles += 1
			
			if created_tiles % 25 == 0 or created_tiles == total_tiles:
				print("IsometricMap: Created " + str(created_tiles) + "/" + str(total_tiles) + " tiles")
	
	print("IsometricMap: Map generation complete")

# Creates a single tile at the specified grid position
func create_tile(grid_pos: Vector2i, tile_type: String = "stone_floor") -> IsometricTile:
	# Instantiate the appropriate tile scene based on the type
	var tile
	
	match tile_type:
		"stone_floor":
			tile = load("res://Level/Tiles/StoneFloorTile.tscn").instantiate()
		"stone_wall":
			tile = load("res://Level/Tiles/StoneWallTile.tscn").instantiate()
		_:
			# Default to stone floor if type not recognized
			print("IsometricMap: Unknown tile type: " + tile_type + ", defaulting to stone_floor")
			tile = load("res://Level/Tiles/StoneFloorTile.tscn").instantiate()
	
	# Set tile properties
	tile.grid_position = grid_pos
	
	# Set the tile's position in the world
	var world_pos = grid_to_world(grid_pos)
	tile.position = world_pos
	
	# Add tile to the map
	add_child(tile)
	
	# Connect tile signals
	if not tile.is_connected("tile_clicked", Callable(self, "_on_tile_clicked")):
		tile.connect("tile_clicked", Callable(self, "_on_tile_clicked"))
	
	return tile

# Convert grid coordinates to isometric world position
func grid_to_world(grid_pos: Vector2i) -> Vector2:
	var world_x = (grid_pos.x - grid_pos.y) * (tile_width / 2)
	var world_y = (grid_pos.x + grid_pos.y) * (tile_height / 2)
	return Vector2(world_x, world_y)

# Convert isometric world position to grid coordinates
func world_to_grid(world_pos: Vector2) -> Vector2i:
	var grid_x = (world_pos.x / (tile_width / 2) + world_pos.y / (tile_height / 2)) / 2
	var grid_y = (world_pos.y / (tile_height / 2) - world_pos.x / (tile_width / 2)) / 2
	return Vector2i(round(grid_x), round(grid_y))

# Handle tile click events
func _on_tile_clicked(tile: IsometricTile):
	print("IsometricMap: Tile clicked at " + str(tile.grid_position))
	if selected_tile:
		print("IsometricMap: Deselecting previous tile at " + str(selected_tile.grid_position))
		selected_tile.highlight(false)
	
	selected_tile = tile
	print("IsometricMap: Highlighting tile at " + str(tile.grid_position))
	tile.highlight(true)
	print("IsometricMap: Emitting tile_selected signal")
	emit_signal("tile_selected", tile)

# Get a tile at a specific grid position
func get_tile(grid_pos: Vector2i) -> IsometricTile:
	if tiles.has(grid_pos):
		return tiles[grid_pos]
	print("IsometricMap: Tile not found at " + str(grid_pos))
	return null

# Get neighbors of a tile (orthogonal only, not diagonal)
func get_neighbors(grid_pos: Vector2i) -> Array:
	var neighbors = []
	var directions = [
		Vector2i(1, 0),  # Right
		Vector2i(-1, 0), # Left
		Vector2i(0, 1),  # Down
		Vector2i(0, -1)  # Up
	]
	
	for dir in directions:
		var neighbor_pos = grid_pos + dir
		if tiles.has(neighbor_pos):
			neighbors.append(tiles[neighbor_pos])
	
	return neighbors

# Check if a position is valid on the grid
func is_valid_position(grid_pos: Vector2i) -> bool:
	var valid = grid_pos.x >= 0 and grid_pos.x < map_width and grid_pos.y >= 0 and grid_pos.y < map_height
	if not valid:
		print("IsometricMap: Position " + str(grid_pos) + " is outside of map bounds")
	return valid
	
# Get the path between two tiles using A* pathfinding
func find_path(start_pos: Vector2i, end_pos: Vector2i) -> Array:
	print("IsometricMap: Finding path from " + str(start_pos) + " to " + str(end_pos))
	
	# Validate positions and check if path is possible
	if not is_valid_path_request(start_pos, end_pos):
		return []
	
	# Use generic A* search with path finding configuration
	var path_result = a_star_search(
		start_pos,
		func(pos): return pos == end_pos,   # Goal test function
		func(from_pos): return heuristic_cost_estimate(from_pos, end_pos),  # Heuristic function
		end_pos  # Pass end_pos for neighbor validation
	)
	
	if path_result.is_empty():
		print("IsometricMap: No path found from " + str(start_pos) + " to " + str(end_pos))
		return []
		
	# Return just the path
	return reconstruct_path(path_result.came_from, end_pos)

# Helper to validate path request
func is_valid_path_request(start_pos: Vector2i, end_pos: Vector2i) -> bool:
	# Validate positions
	if not is_valid_position(start_pos) or not is_valid_position(end_pos):
		print("IsometricMap: Cannot find path - invalid positions")
		return false
	
	# Get tiles for start and end
	var start_tile = get_tile(start_pos)
	var end_tile = get_tile(end_pos)
	
	# Check if the end position is already occupied by a different entity
	if end_tile.is_occupied and end_tile != start_tile:
		print("IsometricMap: Cannot find path - destination is occupied")
		return false
		
	# Check if the end position is unwalkable
	if not end_tile.is_walkable:
		print("IsometricMap: Cannot find path - destination is not walkable")
		return false
		
	return true

# Helper to find the position with lowest f_score in the open set
func find_lowest_f_score_position(open_set: Array, f_score: Dictionary) -> Vector2i:
	return find_lowest_score_position(open_set, f_score)

# Helper to find the position with lowest score in the open set
func find_position_with_lowest_score(open_set: Array, score_dict: Dictionary) -> Vector2i:
	return find_lowest_score_position(open_set, score_dict)

# Generic helper to find position with lowest score in a set
func find_lowest_score_position(open_set: Array, score_dict: Dictionary) -> Vector2i:
	if open_set.is_empty():
		push_error("IsometricMap: Cannot find lowest score position in empty set")
		return Vector2i(0, 0)
		
	var current_pos = open_set[0]
	var current_score = score_dict[current_pos]
	
	for pos in open_set:
		if score_dict[pos] < current_score:
			current_pos = pos
			current_score = score_dict[pos]
			
	return current_pos

# Helper for A* pathfinding - estimate cost
func heuristic_cost_estimate(from_pos: Vector2i, to_pos: Vector2i) -> float:
	# Manhattan distance
	return abs(to_pos.x - from_pos.x) + abs(to_pos.y - from_pos.y)

# Helper for A* pathfinding - reconstruct path
func reconstruct_path(came_from: Dictionary, current_pos: Vector2i) -> Array:
	var total_path = [current_pos]
	
	while current_pos in came_from:
		current_pos = came_from[current_pos]
		total_path.insert(0, current_pos)
	
	# Remove the starting position from the path
	if total_path.size() > 1:
		total_path.remove_at(0)
	
	print("IsometricMap: Path found with " + str(total_path.size()) + " steps")
	return total_path

# Find all tiles that are reachable within a certain number of action points
func find_reachable_tiles(start_pos: Vector2i, max_action_points: int) -> Array:
	print("IsometricMap: Finding all tiles reachable from " + str(start_pos) + 
		" within " + str(max_action_points) + " action points")
		
	# Use generic A* search with reachable tiles configuration
	var search_result = a_star_search(
		start_pos,
		func(_pos): return false,  # No specific goal - explore until action points exhausted
		func(_pos): return 0,      # No heuristic needed for reachable tiles search
		null,                      # No specific end position
		max_action_points          # Limit by action points
	)
	
	# Process all discovered positions to get reachable tiles
	var reachable_tiles = []
	for pos in search_result.g_score.keys():
		# Skip the starting position and positions that exceed action point limit
		if pos == start_pos or search_result.g_score[pos] > max_action_points:
			continue
			
		var tile = get_tile(pos)
		if tile and tile.is_walkable and not tile.is_occupied:
			reachable_tiles.append(tile)
	
	print("IsometricMap: Found " + str(reachable_tiles.size()) + " reachable tiles")
	return reachable_tiles

# Generic A* search algorithm that can be used for both pathfinding and finding reachable tiles
# Returns a dictionary with search results including g_score and came_from
func a_star_search(
	start_pos: Vector2i, 
	is_goal_func: Callable,    # Function that determines if a position is the goal
	heuristic_func: Callable,  # Function that provides the heuristic value
	end_pos = null,            # Optional end position for neighbor validation
	max_cost = INF             # Optional maximum cost limit
) -> Dictionary:
	# Ensure the start position is valid
	if not is_valid_position(start_pos):
		print("IsometricMap: Invalid start position for A* search")
		return {}
		
	# A* data structures
	var open_set = []  # Positions to be evaluated
	var closed_set = [] # Positions already evaluated
	var came_from = {}  # Track the best path
	
	# Cost from start to position
	var g_score = {}
	g_score[start_pos] = 0
	
	# Estimated total cost from start to goal through position
	var f_score = {}
	f_score[start_pos] = heuristic_func.call(start_pos)
	
	# Add start to open set
	open_set.append(start_pos)
	
	while not open_set.is_empty():
		# Find position with lowest f_score in open_set
		var current_pos = find_lowest_score_position(open_set, f_score)
		
		# Check if we've reached the goal
		if is_goal_func.call(current_pos):
			print("IsometricMap: Goal found in A* search")
			return {"came_from": came_from, "g_score": g_score}
		
		# Check if we've reached the cost limit
		if g_score[current_pos] > max_cost:
			# Don't explore this branch further, but keep processing others
			open_set.erase(current_pos)
			closed_set.append(current_pos)
			continue
		
		# Move current from open to closed set
		open_set.erase(current_pos)
		closed_set.append(current_pos)
		
		# Process each neighbor
		for neighbor_pos in get_valid_neighbors(current_pos, end_pos):
			# Skip if already evaluated
			if neighbor_pos in closed_set:
				continue
				
			var neighbor_tile = get_tile(neighbor_pos)
			
			# Calculate tentative g_score (cost from start)
			var tentative_g_score = g_score[current_pos] + neighbor_tile.movement_cost
			
			# Skip if cost exceeds maximum
			if tentative_g_score > max_cost:
				continue
			
			# Add to open set if not already there
			if not neighbor_pos in open_set:
				open_set.append(neighbor_pos)
				f_score[neighbor_pos] = tentative_g_score + heuristic_func.call(neighbor_pos)
			elif tentative_g_score >= g_score.get(neighbor_pos, INF):
				# This is not a better path
				continue
			
			# This is the best path so far
			came_from[neighbor_pos] = current_pos
			g_score[neighbor_pos] = tentative_g_score
			f_score[neighbor_pos] = tentative_g_score + heuristic_func.call(neighbor_pos)
	
	# No goal found but we've explored all reachable positions
	print("IsometricMap: A* search completed without finding goal")
	return {"came_from": came_from, "g_score": g_score}

# Get valid neighbors for pathfinding
func get_valid_neighbors(current_pos: Vector2i, end_pos = null) -> Array:
	var valid_neighbors = []
	
	for neighbor_tile in get_neighbors(current_pos):
		var neighbor_pos = neighbor_tile.grid_position
		
		# Skip if neighbor is not walkable
		if not neighbor_tile.is_walkable:
			continue
			
		# For normal pathfinding (with a destination), check if it's occupied unless it's the destination
		if end_pos != null:
			if neighbor_tile.is_occupied and neighbor_pos != end_pos:
				continue
		# For reachable tiles search, skip occupied tiles
		elif neighbor_tile.is_occupied:
			continue
			
		valid_neighbors.append(neighbor_pos)
	
	return valid_neighbors

# Add entity to the map with Y-sorting
func add_entity(entity: Node2D):
	add_child(entity)  # Fallback 
