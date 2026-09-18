extends RefCounted
## Status effect scaffolding (Omer directive 2026-09-18, round 2).
## Machinery only: statuses can be REGISTERED, build up on a combatant,
## TRIGGER at a threshold, TICK while active, and EXPIRE. No status designs
## exist - the catalog (bleed/poison/...), rates, effects, and resistances
## are all open decisions for Omer.

const Sim = preload("res://src/combat/combat_sim.gd")
const T = preload("res://src/combat/tuning.gd")

var defs := {}     # id -> {threshold, duration, tick_interval, on_tick (Callable, optional)}
var meters := {}   # id -> current buildup
var active := {}   # id -> {t_left, tick_t}

## Registration hook. Nothing registers a real status yet (catalog OPEN).
func register_status(id: String, def: Dictionary) -> void:
	defs[id] = def

func add_buildup(id: String, amount: float, owner_name: String) -> void:
	if not defs.has(id) or active.has(id):
		return
	meters[id] = meters.get(id, 0.0) + amount
	Sim.log_event("STATUS BUILDUP %s on %s %.0f/%.0f" % [id, owner_name, meters[id], defs[id].threshold])
	if meters[id] >= defs[id].threshold:
		active[id] = {"t_left": defs[id].duration, "tick_t": 0.0}
		Sim.log_event("STATUS TRIGGERED %s on %s" % [id, owner_name])

func tick(dt: float, owner_name: String) -> void:
	for id in meters.keys():
		if not active.has(id):
			meters[id] = maxf(0.0, meters[id] - T.STATUS_BUILDUP_DECAY_SCAFFOLD * dt)
	for id in active.keys():
		var a: Dictionary = active[id]
		a.tick_t += dt
		if a.tick_t >= defs[id].tick_interval:
			a.tick_t = 0.0
			Sim.log_event("STATUS TICK %s on %s" % [id, owner_name])
			if defs[id].has("on_tick"):
				defs[id].on_tick.call()
		a.t_left -= dt
		if a.t_left <= 0.0:
			active.erase(id)
			meters[id] = 0.0
			Sim.log_event("STATUS EXPIRED %s on %s" % [id, owner_name])

func is_active(id: String) -> bool:
	return active.has(id)
