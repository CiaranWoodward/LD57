class_name TurnSequencer

extends Node

var actionable_characters: Array[ActionableCharacter]
var current_player_index: int = 0

func initialise_character_set(characters: Array[ActionableCharacter]) -> void:
	actionable_characters = characters
	randomize()
	actionable_characters.shuffle()

func add_character(character: ActionableCharacter) -> void:
	actionable_characters.append(character)

func shuffle_turn_order():
	randomize()
	actionable_characters.shuffle()

func _on_turn_finished() -> void:
	current_player_index += 1
	actionable_characters[current_player_index].start_turn()
