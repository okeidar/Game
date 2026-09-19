extends RefCounted
## Consumables scaffolding (Omer directive 2026-09-18, round 2).
## Machinery only: inventory slots with quantities, a use action (the commit
## lives in the player state machine), and an effect application hook.
## No item designs exist - catalog, quantities, and sources are OPEN.

const Sim = preload("res://src/combat/combat_sim.gd")

var slots: Array = []    # each: {"id": String, "qty": int}
var item_defs := {}      # id -> Callable(user); the effect hook. Catalog OPEN.
var item_descs := {}    # id -> one-line description with its cost (design law: the UI shows the tradeoff)

func add_item(id: String, qty: int = 1) -> void:
	for it in slots:
		if it.id == id:
			it.qty += qty
			Sim.log_event("ITEM GAINED %s x%d (have %d)" % [id, qty, it.qty])
			return
	slots.append({"id": id, "qty": qty})
	Sim.toast("%s x%d" % [id, qty])
	Sim.log_event("ITEM GAINED %s x%d" % [id, qty])

func register_item_def(id: String, on_use: Callable) -> void:
	item_defs[id] = on_use

func register_item_desc(id: String, desc: String) -> void:
	item_descs[id] = desc

func describe(id: String) -> String:
	return item_descs.get(id, "an unwritten thing (scaffold)")

func can_use(slot: int) -> bool:
	return slot >= 0 and slot < slots.size() and slots[slot].qty > 0

func use(slot: int, user) -> bool:
	if not can_use(slot):
		Sim.log_event("ITEM DENIED empty slot")
		return false
	var it: Dictionary = slots[slot]
	it.qty -= 1
	if it.qty <= 0:
		slots.remove_at(slot)
	if item_defs.has(it.id):
		item_defs[it.id].call(user)   # effect application hook
	Sim.log_event("ITEM USED %s (effect hook - catalog undecided)" % it.id)
	return true
