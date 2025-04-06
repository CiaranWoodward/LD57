class_name HellBombEnemy
extends EnemyEntity

# Bomb-specific properties
var explosion_radius: int = 1  # How many tiles away the explosion affects
var explosion_damage: int = 5  # Damage dealt by explosion
var has_exploded: bool = false
var active_particles: int = 0  # Tracks active particle systems

func _init():
	entity_name = "Hell Bomb"
	entity_id = "hellbomb_" + str(randi())

func _ready():
	super._ready()
	# Since this isn't an existing enum type, we'll use MINION as the base type
	enemy_type = EnemyType.MINION
	
	# Additional bomb-specific configuration
	move_speed = 0.0  # Cannot move
	detection_range = 1  # Only detects players in adjacent tiles
	aggression_level = 1.0  # Always on high alert
	max_health = 6
	current_health = 6
	
	# Connect to the particle systems' finished signals
	var explosion_particles = $ExplosionParticles
	if explosion_particles:
		explosion_particles.finished.connect(_on_particles_finished)
		
	var smoke_particles = $SmokeParticles
	if smoke_particles:
		smoke_particles.finished.connect(_on_particles_finished)

# Override process_turn to implement bomb-specific behavior
func process_turn(player_entities: Array):
	# Reset movement
	is_moving = false
	path = []
	
	# Filter player entities to only include those on the same level
	var same_level_players = []
	for player in player_entities:
		if player.current_level == current_level:
			same_level_players.append(player)
	
	# Check for players in adjacent tiles
	for player in same_level_players:
		var distance = grid_position.distance_to(player.grid_position)
		# If a player is adjacent (Manhattan distance of 1), explode immediately
		if distance <= 1:
			print("HellBombEnemy: Player detected in adjacent tile, exploding!")
			explode()
			return false  # No movement
	
	# Bomb doesn't move or do anything else
	return false

# Override the die function to explode when destroyed
func die():
	if not has_exploded:
		explode()
	
	# Call the parent's die method to set flags and emit signals
	super.die()
	
	# Don't queue_free immediately if particles are still playing
	if active_particles > 0:
		# We'll let the particle finished callbacks handle cleanup
		return
	else:
		# No particles or they've already finished, we can remove immediately
		queue_free()

# Explode function that damages entities in nearby tiles
func explode():
	if has_exploded:
		return
		
	print("HellBombEnemy: " + entity_name + " exploding!")
	has_exploded = true
	
	# Visual effect (flash red before dying)
	modulate = Color(1.5, 0.3, 0.3, 1.0)
	
	# Hide the sprite after a small delay
	var sprite = $Sprite2D
	if sprite:
		var sprite_timer = get_tree().create_timer(0.2)
		sprite_timer.timeout.connect(func(): sprite.visible = false)
	
	# Play explosion particles
	active_particles = 0
	
	var explosion_particles = $ExplosionParticles
	if explosion_particles:
		explosion_particles.emitting = true
		active_particles += 1
		
	var smoke_particles = $SmokeParticles
	if smoke_particles:
		smoke_particles.emitting = true
		active_particles += 1
	
	# Add screen shake if the Camera2D is accessible
	add_screen_shake()
	
	# Get all tiles within explosion radius
	var affected_tiles = []
	
	# Only affect tiles on the same level
	if isometric_map:
		# Add the bomb's own tile first
		var bomb_tile = isometric_map.get_tile(grid_position)
		if bomb_tile:
			affected_tiles.append(bomb_tile)
		
		# Add all neighboring tiles within explosion radius
		var neighbors = get_tiles_in_radius(explosion_radius)
		affected_tiles.append_array(neighbors)
		
		# Damage entities in affected tiles
		for tile in affected_tiles:
			if tile.is_occupied and tile.occupying_entity:
				var entity = tile.occupying_entity
				# Don't damage self twice (we already handled that in die())
				if entity != self:
					print("HellBombEnemy: Explosion damaging " + entity.entity_name)
					entity.take_damage(explosion_damage)
	
	# Kill self after exploding but leave our Node2D alive until particles finish
	if not is_dead:
		current_health = 0
		
		# Instead of calling die() immediately, create a small delay
		# to allow particles to play first
		var timer = get_tree().create_timer(0.2)
		timer.timeout.connect(func(): call_deferred("die"))

# Helper function to get all tiles within a certain radius
func get_tiles_in_radius(radius: int) -> Array:
	var result = []
	
	if not isometric_map:
		return result
		
	# Check all tiles in a square around the bomb
	for x in range(-radius, radius + 1):
		for y in range(-radius, radius + 1):
			# Skip the center tile (bomb's position) - we already added it
			if x == 0 and y == 0:
				continue
				
			# Use Manhattan distance for explosion radius
			if abs(x) + abs(y) <= radius:
				var pos = grid_position + Vector2i(x, y)
				var tile = isometric_map.get_tile(pos)
				if tile:
					result.append(tile)
	
	return result

# Override pursue_target to do nothing (bombs don't move)
func pursue_target():
	# Do nothing - bombs don't move
	pass

# Override follow_patrol_path to do nothing (bombs don't patrol)
func follow_patrol_path():
	# Do nothing - bombs don't move
	pass 

# Called when a particle system finishes
func _on_particles_finished():
	active_particles -= 1
	
	# If all particle systems are done and we're dead, free the entity
	if active_particles <= 0 and is_dead and is_instance_valid(self):
		queue_free()

# Add screen shake effect for more impact
func add_screen_shake():
	# Try to find the camera in different ways
	var camera = get_viewport().get_camera_2d()
	
	# If we can find a camera, apply screen shake
	if camera and camera.has_method("screen_shake_add_trauma"):
		# Some cameras implement a trauma system for more natural shake
		camera.screen_shake_add_trauma(2)
		
