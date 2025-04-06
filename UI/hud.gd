extends CanvasLayer
class_name HUD

signal PauseMenu
signal UpgradeMenu
signal DrillButtonHovered(player)
signal DrillButtonUnhovered

# Reference to the current active player
var current_player: PlayerEntity = null

# Drilling visualization
var is_hovering_drill_button: bool = false

func _ready() -> void:
	Global.hud = self
	
	# Connect action buttons
	var action_drill = $Action/ActionMargin/ActionHBox/ActionDrill
	if action_drill:
		action_drill.gui_input.connect(_on_action_drill_input)
		# Connect to mouse enter/exit for hover detection
		action_drill.mouse_entered.connect(_on_action_drill_mouse_entered)
		action_drill.mouse_exited.connect(_on_action_drill_mouse_exited)

func _on_button_menu_pressed() -> void:
	PauseMenu.emit()
	
func _on_button_upgrade_pressed() -> void:
	UpgradeMenu.emit()

# Handle clicking on the drill action button
func _on_action_drill_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# If we have a current player, try to use the drill ability
		if current_player and current_player.abilities.has("drill"):
			current_player.use_ability("drill", null)  # Drill doesn't need a target

# Show drill path when hovering over drill button
func _on_action_drill_mouse_entered() -> void:
	is_hovering_drill_button = true
	if current_player and current_player.abilities.has("drill"):
		DrillButtonHovered.emit(current_player)

# Hide drill path when no longer hovering over drill button
func _on_action_drill_mouse_exited() -> void:
	is_hovering_drill_button = false
	DrillButtonUnhovered.emit()

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

# Updates the UI to show the current player's health
func update_health_bar(current: int, maximum: int) -> void:
	# Get the health bar
	var health_bar = $Info/InfoMargin/InfoVBox/HealthBar
	
	# Update the value and max value
	health_bar.max_value = maximum
	health_bar.value = current
	
	# Optionally change the color based on health percentage
	var health_percent = float(current) / float(maximum)
	if health_percent < 0.3:
		health_bar.get("theme_override_styles/fill").bg_color = Color(0.8, 0.0, 0.0, 1.0) # Critical health (red)
	elif health_percent < 0.6:
		health_bar.get("theme_override_styles/fill").bg_color = Color(0.8, 0.8, 0.0, 1.0) # Low health (yellow)
	else:
		health_bar.get("theme_override_styles/fill").bg_color = Color(0.96, 0.07, 0.14, 1.0) # Normal health (game's default red)

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
		if current_player.is_connected("health_changed", Callable(self, "update_health_bar")):
			current_player.disconnect("health_changed", Callable(self, "update_health_bar"))
	
	# Store reference to the new player
	current_player = player
	
	if player:
		# Connect to the new player's signals
		current_player.connect("action_points_changed", update_action_points)
		current_player.connect("movement_points_changed", update_movement_points)
		current_player.connect("health_changed", update_health_bar)
		
		# Update the UI immediately with current values
		update_action_points(player.action_points, player.max_action_points)
		update_movement_points(player.movement_points, player.max_movement_points)
		update_health_bar(player.current_health, player.max_health)
		
		# Update character image
		update_character_image(player)
		
		# Display drilling indicator if player is drilling
		if player.is_drilling:
			show_drilling_indicator(player.drilling_turns_left)
		else:
			hide_drilling_indicator()
		
		# Update drill visualization if we're hovering the button
		if is_hovering_drill_button:
			DrillButtonHovered.emit(current_player)
	else:
		# Clear UI if no player is active
		update_action_points(0, 0)
		update_movement_points(0, 0)
		update_health_bar(0, 1) # Set to 0 with a max of 1 (empty bar)
		
		# Reset character image
		var image = $Info/InfoMargin/InfoVBox/CharImage
		image.self_modulate = Color(1.0, 1.0, 1.0, 0.5) # Dim the character image
		
		# Hide drilling indicator
		hide_drilling_indicator()
		
		# Clear any drill visualization
		DrillButtonUnhovered.emit()

# Updates the character image based on the player type
func update_character_image(player: PlayerEntity) -> void:
	var image = $Info/InfoMargin/InfoVBox/CharImage
	
	# Use the player's profile texture and tint directly
	image.texture = player.profile_texture
	image.self_modulate = player.profile_tint

# Show a drilling indicator when a player is in the drilling state
func show_drilling_indicator(turns_left: int) -> void:
	# Get the drilling label
	var drill_label = $DrillIndicator/DrillLabel
	
	# Update the text to show the turns remaining
	drill_label.text = "DRILLING: " + str(turns_left) + " turns left"
	
	# Show the indicator
	$DrillIndicator.visible = true

# Hide the drilling indicator
func hide_drilling_indicator() -> void:
	# Hide the drilling indicator
	$DrillIndicator.visible = false
