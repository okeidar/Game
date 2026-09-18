# Phase 0A design notes - feather greybox

Status: built, tested, deployed (agent-built; Omer has not playtested yet).
Build: Godot 4.7.2, GDScript, text-first, headless CI. No art, all signal.

## Creative direction absorbed (Omer, 2026-09-18)

- Dark and gloomy tone, even at greybox: dusk arena, fog, cold moonlight,
  desaturated palette, pale ink HUD.
- Signature mechanic: the winged protagonist collects feathers. One resource,
  two uses: feathers held are armor (damage resistance, later defensive
  abilities); feathers spent are ammunition (volleys). Spending protection for
  offense is the risk economy in one resource.
- Generalized doctrine (Omer, same conversation): the decision system always
  works through tradeoffs. Every strong option carries a cost. Feathers are the
  flagship instance, not the only one.
- Omer has an initial story for some characters. It is not in 0A. No lore was
  invented: the protagonist, the arena ("the greyfield"), and the enemy ("the
  effigy") are placeholders with hooks, not fiction.

## The tradeoff doctrine as implemented in 0A

Every verb in the combat core has a cost line:

| Option | Gain | Cost |
| --- | --- | --- |
| Dodge roll | i-frames (0.34s) + reposition | 25 stamina, committed direction |
| Light attack | 20 dmg, quick | 20 stamina, locked in for 0.88s |
| Heavy attack | 32 dmg, hard stagger | 32 stamina, 0.5s exposed windup, 1.28s total |
| Sprint | 1.6x speed | drains the stamina you need to dodge (12/s) |
| Feather volley | ranged 3x8 dmg | 6 feathers = 10 points of resistance lost |
| Full feather coat | up to 50% damage resist | temptation: every volley strips it |
| Lock-on | camera + aim tracking | narrower awareness, breaks at range/death |

Design rule for everything after 0A (cards, systems, items, routes): each
option must name its cost in the same breath as its power. No free lunches,
no pure upgrades. Numbers live in `src/combat/tuning.gd`, one file, diffable.

## Feather economy (0A numbers)

- Coat size: 30 max. Slow regrowth: 0.7/s, always on (a molt, not a mana bar).
- Resistance: linear, 0% at empty to 50% at full coat.
- Volley: 6 feathers, three projectiles, 8 damage each, 0.35s rooted cast.
  Denied below 6.
- Sources: 5 scattered pickups (+6 each, respawn 12s) and a felled effigy (+6).
- The coat is visible: one pale mote per 5 feathers orbits the protagonist.

## Combat core (0A numbers)

- Stamina 100. Actions allowed while stamina > 0 and may drive it negative
  (souls-style); regen 30/s after 0.7s, paused mid-action.
- Roll: 0.62s, i-frames 0.08-0.42s. The capsule tucks and goes translucent
  exactly during i-frames: the animation and the invulnerability cannot drift.
- Attacks: windup / active / recovery phases from one clock that drives both
  hit resolution and the sword pose. No cancel during windup/active. Inputs
  pressed during recovery are buffered and fire the frame the swing ends.
- Hit model: melee = sector (reach + arc) against capsule hurt radii, resolved
  once on the first active frame. Projectiles = sphere checks. Both are pure
  math, not physics callbacks, so tests are exact.
- Hitstop: 0.05s when you land a hit, 0.09s when you take one (tree pause).
- Effigy: approaches at 3.0 m/s, attacks at 2.3m. Windup 0.85s with early
  tracking (first half, 2.6 rad/s) then committed. Telegraph: slate -> yellow
  (windup) -> red (live frames), plus emission so it reads through fog. Any
  hit staggers it out of the swing. Recovery 1.05s: punishable. 60 hp, rises
  again 4s after falling.
- Player death: YOU DIED, wake at the slab, world resets.
- Camera: behind-the-back orbit (mouse or arrows), sphere-cast pull-in so
  walls never eat it, lock-on eases it behind the player-to-target line.

## Deterministic testing

`godot --headless --path . -- --run-tests`: 12 scenarios, 47 checks, fixed
60Hz physics, scripted input feeds, no RNG anywhere in the sim. Covers:
stamina costs and regen, sprint drain, attack commitment + buffering, hit
window/arc, roll i-frames (standing vs timed vs early), lock-on rules,
telegraph duration gate (>= 0.8s readable) + stagger interrupt, hitstop,
feather resistance/volley/denial/pickup, heavy tradeoff, and a determinism
proof (two identical 400-frame scripts produce identical state traces).

## Hooks left for Omer's story (nothing invented)

- Protagonist: winged, collects feathers. Name, history, why the coat works
  this way: open.
- The effigy: a training thing in a greyfield. What it is a rehearsal for: open.
- The arena: a walled yard at dusk. Where it is, whose it is: open.
- Defensive abilities at high coat (mentioned by Omer): not in 0A; the
  resistance curve is the hook.

## What I cannot judge without Omer

- Feel: roll length, i-frame window, hitstop weight, attack cadence.
- Timing readability: is 0.85s windup fair in the hand, not just in the test.
- Difficulty: effigy damage/hp/aggression vs. the coat economy.
- Whether the tradeoff doctrine reads in play the way he means it.
- Camera feel: sensitivity, lock-on ease, distance.
