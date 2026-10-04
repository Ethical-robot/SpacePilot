# Space Pilot Roadmap

The current milestone is a usable single-player flight prototype. The following items are planned for later development.

> **Controls:** [CONTROLS.md](CONTROLS.md) lists all current gestures and bindings — **update it whenever controls change**.
>
> **Player growth / Survivor economy:** [PROGRESSION.md](PROGRESSION.md) — Mon (§), organic energy, ship fuel, Axe bootstrap, station shop, refinery/fabricator, Relics & keys. Feeds later ice/volcanic survival gear.
>
> **Scale & Speed Contract:** [SCALE_AND_SPEED_CONTRACT.md](SCALE_AND_SPEED_CONTRACT.md) is **APPROVED / LOCKED**. Code source of truth: `ScaleAndSpeedContract`.
>
> Implementation order:
> 1. [x] Freeze contract numbers
> 2. [x] Solar-system container + station specialty binding (visibility / far-system LOD still open)
> 3. [x] Survivor player-growth loop (energy, fuel, Mon, Nav Module, Relics)
> 4. [ ] Speed regimes + upper-atmo transition
> 5. [ ] Visual limb vs gameplay envelope split
> 6. [ ] Shared biome map across orbital / atmo / surface
> 7. [x] Station buy pricing (host < same-system < out-of-system) + trade concourse sell
> 8. [ ] Revisit 50× surface exit scale after ship-scale feels right

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
  - [ ] **Orbital planet look and feel (planet-to-planet approach):** Improve the visual identity of each world while flying between destinations.
    - [x] Within **10,000 m** of a planet, show a readable rough planetary globe (not a flat or sparse marker field).
    - [x] From that range, biome regions must be visible as coherent surface bands/continents so the pilot can choose a landing biome by eye.
    - [x] Replace the current “mostly wasteland + a few oval biome patches” orbital look with denser, type-driven irregular continent meshes that nest together.
    - [x] Upper atmosphere: foggy veil that still reveals the surface below; lower atmosphere: clear visibility with strong fill light.
    - [ ] Keep refining orbital detail and biome transitions toward production terrain quality.
- [ ] **Living planets and surface exploration:** Populate planets with varied life and interactive environments. Landing should let the player transition into a rover-style vehicle, leave the rover to continue on foot, and interact with nearby creatures, objects, resources, and structures.
  - [x] Add initial rover and on-foot surface movement with dominant-hand steering, curved-surface adherence, distinct speeds, and an exploration HUD.
  - [ ] Build a separate surface-scale streaming layer for rover and on-foot exploration. On exit, expand the perceived world and traversal space to **50×** its ship-view scale while preserving the landing location and return path to the ship.
    - [x] Add the first deterministic 3×3 rolling tile neighborhood, 24× local detail population, biome-aware tile content, unloading, and an exact ship-return anchor.
    - [ ] Raise local surface scale from the current prototype factor to the target **50×** ship-view expansion, with matching traversal distances and return-to-ship anchors.
    - [ ] Add production terrain meshes, elevation and collision, broader biome transitions, and final surface-scale calibration.
  - [ ] Replace sparse orbital biome markers with dense local environments at surface scale, including forests, terrain variation, mineral fields, structures, and biome-specific points of interest.
  - [ ] **Planetary terrain language:** Stop relying on oval biome discs over empty wasteland. Every landable world should express readable geology and hydrology at surface scale.
    - [ ] Generate ridges, valleys, mountains, and canyons as first-class terrain features.
    - [ ] On worlds that support surface liquid, generate rivers and lakes with shore transitions into neighboring biomes.
    - [ ] Make terrain feature placement deterministic from planet seed + biome, so revisits rebuild the same landforms.
  - [ ] Add collectible minerals and a persistent inventory for crafting and construction. Distribute minerals by planet and biome, with rarer deposits and higher-value resources more common on airless worlds.
    - [x] Persist collected inventory, quantities, source-planet metadata, processed names, and the equipped item across flight resets and app relaunches.
    - [x] Deterministically vary common, uncommon, and rare mineral deposits by planetary biome, with stronger rare-material weighting on airless worlds.
    - [ ] Research real-world material composition and define the material-to-element processing table, including creature-derived materials, before implementing refinement results.
    - [ ] Implement the **Planetary Element Codex** (see below) so refining / creature drops / mineral processing map onto the full periodic set plus imaginary elements.
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

## Six World Types and Congruency System

Today the player mostly experiences two effective planetary modes (atmosphere vs airless), even though several `CelestialBodyKind` values exist. Rebuild planet generation so each of the six world types is an **ordered identity**, not a thin skin over the same random content. Add **volcanic** as a first-class world type alongside the existing five.

### World identities

| World type | Atmosphere | Dominant terrain / hazards | Primary resource family |
|---|---|---|---|
| **Ocean** | Yes | Continents, forests, rivers, lakes, wetlands; storm and drowning/soft-ground hazards near water; **distinct surface/water mobility** | Softer / liquid-associated elements and organics |
| **Desert** | Yes | Dunes, mesas, canyons, dry riverbeds, oasis lakes (rare); heat and sandstorm hazards | Soft salts, lighter metals, sparse organics |
| **Rocky** (airless / thin) | No (or negligible) | Highlands, craters, ridges, mountains, boulder fields, bases/robots; vacuum / radiation hazards | Dense minerals and heavy elements |
| **Ice** | Yes (cold) | Shelves, ridges, crevasses, frozen lakes/rivers, glacial valleys; cold and collapse hazards; **survival gear required** | Cryogenic volatiles, lighter ices, mixed soft minerals |
| **Volcanic** | Yes (harsh) | Lava fields, calderas, ash plains, fumaroles, basalt ridges; heat, toxic ash, and unstable ground; **survival gear required** | Refractory metals, sulfurs, igneous minerals, heat-gated exotics |
| **Gas** | Cloud/atmosphere only (no solid walkable crust in v1, or limited floating/platform exceptions later) | Cloud bands, storms, shear layers; pressure / toxicity / lightning hazards | Gaseous elements and exotic volatiles |

Stars remain non-landable heat hazards and are outside the six landable/collectible world identities.

### Ordered generation rules (less pure randomness)

- [ ] Define a **planet profile** per world type: biome palette, hazard set, flora rules, fauna rules, survival requirements, and element pools.
- [ ] Prefer weighted tables and fixed slot fills over unconstrained random draws (example: always N continents / storm bands / crater provinces / caldera chains for that type).
- [ ] Keep seeds deterministic, but make outcomes **recognizably typed**: an ocean world should never read like a sparse airless rock with different creature skins; a volcanic world should never read like a mild desert recolor.
- [ ] Orbital globe, atmospheric haze, surface tiles, minerals, hazards, and creatures must all pull from the same planet profile (“system of congruency”).
- [ ] Extend `CelestialBodyKind` (or equivalent profile id) so **volcanic** is generated, streamed, landable, and congruent end-to-end.

### Hazardous-world survival (gear gates)

More hazardous worlds must be difficult to survive on without preparation.

- [ ] **Ice worlds:** Without adequate cold-survival gear, player health drains slowly while outside the ship on that world until the player dies, returns to the ship, or leaves the planet.
- [ ] **Volcanic worlds:** Without adequate heat/toxin-survival gear, player health drains slowly on the same rules (die, re-enter ship, or leave the planet).
- [ ] Define upgrade tiers of survival gear (suit / filters / thermal layers, names TBD) that fully or partially negate the drain when equipped.
- [ ] Surface HUD must clearly warn when a hazard drain is active and when gear is insufficient.
- [ ] Death / recovery on hazard worlds uses the existing survivability loop (recover at ship or rover when available); do not soft-lock the player off-world without a return path.
- [ ] Optional later: milder environmental pressure on desert / gas approaches; v1 hard gates are **ice + volcanic**.

### Ocean mobility

- [ ] Ocean planets introduce **different mobility controls** from standard on-foot / rover traversal (swim / surface craft / dive layers as designed).
- [ ] Keep a coherent hand-control language with space / atmo / land, but ocean locomotion must feel distinct and biome-appropriate.
- [ ] Weapons and tools remain usable where designed; underwater / surface-water constraints are explicit in the ocean profile.

### Surface scale target

- [ ] When leaving the ship, expand perceived planetary surface detail and traversal space to **50×** the ship-view appearance of that landing patch.
- [ ] Preserve exact ship-return anchor and rover/foot continuity across the scale transition.

## Planetary Element Codex

Goal: by visiting enough worlds, the player can eventually collect **all periodic-table elements**, plus a small set of imaginary exotics.

### Collection coverage

- [ ] Catalog every standard periodic element as a refinable / droppable resource identity.
- [ ] Add imaginary / exotic entries, including at least:
  - Dark matter
  - Anti-matter
  - A small additional set of named exotics (final names TBD; keep them rare and type-gated)
- [ ] Track discovery and ownership in a persistent codex UI (analyzer + inventory integration).

### Type-driven sourcing (congruency)

- [ ] **Gas worlds:** primary source of gaseous elements and related volatiles.
- [ ] **Airless rocky worlds:** primary source of dense / heavy minerals and high-value solid elements.
- [ ] **Ocean / desert worlds:** primary source of liquid-associated, softer, and biologically mediated elements.
- [ ] **Ice worlds:** primary source of cryogenic volatiles and cold-gated soft minerals (often behind survival-gear access).
- [ ] **Volcanic worlds:** primary source of refractory metals, sulfurs, and heat-gated minerals/exotics (often behind survival-gear access).
- [ ] Allow secondary bleed (small chance of off-family finds) so exploration stays rewarding, but keep the **majority signature** true to planet type.
- [ ] Gate the rarest exotics (dark matter, anti-matter, and peer imaginaries) behind rare biomes, deep hazards, or special POIs rather than common tile noise.

### Creature drops and periodic values

- [ ] Creature drops are **planet-specific** and map to codex element identities (or named compounds that refine into them).
- [ ] Assign each creature material a periodic / exotic value used by future crafting, trade, and progression.
- [ ] Anatomy can still flavor the drop name, but the underlying element family must remain congruent with the host planet type.

## Biomes, Flora, and Fauna Rules

### Biome readability

- [ ] Reduce oval-only biome stamps; use terrain-aware biome regions shaped by mountains, valleys, coasts, and river networks.
- [ ] Most of a planet’s landable surface should belong to intentional biomes for that world type, not default wasteland filler.
- [ ] From orbit (≥ within 10,000 m), biomes must remain distinguishable.

### Creatures per biome

- [ ] No more than **3 creature species per biome**.
- [ ] Exactly **1 of those 3 is hostile**; the other two are nonaggressive (grazer / ambient / shy).
- [ ] Flora and fauna kits are unique to the biome and derived from the planet profile.
- [ ] Rivers and lakes get aquatic / amphibious kits featuring fins, tentacles, shells, and related anatomy; dry biomes do not spawn those water kits.
- [ ] Biochemistry may be non-carbon on some world types (especially exotic gas / ice / volcanic / airless chemistries), affecting color, drops, and analyzer text.
- [ ] Volcanic biomes favor heat-tolerant / ash-plane flora–fauna kits; ice biomes favor cold-tolerant kits; neither reuses temperate ocean/desert kits unchanged.
- [ ] Species have a **canonical adult size** chosen once by deterministic generation, generally between small-dog and elephant scale. Individuals may vary slightly, but a species should not randomly span that full range.

### Modular generator updates tied to these rules

- [ ] Extend modular creature parts with water-capable traits (fins, shells, tentacles) and restrict them to aquatic biomes.
- [ ] Enforce terrain compatibility: aquatic species stay near rivers/lakes; winged species may use lower sky; ground species remain surface-bound unless anatomy supports jump/climb.
- [ ] Keep one hostile species behavior package per biome (pursuit / ambush / territorial) while nonhostile species idle, graze, or flee.

## Combat, Resources, and Progression

- [x] **Survivor player growth (v1):** Organic energy from logs, ship fuel for cruise/boost/hyper, Mon (§) currency, Axe bootstrap, station shop (Nav Module + tool unlocks), ship refinery/fabricator, Relic + Relic Key loop with scan gate and +33% scanned yield. See [PROGRESSION.md](PROGRESSION.md).
  - [x] Gate DETECT / auto-flight convenience behind Nav Module purchase (or expensive craft).
  - [x] Persist energy, fuel, modules, blueprints, and upgrade tiers with inventory.
  - [ ] Expand Element Codex coverage and data-driven recipes beyond the v1 hardcoded table.
  - [ ] Landing-pad surface vendors (in addition to station shop).
- [ ] **Hostile aliens:** Add aerial ships, flying creatures, ground aliens, and hostile rover-type machines. Enemies can be attacked and destroyed and may yield collectible materials.
- [ ] **Weapon upgrades and shops:** Ship and personal weapons are **upgradable and purchasable**, not fixed to the prototype test suite.
  - [ ] Sell weapon unlocks, tiers, and ammo/support gear at **space-station shops** (trade concourse / specialized vendors).
  - [ ] Also sell weapons and upgrades at **planetary landing-pad shops** / surface vendors near secured pads and settlements.
  - [ ] Station and pad inventories are congruent with host-planet specialty where applicable (pricing and stock lean toward local material families).
  - [ ] Persist owned weapons, equipped loadout, and upgrade tiers across sessions.
  - [ ] Keep the existing Laser / Missile / Slow Beam suite as the starter baseline that shops expand from.
- [ ] **Survival gear economy:** Cold- and heat/toxin-survival gear for ice and volcanic worlds is craftable and/or purchasable from stations and landing-pad shops so hazardous worlds are gated by progression, not arbitrary locks. **Depends on** Survivor energy/Mon/elements loop above.
- [ ] **Galactic progression:** Build a long-term combat, trade, resource, property, and influence loop. The player should be able to fight or trade with aliens, buy resources and planets, gain power and control, terraform planets, and complete procedurally generated quests. Aim for the adventurous progression and larger arc of *Galactic Phantasy Prelude*, expanded into a broader explorable universe.
  - [ ] Use the Planetary Element Codex as a backbone for trade value, crafting gates, and exploration incentives across the six world types.

## Contextual Gameplay

- [x] **Physical cockpit controls:** Provide hand-grabbed animated joystick and throttle controls, visible fire and turbo buttons, a held hyperdrive countdown, and a lower command console.
- [x] **Navigation and ship context:** Support filtered detection, persistent autopilot locks, landing/docking controls, weapon selection, and inventory-sensitive ship exit choices.
  - [x] Save the last landed planet, docked station, or secured wreckage and restore the player’s ship, rover, or on-foot context on the next launch.
- [x] **Test weapon suite:** Provide weapon-specific reticles and trigger behavior for Laser, lock-on Missile, and a cumulative Slow Beam.
- [ ] **Environment-specific controls:** Provide distinct control models for space flight, atmospheric flight, land/rover travel, on-foot exploration, and **ocean / water travel**. Each should feel natural for its situation while retaining a coherent hand-control language.
  - [ ] Ocean-planet mobility is a required profile feature (see Ocean mobility above), not an optional polish pass.
- [ ] **Single player first, multiplayer later:** Build and balance the game as a single-player experience now. Preserve clean boundaries in simulation and player-state systems so multiplayer can be added in a future milestone.

## Visual Quality

- [ ] **Hyper-realistic presentation:** Treat convincing graphics as a core gameplay requirement. Pursue physically based materials, realistic lighting and scale, detailed environments and effects, strong spatial audio, and stable Vision Pro performance. Avoid placeholder-quality visuals in player-facing milestones.
- [ ] **Planet approach presentation:** Treat the 10,000 m biome-readable globe and the 50× landed expansion as a paired visual contract: rough but informative from the ship, rich and traversable on foot/rover.

## Suggested implementation order

1. [x] Survivor player-growth v1 (energy, fuel, Mon, Nav, Relics) — see [PROGRESSION.md](PROGRESSION.md).
2. Define planet profiles + element pools for the **six** world types, including **volcanic** (data/design before more mesh work).
3. Rebuild orbital globe biomes so worlds read correctly within 10,000 m (volcanic ash/lava bands readable from approach).
4. Retarget landed surface scale to 50× and keep ship-return anchors exact.
5. Replace oval/wasteland surface language with ridges, valleys, mountains, rivers, lakes, and volcanic caldera/lava-field language.
6. Implement **hazard survival drains** for ice + volcanic, plus purchasable/craftable survival gear gates (spend Mon/elements from the growth loop).
7. Add **ocean-planet mobility** controls as a distinct locomotion mode.
8. Stand up **station + landing-pad weapon shops** (purchase/upgrade path from the starter weapon suite).
9. Enforce 3-species-per-biome fauna rules (1 hostile) with planet-specific drops into the Element Codex.
10. Expand mineral/gas/soft/volcanic-element sourcing tables until full periodic + exotic coverage is reachable across the galaxy.
