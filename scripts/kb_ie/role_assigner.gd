
class_name RoleAssigner
extends RefCounted

const ROLE_LEADER := "LEADER"
const ROLE_FOLLOWER := "FOLLOWER"

const POWER_BY_TYPE := {
	"Street Thug": 10,
	"Knife Thug": 15,
	"Heavy Enforcer": 20
}


func assign_roles(npcs: Array) -> Dictionary:
	var result := {}
	var candidates: Array[Dictionary] = []

	for npc in npcs:
		if not npc is Dictionary:
			continue

		var npc_id = npc.get("npc_id", null)
		if npc_id == null:
			continue

		candidates.append({
			"npc_id": npc_id,
			"base_power": _get_base_power(npc)
		})

	if candidates.is_empty():
		return result

	candidates.sort_custom(_leader_precedes)

	var leader_id = candidates[0]["npc_id"]

	for candidate in candidates:
		var npc_id = candidate["npc_id"]
		result[str(npc_id)] = (
			ROLE_LEADER if str(npc_id) == str(leader_id)
			else ROLE_FOLLOWER
		)

	return result


func promote_after_leader_down(
	npcs: Array,
	current_roles: Dictionary
) -> Dictionary:
	var updated_roles := current_roles.duplicate(true)
	var candidates: Array[Dictionary] = []

	for npc in npcs:
		if not npc is Dictionary:
			continue

		var npc_id = npc.get("npc_id", null)
		if npc_id == null:
			continue

		var id := str(npc_id)
		var current_role := str(updated_roles.get(id, ROLE_FOLLOWER))

		if current_role == ROLE_LEADER:
			if float(npc.get("hp", 0)) <= 0:
				updated_roles[id] = ROLE_FOLLOWER
			continue

		if float(npc.get("hp", 0)) > 0:
			candidates.append({
				"npc_id": npc_id,
				"base_power": _get_base_power(npc)
			})

	if candidates.is_empty():
		return updated_roles

	candidates.sort_custom(_leader_precedes)

	var new_leader_id := str(candidates[0]["npc_id"])
	updated_roles[new_leader_id] = ROLE_LEADER

	return updated_roles


func _get_base_power(npc: Dictionary) -> int:
	if npc.has("base_power"):
		return int(npc["base_power"])

	var npc_type := str(npc.get("npc_type", npc.get("type", "")))
	return int(POWER_BY_TYPE.get(npc_type, 0))


func _leader_precedes(a: Dictionary, b: Dictionary) -> bool:
	var power_a := int(a["base_power"])
	var power_b := int(b["base_power"])

	if power_a != power_b:
		return power_a > power_b

	return _numeric_id(a["npc_id"]) < _numeric_id(b["npc_id"])


func _numeric_id(value) -> int:
	var text_id := str(value)
	var parts := text_id.split("-")
	var suffix := parts[parts.size() - 1]

	return int(suffix) if suffix.is_valid_int() else 2147483647
