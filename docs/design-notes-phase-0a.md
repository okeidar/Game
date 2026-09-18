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
  (souls-style); regen 45/s after 0.7s, paused mid-action.
- Roll: 0.70s, i-frames 0.0-0.43s (active from the first frame, per the
  FromSoft standard roll). The capsule tucks and goes translucent exactly
  during i-frames: the animation and the invulnerability cannot drift.
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

## Tuning benchmarks (fitted 2026-09-18, Omer directive)

Every fitted value is ranked by evidence strength:
A = published frame data / wiki-documented mechanic. B = community
consensus or structured analysis. C = my judgment call (no public data).

| Value | Fitted | Before | Rank | Source / rationale |
| --- | --- | --- | --- | --- |
| Roll i-frame window | 0.43s from frame 0 | 0.34s from 0.08s | A | Elden Ring: 13 i-frames @30fps = 433ms (fextralife equip-load table). DS3 med roll: i-frames 0-26 @60fps (darksouls3 wikidot combat mechanics). gamedeveloper anatomy article: window active at first frame, 433ms. DS1: 11 frames @30 = 367ms (fandom frame chart). FromSoft converged on ~430ms across three titles; we take the DS3/ER value. |
| Roll total duration | 0.70s | 0.62s | A | DS3 roll-cancel at frame 42/60 (wikidot). ER light/med: 13+8 frames @30fps ~= 0.70s (fextralife). |
| Roll stamina cost | 16 | 25 | A | DS3 roll costs exactly 16 stamina (darksouls3 wikidot stamina page). |
| Stamina regen | 45/s | 30/s | A | 45/s in both DS1 (darksouls wikidot) and DS3 (darksouls3 wikidot + DS3 mechanics cheat sheet). |
| Stamina pool | 100 | 100 | B | DS3 pools run ~90 at start to 160 softcap at 40 END; 100 keeps DS3 costs readable 1:1. |
| Light attack cost | 20 | 20 | B | DS3 straight-sword R1 ~20 stamina (soulsplanner weapon stamina tables; community-standard value). |
| Heavy attack cost | 27 | 32 | B/C | DS3 uncharged R2 sits ~1.3-1.5x the R1 cost; judgement inside that band. |
| Sprint drain | 14/s | 12/s | C | Souls sprint drain is not published; kept a slow drain so sprint stays a positioning tool, not a free state. |
| Regen delay | 0.7s | 0.7s | C | Souls regen delay is unpublished; a short pause after each commit keeps pressure without feeling dead. |
| Effigy windup | 0.85s | 0.85s | B | gamedeveloper anatomy article: attack signal + active must give >= 340ms to be reactable (human processor ~240ms). Training enemy stays generous; Artorias-class telegraphs run up to ~1s (parryeverything breakdown). |
| Effigy recovery (punish window) | 1.05s | 1.05s | B | Same article: the Return phase is the Window of Opportunity and the longest phase; end pose >= 170ms to confirm the attack ended. |
| Effigy damage 25 vs player 100 hp | kept | kept | B/C | Early-game souls enemies kill in ~3-5 clean hits; bare player dies in 4, full coat stretches it to 8 through the resistance curve. |
| Feather resistance model | 0-50% linear in feathers held | same | A model / C curve | DS3 absorption is a % reduction applied after flat defense, stacking multiplicatively (darksouls3 wikidot). The coat is one absorption slot driven by feathers held; the linear-in-feathers curve is ours. |
| Tradeoff doctrine precedent | - | - | A | Elden Ring heavy load: same i-frames but +recovery frames and -20% stamina regen (fextralife). DS1 instability frames: 1.4x damage taken during roll recovery (fandom). FromSoft already prices every defensive option. |
| Light attack timing (0.28/0.14/0.42) | kept-ish | recovery 0.46 | C | Enemy reactability floors do not bound player swings; fitted so one full swing ~= one roll cycle (DS3 straight-sword cadence feel). |
| Heavy timing (0.50/0.16/0.62), damage 32 | kept | kept | C | 1.6x light damage for 1.8x windup and 1.35x stamina: power paid for in commitment. |
| Hitstop 0.05/0.09s | kept | kept | C | Standard action-game band 50-150ms; no souls-specific publication. |
| Roll travel speed | 6.0 m/s | 8.5 | C | ~4.2m travel over 0.70s; souls roll distance is unpublished. |
| Volley economy (6 feathers, 3x8 dmg, 0.35s rooted) | kept | kept | C | Own economy under the tradeoff doctrine: spending armor to buy offense. |
| Lock-on ranges (18/26m) | kept | kept | C | Souls lock-on range is unpublished. |

Indie cross-check (qualitative, rank B): Bleak Sword ships three verbs
(dodge, attack, strong attack) and tuned difficulty by playtesting, not
formulas (gamedeveloper Q&A). Death's Door removed the stamina bar entirely
to keep combat flowing (Polygon review, Noclip documentary). Both confirm
the compact-soulslike pattern: few verbs, readable enemies, difficulty from
timing rather than stats. We keep stamina because Omer's feather doctrine
needs a second resource to trade against, but the verb count stays minimal.

Judgment calls Omer should feel first in playtest: roll travel distance,
sprint drain, regen delay, light/heavy cadence, hitstop. Everything else is
anchored to published souls data.

## Deterministic testing

`godot --headless --path . -- --run-tests`: 12 scenarios, 47 checks, fixed
60Hz physics, scripted input feeds, no RNG anywhere in the sim. Covers:
stamina costs and regen, sprint drain, attack commitment + buffering, hit
window/arc, roll i-frames (standing vs timed vs early), lock-on rules,
telegraph duration gate (>= 0.8s readable) + stagger interrupt, hitstop,
feather resistance/volley/denial/pickup, heavy tradeoff, and a determinism
proof (two identical 400-frame scripts produce identical state traces).

## Hooks left for Omer's story (nothing invented)

- Negative-stamina builds (Omer, 2026-09-18, verbatim-ish): builds/systems
  that weaponize negative stamina - gear that converts stamina debt into
  power, or a feather variant that grows the coat only while in debt. Pure
  tradeoff doctrine: power now, paid for in a resource hole you must climb
  out of. Future-systems material, NOT 0A scope.

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
