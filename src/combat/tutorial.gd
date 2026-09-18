extends RefCounted
## Tutorial hooks machinery (round 5B): contextual hint rules evaluated
## against a context, each firing at most once. The hint catalog and trigger
## conditions are OPEN decisions.

const Sim = preload("res://src/combat/combat_sim.gd")

var rules: Array = []      # {id, condition: Callable(ctx)->bool, text, fired}
var ctx := {}              # game feeds live context (player, arena, flags)

func register_rule(id: String, condition: Callable, text: String) -> void:
	rules.append({"id": id, "condition": condition, "text": text, "fired": false})

func tick() -> void:
	for r in rules:
		if r.fired:
			continue
		if r.condition.call(ctx):
			r.fired = true
			Sim.toast(r.text)
			Sim.log_event("TUTORIAL HINT %s (scaffold)" % r.id)

func reset() -> void:
	for r in rules:
		r.fired = false
