extends RefCounted
## Progression machinery (Omer directive 2026-09-18): a spend/sink path and an
## upgrade application hook, ready for when the details are decided.
## Costs, conversion rate, and the upgrade catalog are ALL UNDECIDED -
## the interfaces below are scaffolding, not design.

const Sim = preload("res://src/combat/combat_sim.gd")
const T = preload("res://src/combat/tuning.gd")

var applied_upgrades: Array = []
var essence := 0.0   # bookkeeping exists; what essence IS for is undecided

func can_afford(cost: Dictionary, player) -> bool:
	return player.feathers >= cost.get("feathers", 0.0)

func spend(cost: Dictionary, player) -> bool:
	if not can_afford(cost, player):
		Sim.log_event("PROGRESSION SPEND DENIED %s" % str(cost))
		return false
	player.add_feathers(-cost.get("feathers", 0.0))
	Sim.log_event("PROGRESSION SPEND %s" % str(cost))
	return true

## Feather -> essence conversion interface. Rate is SCAFFOLD, undecided.
func convert_feathers_to_essence(player, amount: float) -> float:
	var n: float = minf(amount, player.feathers)
	player.add_feathers(-n)
	essence += n * T.ESSENCE_RATE_SCAFFOLD
	Sim.log_event("CONVERTED %.0f feathers -> %.0f essence (scaffold rate)" % [n, n * T.ESSENCE_RATE_SCAFFOLD])
	return n * T.ESSENCE_RATE_SCAFFOLD

## Upgrade application hook. No catalog exists yet (undecided): the hook
## records and acknowledges, nothing more.
func apply_upgrade(upgrade_id: String, _player) -> bool:
	applied_upgrades.append(upgrade_id)
	Sim.log_event("UPGRADE APPLIED (stub, no catalog yet): %s" % upgrade_id)
	return true
