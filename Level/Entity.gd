class_name Entity
extends Node2D

# Entity properties
var entity_id: String = ""
var entity_name: String = ""
var current_tile: IsometricTile = null
var grid_position: Vector2i = Vector2i(0, 0)
var facing_direction: Vector2i = Vector2i(1, 0)  # Default facing right

# Map reference
var isometric_map: IsometricMap = null

# Movement properties
var is_moving: bool = false
var move_speed: float = 1.0  # Tiles per second
var path: Array = []  # Path to follow (array of grid positions)

# Visual components - references to scene nodes
@onready var sprite: Sprite2D = $Sprite2D
@onready var click_area: Area2D = $Area2D

# Entity dimensions (for collision)
var entity_width: int = 64
var entity_height: int = 64

# Signals
signal movement_completed()
signal entity_selected(entity)

func _ready():
	# Connect the input event signal
	if click_area:
		click_area.input_event.connect(_on_area_input_event)
	
	# Update collision shape radius based on entity dimensions
	update_collision_shape()

# Update the collision shape based on entity dimensions
func update_collision_shape():
	if not click_area:
		push_error("No Area2D found in Entity")
		return
		
	# Check for existing CollisionShape2D
	var collision_shape = click_area.get_node_or_null("CollisionShape2D")
	
	# If no CollisionShape2D exists, create one
	if not collision_shape:
		collision_shape = CollisionShape2D.new()
		collision_shape.name = "CollisionShape2D"
		
		# Create a circle shape for the entity
		var circle_shape = CircleShape2D.new()
		circle_shape.radius = min(entity_width, entity_height) / 3
		collision_shape.shape = circle_shape
		
		click_area.add_child(collision_shape)
		# Make sure the owner is set so it's saved with the scene
		if get_tree().edited_scene_root:
			collision_shape.owner = get_tree().edited_scene_root
		else:
			collision_shape.owner = self
	elif collision_shape.shape is CircleShape2D:
		# Update existing circle shape
		var circle_shape = collision_shape.shape as CircleShape2D
		circle_shape.radius = min(entity_width, entity_height) / 3

# Called when input event occurs on the Area2D
func _on_area_input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		emit_signal("entity_selected", self)

func _process(delta):
	if is_moving and path.size() > 0:
		move_along_path(delta)

func set_texture(texture: Texture2D):
	if not sprite:
		return
		
	sprite.texture = texture
	
	# Adjust entity dimensions based on texture size
	if texture:
		entity_width = texture.get_width()
		entity_height = texture.get_height()
		
		# Update the collision shape
		update_collision_shape()

# Place the entity on a specific tile
func place_on_tile(tile: IsometricTile) -> bool:
	if tile == null or not tile.is_walkable or tile.is_occupied:
		return false
		
	# If entity was on another tile, clear it
	if current_tile != null:
		current_tile.remove_entity()
		
	# Place on new tile
	if tile.place_entity(self):
		current_tile = tile
		grid_position = tile.grid_position
		position = tile.position
		return true
		
	return false

# Set a path for the entity to follow
func set_path(new_path: Array):
	path = new_path
	is_moving = path.size() > 0

# Move along the current path
func move_along_path(delta: float):
	if path.size() == 0:
		is_moving = false
		emit_signal("movement_completed")
		return
		
	var next_position = path[0]
	
	# Use isometric_map reference instead of get_parent()
	if not isometric_map:
		# Try to find the map if not set
		isometric_map = get_node("/root/Main/Game/Map")
		if not isometric_map:
			push_error("No isometric map found in Entity.move_along_path")
			is_moving = false
			path.clear()
			emit_signal("movement_completed")
			return
	
	var target_tile = isometric_map.get_tile(next_position)
	
	if target_tile == null or not target_tile.is_walkable or (target_tile.is_occupied and target_tile != current_tile):
		# Path is blocked, stop moving
		is_moving = false
		path.clear()
		emit_signal("movement_completed")
		return
		
	# Calculate movement direction
	var target_world_pos = target_tile.position
	var direction = (target_world_pos - position).normalized()
	var distance_to_move = move_speed * delta * 100  # Adjust as needed
	
	if position.distance_to(target_world_pos) <= distance_to_move:
		# Reached the next tile
		position = target_world_pos
		
		# Update entity's position on the grid
		if place_on_tile(target_tile):
			# Remove this step from the path
			path.remove_at(0)
			
			# Check if we've reached the end of the path
			if path.size() == 0:
				is_moving = false
				emit_signal("movement_completed")
	else:
		# Move towards the next tile
		position += direction * distance_to_move
		
		# Update the facing direction
		if abs(direction.x) > abs(direction.y):
			facing_direction = Vector2i(sign(direction.x), 0)
		else:
			facing_direction = Vector2i(0, sign(direction.y)) 
