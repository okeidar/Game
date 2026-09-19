extends RefCounted
## Moveset machinery (Omer directive 2026-09-18, round 2): per-weapon attack
## tables - light chain, heavy, running attack, rolling attack, jump attack
## slots. The weapon/moveset CATALOG is Omer's later decision; this file holds
## the table shape and one scaffold moveset proving the machinery runs.
## Explicitly NOT included (Omer's exclusions): equip load, poise/hyperarmor,
## charged heavies, weapon arts, guard counters.

const T = preload("res://src/combat/tuning.gd")

## The single scaffold moveset: every slot reuses the existing proven attack
## data so current playtest behavior stays stable. All OPEN: weapons, chains,
## frame data.
static func scaffold_moveset() -> Dictionary:
	return blade()

static func _atk(dmg: float, w: float, a: float, r: float, reach: float, arc: float, stagger: float) -> Dictionary:
	return {"damage": dmg, "windup": w, "active": a, "recovery": r, "reach": reach, "arc_deg": arc, "stagger": stagger}

# --- Weapon catalog (overnight iteration 2, 2026-09-19) ---------------------
# [overnight proposals - awaiting Omer review]. The tradeoff doctrine applied:
# every weapon pays for its strength with a named cost. Numbers chosen against
# the genre reference points in /tmp/deep-research (DS3-class light ~0.9s full
# swing, heavy ~1.3s), NOT duplicated from any game. His exclusions stand: no
# equip load, poise, charged heavies, weapon arts, guard counters.

## BLADE - the standard. No strengths, no weaknesses. The ruler other weapons
## are measured against. Its chain now ENDS in a finisher: the third link hits
## hardest but is the most exposed swing on the table.
static func blade() -> Dictionary:
	return {
		"id": "blade",
		"cost_mult": 1.0,
		"light_chain": [_atk(20.0, 0.28, 0.14, 0.42, 2.4, 100.0, 0.45), _atk(22.0, 0.30, 0.14, 0.46, 2.4, 100.0, 0.5), _atk(31.0, 0.36, 0.16, 0.62, 2.5, 110.0, 1.0)],   # link 3 = FINISHER [overnight proposal - awaiting Omer review]: biggest hit + stagger, paid for with a longer readable windup, the longest recovery, and 1.5x stamina (T.FINISHER_COST_MULT)
		"heavy": _atk(32.0, 0.50, 0.16, 0.62, 2.5, 110.0, 0.8),
		"running_attack": _atk(24.0, 0.24, 0.14, 0.50, 2.5, 90.0, 0.6),
		"rolling_attack": _atk(20.0, 0.20, 0.14, 0.40, 2.3, 90.0, 0.45),
		"jump_attack": _atk(26.0, 0.30, 0.16, 0.55, 2.4, 100.0, 0.7),
	}

## TWIN FANGS - speed. Four-hit chain, cheapest stamina, fastest recovery.
## COST: shortest reach (must hug the enemy), lowest per-hit damage, almost no
## stagger - fangs cannot stop an effigy mid-swing, so every approach is a
## dodge-dependency. Pays for safety with reach; pays for speed with stagger.
static func fangs() -> Dictionary:
	return {
		"id": "fangs",
		"cost_mult": 0.6,
		"light_chain": [
			_atk(9.0, 0.16, 0.10, 0.26, 1.8, 80.0, 0.15),
			_atk(9.0, 0.14, 0.10, 0.24, 1.8, 80.0, 0.15),
			_atk(11.0, 0.16, 0.10, 0.26, 1.8, 80.0, 0.15),
			_atk(15.0, 0.22, 0.12, 0.40, 1.9, 90.0, 0.35),
		],
		"heavy": _atk(24.0, 0.34, 0.14, 0.50, 2.2, 80.0, 0.5),
		"running_attack": _atk(13.0, 0.16, 0.10, 0.34, 2.0, 70.0, 0.25),
		"rolling_attack": _atk(11.0, 0.14, 0.10, 0.28, 1.8, 80.0, 0.2),
		"jump_attack": _atk(16.0, 0.22, 0.12, 0.42, 1.9, 90.0, 0.4),
	}

## MAUL - commitment. Highest per-hit damage and stagger that breaks enemy
## swings. COST: long exposed windup (interruptible), heaviest stamina drain,
## longest recovery - every swing is a bet, and a whiffed maul is a free hit
## for the enemy. Pays for power with exposure.
static func maul() -> Dictionary:
	return {
		"id": "maul",
		"cost_mult": 1.7,
		"light_chain": [_atk(34.0, 0.52, 0.18, 0.72, 2.7, 120.0, 1.3), _atk(42.0, 0.62, 0.20, 0.85, 2.7, 120.0, 1.8)],
		"heavy": _atk(55.0, 0.75, 0.20, 1.0, 2.8, 120.0, 2.2),
		"running_attack": _atk(38.0, 0.45, 0.18, 0.80, 2.8, 100.0, 1.5),
		"rolling_attack": _atk(30.0, 0.40, 0.16, 0.65, 2.5, 100.0, 1.1),
		"jump_attack": _atk(46.0, 0.55, 0.20, 0.90, 2.6, 110.0, 1.8),
	}

## The owned set (greybox: the winged one carries all three; acquisition is a
## later design decision - loot tables stay Omer's).
static func catalog() -> Array:
	return [blade(), fangs(), maul()]
