extends RefCounted
## New Game+ machinery (round 5A): a cycle counter plus scaling hooks that
## reshape values per cycle. What triggers the next cycle, and every scaling
## curve, are OPEN decisions. Default cycle 0, no scalings: identity.

const Sim = preload("res://src/combat/combat_sim.gd")

static var cycle := 0
static var scalings := {}   # key -> Callable(cycle) -> float multiplier

static func register_scaling(key: String, fn: Callable) -> void:
	scalings[key] = fn

static func scaled(key: String, base: float) -> float:
	if scalings.has(key):
		return base * scalings[key].call(cycle)
	return base

static func next_cycle() -> void:
	cycle += 1
	Sim.log_event("NG+ CYCLE %d (trigger conditions undecided)" % cycle)

static func reset() -> void:
	cycle = 0
	scalings.clear()
