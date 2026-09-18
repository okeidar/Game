# Phase 0A design notes - feather greybox

Status: built, tested, deployed (agent-built; Omer has not playtested yet).
Build: Godot 4.7.2, GDScript, text-first, headless CI. No art, all signal.

## Creative direction absorbed (Omer, 2026-09-18)

- Dark and gloomy tone, even at greybox: dusk arena, fog, cold moonlight,
  desaturated palette, pale ink HUD.
- Signature mechanic: Erthis, the winged protagonist, collects feathers. One resource,
  two uses: feathers held are armor (damage resistance, later defensive
  abilities); feathers spent are ammunition (volleys). Spending protection for
  offense is the risk economy in one resource.
- Generalized doctrine (Omer, same conversation): the decision system always
  works through tradeoffs. Every strong option carries a cost. Feathers are the
  flagship instance, not the only one.
- Canon now exists (Omer, 2026-09-18): the protagonist is Erthis and the
  feather mechanic is canon.
- STANDING RULE (Omer, 2026-09-18, verbatim): "feathers are scarce. dont
  invent stuff. ask me first." Never invent reward, economy, or design
  numbers. Propose, get his word, then build. (First applied: the +2-feather
  perfect-dodge payoff was removed the same day it shipped.)
- Perfect dodge reward: OPEN ITEM, deferred by Omer 2026-09-18 ("just make a
  perfect dodge. we will think about the reward later"). HARD RULE: canon story text lives only in the
  private Callosum mind - names appear in this repo, story never does.
  The arena ("the greyfield") and the enemy ("the effigy") remain
  placeholders with hooks, not fiction.

## The tradeoff doctrine as implemented in 0A

Every verb in the combat core has a cost line:

| Option | Gain | Cost |
| --- | --- | --- |
| Dodge roll | i-frames (0.43s) + reposition | 16 stamina, committed direction |
| Light attack | 20 dmg, quick | 20 stamina, locked in for 0.84s |
| Heavy attack | 32 dmg, hard stagger | 27 stamina, 0.5s exposed windup, 1.28s total |
| Sprint | 1.6x speed | drains the stamina you need to dodge (14/s) |
| Feather volley | ranged 3x8 dmg | 6 feathers = 10 points of resistance lost |
| Full feather coat | up to 50% damage resist | temptation: every volley strips it |
| Lock-on | camera + aim tracking | narrower awareness, breaks at range/death |
| Block (hold RMB) | 70% damage cut, 360 coverage | chips 30% through, drains stamina per hit (0.9x dmg), half movement, stamina regen choked to 20% while held |
| Parry (block pressed <=0.13s before impact) | full deflect, attacker reels 1.4s | the tight window itself; misjudge and you eat the blow you tried to read |
| Perfect dodge (hit connects <=0.15s after roll start) | nothing yet - it is a pure timing mechanic; reward deferred to Omer | holding the roll to the last instant is its own risk; payout TBD |
| Guard break (stamina hits 0 while blocking) | - | the blocked hit lands FULL + 1.0s reel: turtling is a loan, not a wall |

Design rule for everything after 0A (cards, systems, items, routes): each
option must name its cost in the same breath as its power. No free lunches,
no pure upgrades. Numbers live in `src/combat/tuning.gd`, one file, diffable.

## Feather economy (0A numbers)

- Coat size: 30 max. NO timer regrowth (Omer directive 2026-09-18, verbatim:
  "feathers are replenished by collection, not over time"). The only ways back
  to a full coat are pickups and kills - collection is the sole recovery verb,
  so every feather spent is a real decision.
- Resistance: linear, 0% at empty to 50% at full coat.
- Volley: 6 feathers, three projectiles, 8 damage each, 0.35s rooted cast.
  Denied below 6.
- Sources: 5 scattered pickups (+6 each, respawn 12s) and a felled effigy (+6).
- The coat is visible: one pale mote per 5 feathers orbits Erthis.

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
- Movement is camera-relative (Omer playtest fix 2026-09-18): WASD resolves
  against camera yaw, the genre standard he expects.
- Defense verbs (Omer playtest directive 2026-09-18, reference: Mortal Shell 2):
  block (hold RMB), parry (block pressed inside a 0.13s window before impact),
  perfect dodge (hit connects within 0.15s of roll start, pays +2 feathers).
  Guard break when stamina empties mid-block. Roll cancels out of block.
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

- Erthis: protagonist, canon. Everything about who he is and why the coat
  works this way lives in the Callosum mind, not in this repo.
- Uldor: canon character, guide-shaped. Hook for later phases; story in the mind.
- Ashitori: canon character, boss-shaped. Hook for a later boss phase;
  story in the mind.
- Kelden'gon: canon character, king-shaped. Hook for a later
  region/arc; story in the mind.
- The effigy: a training thing in a greyfield. What it is a rehearsal for: open.
- The arena: a walled yard at dusk. Where it is, whose it is: open.
- Defensive abilities at high coat (mentioned by Omer): not in 0A; the
  resistance curve is the hook.

## Test hall layout (Omer directive 2026-09-18)

The greyfield is now a test hall: one room per mechanic, in a row, so each
verb is isolable for playtesting. "Make the test room more testable.
Multiple areas. Most with dummies that dont strike back. Only one with real
enemy. A room to test every unique mechanic."

- MOVE: open floor + pillars. Movement, camera-relative WASD, sprint, roll
  feel, lock-on against nothing.
- STRIKE: two training dummies (never strike back). Light/heavy commitment,
  hitstop, stagger-out-of-swing, kill drops.
- VOLLEY: three training dummies at range + three feather pickups. Volley
  cost/spread/commit and the collection loop.
- DEFEND: the ONLY real enemy (approaches, telegraphs, swings) + two pickups.
  I-frames, block, parry, guard break, perfect dodge, death/respawn.

Room names float in pale ink at each room; the HUD shows the current room.
Dummies vs real enemy is one flag (ai_enabled), covered by a deterministic
test: a dummy never swings in 400 frames in range; the real one engages.

## Mortal Shell 2 - what I took (Omer named it as the defense reference)

Researched via 2026 reviews and mechanic guides (gamerant, neonsect, finalboss,
screenrant). MS2's defense shape:
- No stamina at all; Resolve fills from aggression and pays for specials.
- Seals make Guard / Parry / Harden MUTUALLY EXCLUSIVE - one defensive style
  equipped at a time; the choice of seal shapes a fight more than the weapon.
- Guard nullifies but has its own break meter; guard break = vulnerable stagger.
- Perfect Guard / Perfect Harden (tight-timed) refund or pay Break damage.
- Parry is the high-risk, high-reward read: biggest Break payout (~3x a perfect
  guard), worst whiff.
- Full Break meter opens the enemy to a Riposte.

What 0A takes from it:
1. Defense as a CHOICE with a price, never a default (MS2 seal exclusivity is
   the doctrine applied to defense; ours runs block/parry/dodge side by side
   for now, each with its own cost line - exclusivity is a future loadout hook).
2. Tight-timed variants of defensive verbs pay out (our parry reel and
   perfect-dodge feathers are MS2's perfect-guard/perfect-harden pattern).
3. A punished guard (our stamina guard break) keeps turtling honest, like
   MS2's guard meter.
4. NOT taken: no-stamina Resolve (we keep stamina - Omer's feather economy
   needs a second resource to trade against), and the Riposte meter stays a
   future hook (parry already opens a punish window).

## What I cannot judge without Omer

- Feel: roll length, i-frame window, hitstop weight, attack cadence.
- Timing readability: is 0.85s windup fair in the hand, not just in the test.
- Difficulty: effigy damage/hp/aggression vs. the coat economy.
- Whether the tradeoff doctrine reads in play the way he means it.
- Camera feel: sensitivity, lock-on ease, distance.
