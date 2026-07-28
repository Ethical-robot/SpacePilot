# Space Pilot Roadmap

The current milestone is a usable single-player flight prototype. The following items are planned for later development.

## World and Exploration

- [ ] **Procedurally generated regions:** Generate new areas and destinations as the player flies and explores.
  - [x] Use deterministic seeded sector coordinates so revisiting a location regenerates the same destinations.
  - [x] Stream the surrounding 3×3×3 neighborhood into RealityKit and unload distant sectors.
  - [x] Rebase the local scene at sector boundaries to support long-distance flight without precision loss.
  - [x] Integrate procedural destinations with navigation, autopilot, and cockpit telemetry.
  - [x] Persist visited sectors and discovered celestial bodies between sessions.
  - [x] Generate, stream, navigate to, and persist procedural wreckage and station discoveries.
  - [x] Add proximity arrival detection, station docking, and persistent wreckage examination.
  - [ ] Persist future player-created changes to procedural regions.
    - [x] Persist depleted surface trees and mineral formations by deterministic planet and tile resource identifiers.
  - [ ] Add richer encounter rules, additional point-of-interest types, and production-quality assets.
- [ ] **Planet and star traversal:** Allow seamless approaches to and landings on planets. Entering an atmosphere should substantially reduce effective speed for playable low-altitude flight. Flying too close to or into a star should cause the ship to burn up.
  - [x] Detect upper/lower atmosphere, report altitude, progressively limit speed, and establish radial surface up.
  - [x] Auto-upright the ship relative to the planet when the dominant-hand joystick is disconnected.
  - [x] Add accumulating star heat and ship destruction at maximum exposure.
  - [x] Add deterministic type-specific surface biomes and readable close-range terrain landmarks.
  - [x] Add extended upper/lower atmospheres, altitude-driven surface LOD, and lower-atmosphere dogfighting space.
  - [ ] Add detailed atmospheric visuals, terrain, touchdown sites, and a complete destruction/restart sequence.
- [ ] **Living planets and surface exploration:** Populate planets with varied life and interactive environments. Landing should let the player transition into a rover-style vehicle, leave the rover to continue on foot, and interact with nearby creatures, objects, resources, and structures.
  - [x] Add initial rover and on-foot surface movement with dominant-hand steering, curved-surface adherence, distinct speeds, and an exploration HUD.
  - [ ] Build a separate surface-scale streaming layer for rover and on-foot exploration. On exit, expand the perceived world and traversal space to 10–50× its ship-view scale while preserving the landing location and return path to the ship.
    - [x] Add the first deterministic 3×3 rolling tile neighborhood, 24× local detail population, biome-aware tile content, unloading, and an exact ship-return anchor.
    - [ ] Add production terrain meshes, elevation and collision, broader biome transitions, and final surface-scale calibration.
  - [ ] Replace sparse orbital biome markers with dense local environments at surface scale, including forests, terrain variation, mineral fields, structures, and biome-specific points of interest.
  - [ ] Add collectible minerals and a persistent inventory for crafting and construction. Distribute minerals by planet and biome, with rarer deposits and higher-value resources more common on airless worlds.
    - [x] Persist collected inventory, quantities, source-planet metadata, processed names, and the equipped item across flight resets and app relaunches.
    - [x] Deterministically vary common, uncommon, and rare mineral deposits by planetary biome, with stronger rare-material weighting on airless worlds.
    - [ ] Research real-world material composition and define the material-to-element processing table, including creature-derived materials, before implementing refinement results.
    - [ ] Add item-specific activation behavior using the established two-hand activation gesture, with each equipped item dispatching its own effect.
  - [ ] Populate every atmospheric planet with a mixture of hostile enemies and nonaggressive creatures. Select species, behavior, coloring, resources, and encounter frequency from the local biome.
    - [x] Add deterministic planet-themed creature materials with a 33% drop chance, analyzer support, and persistent inventory collection.
    - [ ] Add anatomy-specific drops from modular creature features, such as eagle beaks and spider thread.
  - [ ] Populate airless planets with mineral formations, abandoned or active bases, and occasional aggressive robots concentrated near bases. Do not generate normal wildlife, forests, or living biomes on these worlds.
    - [x] Add deterministic security-robot groups around airless-world bases, with proximity pursuit and persistent analyzer identification.
  - [ ] Create a deterministic modular creature generator using six independently selected feature categories:
    - **Head:** lizard, bear, eagle, mosquito, or spider.
    - **Body:** upright, hunched, or horizontal.
    - **Arms:** claws, crab claws, monkey hands, or limbs matching the selected legs.
    - **Legs:** large/heavy, jumping, spider, tentacle, tall, or short.
    - **Wings:** bat, eagle, gliding, or none.
    - **Tail:** long, spiked, stubby, or multiple tails.
  - [ ] Give each world a deterministic creature color palette derived from its planetary and biome colors, while allowing multiple related species variants on the same world.
  - [ ] Generate coherent creature anatomy and movement from the selected parts, including appropriate stance, locomotion, attack range, grazing or idle behavior, and terrain compatibility.
  - [ ] Allow winged creatures to inhabit the lower sky, circle or migrate above the terrain, land, and interact near ground level. Non-winged creatures must remain surface-bound unless their anatomy supports jumping or climbing.
  - [ ] Add surface encounter spawning, simulation LOD, and despawning so dense forests, creatures, robots, and mineral fields remain stable and performant on Vision Pro.
  - [ ] Add scanning and identification for unknown creatures, minerals, bases, and biome features, with discoveries recorded per planet.
    - [x] Persist analyzer discoveries for surface flora, mineral types, and bases in a per-planet catalog.
- [ ] **On-foot discovery and ship acquisition:** Support entering wreckage, stations, settlements, and ships on foot. Finding wreckage, purchasing ships, stealing ships, boarding, and claiming vehicles may require the player to leave the rover and explore directly.

## Combat, Resources, and Progression

- [ ] **Hostile aliens:** Add aerial ships, flying creatures, ground aliens, and hostile rover-type machines. Enemies can be attacked and destroyed and may yield collectible materials.
- [ ] **Galactic progression:** Build a long-term combat, trade, resource, property, and influence loop. The player should be able to fight or trade with aliens, buy resources and planets, gain power and control, terraform planets, and complete procedurally generated quests. Aim for the adventurous progression and larger arc of *Galactic Phantasy Prelude*, expanded into a broader explorable universe.

## Contextual Gameplay

- [x] **Physical cockpit controls:** Provide hand-grabbed animated joystick and throttle controls, visible fire and turbo buttons, a held hyperdrive countdown, and a lower command console.
- [x] **Navigation and ship context:** Support filtered detection, persistent autopilot locks, landing/docking controls, weapon selection, and inventory-sensitive ship exit choices.
  - [x] Save the last landed planet, docked station, or secured wreckage and restore the player’s ship, rover, or on-foot context on the next launch.
- [x] **Test weapon suite:** Provide weapon-specific reticles and trigger behavior for Laser, lock-on Missile, and a cumulative Slow Beam.
- [ ] **Environment-specific controls:** Provide distinct control models for space flight, atmospheric flight, land/rover travel, on-foot exploration, and water travel. Each should feel natural for its situation while retaining a coherent hand-control language.
- [ ] **Single player first, multiplayer later:** Build and balance the game as a single-player experience now. Preserve clean boundaries in simulation and player-state systems so multiplayer can be added in a future milestone.

## Visual Quality

- [ ] **Hyper-realistic presentation:** Treat convincing graphics as a core gameplay requirement. Pursue physically based materials, realistic lighting and scale, detailed environments and effects, strong spatial audio, and stable Vision Pro performance. Avoid placeholder-quality visuals in player-facing milestones.
