import Foundation
import simd
import UIKit

enum SurfaceBiome: String, Sendable {
    case jungle
    case forest
    case plains
    case desert
    case rocky
    case ocean
    case volcanic
    case cold
}

enum SurfaceRelief: String, Sendable {
    case flat
    case hill
    case valley
    case mountain
    case ravine
}

enum SurfaceBorder: String, Sendable {
    case none
    case waterfall
    case river
    case iceEdge
    case melt
}

enum PlanetClimate: Sendable {
    case gas
    case airless
    case oceanPrimary
    case icePrimary
    case volcanicPrimary
    case mixed
}

enum RingProminence: Sendable {
    case none
    case faint
    case prominent
}

struct PlanetRingLayout {
    var innerRadius: Float
    var outerRadius: Float
    var thickness: Float
    var alpha: CGFloat
    var color: UIColor
    var clumpCount: Int
    var clumpSeed: Float
}

struct PlanetSurfaceSample {
    var biome: SurfaceBiome
    var neighbor: SurfaceBiome?
    var blend: Float
    var relief: SurfaceRelief
    var height: Float
    var frozenForest: Bool
    var border: SurfaceBorder
    var hasSurface: Bool
    var supportsLife: Bool
    var liquidCovered: Bool
    var liquidColor: UIColor
    var groundColor: UIColor
    var trunkColor: UIColor
    var canopyColor: UIColor

    var shellLift: Float {
        let lift: Float = switch relief {
        case .mountain: 0.022
        case .hill: 0.008
        case .flat: 0
        case .valley: -0.007
        case .ravine: -0.016
        }
        return liquidCovered ? min(lift, -0.004) : lift
    }

    var treeAttempts: Int {
        guard supportsLife else { return 0 }
        switch biome {
        case .jungle: return 14
        case .forest: return 7
        case .cold: return frozenForest ? 4 : 0
        default: return 0
        }
    }

    var treeHeightScale: Float {
        switch biome {
        case .jungle: return 1.85
        case .forest: return 1
        case .cold: return frozenForest ? 0.58 : 1
        default: return 1
        }
    }

    /// Counts per streamed tile. All three species stay in the table even
    /// when a tile rolls the low end of the range.
    var creatureRange: ClosedRange<Int> {
        guard supportsLife else { return 0...0 }
        switch biome {
        case .jungle: return 8...12
        case .forest: return 3...5
        case .cold: return frozenForest ? 2...4 : 1...2
        case .plains: return 2...3
        case .ocean: return 3...4
        case .rocky: return 1...2
        case .desert, .volcanic: return 0...1
        }
    }

    fileprivate static func gasPlaceholder(
        liquid: UIColor
    ) -> PlanetSurfaceSample {
        PlanetSurfaceSample(
            biome: .rocky,
            neighbor: nil,
            blend: 0,
            relief: .flat,
            height: 0,
            frozenForest: false,
            border: .none,
            hasSurface: false,
            supportsLife: false,
            liquidCovered: false,
            liquidColor: liquid,
            groundColor: liquid,
            trunkColor: .darkGray,
            canopyColor: .darkGray
        )
    }
}

enum PlanetSurfaceField {
    /// Keep the cockpit above the ground mesh.
    static let shipSurfaceClearance: Float = 4

    /// Radius of the drawn ground at one crust direction. Walking, landing,
    /// and the planet mesh all use this, so feet stay on the surface.
    static func closeSurfaceRadius(
        bodyRadius: Float,
        shellLift: Float
    ) -> Float {
        bodyRadius * (1 + shellLift)
    }

    static func shipSurfaceRadius(
        bodyRadius: Float,
        shellLift: Float
    ) -> Float {
        closeSurfaceRadius(bodyRadius: bodyRadius, shellLift: shellLift)
            + shipSurfaceClearance
    }

    static func climate(for body: CelestialBodyDescriptor) -> PlanetClimate {
        if body.kind == .star || body.kind == .gas { return .gas }
        if !body.hasAtmosphere { return .airless }
        switch body.kind {
        case .ocean: return .oceanPrimary
        case .ice: return .icePrimary
        case .desert:
            return hash01(body.name, salt: 21) < 0.5
                ? .volcanicPrimary
                : .mixed
        case .rocky, .gas, .star:
            return .mixed
        }
    }

    static func sample(
        body: CelestialBodyDescriptor,
        direction: SIMD3<Float>
    ) -> PlanetSurfaceSample {
        let liquid = liquidColor(name: body.name)
        let climate = climate(for: body)
        guard climate != .gas, simd_length(direction) > 0.0001 else {
            return .gasPlaceholder(liquid: liquid)
        }
        let direction = simd_normalize(direction)
        let nameHash = hash64(body.name, salt: 0)
        let here = evaluate(
            body: body,
            direction: direction,
            climate: climate,
            nameHash: nameHash
        )
        let nudge = neighborDirection(direction, name: body.name)
        let there = evaluate(
            body: body,
            direction: nudge.direction,
            climate: climate,
            nameHash: nameHash
        )
        var liquidCovered = here.liquidCovered
        if here.height < 0,
           there.biome == .ocean,
           here.biome != .ocean,
           here.biome != .cold,
           here.biome != .volcanic,
           climate != .airless {
            liquidCovered = true
        }
        let border = borderFeature(
            here: here,
            there: there,
            blend: nudge.blend,
            climate: climate
        )
        let ownColor = shadedColor(
            base: biomeColor(name: body.name, biome: here.biome, liquid: liquid),
            relief: here.relief,
            liquid: liquidCovered,
            liquidColor: liquid
        )
        let neighborColor = shadedColor(
            base: biomeColor(name: body.name, biome: there.biome, liquid: liquid),
            relief: there.relief,
            liquid: there.liquidCovered,
            liquidColor: liquid
        )
        let ground = mix(ownColor, neighborColor, nudge.blend * 0.7)
        let vegetation = vegetationColors(
            name: body.name,
            biome: here.biome,
            frozenForest: here.frozenForest
        )
        return PlanetSurfaceSample(
            biome: here.biome,
            neighbor: nudge.blend > 0 ? there.biome : nil,
            blend: nudge.blend,
            relief: here.relief,
            height: here.height,
            frozenForest: here.frozenForest,
            border: border,
            hasSurface: true,
            supportsLife: climate != .airless,
            liquidCovered: liquidCovered,
            liquidColor: liquid,
            groundColor: ground,
            trunkColor: vegetation.trunk,
            canopyColor: vegetation.canopy
        )
    }

    static func species(
        biome: SurfaceBiome,
        planetName: String
    ) -> [String] {
        let tag =
            planetName.split(separator: " ").first.map(String.init)
            ?? planetName
        let bases: [String] = switch biome {
        case .jungle:
            ["Canopy Howler", "Vine Stalker", "Bloom Grazer"]
        case .forest:
            ["Bark Runner", "Glen Grazer", "Thicket Stalker"]
        case .plains:
            ["Steppe Runner", "Plain Grazer", "Wind Stalker"]
        case .desert:
            ["Dune Skitter", "Ember Horn", "Sand Prowler"]
        case .rocky:
            ["Slate Runner", "Cave Grazer", "Crag Stalker"]
        case .ocean:
            ["Reef Strider", "Tide Grazer", "Shoal Prowler"]
        case .volcanic:
            ["Cinder Skitter", "Ash Horn", "Magma Stalker"]
        case .cold:
            ["Frost Hopper", "Snow Grazer", "Ice Stalker"]
        }
        return bases.map { "\(tag) \($0)" }
    }

    static func hostileSpeciesIndex(
        planetName: String,
        biome: SurfaceBiome
    ) -> Int {
        Int(hash64(planetName + biome.rawValue, salt: 5) % 3)
    }

    static func unitValue(name: String, salt: UInt64) -> Float {
        hash01(name, salt: salt)
    }

    static func gasBandColor(name: String, band: Int) -> UIColor {
        let base = hash01(name, salt: 4)
        let shift = Float(abs(band) % 6) * 0.035
        return UIColor(
            hue: CGFloat((base + shift * 0.15).truncatingRemainder(dividingBy: 1)),
            saturation: CGFloat(0.28 + shift),
            brightness: CGFloat(0.42 + shift * 1.4),
            alpha: 1
        )
    }

    static func ringProminence(
        name: String,
        kind: CelestialBodyKind
    ) -> RingProminence {
        if kind == .star { return .none }
        if name == "Saturn" { return .prominent }
        if name == "Earth" || name == "Moon" || name == "Mars" {
            return .none
        }
        let roll = hash01(name, salt: 77)
        if roll < 0.40 { return .none }
        if roll < 0.72 { return .faint }
        return .prominent
    }

    static func ringLayout(
        for body: CelestialBodyDescriptor
    ) -> PlanetRingLayout? {
        guard body.kind != .star, body.hasRings else { return nil }
        var prominence = ringProminence(name: body.name, kind: body.kind)
        if prominence == .none { prominence = .faint }
        let roll = hash01(body.name, salt: 78)
        let innerScale = 1.28 + roll * 0.32
        let band = prominence == .prominent
            ? 0.9 + roll * 0.75
            : 0.26 + roll * 0.28
        let tint = mix(
            UIColor(red: 0.86, green: 0.78, blue: 0.62, alpha: 1),
            UIColor(red: 0.72, green: 0.78, blue: 0.84, alpha: 1),
            hash01(body.name, salt: 79)
        )
        return PlanetRingLayout(
            innerRadius: body.radius * innerScale,
            outerRadius: body.radius * (innerScale + band),
            thickness: max(
                1.4,
                body.radius
                    * (prominence == .prominent
                        ? 0.012 + roll * 0.018
                        : 0.004 + roll * 0.006)
            ),
            alpha: prominence == .prominent
                ? CGFloat(0.38 + roll * 0.22)
                : CGFloat(0.12 + roll * 0.1),
            color: tint,
            clumpCount: prominence == .prominent ? 8 : 3,
            clumpSeed: roll * 6.28
        )
    }

    static func mineralKind(
        for biome: SurfaceBiome,
        fallback: CelestialBodyKind
    ) -> CelestialBodyKind {
        switch biome {
        case .ocean: .ocean
        case .desert, .volcanic: .desert
        case .cold: .ice
        case .rocky: .rocky
        case .jungle, .forest, .plains:
            switch fallback {
            case .desert: .desert
            case .ice: .ice
            case .rocky: .rocky
            default: .ocean
            }
        }
    }

    // MARK: - Evaluation

    private struct Evaluation {
        var biome: SurfaceBiome
        var relief: SurfaceRelief
        var height: Float
        var frozenForest: Bool
        var liquidCovered: Bool
    }

    private struct NeighborNudge {
        var direction: SIMD3<Float>
        var blend: Float
    }

    private static func evaluate(
        body: CelestialBodyDescriptor,
        direction: SIMD3<Float>,
        climate: PlanetClimate,
        nameHash: UInt64
    ) -> Evaluation {
        let cell = cellCoordinate(direction, name: body.name)
        let raw = rawBiome(cell: cell, climate: climate, nameHash: nameHash)
        let heat = volcanicHeat(
            cell: cell,
            climate: climate,
            nameHash: nameHash
        )
        let cold = coldField(direction, name: body.name)
        let roll = cellHash(cell, nameHash: nameHash, salt: 3)
        var biome = resolveBiome(
            climate: climate,
            raw: raw,
            heat: heat,
            cold: cold,
            roll: roll
        )
        let reliefNoise = reliefField(direction, name: body.name)
        var relief: SurfaceRelief
        var height: Float
        if reliefNoise > 0.55 {
            relief = .mountain
            height = 0.82
        } else if reliefNoise > 0.22 {
            relief = .hill
            height = 0.34
        } else if reliefNoise < -0.55 {
            relief = .ravine
            height = -0.8
        } else if reliefNoise < -0.2 {
            relief = .valley
            height = -0.32
        } else {
            relief = .flat
            height = 0.02
        }
        var liquidCovered = false
        if biome == .ocean {
            if relief == .mountain || relief == .hill {
                biome = relief == .mountain ? .rocky : .plains
            } else {
                height = min(height, -0.18)
                liquidCovered = climate != .airless
            }
        }
        let forestNoise = sin(
            direction.x * 8.4 + hash01(body.name, salt: 15) * 6
        ) * cos(direction.z * 7.1 - hash01(body.name, salt: 16) * 5)
        let frozenForest =
            biome == .cold
            && climate != .airless
            && forestNoise > -0.05
        return Evaluation(
            biome: biome,
            relief: relief,
            height: height,
            frozenForest: frozenForest,
            liquidCovered: liquidCovered
        )
    }

    private static func resolveBiome(
        climate: PlanetClimate,
        raw: SurfaceBiome,
        heat: Float,
        cold: Float,
        roll: Float
    ) -> SurfaceBiome {
        switch climate {
        case .gas:
            return .rocky
        case .airless:
            return cold > 0.18 ? .cold : .rocky
        case .icePrimary:
            if raw == .volcanic { return .volcanic }
            if heat > 0.78 {
                return roll < 0.34
                    ? .ocean
                    : (roll < 0.62 ? .jungle : .forest)
            }
            if heat > 0.5 { return roll < 0.7 ? .forest : .jungle }
            if heat > 0.28 { return .plains }
            return .cold
        case .volcanicPrimary:
            if heat < 0.12 && cold > 0.62 && roll < 0.1 { return .cold }
            if raw == .cold { return .volcanic }
            return raw
        case .oceanPrimary:
            if cold > 0.5 && heat < 0.2 && roll < 0.28 { return .cold }
            return raw
        case .mixed:
            if heat > 0.8 { return .volcanic }
            if cold > 0.45 && heat < 0.2 { return .cold }
            return raw
        }
    }

    private static func rawBiome(
        cell: SIMD3<Int>,
        climate: PlanetClimate,
        nameHash: UInt64
    ) -> SurfaceBiome {
        let roll = cellHash(cell, nameHash: nameHash, salt: 1)
        switch climate {
        case .gas, .airless:
            return .rocky
        case .icePrimary:
            if roll < 0.08 { return .volcanic }
            if roll < 0.14 { return .rocky }
            return .cold
        case .volcanicPrimary:
            if roll < 0.68 { return .volcanic }
            if roll < 0.82 { return .desert }
            if roll < 0.92 { return .rocky }
            if roll < 0.97 { return .plains }
            return .cold
        case .oceanPrimary:
            if roll < 0.64 { return .ocean }
            if roll < 0.74 { return .forest }
            if roll < 0.82 { return .plains }
            if roll < 0.88 { return .jungle }
            if roll < 0.93 { return .desert }
            if roll < 0.97 { return .rocky }
            return .volcanic
        case .mixed:
            let kinds: [SurfaceBiome] = [
                .jungle, .forest, .plains, .desert,
                .rocky, .ocean, .volcanic, .cold
            ]
            return kinds[min(kinds.count - 1, Int(roll * Float(kinds.count)))]
        }
    }

    private static func volcanicHeat(
        cell: SIMD3<Int>,
        climate: PlanetClimate,
        nameHash: UInt64
    ) -> Float {
        if climate == .airless || climate == .gas { return 0 }
        var best: Float = 0
        for z in -2...2 {
            for y in -2...2 {
                for x in -2...2 {
                    let neighbor = SIMD3<Int>(
                        cell.x + x,
                        cell.y + y,
                        cell.z + z
                    )
                    guard rawBiome(
                        cell: neighbor,
                        climate: climate,
                        nameHash: nameHash
                    ) == .volcanic else { continue }
                    let distance = Float(max(abs(x), abs(y), abs(z)))
                    best = max(best, 1 - distance / 3)
                }
            }
        }
        return best
    }

    private static func borderFeature(
        here: Evaluation,
        there: Evaluation,
        blend: Float,
        climate: PlanetClimate
    ) -> SurfaceBorder {
        guard climate != .airless, blend > 0.42 else { return .none }
        let oceanMeetsRavine =
            (here.biome == .ocean && there.relief == .ravine)
            || (there.biome == .ocean && here.relief == .ravine)
        if oceanMeetsRavine { return .waterfall }
        let highGround =
            here.relief == .mountain || here.relief == .hill
        if highGround && there.biome == .ocean { return .river }
        if (here.biome == .cold && there.biome == .ocean)
            || (here.biome == .ocean && there.biome == .cold) {
            return .iceEdge
        }
        if (here.biome == .cold && there.biome == .volcanic)
            || (here.biome == .volcanic && there.biome == .cold) {
            return .melt
        }
        return .none
    }

    private static func neighborDirection(
        _ direction: SIMD3<Float>,
        name: String
    ) -> NeighborNudge {
        let point = warped(direction, name: name)
        let local = SIMD3<Float>(
            point.x - floor(point.x),
            point.y - floor(point.y),
            point.z - floor(point.z)
        )
        let edges: [(Float, Int, Float)] = [
            (local.x, 0, -1),
            (1 - local.x, 0, 1),
            (local.y, 1, -1),
            (1 - local.y, 1, 1),
            (local.z, 2, -1),
            (1 - local.z, 2, 1)
        ]
        let nearest = edges.min { $0.0 < $1.0 } ?? (1, 0, 1)
        let blendWidth: Float = 0.16
        let blend =
            nearest.0 < blendWidth
            ? (1 - nearest.0 / blendWidth) * 0.85
            : 0
        var nudged = direction
        nudged[nearest.1] += nearest.2 * 0.22
        return NeighborNudge(
            direction: simd_normalize(nudged),
            blend: blend
        )
    }

    // MARK: - Fields

    private static func warped(
        _ direction: SIMD3<Float>,
        name: String
    ) -> SIMD3<Float> {
        let seed = hash01(name, salt: 1) * 10
        let amplitude: Float = 0.42 + hash01(name, salt: 2) * 0.35
        let frequency: Float = 2.2 + hash01(name, salt: 3) * 1.4
        let warp = SIMD3<Float>(
            sin(direction.y * frequency + seed),
            sin(direction.z * frequency * 1.07 + seed * 1.3),
            sin(direction.x * frequency * 0.93 + seed * 0.7)
        ) * amplitude
        let scale: Float = 2.4 + hash01(name, salt: 4) * 2.8
        return direction * scale + warp
    }

    private static func cellCoordinate(
        _ direction: SIMD3<Float>,
        name: String
    ) -> SIMD3<Int> {
        let point = warped(direction, name: name)
        return SIMD3<Int>(
            Int(floor(point.x)),
            Int(floor(point.y)),
            Int(floor(point.z))
        )
    }

    private static func coldField(
        _ direction: SIMD3<Float>,
        name: String
    ) -> Float {
        let seed = hash01(name, salt: 9) * 8
        let point = warped(direction, name: name) * 0.37
        let blobs =
            sin(point.x * 1.35 + seed) * cos(point.z * 1.15 - seed)
        let belt = sin(point.y * 1.8 + point.x * 0.4 + seed * 0.6)
        return blobs * 0.7 + belt * 0.45
    }

    private static func reliefField(
        _ direction: SIMD3<Float>,
        name: String
    ) -> Float {
        let seed = hash01(name, salt: 8) * 8
        let coarse =
            sin(direction.x * 3.1 + seed)
            * cos(direction.z * 2.7 - seed)
        let mid = sin(direction.y * 4.4 + direction.x * 1.2 + seed)
        let fine = cos((direction.x + direction.z) * 5.6 + seed * 0.4)
        return coarse * 0.5 + mid * 0.32 + fine * 0.22
    }

    // MARK: - Color

    static func liquidColor(name: String) -> UIColor {
        let palette: [UIColor] = [
            UIColor(red: 0.05, green: 0.32, blue: 0.72, alpha: 1),
            UIColor(red: 0.02, green: 0.52, blue: 0.58, alpha: 1),
            UIColor(red: 0.08, green: 0.42, blue: 0.28, alpha: 1),
            UIColor(red: 0.28, green: 0.18, blue: 0.62, alpha: 1),
            UIColor(red: 0.12, green: 0.48, blue: 0.62, alpha: 1),
            UIColor(red: 0.42, green: 0.30, blue: 0.12, alpha: 1)
        ]
        let index = Int(hash01(name, salt: 11) * Float(palette.count - 1) + 0.001)
        let next = min(palette.count - 1, index + 1)
        return mix(palette[index], palette[next], hash01(name, salt: 12))
    }

    private static func biomeColor(
        name: String,
        biome: SurfaceBiome,
        liquid: UIColor
    ) -> UIColor {
        let roll = hash01(name + biome.rawValue, salt: 12)
        switch biome {
        case .jungle:
            return mix(
                UIColor(red: 0.02, green: 0.28, blue: 0.08, alpha: 1),
                UIColor(red: 0.08, green: 0.46, blue: 0.14, alpha: 1),
                roll
            )
        case .forest:
            return mix(
                UIColor(red: 0.08, green: 0.38, blue: 0.12, alpha: 1),
                UIColor(red: 0.18, green: 0.48, blue: 0.16, alpha: 1),
                roll
            )
        case .plains:
            return mix(
                UIColor(red: 0.62, green: 0.56, blue: 0.28, alpha: 1),
                UIColor(red: 0.46, green: 0.58, blue: 0.24, alpha: 1),
                roll
            )
        case .desert:
            return mix(
                UIColor(red: 0.78, green: 0.58, blue: 0.28, alpha: 1),
                UIColor(red: 0.62, green: 0.34, blue: 0.14, alpha: 1),
                roll
            )
        case .rocky:
            return mix(
                UIColor(red: 0.38, green: 0.36, blue: 0.34, alpha: 1),
                UIColor(red: 0.24, green: 0.22, blue: 0.22, alpha: 1),
                roll
            )
        case .ocean:
            return liquid
        case .volcanic:
            return mix(
                UIColor(red: 0.16, green: 0.05, blue: 0.04, alpha: 1),
                UIColor(red: 0.42, green: 0.10, blue: 0.04, alpha: 1),
                roll
            )
        case .cold:
            return mix(
                UIColor(red: 0.90, green: 0.94, blue: 0.96, alpha: 1),
                UIColor(red: 0.68, green: 0.80, blue: 0.88, alpha: 1),
                roll
            )
        }
    }

    private static func shadedColor(
        base: UIColor,
        relief: SurfaceRelief,
        liquid: Bool,
        liquidColor: UIColor
    ) -> UIColor {
        let source = liquid ? liquidColor : base
        switch relief {
        case .mountain:
            return mix(source, .white, liquid ? 0.08 : 0.28)
        case .hill:
            return mix(source, .white, liquid ? 0.04 : 0.12)
        case .flat:
            return source
        case .valley:
            return mix(source, .black, 0.18)
        case .ravine:
            return mix(source, .black, liquid ? 0.28 : 0.4)
        }
    }

    private static func vegetationColors(
        name: String,
        biome: SurfaceBiome,
        frozenForest: Bool
    ) -> (trunk: UIColor, canopy: UIColor) {
        if frozenForest {
            return (
                UIColor(red: 0.62, green: 0.68, blue: 0.72, alpha: 1),
                UIColor(red: 0.82, green: 0.90, blue: 0.93, alpha: 1)
            )
        }
        let roll = hash01(name + biome.rawValue, salt: 18)
        let canopy = switch biome {
        case .jungle:
            mix(
                UIColor(red: 0.02, green: 0.30, blue: 0.06, alpha: 1),
                UIColor(red: 0.10, green: 0.48, blue: 0.12, alpha: 1),
                roll
            )
        case .forest:
            mix(
                UIColor(red: 0.06, green: 0.40, blue: 0.10, alpha: 1),
                UIColor(red: 0.16, green: 0.52, blue: 0.18, alpha: 1),
                roll
            )
        default:
            mix(
                UIColor(red: 0.10, green: 0.36, blue: 0.12, alpha: 1),
                UIColor(red: 0.20, green: 0.44, blue: 0.16, alpha: 1),
                roll
            )
        }
        let trunk = mix(
            UIColor(red: 0.28, green: 0.14, blue: 0.06, alpha: 1),
            UIColor(red: 0.16, green: 0.09, blue: 0.05, alpha: 1),
            hash01(name, salt: 19)
        )
        return (trunk, canopy)
    }

    private static func mix(_ a: UIColor, _ b: UIColor, _ amount: Float) -> UIColor {
        var ar: CGFloat = 0
        var ag: CGFloat = 0
        var ab: CGFloat = 0
        var aa: CGFloat = 0
        var br: CGFloat = 0
        var bg: CGFloat = 0
        var bb: CGFloat = 0
        var ba: CGFloat = 0
        a.getRed(&ar, green: &ag, blue: &ab, alpha: &aa)
        b.getRed(&br, green: &bg, blue: &bb, alpha: &ba)
        let t = CGFloat(max(0, min(1, amount)))
        return UIColor(
            red: ar + (br - ar) * t,
            green: ag + (bg - ag) * t,
            blue: ab + (bb - ab) * t,
            alpha: 1
        )
    }

    // MARK: - Hash

    private static func hash64(_ text: String, salt: UInt64) -> UInt64 {
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325 ^ salt
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x1000_0000_01B3
        }
        return hash
    }

    private static func hash01(_ text: String, salt: UInt64) -> Float {
        Float(hash64(text, salt: salt) % 10_000) / 10_000
    }

    private static func cellHash(
        _ cell: SIMD3<Int>,
        nameHash: UInt64,
        salt: UInt64
    ) -> Float {
        var hash = nameHash ^ salt
        hash ^= UInt64(bitPattern: Int64(cell.x)) &* 0x9E37_79B9
        hash ^= UInt64(bitPattern: Int64(cell.y)) &* 0xC2B2_AE3D
        hash ^= UInt64(bitPattern: Int64(cell.z)) &* 0x1656_67B1
        hash = hash &* 0x1000_0000_01B3
        return Float(hash % 10_000) / 10_000
    }
}
