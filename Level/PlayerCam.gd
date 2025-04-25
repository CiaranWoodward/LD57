extends Camera2D

@export var MAX_SPEED = 1000.0
@export var ACCEL_TIME = 0.5
@export var STOP_TIME = 0.2
@export var ZOOM_AMOUNT = 0.2
@export var ZOOM_TIME = 0.15
@export var ZOOM_MIN = 0.6
@export var ZOOM_MAX = 2

var zoom_tween
var move_tween
var dir_tween

var speed = 0
var target_zoom = Vector2(1, 1)
var dir_vec = Vector2.ZERO
var moving = false
var dragging = false
var rezoom = false

# Touch and pinch variables
var touch_points = {}
var pinch_start_distance = 0
var pinch_start_zoom = Vector2.ZERO
var is_pinching = false

## Camera boundary in global coordinates
@export var MaxPos : Vector2 = Vector2(1000, 1000)
@export var MinPos : Vector2 = Vector2(-1000, -1000)
@export var LEVEL_MARGIN := 100.0  # Extra margin to add around the calculated bounds
@export var DEBUG_MODE := true  # Set to true to print debug information

# Screen shake variables
@export var screen_shake_decay = 0.85  # How quickly the shaking stops [0, 1].
@export var screen_shake_max_offset = Vector2(20, 20)  # Maximum hor/ver shake in pixels.
@export var screen_shake_max_roll = 0.03  # Maximum rotation in radians (use sparingly).

@onready var screen_shake_start_position = position
@onready var screen_shake_noise = FastNoiseLite.new()

@onready var cam_floor_offset := -400

var screen_shake_noise_y = 0

var screen_shake_childhood_trauma = 0.0 # Base level of trauma
var screen_shake_trauma = 0.0  # Current shake strength.
var screen_shake_trauma_power = 2  # Trauma exponent. Use [2, 3].
var screen_shake_offset: Vector2 = Vector2.ZERO
var screen_shake_rotation_offset: float = 0.0

var unshaken_position: Vector2
var unshaken_rotation_degrees: float

# Reference to the game controller
var game_controller: GameController = null
var level_manager = null
var last_active_level := -1  # Track the last active level to detect changes

# Called when the node enters the scene tree for the first time.
func _ready():
	screen_shake_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	screen_shake_noise.seed = randi()
	screen_shake_noise.frequency = 0.15
	screen_shake_noise.fractal_octaves = 2
	unshaken_position = position
	unshaken_rotation_degrees = rotation_degrees
	
	# Find and store references to game controller and level manager
	await get_tree().process_frame
	_setup_references()

# Setup references to game controller and level manager
func _setup_references():
	# Find game controller in the scene
	var controllers = get_tree().get_nodes_in_group("game_controller")
	if controllers.size() > 0:
		game_controller = controllers[0]
		
		if game_controller:
			# Connect to entity_moved signal to detect player level changes
			if not game_controller.is_connected("entity_moved", Callable(self, "_on_entity_moved")):
				game_controller.entity_moved.connect(_on_entity_moved)
			
			# Get level manager through game controller
			level_manager = game_controller.get_parent().get_node_or_null("LevelManager")
			
			# Initial bounds update
			update_camera_bounds()
			
			# Store initial active level
			if game_controller.has_method("get_active_level"):
				last_active_level = game_controller.current_active_level
			
			if DEBUG_MODE:
				print("PlayerCam: Initial active level is ", last_active_level)
	else:
		push_error("PlayerCam: Could not find GameController")

func _unhandled_input(event):
	# Handle touch events for pinch zooming
	if event is InputEventScreenTouch:
		if event.pressed:
			# Store touch points
			touch_points[event.index] = event.position
		else:
			# Remove touch points
			touch_points.erase(event.index)
			
			# End pinching if less than 2 touch points remain
			if touch_points.size() < 2:
				is_pinching = false
				
	# Handle touch movement for pinch zooming
	if event is InputEventScreenDrag:
		# Update touch point position
		touch_points[event.index] = event.position
		
		# If we have exactly 2 touch points, handle pinch zoom
		if touch_points.size() == 2:
			var touch_positions = touch_points.values()
			var current_distance = touch_positions[0].distance_to(touch_positions[1])
			
			# Start pinch if not already pinching
			if not is_pinching:
				is_pinching = true
				pinch_start_distance = current_distance
				pinch_start_zoom = zoom
			else:
				# Calculate zoom factor based on distance change
				var zoom_factor = pinch_start_distance / current_distance
				target_zoom = pinch_start_zoom * zoom_factor
				rezoom = true
			
	# Only allow unhandled input for start drag
	if event is InputEventMouseButton and (event.button_index == MOUSE_BUTTON_RIGHT || event.button_index == MOUSE_BUTTON_MIDDLE):
		if event.is_pressed():
			dragging = true
			dir_tween = null
			move_tween = null
			speed = 0
			moving = false
			dir_vec = Vector2.ZERO
	if event.is_action_pressed("zoom_in"):
		target_zoom -= Vector2(ZOOM_AMOUNT, ZOOM_AMOUNT)
		rezoom = true
	if event.is_action_pressed("zoom_out"):
		target_zoom += Vector2(ZOOM_AMOUNT, ZOOM_AMOUNT)
		rezoom = true

func _input(event):
	# Once we have started dragging, always track the input
	if not dragging:
		return
	if event is InputEventMouseButton and (event.button_index == MOUSE_BUTTON_RIGHT || event.button_index == MOUSE_BUTTON_MIDDLE):
		if not event.is_pressed():
			dragging = false
	if dragging && event is InputEventMouseMotion:
		unshaken_position -= event.relative / zoom.x
		_bound_level()
		position = unshaken_position

func _bound_level():
	if unshaken_position.x < MinPos.x:
		unshaken_position.x = MinPos.x
	if unshaken_position.y < MinPos.y:
		unshaken_position.y = MinPos.y
	if unshaken_position.x > MaxPos.x:
		unshaken_position.x = MaxPos.x
	if unshaken_position.y > MaxPos.y:
		unshaken_position.y = MaxPos.y

func _physics_process(delta):
	# Check if the active level has changed - don't rely only on signals
	if game_controller and game_controller.current_active_level != last_active_level:
		if DEBUG_MODE:
			print("PlayerCam: Active level changed from ", last_active_level, " to ", game_controller.current_active_level)
		last_active_level = game_controller.current_active_level
		update_camera_bounds()

	if rezoom:
		if target_zoom.x > ZOOM_MAX:
			target_zoom = Vector2(ZOOM_MAX, ZOOM_MAX)
		if target_zoom.x < ZOOM_MIN:
			target_zoom = Vector2(ZOOM_MIN, ZOOM_MIN)
		if target_zoom != zoom:
			zoom_tween = create_tween()
			zoom_tween.tween_property(self, "zoom", target_zoom, ZOOM_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		rezoom = false
	
	if dragging or is_pinching:
		return
	
	var dir_delta = Vector2.ZERO
	if Input.is_action_pressed("ui_right"):
		dir_delta.x += 1
	if Input.is_action_pressed("ui_left"):
		dir_delta.x -= 1
	if Input.is_action_pressed("ui_up"):
		dir_delta.y -= 1
	if Input.is_action_pressed("ui_down"):
		dir_delta.y += 1
	if speed == 0:
		dir_vec = dir_delta
	if dir_delta != Vector2.ZERO:
		dir_delta = dir_delta.normalized()
		dir_tween = create_tween()
		dir_tween.tween_property(self, "dir_vec", dir_delta, 1).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	
	if dir_delta != Vector2.ZERO && !moving:
		# just started moving
		move_tween = create_tween()
		move_tween.tween_property(self, "speed", MAX_SPEED, ACCEL_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		moving = true
	elif dir_delta == Vector2.ZERO && moving:
		# just stopped moving
		move_tween = create_tween()
		move_tween.tween_property(self, "speed", 0, STOP_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		moving = false
	
	unshaken_position += dir_vec * speed * delta * zoom.x
	_bound_level()

	_shake(delta)
	position = unshaken_position + screen_shake_offset
	rotation_degrees = unshaken_rotation_degrees + rad_to_deg(screen_shake_rotation_offset)

# Called when entity_moved signal is emitted
func _on_entity_moved(_entity):
	if DEBUG_MODE:
		print("PlayerCam: entity_moved signal received, checking for level changes")
	check_for_level_changes()

# Check if any player has changed levels and update camera if needed
func check_for_level_changes():
	if not game_controller or not level_manager:
		return
		
	# Force update camera bounds since this is called when a player changes levels
	update_camera_bounds()

func screen_shake_add_permanant_trauma(amount: float):
	screen_shake_childhood_trauma = min(screen_shake_childhood_trauma + amount, 0.6)

func screen_shake_add_trauma(amount : float):
	screen_shake_trauma = min(screen_shake_trauma + amount, 1.0)

func _shake(delta: float):
	if !screen_shake_trauma && !screen_shake_childhood_trauma:
		screen_shake_offset = Vector2.ZERO
		screen_shake_rotation_offset = 0
		return
	screen_shake_trauma = max(screen_shake_trauma - screen_shake_decay * delta, 0)
	var screen_shake_working_trauma = min(screen_shake_trauma + screen_shake_childhood_trauma, 1.0)
	var amt = pow(screen_shake_working_trauma, screen_shake_trauma_power)
	screen_shake_noise_y += 1
	screen_shake_rotation_offset = screen_shake_max_roll * amt * screen_shake_noise.get_noise_2d(0,screen_shake_noise_y)
	screen_shake_offset.x = screen_shake_max_offset.x * amt * screen_shake_noise.get_noise_2d(1000,screen_shake_noise_y)
	screen_shake_offset.y = screen_shake_max_offset.y * amt * screen_shake_noise.get_noise_2d(2000,screen_shake_noise_y)

# Updates camera bounds based on the entirety of all active levels
func update_camera_bounds():
	if not game_controller or not level_manager:
		if DEBUG_MODE:
			print("PlayerCam: Cannot update bounds - missing controller or level manager")
		return
		
	var player_entities = game_controller.player_entities
	if player_entities.size() == 0:
		if DEBUG_MODE:
			print("PlayerCam: No player entities found")
		return
		
	# Find all active level indices - include the current active level and all levels with players
	var active_level_indices = []
	
	# Always include the active level
	if not active_level_indices.has(game_controller.current_active_level) and level_manager.level_nodes.has(game_controller.current_active_level):
		active_level_indices.append(game_controller.current_active_level)
	
	# Also include all levels that have players
	for player in player_entities:
		if not active_level_indices.has(player.current_level) and level_manager.level_nodes.has(player.current_level):
			active_level_indices.append(player.current_level)
	
	if DEBUG_MODE:
		print("PlayerCam: Active level indices for bounds calculation: ", active_level_indices)
	
	# If there are no active levels, return
	if active_level_indices.size() == 0:
		if DEBUG_MODE:
			print("PlayerCam: No active levels found")
		return
		
	# Calculate map bounds across all active levels
	var min_x = INF
	var min_y = INF
	var max_x = -INF
	var max_y = -INF
	
	# Process each active level
	for level_idx in active_level_indices:
		var level_map = level_manager.level_nodes.get(level_idx)
		if not level_map:
			continue
			
		# For each level, find the min and max positions of all its tiles
		var level_min_x = INF
		var level_min_y = INF
		var level_max_x = -INF
		var level_max_y = -INF
		
		# Calculate bounds for this level
		for tile_pos in level_map.tiles:
			var tile = level_map.tiles[tile_pos]
			var world_pos = tile.global_position
			
			level_min_x = min(level_min_x, world_pos.x)
			level_min_y = min(level_min_y, world_pos.y)
			level_max_x = max(level_max_x, world_pos.x)
			level_max_y = max(level_max_y, world_pos.y)
		
		# Debug output for level bounds
		if DEBUG_MODE:
			print("PlayerCam: Level ", level_idx, " bounds: (", level_min_x, ", ", level_min_y, ") to (", level_max_x, ", ", level_max_y, ")")
		
		# Update the overall bounds
		min_x = min(min_x, level_min_x)
		min_y = min(min_y, level_min_y)
		max_x = max(max_x, level_max_x)
		max_y = max(max_y, level_max_y)
	
	# Add margin to calculated bounds
	min_x -= LEVEL_MARGIN
	min_y -= LEVEL_MARGIN
	max_x += LEVEL_MARGIN
	max_y += LEVEL_MARGIN
	
	# Use the global coordinates directly for MinPos and MaxPos
	var new_min_pos = Vector2(min_x, min_y)
	var new_max_pos = Vector2(max_x, max_y)
	
	# Only update if the bounds actually changed
	if new_min_pos != MinPos or new_max_pos != MaxPos:
		MinPos = new_min_pos
		MaxPos = new_max_pos
		
		if DEBUG_MODE:
			print("PlayerCam: Updated camera bounds. MinPos: ", MinPos, " MaxPos: ", MaxPos)
		
		# Make sure the camera stays within the new bounds
		_bound_level()
		
		# Force position update
		position = unshaken_position + screen_shake_offset
