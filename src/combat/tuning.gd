extends RefCounted
## Phase 0A greybox tuning. One resource doctrine:
## stamina pays for body actions; FEATHERS are both armor and ammunition.
## Held feathers harden you; spent feathers buy offense and leave you bare.

const WALK_SPEED := 4.6
const SPRINT_SPEED := 7.4
const SPRINT_DRAIN_PER_SEC := 12.0

const ROLL_SPEED := 8.5
const ROLL_DURATION := 0.62
const ROLL_IFRAME_START := 0.08   # i-frames match the tucked part of the roll
const ROLL_IFRAME_END := 0.42
const ROLL_COST := 25.0

const ATTACK_COST := 20.0
const HEAVY_COST := 32.0
const STAMINA_MAX := 100.0
const STAMINA_REGEN := 30.0
const STAMINA_REGEN_DELAY := 0.7

const PLAYER_HP := 100.0
const PLAYER_HURT_RADIUS := 0.5
const PLAYER_STAGGER := 0.35
const ATTACK_STEP_SPEED := 1.6    # forward drift during windup + active
const BUFFER_AFTER_STATE := 0.25  # input buffer grace after a state ends

# The feather economy. Feathers held = armor. Feathers spent = ammo.
const FEATHERS_MAX := 30.0
const FEATHER_REGEN := 0.7        # slow molt-regrowth per second, always on
const RESIST_AT_FULL := 0.5       # 50% damage taken at a full coat, linear down to 0
const VOLLEY_COST := 6.0
const VOLLEY_DAMAGE := 8.0        # per feather projectile
const VOLLEY_COUNT := 3
const VOLLEY_SPREAD_DEG := 9.0
const VOLLEY_SPEED := 16.0
const VOLLEY_LIFE := 1.2
const VOLLEY_COMMIT := 0.35       # rooted cast time
const VOLLEY_STAGGER := 0.15
const PICKUP_VALUE := 6.0
const PICKUP_RADIUS := 0.9
const PICKUP_RESPAWN := 12.0
const KILL_FEATHERS := 6.0        # a felled effigy sheds into your coat

const PLAYER_ATTACK := {
	"damage": 20.0, "windup": 0.28, "active": 0.14, "recovery": 0.46,
	"reach": 2.4, "arc_deg": 100.0, "stagger": 0.45,
}
# Tradeoff doctrine, instance two: more damage and stagger, but a longer
# exposed windup and a heavier stamina bite. Power paid for in commitment.
const HEAVY_ATTACK := {
	"damage": 32.0, "windup": 0.50, "active": 0.16, "recovery": 0.62,
	"reach": 2.5, "arc_deg": 110.0, "stagger": 0.8,
}
const DUMMY_ATTACK := {
	"damage": 25.0, "windup": 0.85, "active": 0.12, "recovery": 1.05,
	"reach": 2.6, "arc_deg": 90.0,
}
const DUMMY_HP := 60.0
const DUMMY_HURT_RADIUS := 0.6
const DUMMY_APPROACH_SPEED := 3.0
const DUMMY_ATTACK_RANGE := 2.3
const DUMMY_AGGRO_RANGE := 11.0
const DUMMY_COOLDOWN := 0.9
const DUMMY_STAGGER := 0.45
const DUMMY_RESPAWN := 4.0
const DUMMY_TRACK_FRACTION := 0.5  # share of windup where it still turns
const DUMMY_TRACK_RATE := 2.6      # rad/s

const HITSTOP_DEALT := 0.05
const HITSTOP_TAKEN := 0.09

const LOCK_RANGE := 18.0
const LOCK_BREAK_RANGE := 26.0
const LOCK_CONE_DEG := 75.0
