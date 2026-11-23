class_name TransitionModel
extends RefCounted

const ERROR_INVALID_MAPPING := "INVALID_MAPPING"
const ERROR_INVALID_TRANSITION := "INVALID_TRANSITION"
const ERROR_EMPTY_ACTIONS := "EMPTY_ACTIONS"
const ERROR_INVALID_PROBABILITY := "INVALID_PROBABILITY"
const ERROR_INVALID_PROBABILITY_SUM := "INVALID_PROBABILITY_SUM"
const ERROR_INVALID_TOLERANCE := "INVALID_TOLERANCE"
const ERROR_INVALID_PARAMS := "INVALID_PARAMS"
const ERROR_INVALID_STATE := "INVALID_STATE"
const ERROR_INVALID_ACTION := "INVALID_ACTION"
const ERROR_INVALID_BELIEF_RECORD := "INVALID_BELIEF_RECORD"
const ERROR_UNKNOWN_HYPOTHESIS := "UNKNOWN_HYPOTHESIS"

const PARAM_KEYS := [
	"initial_states",
	"state_ids",
	"actions_by_state",
	"terminal_states",
	"transition_spec"
]

# RESULT HELPERS
static func _success(data: Dictionary) -> Dictionary:
	return {
		"valid": true,
		"errors": [],
		"data": data.duplicate(true)
	}


static func _failure(error_code: String) -> Dictionary:
	return {
		"valid": false,
		"errors": [error_code],
		"data": {}
	}


static func _is_numeric(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT


static func _is_finite_number(value: Variant) -> bool:
	return _is_numeric(value) and is_finite(float(value))


static func _valid_tolerance(value: Variant) -> bool:
	return _is_finite_number(value) and float(value) >= 0.0


static func _valid_id(value: Variant) -> bool:
	return typeof(value) == TYPE_STRING and not str(value).is_empty()

# PARAMS VALIDATION
static func validate_params(params: Variant) -> Dictionary:
	if typeof(params) != TYPE_DICTIONARY:
		return _failure(ERROR_INVALID_PARAMS)

	var source: Dictionary = params

	if source.size() != PARAM_KEYS.size():
		return _failure(ERROR_INVALID_PARAMS)

	for key in PARAM_KEYS:
		if not source.has(key):
			return _failure(ERROR_INVALID_PARAMS)

	if typeof(source["initial_states"]) != TYPE_ARRAY:
		return _failure(ERROR_INVALID_PARAMS)

	if typeof(source["state_ids"]) != TYPE_ARRAY:
		return _failure(ERROR_INVALID_PARAMS)

	if typeof(source["actions_by_state"]) != TYPE_DICTIONARY:
		return _failure(ERROR_INVALID_PARAMS)

	if typeof(source["terminal_states"]) != TYPE_ARRAY:
		return _failure(ERROR_INVALID_PARAMS)

	if typeof(source["transition_spec"]) != TYPE_DICTIONARY:
		return _failure(ERROR_INVALID_PARAMS)

	var state_ids: Array = source["state_ids"]
	var initial_states: Array = source["initial_states"]
	var terminal_states: Array = source["terminal_states"]
	var actions_by_state: Dictionary = source["actions_by_state"]
	var transition_spec: Dictionary = source["transition_spec"]

	if state_ids.is_empty() or initial_states.is_empty():
		return _failure(ERROR_INVALID_PARAMS)

	var state_set := {}

	for state in state_ids:
		if not _valid_id(state) or state_set.has(state):
			return _failure(ERROR_INVALID_PARAMS)
		state_set[state] = true

	for state in initial_states:
		if not state_set.has(state):
			return _failure(ERROR_INVALID_STATE)

	var terminal_set := {}

	for state in terminal_states:
		if not state_set.has(state) or terminal_set.has(state):
			return _failure(ERROR_INVALID_STATE)
		terminal_set[state] = true

	if actions_by_state.size() != state_ids.size():
		return _failure(ERROR_INVALID_PARAMS)

	for state in state_ids:
		if not actions_by_state.has(state):
			return _failure(ERROR_INVALID_PARAMS)

		var actions = actions_by_state[state]

		if typeof(actions) != TYPE_ARRAY:
			return _failure(ERROR_INVALID_ACTION)

		var seen_actions := {}

		for action in actions:
			if not _valid_id(action) or seen_actions.has(action):
				return _failure(ERROR_INVALID_ACTION)
			seen_actions[action] = true

		if terminal_set.has(state) and not actions.is_empty():
			return _failure(ERROR_INVALID_ACTION)

	return _success({
		"params": source.duplicate(true)
	})

# TRANSITION VALIDATION
static func validate_transitions(
	state: String,
	action: String,
	params: Dictionary,
	probability_tolerance: float
) -> Dictionary:
	if not _valid_tolerance(probability_tolerance):
		return _failure(ERROR_INVALID_TOLERANCE)

	var params_result := validate_params(params)

	if not params_result["valid"]:
		return params_result

	var clean_params: Dictionary = params_result["data"]["params"]

	var state_ids: Array = clean_params["state_ids"]
	var terminal_states: Array = clean_params["terminal_states"]
	var actions_by_state: Dictionary = clean_params["actions_by_state"]
	var transition_spec: Dictionary = clean_params["transition_spec"]

	if not state_ids.has(state):
		return _failure(ERROR_INVALID_STATE)

	if terminal_states.has(state):
		return _failure(ERROR_EMPTY_ACTIONS)

	var available_actions: Array = actions_by_state[state]

	if not available_actions.has(action):
		return _failure(ERROR_INVALID_ACTION)

	if not transition_spec.has(state):
		return _failure(ERROR_INVALID_TRANSITION)

	var state_spec = transition_spec[state]

	if typeof(state_spec) != TYPE_DICTIONARY:
		return _failure(ERROR_INVALID_TRANSITION)

	if not state_spec.has(action):
		return _failure(ERROR_INVALID_TRANSITION)

	var branches = state_spec[action]

	if typeof(branches) != TYPE_ARRAY or branches.is_empty():
		return _failure(ERROR_EMPTY_ACTIONS)

	var seen_branch_ids := {}
	var probability_sum := 0.0
	var validated_branches: Array[Dictionary] = []

	for branch in branches:
		if typeof(branch) != TYPE_DICTIONARY:
			return _failure(ERROR_INVALID_TRANSITION)

		if (
			not branch.has("branch_id")
			or not branch.has("next_state")
			or not branch.has("probability")
		):
			return _failure(ERROR_INVALID_TRANSITION)

		var branch_id = branch["branch_id"]
		var next_state = branch["next_state"]
		var probability = branch["probability"]

		if not _valid_id(branch_id) or seen_branch_ids.has(branch_id):
			return _failure(ERROR_INVALID_TRANSITION)

		seen_branch_ids[branch_id] = true

		if not state_ids.has(next_state):
			return _failure(ERROR_INVALID_STATE)

		if not _is_finite_number(probability):
			return _failure(ERROR_INVALID_PROBABILITY)

		var p := float(probability)

		if p < 0.0 or p > 1.0:
			return _failure(ERROR_INVALID_PROBABILITY)

		probability_sum += p

		validated_branches.append({
			"branch_id": str(branch_id),
			"next_state": str(next_state),
			"probability": p
		})

	if validated_branches.size() == 1:
		if absf(probability_sum - 1.0) > probability_tolerance:
			return _failure(ERROR_INVALID_PROBABILITY_SUM)

	if absf(probability_sum - 1.0) > probability_tolerance:
		return _failure(ERROR_INVALID_PROBABILITY_SUM)

	return _success({
		"state": state,
		"action": action,
		"branches": validated_branches,
		"sum": probability_sum
	})

# TRANSITION LOOKUP
static func get_transitions(
	state: String,
	action: String,
	params: Dictionary,
	probability_tolerance: float = 0.000001
) -> Dictionary:
	var validation := validate_transitions(
		state,
		action,
		params,
		probability_tolerance
	)

	if not validation["valid"]:
		return validation

	var data: Dictionary = validation["data"]

	return _success({
		"transitions": data["branches"],
		"sum": data["sum"]
	})

# BUILD TRANSITION PARAMS FROM BELIEF
#
# ParameterMapping format used by this implementation:
#
# {
#   "state": {
#     "action": {
#       "branch_id": {
#         "HYPOTHESIS_ID": conditional_probability
#       }
#     }
#   }
# }
#
# p(branch) = SUM_h belief[h] * P(branch | h)
static func build_transition_params(
	base_params: Dictionary,
	belief: Dictionary,
	parameter_mapping: Dictionary,
	probability_tolerance: float
) -> Dictionary:
	if not _valid_tolerance(probability_tolerance):
		return _failure(ERROR_INVALID_TOLERANCE)

	var params_result := validate_params(base_params)

	if not params_result["valid"]:
		return _failure(ERROR_INVALID_MAPPING)

	var distribution_result := _validate_belief(belief)

	if not distribution_result["valid"]:
		return distribution_result

	if typeof(parameter_mapping) != TYPE_DICTIONARY:
		return _failure(ERROR_INVALID_MAPPING)

	var params: Dictionary = params_result["data"]["params"]
	var distribution: Dictionary = distribution_result["data"]["distribution"]
	var mapping: Dictionary = parameter_mapping

	var transition_spec: Dictionary = params["transition_spec"]
	var state_ids: Array = params["state_ids"]
	var actions_by_state: Dictionary = params["actions_by_state"]

	var updated_spec: Dictionary = transition_spec.duplicate(true)

	for state in mapping:
		if not state_ids.has(state):
			return _failure(ERROR_INVALID_MAPPING)

		if typeof(mapping[state]) != TYPE_DICTIONARY:
			return _failure(ERROR_INVALID_MAPPING)

		var action_mapping: Dictionary = mapping[state]

		for action in action_mapping:
			if not actions_by_state[state].has(action):
				return _failure(ERROR_INVALID_MAPPING)

			if typeof(action_mapping[action]) != TYPE_DICTIONARY:
				return _failure(ERROR_INVALID_MAPPING)

			var branch_mapping: Dictionary = action_mapping[action]

			if (
				not updated_spec.has(state)
				or typeof(updated_spec[state]) != TYPE_DICTIONARY
				or not updated_spec[state].has(action)
			):
				return _failure(ERROR_INVALID_MAPPING)

			var branches: Array = updated_spec[state][action]
			var branch_indices := {}

			for index in range(branches.size()):
				var branch_id = branches[index].get("branch_id", "")
				branch_indices[branch_id] = index

			for branch_id in branch_mapping:
				if not branch_indices.has(branch_id):
					return _failure(ERROR_INVALID_MAPPING)

				var conditional = branch_mapping[branch_id]

				if typeof(conditional) != TYPE_DICTIONARY:
					return _failure(ERROR_INVALID_MAPPING)

				if conditional.size() != distribution.size():
					return _failure(ERROR_INVALID_MAPPING)

				var probability := 0.0

				for hypothesis in distribution:
					if not conditional.has(hypothesis):
						return _failure(ERROR_INVALID_MAPPING)

					var conditional_probability = conditional[hypothesis]

					if not _is_finite_number(conditional_probability):
						return _failure(ERROR_INVALID_PROBABILITY)

					var conditional_value := float(conditional_probability)

					if conditional_value < 0.0 or conditional_value > 1.0:
						return _failure(ERROR_INVALID_PROBABILITY)

					probability += (
						float(distribution[hypothesis])
						* conditional_value
					)

				var branch_index: int = branch_indices[branch_id]
				branches[branch_index]["probability"] = probability

			updated_spec[state][action] = branches

	var updated_params := params.duplicate(true)
	updated_params["transition_spec"] = updated_spec

	# Validate every mapped transition pair before returning.
	for state in updated_spec:
		for action in updated_spec[state]:
			var validation := validate_transitions(
				str(state),
				str(action),
				updated_params,
				probability_tolerance
			)

			if not validation["valid"]:
				return _failure(ERROR_INVALID_MAPPING)

	return _success({
		"params": updated_params
	})

# BELIEF VALIDATION
static func _validate_belief(belief: Variant) -> Dictionary:
	if typeof(belief) != TYPE_DICTIONARY:
		return _failure(ERROR_INVALID_BELIEF_RECORD)

	var record: Dictionary = belief

	if (
		not record.has("distribution")
		or not record.has("source")
		or not record.has("source_turn")
	):
		return _failure(ERROR_INVALID_BELIEF_RECORD)

	if typeof(record["distribution"]) != TYPE_DICTIONARY:
		return _failure(ERROR_INVALID_BELIEF_RECORD)

	if typeof(record["source"]) != TYPE_STRING:
		return _failure(ERROR_INVALID_BELIEF_RECORD)

	if typeof(record["source_turn"]) != TYPE_INT:
		return _failure(ERROR_INVALID_BELIEF_RECORD)

	if int(record["source_turn"]) < 0:
		return _failure(ERROR_INVALID_BELIEF_RECORD)

	var source := str(record["source"])

	if (
		source != UncertaintyBelief.SOURCE_INITIAL_PRIOR
		and source != UncertaintyBelief.SOURCE_BAYES_UPDATE
	):
		return _failure(ERROR_INVALID_BELIEF_RECORD)

	var distribution: Dictionary = record["distribution"]

	var validation := UncertaintyBelief.validate_distribution(
		distribution,
		0.000001
	)

	if not validation["valid"]:
		return _failure(ERROR_INVALID_BELIEF_RECORD)

	return _success({
		"distribution": distribution.duplicate(true)
	})

# BUILD BOUND TRANSITION PROVIDER
static func build_transition_provider(params: Dictionary) -> Dictionary:
	var validation := validate_params(params)

	if not validation["valid"]:
		return validation

	var bound_params: Dictionary = validation["data"]["params"]

	var provider := Callable(
		TransitionModel,
		"_provider_get_transitions"
	).bind(bound_params)

	return _success({
		"provider": {
			"get_transitions": provider,
			"actions_by_state": bound_params["actions_by_state"].duplicate(true),
			"terminal_states": bound_params["terminal_states"].duplicate(true),
			"state_ids": bound_params["state_ids"].duplicate(true),
			"initial_states": bound_params["initial_states"].duplicate(true)
		}
	})


static func _provider_get_transitions(
	state: Variant,
	action: Variant,
	params: Dictionary
) -> Dictionary:
	if not _valid_id(state):
		return _failure(ERROR_INVALID_STATE)

	if not _valid_id(action):
		return _failure(ERROR_INVALID_ACTION)

	return get_transitions(
		str(state),
		str(action),
		params
	)
