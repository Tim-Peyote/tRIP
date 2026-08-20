class_name DeepGroveChunk
extends Node3D


func get_narrative_clues() -> Array[Node]:
	var result: Array[Node] = []
	for node: Node in find_children("*", "StaticBody3D", true, false):
		if node.has_signal("discovered"):
			result.append(node)
	return result


func get_emberberries() -> Array[HarvestableIngredient]:
	var result: Array[HarvestableIngredient] = []
	for node: Node in find_children("*", "HarvestableIngredient", true, false):
		var ingredient := node as HarvestableIngredient
		if ingredient.definition_id == &"ingredient.emberberry":
			result.append(ingredient)
	return result

