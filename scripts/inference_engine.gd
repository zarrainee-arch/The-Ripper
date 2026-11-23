
class_name InferenceEngine
extends RefCounted

const DECISION_NONE := "NONE"
const DECISION_NORMAL := "NORMAL_ATTACK"
const DECISION_COORDINATED := "COORDINATED_ATTACK"
const DECISION_WAIT := "WAIT"

var knowledge_base: KnowledgeBase
var inference_log: InferenceLog
var inference_counter: int = 0


func _init(kb: KnowledgeBase = null, log: InferenceLog = null) -> void:
	knowledge_base = kb if kb != null else KnowledgeBase.new()
	inference_log = log if log != null else InferenceLog.new()


func infer(
	facts: Array[Dictionary],
	subject: String,
	turn: int,
	wait_supported: bool = false
) -> Dictionary:
	inference_counter += 1

	var working_facts := facts.duplicate(true)
	var rules_checked: Array[Dictionary] = []
	var matched_rules: Array[String] = []
	var inferred_facts: Array[Dictionary] = []

	var npc_alive := _has_fact(working_facts, "alive", subject)
	var has_turn := _has_fact(working_facts, "has_turn", subject, turn)
	var target_alive := _has_fact(working_facts, "target_alive", "player")
	var acted := _has_fact(working_facts, "acted", subject, turn)
	var role := _get_role(working_facts, subject)
	var leader_id := _find_leader(working_facts)
	var leader_alive := not leader_id.is_empty() and _has_fact(working_facts, "alive", leader_id)
	var leader_attacked := not leader_id.is_empty() and _has_fact(working_facts, "ally_attacked", leader_id, turn)
	var coordination_used := _has_fact(working_facts, "coordination_used", subject, turn)
	var coordinated := _has_fact(working_facts, "coordinated_attack", subject, turn)
	var wait_advised := _has_fact(working_facts, "wait_advised", subject, turn)

	var can_act := npc_alive and has_turn and target_alive and not acted
	_record_rule(rules_checked, matched_rules, "R0", can_act, "Requires alive, has_turn, target_alive and not acted.", {"subject": subject})

	_record_rule(rules_checked, matched_rules, "R6", not npc_alive, "NPC is dead.", {"subject": subject})

	if role == "LEADER" and npc_alive and has_turn and target_alive and not acted:
		_record_rule(rules_checked, matched_rules, "R1", true, "Leader is eligible to act; attack confirmation must come from battle.", {"subject": subject})
	else:
		_record_rule(rules_checked, matched_rules, "R1", false, "Subject is not an eligible living Leader.", {"subject": subject})

	var is_follower := role == "FOLLOWER"
	var can_coordinate := (
		is_follower
		and can_act
		and leader_alive
		and leader_attacked
		and not coordination_used
	)

	_record_rule(rules_checked, matched_rules, "R2", can_coordinate, "Requires living Leader attack, living Follower, unused coordination and action slot.", {"subject": subject, "leader": leader_id})

	var is_low_hp := _is_low_hp(working_facts, subject)
	var should_wait := wait_supported and is_follower and can_act and is_low_hp

	_record_rule(rules_checked, matched_rules, "R9", should_wait, "WAIT is advised for low-HP Follower only when supported.", {"subject": subject})

	if coordination_used:
		_record_rule(rules_checked, matched_rules, "R4", true, "Coordination already used this turn.", {"subject": subject})
	else:
		_record_rule(rules_checked, matched_rules, "R4", false, "Coordination has not been used.", {"subject": subject})

	var no_leader_attack := not leader_alive or not leader_attacked
	_record_rule(rules_checked, matched_rules, "R5", no_leader_attack, "Leader is dead or has not attacked.", {"leader": leader_id})

	var decision := DECISION_NONE
	var reason := "No valid action could be inferred."
	var fallback_used := false

	if not npc_alive:
		reason = "R6: dead NPC cannot act."
	elif not can_act:
		reason = "R0: NPC is not eligible to act."
	elif coordination_used:
		reason = "R4: coordination already used this turn."
	elif wait_advised or should_wait:
		decision = DECISION_WAIT
		reason = "R9: low-HP Follower is advised to wait."
	elif can_coordinate:
		decision = DECISION_COORDINATED
		reason = "R2 and R3: coordinated attack is authorized."
		_record_rule(rules_checked, matched_rules, "R3", true, reason, {"subject": subject})
	else:
		_record_rule(rules_checked, matched_rules, "R3", false, "No coordinated attack facts matched.", {"subject": subject})

		var normal_allowed := npc_alive and has_turn and target_alive and not acted
		_record_rule(rules_checked, matched_rules, "R7", normal_allowed, "Normal attack fallback requires a valid remaining action slot and living target.", {"subject": subject})

		if normal_allowed:
			decision = DECISION_NORMAL
			reason = "R7: normal attack fallback."
			fallback_used = true

	if not matched_rules.has("R8"):
		_record_rule(rules_checked, matched_rules, "R8", false, "Promotion is a phase transition and must be handled at round refresh.", {})

	var result := {
		"inference_id": inference_counter,
		"turn": turn,
		"subject": subject,
		"facts_in": facts.duplicate(true),
		"rules_checked": rules_checked,
		"matched_rules": matched_rules,
		"inferred_facts": inferred_facts,
		"decision": decision,
		"reason": reason,
		"fallback_used": fallback_used
	}

	inference_log.log_inference(result)
	return result


func _record_rule(
	checked: Array[Dictionary],
	matched: Array[String],
	rule_id: String,
	did_match: bool,
	reason: String,
	bindings: Dictionary
) -> void:
	var rule := knowledge_base.get_rule(rule_id)
	var description := str(rule.get("description", ""))

	checked.append({
		"rule_id": rule_id,
		"matched": did_match,
		"why": reason,
		"description": description,
		"bindings": bindings.duplicate(true)
	})

	if did_match:
		matched.append(rule_id)


func _has_fact(
	facts: Array[Dictionary],
	predicate: String,
	subject: String,
	turn: int = -1
) -> bool:
	for fact in facts:
		if str(fact.get("predicate", "")) != predicate:
			continue
		if str(fact.get("subject", "")) != subject:
			continue
		if turn >= 0 and int(fact.get("turn", -1)) != turn:
			continue
		return true
	return false


func _get_role(facts: Array[Dictionary], subject: String) -> String:
	for fact in facts:
		if str(fact.get("predicate", "")) == "role" and str(fact.get("subject", "")) == subject:
			return str(fact.get("value", "")).to_upper()
	return ""


func _find_leader(facts: Array[Dictionary]) -> String:
	for fact in facts:
		if str(fact.get("predicate", "")) == "role" and str(fact.get("value", "")).to_upper() == "LEADER":
			return str(fact.get("subject", ""))
	return ""


func _is_low_hp(facts: Array[Dictionary], subject: String) -> bool:
	var current_hp := -1.0
	var max_hp := -1.0

	for fact in facts:
		if str(fact.get("subject", "")) != subject:
			continue
		match str(fact.get("predicate", "")):
			"hp":
				current_hp = float(fact.get("value", -1))
			"max_hp":
				max_hp = float(fact.get("value", -1))

	return max_hp > 0.0 and current_hp >= 0.0 and current_hp / max_hp < 0.25
