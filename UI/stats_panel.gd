extends PanelContainer

signal stat_upgraded(stat_type)

# Constants for stat types
enum StatType { HP, AP, MP }

# Connected entity
var connected_entity: PlayerEntity = null

# Base upgrade costs
var hp_upgrade_cost: int = 20
var ap_upgrade_cost: int = 25
var mp_upgrade_cost: int = 25

# Cost multiplier per upgrade
var cost_multiplier: float = 1.3

# Track number of upgrades for each stat
var hp_upgrades: int = 0
var ap_upgrades: int = 0
var mp_upgrades: int = 0

# UI Elements
@onready var hp_val_label: Label = $StatsMargin/StatsVBox/HPHBox/HPLabels/HPVal
@onready var ap_val_label: Label = $StatsMargin/StatsVBox/APHBox/APLabels/APVal
@onready var mp_val_label: Label = $StatsMargin/StatsVBox/MPHBox/MPLabels/MPVal

@onready var hp_cost_label: Label = $StatsMargin/StatsVBox/HPHBox/HPIncCost
@onready var ap_cost_label: Label = $StatsMargin/StatsVBox/APHBox/HPIncCost
@onready var mp_cost_label: Label = $StatsMargin/StatsVBox/MPHBox/HPIncCost

@onready var hp_upgrade_button: Button = $StatsMargin/StatsVBox/HPHBox/HPInc
@onready var ap_upgrade_button: Button = $StatsMargin/StatsVBox/APHBox/HPInc
@onready var mp_upgrade_button: Button = $StatsMargin/StatsVBox/MPHBox/HPInc

func _ready():
	# Connect button signals
	hp_upgrade_button.pressed.connect(_on_hp_upgrade_pressed)
	ap_upgrade_button.pressed.connect(_on_ap_upgrade_pressed)
	mp_upgrade_button.pressed.connect(_on_mp_upgrade_pressed)
	
	# Initially disable buttons until entity is connected
	_update_button_states()

# Connect the panel to a specific entity
func connect_to_entity(entity: PlayerEntity):
	# Disconnect from previous entity if exists
	if connected_entity:
		_disconnect_entity_signals()
	
	# Set new entity
	connected_entity = entity
	
	if connected_entity:
		# Connect signals
		connected_entity.health_changed.connect(_on_health_changed)
		connected_entity.action_points_changed.connect(_on_ap_changed)
		connected_entity.movement_points_changed.connect(_on_mp_changed)
		
		# Update displays
		_update_hp_display()
		_update_ap_display()
		_update_mp_display()
		_update_cost_labels()
		_update_button_states()
	else:
		# Reset displays if no entity
		hp_val_label.text = "0/0"
		ap_val_label.text = "0"
		mp_val_label.text = "0"
		
		# Disable buttons
		hp_upgrade_button.disabled = true
		ap_upgrade_button.disabled = true
		mp_upgrade_button.disabled = true

# Disconnect signals when entity changes
func _disconnect_entity_signals():
	if connected_entity:
		if connected_entity.is_connected("health_changed", _on_health_changed):
			connected_entity.health_changed.disconnect(_on_health_changed)
		if connected_entity.is_connected("action_points_changed", _on_ap_changed):
			connected_entity.action_points_changed.disconnect(_on_ap_changed)
		if connected_entity.is_connected("movement_points_changed", _on_mp_changed):
			connected_entity.movement_points_changed.disconnect(_on_mp_changed)

# Signal handlers
func _on_health_changed(current, maximum):
	_update_hp_display()
	_update_button_states()

func _on_ap_changed(current, maximum):
	_update_ap_display()
	_update_button_states()

func _on_mp_changed(current, maximum):
	_update_mp_display()
	_update_button_states()

# Button handlers
func _on_hp_upgrade_pressed():
	if connected_entity and can_afford_upgrade(StatType.HP):
		if connected_entity.current_health < connected_entity.max_health:
			# Just heal if not at max health
			var heal_cost = hp_upgrade_cost / 2
			connected_entity.experience -= heal_cost
			connected_entity.heal_damage(connected_entity.max_health)
		else:
			# Upgrade max health
			connected_entity.experience -= get_upgrade_cost(StatType.HP)
			connected_entity.max_health += 2
			connected_entity.heal_damage(2) # Also heal by the amount increased
			hp_upgrades += 1
		
		_update_cost_labels()
		_update_button_states()
		emit_signal("stat_upgraded", StatType.HP)

func _on_ap_upgrade_pressed():
	if connected_entity and can_afford_upgrade(StatType.AP):
		connected_entity.experience -= get_upgrade_cost(StatType.AP)
		connected_entity.max_action_points += 1
		connected_entity.action_points += 1
		ap_upgrades += 1
		
		_update_cost_labels()
		_update_button_states()
		emit_signal("stat_upgraded", StatType.AP)

func _on_mp_upgrade_pressed():
	if connected_entity and can_afford_upgrade(StatType.MP):
		connected_entity.experience -= get_upgrade_cost(StatType.MP)
		connected_entity.max_movement_points += 1
		connected_entity.movement_points += 1
		mp_upgrades += 1
		
		_update_cost_labels()
		_update_button_states()
		emit_signal("stat_upgraded", StatType.MP)

# Update UI displays
func _update_hp_display():
	if connected_entity:
		hp_val_label.text = str(connected_entity.current_health) + "/" + str(connected_entity.max_health)

func _update_ap_display():
	if connected_entity:
		ap_val_label.text = str(connected_entity.action_points) + "/" + str(connected_entity.max_action_points)

func _update_mp_display():
	if connected_entity:
		mp_val_label.text = str(connected_entity.movement_points) + "/" + str(connected_entity.max_movement_points)

func _update_cost_labels():
	hp_cost_label.text = "(" + str(get_upgrade_cost(StatType.HP)) + ")"
	ap_cost_label.text = "(" + str(get_upgrade_cost(StatType.AP)) + ")"
	mp_cost_label.text = "(" + str(get_upgrade_cost(StatType.MP)) + ")"

# Calculate upgrade costs based on number of previous upgrades
func get_upgrade_cost(stat_type: StatType) -> int:
	var base_cost: int
	var num_upgrades: int
	
	match stat_type:
		StatType.HP:
			base_cost = hp_upgrade_cost
			num_upgrades = hp_upgrades
			# If not at full health, healing costs less
			if connected_entity and connected_entity.current_health < connected_entity.max_health:
				return base_cost / 2
		StatType.AP:
			base_cost = ap_upgrade_cost
			num_upgrades = ap_upgrades
		StatType.MP:
			base_cost = mp_upgrade_cost
			num_upgrades = mp_upgrades
	
	return int(base_cost * pow(cost_multiplier, num_upgrades))

# Check if player can afford an upgrade
func can_afford_upgrade(stat_type: StatType) -> bool:
	if not connected_entity:
		return false
		
	return connected_entity.experience >= get_upgrade_cost(stat_type)

# Update button enabled/disabled states based on affordability
func _update_button_states():
	if connected_entity:
		hp_upgrade_button.disabled = not can_afford_upgrade(StatType.HP)
		ap_upgrade_button.disabled = not can_afford_upgrade(StatType.AP)
		mp_upgrade_button.disabled = not can_afford_upgrade(StatType.MP)
	else:
		hp_upgrade_button.disabled = true
		ap_upgrade_button.disabled = true
		mp_upgrade_button.disabled = true
