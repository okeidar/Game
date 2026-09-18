extends RefCounted
## Settings machinery (round 5A): a registry of named settings with bounded
## values and change hooks. Which settings exist, their ranges, and defaults
## are OPEN - entries registered so far are SCAFFOLD to prove the machinery.

const Sim = preload("res://src/combat/combat_sim.gd")

var defs := {}     # id -> {label, min, max, step, value, on_change}
var order: Array = []

func register_setting(id: String, def: Dictionary) -> void:
	defs[id] = def
	order.append(id)

func adjust(id: String, dir: int) -> void:
	if not defs.has(id):
		return
	var d: Dictionary = defs[id]
	d.value = clampf(d.value + d.step * dir, d.min, d.max)
	Sim.log_event("SETTING %s = %s" % [id, str(d.value)])
	if d.has("on_change"):
		d.on_change.call(d.value)

func label_for(id: String) -> String:
	var d: Dictionary = defs[id]
	return "%s: %s" % [d.label, str(d.value)]
