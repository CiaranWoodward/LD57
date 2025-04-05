class_name ActionableCharacter
extends Node2D

signal turn_finished(character)
signal turn_started(character)

var is_turn_active: bool = false
var turn_sequencer = null

func _ready():
	# Find the TurnSequencer in the scene
	turn_sequencer = find_turn_sequencer()
	
	if turn_sequencer:
		print(self.name + ": Found TurnSequencer and connecting signals")
	else:
		push_error(self.name + ": No TurnSequencer found in scene!")

# Find the TurnSequencer in the scene
func find_turn_sequencer():
	# Try parent-child relationship first
	var parent = get_parent()
	while parent:
		if parent is TurnSequencer:
			return parent
		parent = parent.get_parent()
	
	# Try finding in a group
	var sequencers = get_tree().get_nodes_in_group("turn_sequencer")
	if sequencers.size() > 0:
		return sequencers[0]
	
	return null

# Called by the TurnSequencer to start this character's turn
func start_turn():
	print(self.name + ": Starting turn")
	is_turn_active = true
	emit_signal("turn_started", self)
	
	# Subclasses should override this method to implement their turn logic
	# and call finish_turn() when done

# Called when this character's turn is complete
func finish_turn():
	if not is_turn_active:
		return
		
	print(self.name + ": Finishing turn")
	is_turn_active = false
	emit_signal("turn_finished", self)

# Register with the TurnSequencer
func register_with_sequencer():
	if turn_sequencer:
		turn_sequencer.add_character(self)
	else:
		push_error(self.name + ": Cannot register with TurnSequencer - reference not found")
