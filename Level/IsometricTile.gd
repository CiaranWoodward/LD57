class_name IsometricTile
extends Node2D

# Tile properties
var grid_position: Vector2i = Vector2i(0, 0)
var type: String = "grass"
var is_walkable: bool = true
var is_occupied: bool = false
var movement_cost: float = 1.0
var occupying_entity = null  # Entity currently occupying this tile

# Visual properties
var highlight_color: Color = Color(1.3, 1.3, 0.8, 1)  # Yellow-ish highlight
var is_highlighted: bool = false

# Signals
signal tile_clicked(tile)

func _ready():
	# Connect the input signal of Area2D
	var area = get_node_or_null("Area2D")
	if area:
		if not area.is_connected("input_event", Callable(self, "_on_area_input_event")):
			area.connect("input_event", Callable(self, "_on_area_input_event"))
	else:
		push_warning("IsometricTile: No Area2D found for tile at " + str(grid_position))

# Set up tile texture
func set_texture(texture: Texture2D):

	var sprite = get_node_or_null("Sprite2D")
	if sprite:
#		sprite.texture = texture
		pass
	else:
		push_warning("IsometricTile: No Sprite2D found for tile at " + str(grid_position))

# Highlight tile (used for selection or movement range display)
func highlight(highlight: bool = true):
	is_highlighted = highlight
	print("IsometricTile: " + ("Highlighting" if highlight else "Unhighlighting") + " tile at " + str(grid_position))
	
	var sprite = get_node_or_null("Sprite2D")
	if sprite:
		if highlight:
			sprite.modulate = highlight_color
		else:
			sprite.modulate = Color(1, 1, 1, 1)
	else:
		push_warning("IsometricTile: Cannot highlight - No Sprite2D found for tile at " + str(grid_position))

# Place an entity on this tile
func place_entity(entity: Entity):
	print("IsometricTile: Placing entity " + entity.entity_name + " on tile at " + str(grid_position))
	# Mark tile as occupied
	is_occupied = true
	occupying_entity = entity
	
	# Set the entity's position to match the tile's position
	entity.current_tile = self
	entity.grid_position = grid_position
	
	# This doesn't move the entity's visual Node2D position - that's handled by the entity

# Remove an entity from this tile
func remove_entity():
	if occupying_entity:
		print("IsometricTile: Removing entity " + occupying_entity.entity_name + " from tile at " + str(grid_position))
	else:
		print("IsometricTile: Removing null entity from tile at " + str(grid_position))
	
	# Mark tile as unoccupied
	is_occupied = false
	occupying_entity = null

# Handle mouse input events
func _on_area_input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			print("IsometricTile: Left mouse button pressed on tile at " + str(grid_position))
			emit_signal("tile_clicked", self)

# Get the world position for an entity to be placed on this tile
func get_entity_position() -> Vector2:
	# Return the center of the tile
	return position

# Convert grid coordinates to isometric world position
func grid_to_world(grid_pos: Vector2i, tile_width: int, tile_height: int) -> Vector2:
	var world_x = (grid_pos.x - grid_pos.y) * (tile_width / 2)
	var world_y = (grid_pos.x + grid_pos.y) * (tile_height / 2)
	return Vector2(world_x, world_y)

# Convert isometric world position to grid coordinates
func world_to_grid(world_pos: Vector2, tile_width: int, tile_height: int) -> Vector2i:
	var grid_x = (world_pos.x / (tile_width / 2) + world_pos.y / (tile_height / 2)) / 2
	var grid_y = (world_pos.y / (tile_height / 2) - world_pos.x / (tile_width / 2)) / 2
	return Vector2i(round(grid_x), round(grid_y)) 
