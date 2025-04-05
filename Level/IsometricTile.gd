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
var is_hovered: bool = false
var is_move_selectable: bool = false
var is_attackable: bool = false

# Highlight colors for different states
var hover_color: Color = Color(1.3, 1.3, 0.8, 1)  # Yellow-ish for hover
var move_color: Color = Color(0.7, 1.3, 0.7, 1)   # Green-ish for movement
var attack_color: Color = Color(1.3, 0.7, 0.7, 1) # Red-ish for attack range

# Signals
signal tile_clicked(tile)

func _ready():
	# Connect the input signal of Area2D
	var area = get_node_or_null("Area2D")
	assert(area != null, "IsometricTile: No Area2D found for tile at " + str(grid_position))
	
	if not area.is_connected("input_event", Callable(self, "_on_area_input_event")):
		area.connect("input_event", Callable(self, "_on_area_input_event"))
		
	# Connect mouse_exited signal
	if not area.is_connected("mouse_exited", Callable(self, "_on_area_mouse_exited")):
		area.connect("mouse_exited", Callable(self, "_on_area_mouse_exited"))

# Highlight tile (used for selection or movement range display)
func highlight(highlight: bool = true):
	is_highlighted = highlight
	print("IsometricTile: " + ("Highlighting" if highlight else "Unhighlighting") + " tile at " + str(grid_position))
	
	var sprite = get_node_or_null("Sprite2D")
	assert(sprite != null, "IsometricTile: Cannot highlight - No Sprite2D found for tile at " + str(grid_position))
	
	if highlight:
		update_highlight_color()
	else:
		sprite.modulate = Color(1, 1, 1, 1)
		# Reset highlight flags when unhighlighting
		is_move_selectable = false
		is_attackable = false

# Set hover state
func set_hovered(hovered: bool):
	is_hovered = hovered
	if is_highlighted or is_hovered:
		update_highlight_color()
	else:
		var sprite = get_node_or_null("Sprite2D")
		if sprite:
			sprite.modulate = Color(1, 1, 1, 1)

# Set movement selectable state
func set_move_selectable(selectable: bool):
	is_move_selectable = selectable
	if selectable:
		is_highlighted = true
		update_highlight_color()
	elif is_highlighted:
		update_highlight_color()

# Set attackable state
func set_attackable(attackable: bool):
	is_attackable = attackable
	if attackable:
		is_highlighted = true
		update_highlight_color()
	elif is_highlighted:
		update_highlight_color()

# Update the highlight color based on the current state
func update_highlight_color():
	var sprite = get_node_or_null("Sprite2D")
	if not sprite:
		return
	
	# Priority: hovered > attackable > move_selectable
	if is_hovered:
		sprite.modulate = hover_color
	elif is_attackable:
		sprite.modulate = attack_color
	elif is_move_selectable:
		sprite.modulate = move_color
	elif is_highlighted:
		sprite.modulate = highlight_color
	else:
		sprite.modulate = Color(1, 1, 1, 1)

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
	elif event is InputEventMouseMotion:
		# Set hovered state when mouse enters
		set_hovered(true)

# Called when mouse exits the tile area
func _on_area_mouse_exited():
	# Remove hover effect when mouse leaves
	set_hovered(false)

# Get the world position for an entity to be placed on this tile
func get_entity_position() -> Vector2:
	# Return the center of the tile with a positive Y offset
	# This makes the entity appear at the bottom of the tile,
	# which looks correct in isometric view
	return position + Vector2(0, 32)
