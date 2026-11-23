class_name UncertaintyBelief
extends RefCounted

const SOURCE_INITIAL_PRIOR := "INITIAL_PRIOR"
const SOURCE_BAYES_UPDATE := "BAYES_UPDATE"

const ERROR_EMPTY_DISTRIBUTION := "EMPTY_DISTRIBUTION"
const ERROR_INVALID_PROBABILITY := "INVALID_PROBABILITY"
const ERROR_INVALID_PROBABILITY_SUM := "INVALID_PROBABILITY_SUM"
const ERROR_INVALID_TOLERANCE := "INVALID_TOLERANCE"
const ERROR_INVALID_BELIEF_SOURCE := "INVALID_BELIEF_SOURCE"
const ERROR_INVALID_SOURCE_TURN := "INVALID_SOURCE_TURN"
const ERROR_UNKNOWN_HYPOTHESIS := "UNKNOWN_HYPOTHESIS"
const ERROR_INVALID_BELIEF_RECORD := "INVALID_BELIEF_RECORD"


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
	if not _is_numeric(value):
		return false

	return is_finite(float(value))


static func _validate_tolerance(tolerance: Variant) -> bool:
	return (
		_is_finite_number(tolerance)
		and float(tolerance) >= 0.0
	)


static func _is_valid_id(value: Variant) -> bool:
	return typeof(value) == TYPE_STRING and not str(value).is_empty()


# --------------------------------------------------
# VALIDATE DISTRIBUTION
# --------------------------------------------------

static func validate_distribution(
	dist: Variant,
	probability_tolerance: Variant
) -> Dictionary:
	if not _validate_tolerance(probability_tolerance):
		return _failure(ERROR_INVALID_TOLERANCE)

	if typeof(dist) != TYPE_DICTIONARY:
		return _failure(ERROR_EMPTY_DISTRIBUTION)

	var distribution: Dictionary = dist

	if distribution.is_empty():
		return _failure(ERROR_EMPTY_DISTRIBUTION)

	var total := 0.0

	for hypothesis in distribution:
		if not _is_valid_id(hypothesis):
			return _failure(ERROR_INVALID_PROBABILITY)

		var probability = distribution[hypothesis]

		if not _is_finite_number(probability):
			return _failure(ERROR_INVALID_PROBABILITY)

		var p := float(probability)

		if p < 0.0 or p > 1.0:
			return _failure(ERROR_INVALID_PROBABILITY)

		total += p

	if absf(total - 1.0) > float(probability_tolerance):
		return _failure(ERROR_INVALID_PROBABILITY_SUM)

	return _success({
		"sum": total
	})


# --------------------------------------------------
# CREATE BELIEF
# --------------------------------------------------

static func create_belief(
	prior: Variant,
	probability_tolerance: Variant,
	source: Variant,
	source_turn: Variant
) -> Dictionary:
	if typeof(source) != TYPE_STRING:
		return _failure(ERROR_INVALID_BELIEF_SOURCE)

	if (
		str(source) != SOURCE_INITIAL_PRIOR
		and str(source) != SOURCE_BAYES_UPDATE
	):
		return _failure(ERROR_INVALID_BELIEF_SOURCE)

	if typeof(source_turn) != TYPE_INT or int(source_turn) < 0:
		return _failure(ERROR_INVALID_SOURCE_TURN)

	var validation := validate_distribution(
		prior,
		probability_tolerance
	)

	if not validation["valid"]:
		return validation

	var copied_distribution: Dictionary = prior.duplicate(true)

	var belief := {
		"distribution": copied_distribution,
		"source": str(source),
		"source_turn": int(source_turn)
	}

	return _success({
		"belief": belief
	})


# --------------------------------------------------
# GET PROBABILITY
# --------------------------------------------------

static func get_probability(
	belief: Variant,
	hypothesis: Variant
) -> Dictionary:
	if typeof(belief) != TYPE_DICTIONARY:
		return _failure(ERROR_INVALID_BELIEF_RECORD)

	var record: Dictionary = belief

	if not record.has("distribution"):
		return _failure(ERROR_INVALID_BELIEF_RECORD)

	if not record.has("source") or not record.has("source_turn"):
		return _failure(ERROR_INVALID_BELIEF_RECORD)

	if typeof(record["distribution"]) != TYPE_DICTIONARY:
		return _failure(ERROR_INVALID_BELIEF_RECORD)

	if typeof(record["source"]) != TYPE_STRING:
		return _failure(ERROR_INVALID_BELIEF_RECORD)

	var source := str(record["source"])

	if (
		source != SOURCE_INITIAL_PRIOR
		and source != SOURCE_BAYES_UPDATE
	):
		return _failure(ERROR_INVALID_BELIEF_RECORD)

	if typeof(record["source_turn"]) != TYPE_INT:
		return _failure(ERROR_INVALID_BELIEF_RECORD)

	if int(record["source_turn"]) < 0:
		return _failure(ERROR_INVALID_BELIEF_RECORD)

	var distribution: Dictionary = record["distribution"]

	var validation := validate_distribution(
		distribution,
		0.000001
	)

	if not validation["valid"]:
		return _failure(ERROR_INVALID_BELIEF_RECORD)

	if not _is_valid_id(hypothesis):
		return _failure(ERROR_UNKNOWN_HYPOTHESIS)

	if not distribution.has(hypothesis):
		return _failure(ERROR_UNKNOWN_HYPOTHESIS)

	return _success({
		"probability": float(distribution[hypothesis])
	})
