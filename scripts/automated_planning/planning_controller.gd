extends RefCounted
class_name PlanningController

const DOMAIN = preload("res://scripts/automated_planning/planning_domain.gd")
const PLANNER = preload("res://scripts/automated_planning/planner.gd")
const LOG_SCRIPT = preload("res://scripts/automated_planning/planning_log.gd")

const DECISION_MODEL = preload("res://scripts/automated_planning/decision_model.gd")
const EXPECTED_UTILITY = preload("res://scripts/automated_planning/expected_utility.gd")
const MDP_SOLVER = preload("res://scripts/automated_planning/mdp_solver.gd")

const MAX_REPLAN := 1
const VALID_BATTLE_STATUS := ["executed", "rejected", "error"]

const REASON_REPLACED_BY_REPLAN := "plan_replaced_by_replan"
const REASON_REPLACED_BY_FALLBACK := "plan_replaced_by_fallback"
const REASON_CANCELLED_BATTLE_ENDED := "plan_cancelled_battle_ended"
const REASON_CANCELLED_NO_VALID_ACTION := "plan_cancelled_no_valid_action"
const REASON_CANCELLED_SNAPSHOT_INVALID := "plan_cancelled_snapshot_invalid"

# Konfigurasi Decision Making Under Uncertainty
var uncertainty_model_config: Dictionary = {}
var uncertainty_utility_map: Dictionary = {}

# Provider untuk mengambil data dari komponen lain
var uncertainty_belief_provider: Callable = Callable()
var uncertainty_transition_provider: Callable = Callable()
var uncertainty_meu_provider: Callable = Callable()

# Hasil rekomendasi Decision Making Under Uncertainty
var uncertainty_advisory: Dictionary = {}
var uncertainty_is_configured: bool = false

# Parameter perhitungan
var uncertainty_probability_tolerance: float = 0.000001
var uncertainty_comparison_tolerance: float = 0.000001
var uncertainty_epsilon: float = 0.001
var uncertainty_max_iterations: int = 1000

# Mode default sesuai kontrak, yaitu UCS.
var planner_mode: String = PLANNER.MODE_UCS
var planning_log = LOG_SCRIPT.new()

# Menyimpan state, plan, dan posisi langkah yang sedang dijalankan.
var current_state: Dictionary = {}
var current_plan: Dictionary = {}
var current_turn: int = 0
var current_step: int = 0

# Satu kesempatan replan untuk setiap fase NPC.
var replan_count: int = 0

var phase_finished: bool = false
var battle_ended: bool = false
var active_plan_is_fallback: bool = false

# NPC yang slotnya dilewati. Skipped tidak sama dengan resolved.
var skipped_npcs: Array = []

# Provider snapshot digunakan untuk mengambil kondisi battle terbaru.
var _snapshot_fn: Callable = Callable()

# Menyimpan aksi yang benar-benar sudah dikirim ke battle.
var _sent_keys: Array = []

# Mencegah sinkronisasi snapshot dilakukan berulang tanpa perubahan state.
var _fresh: bool = false

# Reset seluruh data ketika battle baru dimulai.
func reset_for_new_battle() -> void:
	planning_log.clear_log()
	current_state.clear()
	current_plan.clear()
	current_turn = 0
	current_step = 0
	replan_count = 0
	phase_finished = false
	battle_ended = false
	active_plan_is_fallback = false
	skipped_npcs.clear()
	_sent_keys.clear()
	_snapshot_fn = Callable()
	_fresh = false

# Membentuk state awal dan mencari plan untuk fase NPC.
func start_npc_phase(turn: int, npcs: Array, target_alive: bool, wait_supported: bool = false, wait_advised_ids: Array = []) -> Dictionary:
	current_turn = turn
	current_step = 0
	replan_count = 0
	phase_finished = false
	battle_ended = false
	active_plan_is_fallback = false
	skipped_npcs.clear()
	_sent_keys.clear()

	current_state = DOMAIN.create_initial_state(npcs, target_alive, wait_supported, wait_advised_ids)
	current_plan = PLANNER.find_plan(current_state, planner_mode)
	planning_log.log_plan(current_turn, current_plan)

	# State awal sudah dibentuk berdasarkan snapshot battle.
	_fresh = true

	if not target_alive:
		_stop_phase("battle_ended")
		return current_plan.duplicate(true)

	if current_plan.get("status", "") == "no_plan":
		if not _install_fallback_plan("planner_no_plan: " + str(current_plan.get("reason", "unknown"))):
			_mark_unresolved_as_skipped("no_valid_fallback_action")
			_finish_phase()
	elif current_plan.get("status", "") == "goal_already_true":
		_finish_phase()

	return current_plan.duplicate(true)


# Mengambil snapshot terbaru agar validasi dan replan tidak menggunakan state lama.
func _sync_from_provider(force: bool = false) -> bool:
	if not _snapshot_fn.is_valid():
		return true

	if _fresh and not force:
		return true

	var snap: Variant = _snapshot_fn.call()
	var snap_error := _snapshot_error(snap)

	if snap_error != "":
		_fresh = false
		_log_integration_error("snapshot", snap_error)
		return false

	synchronize_battle_state(snap["npcs"], bool(snap["target_alive"]))
	_fresh = true
	return true

# Menghentikan fase jika snapshot battle tidak dapat dipastikan valid.
func _abort_stale_state(exclude_action: Dictionary = {}) -> void:
	_stop_phase("snapshot_invalid", exclude_action, false)

# Membatalkan langkah yang belum dijalankan agar tidak menyisakan status pending.
# exclude_action melindungi aksi yang sudah memiliki status final.
func _cancel_pending_steps(reason: String, exclude_action: Dictionary = {}) -> void:
	var steps: Array = current_plan.get("steps", [])

	for i in range(current_step, steps.size()):
		var step: Dictionary = steps[i]

		if not exclude_action.is_empty() and str(step.get("action", "")) == str(exclude_action.get("type", "")) and str(step.get("npc", "")) == str(exclude_action.get("npc", "")):
			continue

		planning_log.log_plan_step_cancelled(current_turn, step, reason)

# Mencatat pembatalan satu aksi ke planning log.
func _log_action_cancelled(action: Dictionary, reason: String) -> void:
	planning_log.log_plan_step_cancelled(current_turn, {
		"action": str(action.get("type", "")),
		"npc": str(action.get("npc", "")),
		"cost": int(action.get("cost", 0))
	}, reason)

# Mengambil aksi berikutnya yang belum selesai atau dilewati.
func get_next_action() -> Dictionary:
	if phase_finished or battle_ended:
		return {}

	var steps: Array = current_plan.get("steps", [])

	while current_step < steps.size():
		var step: Dictionary = steps[current_step]
		var npc_id: String = str(step.get("npc", ""))

		# Melewati NPC yang sudah resolved atau skipped.
		if current_state.get("resolved", []).has(npc_id) or skipped_npcs.has(npc_id):
			current_step += 1
			continue

		return {
			"type": str(step.get("action", "")),
			"npc": npc_id,
			"cost": int(step.get("cost", 0))
		}

	_finish_phase()
	return {}

# Memeriksa precondition aksi sebelum aksi dikirim ke battle.
# State harus disinkronkan terlebih dahulu oleh pemanggil.
func validate_action(action: Dictionary, inference_result: Dictionary) -> Dictionary:
	var result := {
		"valid": false,
		"reason": ""
	}

	if action.is_empty():
		result["reason"] = "empty_action"
		return result

	if phase_finished or battle_ended:
		result["reason"] = "phase_already_finished"
		return result

	if not bool(current_state.get("target_alive", false)):
		result["reason"] = "target_not_alive"
		planning_log.log_validation(current_turn, action, false, result["reason"])
		_stop_phase("battle_ended")
		return result

	# Memastikan aksi memenuhi aturan yang ditentukan PlanningDomain.
	if not DOMAIN.is_action_valid(current_state, action):
		result["reason"] = "planning_precondition_failed"
		planning_log.log_validation(current_turn, action, false, result["reason"])
		return result

	# Aksi koordinasi harus mendapatkan persetujuan dari inference engine.
	if str(action.get("type", "")) == DOMAIN.ACTION_COORDINATED:
		if not _is_coordination_approved(inference_result, str(action.get("npc", "")), current_turn):
			result["reason"] = "inference_did_not_approve_coordination"
			planning_log.log_validation(current_turn, action, false, result["reason"])
			return result

	result["valid"] = true
	result["reason"] = "all_preconditions_satisfied"
	planning_log.log_validation(current_turn, action, true, result["reason"])
	return result

# Mencatat aksi tepat sebelum controller mengirimkannya ke battle.
func mark_action_sent(action: Dictionary) -> void:
	if action.is_empty():
		return

	var key := DOMAIN.make_action_key(str(action.get("type", "")), str(action.get("npc", "")))

	if not _sent_keys.has(key):
		_sent_keys.append(key)

	planning_log.log_sent(current_turn, action)

# Memastikan hasil inference sesuai dengan NPC dan turn yang sedang berjalan.
func _is_coordination_approved(inference_result: Dictionary, npc_id: String, turn: int) -> bool:
	if inference_result.is_empty():
		return false

	if int(inference_result.get("turn", -1)) != turn:
		return false

	if str(inference_result.get("subject", "")) != npc_id:
		return false

	return str(inference_result.get("decision", "")) == DOMAIN.ACTION_COORDINATED

# Menangani aksi tidak valid atau ditolak dengan maksimal satu kali replan.
func handle_invalid_action(action: Dictionary, reason: String, already_logged: bool = false) -> Dictionary:
	if phase_finished or battle_ended:
		return {"status": "battle_ended"}

	# Mengambil kondisi battle terbaru sebelum replan atau fallback.
	if not _sync_from_provider():
		_abort_stale_state(action if already_logged else {})
		return {"status": "snapshot_invalid"}

	var npc_id: String = str(action.get("npc", ""))
	_block_action(action)

	# Aksi yang sudah ditolak battle tidak boleh ditimpa status pembatalan.
	var exclude := action if already_logged else {}

	# Fallback tidak melakukan replan kembali jika aksinya gagal.
	if active_plan_is_fallback:
		if not already_logged:
			_log_action_cancelled(action, reason)

		_mark_skipped(npc_id, reason, str(action.get("type", "")))
		current_step += 1
		return {"status": "skipped", "npc": npc_id}

	# Mencoba mencari plan baru jika kesempatan replan masih tersedia.
	if replan_count < MAX_REPLAN:
		replan_count += 1
		var new_plan := replan_from_current_state(reason, exclude)

		if phase_finished:
			return {"status": "snapshot_invalid"}

		if new_plan.get("status", "") == "plan_found":
			active_plan_is_fallback = false
			return {"status": "replanned", "plan": new_plan}

		if new_plan.get("status", "") == "goal_already_true":
			_finish_phase()
			return {"status": "done"}

	# Menggunakan fallback jika replan gagal atau batas percobaan tercapai.
	if _install_fallback_plan("fallback_after: " + reason, exclude):
		return {
			"status": "fallback",
			"actions": current_plan.get("steps", []).duplicate(true)
		}

	_cancel_pending_steps(REASON_CANCELLED_NO_VALID_ACTION, exclude)
	_mark_unresolved_as_skipped("no_valid_fallback_after: " + reason)

	current_plan = {
		"status": "no_plan",
		"steps": [],
		"reason": reason
	}

	current_step = 0
	_finish_phase()
	return {"status": "skipped"}

# Memasukkan aksi yang gagal ke daftar blocked agar tidak dipilih kembali.
func _block_action(action: Dictionary) -> void:
	if action.is_empty():
		return

	var key := DOMAIN.make_action_key(str(action.get("type", "")), str(action.get("npc", "")))

	if not current_state.get("blocked", []).has(key):
		current_state["blocked"].append(key)

# Mencatat hasil eksekusi battle dan memperbarui state setelah eksekusi.
func record_execution_result(action: Dictionary, raw_battle_result: Variant) -> Dictionary:
	_fresh = false
	var result := _record_execution_result_inner(action, raw_battle_result)

	# Sinkronisasi pasca-eksekusi dilakukan di sini.
	if not phase_finished and not _sync_from_provider():
		_abort_stale_state()
		return {"status": "snapshot_invalid"}

	return result

# Memproses status hasil battle untuk menentukan kelanjutan fase NPC.
func _record_execution_result_inner(action: Dictionary, raw_battle_result: Variant) -> Dictionary:
	var battle_result := _normalize_battle_result(raw_battle_result)
	var status: String = str(battle_result.get("status", "rejected"))
	var slot_completed: bool = bool(battle_result.get("slot_completed", false))
	var battle_over: bool = bool(battle_result.get("battle_over", false))
	var reason: String = str(battle_result.get("reason", ""))
	var sent_key := DOMAIN.make_action_key(str(action.get("type", "")), str(action.get("npc", "")))

	if _sent_keys.has(sent_key):
		_sent_keys.erase(sent_key)
	else:
		push_warning("record_execution_result untuk aksi yang tidak ditandai sent: " + sent_key)

	# Status executed hanya dicatat jika battle mengonfirmasi slot selesai.
	if not (status == "executed" and not slot_completed):
		planning_log.log_execution(current_turn, action, status, reason)

	if status == "executed" and slot_completed:
		_mark_action_completed(action)
		current_step += 1

		if battle_over:
			_stop_phase("battle_ended")
			return {"status": "battle_ended"}

		return {"status": "ok"}

	if battle_over:
		# Status rejected atau error sudah final dan tidak boleh ditimpa skipped.
		var final_logged := status == "rejected" or status == "error"
		_stop_phase("battle_ended", action if final_logged else {})
		return {"status": "battle_ended"}

	if status == "rejected" or status == "error":
		return handle_invalid_action(action, "battle_" + status + ": " + reason, true)

	# NPC dilewati jika battle belum mengonfirmasi slot selesai.
	var npc_id: String = str(action.get("npc", ""))
	_mark_skipped(npc_id, "slot_not_confirmed: " + reason, str(action.get("type", "")))
	current_step += 1
	return {"status": "skipped", "npc": npc_id}

# Memperbarui state hanya setelah battle mengonfirmasi aksi berhasil.
func _mark_action_completed(action: Dictionary) -> void:
	var npc_id: String = str(action.get("npc", ""))
	var action_type: String = str(action.get("type", ""))

	if npc_id.is_empty():
		return

	if not current_state["resolved"].has(npc_id):
		current_state["resolved"].append(npc_id)
		current_state["resolved"].sort_custom(DOMAIN._compare_npc_id)

	# Serangan normal dari leader membuka kondisi untuk aksi koordinasi.
	if action_type == DOMAIN.ACTION_NORMAL and current_state["roles"].get(npc_id, DOMAIN.ROLE_FOLLOWER) == DOMAIN.ROLE_LEADER:
		current_state["leader_attacked"] = true

	# Mencatat NPC yang sudah menggunakan aksi koordinasi.
	if action_type == DOMAIN.ACTION_COORDINATED and not current_state["coord_used"].has(npc_id):
		current_state["coord_used"].append(npc_id)
		current_state["coord_used"].sort_custom(DOMAIN._compare_npc_id)

# Menyamakan state planning dengan kondisi NPC dan target dari battle.
func synchronize_battle_state(npcs: Array, target_alive: bool) -> void:
	if current_state.is_empty() or phase_finished:
		return

	var actual_state := DOMAIN.create_initial_state(npcs, target_alive, bool(current_state.get("wait_supported", false)), current_state.get("wait_advised", []))

	# Mempertahankan NPC yang sudah resolved selama NPC tersebut masih hidup.
	for npc_id in current_state.get("resolved", []):
		if actual_state["alive"].has(npc_id):
			actual_state["resolved"].append(npc_id)

	# Mempertahankan catatan NPC yang sudah menggunakan koordinasi.
	for npc_id in current_state.get("coord_used", []):
		if actual_state["alive"].has(npc_id):
			actual_state["coord_used"].append(npc_id)

	# Aksi yang pernah gagal tetap diblokir setelah sinkronisasi.
	actual_state["blocked"] = current_state.get("blocked", []).duplicate()
	# Leader yang sudah mati tidak dapat lagi membuka kondisi koordinasi.
	actual_state["leader_attacked"] = bool(current_state.get("leader_attacked", false)) and DOMAIN.has_alive_leader(actual_state)
	current_state = actual_state

	if not target_alive:
		_stop_phase("battle_ended")

# Mencari plan baru berdasarkan state battle terbaru.
func replan_from_current_state(reason: String, exclude_action: Dictionary = {}) -> Dictionary:
	if not _sync_from_provider():
		_abort_stale_state(exclude_action)
		return {"status": "no_plan", "steps": [], "reason": "snapshot_invalid"}

	# Membatalkan sisa plan lama sebelum menggantinya dengan plan baru.
	_cancel_pending_steps(REASON_REPLACED_BY_REPLAN, exclude_action)

	current_plan = PLANNER.find_plan(current_state, planner_mode)
	current_step = 0
	planning_log.log_replan(current_turn, reason, current_plan)

	return current_plan.duplicate(true)

# Membuat aksi fallback untuk NPC yang masih hidup dan belum resolved.
func get_fallback_actions() -> Array:
	var fallback_actions: Array = []

	if not bool(current_state.get("target_alive", false)):
		return fallback_actions

	for npc_id in current_state.get("alive", []):
		if current_state["resolved"].has(npc_id):
			continue
		if skipped_npcs.has(npc_id):
			continue

		var action: Dictionary

		# NPC yang disarankan WAIT tidak dipaksa melakukan NORMAL_ATTACK.
		if current_state["wait_advised"].has(npc_id):
			action = {
				"type": DOMAIN.ACTION_WAIT,
				"npc": npc_id,
				"cost": DOMAIN.COST_WAIT
			}
		else:
			action = {
				"type": DOMAIN.ACTION_NORMAL,
				"npc": npc_id,
				"cost": DOMAIN.COST_NORMAL
			}

		# Memastikan aksi fallback tetap memenuhi seluruh precondition.
		if DOMAIN.is_action_valid(current_state, action):
			fallback_actions.append(action)

	return fallback_actions

# Memasang plan fallback jika planner tidak menghasilkan plan yang dapat dijalankan.
func _install_fallback_plan(reason: String, exclude_action: Dictionary = {}) -> bool:
	var fallback_actions := get_fallback_actions()

	if fallback_actions.is_empty():
		return false

	# Membatalkan langkah plan lama yang tidak akan dijalankan lagi.
	_cancel_pending_steps(REASON_REPLACED_BY_FALLBACK, exclude_action)

	var steps: Array = []
	var total_cost := 0

	for i in range(fallback_actions.size()):
		var action: Dictionary = fallback_actions[i]
		total_cost += int(action["cost"])

		steps.append({
			"i": i + 1,
			"action": action["type"],
			"npc": action["npc"],
			"cost": action["cost"]
		})
		planning_log.log_fallback(current_turn, str(action["npc"]), reason, str(action["type"]))

	current_plan = {
		"status": "fallback",
		"mode": "FALLBACK",
		"goal": "all_alive_npc_resolved",
		"steps": steps,
		"total_cost": total_cost,
		"nodes_expanded": 0,
		"time_ms": 0.0,
		"reason": reason
	}

	current_step = 0
	active_plan_is_fallback = true

	# Menampilkan langkah fallback sebagai pending di log atau overlay.
	planning_log.log_plan(current_turn, current_plan)
	return true

# Menandai NPC yang slotnya dilewati tanpa menganggapnya resolved.
func _mark_skipped(npc_id: String, reason: String, action_type: String = "") -> void:
	if npc_id.is_empty():
		return

	if current_state.get("resolved", []).has(npc_id):
		return

	if not skipped_npcs.has(npc_id):
		skipped_npcs.append(npc_id)
		planning_log.log_execution(current_turn, {"npc": npc_id, "type": action_type}, "skipped", reason)

# Menandai seluruh NPC hidup yang belum selesai sebagai skipped.
func _mark_unresolved_as_skipped(reason: String) -> void:
	for npc_id in current_state.get("alive", []):
		if not current_state["resolved"].has(npc_id) and not skipped_npcs.has(npc_id):
			_mark_skipped(npc_id, reason)

# Menghentikan fase dan membatalkan seluruh langkah yang masih tersisa.
func _stop_phase(reason: String, exclude_action: Dictionary = {}, as_battle_end: bool = true) -> void:
	if phase_finished:
		return

	if as_battle_end:
		battle_ended = true

	# Aksi yang sudah memiliki status final tidak ditimpa menjadi skipped.
	var cancel_reason := REASON_CANCELLED_BATTLE_ENDED if as_battle_end else REASON_CANCELLED_SNAPSHOT_INVALID
	_cancel_pending_steps(cancel_reason, exclude_action)
	_mark_unresolved_as_skipped(reason)

	current_plan = {
		"status": "no_plan",
		"steps": [],
		"reason": reason
	}

	current_step = 0
	_finish_phase()

# Memeriksa apakah seluruh NPC yang masih hidup sudah resolved.
# NPC skipped tetap dihitung sebagai unresolved.
func _finish_phase() -> void:
	if phase_finished:
		return

	phase_finished = true

	var unresolved_npcs: Array = []

	for npc_id in current_state.get("alive", []):
		if not current_state["resolved"].has(npc_id):
			unresolved_npcs.append(npc_id)

	var goal_reached: bool = unresolved_npcs.is_empty()
	planning_log.log_goal(current_turn, goal_reached, unresolved_npcs)

func finish_npc_phase() -> void:
	_finish_phase()

# Mengembalikan seluruh entri planning log.
func get_planning_log() -> Array:
	return planning_log.get_all_entries()

# Mengembalikan salinan state agar data internal tidak berubah dari luar.
func get_current_state() -> Dictionary:
	return current_state.duplicate(true)

# Mengembalikan salinan plan yang sedang digunakan.
func get_current_plan() -> Dictionary:
	return current_plan.duplicate(true)

# Menjalankan fase NPC dengan urutan snapshot, inference, validasi, dan eksekusi battle.
# snapshot_fn mengembalikan {"npcs": Array, "target_alive": bool}.
# inference_fn menerima action dan mengembalikan {"turn": int, "subject": String, "decision": String}.
# execute_fn menerima action dan mengembalikan battle_result.
func run_npc_phase(turn: int, snapshot_fn: Callable, inference_fn: Callable, execute_fn: Callable, wait_supported: bool = false, wait_advised_ids: Array = [], max_iterations_override: int = -1) -> Dictionary:
	_snapshot_fn = snapshot_fn

	# Snapshot awal wajib valid sebelum fase dimulai.
	if not snapshot_fn.is_valid():
		return _abort_phase(turn, "snapshot_fn", "snapshot_fn_unavailable")

	var snap: Variant = snapshot_fn.call()
	var snap_error := _snapshot_error(snap)

	if snap_error != "":
		return _abort_phase(turn, "snapshot", snap_error)

	start_npc_phase(turn, snap["npcs"], bool(snap["target_alive"]), wait_supported, wait_advised_ids)

	# Membatasi iterasi untuk mencegah proses berjalan tanpa akhir.
	var max_iterations: int = 20 + 10 * current_state.get("alive", []).size()

	if max_iterations_override > 0:
		max_iterations = max_iterations_override

	var iterations := 0

	while not phase_finished and iterations < max_iterations:
		iterations += 1
		var action := get_next_action()

		if action.is_empty():
			break

		# Mengambil state terbaru sebelum aksi divalidasi.
		if not _sync_from_provider(true):
			_abort_stale_state()
			break

		# Mengambil hasil inference untuk aksi yang akan dijalankan.
		var inference_result: Dictionary = {}

		if inference_fn.is_valid():
			var raw_inference: Variant = inference_fn.call(action)
			var inference_error := _inference_error(raw_inference)

			if inference_error == "":
				inference_result = raw_inference
			elif str(action.get("type", "")) == DOMAIN.ACTION_COORDINATED:
				_log_integration_error("inference", inference_error)
		elif str(action.get("type", "")) == DOMAIN.ACTION_COORDINATED:
			_log_integration_error("inference", "inference_fn_unavailable")

		var validation := validate_action(action, inference_result)

		if phase_finished:
			break

		if not validation["valid"]:
			handle_invalid_action(action, str(validation["reason"]))
			continue

		# Aksi tidak ditandai sent jika fungsi eksekusi battle tidak tersedia.
		if not execute_fn.is_valid():
			_log_integration_error("execute_fn", "execute_fn_unavailable")
			handle_invalid_action(action, "execute_fn_unavailable")
			continue

		# Mencatat aksi tepat sebelum benar-benar dikirim ke battle.
		mark_action_sent(action)

		var battle_result: Variant = execute_fn.call(action)

		# Mencatat hasil eksekusi sekaligus menyinkronkan state pasca-battle.
		record_execution_result(action, battle_result)

	# Membatalkan sisa langkah jika fase berhenti tanpa hasil atau batas iterasi tercapai.
	if not phase_finished:
		var limit_hit := iterations >= max_iterations
		var end_reason := "iteration_limit_reached" if limit_hit else "phase_ended_without_result"

		_log_integration_error("run_npc_phase", end_reason)
		_cancel_pending_steps("plan_cancelled_" + end_reason)
		_mark_unresolved_as_skipped(end_reason)

		current_plan = {
			"status": "no_plan",
			"steps": [],
			"reason": end_reason
		}

		current_step = 0
		_finish_phase()

	_snapshot_fn = Callable()
	return {
		"turn": turn,
		"iterations": iterations,
		"battle_ended": battle_ended,
		"skipped_npcs": skipped_npcs.duplicate(),
		"unresolved_npcs": _get_unresolved_alive()
	}

# Menghentikan runner jika data awal tidak memenuhi kontrak integrasi.
func _abort_phase(turn: int, source: String, message: String) -> Dictionary:
	current_turn = turn
	phase_finished = true
	_snapshot_fn = Callable()
	_log_integration_error(source, message)

	return {
		"turn": turn,
		"iterations": 0,
		"battle_ended": false,
		"error": message,
		"skipped_npcs": [],
		"unresolved_npcs": []
	}

# Mencatat kesalahan ketika data dari komponen lain tidak sesuai kontrak.
func _log_integration_error(source: String, message: String) -> void:
	planning_log.log_integration_error(current_turn, source, message)

# Memeriksa struktur snapshot yang dikirim oleh battle.
# Format: {"npcs": [{"npc_id": String, "hp": int, "role": String}], "target_alive": bool}
func _snapshot_error(snap: Variant) -> String:
	if typeof(snap) != TYPE_DICTIONARY:
		return "snapshot_not_dictionary"

	if not snap.has("npcs") or typeof(snap["npcs"]) != TYPE_ARRAY:
		return "snapshot_missing_npcs"

	if not snap.has("target_alive") or typeof(snap["target_alive"]) != TYPE_BOOL:
		return "snapshot_missing_target_alive"

	for npc in snap["npcs"]:
		if typeof(npc) != TYPE_DICTIONARY:
			return "snapshot_npc_not_dictionary"

		for field in ["npc_id", "hp", "role"]:
			if not npc.has(field):
				return "snapshot_npc_missing_" + field

		if str(npc["role"]) != DOMAIN.ROLE_LEADER and str(npc["role"]) != DOMAIN.ROLE_FOLLOWER:
			return "snapshot_npc_invalid_role"

	return ""

# Memeriksa struktur hasil inference sebelum digunakan untuk validasi.
# Format: {"turn": int, "subject": String, "decision": String}
func _inference_error(result: Variant) -> String:
	if typeof(result) != TYPE_DICTIONARY:
		return "inference_not_dictionary"

	for field in ["turn", "subject", "decision"]:
		if not result.has(field):
			return "inference_missing_" + field

	return ""

# Memeriksa struktur dan nilai status dari hasil eksekusi battle.
# Format: {"status": String, "slot_completed": bool, "battle_over": bool, "reason": String}
func _battle_result_error(result: Variant) -> String:
	if typeof(result) != TYPE_DICTIONARY:
		return "battle_result_not_dictionary"

	for field in ["status", "slot_completed", "battle_over"]:
		if not result.has(field):
			return "battle_result_missing_" + field

	if not VALID_BATTLE_STATUS.has(str(result["status"])):
		return "battle_result_invalid_status"

	if typeof(result["slot_completed"]) != TYPE_BOOL:
		return "battle_result_slot_completed_not_bool"

	if typeof(result["battle_over"]) != TYPE_BOOL:
		return "battle_result_battle_over_not_bool"

	return ""

# Mengubah hasil battle yang tidak sesuai kontrak menjadi error.
# NPC tidak dianggap selesai jika hasil battle tidak valid.
func _normalize_battle_result(result: Variant) -> Dictionary:
	var error_message := _battle_result_error(result)

	if error_message != "":
		_log_integration_error("battle_result", error_message)

		return {
			"status": "error",
			"slot_completed": false,
			"battle_over": false,
			"reason": "invalid_battle_result: " + error_message
		}

	return {
		"status": str(result["status"]),
		"slot_completed": bool(result["slot_completed"]),
		"battle_over": bool(result["battle_over"]),
		"reason": str(result.get("reason", ""))
	}

# Mengambil NPC hidup yang belum berhasil menyelesaikan slot aksinya.
func _get_unresolved_alive() -> Array:
	var unresolved: Array = []

	for npc_id in current_state.get("alive", []):
		if not current_state["resolved"].has(npc_id):
			unresolved.append(npc_id)

	return unresolved

# Mengatur kebutuhan Decision Making Under Uncertainty
func configure_uncertainty_advisory(model_config: Dictionary, utility_map: Dictionary, belief_provider: Callable, transition_provider: Callable, meu_provider: Callable) -> Dictionary:
	# Menyalin konfigurasi model dan peta utility agar perubahan luar tidak memengaruhi state internal.
	uncertainty_model_config = model_config.duplicate(true)
	uncertainty_utility_map = utility_map.duplicate(true)

	# Menyimpan referensi Callable dari seluruh provider yang dibutuhkan.
	uncertainty_belief_provider = belief_provider
	uncertainty_transition_provider = transition_provider
	uncertainty_meu_provider = meu_provider

	# Menandai bahwa modul advisory telah dikonfigurasi dan membersihkan cache rekomendasi lama.
	uncertainty_is_configured = true
	uncertainty_advisory.clear()

	# Mengembalikan status konfirmasi bahwa konfigurasi berhasil disimpan.
	return {
		"valid": true,
		"errors": [],
		"data": {
			"status": "CONFIGURED"
		}
	}

# Memperbarui rekomendasi berdasarkan kondisi ketidakpastian terbaru
func refresh_uncertainty_advisory() -> Dictionary:
	# Memastikan konfigurasi awal sudah dilakukan sebelum menyegarkan rekomendasi.
	if not uncertainty_is_configured:
		return _uncertainty_error("UNCERTAINTY_NOT_CONFIGURED")

	# Memastikan belief_provider masih aktif dan dapat dipanggil.
	if not uncertainty_belief_provider.is_valid():
		return _uncertainty_error("BELIEF_PROVIDER_UNAVAILABLE")

	# Memastikan transition_provider masih aktif dan dapat dipanggil.
	if not uncertainty_transition_provider.is_valid():
		return _uncertainty_error("TRANSITION_PROVIDER_UNAVAILABLE")

	# Memastikan meu_provider masih aktif dan dapat dipanggil.
	if not uncertainty_meu_provider.is_valid():
		return _uncertainty_error("MEU_PROVIDER_UNAVAILABLE")

	# Mengambil belief terbaru dari provider.
	var belief_result = uncertainty_belief_provider.call()

	# Menghentikan proses jika pengambilan belief gagal atau formatnya tidak valid.
	if not _uncertainty_result_is_valid(belief_result):
		return _uncertainty_error("BELIEF_PROVIDER_ERROR")

	# Mengambil payload data belief terbaru.
	var belief: Dictionary = belief_result.get("data", {})

	# Menyiapkan transition berdasarkan belief terbaru.
	var transition_result = uncertainty_transition_provider.call(belief)

	# Menghentikan proses jika penyediaan transisi gagal.
	if not _uncertainty_result_is_valid(transition_result):
		return _uncertainty_error("TRANSITION_PROVIDER_ERROR")

	# Mengambil struktur transition provider dari hasil panggilan.
	var provider: Dictionary = transition_result.get("data", {})

	# Membuat model keputusan dari konfigurasi yang tersimpan.
	var model_result = DECISION_MODEL.create_model(uncertainty_model_config)

	# Menghentikan proses jika konfigurasi model keputusan tidak valid.
	if not _uncertainty_result_is_valid(model_result):
		return _uncertainty_error(
			"INVALID_DECISION_MODEL",
			model_result.get("errors", [])
		)

	# Mengambil objek model keputusan yang telah tervalidasi.
	var model: Dictionary = model_result.get("data", {}).get("model", {})

	# Memvalidasi model dan transition provider sebelum perhitungan MDP.
	var validation_result = DECISION_MODEL.validate_model(model, provider, uncertainty_probability_tolerance)

	# Menghentikan proses jika kecocokan model dan transisi gagal divalidasi.
	if not _uncertainty_result_is_valid(validation_result):
		return _uncertainty_error(
			"MODEL_VALIDATION_FAILED",
			validation_result.get("errors", [])
		)

	# Menghitung Maximum Expected Utility berdasarkan belief terkini.
	var meu_result = _calculate_uncertainty_meu(belief)

	# Menghentikan proses jika perhitungan MEU mengalami kegagalan.
	if not _uncertainty_result_is_valid(meu_result):
		return _uncertainty_error(
			"MEU_CALCULATION_FAILED",
			meu_result.get("errors", [])
		)

	# Menjalankan Value Iteration untuk memperoleh policy optimal.
	var mdp_result = MDP_SOLVER.value_iteration(
		model,
		provider,
		uncertainty_epsilon,
		uncertainty_max_iterations,
		uncertainty_probability_tolerance,
		uncertainty_comparison_tolerance
	)

	# Menghentikan proses jika eksekusi Value Iteration gagal.
	if not _uncertainty_result_is_valid(mdp_result):
		return _uncertainty_error(
			"MDP_CALCULATION_FAILED",
			mdp_result.get("errors", [])
		)

	# Mengambil payload data hasil perhitungan MDP.
	var mdp_data: Dictionary = mdp_result.get("data", {})

	# Hasil yang belum konvergen tidak boleh dianggap policy optimal.
	if mdp_data.get("status", "") != "CONVERGED":
		return _uncertainty_error(
			"MDP_NOT_CONVERGED",
			mdp_result.get("errors", [])
		)

	# Menyimpan hasil sebagai rekomendasi, bukan perintah aksi.
	uncertainty_advisory = {
		"valid": true,
		"belief": belief,
		"meu": meu_result.get("data", {}),
		"mdp": mdp_data,
		"validation": validation_result.get("data", {}),
		"status": "READY"
	}

	# Mengembalikan salinan lengkap hasil advisory yang telah diperbarui.
	return {
		"valid": true,
		"errors": [],
		"data": uncertainty_advisory.duplicate(true)
	}

# Menghitung Expected Utility untuk setiap alternatif tindakan
func _calculate_uncertainty_meu(belief: Dictionary) -> Dictionary:
	# Meminta daftar outcome untuk setiap aksi berdasarkan belief saat ini.
	var outcome_result = uncertainty_meu_provider.call(belief)

	# Menghentikan perhitungan jika provider gagal menyediakan outcome.
	if not _uncertainty_result_is_valid(outcome_result):
		return _uncertainty_error("MEU_OUTCOME_PROVIDER_ERROR")

	# Mengambil pemetaan outcome berdasarkan ID aksi dan menyiapkan wadah hasil.
	var outcomes_by_action: Dictionary = outcome_result.get("data", {})
	var actions_with_utility: Dictionary = {}

	# Memproses daftar outcome pada setiap kandidat aksi.
	for action_id in outcomes_by_action:
		var outcomes = outcomes_by_action[action_id]

		# Memastikan daftar outcome untuk aksi ini berbentuk Array.
		if not outcomes is Array:
			return _uncertainty_error("INVALID_OUTCOMES")

		# Menampung daftar outcome yang sudah dilengkapi nilai utility.
		var prepared_outcomes: Array = []

		# Memeriksa setiap outcome dan melengkapinya dengan nilai utility.
		for outcome in outcomes:
			# Memastikan setiap elemen outcome berbentuk Dictionary.
			if not outcome is Dictionary:
				return _uncertainty_error("INVALID_OUTCOME")

			var outcome_id = outcome.get("id")

			# Mengambil utility berdasarkan ID outcome dari utility_map.
			var utility_result = DECISION_MODEL.get_utility(uncertainty_utility_map, outcome_id)

			# Menghentikan proses jika ID outcome tidak ditemukan atau utility tidak valid.
			if not _uncertainty_result_is_valid(utility_result):
				return _uncertainty_error(
					"INVALID_OUTCOME_UTILITY",
					utility_result.get("errors", [])
				)

			# Menyusun struktur outcome lengkap dengan ID, probabilitas, dan utility.
			prepared_outcomes.append({
				"id": outcome_id,
				"probability": outcome.get("probability"),
				"utility": utility_result.get("data", {}).get("utility")
			})

		# Menyimpan daftar outcome siap hitung untuk aksi yang bersangkutan.
		actions_with_utility[action_id] = prepared_outcomes

	# Memilih alternatif dengan Maximum Expected Utility.
	return EXPECTED_UTILITY.choose_meu(
		actions_with_utility,
		uncertainty_probability_tolerance,
		uncertainty_comparison_tolerance
	)

# Memeriksa format hasil dari komponen lain
func _uncertainty_result_is_valid(result: Variant) -> bool:
	# Menolak jika hasil kembalian bukan Dictionary.
	if not result is Dictionary:
		return false

	# Memastikan kunci valid tersedia dalam hasil.
	if not result.has("valid"):
		return false

	# Memastikan kunci errors dan data tersedia dalam hasil.
	if not result.has("errors") or not result.has("data"):
		return false

	# Mengembalikan true hanya jika status valid bernilai true secara eksplisit.
	return result["valid"] == true

# Membuat hasil error dengan format Result
func _uncertainty_error(error_code: String, details: Array = []) -> Dictionary:
	# Memasukkan kode error utama sebagai elemen pertama daftar error.
	var errors: Array = [error_code]

	# Menggabungkan rincian error tambahan tanpa duplikasi.
	for detail in details:
		if not errors.has(detail):
			errors.append(detail)

	# Mengembalikan struktur Result gagal beserta status error utama.
	return {
		"valid": false,
		"errors": errors,
		"data": {
			"status": error_code
		}
	}

# Mengambil seluruh hasil advisory
func get_uncertainty_advisory() -> Dictionary:
	# Mengembalikan salinan mendalam dari data advisory saat ini.
	return uncertainty_advisory.duplicate(true)

# Mengambil rekomendasi berdasarkan Maximum Expected Utility
func get_uncertainty_meu_recommendation() -> Variant:
	# Mengembalikan null jika rekomendasi belum pernah dihitung.
	if uncertainty_advisory.is_empty():
		return null

	# Mengambil action terbaik dari hasil perhitungan MEU.
	return uncertainty_advisory.get("meu", {}).get("best_action")

# Mengambil rekomendasi policy MDP berdasarkan state
func get_uncertainty_mdp_recommendation(state_id: String) -> Variant:
	# Mengembalikan null jika rekomendasi belum pernah dihitung.
	if uncertainty_advisory.is_empty():
		return null

	# Mengambil kamus policy MDP dan mencari aksi rekomendasi untuk state_id.
	var policy: Dictionary = uncertainty_advisory.get("mdp", {}).get("policy", {})

	return policy.get(state_id)