class_name EliteEnemy
extends EnemyEntity

# Ranged attack parameters
var ranged_attack_damage: int = 3
var ranged_attack_range: int = 4  # Maximum range of the attack
var optimal_distance: int = 3  # Elite will try to maintain this distance from players
var attack_cooldown: int = 0  # Turns since last attack
var cardinal_directions = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

func _init():
	entity_name = "Elite"
	entity_id = "elite_" + str(randi())

func _ready():
	super._ready()
	enemy_type = EnemyType.ELITE
	
	# Additional elite-specific configuration
	move_speed = 1.0
	detection_range = 8
	aggression_level = 0.7
	max_health = 12
	current_health = 12
	
	xp_value = 5

# Override process_turn to check for ranged attack opportunities
func process_turn(player_entities: Array):
	# Reset movement
	is_moving = false
	path = []
	
	# Decrease attack cooldown if it's active
	if attack_cooldown > 0:
		attack_cooldown -= 1
	
	# Filter player entities to only include those on the same level
	var same_level_players = []
	for player in player_entities:
		if player.current_level == current_level:
			same_level_players.append(player)
	
	# Find closest player for distance calculations
	var closest_player = find_closest_player(same_level_players)
	
	if closest_player:
		# Check if we can attack any player
		if attack_cooldown == 0:
			# Try to find a player in a cardinal direction to attack
			var target_player = find_player_in_cardinal_direction(same_level_players)
			if target_player:
				print("EliteEnemy: " + entity_name + " performing ranged attack on " + target_player.entity_name)
				perform_ranged_attack(target_player)
				attack_cooldown = 2  # Set cooldown to prevent constant attacks
				return false  # No movement after attacking
		
		# If we didn't attack or we're too close, strategically reposition
		var distance_to_closest = grid_position.distance_to(closest_player.grid_position)
		
		# If too close to the player, try to retreat
		if distance_to_closest < optimal_distance:
			retreat_from_player(closest_player)
			return is_moving
	
	# If we didn't attack or reposition, use standard enemy behavior
	return super.process_turn(player_entities)

# Find a player that is in a straight line (cardinal direction) from the elite
func find_player_in_cardinal_direction(player_entities: Array) -> Entity:
	for direction in cardinal_directions:
		var current_pos = grid_position
		
		# Check each position in the direction up to max range
		for _i in range(ranged_attack_range):
			current_pos += direction
			
			# Get the tile at this position
			var current_tile = isometric_map.get_tile(current_pos)
			
			# If there's no tile or it's a wall, stop checking this direction
			if not current_tile or not current_tile.is_walkable:
				break
			
			# If there's a player on this tile, we can attack them
			if current_tile.is_occupied and current_tile.occupying_entity is PlayerEntity:
				var player = current_tile.occupying_entity
				
				# Skip players that are not visible to enemies (e.g., cloaked Scout)
				if player.has_method("is_visible_to_enemies") and not player.is_visible_to_enemies():
					break
					
				print("EliteEnemy: Found player " + player.entity_name + " in direction " + str(direction))
				return player
	
	return null

# Perform a ranged attack on the target entity
func perform_ranged_attack(target_entity: Entity):
	if target_entity and !target_entity.is_dead:
		# Visual indication of attack (could be expanded with animations)
		modulate = Color(0.3, 0.3, 1.5, 1.0)  # Briefly flash blue
		
		# Create a timer to reset the color
		var timer = get_tree().create_timer(0.2)
		timer.timeout.connect(func(): modulate = Color(1, 1, 1, 1))
		
		# Face the target
		var direction = target_entity.grid_position - grid_position
		update_facing_direction(Vector2(direction))
		
		# Use projectile spawner if available
		var projectile_spawner = $ProjectileSpawner
		if projectile_spawner:
			# Calculate spawn position (from Elite)
			var from_pos = global_position
			from_pos.y -= 65  # Height adjustment for elite
			
			# Calculate target position (at target entity)
			var to_pos = target_entity.global_position
			to_pos.y -= 35  # Standard entity height offset
			
			# Spawn the projectile
			var projectile = projectile_spawner.spawn_projectile(from_pos, to_pos)
			if projectile:
				# When projectile hits, apply damage to the target
				projectile.hit_target.connect(func():
					if is_instance_valid(target_entity) and !target_entity.is_dead:
						# Deal damage to the target
						target_entity.take_damage(ranged_attack_damage)
						
						print("EliteEnemy: " + entity_name + " dealt " + str(ranged_attack_damage) + " ranged damage to " + target_entity.entity_name)
						
						# Create hit effect at target
						create_hit_effect(target_entity)
				)
				return
		
		# Fallback if no projectile spawner
		target_entity.take_damage(ranged_attack_damage)
		print("EliteEnemy: " + entity_name + " dealt " + str(ranged_attack_damage) + " ranged damage to " + target_entity.entity_name)

# Create hit effect at the target position
func create_hit_effect(target_entity: Entity):
	if is_instance_valid(target_entity):
		# Get parent for the particles (prefer isometric_map)
		var particle_parent = null
		if isometric_map:
			particle_parent = isometric_map
		else:
			particle_parent = self
		
		# Create hit particles
		var hit_particles = CPUParticles2D.new()
		particle_parent.add_child(hit_particles)
		
		# Configure hit particles
		hit_particles.z_index = 1
		hit_particles.amount = 25
		hit_particles.lifetime = 0.4
		hit_particles.one_shot = true
		hit_particles.explosiveness = 0.9
		hit_particles.direction = Vector2(0, 0)
		hit_particles.spread = 180.0
		hit_particles.gravity = Vector2.ZERO
		hit_particles.initial_velocity_min = 40.0
		hit_particles.initial_velocity_max = 80.0
		hit_particles.scale_amount_min = 3.0
		hit_particles.scale_amount_max = 5.0
		hit_particles.color = Color(0.408, 0.407, 0, 0.8)
		
		# Position particles at the target (use world coordinates)
		var world_pos = target_entity.global_position
		hit_particles.global_position = world_pos
		hit_particles.position.y -= 35  # Height offset to center on entity
		hit_particles.emitting = true
		
		# Remove particles after they finish
		var timer = get_tree().create_timer(0.5)
		timer.timeout.connect(func(): 
			if is_instance_valid(hit_particles):
				hit_particles.queue_free()
		)

# Retreat from player to maintain optimal distance
func retreat_from_player(player: Entity):
	# Calculate direction away from player
	var retreat_direction = grid_position - player.grid_position
	
	# Normalize to cardinal direction
	if abs(retreat_direction.x) > abs(retreat_direction.y):
		retreat_direction.y = 0
		retreat_direction.x = sign(retreat_direction.x)
	else:
		retreat_direction.x = 0
		retreat_direction.y = sign(retreat_direction.y)
	
	# Check if retreat position is valid
	var retreat_pos = grid_position + retreat_direction
	var retreat_tile = isometric_map.get_tile(retreat_pos)
	
	# If retreat position is valid, move there
	if retreat_tile and retreat_tile.is_walkable and not retreat_tile.is_occupied:
		path = [retreat_pos]
		is_moving = true
		print("EliteEnemy: " + entity_name + " retreating from player")
	else:
		# If we can't retreat directly, try a different direction
		for direction in cardinal_directions:
			var alt_retreat_pos = grid_position + direction
			var alt_retreat_tile = isometric_map.get_tile(alt_retreat_pos)
			
			if alt_retreat_tile and alt_retreat_tile.is_walkable and not alt_retreat_tile.is_occupied:
				path = [alt_retreat_pos]
				is_moving = true
				print("EliteEnemy: " + entity_name + " using alternative retreat direction")
				break

# Override pursue_target to maintain optimal distance
func pursue_target():
	if not target_entity:
		return
		
	var distance = grid_position.distance_to(target_entity.grid_position)
	
	# If already at optimal distance, don't move
	if round(distance) == optimal_distance:
		is_moving = false
		path = []
		return
	
	# If too far, move closer but not too close
	if distance > optimal_distance:
		super.pursue_target()
	else:
		# Too close, try to retreat
		retreat_from_player(target_entity) 
