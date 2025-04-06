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

## Maximum camera position
@export var MaxPos : Vector2 = Vector2(1000, 1000)

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

# Called when the node enters the scene tree for the first time.
func _ready():
	screen_shake_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	screen_shake_noise.seed = randi()
	screen_shake_noise.frequency = 0.15
	screen_shake_noise.fractal_octaves = 2
	unshaken_position = position
	unshaken_rotation_degrees = rotation_degrees 

func _unhandled_input(event):
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

func _bound_level():
	if unshaken_position.x < -MaxPos.x:
		unshaken_position.x = -MaxPos.x
	if unshaken_position.y < -MaxPos.y:
		unshaken_position.y = -MaxPos.y
	if unshaken_position.x > MaxPos.x:
		unshaken_position.x = MaxPos.x
	if unshaken_position.y > MaxPos.y:
		unshaken_position.y = MaxPos.y

func _physics_process(delta):
	if rezoom:
		if target_zoom.x > ZOOM_MAX:
			target_zoom = Vector2(ZOOM_MAX, ZOOM_MAX)
		if target_zoom.x < ZOOM_MIN:
			target_zoom = Vector2(ZOOM_MIN, ZOOM_MIN)
		if target_zoom != zoom:
			zoom_tween = create_tween()
			zoom_tween.tween_property(self, "zoom", target_zoom, ZOOM_TIME).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		rezoom = false
	
	if dragging:
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
