class_name WizardPlayer
extends PlayerEntity

var fireball_range: int = 5  # Maximum range for fireball ability
var aoe_radius: int = 1      # Radius for area of effect (1 = 3x3 grid)
var hover_target: IsometricTile = null  # Track currently hovered target for AOE preview
var animation_tree: AnimationTree
var animation_state_machine: AnimationNodeStateMachinePlayback

func configure_player():
	entity_name = "Wizard"
	max_action_points = 4  # Heavy has more action points for abilities
	action_points = max_action_points
	max_movement_points = 2  # But limited movement
	movement_points = max_movement_points
	move_speed = 0.7
	abilities = ["drill", "fireball"]
	max_health = 15
	current_health = 15
	
	# Setup animation tree
	animation_tree = $Sprite2D/AnimationTree
	animation_tree.active = true
	animation_state_machine = animation_tree["parameters/playback"]

func get_ability_cost(ability_name: String) -> int:
	match ability_name:
		"fireball": return 3  # Fireball costs more than most abilities
		_: return super.get_ability_cost(ability_name)

# Override to provide specific descriptions for Wizard abilities
func get_ability_description(ability_name: String) -> String:
	var cost = get_ability_cost(ability_name)
	match ability_name:
		"fireball": 
			return "Fireball: Ranged AOE, up to " + str(fireball_range) + " tiles (Cost: " + str(cost) + " AP)"
		_: 
			return super.get_ability_description(ability_name)

func execute_ability(ability_name: String, target) -> bool:
	if super.execute_ability(ability_name, target):
		return true
		
	match ability_name:
		"fireball":
			if target is IsometricTile:
				# Check if player has enough action points
				var cost = get_ability_cost("fireball")
				if action_points < cost:
					print("WizardPlayer: " + entity_name + " - Not enough action points for fireball")
					return false
				
				# Play cast animation
				animation_state_machine.travel("Cast")
				
				# Get target position and calculate direction
				var target_pos = target.grid_position
				var direction = target_pos - grid_position
				
				# Normalize direction to a unit vector
				if direction.x != 0: direction.x = sign(direction.x)
				if direction.y != 0: direction.y = sign(direction.y)
				
				print("WizardPlayer: " + entity_name + " firing fireball in direction " + str(direction))
				
				# Calculate the line of tiles in the direction, up to max range or until we hit a wall
				var current_pos = grid_position
				var distance = 0
				var impact_pos = null
				
				# We'll stop if we hit a wall or if we go beyond the maximum range
				while distance < fireball_range:
					# Move one step in the direction
					current_pos += Vector2i(direction)
					distance += 1
					
					# Get the tile at this position
					var current_tile = isometric_map.get_tile(current_pos)
					
					# If there's no tile or it's a wall, we impact at the last valid position
					if not current_tile or not current_tile.is_walkable:
						print("WizardPlayer: fireball hit a wall at " + str(current_pos))
						break
					
					# If this is the target tile, this is our impact position
					if current_tile.grid_position == target_pos:
						impact_pos = target_pos
						break
				
				# If we didn't find an impact position, the ability failed
				if not impact_pos:
					print("WizardPlayer: fireball failed - no valid impact position")
					return false
				
				# Fire a projectile to the impact position
				var projectile_spawner = $ProjectileSpawner
				if projectile_spawner and isometric_map:
					# Get the current tile and target tile
					var source_tile = isometric_map.get_tile(grid_position)
					var target_tile = isometric_map.get_tile(impact_pos)
					
					if source_tile and target_tile:
						# Spawn projectile between tiles
						var projectile = projectile_spawner.spawn_projectile_between_tiles(source_tile, target_tile)
						
						if projectile:
							# When the projectile reaches its target, create the explosion effect
							projectile.hit_target.connect(func():
								# Execute the explosion effect
								apply_fireball_explosion(impact_pos)
							)
							
							return true
				
				# Fallback if no projectile spawner - apply the damage directly
				apply_fireball_explosion(impact_pos)
				
				return true
			
			print("WizardPlayer: " + entity_name + " fireball failed - invalid target")
			return false
			
		_:
			return false

# Helper function to apply fireball explosion and damage
func apply_fireball_explosion(impact_pos: Vector2i):
	# Calculate the area of effect
	var affected_entities = []
	
	# Create explosion particles at the impact position
	var impact_tile = isometric_map.get_tile(impact_pos)
	if impact_tile:
		var impact_world_pos = impact_tile.get_entity_position()
		
		# Get parent for the particles (prefer isometric_map)
		var particle_parent = null
		if isometric_map:
			particle_parent = isometric_map
		else:
			particle_parent = self
		
		# Create explosion particles
		var explosion = CPUParticles2D.new()
		particle_parent.add_child(explosion)
		
		# Configure explosion particles
		explosion.z_index = 1
		explosion.amount = 60
		explosion.lifetime = 0.6
		explosion.one_shot = true
		explosion.explosiveness = 0.9
		explosion.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
		explosion.emission_sphere_radius = 10.0
		explosion.direction = Vector2(0, 0)
		explosion.spread = 180.0
		explosion.gravity = Vector2(0, 0)
		explosion.initial_velocity_min = 80.0
		explosion.initial_velocity_max = 150.0
		explosion.scale_amount_min = 4.0
		explosion.scale_amount_max = 8.0
		explosion.color = Color(1, 0.3, 0.1, 0.8)
		
		# Position explosion at impact point
		explosion.global_position = impact_world_pos
		explosion.position.y -= 35  # Height adjustment
		explosion.emitting = true
		
		# Remove explosion particles after they finish
		var timer = get_tree().create_timer(0.8)
		timer.timeout.connect(func(): 
			if is_instance_valid(explosion):
				explosion.queue_free()
		)
	
	# Loop through all tiles within radius of the impact position
	for x in range(-aoe_radius, aoe_radius + 1):
		for y in range(-aoe_radius, aoe_radius + 1):
			var aoe_pos = impact_pos + Vector2i(x, y)
			var aoe_tile = isometric_map.get_tile(aoe_pos)
			
			# If the tile exists and has an entity, damage it
			if aoe_tile and aoe_tile.is_occupied and aoe_tile.occupying_entity is Entity:
				var entity = aoe_tile.occupying_entity
				print("WizardPlayer: fireball hit entity " + entity.entity_name + " at " + str(aoe_pos))
				
				# Don't damage self (in case wizard is in the AOE)
				if entity != self:
					# Add to the list of affected entities
					affected_entities.append(entity)
					
					# Create hit particles at entity position
					var hit_pos = aoe_tile.get_entity_position()
					create_hit_effect(entity, hit_pos)
	
	# Apply damage to all affected entities (3 points of damage)
	for entity in affected_entities:
		entity.take_damage(3)
	
	print("WizardPlayer: fireball affected " + str(affected_entities.size()) + " entities")

# Create hit effect at the target position
func create_hit_effect(target_entity: Entity, position: Vector2):
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
		hit_particles.amount = 20
		hit_particles.lifetime = 0.4
		hit_particles.one_shot = true
		hit_particles.explosiveness = 0.9
		hit_particles.direction = Vector2(0, 0)
		hit_particles.spread = 180.0
		hit_particles.gravity = Vector2.ZERO
		hit_particles.initial_velocity_min = 40.0
		hit_particles.initial_velocity_max = 80.0
		hit_particles.scale_amount_min = 2.0
		hit_particles.scale_amount_max = 4.0
		hit_particles.color = Color(1, 0.3, 0.1, 0.7)
		
		# Position particles
		hit_particles.global_position = position
		hit_particles.position.y -= 35  # Height offset to center on entity
		hit_particles.emitting = true
		
		# Remove particles after they finish
		var timer = get_tree().create_timer(0.5)
		timer.timeout.connect(func(): 
			if is_instance_valid(hit_particles):
				hit_particles.queue_free()
		)

# Helper to find nearby enemies
func get_nearby_enemies(radius: int) -> Array:
	var nearby = []
	
	# Use the game_controller reference directly with assertion
	assert(game_controller != null, "HeavyPlayer: " + entity_name + " - GameController reference not set")
	assert(game_controller is GameController, "HeavyPlayer: " + entity_name + " - game_controller is not a GameController instance")
	
	for enemy in game_controller.enemy_entities:
		if grid_position.distance_to(enemy.grid_position) <= radius:
			nearby.append(enemy)
	
	return nearby

# Highlight tiles that can be targeted with fireball
func highlight_fireball_targets():
	# Get the isometric map
	if not isometric_map:
		print("WizardPlayer: Cannot highlight fireball targets - isometric_map is null")
		return
		
	# Clear any existing highlights
	if game_controller:
		game_controller.clear_all_highlights()
	
	# Get the directions (cardinal)
	var directions = [
		Vector2(1, 0),   # Right
		Vector2(-1, 0),  # Left
		Vector2(0, 1),   # Down
		Vector2(0, -1),  # Up
	]
	
	var highlighted_count = 0
	print("WizardPlayer: Highlighting fireball targets from " + str(grid_position))
	
	# For each direction, trace a line until we hit a wall or max range
	for dir in directions:
		var current_pos = grid_position
		var distance = 0
		var path_tiles = []
		
		# Trace the line
		while distance < fireball_range:
			# Move one step in the direction
			current_pos += Vector2i(dir)
			distance += 1
			
			# Get the tile at this position
			var current_tile = isometric_map.get_tile(current_pos)
			
			# If there's no tile or it's a wall, stop
			if not current_tile or not current_tile.is_walkable:
				break
			
			# Add this tile to the path
			path_tiles.append(current_tile)
			
			# Set up hover signal connection for AOE preview
			if not current_tile.is_connected("tile_highlight_change", Callable(self, "_on_tile_highlight_change")):
				current_tile.connect("tile_highlight_change", Callable(self, "_on_tile_highlight_change"))
			
			# Mark this tile as a target
			current_tile.set_action_target(true)
			highlighted_count += 1
		
	print("WizardPlayer: Highlighted " + str(highlighted_count) + " fireball targets") 

# Handle tile highlight changes to show AOE preview
func _on_tile_highlight_change(tile: IsometricTile):
	# If hovering on a target tile, show AOE preview
	if tile.is_action_target and tile.is_hovered:
		# If we're already hovering a tile, clear its AOE preview first
		if hover_target != null and hover_target != tile:
			# Only clear if it's still action_target but not highlighted as AOE
			for x in range(-aoe_radius, aoe_radius + 1):
				for y in range(-aoe_radius, aoe_radius + 1):
					var prev_aoe_pos = hover_target.grid_position + Vector2i(x, y)
					var prev_aoe_tile = isometric_map.get_tile(prev_aoe_pos)
					
					# Don't modify the actual target tiles, only the AOE previews
					if prev_aoe_tile and prev_aoe_tile != hover_target and not prev_aoe_tile.is_action_target:
						prev_aoe_tile.set_attackable(false)
		
		# Set new hover target and show its AOE
		hover_target = tile
		highlight_fireball_aoe(tile.grid_position)
	
	# When no longer hovering a target tile, clear AOE preview
	elif hover_target == tile and not tile.is_hovered:
		# Clear AOE highlighting but leave target highlighting
		clear_fireball_aoe(tile.grid_position)
		
		hover_target = null

# Clear the AOE area highlighting around the targeted position
func clear_fireball_aoe(target_pos: Vector2i):
	if not isometric_map:
		return
		
	print("WizardPlayer: Clearing fireball AOE preview at " + str(target_pos))
	
	# Clear all tiles in AOE radius
	for x in range(-aoe_radius, aoe_radius + 1):
		for y in range(-aoe_radius, aoe_radius + 1):
			var aoe_pos = target_pos + Vector2i(x, y)
			var aoe_tile = isometric_map.get_tile(aoe_pos)
			
			# Only clear attackable on non-target tiles
			if aoe_tile and aoe_tile != hover_target and not aoe_tile.is_action_target:
				aoe_tile.set_attackable(false)

# Highlight the AOE area around the targeted position
func highlight_fireball_aoe(target_pos: Vector2i):
	if not isometric_map:
		return
		
	print("WizardPlayer: Showing fireball AOE preview at " + str(target_pos))
	
	# Highlight all tiles in AOE radius (including walls to show full blast area)
	for x in range(-aoe_radius, aoe_radius + 1):
		for y in range(-aoe_radius, aoe_radius + 1):
			var aoe_pos = target_pos + Vector2i(x, y)
			var aoe_tile = isometric_map.get_tile(aoe_pos)
			
			# Mark all tiles in the AOE range as attackable, except the target itself
			if aoe_tile and not aoe_tile.is_action_target:
				aoe_tile.set_attackable(true)

# Wizard gets more action points and occasionally increases fireball effects
func on_level_up():
	# Increase health and action points
	max_health += 2
	current_health += 2
	
	# Custom allocation favoring action points over movement
	max_action_points += 1
	if level % 2 == 0:  # Only every other level
		max_movement_points += 1 
		
	# Increase fireball range every other level
	if level % 2 == 0:
		fireball_range += 1
