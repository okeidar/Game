extends RefCounted
## Death-penalty machinery. Death drops every carried ESSENCE (scaffold label
## - the enemy-drop currency) where they fell and leaves a remnant that holds
## it for recovery. Feathers are NEVER dropped (Omer ruling 2026-09-19:
## feathers are not currency) - the coat survives death.

const Sim = preload("res://src/combat/combat_sim.gd")
const Remnant = preload("res://src/world/remnant.gd")

static func drop(player, parent: Node) -> Node:
	# Genre law [overnight proposal - awaiting Omer review]: death drops every
	# carried essence where you fell. Die again before recovering and what the
	# first remnant held is gone for good - only the latest death leaves a mark.
	for old in parent.get_tree().get_nodes_in_group("remnants"):
		var held: float = old.payload.get("contents", {}).get("essence", 0.0)
		if held > 0.0:
			Sim.log_event("THE FIRST REMNANT FADES - %d essence gone for good" % int(held))
		else:
			Sim.log_event("THE FIRST REMNANT FADES (it held nothing)")
		old.queue_free()
	var r = Remnant.new()
	var carried: float = 0.0
	if player.progression != null:
		carried = player.progression.essence
		player.progression.essence = 0.0
	r.payload = {"death_position": player.global_position, "contents": {"essence": carried}}
	r.position = player.global_position
	parent.add_child(r)
	Sim.log_event("REMNANT LEFT WHERE THEY FELL - %d essence with it (the coat is untouched)" % int(carried))
	return r
