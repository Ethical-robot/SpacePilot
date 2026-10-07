# Space Pilot — Player Growth / Survivor Economy

**Status:** Living document for the Survivor-first progression loop.  
**Code sources:** `ProgressionEconomy.swift`, `FlightModel.swift`, `ProceduralUniverse.swift`, shop/refinery UI in `ImmersiveSpaceView.swift`.

Currency is **Mon**, shown as **§** (persisted via the legacy credits store).

## Difficulty

| Mode | Start | Energy / fuel | Nav DETECT |
|---|---|---|---|
| Survivor | Axe + empty | Full costs | Buy Nav Module at station |
| Normal | Axe + slicer + crumbler + analyzer | Reduced costs | Owned |
| Creative | All tools | No costs | Owned |

## Bootstrap loop (Survivor)

1. Chop trees with the **Axe** (no energy cost).
2. Return to ship (landed/docked) → **REFINERY** → convert logs to **organic energy**.
3. Unlock powered tools via station shop, wreckage modules, or craft (blueprint + elements).
4. Powered tools (Analyzer, Crumbler, Slicer, Launcher) spend organic energy at **1/4** the original drain rates.
5. Craft **Energy Cubes** (Cube I = 10 any crystal + 10 logs → single-use **+100** recharge). Higher cube tiers need more materials.
6. Craft **Energy Storage** expansions (each +50 permanent capacity; each tier needs one additional element type).
7. Cruise burns **ship fuel**; atmospheric boost and hyperdrive burn much more.
8. Find a **station** in-system and buy the **Auto-Flight Nav Module** (§120) to unlock DETECT.

## Refinery / fabricator

Available when:
- Docked or landed **in the ship**, or
- In the **rover** after buying/crafting the **Rover Refinery Module**

- Convert logs → energy
- Refine equipped materials → elements
- Craft tools/modules, **Energy Cubes**, and **Energy Storage** expansions (some need blueprints)

Opening the refinery hides the inventory kit and both aiming/directional crosshairs so the panel stays interactive; closing restores them.

## Relics

- Relics spawn as mineral-looking formations (`|relic` tag).
- **Analyzer** scan confirms “RELIC” and marks the resource scanned.
- Intact pickup requires a **Relic Key** (rare crumbler drop); key fuses on pickup.
- Equipped Relic Key draws a ~3 m purple locator beam from the held key toward the nearest Relic formation.
- Outcomes: sell for high Mon, **OPEN RELIC** for blueprints/modules/materials, or crumbler-breakdown for Relic Fragments.
- Scanning any mineral/tree before harvest grants **+33%** yield.

## Station shop

Docked LEAVE → **Visit station shop**:

- Nav Module, Analyzer / Crumbler / Slicer unlocks, Crumbler efficiency upgrade

Wreckage examine can also drop modules/blueprints.

## Roadmap hook

Organic energy, Mon, elements, and Relic loot feed later **ice / volcanic survival gear** gates in [TASKS.md](TASKS.md).
