extends RefCounted
class_name PlanningLog

const STATUS_PENDING := "pending"
const STATUS_SENT := "sent"
const STATUS_EXECUTED := "executed"
const STATUS_REJECTED := "rejected"
const STATUS_SKIPPED := "skipped"

const EVENT_PLAN := "plan"
const EVENT_VALIDATION := "validation"
const EVENT_EXECUTION := "execution"
const EVENT_REPLAN := "replan"
const EVENT_FALLBACK := "fallback"
const EVENT_GOAL := "goal"
const EVENT_RESULT := "result"
const EVENT_ERROR := "integration_error"

# Menyimpan seluruh riwayat aktivitas planning berdasarkan urutan kejadian.
var entries: Array = []
var seq_counter: int = 0

# Menghapus seluruh riwayat dan mengatur ulang nomor urut entri.
func clear_log() -> void:
	entries.clear()
	seq_counter = 0

# Membuat entri baru dengan nomor urut dan salinan data agar riwayat tidak berubah dari luar.
func _add_entry(turn: int, event_type: String, data: Dictionary = {}) -> Dictionary:
	seq_counter += 1

	var entry := {
		"seq_id": seq_counter,
		"turn": turn,
		"event_type": event_type,
		"data": data.duplicate(true)
	}

	entries.append(entry)
	return entry.duplicate(true)

# Mencatat hasil pencarian plan beserta seluruh langkah yang dihasilkan.
func log_plan(turn: int, plan: Dictionary) -> void:
	var plan_data := {
		"status": str(plan.get("status", "no_plan")),
		"mode": str(plan.get("mode", "")),
		"goal": str(plan.get("goal", "")),
		"steps": plan.get("steps", []).duplicate(true),
		"total_cost": int(plan.get("total_cost", 0)),
		"nodes_expanded": int(plan.get("nodes_expanded", 0)),
		"time_ms": float(plan.get("time_ms", 0.0)),
		"reason": str(plan.get("reason", ""))
	}

	_add_entry(turn, EVENT_PLAN, plan_data)

	# Setiap langkah dimulai dengan status pending sebelum dikirim ke battle.
	for step in plan.get("steps", []):
		_add_entry(turn, EVENT_EXECUTION, {
			"action": str(step.get("action", "")),
			"npc": str(step.get("npc", "")),
			"cost": int(step.get("cost", 0)),
			"status": STATUS_PENDING,
			"reason": "waiting_for_execution"
		})

# Mencatat hasil validasi aksi beserta alasan diterima atau ditolaknya aksi.
func log_validation(turn: int, action: Dictionary, is_valid: bool, reason: String) -> void:
	_add_entry(turn, EVENT_VALIDATION, {
		"action": str(action.get("type", "")),
		"npc": str(action.get("npc", "")),
		"valid": is_valid,
		"reason": reason
	})

# Mencatat bahwa aksi sudah dikirim dari controller ke battle.
func log_sent(turn: int, action: Dictionary) -> void:
	_add_entry(turn, EVENT_EXECUTION, {
		"action": str(action.get("type", "")),
		"npc": str(action.get("npc", "")),
		"cost": int(action.get("cost", 0)),
		"status": STATUS_SENT,
		"reason": "action_sent_to_battle"
	})

# Mencatat hasil akhir eksekusi aksi berdasarkan respons dari battle.
func log_execution(turn: int, action: Dictionary, status: String, reason: String) -> void:
	var normalized_status := status

	# Status error diseragamkan menjadi rejected agar sesuai dengan status log.
	if status == "error":
		normalized_status = STATUS_REJECTED

	if normalized_status != STATUS_EXECUTED and normalized_status != STATUS_REJECTED and normalized_status != STATUS_SKIPPED:
		normalized_status = STATUS_SKIPPED

	_add_entry(turn, EVENT_EXECUTION, {
		"action": str(action.get("type", "")),
		"npc": str(action.get("npc", "")),
		"cost": int(action.get("cost", 0)),
		"status": normalized_status,
		"reason": reason
	})

# Mencatat langkah plan lama yang dibatalkan dan alasan pembatalannya.
func log_plan_step_cancelled(turn: int, step: Dictionary, reason: String) -> void:
	_add_entry(turn, EVENT_EXECUTION, {
		"action": str(step.get("action", step.get("type", ""))),
		"npc": str(step.get("npc", "")),
		"cost": int(step.get("cost", 0)),
		"status": STATUS_SKIPPED,
		"reason": reason
	})

# Mencatat kesalahan integrasi dari battle, inference engine, atau proses planning.
func log_integration_error(turn: int, source: String, message: String) -> void:
	_add_entry(turn, EVENT_ERROR, {
		"source": source,
		"message": message
	})

# Mencatat proses replan beserta plan baru yang dihasilkan.
func log_replan(turn: int, reason: String, new_plan: Dictionary) -> void:
	_add_entry(turn, EVENT_REPLAN, {
		"reason": reason,
		"status": str(new_plan.get("status", "no_plan")),
		"mode": str(new_plan.get("mode", "")),
		"steps": new_plan.get("steps", []).duplicate(true),
		"total_cost": int(new_plan.get("total_cost", 0)),
		"nodes_expanded": int(new_plan.get("nodes_expanded", 0)),
		"time_ms": float(new_plan.get("time_ms", 0.0)),
		"plan_reason": str(new_plan.get("reason", ""))
	})

	# Langkah dari plan baru kembali dimulai dengan status pending.
	for step in new_plan.get("steps", []):
		_add_entry(turn, EVENT_EXECUTION, {
			"action": str(step.get("action", "")),
			"npc": str(step.get("npc", "")),
			"cost": int(step.get("cost", 0)),
			"status": STATUS_PENDING,
			"reason": "waiting_for_replanned_execution"
		})

# Mencatat penggunaan fallback untuk NPC yang tidak memiliki aksi dari plan utama.
func log_fallback(turn: int, npc_id: String, reason: String, action_type: String = "NORMAL_ATTACK") -> void:
	_add_entry(turn, EVENT_FALLBACK, {
		"npc": npc_id,
		"action": action_type,
		"status": "fallback",
		"reason": reason
	})

# Mencatat apakah seluruh NPC hidup berhasil menyelesaikan aksinya.
func log_goal(turn: int, goal_reached: bool, unresolved_npcs: Array) -> void:
	var result_status := "goal_reached"
	if not goal_reached:
		result_status = "goal_not_reached"

	_add_entry(turn, EVENT_GOAL, {
		"goal": "all_alive_npc_resolved",
		"goal_reached": goal_reached,
		"status": result_status,
		"unresolved_npcs": unresolved_npcs.duplicate()
	})

	# Mencatat hasil akhir fase untuk kebutuhan evaluasi.
	_add_entry(turn, EVENT_RESULT, {
		"status": result_status,
		"unresolved_npcs": unresolved_npcs.duplicate()
	})

# Mengambil status terbaru setiap kombinasi aksi dan NPC pada turn tertentu.
# Entri dengan seq_id terbesar menjadi status yang digunakan oleh overlay.
func get_latest_action_statuses(turn: int) -> Dictionary:
	var latest := {}

	for e in entries:
		if int(e["turn"]) != turn or str(e["event_type"]) != EVENT_EXECUTION:
			continue

		var d: Dictionary = e["data"]
		var action_type := str(d.get("action", ""))

		# Entri tanpa aksi merupakan status tingkat NPC, bukan status aksi.
		if action_type.is_empty():
			continue

		var npc_id := str(d.get("npc", ""))

		latest["%s|%s" % [action_type, npc_id]] = {
			"action": action_type,
			"npc": npc_id,
			"cost": int(d.get("cost", 0)),
			"status": str(d.get("status", "")),
			"reason": str(d.get("reason", "")),
			"seq_id": int(e["seq_id"])
		}

	return latest

# Mengambil status terbaru untuk satu aksi dan NPC tertentu.
func get_latest_status(turn: int, action_type: String, npc_id: String) -> String:
	var latest := get_latest_action_statuses(turn)
	var key := "%s|%s" % [action_type, npc_id]

	if not latest.has(key):
		return ""

	return str(latest[key]["status"])

# Memeriksa apakah masih ada aksi berstatus pending pada turn tertentu.
func has_pending_actions(turn: int) -> bool:
	for item in get_latest_action_statuses(turn).values():
		if item["status"] == STATUS_PENDING:
			return true

	return false

# Mengambil catatan skipped tingkat NPC yang tidak terikat pada aksi tertentu.
func get_npc_level_skips(turn: int) -> Array:
	var result: Array = []

	for e in entries:
		if int(e["turn"]) != turn or str(e["event_type"]) != EVENT_EXECUTION:
			continue

		var d: Dictionary = e["data"]

		if str(d.get("action", "")).is_empty() and str(d.get("status", "")) == STATUS_SKIPPED:
			result.append({
				"npc": str(d.get("npc", "")),
				"reason": str(d.get("reason", "")),
				"seq_id": int(e["seq_id"])
			})

	return result

# Mengembalikan seluruh riwayat dengan salinan data.
func get_all_entries() -> Array:
	return entries.duplicate(true)

# Mengambil seluruh entri yang berasal dari turn tertentu.
func get_entries_by_turn(turn: int) -> Array:
	var result: Array = []

	for entry in entries:
		if int(entry.get("turn", -1)) == turn:
			result.append(entry.duplicate(true))

	return result

# Mengambil seluruh entri dari turn yang paling baru dicatat.
func get_latest_turn_entries() -> Array:
	if entries.is_empty():
		return []

	var latest_turn: int = int(entries[entries.size() - 1]["turn"])
	return get_entries_by_turn(latest_turn)

# Mengambil nomor turn terakhir yang tercatat.
func get_latest_turn() -> int:
	if entries.is_empty():
		return -1

	return int(entries[entries.size() - 1]["turn"])

# Mengembalikan jumlah seluruh entri dalam planning log.
func get_entry_count() -> int:
	return entries.size()