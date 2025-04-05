# Isometric Strategy Game Foundation

This project provides a foundation for an isometric, tile-based strategy game built with Godot 4. Instead of using Godot's built-in TileMap system, it implements a custom grid using Node2D instances for maximum flexibility.

## Core Components

### IsometricTile
- Represents a single tile in the game grid
- Handles tile properties (walkable, movement cost, etc.)
- Manages entities placed on the tile
- Uses modulation for highlighting instead of a separate sprite
- Includes an Area2D with a diamond-shaped collision polygon for input detection
- Configured through the Godot editor with a scene

### IsometricMap
- Manages a collection of tiles in an isometric grid
- Handles conversion between grid and world coordinates
- Provides pathfinding and tile querying capabilities
- Instantiates tile scenes for visual customization
- Sets up proper collision shapes for each tile based on tile dimensions

### Entity
- Base class for all game objects that can be placed on tiles
- Handles movement along paths
- Manages entity properties and visual representation
- Includes an Area2D with a circular collision shape for input detection
- Configured through the Godot editor with a scene
- Automatically adjusts collision radius based on texture size

### GameController
- Manages game state and turn-based gameplay
- Handles entity selection and movement
- Coordinates interaction between entities and the map
- Provides game flow control (turns, game start/end)
- Instantiates entity scenes for visual customization

## Usage

### Creating a Map
The map is automatically generated based on the width and height parameters set in the IsometricMap node. You can adjust these in the editor.

### Customizing Tiles
Tiles are configured through the IsometricTile scene. To customize tile appearance:

1. Open the IsometricTile scene in the editor
2. Set the texture for the Sprite2D node
3. Configure the highlight color and other properties
4. Save the scene

The map will instantiate this scene for each tile position. The collision shape for input detection is automatically generated based on the tile dimensions.

### Customizing Entities
Entities are configured through the Entity scene. To customize entity appearance:

1. Open the Entity scene in the editor
2. Set the texture for the Sprite2D node 
3. Adjust the collision shape if needed
4. Save the scene

The GameController will instantiate this scene when spawning entities. The collision shape automatically adjusts based on the texture size.

### Adding Entities
Entities can be spawned using the GameController:

```gdscript
# In your game initialization code:
var game_controller = $GameController
var player_texture = preload("res://path_to_your_player_texture.png")
var player = game_controller.spawn_player(Vector2i(5, 5), player_texture)

var enemy_texture = preload("res://path_to_your_enemy_texture.png")
var enemy = game_controller.spawn_enemy(Vector2i(8, 8), "Demon", enemy_texture)
```

### Game Flow
The game uses a turn-based system managed by the GameController:

```gdscript
# Start the game (typically called after setting up the map and entities)
game_controller.start_game()

# Connect to signals to respond to game events
game_controller.connect("turn_changed", Callable(self, "_on_turn_changed"))
game_controller.connect("game_state_changed", Callable(self, "_on_game_state_changed"))
game_controller.connect("entity_moved", Callable(self, "_on_entity_moved"))
```

## Extending the System

### Creating Custom Tile Types
You can create different tile scenes for various terrain types or extend the IsometricTile class:

```gdscript
class_name WaterTile
extends IsometricTile

func _init():
    super._init()
    tile_type = "water"
    is_walkable = false
    # Set custom properties
```

### Creating Custom Entities
Extend the Entity class to create specialized entity types:

```gdscript
class_name Player
extends Entity

var health: int = 100
var attack: int = 10

func _init():
    super._init()
    entity_name = "Player"
    move_speed = 2.0
    # Set custom properties
```

## Future Improvements

- Implement A* pathfinding for better movement
- Add Z-sorting for proper isometric depth
- Implement advanced turn-based mechanics
- Add animation support for entities
- Implement combat and interaction systems 