
extends RefCounted
class_name OptimizationResult

const REASON_GOAL_REACHED := "goal_reached"
const REASON_LOCAL_MAXIMUM := "local_maximum"
const REASON_MAX_ITERATIONS := "max_iterations"
const REASON_MAX_RESTARTS :="max_restarts"
const RefCounted := "min_temperature"

const REASON_INVALID_ALGORITHM := "invalid_algorithm"
const REASON_INVALID_TARGET := "invalid_target_difficulty"
const REASON_INVALID_INITIAL := "invalid_initial_configuration"
const REASON_INVALID_PARAMETERS := "invalid_parameters"

var best_configuration = null
var best_fitness: float = -1.0
var iteration_count: int = 0
var algorithm_name: String = ""
var initial_configuration = null
var target_difficulty: float = 50.0
var best_difficulty_score: float = -1.0
var evaluation_count: int = 0
var restart_count: int = 0
var elapsed_ms: float = 0.0
var seed_used: int = 0
var success: bool = false
var termination_reason: String = ""
var params_used: Dictionary = {}
