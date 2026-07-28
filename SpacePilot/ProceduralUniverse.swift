import Foundation
import RealityKit
import simd
import UIKit

struct SurfacePickup {
    enum Category: Codable, Equatable, Sendable {
        case log
        case mineral
        case electronic
        case creatureMaterial
    }

    let materialName: String
    let category: Category
    let sourcePlanetIdentifier: String
    let sourcePlanetName: String
    let sourcePlanetKind: CelestialBodyKind
}

enum UniverseScale {
    static let celestialBody: Float = 100
    static let distance: Float = 100
    static let station: Float = 25
    static let stationRadius: Float = 8 * station
    static let stationDockingDistance: Float = 300
    static let wreckage: Float = 4
    static let wreckageRadius: Float = 7 * wreckage
    static let surfaceEyeHeight: Float = 1

    static func upperAtmosphereDepth(for radius: Float) -> Float {
        max(radius * 3, 700)
    }

    static func lowerAtmosphereDepth(for radius: Float) -> Float {
        radius * 0.32
    }
}

struct GalacticSector: Codable, Hashable, Sendable {
    var x: Int64
    var y: Int64
    var z: Int64

    static let origin = GalacticSector(x: 0, y: 0, z: 0)

    static func + (lhs: GalacticSector, rhs: GalacticSector) -> GalacticSector {
        GalacticSector(x: lhs.x + rhs.x, y: lhs.y + rhs.y, z: lhs.z + rhs.z)
    }
}

struct GalacticPosition: Sendable {
    static let sectorSize = 12_000.0 * Double(UniverseScale.distance)
    static let halfSectorSize = sectorSize / 2
    static let origin = GalacticPosition(sector: .origin, local: .zero)

    var sector: GalacticSector
    var local: SIMD3<Double>

    mutating func translate(by delta: SIMD3<Double>) {
        local += delta
        normalize()
    }

    func vector(to sector: GalacticSector, local target: SIMD3<Double>) -> SIMD3<Double> {
        let sectorDelta = SIMD3<Double>(
            Double(sector.x - self.sector.x),
            Double(sector.y - self.sector.y),
            Double(sector.z - self.sector.z)
        ) * Self.sectorSize
        return sectorDelta + target - local
    }

    private mutating func normalize() {
        while local.x >= Self.halfSectorSize {
            local.x -= Self.sectorSize
            sector.x += 1
        }
        while local.x < -Self.halfSectorSize {
            local.x += Self.sectorSize
            sector.x -= 1
        }
        while local.y >= Self.halfSectorSize {
            local.y -= Self.sectorSize
            sector.y += 1
        }
        while local.y < -Self.halfSectorSize {
            local.y += Self.sectorSize
            sector.y -= 1
        }
        while local.z >= Self.halfSectorSize {
            local.z -= Self.sectorSize
            sector.z += 1
        }
        while local.z < -Self.halfSectorSize {
            local.z += Self.sectorSize
            sector.z -= 1
        }
    }
}

enum CelestialBodyKind: Codable, Equatable, Sendable {
    case star
    case ocean
    case desert
    case rocky
    case ice
    case gas
}

struct CelestialBodyDescriptor: Sendable {
    let name: String
    let kind: CelestialBodyKind
    let radius: Float
    let localPosition: SIMD3<Double>
    let hasRings: Bool
    let hasAtmosphere: Bool
}

enum PointOfInterestKind: String, Sendable {
    case wreckage
    case station

    var displayName: String {
        switch self {
        case .wreckage: "WRECKAGE"
        case .station: "STATION"
        }
    }
}

struct PointOfInterestDescriptor: Sendable {
    let name: String
    let kind: PointOfInterestKind
    let localPosition: SIMD3<Double>
    let orientation: SIMD3<Float>
}

struct ProceduralRegion: Sendable {
    let sector: GalacticSector
    let bodies: [CelestialBodyDescriptor]
    let pointsOfInterest: [PointOfInterestDescriptor]
    let stars: [SIMD3<Float>]
}

struct ProceduralUniverseGenerator: Sendable {
    let universeSeed: UInt64

    func region(at sector: GalacticSector) -> ProceduralRegion {
        if sector == .origin {
            return startingRegion()
        }

        var random = UniverseRandom(seed: seed(for: sector))
        let bodyCount = random.int(in: 1...3)
        var bodies: [CelestialBodyDescriptor] = []
        bodies.reserveCapacity(bodyCount)

        let syllables = ["Astra", "Cinder", "Eos", "Khepri", "Nysa", "Orion", "Rhea", "Vela", "Zephyr"]
        let suffixes = ["I", "II", "III", "Prime", "Minor", "Haven", "Reach"]

        for index in 0..<bodyCount {
            let isStar = index == 0 && random.chance(0.22)
            let kind: CelestialBodyKind = isStar
                ? .star
                : [.ocean, .desert, .rocky, .ice, .gas][random.int(in: 0...4)]
            let baseRadius: Float = isStar
                ? random.float(in: 4.5...8.5)
                : random.float(in: 1.4...5.8)
            let radius = baseRadius * UniverseScale.celestialBody
            let name = "\(syllables[random.int(in: 0...(syllables.count - 1))]) \(suffixes[random.int(in: 0...(suffixes.count - 1))])"
            let position = spacedBodyPosition(existing: bodies, random: &random)
            let hasAtmosphere: Bool = switch kind {
            case .star:
                false
            case .ocean:
                random.chance(0.92)
            case .desert:
                random.chance(0.68)
            case .rocky:
                random.chance(0.34)
            case .ice:
                random.chance(0.52)
            case .gas:
                true
            }
            bodies.append(
                CelestialBodyDescriptor(
                    name: name,
                    kind: kind,
                    radius: radius,
                    localPosition: position,
                    hasRings: kind == .gas && random.chance(0.45),
                    hasAtmosphere: hasAtmosphere
                )
            )
        }

        let stars = (0..<12).map { _ in
            SIMD3<Float>(
                random.float(in: -5_800...5_800) * UniverseScale.distance,
                random.float(in: -5_800...5_800) * UniverseScale.distance,
                random.float(in: -5_800...5_800) * UniverseScale.distance
            )
        }
        let pointsOfInterest = makePointsOfInterest(
            near: bodies,
            random: &random
        )
        return ProceduralRegion(
            sector: sector,
            bodies: bodies,
            pointsOfInterest: pointsOfInterest,
            stars: stars
        )
    }

    private func makePointsOfInterest(
        near bodies: [CelestialBodyDescriptor],
        random: inout UniverseRandom
    ) -> [PointOfInterestDescriptor] {
        let count = random.chance(0.68) ? 1 : 2
        var points: [PointOfInterestDescriptor] = []
        let stationNames = ["Wayfarer Exchange", "Farpoint Relay", "Helios Anchorage", "Frontier Depot"]
        let wreckageNames = ["Silent Convoy", "Broken Spear", "Lost Surveyor", "Drifting Ark"]

        for _ in 0..<count {
            let kind: PointOfInterestKind = random.chance(0.42) ? .station : .wreckage
            let names = kind == .station ? stationNames : wreckageNames
            points.append(
                PointOfInterestDescriptor(
                    name: names[random.int(in: 0...(names.count - 1))],
                    kind: kind,
                    localPosition: spacedPointOfInterestPosition(
                        bodies: bodies,
                        existing: points,
                        kind: kind,
                        random: &random
                    ),
                    orientation: SIMD3<Float>(
                        random.float(in: -.pi ... .pi),
                        random.float(in: -.pi ... .pi),
                        random.float(in: -.pi ... .pi)
                    )
                )
            )
        }
        return points
    }

    private func spacedPointOfInterestPosition(
        bodies: [CelestialBodyDescriptor],
        existing points: [PointOfInterestDescriptor],
        kind: PointOfInterestKind,
        random: inout UniverseRandom
    ) -> SIMD3<Double> {
        let distanceScale = Double(UniverseScale.distance)
        let candidateRadius = Double(
            kind == .station
                ? UniverseScale.stationRadius
                : UniverseScale.wreckageRadius
        )
        var candidate = SIMD3<Double>.zero
        for _ in 0..<48 {
            candidate = SIMD3<Double>(
                random.double(in: -4_200...4_200) * distanceScale,
                random.double(in: -2_500...2_500) * distanceScale,
                random.double(in: -4_200...4_200) * distanceScale
            )
            let clearOfBodies = bodies.allSatisfy {
                simd_distance(candidate, $0.localPosition)
                    >= max(
                        Double($0.radius) + candidateRadius + 200,
                        1_000 * distanceScale
                    )
            }
            let clearOfOtherPoints = points.allSatisfy {
                let existingRadius = Double(
                    $0.kind == .station
                        ? UniverseScale.stationRadius
                        : UniverseScale.wreckageRadius
                )
                return simd_distance(candidate, $0.localPosition)
                    >= max(
                        candidateRadius + existingRadius + 300,
                        1_400 * distanceScale
                    )
            }
            if simd_length(candidate) >= 600 * distanceScale,
               clearOfBodies,
               clearOfOtherPoints {
                return candidate
            }
        }
        return candidate
    }

    private func spacedBodyPosition(
        existing bodies: [CelestialBodyDescriptor],
        random: inout UniverseRandom
    ) -> SIMD3<Double> {
        let distanceScale = Double(UniverseScale.distance)
        let minimumBodySpacing = 2_600.0 * distanceScale
        let clearCenterRadius = 1_800.0 * distanceScale
        var candidate = SIMD3<Double>.zero

        for _ in 0..<48 {
            candidate = SIMD3<Double>(
                random.double(in: -4_500...4_500) * distanceScale,
                random.double(in: -3_000...3_000) * distanceScale,
                random.double(in: -4_500...4_500) * distanceScale
            )
            let clearsSectorCenter = simd_length(candidate) >= clearCenterRadius
            let clearsOtherBodies = bodies.allSatisfy {
                simd_distance(candidate, $0.localPosition) >= minimumBodySpacing
            }
            if clearsSectorCenter && clearsOtherBodies {
                return candidate
            }
        }
        return candidate
    }

    private func startingRegion() -> ProceduralRegion {
        let distanceScale = Double(UniverseScale.distance)
        let bodies = [
            CelestialBodyDescriptor(name: "Sun", kind: .star, radius: 5.5 * UniverseScale.celestialBody, localPosition: SIMD3<Double>(-3_000, 1_600, -5_200) * distanceScale, hasRings: false, hasAtmosphere: false),
            CelestialBodyDescriptor(name: "Earth", kind: .ocean, radius: 3.2 * UniverseScale.celestialBody, localPosition: SIMD3<Double>(1_800, -250, -3_500) * distanceScale, hasRings: false, hasAtmosphere: true),
            CelestialBodyDescriptor(name: "Moon", kind: .rocky, radius: 1.35 * UniverseScale.celestialBody, localPosition: SIMD3<Double>(4_300, 500, -4_600) * distanceScale, hasRings: false, hasAtmosphere: false),
            CelestialBodyDescriptor(name: "Mars", kind: .desert, radius: 2.5 * UniverseScale.celestialBody, localPosition: SIMD3<Double>(-4_500, -900, -2_300) * distanceScale, hasRings: false, hasAtmosphere: true),
            CelestialBodyDescriptor(name: "Saturn", kind: .gas, radius: 4.8 * UniverseScale.celestialBody, localPosition: SIMD3<Double>(3_800, 1_200, 4_200) * distanceScale, hasRings: true, hasAtmosphere: true)
        ]
        var random = UniverseRandom(seed: universeSeed ^ 0x5A17_F13D)
        let stars = (0..<96).map { _ in
            random.unitVector()
                * random.float(in: 800...5_800)
                * UniverseScale.distance
        }
        let pointsOfInterest = [
            PointOfInterestDescriptor(
                name: "Wayfarer Exchange",
                kind: .station,
                localPosition: SIMD3<Double>(-1_150, 320, 1_300) * distanceScale,
                orientation: [0.15, -0.5, 0.08]
            ),
            PointOfInterestDescriptor(
                name: "Lost Surveyor",
                kind: .wreckage,
                localPosition: SIMD3<Double>(980, -180, -1_250) * distanceScale,
                orientation: [-0.4, 0.7, 0.3]
            )
        ]
        return ProceduralRegion(
            sector: .origin,
            bodies: bodies,
            pointsOfInterest: pointsOfInterest,
            stars: stars
        )
    }

    private func seed(for sector: GalacticSector) -> UInt64 {
        var value = universeSeed
        value = mix(value ^ UInt64(bitPattern: sector.x))
        value = mix(value ^ UInt64(bitPattern: sector.y) &* 0x9E37_79B9_7F4A_7C15)
        value = mix(value ^ UInt64(bitPattern: sector.z) &* 0xD1B5_4A32_D192_ED03)
        return value
    }

    private func mix(_ value: UInt64) -> UInt64 {
        var result = value
        result ^= result >> 30
        result &*= 0xBF58_476D_1CE4_E5B9
        result ^= result >> 27
        result &*= 0x94D0_49BB_1331_11EB
        result ^= result >> 31
        return result
    }
}

enum NavigationTargetKind: Codable, Equatable, Sendable {
    case world
    case wreckage
    case station

    var displayName: String {
        switch self {
        case .world: "WORLD"
        case .wreckage: "WRECKAGE"
        case .station: "STATION"
        }
    }
}

struct NearbyNavigationTarget: Sendable {
    let identifier: String
    let name: String
    let kind: NavigationTargetKind
    let vector: SIMD3<Float>
    let distance: Float
    let radius: Float
    let celestialKind: CelestialBodyKind?
    let hasAtmosphere: Bool
}

private struct UniverseDiscoverySnapshot: Codable {
    var visitedSectors: Set<GalacticSector> = []
    var discoveredBodies: Set<String> = []
    var discoveredPointsOfInterest: Set<String>?
    var investigatedWreckage: Set<String>?
}

private struct SurfaceResourceSnapshot: Codable {
    var depletedResourceIdentifiers: Set<String> = []
}

private struct PlanetaryScanSnapshot: Codable {
    var recordsByWorldIdentifier: [String: Set<String>] = [:]
}

@MainActor
private final class PlanetaryScanStore {
    private static let storageKey = "SpacePilot.PlanetaryScans.v1"
    private var snapshot: PlanetaryScanSnapshot

    init(defaults: UserDefaults = .standard) {
        if let data = defaults.data(forKey: Self.storageKey),
           let saved = try? JSONDecoder().decode(
                PlanetaryScanSnapshot.self,
                from: data
           ) {
            snapshot = saved
        } else {
            snapshot = PlanetaryScanSnapshot()
        }
    }

    func record(
        worldIdentifier: String,
        discoveryIdentifier: String,
        defaults: UserDefaults = .standard
    ) -> (isNew: Bool, count: Int) {
        var records =
            snapshot.recordsByWorldIdentifier[worldIdentifier]
                ?? []
        let isNew = records.insert(discoveryIdentifier).inserted
        snapshot.recordsByWorldIdentifier[worldIdentifier] = records
        if isNew,
           let data = try? JSONEncoder().encode(snapshot) {
            defaults.set(data, forKey: Self.storageKey)
        }
        return (isNew, records.count)
    }
}

@MainActor
private final class SurfaceResourceStore {
    private static let storageKey =
        "SpacePilot.DepletedSurfaceResources.v1"
    private var snapshot: SurfaceResourceSnapshot

    init(defaults: UserDefaults = .standard) {
        if let data = defaults.data(forKey: Self.storageKey),
           let saved = try? JSONDecoder().decode(
                SurfaceResourceSnapshot.self,
                from: data
           ) {
            snapshot = saved
        } else {
            snapshot = SurfaceResourceSnapshot()
        }
    }

    func contains(_ identifier: String) -> Bool {
        snapshot.depletedResourceIdentifiers.contains(identifier)
    }

    func deplete(
        _ identifier: String,
        defaults: UserDefaults = .standard
    ) {
        guard snapshot.depletedResourceIdentifiers
            .insert(identifier).inserted,
            let data = try? JSONEncoder().encode(snapshot) else {
            return
        }
        defaults.set(data, forKey: Self.storageKey)
    }
}

@MainActor
private final class UniverseDiscoveryStore {
    private static let storageKey = "SpacePilot.UniverseDiscoveries.v1"
    private var snapshot: UniverseDiscoverySnapshot

    var visitedSectorCount: Int { snapshot.visitedSectors.count }
    var discoveredBodyCount: Int { snapshot.discoveredBodies.count }
    var discoveredPointOfInterestCount: Int {
        snapshot.discoveredPointsOfInterest?.count ?? 0
    }
    var investigatedWreckageCount: Int {
        snapshot.investigatedWreckage?.count ?? 0
    }

    init(defaults: UserDefaults = .standard) {
        if let data = defaults.data(forKey: Self.storageKey),
           let saved = try? JSONDecoder().decode(UniverseDiscoverySnapshot.self, from: data) {
            snapshot = saved
        } else {
            snapshot = UniverseDiscoverySnapshot()
        }
    }

    func discover(_ region: ProceduralRegion, defaults: UserDefaults = .standard) {
        let insertedSector = snapshot.visitedSectors.insert(region.sector).inserted
        var insertedBody = false
        for (index, body) in region.bodies.enumerated() {
            let identifier = "\(region.sector.x),\(region.sector.y),\(region.sector.z):\(index):\(body.name)"
            insertedBody = snapshot.discoveredBodies.insert(identifier).inserted || insertedBody
        }
        var discoveredPoints = snapshot.discoveredPointsOfInterest ?? []
        var insertedPoint = false
        for (index, point) in region.pointsOfInterest.enumerated() {
            let identifier = "\(region.sector.x),\(region.sector.y),\(region.sector.z):\(index):\(point.kind.rawValue):\(point.name)"
            insertedPoint = discoveredPoints.insert(identifier).inserted || insertedPoint
        }
        snapshot.discoveredPointsOfInterest = discoveredPoints

        guard insertedSector || insertedBody || insertedPoint,
              let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }

    func isWreckageInvestigated(_ identifier: String) -> Bool {
        snapshot.investigatedWreckage?.contains(identifier) == true
    }

    func investigateWreckage(
        _ identifier: String,
        defaults: UserDefaults = .standard
    ) {
        var investigated = snapshot.investigatedWreckage ?? []
        guard investigated.insert(identifier).inserted else { return }
        snapshot.investigatedWreckage = investigated
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: Self.storageKey)
    }
}

@MainActor
final class UniverseStreamer {
    private enum CreatureBehavior: Equatable {
        case roaming
        case pursuing
        case attacking
        case returningHome
    }

    private struct CreatureRuntimeState {
        var position: SIMD2<Double>
        var altitude: Double
        var behavior: CreatureBehavior
        var health: Float
        var stunRemaining: Float
        var retreatRemaining: Float
        var impactFlashRemaining: Float
        var crumblerFlashRemaining: Float
        var attackCooldownRemaining: Float
        var avoidanceObstacleIdentifier: String?
        var avoidanceSide: Double
    }

    private struct CreatureObstacle {
        let identifier: String
        let center: SIMD2<Double>
        let radius: Double
        let height: Double
    }

    private struct SurfaceTileCoordinate: Hashable {
        let x: Int
        let z: Int
    }

    private struct SurfaceExplorationState {
        let worldIdentifier: String
        let body: CelestialBodyDescriptor
        let bodyEntity: Entity
        let root: Entity
        let shipMarker: Entity
        let roverMarker: Entity
        let anchorNormal: SIMD3<Float>
        let tangentRight: SIMD3<Float>
        let tangentForward: SIMD3<Float>
        let effectiveRadius: Float
        let biomeCenterX: Float
        let biomeCenterZ: Float
        let biomeHalfWidth: Float
        let biomeHalfDepth: Float
        var loadedTiles: [SurfaceTileCoordinate: Entity]
        var resourceHealth: [ObjectIdentifier: Float]
        var creatureStates: [String: CreatureRuntimeState]
        var wildlifeAnimationTime: Float
        var pendingCreatureHits: Int
        var pendingCreatureKnockback: SIMD3<Float>
    }

    private let root: Entity
    private let generator: ProceduralUniverseGenerator
    private let planetaryScans = PlanetaryScanStore()
    private var loadedRegions: [GalacticSector: (descriptor: ProceduralRegion, entity: Entity)] = [:]
    private var regionChildSimulationPositions:
        [ObjectIdentifier: SIMD3<Double>] = [:]
    private var renderOrigin: GalacticPosition?
    private var centerSector: GalacticSector?
    private var streamingTask: Task<Void, Never>?
    private var surfaceExplorationState: SurfaceExplorationState?
    private let discoveries = UniverseDiscoveryStore()
    private let surfaceResources = SurfaceResourceStore()
    private let streamingRadius: Int64 = 1
    private let surfacePerspectiveScale: Float = 24
    private let surfaceTileSize: Float = 54
    private let surfaceTileRadius = 1
    private let expandedBiomeElevation: Float = 0.32

    var visitedSectorCount: Int { discoveries.visitedSectorCount }
    var discoveredBodyCount: Int { discoveries.discoveredBodyCount }
    var discoveredPointOfInterestCount: Int {
        discoveries.discoveredPointOfInterestCount
    }
    var investigatedWreckageCount: Int {
        discoveries.investigatedWreckageCount
    }

    init(root: Entity, universeSeed: UInt64 = 0x5350_4143_4550_494C) {
        self.root = root
        generator = ProceduralUniverseGenerator(universeSeed: universeSeed)
    }

    func update(around sector: GalacticSector) {
        guard centerSector != sector else { return }
        streamingTask?.cancel()
        centerSector = sector

        var required = Set<GalacticSector>()
        for x in -streamingRadius...streamingRadius {
            for y in -streamingRadius...streamingRadius {
                for z in -streamingRadius...streamingRadius {
                    required.insert(sector + GalacticSector(x: x, y: y, z: z))
                }
            }
        }

        let obsoleteSectors = loadedRegions.keys.filter { !required.contains($0) }
        for loadedSector in obsoleteSectors {
            loadedRegions.removeValue(forKey: loadedSector)?.entity.removeFromParent()
        }

        loadRegionIfNeeded(at: sector)
        repositionRegions(relativeTo: sector)
        if let currentRegion = loadedRegions[sector]?.descriptor {
            discoveries.discover(currentRegion)
        }

        let neighboringSectors = required
            .filter { $0 != sector && loadedRegions[$0] == nil }
            .sorted {
                sectorDistance($0, from: sector)
                    < sectorDistance($1, from: sector)
            }
        streamingTask = Task { @MainActor [weak self] in
            guard let self else { return }
            for neighboringSector in neighboringSectors {
                guard !Task.isCancelled, self.centerSector == sector else {
                    return
                }
                await Task.yield()
                self.loadRegionIfNeeded(at: neighboringSector)
                self.repositionRegions(relativeTo: sector)
            }
        }
    }

    func removeAll() {
        streamingTask?.cancel()
        streamingTask = nil
        endSurfaceExploration()
        for region in loadedRegions.values {
            region.entity.removeFromParent()
        }
        loadedRegions.removeAll()
        regionChildSimulationPositions.removeAll()
        renderOrigin = nil
        centerSector = nil
    }

    func beginSurfaceExploration(
        around position: GalacticPosition
    ) -> SIMD3<Float>? {
        endSurfaceExploration()
        guard let world = nearestDestination(
            to: position,
            matching: .world
        ),
        world.celestialKind != .star,
        let record = bodyRecord(identifiedBy: world.identifier),
        world.distance > 0.001 else {
            return nil
        }

        let anchorNormal = simd_normalize(-world.vector)
        let reference =
            abs(anchorNormal.y) < 0.92
                ? SIMD3<Float>(0, 1, 0)
                : SIMD3<Float>(1, 0, 0)
        let tangentRight = simd_normalize(
            simd_cross(reference, anchorNormal)
        )
        let tangentForward = simd_normalize(
            simd_cross(anchorNormal, tangentRight)
        )
        let surfaceRoot = Entity()
        surfaceRoot.name = "Local Surface Exploration"
        record.entity.addChild(surfaceRoot)
        let shipMarker = makeSurfaceShipMarker()
        let roverMarker = makeSurfaceRoverMarker()
        roverMarker.isEnabled = false
        surfaceRoot.addChild(shipMarker)
        surfaceRoot.addChild(roverMarker)
        record.entity.findEntity(named: "Upper Atmosphere Detail")?
            .isEnabled = false
        record.entity.findEntity(named: "Lower Atmosphere Detail")?
            .isEnabled = false
        record.entity.findEntity(named: "Ground Detail")?
            .isEnabled = false
        let biome = expandedLandingBiome(
            for: record.body,
            landingNormal: anchorNormal,
            tangentRight: tangentRight,
            tangentForward: tangentForward
        )
        let effectiveRadius =
            record.body.radius * surfacePerspectiveScale
        let state = SurfaceExplorationState(
            worldIdentifier: world.identifier,
            body: record.body,
            bodyEntity: record.entity,
            root: surfaceRoot,
            shipMarker: shipMarker,
            roverMarker: roverMarker,
            anchorNormal: anchorNormal,
            tangentRight: tangentRight,
            tangentForward: tangentForward,
            effectiveRadius: effectiveRadius,
            biomeCenterX: biome.centerX,
            biomeCenterZ: biome.centerZ,
            biomeHalfWidth: biome.halfWidth,
            biomeHalfDepth: biome.halfDepth,
            loadedTiles: [:],
            resourceHealth: [:],
            creatureStates: [:],
            wildlifeAnimationTime: 0,
            pendingCreatureHits: 0,
            pendingCreatureKnockback: .zero
        )
        surfaceRoot.addChild(
            makeExplorationScalePlanetSurface(state: state)
        )
        if record.body.hasAtmosphere,
           let expandedBiome = makeExpandedBiomeSurface(state: state) {
            surfaceRoot.addChild(expandedBiome)
        }
        surfaceExplorationState = state
        let terrainElevation =
            record.body.hasAtmosphere ? expandedBiomeElevation : 0
        let desiredDistance =
            effectiveRadius
                + UniverseScale.surfaceEyeHeight
                + terrainElevation
        return anchorNormal * (desiredDistance - world.distance)
    }

    func updateSurfaceExploration(
        around position: GalacticPosition,
        deltaTime: Float = 1 / 60
    ) {
        guard var state = surfaceExplorationState,
              let world = destination(
                identifiedBy: state.worldIdentifier,
                to: position
              ),
              world.distance > 0.001 else {
            return
        }

        let surfacePoint = -world.vector
        let anchorPoint =
            state.anchorNormal
                * (state.effectiveRadius + UniverseScale.surfaceEyeHeight)
        let offset = surfacePoint - anchorPoint
        let localX = simd_dot(offset, state.tangentRight)
        let localZ = simd_dot(offset, state.tangentForward)
        let center = SurfaceTileCoordinate(
            x: Int((localX / surfaceTileSize).rounded()),
            z: Int((localZ / surfaceTileSize).rounded())
        )

        var required = Set<SurfaceTileCoordinate>()
        for x in -surfaceTileRadius...surfaceTileRadius {
            for z in -surfaceTileRadius...surfaceTileRadius {
                required.insert(
                    SurfaceTileCoordinate(
                        x: center.x + x,
                        z: center.z + z
                    )
                )
            }
        }

        for coordinate in state.loadedTiles.keys
            where !required.contains(coordinate) {
            state.loadedTiles.removeValue(forKey: coordinate)?
                .removeFromParent()
        }
        for coordinate in required
            where state.loadedTiles[coordinate] == nil {
            let tile = makeSurfaceTile(
                coordinate: coordinate,
                state: state
            )
            state.root.addChild(tile)
            state.loadedTiles[coordinate] = tile
        }
        updateSurfaceSecurityRobots(
            in: state.root,
            toward: surfacePoint,
            state: state
        )
        let simulationDelta = max(0, min(deltaTime, 0.05))
        state.wildlifeAnimationTime += simulationDelta
        updateSurfaceCreatures(
            in: state.root,
            toward: surfacePoint,
            deltaTime: simulationDelta,
            state: &state
        )
        updateHealthDisplaysFacingPlayer(
            in: state.root,
            toward: surfacePoint,
            state: state
        )
        surfaceExplorationState = state
    }

    func endSurfaceExploration() {
        surfaceExplorationState?.root.removeFromParent()
        surfaceExplorationState = nil
    }

    var activeSurfaceRadius: Float? {
        surfaceExplorationState?.effectiveRadius
    }

    func consumeCreatureAttacks() -> (
        hits: Int,
        knockback: SIMD3<Float>
    ) {
        guard var state = surfaceExplorationState else {
            return (0, .zero)
        }
        let result = (
            state.pendingCreatureHits,
            state.pendingCreatureKnockback
        )
        state.pendingCreatureHits = 0
        state.pendingCreatureKnockback = .zero
        surfaceExplorationState = state
        return result
    }

    func replaceRoverWithCollectibleScraps() {
        guard let state = surfaceExplorationState else { return }
        let center = state.roverMarker.position(relativeTo: state.root)
        state.roverMarker.isEnabled = false
        let material = SimpleMaterial(
            color: .darkGray,
            roughness: 0.32,
            isMetallic: true
        )
        for index in 0..<8 {
            let angle = Float(index) / 8 * 2 * .pi
            let size = SIMD3<Float>(
                0.18 + Float(index % 3) * 0.08,
                0.10 + Float(index % 2) * 0.05,
                0.22 + Float((index + 1) % 3) * 0.07
            )
            let scrap = ModelEntity(
                mesh: .generateBox(size: size, cornerRadius: 0.025),
                materials: [material]
            )
            scrap.name = "Loose Electronic|Rover Scrap"
            let radial =
                state.tangentRight * (cos(angle) * 0.8)
                + state.tangentForward * (sin(angle) * 0.8)
            scrap.position =
                center + radial + state.anchorNormal * (size.y * 0.5)
            scrap.orientation = simd_quatf(
                angle: angle * 0.7,
                axis: state.anchorNormal
            )
            state.root.addChild(scrap)
        }
    }

    func updateSurfaceVehicleMarkers(
        shipPosition: GalacticPosition?,
        roverPosition: GalacticPosition?,
        roverIsOccupied: Bool
    ) {
        guard let state = surfaceExplorationState else { return }
        if let shipPosition {
            positionSurfaceMarker(
                state.shipMarker,
                at: shipPosition,
                state: state
            )
            state.shipMarker.isEnabled = true
        } else {
            state.shipMarker.isEnabled = false
        }

        if let roverPosition {
            positionSurfaceMarker(
                state.roverMarker,
                at: roverPosition,
                state: state
            )
            state.roverMarker.isEnabled = !roverIsOccupied
        } else {
            state.roverMarker.isEnabled = false
        }
    }

    func surfaceElevation(around position: GalacticPosition) -> Float {
        guard let state = surfaceExplorationState,
              state.body.hasAtmosphere,
              let world = destination(
                identifiedBy: state.worldIdentifier,
                to: position
              ),
              world.distance > 0.001 else {
            return 0
        }
        let surfacePoint = -world.vector
        let anchorPoint =
            state.anchorNormal
                * (state.effectiveRadius + UniverseScale.surfaceEyeHeight)
        let offset = surfacePoint - anchorPoint
        let x = simd_dot(offset, state.tangentRight)
        let z = simd_dot(offset, state.tangentForward)
        return isInsideExpandedBiome(
            x: x,
            z: z,
            state: state,
            normalizedLimit: 1
        ) ? expandedBiomeElevation : 0
    }

    func applySurfaceTool(
        _ tool: SurfaceTool,
        atWorldPosition point: SIMD3<Float>,
        direction: SIMD3<Float>? = nil,
        damageAmount: Float? = nil
    ) -> String? {
        guard var state = surfaceExplorationState else { return nil }
        let targetName: String
        let radius: Float
        switch tool {
        case .sonicSlicer:
            targetName = "Surface Forest Tree"
            radius = 3.2
        case .matterCrumbler:
            targetName = "Collectible Mineral"
            radius = 12
        case .empty, .matterLauncher, .analyzer:
            return nil
        }
        var nearest: Entity?
        var nearestDistance = radius

        func inspect(_ entity: Entity) {
            if entity.name == targetName
                || (tool == .sonicSlicer
                    && entity.name.hasPrefix(
                        "Surface Forest Tree|"
                    ))
                || (tool == .matterCrumbler
                    && entity.name.hasPrefix(
                        "Collectible Mineral|"
                    ))
                || (tool == .matterCrumbler
                    && entity.name.hasPrefix("Surface Creature|"))
                || (tool == .sonicSlicer
                    && entity.name.hasPrefix("Surface Creature|")) {
                let offset =
                    entity.position(relativeTo: nil) - point
                let distance: Float
                if tool == .matterCrumbler, let direction {
                    let aim = simd_normalize(direction)
                    let forward = simd_dot(offset, aim)
                    let perpendicular = simd_length(
                        offset - aim * forward
                    )
                    guard forward >= 0,
                          forward <= radius,
                          perpendicular <= 1.35 else {
                        for child in entity.children {
                            inspect(child)
                        }
                        return
                    }
                    distance = forward + perpendicular * 0.6
                } else {
                    distance = simd_length(offset)
                }
                if distance <= nearestDistance {
                    nearest = entity
                    nearestDistance = distance
                }
            }
            for child in entity.children {
                inspect(child)
            }
        }
        inspect(state.root)
        guard let nearest, let parent = nearest.parent else { return nil }
        if nearest.name.hasPrefix("Surface Creature|") {
            let stateKey = nearest.name
            var creatureState = state.creatureStates[stateKey]
                ?? CreatureRuntimeState(
                    position: .zero,
                    altitude: 0,
                    behavior: .roaming,
                    health: 100,
                    stunRemaining: 0,
                    retreatRemaining: 0,
                    impactFlashRemaining: 0,
                    crumblerFlashRemaining: 0,
                    attackCooldownRemaining: 0,
                    avoidanceObstacleIdentifier: nil,
                    avoidanceSide: 0
                )
            let creatureDamage: Float =
                tool == .sonicSlicer
                    ? 40
                    : (damageAmount ?? 34) * 0.2
            creatureState.health = max(
                0,
                creatureState.health - creatureDamage
            )
            creatureState.retreatRemaining =
                nearest.name.split(separator: "|").dropFirst().first == "1"
                    ? 1.5
                    : 3
            if tool == .matterCrumbler {
                creatureState.crumblerFlashRemaining = 0.32
            } else {
                creatureState.impactFlashRemaining = 0.32
            }
            state.creatureStates[stateKey] = creatureState
            updateResourceHealthBar(
                on: nearest,
                fraction: creatureState.health / 100,
                height: 2.25
            )
            surfaceExplorationState = state
            if creatureState.health <= 0 {
                let droppedMaterial = spawnCreatureDropIfNeeded(
                    from: nearest,
                    state: state
                )
                nearest.removeFromParent()
                return "\(tool.rawValue) • CREATURE NEUTRALIZED"
                    + (droppedMaterial.map { " • \($0) DROPPED" } ?? "")
            }
            return "\(tool.rawValue) • CREATURE \(Int(creatureState.health.rounded())) HP"
        }
        let healthKey = ObjectIdentifier(nearest)
        let damage: Float = switch tool {
        case .sonicSlicer: 34
        case .matterCrumbler: damageAmount ?? 34
        case .empty, .matterLauncher, .analyzer: 0
        }
        let maximumHealth: Float =
            tool == .matterCrumbler
                ? mineralDepositHealth(encodedIn: nearest.name)
                : 100
        let remainingHealth = max(
            0,
            (state.resourceHealth[healthKey] ?? maximumHealth) - damage
        )
        let healthFraction = remainingHealth / maximumHealth
        state.resourceHealth[healthKey] = remainingHealth
        updateResourceHealthBar(
            on: nearest,
            fraction: healthFraction,
            height: tool == .sonicSlicer
                ? 4.6
                : 0.72
                    + Float(mineralDepositTier(encodedIn: nearest.name))
                        * 0.12
        )
        surfaceExplorationState = state
        guard remainingHealth <= 0 else {
            let target = tool == .sonicSlicer ? "TREE" : "MINERAL"
            let healthPercent = Int((healthFraction * 100).rounded())
            return "\(tool.rawValue) ACTIVATED • \(target) \(healthPercent)% HEALTH"
        }
        state.resourceHealth.removeValue(forKey: healthKey)
        let transform = nearest.transform
        if let resourceIdentifier =
            surfaceResourceIdentifier(encodedIn: nearest.name) {
            surfaceResources.deplete(resourceIdentifier)
        }
        nearest.removeFromParent()

        let materialName: String
        let looseGroup = Entity()
        looseGroup.transform = transform
        parent.addChild(looseGroup)
        let burst = ModelEntity(
            mesh: .generateSphere(radius: tool == .sonicSlicer ? 0.72 : 0.46),
            materials: [
                UnlitMaterial(
                    color: tool == .sonicSlicer
                        ? UIColor.systemGreen.withAlphaComponent(0.72)
                        : UIColor.systemCyan.withAlphaComponent(0.82)
                )
            ]
        )
        burst.name = "Resource Destruction Burst"
        burst.position.y = tool == .sonicSlicer ? 1.4 : 0.7
        looseGroup.addChild(burst)
        Task { @MainActor [weak burst] in
            try? await Task.sleep(for: .milliseconds(260))
            burst?.removeFromParent()
        }
        switch tool {
        case .sonicSlicer:
            materialName = logMaterialName(for: state.body.kind)
            addLooseLogs(
                to: looseGroup,
                materialName: materialName,
                color: logMaterialColor(for: state.body.kind)
            )
        case .matterCrumbler:
            materialName =
                mineralName(encodedIn: nearest.name)
                    ?? mineralMaterialName(for: state.body.kind)
            addLooseMineralPieces(
                to: looseGroup,
                materialName: materialName,
                color: mineralMaterialColor(
                    for: state.body.kind,
                    materialName: materialName
                ),
                count: mineralDepositDropCount(
                    encodedIn: nearest.name
                )
            )
        case .empty, .matterLauncher, .analyzer:
            return nil
        }
        surfaceExplorationState = state
        return tool == .sonicSlicer
            ? "SONIC SLICER ACTIVATED • \(materialName) LOGS DROPPED"
            : "MATTER CRUMBLER ACTIVATED • \(materialName) SCATTERED"
    }

    private func updateResourceHealthBar(
        on resource: Entity,
        fraction: Float,
        height: Float
    ) {
        let bar: Entity
        if let existing = resource.findEntity(
            named: "Resource Health Bar"
        ) {
            bar = existing
        } else {
            bar = Entity()
            bar.name = "Resource Health Bar"
            bar.position.y = height
            let background = ModelEntity(
                mesh: .generateBox(
                    width: 0.92,
                    height: 0.12,
                    depth: 0.055
                ),
                materials: [
                    UnlitMaterial(
                        color: UIColor.black.withAlphaComponent(0.82)
                    )
                ]
            )
            bar.addChild(background)
            let fill = ModelEntity(
                mesh: .generateBox(
                    width: 0.84,
                    height: 0.075,
                    depth: 0.063
                ),
                materials: [UnlitMaterial(color: .systemGreen)]
            )
            fill.name = "Resource Health Fill"
            bar.addChild(fill)
            resource.addChild(bar)
        }
        guard let fill = bar.findEntity(
            named: "Resource Health Fill"
        ) else { return }
        let clamped = max(0.001, min(1, fraction))
        bar.isEnabled = fraction < 0.999
        fill.scale.x = clamped
        fill.position.x = -0.42 * (1 - clamped)
        if let model = fill as? ModelEntity {
            model.model?.materials = [
                UnlitMaterial(
                    color: fraction > 0.55
                        ? .systemGreen
                        : (fraction > 0.25
                            ? .systemYellow
                            : .systemRed)
                )
            ]
        }
    }

    private func updateHealthDisplaysFacingPlayer(
        in root: Entity,
        toward playerSurfacePoint: SIMD3<Float>,
        state: SurfaceExplorationState
    ) {
        func update(_ entity: Entity) {
            if entity.name == "Resource Health Bar", entity.isEnabled {
                let position = entity.position(relativeTo: root)
                let towardPlayer = playerSurfacePoint - position
                guard simd_length_squared(towardPlayer) > 0.000_001 else {
                    return
                }
                let forward = simd_normalize(towardPlayer)
                let surfaceUp = simd_normalize(playerSurfacePoint)
                var right = simd_cross(surfaceUp, forward)
                if simd_length_squared(right) < 0.000_001 {
                    right = state.tangentRight
                } else {
                    right = simd_normalize(right)
                }
                let displayUp = simd_normalize(
                    simd_cross(forward, right)
                )
                entity.setOrientation(
                    simd_quatf(
                        simd_float3x3(
                            columns: (right, displayUp, forward)
                        )
                    ),
                    relativeTo: root
                )
                return
            }
            for child in entity.children {
                update(child)
            }
        }
        update(root)
    }

    func analyzeSurfaceTarget(
        from point: SIMD3<Float>,
        direction: SIMD3<Float>,
        maximumDistance: Float = 12
    ) -> String? {
        guard var state = surfaceExplorationState else { return nil }
        let aim = simd_normalize(direction)
        var nearest: Entity?
        var nearestForward = maximumDistance
        func inspect(_ entity: Entity) {
            let isCandidate =
                entity.name.hasPrefix("Surface Forest Tree")
                || entity.name.hasPrefix("Collectible Mineral")
                || entity.name.hasPrefix("Loose Log|")
                || entity.name.hasPrefix("Loose Mineral|")
                || entity.name.hasPrefix("Loose Electronic|")
                || entity.name.hasPrefix("Loose Creature Material|")
                || entity.name == "Surface Base"
                || entity.name.hasPrefix("Surface Security Robot|")
                || entity.name.hasPrefix("Surface Creature|")
            if isCandidate {
                let targetHeight: Float =
                    entity.name.hasPrefix("Surface Forest Tree")
                        ? 1.4
                        : (entity.name.hasPrefix("Collectible Mineral")
                            ? 0.8
                            : (entity.name == "Surface Base"
                                ? 1.4
                                : (entity.name.hasPrefix(
                                    "Surface Security Robot|"
                                ) || entity.name.hasPrefix(
                                    "Surface Creature|"
                                ) ? 0.9 : 0)))
                let targetPoint = entity.convert(
                    position: SIMD3<Float>(0, targetHeight, 0),
                    to: nil
                )
                let offset = targetPoint - point
                let forward = simd_dot(offset, aim)
                let perpendicular = simd_length(offset - aim * forward)
                if forward > 0,
                   forward < nearestForward,
                   perpendicular <= max(0.75, forward * 0.18) {
                    nearest = entity
                    nearestForward = forward
                }
            }
            for child in entity.children {
                inspect(child)
            }
        }
        inspect(state.root)
        guard let nearest else { return nil }
        if nearest.name.hasPrefix("Surface Forest Tree") {
            let materialName = logMaterialName(for: state.body.kind)
            return planetaryScanResult(
                state: state,
                identifier: "flora:\(materialName)",
                label: "\(materialName) tree",
                interaction: "slicer compatible"
            )
        }
        if nearest.name.hasPrefix("Collectible Mineral") {
            let materialName =
                mineralName(encodedIn: nearest.name)
                    ?? mineralMaterialName(for: state.body.kind)
            let depositSize = mineralDepositSizeName(
                encodedIn: nearest.name
            )
            return planetaryScanResult(
                state: state,
                identifier: "mineral:\(materialName)",
                label: "\(depositSize) \(materialName) formation",
                interaction: "crumbler compatible"
            )
        }
        if nearest.name.hasPrefix("Loose Log|") {
            let materialName = String(
                nearest.name.dropFirst("Loose Log|".count)
            )
            return planetaryScanResult(
                state: state,
                identifier: "flora:\(materialName)",
                label: "\(materialName) log",
                interaction: "collectible"
            )
        }
        if nearest.name.hasPrefix("Loose Mineral|") {
            let materialName = String(
                nearest.name.dropFirst("Loose Mineral|".count)
            )
            return planetaryScanResult(
                state: state,
                identifier: "mineral:\(materialName)",
                label: "\(materialName) fragment",
                interaction: "launcher ammo"
            )
        }
        if nearest.name.hasPrefix("Loose Electronic|") {
            let materialName = String(
                nearest.name.dropFirst("Loose Electronic|".count)
            )
            return planetaryScanResult(
                state: state,
                identifier: "electronic:\(materialName)",
                label: materialName,
                interaction: "collectible electronic salvage"
            )
        }
        if nearest.name.hasPrefix("Loose Creature Material|") {
            let materialName = String(
                nearest.name.dropFirst("Loose Creature Material|".count)
            )
            return planetaryScanResult(
                state: state,
                identifier: "creature-material:\(materialName)",
                label: materialName,
                interaction: "collectible biological material"
            )
        }
        if nearest.name.hasPrefix("Surface Security Robot|") {
            return planetaryScanResult(
                state: state,
                identifier: "hostile:surface-security-robot",
                label: "surface security robot",
                interaction: "hostile proximity response"
            )
        }
        if nearest.name.hasPrefix("Surface Creature|") {
            let components = nearest.name.split(separator: "|")
            let isAggressive =
                components.count > 1 && components[1] == "1"
            let speciesName =
                components.count > 7
                    ? String(components[7])
                    : "unknown creature"
            let stateKey = nearest.name
            var creatureState = state.creatureStates[stateKey]
                ?? CreatureRuntimeState(
                    position: .zero,
                    altitude: 0,
                    behavior: .roaming,
                    health: 100,
                    stunRemaining: 0,
                    retreatRemaining: 0,
                    impactFlashRemaining: 0,
                    crumblerFlashRemaining: 0,
                    attackCooldownRemaining: 0,
                    avoidanceObstacleIdentifier: nil,
                    avoidanceSide: 0
                )
            creatureState.stunRemaining = 7
            state.creatureStates[stateKey] = creatureState
            surfaceExplorationState = state
            return planetaryScanResult(
                state: state,
                identifier: "fauna:\(speciesName)",
                label: speciesName,
                interaction: isAggressive
                    ? "aggressive fauna • stunned 7 seconds"
                    : "passive fauna • stunned 7 seconds"
            )
        }
        return planetaryScanResult(
            state: state,
            identifier: "structure:surface-base",
            label: "surface base",
            interaction: "structure recorded"
        )
    }

    private func planetaryScanResult(
        state: SurfaceExplorationState,
        identifier: String,
        label: String,
        interaction: String
    ) -> String {
        let result = planetaryScans.record(
            worldIdentifier: state.worldIdentifier,
            discoveryIdentifier: identifier
        )
        return "\(result.isNew ? "NEW DISCOVERY" : "KNOWN")"
            + " • \(label) • \(interaction)"
            + " • PLANET CATALOG \(result.count)"
    }

    func collectLooseSurfaceItems(
        atWorldPosition point: SIMD3<Float>,
        maximumDistance: Float
    ) -> [SurfacePickup]? {
        guard let state = surfaceExplorationState else { return nil }
        var nearest: Entity?
        var nearestDistance = maximumDistance
        func inspect(_ entity: Entity) {
            if loosePickupCategory(for: entity) != nil {
                let distance = simd_distance(
                    entity.position(relativeTo: nil),
                    point
                )
                if distance <= nearestDistance {
                    nearest = entity
                    nearestDistance = distance
                }
            }
            for child in entity.children {
                inspect(child)
            }
        }
        inspect(state.root)
        guard let nearest,
              let category = loosePickupCategory(for: nearest) else {
            return nil
        }
        return collectLooseSurfacePile(
            centeredOn: nearest,
            category: category,
            state: state
        )
    }

    func collectLooseSurfaceItems(
        from point: SIMD3<Float>,
        direction: SIMD3<Float>,
        maximumDistance: Float
    ) -> [SurfacePickup]? {
        guard let state = surfaceExplorationState else { return nil }
        let aim = simd_normalize(direction)
        var nearest: Entity?
        var bestSelectionScore = Float.greatestFiniteMagnitude
        func inspect(_ entity: Entity) {
            if loosePickupCategory(for: entity) != nil {
                let offset = entity.position(relativeTo: nil) - point
                let forward = simd_dot(offset, aim)
                let perpendicular = simd_length(offset - aim * forward)
                let focusRadius = max(0.75, forward * 0.18)
                if forward > 0,
                   forward <= maximumDistance,
                   perpendicular <= focusRadius {
                    // Depth is primary so repeated gestures collect piles in
                    // near-to-far order. Aim offset only breaks close ties.
                    let selectionScore = forward + perpendicular * 0.35
                    if selectionScore < bestSelectionScore {
                        nearest = entity
                        bestSelectionScore = selectionScore
                    }
                }
            }
            for child in entity.children {
                inspect(child)
            }
        }
        inspect(state.root)
        guard let nearest,
              let category = loosePickupCategory(for: nearest) else {
            return nil
        }
        return collectLooseSurfacePile(
            centeredOn: nearest,
            category: category,
            state: state
        )
    }

    private func loosePickupCategory(
        for entity: Entity
    ) -> SurfacePickup.Category? {
        if entity.name.hasPrefix("Loose Log|") {
            return .log
        }
        if entity.name.hasPrefix("Loose Mineral|") {
            return .mineral
        }
        if entity.name.hasPrefix("Loose Electronic|") {
            return .electronic
        }
        if entity.name.hasPrefix("Loose Creature Material|") {
            return .creatureMaterial
        }
        return nil
    }

    private func collectLooseSurfacePile(
        centeredOn primary: Entity,
        category: SurfacePickup.Category,
        state: SurfaceExplorationState
    ) -> [SurfacePickup] {
        let pileRadius: Float = 1.5
        let center = primary.position(relativeTo: nil)
        var entities: [Entity] = []
        func inspect(_ entity: Entity) {
            if loosePickupCategory(for: entity) == category,
               simd_distance(
                    entity.position(relativeTo: nil),
                    center
               ) <= pileRadius {
                entities.append(entity)
            }
            for child in entity.children {
                inspect(child)
            }
        }
        inspect(state.root)

        let pickups = entities.compactMap { entity -> SurfacePickup? in
            let components = entity.name.split(
                separator: "|",
                maxSplits: 1
            )
            guard components.count == 2 else { return nil }
            return SurfacePickup(
                materialName: String(components[1]),
                category: category,
                sourcePlanetIdentifier: state.worldIdentifier,
                sourcePlanetName: state.body.name,
                sourcePlanetKind: state.body.kind
            )
        }
        for entity in entities {
            entity.removeFromParent()
        }
        return pickups
    }

    func hitSurfaceCombatTarget(
        atWorldPosition point: SIMD3<Float>,
        maximumDistance: Float = 0.85
    ) -> String? {
        guard var state = surfaceExplorationState else { return nil }
        var nearest: Entity?
        var nearestDistance = maximumDistance
        func inspect(_ entity: Entity) {
            if entity.name.hasPrefix("Surface Security Robot|")
                || entity.name.hasPrefix("Surface Creature|") {
                let targetPoint = entity.convert(
                    position: SIMD3<Float>(0, 0.9, 0),
                    to: nil
                )
                let distance = simd_distance(targetPoint, point)
                if distance <= nearestDistance {
                    nearest = entity
                    nearestDistance = distance
                }
            }
            for child in entity.children {
                inspect(child)
            }
        }
        inspect(state.root)
        guard let target = nearest, let parent = target.parent else {
            return nil
        }

        if target.name.hasPrefix("Surface Creature|") {
            let stateKey = target.name
            var creatureState = state.creatureStates[stateKey]
                ?? CreatureRuntimeState(
                    position: .zero,
                    altitude: 0,
                    behavior: .roaming,
                    health: 100,
                    stunRemaining: 0,
                    retreatRemaining: 0,
                    impactFlashRemaining: 0,
                    crumblerFlashRemaining: 0,
                    attackCooldownRemaining: 0,
                    avoidanceObstacleIdentifier: nil,
                    avoidanceSide: 0
                )
            creatureState.health = max(0, creatureState.health - 40)
            creatureState.retreatRemaining =
                target.name.split(separator: "|").dropFirst().first == "1"
                    ? 1.5
                    : 3
            creatureState.impactFlashRemaining = 0.32
            state.creatureStates[stateKey] = creatureState
            updateResourceHealthBar(
                on: target,
                fraction: creatureState.health / 100,
                height: 2.25
            )
            surfaceExplorationState = state
            guard creatureState.health <= 0 else {
                return "MATTER IMPACT • CREATURE \(Int(creatureState.health)) HP"
            }
            let droppedMaterial = spawnCreatureDropIfNeeded(
                from: target,
                state: state
            )
            target.removeFromParent()
            return "MATTER IMPACT • CREATURE NEUTRALIZED"
                + (droppedMaterial.map { " • \($0) DROPPED" } ?? "")
        }

        let robot = target
        let healthKey = ObjectIdentifier(robot)
        let remainingHits = Int(state.resourceHealth[healthKey] ?? 3) - 1
        if remainingHits > 0 {
            state.resourceHealth[healthKey] = Float(remainingHits)
            updateResourceHealthBar(
                on: robot,
                fraction: Float(remainingHits) / 3,
                height: 1.9
            )
            surfaceExplorationState = state
            return "MATTER IMPACT • SECURITY ROBOT \(remainingHits) HITS REMAIN"
        }

        state.resourceHealth.removeValue(forKey: healthKey)
        let transform = robot.transform
        robot.removeFromParent()

        let wreckage = Entity()
        wreckage.name = "Destroyed Security Robot Wreckage"
        wreckage.transform = transform
        parent.addChild(wreckage)
        let burstColors: [UIColor] = [
            .white, .systemYellow, .systemOrange, .systemRed
        ]
        var bursts: [ModelEntity] = []
        for index in 0..<burstColors.count {
            let burst = ModelEntity(
                mesh: .generateSphere(
                    radius: 0.25 + Float(index) * 0.12
                ),
                materials: [
                    UnlitMaterial(
                        color: burstColors[index]
                            .withAlphaComponent(0.9)
                    )
                ]
            )
            burst.name = "Security Robot Explosion"
            burst.position = [
                Float(index % 2 == 0 ? -1 : 1)
                    * Float(index) * 0.08,
                0.65 + Float(index) * 0.13,
                Float(index % 2 == 0 ? 1 : -1) * 0.09
            ]
            wreckage.addChild(burst)
            bursts.append(burst)
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(320))
            for burst in bursts {
                burst.removeFromParent()
            }
        }

        let droppedCircuitBoard = Int.random(in: 0..<100) < 40
        if droppedCircuitBoard {
            let board = ModelEntity(
                mesh: .generateBox(
                    width: 0.34,
                    height: 0.035,
                    depth: 0.22
                ),
                materials: [
                    SimpleMaterial(
                        color: UIColor(
                            red: 0.04,
                            green: 0.38,
                            blue: 0.18,
                            alpha: 1
                        ),
                        roughness: 0.35,
                        isMetallic: true
                    )
                ]
            )
            board.name = "Loose Electronic|Circuit Board"
            board.position.y = 0.025
            wreckage.addChild(board)
        }
        surfaceExplorationState = state
        return droppedCircuitBoard
            ? "SECURITY ROBOT DESTROYED • CIRCUIT BOARD DROPPED"
            : "SECURITY ROBOT DESTROYED • NO SALVAGE"
    }

    /// Resolves once, at the moment a creature is defeated. The creature's
    /// deterministic identity keeps both the 33% result and selected material
    /// stable for a given world instead of changing with frame timing.
    private func spawnCreatureDropIfNeeded(
        from creature: Entity,
        state: SurfaceExplorationState
    ) -> String? {
        var hash: UInt64 = 1469598103934665603
        for byte in "\(state.worldIdentifier)|\(creature.name)".utf8 {
            hash = (hash ^ UInt64(byte)) &* 1099511628211
        }
        guard hash % 100 < 33 else { return nil }

        let materials = creatureDropMaterialNames(for: state.body.kind)
        let materialName = materials[
            Int((hash / 100) % UInt64(materials.count))
        ]
        let color = creatureDropColor(for: state.body.kind)
        let isCrystal = materialName.hasSuffix("Crystal")
        let drop = ModelEntity(
            mesh: isCrystal
                ? .generateBox(width: 0.22, height: 0.34, depth: 0.20)
                : .generateSphere(radius: 0.17),
            materials: [
                SimpleMaterial(
                    color: color,
                    roughness: isCrystal ? 0.18 : 0.72,
                    isMetallic: isCrystal
                )
            ]
        )
        drop.name = "Loose Creature Material|\(materialName)"
        let defeatedPosition = creature.position(relativeTo: state.root)
        let deathX = simd_dot(defeatedPosition, state.tangentRight)
        let deathZ = simd_dot(defeatedPosition, state.tangentForward)
        let surfaceUp = projectedSurfaceDirection(
            x: deathX,
            z: deathZ,
            state: state
        )
        let landingPosition =
            surfaceUp
            * (state.effectiveRadius + expandedBiomeElevation + 0.18)
        let deathAltitude = max(
            0,
            simd_dot(defeatedPosition, surfaceUp)
                - (state.effectiveRadius + expandedBiomeElevation)
        )
        let releasePosition =
            deathAltitude > 0.35
                ? defeatedPosition
                : defeatedPosition
                    + surfaceUp * (2.6 * max(0.7, creature.scale.y))
        drop.orientation = simd_quatf(
            angle: Float(hash % 628) / 100,
            axis: surfaceUp
        )
        let fallDistance = simd_distance(
            releasePosition,
            landingPosition
        )
        drop.position = releasePosition
        state.root.addChild(drop)
        if fallDistance > 0.25 {
            var landingTransform = drop.transform
            landingTransform.translation = landingPosition
            let fallDuration = Double(
                min(2.4, max(0.45, sqrt(fallDistance) * 0.42))
            )
            drop.move(
                to: landingTransform,
                relativeTo: state.root,
                duration: fallDuration,
                timingFunction: .easeIn
            )
        }
        return materialName
    }

    private func creatureDropMaterialNames(
        for kind: CelestialBodyKind
    ) -> [String] {
        let prefix: String = switch kind {
        case .ocean: "Pelagic"
        case .desert: "Dune"
        case .rocky: "Lithic"
        case .ice: "Cryonic"
        case .gas: "Aetheric"
        case .star: "Solar"
        }
        return [
            "\(prefix) Feces",
            "\(prefix) Meat",
            "\(prefix) Pheromone Secretion",
            "\(prefix) Crystal",
            "\(prefix) Bone",
            "\(prefix) Hide",
            "\(prefix) Chitin",
            "\(prefix) Venom Sac",
            "\(prefix) Scent Gland",
            "\(prefix) Scale"
        ]
    }

    private func creatureDropColor(
        for kind: CelestialBodyKind
    ) -> UIColor {
        switch kind {
        case .ocean: .systemTeal
        case .desert: .systemOrange
        case .rocky: .systemIndigo
        case .ice: .systemCyan
        case .gas: .systemPurple
        case .star: .systemYellow
        }
    }

    private func addLooseLogs(
        to root: Entity,
        materialName: String,
        color: UIColor
    ) {
        let material = SimpleMaterial(
            color: color,
            roughness: 0.86,
            isMetallic: false
        )
        for index in 0..<3 {
            let log = ModelEntity(
                mesh: .generateCylinder(height: 1.05, radius: 0.13),
                materials: [material]
            )
            log.name = "Loose Log|\(materialName)"
            log.position = [
                Float(index - 1) * 0.34,
                0.14,
                Float(index % 2) * 0.28
            ]
            log.orientation = simd_quatf(
                angle: .pi / 2 + Float(index) * 0.22,
                axis: [0, 0, 1]
            )
            root.addChild(log)
        }
    }

    private func addLooseMineralPieces(
        to root: Entity,
        materialName: String,
        color: UIColor,
        count: Int
    ) {
        let material = SimpleMaterial(
            color: color,
            roughness: 0.24,
            isMetallic: true
        )
        let columns = min(5, count)
        let rows = (count + columns - 1) / columns
        for index in 0..<count {
            let pieceHeight = 0.24 + Float(index % 4) * 0.04
            let piece = ModelEntity(
                mesh: .generateBox(
                    width: 0.22,
                    height: pieceHeight,
                    depth: 0.20
                ),
                materials: [material]
            )
            piece.name = "Loose Mineral|\(materialName)"
            let column = index % columns
            let row = index / columns
            piece.position = [
                (Float(column) - Float(columns - 1) * 0.5) * 0.30,
                pieceHeight * 0.5 + 0.005,
                (Float(row) - Float(rows - 1) * 0.5) * 0.27
            ]
            piece.orientation = simd_quatf(
                angle: Float(index - 1) * 0.35,
                axis: [0, 1, 0]
            )
            root.addChild(piece)
        }
    }

    private func logMaterialName(
        for kind: CelestialBodyKind
    ) -> String {
        switch kind {
        case .ocean: "Verdant Timber"
        case .desert: "Emberwood"
        case .rocky: "Ironbark"
        case .ice: "Crystalwood"
        case .gas: "Balloonwood"
        case .star: "Solar Fiber"
        }
    }

    private func mineralMaterialName(
        for kind: CelestialBodyKind
    ) -> String {
        switch kind {
        case .ocean: "Pelagite"
        case .desert: "Cinderstone"
        case .rocky: "Gravium"
        case .ice: "Crysolite"
        case .gas: "Aether Crystal"
        case .star: "Helion"
        }
    }

    private func mineralName(
        encodedIn entityName: String
    ) -> String? {
        let components = entityName.split(separator: "|")
        guard components.count >= 2 else { return nil }
        return String(components[1])
    }

    private func mineralDepositTier(
        encodedIn entityName: String
    ) -> Int {
        let components = entityName.split(separator: "|")
        guard components.count >= 4,
              let tier = Int(components[3]) else {
            return 0
        }
        return min(4, max(0, tier))
    }

    private func mineralDepositHealth(
        encodedIn entityName: String
    ) -> Float {
        switch mineralDepositTier(encodedIn: entityName) {
        case 0: 60
        case 1: 110
        case 2: 180
        case 3: 270
        default: 380
        }
    }

    private func mineralDepositDropCount(
        encodedIn entityName: String
    ) -> Int {
        let range: ClosedRange<Int> =
            switch mineralDepositTier(encodedIn: entityName) {
            case 0: 2...3
            case 1: 4...6
            case 2: 7...10
            case 3: 11...16
            default: 17...20
            }
        let hash = entityName.utf8.reduce(
            UInt64(1_469_598_103_934_665_603)
        ) {
            ($0 ^ UInt64($1)) &* 1_099_511_628_211
        }
        return range.lowerBound
            + Int(hash % UInt64(range.count))
    }

    private func mineralDepositSizeName(
        encodedIn entityName: String
    ) -> String {
        switch mineralDepositTier(encodedIn: entityName) {
        case 0: "small"
        case 1: "medium-small"
        case 2: "medium"
        case 3: "large"
        default: "massive"
        }
    }

    private func surfaceResourceIdentifier(
        encodedIn entityName: String
    ) -> String? {
        let components = entityName.split(separator: "|")
        guard components.count >= 2 else { return nil }
        if components[0] == "Surface Forest Tree" {
            return String(components[1])
        }
        guard components[0] == "Collectible Mineral",
              components.count >= 3 else {
            return nil
        }
        return String(components[2])
    }

    private func surfaceResourceIdentifier(
        worldIdentifier: String,
        coordinate: SurfaceTileCoordinate,
        category: String,
        index: Int
    ) -> String {
        "\(worldIdentifier):tile:\(coordinate.x),\(coordinate.z)"
            + ":\(category):\(index)"
    }

    private func mineralMaterialName(
        for body: CelestialBodyDescriptor,
        random: inout UniverseRandom
    ) -> String {
        let roll = random.double(in: 0...1)
        let uncommonThreshold =
            body.hasAtmosphere ? 0.72 : 0.43
        let rareThreshold =
            body.hasAtmosphere ? 0.96 : 0.78
        let tier =
            roll >= rareThreshold
                ? 2
                : (roll >= uncommonThreshold ? 1 : 0)
        return switch (body.kind, tier) {
        case (.ocean, 0): "Pelagite"
        case (.ocean, 1): "Reef Crystal"
        case (.ocean, _): "Abyss Crystal"
        case (.desert, 0): "Cinderstone"
        case (.desert, 1): "Sun Glass"
        case (.desert, _): "Ember Crystal"
        case (.rocky, 0): "Stone Ore"
        case (.rocky, 1): "Gravium"
        case (.rocky, _): "Core Crystal"
        case (.ice, 0): "Crysolite"
        case (.ice, 1): "Frost Quartz"
        case (.ice, _): "Aurora Crystal"
        case (.gas, 0): "Aether Crystal"
        case (.gas, 1): "Storm Glass"
        case (.gas, _): "Cloud Diamond"
        case (.star, 0): "Solar Fiber"
        case (.star, 1): "Helion"
        case (.star, _): "Star Crystal"
        }
    }

    private func logMaterialColor(
        for kind: CelestialBodyKind
    ) -> UIColor {
        switch kind {
        case .ocean: UIColor(red: 0.22, green: 0.46, blue: 0.16, alpha: 1)
        case .desert: UIColor(red: 0.70, green: 0.20, blue: 0.04, alpha: 1)
        case .rocky: UIColor(white: 0.28, alpha: 1)
        case .ice: .systemCyan
        case .gas: .systemPurple
        case .star: .systemYellow
        }
    }

    private func mineralMaterialColor(
        for kind: CelestialBodyKind
    ) -> UIColor {
        switch kind {
        case .ocean: .systemTeal
        case .desert: .systemOrange
        case .rocky: .systemIndigo
        case .ice: .systemCyan
        case .gas: .systemPurple
        case .star: .white
        }
    }

    private func mineralMaterialColor(
        for kind: CelestialBodyKind,
        materialName: String
    ) -> UIColor {
        if materialName.contains("Abyss")
            || materialName.contains("Ember")
            || materialName.contains("Core")
            || materialName.contains("Aurora")
            || materialName.contains("Diamond")
            || materialName.contains("Star") {
            return .white
        }
        if materialName.contains("Reef")
            || materialName.contains("Sun Glass")
            || materialName == "Gravium"
            || materialName.contains("Quartz")
            || materialName.contains("Storm") {
            return .systemPink
        }
        return mineralMaterialColor(for: kind)
    }

    private func bodyRecord(
        identifiedBy identifier: String
    ) -> (body: CelestialBodyDescriptor, entity: Entity)? {
        for region in loadedRegions.values {
            for (bodyIndex, body) in region.descriptor.bodies.enumerated() {
                let bodyIdentifier =
                    "\(region.descriptor.sector.x),"
                    + "\(region.descriptor.sector.y),"
                    + "\(region.descriptor.sector.z):body:"
                    + "\(bodyIndex):\(body.name)"
                guard bodyIdentifier == identifier,
                      let entity = region.entity.findEntity(
                        named: body.name
                      ) else {
                    continue
                }
                return (body, entity)
            }
        }
        return nil
    }

    private func loadRegionIfNeeded(at sector: GalacticSector) {
        guard loadedRegions[sector] == nil else { return }
        let descriptor = generator.region(at: sector)
        let entity = makeRegionEntity(descriptor)
        for child in entity.children {
            regionChildSimulationPositions[ObjectIdentifier(child)] =
                SIMD3<Double>(child.position)
        }
        root.addChild(entity)
        loadedRegions[sector] = (descriptor, entity)
        if let renderOrigin {
            updateRenderOrigin(around: renderOrigin)
        }
    }

    private func sectorDistance(
        _ candidate: GalacticSector,
        from center: GalacticSector
    ) -> Int64 {
        abs(candidate.x - center.x)
            + abs(candidate.y - center.y)
            + abs(candidate.z - center.z)
    }

    func updateSurfaceDetailVisibility(
        around position: GalacticPosition,
        showGroundDetail: Bool
    ) {
        for region in loadedRegions.values {
            for body in region.descriptor.bodies where body.kind != .star {
                let vector = position.vector(
                    to: region.descriptor.sector,
                    local: body.localPosition
                )
                let altitude = max(0, Float(simd_length(vector)) - body.radius)
                guard let bodyEntity = region.entity.findEntity(named: body.name) else {
                    continue
                }
                let shouldShowRoughDetail = altitude <= 10_000
                if let roughDetail = bodyEntity.findEntity(
                    named: "Upper Atmosphere Detail"
                ) {
                    if shouldShowRoughDetail && roughDetail.children.isEmpty {
                        if body.hasAtmosphere {
                            addRoughSurfaceDetail(to: roughDetail, for: body)
                        } else {
                            addAirlessSurfaceDetail(to: roughDetail, for: body)
                        }
                    }
                    roughDetail.isEnabled =
                        shouldShowRoughDetail && !showGroundDetail
                }
                let shouldShowLowerDetail =
                    body.hasAtmosphere
                    && altitude
                    <= UniverseScale.lowerAtmosphereDepth(for: body.radius)
                        * 1.15
                if let lowerDetail = bodyEntity.findEntity(
                    named: "Lower Atmosphere Detail"
                ) {
                    if shouldShowLowerDetail && lowerDetail.children.isEmpty {
                        addLowerSurfaceDetail(to: lowerDetail, for: body)
                    }
                    lowerDetail.isEnabled =
                        shouldShowLowerDetail && !showGroundDetail
                }

                let shouldShowGroundDetail = false
                if let groundDetail = bodyEntity.findEntity(
                    named: "Ground Detail"
                ) {
                    if shouldShowGroundDetail && groundDetail.children.isEmpty {
                        addGroundSurfaceDetail(to: groundDetail, for: body)
                    }
                    groundDetail.isEnabled = shouldShowGroundDetail
                }
            }
        }
    }

    func nearestDestination(
        to position: GalacticPosition,
        matching requestedKind: NavigationTargetKind? = nil,
        atmosphere requiredAtmosphere: Bool? = nil
    ) -> NearbyNavigationTarget? {
        var nearest: NearbyNavigationTarget?
        for region in loadedRegions.values {
            if requestedKind == nil || requestedKind == .world {
                for (bodyIndex, body) in region.descriptor.bodies.enumerated() {
                    if let requiredAtmosphere {
                        guard body.kind != .star,
                              body.hasAtmosphere == requiredAtmosphere else {
                            continue
                        }
                    }
                    let vectorDouble = position.vector(
                        to: region.descriptor.sector,
                        local: body.localPosition
                    )
                    let distance = Float(simd_length(vectorDouble))
                    if nearest.map({ distance < $0.distance }) ?? true {
                        nearest = NearbyNavigationTarget(
                            identifier: "\(region.descriptor.sector.x),\(region.descriptor.sector.y),\(region.descriptor.sector.z):body:\(bodyIndex):\(body.name)",
                            name: body.name,
                            kind: .world,
                            vector: SIMD3<Float>(vectorDouble),
                            distance: distance,
                            radius: body.radius,
                            celestialKind: body.kind,
                            hasAtmosphere: body.hasAtmosphere
                        )
                    }
                }
            }
            for (pointIndex, point) in region.descriptor.pointsOfInterest.enumerated() {
                let targetKind: NavigationTargetKind =
                    point.kind == .station ? .station : .wreckage
                guard requestedKind == nil || requestedKind == targetKind else { continue }
                let vectorDouble = position.vector(
                    to: region.descriptor.sector,
                    local: point.localPosition
                )
                let distance = Float(simd_length(vectorDouble))
                if nearest.map({ distance < $0.distance }) ?? true {
                    nearest = NearbyNavigationTarget(
                        identifier: "\(region.descriptor.sector.x),\(region.descriptor.sector.y),\(region.descriptor.sector.z):\(pointIndex):\(point.kind.rawValue):\(point.name)",
                        name: point.name,
                        kind: targetKind,
                        vector: SIMD3<Float>(vectorDouble),
                        distance: distance,
                        radius: point.kind == .station
                            ? UniverseScale.stationRadius
                            : UniverseScale.wreckageRadius,
                        celestialKind: nil,
                        hasAtmosphere: false
                    )
                }
            }
        }
        return nearest
    }

    func destination(
        identifiedBy identifier: String,
        to position: GalacticPosition
    ) -> NearbyNavigationTarget? {
        for region in loadedRegions.values {
            for (bodyIndex, body) in region.descriptor.bodies.enumerated() {
                let bodyIdentifier = "\(region.descriptor.sector.x),\(region.descriptor.sector.y),\(region.descriptor.sector.z):body:\(bodyIndex):\(body.name)"
                guard bodyIdentifier == identifier else { continue }
                let vector = position.vector(
                    to: region.descriptor.sector,
                    local: body.localPosition
                )
                return NearbyNavigationTarget(
                    identifier: identifier,
                    name: body.name,
                    kind: .world,
                    vector: SIMD3<Float>(vector),
                    distance: Float(simd_length(vector)),
                    radius: body.radius,
                    celestialKind: body.kind,
                    hasAtmosphere: body.hasAtmosphere
                )
            }
            for (pointIndex, point) in region.descriptor.pointsOfInterest.enumerated() {
                let pointIdentifier = "\(region.descriptor.sector.x),\(region.descriptor.sector.y),\(region.descriptor.sector.z):\(pointIndex):\(point.kind.rawValue):\(point.name)"
                guard pointIdentifier == identifier else { continue }
                let vector = position.vector(
                    to: region.descriptor.sector,
                    local: point.localPosition
                )
                return NearbyNavigationTarget(
                    identifier: identifier,
                    name: point.name,
                    kind: point.kind == .station ? .station : .wreckage,
                    vector: SIMD3<Float>(vector),
                    distance: Float(simd_length(vector)),
                    radius: point.kind == .station
                        ? UniverseScale.stationRadius
                        : UniverseScale.wreckageRadius,
                    celestialKind: nil,
                    hasAtmosphere: false
                )
            }
        }
        return nil
    }

    func nearestDestination(
        to position: GalacticPosition,
        alignedWith direction: SIMD3<Float>,
        minimumAlignment: Float
    ) -> NearbyNavigationTarget? {
        var nearest: NearbyNavigationTarget?
        for region in loadedRegions.values {
            for (bodyIndex, body) in region.descriptor.bodies.enumerated() {
                let vectorDouble = position.vector(
                    to: region.descriptor.sector,
                    local: body.localPosition
                )
                let vector = SIMD3<Float>(vectorDouble)
                let distance = simd_length(vector)
                guard distance > 0.001,
                      simd_dot(direction, vector / distance) >= minimumAlignment else {
                    continue
                }
                if nearest.map({ distance < $0.distance }) ?? true {
                    nearest = NearbyNavigationTarget(
                        identifier: "\(region.descriptor.sector.x),\(region.descriptor.sector.y),\(region.descriptor.sector.z):body:\(bodyIndex):\(body.name)",
                        name: body.name,
                        kind: .world,
                        vector: vector,
                        distance: distance,
                        radius: body.radius,
                        celestialKind: body.kind,
                        hasAtmosphere: body.hasAtmosphere
                    )
                }
            }
            for (pointIndex, point) in region.descriptor.pointsOfInterest.enumerated() {
                let vectorDouble = position.vector(
                    to: region.descriptor.sector,
                    local: point.localPosition
                )
                let vector = SIMD3<Float>(vectorDouble)
                let distance = simd_length(vector)
                guard distance > 0.001,
                      simd_dot(direction, vector / distance) >= minimumAlignment else {
                    continue
                }
                let kind: NavigationTargetKind =
                    point.kind == .station ? .station : .wreckage
                if nearest.map({ distance < $0.distance }) ?? true {
                    nearest = NearbyNavigationTarget(
                        identifier: "\(region.descriptor.sector.x),\(region.descriptor.sector.y),\(region.descriptor.sector.z):\(pointIndex):\(point.kind.rawValue):\(point.name)",
                        name: point.name,
                        kind: kind,
                        vector: vector,
                        distance: distance,
                        radius: point.kind == .station
                            ? UniverseScale.stationRadius
                            : UniverseScale.wreckageRadius,
                        celestialKind: nil,
                        hasAtmosphere: false
                    )
                }
            }
        }
        return nearest
    }

    func destinations(
        to position: GalacticPosition,
        alignedWith direction: SIMD3<Float>,
        minimumAlignment: Float,
        maximumDistance: Float
    ) -> [NearbyNavigationTarget] {
        var matches: [NearbyNavigationTarget] = []
        for region in loadedRegions.values {
            for (bodyIndex, body) in region.descriptor.bodies.enumerated() {
                let vectorDouble = position.vector(
                    to: region.descriptor.sector,
                    local: body.localPosition
                )
                let vector = SIMD3<Float>(vectorDouble)
                let distance = simd_length(vector)
                guard distance > 0.001,
                      distance <= maximumDistance,
                      simd_dot(direction, vector / distance)
                        >= minimumAlignment else {
                    continue
                }
                matches.append(
                    NearbyNavigationTarget(
                        identifier: "\(region.descriptor.sector.x),\(region.descriptor.sector.y),\(region.descriptor.sector.z):body:\(bodyIndex):\(body.name)",
                        name: body.name,
                        kind: .world,
                        vector: vector,
                        distance: distance,
                        radius: body.radius,
                        celestialKind: body.kind,
                        hasAtmosphere: body.hasAtmosphere
                    )
                )
            }
            for (pointIndex, point) in
                region.descriptor.pointsOfInterest.enumerated() {
                let vectorDouble = position.vector(
                    to: region.descriptor.sector,
                    local: point.localPosition
                )
                let vector = SIMD3<Float>(vectorDouble)
                let distance = simd_length(vector)
                guard distance > 0.001,
                      distance <= maximumDistance,
                      simd_dot(direction, vector / distance)
                        >= minimumAlignment else {
                    continue
                }
                let kind: NavigationTargetKind =
                    point.kind == .station ? .station : .wreckage
                matches.append(
                    NearbyNavigationTarget(
                        identifier: "\(region.descriptor.sector.x),\(region.descriptor.sector.y),\(region.descriptor.sector.z):\(pointIndex):\(point.kind.rawValue):\(point.name)",
                        name: point.name,
                        kind: kind,
                        vector: vector,
                        distance: distance,
                        radius: point.kind == .station
                            ? UniverseScale.stationRadius
                            : UniverseScale.wreckageRadius,
                        celestialKind: nil,
                        hasAtmosphere: false
                    )
                )
            }
        }
        return matches.sorted { $0.distance < $1.distance }
    }

    func constrainSpaceMovement(
        from position: GalacticPosition,
        proposedDelta: SIMD3<Float>,
        clearance: Float
    ) -> (delta: SIMD3<Float>, obstacle: String?) {
        guard simd_length_squared(proposedDelta) > 0.000_001 else {
            return (proposedDelta, nil)
        }
        var earliestFraction: Float = 1
        var obstacle: String?

        for region in loadedRegions.values {
            for body in region.descriptor.bodies {
                let center = SIMD3<Float>(
                    position.vector(
                        to: region.descriptor.sector,
                        local: body.localPosition
                    )
                )
                if let fraction = segmentEntryFraction(
                    center: center,
                    radius: body.radius + clearance,
                    movement: proposedDelta
                ), fraction < earliestFraction {
                    earliestFraction = fraction
                    obstacle = body.name
                }
            }
            for point in region.descriptor.pointsOfInterest {
                let center = SIMD3<Float>(
                    position.vector(
                        to: region.descriptor.sector,
                        local: point.localPosition
                    )
                )
                let radius =
                    point.kind == .station
                        ? UniverseScale.stationRadius
                        : UniverseScale.wreckageRadius
                if let fraction = segmentEntryFraction(
                    center: center,
                    radius: radius + clearance,
                    movement: proposedDelta
                ), fraction < earliestFraction {
                    earliestFraction = fraction
                    obstacle = point.name
                }
            }
        }
        let safeFraction = max(0, earliestFraction - 0.0001)
        return (proposedDelta * safeFraction, obstacle)
    }

    func constrainSurfaceMovement(
        around position: GalacticPosition,
        proposedDelta: SIMD3<Float>,
        playerRadius: Float
    ) -> (
        delta: SIMD3<Float>,
        obstacle: String?,
        stepHeight: Float
    ) {
        guard let state = surfaceExplorationState,
              let world = destination(
                identifiedBy: state.worldIdentifier,
                to: position
              ),
              simd_length_squared(proposedDelta) > 0.000_001 else {
            return (proposedDelta, nil, 0)
        }
        let playerPoint = -world.vector
        let nextPlayerPoint = playerPoint + proposedDelta
        var earliestFraction: Float = 1
        var obstacle: String?
        var stepHeight: Float = 0

        func inspect(_ entity: Entity) {
            let collisionRadius: Float?
            let collisionHeight: Float
            let isStepable: Bool
            if entity.name.hasPrefix("Surface Forest Tree|") {
                collisionRadius =
                    1.55 * max(entity.scale.x, entity.scale.z)
                collisionHeight = 1.55 * entity.scale.y
                isStepable = false
            } else if entity.name.hasPrefix("Collectible Mineral|") {
                let tier = mineralDepositTier(encodedIn: entity.name)
                collisionRadius = 0.72 + Float(tier) * 0.19
                collisionHeight = 0.42 + Float(tier) * 0.08
                isStepable = true
            } else if entity.name.hasPrefix("Loose Mineral|")
                || entity.name.hasPrefix("Loose Electronic|")
                || entity.name.hasPrefix("Loose Log|")
                || entity.name.hasPrefix("Loose Creature Material|")
                || entity.name.hasPrefix("Step Surface|") {
                collisionRadius = 0.62
                collisionHeight = 0.32
                isStepable = true
            } else if entity.name.hasPrefix("Surface Creature|") {
                collisionRadius =
                    0.82 * max(entity.scale.x, entity.scale.z)
                collisionHeight = 0.78 * entity.scale.y
                isStepable = false
            } else if entity.name == "Surface Base" {
                collisionRadius = 4.6
                collisionHeight = 0.9
                isStepable = false
            } else if entity.name.hasPrefix(
                "Surface Security Robot|"
            ) {
                collisionRadius = 0.72
                collisionHeight = 0.82
                isStepable = false
            } else if entity.name == "Landed Ship" {
                collisionRadius = 2.5
                collisionHeight = 1.1
                isStepable = false
            } else if entity.name == "Parked Rover" {
                collisionRadius = 1.35
                collisionHeight = 0.65
                isStepable = false
            } else {
                collisionRadius = nil
                collisionHeight = 0
                isStepable = false
            }
            if let collisionRadius {
                let entityUp = entity.orientation(relativeTo: state.root)
                    .act(SIMD3<Float>(0, 1, 0))
                let center =
                    entity.position(relativeTo: state.root)
                        + entityUp * collisionHeight
                if isStepable {
                    let base = entity.position(relativeTo: state.root)
                    let offset = nextPlayerPoint - base
                    let horizontalOffset =
                        offset - entityUp * simd_dot(offset, entityUp)
                    if simd_length(horizontalOffset)
                        <= collisionRadius + playerRadius * 0.45 {
                        stepHeight = max(
                            stepHeight,
                            collisionHeight * 2
                        )
                    }
                    return
                }
                if let fraction = segmentEntryFraction(
                    center: center - playerPoint,
                    radius: collisionRadius + playerRadius,
                    movement: proposedDelta
                ), fraction < earliestFraction {
                    earliestFraction = fraction
                    obstacle = entity.name.split(separator: "|")
                        .first.map(String.init) ?? entity.name
                }
                return
            }
            for child in entity.children {
                inspect(child)
            }
        }
        inspect(state.root)
        let safeFraction = max(0, earliestFraction - 0.001)
        return (
            proposedDelta * safeFraction,
            obstacle,
            stepHeight
        )
    }

    private func segmentEntryFraction(
        center: SIMD3<Float>,
        radius: Float,
        movement: SIMD3<Float>
    ) -> Float? {
        let a = simd_length_squared(movement)
        guard a > 0.000_001 else { return nil }
        let c = simd_length_squared(center) - radius * radius
        if c <= 0 {
            return simd_dot(movement, center) > 0 ? 0 : nil
        }
        let b = -2 * simd_dot(center, movement)
        let discriminant = b * b - 4 * a * c
        guard discriminant >= 0 else { return nil }
        let entry = (-b - sqrt(discriminant)) / (2 * a)
        return entry >= 0 && entry <= 1 ? entry : nil
    }

    func isWreckageInvestigated(_ identifier: String) -> Bool {
        discoveries.isWreckageInvestigated(identifier)
    }

    func investigateWreckage(_ identifier: String) {
        discoveries.investigateWreckage(identifier)
    }

    private func repositionRegions(relativeTo center: GalacticSector) {
        for (sector, region) in loadedRegions {
            region.entity.position = SIMD3<Float>(
                Float(sector.x - center.x) * Float(GalacticPosition.sectorSize),
                Float(sector.y - center.y) * Float(GalacticPosition.sectorSize),
                Float(sector.z - center.z) * Float(GalacticPosition.sectorSize)
            )
        }
    }

    /// Keeps nearby render transforms small without changing galactic
    /// simulation coordinates. RealityKit stores transforms as Float, so
    /// subtracting the Double-precision player origin before conversion
    /// avoids cancellation jitter at planetary distances.
    func updateRenderOrigin(around position: GalacticPosition) {
        renderOrigin = position
        for (sector, region) in loadedRegions {
            let sectorOffset = SIMD3<Double>(
                Double(sector.x - position.sector.x),
                Double(sector.y - position.sector.y),
                Double(sector.z - position.sector.z)
            ) * GalacticPosition.sectorSize
            region.entity.position = SIMD3<Float>(sectorOffset)
            for child in region.entity.children {
                guard let simulationPosition =
                    regionChildSimulationPositions[
                        ObjectIdentifier(child)
                    ] else {
                    continue
                }
                child.position = SIMD3<Float>(
                    simulationPosition - position.local
                )
            }
        }
    }

    private func makeRegionEntity(_ region: ProceduralRegion) -> Entity {
        let regionRoot = Entity()
        regionRoot.name = "Sector \(region.sector.x),\(region.sector.y),\(region.sector.z)"

        let starMesh = MeshResource.generateSphere(radius: 0.05)
        let starMaterial = UnlitMaterial(color: .white)
        for position in region.stars {
            let star = ModelEntity(mesh: starMesh, materials: [starMaterial])
            star.position = position
            regionRoot.addChild(star)
        }

        for body in region.bodies {
            regionRoot.addChild(makeBodyEntity(body))
        }
        for point in region.pointsOfInterest {
            regionRoot.addChild(makePointOfInterestEntity(point))
        }
        return regionRoot
    }

    private func makePointOfInterestEntity(_ point: PointOfInterestDescriptor) -> Entity {
        let container = Entity()
        container.name = "\(point.kind.displayName): \(point.name)"
        container.position = SIMD3<Float>(point.localPosition)
        container.orientation =
            simd_quatf(angle: point.orientation.y, axis: [0, 1, 0])
            * simd_quatf(angle: point.orientation.x, axis: [1, 0, 0])
            * simd_quatf(angle: point.orientation.z, axis: [0, 0, 1])

        switch point.kind {
        case .station:
            container.scale = SIMD3<Float>(repeating: UniverseScale.station)
            addStationGeometry(to: container)
        case .wreckage:
            container.scale = SIMD3<Float>(repeating: UniverseScale.wreckage)
            addWreckageGeometry(to: container)
        }
        return container
    }

    private func addStationGeometry(to root: Entity) {
        let hull = SimpleMaterial(color: .darkGray, roughness: 0.35, isMetallic: true)
        let hub = ModelEntity(mesh: .generateSphere(radius: 2.8), materials: [hull])
        root.addChild(hub)

        let spine = ModelEntity(
            mesh: .generateCylinder(height: 14, radius: 1.15),
            materials: [hull]
        )
        root.addChild(spine)

        for angle in stride(from: Float.zero, to: 2 * .pi, by: .pi / 2) {
            let arm = ModelEntity(
                mesh: .generateBox(width: 13, height: 0.75, depth: 0.75),
                materials: [hull]
            )
            arm.orientation = simd_quatf(angle: angle, axis: [0, 1, 0])
            root.addChild(arm)

            let light = ModelEntity(
                mesh: .generateSphere(radius: 0.22),
                materials: [UnlitMaterial(color: .cyan)]
            )
            light.position = [cos(angle) * 6.4, 0, -sin(angle) * 6.4]
            root.addChild(light)
        }
    }

    private func addWreckageGeometry(to root: Entity) {
        let scorchedHull = SimpleMaterial(
            color: UIColor(white: 0.18, alpha: 1),
            roughness: 0.88,
            isMetallic: true
        )
        let fragments: [(SIMD3<Float>, SIMD3<Float>)] = [
            ([-3.4, 0.2, 0], [5.4, 1.2, 1.8]),
            ([2.5, 1.1, -1.7], [3.8, 0.7, 2.4]),
            ([0.8, -1.8, 2.9], [2.2, 1.4, 4.1]),
            ([4.6, -0.8, 2.0], [1.1, 2.7, 1.3])
        ]
        for (index, fragment) in fragments.enumerated() {
            let piece = ModelEntity(
                mesh: .generateBox(
                    width: fragment.1.x,
                    height: fragment.1.y,
                    depth: fragment.1.z
                ),
                materials: [scorchedHull]
            )
            piece.position = fragment.0
            piece.orientation = simd_quatf(
                angle: Float(index + 1) * 0.47,
                axis: simd_normalize(SIMD3<Float>(1, Float(index + 1), 0.6))
            )
            root.addChild(piece)
        }

        let distressBeacon = ModelEntity(
            mesh: .generateSphere(radius: 0.3),
            materials: [UnlitMaterial(color: .systemRed)]
        )
        distressBeacon.position = [0, 2.2, 0]
        root.addChild(distressBeacon)
    }

    private func makeBodyEntity(_ body: CelestialBodyDescriptor) -> Entity {
        let container = Entity()
        container.name = body.name
        container.position = SIMD3<Float>(body.localPosition)

        let color = color(for: body.kind)
        let material: any Material = body.kind == .star
            ? UnlitMaterial(color: color)
            : SimpleMaterial(color: color, roughness: 0.72, isMetallic: false)
        let sphere = ModelEntity(
            mesh: .generateSphere(radius: body.radius),
            materials: [material]
        )
        container.addChild(sphere)

        if body.kind == .star {
            let light = PointLight()
            light.light.color = color
            light.light.intensity = 16_000
            light.light.attenuationRadius = 2_400
            container.addChild(light)
        }

        if body.kind != .star && body.hasAtmosphere {
            let lowerAtmosphere = ModelEntity(
                mesh: .generateSphere(
                    radius: body.radius
                        + UniverseScale.lowerAtmosphereDepth(for: body.radius)
                ),
                materials: [
                    UnlitMaterial(color: color.withAlphaComponent(0.025))
                ]
            )
            lowerAtmosphere.name = "Lower Atmosphere"
            container.addChild(lowerAtmosphere)

            let upperAtmosphere = ModelEntity(
                mesh: .generateSphere(
                    radius: body.radius
                        + UniverseScale.upperAtmosphereDepth(for: body.radius)
                ),
                materials: [
                    UnlitMaterial(color: color.withAlphaComponent(0.008))
                ]
            )
            upperAtmosphere.name = "Upper Atmosphere"
            container.addChild(upperAtmosphere)
        }

        if body.kind != .star {
            let roughDetail = Entity()
            roughDetail.name = "Upper Atmosphere Detail"
            roughDetail.isEnabled = false
            container.addChild(roughDetail)
            let lowerDetail = Entity()
            lowerDetail.name = "Lower Atmosphere Detail"
            lowerDetail.isEnabled = false
            container.addChild(lowerDetail)
            let groundDetail = Entity()
            groundDetail.name = "Ground Detail"
            groundDetail.isEnabled = false
            container.addChild(groundDetail)
        }

        if body.hasRings {
            let ring = ModelEntity(
                mesh: .generateCylinder(height: 0.035, radius: body.radius * 1.75),
                materials: [UnlitMaterial(color: UIColor.systemYellow.withAlphaComponent(0.48))]
            )
            ring.orientation = simd_quatf(angle: .pi / 2.7, axis: SIMD3<Float>(1, 0, 0))
            container.addChild(ring)
        }
        return container
    }

    private func expandedLandingBiome(
        for body: CelestialBodyDescriptor,
        landingNormal: SIMD3<Float>,
        tangentRight: SIMD3<Float>,
        tangentForward: SIMD3<Float>
    ) -> (
        centerX: Float,
        centerZ: Float,
        halfWidth: Float,
        halfDepth: Float
    ) {
        let phase = Float(body.name.utf8.reduce(0) {
            ($0 + UInt64($1)) % 10_000
        }) * 0.013
        var closestIndex = 0
        var closestDirection = surfaceDirection(
            index: 0,
            count: 18,
            phase: phase
        )
        var closestAlignment = simd_dot(
            landingNormal,
            closestDirection
        )
        for index in 1..<18 {
            let direction = surfaceDirection(
                index: index,
                count: 18,
                phase: phase
            )
            let alignment = simd_dot(landingNormal, direction)
            if alignment > closestAlignment {
                closestIndex = index
                closestDirection = direction
                closestAlignment = alignment
            }
        }

        let originalHalfWidth =
            body.radius
            * (0.055 + Float(closestIndex % 4) * 0.014)
        let originalHalfDepth = originalHalfWidth * 0.72
        let landingDelta = (landingNormal - closestDirection) * body.radius
        let relativeX = max(
            -0.94,
            min(
                0.94,
                simd_dot(landingDelta, tangentRight)
                    / originalHalfWidth
            )
        )
        let relativeZ = max(
            -0.94,
            min(
                0.94,
                simd_dot(landingDelta, tangentForward)
                    / originalHalfDepth
            )
        )
        let expandedHalfWidth = originalHalfWidth * 50
        let expandedHalfDepth = originalHalfDepth * 50
        return (
            centerX: -relativeX * expandedHalfWidth,
            centerZ: -relativeZ * expandedHalfDepth,
            halfWidth: expandedHalfWidth,
            halfDepth: expandedHalfDepth
        )
    }

    private func makeExpandedBiomeSurface(
        state: SurfaceExplorationState
    ) -> ModelEntity? {
        let ringCount = 12
        let segmentCount = 48
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var indices: [UInt32] = []

        let centerDirection = projectedSurfaceDirection(
            x: state.biomeCenterX,
            z: state.biomeCenterZ,
            state: state
        )
        positions.append(
            centerDirection
                * (state.effectiveRadius + expandedBiomeElevation)
        )
        normals.append(centerDirection)

        for ring in 1...ringCount {
            let radiusFraction = Float(ring) / Float(ringCount)
            for segment in 0..<segmentCount {
                let angle =
                    Float(segment) / Float(segmentCount) * 2 * .pi
                let x =
                    state.biomeCenterX
                    + cos(angle) * state.biomeHalfWidth * radiusFraction
                let z =
                    state.biomeCenterZ
                    + sin(angle) * state.biomeHalfDepth * radiusFraction
                let direction = projectedSurfaceDirection(
                    x: x,
                    z: z,
                    state: state
                )
                positions.append(
                    direction
                        * (state.effectiveRadius + expandedBiomeElevation)
                )
                normals.append(direction)
            }
        }

        for segment in 0..<segmentCount {
            let current = UInt32(1 + segment)
            let next = UInt32(1 + (segment + 1) % segmentCount)
            indices.append(contentsOf: [0, current, next])
        }
        if ringCount > 1 {
            for ring in 1..<ringCount {
                let innerStart = 1 + (ring - 1) * segmentCount
                let outerStart = 1 + ring * segmentCount
                for segment in 0..<segmentCount {
                    let nextSegment = (segment + 1) % segmentCount
                    let innerCurrent = UInt32(innerStart + segment)
                    let innerNext = UInt32(innerStart + nextSegment)
                    let outerCurrent = UInt32(outerStart + segment)
                    let outerNext = UInt32(outerStart + nextSegment)
                    indices.append(
                        contentsOf: [
                            innerCurrent,
                            outerCurrent,
                            innerNext,
                            innerNext,
                            outerCurrent,
                            outerNext
                        ]
                    )
                }
            }
        }

        var descriptor = MeshDescriptor(name: "Expanded Landing Biome")
        descriptor.positions = MeshBuffers.Positions(positions)
        descriptor.normals = MeshBuffers.Normals(normals)
        descriptor.primitives = .triangles(indices)
        guard let mesh = try? MeshResource.generate(from: [descriptor]) else {
            return nil
        }
        let material = SimpleMaterial(
            color: surfaceBiomeColor(for: state.body.kind),
            roughness: 0.96,
            isMetallic: false
        )
        let entity = ModelEntity(mesh: mesh, materials: [material])
        entity.name = "Expanded Landing Biome"
        return entity
    }

    private func makeExplorationScalePlanetSurface(
        state: SurfaceExplorationState
    ) -> ModelEntity {
        let material = SimpleMaterial(
            color: color(for: state.body.kind),
            roughness: 0.96,
            isMetallic: false
        )
        let entity = ModelEntity(
            mesh: .generateSphere(radius: state.effectiveRadius),
            materials: [material]
        )
        entity.name = "Exploration Scale Planet Surface"
        return entity
    }

    private func positionSurfaceMarker(
        _ marker: Entity,
        at position: GalacticPosition,
        state: SurfaceExplorationState
    ) {
        guard let world = destination(
            identifiedBy: state.worldIdentifier,
            to: position
        ), world.distance > 0.001 else {
            marker.isEnabled = false
            return
        }
        let surfaceUp = simd_normalize(-world.vector)
        let elevation = surfaceElevation(around: position)
        marker.position =
            surfaceUp * (state.effectiveRadius + elevation)
        marker.orientation = simd_quatf(
            from: SIMD3<Float>(0, 1, 0),
            to: surfaceUp
        )
    }

    private func makeSurfaceShipMarker() -> Entity {
        let ship = Entity()
        ship.name = "Landed Ship"
        let hullMaterial = SimpleMaterial(
            color: UIColor(white: 0.72, alpha: 1),
            roughness: 0.26,
            isMetallic: true
        )
        let windowMaterial = UnlitMaterial(
            color: UIColor.systemCyan.withAlphaComponent(0.92)
        )
        let hull = ModelEntity(
            mesh: .generateBox(
                width: 3.2,
                height: 1.25,
                depth: 6.4,
                cornerRadius: 0.45
            ),
            materials: [hullMaterial]
        )
        hull.position.y = 1.05
        ship.addChild(hull)
        let canopy = ModelEntity(
            mesh: .generateSphere(radius: 1.15),
            materials: [windowMaterial]
        )
        canopy.position = [0, 1.85, -0.65]
        canopy.scale = [1, 0.55, 1.35]
        ship.addChild(canopy)
        for side: Float in [-1, 1] {
            let wing = ModelEntity(
                mesh: .generateBox(
                    width: 2.8,
                    height: 0.22,
                    depth: 3.5
                ),
                materials: [hullMaterial]
            )
            wing.position = [side * 2.25, 0.72, 0.35]
            ship.addChild(wing)
        }
        return ship
    }

    private func makeSurfaceRoverMarker() -> Entity {
        let rover = Entity()
        rover.name = "Parked Rover"
        let bodyMaterial = SimpleMaterial(
            color: UIColor(red: 0.62, green: 0.32, blue: 0.08, alpha: 1),
            roughness: 0.48,
            isMetallic: true
        )
        let tireMaterial = SimpleMaterial(
            color: UIColor(white: 0.06, alpha: 1),
            roughness: 0.92,
            isMetallic: false
        )
        let body = ModelEntity(
            mesh: .generateBox(
                width: 2.1,
                height: 0.8,
                depth: 3.4,
                cornerRadius: 0.28
            ),
            materials: [bodyMaterial]
        )
        body.position.y = 0.95
        rover.addChild(body)
        for side: Float in [-1, 1] {
            for depth: Float in [-1.05, 1.05] {
                let wheel = ModelEntity(
                    mesh: .generateCylinder(height: 0.34, radius: 0.48),
                    materials: [tireMaterial]
                )
                wheel.position = [side * 1.15, 0.48, depth]
                wheel.orientation = simd_quatf(
                    angle: .pi / 2,
                    axis: [0, 0, 1]
                )
                rover.addChild(wheel)
            }
        }
        return rover
    }

    private func projectedSurfaceDirection(
        x: Float,
        z: Float,
        state: SurfaceExplorationState
    ) -> SIMD3<Float> {
        simd_normalize(
            state.anchorNormal * state.effectiveRadius
                + state.tangentRight * x
                + state.tangentForward * z
        )
    }

    private func isInsideExpandedBiome(
        x: Float,
        z: Float,
        state: SurfaceExplorationState,
        normalizedLimit: Float = 1
    ) -> Bool {
        guard state.body.hasAtmosphere else { return true }
        let normalizedX =
            (x - state.biomeCenterX) / state.biomeHalfWidth
        let normalizedZ =
            (z - state.biomeCenterZ) / state.biomeHalfDepth
        return normalizedX * normalizedX + normalizedZ * normalizedZ
            <= normalizedLimit * normalizedLimit
    }

    private func surfaceBiomeColor(
        for kind: CelestialBodyKind
    ) -> UIColor {
        switch kind {
        case .ocean:
            UIColor(red: 0.12, green: 0.34, blue: 0.12, alpha: 1)
        case .desert:
            UIColor(red: 0.42, green: 0.16, blue: 0.055, alpha: 1)
        case .rocky:
            UIColor(white: 0.22, alpha: 1)
        case .ice:
            UIColor(red: 0.72, green: 0.88, blue: 0.93, alpha: 1)
        case .gas:
            UIColor(red: 0.34, green: 0.18, blue: 0.48, alpha: 1)
        case .star:
            .clear
        }
    }

    private func makeSurfaceTile(
        coordinate: SurfaceTileCoordinate,
        state: SurfaceExplorationState
    ) -> Entity {
        let tile = Entity()
        tile.name = "Surface Tile \(coordinate.x),\(coordinate.z)"

        var seed = state.body.name.utf8.reduce(UInt64(0x51F4_CE)) {
            ($0 &* 1_099_511_628_211) ^ UInt64($1)
        }
        seed ^= UInt64(bitPattern: Int64(coordinate.x))
            &* 0x9E37_79B9_7F4A_7C15
        seed ^= UInt64(bitPattern: Int64(coordinate.z))
            &* 0xD1B5_4A32_D192_ED03
        var random = UniverseRandom(seed: seed)

        if state.body.hasAtmosphere {
            addSurfaceForest(
                to: tile,
                coordinate: coordinate,
                state: state,
                random: &random
            )
            addSurfaceMinerals(
                to: tile,
                coordinate: coordinate,
                state: state,
                count: 3,
                random: &random
            )
            addSurfaceCreatures(
                to: tile,
                coordinate: coordinate,
                state: state,
                random: &random
            )
        } else {
            addSurfaceMinerals(
                to: tile,
                coordinate: coordinate,
                state: state,
                count: 12,
                random: &random
            )
            if random.chance(0.16) {
                addSurfaceBase(
                    to: tile,
                    coordinate: coordinate,
                    state: state
                )
                addSurfaceSecurityRobots(
                    to: tile,
                    coordinate: coordinate,
                    state: state,
                    random: &random
                )
            }
        }
        return tile
    }

    private func addSurfaceForest(
        to tile: Entity,
        coordinate: SurfaceTileCoordinate,
        state: SurfaceExplorationState,
        random: inout UniverseRandom
    ) {
        let trunkColor: UIColor = switch state.body.kind {
        case .ocean:
            UIColor(red: 0.20, green: 0.09, blue: 0.035, alpha: 1)
        case .desert:
            UIColor(red: 0.35, green: 0.10, blue: 0.025, alpha: 1)
        case .rocky:
            UIColor(white: 0.18, alpha: 1)
        case .ice:
            UIColor(red: 0.32, green: 0.70, blue: 0.88, alpha: 1)
        case .gas:
            UIColor(red: 0.38, green: 0.12, blue: 0.50, alpha: 1)
        case .star:
            .darkGray
        }
        let canopyColor: UIColor = switch state.body.kind {
        case .ocean:
            UIColor(red: 0.03, green: 0.32, blue: 0.07, alpha: 1)
        case .desert:
            UIColor(red: 0.94, green: 0.42, blue: 0.06, alpha: 1)
        case .rocky:
            UIColor(red: 0.48, green: 0.32, blue: 0.62, alpha: 1)
        case .ice:
            UIColor(red: 0.74, green: 0.95, blue: 1, alpha: 1)
        case .gas:
            UIColor(red: 0.92, green: 0.34, blue: 0.72, alpha: 1)
        case .star:
            .white
        }
        let trunkMaterial = SimpleMaterial(
            color: trunkColor,
            roughness: 0.96,
            isMetallic: false
        )
        let canopyMaterial = SimpleMaterial(
            color: canopyColor,
            roughness: 0.90,
            isMetallic: false
        )
        let treeCount = Int(surfacePerspectiveScale * 0.58)
        let trunkMesh = MeshResource.generateCylinder(
            height: 2.8,
            radius: 0.16
        )
        let canopyMesh = MeshResource.generateSphere(radius: 1.15)
        for index in 0..<treeCount {
            let x =
                Float(coordinate.x) * surfaceTileSize
                + random.float(
                    in: -surfaceTileSize * 0.43...surfaceTileSize * 0.43
                )
            let z =
                Float(coordinate.z) * surfaceTileSize
                + random.float(
                    in: -surfaceTileSize * 0.43...surfaceTileSize * 0.43
                )
            // The landing point can be as far as 94% from the oval center.
            // Keep trees within the biome while still populating edge landings.
            guard isInsideExpandedBiome(
                x: x,
                z: z,
                state: state,
                normalizedLimit: 0.97
            ) else {
                continue
            }
            let scale = random.float(in: 0.72...1.45)
            let resourceIdentifier = surfaceResourceIdentifier(
                worldIdentifier: state.worldIdentifier,
                coordinate: coordinate,
                category: "tree",
                index: index
            )
            guard !surfaceResources.contains(resourceIdentifier) else {
                continue
            }
            let direction = projectedSurfaceDirection(
                x: x,
                z: z,
                state: state
            )
            let tree = Entity()
            tree.name =
                "Surface Forest Tree|\(resourceIdentifier)"
            // Sink the trunk base slightly into the exact expanded-biome
            // surface. Only purpose-built balloon trees may float.
            tree.position = direction * (
                state.effectiveRadius
                    + expandedBiomeElevation - 0.03
            )
            tree.orientation = simd_quatf(
                from: SIMD3<Float>(0, 1, 0),
                to: direction
            )
            tree.scale = SIMD3<Float>(repeating: scale)
            let trunk = ModelEntity(
                mesh: trunkMesh,
                materials: [trunkMaterial]
            )
            trunk.position.y = 1.4
            tree.addChild(trunk)
            let canopy = ModelEntity(
                mesh: canopyMesh,
                materials: [canopyMaterial]
            )
            canopy.position.y = 3.15
            canopy.scale = index.isMultiple(of: 3)
                ? [0.72, 1.42, 0.72]
                : [1.15, 0.82, 1.15]
            tree.addChild(canopy)
            tile.addChild(tree)
        }
    }

    private func addSurfaceMinerals(
        to tile: Entity,
        coordinate: SurfaceTileCoordinate,
        state: SurfaceExplorationState,
        count: Int,
        random: inout UniverseRandom
    ) {
        let mesh = MeshResource.generateBox(
            width: 0.32,
            height: 1.8,
            depth: 0.32
        )
        for index in 0..<count {
            let x =
                Float(coordinate.x) * surfaceTileSize
                + random.float(
                    in: -surfaceTileSize * 0.44...surfaceTileSize * 0.44
                )
            let z =
                Float(coordinate.z) * surfaceTileSize
                + random.float(
                    in: -surfaceTileSize * 0.44...surfaceTileSize * 0.44
                )
            guard isInsideExpandedBiome(
                x: x,
                z: z,
                state: state,
                normalizedLimit: 0.98
            ) else {
                continue
            }
            let direction = projectedSurfaceDirection(
                x: x,
                z: z,
                state: state
            )
            let materialName = mineralMaterialName(
                for: state.body,
                random: &random
            )
            let depositTier = random.int(in: 0...4)
            let resourceIdentifier = surfaceResourceIdentifier(
                worldIdentifier: state.worldIdentifier,
                coordinate: coordinate,
                category: "mineral",
                index: index
            )
            guard !surfaceResources.contains(resourceIdentifier) else {
                continue
            }
            let material = SimpleMaterial(
                color: mineralMaterialColor(
                    for: state.body.kind,
                    materialName: materialName
                ),
                roughness: 0.28,
                isMetallic: true
            )
            let formation = Entity()
            formation.name =
                "Collectible Mineral|\(materialName)"
                + "|\(resourceIdentifier)|\(depositTier)"
            let terrainElevation =
                state.body.hasAtmosphere ? expandedBiomeElevation : 0
            formation.position =
                direction * (
                    state.effectiveRadius
                        + terrainElevation
                )
            formation.orientation = simd_quatf(
                from: SIMD3<Float>(0, 1, 0),
                to: direction
            )
            let shardCounts = [2, 3, 4, 5, 7]
            let lengthScales: [Float] = [0.48, 0.72, 0.96, 1.26, 1.62]
            let thicknessScales: [Float] = [0.70, 0.84, 1, 1.18, 1.38]
            let shardCount = shardCounts[depositTier]
            let baseLength = lengthScales[depositTier]
            let thickness = thicknessScales[depositTier]
            for shardIndex in 0..<shardCount {
                let shard = ModelEntity(
                    mesh: mesh,
                    materials: [material]
                )
                let centeredIndex =
                    Float(shardIndex) - Float(shardCount - 1) * 0.5
                let lengthVariation =
                    0.76 + Float((shardIndex * 3 + index) % 4) * 0.09
                shard.scale = [
                    thickness
                        * (0.82 + Float(shardIndex % 2) * 0.16),
                    baseLength * lengthVariation,
                    thickness
                ]
                shard.position = [
                    centeredIndex * 0.22 * thickness,
                    0,
                    Float(shardIndex % 3 - 1) * 0.12 * thickness
                ]
                let fanAngle =
                    centeredIndex * (0.16 + Float(depositTier) * 0.018)
                // Each crystal lies on its back with its center at the
                // terrain plane, leaving the upper half visible.
                shard.orientation =
                    simd_quatf(angle: fanAngle, axis: [0, 1, 0])
                    * simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
                formation.addChild(shard)
            }
            tile.addChild(formation)
        }
    }

    private func addSurfaceBase(
        to tile: Entity,
        coordinate: SurfaceTileCoordinate,
        state: SurfaceExplorationState
    ) {
        let base = Entity()
        base.name = "Surface Base"
        let x = Float(coordinate.x) * surfaceTileSize
        let z = Float(coordinate.z) * surfaceTileSize
        let direction = projectedSurfaceDirection(
            x: x,
            z: z,
            state: state
        )
        base.position = direction * (state.effectiveRadius + 0.02)
        base.orientation = simd_quatf(
            from: SIMD3<Float>(0, 1, 0),
            to: direction
        )
        let hullMaterial = SimpleMaterial(
            color: UIColor(white: 0.28, alpha: 1),
            roughness: 0.38,
            isMetallic: true
        )
        let platform = ModelEntity(
            mesh: .generateCylinder(height: 0.35, radius: 4.5),
            materials: [hullMaterial]
        )
        platform.position.y = 0.08
        base.addChild(platform)
        let habitat = ModelEntity(
            mesh: .generateSphere(radius: 2.4),
            materials: [hullMaterial]
        )
        habitat.position.y = 1.25
        habitat.scale.y = 0.58
        base.addChild(habitat)
        let beacon = ModelEntity(
            mesh: .generateSphere(radius: 0.28),
            materials: [
                UnlitMaterial(color: color(for: state.body.kind))
            ]
        )
        beacon.position.y = 3.2
        base.addChild(beacon)
        tile.addChild(base)
    }

    private func addSurfaceCreatures(
        to tile: Entity,
        coordinate: SurfaceTileCoordinate,
        state: SurfaceExplorationState,
        random: inout UniverseRandom
    ) {
        let speciesNames: [String] = switch state.body.kind {
        case .ocean: ["Reef Strider", "Moss Grazer", "Tideback"]
        case .desert: ["Dune Skitter", "Ember Horn", "Sand Prowler"]
        case .rocky: ["Slate Runner", "Cave Grazer", "Crag Stalker"]
        case .ice: ["Frost Hopper", "Glassback", "Rime Hunter"]
        case .gas: ["Cloud Walker", "Vapor Grazer", "Storm Prowler"]
        case .star: []
        }
        guard !speciesNames.isEmpty else { return }

        let creatureCount = random.int(in: 3...5)
        let worldCreatureSeed = state.worldIdentifier.utf8.reduce(
            UInt64(0xA11E_51F3)
        ) {
            ($0 &* 1_099_511_628_211) ^ UInt64($1)
        }
        let hostileSpeciesIndex =
            Int(worldCreatureSeed % UInt64(speciesNames.count))
        let baseX = Float(coordinate.x) * surfaceTileSize
        let baseZ = Float(coordinate.z) * surfaceTileSize

        for index in 0..<creatureCount {
            let homeX = baseX + random.float(in: -18...18)
            let homeZ = baseZ + random.float(in: -18...18)
            guard isInsideExpandedBiome(
                x: homeX,
                z: homeZ,
                state: state,
                normalizedLimit: 0.94
            ) else {
                continue
            }
            // Every populated tile begins with one member of each of the
            // world's three species, then fills any additional encounters.
            let speciesIndex =
                index < speciesNames.count
                    ? index
                    : random.int(in: 0...(speciesNames.count - 1))
            let speciesName = speciesNames[speciesIndex]
            let isAggressive = speciesIndex == hostileSpeciesIndex
            let heading = random.float(in: 0...(2 * .pi))
            let speed = random.float(
                in: isAggressive ? 1.25...1.65 : 0.55...0.95
            )
            let phase = random.float(in: 0...(2 * .pi))
            let size = random.float(in: 0.82...1.28)
            var speciesRandom = UniverseRandom(
                seed:
                    worldCreatureSeed
                    ^ (
                        UInt64(speciesIndex + 1)
                            &* 0x9E37_79B9_7F4A_7C15
                    )
            )
            let heads = ["lizard", "bear", "eagle", "mosquito", "spider"]
            let bodies = ["upright", "hunched", "horizontal"]
            let arms = [
                "claws", "crab claws", "monkey hands", "matching legs"
            ]
            let legs = [
                "heavy", "jumping", "spider", "tentacle", "tall", "short"
            ]
            let wings = ["bat", "eagle", "gliding", "none"]
            let tails = ["long", "spiked", "stubby", "multiple"]
            let headType =
                heads[speciesRandom.int(in: 0...(heads.count - 1))]
            let bodyType =
                bodies[speciesRandom.int(in: 0...(bodies.count - 1))]
            let armType =
                arms[speciesRandom.int(in: 0...(arms.count - 1))]
            let legType =
                legs[speciesRandom.int(in: 0...(legs.count - 1))]
            let wingType =
                wings[speciesRandom.int(in: 0...(wings.count - 1))]
            let tailType =
                tails[speciesRandom.int(in: 0...(tails.count - 1))]
            let direction = projectedSurfaceDirection(
                x: homeX,
                z: homeZ,
                state: state
            )

            let creature = Entity()
            creature.name =
                "Surface Creature|\(isAggressive ? 1 : 0)"
                + "|\(homeX)|\(homeZ)|\(heading)|\(speed)"
                + "|\(phase)|\(speciesName)|\(wingType)"
            creature.position = direction * (
                state.effectiveRadius + expandedBiomeElevation
            )
            creature.orientation = simd_quatf(
                from: SIMD3<Float>(0, 1, 0),
                to: direction
            )
            creature.scale = SIMD3<Float>(repeating: size)

            let baseColor = creatureColor(
                for: state.body.kind,
                speciesIndex: speciesIndex
            )
            addCreatureAnatomy(
                to: creature,
                head: headType,
                body: bodyType,
                arms: armType,
                legs: legType,
                wings: wingType,
                tail: tailType,
                color: baseColor,
                isAggressive: isAggressive
            )
            let hitFlash = ModelEntity(
                mesh: .generateSphere(radius: 1.08),
                materials: [
                    UnlitMaterial(
                        color: UIColor.white.withAlphaComponent(0.32)
                    )
                ]
            )
            hitFlash.name = "Creature Hit Flash"
            hitFlash.position.y = 0.82
            hitFlash.isEnabled = false
            creature.addChild(hitFlash)
            updateResourceHealthBar(
                on: creature,
                fraction: 1,
                height: 2.25
            )
            tile.addChild(creature)
        }
    }

    private func addCreatureAnatomy(
        to creature: Entity,
        head headType: String,
        body bodyType: String,
        arms armType: String,
        legs legType: String,
        wings wingType: String,
        tail tailType: String,
        color: UIColor,
        isAggressive: Bool
    ) {
        let skin = SimpleMaterial(
            color: color,
            roughness: 0.76,
            isMetallic: false
        )
        let accent = SimpleMaterial(
            color: color.withAlphaComponent(0.92),
            roughness: 0.62,
            isMetallic: false
        )
        let body = ModelEntity(
            mesh: .generateSphere(radius: 0.52),
            materials: [skin]
        )
        body.name = "Creature Body"
        switch bodyType {
        case "upright":
            body.position.y = 1.02
            body.scale = [0.76, 1.34, 0.72]
        case "hunched":
            body.position.y = 0.84
            body.scale = [1.05, 0.90, 1.14]
            body.orientation = simd_quatf(
                angle: -0.28,
                axis: [1, 0, 0]
            )
        default:
            body.position.y = 0.72
            body.scale = [1.05, 0.66, 1.42]
        }
        creature.addChild(body)

        let headHeight: Float = bodyType == "upright" ? 1.62 : 0.92
        // Creature anatomy uses local +Z as its forward/head direction.
        let headForward: Float = bodyType == "upright" ? 0.28 : 0.78
        let head = ModelEntity(
            mesh: .generateSphere(radius: 0.30),
            materials: [accent]
        )
        head.name = "Creature Head \(headType)"
        head.position = [0, headHeight, headForward]
        switch headType {
        case "lizard":
            head.scale = [0.82, 0.66, 1.45]
        case "bear":
            head.scale = [1.22, 1.12, 1.02]
            for side: Float in [-1, 1] {
                let ear = ModelEntity(
                    mesh: .generateSphere(radius: 0.10),
                    materials: [accent]
                )
                ear.position = [
                    side * 0.20,
                    headHeight + 0.25,
                    headForward
                ]
                creature.addChild(ear)
            }
        case "eagle":
            head.scale = [0.86, 1.0, 0.92]
            let beak = ModelEntity(
                mesh: .generateBox(
                    width: 0.15,
                    height: 0.11,
                    depth: 0.34
                ),
                materials: [
                    SimpleMaterial(
                        color: .systemYellow,
                        roughness: 0.60,
                        isMetallic: false
                    )
                ]
            )
            beak.position = [0, headHeight - 0.02, headForward + 0.31]
            creature.addChild(beak)
        case "mosquito":
            head.scale = [0.72, 0.72, 0.72]
            let proboscis = ModelEntity(
                mesh: .generateCylinder(height: 0.54, radius: 0.025),
                materials: [accent]
            )
            proboscis.position = [0, headHeight, headForward + 0.38]
            proboscis.orientation = simd_quatf(
                angle: .pi / 2,
                axis: [1, 0, 0]
            )
            creature.addChild(proboscis)
        default:
            head.scale = [1.18, 0.62, 1.08]
        }

        let eyeMaterial = UnlitMaterial(
            color: isAggressive ? .systemRed : .systemCyan
        )
        let eyeCount = headType == "spider" ? 4 : 2
        for eyeIndex in 0..<eyeCount {
            let eye = ModelEntity(
                mesh: .generateSphere(radius: 0.045),
                materials: [eyeMaterial]
            )
            let row = eyeIndex / 2
            let side: Float = eyeIndex.isMultiple(of: 2) ? -1 : 1
            eye.position = [
                side * (row == 0 ? 0.13 : 0.21),
                headHeight + Float(row) * 0.10,
                headForward + 0.29
            ]
            creature.addChild(eye)
        }
        creature.addChild(head)

        let legCount = legType == "spider" ? 8 : (legType == "tentacle" ? 6 : 4)
        let legHeight: Float = switch legType {
        case "tall": 1.02
        case "jumping", "heavy": 0.76
        case "short": 0.42
        default: 0.62
        }
        let legRadius: Float = legType == "heavy" ? 0.15 : 0.085
        for legIndex in 0..<legCount {
            let side: Float = legIndex.isMultiple(of: 2) ? -1 : 1
            let row = legIndex / 2
            let rowCount = max(2, legCount / 2)
            let rowFraction =
                Float(row) / Float(max(1, rowCount - 1))
            let z = -0.42 + rowFraction * 0.84
            let leg = ModelEntity(
                mesh: .generateCylinder(
                    height: legHeight,
                    radius: legType == "tentacle"
                        ? 0.055
                        : legRadius
                ),
                materials: [accent]
            )
            leg.name = "Creature Leg \(legIndex)|\(legType)"
            leg.position = [
                side * (legType == "spider" ? 0.48 : 0.34),
                legHeight * 0.45,
                z
            ]
            if legType == "spider" {
                leg.orientation = simd_quatf(
                    angle: side * 0.58,
                    axis: [0, 0, 1]
                )
            }
            creature.addChild(leg)
        }

        for side: Float in [-1, 1] {
            let armLength: Float =
                armType == "monkey hands" ? 0.82 : 0.48
            let arm = ModelEntity(
                mesh: .generateCylinder(height: armLength, radius: 0.075),
                materials: [accent]
            )
            arm.name = "Creature Arm"
            arm.position = [
                side * 0.52,
                bodyType == "upright" ? 1.12 : 0.76,
                -0.18
            ]
            arm.orientation = simd_quatf(
                angle: side * .pi / 3,
                axis: [0, 0, 1]
            )
            creature.addChild(arm)
            let hand = ModelEntity(
                mesh: .generateSphere(
                    radius: armType == "crab claws" ? 0.18 : 0.11
                ),
                materials: [accent]
            )
            hand.name = "Creature \(armType)"
            hand.position = [
                side * (0.52 + armLength * 0.38),
                bodyType == "upright" ? 0.88 : 0.58,
                -0.18
            ]
            hand.scale = armType == "claws"
                ? [0.55, 0.72, 1.35]
                : [1, 1, 1]
            creature.addChild(hand)
        }

        if wingType != "none" {
            for side: Float in [-1, 1] {
                let wing = ModelEntity(
                    mesh: .generateBox(
                        width: wingType == "gliding" ? 1.15 : 0.92,
                        height: 0.045,
                        depth: wingType == "bat" ? 0.68 : 0.48
                    ),
                    materials: [accent]
                )
                wing.name = "Creature Wing \(side < 0 ? 0 : 1)"
                wing.position = [side * 0.72, 1.02, 0.05]
                wing.orientation = simd_quatf(
                    angle: side * 0.20,
                    axis: [0, 0, 1]
                )
                creature.addChild(wing)
            }
        }

        let tailCount = tailType == "multiple" ? 3 : 1
        for tailIndex in 0..<tailCount {
            let tailLength: Float = switch tailType {
            case "long": 1.18
            case "stubby": 0.36
            default: 0.76
            }
            let tail = ModelEntity(
                mesh: .generateCylinder(
                    height: tailLength,
                    radius: tailType == "spiked" ? 0.10 : 0.065
                ),
                materials: [accent]
            )
            tail.name = "Creature Tail \(tailIndex)"
            tail.position = [
                Float(tailIndex - (tailCount - 1) / 2) * 0.16,
                0.72,
                -0.68 - tailLength * 0.35
            ]
            tail.orientation = simd_quatf(
                angle: .pi / 2,
                axis: [1, 0, 0]
            )
            creature.addChild(tail)
        }
    }

    private func creatureColor(
        for kind: CelestialBodyKind,
        speciesIndex: Int
    ) -> UIColor {
        let palette: [UIColor] = switch kind {
        case .ocean:
            [.systemGreen, .systemTeal, .systemBlue]
        case .desert:
            [.systemOrange, .systemBrown, .systemRed]
        case .rocky:
            [.systemGray, .systemPurple, .systemIndigo]
        case .ice:
            [.systemCyan, .white, .systemBlue]
        case .gas:
            [.systemPurple, .systemPink, .systemYellow]
        case .star:
            [.white]
        }
        return palette[speciesIndex % palette.count]
    }

    private func addSurfaceSecurityRobots(
        to tile: Entity,
        coordinate: SurfaceTileCoordinate,
        state: SurfaceExplorationState,
        random: inout UniverseRandom
    ) {
        let shellMaterial = SimpleMaterial(
            color: UIColor(white: 0.16, alpha: 1),
            roughness: 0.24,
            isMetallic: true
        )
        let armorMaterial = SimpleMaterial(
            color: UIColor(red: 0.34, green: 0.05, blue: 0.04, alpha: 1),
            roughness: 0.32,
            isMetallic: true
        )
        let bodyMesh = MeshResource.generateBox(
            width: 0.72,
            height: 0.82,
            depth: 0.50
        )
        let headMesh = MeshResource.generateBox(
            width: 0.56,
            height: 0.34,
            depth: 0.42
        )
        let limbMesh = MeshResource.generateCylinder(
            height: 0.68,
            radius: 0.09
        )
        let eyeMesh = MeshResource.generateSphere(radius: 0.09)
        let robotCount = random.int(in: 3...5)
        let baseX = Float(coordinate.x) * surfaceTileSize
        let baseZ = Float(coordinate.z) * surfaceTileSize

        for index in 0..<robotCount {
            let angle = random.float(in: 0...(2 * .pi))
            let patrolRadius = random.float(in: 5.5...10)
            let x = baseX + cos(angle) * patrolRadius
            let z = baseZ + sin(angle) * patrolRadius
            let direction = projectedSurfaceDirection(
                x: x,
                z: z,
                state: state
            )
            let robot = Entity()
            robot.name =
                "Surface Security Robot|\(coordinate.x)|"
                + "\(coordinate.z)|\(index)"
            robot.position =
                direction * (state.effectiveRadius + 0.02)
            robot.orientation = simd_quatf(
                from: SIMD3<Float>(0, 1, 0),
                to: direction
            )

            let body = ModelEntity(
                mesh: bodyMesh,
                materials: [armorMaterial]
            )
            body.position.y = 0.88
            robot.addChild(body)
            let head = ModelEntity(
                mesh: headMesh,
                materials: [shellMaterial]
            )
            head.position.y = 1.44
            robot.addChild(head)
            for side: Float in [-1, 1] {
                let leg = ModelEntity(
                    mesh: limbMesh,
                    materials: [shellMaterial]
                )
                leg.position = [side * 0.23, 0.35, 0]
                robot.addChild(leg)
                let arm = ModelEntity(
                    mesh: limbMesh,
                    materials: [armorMaterial]
                )
                arm.position = [side * 0.48, 0.91, 0]
                arm.orientation = simd_quatf(
                    angle: .pi / 2,
                    axis: [0, 0, 1]
                )
                robot.addChild(arm)
            }
            let eye = ModelEntity(
                mesh: eyeMesh,
                materials: [UnlitMaterial(color: .systemRed)]
            )
            eye.position = [0, 1.48, -0.23]
            robot.addChild(eye)
            tile.addChild(robot)
        }
    }

    private func updateSurfaceSecurityRobots(
        in root: Entity,
        toward playerSurfacePoint: SIMD3<Float>,
        state: SurfaceExplorationState
    ) {
        var robots: [Entity] = []
        func collect(from entity: Entity) {
            if entity.name.hasPrefix("Surface Security Robot|") {
                robots.append(entity)
            }
            for child in entity.children {
                collect(from: child)
            }
        }
        collect(from: root)

        let playerX = simd_dot(playerSurfacePoint, state.tangentRight)
        let playerZ = simd_dot(playerSurfacePoint, state.tangentForward)
        for robot in robots {
            let components = robot.name.split(separator: "|")
            guard components.count >= 3,
                  let tileX = Float(components[1]),
                  let tileZ = Float(components[2]) else {
                continue
            }
            let position = robot.position(relativeTo: root)
            let robotX = simd_dot(position, state.tangentRight)
            let robotZ = simd_dot(position, state.tangentForward)
            let toPlayer = SIMD2<Float>(
                playerX - robotX,
                playerZ - robotZ
            )
            let distance = simd_length(toPlayer)
            let home = SIMD2<Float>(
                tileX * surfaceTileSize,
                tileZ * surfaceTileSize
            )
            let distanceFromHome = simd_length(
                SIMD2<Float>(robotX, robotZ) - home
            )
            guard distance > 1.8,
                  distance < 22,
                  distanceFromHome < 17 else {
                continue
            }
            let step = simd_normalize(toPlayer) * min(0.025, distance - 1.8)
            let nextX = robotX + step.x
            let nextZ = robotZ + step.y
            let direction = projectedSurfaceDirection(
                x: nextX,
                z: nextZ,
                state: state
            )
            robot.setPosition(
                direction * (state.effectiveRadius + 0.02),
                relativeTo: root
            )
            robot.setOrientation(
                simd_quatf(
                    from: SIMD3<Float>(0, 1, 0),
                    to: direction
                ),
                relativeTo: root
            )
        }
    }

    private func updateSurfaceCreatures(
        in root: Entity,
        toward playerSurfacePoint: SIMD3<Float>,
        deltaTime: Float,
        state: inout SurfaceExplorationState
    ) {
        var creatures: [Entity] = []
        func collect(from entity: Entity) {
            if entity.name.hasPrefix("Surface Creature|") {
                creatures.append(entity)
            }
            for child in entity.children {
                collect(from: child)
            }
        }
        collect(from: root)

        var obstacles: [CreatureObstacle] = []
        func collectObstacles(from entity: Entity) {
            guard entity.isEnabled else { return }
            let radius: Float?
            let height: Float
            if entity.name.hasPrefix("Surface Forest Tree|") {
                radius = 1.55 * max(entity.scale.x, entity.scale.z)
                height = 3.1 * entity.scale.y
            } else if entity.name.hasPrefix("Collectible Mineral|") {
                let tier = mineralDepositTier(encodedIn: entity.name)
                radius = 0.72 + Float(tier) * 0.19
                height = 0.84 + Float(tier) * 0.16
            } else if entity.name.hasPrefix("Loose Mineral|")
                || entity.name.hasPrefix("Loose Electronic|")
                || entity.name.hasPrefix("Loose Log|")
                || entity.name.hasPrefix("Loose Creature Material|")
                || entity.name.hasPrefix("Step Surface|") {
                radius = 0.62
                height = 0.64
            } else if entity.name == "Surface Base" {
                radius = 4.6
                height = 2.8
            } else if entity.name.hasPrefix("Surface Security Robot|") {
                radius = 0.72
                height = 1.64
            } else if entity.name == "Landed Ship" {
                radius = 2.5
                height = 2.2
            } else if entity.name == "Parked Rover" {
                radius = 1.35
                height = 1.3
            } else {
                radius = nil
                height = 0
            }
            if let radius {
                let position = entity.position(relativeTo: root)
                obstacles.append(
                    CreatureObstacle(
                        identifier:
                            entity.name
                            + "|"
                            + String(describing: ObjectIdentifier(entity)),
                        center: SIMD2<Double>(
                            Double(simd_dot(position, state.tangentRight)),
                            Double(simd_dot(position, state.tangentForward))
                        ),
                        radius: Double(radius),
                        height: Double(height)
                    )
                )
                return
            }
            for child in entity.children {
                collectObstacles(from: child)
            }
        }
        collectObstacles(from: root)

        let playerX = Double(simd_dot(
            playerSurfacePoint,
            state.tangentRight
        ))
        let playerZ = Double(simd_dot(
            playerSurfacePoint,
            state.tangentForward
        ))
        let paceSeed = state.worldIdentifier.utf8.reduce(UInt64(0)) {
            (($0 &* 1099511628211) ^ UInt64($1))
        }
        let planetPace =
            0.5 + Float(paceSeed % 1_501) / 1_000
        let attackInterval = 1 / planetPace
        for creature in creatures {
            let components = creature.name.split(separator: "|")
            guard components.count >= 9,
                  let homeX = Float(components[2]),
                  let homeZ = Float(components[3]),
                  let heading = Float(components[4]),
                  let speed = Float(components[5]),
                  let phase = Float(components[6]) else {
                continue
            }
            let isAggressive = components[1] == "1"
            let isWinged = components[8] != "none"
            let flightCycle = (
                state.wildlifeAnimationTime + phase * 4
            ).truncatingRemainder(dividingBy: 44)
            let scheduledFlightHeight: Float
            if !isWinged || flightCycle < 10 || flightCycle >= 38 {
                scheduledFlightHeight = 0
            } else if flightCycle < 15 {
                scheduledFlightHeight = (flightCycle - 10) / 5 * 20
            } else if flightCycle < 32 {
                scheduledFlightHeight =
                    15
                    + sin((flightCycle - 15) / 17 * 2 * .pi) * 5
            } else {
                scheduledFlightHeight = max(
                    0,
                    (38 - flightCycle) / 6 * 20
                )
            }
            let renderedPosition = creature.position(relativeTo: root)
            let surfaceRadius =
                state.effectiveRadius + expandedBiomeElevation
            let stateKey = creature.name
            var runtime = state.creatureStates[stateKey]
                ?? CreatureRuntimeState(
                    position: SIMD2<Double>(
                        Double(homeX),
                        Double(homeZ)
                    ),
                    altitude: 0,
                    behavior: .roaming,
                    health: 100,
                    stunRemaining: 0,
                    retreatRemaining: 0,
                    impactFlashRemaining: 0,
                    crumblerFlashRemaining: 0,
                    attackCooldownRemaining: 0,
                    avoidanceObstacleIdentifier: nil,
                    avoidanceSide: 0
                )
            if runtime.health <= 0 {
                creature.removeFromParent()
                continue
            }
            runtime.stunRemaining = max(
                0,
                runtime.stunRemaining - deltaTime
            )
            runtime.retreatRemaining = max(
                0,
                runtime.retreatRemaining - deltaTime
            )
            runtime.impactFlashRemaining = max(
                0,
                runtime.impactFlashRemaining - deltaTime
            )
            runtime.crumblerFlashRemaining = max(
                0,
                runtime.crumblerFlashRemaining - deltaTime
            )
            runtime.attackCooldownRemaining = max(
                0,
                runtime.attackCooldownRemaining - deltaTime
            )
            let isStunned = runtime.stunRemaining > 0
            let isRetreating =
                runtime.retreatRemaining > 0 && !isStunned
            let creatureX = runtime.position.x
            let creatureZ = runtime.position.y
            let toPlayer = SIMD2<Double>(
                playerX - creatureX,
                playerZ - creatureZ
            )
            let playerDistance = simd_length(toPlayer)
            let toHome = SIMD2<Double>(
                Double(homeX) - creatureX,
                Double(homeZ) - creatureZ
            )
            let homeDistance = simd_length(toHome)

            let normalHabitatRadius: Double = isWinged ? 12 : 9
            let aggressionRange: Double = isWinged ? 42 : 30
            let pursuitLeash: Double = 30
            let attackEnterDistance: Double = 0.95
            let attackExitDistance: Double = 1.65
            let playerAltitude = max(
                0,
                Double(simd_length(playerSurfacePoint) - surfaceRadius)
            )
            // Aim a flying attack below the player's eye point so the
            // creature and its attack animation remain in view. Ground
            // creatures stay surface-bound.
            let attackAltitude =
                isWinged ? max(0, playerAltitude - 0.75) : 0
            let verticalSeparation =
                abs(runtime.altitude - attackAltitude)
            let isAtAttackHeight = verticalSeparation <= 0.55

            if isAggressive && !isStunned && !isRetreating {
                switch runtime.behavior {
                case .attacking:
                    if playerDistance > attackExitDistance
                        || !isAtAttackHeight {
                        runtime.behavior =
                            playerDistance < aggressionRange
                                && homeDistance < pursuitLeash
                                ? .pursuing
                                : .returningHome
                    }
                case .pursuing:
                    if playerDistance <= attackEnterDistance
                        && isAtAttackHeight {
                        runtime.behavior = .attacking
                    } else if playerDistance >= aggressionRange
                        || homeDistance >= pursuitLeash {
                        runtime.behavior = .returningHome
                    }
                case .roaming:
                    if playerDistance < aggressionRange
                        && homeDistance < pursuitLeash {
                        runtime.behavior = .pursuing
                    }
                case .returningHome:
                    // Do not reacquire immediately after crossing back inside
                    // the pursuit leash. The old shared transition alternated
                    // between playerward and homeward movement every frame at
                    // the leash boundary, which made grounded aggressors
                    // dance left and right. Finish resetting near home first.
                    if homeDistance <= normalHabitatRadius * 0.7 {
                        runtime.behavior =
                            playerDistance < aggressionRange
                                ? .pursuing
                                : .roaming
                    }
                }
            } else if homeDistance > normalHabitatRadius {
                runtime.behavior = .returningHome
            } else if runtime.behavior == .returningHome
                && homeDistance <= normalHabitatRadius * 0.7 {
                runtime.behavior = .roaming
            }

            let isAttacking =
                runtime.behavior == .attacking
                    && !isStunned
                    && !isRetreating
            if isAttacking && runtime.attackCooldownRemaining <= 0 {
                runtime.attackCooldownRemaining = attackInterval
                state.pendingCreatureHits += 1
                if playerDistance > 0.0001 {
                    let away = simd_normalize(toPlayer)
                    state.pendingCreatureKnockback +=
                        state.tangentRight * Float(away.x)
                        + state.tangentForward * Float(away.y)
                }
            }
            let horizontalSpeed =
                Double(
                    speed
                        * planetPace
                        * (runtime.altitude > 0.15 ? 1.35 : 1)
                        * (isRetreating ? 1.3 : 1)
                )
            let horizontalStep =
                (isAttacking || isStunned)
                    ? 0
                    : horizontalSpeed * Double(deltaTime)
            // Altitude correction has its own movement budget so a flying
            // creature can finish a descent after reaching attack range.
            // Limit the slope to 45 degrees during normal movement.
            let verticalMovementBudget =
                isStunned ? 0 : horizontalSpeed * Double(deltaTime)
            let targetFlightHeight: Double =
                isAggressive
                    && (
                        runtime.behavior == .pursuing
                            || runtime.behavior == .attacking
                    )
                    ? attackAltitude
                    : Double(scheduledFlightHeight)
            let verticalDifference =
                targetFlightHeight - runtime.altitude
            let verticalStep = max(
                -verticalMovementBudget,
                min(verticalMovementBudget, verticalDifference)
            )
            runtime.altitude = max(0, runtime.altitude + verticalStep)
            let flightHeight = Float(runtime.altitude)
            let isFlying =
                flightHeight > 0.15 || targetFlightHeight > 0.15

            var movementDirection: SIMD2<Double>
            if isRetreating {
                movementDirection =
                    playerDistance > 0.0001
                        ? -simd_normalize(toPlayer)
                        : simd_normalize(toHome)
            } else if runtime.behavior == .pursuing {
                if playerDistance > 0.0001 {
                    let directApproach = simd_normalize(toPlayer)
                    if playerDistance > 4 {
                        // Approach in a smooth weave while guaranteeing
                        // forward progress. The weave fades out over the last
                        // few meters so close-range pursuit is direct.
                        let approachRight = SIMD2<Double>(
                            -directApproach.y,
                            directApproach.x
                        )
                        let meanderStrength =
                            min(0.34, max(0, (playerDistance - 4) / 12))
                        let meander =
                            sin(
                                Double(state.wildlifeAnimationTime) * 0.62
                                    + Double(phase) * 1.7
                            ) * meanderStrength
                        movementDirection = simd_normalize(
                            directApproach + approachRight * meander
                        )
                    } else {
                        movementDirection = directApproach
                    }
                } else {
                    movementDirection = SIMD2<Double>(1, 0)
                }
            } else if runtime.behavior == .attacking {
                movementDirection =
                    playerDistance > 0.0001
                        ? simd_normalize(toPlayer)
                        : SIMD2<Double>(1, 0)
            } else if runtime.behavior == .returningHome
                || homeDistance > normalHabitatRadius {
                movementDirection = simd_normalize(toHome)
            } else {
                let wanderingHeading = Double(
                    heading
                        + sin(
                            state.wildlifeAnimationTime * 0.38 + phase
                        ) * 1.35
                )
                let wanderingDirection = SIMD2<Double>(
                    cos(wanderingHeading),
                    sin(wanderingHeading)
                )
                let tetherStart = normalHabitatRadius * 0.62
                if homeDistance > tetherStart {
                    let tetherStrength = min(
                        0.88,
                        (homeDistance - tetherStart)
                            / (normalHabitatRadius - tetherStart)
                    )
                    movementDirection = simd_normalize(
                        wanderingDirection * (1 - tetherStrength)
                            + simd_normalize(toHome) * tetherStrength
                    )
                } else {
                    movementDirection = wanderingDirection
                }
            }

            if !isAttacking && !isStunned {
                let creatureRadius =
                    Double(0.82 * max(creature.scale.x, creature.scale.z))
                        + 0.22
                let lookAhead = max(
                    2.4,
                    min(5.2, horizontalSpeed * 1.8)
                )
                let pathRight = SIMD2<Double>(
                    -movementDirection.y,
                    movementDirection.x
                )
                func pathMeasurements(
                    to obstacle: CreatureObstacle
                ) -> (forward: Double, lateral: Double, clearance: Double) {
                    let offset = obstacle.center - runtime.position
                    return (
                        simd_dot(offset, movementDirection),
                        simd_dot(offset, pathRight),
                        obstacle.radius + creatureRadius
                    )
                }

                var activeObstacle = obstacles.first {
                    $0.identifier == runtime.avoidanceObstacleIdentifier
                }
                if let obstacle = activeObstacle {
                    let path = pathMeasurements(to: obstacle)
                    let hasCleared =
                        path.forward < -path.clearance * 0.25
                            || abs(path.lateral) > path.clearance + 0.85
                            || runtime.altitude > obstacle.height + 0.45
                    if hasCleared {
                        runtime.avoidanceObstacleIdentifier = nil
                        runtime.avoidanceSide = 0
                        activeObstacle = nil
                    }
                } else if runtime.avoidanceObstacleIdentifier != nil {
                    runtime.avoidanceObstacleIdentifier = nil
                    runtime.avoidanceSide = 0
                }

                if activeObstacle == nil {
                    activeObstacle = obstacles
                        .filter { runtime.altitude <= $0.height + 0.45 }
                        .filter {
                            let path = pathMeasurements(to: $0)
                            let distance = simd_length(
                                $0.center - runtime.position
                            )
                            return distance < path.clearance + 0.25
                                || (
                                    path.forward > 0
                                        && path.forward < lookAhead
                                        && abs(path.lateral)
                                            < path.clearance + 0.2
                                )
                        }
                        .min {
                            pathMeasurements(to: $0).forward
                                < pathMeasurements(to: $1).forward
                        }
                    if let obstacle = activeObstacle {
                        var sideSeed =
                            stateKey.utf8.reduce(UInt64(0xcbf29ce484222325)) {
                                ($0 ^ UInt64($1)) &* 0x100000001b3
                            }
                        sideSeed = obstacle.identifier.utf8.reduce(sideSeed) {
                            ($0 ^ UInt64($1)) &* 0x100000001b3
                        }
                        runtime.avoidanceObstacleIdentifier =
                            obstacle.identifier
                        runtime.avoidanceSide =
                            sideSeed.isMultiple(of: 2) ? -1 : 1
                    }
                }

                if let obstacle = activeObstacle {
                    let path = pathMeasurements(to: obstacle)
                    let waypoint =
                        obstacle.center
                        + pathRight
                            * runtime.avoidanceSide
                            * (path.clearance + 0.65)
                        + movementDirection
                            * min(1.8, max(0.8, path.clearance * 0.55))
                    let toWaypoint = waypoint - runtime.position
                    if simd_length_squared(toWaypoint) > 0.000_001 {
                        movementDirection = simd_normalize(toWaypoint)
                    }
                }
            } else if isAttacking {
                runtime.avoidanceObstacleIdentifier = nil
                runtime.avoidanceSide = 0
            }

            let currentSurfaceDirection =
                simd_length_squared(renderedPosition) > 0.000_001
                    ? simd_normalize(renderedPosition)
                    : state.anchorNormal
            let desiredForwardUnprojected =
                state.tangentRight * Float(movementDirection.x)
                + state.tangentForward * Float(movementDirection.y)
            let desiredForward = simd_normalize(
                desiredForwardUnprojected
                    - currentSurfaceDirection
                        * simd_dot(
                            desiredForwardUnprojected,
                            currentSurfaceDirection
                        )
            )
            // Keep flight facing level. Altitude changes must not feed back
            // into yaw or pitch; that coupling caused the persistent
            // sideways/downward orientation jitter near the player.
            let travelForward = desiredForward
            let steeringRight = simd_normalize(
                simd_cross(currentSurfaceDirection, travelForward)
            )
            let steeringUp = simd_normalize(
                simd_cross(travelForward, steeringRight)
            )
            let steeringOrientation = simd_quatf(
                simd_float3x3(
                    columns: (
                        steeringRight,
                        steeringUp,
                        travelForward
                    )
                )
            )
            let turnResponse: Float =
                runtime.behavior == .pursuing ? 14 : 7
            let currentOrientation =
                creature.orientation(relativeTo: root)
            let currentForward = currentOrientation.act(
                SIMD3<Float>(0, 0, 1)
            )
            let currentOrientationMovement = SIMD2<Double>(
                Double(simd_dot(currentForward, state.tangentRight)),
                Double(simd_dot(currentForward, state.tangentForward))
            )
            let currentFacingDirection =
                simd_length_squared(currentOrientationMovement) > 0.000_001
                    ? simd_normalize(currentOrientationMovement)
                    : movementDirection
            let currentTargetAlignment = simd_dot(
                currentFacingDirection,
                movementDirection
            )
            // Once an attacker is facing within roughly five degrees of the
            // player, hold its orientation. Tiny target-coordinate changes
            // must not rock a wide creature from side to side.
            let holdsStableAttackFacing =
                isAttacking && currentTargetAlignment > 0.996
            let steeredOrientation =
                holdsStableAttackFacing
                    ? currentOrientation
                    : simd_slerp(
                        currentOrientation,
                        steeringOrientation,
                        min(1, deltaTime * turnResponse)
                    )
            let orientedForward = steeredOrientation.act(
                SIMD3<Float>(0, 0, 1)
            )
            let orientationMovement = SIMD2<Double>(
                Double(simd_dot(orientedForward, state.tangentRight)),
                Double(simd_dot(orientedForward, state.tangentForward))
            )
            let facingDirection =
                simd_length_squared(orientationMovement) > 0.000_001
                    ? simd_normalize(orientationMovement)
                    : movementDirection
            let targetAlignment = simd_dot(
                facingDirection,
                movementDirection
            )
            // Turning only controls speed. Translation follows the requested
            // path directly so a partially turned creature cannot convert
            // steering corrections into lateral oscillation near the player.
            let alignmentSpeed = max(
                0,
                min(1, (targetAlignment - 0.15) / 0.85)
            )
            var appliedHorizontalStep = horizontalStep * alignmentSpeed
            if runtime.behavior == .pursuing && playerDistance > 0.0001 {
                appliedHorizontalStep = min(
                    appliedHorizontalStep,
                    max(0, playerDistance - attackEnterDistance)
                )
            }
            let isAttackDescent =
                isWinged
                    && runtime.behavior == .pursuing
                    && verticalDifference < -0.000_001
            if isAttackDescent {
                // Descend vertically before closing attack distance. This
                // leaves no horizontal velocity for the facing calculation
                // to amplify into a sideways orbit.
                appliedHorizontalStep = 0
            }
            runtime.position +=
                movementDirection * appliedHorizontalStep
            let nextX = Float(runtime.position.x)
            let nextZ = Float(runtime.position.y)
            let surfaceDirection = projectedSurfaceDirection(
                x: nextX,
                z: nextZ,
                state: state
            )
            let nextPosition =
                surfaceDirection * (
                    surfaceRadius + flightHeight
                )
            creature.setPosition(nextPosition, relativeTo: root)
            creature.setOrientation(
                steeredOrientation,
                relativeTo: root
            )
            state.creatureStates[stateKey] = runtime
            if let flash = creature.findEntity(
                named: "Creature Hit Flash"
            ) {
                let impactVisible =
                    runtime.impactFlashRemaining > 0
                        && Int(
                            state.wildlifeAnimationTime * 16
                        ).isMultiple(of: 2)
                let crumblerVisible =
                    runtime.crumblerFlashRemaining > 0
                        && Int(
                            state.wildlifeAnimationTime * 4
                        ).isMultiple(of: 2)
                flash.isEnabled = impactVisible || crumblerVisible
            }

            let stridePhase =
                state.wildlifeAnimationTime
                    * (isAggressive ? 10 : 7) + phase
            let isLocomoting = appliedHorizontalStep > 0.000_001
            let isDescending = isFlying && verticalStep < -0.000_001
            let shouldFlapWings = isFlying && !isDescending
            if let body = creature.findEntity(named: "Creature Body") {
                let restingHeight: Float =
                    body.scale.y > 1
                        ? 1.02
                        : (body.scale.y > 0.8 ? 0.84 : 0.72)
                body.position.y =
                    restingHeight
                    + (isFlying
                        ? (isDescending
                            ? 0
                            : sin(stridePhase * 0.45) * 0.018)
                        : (isAttacking
                            ? 0
                            : (isLocomoting
                                ? abs(sin(stridePhase)) * 0.055
                                : 0)))
                body.position.z = isAttacking
                    ? max(0, sin(stridePhase * 0.7)) * 0.30
                    : 0
            }
            var legs: [Entity] = []
            var arms: [Entity] = []
            var heads: [Entity] = []
            var tails: [Entity] = []
            var wings: [Entity] = []
            func collectAnimatedParts(from entity: Entity) {
                if entity.name.hasPrefix("Creature Leg ") {
                    legs.append(entity)
                } else if entity.name == "Creature Arm" {
                    arms.append(entity)
                } else if entity.name.hasPrefix("Creature Head ") {
                    heads.append(entity)
                } else if entity.name.hasPrefix("Creature Tail ") {
                    tails.append(entity)
                } else if entity.name.hasPrefix("Creature Wing ") {
                    wings.append(entity)
                }
                for child in entity.children {
                    collectAnimatedParts(from: child)
                }
            }
            collectAnimatedParts(from: creature)
            for head in heads {
                head.orientation = simd_quatf(
                    angle: isAttacking
                        ? -0.28 - max(0, sin(stridePhase * 0.7)) * 0.38
                        : (isStunned ? 0.38 : 0),
                    axis: [1, 0, 0]
                )
            }
            for (armIndex, arm) in arms.enumerated() {
                let side: Float = armIndex.isMultiple(of: 2) ? -1 : 1
                arm.orientation = simd_quatf(
                    angle: isAttacking
                        ? side
                            * (
                                0.35
                                    + max(
                                        0,
                                        sin(
                                            stridePhase * 0.7
                                                + Float(armIndex) * .pi
                                        )
                                    ) * 0.9
                            )
                        : 0,
                    axis: [1, 0, 0]
                )
            }
            for (legIndex, leg) in legs.enumerated() {
                let opposingPhase: Float =
                    (legIndex == 0 || legIndex == 3) ? 0 : .pi
                let strideRotation = simd_quatf(
                    angle: (isStunned || isAttacking || !isLocomoting)
                        ? 0
                        : (isFlying
                        ? -0.72
                        : sin(stridePhase + opposingPhase) * 0.58),
                    axis: [1, 0, 0]
                )
                if leg.name.hasSuffix("|spider") {
                    let side: Float =
                        legIndex.isMultiple(of: 2) ? -1 : 1
                    leg.orientation =
                        strideRotation
                        * simd_quatf(
                            angle: side * 0.58,
                            axis: [0, 0, 1]
                        )
                } else {
                    leg.orientation = strideRotation
                }
            }
            for (tailIndex, tail) in tails.enumerated() {
                tail.orientation = simd_quatf(
                    angle:
                        .pi / 2
                        + sin(
                            stridePhase * 0.55 + Float(tailIndex) * 0.7
                        ) * 0.22,
                    axis: [1, 0, 0]
                )
            }
            for (wingIndex, wing) in wings.enumerated() {
                let side: Float = wingIndex == 0 ? -1 : 1
                let flapAmount: Float = shouldFlapWings
                    ? sin(stridePhase * 1.8) * 0.52
                    : 0
                let restingAngle: Float = isDescending ? 0.04 : 0.20
                wing.orientation = simd_quatf(
                    angle:
                        side
                        * (restingAngle + flapAmount),
                    axis: [0, 0, 1]
                )
            }
        }
    }

    private func addRoughSurfaceDetail(
        to roughRoot: Entity,
        for body: CelestialBodyDescriptor
    ) {
        let patchColor: UIColor = switch body.kind {
        case .ocean:
            UIColor(red: 0.12, green: 0.34, blue: 0.12, alpha: 1)
        case .desert:
            UIColor(red: 0.42, green: 0.16, blue: 0.055, alpha: 1)
        case .rocky:
            UIColor(white: 0.22, alpha: 1)
        case .ice:
            UIColor(red: 0.72, green: 0.88, blue: 0.93, alpha: 1)
        case .gas:
            UIColor(red: 0.34, green: 0.18, blue: 0.48, alpha: 1)
        case .star:
            .clear
        }
        let patchMaterial = SimpleMaterial(
            color: patchColor,
            roughness: 0.94,
            isMetallic: false
        )
        let patchMesh = MeshResource.generateSphere(radius: 1)
        let phase = Float(body.name.utf8.reduce(0) { ($0 + UInt64($1)) % 10_000 })
            * 0.013

        for index in 0..<18 {
            let direction = surfaceDirection(
                index: index,
                count: 18,
                phase: phase
            )
            let width = body.radius * (0.055 + Float(index % 4) * 0.014)
            let elevationScale: Float = switch body.kind {
            case .ocean: 0.004
            case .desert: 0.009
            case .rocky: 0.012
            case .ice: 0.007
            case .gas: 0.002
            case .star: 0
            }
            let elevation =
                body.radius * (elevationScale + Float(index % 3) * 0.002)
            let patch = ModelEntity(
                mesh: patchMesh,
                materials: [patchMaterial]
            )
            patch.name = switch body.kind {
            case .ocean: "Forest Continent"
            case .desert: "Dune Highlands"
            case .rocky: "Rocky Highlands"
            case .ice: "Ice Shelf"
            case .gas: "Cloud Formation"
            case .star: "Surface Feature"
            }
            // Sink the flattened terrain volume into the curved planet so its
            // perimeter never reads as a floating plate.
            patch.position = direction * (body.radius - elevation * 0.35)
            patch.orientation = simd_quatf(
                from: SIMD3<Float>(0, 1, 0),
                to: direction
            )
            patch.scale = [width, elevation, width * 0.72]
            roughRoot.addChild(patch)
        }
    }

    private func addAirlessSurfaceDetail(
        to root: Entity,
        for body: CelestialBodyDescriptor
    ) {
        let phase = Float(body.name.utf8.reduce(0) {
            ($0 + UInt64($1)) % 10_000
        }) * 0.013
        let mineralColor: UIColor = switch body.kind {
        case .ocean: .systemTeal
        case .desert: .systemOrange
        case .rocky: .systemIndigo
        case .ice: .systemCyan
        case .gas: .systemPurple
        case .star: .white
        }
        let mineralMaterial = SimpleMaterial(
            color: mineralColor,
            roughness: 0.34,
            isMetallic: true
        )
        let mineralHeight = max(body.radius * 0.026, 3)
        let mineralMesh = MeshResource.generateBox(
            width: mineralHeight * 0.22,
            height: mineralHeight,
            depth: mineralHeight * 0.22
        )
        for index in 0..<24 {
            let direction = surfaceDirection(
                index: index,
                count: 24,
                phase: phase
            )
            let formation = Entity()
            formation.name = "Mineral Formation"
            formation.position =
                direction * (body.radius + mineralHeight * 0.42)
            formation.orientation = simd_quatf(
                from: SIMD3<Float>(0, 1, 0),
                to: direction
            )
            for shardIndex in 0..<3 {
                let shard = ModelEntity(
                    mesh: mineralMesh,
                    materials: [mineralMaterial]
                )
                shard.position = [
                    Float(shardIndex - 1) * mineralHeight * 0.18,
                    Float(shardIndex % 2) * mineralHeight * 0.12,
                    Float((index + shardIndex) % 3 - 1)
                        * mineralHeight * 0.12
                ]
                shard.scale.y = 0.62 + Float(shardIndex) * 0.18
                shard.orientation = simd_quatf(
                    angle: Float(shardIndex - 1) * 0.18,
                    axis: [0, 0, 1]
                )
                formation.addChild(shard)
            }
            root.addChild(formation)
        }

        let baseMaterial = SimpleMaterial(
            color: UIColor(white: 0.22, alpha: 1),
            roughness: 0.42,
            isMetallic: true
        )
        let beaconMaterial = UnlitMaterial(color: mineralColor)
        for index in 0..<2 {
            let direction = surfaceDirection(
                index: index * 9 + 4,
                count: 27,
                phase: phase + 0.8
            )
            let baseRadius = max(body.radius * 0.035, 4)
            let base = Entity()
            base.name = "Remote Mining Base"
            base.position = direction * (body.radius + baseRadius * 0.10)
            base.orientation = simd_quatf(
                from: SIMD3<Float>(0, 1, 0),
                to: direction
            )
            let platform = ModelEntity(
                mesh: .generateCylinder(
                    height: baseRadius * 0.18,
                    radius: baseRadius
                ),
                materials: [baseMaterial]
            )
            base.addChild(platform)
            let habitat = ModelEntity(
                mesh: .generateSphere(radius: baseRadius * 0.44),
                materials: [baseMaterial]
            )
            habitat.position.y = baseRadius * 0.22
            habitat.scale.y = 0.55
            base.addChild(habitat)
            let beacon = ModelEntity(
                mesh: .generateSphere(radius: baseRadius * 0.10),
                materials: [beaconMaterial]
            )
            beacon.position.y = baseRadius * 0.72
            base.addChild(beacon)
            root.addChild(base)
        }
    }

    private func addLowerSurfaceDetail(
        to lowerRoot: Entity,
        for body: CelestialBodyDescriptor
    ) {
        let phase = Float(body.name.utf8.reduce(0) {
            ($0 + UInt64($1)) % 10_000
        }) * 0.013
        switch body.kind {
        case .ocean:
            addTreeBiome(to: lowerRoot, body: body, phase: phase)
            addValleys(
                to: lowerRoot,
                body: body,
                phase: phase + 0.7,
                color: UIColor(red: 0.035, green: 0.16, blue: 0.07, alpha: 1),
                name: "Forested Valley"
            )
        case .desert:
            addTreeBiome(to: lowerRoot, body: body, phase: phase)
            addDesertBiome(to: lowerRoot, body: body, phase: phase)
            addValleys(
                to: lowerRoot,
                body: body,
                phase: phase + 1.1,
                color: UIColor(red: 0.24, green: 0.055, blue: 0.025, alpha: 1),
                name: "Canyon Valley"
            )
        case .rocky:
            addTreeBiome(to: lowerRoot, body: body, phase: phase)
            addRockyBiome(to: lowerRoot, body: body, phase: phase)
            addValleys(
                to: lowerRoot,
                body: body,
                phase: phase + 1.9,
                color: UIColor(white: 0.09, alpha: 1),
                name: "Impact Valley"
            )
        case .ice:
            addTreeBiome(to: lowerRoot, body: body, phase: phase)
            addIceBiome(to: lowerRoot, body: body, phase: phase)
        case .gas:
            addTreeBiome(to: lowerRoot, body: body, phase: phase)
            addGasBiome(to: lowerRoot, body: body, phase: phase)
        case .star:
            break
        }

        let padMaterial = UnlitMaterial(
            color: UIColor.systemCyan.withAlphaComponent(0.92)
        )
        let padDirections: [SIMD3<Float>] = [
            simd_normalize([0.31, 0.88, -0.36]),
            simd_normalize([-0.72, 0.22, 0.66]),
            simd_normalize([0.58, -0.64, 0.50])
        ]
        for (index, direction) in padDirections.enumerated() {
            let height = max(body.radius * 0.003, 0.5)
            let pad = ModelEntity(
                mesh: .generateCylinder(
                    height: height,
                    radius: max(body.radius * 0.022, 2.5)
                ),
                materials: [padMaterial]
            )
            pad.name = "Landing Site \(index + 1)"
            pad.position = direction * (body.radius + height * 0.6)
            pad.orientation = simd_quatf(
                from: SIMD3<Float>(0, 1, 0),
                to: direction
            )
            lowerRoot.addChild(pad)
        }
    }

    private func addGroundSurfaceDetail(
        to groundRoot: Entity,
        for body: CelestialBodyDescriptor
    ) {
        let phase = Float(body.name.utf8.reduce(0) {
            ($0 + UInt64($1)) % 10_000
        }) * 0.013
        addGroundMicroDetail(
            to: groundRoot,
            body: body,
            phase: phase
        )
    }

    private func surfaceDirection(
        index: Int,
        count: Int,
        phase: Float
    ) -> SIMD3<Float> {
        let fraction = (Float(index) + 0.5) / Float(count)
        let y = 1 - 2 * fraction
        let ringRadius = sqrt(max(0, 1 - y * y))
        let angle = Float(index) * 2.399_963 + phase
        return simd_normalize(
            SIMD3<Float>(
                cos(angle) * ringRadius,
                y,
                sin(angle) * ringRadius
            )
        )
    }

    private func addTreeBiome(
        to root: Entity,
        body: CelestialBodyDescriptor,
        phase: Float
    ) {
        let trunkColor: UIColor
        let canopyColors: [UIColor]
        switch body.kind {
        case .ocean:
            trunkColor = UIColor(red: 0.20, green: 0.09, blue: 0.035, alpha: 1)
            canopyColors = [
                UIColor(red: 0.025, green: 0.24, blue: 0.055, alpha: 1),
                UIColor(red: 0.055, green: 0.38, blue: 0.09, alpha: 1)
            ]
        case .desert:
            trunkColor = UIColor(red: 0.30, green: 0.07, blue: 0.025, alpha: 1)
            canopyColors = [
                UIColor(red: 0.86, green: 0.29, blue: 0.055, alpha: 1),
                UIColor(red: 0.95, green: 0.58, blue: 0.08, alpha: 1)
            ]
        case .rocky:
            trunkColor = UIColor(white: 0.16, alpha: 1)
            canopyColors = [
                UIColor(red: 0.38, green: 0.23, blue: 0.52, alpha: 1),
                UIColor(red: 0.53, green: 0.48, blue: 0.62, alpha: 1)
            ]
        case .ice:
            trunkColor = UIColor(red: 0.35, green: 0.76, blue: 0.92, alpha: 1)
            canopyColors = [
                UIColor(red: 0.70, green: 0.94, blue: 1, alpha: 1),
                .white
            ]
        case .gas:
            trunkColor = UIColor(red: 0.42, green: 0.16, blue: 0.55, alpha: 1)
            canopyColors = [
                UIColor(red: 0.95, green: 0.38, blue: 0.72, alpha: 1),
                UIColor(red: 0.40, green: 0.88, blue: 0.94, alpha: 1)
            ]
        case .star:
            return
        }

        let trunkMaterial = SimpleMaterial(
            color: trunkColor,
            roughness: 0.95,
            isMetallic: false
        )
        let canopyMaterials = canopyColors.map {
            SimpleMaterial(
                color: $0,
                roughness: 0.9,
                isMetallic: false
            )
        }
        let treeHeight = max(body.radius * 0.018, 1.8)
        let trunkMesh = MeshResource.generateCylinder(
            height: treeHeight * 0.62,
            radius: treeHeight * 0.065
        )
        let canopyMesh = MeshResource.generateSphere(radius: treeHeight * 0.24)

        for index in 0..<16 {
            let cluster = index / 4
            let treeInCluster = index % 4
            let continentIndex = cluster * 4 + 1
            let continentDirection = surfaceDirection(
                index: continentIndex,
                count: 18,
                phase: phase
            )
            let reference = abs(continentDirection.y) < 0.9
                ? SIMD3<Float>(0, 1, 0)
                : SIMD3<Float>(1, 0, 0)
            let tangent = simd_normalize(
                simd_cross(continentDirection, reference)
            )
            let bitangent = simd_normalize(
                simd_cross(continentDirection, tangent)
            )
            let lateral = Float(treeInCluster) * 0.012 - 0.018
            let depth = Float((treeInCluster * 2) % 4) * 0.010 - 0.015
            let direction = simd_normalize(
                continentDirection
                    + tangent * lateral
                    + bitangent * depth
            )
            let elevationScale: Float = switch body.kind {
            case .ocean: 0.004
            case .desert: 0.009
            case .rocky: 0.012
            case .ice: 0.007
            case .gas: 0.002
            case .star: 0
            }
            let patchElevation =
                body.radius
                * (elevationScale + Float(continentIndex % 3) * 0.002)
            let tree = Entity()
            tree.position = direction * (
                body.radius + patchElevation * 0.65
            )
            tree.orientation = simd_quatf(
                from: SIMD3<Float>(0, 1, 0),
                to: direction
            )

            let trunk = ModelEntity(
                mesh: trunkMesh,
                materials: [trunkMaterial]
            )
            trunk.position.y = treeHeight * 0.31
            tree.addChild(trunk)

            let canopyMaterial = canopyMaterials[index % canopyMaterials.count]
            let style: Int = switch body.kind {
            case .ocean: index % 3
            case .ice: 3
            case .desert, .gas: 4
            case .rocky: index.isMultiple(of: 2) ? 3 : 4
            case .star: 0
            }
            switch style {
            case 0:
                tree.name = "Pine Tree"
                for tier in 0..<3 {
                    let canopy = ModelEntity(
                        mesh: canopyMesh,
                        materials: [canopyMaterial]
                    )
                    canopy.position.y =
                        treeHeight * (0.48 + Float(tier) * 0.17)
                    let width = 1 - Float(tier) * 0.2
                    canopy.scale = [width, 0.72, width]
                    tree.addChild(canopy)
                }
            case 1:
                tree.name = "Weeping Willow"
                let canopy = ModelEntity(
                    mesh: canopyMesh,
                    materials: [canopyMaterial]
                )
                canopy.position.y = treeHeight * 0.72
                canopy.scale = [1.35, 0.72, 1.35]
                tree.addChild(canopy)
                let branchMesh = MeshResource.generateCylinder(
                    height: treeHeight * 0.35,
                    radius: treeHeight * 0.018
                )
                for branchIndex in 0..<4 {
                    let angle = Float(branchIndex) * .pi / 2
                    let branch = ModelEntity(
                        mesh: branchMesh,
                        materials: [canopyMaterial]
                    )
                    branch.position = [
                        cos(angle) * treeHeight * 0.23,
                        treeHeight * 0.50,
                        sin(angle) * treeHeight * 0.23
                    ]
                    tree.addChild(branch)
                }
            case 3:
                tree.name = "Ice Crystal Tree"
                for branchIndex in 0..<6 {
                    let branch = ModelEntity(
                        mesh: .generateBox(
                            width: treeHeight * 0.035,
                            height: treeHeight * 0.38,
                            depth: treeHeight * 0.035
                        ),
                        materials: [canopyMaterial]
                    )
                    branch.position.y =
                        treeHeight * (0.42 + Float(branchIndex % 3) * 0.16)
                    branch.orientation =
                        simd_quatf(
                            angle: branchIndex.isMultiple(of: 2)
                                ? .pi / 3
                                : -.pi / 3,
                            axis: [0, 0, 1]
                        )
                        * simd_quatf(
                            angle: Float(branchIndex) * .pi / 3,
                            axis: [0, 1, 0]
                        )
                    tree.addChild(branch)
                }
            case 4:
                tree.name = "Floating Balloon Tree"
                let balloon = ModelEntity(
                    mesh: canopyMesh,
                    materials: [canopyMaterial]
                )
                balloon.position.y = treeHeight * 0.96
                balloon.scale = [1.35, 1.65, 1.35]
                tree.addChild(balloon)
            default:
                tree.name = "Broadleaf Tree"
                let canopy = ModelEntity(
                    mesh: canopyMesh,
                    materials: [canopyMaterial]
                )
                canopy.position.y = treeHeight * 0.72
                canopy.scale = [1.15, 1, 1.15]
                tree.addChild(canopy)
            }
            root.addChild(tree)
        }
    }

    private func addValleys(
        to root: Entity,
        body: CelestialBodyDescriptor,
        phase: Float,
        color: UIColor,
        name: String
    ) {
        let material = SimpleMaterial(
            color: color,
            roughness: 0.98,
            isMetallic: false
        )
        let mesh = MeshResource.generateSphere(radius: 1)
        for index in 0..<6 {
            let direction = surfaceDirection(
                index: index * 2 + 3,
                count: 29,
                phase: phase
            )
            let valley = ModelEntity(mesh: mesh, materials: [material])
            valley.name = name
            valley.position = direction * (body.radius + body.radius * 0.0006)
            valley.orientation = simd_quatf(
                from: SIMD3<Float>(0, 1, 0),
                to: direction
            )
            valley.scale = [
                body.radius * 0.065,
                body.radius * 0.0012,
                body.radius * 0.014
            ]
            root.addChild(valley)
        }
    }

    private func addDesertBiome(
        to root: Entity,
        body: CelestialBodyDescriptor,
        phase: Float
    ) {
        let material = SimpleMaterial(
            color: UIColor(red: 0.52, green: 0.20, blue: 0.055, alpha: 1),
            roughness: 0.88,
            isMetallic: false
        )
        for index in 0..<9 {
            let direction = surfaceDirection(
                index: index * 2,
                count: 37,
                phase: phase + 0.35
            )
            let height = body.radius * (0.012 + Float(index % 3) * 0.004)
            let mesa = ModelEntity(
                mesh: .generateCylinder(
                    height: height,
                    radius: body.radius * 0.014
                ),
                materials: [material]
            )
            mesa.name = "Desert Mesa"
            mesa.position = direction * (body.radius + height * 0.38)
            mesa.orientation = simd_quatf(
                from: SIMD3<Float>(0, 1, 0),
                to: direction
            )
            root.addChild(mesa)
        }
    }

    private func addRockyBiome(
        to root: Entity,
        body: CelestialBodyDescriptor,
        phase: Float
    ) {
        let craterMaterial = SimpleMaterial(
            color: UIColor(white: 0.075, alpha: 1),
            roughness: 1,
            isMetallic: false
        )
        let rockMaterial = SimpleMaterial(
            color: UIColor(white: 0.34, alpha: 1),
            roughness: 0.9,
            isMetallic: true
        )
        for index in 0..<8 {
            let direction = surfaceDirection(
                index: index * 3,
                count: 41,
                phase: phase
            )
            let crater = ModelEntity(
                mesh: .generateSphere(radius: 1),
                materials: [craterMaterial]
            )
            crater.name = "Impact Crater"
            crater.position = direction * (body.radius + body.radius * 0.0005)
            crater.orientation = simd_quatf(
                from: SIMD3<Float>(0, 1, 0),
                to: direction
            )
            crater.scale = [
                body.radius * 0.025,
                body.radius * 0.001,
                body.radius * 0.025
            ]
            root.addChild(crater)

            let boulder = ModelEntity(
                mesh: .generateSphere(radius: body.radius * 0.009),
                materials: [rockMaterial]
            )
            boulder.name = "Crater Boulder"
            boulder.position = direction * (body.radius + body.radius * 0.006)
            boulder.scale = [1, 0.72, 1.35]
            root.addChild(boulder)
        }
    }

    private func addIceBiome(
        to root: Entity,
        body: CelestialBodyDescriptor,
        phase: Float
    ) {
        let ridgeMaterial = SimpleMaterial(
            color: .white,
            roughness: 0.68,
            isMetallic: false
        )
        let crevasseMaterial = UnlitMaterial(
            color: UIColor.systemBlue.withAlphaComponent(0.72)
        )
        for index in 0..<10 {
            let direction = surfaceDirection(
                index: index * 2,
                count: 43,
                phase: phase
            )
            let ridge = ModelEntity(
                mesh: .generateBox(
                    width: body.radius * 0.045,
                    height: body.radius * 0.009,
                    depth: body.radius * 0.008,
                    cornerRadius: body.radius * 0.002
                ),
                materials: [ridgeMaterial]
            )
            ridge.name = "Glacial Ridge"
            ridge.position = direction * (body.radius + body.radius * 0.004)
            ridge.orientation = simd_quatf(
                from: SIMD3<Float>(0, 1, 0),
                to: direction
            )
            root.addChild(ridge)

            let crevasse = ModelEntity(
                mesh: .generateBox(
                    width: body.radius * 0.035,
                    height: body.radius * 0.001,
                    depth: body.radius * 0.003
                ),
                materials: [crevasseMaterial]
            )
            crevasse.name = "Ice Crevasse"
            crevasse.position = direction * (body.radius + body.radius * 0.009)
            crevasse.orientation = ridge.orientation
            root.addChild(crevasse)
        }
    }

    private func addGasBiome(
        to root: Entity,
        body: CelestialBodyDescriptor,
        phase: Float
    ) {
        let bandColors: [UIColor] = [
            UIColor(red: 0.48, green: 0.30, blue: 0.62, alpha: 0.76),
            UIColor(red: 0.70, green: 0.48, blue: 0.75, alpha: 0.65)
        ]
        for index in 0..<7 {
            let latitude = -0.72 + Float(index) * 0.24
            let ringRadius =
                body.radius * sqrt(max(0.05, 1 - latitude * latitude))
            let band = ModelEntity(
                mesh: .generateCylinder(
                    height: body.radius * 0.055,
                    radius: ringRadius * 1.006
                ),
                materials: [
                    UnlitMaterial(color: bandColors[index % bandColors.count])
                ]
            )
            band.name = "Gas Cloud Band"
            band.position.y = body.radius * latitude
            root.addChild(band)
        }

        let stormDirection = surfaceDirection(index: 7, count: 23, phase: phase)
        let storm = ModelEntity(
            mesh: .generateSphere(radius: 1),
            materials: [
                UnlitMaterial(
                    color: UIColor.systemOrange.withAlphaComponent(0.82)
                )
            ]
        )
        storm.name = "Planetary Storm"
        storm.position = stormDirection * (body.radius * 1.008)
        storm.orientation = simd_quatf(
            from: SIMD3<Float>(0, 1, 0),
            to: stormDirection
        )
        storm.scale = [
            body.radius * 0.075,
            body.radius * 0.003,
            body.radius * 0.038
        ]
        root.addChild(storm)
    }

    private func addGroundMicroDetail(
        to root: Entity,
        body: CelestialBodyDescriptor,
        phase: Float
    ) {
        let color: UIColor = switch body.kind {
        case .ocean:
            UIColor(red: 0.07, green: 0.42, blue: 0.10, alpha: 1)
        case .desert:
            UIColor(red: 0.36, green: 0.12, blue: 0.035, alpha: 1)
        case .rocky:
            UIColor(white: 0.42, alpha: 1)
        case .ice:
            UIColor(red: 0.80, green: 0.95, blue: 1, alpha: 1)
        case .gas:
            UIColor(red: 0.73, green: 0.54, blue: 0.82, alpha: 0.72)
        case .star:
            .clear
        }
        let material = SimpleMaterial(
            color: color,
            roughness: 0.93,
            isMetallic: body.kind == .rocky
        )
        let mesh = MeshResource.generateSphere(radius: 1)
        for index in 0..<36 {
            let direction = surfaceDirection(
                index: index,
                count: 36,
                phase: phase + 0.41
            )
            let height = max(
                body.radius * (0.002 + Float(index % 4) * 0.001),
                0.45
            )
            let detail = ModelEntity(mesh: mesh, materials: [material])
            detail.name = switch body.kind {
            case .ocean: "Ground Shrub"
            case .desert: "Dune Rock"
            case .rocky: "Surface Stone"
            case .ice: "Ice Fragment"
            case .gas: "Cloud Wisp"
            case .star: "Ground Detail"
            }
            detail.position = direction * (body.radius + height * 0.45)
            detail.orientation = simd_quatf(
                from: SIMD3<Float>(0, 1, 0),
                to: direction
            )
            detail.scale = [
                height * (0.7 + Float(index % 3) * 0.18),
                height,
                height * (0.55 + Float(index % 2) * 0.2)
            ]
            root.addChild(detail)
        }
    }

    private func color(for kind: CelestialBodyKind) -> UIColor {
        switch kind {
        case .star: .systemYellow
        case .ocean: .systemBlue
        case .desert: .systemOrange
        case .rocky: .lightGray
        case .ice: .systemCyan
        case .gas: .systemPurple
        }
    }
}

private struct UniverseRandom {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }

    mutating func int(in range: ClosedRange<Int>) -> Int {
        range.lowerBound + Int(next() % UInt64(range.count))
    }

    mutating func chance(_ probability: Double) -> Bool {
        double(in: 0...1) < probability
    }

    mutating func double(in range: ClosedRange<Double>) -> Double {
        let unit = Double(next() >> 11) / Double(1 << 53)
        return range.lowerBound + unit * (range.upperBound - range.lowerBound)
    }

    mutating func float(in range: ClosedRange<Float>) -> Float {
        Float(double(in: Double(range.lowerBound)...Double(range.upperBound)))
    }

    mutating func unitVector() -> SIMD3<Float> {
        let z = float(in: -1...1)
        let angle = float(in: 0...(2 * .pi))
        let radius = sqrt(max(0, 1 - z * z))
        return SIMD3<Float>(radius * cos(angle), radius * sin(angle), z)
    }
}
