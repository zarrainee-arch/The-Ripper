
class_name FactManager
extends RefCounted

var facts: Array[Dictionary] = []
var current_turn: int = -1


# ==================================================
# ADD FACT
# ==================================================

func add_fact(
	predicate: String,
	subject: String,
	value = true,
	turn: int = -1,
	source: String = "battle",
	rule_id: String = ""
) -> void:
	var fact := {
		"predicate": predicate,
		"subject": subject,
		"value": value,
		"turn": turn,
		"source": source,
		"rule_id": rule_id
	}

	if not has_fact(predicate, subject, turn, value):
		facts.append(fact)


# ==================================================
# CHECK FACT
# ==================================================

func has_fact(
	predicate: String,
	subject: String,
	turn: int = -1,
	value = null
) -> bool:
	for fact in facts:
		if str(fact.get("predicate", "")) != predicate:
			continue

		if str(fact.get("subject", "")) != subject:
			continue

		if turn >= 0 and int(fact.get("turn", -1)) != turn:
			continue

		if value != null and fact.get("value") != value:
			continue

		return true

	return false


# ==================================================
# GET FACTS
# ==================================================

func get_facts() -> Array[Dictionary]:
	return facts.duplicate(true)


func get_facts_for_turn(turn: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	for fact in facts:
		var fact_turn := int(fact.get("turn", -1))

		if fact_turn == turn or fact_turn == -1:
			result.append(fact.duplicate(true))

	return result


# ==================================================
# BATTLE SYNCHRONIZATION
# ==================================================

func sync_npc_from_battle(
	npc: Dictionary,
	role: String,
	turn: int
) -> void:
	var npc_id := str(npc.get("npc_id", ""))

	if npc_id.is_empty():
		return

	var hp := float(npc.get("hp", 0))
	var max_hp := float(npc.get("max_hp", 0))
	var alive := hp > 0

	_replace_persistent_fact("alive", npc_id, alive)
	_replace_persistent_fact("role", npc_id, role)
	_replace_persistent_fact("hp", npc_id, hp)
	_replace_persistent_fact("max_hp", npc_id, max_hp)

	if bool(npc.get("has_turn", false)):
		add_fact("has_turn", npc_id, true, turn)

	if bool(npc.get("acted", false)):
		add_fact("acted", npc_id, true, turn)


func sync_target_from_battle(target_alive: bool) -> void:
	_replace_persistent_fact(
		"target_alive",
		"player",
		target_alive
	)


# ==================================================
# ACTION FACTS
# ==================================================

func record_leader_attack(
	leader_id: String,
	turn: int
) -> void:
	add_fact(
		"ally_attacked",
		leader_id,
		true,
		turn,
		"battle"
	)


func record_coordination_used(
	follower_id: String,
	turn: int
) -> void:
	add_fact(
		"coordination_used",
		follower_id,
		true,
		turn,
		"battle"
	)


func record_action(
	npc_id: String,
	turn: int
) -> void:
	add_fact(
		"acted",
		npc_id,
		true,
		turn,
		"battle"
	)


# ==================================================
# TURN MANAGEMENT
# ==================================================

func start_new_turn(turn: int) -> void:
	current_turn = turn

	var persistent_facts: Array[Dictionary] = []

	for fact in facts:
		if int(fact.get("turn", -1)) == -1:
			persistent_facts.append(fact)

	facts = persistent_facts


func clear_inferred_facts() -> void:
	var retained: Array[Dictionary] = []

	for fact in facts:
		if str(fact.get("source", "")) != "inferred":
			retained.append(fact)

	facts = retained


# ==================================================
# INTERNAL HELPERS
# ==================================================

func _replace_persistent_fact(
	predicate: String,
	subject: String,
	value
) -> void:
	for index in range(facts.size() - 1, -1, -1):
		var fact := facts[index]

		if (
			str(fact.get("predicate", "")) == predicate
			and str(fact.get("subject", "")) == subject
			and int(fact.get("turn", -1)) == -1
		):
			facts.remove_at(index)

	add_fact(
		predicate,
		subject,
		value,
		-1,
		"battle"
	)
