extends RefCounted
## Map machinery (round 5B): a region graph - named regions, links between
## them, visited flags, current-region tracking. Cartography, region
## boundaries, and any map UI presentation are OPEN.

const Sim = preload("res://src/combat/combat_sim.gd")

var regions := {}        # id -> {"links": Array, "visited": bool}
var current := ""

func register_region(id: String) -> void:
	if not regions.has(id):
		regions[id] = {"links": [], "visited": false}

func link(a: String, b: String) -> void:
	register_region(a)
	register_region(b)
	if not regions[a].links.has(b):
		regions[a].links.append(b)
	if not regions[b].links.has(a):
		regions[b].links.append(a)

func set_current(id: String) -> void:
	if current == id:
		return
	current = id
	if not regions.get(id, {}).get("visited", true):
		regions[id].visited = true
		Sim.log_event("MAP discovered %s" % id)

func is_visited(id: String) -> bool:
	return regions.get(id, {}).get("visited", false)
