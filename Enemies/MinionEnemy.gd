class_name MinionEnemy
extends EnemyEntity

# AOE attack parameters
var aoe_attack_damage: int = 2
var aoe_attack_range: int = 4  # Maximum range of the attack
var aoe_radius: int = 1  # Creates a 3x3 grid (center + 1 in each direction)
var optimal_distance: int = 3  # Minion will try to maintain this distance from players
var attack_cooldown: int = 0  # Turns since last attack
var cardinal_directions = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

func _init():
	entity_name = "Minion"
	entity_id = "minion_" + str(randi())

func _ready():
	super._ready()
	enemy_type = EnemyType.MINION
	
	# Additional minion-specific configuration
	move_speed = 1.2
	detection_range = 8
	aggression_level = 0.3
	max_health = 5
	current_health = 5
	
	xp_value = 50

# Override process_turn to check for AOE attack opportunities
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
		# Check if we can perform an AOE attack
		if attack_cooldown == 0:
			# Find the best position to target
			var attack_info = find_best_aoe_target(same_level_players)
			if attack_info.has("position") and attack_info.has("direction"):
				print("MinionEnemy: " + entity_name + " performing AOE attack at " + str(attack_info.position) + 
					  " targeting " + str(attack_info.player_count) + " players (and " + 
					  str(attack_info.enemy_count) + " other enemies as collateral)")
				perform_aoe_attack(attack_info.position, attack_info.direction)
				attack_cooldown = 2  # Cooldown due to AOE power
				return false  # No movement after attacking
		
		# If we didn't attack or we're too close, strategically reposition
		var distance_to_closest = grid_position.distance_to(closest_player.grid_position)
		
		# If too close to the player, try to retreat
		if distance_to_closest < optimal_distance:
			retreat_from_player(closest_player)
			return is_moving
	
	# If we didn't attack or reposition, use standard enemy behavior
	return super.process_turn(player_entities)

# Find the best position for an AOE attack
func find_best_aoe_target(player_entities: Array) -> Dictionary:
	var result = {}
	var best_score = -1  # Start with negative score so any valid target is better
	
	for direction in cardinal_directions:
		var current_pos = grid_position
		
		# Check each position in the direction up to max range
		for i in range(aoe_attack_range):
			current_pos += direction
			
			# Get the tile at this position
			var current_tile = isometric_map.get_tile(current_pos)
			
			# If there's no tile or it's a wall, stop checking this direction
			if not current_tile or not current_tile.is_walkable:
				break
			
			# Calculate score for this position
			var target_info = calculate_aoe_target_score(current_pos)
			
			# Only consider positions that would hit at least one player
			if target_info.player_count > 0:
				# Score = player count * 10 + enemy count (heavily prioritize hitting players)
				var score = (target_info.player_count * 10) + target_info.enemy_count
				
				# If this is better than our current best, update it
				if score > best_score:
					best_score = score
					result = {
						"position": current_pos,
						"direction": direction,
						"player_count": target_info.player_count,
						"enemy_count": target_info.enemy_count,
						"score": score
					}
	
	return result

# Calculate targeting score for a position - prioritizing players but counting all hits
func calculate_aoe_target_score(center_pos: Vector2i) -> Dictionary:
	var player_count = 0
	var enemy_count = 0
	
	# Check the 3x3 grid around the center position
	for x in range(-aoe_radius, aoe_radius + 1):
		for y in range(-aoe_radius, aoe_radius + 1):
			var pos = center_pos + Vector2i(x, y)
			var tile = isometric_map.get_tile(pos)
			
			# If the tile exists and has an entity, count it
			if tile and tile.is_occupied and tile.occupying_entity is Entity:
				var entity = tile.occupying_entity
				
				# Don't count ourselves
				if entity != self:
					if entity is PlayerEntity:
						# Skip players that are not visible to enemies (e.g., cloaked Scout)
						if entity.has_method("is_visible_to_enemies") and not entity.is_visible_to_enemies():
							continue
						player_count += 1
					elif entity is EnemyEntity:
						enemy_count += 1
	
	return {
		"player_count": player_count,
		"enemy_count": enemy_count
	}

# Perform an AOE attack at the given position
func perform_aoe_attack(center_pos: Vector2i, attack_direction: Vector2i):
	# Visual indication of attack
	modulate = Color(1.5, 0.5, 0.0, 1.0)  # Briefly flash orange
	
	# Create a timer to reset the color
	var timer = get_tree().create_timer(0.2)
	timer.timeout.connect(func(): modulate = Color(1, 1, 1, 1))
	
	# Face the attack direction
	update_facing_direction(Vector2(attack_direction))
	
	print("MinionEnemy: " + entity_name + " performing AOE attack at " + str(center_pos))
	
	# Get the world position of the center for particles
	var center_tile = isometric_map.get_tile(center_pos)
	if center_tile:
		var world_pos = center_tile.get_entity_position()
		
		# Draw a line between our position and the target
		var line = $AOEPreviewLine
		if line:
			line.visible = true
			line.clear_points()
			# Use local space for the line points
			line.add_point(Vector2(0, 0))  # Line starts at the center of the line's local position
			
			# Calculate the endpoint in local coordinates
			var target_local = world_pos - global_position
			# Adjust for the line's position offset to ensure the line connects properly
			target_local.y += line.position.y
			
			line.add_point(target_local)
			
			# Hide the line after a short delay
			var line_timer = get_tree().create_timer(0.3)
			line_timer.timeout.connect(func(): line.visible = false)
		
		# Fire a projectile to the center position
		var projectile_spawner = $ProjectileSpawner
		if projectile_spawner:
			var from_pos = global_position
			from_pos.y -= 36  # Height adjustment for minion
			
			# Spawn projectile
			var projectile = projectile_spawner.spawn_projectile(from_pos, world_pos)
			if projectile:
				# When projectile hits, trigger the AOE explosion
				projectile.hit_target.connect(func():
					# Play attack particles at the center
					var particles = $AOEAttackParticles
					if particles:
						particles.position = Vector2(0, -36)  # Reset to default position first
						particles.global_position = world_pos
						# Apply height offset to properly center on entities
						particles.position.y -= 35  # Standard entity height offset
						particles.emitting = true
					
					# Apply damage to all entities in the area
					apply_aoe_damage(center_pos)
				)
		else:
			# Fallback if no projectile spawner - use the original implementation
			# Play attack particles at the center
			var particles = $AOEAttackParticles
			if particles:
				particles.position = Vector2(0, -36)  # Reset to default position first
				particles.global_position = world_pos
				# Apply height offset to properly center on entities
				particles.position.y -= 35  # Standard entity height offset
				particles.emitting = true
			
			# Apply damage directly
			apply_aoe_damage(center_pos)

# Helper function to apply AOE damage
func apply_aoe_damage(center_pos: Vector2i):
	var hit_entities = []
	
	# Check the 3x3 grid around the center position
	for x in range(-aoe_radius, aoe_radius + 1):
		for y in range(-aoe_radius, aoe_radius + 1):
			var pos = center_pos + Vector2i(x, y)
			var tile = isometric_map.get_tile(pos)
			
			# If the tile exists and has an entity, damage it
			if tile and tile.is_occupied and tile.occupying_entity is Entity:
				var entity = tile.occupying_entity
				
				# Don't damage ourselves
				if entity != self:
					var is_cloaked_scout = false
					# Check if it's a cloaked scout - we'll still damage them, but note that they're cloaked
					if entity is PlayerEntity and entity.has_method("is_visible_to_enemies") and not entity.is_visible_to_enemies():
						is_cloaked_scout = true
						print("MinionEnemy: AOE attack found cloaked scout at " + str(pos))
						
					hit_entities.append(entity)
					
					# Create particles at each hit entity's position
					var hit_pos = tile.get_entity_position()
					
					# Try to find the isometric map first
					var particle_parent = null
					if isometric_map:
						particle_parent = isometric_map
					else:
						particle_parent = self
						
					var attack_particles = CPUParticles2D.new()
					particle_parent.add_child(attack_particles)
					attack_particles.z_index = 1
					attack_particles.amount = 20
					attack_particles.lifetime = 0.4
					attack_particles.one_shot = true
					attack_particles.explosiveness = 0.8
					attack_particles.direction = Vector2(0, 0)
					attack_particles.spread = 180.0
					attack_particles.initial_velocity_min = 30.0
					attack_particles.initial_velocity_max = 60.0
					attack_particles.scale_amount_min = 2.0
					attack_particles.scale_amount_max = 4.0
					
					# Use special color for cloaked units being revealed
					if is_cloaked_scout:
						attack_particles.color = Color(1.0, 0.8, 0.2, 0.9) # Bright yellow to show cloak breaking
					else:
						attack_particles.color = Color(0.6, 0.8, 1, 0.7)
						
					attack_particles.global_position = hit_pos
					# Adjust height to center on entity
					attack_particles.position.y -= 35  # Standard entity height offset
					attack_particles.emitting = true
					
					# Remove the particles after they finish
					var particle_timer = get_tree().create_timer(0.5)
					particle_timer.timeout.connect(func(): 
						if is_instance_valid(attack_particles):
							attack_particles.queue_free()
					)
	
	# Apply damage to all hit entities
	for entity in hit_entities:
		entity.take_damage(aoe_attack_damage)
		print("MinionEnemy: AOE attack hit " + entity.entity_name + " for " + str(aoe_attack_damage) + " damage")
	
	print("MinionEnemy: AOE attack hit " + str(hit_entities.size()) + " entities")

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
		print("MinionEnemy: " + entity_name + " retreating from player")
	else:
		# If we can't retreat directly, try a different direction
		for direction in cardinal_directions:
			var alt_retreat_pos = grid_position + direction
			var alt_retreat_tile = isometric_map.get_tile(alt_retreat_pos)
			
			if alt_retreat_tile and alt_retreat_tile.is_walkable and not alt_retreat_tile.is_occupied:
				path = [alt_retreat_pos]
				is_moving = true
				print("MinionEnemy: " + entity_name + " using alternative retreat direction")
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
