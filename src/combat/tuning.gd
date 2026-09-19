extends RefCounted
## Phase 0A greybox tuning, fitted to published souls-like values (see
## docs/design-notes-phase-0a.md "Tuning benchmarks" for the full table).
## One resource doctrine: stamina pays for body actions; FEATHERS are both
## armor and ammunition. Held feathers harden you; spent feathers buy offense
## and leave you bare. Every strong option carries a named cost.

const WALK_SPEED := 4.6            # C: feel value, no published analogue
const SPRINT_SPEED := 7.4          # C: ~1.6x walk, matches souls walk/sprint ratio feel
const SPRINT_DRAIN_PER_SEC := 14.0 # C: DS3 drain is unpublished; kept near DS1-era estimates

# Roll: fitted to the FromSoft standard roll (A-grade convergence):
# DS3 med roll i-frames 0-26 @60fps (433ms window), roll-cancel at 42 (0.70s)
# Elden Ring light/med: 13 i-frames @30fps = 433ms, 8 recovery frames, ~0.70s total
# DS1: 11 i-frames @30fps (367ms); i-frames active from the first frame (DS3/ER)
const ROLL_SPEED := 6.0            # C: ~4.2m travel over the roll; souls roll distance unpublished
const ROLL_DURATION := 0.70        # A: DS3 roll-cancel 42/60, ER ~21/30
const ROLL_IFRAME_START := 0.0     # A: i-frames from frame 0 (DS3 wikidot, gamedev anatomy article)
const ROLL_IFRAME_END := 0.43      # A: 433ms window (ER 13/30; DS3 med roll 0-26/60)
const ROLL_COST := 16.0            # A: DS3 roll costs exactly 16 stamina (darksouls3.wikidot.com/stamina)

const ATTACK_COST := 20.0          # B: DS3 straight-sword R1 ~20 (soulsplanner weapon stamina tables)
const HEAVY_COST := 27.0           # B/C: DS3 uncharged R2 sits ~1.3-1.5x R1 cost
const STAMINA_MAX := 100.0         # B: DS3 starting-mid pool 90-160 (softcap 160 @40 END); 100 keeps costs readable
const STAMINA_REGEN := 45.0        # A: exactly 45/s in both DS1 and DS3
const STAMINA_REGEN_DELAY := 0.7   # C: souls regen delay is unpublished; short delay keeps pressure after commits

const PLAYER_HP := 100.0
const PLAYER_HURT_RADIUS := 0.5    # C: greybox capsule
const PLAYER_STAGGER := 0.35       # C: hitstun length is feel territory
const ATTACK_STEP_SPEED := 1.6     # C: forward drift during windup + active
const BUFFER_AFTER_STATE := 0.25   # C: input buffer grace after a state ends

# The feather economy. Feathers held = armor. Feathers spent = ammo.
# Model is A-grade: DS3 absorption is a % reduction applied after flat
# defense, stacking multiplicatively - the coat is a single absorption slot
# driven by feathers held. Linear-in-feathers curve is our judgment call (C).
const FEATHERS_MAX := 30.0
# Omer directive (2026-09-18, verbatim): "feathers are replenished by
# collection, not over time". No timer-based regrowth exists. The coat refills
# only through world pickups (respawning) and feathers from felled enemies,
# so there is always an earnable path back.
const RESIST_AT_FULL := 0.5        # C: 50% at a full coat, linear down to 0
const VOLLEY_COST := 6.0           # C: own economy
const VOLLEY_DAMAGE := 8.0         # C: per feather projectile
const VOLLEY_COUNT := 3
const VOLLEY_SPREAD_DEG := 9.0
const VOLLEY_SPEED := 16.0
const VOLLEY_LIFE := 1.2
const VOLLEY_COMMIT := 0.35        # C: rooted cast time
const VOLLEY_STAGGER := 0.15
const PICKUP_VALUE := 6.0
const PICKUP_RADIUS := 0.9
const PICKUP_RESPAWN := 12.0
const KILL_FEATHERS := 6.0         # a felled effigy sheds into your coat
const KILL_FEATHERS_RISEN := 1.0   # [overnight proposal - awaiting Omer review] an effigy that rose on its own timer is worth a token: scarcity stays real, and full-value farming means RESTING to reset the world (the genre's farm loop costs the world reset)

# Player light attack. Enemy-reactability rules do not bound player swings;
# fitted so one full swing ~= one roll cycle (C, DS3 straight-sword feel).
const PLAYER_ATTACK := {
	"damage": 20.0, "windup": 0.28, "active": 0.14, "recovery": 0.42,
	"reach": 2.4, "arc_deg": 100.0, "stagger": 0.45,
}
# Tradeoff doctrine, instance two: more damage and stagger, but a longer
# exposed windup and a heavier stamina bite. Power paid for in commitment.
const HEAVY_ATTACK := {
	"damage": 32.0, "windup": 0.50, "active": 0.16, "recovery": 0.62,
	"reach": 2.5, "arc_deg": 110.0, "stagger": 0.8,
}
# Effigy attack: B-grade fit. gamedev anatomy article: attack signal + active
# must give >= 340ms to be reactable; training enemy stays generous (0.85s).
# Recovery is the Window of Opportunity and should be the longest phase.
const DUMMY_ATTACK := {
	"damage": 15.0, "windup": 0.85, "active": 0.12, "recovery": 1.05,  # [overnight proposal - awaiting Omer review] 25->15: training effigy killed in 4 hits; genre tutorial hits take ~10-15% of a bar
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

# Pattern cycle [overnight proposal - awaiting Omer review]: the training
# effigy no longer repeats one swing forever - every third attack chains a
# faster, weaker follow-up (deterministic counter, never RNG). The follow-up
# pays for its speed with lower damage; after the double the effigy rests
# longer (DUMMY_CHAIN_COOLDOWN) - pressure costs the enemy its punish window.
# Telegraph honesty holds: the follow-up runs the same yellow->red cycle.
const DUMMY_ATTACK_FOLLOWUP := {
	"damage": 10.0, "windup": 0.5, "active": 0.12, "recovery": 0.6,
	"reach": 2.6, "arc_deg": 90.0, "delay": 0.25,
}
const DUMMY_PATTERN_PERIOD := 3     # every 3rd swing chains the follow-up
const DUMMY_CHAIN_COOLDOWN := 1.6   # the longer rest after the double

# The overhead [overnight proposal - awaiting Omer review]: every 6th swing the
# effigy heaves the club overhead - slow, heavy, narrow, and UNBLOCKABLE (the
# red-only tell: the windup glows red instead of yellow). Block fails against
# it; spacing or a roll beats it. This is the pattern's second attack, the one
# that punishes a player who only learned to hold block.
const DUMMY_ATTACK_OVERHEAD := {
	"damage": 25.0, "windup": 1.2, "active": 0.14, "recovery": 1.2,
	"reach": 2.8, "arc_deg": 70.0, "unblockable": true,
}
const DUMMY_OVERHEAD_PERIOD := 6   # every 6th swing is the overhead

# The shove [overnight proposal - awaiting Omer review]: hugging the effigy is
# not free. Stand inside DUMMY_SHOVE_RANGE for DUMMY_SHOVE_DWELL seconds and it
# shoves you off - fast, weak, and telegraphed with the same yellow->red cycle.
# COST to the effigy (tradeoff doctrine cuts both ways): shoving steps it
# BACKWARD and leaves the long rest (same price as the double), so baiting the
# shove buys a real approach window. Both sides pay.
const DUMMY_SHOVE := {
	"damage": 6.0, "windup": 0.28, "active": 0.10, "recovery": 0.5,
	"reach": 1.6, "arc_deg": 120.0,
}
const DUMMY_SHOVE_RANGE := 1.3    # closer than any weapon reach: hugging
const DUMMY_SHOVE_DWELL := 0.8    # seconds of hugging before it answers
const DUMMY_SHOVE_RETREAT := 2.0  # its backward step speed after the shove

# Defense verbs (Omer playtest directive 2026-09-18; reference: Mortal Shell 2).
# Doctrine: every defense pays for its safety - block pays stamina + mobility,
# parry pays a tight timing window, perfect dodge pays proximity to the blow.
const BLOCK_DAMAGE_CUT := 0.7        # C: blocked hits still chip 30% through (MS2 guard nullifies; we keep chip per doctrine)
const BLOCK_STAMINA_PER_DAMAGE := 0.9 # C: the guard budget is stamina; heavy hits tax it harder
const BLOCK_MOVE_MULT := 0.45        # B: MS2 guard allows slow movement
const BLOCK_REGEN_MULT := 0.2        # A: DS3 blocking cuts stamina regen by 80%
const GUARD_BREAK_STAGGER := 1.0     # C: guard break = full hit + long reel
const PARRY_WINDOW := 0.13           # B: block pressed this close to impact deflects (DS3 parry ~8-12 active frames @60)
const PARRY_STAGGER := 1.4           # C: deflected attacker reels - the punish window (MS2 break damage, simplified)
const PERFECT_DODGE_WINDOW := 0.15   # C: hit must connect within this of roll start
# Perfect dodge pays NOTHING yet. Omer 2026-09-18: "feathers are scarce. dont
# invent stuff. ask me first." Standing rule: never invent reward/economy/
# design numbers - propose, get his word, then build.

const HITSTOP_DEALT := 0.08        # [overnight proposal - awaiting Omer review] 50->80ms inside the 50-150ms action-game band; dealt hits were hard to feel
const HITSTOP_TAKEN := 0.09
const DEATH_SCREEN_DELAY := 1.4   # [overnight proposal - awaiting Omer review] beat of world between the killing blow and YOU DIED (DS3 ~1.2s fade)

const LOCK_RANGE := 18.0           # C: souls lock-on range unpublished
const LOCK_BREAK_RANGE := 26.0
const LOCK_CONE_DEG := 75.0

# ---------------------------------------------------------------------------
# MACHINERY SCAFFOLDS (Omer directive 2026-09-18: "just have the thing ready
# for when we decide the details"). Every value below is PLACEHOLDER
# SCAFFOLDING, not design. Standing rule: Omer decides the real numbers.
const HEAL_CHARGES_SCAFFOLD := 3        # SCAFFOLD - charges undecided
const HEAL_AMOUNT_SCAFFOLD := 40.0      # SCAFFOLD - amount undecided
const HEAL_COMMIT := 0.9                # SCAFFOLD - rooted cast time undecided
const CRIT_WINDOW_SCAFFOLD := 1.2       # SCAFFOLD - riposte window undecided
const CRIT_MULTIPLIER_SCAFFOLD := 2.0   # SCAFFOLD - riposte multiplier undecided
const BACKSTAB_HALF_ANGLE_SCAFFOLD := 60.0  # SCAFFOLD - backstab condition undecided
const CHECKPOINT_RADIUS_SCAFFOLD := 1.8 # SCAFFOLD - interact radius undecided
const ESSENCE_RATE_SCAFFOLD := 1.0      # SCAFFOLD - feather->essence conversion undecided

# Sneak + sound machinery scaffolds (Omer directive 2026-09-18, round 2):
# sneak = slow walk; movement emits sound events. Enemy-side awareness is
# deliberately NOT built (deferred). Values below are SCAFFOLD, not design.
const SNEAK_SPEED_MULT_SCAFFOLD := 0.45   # SCAFFOLD - sneak speed undecided
const SOUND_STEP_DISTANCE := 2.0          # machinery: one footstep per this much travel
const SOUND_RADIUS_SNEAK_SCAFFOLD := 2.5  # SCAFFOLD - sound radii undecided
const SOUND_RADIUS_WALK_SCAFFOLD := 6.0   # SCAFFOLD
const SOUND_RADIUS_SPRINT_SCAFFOLD := 10.0 # SCAFFOLD
const SOUND_RADIUS_ROLL_SCAFFOLD := 8.0   # SCAFFOLD
const STATUS_BUILDUP_DECAY_SCAFFOLD := 10.0 # SCAFFOLD - buildup decay/s undecided
const ITEM_USE_COMMIT_SCAFFOLD := 0.8     # SCAFFOLD - item use commit undecided

# Moveset + jump scaffolds (Omer directive 2026-09-18, round 2).
const CHAIN_WINDOW_SCAFFOLD := 0.8      # SCAFFOLD - chain continue window undecided
const CHAIN_CANCEL_POINT_SCAFFOLD := 0.6  # [overnight proposal - awaiting Omer review] SCAFFOLD - recovery fraction before a chain/dodge cancel opens; the first 60% of recovery stays committed
const FINISHER_COST_MULT := 1.5        # [overnight proposal - awaiting Omer review] chain finisher pays 1.5x stamina for the burst
const WEAPON_SWAP_LOCKOUT := 0.45      # [overnight proposal - awaiting Omer review] SCAFFOLD - seconds of exposure after a mid-fight weapon swap; no attack can start
const ROLL_ATTACK_WINDOW_SCAFFOLD := 0.4 # SCAFFOLD - roll-attack window undecided
const JUMP_VELOCITY_SCAFFOLD := 5.0     # SCAFFOLD - jump height/feel undecided

# Awareness + hazard scaffolds (round 3, autonomous scaffolding under Omer's
# standing directive). Enemy-side detection machinery; all values OPEN.
const VISION_RANGE_SCAFFOLD := 12.0      # SCAFFOLD - sight range undecided
const VISION_HALF_ANGLE_SCAFFOLD := 65.0 # SCAFFOLD - vision cone undecided
const SNEAK_VISION_MULT_SCAFFOLD := 0.5  # SCAFFOLD - sneak visibility undecided
const SUSPICION_TIME_SCAFFOLD := 0.9     # SCAFFOLD - time-to-alert undecided
const HEARING_STIMULUS_SCAFFOLD := 0.7   # SCAFFOLD - hearing vs sight weight undecided
const HEARING_PULSE_SCAFFOLD := 0.4      # SCAFFOLD - suspicion bump per heard sound undecided
const ALERT_MEMORY_SCAFFOLD := 3.0       # SCAFFOLD - how long alert persists undecided
const FALL_SAFE_SPEED_SCAFFOLD := 12.0   # SCAFFOLD - safe landing speed undecided
const FALL_DAMAGE_SCALE_SCAFFOLD := 5.0  # SCAFFOLD - damage per m/s over safe undecided

const ALERT_LINK_RADIUS_SCAFFOLD := 8.0  # SCAFFOLD - aggro link radius undecided
