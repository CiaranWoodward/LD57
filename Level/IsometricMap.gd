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
	generate_map()

# Generates the isometric map
func generate_map():
	# Clear existing tiles if any
	for child in get_children():
		if child is IsometricTile:
			child.queue_free()
	
	tiles.clear()
	
	# Create new tiles
	for x in range(map_width):
		for y in range(map_height):
			var grid_pos = Vector2i(x, y)
			var tile = create_tile(grid_pos)
			tiles[grid_pos] = tile
			
			# Connect the tile's signal
			if tile.has_signal("tile_clicked"):
				tile.connect("tile_clicked", Callable(self, "_on_tile_clicked"))

# Creates a single tile at the specified grid position
func create_tile(grid_pos: Vector2i) -> IsometricTile:
	var tile: IsometricTile
	
	if tile_scene:
		# Instantiate the tile from the scene
		tile = tile_scene.instantiate()
	else:
		# Create a tile from scratch
		tile = IsometricTile.new()
		
		# Create required child nodes if they don't exist
		var sprite = Sprite2D.new()
		sprite.name = "Sprite2D"
		tile.add_child(sprite)
		
		var area = Area2D.new()
		area.name = "Area2D"
		area.monitorable = false
		tile.add_child(area)
		
		var collision = CollisionPolygon2D.new()
		collision.name = "CollisionPolygon2D"
		# Create diamond-shaped polygon
		var points = PackedVector2Array([
			Vector2(0, -tile_height/2),           # Top
			Vector2(tile_width/2, 0),             # Right
			Vector2(0, tile_height/2),            # Bottom
			Vector2(-tile_width/2, 0)             # Left
		])
		collision.polygon = points
		area.add_child(collision)
	
	tile.grid_position = grid_pos
	
	# Set tile dimensions and update collision shape
	tile.tile_width = tile_width
	tile.tile_height = tile_height
	
	# Calculate world position using isometric projection
	var world_pos = grid_to_world(grid_pos)
	tile.position = world_pos
	
	# Add the tile to the scene
	add_child(tile)
	
	# Ensure the Area2D exists and has a CollisionPolygon2D
	ensure_area2d_exists(tile)
	
	return tile

# Ensures the Area2D exists in the tile
func ensure_area2d_exists(tile: IsometricTile):
	# Check if Area2D exists
	var area = tile.get_node_or_null("Area2D")
	if not area:
		# Create Area2D
		area = Area2D.new()
		area.name = "Area2D"
		area.monitorable = false
		tile.add_child(area)
	
	# Check if CollisionPolygon2D exists
	var collision = area.get_node_or_null("CollisionPolygon2D")
	if not collision:
		# Create CollisionPolygon2D
		collision = CollisionPolygon2D.new()
		collision.name = "CollisionPolygon2D"
		# Create diamond-shaped polygon
		var points = PackedVector2Array([
			Vector2(0, -tile_height/2),           # Top
			Vector2(tile_width/2, 0),             # Right
			Vector2(0, tile_height/2),            # Bottom
			Vector2(-tile_width/2, 0)             # Left
		])
		collision.polygon = points
		area.add_child(collision)

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
	if selected_tile:
		selected_tile.highlight_tile(false)
	
	selected_tile = tile
	tile.highlight_tile(true)
	emit_signal("tile_selected", tile)

# Get a tile at a specific grid position
func get_tile(grid_pos: Vector2i) -> IsometricTile:
	if tiles.has(grid_pos):
		return tiles[grid_pos]
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
	return grid_pos.x >= 0 and grid_pos.x < map_width and grid_pos.y >= 0 and grid_pos.y < map_height
	
# Get the path between two tiles (simple implementation, can be expanded later)
func find_path(start_pos: Vector2i, end_pos: Vector2i) -> Array:
	# This is a placeholder. Consider implementing A* pathfinding here
	# For now, just return a straight line between the points
	var path = []
	
	# Validate positions
	if not is_valid_position(start_pos) or not is_valid_position(end_pos):
		return path
		
	# For now, just add the end position
	# This should be replaced with proper pathfinding
	path.append(end_pos)
	
	return path 
