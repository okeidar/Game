# Feather Greybox - Phase 0A

A souls-like combat core in greybox, built and deployed entirely by an agent.
Godot 4.7.2, GDScript, text-first scenes and resources, headless CI.

The fiction hook: the protagonist is winged and collects feathers. Feathers are
one resource with two uses - the coat you wear (held feathers grant damage
resistance) and the shot you fire (a volley spends them and leaves you bare).
That dual-use is the game's risk economy in miniature: every strong option
carries a cost. See docs/design-notes-phase-0a.md.

## Phase 0A scope
- Walled arena at dusk: fog, cold moonlight, pillars, scattered feather pickups.
- Player: move / sprint (drains stamina), dodge roll with i-frames that match
  the tucked animation, committed light and heavy swings with input buffering
  during recovery, feather volley (spends the coat for ranged damage).
- Lock-on (nearest enemy near camera-forward, breaks on death or distance).
- Hitboxes as honest sectors; hurtboxes as capsules. Hitstop, hit flash,
  telegraph colors on the effigy (yellow windup, red live frames).
- One effigy: approaches, raises its club slow, strikes, recovers. Any hit
  staggers it out of windup. It drops feathers when felled and rises again.
- Death: YOU DIED, wake at the slab.

## Controls
WASD move - SHIFT sprint - SPACE roll - LMB attack - F heavy - R / RMB volley -
TAB lock-on - arrows or mouse camera - ESC frees the cursor.

## Headless verification and export (pinned Godot 4.7.2)
    godot --headless --path . --editor --quit          # import
    godot --headless --path . -- --run-tests           # deterministic combat tests
    godot --headless --path . -- --self-test           # smoke
    mkdir -p build/web
    godot --headless --path . --export-release Web build/web/index.html

The web build must be served over HTTP, not opened as a file.
