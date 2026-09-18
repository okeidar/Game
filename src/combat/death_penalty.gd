extends RefCounted
## Death-penalty machinery. Death records location/state and leaves a remnant
## that can hold something for recovery. What is dropped: UNDECIDED.

const Sim = preload("res://src/combat/combat_sim.gd")
const Remnant = preload("res://src/world/remnant.gd")

static func drop(player, parent: Node) -> Node:
	var r = Remnant.new()
	# Payload rules UNDECIDED (open decision for Omer): the record exists,
	# the contents stay empty scaffolding until he decides what death costs.
	r.payload = {"death_position": player.global_position, "contents": {}}
	r.position = player.global_position
	parent.add_child(r)
	Sim.log_event("REMNANT LEFT WHERE THEY FELL (what it holds: undecided)")
	return r
