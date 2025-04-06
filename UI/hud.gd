extends CanvasLayer
class_name HUD

signal PauseMenu

# Reference to the current active player
var current_player: PlayerEntity = null

func _ready() -> void:
	Global.hud = self

func _on_button_menu_pressed() -> void:
	PauseMenu.emit()

func get_end_turn_button():
	return $End/EndMargin/EndButton

# Updates the UI to show the current player's action points
func update_action_points(current: int, maximum: int) -> void:
	# Get all action point indicators
	var action_containers = $Info/InfoMargin/InfoVBox/ActHBox.get_children()
	
	# Skip the first child (it's the texture rect icon)
	for i in range(1, action_containers.size()):
		# i-1 is the index without the icon
		var point_index = i - 1
		
		# Check if this point should be active
		if point_index < current:
			action_containers[i].modulate = Color(1, 1, 1, 1) # Fully visible
		else:
			action_containers[i].modulate = Color(1, 1, 1, 0.3) # Dimmed
		
		# Hide the points beyond the maximum
		action_containers[i].visible = point_index < maximum

# Updates the UI to show the current player's movement points
func update_movement_points(current: int, maximum: int) -> void:
	# Get all movement point indicators
	var move_containers = $Info/InfoMargin/InfoVBox/MoveHBox.get_children()
	
	# Skip the first child (it's the texture rect icon)
	for i in range(1, move_containers.size()):
		# i-1 is the index without the icon
		var point_index = i - 1
		
		# Check if this point should be active
		if point_index < current:
			move_containers[i].modulate = Color(1, 1, 1, 1) # Fully visible
		else:
			move_containers[i].modulate = Color(1, 1, 1, 0.3) # Dimmed
		
		# Hide the points beyond the maximum
		move_containers[i].visible = point_index < maximum

# Called when a player is activated - should be called by GameController
func set_active_player(player: PlayerEntity) -> void:
	# Disconnect from previous player if exists
	if current_player:
		if current_player.is_connected("action_points_changed", Callable(self, "update_action_points")):
			current_player.disconnect("action_points_changed", Callable(self, "update_action_points"))
		if current_player.is_connected("movement_points_changed", Callable(self, "update_movement_points")):
			current_player.disconnect("movement_points_changed", Callable(self, "update_movement_points"))
	
	# Store reference to the new player
	current_player = player
	
	if player:
		# Connect to the new player's signals
		current_player.connect("action_points_changed", update_action_points)
		current_player.connect("movement_points_changed", update_movement_points)
		
		# Update the UI immediately with current values
		update_action_points(player.action_points, player.max_action_points)
		update_movement_points(player.movement_points, player.max_movement_points)
		
		# Update character image
		update_character_image(player)
	else:
		# Clear UI if no player is active
		update_action_points(0, 0)
		update_movement_points(0, 0)
		
		# Reset character image
		var image = $Info/InfoMargin/InfoVBox/CharImage
		image.self_modulate = Color(1.0, 1.0, 1.0, 0.5) # Dim the character image

# Updates the character image based on the player type
func update_character_image(player: PlayerEntity) -> void:
	var image = $Info/InfoMargin/InfoVBox/CharImage
	
	# Since we only have one generic face image for now, use it for all players
	# but tint it based on player type to provide visual distinction
	if player is HeavyPlayer:
		image.texture = preload("res://images/image_face.png")
		image.self_modulate = Color(0.8, 0.3, 0.3, 1.0)  # Reddish tint for Heavy
	elif player is ScoutPlayer:
		image.texture = preload("res://images/image_face.png")
		image.self_modulate = Color(0.3, 0.8, 0.3, 1.0)  # Greenish tint for Scout
	elif player is SupportPlayer:
		image.texture = preload("res://images/image_face.png")
		image.self_modulate = Color(0.3, 0.3, 0.8, 1.0)  # Bluish tint for Support
	elif player is MedicPlayer:
		image.texture = preload("res://images/image_face.png")
		image.self_modulate = Color(0.8, 0.8, 0.3, 1.0)  # Yellowish tint for Medic
	else:
		# Default for any other player type
		image.texture = preload("res://images/image_face.png")
		image.self_modulate = Color(1.0, 1.0, 1.0, 1.0)  # No tint
