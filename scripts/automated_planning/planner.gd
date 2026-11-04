
extends RefCounted
class_name Planner

# Menghubungkan Planner dengan PlanningDomain untuk menggunakan fungsi validasi aksi, penerapan aksi, goal, state key, dan heuristic.
const DOMAIN = preload("res://scripts/automated_planning/planning_domain.gd")

# Mode pencarian yang dapat digunakan oleh planner.
const MODE_UCS := "UCS"
const MODE_ASTAR := "ASTAR"

# Batas maksimum jumlah node yang boleh diekspansi selama pencarian.
# Jika batas ini tercapai sebelum goal ditemukan, pencarian dihentikan.
const MAX_NODES := 5000

static func find_plan(initial_state: Dictionary, planner_mode: String = MODE_UCS) -> Dictionary:
    # Mencatat waktu awal untuk menghitung durasi proses planning.
    var start_time := Time.get_ticks_usec()

    # Menyiapkan struktur hasil planning dengan nilai awal.
    # Status awal no_plan sampai planner berhasil menemukan goal.
    var result := {
        "status": "no_plan",
        "goal": "all_alive_npc_resolved",
        "s0": initial_state.duplicate(true),
        "steps": [],
        "total_cost": 0,
        "nodes_expanded": 0,
        "time_ms": 0.0,
        "mode": planner_mode,
        "reason": ""
    }

    # Memastikan mode pencarian yang diberikan merupakan UCS atau A*.
    if planner_mode != MODE_UCS and planner_mode != MODE_ASTAR:
        result["reason"] = "invalid_planner_mode"
        return _finish_result(result, start_time)

    # Jika seluruh NPC yang masih hidup sudah resolved sejak S0, tidak diperlukan pencarian rencana baru.
    if DOMAIN.is_goal(initial_state):
        result["status"] = "goal_already_true"
        result["reason"] = "Goal sudah terpenuhi pada S0."
        return _finish_result(result, start_time)

    # Planning tidak dapat dilakukan jika target utama sudah tidak hidup.
    if not bool(initial_state.get("target_alive", false)):
        result["reason"] = "target_not_alive"
        return _finish_result(result, start_time)

    # Kedalaman maksimum dibatasi oleh jumlah NPC yang masih hidup.
    # Setiap aksi hanya dapat menyelesaikan satu NPC.
    var max_depth: int = initial_state.get("alive", []).size()

    # Menyimpan seluruh node pencarian.
    # Setiap node berisi state, biaya g, kedalaman, parent, dan aksi.
    # Parent node awal menggunakan -1 sebagai penanda bahwa node ini merupakan akar pencarian dan tidak memiliki parent.
    var nodes: Array = [{
        "state": initial_state.duplicate(true),
        "g": 0,
        "depth": 0,
        "parent": -1,
        "action": {}
    }]

    # Frontier berisi indeks node yang menunggu untuk diekspansi.
    # Pencarian dimulai dari node awal dengan indeks 0.
    var frontier: Array = [0]

    # Visited menyimpan biaya terbaik yang pernah ditemukan untuk setiap state agar state yang sama tidak diproses berulang.
    var visited: Dictionary = {}
    visited[DOMAIN.get_state_key(initial_state)] = 0

    # Menyimpan indeks node goal yang berhasil ditemukan.
    # Nilai -1 berarti goal belum ditemukan.
    var goal_index := -1
    var expanded := 0

    # Pencarian berlangsung selama masih ada node di frontier.
    while not frontier.is_empty():
        # Memilih node dengan prioritas terbaik berdasarkan mode UCS atau A*.
        var best_position := _get_best_frontier_position(frontier, nodes, planner_mode)
        var current_index: int = frontier.pop_at(best_position)

        # Mengambil informasi node yang sedang diproses.
        var current_node: Dictionary = nodes[current_index]
        var current_state: Dictionary = current_node["state"]
        var current_g: int = int(current_node["g"])
        var current_depth: int = int(current_node["depth"])
        var current_key: String = DOMAIN.get_state_key(current_state)

        # Mengabaikan node jika sudah ditemukan jalur lain menuju state yang sama dengan biaya lebih rendah.
        if current_g > int(visited.get(current_key, current_g)):
            continue

        # Memeriksa apakah state saat ini sudah memenuhi kondisi goal.
        # Jika terpenuhi, pencarian dapat dihentikan.
        if DOMAIN.is_goal(current_state):
            goal_index = current_index
            break

        # Menghentikan pencarian jika batas ekspansi node tercapai.
        if expanded >= MAX_NODES:
            result["reason"] = "limit_exceeded"
            result["nodes_expanded"] = expanded
            return _finish_result(result, start_time)

        # Menghitung jumlah node yang benar-benar diekspansi.
        expanded += 1

        # Tidak melakukan ekspansi jika kedalaman maksimum sudah tercapai.
        if current_depth >= max_depth:
            continue

        # Menghasilkan seluruh aksi yang valid untuk state saat ini.
        for action in DOMAIN.get_available_actions(current_state):
            # Membuat state baru berdasarkan efek dari aksi yang dipilih.
            var next_state: Dictionary = DOMAIN.apply_action(current_state, action)

            # Mengabaikan aksi yang tidak menghasilkan state valid.
            if next_state.is_empty():
                continue

            # Menghitung biaya jalur baru dari S0 sampai state berikutnya.
            var next_g: int = current_g + int(action.get("cost", 0))
            var next_key: String = DOMAIN.get_state_key(next_state)

            # Jika state sudah pernah ditemukan dengan biaya lebih kecil atau sama, jalur baru ini tidak perlu dimasukkan ke frontier.
            if visited.has(next_key) and next_g >= int(visited[next_key]):
                continue

            # Memperbarui biaya terbaik yang ditemukan untuk state tersebut.
            visited[next_key] = next_g

            # Menyimpan node baru beserta hubungan parent dan aksi yang digunakan untuk mencapai state tersebut.
            nodes.append({
                "state": next_state,
                "g": next_g,
                "depth": current_depth + 1,
                "parent": current_index,
                "action": action.duplicate(true)
            })

            # Memasukkan indeks node baru ke frontier.
            frontier.append(nodes.size() - 1)

    # Menyimpan jumlah node yang telah diekspansi selama pencarian.
    result["nodes_expanded"] = expanded

    # Jika frontier habis dan goal tidak ditemukan,
    # berarti tidak ada rencana yang dapat memenuhi goal.
    if goal_index == -1:
        result["reason"] = "frontier_exhausted"
        return _finish_result(result, start_time)

    # Menyusun kembali urutan aksi dari node goal menuju node awal.
    var reconstructed := _reconstruct_plan(nodes, goal_index)

    # Menyimpan hasil pencarian yang berhasil menemukan goal.
    result["status"] = "plan_found"
    result["steps"] = reconstructed["steps"]
    result["total_cost"] = reconstructed["total_cost"]
    result["reason"] = "Goal berhasil ditemukan"

    # Menghitung waktu proses dan mengembalikan hasil planning.
    return _finish_result(result, start_time)


static func _get_best_frontier_position(frontier: Array, nodes: Array, planner_mode: String) -> int:
    # Menganggap elemen pertama frontier sebagai node terbaik sementara.
    var best_position := 0
    var best_index: int = frontier[0]

    # Memeriksa seluruh node lain untuk mencari prioritas terbaik.
    for i in range(1, frontier.size()):
        var node_index: int = frontier[i]

        # Memperbarui posisi jika ditemukan node yang lebih baik.
        if _is_better(nodes[node_index], node_index, nodes[best_index], best_index, planner_mode):
            best_position = i
            best_index = node_index

    return best_position


static func _is_better(node: Dictionary, node_index: int, best_node: Dictionary, best_index: int, planner_mode: String) -> bool:
    # Menghitung prioritas node berdasarkan algoritma yang digunakan.
    var priority: int = _calculate_priority(node, planner_mode)
    var best_priority: int = _calculate_priority(best_node, planner_mode)

    # Node dengan nilai prioritas lebih kecil dipilih terlebih dahulu.
    if priority != best_priority:
        return priority < best_priority

    # Jika prioritas sama, gunakan ID NPC sebagai tie-breaker.
    # NPC dengan ID numerik lebih kecil diprioritaskan.
    var npc_id: String = _get_node_npc_id(node)
    var best_npc_id: String = _get_node_npc_id(best_node)
    var numeric_id: int = DOMAIN._get_numeric_id(npc_id)
    var best_numeric_id: int = DOMAIN._get_numeric_id(best_npc_id)

    if numeric_id != best_numeric_id:
        return numeric_id < best_numeric_id

    # Jika ID NPC sama, gunakan urutan alfabetis tipe aksi agar pemilihan node tetap deterministik.
    var action_type: String = str(node.get("action", {}).get("type", ""))
    var best_action_type: String = str(best_node.get("action", {}).get("type", ""))

    if action_type != best_action_type:
        return action_type < best_action_type

    # Jika seluruh kriteria sama, gunakan indeks node agar urutan pemilihan tetap konsisten.
    return node_index < best_index


static func _get_node_npc_id(node: Dictionary) -> String:
    # Mengambil informasi aksi dari node yang sedang diperiksa.
    var action: Dictionary = node.get("action", {})

    # Node awal tidak memiliki aksi maupun NPC yang menjalankannya.
    if action.is_empty():
        return ""

    return str(action.get("npc", ""))


static func _calculate_priority(node: Dictionary, planner_mode: String) -> int:
    # g merupakan total biaya dari S0 sampai node saat ini.
    var g: int = int(node["g"])

    # UCS hanya mempertimbangkan biaya jalur yang sudah ditempuh.
    if planner_mode == MODE_UCS:
        return g

    # A* mempertimbangkan biaya jalur dan estimasi biaya menuju goal.
    # f(n) = g(n) + h(n).
    return g + DOMAIN.calculate_heuristic(node["state"])


static func _reconstruct_plan(nodes: Array, goal_index: int) -> Dictionary:
    # Menampung aksi dalam urutan terbalik, dimulai dari node goal.
    var reversed_steps: Array = []
    var current_index := goal_index

    # Menelusuri hubungan parent dari node goal sampai node awal.
    # Penelusuran berhenti ketika parent bernilai -1.
    while current_index != -1:
        var node: Dictionary = nodes[current_index]

        # Node awal tidak memiliki aksi, sehingga hanya node yang memiliki aksi yang dimasukkan ke dalam rencana.
        if not node["action"].is_empty():
            reversed_steps.append(node["action"].duplicate(true))

        current_index = int(node["parent"])

    # Membalik urutan agar aksi dimulai dari S0 menuju goal.
    reversed_steps.reverse()

    # Menyusun daftar langkah akhir dan menghitung total biaya.
    var steps: Array = []
    var total_cost := 0

    for i in range(reversed_steps.size()):
        var action: Dictionary = reversed_steps[i]
        var action_cost: int = int(action.get("cost", 0))

        # Menambahkan biaya setiap aksi ke total biaya rencana.
        total_cost += action_cost

        # Menyimpan informasi aksi dengan nomor urut, tipe aksi, NPC pelaksana, dan biaya aksi.
        steps.append({
            "i": i + 1,
            "action": str(action.get("type", "")),
            "npc": str(action.get("npc", "")),
            "cost": action_cost
        })

    return {
        "steps": steps,
        "total_cost": total_cost
    }


static func _finish_result(result: Dictionary, start_time: int) -> Dictionary:
    # Menghitung selisih waktu sejak planning dimulai.
    var elapsed: int = Time.get_ticks_usec() - start_time

    # Mengubah mikrodetik menjadi milidetik untuk laporan hasil.
    result["time_ms"] = float(elapsed) / 1000.0

    return result
