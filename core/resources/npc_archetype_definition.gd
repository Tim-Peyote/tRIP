class_name NPCArchetypeDefinition
extends ContentDefinition

enum EncounterRole { GUIDE, WITNESS, TRADER, RIVAL, KEEPER, APPARITION, ANTAGONIST }
enum Persistence { FIXED_STORY, SEED_WANDERER, CONDITIONAL, MEMORY_ONLY }

@export_category("Dramatic contract")
@export var world_phase_ids: Array[StringName] = []
@export var encounter_role: EncounterRole = EncounterRole.WITNESS
@export var persistence: Persistence = Persistence.CONDITIONAL
@export var affiliation: StringName = &"unaffiliated"
@export_multiline var occupation: String
@export_multiline var public_goal: String
@export_multiline var private_need: String
@export_multiline var secret: String
@export var relationship_keys: Array[StringName] = []

@export_category("Character sheet")
@export_multiline var silhouette_notes: String
@export_multiline var clothing_layers: String
@export var carried_gear: Array[String] = []
@export var palette: PackedColorArray = []
@export var expression_states: Array[StringName] = [&"neutral", &"wary", &"focused"]
@export var animation_states: Array[StringName] = [&"idle", &"notice", &"talk", &"work", &"leave"]
@export var personality_traits: Array[String] = []
@export var dialogue_themes: Array[String] = []
@export_multiline var encounter_rules: String
@export_multiline var lore_note: String


func validate() -> PackedStringArray:
	var messages := super.validate()
	if world_phase_ids.is_empty():
		messages.append("NPC '%s' has no world phase." % id)
	if occupation.strip_edges().is_empty():
		messages.append("NPC '%s' has no occupation." % id)
	if public_goal.strip_edges().is_empty() or secret.strip_edges().is_empty():
		messages.append("NPC '%s' needs a public goal and a secret." % id)
	if silhouette_notes.strip_edges().is_empty() or clothing_layers.strip_edges().is_empty():
		messages.append("NPC '%s' lacks a complete character sheet." % id)
	return messages
