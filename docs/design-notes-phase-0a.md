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

---

## Machinery pass (2026-09-19): six systems built with details OPEN

Directive from Omer: "lets do everything that is not detailed but machinary …
just have the thing ready for when we decide the details." Every system below
is real machinery with its undecided parts named as scaffolds. None of the
numbers below are design; they exist so the machine runs and can be felt in
the playtest. Standing rule holds: Omer decides the real values.

### 1. Checkpoints - built, rest effect OPEN
- A checkpoint entity exists (pale obelisk, MOVE room beside the slab).
  Walk up + E registers it (brightens, logged) and calls "rest".
- Rest currently does NOTHING but acknowledge itself.
- OPEN DECISIONS: what rest restores (hp? heal charges? feathers?), does it
  respawn/reset enemies, is it the progression/level-up site, respawn point
  rules, one-shot vs reusable registration.

### 2. Basic heal - works, numbers OPEN
- Q: rooted commit (0.9s scaffold), then heals. Heal is interruptible by
  stagger (commit risk). HUD shows remaining charges.
- Scaffold values, NOT design: 3 charges, +40 hp per charge.
- Tradeoff shape already in the machinery: the commit roots you, a stagger
  wastes the cast, charges are finite.
- OPEN DECISIONS: charge count, heal amount, refill source (checkpoint?
  collection? kills? none?), cast time, can you move/cancel, does it cost
  stamina or feathers.

### 3. Death penalty - records + remnant, payload OPEN
- On death a remnant mote is left at the death spot; walking over it recovers
  it. The record (position + contents container) exists.
- The payload is EMPTY: nothing is deducted, nothing is restored.
- OPEN DECISIONS: what drops (feathers? essence? a fraction?), one remnant at
  a time or many, does dying again destroy the old remnant, recovery radius,
  can enemies interact with it.

### 4. Progression - spend/convert/upgrade hooks, catalog OPEN
- spend(cost, player) machinery works (checks affordability, deducts,
  refuses when short - tested). convert_feathers_to_essence exists at a
  SCAFFOLD 1:1 rate. apply_upgrade(id) hook records applications.
- OPEN DECISIONS: the whole economy. Costs, conversion rate (if conversion
  exists at all), what essence is for, the upgrade catalog and its tradeoffs,
  where spending happens (checkpoint UI?).

### 5. Riposte - crit window works, conditions/values OPEN
- A crit window opens on the enemy when its attack is parried (reel) and,
  as scaffolding, when you strike from its rear arc (60 deg half-angle).
  Hits inside the window crit and are logged as RIPOSTE.
- Scaffold values: 1.2s window, x2.0 damage, 60 deg backstab arc.
- OPEN DECISIONS: the multiplier, whether backstab crits at all (and its
  arc), window length, does a riposte cost stamina, can it be a distinct
  animation/verb instead of a normal attack, does guard-break also open it.

### 6. Enemy attack patterns - chain + flags machinery, patterns OPEN
- Effigy attacks can now be chained (data-driven links with per-link delay)
  and carry flags; "unblockable" is the first flag: it telegraphs RED from
  windup start (normal attacks glow sickly yellow) and pierces block/parry.
  Tests force specific attacks; live behavior unchanged (single club swing,
  empty chain table).
- OPEN DECISIONS: the actual chain patterns, which attacks are unblockable,
  delay windows between links, does the player get a punish window after a
  chain, per-enemy movesets.

### Deliberately NOT done (kept stable for the current playtest)
- Death deducts nothing (payload empty until Omer decides).
- Effigy keeps its single club swing; chains exist but are unused in play.
- No progression UI: hooks are code-level until the economy is decided.
- Perfect dodge still pays nothing (Omer: "we will think about the reward later").

### New test coverage (16/16 green)
heal commit + charge denial, checkpoint register + rest stub, remnant drop +
recovery, parry-window riposte crit, unblockable through block, two-link
chain, progression spend/deny/convert/upgrade. Legacy scenarios updated so
their effigies face the player (backstab machinery made their old arbitrary
facing meaningful).

---

## Machinery pass 2 (2026-09-19): player-side sneak/sound, statuses, consumables, movesets, jump

Directives from Omer: "Sneak - lets take player side now. Means a slow walk. It means
we also nees to emit sound. Build scaffolding fir status effects and consumables" and
"And combos, jump and the rest you mentioned. No equip load, poise, charged heavies,
weapon art, and guard counters". Machinery only; every number below is SCAFFOLD.

### EXPLICITLY EXCLUDED BY OMER - do not build, do not propose again
equip load - poise / hyperarmor - charged heavies - weapon arts - guard counters.

### 7. Sneak + sound (player side only)
- CTRL = sneak walk (slow). Movement emits SOUND events: a footstep per 2m of
  travel, each with a radius/loudness property. Sneak quietest, walk medium,
  sprint loud, roll emits one on start. HUD shows SNEAK while active.
- Scaffold: sneak speed x0.45; radii sneak 2.5 / walk 6.0 / sprint 10.0 / roll 8.0.
- Enemy hearing/awareness is the DEFERRED enemy side: nothing consumes sound yet.
- OPEN: sneak speed multiplier, sound radii, what else emits sound (attacks?
  landing from a jump? item use?), whether sound is how enemies notice you at all.

### 8. Status effects scaffolding
- Every combatant (player AND enemies) has a status system: statuses can be
  registered with threshold/duration/tick interval; build-up accumulates,
  crossing the threshold triggers, active statuses tick on an interval, then
  expire; untriggered build-up decays. Effect hooks (on_tick callables) exist.
- No status designs exist: the catalog (bleed/poison/frost/...), build-up
  rates, effects, and resistances are all OPEN for Omer.

### 9. Consumables scaffolding
- Inventory machinery: slots with quantities, add/stack, use with a rooted
  commit (key 1, slot 0), effect application hook per item def, empty-slot
  denial. Commit is interruptible by stagger (tradeoff shape preserved).
- Scaffold: 0.8s use commit. No item designs: catalog, quantities, and where
  items come from are all OPEN.

### 10. Moveset machinery (combos)
- Per-weapon moveset TABLES: light chain (ordered links), heavy, running
  attack, rolling attack, jump attack slots. Player attack selection reads the
  table: light presses advance the chain inside a window, sprint-attack uses
  the running slot, post-roll attack uses the rolling slot, airborne attack
  uses the jump slot. One scaffold moveset exists; every slot reuses the
  current proven attack data, so playtest behavior is unchanged.
- Scaffold: chain window 0.8s, roll-attack window 0.4s.
- OPEN: the weapon catalog, chains per weapon, all frame data, whether
  running/rolling/jump attacks get distinct properties.

### 11. Jump
- V = jump (key binding itself is provisional scaffolding). Jump-attack hook
  exists (airborne attack uses the jump slot). Gravity now preserves upward
  velocity so a jump survives its first frame.
- Scaffold: jump velocity 5.0 (gravity 18). OPEN: height/feel, air control
  (currently full), jump-attack properties, does jumping cost stamina.

### New test coverage (18/18 green)
sneak speed + quiet/medium/loud/roll sound events; status build-up, trigger,
tick, expiry, decay; consumable commit, effect hook, quantity tracking,
empty-slot denial; light-chain advance + window reset; running and rolling
slots; jump leaves floor, lands, jump-attack slot while airborne.

---

## Machinery pass 3 (2026-09-19): enemy awareness, enemy ranged, respawn linkage, fall damage

Built under Omer's standing directive: "Keep working on the game until everything
is scaffolded properly. Then we will start breaking down the details."

### 12. Enemy awareness (the deferred enemy side of sneak)
- Every ai-enabled enemy runs an awareness state machine: calm -> suspicious ->
  alert, and back down. Vision: cone check (range x half-angle), halved range
  against a sneaking player (sneak is now a held state, not motion-gated).
  Hearing: consumes the movement sound bus; each heard sound is a suspicion
  pulse. Being struck alerts instantly (provoked). The effigy only engages
  when alert; losing the trail de-escalates.
- Scaffold: vision 12m / 65 deg half-angle / sneak x0.5, suspicion 0.9s to
  alert by sight, hearing pulse 0.4 per sound, alert memory 3.0s.
- OPEN: all detection numbers, LOS occlusion (none yet), alert propagation
  between enemies, what suspicious DOES (investigate the sound spot?),
  whether alert ever fully resets.

### 13. Enemy ranged machinery
- Any enemy attack entry may carry a "projectile" table (speed/damage/life):
  the swing instead fires a projectile at the player (reuses the volley
  projectile, parametrized shooter/target/log). Live effigy unchanged.
- OPEN: which enemies get ranged attacks, projectile properties, can
  projectiles be blocked/parried/dodged distinctively.

### 14. Checkpoint respawn linkage
- Death now respawns the player at the registered checkpoint (falls back to
  the original spawn when none). Rest effects remain open.
- OPEN: does respawn reset enemies (they currently respawn on their own
  timer), does it refill heal charges (it does today via reset_run - flagged
  as scaffold until rest rules are decided).

### 15. Fall damage machinery
- Landing faster than a safe speed deals scaled damage. Roll unchanged.
- Scaffold: safe 12 m/s, 5 damage per m/s over. OPEN: thresholds, lethal
  falls, landing stagger.

### New test coverage (19/19 green)
sneak invisibility in the cone, vision alert, hearing alert from behind,
enemy projectile flight + hit, checkpoint respawn resolution + fallback,
safe fall vs damaging fall.

---

## Machinery pass 4 (2026-09-19): the game shell layer

Omer caught the gap: "nothing? what about menu, inventory, stats, etc?"
The earlier scaffold-complete claim covered combat/core-loop only. This pass
scaffolds the shell. All UI is text-only machinery: layout, art, wording,
and bindings are OPEN (bindings provisional: ESC pause, I items, O equip).

### 16. Title + pause menus
- Menu machinery: state machine (title/pause/death/inventory/equipment),
  cursor nav with wrap, activate hooks. Boot lands on title (BEGIN enters,
  QUIT is a hook). Pause = RESUME / QUIT-TO-TITLE hook. Tree pauses under menus.

### 17. Inventory UI
- Lists consumable slots with quantities, use-through-UI routes into the
  existing commit machinery. Slot routing (which slot gets used) is scaffold.

### 18. Stats/attributes
- Attribute table on the player (enemies share the combatant base, so the
  same system attaches): register/raise/read + derived-value scaling hooks.
  recalculate_derived() applies registered scalings; with none registered
  everything falls back to current values. ZERO stats designed: catalog,
  starting values, curves are all Omer's.

### 19. Equipment screen
- Equipment slots (weapon) hold moveset tables; equip swaps the live moveset
  (chain state resets). UI lists the slot, swap machinery proven with a
  3-link test moveset. Slot rules/catalog OPEN.

### 20. Save/load
- Capture/restore: position, hp/stamina/feathers, heal charges, attributes,
  inventory, checkpoint, deaths. JSON file (user://) + dict API. Format,
  scope, slot rules OPEN. Checkpoint node relink on load is world-side (open).

### 21. Death screen
- YOU DIED state screen; RISE confirms respawn at the registered checkpoint
  (replaces the old 2.5s auto-respawn). Art/wording OPEN.

### New test coverage (20/20 green)
attribute scaling feed + fallback, attribute raise; moveset swap drives a
3-link chain; save/load round-trip of every captured field; menu nav/wrap/
activate, inventory UI use, death screen banner + respawn hook, title BEGIN.

---

## WHAT'S MISSING (living list - updated each round)

Layered souls-like completeness. [scaffolded] = machinery exists, details open.
[proposal] = gap I hunted up, NOT approved, never built without Omer's word.

### Combat core - SCAFFOLDED
movement (walk/sprint/roll/perfect dodge/sneak/jump), camera+lock-on, light/
heavy/volley, movesets+combos, block/parry/guard-break, riposte, stamina,
feathers economy hooks, statuses, consumables, heal, fall damage.

### Enemy machinery - SCAFFOLDED
attack chains + flags (unblockable), awareness (vision/hearing/alert), ranged
projectiles, stagger, training-dummy vs real-enemy modes, respawn.

### World/loop - SCAFFOLDED
checkpoints + rest stub, death remnant, respawn linkage, test hall.

### Shell - SCAFFOLDED (this round)
title/pause/death menus, inventory UI, attributes, equipment screen, save/load.

### Missing - proposals awaiting Omer's word (DO NOT BUILD):
1. Settings menu machinery (volume/FOV/remap hooks) - shell layer.
2. Audio hooks (SFX/music event bus; the sound system is gameplay-only today).
3. NPC + dialogue machinery (talk verb, dialogue trees as data).
4. Map machinery (world map/region graph; not minimap art).
5. Boss machinery (phases, health-bar presentation, arena triggers) - combat.
6. Tutorial/teaching hooks (contextual hints; the hall is informal today).
7. Multi-enemy encounter machinery (aggro linking between enemies - noted in
   awareness open decisions).
8. Message/notification feed UI (event toasts: item gained, status applied).
9. Gestures/photo-mode style extras - low priority, listed for completeness.
10. New Game+ machinery (cycle counter, difficulty scaling hook) - meta.

## Round 5 (scaffolds round, 2026-09-18)
Shipped: ALL TEN what's-missing scaffolds.
- **Settings menu**: setting registry (setting.gd + Settings.gd autoload, lookup/default/reset/set with subscribers). Shell "settings" kind from pause. SCAFFOLD entries: master_volume (-60..+24 dB, applied to Master bus when audio lands) and camera_fov (applied live). Real game entries later.
- **Audio hooks**: AudioBus autoload, sfx(name, pos) / music(name) with registered-stream lookup; call sites at parry/riposte/stagger/wound/item/checkpoint-fire/respawn + music stubs at title/gameover. Every name a placeholder.
- **NPC + dialogue**: dialogue.gd data-tree engine (tree.json: nodes/choices/next/once/on_choose), npc.gd interactables with talk() and spoke signals; player routes npc_spoke through Sim. One SCAFFOLD npc ("SHELL KEEPER", ETERNAL WITNESS) in the MOVE room with the two-line tree from the proposal. shell dialogue kind renders the tree + numbered choices.
- **Map**: map_data.gd registry (rooms + one-way links), game builds it from arena.ROOMS on boot, discovery flags, shell "map" kind (M) lists discovered/undiscovered rooms.
- **Boss machinery**: boss_data on combatants (display_name/phases); hp-threshold phase transitions swap movesets + armor, phase announcements via toast; exposes immunities/stagger_mult for tuning (SCAFFOLD fields, unwired). apply_effigy_stats marks the two big effigies as two-phase SCAFFOLD bosses.
- **Tutorial hooks**: tutorial.gd autoload, once-only flagged rules with conditions + cooldowns; game._check_tutorial scans each tick. One SCAFFOLD rule: low-stamina hint. Tutorial messaging must never break flow — for Omer to define the copy and triggers.
- **Multi-enemy aggro linking**: Sim.alert_pulses + awareness watermark + ALERT_LINK_RADIUS_SCAFFOLD (8.0m): one alerted enemy alerts same-type friends in radius. Radius/typing open for tuning.
- **Message/toast feed**: Sim.toasts ring buffer + HUD toast label + Sim.toast() convenience. Machinery reports through it.
- **NG+**: ngplus.gd (NGPlus autoload): begin_next_cycle bumps cycle, ngplus_hp_scale/... scaffolding formulas + apply_enemy_stats hook; game._build applies hp scaling to effigies. Which endings trigger NG+, which enemies scale, and what carries over are open design.
- **Gestures**: gestures.gd (Gestures autoload) registry, shell "gestures" kind (G) listing + performing SCAFFOLD gestures; perform() emits gesture_performed for future animation machinery.
- Tests: 22 scenarios (was 21) — ScenarioRound5A (toasts/settings/audio-hooks/NG+/gestures) + ScenarioRound5B (map/dialogue/tutorial/aggro-link/boss). 22/22 green.

### What's-missing list — the ten marked scaffolded
- ~~audio hooks~~ [scaffolded], ~~boss machinery~~ [scaffolded], ~~tutorial hooks~~ [scaffolded], ~~multi-enemy aggro linking~~ [scaffolded], ~~message/toast feed~~ [scaffolded], ~~NG+ machinery~~ [scaffolded], ~~gestures~~ [scaffolded], ~~settings menu~~ [scaffolded], ~~NPC + dialogue~~ [scaffolded], ~~map~~ [scaffolded].
### Scope ruling (Omer, 2026-09-19 ~00:05): critical path only, no feature creep
Verbatim: "no focus on the critical path. not feature creeping. ng+, actual bosses, copiues, co-op, bestiary, tod, are too much"
**CUT (rejected by Omer, removed from candidates, never to be re-proposed):**
- NG+ design (the round-5 ngplus.gd machinery stays as shipped scaffold; no further design work)
- Actual boss design/content (machinery stays; no content)
- Co-op / phantom machinery
- Bestiary / enemy codex
- Weather / time-of-day machinery
- "Copiues" (his word; read as copies/duplicated content) — cut with the rest

### Remaining proposals (unapproved, unbuilt, critical-path candidates only)
- **Fast travel between checkpoints** — machinery hook exists (respawn + fire); needs a travel choice at the fire. Design first.
- **Item durability** — Elden Ring lacks it; do we? Proposed, not built.
- **Real audio streams** — hook names are placeholders; actual sound selection is an art call.
- **Tutorial copy + trigger set** — machinery takes rules; writing them is design.
- **Map visual layout** — discovery list is text; a visual map layout is an art/UI call.

### Critical path (per main's read-back, Omer to correct if wrong)
The core loop's detail decisions: heal, death penalty, progression, checkpoint behavior, enemy patterns, movesets. New scaffolding is on hold until his detail-breakdown begins.

## Playtest fix (2026-09-19): sprint was slow in live play
Omer: "I played. you said shift to sprint but it is actually slow. it means your tests are not good enough"
Root cause: machinery pass 2 (sneak round, 3a93dd5) bound sneak to SHIFT (4194325), the same key as sprint. Held SHIFT engaged sneak, and the sprint gate (`inp.sprint and not sneaking`) never opened. SHIFT gave 45% walk speed. HUD always said "CTRL sneak" - the binding never matched the label.
Fix: sneak rebound to CTRL (4194326) in project.godot.
Test gap (his meta-point, correct): every prior test asserted STATE (sprinting flag, speeds table), never OUTCOME (real displacement over frames), and nothing checked that two movement gaits don't share a physical key. Added ScenarioSprintOutcome: measures REAL velocity over 60-frame windows (sprint 7.40 m/s vs walk 4.60 vs sneak 2.07) and asserts sprint/sneak bindings never overlap + sprint=SHIFT + sneak=CTRL. Live-verified in headless Chrome via real key events + POS telemetry: per-sample sprint/walk ratio 1.61, exactly SPRINT_SPEED/WALK_SPEED.
Also added: web debug hook `?debugpos=1` prints player position every 0.5s for live measurement (game.gd, web-only).

## Overnight iteration 1 (2026-09-19, ~02:15): measurement infrastructure + baseline
Omer's mandate: "It still doesnt feel like a game... continue untill i wake up with multiple iterations... always test and assess - both with stats and playtests... Record everything to a log and then analyze it. Compare to other games (as a reference)... create a controller or an automation... simulate input so you can 'virtually play' the game. Record it and review the footage."
Built first because every later iteration is judged by it:
- **Structured stats feed**: Sim.stat(kind, fields) prints STAT <json> to console (harvested live) and keeps a test-visible copy. Events: attack(slot/dmg/windup), hit(target/dmg/crit/slot), whiff(slot), player_hurt(dmg/hp), block, parry, roll, heal(charges_left), death, respawn.
- **Live telemetry**: ?debugpos=1 now prints POS (pos+hp+stamina) and EPOS (per-enemy pos/hp/dead) every 0.5s, web only.
- **Playtest bot** (verify/playtest.js): real keyboard/mouse input via headless Chrome; steers to nearest living effigy by telemetry (8-way), sprints past 5m, attacks in range with chain presses, rolls on telegraph console lines, heals under 40 hp. Captures console + screenshot frames; assembles film.mp4 + montage.png for footage review; writes run.log + stats.json.
- **Analyzer** (verify/analyze.py): duration, attacks/hits/whiffs/hit-rate, dmg dealt/taken, dps, deaths, rolls, slot mix, time-to-first-hit.
Overnight-design-choice log begins next iteration (weapons/combos). All overnight choices are marked [overnight proposal - awaiting Omer review].

## Overnight iteration 2 (2026-09-19, ~02:50): real weapon catalog + combo chains
Omer's named gap: "No real combos and weapon changes."
ALL CHOICES BELOW ARE [overnight proposals - awaiting Omer review]. Genre reference points used as calibration only (DS3-class light swing ~0.9s total, heavy ~1.3s), not duplicated.

### The roster (machinery: moveset tables + equipment swap, both pre-existing)
- **BLADE** (id blade) - the standard; the ruler others are measured against. 2-hit light chain 20/22, heavy 32. No strengths, no weaknesses. cost_mult 1.0.
- **TWIN FANGS** (id fangs) - speed. 4-hit light chain 9/9/11/15 (44 total), windups .14-.22s, cheapest stamina (cost_mult 0.6). COST: reach 1.8 (must hug), stagger ~0.15 (cannot interrupt an enemy swing - every approach is dodge-dependent). Pays for safety with reach, for speed with stagger.
- **MAUL** (id maul) - commitment. 2-hit light chain 34/42, heavy 55, stagger 1.3-2.2 (breaks enemy swings). COST: windup .52-.75s exposed and interruptible, cost_mult 1.7, long recovery - a whiffed maul is a free hit for the enemy. Pays for power with exposure.
- Weapon switching: equipment menu (O) now lists the catalog with live-equip markers, swap resets the chain; HUD shows the current weapon name; equip/attack stats carry weapon id. Greybox acquisition: all three carried from start (loot/acquisition design stays Omer's).

### Frame-data verification (ScenarioWeapons, real outcomes)
Fangs chain = exactly 44 dmg over 4 hits, first hit lands ~+10 frames; maul first hit lands ~+31 frames for 34 (no hit before - the commitment is measurable); blade light 20; equip swap live-resets the chain.

### Two real bugs the stats/telemetry work surfaced this iteration
1. **Stamina goes negative** (telemetry showed st=-19): _spend_stamina never clamps, gates only check <= 0 - hidden stamina debt. Souls clamps at 0. NOT YET FIXED - candidate for iteration 4 (feel/pacing) or Omer's call since it changes punishment feel.
2. **Spawn-drop jump-attack trap**: player spawns 0.1m airborne; an attack in the first ~10 frames silently becomes a jump attack. Old tests masked it (scaffold jump = light data). Tests now attack grounded. Design question for Omer: should a 5cm drop really change your move?
### Test fragility lesson (for the record)
Frame-exact assertions ("swing completes by f=100") break when content timings change by design. New tests assert outcome windows, and the spawn-drop trap is now documented in the affected scenarios.

## Overnight iteration 3 (2026-09-19, ~03:25): shell presentation pass
Omer's named gap: "The menues and inventory feels bad."
[overnight proposals - awaiting Omer review] Presentation only - menu machinery (items, actions, nav) untouched.
- Full-screen dimmer behind every menu (62% dark), deeper (85%) under death.
- Panel with border + padding that menus live in (was: bare text floating over the world).
- Selection is a highlighted row (bg band + white text + > cursor), not just a caret.
- Per-kind structure: header + quiet subtitle line + footer key hints. Title screen gets the game name big with a greybox tag. Death is a full-screen takeover: big red YOU DIED + centered respawn option (genre's most important screen).
- Equipment rows now carry decision-relevant stats: "fangs - 4-hit chain 44 dmg - reach 1.8 - stamina x0.6" so a weapon swap is an informed tradeoff choice (his doctrine) instead of a name list.
- Subtitle tone lines are placeholder flavor, all replaceable ("the world waits" etc).

## Iteration 4 - game-feel juice + genre benchmark (overnight)

Reference frame: Dark Souls 3 mechanics cheat sheet (gastevens/dark-souls-3-mechanics-cheat-sheet) + tuning ledger at /tmp/deep-research/soulslike-tuning/. We are not duplicating a game; these numbers are calibration anchors.

1. BUG FIX (not a proposal): stamina spend never clamped. Sprint-attack chains drove stamina to -19 (telemetry, iteration 1), which is hidden regen debt the player cannot see. `_spend_stamina` now clamps at 0, matching genre behavior (DS3 pool bottoms out at 0). New scenario `stamina_clamp` asserts roll-from-5 lands exactly 0 and regen recovers from a clamped zero.
2. [overnight proposal - awaiting Omer review] Hitstop dealt 50ms -> 80ms (taken stays 90ms). Action-game standard band is 50-150ms; at 50ms our landed hits were barely readable. Tradeoff: more hitstop slows chained offense slightly - the cost of punchier feedback is a hair less flow.
3. [overnight proposal - awaiting Omer review] Death-screen delay 1.4s (new tuning const DEATH_SCREEN_DELAY). Previously YOU DIED took over the screen the same frame the blow landed; genre shape is a beat of world first (DS3 ~1.2s fade). Tradeoff: 1.4s of dead time per death vs. the death actually reading as an event.
4. [overnight proposal - awaiting Omer review] Training effigy damage 25 -> 15. At 25 vs 100hp the FIRST enemy killed in 4 clean hits; genre tutorial enemies take ~10-15% of a bar per hit (now 15%). Tradeoff: gentler onboarding vs. less early menace. All hurt/block/parry test expectations updated (they are derived from tuning).
5. Roll i-frames already render as a ghost tuck (alpha 0.45 inside the window) - verified in code; no change needed.

Open (his call, flagged again): spawn-drop jump-attack quirk (attack within the first ~10 frames after landing silently becomes a jump attack). Bot-level death-respawn verification happens live this round.

## Iteration 5 - combos and weapon changes in motion (overnight)

Omer's named gap: "No real combos and weapon changes."

1. [overnight proposal - awaiting Omer review] CHAIN CANCEL WINDOW (CHAIN_CANCEL_POINT_SCAFFOLD = 0.6). Before: the next chain hit could only start after the FULL recovery of the previous swing - chains felt like separate swings with a pause, which is exactly the "no real combos" complaint. Now a pressed or buffered attack during the last 40% of recovery fires immediately, so a chain flows (blade hit gap 840ms -> ~670ms, asserted in the combo_cancel scenario). Tradeoff per the doctrine: the first 60% of recovery is still committed (whiff punishment lives there), and canceling into the next swing spends its stamina and locks you in again - speed bought with commitment, not free.
2. [overnight proposal - awaiting Omer review] DODGE CANCEL at the same point: a buffered roll fires out of late recovery. This is the genre's core rhythm (swing -> roll out) and was impossible before without waiting out the full recovery. Cost: the roll's 16 stamina, and the first 60% of recovery is still uncancellable.
3. Enemy hit-flash and roll i-frame ghosting already existed (checked, no change). Weapon-swap stays menu-only (it resets the chain, which is the real cost); no swap animation - that is scope creep for a greybox.

Stat nuance noted: a canceled whiff does not emit a whiff stat (the swing never reaches "done"); hit/whiff rates now slightly overstate accuracy. Acceptable for greybox analytics.

Still his call: spawn-drop jump-attack quirk (flagged iterations 2 and 4).

## Iteration 6 - enemy-side feel and camera readability (overnight)

Audit result: the effigy was already well-built (yellow->red telegraph with emission, club raise/fall pose mirroring the attack clock, early-track-late-commit aiming, punishable recovery, keel-over death, any-hit staggers it out of windup). The real readability gaps were camera-side:

1. [overnight proposal - awaiting Omer review] Close-camera body fade. Playtest footage showed the player's own pale capsule filling half the screen whenever a wall pushed the camera in (the sphere-cast pulls to 0.8m, inside the body's silhouette). Genre standard: fade the character. Now below 1.6m camera distance the body renders at 25% alpha; roll ghosting stacks under it. Cost: at point-blank camera the player is a ghost - readability of the WORLD beats readability of the body in that moment.
2. [overnight proposal - awaiting Omer review] Lock-on marker: a small gold unshaded spark floats over the locked enemy with a gentle bob. Before, lock-on had no world-space indicator - only the HUD bar changed. Cost: one more moving light-element on screen; genre-standard.

Not done (scope): camera collision overhaul (the sphere-cast works; only the close-up readability was broken), effigy attack variety (content design is Omer's - the attack_chain machinery already supports follow-ups), multi-enemy separation (only one live enemy in 0A; physics bodies already push apart).

Verification note: both changes are presentation-layer; the harness does not drive game.gd/camera rig, so they are verified by playtest footage this round, with the 26-scenario suite confirming no regressions.

## Iteration 7 - HUD combat feedback (overnight)

The HUD had the right data but no FEEL: bars snapped instantly and nothing warned you before a denial.

1. [overnight proposal - awaiting Omer review] Damage trails (both directions). Player hp and the effigy bar now carry a pale "ghost" segment behind the real fill: on damage the ghost lingers where the bar was and drains down (25/s player, 20/s enemy); on heal it snaps up. This is the genre's single strongest damage-readability device - a hit has visible WEIGHT because you watch what you lost drain away. Cost: one extra bar element each; none in gameplay terms.
2. [overnight proposal - awaiting Omer review] Low-stamina warning: below roll cost (16) the stamina bar pulses hot. Before, the first sign of an empty pool was a denied roll - a silent failure at the worst moment. Cost: a pulsing element in the peripheral UI; genre-consistent (DS3 flashes the bar on deny).
3. [overnight proposal - awaiting Omer review] Heal charges are pips (3 gold squares, filled/dim), not "heal x3" text - readable at a glance mid-fight.

Verification: new ?hudcheck=1 debug hook (applies a 35-dmg hit, drops stamina to 10, damages the effigy) so the feedback can be screenshot-verified headlessly. No damage numbers - genre doesn't float them; skipped deliberately.

## Iteration 8 - checkpoint rest becomes real (overnight)

Critical path items: progression + checkpoint behavior. The rest stub is gone; the checkpoint now opens a menu.

1. [overnight proposal - awaiting Omer review] REST: closes wounds (hp to max), refills stamina and heal charges, and THE FALLEN RISE AGAIN - every felled effigy respawns at its post. The genre loop: comfort is real, and its price is that the world resets. The training effigy's own auto-respawn timer is untouched (load-bearing for a training room; rest-triggered respawn now ALSO exists).
2. [overnight proposal - awaiting Omer review] First feather spends, riding the Progression machinery: HARDEN (+10 max hp, 20 feathers) and MEND (+1 heal charge capacity, 30 feathers). PRICES ARE SCAFFOLD PLACEHOLDERS awaiting his economy. The tradeoff is built into the currency itself: feathers spent on power are feathers not worn as coat/resist - spending is a real decision, not a free upgrade.
3. Interact (E) at the checkpoint now opens this menu (registers first, as before). The death remnant is untouched by rest - what you dropped still waits where you fell.
4. HUD shows the results immediately: heal pips refill, hp bar ghost snaps up, feather count drops on a buy.

Tests: checkpoint_rest scenario (menu rows, rest refill + respawn-at-post, exact spend amounts, denial when poor); machinery_scaffolds run 1 updated (no more stub event; menu wiring covered by the new scenario).

## Iteration 9 - enemy patterns: the effigy learns a rhythm (2026-09-19, overnight)

Omer's critical path names "enemy patterns" explicitly. The training effigy had
exactly one attack repeated forever - a punching bag, not an opponent.

[overnight proposal - awaiting Omer review] The effigy now runs a deterministic
pattern cycle (no RNG anywhere in the sim): swings 1 and 2 are the honest club
swing, every 3rd swing chains a faster, weaker follow-up (10 dmg, 0.5s windup,
0.25s link delay) riding the existing attack_chain machinery. Tradeoff doctrine
holds on the ENEMY side too: the follow-up pays for its speed with lower damage,
and after the double the effigy rests 1.6s instead of 0.9s - pressure costs it
its punish window. Telegraph honesty: the follow-up runs the same yellow->red
color cycle and club animation, no hidden armor, still staggerable out of
windup, still parryable (a deflect clears the whole chain).

World reset on death (genre law) was already wired in game.gd _respawn, but
reset_run had gaps: it now also clears attack_chain, chain_delay_t, the pattern
counter, and awareness (suspicion 0, calm) - before, a killed-then-risen or
reset effigy could keep a pending chain or stay aggroed.

Tests: new scenario pattern_cycle (28 scenarios total) - cycle determinism
(swings 1-2 never chain, swing 3 chains, double lands exactly 15+10, cooldown
> 1.5s after), and the world reset (full hp, back at post, chain/pattern/aggro
cleared). Machinery run 5 (manual chain injection) still passes unchanged.

Prices/values are scaffold tuning awaiting Omer's pass: follow-up damage 10,
pattern period 3, chain cooldown 1.6s.

## Iteration 10 - pattern depth: the overhead (2026-09-19, overnight)

The effigy's rhythm was one attack plus a follow-up. A player who learned
"hold block, punish after" had solved it. Iteration 10 gives the pattern a
second distinct attack.

[overnight proposal - awaiting Omer review] Every 6th swing (deterministic
counter, no RNG) the effigy heaves the club OVERHEAD: slow (1.2s windup),
heavy (25 dmg), narrow (70 deg arc), longer reach (2.8) - and UNBLOCKABLE,
riding the tested unblockable flag machinery. The tell is honest and already
wired: unblockable windups glow red instead of yellow. Block fails against it
(full 25 through the guard); spacing or a roll beats it. This is the attack
that punishes a player who only learned to turtle. Distinct log line
"HEAVES ITS CLUB OVERHEAD" so footage and stats can see it.

Cycle is now: swings 1-2 plain, 3 chains the quick follow-up, 4-5 plain,
6 overhead. World reset still zeroes the counter.

Tests: pattern_cycle extended (run 2) - rhythm positions verified swing by
swing, overhead announced distinctly, unblockable goes through a held block
for exactly 25. Machinery run 4 (forced unblockable) still green. 28/28.

Scaffold values awaiting Omer: overhead 25 dmg / 1.2s windup / period 6.

Skipped from the candidate list: post-chain vulnerability window (+damage
after the double-rest) - no honest visual telegraph designed yet; proposing
without a readable tell would break telegraph honesty. Parked.
