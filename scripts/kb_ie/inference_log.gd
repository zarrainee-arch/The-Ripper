
class_name InferenceLog
extends RefCounted

var entries: Array[Dictionary] = []


func add_entry(entry: Dictionary) -> void:
	entries.append(entry.duplicate(true))


func log_rule_check(
	rule_id: String,
	matched: bool,
	reason: String,
	bindings: Dictionary = {}
) -> void:
	add_entry({
		"type": "rule_check",
		"rule_id": rule_id,
		"matched": matched,
		"reason": reason,
		"bindings": bindings.duplicate(true)
	})


func log_inference(result: Dictionary) -> void:
	add_entry({
		"type": "inference",
		"data": result.duplicate(true)
	})


func get_entries() -> Array[Dictionary]:
	return entries.duplicate(true)


func clear() -> void:
	entries.clear()


func get_entries_for_turn(turn: int) -> Array[Dictionary]:
	var filtered: Array[Dictionary] = []

	for entry in entries:
		var data = entry.get("data", entry)
		if int(data.get("turn", -1)) == turn:
			filtered.append(entry.duplicate(true))

	return filtered
