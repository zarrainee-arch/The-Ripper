
class_name KnowledgeBase
extends RefCounted

const R0 := "R0"
const R1 := "R1"
const R2 := "R2"
const R3 := "R3"
const R4 := "R4"
const R5 := "R5"
const R6 := "R6"
const R7 := "R7"
const R8 := "R8"
const R9 := "R9"

var rules: Array[Dictionary] = []


func _init() -> void:
	load_default_rules()


func load_default_rules() -> void:
	rules = [
		{"id": R0, "priority": 0, "description": "NPC can act when alive, has turn, target alive and not acted."},
		{"id": R1, "priority": 1, "description": "Confirmed Leader attack establishes ally_attacked."},
		{"id": R2, "priority": 2, "description": "Leader attack enables eligible Follower coordination."},
		{"id": R3, "priority": 3, "description": "Eligible coordination produces COORDINATED_ATTACK decision."},
		{"id": R4, "priority": 4, "description": "Prevent a second coordination in the same turn."},
		{"id": R5, "priority": 5, "description": "No coordination if Leader is dead or has not attacked."},
		{"id": R6, "priority": 6, "description": "Dead NPC cannot act."},
		{"id": R7, "priority": 7, "description": "Normal attack fallback when coordination does not apply."},
		{"id": R8, "priority": 8, "description": "Promote strongest living Follower after Leader death."},
		{"id": R9, "priority": 9, "description": "Advise low-HP Follower to wait when WAIT is supported."}
	]


func get_rules() -> Array[Dictionary]:
	return rules.duplicate(true)


func get_rule(rule_id: String) -> Dictionary:
	for rule in rules:
		if str(rule.get("id", "")) == rule_id:
			return rule.duplicate(true)
	return {}


func set_rule(rule_id: String, updates: Dictionary) -> bool:
	for index in range(rules.size()):
		if str(rules[index].get("id", "")) == rule_id:
			for key in updates:
				rules[index][key] = updates[key]
			return true
	return false


func add_rule(rule: Dictionary) -> bool:
	var rule_id := str(rule.get("id", ""))
	if rule_id.is_empty() or not get_rule(rule_id).is_empty():
		return false

	rules.append(rule.duplicate(true))
	return true


func remove_rule(rule_id: String) -> bool:
	for index in range(rules.size()):
		if str(rules[index].get("id", "")) == rule_id:
			rules.remove_at(index)
			return true
	return false
