extends Node2D

# This script initializes the game by setting up the map and entities
# Attach this to the main Game scene

# Reference to key nodes
@onready var map: IsometricMap = $Map
@onready var game_controller: GameController = $GameController

# Example textures (for entities only)
@export var player_texture: Texture2D
@export var enemy_texture: Texture2D

func _ready():
	# Wait a frame for the map to fully initialize
	await get_tree().process_frame
	
	# Set up game controller and entities
	if game_controller:
		# Spawn player in the center of the map
		var player_pos = Vector2i(map.map_width / 2, map.map_height / 2)
		var player = game_controller.spawn_player(player_pos, player_texture)
		
		# Spawn a few enemies around the map for testing
		var enemy_positions = [
			Vector2i(player_pos.x + 3, player_pos.y + 3),
			Vector2i(player_pos.x - 3, player_pos.y - 3),
			Vector2i(player_pos.x + 3, player_pos.y - 3)
		]
		
		for pos in enemy_positions:
			if map.is_valid_position(pos):
				var enemy = game_controller.spawn_enemy(pos, "Demon", enemy_texture)
		
		# Connect to game events
		game_controller.connect("turn_changed", Callable(self, "_on_turn_changed"))
		game_controller.connect("game_state_changed", Callable(self, "_on_game_state_changed"))
		
		# Start the game
		game_controller.start_game()
		
		# Center camera on player
		center_camera_on_player(player)

# Center the camera on the player entity
func center_camera_on_player(player: Entity):
	var camera = $Camera2D
	if camera and player:
		camera.position = player.position

# Handle turn changes
func _on_turn_changed(turn: String):
	print("Turn changed to: ", turn)
	
	# You can implement UI updates or other logic here
	# For example, display whose turn it is on the screen

# Handle game state changes
func _on_game_state_changed(state: String):
	print("Game state changed to: ", state)
	
	# You can implement UI updates or other logic here
	# For example, show a game over screen if state is "game_over" 
