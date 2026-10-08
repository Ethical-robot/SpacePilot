# Space Pilot — Scale & Speed Contract

**Status:** APPROVED / LOCKED — 2026-07-28  
**Goal:** Align solar-system presentation, atmosphere flight, orbital planet look, and station economy with the four priorities, while **preserving landed walking/rover gameplay mechanics**.

Numbers below are the implementation source of truth (`ScaleAndSpeedContract` in code). Ranges from the analysis draft are resolved to midpoints.

---

## Priorities (locked)

1. **Preserve walking-mode gameplay** when landed in a biome (controls, speeds, tools, inventory loops). Locations/content may change; mechanics stay.
2. **Lower atmosphere must be roomy enough** for comfortable flight and dogfighting.
3. **Planets must look like planets from space** — biomes stitched into a coherent globe + thin atmosphere limb.
4. **Each biome has distinct flora & fauna composition.**
5. **Stations specialize in nearby-planet materials** (pricing rule below).

---

## Architecture: three nested spaces

```text
Galaxy (hyperdrive only)
  └── Solar System (system cruise)
        └── Planet envelope (atmo cruise)
              ├── Upper atmosphere  = transition + fast circumnavigation
              └── Lower atmosphere  = dogfight / biome precision
                    └── Surface site (walking/rover) = preserved mechanics
```

Shared across layers: **one planet seed / profile** (biomes, elements, flora/fauna kits, station specialty).

---

## A. Solar-system contract (locked)

| Rule | Value |
|---|---|
| Stars per system | 1 |
| Planets per system | 2–6 |
| Stations per system | ≥ 2 |
| Stations per planet | ≤ 1 |
| Station placement | Usually near a host planet |
| Small star radius | ≥ **5×** largest planet radius |
| Large star radius | ≥ **50×** largest planet radius (rarer) |

### Visibility
- Far / galactic: system reads as **sun + point field**; planets not readable  
- Near system: planets become visible local bodies  
- Stations detectable / autopilotable inside the system  

### Travel time targets (at system-cruise max)

| Trip | Target |
|---|---|
| Neighbor planet → planet | **60 s** (band 45–90) |
| Planet → its near station | **18 s** (band 10–25) |
| Outer planet → sun limb | **90 s** (band 60–120) |

Distances = `time × systemCruiseMax`.

### Autopilot
- Lock stations and planets  
- Autopilot to stations **routes around planets** (no solid chords)

---

## B. Atmosphere contract (locked)

### Visual limb
| Layer | Radius |
|---|---|
| Core | `R` |
| Inner haze | `R × 1.02` |
| Outer haze | `R × 1.05` |

Soft alpha; stars show through the rim. **Never** use gameplay envelope thickness for the glow mesh.

### Gameplay envelope (from surface)

Scaled to the planet so you enter when the world is large in view. A fixed 12,000-unit shell started the full-screen sky while the planet was still a small disc (the Earth station sits only about 1,800 units outside that shell). The visual limb above does **not** use these depths.

| Band | Distance from surface |
|---|---|
| Lower atmosphere | `max(0.95 × R, 180)`, and at most 62% of the upper depth |
| Upper atmosphere | `max(2.8 × R, 420)` |
| Biome view (globe + rings only, not a speed zone) | within `20,000` |

Earth (`R ≈ 320`): lower about 300, upper about 900. Autopilot stops at the upper edge.

Airless worlds: no atmo bands; near-surface approach shell for landing only.

### Transition
- Enter upper atmo from space → system cruise → atmo cruise; enable horizon assist  
- Leave upper atmo → atmo cruise → system cruise; disable horizon lock  
- Hyperdrive blocked in both atmo bands  

---

## C. Speed regimes (locked)

Let **`A = atmosphericBaseMax = 24`** (lower-atmo non-boost ceiling / dogfight-readable).

| Mode | Multiplier | Absolute (u/s) |
|---|---|---|
| Lower atmo cruise | `1.0 × A` | 24 |
| Lower atmo speed button | `1.75 × A` | 42 |
| Upper atmo cruise | `5.0 × A` | 120 |
| Upper atmo + speed button | `10 × A` | 240 |
| System cruise | `32 × A` | 768 |
| Hyperdrive | `20 × system` | 15_360 |

Ship space max outside atmo (pre-hyper) = system cruise. Hyperdrive remains inter-system only.

---

## D. Station material specialization & pricing (locked)

- Each station anchors to one **host planet**  
- Specializes in that planet’s **material family** (congruency / Element Codex pools)

### Buy prices (station pays the player)

| Goods origin | Multiplier vs baseline |
|---|---|
| Host planet (specialty) | **0.55×** (lowest) |
| Other planets in same solar system | **1.00×** |
| Outside this solar system | **1.65×** (highest) |

Local dump market + haul incentive. Sell-to-player pricing is a later phase.

---

## E. Surface scale

- **Long-term:** reduce reliance on 50× exit rescale once ship-scale worlds feel large  
- **Until then:** preserve walking/rover mechanics; 50× remains an allowed interim

---

## F. Must not change (first passes)

- Walking / rover control mapping and speed feel  
- Tool gestures, inventory equip/activate patterns  
- Landing / takeoff / dock / examine verb flows  
- Hyperdrive spool UX concept  

---

## G. Implementation order

1. ~~Freeze this contract~~  
2. Solar-system container + visibility + station specialty binding  
3. Speed regimes + upper-atmo transition  
4. Visual limb vs gameplay envelope split (finalize planet look)  
5. Shared biome map → orbital + atmo LOD + surface kits  
6. Station buy pricing using source-planet tags  
7. Revisit surface 50× only if ship-scale worlds already feel large  

---

*Approved checklist items 1–9 as proposed (midpoints locked).*
