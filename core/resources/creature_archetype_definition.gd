class_name CreatureArchetypeDefinition
extends ContentDefinition

enum BodyPlan { UNGULATE, PREDATOR, BEAR, SMALL_MAMMAL, BIRD, SERPENT, INSECT, OTHER }
enum Temperament { SHY, WATCHFUL, TERRITORIAL, PREDATORY, CURIOUS, MYTHIC }
enum ActivityWindow { DAY, NIGHT, CREPUSCULAR, ANY }

@export_category("Ecology")
@export var world_phase_ids: Array[StringName] = []
@export var body_plan: BodyPlan = BodyPlan.UNGULATE
@export var temperament: Temperament = Temperament.SHY
@export var activity_window: ActivityWindow = ActivityWindow.ANY
@export_range(0.0, 1.0, 0.01) var spawn_weight: float = 0.5
@export_range(1, 8, 1) var group_min: int = 1
@export_range(1, 12, 1) var group_max: int = 1
@export_range(0.2, 8.0, 0.1) var move_speed: float = 2.0
@export_range(2.0, 50.0, 0.5) var awareness_distance: float = 14.0
@export_range(2.0, 40.0, 0.5) var flee_distance: float = 9.0
@export var habitat_tags: Array[StringName] = []
@export var diet_tags: Array[StringName] = []

@export_category("Character sheet")
@export_multiline var natural_basis: String
@export_multiline var silhouette_notes: String
@export var body_color: Color = Color(0.34, 0.26, 0.18)
@export var accent_color: Color = Color(0.72, 0.58, 0.32)
@export_range(0.25, 3.0, 0.05) var visual_scale: float = 1.0
@export var animation_states: Array[StringName] = [&"idle", &"notice", &"turn", &"walk", &"flee"]
@export var behavior_traits: Array[String] = []
@export var gameplay_tells: Array[String] = []
@export var player_interactions: Array[StringName] = [&"observe"]
@export_multiline var world_layer_mutation: String
@export_multiline var lore_note: String


func validate() -> PackedStringArray:
	var messages := super.validate()
	if world_phase_ids.is_empty():
		messages.append("Creature '%s' has no world phase." % id)
	if group_max < group_min:
		messages.append("Creature '%s' has an invalid group range." % id)
	if natural_basis.strip_edges().is_empty():
		messages.append("Creature '%s' has no natural basis." % id)
	if silhouette_notes.strip_edges().is_empty():
		messages.append("Creature '%s' has no silhouette specification." % id)
	if animation_states.size() < 4:
		messages.append("Creature '%s' needs at least four animation states." % id)
	return messages
