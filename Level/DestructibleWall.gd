class_name DestructibleWall
extends EnemyEntity

var destroyed_particles_active: int = 0

func _init():
	entity_name = "Destructible Wall"
	entity_id = "wall_" + str(randi())

func _ready():
	super._ready()
	
	# Set the correct enemy type
	enemy_type = EnemyType.DESTRUCTIBLE_WALL
	
	# Static configuration
	move_speed = 0.0  # Cannot move
	detection_range = 0  # Doesn't detect players
	aggression_level = 0.0  # No aggression
	max_health = 10
	current_health = 10
	
	xp_value = 10
	
	# Connect to the particle systems' finished signals if any
	var destruction_particles = $DestructionParticles
	if destruction_particles:
		destruction_particles.finished.connect(_on_particles_finished)

# Override process_turn to do nothing (walls don't take actions)
func process_turn(player_entities: Array):
	# Static objects don't move or take any actions
	return false

# Override pursue_target to do nothing (walls don't move)
func pursue_target():
	# Do nothing - walls don't move
	pass

# Override follow_patrol_path to do nothing (walls don't patrol)
func follow_patrol_path():
	# Do nothing - walls don't move
	pass

# Override die function to handle destruction with particles
func die():
	print("DestructibleWall: " + entity_name + " destroyed!")
	
	# Visual effect (flash red before dying)
	modulate = Color(1.5, 0.3, 0.3, 1.0)
	
	# Hide the sprite after a small delay
	var sprite = $Sprite2D
	if sprite:
		var sprite_timer = get_tree().create_timer(0.2)
		sprite_timer.timeout.connect(func(): sprite.visible = false)
	
	# Play destruction particles
	destroyed_particles_active = 0
	
	var destruction_particles = $DestructionParticles
	if destruction_particles:
		destruction_particles.emitting = true
		destroyed_particles_active += 1
	
	# Call the parent's die method to set flags and emit signals
	super.die()
	
	# Only queue_free if no particles are playing
	if destroyed_particles_active == 0:
		queue_free()

# Called when a particle system finishes
func _on_particles_finished():
	destroyed_particles_active -= 1
	
	# If all particle systems are done and we're dead, free the entity
	if destroyed_particles_active <= 0 and is_dead and is_instance_valid(self):
		queue_free() 