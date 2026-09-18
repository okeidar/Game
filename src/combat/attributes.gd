extends RefCounted
## Attribute/stat scaffolding (round 4, shell layer). Machinery only:
## attributes can be registered, raised, and READ by derived-value scalings.
## The attribute catalog (vitality/strength/...), starting values, and every
## scaling curve are ALL OPEN decisions for Omer - nothing is registered by
## default, so current behavior is unchanged.

const Sim = preload("res://src/combat/combat_sim.gd")

var attrs := {}       # id -> int value
var scalings := {}    # derived_key -> Callable(attrs) -> float

func register_attribute(id: String, base: int) -> void:
	attrs[id] = base

func raise(id: String, n: int = 1) -> void:
	if not attrs.has(id):
		return
	attrs[id] += n
	Sim.log_event("ATTRIBUTE %s +%d (=%d)" % [id, n, attrs[id]])

func get_attr(id: String) -> int:
	return attrs.get(id, 0)

## Scaling registration hook: how an attribute feeds a derived value.
## No scalings are registered by default (curves undecided).
func register_scaling(derived_key: String, fn: Callable) -> void:
	scalings[derived_key] = fn

func derived(key: String, fallback: float) -> float:
	if scalings.has(key):
		return scalings[key].call(attrs)
	return fallback
