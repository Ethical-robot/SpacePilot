# Space Pilot — Controls & Gestures

**Status:** Living document — update this file whenever hand, gamepad, HUD, or window controls change.  
**Code sources of truth:** `HandFlightController.swift`, `ImmersiveSpaceView.swift` (`ControllerObserver`, cockpit/HUD UI), `MissionControlView.swift`, `FlightModel.swift`.

**Dominant hand** defaults to **RIGHT** and is configured only in Settings (gear on the loadout kit). Ship, Walking, and Rover each have a separate handedness setting. Gestures never steal or switch dominance.

**Inventory kit** (non-dominant fist toward you, thumb tucked) works in every play context while you are not game-over: flying, docked station, wreckage, landed in ship, rover, and on foot. On foot it also shows the tool strip.

**Pause:** Open the gear on the inventory panel (top-right). That is the only pause entry; it pauses simulation in single-player only.

---

## 1. Space / atmospheric flight (in ship)

### Hand — dominant (joystick)

| Gesture | Action |
|---|---|
| Fist + thumb up (grip) | Grab physical joystick (hand must already be the configured dominant hand) |
| Fist tilt left / right | Yaw + coordinated roll |
| Fist tilt toward / away | Pitch up / down |
| Thumb fold onto fist (fire) | Hold weapon trigger (Laser / Slow Beam continuous; Missile per press) |
| Thumb up / release fold | Stop firing |
| Open hand / lose fist | Release joystick; inputs clear. In atmosphere, ship auto-uprights when stick is released |

### Hand — secondary (throttle + kit)

| Gesture | Action |
|---|---|
| Fist with knuckles up | Grab throttle |
| Push fist forward (−Z) | Increase throttle toward max forward |
| Pull fist back (+Z) | Reverse up to ~50% max forward |
| Thumb fold (outside atmosphere) | Hold turbo: 3 s charge → hyperdrive; extend thumb to cancel / exit hyper |
| Thumb fold (inside atmosphere) | Atmospheric boost hold (no hyperdrive) |
| Release throttle pose | Keep current speed; throttle visual releases |
| Closed fist toward your face (palm facing you), thumb tucked on the fist | Open inventory kit |
| Leave kit fist pose (~0.28 s grace) | Close kit (settings stay open if gear menu is up) |

### Hand — either (seated view)

| Gesture | Action |
|---|---|
| Dominant thumb↔index pinch + drag left/right | Yaw forward / compass view; release keeps heading. Does not apply while fist-gripping joystick |

### Gamepad (in ship)

| Input | Action |
|---|---|
| Left stick X / Y | Yaw / pitch |
| Right stick X | Roll |
| Right trigger | Throttle |
| A | Toggle autopilot |
| B | Full stop |
| Y or D-pad Up | Toggle inventory kit |

### Cockpit HUD / attachments (in ship)

| Control | Action |
|---|---|
| Landing / takeoff / dock button | Context landing control (`performLandingControl`) |
| Weapon button | Cycle Laser → Missile → Slow Beam |
| Shield button | Toggle ship shield |
| DETECT ∞ | Open detection picker (requires Nav Module; otherwise shows lock + station hint) |
| REFINERY | Open refinery / fabricator when docked or landed |
| LEAVE menu | Exit options raise **up** from the lower bar (Deploy rover, Leave on foot, Visit trade concourse, Visit station shop, … when available) |
| DETECT picker | Raises **up** from the lower bar (same expansion rule as LEAVE) |
| Inventory settings (gear) | Expands **down** from the inventory top bar |
| Target contact panel | CONTINUE toward locked target / CHANGE TRAJECTORY (cancel autopilot) |
| Context proximity | DOCK / UNDOCK / EXAMINE when in range and slow enough |

### Mission Control window (non-immersive / companion)

| Control | Action |
|---|---|
| Thrust / Pitch / Yaw sliders | Direct flight inputs |
| Autopilot toggle | Enable / disable autopilot |
| Center controls | Zero pitch & yaw |
| Full stop | Stop ship |
| Reset | Reset flight |
| Exit space | Leave immersive space |

---

## 2. Surface — Deploy rover

### Hand — dominant

| Gesture | Action |
|---|---|
| Fist (thumb up not required once exploring) | Grip rover stick |
| Tilt forward / back | Drive forward / reverse |
| Tilt left / right | Turn |
| Dominant thumb↔index pinch + drag | Seated view / compass yaw (persistent) |

### Hand — non-dominant (inventory)

| Gesture | Action |
|---|---|
| Closed fist toward your face, thumb tucked | Open inventory kit |
| Leave kit fist pose (~0.28 s grace) | Close kit |

### Gamepad

| Input | Action |
|---|---|
| Left stick Y / X | Forward-back / turn |
| A | Leave rover |
| B | Board nearest ship (within ~15 m) |
| Y or D-pad Up | Toggle surface kit / inventory |

### HUD panel

| Control | Action |
|---|---|
| LEAVE ROVER | Exit to on-foot |
| ENTER SHIP | Return to ship (within ~15 m) |

Headset look does not steer the rover; fist / stick does.

---

## 3. Surface — Leave on foot

### Secondary hand (locomotion + kit + pickup)

| Gesture | Action |
|---|---|
| Thumb tip ↔ middle finger (in front activation zone) | Walk forward (hold) |
| Solid walk hold → brief thumb/middle break → hold walk again (within ~0.4 s) | Run at 2× (stays while you keep holding walk) |
| Closed fist toward your face (palm facing you so you see the fingers), thumb tucked on the fist | Open tools + inventory kit |
| Leave kit fist pose (~0.28 s grace) | Close kit |
| Thumb↔index pinch (edge) while looking at loose item | Pick up looked-at loose material |
| C-shape then close grab (non-dominant) | Alternate pickup (gaze + close) |

Walk direction follows **headset facing** (projected on the surface).

### Dominant hand (tools + jetpack + view)

| Gesture | Action |
|---|---|
| Thumb↔middle (open hand, not tool-thumb-fold, in zone) | Jetpack thrust (while fuel remains) |
| Index tip tap / swipe on tool strip | Select / cycle surface tools when kit open |
| Thumb fold (armed after release) + aim | Activate selected tool (see tools below) |
| Thumb↔index pinch + drag | Seated view / compass yaw (persistent) |
| Hold equipped inventory item to mouth ~2 s | Eat equipped item |

### Surface tools (dominant thumb fold to fire)

| Tool | Behavior |
|---|---|
| EMPTY | No tool fire |
| AXE | Chop trees for organic feedstock (no energy cost; Survivor starter) |
| SONIC SLICER | Pulse cut at tool tip (uses organic energy) |
| MATTER CRUMBLER | Continuous beam while held & aimed forward (uses organic energy) |
| MATTER LAUNCHER | Fire projectile (uses mineral ammo + energy) |
| ANALYZER | Scan target ahead (uses organic energy; +33% yield if scanned before harvest; confirms Relics) |

Tool availability depends on difficulty, shop unlocks, and crafting (see [PROGRESSION.md](PROGRESSION.md)).

### Relic Key (equipped inventory item)

| Gesture / state | Action |
|---|---|
| Equip Relic Key in dominant hand | Thin purple locator line (~3 m) toward nearest Relic |
| Pickup scanned Relic | Consumes 1 Relic Key (fuses); Relic can be opened |

### Both hands

| Gesture | Action |
|---|---|
| Both hands C-shape, then both close grab within ~0.6 s | Activate equipped inventory item |

### Gamepad (on foot)

| Input | Action |
|---|---|
| Left stick Y (forward) | Walk forward |
| Left stick click (L3) while moving | Run 2× |
| A (hold) | Jetpack thrust |
| B | Board nearest ship or rover (~15 m) |
| X | Collect looked-at loose item (controller gaze / aim) |
| Y or D-pad Up | Toggle tools + inventory kit |
| LB / RB | Cycle surface tool previous / next |
| Right trigger | Hold to use selected surface tool (controller aim) |

### HUD panel

| Control | Action |
|---|---|
| ENTER SHIP | Within ~15 m of landed ship |
| ENTER ROVER | Within ~15 m of parked rover |

---

## 4. Inventory kit & Settings

### Inventory UI

| Control | Action |
|---|---|
| Tap inventory item | Equip / select |
| Gear (top-right of inventory header) | Open Settings (pauses in single-player) |
| Close (X) / Resume | Leave Settings and unpause |
| REFINERY (when docked/landed) | Open ship refinery / fabricator |
| REFINE 1 / OPEN RELIC | Refine equipped material or open a fused Relic |
| Station trade concourse | Sell cargo for Mon (§) when visiting trade |
| Visit station shop | Buy Nav Module and tool unlocks for Mon (§) |

### Settings (gear menu)

| Control | Action |
|---|---|
| Ship / Walking / Rover dominant hand | Right or Left per mode (persisted) |
| Reset game data | Wipe inventory & Mon, return to starting station, pick difficulty |
| Reset world (keep stuff) • TEST | Relocate + pick difficulty, keep inventory (temporary for testing) |
| Difficulty on reset | **Creative** — no real damage, all tools, no energy/fuel costs. **Normal** — basic tools, reduced energy/fuel costs. **Survivor** — Axe start, full energy/fuel costs, Nav Module gated |

---

## 5. Automatic / passive behaviors (not player gestures)

| Behavior | When |
|---|---|
| Atmospheric auto-upright + travel curvature | Joystick released in atmosphere; attitude follows planet curve |
| On-foot horizon curvature | Walking attitude follows surface radial as you move |
| Surface shell reproject | Enter-range and restore snap actors to current walkable radius |
| Jetpack fuel regen | On ground, not thrusting |
| Star heat damage | Too close to a star (scaled by difficulty; Creative = feedback only) |
| Creature / robot attacks | On foot near hostiles (scaled by difficulty; Creative = feedback only) |
| Simulation pause | Settings gear open in single-player |

---

## 6. Maintenance rule

When changing controls:

1. Update the matching code (`HandFlightController`, `ControllerObserver`, HUD, or `MissionControlView`).
2. **Update this file in the same change** so sections stay accurate.
3. If a mode gains/loses a binding, adjust the tables above (do not leave stale rows).
4. Prefer short player-facing names here; keep implementation detail in code comments.
