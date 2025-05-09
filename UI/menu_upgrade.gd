extends CanvasLayer
class_name UpgradeMenu

signal upgrade_exit

@onready var heavy_upgrade: Node = $UpgradeMargin/UpgradePanel/UpgradeHBoxMargin/UpgradeVBox/Heavy
@onready var scout_upgrade: Node = $UpgradeMargin/UpgradePanel/UpgradeHBoxMargin/UpgradeVBox/Scout
@onready var wizard_upgrade: Node = $UpgradeMargin/UpgradePanel/UpgradeHBoxMargin/UpgradeVBox/Wizard

func _ready() -> void:
	Global.upgrade_menu = self

func _on_exit_button_pressed() -> void:
	upgrade_exit.emit()

func _bind_player(player: PlayerEntity, upgrader: Node) -> void:
	upgrader.get_node("StatsPanel").connect_to_entity(player)
	
	# Connect ability panels to the player entity
	for child in upgrader.get_children():
		if child is PanelContainer and child.name.begins_with("AbilityPanel"):
			if child.has_signal("button_pressed"):
				child.button_pressed.connect(
					func(ability_panel):
						if player.has_method("unlock_ability"):
							player.unlock_ability(ability_panel.ability_name)
				)

func connect_to_entity(entity: PlayerEntity) -> void:
	if entity is HeavyPlayer:
		_bind_player(entity, heavy_upgrade)
	elif entity is ScoutPlayer:
		_bind_player(entity, scout_upgrade)
	elif entity is WizardPlayer:
		_bind_player(entity, wizard_upgrade)
