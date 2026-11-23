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

# Konfigurasi Decision Making Under Uncertainty (tanpa placeholder hipotesis hardcoded)
var uncertainty_model_config: Dictionary = {}
var uncertainty_utility_map: Dictionary = {}
var uncertainty_initial_prior: Dictionary = {}
var uncertainty_allowed_evidence_values: Array = []

# Provider dan validator lintas modul (Zahra, Andina, & KB R0-R9)
var uncertainty_prior_provider: Callable = Callable()
var uncertainty_belief_provider: Callable = Callable()
var uncertainty_transition_provider: Callable = Callable()
var uncertainty_meu_provider: Callable = Callable()
var uncertainty_likelihood_validator: Callable = Callable()
var uncertainty_bayesian_updater: Callable = Callable()
var uncertainty_kb_validator: Callable = Callable()
var uncertainty_overlay: Variant = null

# Hasil rekomendasi dan status aktif Decision Making Under Uncertainty
var uncertainty_advisory: Dictionary = {}
var uncertainty_is_configured: bool = false
var uncertainty_fallback_active: bool = false

# Parameter perhitungan sesuai ketetapan HDS-04
var uncertainty_probability_tolerance: float = 0.000001
var uncertainty_comparison_tolerance: float = 0.000000001
var uncertainty_epsilon: float = 0.001
var uncertainty_max_iterations: int = 1000

# Manajemen epoch, belief aktif, deduplikasi, dan log terstruktur (HDS-01, HDS-07, HDS-09)
var battle_epoch: int = 0
var active_belief_epoch: int = 0
var active_belief_record: Dictionary = {}
var uncertainty_sequence_id: int = 0
var uncertainty_logs: Array = []

# Penyimpanan deduplikasi dua lapis di controller tanpa mengubah schema BeliefRecord (HDS-01)
var _used_turn_slots: Dictionary = {}
var _processed_evidence_ids: Dictionary = {}

# Cache MEU dan Cache MDP yang dipisahkan sesuai HDS-06
var _meu_cache_key: String = ""
var _meu_cache_result: Dictionary = {}
var _mdp_cache_key: String = ""
var _mdp_cache_result: Dictionary = {}
var _vi_executed_epoch: int = -1
var _vi_executed_turn: int = -1

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

# Mengambil prior awal dari prior_provider Zahra, konfigurasi prior eksplisit,
# atau fallback belief_provider jika sumber prior eksplisit tidak tersedia (HDS-01 & HDS-07).
func _create_initial_prior_record() -> Dictionary:
	# 1. Mengutamakan prior_provider dari modul Zahra jika tersedia dan valid.
	if uncertainty_prior_provider.is_valid():
		var prior_res: Variant = uncertainty_prior_provider.call()
		if _uncertainty_result_is_valid(prior_res):
			var data: Dictionary = prior_res.get("data", {})
			var raw_rec: Variant = data.get("belief", data)
			if raw_rec is Dictionary:
				return raw_rec.duplicate(true)

	# 2. Menggunakan distribusi prior eksplisit yang diberikan saat konfigurasi.
	if not uncertainty_initial_prior.is_empty():
		return {
			"type": "INITIAL_PRIOR",
			"source_turn": 0,
			"distribution": uncertainty_initial_prior.duplicate(true)
		}

	# 3. Fallback ke belief_provider hanya untuk inisialisasi awal jika prior eksplisit kosong.
	if uncertainty_belief_provider.is_valid():
		var belief_res: Variant = uncertainty_belief_provider.call()
		if _uncertainty_result_is_valid(belief_res):
			var b_data: Dictionary = belief_res.get("data", {})
			var b_rec: Variant = b_data.get("belief", b_data)
			if b_rec is Dictionary:
				return b_rec.duplicate(true)

	return {}

# Memvalidasi nilai probabilitas tunggal (numerik, finite, berada pada rentang [0.0, 1.0]).
func _is_valid_probability_value(value: Variant) -> bool:
	if not (value is int or value is float):
		return false

	var f: float = float(value)
	return is_finite(f) and f >= 0.0 and f <= 1.0

# Memvalidasi struktur lengkap BeliefRecord (type, source_turn, distribution, hipotesis, dan probabilitas).
func _validate_belief_record(record: Variant, expected_type: String, expected_turn: int, expected_hypotheses: Array = []) -> Array[String]:
	var errors: Array[String] = []

	if not record is Dictionary or record.is_empty():
		errors.append("INVALID_BELIEF_RECORD")
		return errors

	# Validasi metadata wajib BeliefRecord (type & source_turn).
	if not record.has("type") or not record["type"] is String or str(record["type"]) != expected_type:
		errors.append("INVALID_BELIEF_TYPE")
		return errors

	if not record.has("source_turn") or not record["source_turn"] is int:
		errors.append("INVALID_BELIEF_TURN")
		return errors

	var source_turn: int = int(record["source_turn"])
	if source_turn < 0 or source_turn != expected_turn or source_turn > current_turn:
		errors.append("INVALID_BELIEF_TURN")
		return errors

	# Validasi keberadaan dan tipe distribution.
	if not record.has("distribution") or not record["distribution"] is Dictionary:
		errors.append("INVALID_BELIEF_DISTRIBUTION")
		return errors

	var dist: Dictionary = record["distribution"]
	if dist.is_empty():
		errors.append("EMPTY_BELIEF_DISTRIBUTION")
		return errors

	# Jika daftar hipotesis referensi tersedia, pastikan himpunan hipotesis sama persis.
	if not expected_hypotheses.is_empty():
		if dist.size() != expected_hypotheses.size():
			errors.append("BELIEF_HYPOTHESIS_MISMATCH")
			return errors

		for expected_h in expected_hypotheses:
			if not dist.has(expected_h):
				errors.append("BELIEF_HYPOTHESIS_MISMATCH")
				return errors

	# Validasi setiap probabilitas hipotesis dan akumulasi totalnya.
	var prob_sum: float = 0.0
	for h in dist:
		if not h is String or h.strip_edges().is_empty():
			errors.append("INVALID_HYPOTHESIS_ID")
			return errors

		var p_val: Variant = dist[h]
		if not _is_valid_probability_value(p_val):
			errors.append("INVALID_BELIEF_PROBABILITY")
			return errors

		prob_sum += float(p_val)
		if not is_finite(prob_sum):
			errors.append("INVALID_BELIEF_PROBABILITY_SUM")
			return errors

	if abs(prob_sum - 1.0) > uncertainty_probability_tolerance:
		errors.append("INVALID_BELIEF_PROBABILITY_SUM")
		return errors

	return errors

# Membersihkan cache MEU dan MDP secara terpisah (HDS-06).
func _clear_uncertainty_caches() -> void:
	_meu_cache_key = ""
	_meu_cache_result.clear()
	_mdp_cache_key = ""
	_mdp_cache_result.clear()
	_vi_executed_epoch = -1
	_vi_executed_turn = -1

# Menghubungkan instance overlay Andina ke controller (HDS-07 & HDS-12).
func set_uncertainty_overlay(overlay: Variant) -> void:
	uncertainty_overlay = overlay

# Menghubungkan validator KB R0-R9 ke controller untuk pemeriksaan rekomendasi uncertainty (HDS-08).
func set_uncertainty_kb_validator(kb_validator: Callable) -> void:
	uncertainty_kb_validator = kb_validator

# Reset seluruh data ketika battle baru dimulai (termasuk lifecycle HDS-07).
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

	# Siklus restart HDS-07: naikkan epoch, clear overlay, reset turn/sequence, dan buat prior baru.
	battle_epoch += 1
	active_belief_epoch = battle_epoch
	uncertainty_sequence_id = 0
	uncertainty_fallback_active = false
	_used_turn_slots.clear()
	_processed_evidence_ids.clear()
	uncertainty_advisory.clear()
	uncertainty_logs.clear()
	active_belief_record.clear()
	_clear_uncertainty_caches()

	if uncertainty_is_configured:
		var init_rec := _create_initial_prior_record()
		var prior_errors := _validate_belief_record(init_rec, "INITIAL_PRIOR", 0)
		if prior_errors.is_empty():
			active_belief_record = init_rec
		else:
			uncertainty_is_configured = false

	if uncertainty_overlay != null and uncertainty_overlay.has_method("clear"):
		uncertainty_overlay.call("clear", battle_epoch)

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

	# DEBUG: Melihat plan yang dihasilkan planner sebelum dieksekusi.
	print("===== PLANNING RESULT =====")
	print("STATUS: ", current_plan.get("status"))
	print("TOTAL COST: ", current_plan.get("total_cost"))

	for step in current_plan.get("steps", []):
		print(
			"STEP ", step.get("i"),
			" | NPC: ", step.get("npc"),
			" | ACTION: ", step.get("action"),
			" | COST: ", step.get("cost")
		)

	print("==========================")

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
	print("\n--- COORDINATION APPROVAL DEBUG ---")
	print("Inference Result: ", inference_result)
	print("Expected NPC: ", npc_id)
	print("Expected Turn: ", turn)

	if inference_result.is_empty():
		print("REJECTED: inference_result is empty")
		return false

	if int(inference_result.get("turn", -1)) != turn:
		print("REJECTED: turn mismatch")
		print("Inference turn: ", inference_result.get("turn", -1))
		return false

	if str(inference_result.get("subject", "")) != npc_id:
		print("REJECTED: subject mismatch")
		print("Inference subject: ", inference_result.get("subject", ""))
		return false

	if str(inference_result.get("decision", "")) != DOMAIN.ACTION_COORDINATED:
		print("REJECTED: decision mismatch")
		print("Inference decision: ", inference_result.get("decision", ""))
		print("Expected decision: ", DOMAIN.ACTION_COORDINATED)
		return false

	print("APPROVED: coordination accepted")
	return true

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

		var battle_result: Variant = await execute_fn.call(action)

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
func _inference_error(result: Variant) -> String:
	if typeof(result) != TYPE_DICTIONARY:
		return "inference_not_dictionary"

	for field in ["turn", "subject", "decision"]:
		if not result.has(field):
			return "inference_missing_" + field

	return ""

# Memeriksa struktur dan nilai status dari hasil eksekusi battle.
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

# Mengatur kebutuhan Decision Making Under Uncertainty.
# Membersihkan seluruh state lama terlebih dahulu agar kegagalan konfigurasi baru tidak menyisakan data lama.
func configure_uncertainty_advisory(model_config: Dictionary, utility_map: Dictionary, belief_provider: Callable, transition_provider: Callable, meu_provider: Callable, likelihood_validator: Callable = Callable(), bayesian_updater: Callable = Callable(), prior_provider: Callable = Callable(), initial_prior_distribution: Dictionary = {}, kb_validator: Callable = Callable(), allowed_evidence_values: Array = []) -> Dictionary:
	# 1. Reset seluruh state runtime dan active_belief_record di awal sebelum validasi apa pun.
	uncertainty_is_configured = false
	uncertainty_fallback_active = false
	uncertainty_advisory.clear()
	active_belief_record.clear()
	_used_turn_slots.clear()
	_processed_evidence_ids.clear()
	_clear_uncertainty_caches()
	active_belief_epoch = battle_epoch

	# 2. Salin konfigurasi input dan referensi Callable lintas modul.
	uncertainty_model_config = model_config.duplicate(true)
	uncertainty_utility_map = utility_map.duplicate(true)
	uncertainty_initial_prior = initial_prior_distribution.duplicate(true)
	uncertainty_allowed_evidence_values = allowed_evidence_values.duplicate(true)

	uncertainty_belief_provider = belief_provider
	uncertainty_transition_provider = transition_provider
	uncertainty_meu_provider = meu_provider
	uncertainty_likelihood_validator = likelihood_validator
	uncertainty_bayesian_updater = bayesian_updater
	uncertainty_prior_provider = prior_provider
	uncertainty_kb_validator = kb_validator

	# 3. Validasi daftar nilai evidence eksplisit (tidak boleh kosong sesuai kontrak Zahra).
	if uncertainty_allowed_evidence_values.is_empty():
		return _uncertainty_fail_and_log("INVALID_ALLOWED_EVIDENCE_VALUES")

	for ev_val in uncertainty_allowed_evidence_values:
		if not ev_val is String or ev_val.strip_edges().is_empty():
			return _uncertainty_fail_and_log("INVALID_ALLOWED_EVIDENCE_VALUES")

	# 4. Inisialisasi dan validasi struktur lengkap BeliefRecord prior awal (type, source_turn, distribution).
	var initial_record := _create_initial_prior_record()
	if initial_record.is_empty():
		return _uncertainty_fail_and_log("MISSING_PRIOR")

	var prior_errors := _validate_belief_record(initial_record, "INITIAL_PRIOR", 0)
	if not prior_errors.is_empty():
		return _uncertainty_fail_and_log(prior_errors[0], prior_errors)

	# 5. Aktifkan konfigurasi dan isi active_belief_record hanya setelah seluruh pemeriksaan lulus.
	uncertainty_is_configured = true
	active_belief_record = initial_record.duplicate(true)

	return {
		"valid": true,
		"errors": [],
		"data": {
			"status": "CONFIGURED"
		}
	}

# Memproses evidence baru dengan urutan deduplikasi dan Bayesian update wajib sesuai HDS-01 & HDS-07.
func process_uncertainty_evidence(event_epoch: int, turn: int, source_id: String, evidence_id: String, evidence_value: String, likelihood: Dictionary) -> Dictionary:
	# Pastikan modul sudah terkonfigurasi dan memiliki belief aktif yang valid.
	if not uncertainty_is_configured or active_belief_record.is_empty():
		return _uncertainty_fail_and_log("UNCERTAINTY_NOT_CONFIGURED", [], null, 0, null, null, null, null, false)

	# 1. Periksa battle_epoch dan turn aktif (HDS-01 & HDS-07).
	if event_epoch != battle_epoch or active_belief_epoch != battle_epoch:
		return _uncertainty_fail_and_log("STALE_BELIEF_EPOCH", [], null, 0, null, null, null, null, false)

	if turn < 0 or turn != current_turn:
		return _uncertainty_fail_and_log("INVALID_BELIEF_TURN", [], null, 0, null, null, null, null, false)

	# Validasi ketat identitas evidence dan nilai evidence eksplisit sebelum menyentuh slot turn.
	if source_id.strip_edges().is_empty() or evidence_id.strip_edges().is_empty():
		return _uncertainty_fail_and_log("INVALID_EVIDENCE_ID", [], null, 0, null, null, null, null, false)

	if evidence_value.strip_edges().is_empty() or uncertainty_allowed_evidence_values.is_empty() or not uncertainty_allowed_evidence_values.has(evidence_value):
		return _uncertainty_fail_and_log("INVALID_EVIDENCE_VALUE", [], null, 0, null, null, null, null, false)

	if likelihood.is_empty():
		return _uncertainty_fail_and_log("INVALID_LIKELIHOOD", [], null, 0, null, null, null, null, false)

	# 2. Periksa identitas evidence lebih dahulu agar pengulangan evidence terdeteksi spesifik (poin D).
	var evidence_key := "%d:%d:%s:%s" % [battle_epoch, turn, source_id, evidence_id]
	if _processed_evidence_ids.has(evidence_key):
		return _uncertainty_fail_and_log("DUPLICATE_EVIDENCE", [], null, 0, null, null, null, null, false)

	# 3. Periksa apakah slot turn (battle_epoch, turn) sudah terpakai (maksimal 1 evidence total per turn).
	var turn_slot_key := "%d:%d" % [battle_epoch, turn]
	if _used_turn_slots.has(turn_slot_key):
		return _uncertainty_fail_and_log("TURN_EVIDENCE_SLOT_OCCUPIED", [], null, 0, null, null, null, null, false)

	# 4. Validasi evidence dan likelihood melalui modul Zahra (validate_likelihood).
	if not uncertainty_likelihood_validator.is_valid():
		return _uncertainty_fail_and_log("LIKELIHOOD_VALIDATOR_UNAVAILABLE", [], "LIKELIHOOD_VALIDATOR_UNAVAILABLE", 0, null, null, null, null, false)

	var likelihood_check: Variant = uncertainty_likelihood_validator.call(likelihood)
	if not _uncertainty_result_is_valid(likelihood_check):
		var lh_errors: Array = likelihood_check.get("errors", []) if likelihood_check is Dictionary else []
		return _uncertainty_fail_and_log("INVALID_LIKELIHOOD", lh_errors, null, 0, null, null, null, null, false)

	# 5. Jalankan Bayesian update (update_belief) dengan mempertahankan belief aktif jika gagal.
	if not uncertainty_bayesian_updater.is_valid():
		return _uncertainty_fail_and_log("BAYESIAN_UPDATER_UNAVAILABLE", [], "BAYESIAN_UPDATER_UNAVAILABLE", 0, null, null, null, null, false)

	var update_result: Variant = uncertainty_bayesian_updater.call(
		active_belief_record,
		evidence_value,
		likelihood,
		turn
	)

	# 7. Jika update gagal (valid == false), pertahankan belief aktif dan JANGAN mengunci slot turn.
	if not _uncertainty_result_is_valid(update_result):
		var upd_errors: Array = update_result.get("errors", []) if update_result is Dictionary else []
		return _uncertainty_fail_and_log("BAYES_UPDATE_FAILED", upd_errors, null, 0, null, null, null, null, false)

	# Validasi menyeluruh struktur BeliefRecord hasil Bayesian update sebelum disimpan.
	var updated_data: Dictionary = update_result.get("data", {})
	var raw_new_belief: Variant = updated_data.get("belief", updated_data)
	var expected_hypotheses: Array = active_belief_record.get("distribution", {}).keys()
	var belief_errors := _validate_belief_record(raw_new_belief, "BAYES_UPDATE", turn, expected_hypotheses)

	if not belief_errors.is_empty():
		return _uncertainty_fail_and_log("INVALID_BELIEF_RECORD", belief_errors, null, 0, null, null, null, null, false)

	# 6. Jika validasi lulus, simpan belief baru, catat identitas evidence, dan kunci slot turn.
	active_belief_record = (raw_new_belief as Dictionary).duplicate(true)
	active_belief_epoch = battle_epoch

	# Tandai advisory sebelumnya sebagai kedaluwarsa karena belief baru saja berubah (HDS-06).
	uncertainty_advisory.clear()

	_processed_evidence_ids[evidence_key] = true
	_used_turn_slots[turn_slot_key] = true

	return {
		"valid": true,
		"errors": [],
		"data": {
			"belief": active_belief_record.duplicate(true)
		}
	}

# Mengambil belief aktif saat ini (prior atau hasil Bayesian update terakhir).
func get_active_belief_record() -> Dictionary:
	return active_belief_record.duplicate(true)

# Menyusun struktur data secara kanonik (key Dictionary diurutkan) agar serialisasi cache key deterministik (HDS-06).
func _canonicalize_for_cache(value: Variant) -> Variant:
	if value is Dictionary:
		var sorted_keys: Array = value.keys()
		sorted_keys.sort()
		var canonical_dict: Dictionary = {}
		for k in sorted_keys:
			canonical_dict[str(k)] = _canonicalize_for_cache(value[k])
		return canonical_dict

	if value is Array:
		var canonical_array: Array = []
		for item in value:
			canonical_array.append(_canonicalize_for_cache(item))
		return canonical_array

	return value

# Membuat key deterministik untuk cache MEU berdasarkan seluruh input wajib HDS-06.
func _build_meu_cache_key(belief_dist: Variant, outcomes_by_action: Dictionary, outcome_likelihood: Variant) -> String:
	var canonical: Variant = _canonicalize_for_cache({
		"battle_epoch": battle_epoch,
		"belief_distribution": belief_dist,
		"outcome_likelihood": outcome_likelihood,
		"outcomes_by_action": outcomes_by_action,
		"utilities": uncertainty_utility_map,
		"probability_tolerance": uncertainty_probability_tolerance,
		"comparison_tolerance": uncertainty_comparison_tolerance
	})
	return JSON.stringify(canonical, "", true)

# Membuat key deterministik untuk cache MDP berdasarkan seluruh input wajib HDS-06.
func _build_mdp_cache_key(normalized_model: Dictionary, provider: Dictionary, belief_dist: Variant) -> String:
	var canonical: Variant = _canonicalize_for_cache({
		"model": {
			"state_ids": normalized_model.get("state_ids", []),
			"initial_states": normalized_model.get("initial_states", []),
			"terminal_states": normalized_model.get("terminal_states", []),
			"terminal_classes": normalized_model.get("terminal_classes", {}),
			"actions_by_state": normalized_model.get("actions_by_state", {}),
			"reward_by_state": normalized_model.get("reward_by_state", {}),
			"discount_factor": normalized_model.get("discount_factor", 0.0)
		},
		"transition_spec": provider.get("transition_spec", {}),
		"params": provider.get("params", {}),
		"provider_meta": {
			"state_ids": provider.get("state_ids", []),
			"initial_states": provider.get("initial_states", []),
			"terminal_states": provider.get("terminal_states", []),
			"actions_by_state": provider.get("actions_by_state", {})
		},
		"battle_epoch": battle_epoch,
		"belief_distribution": belief_dist,
		"epsilon": uncertainty_epsilon,
		"max_iterations": uncertainty_max_iterations,
		"probability_tolerance": uncertainty_probability_tolerance,
		"comparison_tolerance": uncertainty_comparison_tolerance
	})
	return JSON.stringify(canonical, "", true)

# Memvalidasi struktur wajib BeliefRecord serta aturan lifecycle epoch & source_turn (HDS-07).
func _validate_belief_lifecycle(belief: Dictionary) -> String:
	if belief.is_empty():
		return "INVALID_BELIEF_RECORD"

	if active_belief_epoch != battle_epoch:
		return "STALE_BELIEF_EPOCH"

	if belief.has("battle_epoch") and int(belief["battle_epoch"]) != battle_epoch:
		return "STALE_BELIEF_EPOCH"

	if not belief.has("type") or not belief["type"] is String:
		return "INVALID_BELIEF_TYPE"

	var b_type: String = str(belief["type"])
	if b_type != "INITIAL_PRIOR" and b_type != "BAYES_UPDATE":
		return "INVALID_BELIEF_TYPE"

	if not belief.has("source_turn") or not belief["source_turn"] is int:
		return "INVALID_BELIEF_TURN"

	var source_turn: int = int(belief["source_turn"])
	if source_turn < 0 or source_turn > current_turn:
		return "INVALID_BELIEF_TURN"

	if b_type == "INITIAL_PRIOR" and source_turn != 0:
		return "INVALID_BELIEF_TURN"

	if not belief.has("distribution") or not belief["distribution"] is Dictionary:
		return "INVALID_BELIEF_DISTRIBUTION"

	var dist: Dictionary = belief["distribution"]
	if dist.is_empty():
		return "EMPTY_BELIEF_DISTRIBUTION"

	var prob_sum: float = 0.0
	for h in dist:
		if not h is String or h.strip_edges().is_empty():
			return "INVALID_HYPOTHESIS_ID"

		var p_val: Variant = dist[h]
		if not _is_valid_probability_value(p_val):
			return "INVALID_BELIEF_PROBABILITY"

		prob_sum += float(p_val)
		if not is_finite(prob_sum):
			return "INVALID_BELIEF_PROBABILITY_SUM"

	if abs(prob_sum - 1.0) > uncertainty_probability_tolerance:
		return "INVALID_BELIEF_PROBABILITY_SUM"

	return ""

# Mencatat log terstruktur uncertainty sesuai kontrak HDS-09.
# Memisahkan runtime_ms (durasi aktual pemanggilan saat ini) dan vi_runtime_ms (durasi murni solver VI).
func _record_uncertainty_log(status: String, error_ids: Array, iterations: int, delta: Variant, runtime_ms: Variant, meu_rec: Variant, mdp_rec: Variant, fallback_reason: Variant = null, kb_rejection_reason: Variant = null, integration_error: Variant = null, vi_runtime_ms: Variant = null, mdp_cache_hit: bool = false) -> void:
	uncertainty_sequence_id += 1

	var entry := {
		"timestamp": Time.get_unix_time_from_system(),
		"battle_epoch": battle_epoch,
		"turn": current_turn,
		"sequence_id": uncertainty_sequence_id,
		"status": status,
		"error_ids": error_ids.duplicate(true),
		"integration_error": integration_error,
		"iterations": iterations,
		"delta": delta,
		"runtime_ms": runtime_ms,
		"vi_runtime_ms": vi_runtime_ms,
		"mdp_cache_hit": mdp_cache_hit,
		"meu_recommendation": meu_rec,
		"mdp_recommendation": mdp_rec,
		"fallback_reason": fallback_reason,
		"kb_rejection_reason": kb_rejection_reason
	}

	uncertainty_logs.append(entry)

# Mengaktifkan fallback advisory tanpa menyentuh current_plan UCS/A* atau KB R0-R9 (HDS-08).
# Sesuai HDS-08, UCS/A* dan KB R0-R9 tetap menjadi otoritas eksekusi tunggal.
func _trigger_uncertainty_fallback(reason: String) -> void:
	uncertainty_fallback_active = true
	if not uncertainty_advisory.is_empty():
		uncertainty_advisory["advisory_recommendation"] = null
		uncertainty_advisory["fallback_active"] = true
		uncertainty_advisory["fallback_reason"] = reason

# Memperbarui rekomendasi berdasarkan kondisi ketidakpastian terbaru
func refresh_uncertainty_advisory() -> Dictionary:
	var advisory_start_usec := Time.get_ticks_usec()

	if not uncertainty_is_configured:
		return _uncertainty_fail_and_log("UNCERTAINTY_NOT_CONFIGURED", [], null, 0, null, float(Time.get_ticks_usec() - advisory_start_usec) / 1000.0)

	if not uncertainty_transition_provider.is_valid():
		return _uncertainty_fail_and_log("TRANSITION_PROVIDER_UNAVAILABLE", [], "TRANSITION_PROVIDER_UNAVAILABLE", 0, null, float(Time.get_ticks_usec() - advisory_start_usec) / 1000.0)

	if not uncertainty_meu_provider.is_valid():
		return _uncertainty_fail_and_log("MEU_PROVIDER_UNAVAILABLE", [], "MEU_PROVIDER_UNAVAILABLE", 0, null, float(Time.get_ticks_usec() - advisory_start_usec) / 1000.0)

	# Menggunakan active_belief_record sebagai sumber utama agar hasil Bayesian update tidak tertimpa (HDS-07).
	if active_belief_record.is_empty():
		var init_rec := _create_initial_prior_record()
		var prior_errors := _validate_belief_record(init_rec, "INITIAL_PRIOR", 0)
		if prior_errors.is_empty():
			active_belief_record = init_rec
			active_belief_epoch = battle_epoch
		else:
			return _uncertainty_fail_and_log("MISSING_PRIOR", prior_errors, null, 0, null, float(Time.get_ticks_usec() - advisory_start_usec) / 1000.0)

	var belief: Dictionary = active_belief_record.duplicate(true)

	# Memvalidasi struktur wajib dan lifecycle BeliefRecord sebelum masuk ke solver (HDS-07).
	var lifecycle_error := _validate_belief_lifecycle(belief)
	if lifecycle_error != "":
		return _uncertainty_fail_and_log(lifecycle_error, [], lifecycle_error, 0, null, float(Time.get_ticks_usec() - advisory_start_usec) / 1000.0)

	# Mengambil distribusi belief yang sudah tervalidasi.
	var belief_dist: Dictionary = belief["distribution"]

	# Menyiapkan transition berdasarkan belief terbaru.
	var transition_result = uncertainty_transition_provider.call(belief)
	if not _uncertainty_result_is_valid(transition_result):
		var trans_errors: Array = transition_result.get("errors", []) if transition_result is Dictionary else []
		var fail_code := "INVALID_MAPPING" if trans_errors.has("INVALID_MAPPING") else "TRANSITION_PROVIDER_ERROR"
		return _uncertainty_fail_and_log(fail_code, trans_errors, fail_code, 0, null, float(Time.get_ticks_usec() - advisory_start_usec) / 1000.0)

	var provider: Dictionary = transition_result.get("data", {})

	# Membuat dan memvalidasi model keputusan.
	var model_result = DECISION_MODEL.create_model(uncertainty_model_config)
	if not _uncertainty_result_is_valid(model_result):
		return _uncertainty_fail_and_log("INVALID_DECISION_MODEL", model_result.get("errors", []), null, 0, null, float(Time.get_ticks_usec() - advisory_start_usec) / 1000.0)

	var model: Dictionary = model_result.get("data", {}).get("model", {})

	var validation_result = DECISION_MODEL.validate_model(model, provider, uncertainty_probability_tolerance)
	if not _uncertainty_result_is_valid(validation_result):
		return _uncertainty_fail_and_log("MODEL_VALIDATION_FAILED", validation_result.get("errors", []), null, 0, null, float(Time.get_ticks_usec() - advisory_start_usec) / 1000.0)

	# Menghitung Maximum Expected Utility dengan cache MEU terpisah (HDS-06).
	var meu_result = _calculate_uncertainty_meu(belief, belief_dist)
	if not _uncertainty_result_is_valid(meu_result):
		return _uncertainty_fail_and_log("MEU_CALCULATION_FAILED", meu_result.get("errors", []), null, 0, null, float(Time.get_ticks_usec() - advisory_start_usec) / 1000.0)

	var meu_data: Dictionary = meu_result.get("data", {})
	var meu_rec: Variant = meu_data.get("best_action")

	# Memastikan rekomendasi MEU tersedia dan valid.
	if not meu_rec is String or meu_rec.strip_edges().is_empty():
		return _uncertainty_fail_and_log("MISSING_MEU_RECOMMENDATION", [], null, 0, null, float(Time.get_ticks_usec() - advisory_start_usec) / 1000.0, meu_rec)

	# Memeriksa cache MDP dan batasan maksimal satu kali Value Iteration per turn (HDS-06).
	# Pada cache hit, vi_runtime_ms = 0.0 (tidak memakai waktu komputasi pemanggilan sebelumnya) (poin B).
	var mdp_key := _build_mdp_cache_key(model, provider, belief_dist)
	var mdp_result: Dictionary
	var vi_runtime_ms: Variant = null
	var mdp_cache_hit: bool = false

	if mdp_key == _mdp_cache_key and not _mdp_cache_result.is_empty():
		mdp_result = _mdp_cache_result.duplicate(true)
		mdp_cache_hit = true
		vi_runtime_ms = 0.0
	else:
		# Jika input berubah di tengah turn setelah VI berjalan, tolak secara eksplisit tanpa memakai hasil lama.
		if _vi_executed_epoch == battle_epoch and _vi_executed_turn == current_turn:
			return _uncertainty_fail_and_log("VI_TURN_LIMIT_REACHED", [], null, 0, null, float(Time.get_ticks_usec() - advisory_start_usec) / 1000.0, meu_rec)

		var vi_start_usec := Time.get_ticks_usec()

		mdp_result = MDP_SOLVER.value_iteration(
			model,
			provider,
			uncertainty_epsilon,
			uncertainty_max_iterations,
			uncertainty_probability_tolerance,
			uncertainty_comparison_tolerance
		)

		vi_runtime_ms = float(Time.get_ticks_usec() - vi_start_usec) / 1000.0
		_vi_executed_epoch = battle_epoch
		_vi_executed_turn = current_turn

		if _uncertainty_result_is_valid(mdp_result):
			_mdp_cache_key = mdp_key
			_mdp_cache_result = mdp_result.duplicate(true)

	# Menghentikan proses jika eksekusi Value Iteration gagal.
	if not _uncertainty_result_is_valid(mdp_result):
		var fail_data: Dictionary = mdp_result.get("data", {}) if mdp_result is Dictionary else {}
		var fail_iters: int = int(fail_data.get("iterations", 0))
		var fail_delta: Variant = fail_data.get("delta", null)
		return _uncertainty_fail_and_log(
			"MDP_CALCULATION_FAILED",
			mdp_result.get("errors", []),
			null,
			fail_iters,
			fail_delta,
			float(Time.get_ticks_usec() - advisory_start_usec) / 1000.0,
			meu_rec,
			null,
			true,
			vi_runtime_ms,
			mdp_cache_hit
		)

	var mdp_data: Dictionary = mdp_result.get("data", {})

	# Hasil yang belum konvergen tidak boleh dianggap policy optimal dan memicu fallback (HDS-06).
	if mdp_data.get("status", "") != "CONVERGED":
		return _uncertainty_fail_and_log(
			"MAX_ITERATIONS_REACHED",
			mdp_result.get("errors", []),
			null,
			int(mdp_data.get("iterations", 0)),
			mdp_data.get("delta", null),
			float(Time.get_ticks_usec() - advisory_start_usec) / 1000.0,
			meu_rec,
			null,
			true,
			vi_runtime_ms,
			mdp_cache_hit
		)

	# Mengambil dan memvalidasi kelengkapan rekomendasi policy MDP pada initial state.
	var initial_states: Array = model.get("initial_states", [])
	var primary_state: String = str(initial_states[0]) if not initial_states.is_empty() else ""
	var policy: Dictionary = mdp_data.get("policy", {})
	var mdp_rec: Variant = policy.get(primary_state) if primary_state != "" and policy.has(primary_state) else null

	if not mdp_rec is String or mdp_rec.strip_edges().is_empty():
		return _uncertainty_fail_and_log(
			"MISSING_MDP_RECOMMENDATION",
			[],
			null,
			int(mdp_data.get("iterations", 0)),
			mdp_data.get("delta", null),
			float(Time.get_ticks_usec() - advisory_start_usec) / 1000.0,
			meu_rec,
			mdp_rec,
			true,
			vi_runtime_ms,
			mdp_cache_hit
		)

	# Menangani konflik rekomendasi antara MEU dan MDP sesuai HDS-08 (catat & defer ke UCS/A*).
	var has_conflict: bool = (str(meu_rec) != str(mdp_rec))
	var advisory_status: String = "RECOMMENDATION_CONFLICT" if has_conflict else "READY"
	var fallback_reason: Variant = "recommendation_conflict" if has_conflict else null
	var current_runtime_ms: float = float(Time.get_ticks_usec() - advisory_start_usec) / 1000.0

	# Menyimpan hasil sementara sebelum pemeriksaan wajib KB R0-R9 (advisory_recommendation masih null).
	uncertainty_advisory = {
		"valid": true,
		"battle_epoch": battle_epoch,
		"turn": current_turn,
		"belief": belief,
		"meu": meu_data,
		"mdp": mdp_data,
		"validation": validation_result.get("data", {}),
		"advisory_recommendation": null,
		"recommendation_conflict": has_conflict,
		"fallback_active": has_conflict,
		"fallback_reason": fallback_reason,
		"kb_validated": false,
		"kb_rejected": false,
		"kb_rejection_reason": null,
		"runtime_ms": current_runtime_ms,
		"vi_runtime_ms": vi_runtime_ms,
		"mdp_cache_hit": mdp_cache_hit,
		"status": advisory_status
	}

	if has_conflict:
		_trigger_uncertainty_fallback("recommendation_conflict")
		_record_uncertainty_log(
			advisory_status,
			["recommendation_conflict"],
			int(mdp_data.get("iterations", 0)),
			mdp_data.get("delta", null),
			current_runtime_ms,
			meu_rec,
			mdp_rec,
			fallback_reason,
			null,
			null,
			vi_runtime_ms,
			mdp_cache_hit
		)
		return {
			"valid": true,
			"errors": [],
			"data": uncertainty_advisory.duplicate(true)
		}

	# HDS-08: KB R0-R9 adalah otoritas validasi wajib. Jika validator KB tidak tersedia,
	# rekomendasi tidak boleh dianggap disetujui KB secara diam-diam.
	if not uncertainty_kb_validator.is_valid():
		return _uncertainty_fail_and_log(
			"KB_VALIDATOR_UNAVAILABLE",
			[],
			"KB_VALIDATOR_UNAVAILABLE",
			int(mdp_data.get("iterations", 0)),
			mdp_data.get("delta", null),
			float(Time.get_ticks_usec() - advisory_start_usec) / 1000.0,
			meu_rec,
			mdp_rec,
			true,
			vi_runtime_ms,
			mdp_cache_hit
		)

	# Memvalidasi rekomendasi terhadap KB R0-R9 dan memeriksa struktur kembaliannya.
	var kb_check: Variant = uncertainty_kb_validator.call(mdp_rec, current_state)
	var kb_ok: bool = false
	var kb_reason: String = "kb_r0_r9_rejected"

	if kb_check is bool:
		kb_ok = kb_check
	elif kb_check is Dictionary and kb_check.has("valid") and kb_check["valid"] is bool:
		kb_ok = kb_check["valid"]
		kb_reason = str(kb_check.get("reason", kb_reason))
	else:
		return _uncertainty_fail_and_log(
			"KB_VALIDATOR_ERROR",
			[],
			"KB_VALIDATOR_INVALID_RESPONSE",
			int(mdp_data.get("iterations", 0)),
			mdp_data.get("delta", null),
			float(Time.get_ticks_usec() - advisory_start_usec) / 1000.0,
			meu_rec,
			mdp_rec,
			true,
			vi_runtime_ms,
			mdp_cache_hit
		)

	uncertainty_advisory["runtime_ms"] = float(Time.get_ticks_usec() - advisory_start_usec) / 1000.0
	return apply_kb_validation_to_uncertainty(kb_ok, kb_reason)

# Memvalidasi rekomendasi uncertainty terhadap KB R0-R9 dan menangani penolakan KB sesuai HDS-08.
# Memastikan advisory masih berasal dari epoch, turn, dan belief aktif sebelum diproses.
func apply_kb_validation_to_uncertainty(kb_approved: bool, rejection_reason: String = "") -> Dictionary:
	if not uncertainty_is_configured:
		return _uncertainty_fail_and_log("UNCERTAINTY_NOT_CONFIGURED")

	if uncertainty_advisory.is_empty():
		return _uncertainty_fail_and_log("UNCERTAINTY_ADVISORY_EMPTY")

	# Pastikan advisory tidak sedang dalam status gagal atau konflik rekomendasi.
	if not bool(uncertainty_advisory.get("valid", false)) or bool(uncertainty_advisory.get("recommendation_conflict", false)):
		return _uncertainty_fail_and_log("INVALID_ADVISORY_STATE")

	# Pastikan epoch advisory masih sesuai dengan epoch battle dan belief aktif.
	if int(uncertainty_advisory.get("battle_epoch", -1)) != battle_epoch or active_belief_epoch != battle_epoch:
		return _uncertainty_fail_and_log("STALE_ADVISORY_EPOCH")

	# Pastikan turn advisory masih sesuai dengan current_turn aktif.
	if int(uncertainty_advisory.get("turn", -1)) != current_turn:
		return _uncertainty_fail_and_log("STALE_ADVISORY_TURN")

	# Pastikan belief aktif masih valid dan identik dengan belief pada advisory.
	var belief_lifecycle_err := _validate_belief_lifecycle(active_belief_record)
	if belief_lifecycle_err != "":
		return _uncertainty_fail_and_log(belief_lifecycle_err)

	var advisory_belief: Variant = uncertainty_advisory.get("belief", {})
	if not advisory_belief is Dictionary or (advisory_belief as Dictionary).is_empty():
		return _uncertainty_fail_and_log("INVALID_ADVISORY_BELIEF")

	if _canonicalize_for_cache(advisory_belief) != _canonicalize_for_cache(active_belief_record):
		return _uncertainty_fail_and_log("STALE_ADVISORY_BELIEF")

	var meu_rec: Variant = get_uncertainty_meu_recommendation()
	var initial_states: Array = uncertainty_model_config.get("initial_states", [])
	var primary_state: String = str(initial_states[0]) if not initial_states.is_empty() else ""
	var mdp_rec: Variant = get_uncertainty_mdp_recommendation(primary_state) if primary_state != "" else null
	var mdp_data: Dictionary = uncertainty_advisory.get("mdp", {})
	var recorded_runtime_ms: Variant = uncertainty_advisory.get("runtime_ms", null)
	var recorded_vi_ms: Variant = uncertainty_advisory.get("vi_runtime_ms", null)
	var recorded_cache_hit: bool = bool(uncertainty_advisory.get("mdp_cache_hit", false))

	if not meu_rec is String or meu_rec.strip_edges().is_empty() or not mdp_rec is String or mdp_rec.strip_edges().is_empty():
		return _uncertainty_fail_and_log("MISSING_ADVISORY_RECOMMENDATION")

	if not kb_approved:
		var reason := rejection_reason if not rejection_reason.is_empty() else "kb_r0_r9_rejected"
		_trigger_uncertainty_fallback("kb_rejection: " + reason)

		uncertainty_advisory["advisory_recommendation"] = null
		uncertainty_advisory["kb_validated"] = true
		uncertainty_advisory["kb_rejected"] = true
		uncertainty_advisory["kb_rejection_reason"] = reason
		uncertainty_advisory["status"] = "KB_REJECTED"

		_record_uncertainty_log(
			"KB_REJECTED",
			["KB_REJECTION"],
			int(mdp_data.get("iterations", 0)),
			mdp_data.get("delta", null),
			recorded_runtime_ms,
			meu_rec,
			mdp_rec,
			"kb_rejection",
			reason,
			null,
			recorded_vi_ms,
			recorded_cache_hit
		)

		return {
			"valid": false,
			"errors": ["KB_REJECTION"],
			"data": uncertainty_advisory.duplicate(true)
		}

	uncertainty_fallback_active = false
	uncertainty_advisory["advisory_recommendation"] = mdp_rec
	uncertainty_advisory["kb_validated"] = true
	uncertainty_advisory["kb_rejected"] = false
	uncertainty_advisory["kb_rejection_reason"] = null
	uncertainty_advisory["status"] = "READY"

	_record_uncertainty_log(
		"READY",
		[],
		int(mdp_data.get("iterations", 0)),
		mdp_data.get("delta", null),
		recorded_runtime_ms,
		meu_rec,
		mdp_rec,
		null,
		null,
		null,
		recorded_vi_ms,
		recorded_cache_hit
	)

	return {
		"valid": true,
		"errors": [],
		"data": uncertainty_advisory.duplicate(true)
	}

# Menyelesaikan dan memvalidasi probabilitas akhir outcome P(o | a, b):
# 1) Jika outcome["probability"] tersedia, validasi numerik, finite, dan rentang [0.0, 1.0].
# 2) Jika tidak tersedia, hitung marginalisasi sum_h P(o | a, h) * b(h) dari outcome_likelihood.
func _resolve_outcome_probability(action_id: Variant, outcome: Dictionary, outcome_likelihood: Variant, belief_dist: Dictionary) -> Variant:
	if outcome.has("probability") and outcome["probability"] != null:
		var raw_prob: Variant = outcome["probability"]
		if not _is_valid_probability_value(raw_prob):
			return null
		return float(raw_prob)

	if not outcome_likelihood is Dictionary or outcome_likelihood.is_empty():
		return null

	var outcome_id: Variant = outcome.get("id")
	if not outcome_id is String or str(outcome_id).strip_edges().is_empty():
		return null

	var per_hypothesis: Variant = null

	if outcome_likelihood.has(action_id) and outcome_likelihood[action_id] is Dictionary:
		var action_lh: Dictionary = outcome_likelihood[action_id]
		if action_lh.has(outcome_id):
			per_hypothesis = action_lh[outcome_id]
	elif outcome_likelihood.has(outcome_id):
		per_hypothesis = outcome_likelihood[outcome_id]

	if not per_hypothesis is Dictionary or per_hypothesis.is_empty():
		return null

	# Pastikan himpunan hipotesis pada likelihood sama dengan hipotesis pada belief aktif.
	if per_hypothesis.size() != belief_dist.size():
		return null

	var marginalized_prob: float = 0.0
	for h in belief_dist:
		if not per_hypothesis.has(h):
			return null
		var lh_val: Variant = per_hypothesis[h]
		if not _is_valid_probability_value(lh_val):
			return null
		marginalized_prob += float(lh_val) * float(belief_dist[h])

	if not is_finite(marginalized_prob) or marginalized_prob < 0.0 or marginalized_prob > 1.0 + uncertainty_probability_tolerance:
		return null

	return clampf(marginalized_prob, 0.0, 1.0)

# Menghitung Expected Utility untuk setiap alternatif tindakan dengan cache MEU terpisah (HDS-06).
# Memastikan total probabilitas seluruh outcome untuk setiap action tepat 1.0 dalam toleransi (poin A).
func _calculate_uncertainty_meu(belief: Dictionary, belief_dist: Dictionary) -> Dictionary:
	print("MEU BELIEF: ", belief)
	print("MEU BELIEF DIST: ", belief_dist)

	var outcome_result = uncertainty_meu_provider.call(belief)

	if not _uncertainty_result_is_valid(outcome_result):
		return _uncertainty_error("MEU_OUTCOME_PROVIDER_ERROR")

	var raw_data: Dictionary = outcome_result.get("data", {})
	var outcomes_by_action: Dictionary = raw_data.get("outcomes_by_action", raw_data)

	if raw_data.has("outcome_likelihood") and raw_data["outcome_likelihood"] != null and not raw_data["outcome_likelihood"] is Dictionary:
		return _uncertainty_error("INVALID_OUTCOME_LIKELIHOOD")

	var outcome_likelihood: Dictionary = raw_data.get("outcome_likelihood", {}) if raw_data.get("outcome_likelihood") is Dictionary else {}

	if outcomes_by_action.is_empty():
		return _uncertainty_error("EMPTY_OUTCOMES_BY_ACTION")

	# Memeriksa cache MEU sebelum menghitung ulang (HDS-06).
	var meu_key := _build_meu_cache_key(belief_dist, outcomes_by_action, outcome_likelihood)

	print("MEU CACHE KEY: ", meu_key)

	if meu_key == _meu_cache_key and not _meu_cache_result.is_empty():
		return _meu_cache_result.duplicate(true)

	var actions_with_utility: Dictionary = {}

	for action_id in outcomes_by_action:
		var outcomes = outcomes_by_action[action_id]

		if not outcomes is Array or outcomes.is_empty():
			return _uncertainty_error("INVALID_OUTCOMES")

		var prepared_outcomes: Array = []
		var prob_sum: float = 0.0

		for outcome in outcomes:
			if not outcome is Dictionary:
				return _uncertainty_error("INVALID_OUTCOME")

			var outcome_id: Variant = outcome.get("id")
			if not outcome_id is String or str(outcome_id).strip_edges().is_empty():
				return _uncertainty_error("INVALID_OUTCOME_ID")

			var resolved_prob: Variant = _resolve_outcome_probability(
				action_id,
				outcome,
				outcome_likelihood,
				belief_dist
			)

			if resolved_prob == null:
				return _uncertainty_error("INVALID_OUTCOME_PROBABILITY")

			prob_sum += float(resolved_prob)

			if not is_finite(prob_sum):
				return _uncertainty_error("INVALID_OUTCOME_PROBABILITY_SUM")

			var utility_result = DECISION_MODEL.get_utility(uncertainty_utility_map, outcome_id)

			if not _uncertainty_result_is_valid(utility_result):
				return _uncertainty_error(
					"INVALID_OUTCOME_UTILITY",
					utility_result.get("errors", [])
				)

			prepared_outcomes.append({
				"id": outcome_id,
				"probability": resolved_prob,
				"utility": utility_result.get("data", {}).get("utility")
			})

		# Pastikan distribusi probabilitas seluruh outcome pada action ini berjumlah 1.0.
		if abs(prob_sum - 1.0) > uncertainty_probability_tolerance:
			return _uncertainty_error("INVALID_OUTCOME_PROBABILITY_SUM")

		actions_with_utility[action_id] = prepared_outcomes

	var choose_result: Dictionary = EXPECTED_UTILITY.choose_meu(
		actions_with_utility,
		uncertainty_probability_tolerance,
		uncertainty_comparison_tolerance
	)

	if _uncertainty_result_is_valid(choose_result):
		_meu_cache_key = meu_key
		_meu_cache_result = choose_result.duplicate(true)

	return choose_result

# Memeriksa format hasil dari komponen lain
func _uncertainty_result_is_valid(result: Variant) -> bool:
	if not result is Dictionary:
		return false

	if not result.has("valid"):
		return false

	if not result.has("errors") or not result.has("data"):
		return false

	return result["valid"] == true

# Mencatat kegagalan ke log terstruktur HDS-09 dan mengembalikan Result error.
# invalidate_advisory = false digunakan saat menolak evidence tidak valid agar advisory sah sebelumnya tidak hilang.
func _uncertainty_fail_and_log(error_code: String, details: Array = [], integration_error: Variant = null, iterations: int = 0, delta: Variant = null, runtime_ms: Variant = null, meu_rec: Variant = null, mdp_rec: Variant = null, invalidate_advisory: bool = true, vi_runtime_ms: Variant = null, mdp_cache_hit: bool = false) -> Dictionary:
	var err_result := _uncertainty_error(error_code, details)

	if invalidate_advisory:
		uncertainty_fallback_active = true
		uncertainty_advisory = {
			"valid": false,
			"battle_epoch": battle_epoch,
			"turn": current_turn,
			"advisory_recommendation": null,
			"fallback_active": true,
			"fallback_reason": error_code,
			"kb_validated": false,
			"kb_rejected": false,
			"runtime_ms": runtime_ms,
			"vi_runtime_ms": vi_runtime_ms,
			"mdp_cache_hit": mdp_cache_hit,
			"status": error_code
		}

	_record_uncertainty_log(
		error_code,
		err_result["errors"],
		iterations,
		delta,
		runtime_ms,
		meu_rec,
		mdp_rec,
		error_code,
		null,
		integration_error,
		vi_runtime_ms,
		mdp_cache_hit
	)

	return err_result

# Membuat hasil error dengan format Result
func _uncertainty_error(error_code: String, details: Array = []) -> Dictionary:
	var errors: Array = [error_code]

	for detail in details:
		if not errors.has(detail):
			errors.append(detail)

	return {
		"valid": false,
		"errors": errors,
		"data": {
			"status": error_code
		}
	}

# Memeriksa apakah uncertainty_advisory memiliki sumber belief terverifikasi dan sinkron dengan state aktif (poin C).
func _is_uncertainty_advisory_fresh() -> bool:
	if not uncertainty_is_configured or uncertainty_advisory.is_empty():
		return false

	if int(uncertainty_advisory.get("battle_epoch", -1)) != battle_epoch:
		return false

	if active_belief_epoch != battle_epoch:
		return false

	if int(uncertainty_advisory.get("turn", -1)) != current_turn:
		return false

	if not uncertainty_advisory.has("belief") or not uncertainty_advisory["belief"] is Dictionary:
		return false

	var advisory_belief: Dictionary = uncertainty_advisory["belief"]
	if advisory_belief.is_empty():
		return false

	if active_belief_record.is_empty() or _validate_belief_lifecycle(active_belief_record) != "":
		return false

	if _canonicalize_for_cache(advisory_belief) != _canonicalize_for_cache(active_belief_record):
		return false

	return true

# Mengambil seluruh hasil advisory dengan perlindungan terhadap data kedaluwarsa.
func get_uncertainty_advisory() -> Dictionary:
	if uncertainty_advisory.is_empty():
		return {}

	var snapshot: Dictionary = uncertainty_advisory.duplicate(true)
	if not _is_uncertainty_advisory_fresh():
		snapshot["valid"] = false
		snapshot["advisory_recommendation"] = null
		snapshot["fallback_active"] = true
		snapshot["fallback_reason"] = "stale_advisory"
		snapshot["status"] = "STALE_ADVISORY"

	return snapshot

# Mengambil rekomendasi berdasarkan Maximum Expected Utility hanya jika advisory masih berlaku.
func get_uncertainty_meu_recommendation() -> Variant:
	if not _is_uncertainty_advisory_fresh():
		return null

	if not bool(uncertainty_advisory.get("valid", false)):
		return null

	return uncertainty_advisory.get("meu", {}).get("best_action")

# Mengambil rekomendasi policy MDP berdasarkan state hanya jika advisory masih berlaku.
func get_uncertainty_mdp_recommendation(state_id: String) -> Variant:
	if not _is_uncertainty_advisory_fresh():
		return null

	if not bool(uncertainty_advisory.get("valid", false)):
		return null

	var policy: Dictionary = uncertainty_advisory.get("mdp", {}).get("policy", {})

	return policy.get(state_id)

# Mengambil seluruh entri log terstruktur uncertainty (HDS-09).
func get_uncertainty_logs() -> Array:
	return uncertainty_logs.duplicate(true)

func set_planner_mode(mode: String) -> void:
	match mode:
		"ucs":
			planner_mode = PLANNER.MODE_UCS
		"astar_manhattan", "astar_euclidean":
			planner_mode = PLANNER.MODE_ASTAR
		_:
			planner_mode = PLANNER.MODE_UCS

	print("PLANNER MODE SET: ", planner_mode)
		
