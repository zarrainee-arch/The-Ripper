
extends SceneTree

func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var csp := CSPRoleAssignment.new()

	_test_configuration(csp, [1, 0, 0], 1)
	_test_configuration(csp, [1, 1, 0], 2)
	_test_configuration(csp, [1, 1, 1], 3)
	_test_configuration(csp, [4, 3, 3], 10)
	_test_invalid_configuration(csp)
	_test_constraint_validation(csp)

	print("=== CSP TESTS FINISHED ===")
	quit()


func _test_configuration(
	csp: CSPRoleAssignment,
	composition: Array[int],
	expected_count: int
) -> void:
	var configuration := LocalSearch.NPCConfiguration.new(
		composition,
		"Knife",
		"Street Clothes"
	)

	var result: Dictionary = csp.solve(configuration)

	print("\n--- Test ", expected_count, " NPC ---")
	print("Success: ", result["success"])
	print("Message: ", result["message"])

	if not result["success"]:
		push_error("CSP gagal untuk konfigurasi %d NPC." % expected_count)
		return

	var npcs: Array[Dictionary] = result["npcs"]
	var assignments: Dictionary = result["assignments"]
	var leader_count: int = 0
	var follower_count: int = 0

	for npc in npcs:
		var npc_id: String = npc["npc_id"]
		var role: String = assignments[npc_id]

		print(npc_id, " (", npc["npc_type"], ") -> ", role)

		if role == CSPRoleAssignment.ROLE_LEADER:
			leader_count += 1
		elif role == CSPRoleAssignment.ROLE_FOLLOWER:
			follower_count += 1

	var passed: bool = (
		npcs.size() == expected_count
		and assignments.size() == expected_count
		and leader_count == 1
		and follower_count == expected_count - 1
		and csp.validate_assignments(npcs, assignments)
	)

	if passed:
		print("RESULT: PASS")
	else:
		push_error("RESULT: FAIL untuk konfigurasi %d NPC." % expected_count)


func _test_invalid_configuration(csp: CSPRoleAssignment) -> void:
	var configuration := LocalSearch.NPCConfiguration.new(
		[0, 0, 0],
		"Knife",
		"Street Clothes"
	)

	var result: Dictionary = csp.solve(configuration)

	print("\n--- Test Invalid Configuration ---")
	print("Success: ", result["success"])
	print("Message: ", result["message"])

	if not result["success"]:
		print("RESULT: PASS")
	else:
		push_error("CSP seharusnya menolak konfigurasi tidak valid.")


func _test_constraint_validation(csp: CSPRoleAssignment) -> void:
	var configuration := LocalSearch.NPCConfiguration.new(
		[1, 1, 1],
		"Knife",
		"Street Clothes"
	)

	var result: Dictionary = csp.solve(configuration)

	if not result["success"]:
		push_error("Setup constraint test gagal.")
		return

	var npcs: Array[Dictionary] = result["npcs"]
	var valid_assignments: Dictionary = result["assignments"]

	# Kasus 1: dua Leader harus ditolak.
	var two_leaders: Dictionary = valid_assignments.duplicate(true)
	two_leaders["NPC-01"] = CSPRoleAssignment.ROLE_LEADER
	two_leaders["NPC-02"] = CSPRoleAssignment.ROLE_LEADER

	var reject_two_leaders: bool = not csp.validate_assignments(
		npcs, two_leaders
	)

	# Kasus 2: tidak ada Leader harus ditolak.
	var no_leader: Dictionary = valid_assignments.duplicate(true)
	for npc in npcs:
		no_leader[npc["npc_id"]] = CSPRoleAssignment.ROLE_FOLLOWER

	var reject_no_leader: bool = not csp.validate_assignments(
		npcs, no_leader
	)

	# Kasus 3: ID NPC asing harus ditolak.
	var unknown_npc: Dictionary = valid_assignments.duplicate(true)
	unknown_npc.erase("NPC-03")
	unknown_npc["NPC-99"] = CSPRoleAssignment.ROLE_FOLLOWER
	
	var reject_unknown_npc: bool = not csp.validate_assignments(
		npcs, unknown_npc
	)

	print("\n--- Constraint Validation Tests ---")
	print("Reject two Leaders: ", reject_two_leaders)
	print("Reject no Leader: ", reject_no_leader)
	print("Reject unknown NPC: ", reject_unknown_npc)

	if reject_two_leaders and reject_no_leader and reject_unknown_npc:
		print("RESULT: PASS")
	else:
		push_error("Constraint validation test gagal.")
