extends RefCounted
## Dialogue machinery (round 5B): trees as pure data - nodes with text and
## labeled choices leading to other nodes. The actual writing, who says it,
## and every narrative decision are OPEN (and canon text never enters the
## public repo anyway).

const Sim = preload("res://src/combat/combat_sim.gd")

var tree := {}
var current := ""
var ended := false

func start(t: Dictionary, entry: String) -> void:
	tree = t
	current = entry
	ended = false
	Sim.log_event("DIALOGUE START %s" % entry)

func node() -> Dictionary:
	return tree.get(current, {"text": "(missing node)", "choices": []})

func choices() -> Array:
	return node().get("choices", [])

func choose(i: int) -> void:
	var c := choices()
	if i < 0 or i >= c.size():
		return
	var nxt: String = c[i].get("next", "")
	if nxt == "":
		ended = true
		Sim.log_event("DIALOGUE END")
	else:
		current = nxt
