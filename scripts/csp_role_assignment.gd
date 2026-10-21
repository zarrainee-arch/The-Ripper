
extends RefCounted
class_name CSPRoleAssignment

const ROLE_LEADER: String = "LEADER"
const ROLE_FOLLOWER: String = "FOLLOWER"
const ROLES: Array[String] = [ROLE_LEADER, ROLE_FOLLOWER]


# =========================================================
# MAIN SOLVER
# =========================================================

func solve(configuration: LocalSearch.NPCConfiguration) -> Dictionary:
	if configuration == null:
		return _failure("Konfigurasi tidak tersedia.")

	if not configuration.is_valid():
		return _failure("Konfigurasi tidak valid.")

	var npcs: Array[Dictionary] = _build_npc_list(configuration)

	if npcs.is_empty():
		return _failure("Tidak ada NPC untuk diberi peran.")

	var domains: Dictionary = {}

	for npc in npcs:
		domains[npc["npc_id"]] = ROLES.duplicate()

	# Satu NPC wajib menjadi Leader.
	if npcs.size() == 1:
		domains[npcs[0]["npc_id"]] = [ROLE_LEADER]

	# AC-3: konsistensi constraint antarvariabel.
	if not _ac3(npcs, domains):
		return _failure("AC-3 menemukan domain yang tidak konsisten.")

	var assignments: Dictionary = {}

	if not _backtrack(npcs, assignments, domains):
		return _failure("Tidak ditemukan solusi CSP.")

	if not validate_assignments(npcs, assignments):
		return _failure("Hasil penugasan melanggar constraint.")

	return {
		"success": true,
		"npcs": npcs,
		"assignments": assignments,
		"message": "Penugasan peran berhasil."
	}


# =========================================================
# BUILD NPC VARIABLES
# =========================================================

func _build_npc_list(
	configuration: LocalSearch.NPCConfiguration
) -> Array[Dictionary]:
	var npcs: Array[Dictionary] = []
	var npc_id: int = 1

	for type_index in range(configuration.composition.size()):
		var count: int = configuration.composition[type_index]
		var npc_type: String = LocalSearch.NPC_TYPES[type_index]

		for i in range(count):
			npcs.append({
				"npc_id": "NPC-%02d" % npc_id,
				"npc_type": npc_type
			})
			npc_id += 1

	return npcs


# =========================================================
# BACKTRACKING + MRV + LCV
# =========================================================

func _backtrack(
	npcs: Array[Dictionary],
	assignments: Dictionary,
	domains: Dictionary
) -> bool:
	if assignments.size() == npcs.size():
		return validate_assignments(npcs, assignments)

	# MRV: pilih variabel dengan domain tersisa paling sedikit.
	var npc_id: String = _select_mrv(npcs, assignments, domains)

	# LCV: coba nilai yang paling sedikit membatasi tetangga dahulu.
	var ordered_roles: Array = _order_lcv(
		npcs, npc_id, assignments, domains
	)

	for role in ordered_roles:
		var next_assignments: Dictionary = assignments.duplicate(true)
		next_assignments[npc_id] = role

		if not _is_partial_assignment_valid(npcs, next_assignments):
			continue

		var next_domains: Dictionary = domains.duplicate(true)
		next_domains[npc_id] = [role]

		# Forward checking: jika ada Leader, NPC lain tidak boleh Leader.
		if role == ROLE_LEADER:
			for other_npc in npcs:
				var other_id: String = other_npc["npc_id"]

				if other_id != npc_id and not next_assignments.has(other_id):
					next_domains[other_id].erase(ROLE_LEADER)

		if not _domains_are_valid(npcs, next_assignments, next_domains):
			continue

		# AC-3 setelah domain diperbarui.
		if not _ac3(npcs, next_domains):
			continue

		if _backtrack(npcs, next_assignments, next_domains):
			assignments.clear()
			for key in next_assignments:
				assignments[key] = next_assignments[key]
			return true

	return false


# MRV: domain terkecil; jika seri, urutan NPC menjadi tie-breaker.
func _select_mrv(
	npcs: Array[Dictionary],
	assignments: Dictionary,
	domains: Dictionary
) -> String:
	var selected_id: String = ""
	var smallest_domain: int = 999999

	for npc in npcs:
		var npc_id: String = npc["npc_id"]

		if assignments.has(npc_id):
			continue

		var domain_size: int = domains[npc_id].size()

		if domain_size < smallest_domain:
			smallest_domain = domain_size
			selected_id = npc_id

	return selected_id


# LCV: urutkan role berdasarkan jumlah nilai tetangga yang tetap tersedia.
func _order_lcv(
	npcs: Array[Dictionary],
	npc_id: String,
	assignments: Dictionary,
	domains: Dictionary
) -> Array:
	var scored_roles: Array[Dictionary] = []

	for role in domains[npc_id]:
		var eliminated_values: int = 0

		if role == ROLE_LEADER:
			for other_npc in npcs:
				var other_id: String = other_npc["npc_id"]

				if other_id == npc_id or assignments.has(other_id):
					continue

				if domains[other_id].has(ROLE_LEADER):
					eliminated_values += 1

		scored_roles.append({
			"role": role,
			"eliminated": eliminated_values
		})

	# Nilai dengan eliminasi paling sedikit dicoba terlebih dahulu.
	for i in range(scored_roles.size()):
		for j in range(i + 1, scored_roles.size()):
			if scored_roles[j]["eliminated"] < scored_roles[i]["eliminated"]:
				var temp: Dictionary = scored_roles[i]
				scored_roles[i] = scored_roles[j]
				scored_roles[j] = temp

	var result: Array = []

	for item in scored_roles:
		result.append(item["role"])

	return result


# =========================================================
# AC-3
# Binary constraint: dua NPC tidak boleh sama-sama Leader.
# =========================================================

func _ac3(
	npcs: Array[Dictionary],
	domains: Dictionary
) -> bool:
	var queue: Array[Array] = []

	for npc_a in npcs:
		for npc_b in npcs:
			var id_a: String = npc_a["npc_id"]
			var id_b: String = npc_b["npc_id"]

			if id_a != id_b:
				queue.append([id_a, id_b])

	while not queue.is_empty():
		var arc: Array = queue.pop_front()
		var id_a: String = arc[0]
		var id_b: String = arc[1]

		if _revise(id_a, id_b, domains):
			if domains[id_a].is_empty():
				return false

			for npc in npcs:
				var neighbor_id: String = npc["npc_id"]

				if neighbor_id != id_a and neighbor_id != id_b:
					queue.append([neighbor_id, id_a])

	return true


func _revise(
	id_a: String,
	id_b: String,
	domains: Dictionary
) -> bool:
	var revised: bool = false
	var values_to_remove: Array = []

	for role_a in domains[id_a]:
		var has_support: bool = false

		for role_b in domains[id_b]:
			# Constraint: bukan keduanya Leader.
			if not (role_a == ROLE_LEADER and role_b == ROLE_LEADER):
				has_support = true
				break

		if not has_support:
			values_to_remove.append(role_a)

	for role in values_to_remove:
		domains[id_a].erase(role)
		revised = true

	return revised


# =========================================================
# CONSTRAINT VALIDATION
# =========================================================

func _is_partial_assignment_valid(
	npcs: Array[Dictionary],
	assignments: Dictionary
) -> bool:
	var leader_count: int = 0

	for npc in npcs:
		var npc_id: String = npc["npc_id"]

		if not assignments.has(npc_id):
			continue

		var role: String = assignments[npc_id]

		if not ROLES.has(role):
			return false

		if role == ROLE_LEADER:
			leader_count += 1

	return leader_count <= 1


func _domains_are_valid(
	npcs: Array[Dictionary],
	assignments: Dictionary,
	domains: Dictionary
) -> bool:
	for npc in npcs:
		var npc_id: String = npc["npc_id"]

		if not assignments.has(npc_id) and domains[npc_id].is_empty():
			return false

	# Jika belum ada Leader dan semua domain tersisa tidak menyediakan
	# Leader, tidak mungkin memenuhi constraint tepat satu Leader.
	var leader_assigned: bool = false
	var leader_available: bool = false

	for npc in npcs:
		var npc_id: String = npc["npc_id"]

		if assignments.get(npc_id, "") == ROLE_LEADER:
			leader_assigned = true

		if not assignments.has(npc_id) and domains[npc_id].has(ROLE_LEADER):
			leader_available = true

	if not leader_assigned and not leader_available:
		return false

	return true


func validate_assignments(
	npcs: Array[Dictionary],
	assignments: Dictionary
) -> bool:
	if npcs.is_empty():
		return false

	if assignments.size() != npcs.size():
		return false

	var known_ids: Dictionary = {}
	var leader_count: int = 0

	for npc in npcs:
		var npc_id: String = npc["npc_id"]
		known_ids[npc_id] = true

		if not assignments.has(npc_id):
			return false

		var role: String = assignments[npc_id]

		if not ROLES.has(role):
			return false

		if role == ROLE_LEADER:
			leader_count += 1

	# Tolak ID tambahan yang tidak berasal dari konfigurasi.
	for assigned_id in assignments.keys():
		if not known_ids.has(assigned_id):
			return false

	# Satu NPC: harus Leader. Lebih dari satu: tepat satu Leader.
	return leader_count == 1


func _failure(message: String) -> Dictionary:
	return {
		"success": false,
		"npcs": [],
		"assignments": {},
		"message": message
	}



func run_csp_tests() -> void:
	var test_cases: Array = [
	[1, 1],
	[2, 1],
	[7, 1]
]

	print("\n===== CSP TESTING =====")

	for test_case in test_cases:
		var npc_count: int = test_case[0]
		var expected_leaders: int = test_case[1]

		var npcs: Array[Dictionary] = []

		for i in range(npc_count):
			npcs.append({
				"npc_id": "NPC-%02d" % (i + 1),
				"npc_type": "Street Thug"
			})

		var domains: Dictionary = {}

		for npc_data in npcs:
			domains[npc_data["npc_id"]] = ROLES.duplicate()

		if npc_count == 1:
			domains["NPC-01"] = [ROLE_LEADER]

		var assignments: Dictionary = {}
		var success: bool = (
			_ac3(npcs, domains)
			and _backtrack(npcs, assignments, domains)
		)

		var leader_count: int = 0

		for role in assignments.values():
			if role == ROLE_LEADER:
				leader_count += 1

		var valid: bool = (
			success
			and validate_assignments(npcs, assignments)
			and leader_count == expected_leaders
		)

		print(
			"NPC: ", npc_count,
			" | Assignments: ", assignments,
			" | Leaders: ", leader_count,
			" | ", "PASS" if valid else "FAIL"
		)
