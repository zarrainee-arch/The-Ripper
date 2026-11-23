class_name BayesianUpdater
extends RefCounted

const UB = preload("res://scripts/bayes_belief/uncertainty_belief1.gd")

const ERROR_EMPTY_DISTRIBUTION := "EMPTY_DISTRIBUTION"
const ERROR_EMPTY_ACTIONS := "EMPTY_ACTIONS"
const ERROR_EMPTY_OUTCOMES := "EMPTY_OUTCOMES"
const ERROR_INVALID_PROBABILITY := "INVALID_PROBABILITY"
const ERROR_INVALID_PROBABILITY_SUM := "INVALID_PROBABILITY_SUM"
const ERROR_INVALID_TOLERANCE := "INVALID_TOLERANCE"
const ERROR_INVALID_LIKELIHOOD := "INVALID_LIKELIHOOD"
const ERROR_UNKNOWN_EVIDENCE := "UNKNOWN_EVIDENCE"
const ERROR_ZERO_EVIDENCE_PROBABILITY := "ZERO_EVIDENCE_PROBABILITY"
const ERROR_INVALID_BELIEF_RECORD := "INVALID_BELIEF_RECORD"
const ERROR_INVALID_SOURCE_TURN := "INVALID_SOURCE_TURN"
const ERROR_INVALID_UTILITY := "INVALID_UTILITY"
const ERROR_INVALID_MAPPING := "INVALID_MAPPING"


# --------------------------------------------------
# RESULT HELPERS
# --------------------------------------------------

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

	var source := str(record["source"])
	if (
		source != UB.SOURCE_INITIAL_PRIOR
		and source != UB.SOURCE_BAYES_UPDATE
	):
		return _failure(ERROR_INVALID_BELIEF_RECORD)

	if typeof(record["source_turn"]) != TYPE_INT:
		return _failure(ERROR_INVALID_BELIEF_RECORD)

	if int(record["source_turn"]) < 0:
		return _failure(ERROR_INVALID_BELIEF_RECORD)

	var distribution: Dictionary = record["distribution"]
	var validation: Dictionary = UB.validate_distribution(
		distribution,
		0.000001
	)

	if not validation["valid"]:
		return _failure(ERROR_INVALID_BELIEF_RECORD)

	return _success({
		"belief": record.duplicate(true)
	})


# --------------------------------------------------
# LIKELIHOOD VALIDATION
# likelihood[hypothesis][evidence] = P(evidence | hypothesis)
# --------------------------------------------------

static func validate_likelihood(
	likelihood: Variant,
	hypotheses: Variant,
	evidence_ids: Variant,
	probability_tolerance: Variant
) -> Dictionary:
	if not _valid_tolerance(probability_tolerance):
		return _failure(ERROR_INVALID_TOLERANCE)

	if typeof(likelihood) != TYPE_DICTIONARY:
		return _failure(ERROR_INVALID_LIKELIHOOD)

	if typeof(hypotheses) != TYPE_ARRAY or typeof(evidence_ids) != TYPE_ARRAY:
		return _failure(ERROR_INVALID_LIKELIHOOD)

	var matrix: Dictionary = likelihood
	var hypothesis_list: Array = hypotheses
	var evidence_list: Array = evidence_ids

	if hypothesis_list.is_empty() or evidence_list.is_empty():
		return _failure(ERROR_INVALID_LIKELIHOOD)

	if matrix.size() != hypothesis_list.size():
		return _failure(ERROR_INVALID_LIKELIHOOD)

	var seen_hypotheses := {}
	var seen_evidence := {}

	for hypothesis in hypothesis_list:
		if not _valid_id(hypothesis) or seen_hypotheses.has(hypothesis):
			return _failure(ERROR_INVALID_LIKELIHOOD)
		seen_hypotheses[hypothesis] = true

	for evidence in evidence_list:
		if not _valid_id(evidence) or seen_evidence.has(evidence):
			return _failure(ERROR_INVALID_LIKELIHOOD)
		seen_evidence[evidence] = true

	for hypothesis in hypothesis_list:
		if not matrix.has(hypothesis):
			return _failure(ERROR_INVALID_LIKELIHOOD)

		var row = matrix[hypothesis]
		if typeof(row) != TYPE_DICTIONARY:
			return _failure(ERROR_INVALID_LIKELIHOOD)

		if row.size() != evidence_list.size():
			return _failure(ERROR_INVALID_LIKELIHOOD)

		var row_sum := 0.0

		for evidence in evidence_list:
			if not row.has(evidence):
				return _failure(ERROR_INVALID_LIKELIHOOD)

			var probability = row[evidence]

			if not _is_finite_number(probability):
				return _failure(ERROR_INVALID_LIKELIHOOD)

			var p := float(probability)

			if p < 0.0 or p > 1.0:
				return _failure(ERROR_INVALID_LIKELIHOOD)

			row_sum += p

		if absf(row_sum - 1.0) > float(probability_tolerance):
			return _failure(ERROR_INVALID_LIKELIHOOD)

	return _success({
		"hypotheses": hypothesis_list.duplicate(true),
		"evidence_ids": evidence_list.duplicate(true)
	})


# --------------------------------------------------
# MARGINAL PROBABILITY
# P(E) = SUM_h P(h) * P(E | h)
# --------------------------------------------------

static func compute_marginal(
	prior: Variant,
	likelihood: Variant,
	evidence: Variant
) -> Dictionary:
	var belief_result := _validate_belief(prior)
	if not belief_result["valid"]:
		return belief_result

	if not _valid_id(evidence):
		return _failure(ERROR_UNKNOWN_EVIDENCE)

	if typeof(likelihood) != TYPE_DICTIONARY:
		return _failure(ERROR_INVALID_LIKELIHOOD)

	var record: Dictionary = belief_result["data"]["belief"]
	var distribution: Dictionary = record["distribution"]
	var matrix: Dictionary = likelihood

	var marginal := 0.0
	var terms: Array[Dictionary] = []

	for hypothesis in distribution:
		if not matrix.has(hypothesis):
			return _failure(ERROR_INVALID_LIKELIHOOD)

		var row = matrix[hypothesis]
		if typeof(row) != TYPE_DICTIONARY or not row.has(evidence):
			return _failure(ERROR_UNKNOWN_EVIDENCE)

		var likelihood_value = row[evidence]

		if not _is_finite_number(likelihood_value):
			return _failure(ERROR_INVALID_LIKELIHOOD)

		var likelihood_probability := float(likelihood_value)

		if likelihood_probability < 0.0 or likelihood_probability > 1.0:
			return _failure(ERROR_INVALID_LIKELIHOOD)

		var prior_probability := float(distribution[hypothesis])
		var contribution := prior_probability * likelihood_probability

		marginal += contribution

		terms.append({
			"hypothesis": str(hypothesis),
			"prior": prior_probability,
			"likelihood": likelihood_probability,
			"contribution": contribution
		})

	if marginal <= 0.0:
		return _failure(ERROR_ZERO_EVIDENCE_PROBABILITY)

	return _success({
		"marginal": marginal,
		"evidence": str(evidence),
		"terms": terms
	})


# --------------------------------------------------
# BAYESIAN UPDATE
# P(H | E) = P(E | H) * P(H) / P(E)
# --------------------------------------------------

static func update_belief(
	prior: Variant,
	likelihood: Variant,
	evidence: Variant,
	source_turn: Variant,
	probability_tolerance: Variant
) -> Dictionary:
	if not _valid_tolerance(probability_tolerance):
		return _failure(ERROR_INVALID_TOLERANCE)

	if typeof(source_turn) != TYPE_INT or int(source_turn) < 0:
		return _failure(ERROR_INVALID_SOURCE_TURN)

	var belief_result := _validate_belief(prior)
	if not belief_result["valid"]:
		return belief_result

	var prior_record: Dictionary = belief_result["data"]["belief"]
	var prior_distribution: Dictionary = prior_record["distribution"]

	var hypotheses: Array = []
	for hypothesis in prior_distribution:
		hypotheses.append(str(hypothesis))

	var evidence_ids: Array = []
	if typeof(likelihood) == TYPE_DICTIONARY:
		var first_row = likelihood.get(hypotheses[0], {})
		if typeof(first_row) == TYPE_DICTIONARY:
			for evidence_id in first_row:
				evidence_ids.append(str(evidence_id))

	var likelihood_validation := validate_likelihood(
		likelihood,
		hypotheses,
		evidence_ids,
		probability_tolerance
	)

	if not likelihood_validation["valid"]:
		return likelihood_validation

	if not _valid_id(evidence) or not evidence_ids.has(evidence):
		return _failure(ERROR_UNKNOWN_EVIDENCE)

	var marginal_result := compute_marginal(
		prior_record,
		likelihood,
		evidence
	)

	if not marginal_result["valid"]:
		return marginal_result

	var marginal_data: Dictionary = marginal_result["data"]
	var marginal := float(marginal_data["marginal"])
	var posterior_distribution := {}

	for hypothesis in prior_distribution:
		var prior_probability := float(prior_distribution[hypothesis])
		var likelihood_probability := float(likelihood[hypothesis][evidence])

		posterior_distribution[str(hypothesis)] = (
			prior_probability * likelihood_probability / marginal
		)

	var posterior_result := UncertaintyBelief.create_belief(
		posterior_distribution,
		probability_tolerance,
		UncertaintyBelief.SOURCE_BAYES_UPDATE,
		int(source_turn)
	)

	if not posterior_result["valid"]:
		return posterior_result

	var posterior: Dictionary = posterior_result["data"]["belief"]

	return _success({
		"posterior": posterior,
		"prior": prior_record.duplicate(true),
		"evidence": str(evidence),
		"marginal": marginal,
		"terms": marginal_data["terms"]
	})


# --------------------------------------------------
# OUTCOME LIST BUILDER
# Outcome probability = SUM_h belief[h] * likelihood[action][outcome][h]
# Utility is looked up using the outcome ID.
# --------------------------------------------------

static func build_outcome_list(
	belief: Variant,
	outcome_likelihood: Variant,
	utilities: Variant,
	outcomes_by_action: Variant,
	probability_tolerance: Variant
) -> Dictionary:
	if not _valid_tolerance(probability_tolerance):
		return _failure(ERROR_INVALID_TOLERANCE)

	var belief_result := _validate_belief(belief)
	if not belief_result["valid"]:
		return belief_result

	if typeof(outcome_likelihood) != TYPE_DICTIONARY:
		return _failure(ERROR_INVALID_MAPPING)

	if typeof(utilities) != TYPE_DICTIONARY:
		return _failure(ERROR_INVALID_UTILITY)

	if typeof(outcomes_by_action) != TYPE_DICTIONARY:
		return _failure(ERROR_INVALID_MAPPING)

	var actions: Dictionary = outcomes_by_action
	var likelihoods: Dictionary = outcome_likelihood
	var utility_map: Dictionary = utilities
	var distribution: Dictionary = belief_result["data"]["belief"]["distribution"]

	if actions.is_empty():
		return _failure(ERROR_EMPTY_ACTIONS)

	var built_actions := {}

	for action in actions:
		if not _valid_id(action):
			return _failure(ERROR_INVALID_MAPPING)

		var outcome_ids = actions[action]

		if typeof(outcome_ids) != TYPE_ARRAY:
			return _failure(ERROR_INVALID_MAPPING)

		if outcome_ids.is_empty():
			return _failure(ERROR_EMPTY_OUTCOMES)

		if not likelihoods.has(action):
			return _failure(ERROR_INVALID_MAPPING)

		var action_likelihood = likelihoods[action]

		if typeof(action_likelihood) != TYPE_DICTIONARY:
			return _failure(ERROR_INVALID_MAPPING)

		var seen_outcomes := {}
		var outcome_list: Array[Dictionary] = []
		var probability_sum := 0.0

		for outcome_id in outcome_ids:
			if not _valid_id(outcome_id) or seen_outcomes.has(outcome_id):
				return _failure(ERROR_INVALID_MAPPING)

			seen_outcomes[outcome_id] = true

			if not utility_map.has(outcome_id):
				return _failure(ERROR_INVALID_UTILITY)

			var utility_value = utility_map[outcome_id]

			if not _is_finite_number(utility_value):
				return _failure(ERROR_INVALID_UTILITY)

			if not action_likelihood.has(outcome_id):
				return _failure(ERROR_INVALID_MAPPING)

			var conditional = action_likelihood[outcome_id]

			if typeof(conditional) != TYPE_DICTIONARY:
				return _failure(ERROR_INVALID_MAPPING)

			var outcome_probability := 0.0

			for hypothesis in distribution:
				if not conditional.has(hypothesis):
					return _failure(ERROR_INVALID_MAPPING)

				var conditional_probability = conditional[hypothesis]

				if not _is_finite_number(conditional_probability):
					return _failure(ERROR_INVALID_PROBABILITY)

				var p := float(conditional_probability)

				if p < 0.0 or p > 1.0:
					return _failure(ERROR_INVALID_PROBABILITY)

				outcome_probability += (
					float(distribution[hypothesis]) * p
				)

			probability_sum += outcome_probability

			outcome_list.append({
				"id": str(outcome_id),
				"probability": outcome_probability,
				"utility": float(utility_value)
			})

		if absf(probability_sum - 1.0) > float(probability_tolerance):
			return _failure(ERROR_INVALID_PROBABILITY_SUM)

		built_actions[str(action)] = outcome_list

	return _success({
		"actions": built_actions
	})
