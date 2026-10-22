# guys

A squad brawler for [Petrichor64](https://github.com/Auxnon/petrichor64): Metal
Slug's guns, Pikmin's squads, Lemmings' sense of direction.

The ground is no place to live. People keep to the mountains, floating islands
and flying cities, and get about in slow, clunky airships. You lead up to three
commanders through Ridgeback Pass to take the flying fortress at the far end.

## Playing

```sh
chor path/to/guys        # or petrichor64/target/release/chor (build with --features audio for sound)
```

| input | |
|---|---|
| WASD / arrows | walk (at a helm: A/D fly, W/S climb and sink) |
| SPACE | jump |
| LMB | send soldiers there; click a cannon to crew it |
| RMB | rally: follow me, and enlist civilians (hold to keep calling) |
| H / F | hold the line / forward march |
| Q | fire your own pistol at the pointer |
| E | take or leave the helm |
| P | promote a veteran (level 1+) to commander |
| 1 2 3, C | pick a commander, or the next one |
| F1 / ESC | orders card (pauses) |
| scroll | zoom |

## How it plays

- **Commanders and their circles.** Soldiers only hear a commander whose circle
  they stand in. The circle grows with comm tech: voice, megaphone, radio (radio
  commanders also relay orders through each other's circles), and a sound
  system (the biggest circle, but heavy). At most three commanders per side.
- **Formation.** Followers take slots in rows behind their commander and walk
  there under their own steam, with eased steering, soft-body jostling and real
  walls, so a squad files along instead of snapping into place.
- **Losing contact.** Stay out of the circle too long, or lose your commander,
  and a soldier wanders off like a lemming: plodding, turning at walls, and not
  at edges. Rally them before they find the drop.
- **Soldiers.** Pistols hit hard, miss a lot, and rounds are scarce. Most fights
  end up as fists and blades. Kills level a soldier from 0 to 3 (more health,
  harder hits, a steadier aim). The dead drop their guns, and the unarmed go for
  them.
- **Towns.** Highdale on the ridge and Skyholm in the sky have civilians to
  enlist. They start at level 0 with bare fists, and raiders prey on them.
- **Cannons.** A cannon fires only what's been carried to it. Crew one and your
  soldiers haul shells from a munitions pile one at a time. The bursts fling
  people, sometimes off a cliff.
- **Airships.** Blocks that fly together (the idea comes from
  [sosh](https://github.com/Auxnon/sosh)'s airships). Stand at the helm to fly
  one. Whoever's on deck rides along, and ships moor and board nose to tail.

## Code

`scripts/` (silt Lua, written in the restricted style petrichor64's
`AGENTS.md` asks for):

| file | |
|---|---|
| `main.lua` | game state, camera, frame loop, win/lose, restart |
| `level.lua` | the region: terrain, towns, units, ships, gear |
| `terrain.lua` | heightmap columns and `W.ground`, the one ground query |
| `ships.lua` | airships and the fortress: block grids, flight, riders |
| `unit.lua` | everyone who walks: physics, levels, weapons, drawing |
| `ai.lua` | soldiers, civilians, enemy commanders, pilots |
| `cmd.lua` | commanders: tech, orders, formation, contact, rings |
| `combat.lua` | pistols, melee, cannon shells |
| `gear.lua` | pickups, cannons, munitions piles |
| `fx.lua`, `sfx.lua`, `hud.lua`, `input.lua`, `art.lua`, `util.lua` | the rest |

`tools/gen_art.py` draws the soldier and effect sheets (`assets/sol.16.png`,
`assets/fx.16.png`). Ship blocks come from sosh, and the other sprites are
hand-drawn.

## Testing

`playtests/run.sh <test.lua> [seconds] [frames…]` runs a scripted playtest on a
hidden Hyprland output and saves frames with `CHOR_SNAP`. Each test drives the
same functions the input does (`WALK_FAKE`, `FLY_FAKE`, `MOUSE_FAKE`
overrides). See the header of `run.sh`. Mute the system audio first, because the
engine opens a real output device.

- `smoke`: boots and idles
- `tour`: hops the level, logging deaths
- `assault`: formation march, megaphone, taking the outpost
- `town`: enlisting civilians, scavenging, losing a commander
- `cannon`: hauling shells, cannon fire
- `sky`: boarding and flying the airship
- `finale`: boarding the fortress and taking the flag
