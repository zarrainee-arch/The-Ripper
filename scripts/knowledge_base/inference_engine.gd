extends RefCounted
class_name InferenceEngine

# Konstanta peran dari KnowledgeBase.
const LEADER = KnowledgeBase.LEADER
const FOLLOWER = KnowledgeBase.FOLLOWER

# Konstanta jenis aksi dari KnowledgeBase.
const COORDINATED_ATTACK = KnowledgeBase.COORDINATED_ATTACK
const NORMAL_ATTACK = KnowledgeBase.NORMAL_ATTACK
const NO_ACTION = KnowledgeBase.NO_ACTION

# Menyimpan objek KnowledgeBase.
var knowledge_base: KnowledgeBase

# Menerima KnowledgeBase saat objek dibuat.
func _init(kb: KnowledgeBase):
    knowledge_base = kb

# Menjalankan proses inferensi untuk satu giliran.
func infer(turn_id: int) -> Dictionary:
    var rules_checked: Array[String] = []
    var matched_rules: Array[String] = []
    var inferred_facts: Array[Dictionary] = []
    var decisions: Array[Dictionary] = []
    var reasons: Array[String] = []
    var trace: Array[Dictionary] = []
    var applied_keys: Dictionary = {}

    # Membersihkan fakta giliran lama dan fakta turunan.
    knowledge_base.clear_old_turn_facts(turn_id)
    knowledge_base.clear_derived_facts()

    # Menyimpan fakta masukan sebelum inferensi.
    var input_facts: Array[Dictionary] = knowledge_base.get_facts()
    knowledge_base.set_fact("current_turn", {"turn_id": turn_id})

    # Mengambil aturan dari KnowledgeBase.
    var rules: Array[Dictionary] = knowledge_base.get_rules()

    # Menjalankan stage 1 dan 2 sampai tidak ada fakta baru.
    for stage in [1, 2]:
        var stage_rules = _rules_for_stage(rules, stage)
        var changed = true

        while changed:
            changed = false

            for rule in stage_rules:
                _append_unique(rules_checked, str(rule["id"]))
                var all_facts: Array = knowledge_base.get_facts()

                # Mencari semua binding yang memenuhi kondisi aturan.
                for bindings in _match_conditions(rule["conditions"], all_facts, {}):
                    var new_fact: Dictionary = _instantiate(rule["assert"], bindings)
                    var fact_type: String = str(new_fact["type"])
                    new_fact.erase("type")

                    _append_unique(matched_rules, str(rule["id"]))
                    _append_unique(reasons, str(rule["reason"]))

                    # Menambahkan fakta hanya jika belum tersedia.
                    if not knowledge_base.has_fact(fact_type, new_fact):
                        knowledge_base.set_fact(fact_type, new_fact)
                        var logged = new_fact.duplicate()
                        logged["type"] = fact_type
                        logged["rule_id"] = rule["id"]
                        inferred_facts.append(logged)
                        applied_keys[_binding_key(str(rule["id"]), bindings)] = true
                        changed = true

        # Mengambil fakta akhir untuk mencatat hasil evaluasi stage.
        var stage_facts: Array = knowledge_base.get_facts()
        for rule in stage_rules:
            var matches: Array = _match_conditions(rule["conditions"], stage_facts, {})

            # Mencatat aturan yang tidak memenuhi kondisi.
            if matches.is_empty():
                trace.append(_unmatched_entry(rule, stage_facts))
                continue

            # Mencatat hasil pencocokan setiap binding.
            for bindings in matches:
                var produced: Dictionary = _instantiate(rule["assert"], bindings)
                trace.append({
                    "rule_id": rule["id"],
                    "stage": rule["stage"],
                    "matched": true,
                    "bindings": bindings.duplicate(),
                    "produced": produced,
                    "applied": applied_keys.has(_binding_key(str(rule["id"]), bindings)),
                    "suppressed_by": ""
                })

    # Mengurutkan aturan keputusan berdasarkan prioritas.
    var decision_rules = _rules_for_stage(rules, 3)
    decision_rules.sort_custom(func(a, b): return a["priority"] < b["priority"])
    var decided: Dictionary = {}
    var decision_facts: Array = knowledge_base.get_facts()

    # Mengevaluasi aturan keputusan untuk setiap NPC.
    for rule in decision_rules:
        _append_unique(rules_checked, str(rule["id"]))

        var matches: Array = _match_conditions(rule["conditions"], decision_facts, {})

        # Mencatat aturan yang tidak cocok.
        if matches.is_empty():
            trace.append(_unmatched_entry(rule, decision_facts))
            continue

        for bindings in matches:
            var spec: Dictionary = rule["decide"]
            var subject = str(_resolve(spec["subject"], bindings))
            var applied = not decided.has(subject)

            # Mencatat apakah keputusan diterapkan atau ditekan aturan lain.
            trace.append({
                "rule_id": rule["id"],
                "stage": rule["stage"],
                "matched": true,
                "bindings": bindings.duplicate(),
                "produced": spec["action"],
                "applied": applied,
                "suppressed_by": "" if applied else str(decided[subject])
            })

            # Melewati keputusan jika NPC sudah diputuskan.
            if not applied:
                continue

            decided[subject] = str(rule["id"])
            _append_unique(matched_rules, str(rule["id"]))
            _append_unique(reasons, str(rule["reason"]))

            # Mengumpulkan fakta konteks untuk menjelaskan keputusan.
            var context_facts: Array = []
            for fact_type in rule.get("explain_with", []):
                for fact in decision_facts:
                    if fact.get("type", "") == fact_type and fact.get("turn_id", turn_id) == turn_id:
                        context_facts.append(fact)

            # Menyimpan keputusan akhir NPC.
            decisions.append({
                "npc_id": subject,
                "action": spec["action"],
                "reason": rule["reason"],
                "turn_id": turn_id,
                "rule_id": rule["id"],
                "bonus_damage": spec.get("bonus_damage", 0),
                "context_facts": context_facts
            })

    # Mengurutkan keputusan berdasarkan ID NPC.
    decisions.sort_custom(func(a, b): return str(a["npc_id"]) < str(b["npc_id"]))

    # Memeriksa apakah aturan fallback R7 digunakan.
    var fallback_used = false
    for decision in decisions:
        if decision["rule_id"] == "R7":
            fallback_used = true

    # Mengembalikan hasil inferensi dan log evaluasi.
    return {
        "turn_id": turn_id,
        "facts": input_facts,
        "facts_after_inference": knowledge_base.get_facts(),
        "rules_checked": rules_checked,
        "matched_rules": matched_rules,
        "inferred_facts": inferred_facts,
        "decisions": decisions,
        "reasons": reasons,
        "trace": trace,
        "fallback_used": fallback_used,
        "execution_status": "PENDING"
    }

# Menetapkan peran NPC.
func set_role(npc_id: String, role: String) -> void:
    knowledge_base.set_fact("role", {"npc_id": npc_id, "role": role})

# Mencatat serangan NPC pada giliran tertentu.
func record_attack(npc_id: String, turn_id: int) -> void:
    knowledge_base.set_fact("attacked", {"npc_id": npc_id, "turn_id": turn_id})

# Menghapus catatan serangan NPC.
func clear_attack(npc_id: String, turn_id: int) -> void:
    knowledge_base.remove_fact("attacked", {"npc_id": npc_id, "turn_id": turn_id})

# Menghapus seluruh fakta ketika battle diulang.
func reset_battle() -> void:
    knowledge_base.clear_facts()

# Mencatat bahwa NPC telah menggunakan koordinasi.
func mark_coordination_used(npc_id: String, turn_id: int) -> void:
    knowledge_base.set_fact("coordination_used", {"npc_id": npc_id, "turn_id": turn_id})

# Memperbarui status hidup NPC.
func update_npc_alive(npc_id: String, is_alive: bool) -> void:
    knowledge_base.set_fact("alive", {"npc_id": npc_id, "value": is_alive})

# Membuat kunci unik berdasarkan aturan dan binding.
func _binding_key(rule_id: String, bindings: Dictionary) -> String:
    var names: Array = bindings.keys()
    names.sort()

    var parts := PackedStringArray()
    for variable in names:
        parts.append("%s=%s" % [str(variable), str(bindings[variable])])

    return "%s|%s" % [rule_id, ";".join(parts)]

# Membuat catatan untuk aturan yang tidak cocok.
func _unmatched_entry(rule: Dictionary, facts: Array) -> Dictionary:
    return {
        "rule_id": rule["id"],
        "stage": rule["stage"],
        "matched": false,
        "bindings": {},
        "produced": "",
        "applied": false,
        "suppressed_by": "",
        "failed_condition": _first_failed_condition(rule["conditions"], facts)
    }

# Mencari kondisi pertama yang gagal dipenuhi.
func _first_failed_condition(conditions: Array, facts: Array) -> String:
    for i in range(conditions.size()):
        if _match_conditions(conditions.slice(0, i + 1), facts, {}).is_empty():
            return _describe_condition(conditions[i])
    return ""

# Mengubah kondisi menjadi teks yang mudah dibaca.
func _describe_condition(condition: Dictionary) -> String:
    var parts := PackedStringArray()
    for key in condition:
        if key == "type" or key == "not":
            continue
        parts.append("%s=%s" % [key, str(condition[key])])

    var text = "%s(%s)" % [condition.get("type", "?"), ", ".join(parts)]
    if condition.get("not", false):
        text = "NOT " + text
    return text

# Mengambil aturan berdasarkan nomor stage.
func _rules_for_stage(rules: Array, stage: int) -> Array:
    var result: Array = []
    for rule in rules:
        if int(rule.get("stage", 0)) == stage:
            result.append(rule)
    return result

# Mencari semua binding yang memenuhi kondisi aturan.
func _match_conditions(conditions: Array, facts: Array, bindings: Dictionary) -> Array:
    if conditions.is_empty():
        return [bindings]

    var condition: Dictionary = conditions[0]
    var rest: Array = conditions.slice(1)
    var results: Array = []

    # Negasi terpenuhi jika tidak ditemukan fakta yang cocok.
    if condition.get("not", false):
        for fact in facts:
            if _unify(condition, fact, bindings) != null:
                return results
        results.append_array(_match_conditions(rest, facts, bindings))
        return results

    # Mencocokkan kondisi positif dengan setiap fakta.
    for fact in facts:
        var new_bindings = _unify(condition, fact, bindings)
        if new_bindings == null:
            continue
        results.append_array(_match_conditions(rest, facts, new_bindings))

    return results

# Mencocokkan pola kondisi dengan satu fakta.
func _unify(pattern: Dictionary, fact: Dictionary, bindings: Dictionary) -> Variant:
    if fact.get("type", "") != pattern.get("type", ""):
        return null

    var result: Dictionary = bindings.duplicate()

    # Memeriksa setiap atribut pada pola.
    for key in pattern:
        if key == "type" or key == "not":
            continue

        if not fact.has(key):
            return null

        var expected = pattern[key]

        # Mengikat variabel atau memeriksa nilai yang sudah terikat.
        if _is_variable(expected):
            if result.has(expected):
                if result[expected] != fact[key]:
                    return null
            else:
                result[expected] = fact[key]
        elif expected != fact[key]:
            return null

    return result

# Memeriksa apakah nilai merupakan variabel.
func _is_variable(value) -> bool:
    return typeof(value) == TYPE_STRING and str(value).begins_with("?")

# Mengambil nilai variabel dari binding.
func _resolve(value, bindings: Dictionary):
    if _is_variable(value):
        return bindings.get(value)
    return value

# Mengisi template dengan nilai binding.
func _instantiate(template: Dictionary, bindings: Dictionary) -> Dictionary:
    var result: Dictionary = {}
    for key in template:
        result[key] = _resolve(template[key], bindings)
    return result

# Menambahkan nilai hanya jika belum ada.
func _append_unique(values: Array, value: String) -> void:
    if not values.has(value):
        values.append(value)