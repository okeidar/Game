extends RefCounted
## Death-penalty machinery. Death records location/state and leaves a remnant
## that can hold something for recovery. What is dropped: UNDECIDED.

const Sim = preload("res://src/combat/combat_sim.gd")
const Remnant = preload("res://src/world/remnant.gd")

static func drop(player, parent: Node) -> Node:
	# Genre law [overnight proposal - awaiting Omer review]: death drops every
	# carried feather where you fell. Die again before recovering and what the
	# first remnant held is gone for good - only the latest death leaves a mark.
	for old in parent.get_tree().get_nodes_in_group("remnants"):
		var held: float = old.payload.get("contents", {}).get("feathers", 0.0)
		if held > 0.0:
			Sim.log_event("THE FIRST REMNANT FADES - %d feathers gone for good" % int(held))
		else:
			Sim.log_event("THE FIRST REMNANT FADES (it held nothing)")
		old.queue_free()
	var r = Remnant.new()
	var carried: float = player.feathers
	r.payload = {"death_position": player.global_position, "contents": {"feathers": carried}}
	player.feathers = 0.0
	r.position = player.global_position
	parent.add_child(r)
	Sim.log_event("REMNANT LEFT WHERE THEY FELL - %d feathers with it" % int(carried))
	return r
