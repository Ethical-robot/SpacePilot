import Foundation
import simd

/// Locked Scale & Speed Contract numbers (approved 2026-07-28).
/// See `SCALE_AND_SPEED_CONTRACT.md`.
enum ScaleAndSpeedContract {
    // MARK: - Atmosphere gameplay envelope (from surface)

    /// Lower-atmosphere thickness as a fraction of planet radius.
    static let lowerAtmosphereFraction: Float = 0.52
    /// Additional upper-atmosphere thickness as a fraction of planet radius.
    static let upperAtmosphereAdditionalFraction: Float = 0.42
    /// Total atmo stack from surface (`lower + upper additional`).
    static var totalAtmosphereFraction: Float {
        lowerAtmosphereFraction + upperAtmosphereAdditionalFraction
    }

    static func lowerAtmosphereDepth(for radius: Float) -> Float {
        radius * lowerAtmosphereFraction
    }

    /// Distance from surface to the top of the upper atmosphere.
    static func upperAtmosphereDepth(for radius: Float) -> Float {
        radius * totalAtmosphereFraction
    }

    // MARK: - Visual atmosphere limb

    static let visualInnerHazeScale: Float = 1.02
    static let visualOuterHazeScale: Float = 1.05

    // MARK: - Speed regimes

    /// Lower-atmo non-boost ceiling (dogfight-readable).
    static let atmosphericBaseMax: Float = 24

    static let lowerAtmosphereBoostMultiplier: Float = 1.75
    static let upperAtmosphereCruiseMultiplier: Float = 3.5
    static let upperAtmosphereBoostMultiplier: Float = 7.0
    static let systemCruiseMultiplier: Float = 32
    /// Hyperdrive max relative to system cruise.
    static let hyperdriveVsSystemMultiplier: Float = 20

    static var lowerAtmosphereCruiseMax: Float { atmosphericBaseMax }
    static var lowerAtmosphereBoostMax: Float {
        atmosphericBaseMax * lowerAtmosphereBoostMultiplier
    }
    static var upperAtmosphereCruiseMax: Float {
        atmosphericBaseMax * upperAtmosphereCruiseMultiplier
    }
    static var upperAtmosphereBoostMax: Float {
        atmosphericBaseMax * upperAtmosphereBoostMultiplier
    }
    static var systemCruiseMax: Float {
        atmosphericBaseMax * systemCruiseMultiplier
    }
    static var hyperdriveMax: Float {
        systemCruiseMax * hyperdriveVsSystemMultiplier
    }

    // MARK: - Travel time targets → derived distances

    static let planetToPlanetSeconds: Float = 60
    static let planetToStationSeconds: Float = 18
    static let outerPlanetToSunSeconds: Float = 90

    static var typicalPlanetSpacing: Float {
        systemCruiseMax * planetToPlanetSeconds
    }
    static var typicalStationOrbitDistance: Float {
        systemCruiseMax * planetToStationSeconds
    }

    // MARK: - Solar system composition

    static let minPlanetsPerSystem = 2
    static let maxPlanetsPerSystem = 6
    static let minStationsPerSystem = 2
    static let smallStarVsLargestPlanet: Float = 5
    static let largeStarVsLargestPlanet: Float = 50
    /// Chance a system gets the large-star tier instead of small.
    static let largeStarChance: Float = 0.18

    // MARK: - Station buy pricing (station pays the player)

    static let hostPlanetBuyMultiplier: Float = 0.55
    static let sameSystemBuyMultiplier: Float = 1.00
    static let outOfSystemBuyMultiplier: Float = 1.65

    static func baselineUnitPrice(for category: SurfacePickup.Category) -> Int {
        switch category {
        case .log: 4
        case .mineral: 12
        case .creatureMaterial: 18
        case .electronic: 25
        case .relic: ProgressionEconomy.relicSellPriceMon
        case .relicKey: 40
        case .element: 8
        case .blueprint: 60
        case .module: 90
        }
    }
}

enum StationMaterialFamily: String, Codable, Sendable {
    case softOrganics
    case saltsLightMetals
    case denseHeavyMinerals
    case cryogenicVolatiles
    case gaseousExotics

    var displayName: String {
        switch self {
        case .softOrganics: "Soft organics & liquids"
        case .saltsLightMetals: "Salts & light metals"
        case .denseHeavyMinerals: "Dense / heavy minerals"
        case .cryogenicVolatiles: "Cryogenic volatiles"
        case .gaseousExotics: "Gaseous & exotic volatiles"
        }
    }

    static func specializing(in kind: CelestialBodyKind) -> StationMaterialFamily {
        switch kind {
        case .ocean: .softOrganics
        case .desert: .saltsLightMetals
        case .rocky: .denseHeavyMinerals
        case .ice: .cryogenicVolatiles
        case .gas: .gaseousExotics
        case .star: .gaseousExotics
        }
    }
}

enum StationBuyOrigin: Equatable, Sendable {
    case hostPlanet
    case sameSystem
    case outOfSystem

    var multiplier: Float {
        switch self {
        case .hostPlanet: ScaleAndSpeedContract.hostPlanetBuyMultiplier
        case .sameSystem: ScaleAndSpeedContract.sameSystemBuyMultiplier
        case .outOfSystem: ScaleAndSpeedContract.outOfSystemBuyMultiplier
        }
    }

    var label: String {
        switch self {
        case .hostPlanet: "Local specialty"
        case .sameSystem: "Same system"
        case .outOfSystem: "Out of system"
        }
    }
}

enum StationTradePricing {
    static func buyOrigin(
        itemSourcePlanetIdentifier: String,
        itemSourcePlanetName: String,
        hostPlanetIdentifier: String?,
        hostPlanetName: String?,
        stationSystemSector: GalacticSector?,
        itemSystemSector: GalacticSector?
    ) -> StationBuyOrigin {
        if let hostID = hostPlanetIdentifier,
           itemSourcePlanetIdentifier == hostID {
            return .hostPlanet
        }
        if let hostName = hostPlanetName,
           itemSourcePlanetName == hostName,
           hostPlanetIdentifier == nil || itemSourcePlanetIdentifier.isEmpty {
            return .hostPlanet
        }
        if let stationSector = stationSystemSector,
           let itemSector = itemSystemSector,
           stationSector == itemSector {
            return .sameSystem
        }
        // Same-system fallback when sector metadata is missing:
        // non-host goods still count as same-system if we cannot prove otherwise.
        if stationSystemSector == nil || itemSystemSector == nil {
            return .sameSystem
        }
        return .outOfSystem
    }

    static func unitBuyPrice(
        category: SurfacePickup.Category,
        origin: StationBuyOrigin
    ) -> Int {
        let baseline = Float(ScaleAndSpeedContract.baselineUnitPrice(for: category))
        return max(1, Int((baseline * origin.multiplier).rounded()))
    }
}
