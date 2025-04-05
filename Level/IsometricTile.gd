class_name IsometricTile
extends Node2D

# Tile properties
var grid_position: Vector2i = Vector2i(0, 0)  # Grid coordinates (not world position)
var tile_type: String = "grass"  # Default type
var is_occupied: bool = false
var occupant = null  # Reference to the entity on this tile (player, enemy, object)
var is_walkable: bool = true
var movement_cost: float = 1.0

# Default tile dimensions
var tile_width: int = 128
var tile_height: int = 64

# Highlight properties
@export var highlight_color: Color = Color(1.2, 1.2, 1.2, 1.0)  # Slightly brighter white for highlight
var default_modulate: Color = Color(1.0, 1.0, 1.0, 1.0)

signal tile_clicked(tile)

func _ready():
	# Get references to child nodes
	var sprite = get_node_or_null("Sprite2D")
	if sprite:
		default_modulate = sprite.modulate
	
	# Connect Area2D input events
	var area = get_node_or_null("Area2D")
	if area:
		# Connect to input event
		if not area.is_connected("input_event", Callable(self, "_on_area_input_event")):
			area.connect("input_event", Callable(self, "_on_area_input_event"))

# Called when input event occurs on the Area2D
func _on_area_input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		emit_signal("tile_clicked", self)
		print("Got click!")

func set_tile_texture(texture: Texture2D):
	var sprite = get_node_or_null("Sprite2D")
	if sprite:
		sprite.texture = texture

func highlight_tile(is_highlighted: bool):
	var sprite = get_node_or_null("Sprite2D")
	if not sprite:
		return
		
	if is_highlighted:
		sprite.modulate = highlight_color
	else:
		sprite.modulate = default_modulate

func place_entity(entity) -> bool:
	if is_occupied or not is_walkable:
		return false
	
	is_occupied = true
	occupant = entity
	return true

func remove_entity():
	is_occupied = false
	occupant = null

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
