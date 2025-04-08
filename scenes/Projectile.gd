class_name Projectile
extends Node2D

signal hit_target
signal projectile_completed

# Projectile properties
@export var speed: float = 400.0
@export var trail_lifetime: float = 0.4
@export var trail_amount: int = 20
@export var projectile_color: Color = Color(1.0, 0.7, 0.2, 0.8)

# Internal variables
var start_position: Vector2
var target_position: Vector2
var travel_direction: Vector2 = Vector2.ZERO
var distance_to_target: float
var progress: float = 0.0
var is_completed: bool = false

func _ready():
	# Make sure the trail particles start emitting
	var trail = $TrailParticles
	if trail:
		trail.emitting = true
		trail.lifetime = trail_lifetime
		trail.amount = trail_amount
		trail.color = projectile_color

func _process(delta):
	if is_completed:
		return
		
	# Update position based on progress
	progress += speed * delta / distance_to_target
	progress = min(progress, 1.0)
	
	position = start_position.lerp(target_position, progress)
	
	# Check if we've reached the target
	if progress >= 1.0:
		complete()

func initialize(from_position: Vector2, to_position: Vector2, projectile_speed: float = 400.0):
	# Set positions and movement
	start_position = from_position
	target_position = to_position
	position = start_position
	speed = projectile_speed
	
	# Calculate direction and distance
	travel_direction = (target_position - start_position).normalized()
	distance_to_target = start_position.distance_to(target_position)
	
	# Rotate sprite to match direction
	rotation = travel_direction.angle()

func create_hit_effect():
	# Create hit particles effect
	var hit_particles = CPUParticles2D.new()
	
	# Add to the same parent as this projectile
	get_parent().add_child(hit_particles)
	
	# Set global position to ensure it appears at the correct spot
	hit_particles.global_position = global_position
	
	# Configure hit particles
	hit_particles.z_index = 1
	hit_particles.amount = 30
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
	hit_particles.color = projectile_color
	hit_particles.emitting = true
	
	# Remove particles after they finish
	var timer = get_tree().create_timer(0.5)
	timer.timeout.connect(func(): 
		if is_instance_valid(hit_particles):
			hit_particles.queue_free()
	)

func complete():
	if is_completed:
		return
		
	is_completed = true
	emit_signal("hit_target")
	emit_signal("projectile_completed")
	
	# Create hit effect
	create_hit_effect()
	
	# Hide the sprite but keep the trail particles visible
	$Sprite2D.visible = false
	
	# Stop emitting new particles but let existing ones fade out
	var trail = $TrailParticles
	if trail:
		trail.emitting = false
	
	# Queue free after particles fade out
	var timer = get_tree().create_timer(trail_lifetime)
	timer.timeout.connect(func(): queue_free()) 
