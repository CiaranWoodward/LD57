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
			var tile = create_tile(grid_pos)
			tiles[grid_pos] = tile
			created_tiles += 1
			
			if created_tiles % 25 == 0 or created_tiles == total_tiles:
				print("IsometricMap: Created " + str(created_tiles) + "/" + str(total_tiles) + " tiles")
	
	print("IsometricMap: Map generation complete")

# Creates a single tile at the specified grid position
func create_tile(grid_pos: Vector2i, tile_type: String = "grass") -> IsometricTile:
	print("IsometricMap: Instantiating tile scene for position " + str(grid_pos))
	
	# Instantiate the tile scene
	var tile
	tile = tile_scene.instantiate()
	
	# Set tile properties
	tile.grid_position = grid_pos
	tile.type = tile_type
	
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
	print("IsometricMap: Getting neighbors for tile at " + str(grid_pos))
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
	
	print("IsometricMap: Found " + str(neighbors.size()) + " neighbors")
	return neighbors

# Check if a position is valid on the grid
func is_valid_position(grid_pos: Vector2i) -> bool:
	var valid = grid_pos.x >= 0 and grid_pos.x < map_width and grid_pos.y >= 0 and grid_pos.y < map_height
	if not valid:
		print("IsometricMap: Position " + str(grid_pos) + " is outside of map bounds")
	return valid
	
# Get the path between two tiles (simple implementation, can be expanded later)
func find_path(start_pos: Vector2i, end_pos: Vector2i) -> Array:
	print("IsometricMap: Finding path from " + str(start_pos) + " to " + str(end_pos))
	# This is a placeholder. Consider implementing A* pathfinding here
	# For now, just return a straight line between the points
	var path = []
	
	# Validate positions
	if not is_valid_position(start_pos) or not is_valid_position(end_pos):
		print("IsometricMap: Cannot find path - invalid positions")
		return path
		
	# For now, just add the end position
	# This should be replaced with proper pathfinding
	path.append(end_pos)
	
	print("IsometricMap: Path found with " + str(path.size()) + " steps")
	return path 
