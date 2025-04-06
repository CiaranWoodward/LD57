class_name TurnSequencer

extends Node

# Tracks all characters participating in the turn sequence
var characters: Array = []

# Tracks the index of the currently active character
var current_index: int = -1

# Character groups for organizing turns (e.g., "player", "enemy") 
var character_groups: Dictionary = {}
var current_group: String = ""

# Signals
signal turn_started(character)
signal turn_ended(character)
signal all_turns_completed()
signal group_turns_started(group_name)
signal group_turns_completed(group_name)

func _ready():
	# Add self to a group for easier finding by characters
	add_to_group("turn_sequencer")
	print("TurnSequencer: Initialized")

# Initialize the sequencer with a set of characters
func initialize(new_characters: Array):
	characters = new_characters
	print("TurnSequencer: Initialized with " + str(characters.size()) + " characters")
	
	# Connect signals for all characters
	for character in characters:
		_connect_character_signals(character)

# Add a single character to the sequence
func add_character(character):
	if character in characters:
		return
		
	characters.append(character)
	_connect_character_signals(character)
	print("TurnSequencer: Added character " + character.name)

# Add a character to a specific group
func add_character_to_group(character, group_name: String):
	if not character_groups.has(group_name):
		character_groups[group_name] = []
		
	if not character in character_groups[group_name]:
		character_groups[group_name].append(character)
		print("TurnSequencer: Added character " + character.name + " to group " + group_name)
	
	# Make sure the character is also in the main character list
	if not character in characters:
		add_character(character)

# Remove a character from the sequence
func remove_character(character):
	# Remove from main character list
	if character in characters:
		characters.erase(character)
		
		# Disconnect signals
		if character.is_connected("turn_finished", _on_character_turn_finished):
			character.turn_finished.disconnect(_on_character_turn_finished)
		
		print("TurnSequencer: Removed character " + character.name)
	
	# Remove from all character groups
	for group_name in character_groups:
		if character in character_groups[group_name]:
			character_groups[group_name].erase(character)
			print("TurnSequencer: Removed character " + character.name + " from group " + group_name)
	
	# If we're in a group turn, make sure our characters array matches the current group
	if current_group != "":
		characters = character_groups[current_group].duplicate()
	
	# Adjust current_index if needed
	if current_index >= characters.size() and characters.size() > 0:
		current_index = characters.size() - 1
		
	# If we're in the middle of a turn cycle, adjust who goes next
	if current_index >= 0 and current_index < characters.size():
		call_deferred("_start_next_character_turn")

# Connect signals for a character
func _connect_character_signals(character):
	if not character.is_connected("turn_finished", _on_character_turn_finished):
		character.turn_finished.connect(_on_character_turn_finished)
		print("TurnSequencer: Connected signals for " + character.name)

# Start the first turn in the sequence
func start_turns():
	print("TurnSequencer: Starting turn sequence")
	
	if characters.size() == 0:
		print("TurnSequencer: No characters to process")
		emit_signal("all_turns_completed")
		return
	
	current_index = -1
	_start_next_character_turn()

# Start turns for a specific group
func start_group_turns(group_name: String):
	print("TurnSequencer: Starting turns for group " + group_name)
	
	if not character_groups.has(group_name) or character_groups[group_name].size() == 0:
		print("TurnSequencer: No characters in group " + group_name)
		emit_signal("group_turns_completed", group_name)
		return
	
	# Set the current group and emit the signal
	current_group = group_name
	emit_signal("group_turns_started", group_name)
	
	# Use only this group's characters for processing turns
	characters = character_groups[group_name].duplicate()
	
	# Reset the index to start from the first character
	current_index = -1
	
	# Start processing the first character in the group
	_start_next_character_turn()

# Start the turn for the next character in sequence
func _start_next_character_turn():
	current_index += 1
	
	# Check if we've reached the end of the sequence
	if current_index >= characters.size():
		print("TurnSequencer: All characters processed in group " + current_group)
		
		# Signal that this group's turns are completed
		var old_group = current_group
		current_group = ""
		emit_signal("group_turns_completed", old_group)
		return
	
	var character = characters[current_index]
	print("TurnSequencer: Starting turn for " + character.name + " (" + str(current_index + 1) + "/" + str(characters.size()) + ")")
	
	# Signal that we're starting this character's turn
	emit_signal("turn_started", character)
	
	# Start the character's turn (will eventually call finish_turn)
	character.start_turn()

# Called when a character finishes their turn
func _on_character_turn_finished(character):
	print("TurnSequencer: Character " + character.name + " finished turn")
	
	# Make sure this is the current character
	if current_index < 0 or current_index >= characters.size() or characters[current_index] != character:
		push_warning("TurnSequencer: Character " + character.name + " finished turn but is not the current character")
		return
	
	# Signal that this character's turn has ended
	emit_signal("turn_ended", character)
	
	# Start the next character's turn
	call_deferred("_start_next_character_turn")

# Shuffle the turn order
func shuffle_turn_order():
	if current_index >= 0:
		push_warning("TurnSequencer: Cannot shuffle turn order during an active turn sequence")
		return
	
	randomize()
	characters.shuffle()
	print("TurnSequencer: Turn order shuffled")

# Shuffle the turn order for a specific group
func shuffle_group_turn_order(group_name: String):
	if current_group == group_name and current_index >= 0:
		push_warning("TurnSequencer: Cannot shuffle group turn order during an active turn sequence")
		return
	
	if not character_groups.has(group_name):
		return
	
	randomize()
	character_groups[group_name].shuffle()
	print("TurnSequencer: Turn order shuffled for group " + group_name)

# Skip the current character's turn
func skip_current_turn():
	if current_index < 0 or current_index >= characters.size():
		return
		
	var character = characters[current_index]
	print("TurnSequencer: Skipping turn for " + character.name)
	
	# Signal that this character's turn has ended
	emit_signal("turn_ended", character)
	
	# Move to the next character
	call_deferred("_start_next_character_turn")
