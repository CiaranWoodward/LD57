class_name ProjectileSpawner
extends Node2D

signal projectile_hit(target_position)

@export var projectile_scene: PackedScene
@export var projectile_speed: float = 400.0
@export var projectile_color: Color = Color(1.0, 0.7, 0.2, 0.8)
@export var spawn_offset: Vector2 = Vector2(0, -35)  # Default offset to spawn from entity's center

func _ready():
	# Load default projectile scene if none provided
	if projectile_scene == null:
		projectile_scene = load("res://scenes/Projectile.tscn")

func spawn_projectile(from_position: Vector2, to_position: Vector2) -> Projectile:
	# Instantiate projectile scene
	var projectile = projectile_scene.instantiate() as Projectile
	if not projectile:
		push_error("ProjectileSpawner: Failed to instantiate projectile!")
		return null
	
	# Get the parent entity's isometric map to add the projectile to
	var parent_entity = get_parent()
	var isometric_map = null
	
	# Try to find the isometric map reference from the parent entity
	if parent_entity and parent_entity.has_method("get_isometric_map"):
		isometric_map = parent_entity.get_isometric_map()
	elif parent_entity and parent_entity.get("isometric_map"):
		isometric_map = parent_entity.isometric_map
	
	# Add the projectile to the isometric map if found, otherwise add to current scene
	if isometric_map:
		isometric_map.add_child(projectile)
		print("ProjectileSpawner: Added projectile to isometric map")
	else:
		get_tree().current_scene.add_child(projectile)
		push_warning("ProjectileSpawner: Couldn't find isometric map, added projectile to current scene")
	
	# Set projectile properties
	projectile.speed = projectile_speed
	projectile.projectile_color = projectile_color
	
	# Initialize projectile with start and end positions
	projectile.initialize(from_position, to_position, projectile_speed)
	
	# Connect signal
	projectile.hit_target.connect(_on_projectile_hit.bind(to_position))
	
	return projectile

func spawn_projectile_from_entity(entity: Node2D, to_position: Vector2) -> Projectile:
	# Calculate spawn position
	var spawn_position = entity.global_position + spawn_offset
	
	# Spawn projectile
	return spawn_projectile(spawn_position, to_position)

func spawn_projectile_between_tiles(from_tile, to_tile) -> Projectile:
	if not from_tile or not to_tile:
		push_warning("ProjectileSpawner: Invalid tiles provided")
		return null
	
	# Get world positions for tiles
	var from_pos = from_tile.get_entity_position()
	var to_pos = to_tile.get_entity_position()
	
	# Apply height adjustment for better visuals
	from_pos.y -= 35
	to_pos.y -= 35
	
	# Spawn projectile between the tiles
	return spawn_projectile(from_pos, to_pos)

func _on_projectile_hit(target_position):
	emit_signal("projectile_hit", target_position) 