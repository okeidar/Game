extends RefCounted
## Gesture machinery (round 5A): a registry of named gestures with perform
## hooks. The gesture catalog, animations, and any gameplay effects are OPEN -
## nothing is registered by default.

const Sim = preload("res://src/combat/combat_sim.gd")

var gestures := {}   # id -> Callable(player)
var order: Array = []

func register_gesture(id: String, fn: Callable) -> void:
	gestures[id] = fn
	order.append(id)

func perform(id: String, player) -> bool:
	if not gestures.has(id):
		return false
	Sim.log_event("GESTURE %s (scaffold - catalog undecided)" % id)
	gestures[id].call(player)
	return true
