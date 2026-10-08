import Foundation
import Observation
import RealityKit
import simd
import UIKit

enum ShipWeapon: String, CaseIterable, Sendable {
    case laser = "LASER"
    case missile = "MISSILE"
    case slowBeam = "SLOW BEAM"

    var reticleDiameter: CGFloat {
        switch self {
        case .laser: 150
        case .missile: 250
        case .slowBeam: 190
        }
    }

    var aimHalfAngle: Float {
        switch self {
        case .laser: 0.09
        case .missile: 0.22
        case .slowBeam: 0.14
        }
    }
}

enum SurfaceTool: String, CaseIterable, Sendable {
    case empty = "EMPTY"
    case axe = "AXE"
    case sonicSlicer = "SONIC SLICER"
    case matterCrumbler = "MATTER CRUMBLER"
    case matterLauncher = "MATTER LAUNCHER"
    case analyzer = "ANALYZER"

    var rawIndex: Int {
        Self.allCases.firstIndex(of: self) ?? 0
    }

    var usesOrganicEnergy: Bool {
        switch self {
        case .empty, .axe: false
        case .sonicSlicer, .matterCrumbler, .matterLauncher, .analyzer:
            true
        }
    }
}

enum GameDifficulty: String, CaseIterable, Codable, Sendable {
    case creative = "Creative"
    case normal = "Normal"
    case survivor = "Survivor"

    var detail: String {
        switch self {
        case .creative:
            "Damage feedback only — no real damage. All tools unlocked. No energy/fuel costs."
        case .normal:
            "Basic tools, standard damage. Reduced energy and fuel costs."
        case .survivor:
            "Start with Axe only. Powered tools and flight burn organics/fuel. Find Mon (§), craft, trade, and chase Relics."
        }
    }
}

enum DominantHandSetting: String, CaseIterable, Codable, Sendable {
    case right = "RIGHT"
    case left = "LEFT"
}

private struct PlayerSettingsSnapshot: Codable {
    var shipDominantHand: String
    var walkingDominantHand: String
    var roverDominantHand: String
    var difficulty: String
    /// Prefer seeing people / surroundings while immersed. Missing = on.
    var showPeopleWhilePlaying: Bool?
    /// Testing switch. Missing = off.
    var unlimitedFuelAndEnergy: Bool?
}

enum FlightConsolePage: Equatable, Sendable {
    case standby
    case fabricator
    case autopilot
    case autopilotPlanets
    case autopilotStations
    case autopilotDebris
    case engineStart
    case engineStop
}

enum SettingsResetPrompt: Equatable, Sendable {
    /// Wipe progress, move to start, pick difficulty.
    case fullReset
    /// Testing only: keep inventory/credits, relocate, pick difficulty.
    case worldResetKeepStuff
}

struct TargetContact: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let kind: NavigationTargetKind
    let distance: Float
}

struct InventoryItem: Codable, Identifiable, Equatable, Sendable {
    let id: String
    let materialName: String
    let category: SurfacePickup.Category
    let sourcePlanetIdentifier: String
    let sourcePlanetName: String
    let sourcePlanetKind: CelestialBodyKind
    var quantity: Int
    var processedElementName: String?
    /// Relic fused with a key — can be opened at the ship/station.
    var relicCanOpen: Bool?
    var moduleID: String?
    var blueprintID: String?
    /// Single-use organic energy recharge when activated/consumed.
    var energyRecharge: Float?

    var categoryLabel: String {
        switch category {
        case .log: "LOG"
        case .mineral: "MINERAL"
        case .electronic: "ELECTRONIC"
        case .creatureMaterial: "CREATURE MATERIAL"
        case .relic: "RELIC"
        case .relicKey: "RELIC KEY"
        case .element: "ELEMENT"
        case .blueprint: "BLUEPRINT"
        case .module: "MODULE"
        }
    }

    var displayName: String {
        processedElementName ?? materialName
    }

    var isRelicKey: Bool { category == .relicKey }
    var isRelic: Bool { category == .relic }
    var isEnergyCube: Bool {
        energyRecharge != nil && energyRecharge! > 0
    }
}

private struct InventorySnapshot: Codable {
    let items: [InventoryItem]
    let equippedItemID: String?
    let credits: Int?
    var progression: ProgressionSnapshot?

    init(
        items: [InventoryItem],
        equippedItemID: String?,
        credits: Int,
        progression: ProgressionSnapshot? = nil
    ) {
        self.items = items
        self.equippedItemID = equippedItemID
        self.credits = credits
        self.progression = progression
    }
}

struct StationTradeOffer: Identifiable, Equatable, Sendable {
    let id: String
    let item: InventoryItem
    let origin: StationBuyOrigin
    let unitPrice: Int

    var totalPrice: Int { unitPrice * item.quantity }
}

private struct SavedGalacticPosition: Codable {
    let sector: GalacticSector
    let x: Double
    let y: Double
    let z: Double

    init(_ position: GalacticPosition) {
        sector = position.sector
        x = position.local.x
        y = position.local.y
        z = position.local.z
    }

    var position: GalacticPosition {
        GalacticPosition(sector: sector, local: [x, y, z])
    }
}

private struct SavedQuaternion: Codable {
    let x: Float
    let y: Float
    let z: Float
    let w: Float

    init(_ quaternion: simd_quatf) {
        x = quaternion.vector.x
        y = quaternion.vector.y
        z = quaternion.vector.z
        w = quaternion.vector.w
    }

    var quaternion: simd_quatf {
        simd_normalize(simd_quatf(vector: [x, y, z, w]))
    }
}

private struct SavedVector3: Codable {
    let x: Float
    let y: Float
    let z: Float

    init(_ vector: SIMD3<Float>) {
        x = vector.x
        y = vector.y
        z = vector.z
    }

    var vector: SIMD3<Float> { [x, y, z] }
}

private struct LocationCheckpoint: Codable {
    let targetIdentifier: String
    let targetName: String
    let targetKind: NavigationTargetKind
    let isLanded: Bool
    let playerPosition: SavedGalacticPosition
    let playerAttitude: SavedQuaternion
    let activeExplorationMode: String?
    let landedShipPosition: SavedGalacticPosition?
    let landedShipAttitude: SavedQuaternion?
    let surfaceShipPosition: SavedGalacticPosition?
    let surfaceRoverPosition: SavedGalacticPosition?
    let explorationHeading: SavedVector3
    let roverDeployed: Bool
    let dominantHandName: String?
    let playerHealth: Float?
    let roverShield: Float?
    let roverHull: Float?
    let shipShield: Float?
    let shipHull: Float?
    let shipShieldActive: Bool?
    let hasRover: Bool?
}

private struct SurfaceProjectileState {
    let entity: Entity
    let direction: SIMD3<Float>
    var remainingLife: Float
    var speed: Float = 14
    var scaleGrowthPerSecond: Float = 0
    var damagesSecurityRobots = false
}

private enum AutomatedFlightPhase {
    case none
    case levelingForLanding
    case descendingForLanding
    case verticalTakeoff
}

@MainActor
@Observable
final class FlightModel {
    static let immersiveSpaceID = "SpaceFlight"
    private static let inventoryStorageKey = "SpacePilot.Inventory.v1"
    private static let locationStorageKey = "SpacePilot.Location.v1"
    private static let creditsStorageKey = "SpacePilot.Credits.v1"
    private static let settingsStorageKey = "SpacePilot.Settings.v1"

    var isImmersive = false
    /// High-frequency stick/throttle inputs stay observation-ignored so hand
    /// tracking does not invalidate SwiftUI HUD/window views every frame.
    @ObservationIgnored var throttle = 0.18
    @ObservationIgnored var pitchInput = 0.0
    @ObservationIgnored var yawInput = 0.0
    @ObservationIgnored var rollInput = 0.0
    @ObservationIgnored var strafeInputX = 0.0
    @ObservationIgnored var strafeInputY = 0.0
    var autopilot = false
    @ObservationIgnored private var simulationSpeed: Float = 0
    var speed: Float {
        get { simulationSpeed }
        set { simulationSpeed = newValue }
    }
    @ObservationIgnored var distanceTravelled: Float = 0
    @ObservationIgnored var elapsedTime: TimeInterval = 0
    /// Throttled HUD mirror of `travelSpeed` (updated in `updateTelemetry`).
    var displayedTravelSpeed: Float = 0
    var displayedDistanceTravelled: Float = 0
    var displayedElapsedTime: TimeInterval = 0
    var nearestObject = "Earth"
    var nearestDistance: Float = 0
    var currentRegion = "0, 0, 0"
    var visitedSectorCount = 0
    var discoveredBodyCount = 0
    var discoveredPointOfInterestCount = 0
    var dominantHandActive = false
    var supportHandActive = false
    var dominantHandName = "—"
    var handTrackingStatus = "Show a thumbs-up"
    var isLaserFiring = false
    var isTriggerPressed = false
    var isMissileInFlight = false
    var slowBeamEffectPercent = 0
    var slowBeamTargetName: String?
    var targetContacts: [TargetContact] = []
    var isBoosting = false
    var isHyperDriveCharging = false
    var hyperDriveCountdown: Double = 0
    var isAtmosphericBoostHeld = false
    @ObservationIgnored var atmosphericBoostBlend: Float = 0
    var isAtmosphericBoostActive = false
    var isWithinPlanetAtmosphere = false
    /// Close enough to an airless surface to level and land. No sky haze.
    @ObservationIgnored var isInAirlessLandingRange = false
    @ObservationIgnored var shipLaserDamageTimer: Float = 0
    var isDocked = false
    var isLanded = false
    var contextActionTitle: String?
    var contextActionEnabled = false
    var interactionStatus = ""
    var investigatedWreckageCount = 0
    var lockedTargetName: String?
    var currentWeaponIndex = 0
    var hasRover = true
    var hasDrone = true
    var activeExplorationMode: String?
    var environmentStatus = "SPACE"
    var altitudeAboveSurface: Float?
    var atmosphericSpeedLimit: Float?
    /// Boost ceiling while inside an atmosphere. Independent of space boost.
    var atmosphericBoostLimit: Float?
    @ObservationIgnored var atmosphereHazeOpacity = 0.0
    var starHeat: Float = 0
    var isShipDestroyed = false
    var playerHealth: Float = 20
    var roverShield: Float = 60
    var roverHull: Float = 100
    var shipShield: Float = 500
    var shipHull: Float = 1_000
    var isShipShieldActive = true
    @ObservationIgnored private var simulationDamageFlashOpacity: Double = 0
    var damageFlashOpacity: Double = 0
    var gameOverTitle: String?
    var gameOverSubtitle = ""
    @ObservationIgnored var explorationForwardInput = 0.0
    @ObservationIgnored var explorationTurnInput = 0.0
    @ObservationIgnored var explorationTravelSpeed: Float = 0
    @ObservationIgnored var explorationHeadingDegrees: Float = 0
    var displayedExplorationTravelSpeed: Float = 0
    var displayedExplorationHeadingDegrees: Float = 0
    var shipNavigationDistance: Float = 0
    var shipNavigationBearingDegrees: Float = 0
    var roverNavigationDistance: Float?
    var roverNavigationBearingDegrees: Float?
    var walkingGestureActive = false
    var isRoverDeployed = false
    var surfaceToolMenuVisible = false
    var selectedSurfaceToolIndex = 0
    var collectedSurfaceItems = 0
    var surfaceToolStatus = "Palm toward you for tools"
    var collectedLogs: [String: Int] = [:]
    var collectedMinerals: [String: Int] = [:]
    var inventoryItems: [InventoryItem] = []
    var inventoryVisible = false
    /// Loadout-kit gear menu; only pause path in single-player.
    var isSettingsMenuPresented = false
    var isPaused = false
    var gameDifficulty: GameDifficulty = .normal
    var shipDominantHand: DominantHandSetting = .right
    var walkingDominantHand: DominantHandSetting = .right
    var roverDominantHand: DominantHandSetting = .right
    /// Progressive immersion so People Awareness / Crown can reveal people.
    /// Off locks full immersion. Default on.
    var showPeopleWhilePlaying = true
    /// Temporary testing switch. Ship fuel and tool energy are not spent.
    var unlimitedFuelAndEnergy = false
    /// Confirmation sheet inside settings (`nil` = none).
    var settingsResetPrompt: SettingsResetPrompt?
    /// Tools available for the current difficulty / unlocks.
    @ObservationIgnored var unlockedSurfaceToolIndices: Set<Int> =
        Set(SurfaceTool.allCases.indices)
    var equippedInventoryItemID: String?
    /// Player currency (Mon). Persisted under the legacy credits key.
    var credits = 0
    var organicEnergy: Float = ProgressionEconomy.baseOrganicEnergyCapacity
    var shipFuel: Float = ProgressionEconomy.maxShipFuel
    var hasNavModule = true
    var ownedModuleIDs: Set<String> = []
    var ownedBlueprintIDs: Set<String> = []
    var crumblerEfficiencyTier = 0
    var toolUpgradeTiers: [String: Int] = [:]
    /// Permanent capacity expansions crafted (each +50, max 5).
    var energyStorageExpansions = 0
    var isRefineryPresented = false
    var isStationShopPresented = false
    @ObservationIgnored private var guaranteedAxeGranted = false
    @ObservationIgnored private var relicLocatorEntity: Entity?

    var mon: Int {
        get { credits }
        set { credits = max(0, newValue) }
    }
    var organicEnergyCapacity: Float {
        ProgressionEconomy.organicEnergyCapacity(
            expansions: energyStorageExpansions
        )
    }

    let inventoryCapacity = 100
    let inventoryDemoSlotCount = 50
    @ObservationIgnored private var dockedStationHostPlanetName: String?
    @ObservationIgnored private var dockedStationHostPlanetKind:
        CelestialBodyKind?
    @ObservationIgnored private var dockedStationSpecialty:
        StationMaterialFamily?
    @ObservationIgnored private var dockedStationSystemSector: GalacticSector?

    @ObservationIgnored var universeRoot: Entity?
    @ObservationIgnored var universeStreamer: UniverseStreamer?
    @ObservationIgnored var laserEntity: Entity?
    @ObservationIgnored var slowBeamEntity: Entity?
    @ObservationIgnored var missileEntity: Entity?
    @ObservationIgnored var weaponReticleEntity: Entity?
    @ObservationIgnored private var weaponReticleSuppressed = false
    @ObservationIgnored var aimAnchorEntity: Entity?
    @ObservationIgnored var atmosphereEnvironmentEntity: Entity?
    @ObservationIgnored var atmosphereSkyEntity: ModelEntity?
    @ObservationIgnored var atmosphereLightEntities: [DirectionalLight] = []
    @ObservationIgnored var lastAtmosphereVisualOpacity: Float = -1
    @ObservationIgnored var lastAtmosphereVisualKind: CelestialBodyKind?
    @ObservationIgnored var lastSkyLimbElevation: Float = 999
    @ObservationIgnored var lastSkyTextureKey: Int = -1
    @ObservationIgnored var playerPosition = GalacticPosition.origin
    @ObservationIgnored var playerAttitude = simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0))
    @ObservationIgnored var lastTick = ContinuousClock.now
    @ObservationIgnored var telemetryAccumulator: TimeInterval = 0
    @ObservationIgnored var sceneUpdateSubscription: EventSubscription?
    @ObservationIgnored var onFrameExtras: (() -> Void)?
    @ObservationIgnored private var lastCheckpointPlayerPosition:
        GalacticPosition?
    @ObservationIgnored var nearbyInteractionTarget: NearbyNavigationTarget?
    @ObservationIgnored var lockedTargetIdentifier: String?
    @ObservationIgnored var securedLocationKind: NavigationTargetKind?
    @ObservationIgnored var securedLocationName: String?
    @ObservationIgnored private var securedLocationIdentifier: String?
    @ObservationIgnored var joystickControlEntity: Entity?
    @ObservationIgnored var joystickPivotEntity: Entity?
    @ObservationIgnored var throttleControlEntity: Entity?
    @ObservationIgnored var throttleHandleEntity: Entity?
    @ObservationIgnored var fireButtonEntity: Entity?
    @ObservationIgnored var turboButtonEntity: Entity?
    @ObservationIgnored var hyperSpeedEntity: Entity?
    @ObservationIgnored var cockpitEntity: Entity?
    @ObservationIgnored var trueForwardReferenceEntity: Entity?
    @ObservationIgnored var lastFireButtonLit: Bool?
    @ObservationIgnored var lastTurboButtonState: Int?
    @ObservationIgnored var lastReticleWeaponIndex: Int?
    @ObservationIgnored var turboButtonSide: Float = 1
    @ObservationIgnored var missileFlightRemaining: Float = 0
    @ObservationIgnored var missileTargetName: String?
    @ObservationIgnored var missileWillHit = false
    @ObservationIgnored var missileVisualVelocity = SIMD3<Float>.zero
    @ObservationIgnored var nextMissileLaunchesFromLeft = true
    @ObservationIgnored var slowExposureByTarget: [String: Float] = [:]
    @ObservationIgnored var surfaceUpDirection: SIMD3<Float>?
    @ObservationIgnored var nearbyWorldForEnvironment: NearbyNavigationTarget?
    @ObservationIgnored var explorationHeading = SIMD3<Float>(0, 0, -1)
    @ObservationIgnored var explorationNorth = SIMD3<Float>(0, 0, -1)
    @ObservationIgnored var explorationEast = SIMD3<Float>(1, 0, 0)
    @ObservationIgnored var surfaceStepHeight: Float = 0
    /// Extra height from on-foot jetpack thrust / slow fall (walking only).
    @ObservationIgnored var surfaceJetpackAltitude: Float = 0
    @ObservationIgnored var surfaceJetpackVelocity: Float = 0
    /// Max rocket / jetpack flight time in seconds (full bar).
    static let jetpackFuelCapacity: Float = 5
    @ObservationIgnored var surfaceJetpackFuel: Float = FlightModel.jetpackFuelCapacity
    @ObservationIgnored var isJetpackThrusting = false
    @ObservationIgnored var isRunningGestureActive = false
    @ObservationIgnored var controllerRunHeld = false
    /// Gamepad can latch the kit open independently of the hand pose.
    @ObservationIgnored var controllerSurfaceKitLatched = false
    /// Hand-driven kit request (on foot: fist + thumb toward you).
    @ObservationIgnored var handSurfaceKitActive = false
    /// HUD mirror of jetpack fuel (0...capacity seconds).
    var displayedJetpackFuel: Float = FlightModel.jetpackFuelCapacity
    @ObservationIgnored var landedShipPosition: GalacticPosition?
    @ObservationIgnored var landedShipAttitude: simd_quatf?
    @ObservationIgnored var surfaceShipPosition: GalacticPosition?
    @ObservationIgnored var surfaceRoverPosition: GalacticPosition?
    @ObservationIgnored var surfaceToolMenuEntity: Entity?
    @ObservationIgnored var heldSurfaceToolEntity: Entity?
    /// Tool-menu slot currently held down by the index tip (−1 = none).
    /// Tool-menu plate latched down for the currently selected tool.
    @ObservationIgnored private var pressedSurfaceToolSlotIndex: Int = -1
    @ObservationIgnored var heldInventoryItemEntity: Entity?
    @ObservationIgnored private var inventoryDismissedForCurrentGesture = false
    @ObservationIgnored private var surfaceProjectiles:
        [SurfaceProjectileState] = []
    @ObservationIgnored private var matterCrumblerBeamEntity: Entity?
    @ObservationIgnored private var matterCrumblerBeamTimeout: Float = 0
    @ObservationIgnored private var matterCrumblerTrackingHold = false
    @ObservationIgnored private var lastMatterCrumblerOrigin =
        SIMD3<Float>.zero
    @ObservationIgnored private var lastMatterCrumblerDirection =
        SIMD3<Float>(0, 0, -1)
    @ObservationIgnored private var analyzerRingMesh: MeshResource?
    @ObservationIgnored var walkingFacingDirection =
        SIMD3<Float>(0, 0, -1)
    @ObservationIgnored var hasWalkingFacingDirection = false
    @ObservationIgnored private var automatedFlightPhase = AutomatedFlightPhase.none
    @ObservationIgnored private var automatedTargetIdentifier: String?
    @ObservationIgnored private var landingLevelElapsed: Float = 0
    @ObservationIgnored private var takeoffTargetDistance: Float = 0
    /// Autopilot: countdown while warning about low fuel before hyper.
    @ObservationIgnored private var autopilotFuelWarningRemaining: Double = 0
    /// Autopilot: 3 s charge before hyper (same as manual turbo).
    @ObservationIgnored private var autopilotHyperChargeRemaining: Double = 0
    /// Autopilot: flash pad three times on arrival before disengaging.
    @ObservationIgnored private var autopilotArrivalFlashRemaining: Double = 0
    @ObservationIgnored private var autopilotPendingHyper = false
    @ObservationIgnored private var consolePageBeforeEngine: FlightConsolePage = .standby
    @ObservationIgnored private var savedLocationCheckpoint:
        LocationCheckpoint?
    @ObservationIgnored private var checkpointSaveAccumulator: Float = 0
    @ObservationIgnored private var pendingSurfaceKnockback =
        SIMD3<Float>.zero
    @ObservationIgnored private var gameOverRemaining: Float = 0
    @ObservationIgnored private var walkingRecoveryUsesRover = false
    @ObservationIgnored private var lastTakeoffPosition:
        GalacticPosition?
    @ObservationIgnored private var lastTakeoffAttitude: simd_quatf?
    let maximumForwardSpeed: Float = 46
    let hyperDriveChargeMultiplier: Float = 4
    let atmosphericBoostMultiplier: Float = 4
    let boostMultiplier: Float = 10 * UniverseScale.distance
    let equippedWeapons = ShipWeapon.allCases

    init(defaults: UserDefaults = .standard) {
        if let locationData = defaults.data(
            forKey: Self.locationStorageKey
        ) {
            savedLocationCheckpoint = try? JSONDecoder().decode(
                LocationCheckpoint.self,
                from: locationData
            )
        }
        loadPlayerSettings(defaults: defaults)

        guard let data = defaults.data(
            forKey: Self.inventoryStorageKey
        ),
        let snapshot = try? JSONDecoder().decode(
            InventorySnapshot.self,
            from: data
        ) else {
            applyDifficultyLoadout(resetMeters: true)
            return
        }

        inventoryItems = Array(
            snapshot.items
                .filter { $0.quantity > 0 }
                .prefix(inventoryCapacity)
        )
        equippedInventoryItemID = snapshot.equippedItemID.flatMap { savedID in
            inventoryItems.contains(where: { $0.id == savedID })
                ? savedID
                : nil
        }
        credits = max(0, snapshot.credits ?? defaults.integer(forKey: Self.creditsStorageKey))
        if let progression = snapshot.progression {
            applyProgressionSnapshot(progression)
        }
        rebuildCollectedItemCounts()
        applyDifficultyLoadout(resetMeters: snapshot.progression == nil)
    }

    var travelSpeed: Float {
        let unrestrictedSpeed: Float
        if isBoosting {
            // Full hyperdrive always exceeds the fixed pre-charge velocity,
            // even when it was engaged from a low throttle setting.
            unrestrictedSpeed = max(speed, maximumForwardSpeed) * boostMultiplier
        } else if isHyperDriveCharging {
            unrestrictedSpeed = maximumForwardSpeed * hyperDriveChargeMultiplier
        } else {
            unrestrictedSpeed = speed
        }
        guard let atmosphericSpeedLimit else { return unrestrictedSpeed }
        let limitedSpeed = max(
            -atmosphericSpeedLimit,
            min(atmosphericSpeedLimit, unrestrictedSpeed)
        )
        guard atmosphericBoostBlend > 0 else { return limitedSpeed }
        let boostCeiling =
            atmosphericBoostLimit
            ?? maximumForwardSpeed * atmosphericBoostMultiplier
        return limitedSpeed
            + (boostCeiling - limitedSpeed) * atmosphericBoostBlend
    }
    var isConsumingHyperFuel: Bool { isBoosting }
    /// `currentWeaponIndex == equippedWeapons.count` means disarmed.
    /// Engines off forces the weapon off without changing that selection.
    var isWeaponArmed: Bool {
        enginesRunning
            && currentWeaponIndex >= 0
            && currentWeaponIndex < equippedWeapons.count
    }
    var currentWeaponType: ShipWeapon {
        guard isWeaponArmed else { return .laser }
        return equippedWeapons[currentWeaponIndex]
    }
    var currentWeapon: String {
        isWeaponArmed ? currentWeaponType.rawValue : "DISARMED"
    }
    var reticleDiameter: CGFloat {
        isWeaponArmed ? currentWeaponType.reticleDiameter : 150
    }
    var hasAutopilotTarget: Bool { lockedTargetIdentifier != nil }
    /// Console pad blink while AP warns or finishes arrival.
    var autopilotConsoleFlashing = false
    /// Propulsion. Off in space holds course and speed with no fuel use.
    /// Hyperdrive shuts down when engines are off.
    var enginesRunning = true
    var consolePage: FlightConsolePage = .standby
    var engineAnimRemaining: Double = 0
    var isOutsideShip: Bool { activeExplorationMode != nil }
    var isSurfaceExploration: Bool {
        activeExplorationMode == "Deploy rover"
            || activeExplorationMode == "Leave on foot"
    }
    var isTradeConcourseActive: Bool {
        activeExplorationMode == "Visit trade concourse"
    }
    /// Inventory / loadout kit is available in every play context.
    var canPresentInventory: Bool {
        gameOverTitle == nil
    }

    var dominantHandSettingForCurrentMode: DominantHandSetting {
        switch activeExplorationMode {
        case "Leave on foot": walkingDominantHand
        case "Deploy rover": roverDominantHand
        default: shipDominantHand
        }
    }
    var isAutomatedFlightManeuver: Bool {
        automatedFlightPhase != .none
    }
    var explorationMaximumSpeed: Float {
        activeExplorationMode == "Deploy rover" ? 11 : 2.6
    }
    var canEnterShip: Bool {
        isSurfaceExploration && shipNavigationDistance <= 15
    }
    var canEnterRover: Bool {
        activeExplorationMode == "Leave on foot"
            && roverNavigationDistance.map { $0 <= 15 } == true
    }
    var selectedSurfaceTool: SurfaceTool {
        SurfaceTool.allCases[selectedSurfaceToolIndex]
    }
    var matterLauncherAmmoCount: Int {
        collectedMinerals.values.reduce(0, +)
    }
    var equippedInventoryItem: InventoryItem? {
        inventoryItems.first { $0.id == equippedInventoryItemID }
    }
    var surfaceToolInstruction: String {
        if equippedInventoryItem != nil {
            return "HOLD ITEM TO MOUTH FOR 2 SECONDS TO EAT"
        }
        return switch selectedSurfaceTool {
        case .axe:
            "AXE • CHOP TREES FOR ORGANIC ENERGY FEEDSTOCK"
        case .sonicSlicer:
            "AIM TOOL • PRESS THUMB DOWN TO ACTIVATE"
        case .matterCrumbler, .matterLauncher, .analyzer:
            "AIM TOOL • ENERGY \(Int(organicEnergy)) • PRESS THUMB DOWN"
        case .empty:
            "LOOK TO STEER • EXTEND SECONDARY HAND TO WALK"
        }
    }
    var canCycleWeapons: Bool {
        enginesRunning && !isAutomatedFlightManeuver
    }
    var canPresentDetectionPicker: Bool {
        !isDocked && !isLanded && !isAutomatedFlightManeuver
    }
    var canUseDetection: Bool {
        hasNavModule && canPresentDetectionPicker
    }
    var detectionLockReason: String {
        hasNavModule
            ? ""
            : "Requires Nav Module — buy at a station (§\(ProgressionEconomy.navModulePriceMon))"
    }
    var hasRoverRefinery: Bool {
        ownedModuleIDs.contains(ProgressionEconomy.roverRefineryModuleID)
    }
    /// Ship: available in cockpit including free flight. Rover: Rover Refinery upgrade.
    var isFabricatorAvailable: Bool {
        guard !isShipDestroyed else { return false }
        if !isOutsideShip {
            return true
        }
        return activeExplorationMode == "Deploy rover" && hasRoverRefinery
    }
    var isStationShopAvailable: Bool {
        isDocked && securedLocationKind == .station && !isOutsideShip
    }
    var canLeaveShip: Bool { !availableExitOptions.isEmpty }
    var canUseLandingControl: Bool {
        if isAutomatedFlightManeuver { return false }
        if isLanded || isDocked { return true }
        guard abs(travelSpeed) <= maximumForwardSpeed * 0.5,
              let target = universeStreamer?.nearestDestination(to: playerPosition) else {
            return false
        }
        return switch target.kind {
        case .station:
            target.distance <= UniverseScale.stationDockingDistance
        case .wreckage: target.distance <= 50
        case .world:
            target.celestialKind == .gas
                ? false
                : target.hasAtmosphere
                ? target.distance - target.radius
                    <= UniverseScale.lowerAtmosphereDepth(for: target.radius)
                : target.distance <= target.radius + 22
        }
    }
    var landingControlTitle: String {
        switch automatedFlightPhase {
        case .levelingForLanding: return "LEVELING"
        case .descendingForLanding: return "LANDING"
        case .verticalTakeoff: return "TAKING OFF"
        case .none: break
        }
        if isLanded { return "TAKE OFF" }
        if isDocked { return "UNDOCK" }
        return "LAND / DOCK"
    }
    var availableExitOptions: [String] {
        if isLanded {
            return ["Leave on foot"]
                + (hasRover && !isRoverDeployed
                    ? ["Deploy rover"]
                    : [])
        }
        if isDocked, securedLocationKind == .station {
            return [
                "Visit trade concourse",
                "Visit station shop",
                "Visit shipyard",
                "Explore station"
            ]
        }
        if isDocked, securedLocationKind == .wreckage {
            return ["Explore wreckage"] + (hasDrone ? ["Deploy drone"] : [])
        }
        return []
    }

    func resetFlight() {
        playerPosition = .origin
        playerAttitude = simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0))
        speed = 0
        distanceTravelled = 0
        elapsedTime = 0
        throttle = 0.18
        pitchInput = 0
        yawInput = 0
        rollInput = 0
        strafeInputX = 0
        strafeInputY = 0
        autopilot = false
        isBoosting = false
        isHyperDriveCharging = false
        hyperDriveCountdown = 0
        isAtmosphericBoostHeld = false
        atmosphericBoostBlend = 0
        isAtmosphericBoostActive = false
        isWithinPlanetAtmosphere = false
        automatedFlightPhase = .none
        automatedTargetIdentifier = nil
        landingLevelElapsed = 0
        takeoffTargetDistance = 0
        isDocked = false
        isLanded = false
        securedLocationIdentifier = nil
        securedLocationKind = nil
        securedLocationName = nil
        clearDockedStationTradeContext()
        activeExplorationMode = nil
        resetWalkingLocomotionBoosts()
        landedShipPosition = nil
        landedShipAttitude = nil
        surfaceShipPosition = nil
        surfaceRoverPosition = nil
        isRoverDeployed = false
        universeStreamer?.endSurfaceExploration()
        environmentStatus = "SPACE"
        altitudeAboveSurface = nil
        atmosphericSpeedLimit = nil
            atmosphericBoostLimit = nil
        atmosphereHazeOpacity = 0
        atmosphereEnvironmentEntity?.isEnabled = false
        lastAtmosphereVisualOpacity = -1
        lastAtmosphereVisualKind = nil
        lastSkyLimbElevation = 999
        lastSkyTextureKey = -1
        surfaceUpDirection = nil
        nearbyWorldForEnvironment = nil
        starHeat = 0
        isShipDestroyed = false
        playerHealth = 20
        roverShield = 60
        roverHull = 100
        shipShield = 500
        shipHull = 1_000
        isShipShieldActive = true
        setDamageFlashOpacity(0)
        gameOverTitle = nil
        gameOverSubtitle = ""
        gameOverRemaining = 0
        pendingSurfaceKnockback = .zero
        walkingRecoveryUsesRover = false
        lastTakeoffPosition = nil
        lastTakeoffAttitude = nil
        explorationForwardInput = 0
        explorationTurnInput = 0
        explorationTravelSpeed = 0
        explorationHeadingDegrees = 0
        displayedTravelSpeed = 0
        displayedDistanceTravelled = 0
        displayedElapsedTime = 0
        displayedExplorationTravelSpeed = 0
        displayedExplorationHeadingDegrees = 0
        explorationHeading = [0, 0, -1]
        explorationNorth = [0, 0, -1]
        explorationEast = [1, 0, 0]
        walkingFacingDirection = [0, 0, -1]
        hasWalkingFacingDirection = false
        shipNavigationDistance = 0
        shipNavigationBearingDegrees = 0
        roverNavigationDistance = nil
        roverNavigationBearingDegrees = nil
        walkingGestureActive = false
        surfaceToolMenuVisible = false
        selectedSurfaceToolIndex = 0
        surfaceToolStatus = "Palm toward you for tools"
        inventoryVisible = false
        inventoryDismissedForCurrentGesture = false
        clearSurfaceProjectiles()
        updateSelectedSurfaceToolVisual()
        updateHeldInventoryItemVisual()
        cockpitEntity?.isEnabled = true
        cancelAutopilotTarget()
        nearbyInteractionTarget = nil
        contextActionTitle = nil
        contextActionEnabled = false
        interactionStatus = ""
        setLaserFiring(false)
        isMissileInFlight = false
        missileEntity?.isEnabled = false
        missileFlightRemaining = 0
        missileTargetName = nil
        nextMissileLaunchesFromLeft = true
        slowBeamTargetName = nil
        slowBeamEffectPercent = 0
        targetContacts = []
        lastTick = .now
        checkpointSaveAccumulator = 0
        // Startup is always landed or docked. Engines stay off until the pad
        // is pressed; the checkpoint does not store this flag.
        enginesRunning = false
        restoreSavedLocation()
        universeStreamer?.update(around: playerPosition.sector)
        ensureSafeSpawnOutsideStarHazard()
        applyCameraTransform()
        updateCockpitVisuals(dt: 0)
        updateTelemetry()
    }

    /// Origin is the system sun center after the solar-system contract. Never
    /// leave the player free-flying inside a star heat zone.
    private func ensureSafeSpawnOutsideStarHazard() {
        if isLanded { return }
        let needsRescue: Bool
        if let streamer = universeStreamer,
           let star = streamer.nearestDestination(
                to: playerPosition,
                matching: .world
           ),
           star.celestialKind == .star {
            let altitude = max(0, star.distance - star.radius)
            let heatZoneDepth = max(star.radius * 0.6, 250)
            needsRescue = altitude < heatZoneDepth
        } else if !isDocked, !isLanded {
            // Fresh start / reset with no station context: still rescue if we
            // are sitting at galactic origin with no safe checkpoint.
            needsRescue =
                simd_length(playerPosition.local) < 50
                && playerPosition.sector == .origin
        } else {
            needsRescue = false
        }
        guard needsRescue else { return }
        dockAtStartingStation()
    }

    private func dockAtStartingStation() {
        guard let streamer = universeStreamer else {
            let station =
                ProceduralUniverseGenerator(
                    universeSeed: 0x5350_4143_4550_494C
                ).startingStation()
            playerPosition = GalacticPosition(
                sector: .origin,
                local: station.localPosition
            )
            isDocked = true
            isLanded = false
            securedLocationName = station.name
            securedLocationKind = .station
            dockedStationHostPlanetName = station.hostPlanetName
            dockedStationHostPlanetKind = station.hostPlanetKind
            dockedStationSpecialty = station.specialtyFamily
            dockedStationSystemSector = .origin
            starHeat = 0
            speed = 0
            throttle = 0
            interactionStatus = "Docked at \(station.name)"
            return
        }
        streamer.update(around: .origin)
        let target = streamer.startingStationNavigationTarget()
        playerPosition = GalacticPosition(
            sector: .origin,
            local: streamer.startingStation.localPosition
        )
        secureShip(to: target, landed: false)
        starHeat = 0
        speed = 0
        throttle = 0
        interactionStatus = "Docked at \(target.name)"
        persistLocationCheckpoint()
    }

    func saveProgress() {
        persistInventory()
        persistLocationCheckpoint()
        persistPlayerSettings()
    }

    var damageIntakeMultiplier: Float {
        switch gameDifficulty {
        case .creative: 0
        case .normal: 1
        case .survivor: 1.75
        }
    }

    /// Single-player only until multiplayer exists; gear is the only pause entry.
    var allowsSimulationPause: Bool { true }

    func openSettingsMenu() {
        settingsResetPrompt = nil
        isSettingsMenuPresented = true
        if allowsSimulationPause {
            isPaused = true
        }
        inventoryDismissedForCurrentGesture = false
        inventoryVisible = true
        updateWeaponReticleVisual()
        interactionStatus =
            isPaused ? "Paused • Settings" : "Settings"
    }

    func closeSettingsMenu() {
        settingsResetPrompt = nil
        isSettingsMenuPresented = false
        isPaused = false
        interactionStatus = ""
        // Drop stale hand latch; re-open kit with fist / gamepad if needed.
        handSurfaceKitActive = false
        refreshSurfaceKitVisibility()
    }

    func setShipDominantHand(_ hand: DominantHandSetting) {
        shipDominantHand = hand
        persistPlayerSettings()
        dominantHandName = dominantHandSettingForCurrentMode.rawValue
    }

    func setWalkingDominantHand(_ hand: DominantHandSetting) {
        walkingDominantHand = hand
        persistPlayerSettings()
        dominantHandName = dominantHandSettingForCurrentMode.rawValue
    }

    func setRoverDominantHand(_ hand: DominantHandSetting) {
        roverDominantHand = hand
        persistPlayerSettings()
        dominantHandName = dominantHandSettingForCurrentMode.rawValue
    }

    func setShowPeopleWhilePlaying(_ enabled: Bool) {
        showPeopleWhilePlaying = enabled
        persistPlayerSettings()
    }

    func setUnlimitedFuelAndEnergy(_ enabled: Bool) {
        unlimitedFuelAndEnergy = enabled
        persistPlayerSettings()
    }

    func beginSettingsResetPrompt(_ prompt: SettingsResetPrompt) {
        settingsResetPrompt = prompt
    }

    func cancelSettingsResetPrompt() {
        settingsResetPrompt = nil
    }

    /// Full wipe or testing world-reset; always relocates to the starting station.
    func confirmSettingsReset(
        difficulty: GameDifficulty,
        keepInventoryAndCredits: Bool
    ) {
        gameDifficulty = difficulty
        settingsResetPrompt = nil
        isSettingsMenuPresented = false
        isPaused = false
        inventoryVisible = false
        surfaceToolMenuVisible = false
        surfaceToolMenuEntity?.isEnabled = false
        handSurfaceKitActive = false
        controllerSurfaceKitLatched = false

        if !keepInventoryAndCredits {
            inventoryItems = []
            equippedInventoryItemID = nil
            credits = 0
            collectedLogs = [:]
            collectedMinerals = [:]
            collectedSurfaceItems = 0
            hasRover = true
            hasDrone = true
            defaultsClearLocationCheckpoint()
            persistInventory()
        }

        if !keepInventoryAndCredits {
            ownedModuleIDs = []
            ownedBlueprintIDs = []
            crumblerEfficiencyTier = 0
            toolUpgradeTiers = [:]
            energyStorageExpansions = 0
            hasNavModule = false
            guaranteedAxeGranted = false
            unlockedSurfaceToolIndices = [SurfaceTool.empty.rawIndex]
        }
        applyDifficultyLoadout(resetMeters: true)
        persistPlayerSettings()

        activeExplorationMode = nil
        isStationShopPresented = false
        isRefineryPresented = false
        resetWalkingLocomotionBoosts()
        universeStreamer?.endSurfaceExploration()
        landedShipPosition = nil
        landedShipAttitude = nil
        surfaceShipPosition = nil
        surfaceRoverPosition = nil
        isRoverDeployed = false
        cockpitEntity?.isEnabled = true
        synchronizeTrueForwardParent()
        trueForwardReferenceEntity?.isEnabled = true
        isShipDestroyed = false
        playerHealth = 20
        roverShield = 60
        roverHull = 100
        shipShield = 500
        shipHull = 1_000
        gameOverTitle = nil
        gameOverSubtitle = ""
        setWeaponTrigger(false)
        stop()
        enginesRunning = false
        consolePage = .standby
        dockAtStartingStation()
        universeStreamer?.update(around: playerPosition.sector)
        applyCameraTransform()
        updateTelemetry()
        interactionStatus =
            keepInventoryAndCredits
                ? "World reset • \(difficulty.rawValue) • inventory kept (test)"
                : "Game reset • \(difficulty.rawValue)"
        saveProgress()
    }

    func openRefineryPanel() {
        guard isFabricatorAvailable else {
            interactionStatus =
                activeExplorationMode == "Deploy rover"
                    ? "Install Rover Refinery Module at a station first"
                    : "Fabricator unavailable"
            return
        }
        // Hide the loadout kit so its closer attachment cannot steal hits
        // from the fabricator panel (that looked like a frozen / unclosable UI).
        inventoryVisible = false
        inventoryDismissedForCurrentGesture = true
        isSettingsMenuPresented = false
        isPaused = false
        isStationShopPresented = false
        isRefineryPresented = true
        setWeaponReticleSuppressed(true)
        trueForwardReferenceEntity?.isEnabled = false
        interactionStatus = "Refinery / Fabricator"
    }

    func closeRefineryPanel(clearStatus: Bool = true) {
        guard isRefineryPresented else { return }
        isRefineryPresented = false
        inventoryDismissedForCurrentGesture = false
        // Restore aiming / directional sights unless another modal owns them.
        if !isStationShopPresented && !isSettingsMenuPresented {
            setWeaponReticleSuppressed(false)
        }
        updateWeaponReticleVisual()
        updateTrueForwardReference()
        if clearStatus {
            interactionStatus = ""
        }
    }

    func closeStationShop() {
        isStationShopPresented = false
        if !isRefineryPresented && !isSettingsMenuPresented {
            setWeaponReticleSuppressed(false)
        }
        updateWeaponReticleVisual()
        updateTrueForwardReference()
    }

    private func defaultsClearLocationCheckpoint(
        defaults: UserDefaults = .standard
    ) {
        savedLocationCheckpoint = nil
        defaults.removeObject(forKey: Self.locationStorageKey)
    }

    private func loadPlayerSettings(defaults: UserDefaults = .standard) {
        guard let data = defaults.data(forKey: Self.settingsStorageKey),
              let snapshot = try? JSONDecoder().decode(
                PlayerSettingsSnapshot.self,
                from: data
              ) else {
            shipDominantHand = .right
            walkingDominantHand = .right
            roverDominantHand = .right
            gameDifficulty = .normal
            showPeopleWhilePlaying = true
            unlimitedFuelAndEnergy = false
            dominantHandName = DominantHandSetting.right.rawValue
            return
        }
        shipDominantHand =
            DominantHandSetting(rawValue: snapshot.shipDominantHand) ?? .right
        walkingDominantHand =
            DominantHandSetting(rawValue: snapshot.walkingDominantHand)
            ?? .right
        roverDominantHand =
            DominantHandSetting(rawValue: snapshot.roverDominantHand) ?? .right
        gameDifficulty =
            GameDifficulty(rawValue: snapshot.difficulty) ?? .normal
        showPeopleWhilePlaying = snapshot.showPeopleWhilePlaying ?? true
        unlimitedFuelAndEnergy = snapshot.unlimitedFuelAndEnergy ?? false
        dominantHandName = dominantHandSettingForCurrentMode.rawValue
    }

    private func persistPlayerSettings(
        defaults: UserDefaults = .standard
    ) {
        let snapshot = PlayerSettingsSnapshot(
            shipDominantHand: shipDominantHand.rawValue,
            walkingDominantHand: walkingDominantHand.rawValue,
            roverDominantHand: roverDominantHand.rawValue,
            difficulty: gameDifficulty.rawValue,
            showPeopleWhilePlaying: showPeopleWhilePlaying,
            unlimitedFuelAndEnergy: unlimitedFuelAndEnergy
        )
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: Self.settingsStorageKey)
    }

    private func applyDifficultyLoadout(resetMeters: Bool = false) {
        switch gameDifficulty {
        case .creative:
            unlockedSurfaceToolIndices = Set(SurfaceTool.allCases.indices)
            hasNavModule = true
            ownedModuleIDs.insert(ProgressionEconomy.navModuleID)
            if resetMeters {
                energyStorageExpansions = 0
                organicEnergy = organicEnergyCapacity
                shipFuel = ProgressionEconomy.maxShipFuel
            }
        case .normal:
            unlockedSurfaceToolIndices.formUnion([
                SurfaceTool.empty.rawIndex,
                SurfaceTool.axe.rawIndex,
                SurfaceTool.sonicSlicer.rawIndex,
                SurfaceTool.matterCrumbler.rawIndex,
                SurfaceTool.analyzer.rawIndex
            ])
            hasNavModule = true
            ownedModuleIDs.insert(ProgressionEconomy.navModuleID)
            if resetMeters {
                energyStorageExpansions = 0
                organicEnergy = organicEnergyCapacity
                shipFuel = ProgressionEconomy.maxShipFuel
            }
        case .survivor:
            unlockedSurfaceToolIndices.formUnion([
                SurfaceTool.empty.rawIndex,
                SurfaceTool.axe.rawIndex
            ])
            // Early path: Axe ships with the starter kit.
            guaranteedAxeGranted = true
            hasNavModule = ownedModuleIDs.contains(
                ProgressionEconomy.navModuleID
            )
            if resetMeters {
                energyStorageExpansions = 0
                organicEnergy = 25
                shipFuel = 45
            }
        }
        // Re-apply module tool unlocks earned in prior sessions.
        for moduleID in ownedModuleIDs {
            applyModuleUnlock(moduleID, persist: false)
        }
        organicEnergy = min(organicEnergy, organicEnergyCapacity)
        if !unlockedSurfaceToolIndices.contains(selectedSurfaceToolIndex) {
            selectedSurfaceToolIndex =
                unlockedSurfaceToolIndices.sorted().first ?? 0
        }
        updateSelectedSurfaceToolVisual()
        persistProgression()
    }

    private func applyProgressionSnapshot(_ snapshot: ProgressionSnapshot) {
        energyStorageExpansions = max(
            0,
            min(
                ProgressionEconomy.maxEnergyStorageExpansions,
                snapshot.energyStorageExpansions ?? 0
            )
        )
        organicEnergy = min(
            organicEnergyCapacity,
            max(0, snapshot.organicEnergy)
        )
        shipFuel = min(
            ProgressionEconomy.maxShipFuel,
            max(0, snapshot.shipFuel)
        )
        hasNavModule = snapshot.hasNavModule
        ownedModuleIDs = Set(snapshot.ownedModuleIDs)
        ownedBlueprintIDs = Set(snapshot.ownedBlueprintIDs)
        crumblerEfficiencyTier = max(0, min(2, snapshot.crumblerEfficiencyTier))
        toolUpgradeTiers = snapshot.toolUpgradeTiers
        guaranteedAxeGranted = snapshot.guaranteedAxeGranted
    }

    private func makeProgressionSnapshot() -> ProgressionSnapshot {
        ProgressionSnapshot(
            organicEnergy: organicEnergy,
            shipFuel: shipFuel,
            hasNavModule: hasNavModule,
            ownedModuleIDs: ownedModuleIDs.sorted(),
            ownedBlueprintIDs: ownedBlueprintIDs.sorted(),
            crumblerEfficiencyTier: crumblerEfficiencyTier,
            toolUpgradeTiers: toolUpgradeTiers,
            guaranteedAxeGranted: guaranteedAxeGranted,
            energyStorageExpansions: energyStorageExpansions
        )
    }

    private func persistProgression() {
        persistInventory()
    }

    @discardableResult
    func spendOrganicEnergy(_ amount: Float) -> Bool {
        if unlimitedFuelAndEnergy { return true }
        let cost =
            amount * ProgressionEconomy.energyCostMultiplier(
                difficulty: gameDifficulty
            )
        guard cost <= 0.000_1 || organicEnergy >= cost else {
            surfaceToolStatus = "LOW ORGANIC ENERGY • convert logs at ship"
            interactionStatus = surfaceToolStatus
            return false
        }
        organicEnergy = max(0, organicEnergy - cost)
        return true
    }

    func convertLogsToEnergy(maxLogs: Int = 50) -> Int {
        guard isFabricatorAvailable else {
            interactionStatus = "Fabricator unavailable"
            return 0
        }
        var converted = 0
        while converted < maxLogs,
              organicEnergy < organicEnergyCapacity - 0.5,
              let index = inventoryItems.firstIndex(where: {
                  $0.category == .log && $0.quantity > 0
              }) {
            inventoryItems[index].quantity -= 1
            if inventoryItems[index].quantity <= 0 {
                let removedID = inventoryItems[index].id
                inventoryItems.remove(at: index)
                if equippedInventoryItemID == removedID {
                    equippedInventoryItemID = nil
                }
            }
            organicEnergy = min(
                organicEnergyCapacity,
                organicEnergy + ProgressionEconomy.energyPerLog
            )
            converted += 1
        }
        rebuildCollectedItemCounts()
        persistInventory()
        interactionStatus =
            converted > 0
                ? "Converted \(converted) log(s) → energy \(Int(organicEnergy))/\(Int(organicEnergyCapacity))"
                : "No logs to convert (or energy full)"
        return converted
    }

    /// Consume one equipped (or matched) energy cube for a one-shot recharge.
    @discardableResult
    func useEnergyCube(itemID: String? = nil) -> Bool {
        let targetID = itemID ?? equippedInventoryItemID
        guard let targetID,
              let index = inventoryItems.firstIndex(where: {
                  $0.id == targetID && $0.isEnergyCube
              }),
              let recharge = inventoryItems[index].energyRecharge,
              recharge > 0 else {
            interactionStatus = "Equip an Energy Cube to recharge"
            return false
        }
        let before = organicEnergy
        organicEnergy = min(organicEnergyCapacity, organicEnergy + recharge)
        let gained = organicEnergy - before
        consumeInventoryItem(identifiedBy: targetID)
        persistInventory()
        interactionStatus =
            "Energy Cube used • +\(Int(gained.rounded())) "
            + "(\(Int(organicEnergy))/\(Int(organicEnergyCapacity)))"
        surfaceToolStatus = interactionStatus
        return true
    }

    private func burnShipFuel(dt: Float) {
        if unlimitedFuelAndEnergy { return }
        let mult = ProgressionEconomy.fuelCostMultiplier(
            difficulty: gameDifficulty
        )
        guard mult > 0, enginesRunning, !isOutsideShip, !isDocked, !isLanded else {
            return
        }
        var rate: Float = 0
        if isBoosting {
            rate = ProgressionEconomy.hyperFuelPerSecond
        } else if isAtmosphericBoostHeld || atmosphericBoostBlend > 0.05 {
            rate = ProgressionEconomy.boostFuelPerSecond
        } else if abs(speed) > 0.5 || throttle > 0.05 {
            rate = ProgressionEconomy.cruiseFuelPerSecond * Float(max(throttle, 0.15))
        }
        guard rate > 0 else { return }
        shipFuel = max(0, shipFuel - rate * mult * dt)
        if shipFuel <= 0.01 {
            if isBoosting || isHyperDriveCharging {
                cancelHyperDriveCharge()
                interactionStatus = "Fuel empty • hyperdrive offline"
            }
            // Limp both directions equally — an upper-only clamp used to leave
            // reverse uncapped, so backing away from a planet felt faster than
            // flying forward (and hyperdrive stays offline until refuel).
            if throttle > 0.25 {
                throttle = 0.18
            } else if throttle < -0.25 {
                throttle = -0.18
            }
            let limpSpeed = maximumForwardSpeed * 0.22
            speed = max(-limpSpeed, min(limpSpeed, speed))
        }
    }

    func applyModuleUnlock(_ moduleID: String, persist: Bool = true) {
        ownedModuleIDs.insert(moduleID)
        switch moduleID {
        case ProgressionEconomy.navModuleID:
            hasNavModule = true
        case "module.analyzer", "unlock.analyzer":
            unlockedSurfaceToolIndices.insert(SurfaceTool.analyzer.rawIndex)
        case "module.crumbler", "unlock.crumbler":
            unlockedSurfaceToolIndices.insert(
                SurfaceTool.matterCrumbler.rawIndex
            )
        case "module.slicer", "unlock.slicer":
            unlockedSurfaceToolIndices.insert(SurfaceTool.sonicSlicer.rawIndex)
        case "module.crumbler_efficiency":
            crumblerEfficiencyTier = min(2, crumblerEfficiencyTier + 1)
        case ProgressionEconomy.roverRefineryModuleID:
            break
        default:
            break
        }
        if persist {
            persistInventory()
            updateSelectedSurfaceToolVisual()
        }
    }

    @discardableResult
    func purchaseShopSKU(_ sku: ProgressionEconomy.ShopSKU) -> Bool {
        guard isStationShopAvailable else {
            interactionStatus = "Dock at a station to use the shop"
            return false
        }
        guard mon >= sku.priceMon else {
            interactionStatus =
                "Need \(ProgressionEconomy.formatMon(sku.priceMon))"
                + " (have \(ProgressionEconomy.formatMon(mon)))"
            return false
        }
        switch sku {
        case .navModule:
            guard !hasNavModule else {
                interactionStatus = "Nav Module already installed"
                return false
            }
            mon -= sku.priceMon
            applyModuleUnlock(ProgressionEconomy.navModuleID)
        case .unlockAnalyzer:
            guard !unlockedSurfaceToolIndices.contains(
                SurfaceTool.analyzer.rawIndex
            ) else {
                interactionStatus = "Analyzer already unlocked"
                return false
            }
            mon -= sku.priceMon
            applyModuleUnlock("module.analyzer")
        case .unlockCrumbler:
            guard !unlockedSurfaceToolIndices.contains(
                SurfaceTool.matterCrumbler.rawIndex
            ) else {
                interactionStatus = "Matter Crumbler already unlocked"
                return false
            }
            mon -= sku.priceMon
            applyModuleUnlock("module.crumbler")
        case .unlockSlicer:
            guard !unlockedSurfaceToolIndices.contains(
                SurfaceTool.sonicSlicer.rawIndex
            ) else {
                interactionStatus = "Sonic Slicer already unlocked"
                return false
            }
            mon -= sku.priceMon
            applyModuleUnlock("module.slicer")
        case .upgradeCrumblerEfficiency:
            guard crumblerEfficiencyTier < 2 else {
                interactionStatus = "Crumbler efficiency maxed"
                return false
            }
            mon -= sku.priceMon
            applyModuleUnlock("module.crumbler_efficiency")
        case .roverRefinery:
            guard !hasRoverRefinery else {
                interactionStatus = "Rover Refinery already installed"
                return false
            }
            mon -= sku.priceMon
            applyModuleUnlock(ProgressionEconomy.roverRefineryModuleID)
        }
        interactionStatus =
            "Purchased \(sku.title) for \(ProgressionEconomy.formatMon(sku.priceMon))"
        return true
    }

    @discardableResult
    func refineInventoryItem(_ itemID: String) -> Bool {
        guard isFabricatorAvailable,
              let index = inventoryItems.firstIndex(where: { $0.id == itemID })
        else {
            interactionStatus = "Fabricator unavailable"
            return false
        }
        let item = inventoryItems[index]
        let yields = ProgressionEconomy.refineYield(
            materialName: item.materialName,
            category: item.category
        )
        guard !yields.isEmpty else {
            interactionStatus = "Cannot refine \(item.displayName)"
            return false
        }
        consumeInventoryItem(identifiedBy: itemID)
        for yield in yields {
            addElementToInventory(name: yield.element, count: yield.count)
        }
        persistInventory()
        interactionStatus =
            "Refined \(item.displayName) → "
            + yields.map { "\($0.count)× \($0.element)" }.joined(separator: ", ")
        return true
    }

    var canConvertLogsToEnergy: Bool {
        isFabricatorAvailable
            && organicEnergy < organicEnergyCapacity - 0.5
            && categoryQuantity(.log) > 0
    }

    func inventoryElementCount(_ name: String) -> Int {
        elementQuantity(name)
    }

    func inventoryCategoryCount(_ category: SurfacePickup.Category) -> Int {
        categoryQuantity(category)
    }

    /// Whether every unlock gate and material cost for the recipe is met.
    func canCraftRecipe(_ recipeID: String) -> Bool {
        craftRecipeFailureReason(recipeID) == nil
    }

    func canCraftRecipe(
        _ recipe: ProgressionEconomy.CraftRecipe
    ) -> Bool {
        craftRecipeFailureReason(recipe) == nil
    }

    /// Per-ingredient sufficiency for refinery list styling.
    func recipeIngredientStatuses(
        _ recipe: ProgressionEconomy.CraftRecipe
    ) -> [(id: String, label: String, satisfied: Bool)] {
        var rows: [(id: String, label: String, satisfied: Bool)] = []
        for key in recipe.elements.keys.sorted() {
            let need = recipe.elements[key] ?? 0
            let have = elementQuantity(key)
            rows.append(
                (
                    id: "element-\(key)",
                    label: "\(need)× \(key)",
                    satisfied: have >= need
                )
            )
        }
        if recipe.logCost > 0 {
            rows.append(
                (
                    id: "logs",
                    label: "\(recipe.logCost)× logs",
                    satisfied: categoryQuantity(.log) >= recipe.logCost
                )
            )
        }
        if recipe.anyMineralCost > 0 {
            rows.append(
                (
                    id: "minerals",
                    label: "\(recipe.anyMineralCost)× any crystal",
                    satisfied: categoryQuantity(.mineral)
                        >= recipe.anyMineralCost
                )
            )
        }
        if recipe.combustibleMineralCost > 0 {
            rows.append(
                (
                    id: "combustibles",
                    label:
                        "\(recipe.combustibleMineralCost)× combustible mineral",
                    satisfied: combustibleMineralQuantity()
                        >= recipe.combustibleMineralCost
                )
            )
        }
        return rows
    }

    @discardableResult
    func craftRecipe(_ recipeID: String) -> Bool {
        guard isFabricatorAvailable,
              let recipe = ProgressionEconomy.craftRecipes.first(where: {
                  $0.id == recipeID
              }) else {
            interactionStatus = "Fabricator unavailable"
            return false
        }
        if let reason = craftRecipeFailureReason(recipe) {
            interactionStatus = reason
            return false
        }
        for (element, need) in recipe.elements {
            consumeElement(named: element, count: need)
        }
        if recipe.logCost > 0 {
            consumeCategory(.log, count: recipe.logCost)
        }
        if recipe.anyMineralCost > 0 {
            consumeCategory(.mineral, count: recipe.anyMineralCost)
        }
        if recipe.combustibleMineralCost > 0 {
            consumeCombustibleMinerals(count: recipe.combustibleMineralCost)
        }
        if let tool = recipe.unlocksTool {
            unlockedSurfaceToolIndices.insert(tool.rawIndex)
        }
        if let moduleID = recipe.grantsModuleID {
            applyModuleUnlock(moduleID, persist: false)
        }
        if let blueprintID = recipe.grantsBlueprintID {
            ownedBlueprintIDs.insert(blueprintID)
        }
        if let recharge = recipe.energyCubeRecharge {
            addEnergyCubeToInventory(recharge: recharge, title: recipe.title)
        }
        if let fuel = recipe.shipFuelAmount, fuel > 0 {
            let before = shipFuel
            shipFuel = min(ProgressionEconomy.maxShipFuel, shipFuel + fuel)
            let gained = shipFuel - before
            interactionStatus =
                "Fabricated \(recipe.title) • +\(Int(gained.rounded())) fuel "
                + "(\(Int(shipFuel))/\(Int(ProgressionEconomy.maxShipFuel)))"
            persistInventory()
            updateSelectedSurfaceToolVisual()
            closeRefineryPanel(clearStatus: false)
            return true
        }
        if let bonus = recipe.energyCapacityBonus, bonus > 0 {
            energyStorageExpansions = min(
                ProgressionEconomy.maxEnergyStorageExpansions,
                energyStorageExpansions + 1
            )
            interactionStatus =
                "Fabricated \(recipe.title) • capacity "
                + "\(Int(organicEnergyCapacity))"
            persistInventory()
            updateSelectedSurfaceToolVisual()
            closeRefineryPanel(clearStatus: false)
            return true
        }
        persistInventory()
        updateSelectedSurfaceToolVisual()
        interactionStatus = "Fabricated \(recipe.title)"
        closeRefineryPanel(clearStatus: false)
        return true
    }

    private func craftRecipeFailureReason(
        _ recipeID: String
    ) -> String? {
        guard let recipe = ProgressionEconomy.craftRecipes.first(where: {
            $0.id == recipeID
        }) else {
            return "Unknown recipe"
        }
        return craftRecipeFailureReason(recipe)
    }

    private func craftRecipeFailureReason(
        _ recipe: ProgressionEconomy.CraftRecipe
    ) -> String? {
        guard isFabricatorAvailable else {
            return "Fabricator unavailable"
        }
        if let blueprintID = recipe.blueprintID,
           !ownedBlueprintIDs.contains(blueprintID) {
            return "Missing blueprint for \(recipe.title)"
        }
        if let required = recipe.requiredStorageExpansions {
            guard energyStorageExpansions == required else {
                return required == 0
                    ? "Storage expansion already beyond tier I"
                    : "Craft prior Energy Storage upgrade first"
            }
            guard energyStorageExpansions
                < ProgressionEconomy.maxEnergyStorageExpansions else {
                return "Energy storage fully expanded"
            }
        }
        for (element, need) in recipe.elements {
            let have = elementQuantity(element)
            if have < need {
                return "Need \(need)× \(element) (have \(have))"
            }
        }
        if recipe.logCost > 0 {
            let have = categoryQuantity(.log)
            if have < recipe.logCost {
                return "Need \(recipe.logCost)× logs (have \(have))"
            }
        }
        if recipe.anyMineralCost > 0 {
            let have = categoryQuantity(.mineral)
            if have < recipe.anyMineralCost {
                return "Need \(recipe.anyMineralCost)× crystals/minerals"
                    + " (have \(have))"
            }
        }
        if recipe.combustibleMineralCost > 0 {
            let have = combustibleMineralQuantity()
            if have < recipe.combustibleMineralCost {
                return "Need \(recipe.combustibleMineralCost)× "
                    + "combustible mineral (have \(have))"
            }
        }
        if let fuel = recipe.shipFuelAmount, fuel > 0 {
            guard shipFuel < ProgressionEconomy.maxShipFuel - 0.5 else {
                return "Fuel tanks full"
            }
        }
        if let recharge = recipe.energyCubeRecharge {
            let canStack = inventoryItems.contains {
                $0.isEnergyCube
                    && abs(($0.energyRecharge ?? 0) - recharge) < 0.1
                    && $0.materialName == recipe.title
            }
            if !canStack && inventoryItems.count >= inventoryCapacity {
                return "Inventory full • cannot store Energy Cube"
            }
        }
        return nil
    }

    private func elementQuantity(_ name: String) -> Int {
        inventoryItems
            .filter {
                $0.category == .element
                    && ($0.processedElementName == name
                        || $0.materialName == name)
            }
            .reduce(0) { $0 + $1.quantity }
    }

    private func categoryQuantity(_ category: SurfacePickup.Category) -> Int {
        inventoryItems
            .filter { $0.category == category }
            .reduce(0) { $0 + $1.quantity }
    }

    private func combustibleMineralQuantity() -> Int {
        inventoryItems
            .filter {
                $0.category == .mineral
                    && ProgressionEconomy.isCombustibleMineral(
                        materialName: $0.materialName
                    )
            }
            .reduce(0) { $0 + $1.quantity }
    }

    private func consumeCombustibleMinerals(count: Int) {
        var remaining = count
        while remaining > 0,
              let index = inventoryItems.firstIndex(where: {
                  $0.category == .mineral
                      && $0.quantity > 0
                      && ProgressionEconomy.isCombustibleMineral(
                          materialName: $0.materialName
                      )
              }) {
            let take = min(remaining, inventoryItems[index].quantity)
            inventoryItems[index].quantity -= take
            remaining -= take
            if inventoryItems[index].quantity <= 0 {
                let removedID = inventoryItems[index].id
                inventoryItems.remove(at: index)
                if equippedInventoryItemID == removedID {
                    equippedInventoryItemID = nil
                }
            }
        }
        rebuildCollectedItemCounts()
    }

    private func consumeElement(named name: String, count: Int) {
        var remaining = count
        while remaining > 0,
              let index = inventoryItems.firstIndex(where: {
                  $0.category == .element
                      && ($0.processedElementName == name
                          || $0.materialName == name)
                      && $0.quantity > 0
              }) {
            let take = min(remaining, inventoryItems[index].quantity)
            inventoryItems[index].quantity -= take
            remaining -= take
            if inventoryItems[index].quantity <= 0 {
                inventoryItems.remove(at: index)
            }
        }
    }

    private func consumeCategory(
        _ category: SurfacePickup.Category,
        count: Int
    ) {
        var remaining = count
        while remaining > 0,
              let index = inventoryItems.firstIndex(where: {
                  $0.category == category && $0.quantity > 0
              }) {
            let take = min(remaining, inventoryItems[index].quantity)
            inventoryItems[index].quantity -= take
            remaining -= take
            if inventoryItems[index].quantity <= 0 {
                let removedID = inventoryItems[index].id
                inventoryItems.remove(at: index)
                if equippedInventoryItemID == removedID {
                    equippedInventoryItemID = nil
                }
            }
        }
        rebuildCollectedItemCounts()
    }

    private func addEnergyCubeToInventory(
        recharge: Float,
        title: String
    ) {
        let name = title
        if let index = inventoryItems.firstIndex(where: {
            $0.isEnergyCube
                && abs(($0.energyRecharge ?? 0) - recharge) < 0.1
                && $0.materialName == name
        }) {
            inventoryItems[index].quantity += 1
            return
        }
        guard inventoryItems.count < inventoryCapacity else {
            interactionStatus = "Inventory full • cannot store Energy Cube"
            return
        }
        inventoryItems.append(
            InventoryItem(
                id: "energy-cube-\(Int(recharge))-\(UUID().uuidString)",
                materialName: name,
                category: .electronic,
                sourcePlanetIdentifier: "",
                sourcePlanetName: "Fabricator",
                sourcePlanetKind: .rocky,
                quantity: 1,
                processedElementName: nil,
                energyRecharge: recharge
            )
        )
    }

    private func addElementToInventory(name: String, count: Int) {
        if let index = inventoryItems.firstIndex(where: {
            $0.category == .element
                && ($0.processedElementName == name || $0.materialName == name)
        }) {
            inventoryItems[index].quantity += count
            return
        }
        guard inventoryItems.count < inventoryCapacity else { return }
        inventoryItems.append(
            InventoryItem(
                id: "element-\(name)-\(UUID().uuidString)",
                materialName: name,
                category: .element,
                sourcePlanetIdentifier: "",
                sourcePlanetName: "Refinery",
                sourcePlanetKind: .rocky,
                quantity: count,
                processedElementName: name
            )
        )
    }

    @discardableResult
    func openEquippedRelic() -> Bool {
        guard let item = equippedInventoryItem, item.isRelic else {
            interactionStatus = "Equip a Relic to open it"
            return false
        }
        guard item.relicCanOpen == true else {
            interactionStatus = "Relic needs a fused Relic Key"
            return false
        }
        consumeInventoryItem(identifiedBy: item.id)
        // Open rewards: high-tier materials + chance at blueprint/module.
        addElementToInventory(name: "Titanium", count: 3)
        addElementToInventory(name: "Gold", count: 2)
        addElementToInventory(name: "Silicon", count: 2)
        let roll = Int.random(in: 0...99)
        if roll < 35 {
            ownedBlueprintIDs.insert(ProgressionEconomy.analyzerBlueprintID)
            interactionStatus = "Relic opened • Analyzer blueprint recovered"
        } else if roll < 60 {
            ownedBlueprintIDs.insert(ProgressionEconomy.crumblerBlueprintID)
            interactionStatus = "Relic opened • Crumbler blueprint recovered"
        } else if roll < 75 {
            applyModuleUnlock("module.slicer")
            interactionStatus = "Relic opened • Sonic Slicer module recovered"
        } else {
            mon += 80
            interactionStatus =
                "Relic opened • materials + \(ProgressionEconomy.formatMon(80))"
        }
        persistInventory()
        return true
    }

    func relicKeyCount() -> Int {
        inventoryItems
            .filter(\.isRelicKey)
            .reduce(0) { $0 + $1.quantity }
    }

    @discardableResult
    func consumeRelicKeyForPickup() -> Bool {
        guard let index = inventoryItems.firstIndex(where: {
            $0.isRelicKey && $0.quantity > 0
        }) else {
            return false
        }
        inventoryItems[index].quantity -= 1
        if inventoryItems[index].quantity <= 0 {
            let removed = inventoryItems[index].id
            inventoryItems.remove(at: index)
            if equippedInventoryItemID == removed {
                equippedInventoryItemID = nil
                updateHeldInventoryItemVisual()
            }
        }
        return true
    }

    func stop() {
        throttle = 0
        speed = 0
        isBoosting = false
        isAtmosphericBoostHeld = false
        cancelHyperDriveCharge()
    }

    func toggleShipShield() {
        guard !isOutsideShip, !isShipDestroyed else { return }
        isShipShieldActive.toggle()
        interactionStatus =
            isShipShieldActive ? "Ship shield active" : "Ship shield offline"
    }

    func applyShipProjectileDamage(_ amount: Float) {
        applyShipDamage(amount, reason: "hostile fire")
    }

    private func applyShipDamage(_ amount: Float, reason: String) {
        guard amount > 0, !isShipDestroyed else { return }
        setDamageFlashOpacity(max(simulationDamageFlashOpacity, 0.42))
        guard gameDifficulty != .creative else { return }
        var remaining = amount * damageIntakeMultiplier
        if isShipShieldActive && shipShield > 0 {
            let absorbed = min(shipShield, remaining)
            shipShield -= absorbed
            remaining -= absorbed
        }
        if remaining > 0 {
            shipHull = max(isOutsideShip ? 1 : 0, shipHull - remaining)
        }
        guard shipHull <= 0, !isOutsideShip else { return }
        isShipDestroyed = true
        cancelHyperDriveCharge()
        setWeaponTrigger(false)
        speed = 0
        throttle = 0
        environmentStatus = "SHIP DESTROYED"
        beginGameOver(
            title: "SHIP LOST",
            subtitle: "Recovering from the last takeoff point"
        )
        interactionStatus = "Ship destroyed by \(reason)"
    }

    private func applyCreatureAttacks() {
        let attacks =
            universeStreamer?.consumeCreatureAttacks()
                ?? (hits: 0, knockback: SIMD3<Float>.zero)
        guard attacks.hits > 0 else { return }
        setDamageFlashOpacity(max(simulationDamageFlashOpacity, 0.34))
        guard gameDifficulty != .creative else { return }
        if activeExplorationMode == "Deploy rover" {
            var damage = Float(attacks.hits) * damageIntakeMultiplier
            let shieldDamage = min(roverShield, damage)
            roverShield -= shieldDamage
            damage -= shieldDamage
            roverHull = max(0, roverHull - damage)
            if roverHull <= 0 {
                destroyRover()
            }
            return
        }

        playerHealth = max(
            0,
            playerHealth - Float(attacks.hits) * damageIntakeMultiplier
        )
        if simd_length_squared(attacks.knockback) > 0.0001 {
            pendingSurfaceKnockback +=
                simd_normalize(attacks.knockback)
                    * min(0.22, Float(attacks.hits) * 0.08)
        }
        if playerHealth <= 0 {
            beginGameOver(
                title: "EXPLORER DOWN",
                subtitle: walkingRecoveryUsesRover && hasRover
                    ? "Recovering at the rover"
                    : "Recovering at the ship"
            )
        }
    }

    private func destroyRover() {
        roverHull = 0
        roverShield = 0
        universeStreamer?.replaceRoverWithCollectibleScraps()
        hasRover = false
        isRoverDeployed = false
        activeExplorationMode = "Leave on foot"
        surfaceRoverPosition = nil
        walkingRecoveryUsesRover = false
        updateSurfaceNavigation()
        updateSurfaceVehicleMarkers()
        interactionStatus =
            "Rover disabled • collectible rover scraps recovered"
    }

    private func beginGameOver(title: String, subtitle: String) {
        guard gameOverTitle == nil else { return }
        gameOverTitle = title
        gameOverSubtitle = subtitle
        gameOverRemaining = 3.5
        explorationForwardInput = 0
        explorationTurnInput = 0
        walkingGestureActive = false
        speed = 0
        throttle = 0
    }

    private func updateGameOver(dt: Float) {
        guard gameOverTitle != nil else { return }
        gameOverRemaining -= dt
        guard gameOverRemaining <= 0 else { return }
        if isShipDestroyed {
            if let lastTakeoffPosition {
                playerPosition = lastTakeoffPosition
            }
            if let lastTakeoffAttitude {
                playerAttitude = lastTakeoffAttitude
            }
            isShipDestroyed = false
            shipHull = 1_000
            shipShield = 500
            isShipShieldActive = true
            isLanded = true
            isDocked = false
            automatedFlightPhase = .none
            activeExplorationMode = nil
            cockpitEntity?.isEnabled = true
        } else if walkingRecoveryUsesRover,
                  hasRover,
                  let roverPosition = surfaceRoverPosition {
            playerPosition = roverPosition
            activeExplorationMode = "Deploy rover"
            isRoverDeployed = true
        } else {
            forceRecoveryToShip()
        }
        playerHealth = 20
        pendingSurfaceKnockback = .zero
        setDamageFlashOpacity(0)
        gameOverTitle = nil
        gameOverSubtitle = ""
        applyCameraTransform()
        updateSurfaceVehicleMarkers()
        persistLocationCheckpoint()
    }

    private func forceRecoveryToShip() {
        stowHeldHandItem()
        if let shipPosition = landedShipPosition {
            playerPosition = shipPosition
        }
        if let shipAttitude = landedShipAttitude {
            playerAttitude = shipAttitude
        }
        activeExplorationMode = nil
        isRoverDeployed = false
        universeStreamer?.endSurfaceExploration()
        cockpitEntity?.isEnabled = true
        resetWalkingLocomotionBoosts()
        surfaceShipPosition = nil
        surfaceRoverPosition = nil
        landedShipPosition = nil
        landedShipAttitude = nil
    }

    func setLaserFiring(_ firing: Bool) {
        setWeaponTrigger(firing)
    }

    func setWeaponTrigger(_ pressed: Bool) {
        guard !pressed || !isAutomatedFlightManeuver else { return }
        guard !pressed || isWeaponArmed else {
            if isTriggerPressed {
                isTriggerPressed = false
                fireButtonEntity?.position.y = 0.324
                laserEntity?.isEnabled = false
                slowBeamEntity?.isEnabled = false
                isLaserFiring = false
                slowBeamTargetName = nil
                slowBeamEffectPercent = 0
            }
            return
        }
        guard pressed != isTriggerPressed else { return }
        isTriggerPressed = pressed
        fireButtonEntity?.position.y = pressed ? 0.316 : 0.324

        laserEntity?.isEnabled = pressed && currentWeaponType == .laser
        slowBeamEntity?.isEnabled = pressed && currentWeaponType == .slowBeam
        isLaserFiring =
            pressed
            && (currentWeaponType == .laser || currentWeaponType == .slowBeam)

        if pressed && currentWeaponType == .missile {
            fireMissile()
        }
        if !pressed {
            slowBeamTargetName = nil
            slowBeamEffectPercent = 0
        }
    }

    func configureCockpit(_ cockpit: Entity) {
        cockpitEntity = cockpit
        joystickControlEntity = cockpit.findEntity(named: "Joystick Control")
        joystickPivotEntity = cockpit.findEntity(named: "Joystick Pivot")
        throttleControlEntity = cockpit.findEntity(named: "Throttle Control")
        throttleHandleEntity = cockpit.findEntity(named: "Throttle Handle")
        fireButtonEntity = cockpit.findEntity(named: "Fire Button")
        turboButtonEntity = cockpit.findEntity(named: "Turbo Button")
        hyperSpeedEntity = cockpit.findEntity(named: "Hyper Speed Tunnel")
        trueForwardReferenceEntity =
            cockpit.findEntity(named: "True Forward Reference")
        joystickControlEntity?.isEnabled = false
        throttleControlEntity?.isEnabled = false
        updateCockpitVisuals(dt: 0)
    }

    func configureWeaponReticle(_ reticle: Entity) {
        weaponReticleEntity = reticle
        lastReticleWeaponIndex = nil
        updateWeaponReticleVisual()
    }

    func setWeaponReticleSuppressed(_ suppressed: Bool) {
        weaponReticleSuppressed = suppressed
        updateWeaponReticleVisual()
    }

    func configureAtmosphereEnvironment(_ environment: Entity) {
        atmosphereEnvironmentEntity = environment
        atmosphereSkyEntity =
            environment.findEntity(named: "Atmosphere Sky") as? ModelEntity
        atmosphereLightEntities = environment.children.compactMap {
            $0 as? DirectionalLight
        }
        disableAtmosphereEnvironment()
    }

    func clearAtmosphereEnvironment() {
        atmosphereEnvironmentEntity = nil
        atmosphereSkyEntity = nil
        atmosphereLightEntities = []
        lastAtmosphereVisualOpacity = -1
        lastAtmosphereVisualKind = nil
        lastSkyLimbElevation = 999
        lastSkyTextureKey = -1
    }

    func grabJoystick(at fistPosition: SIMD3<Float>) {
        joystickControlEntity?.isEnabled = true
        joystickControlEntity?.position = fistPosition + SIMD3<Float>(0, -0.23, 0)
    }

    func releaseJoystickVisual() {
        joystickControlEntity?.isEnabled = false
    }

    func grabThrottle(
        at fistPosition: SIMD3<Float>,
        secondaryHandIsLeft: Bool
    ) {
        throttleControlEntity?.isEnabled = true
        throttleControlEntity?.position = fistPosition + SIMD3<Float>(0, -0.14, 0)
        // A left support hand presses on its right side; a right support hand
        // presses on its left side.
        turboButtonSide = secondaryHandIsLeft ? 1 : -1
        positionTurboButton(pressed: isHyperDriveCharging || isBoosting)
    }

    func releaseThrottleVisual() {
        throttleControlEntity?.isEnabled = false
    }

    func updateHyperDriveCharge(remaining: Double) {
        guard enginesRunning else {
            cancelHyperDriveCharge()
            return
        }
        guard !isWithinPlanetAtmosphere else {
            cancelHyperDriveCharge()
            return
        }
        hyperDriveCountdown = max(0, remaining)
        isHyperDriveCharging = remaining > 0
        positionTurboButton(pressed: true)
    }

    func activateHyperDrive() {
        guard enginesRunning else {
            cancelHyperDriveCharge()
            return
        }
        guard !isWithinPlanetAtmosphere else {
            cancelHyperDriveCharge()
            return
        }
        hyperDriveCountdown = 0
        isHyperDriveCharging = false
        isBoosting = true
        positionTurboButton(pressed: true)
    }

    func setAtmosphericBoostHeld(_ held: Bool) {
        guard isWithinPlanetAtmosphere,
              !isDocked,
              !isLanded,
              !isAutomatedFlightManeuver else {
            isAtmosphericBoostHeld = false
            positionTurboButton(pressed: false)
            return
        }
        if held {
            isBoosting = false
            isHyperDriveCharging = false
            hyperDriveCountdown = 0
        }
        isAtmosphericBoostHeld = held
        positionTurboButton(pressed: held)
    }

    func cancelHyperDriveCharge() {
        hyperDriveCountdown = 0
        isHyperDriveCharging = false
        isBoosting = false
        isAtmosphericBoostHeld = false
        positionTurboButton(pressed: false)
    }

    private func positionTurboButton(pressed: Bool) {
        turboButtonEntity?.position = [
            turboButtonSide * (pressed ? 0.068 : 0.076),
            0.06,
            -0.005
        ]
    }

    func cycleWeapon() {
        guard canCycleWeapons else { return }
        setWeaponTrigger(false)
        // Cycle equipped weapons, then Disarmed, then back to the first weapon.
        let slotCount = equippedWeapons.count + 1
        currentWeaponIndex = (currentWeaponIndex + 1) % slotCount
        interactionStatus =
            isWeaponArmed
                ? "\(currentWeapon) armed"
                : "Weapons disarmed"
        lastReticleWeaponIndex = nil
        updateWeaponReticleVisual()
    }

    private func fireMissile() {
        guard !isMissileInFlight else {
            interactionStatus = "Missile already in flight"
            return
        }
        let target = aimedTarget(for: .missile)
        missileWillHit = target != nil
        missileTargetName = target?.name
        missileFlightRemaining = target.map {
            min(max($0.distance / 240, 0.45), 3)
        } ?? 1.2
        let launchPoint = weaponLaunchPoint(
            horizontalSide: nextMissileLaunchesFromLeft ? -1 : 1
        )
        nextMissileLaunchesFromLeft.toggle()
        let aimPoint = SIMD3<Float>(
            0,
            0,
            -weaponVisualRange(for: target)
        )
        missileVisualVelocity =
            (aimPoint - launchPoint) / missileFlightRemaining
        isMissileInFlight = true
        missileEntity?.position = launchPoint
        missileEntity?.orientation = simd_quatf(
            from: SIMD3<Float>(0, 0, -1),
            to: simd_normalize(missileVisualVelocity)
        )
        missileEntity?.isEnabled = true
        interactionStatus = target.map {
            "Missile locked: \($0.name)"
        } ?? "Missile fired — no target in reticle"
    }

    private func aimedTarget(for weapon: ShipWeapon) -> NearbyNavigationTarget? {
        let shipForward = weaponAimDirection
        let minimumAlignment = cos(weapon.aimHalfAngle)
        let target: NearbyNavigationTarget? = if let identifier = lockedTargetIdentifier {
            universeStreamer?.destination(
                identifiedBy: identifier,
                to: playerPosition
            )
        } else {
            universeStreamer?.nearestDestination(
                to: playerPosition,
                alignedWith: shipForward,
                minimumAlignment: minimumAlignment
            )
        }
        guard let target, target.distance > 0.001 else { return nil }
        let targetDirection = simd_normalize(target.vector)
        return simd_dot(shipForward, targetDirection) >= minimumAlignment
            ? target
            : nil
    }

    private func updateWeaponEffects(dt: Float) {
        if isTriggerPressed,
           currentWeaponType == .laser,
           !isOutsideShip,
           !isLanded {
            shipLaserDamageTimer -= dt
            if shipLaserDamageTimer <= 0 {
                let origin =
                    aimAnchorEntity?.position(relativeTo: nil) ?? .zero
                let aim = aimAnchorEntity?.convert(
                    direction: SIMD3<Float>(0, 0, -1),
                    to: nil
                ) ?? SIMD3<Float>(0, 0, -1)
                if let result = universeStreamer?.damageCreatureAlongRay(
                    from: origin,
                    direction: aim,
                    damage: 80
                ) {
                    interactionStatus = result
                    shipLaserDamageTimer = 0.4
                }
            }
        } else {
            shipLaserDamageTimer = 0
        }

        if isMissileInFlight {
            missileFlightRemaining -= dt
            missileEntity?.position += missileVisualVelocity * dt
            if missileFlightRemaining <= 0 {
                isMissileInFlight = false
                missileEntity?.isEnabled = false
                if missileWillHit, let missileTargetName {
                    interactionStatus = "Missile hit \(missileTargetName)"
                } else {
                    interactionStatus = "Missile missed"
                }
                missileTargetName = nil
                missileWillHit = false
            }
        }

        guard isTriggerPressed,
              currentWeaponType == .slowBeam,
              let target = aimedTarget(for: .slowBeam) else {
            if currentWeaponType == .slowBeam {
                slowBeamTargetName = nil
                slowBeamEffectPercent = 0
            }
            return
        }

        let exposure = min((slowExposureByTarget[target.identifier] ?? 0) + dt, 5)
        slowExposureByTarget[target.identifier] = exposure
        let strength = min(exposure * 0.18, 0.9)
        slowBeamTargetName = target.name
        slowBeamEffectPercent = Int((strength * 100).rounded())
        interactionStatus =
            "\(target.name) slowed \(slowBeamEffectPercent)%"
    }

    func detectNearest(_ kind: NavigationTargetKind) {
        guard let target = universeStreamer?.nearestDestination(
            to: playerPosition,
            matching: kind
        ) else {
            interactionStatus = "No \(kind.displayName.lowercased()) detected nearby"
            return
        }
        engageAutopilot(toward: target)
    }

    func detectNearestAirlessPlanet() {
        guard let target = universeStreamer?.nearestDestination(
            to: playerPosition,
            matching: .world,
            atmosphere: false
        ) else {
            interactionStatus = "No airless planet detected nearby"
            return
        }
        engageAutopilot(toward: target)
    }

    func cancelAutopilotTarget() {
        lockedTargetIdentifier = nil
        lockedTargetName = nil
        disengageAutopilot(keepTarget: false)
    }

    /// Console Auto-Pilot pad: open picker when no target; else toggle engage.
    func toggleAutopilotFromConsole() {
        if autopilot {
            disengageAutopilot(keepTarget: true)
            interactionStatus = "Auto-Pilot off • manual flight"
            return
        }
        guard hasAutopilotTarget,
              let identifier = lockedTargetIdentifier,
              let target = universeStreamer?.destination(
                identifiedBy: identifier,
                to: playerPosition
              ) else {
            return
        }
        engageAutopilot(toward: target)
    }

    func continueTowardContact(_ contact: TargetContact) {
        guard let target = universeStreamer?.destination(
            identifiedBy: contact.id,
            to: playerPosition
        ) else {
            interactionStatus = "\(contact.name) is no longer in sensor range"
            return
        }
        engageAutopilot(toward: target)
    }

    func changeTrajectory() {
        cancelAutopilotTarget()
        interactionStatus = "Autopilot released • Change trajectory manually"
    }

    func engageAutopilot(toward target: NearbyNavigationTarget) {
        lockedTargetIdentifier = target.identifier
        lockedTargetName = target.name
        autopilotFuelWarningRemaining = 0
        autopilotHyperChargeRemaining = 0
        autopilotArrivalFlashRemaining = 0
        autopilotPendingHyper = false
        autopilotConsoleFlashing = false

        let stopDistance = autopilotStopDistance(for: target)
        let travelDistance = max(0, target.distance - stopDistance)
        if travelDistance <= 2 {
            beginAutopilotArrivalFlash(message: "Arrived at \(target.name)")
            return
        }

        let requiredFuel = estimatedAutopilotFuel(
            travelDistance: travelDistance,
            useHyper: canAutopilotUseHyper(travelDistance: travelDistance)
        )
        let fuelMult = max(
            0.0001,
            ProgressionEconomy.fuelCostMultiplier(difficulty: gameDifficulty)
        )
        // Creative (0 cost) and the testing toggle always have enough fuel.
        let effectiveRequired =
            unlimitedFuelAndEnergy || fuelMult <= 0.0001 ? 0 : requiredFuel

        if shipFuel + 0.05 < effectiveRequired {
            autopilot = false
            interactionStatus =
                "Auto-Pilot cancelled • need \(Int(ceil(effectiveRequired))) fuel"
                    + " for this jump (have \(Int(shipFuel.rounded())))"
            return
        }

        autopilot = true
        pitchInput = 0
        yawInput = 0
        rollInput = 0

        let useHyper = canAutopilotUseHyper(travelDistance: travelDistance)
        if !useHyper {
            interactionStatus = "Auto-Pilot on • cruising to \(target.name)"
            return
        }

        if effectiveRequired > 0, shipFuel < effectiveRequired * 2 {
            autopilotFuelWarningRemaining = 3
            autopilotPendingHyper = true
            autopilotConsoleFlashing = true
            interactionStatus =
                "Low fuel for jump • recommend cancel • "
                    + "\(Int(shipFuel.rounded())) / "
                    + "\(Int(ceil(effectiveRequired * 2))) recommended"
            return
        }

        beginAutopilotHyperCharge()
        interactionStatus = "Auto-Pilot • hyperspace to \(target.name)"
    }

    private func disengageAutopilot(keepTarget: Bool) {
        autopilot = false
        autopilotFuelWarningRemaining = 0
        autopilotHyperChargeRemaining = 0
        autopilotArrivalFlashRemaining = 0
        autopilotPendingHyper = false
        autopilotConsoleFlashing = false
        if isBoosting || isHyperDriveCharging {
            cancelHyperDriveCharge()
        }
        if !keepTarget {
            lockedTargetIdentifier = nil
            lockedTargetName = nil
        }
    }

    private func beginAutopilotHyperCharge() {
        autopilotPendingHyper = false
        autopilotFuelWarningRemaining = 0
        autopilotHyperChargeRemaining = 3
        autopilotConsoleFlashing = false
        updateHyperDriveCharge(remaining: 3)
    }

    private func beginAutopilotArrivalFlash(message: String) {
        autopilot = false
        if isBoosting || isHyperDriveCharging {
            cancelHyperDriveCharge()
        }
        throttle = 0
        speed = min(speed, maximumForwardSpeed * 0.2)
        autopilotArrivalFlashRemaining = 1.2
        autopilotConsoleFlashing = true
        interactionStatus = message
    }

    private func canAutopilotUseHyper(travelDistance: Float) -> Bool {
        !isWithinPlanetAtmosphere
            && !isDocked
            && !isLanded
            && travelDistance > 2_500
    }

    private func autopilotStopDistance(
        for destination: NearbyNavigationTarget
    ) -> Float {
        switch destination.kind {
        case .station, .wreckage:
            return 200
        case .world:
            if destination.hasAtmosphere {
                return destination.radius
                    + UniverseScale.upperAtmosphereDepth(
                        for: destination.radius
                    )
            }
            return destination.radius + 200
        }
    }

    private func estimatedAutopilotFuel(
        travelDistance: Float,
        useHyper: Bool
    ) -> Float {
        let mult = ProgressionEconomy.fuelCostMultiplier(
            difficulty: gameDifficulty
        )
        guard mult > 0, travelDistance > 1 else { return 0 }
        if useHyper {
            let hyperSpeed = max(maximumForwardSpeed, 1) * boostMultiplier
            let hyperTime = travelDistance / hyperSpeed
            let approachCruise: Float = 8
            return (
                ProgressionEconomy.hyperFuelPerSecond * hyperTime
                    + ProgressionEconomy.cruiseFuelPerSecond * approachCruise
            ) * mult
        }
        let cruiseSpeed = maximumForwardSpeed * 0.85
        let cruiseTime = travelDistance / max(cruiseSpeed, 1)
        return ProgressionEconomy.cruiseFuelPerSecond * cruiseTime * mult
    }

    private func updateAutopilotAssist(dt: Float) {
        guard enginesRunning else { return }
        if autopilotArrivalFlashRemaining > 0 {
            autopilotArrivalFlashRemaining = max(
                0,
                autopilotArrivalFlashRemaining - Double(dt)
            )
            autopilotConsoleFlashing =
                Int(autopilotArrivalFlashRemaining * 5) % 2 == 0
                && autopilotArrivalFlashRemaining > 0
            if autopilotArrivalFlashRemaining <= 0 {
                autopilotConsoleFlashing = false
            }
        }

        guard autopilot else { return }

        if autopilotFuelWarningRemaining > 0 {
            autopilotFuelWarningRemaining = max(
                0,
                autopilotFuelWarningRemaining - Double(dt)
            )
            autopilotConsoleFlashing =
                Int(autopilotFuelWarningRemaining * 6) % 2 == 0
            if autopilotFuelWarningRemaining <= 0, autopilotPendingHyper {
                beginAutopilotHyperCharge()
                interactionStatus =
                    lockedTargetName.map { "Auto-Pilot • hyperspace to \($0)" }
                    ?? "Auto-Pilot • hyperspace"
            }
            return
        }

        if autopilotHyperChargeRemaining > 0 {
            autopilotHyperChargeRemaining = max(
                0,
                autopilotHyperChargeRemaining - Double(dt)
            )
            updateHyperDriveCharge(remaining: autopilotHyperChargeRemaining)
            if autopilotHyperChargeRemaining <= 0 {
                activateHyperDrive()
            }
            return
        }

        // Drive toward the destination; leave stick inputs cleared.
        pitchInput = 0
        yawInput = 0
        rollInput = 0
        if !isBoosting, !isHyperDriveCharging {
            throttle = max(throttle, 0.85)
        }
    }

    var isAutopilotMenuPresented: Bool {
        switch consolePage {
        case .autopilot, .autopilotPlanets, .autopilotStations, .autopilotDebris:
            true
        default:
            false
        }
    }

    func toggleFabricatorConsole() {
        if consolePage == .fabricator {
            consolePage = .standby
        } else {
            consolePage = .fabricator
        }
    }

    func toggleAutopilotConsole() {
        if isAutopilotMenuPresented || autopilot {
            if isAutopilotMenuPresented {
                consolePage = .standby
            }
            if autopilot {
                disengageAutopilot(keepTarget: true)
                interactionStatus = "Auto-Pilot off • manual flight"
            }
        } else {
            consolePage = .autopilot
        }
    }

    /// Engines on: flight control (and undock / takeoff when secured).
    /// Engines off in space: hold course and speed, no fuel, hyperdrive stops.
    func toggleShipEngines() {
        if consolePage != .engineStart && consolePage != .engineStop {
            consolePageBeforeEngine = consolePage
        }
        if enginesRunning {
            enginesRunning = false
            setWeaponTrigger(false)
            pitchInput = 0
            yawInput = 0
            rollInput = 0
            if isBoosting || isHyperDriveCharging {
                cancelHyperDriveCharge()
            }
            consolePage = .engineStop
            engineAnimRemaining = 1.6
            if !isLanded, !isDocked, let world = worldInLandingEnvelope() {
                beginPlanetaryLanding(on: world)
                return
            }
            interactionStatus = isDocked || isLanded
                ? "Engines offline"
                : "Engines offline • drifting on course"
            return
        }
        enginesRunning = true
        consolePage = .engineStart
        engineAnimRemaining = 1.6
        if isLanded {
            beginVerticalTakeoff()
            interactionStatus = "Engines online • taking off"
        } else if isDocked {
            isDocked = false
            securedLocationKind = nil
            securedLocationName = nil
            clearDockedStationTradeContext()
            if isTradeConcourseActive {
                activeExplorationMode = nil
                cockpitEntity?.isEnabled = true
            }
            interactionStatus = "Engines online • undocked"
        } else {
            interactionStatus = "Engines online"
        }
    }

    func knownConsoleDestinations(
        _ kind: NavigationTargetKind
    ) -> [NearbyNavigationTarget] {
        universeStreamer?.knownDestinations(
            kind: kind,
            near: playerPosition
        ) ?? []
    }

    func engageNearestPlanet(kind: CelestialBodyKind? = nil, airless: Bool = false) {
        guard let target = universeStreamer?.nearestDestination(
            to: playerPosition,
            matching: .world,
            atmosphere: airless ? false : nil,
            bodyKind: kind,
            excludingStars: true
        ) else {
            interactionStatus = "No matching planet in range"
            return
        }
        engageAutopilot(toward: target)
    }

    /// Lower atmosphere on a world with air, or the same distance above an
    /// airless surface. Airless worlds use the range to land, not to haze.
    private func worldInLandingEnvelope() -> NearbyNavigationTarget? {
        guard let target = universeStreamer?.nearestDestination(
            to: playerPosition,
            matching: .world
        ),
        target.kind == .world,
        target.celestialKind != .gas,
        target.celestialKind != .star else { return nil }
        let altitude = target.distance - target.radius
        guard altitude
            <= UniverseScale.lowerAtmosphereDepth(for: target.radius) else {
            return nil
        }
        return target
    }

    private func updateEngineAnimation(dt: Float) {
        guard engineAnimRemaining > 0 else { return }
        engineAnimRemaining = max(0, engineAnimRemaining - Double(dt))
        guard engineAnimRemaining == 0 else { return }
        if consolePage == .engineStart || consolePage == .engineStop {
            let saved = consolePageBeforeEngine
            consolePage =
                saved == .engineStart || saved == .engineStop
                    ? .standby
                    : saved
        }
    }

    func performLandingControl() {
        if isLanded {
            beginVerticalTakeoff()
            return
        }
        if isDocked {
            isDocked = false
            securedLocationKind = nil
            securedLocationName = nil
            clearDockedStationTradeContext()
            if isTradeConcourseActive {
                activeExplorationMode = nil
                cockpitEntity?.isEnabled = true
            }
            interactionStatus = "Undocked"
            return
        }

        guard let target = universeStreamer?.nearestDestination(to: playerPosition) else {
            interactionStatus = "No landing or docking target"
            return
        }
        guard abs(travelSpeed) <= maximumForwardSpeed * 0.5 else {
            interactionStatus = "Reduce to half speed before landing or docking"
            return
        }

        switch target.kind {
        case .station
            where target.distance
                <= UniverseScale.stationDockingDistance:
            secureShip(to: target, landed: false)
            interactionStatus = "Docked at \(target.name)"
        case .wreckage where target.distance <= 50:
            secureShip(to: target, landed: false)
            interactionStatus = "Secured to \(target.name)"
        case .world where target.celestialKind == .gas:
            interactionStatus = "Gas world — no surface to land on"
        case .world
            where target.celestialKind != .star
                && target.distance - target.radius
                    <= UniverseScale.lowerAtmosphereDepth(for: target.radius):
            beginPlanetaryLanding(on: target)
        case .world where target.hasAtmosphere:
            interactionStatus = "Enter the lower atmosphere before landing"
        case .world:
            interactionStatus = "Move closer to the surface before landing"
        default:
            interactionStatus = "Move closer to the docking target"
        }
    }

    private func beginPlanetaryLanding(on target: NearbyNavigationTarget) {
        if target.celestialKind == .gas {
            interactionStatus = "Gas world — no surface to land on"
            return
        }
        setWeaponTrigger(false)
        cancelAutopilotTarget()
        cancelHyperDriveCharge()
        throttle = 0
        speed = 0
        automatedTargetIdentifier = target.identifier
        automatedFlightPhase = .levelingForLanding
        landingLevelElapsed = 0
        interactionStatus = "Landing 1/3 • Leveling ship"
    }

    private func beginVerticalTakeoff() {
        lastTakeoffPosition = playerPosition
        lastTakeoffAttitude = playerAttitude
        guard let target = nearbyInteractionTarget,
              target.kind == .world,
              let world = universeStreamer?.destination(
                identifiedBy: target.identifier,
                to: playerPosition
              ) else {
            isLanded = false
            securedLocationKind = nil
            securedLocationName = nil
            surfaceShipPosition = nil
            updateSurfaceVehicleMarkers()
            interactionStatus = "Takeoff complete"
            return
        }

        setWeaponTrigger(false)
        cancelHyperDriveCharge()
        throttle = 0
        speed = 0
        activeExplorationMode = nil
        resetWalkingLocomotionBoosts()
        isLanded = false
        surfaceShipPosition = nil
        updateSurfaceVehicleMarkers()
        automatedTargetIdentifier = world.identifier
        let surfaceRadius =
            universeStreamer?.shipSurfaceRadius(for: world) ?? world.radius
        takeoffTargetDistance = max(world.distance, surfaceRadius) + 30.48
        automatedFlightPhase = .verticalTakeoff
        interactionStatus = "Takeoff • Vertical climb 100 ft"
    }

    func selectExitOption(_ option: String) {
        guard availableExitOptions.contains(option) else { return }
        if option == "Visit station shop" {
            inventoryVisible = false
            inventoryDismissedForCurrentGesture = true
            isRefineryPresented = false
            isStationShopPresented = true
            setWeaponReticleSuppressed(true)
            trueForwardReferenceEntity?.isEnabled = false
            interactionStatus =
                "Station shop • Mon \(ProgressionEconomy.formatMon(mon))"
            return
        }
        landedShipPosition = playerPosition
        landedShipAttitude = playerAttitude
        stowHeldHandItem()
        activeExplorationMode = option
        walkingRecoveryUsesRover = false
        cockpitEntity?.isEnabled = false
        synchronizeTrueForwardParent()
        trueForwardReferenceEntity?.isEnabled =
            option == "Deploy rover"
        interactionStatus = option
        if isSurfaceExploration {
            initializeExplorationHeading()
            let alreadyOnSurface =
                universeStreamer?.hasProximitySurface(
                    around: playerPosition
                ) ?? false
            if !alreadyOnSurface,
               let surfaceAdjustment =
                universeStreamer?.beginSurfaceExploration(
                    around: playerPosition
                ) {
                playerPosition.translate(
                    by: SIMD3<Double>(surfaceAdjustment)
                )
            }
            universeStreamer?.update(
                around: playerPosition.sector
            )
            surfaceShipPosition = playerPosition
            if let projected = universeStreamer?.reprojectOntoSurfaceShell(
                playerPosition
            ) {
                playerPosition = projected
            }
            universeStreamer?.updateSurfaceExploration(
                around: playerPosition,
                engagePlayer: true
            )
            moveAcrossSurface(
                by: explorationHeading
                    * (option == "Deploy rover" ? 8 : 5)
            )
            if option == "Deploy rover" {
                isRoverDeployed = true
                surfaceRoverPosition = playerPosition
            }
            updateSurfaceNavigation()
            updateSurfaceVehicleMarkers()
        }
        universeStreamer?.updateSurfaceDetailVisibility(
            around: playerPosition,
            showGroundDetail: true
        )
        persistLocationCheckpoint()
    }

    func returnToShip() {
        guard !isSurfaceExploration || canEnterShip else {
            interactionStatus =
                "Move within 15 m of the ship before entering"
            return
        }
        explorationForwardInput = 0
        explorationTurnInput = 0
        explorationTravelSpeed = 0
        walkingGestureActive = false
        stowHeldHandItem()
        setSurfaceToolMenuVisible(false)
        setHeldSurfaceToolVisible(false)
        if activeExplorationMode == "Deploy rover" {
            isRoverDeployed = false
            surfaceRoverPosition = nil
        }
        activeExplorationMode = nil
        resetWalkingLocomotionBoosts()
        if let shipPosition = landedShipPosition {
            playerPosition = shipPosition
        }
        if let shipAttitude = landedShipAttitude {
            playerAttitude = shipAttitude
        }
        landedShipPosition = nil
        landedShipAttitude = nil
        surfaceShipPosition = nil
        updateSurfaceVehicleMarkers()
        shipNavigationDistance = 0
        shipNavigationBearingDegrees = 0
        roverNavigationDistance = nil
        roverNavigationBearingDegrees = nil
        cockpitEntity?.isEnabled = true
        synchronizeTrueForwardParent()
        trueForwardReferenceEntity?.isEnabled = true
        interactionStatus = "Returned to ship"
        updateWeaponReticleVisual()
        applyCameraTransform()
        universeStreamer?.updateSurfaceDetailVisibility(
            around: playerPosition,
            showGroundDetail: false
        )
        persistLocationCheckpoint()
    }

    func setExplorationControls(forward: Double, turn: Double) {
        explorationForwardInput = max(-1, min(1, forward))
        explorationTurnInput = max(-1, min(1, turn))
    }

    func setWalkingGestureActive(_ active: Bool) {
        guard activeExplorationMode == "Leave on foot" else {
            walkingGestureActive = false
            isRunningGestureActive = false
            return
        }
        // Kit may stay open from gamepad latch while walking.
        walkingGestureActive = active
        if !walkingGestureActive {
            isRunningGestureActive = false
        }
    }

    func setRunningGestureActive(_ active: Bool) {
        guard activeExplorationMode == "Leave on foot",
              walkingGestureActive || explorationForwardInput > 0.12 else {
            isRunningGestureActive = false
            return
        }
        isRunningGestureActive = active
    }

    func setJetpackThrusting(_ active: Bool) {
        guard activeExplorationMode == "Leave on foot" else {
            isJetpackThrusting = false
            return
        }
        isJetpackThrusting = active
    }

    func setControllerRunHeld(_ held: Bool) {
        guard activeExplorationMode == "Leave on foot" else {
            controllerRunHeld = false
            return
        }
        controllerRunHeld = held
    }

    var isSurfaceKitVisible: Bool {
        inventoryVisible || surfaceToolMenuVisible
    }

    /// Recompute kit visibility from hand kit pose and/or gamepad latch.
    func refreshSurfaceKitVisibility() {
        setSurfaceKitVisible(handSurfaceKitActive || controllerSurfaceKitLatched)
    }

    func setHandSurfaceKitActive(_ active: Bool) {
        handSurfaceKitActive = active
        if active {
            // Palm takes priority; clear stale controller latch conflict by
            // keeping both OR'd in refreshSurfaceKitVisibility.
        }
        refreshSurfaceKitVisibility()
    }

    /// Hand / gamepad kit: inventory and (on foot) tool menu together.
    /// Does not interrupt walk, run, or jetpack.
    func setSurfaceKitVisible(_ visible: Bool) {
        // Settings owns pause; keep the inventory panel until the gear closes.
        if isSettingsMenuPresented && !visible {
            handSurfaceKitActive = false
            inventoryVisible = true
            surfaceToolMenuVisible = false
            surfaceToolMenuEntity?.isEnabled = false
            updateWeaponReticleVisual()
            return
        }

        let showInventory = visible && canPresentInventory
        let showTools =
            visible && activeExplorationMode == "Leave on foot"

        if !showInventory {
            inventoryVisible = false
            inventoryDismissedForCurrentGesture = false
        } else if !inventoryDismissedForCurrentGesture {
            inventoryVisible = true
        }

        surfaceToolMenuVisible = showTools
        surfaceToolMenuEntity?.isEnabled = showTools
        if showTools {
            surfaceToolStatus =
                "Kit open • index tap a tool • select inventory items"
            syncSurfaceToolMenuSelectionPress()
        }
        if !visible {
            handSurfaceKitActive = false
        }
        updateWeaponReticleVisual()
    }

    func toggleSurfaceKit() {
        // Don't dismiss via gamepad toggle while paused in settings.
        guard !isSettingsMenuPresented else { return }
        controllerSurfaceKitLatched.toggle()
        if !controllerSurfaceKitLatched {
            handSurfaceKitActive = false
        }
        refreshSurfaceKitVisibility()
    }

    func resetWalkingLocomotionBoosts() {
        isRunningGestureActive = false
        isJetpackThrusting = false
        controllerRunHeld = false
        surfaceStepHeight = 0
        surfaceJetpackAltitude = 0
        surfaceJetpackVelocity = 0
        surfaceJetpackFuel = Self.jetpackFuelCapacity
        displayedJetpackFuel = Self.jetpackFuelCapacity
    }

    func configureSurfaceTools(
        menu: Entity,
        heldTool: Entity,
        heldInventoryItem: Entity
    ) {
        surfaceToolMenuEntity = menu
        heldSurfaceToolEntity = heldTool
        heldInventoryItemEntity = heldInventoryItem
        menu.isEnabled = false
        heldTool.isEnabled = false
        heldInventoryItem.isEnabled = false
        updateSelectedSurfaceToolVisual()
        updateHeldInventoryItemVisual()
        syncSurfaceToolMenuSelectionPress()
    }

    func setInventoryVisible(_ visible: Bool) {
        // Inventory is part of the shared surface kit.
        if visible {
            inventoryDismissedForCurrentGesture = false
            setSurfaceKitVisible(true)
        } else if !surfaceToolMenuVisible {
            setSurfaceKitVisible(false)
        } else {
            inventoryVisible = false
            inventoryDismissedForCurrentGesture = false
        }
    }

    func setSurfaceToolMenuVisible(_ visible: Bool) {
        if visible {
            setSurfaceKitVisible(true)
        } else if !inventoryVisible {
            setSurfaceKitVisible(false)
        } else {
            surfaceToolMenuVisible = false
            surfaceToolMenuEntity?.isEnabled = false
        }
    }

    func updateSurfaceToolMenuPose(
        position: SIMD3<Float>,
        palmNormal: SIMD3<Float>
    ) {
        guard let menu = surfaceToolMenuEntity else { return }
        menu.position = position
        menu.orientation = simd_quatf(
            from: SIMD3<Float>(0, 0, 1),
            to: simd_normalize(palmNormal)
        )
    }

    func surfaceToolSlot(
        at worldPosition: SIMD3<Float>
    ) -> Int? {
        guard surfaceToolMenuVisible,
              let menu = surfaceToolMenuEntity else {
            return nil
        }
        let local = menu.convert(position: worldPosition, from: nil)
        guard abs(local.y) < 0.055, abs(local.z) < 0.065 else {
            return nil
        }
        let spacing: Float = 0.062
        let center = Float(SurfaceTool.allCases.count - 1) * 0.5
        let index = Int((local.x / spacing + center).rounded())
        guard SurfaceTool.allCases.indices.contains(index),
              abs(local.x - (Float(index) - center) * spacing) < 0.034 else {
            return nil
        }
        return index
    }

    func selectSurfaceTool(at index: Int) {
        guard SurfaceTool.allCases.indices.contains(index),
              unlockedSurfaceToolIndices.contains(index) else {
            return
        }
        stopMatterCrumblerBeam()
        equippedInventoryItemID = nil
        persistInventory()
        selectedSurfaceToolIndex = index
        updateSelectedSurfaceToolVisual()
        updateHeldInventoryItemVisual()
        syncSurfaceToolMenuSelectionPress()
        surfaceToolStatus =
            selectedSurfaceTool == .empty
                ? "Tool put away"
                : "\(selectedSurfaceTool.rawValue) equipped"
    }

    /// Keep the selected tool plate latched down until another tool is chosen.
    private func syncSurfaceToolMenuSelectionPress() {
        pressedSurfaceToolSlotIndex = selectedSurfaceToolIndex
        updateSurfaceToolMenuPressVisuals()
    }

    private func updateSurfaceToolMenuPressVisuals() {
        guard let menu = surfaceToolMenuEntity else { return }
        let pressDepth: Float = 0.008
        for child in menu.children where child.name.hasPrefix("Tool Slot ") {
            let suffix = child.name.dropFirst("Tool Slot ".count)
            guard let index = Int(suffix.prefix(while: \.isNumber)) else {
                continue
            }
            let pressed = index == pressedSurfaceToolSlotIndex
            let plateZ: Float = pressed ? -pressDepth : 0
            let glyphZ: Float = pressed ? 0.009 - pressDepth : 0.009
            if let plate = child.findEntity(named: "Tool Slot Plate") {
                plate.position.z = plateZ
            }
            if let glyph = child.findEntity(named: "Tool Slot Glyph") {
                glyph.position.z = glyphZ
            }
        }
    }

    func cycleSurfaceTool(by offset: Int) {
        let unlocked = unlockedSurfaceToolIndices.sorted()
        guard !unlocked.isEmpty else { return }
        guard let current = unlocked.firstIndex(
            of: selectedSurfaceToolIndex
        ) else {
            selectSurfaceTool(at: unlocked[0])
            return
        }
        let next = (current + offset + unlocked.count) % unlocked.count
        selectSurfaceTool(at: unlocked[next])
    }

    func updateHeldSurfaceToolPose(
        position: SIMD3<Float>,
        pointingDirection: SIMD3<Float>
    ) {
        guard let heldSurfaceToolEntity else { return }
        heldSurfaceToolEntity.position = position
        heldSurfaceToolEntity.orientation = simd_quatf(
            from: SIMD3<Float>(0, 0, -1),
            to: simd_normalize(pointingDirection)
        )
        heldSurfaceToolEntity.isEnabled =
            activeExplorationMode == "Leave on foot"
                && selectedSurfaceTool != .empty
    }

    /// Last time hand tracking posed the held inventory item (gamepad fallback
    /// only kicks in when this goes stale).
    @ObservationIgnored var lastHeldInventoryHandPoseTime: TimeInterval = 0

    func updateHeldInventoryItemPose(
        position: SIMD3<Float>,
        pointingDirection: SIMD3<Float>,
        palmNormal: SIMD3<Float> = SIMD3<Float>(0, 1, 0),
        fromHandTracking: Bool = false
    ) {
        guard let heldInventoryItemEntity else { return }
        let forward = simd_normalize(pointingDirection)
        heldInventoryItemEntity.position = position + forward * 0.08
        // Full grip basis: fingers = object −Z, palm-out = object +Y so
        // folding fingers / flipping palm rotates the held prop with the hand.
        heldInventoryItemEntity.orientation = handGripOrientation(
            pointingDirection: forward,
            palmNormal: palmNormal
        )
        heldInventoryItemEntity.isEnabled =
            equippedInventoryItemID != nil
        if fromHandTracking {
            lastHeldInventoryHandPoseTime =
                ProcessInfo.processInfo.systemUptime
        }
    }

    /// Maps hand axes onto held props (local −Z along fingers, +Y out of palm).
    private func handGripOrientation(
        pointingDirection: SIMD3<Float>,
        palmNormal: SIMD3<Float>
    ) -> simd_quatf {
        let forward = simd_normalize(pointingDirection)
        var upHint = palmNormal
        if simd_length_squared(upHint) < 0.000_1 {
            upHint = SIMD3<Float>(0, 1, 0)
        } else {
            upHint = simd_normalize(upHint)
        }
        var right = simd_cross(forward, upHint)
        if simd_length_squared(right) < 0.000_1 {
            right = simd_cross(forward, SIMD3<Float>(0, 1, 0))
            if simd_length_squared(right) < 0.000_1 {
                right = simd_cross(forward, SIMD3<Float>(1, 0, 0))
            }
        }
        right = simd_normalize(right)
        let up = simd_normalize(simd_cross(right, forward))
        let basis = simd_float3x3(columns: (right, up, -forward))
        return simd_normalize(simd_quatf(basis))
    }

    /// Unequip whatever is in the dominant hand. Used when boarding or leaving.
    private func stowHeldHandItem() {
        let holdingItem = equippedInventoryItemID != nil
        let holdingTool = selectedSurfaceTool != .empty
        guard holdingItem || holdingTool else { return }
        stopMatterCrumblerBeam()
        equippedInventoryItemID = nil
        persistInventory()
        selectedSurfaceToolIndex = SurfaceTool.empty.rawIndex
        updateSelectedSurfaceToolVisual()
        updateHeldInventoryItemVisual()
        heldInventoryItemEntity?.isEnabled = false
        heldSurfaceToolEntity?.isEnabled = false
        syncSurfaceToolMenuSelectionPress()
        surfaceToolStatus = holdingItem ? "Item put away" : "Tool put away"
    }

    func equipInventoryItem(_ item: InventoryItem) {
        guard inventoryItems.contains(where: { $0.id == item.id }) else {
            return
        }
        equippedInventoryItemID = item.id
        persistInventory()
        selectedSurfaceToolIndex = 0
        updateSelectedSurfaceToolVisual()
        updateHeldInventoryItemVisual()
        syncSurfaceToolMenuSelectionPress()
        // Keep the shared kit open so tools and inventory stay available.
        surfaceToolStatus =
            "\(item.displayName) equipped from \(item.sourcePlanetName)"
    }

    func activateEquippedInventoryItem() {
        guard let item = equippedInventoryItem else {
            surfaceToolStatus = "Activation • no item in dominant hand"
            return
        }
        if item.isEnergyCube {
            _ = useEnergyCube(itemID: item.id)
            return
        }
        surfaceToolStatus = "Activation • \(item.displayName) activated"
    }

    func beginEatingAttempt(_ item: InventoryItem) {
        guard equippedInventoryItemID == item.id else { return }
        surfaceToolStatus = "Eating \(item.displayName)…"
    }

    func cancelEatingAttempt() {
        guard equippedInventoryItem != nil else { return }
        surfaceToolStatus = "Eating cancelled"
    }

    func emitEatingFragments(from position: SIMD3<Float>) {
        guard let item = equippedInventoryItem,
              let sceneRoot = heldInventoryItemEntity?.parent else {
            return
        }
        let lowercasedName = item.materialName.lowercased()
        let color: UIColor
        if lowercasedName.hasSuffix(" meat") {
            color = UIColor(red: 0.58, green: 0.12, blue: 0.10, alpha: 1)
        } else if lowercasedName.hasSuffix(" feces") {
            color = UIColor(red: 0.28, green: 0.16, blue: 0.07, alpha: 1)
        } else {
            color = switch item.sourcePlanetKind {
            case .ocean: .systemTeal
            case .desert: .systemOrange
            case .rocky: .systemIndigo
            case .ice: .systemCyan
            case .gas: .systemPurple
            case .star: .systemYellow
            }
        }
        let phase = Float(
            ProcessInfo.processInfo.systemUptime
                .truncatingRemainder(dividingBy: 6.28)
        )
        for index in 0..<3 {
            let angle = phase + Float(index) * 2.094
            let fragment = ModelEntity(
                mesh: .generateSphere(
                    radius: 0.010 + Float(index) * 0.002
                ),
                materials: [
                    SimpleMaterial(
                        color: color,
                        roughness: 0.8,
                        isMetallic: false
                    )
                ]
            )
            fragment.name = "Eating Fragment"
            fragment.position = position
            sceneRoot.addChild(fragment)
            let direction = simd_normalize(
                SIMD3<Float>(
                    cos(angle) * 0.72,
                    0.38 + Float(index) * 0.12,
                    sin(angle) * 0.72
                )
            )
            surfaceProjectiles.append(
                SurfaceProjectileState(
                    entity: fragment,
                    direction: direction,
                    remainingLife: 0.55,
                    speed: 0.32
                )
            )
        }
    }

    func eatEquippedInventoryItem() {
        guard let item = equippedInventoryItem else { return }
        let lowercasedName = item.materialName.lowercased()
        consumeInventoryItem(identifiedBy: item.id)
        rebuildCollectedItemCounts()

        if lowercasedName.hasSuffix(" meat") {
            playerHealth = min(20, playerHealth + 5)
            surfaceToolStatus =
                "Ate \(item.displayName) • +5 health"
            return
        }
        if lowercasedName.hasSuffix(" feces") {
            setDamageFlashOpacity(max(simulationDamageFlashOpacity, 0.34))
            if gameDifficulty == .creative {
                surfaceToolStatus =
                    "Ate \(item.displayName) • damage feedback only"
                return
            }
            playerHealth = max(0, playerHealth - 5)
            surfaceToolStatus =
                "Ate \(item.displayName) • −5 health"
            if playerHealth <= 0 {
                beginGameOver(
                    title: "EXPLORER DOWN",
                    subtitle: walkingRecoveryUsesRover && hasRover
                        ? "Recovering at the rover"
                        : "Recovering at the ship"
                )
            }
            return
        }
        surfaceToolStatus =
            "Ate \(item.displayName) • no health effect"
    }

    func setHeldSurfaceToolVisible(_ visible: Bool) {
        heldSurfaceToolEntity?.isEnabled =
            visible
                && activeExplorationMode == "Leave on foot"
                && selectedSurfaceTool != .empty
    }

    func applySelectedSurfaceTool(
        atWorldPosition point: SIMD3<Float>,
        direction: SIMD3<Float>? = nil
    ) {
        guard activeExplorationMode == "Leave on foot" else { return }
        // Instant tools only. Matter crumbler is continuous and must go
        // through updateMatterCrumblerBeam with a per-tick damage amount.
        let tool = selectedSurfaceTool
        guard tool == .sonicSlicer || tool == .axe else { return }
        let energyCost: Float =
            tool == .axe
                ? ProgressionEconomy.axeEnergyCost
                : ProgressionEconomy.slicerEnergyCost
        guard spendOrganicEnergy(energyCost) else { return }
        if let material = universeStreamer?.applySurfaceTool(
            tool,
            atWorldPosition: point,
            direction: direction
        ) {
            surfaceToolStatus = material
        }
    }

    func updateMatterCrumblerBeam(
        from position: SIMD3<Float>,
        direction: SIMD3<Float>,
        deltaTime: Float
    ) {
        guard activeExplorationMode == "Leave on foot",
              selectedSurfaceTool == .matterCrumbler,
              let sceneRoot = heldSurfaceToolEntity?.parent else {
            stopMatterCrumblerBeam()
            return
        }
        let efficiency = 1 - 0.25 * Float(crumblerEfficiencyTier)
        let energyRate =
            ProgressionEconomy.crumblerEnergyPerSecond * max(0.5, efficiency)
        guard spendOrganicEnergy(energyRate * max(deltaTime, 1.0 / 60.0)) else {
            stopMatterCrumblerBeam()
            return
        }
        let aim = simd_normalize(direction)
        lastMatterCrumblerOrigin = position
        lastMatterCrumblerDirection = aim
        let beam: Entity
        if let existing = matterCrumblerBeamEntity {
            beam = existing
        } else {
            var material = UnlitMaterial(color: .cyan)
            material.blending = .transparent(opacity: .init(floatLiteral: 0.92))
            let created = ModelEntity(
                mesh: .generateCylinder(height: 12, radius: 0.045),
                materials: [material]
            )
            created.name = "Matter Crumbler Continuous Beam"
            let sortGroup = ModelSortGroup(depthPass: .postPass)
            created.components.set(
                ModelSortGroupComponent(group: sortGroup, order: 8_500)
            )
            created.components.set(OpacityComponent(opacity: 0.92))
            sceneRoot.addChild(created)
            matterCrumblerBeamEntity = created
            beam = created
        }
        let worldCenter = position + aim * 6
        beam.position = sceneRoot.convert(position: worldCenter, from: nil)
        let localAim = simd_normalize(
            sceneRoot.convert(direction: aim, from: nil)
        )
        beam.orientation = simd_quatf(
            from: SIMD3<Float>(0, 1, 0),
            to: localAim
        )
        beam.isEnabled = true
        matterCrumblerBeamTimeout = 0.18

        guard deltaTime > 0 else { return }
        // Slow continuous grind: 10 HP/s, hard-capped so a tracking hitch
        // cannot dump a burst of damage in one callback.
        let damagePerSecond: Float = 10
        let tickDamage =
            damagePerSecond * min(deltaTime, 1.0 / 30.0)
        if let result = universeStreamer?.applySurfaceTool(
            .matterCrumbler,
            atWorldPosition: position,
            direction: aim,
            damageAmount: tickDamage
        ) {
            surfaceToolStatus = result
        }
    }

    func stopMatterCrumblerBeam() {
        matterCrumblerBeamEntity?.removeFromParent()
        matterCrumblerBeamEntity = nil
        matterCrumblerBeamTimeout = 0
        matterCrumblerTrackingHold = false
    }

    func setMatterCrumblerTrackingHold(_ active: Bool) {
        matterCrumblerTrackingHold =
            active
                && selectedSurfaceTool == .matterCrumbler
                && matterCrumblerBeamEntity != nil
    }

    /// Head-aimed origin/direction for gamepad surface tools on foot.
    func controllerSurfaceAim() -> (
        origin: SIMD3<Float>,
        direction: SIMD3<Float>
    ) {
        let direction: SIMD3<Float>
        if hasWalkingFacingDirection {
            direction = simd_normalize(
                playerAttitude.act(walkingFacingDirection)
            )
        } else {
            direction = weaponAimDirection
        }
        let eye =
            aimAnchorEntity?.position(relativeTo: nil)
                ?? SIMD3<Float>.zero
        return (eye + direction * 0.28, direction)
    }

    /// Edge/hold tool use from a game controller while on foot.
    func updateControllerSurfaceTool(
        pressed: Bool,
        wasPressed: Bool,
        deltaTime: Float
    ) {
        guard activeExplorationMode == "Leave on foot" else {
            stopMatterCrumblerBeam()
            return
        }
        let aim = controllerSurfaceAim()
        switch selectedSurfaceTool {
        case .matterCrumbler:
            if pressed {
                updateMatterCrumblerBeam(
                    from: aim.origin,
                    direction: aim.direction,
                    deltaTime: deltaTime
                )
            } else if wasPressed {
                // Only a real RT release stops the beam. Idle pulses must
                // not cancel a hand-driven crumbler.
                stopMatterCrumblerBeam()
            }
        case .sonicSlicer, .axe:
            if pressed, !wasPressed {
                applySelectedSurfaceTool(
                    atWorldPosition: aim.origin,
                    direction: aim.direction
                )
            }
        case .matterLauncher:
            if pressed, !wasPressed {
                fireMatterLauncher(
                    from: aim.origin,
                    direction: aim.direction
                )
            }
        case .analyzer:
            if pressed, !wasPressed {
                showSurfaceToolActivation(
                    .analyzer,
                    from: aim.origin,
                    direction: aim.direction
                )
                analyzeSurfaceTarget(
                    from: aim.origin,
                    direction: aim.direction
                )
            }
        case .empty:
            if wasPressed {
                stopMatterCrumblerBeam()
            }
        }
    }

    func collectWithControllerGaze() {
        guard activeExplorationMode == "Leave on foot" else { return }
        let aim = controllerSurfaceAim()
        collectLookedAtSurfaceItem(
            from: aim.origin,
            direction: aim.direction
        )
    }

    func boardNearestSurfaceVehicle() {
        if canEnterShip {
            returnToShip()
        } else if canEnterRover {
            enterRover()
        } else if activeExplorationMode == "Deploy rover" {
            leaveRover()
        } else {
            interactionStatus =
                "Move within 15 m of the ship or rover"
        }
    }

    func analyzeSurfaceTarget(
        from position: SIMD3<Float>,
        direction: SIMD3<Float>
    ) {
        guard activeExplorationMode == "Leave on foot",
              selectedSurfaceTool == .analyzer else {
            return
        }
        guard spendOrganicEnergy(ProgressionEconomy.analyzerEnergyCost) else {
            return
        }
        surfaceToolStatus =
            universeStreamer?.analyzeSurfaceTarget(
                from: position,
                direction: direction
            ) ?? "Analyzer: no target in window"
    }

    func collectLooseSurfaceItem(
        atWorldPosition point: SIMD3<Float>
    ) {
        guard activeExplorationMode == "Leave on foot" else { return }
        guard let pickups = universeStreamer?.collectLooseSurfaceItems(
            atWorldPosition: point,
            maximumDistance: 1.275
        ) else {
            surfaceToolStatus = "No loose material between your hands"
            return
        }
        storePile(pickups)
    }

    func collectLookedAtSurfaceItem(
        from position: SIMD3<Float>,
        direction: SIMD3<Float>
    ) {
        guard activeExplorationMode == "Leave on foot" else { return }
        if let relicPickup = universeStreamer?.collectScannedRelic(
            from: position,
            direction: direction,
            maximumDistance: 15
        ) {
            guard consumeRelicKeyForPickup() else {
                surfaceToolStatus =
                    "Relic scanned • need a Relic Key to claim intact"
                return
            }
            var claimed = relicPickup
            claimed.relicCanOpen = true
            store(claimed)
            surfaceToolStatus =
                "Relic claimed • Relic Key fused"
            return
        }
        guard let pickups = universeStreamer?.collectLooseSurfaceItems(
            from: position,
            direction: direction,
            maximumDistance: 15
        ) else {
            surfaceToolStatus = "No loose material in view"
            return
        }
        storePile(pickups)
    }

    func fireMatterLauncher(
        from position: SIMD3<Float>,
        direction: SIMD3<Float>
    ) {
        guard activeExplorationMode == "Leave on foot",
              selectedSurfaceTool == .matterLauncher else {
            return
        }
        guard spendOrganicEnergy(ProgressionEconomy.launcherEnergyCost) else {
            return
        }
        guard let ammo = collectedMinerals
            .sorted(by: { $0.key < $1.key })
            .first(where: { $0.value > 0 }) else {
            surfaceToolStatus = "MATTER LAUNCHER ACTIVATED • EMPTY"
            return
        }
        if ammo.value == 1 {
            collectedMinerals.removeValue(forKey: ammo.key)
        } else {
            collectedMinerals[ammo.key] = ammo.value - 1
        }
        consumeInventoryItem(
            materialName: ammo.key,
            category: .mineral
        )
        guard let sceneRoot = heldSurfaceToolEntity?.parent else { return }
        let projectile = ModelEntity(
            mesh: .generateSphere(radius: 0.035),
            materials: [
                UnlitMaterial(color: UIColor.systemOrange)
            ]
        )
        projectile.name = "Matter Projectile • \(ammo.key)"
        projectile.position = position
        sceneRoot.addChild(projectile)
        surfaceProjectiles.append(
            SurfaceProjectileState(
                entity: projectile,
                direction: simd_normalize(direction),
                remainingLife: 2.5,
                damagesSecurityRobots: true
            )
        )
        surfaceToolStatus =
            "MATTER LAUNCHER ACTIVATED • FIRED \(ammo.key)"
                + " • \(matterLauncherAmmoCount) AMMO LEFT"
    }

    func showSurfaceToolActivation(
        _ tool: SurfaceTool,
        from position: SIMD3<Float>,
        direction: SIMD3<Float>
    ) {
        if tool == .analyzer {
            showAnalyzerRingStream(
                from: position,
                direction: direction
            )
            return
        }
        guard let sceneRoot = heldSurfaceToolEntity?.parent else { return }
        let color: UIColor = switch tool {
        case .matterCrumbler: .systemCyan
        case .analyzer: .systemGreen
        case .matterLauncher: .systemOrange
        case .sonicSlicer: .systemBlue
        case .axe: .systemBrown
        case .empty: .clear
        }
        let pulse = ModelEntity(
            mesh: .generateSphere(radius: 0.055),
            materials: [UnlitMaterial(color: color)]
        )
        pulse.name = "\(tool.rawValue) Activation Pulse"
        pulse.position = position
        sceneRoot.addChild(pulse)
        surfaceProjectiles.append(
            SurfaceProjectileState(
                entity: pulse,
                direction: simd_normalize(direction),
                remainingLife: 0.45
            )
        )
    }

    private func showAnalyzerRingStream(
        from position: SIMD3<Float>,
        direction: SIMD3<Float>
    ) {
        guard let sceneRoot = heldSurfaceToolEntity?.parent,
              let ringMesh = analyzerPulseRingMesh() else {
            return
        }
        let aim = simd_normalize(direction)
        Task { @MainActor [weak self, weak sceneRoot] in
            for index in 0..<14 {
                guard let self, let sceneRoot,
                      self.activeExplorationMode == "Leave on foot",
                      self.selectedSurfaceTool == .analyzer else {
                    return
                }
                let ring = ModelEntity(
                    mesh: ringMesh,
                    materials: [
                        UnlitMaterial(
                            color: UIColor.systemGreen
                                .withAlphaComponent(0.96)
                        )
                    ]
                )
                ring.name = "Analyzer Pulse Ring \(index + 1)"
                ring.position = position
                ring.orientation = simd_quatf(
                    from: SIMD3<Float>(0, 0, 1),
                    to: aim
                )
                ring.scale = SIMD3<Float>(repeating: 0.11)
                sceneRoot.addChild(ring)
                self.surfaceProjectiles.append(
                    SurfaceProjectileState(
                        entity: ring,
                        direction: aim,
                        remainingLife: 1,
                        speed: 10,
                        scaleGrowthPerSecond: 0.32
                    )
                )
                try? await Task.sleep(for: .milliseconds(55))
            }
        }
    }

    private func analyzerPulseRingMesh() -> MeshResource? {
        if let analyzerRingMesh {
            return analyzerRingMesh
        }
        let segmentCount = 48
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var indices: [UInt32] = []
        for segment in 0..<segmentCount {
            let angle =
                Float(segment) / Float(segmentCount) * 2 * Float.pi
            for radius: Float in [1, 0.82] {
                positions.append([
                    cos(angle) * radius,
                    sin(angle) * radius,
                    0
                ])
                normals.append([0, 0, 1])
            }
        }
        for segment in 0..<segmentCount {
            let next = (segment + 1) % segmentCount
            let outer = UInt32(segment * 2)
            let inner = outer + 1
            let nextOuter = UInt32(next * 2)
            let nextInner = nextOuter + 1
            indices.append(
                contentsOf: [
                    outer, nextOuter, inner,
                    nextOuter, nextInner, inner,
                    // Duplicate the annulus with reversed winding so the
                    // pulse is visible from both the tool and target sides.
                    inner, nextOuter, outer,
                    inner, nextInner, nextOuter
                ]
            )
        }
        var descriptor = MeshDescriptor(name: "Analyzer Pulse Ring")
        descriptor.positions = MeshBuffers.Positions(positions)
        descriptor.normals = MeshBuffers.Normals(normals)
        descriptor.primitives = .triangles(indices)
        analyzerRingMesh = try? MeshResource.generate(from: [descriptor])
        return analyzerRingMesh
    }

    private func updateSurfaceProjectiles(dt: Float) {
        var impactedProjectileIndices = Set<Int>()
        for index in surfaceProjectiles.indices {
            surfaceProjectiles[index].entity.position +=
                surfaceProjectiles[index].direction
                    * surfaceProjectiles[index].speed * dt
            if surfaceProjectiles[index].scaleGrowthPerSecond > 0 {
                surfaceProjectiles[index].entity.scale +=
                    SIMD3<Float>(
                        repeating:
                            surfaceProjectiles[index]
                                .scaleGrowthPerSecond * dt
                    )
            }
            surfaceProjectiles[index].remainingLife -= dt
            if surfaceProjectiles[index].damagesSecurityRobots,
               let result = universeStreamer?.hitSurfaceCombatTarget(
                    atWorldPosition:
                        surfaceProjectiles[index].entity.position(
                            relativeTo: nil
                        )
               ) {
                surfaceToolStatus = result
                impactedProjectileIndices.insert(index)
            }
        }
        for index in surfaceProjectiles.indices.reversed()
            where surfaceProjectiles[index].remainingLife <= 0
                || impactedProjectileIndices.contains(index) {
            surfaceProjectiles[index].entity.removeFromParent()
            surfaceProjectiles.remove(at: index)
        }
        if matterCrumblerBeamEntity != nil {
            if matterCrumblerTrackingHold {
                updateMatterCrumblerBeam(
                    from: lastMatterCrumblerOrigin,
                    direction: lastMatterCrumblerDirection,
                    deltaTime: dt
                )
            } else {
                matterCrumblerBeamTimeout -= dt
                if matterCrumblerBeamTimeout <= 0 {
                    stopMatterCrumblerBeam()
                }
            }
        }
    }

    private func clearSurfaceProjectiles() {
        for projectile in surfaceProjectiles {
            projectile.entity.removeFromParent()
        }
        surfaceProjectiles.removeAll()
        stopMatterCrumblerBeam()
    }

    private func updateSelectedSurfaceToolVisual() {
        guard let heldSurfaceToolEntity else { return }
        for (index, child) in heldSurfaceToolEntity.children.enumerated() {
            child.isEnabled = index == selectedSurfaceToolIndex
                && selectedSurfaceTool != .empty
        }
        heldSurfaceToolEntity.isEnabled =
            activeExplorationMode == "Leave on foot"
                && selectedSurfaceTool != .empty
    }

    private func storePile(_ pickups: [SurfacePickup]) {
        guard let first = pickups.first else { return }
        let startingCount = collectedSurfaceItems
        for pickup in pickups {
            store(pickup)
        }
        let collectedCount = collectedSurfaceItems - startingCount
        guard collectedCount > 0 else { return }
        let pileName: String = switch first.category {
        case .log: "logs"
        case .mineral: "minerals"
        case .electronic: "electronics"
        case .creatureMaterial: "creature materials"
        case .relic: "relics"
        case .relicKey: "relic keys"
        case .element: "elements"
        case .blueprint: "blueprints"
        case .module: "modules"
        }
        surfaceToolStatus =
            "Collected \(collectedCount) \(pileName)"
                + " • \(first.sourcePlanetName)"
    }

    private func store(_ pickup: SurfacePickup) {
        let itemID =
            "\(pickup.sourcePlanetIdentifier)|\(pickup.category)|"
            + pickup.materialName
        if let index = inventoryItems.firstIndex(
            where: { $0.id == itemID }
        ) {
            inventoryItems[index].quantity += 1
        } else {
            guard inventoryItems.count < inventoryCapacity else {
                surfaceToolStatus = "Inventory full • 100 / 100 slots"
                return
            }
            inventoryItems.append(
                InventoryItem(
                    id: itemID,
                    materialName: pickup.materialName,
                    category: pickup.category,
                    sourcePlanetIdentifier:
                        pickup.sourcePlanetIdentifier,
                    sourcePlanetName: pickup.sourcePlanetName,
                    sourcePlanetKind: pickup.sourcePlanetKind,
                    quantity: 1,
                    processedElementName:
                        pickup.category == .element
                            ? pickup.materialName
                            : nil,
                    relicCanOpen: pickup.relicCanOpen,
                    moduleID: pickup.moduleID,
                    blueprintID: pickup.blueprintID
                )
            )
        }
        if pickup.relicCanOpen,
           let index = inventoryItems.firstIndex(where: { $0.id == itemID }) {
            inventoryItems[index].relicCanOpen = true
        }
        switch pickup.category {
        case .log:
            collectedLogs[pickup.materialName, default: 0] += 1
        case .mineral:
            collectedMinerals[pickup.materialName, default: 0] += 1
        case .electronic, .creatureMaterial, .relic, .relicKey,
            .element, .blueprint, .module:
            break
        }
        collectedSurfaceItems += 1
        persistInventory()
        surfaceToolStatus =
            "Collected \(pickup.materialName) • \(pickup.sourcePlanetName)"
    }

    private func consumeInventoryItem(
        materialName: String,
        category: SurfacePickup.Category
    ) {
        guard let index = inventoryItems.firstIndex(
            where: {
                $0.materialName == materialName
                    && $0.category == category
            }
        ) else { return }
        consumeInventoryItem(identifiedBy: inventoryItems[index].id)
    }

    private func consumeInventoryItem(identifiedBy id: String) {
        guard let index = inventoryItems.firstIndex(
            where: { $0.id == id }
        ) else { return }
        if inventoryItems[index].quantity <= 1 {
            let removedID = inventoryItems[index].id
            inventoryItems.remove(at: index)
            if equippedInventoryItemID == removedID {
                equippedInventoryItemID = nil
                updateHeldInventoryItemVisual()
            }
        } else {
            inventoryItems[index].quantity -= 1
        }
        persistInventory()
    }

    private func persistLocationCheckpoint(
        defaults: UserDefaults = .standard
    ) {
        guard (isLanded || isDocked),
              let targetIdentifier = securedLocationIdentifier,
              let targetName = securedLocationName,
              let targetKind = securedLocationKind else {
            return
        }
        let checkpoint = LocationCheckpoint(
            targetIdentifier: targetIdentifier,
            targetName: targetName,
            targetKind: targetKind,
            isLanded: isLanded,
            playerPosition: SavedGalacticPosition(playerPosition),
            playerAttitude: SavedQuaternion(playerAttitude),
            activeExplorationMode: activeExplorationMode,
            landedShipPosition: landedShipPosition.map(
                SavedGalacticPosition.init
            ),
            landedShipAttitude: landedShipAttitude.map(
                SavedQuaternion.init
            ),
            surfaceShipPosition: surfaceShipPosition.map(
                SavedGalacticPosition.init
            ),
            surfaceRoverPosition: surfaceRoverPosition.map(
                SavedGalacticPosition.init
            ),
            explorationHeading: SavedVector3(explorationHeading),
            roverDeployed: isRoverDeployed,
            dominantHandName:
                dominantHandName == "LEFT"
                    || dominantHandName == "RIGHT"
                    ? dominantHandName
                    : nil,
            playerHealth: playerHealth,
            roverShield: roverShield,
            roverHull: roverHull,
            shipShield: shipShield,
            shipHull: shipHull,
            shipShieldActive: isShipShieldActive,
            hasRover: hasRover
        )
        guard let data = try? JSONEncoder().encode(checkpoint) else {
            return
        }
        savedLocationCheckpoint = checkpoint
        defaults.set(data, forKey: Self.locationStorageKey)
    }

    private func restoreSavedLocation() {
        guard let checkpoint = savedLocationCheckpoint else { return }

        let savedPlayerPosition = checkpoint.playerPosition.position
        playerPosition =
            checkpoint.landedShipPosition?.position
                ?? savedPlayerPosition
        playerAttitude = checkpoint.playerAttitude.quaternion
        isLanded = checkpoint.isLanded
        isDocked = !checkpoint.isLanded
        securedLocationIdentifier = checkpoint.targetIdentifier
        securedLocationKind = checkpoint.targetKind
        securedLocationName = checkpoint.targetName
        if !checkpoint.isLanded,
           checkpoint.targetKind == .station,
           let station = universeStreamer?.destination(
                identifiedBy: checkpoint.targetIdentifier,
                to: checkpoint.playerPosition.position
           ) {
            dockedStationHostPlanetName = station.hostPlanetName
            dockedStationHostPlanetKind = station.hostPlanetKind
            dockedStationSpecialty = station.specialtyFamily
            dockedStationSystemSector = station.systemSector
        } else {
            clearDockedStationTradeContext()
        }
        dominantHandName = checkpoint.dominantHandName ?? "—"
        playerHealth = checkpoint.playerHealth ?? 20
        roverShield = checkpoint.roverShield ?? 60
        roverHull = checkpoint.roverHull ?? 100
        shipShield = checkpoint.shipShield ?? 500
        shipHull = checkpoint.shipHull ?? 1_000
        isShipShieldActive = checkpoint.shipShieldActive ?? true
        hasRover = checkpoint.hasRover ?? true
        universeStreamer?.update(around: playerPosition.sector)

        nearbyInteractionTarget = universeStreamer?.destination(
            identifiedBy: checkpoint.targetIdentifier,
            to: playerPosition
        )

        activeExplorationMode = checkpoint.activeExplorationMode
        guard let activeExplorationMode else {
            interactionStatus =
                checkpoint.isLanded
                    ? "Resumed on \(checkpoint.targetName)"
                    : "Resumed at \(checkpoint.targetName)"
            return
        }

        cockpitEntity?.isEnabled = false
        synchronizeTrueForwardParent()
        trueForwardReferenceEntity?.isEnabled =
            activeExplorationMode == "Deploy rover"
        landedShipPosition =
            checkpoint.landedShipPosition?.position
                ?? playerPosition
        landedShipAttitude =
            checkpoint.landedShipAttitude?.quaternion
                ?? playerAttitude

        if activeExplorationMode == "Deploy rover"
            || activeExplorationMode == "Leave on foot" {
            if let surfaceAdjustment =
                universeStreamer?.beginSurfaceExploration(
                    around: landedShipPosition ?? playerPosition
                ) {
                playerPosition.translate(
                    by: SIMD3<Double>(surfaceAdjustment)
                )
            }
            surfaceShipPosition =
                checkpoint.surfaceShipPosition?.position
                    ?? playerPosition
            surfaceRoverPosition =
                checkpoint.surfaceRoverPosition?.position
            walkingRecoveryUsesRover =
                activeExplorationMode == "Leave on foot"
                    && surfaceRoverPosition != nil
            playerPosition = savedPlayerPosition
            // Old checkpoints may sit on a prior perspective-scale shell.
            // Snap player + vehicles onto the active exploration radius.
            reprojectSurfaceActorsOntoShell()
            explorationHeading =
                simd_length_squared(checkpoint.explorationHeading.vector)
                    > 0.001
                    ? simd_normalize(
                        checkpoint.explorationHeading.vector
                    )
                    : SIMD3<Float>(0, 0, -1)
            isRoverDeployed = checkpoint.roverDeployed && hasRover
            universeStreamer?.update(
                around: playerPosition.sector
            )
            universeStreamer?.updateSurfaceExploration(
                around: playerPosition
            )
            updateSurfaceNavigation()
            updateSurfaceVehicleMarkers()
        } else {
            playerPosition = savedPlayerPosition
        }

        universeStreamer?.updateSurfaceDetailVisibility(
            around: playerPosition,
            showGroundDetail: true
        )
        interactionStatus =
            "Resumed \(activeExplorationMode) at "
            + checkpoint.targetName
    }

    private func rebuildCollectedItemCounts() {
        collectedLogs = [:]
        collectedMinerals = [:]
        for item in inventoryItems {
            switch item.category {
            case .log:
                collectedLogs[item.materialName, default: 0] += item.quantity
            case .mineral:
                collectedMinerals[item.materialName, default: 0] += item.quantity
            case .electronic, .creatureMaterial, .relic, .relicKey,
                .element, .blueprint, .module:
                break
            }
        }
        collectedSurfaceItems = inventoryItems.reduce(0) {
            $0 + $1.quantity
        }
    }

    private func persistInventory(defaults: UserDefaults = .standard) {
        let snapshot = InventorySnapshot(
            items: inventoryItems,
            equippedItemID: equippedInventoryItemID,
            credits: credits,
            progression: makeProgressionSnapshot()
        )
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: Self.inventoryStorageKey)
        defaults.set(credits, forKey: Self.creditsStorageKey)
    }

    private func updateHeldInventoryItemVisual() {
        guard let heldInventoryItemEntity else { return }
        let item = equippedInventoryItem
        heldInventoryItemEntity.isEnabled = item != nil
        let isLog = item?.category == .log
        let isFeces =
            item?.materialName.lowercased().hasSuffix(" feces") == true
        let isCircuitBoard =
            item?.category == .electronic
            && item?.materialName
                .localizedCaseInsensitiveContains("circuit") == true
        heldInventoryItemEntity.findEntity(
            named: "Held Inventory Log"
        )?.isEnabled = isLog && !isFeces
        heldInventoryItemEntity.findEntity(
            named: "Held Inventory Circuit Board"
        )?.isEnabled = isCircuitBoard
        heldInventoryItemEntity.findEntity(
            named: "Held Inventory Mineral"
        )?.isEnabled =
            item != nil && !isLog && !isFeces && !isCircuitBoard
        heldInventoryItemEntity.findEntity(
            named: "Held Inventory Feces"
        )?.isEnabled = isFeces

        guard let item else { return }
        // Keep authored circuit-board materials intact.
        guard !isCircuitBoard else { return }

        let color: UIColor = switch item.category {
        case .electronic, .module, .blueprint:
            .systemGreen
        case .relic: .systemYellow
        case .relicKey: .systemPurple
        case .element: .systemMint
        case .log, .mineral, .creatureMaterial:
            switch item.sourcePlanetKind {
            case .ocean:
                item.category == .log ? .systemGreen : .systemTeal
            case .desert: .systemOrange
            case .rocky: .systemIndigo
            case .ice: .systemCyan
            case .gas: .systemPurple
            case .star: .systemYellow
            }
        }
        let isOrganic =
            item.category == .log || item.category == .creatureMaterial
        for child in heldInventoryItemEntity.children {
            guard child.name != "Held Inventory Circuit Board",
                  child.name != "Held Inventory Feces" else {
                continue
            }
            (child as? ModelEntity)?.model?.materials = [
                SimpleMaterial(
                    color: color,
                    roughness: isOrganic ? 0.72 : 0.24,
                    isMetallic: !isOrganic
                )
            ]
        }
    }

    func setWalkingFacingDirection(_ direction: SIMD3<Float>) {
        guard simd_length_squared(direction) > 0.001 else { return }
        walkingFacingDirection = simd_normalize(direction)
        hasWalkingFacingDirection = true
    }

    /// Seated pinch-drag: yaw the forward / compass heading and keep it.
    /// Positive radians turns facing to the right.
    func applySeatedViewYaw(_ radians: Float) {
        guard abs(radians) > 1e-6 else { return }

        if isSurfaceExploration,
           let world = universeStreamer?.nearestDestination(
            to: playerPosition,
            matching: .world
           ),
           world.distance > 0.001 {
            let surfaceUp = -simd_normalize(world.vector)
            let yaw = simd_quatf(angle: -radians, axis: surfaceUp)
            if activeExplorationMode == "Deploy rover" {
                explorationHeading = simd_normalize(
                    yaw.act(explorationHeading)
                )
                let right = simd_normalize(
                    simd_cross(explorationHeading, surfaceUp)
                )
                let basis = simd_float3x3(
                    columns: (right, surfaceUp, -explorationHeading)
                )
                playerAttitude = simd_normalize(simd_quatf(basis))
            } else {
                playerAttitude = simd_normalize(yaw * playerAttitude)
                explorationHeading = simd_normalize(
                    yaw.act(
                        explorationHeading
                            - surfaceUp
                                * simd_dot(explorationHeading, surfaceUp)
                    )
                )
            }
            explorationHeadingDegrees = atan2(
                simd_dot(explorationHeading, explorationEast),
                simd_dot(explorationHeading, explorationNorth)
            ) * 180 / .pi
            if explorationHeadingDegrees < 0 {
                explorationHeadingDegrees += 360
            }
            displayedExplorationHeadingDegrees = explorationHeadingDegrees
        } else {
            let up = simd_normalize(
                playerAttitude.act(SIMD3<Float>(0, 1, 0))
            )
            let yaw = simd_quatf(angle: -radians, axis: up)
            playerAttitude = simd_normalize(yaw * playerAttitude)
        }
        applyCameraTransform()
    }

    func leaveRover() {
        guard activeExplorationMode == "Deploy rover" else { return }
        explorationForwardInput = 0
        explorationTurnInput = 0
        explorationTravelSpeed = 0
        surfaceRoverPosition = playerPosition
        activeExplorationMode = "Leave on foot"
        walkingRecoveryUsesRover = true
        walkingGestureActive = false
        resetWalkingLocomotionBoosts()
        trueForwardReferenceEntity?.isEnabled = false
        // Enable the parked-rover collision at its saved position, then move
        // the player to the clearest side exit instead of leaving the player
        // centered on top of the rover.
        updateSurfaceVehicleMarkers()
        if let world = universeStreamer?.nearestDestination(
            to: playerPosition,
            matching: .world
        ), world.distance > 0.001 {
            let surfaceUp = -simd_normalize(world.vector)
            let exitRight = simd_normalize(
                simd_cross(explorationHeading, surfaceUp)
            )
            let exitDistance: Float = 2.15
            let candidates = [
                exitRight * exitDistance,
                -exitRight * exitDistance,
                -explorationHeading * exitDistance,
                explorationHeading * exitDistance
            ]
            let exitDelta = candidates.max {
                let left =
                    universeStreamer?.constrainSurfaceMovement(
                        around: playerPosition,
                        proposedDelta: $0,
                        playerRadius: 0.34
                    ).delta ?? $0
                let right =
                    universeStreamer?.constrainSurfaceMovement(
                        around: playerPosition,
                        proposedDelta: $1,
                        playerRadius: 0.34
                    ).delta ?? $1
                return simd_length_squared(left) < simd_length_squared(right)
            } ?? exitRight * exitDistance
            moveAcrossSurface(by: exitDelta)
        }
        updateSurfaceNavigation()
        updateSurfaceVehicleMarkers()
        applyCameraTransform()
        interactionStatus = "Exited rover"
        persistLocationCheckpoint()
    }

    func enterRover() {
        guard canEnterRover, let roverPosition = surfaceRoverPosition else {
            interactionStatus =
                "Move within 15 m of the rover before entering"
            return
        }
        walkingGestureActive = false
        explorationForwardInput = 0
        explorationTurnInput = 0
        explorationTravelSpeed = 0
        playerPosition =
            universeStreamer?.reprojectOntoSurfaceShell(roverPosition)
            ?? roverPosition
        surfaceRoverPosition = playerPosition
        activeExplorationMode = "Deploy rover"
        synchronizeTrueForwardParent()
        trueForwardReferenceEntity?.isEnabled = true
        initializeExplorationHeading()
        updateSurfaceNavigation()
        updateSurfaceVehicleMarkers()
        applyCameraTransform()
        interactionStatus = "Entered rover"
        persistLocationCheckpoint()
    }

    private func secureShip(to target: NearbyNavigationTarget, landed: Bool) {
        setWeaponTrigger(false)
        stop()
        cancelAutopilotTarget()
        isLanded = landed
        isDocked = !landed
        if landed {
            enginesRunning = false
            // The cockpit is the ship. The exterior hull appears only after exit.
            surfaceShipPosition = nil
            updateSurfaceVehicleMarkers()
        }
        securedLocationIdentifier = target.identifier
        securedLocationKind = target.kind
        securedLocationName = target.name
        nearbyInteractionTarget = target
        if !landed, target.kind == .station {
            dockedStationHostPlanetName = target.hostPlanetName
            dockedStationHostPlanetKind = target.hostPlanetKind
            dockedStationSpecialty = target.specialtyFamily
            dockedStationSystemSector = target.systemSector
        } else {
            clearDockedStationTradeContext()
        }
        persistLocationCheckpoint()
    }

    private func clearDockedStationTradeContext() {
        dockedStationHostPlanetName = nil
        dockedStationHostPlanetKind = nil
        dockedStationSpecialty = nil
        dockedStationSystemSector = nil
    }

    var dockedStationSpecialtyLabel: String {
        guard isDocked, securedLocationKind == .station else {
            return ""
        }
        let family =
            dockedStationSpecialty?.displayName
            ?? "General cargo"
        let host = dockedStationHostPlanetName ?? "unknown world"
        return "Specialty: \(family) • Host: \(host)"
    }

    var stationTradeOffers: [StationTradeOffer] {
        guard isDocked, securedLocationKind == .station else { return [] }
        return inventoryItems.map { item in
            let origin = StationTradePricing.buyOrigin(
                itemSourcePlanetIdentifier: item.sourcePlanetIdentifier,
                itemSourcePlanetName: item.sourcePlanetName,
                hostPlanetIdentifier: nil,
                hostPlanetName: dockedStationHostPlanetName,
                stationSystemSector: dockedStationSystemSector,
                itemSystemSector: Self.systemSector(
                    fromBodyIdentifier: item.sourcePlanetIdentifier
                )
            )
            let unitPrice = StationTradePricing.unitBuyPrice(
                category: item.category,
                origin: origin
            )
            return StationTradeOffer(
                id: item.id,
                item: item,
                origin: origin,
                unitPrice: unitPrice
            )
        }
        .sorted {
            if $0.origin.label != $1.origin.label {
                return $0.origin.label < $1.origin.label
            }
            return $0.item.displayName < $1.item.displayName
        }
    }

    @discardableResult
    func sellInventoryItem(_ itemID: String, quantity: Int = 1) -> Bool {
        guard isDocked,
              securedLocationKind == .station,
              isTradeConcourseActive,
              quantity > 0,
              let index = inventoryItems.firstIndex(where: { $0.id == itemID })
        else {
            interactionStatus = "Open the trade concourse while docked to sell"
            return false
        }
        let item = inventoryItems[index]
        let sellCount = min(quantity, item.quantity)
        guard sellCount > 0 else { return false }
        let origin = StationTradePricing.buyOrigin(
            itemSourcePlanetIdentifier: item.sourcePlanetIdentifier,
            itemSourcePlanetName: item.sourcePlanetName,
            hostPlanetIdentifier: nil,
            hostPlanetName: dockedStationHostPlanetName,
            stationSystemSector: dockedStationSystemSector,
            itemSystemSector: Self.systemSector(
                fromBodyIdentifier: item.sourcePlanetIdentifier
            )
        )
        let unitPrice = StationTradePricing.unitBuyPrice(
            category: item.category,
            origin: origin
        )
        let payout = unitPrice * sellCount
        credits += payout
        if item.quantity <= sellCount {
            let removedID = inventoryItems[index].id
            inventoryItems.remove(at: index)
            if equippedInventoryItemID == removedID {
                equippedInventoryItemID = nil
                updateHeldInventoryItemVisual()
            }
        } else {
            inventoryItems[index].quantity -= sellCount
        }
        rebuildCollectedItemCounts()
        persistInventory()
        interactionStatus =
            "Sold \(sellCount)× \(item.displayName) for "
            + ProgressionEconomy.formatMon(payout)
            + " (\(origin.label))"
        return true
    }

    func sellAllTradeInventory() {
        guard isDocked,
              securedLocationKind == .station,
              isTradeConcourseActive else {
            interactionStatus = "Open the trade concourse while docked to sell"
            return
        }
        let offers = stationTradeOffers
        guard !offers.isEmpty else {
            interactionStatus = "No cargo to sell"
            return
        }
        var total = 0
        for offer in offers {
            let payout = offer.totalPrice
            credits += payout
            total += payout
            inventoryItems.removeAll { $0.id == offer.id }
        }
        if let equipped = equippedInventoryItemID,
           !inventoryItems.contains(where: { $0.id == equipped }) {
            equippedInventoryItemID = nil
            updateHeldInventoryItemVisual()
        }
        rebuildCollectedItemCounts()
        persistInventory()
        interactionStatus =
            "Sold all cargo for \(ProgressionEconomy.formatMon(total))"
    }

    private static func systemSector(
        fromBodyIdentifier identifier: String
    ) -> GalacticSector? {
        let head = identifier.split(separator: ":", maxSplits: 1).first
        guard let head else { return nil }
        let parts = head.split(separator: ",")
        guard parts.count == 3,
              let x = Int64(parts[0]),
              let y = Int64(parts[1]),
              let z = Int64(parts[2]) else {
            return nil
        }
        return GalacticSector(x: x, y: y, z: z)
    }

    func performContextAction() {
        if isLanded {
            beginVerticalTakeoff()
            contextActionTitle = nil
            contextActionEnabled = false
            return
        }
        if isDocked {
            isDocked = false
            securedLocationKind = nil
            securedLocationName = nil
            clearDockedStationTradeContext()
            if isTradeConcourseActive {
                activeExplorationMode = nil
                cockpitEntity?.isEnabled = true
            }
            interactionStatus = "Undocked"
            contextActionTitle = nil
            contextActionEnabled = false
            updateTelemetry()
            return
        }

        guard contextActionEnabled, let target = nearbyInteractionTarget else { return }
        switch target.kind {
        case .station:
            secureShip(to: target, landed: false)
            interactionStatus = "Docked at \(target.name)"
            contextActionTitle = "UNDOCK"
            contextActionEnabled = true
        case .wreckage:
            universeStreamer?.investigateWreckage(target.identifier)
            // Debris salvage: chance at a progression module/blueprint.
            let salvage = Int.random(in: 0...99)
            if salvage < 25 {
                ownedBlueprintIDs.insert(
                    ProgressionEconomy.analyzerBlueprintID
                )
                interactionStatus =
                    "Examined \(target.name) • Analyzer blueprint"
            } else if salvage < 45 {
                applyModuleUnlock("module.slicer")
                interactionStatus =
                    "Examined \(target.name) • Sonic Slicer module"
            } else if salvage < 55 {
                applyModuleUnlock("module.crumbler")
                interactionStatus =
                    "Examined \(target.name) • Matter Crumbler module"
            } else {
                interactionStatus = "Examined \(target.name)"
            }
            contextActionTitle = "EXAMINED"
            contextActionEnabled = false
            investigatedWreckageCount =
                universeStreamer?.investigatedWreckageCount ?? 0
            persistInventory()
        case .world:
            break
        }
    }

    func setHandTrackingStatus(_ status: String) {
        guard handTrackingStatus != status else { return }
        handTrackingStatus = status
    }

    func setDominantHandActive(_ active: Bool) {
        guard dominantHandActive != active else { return }
        dominantHandActive = active
    }

    func setSupportHandActive(_ active: Bool) {
        guard supportHandActive != active else { return }
        supportHandActive = active
    }

    func setInteractionStatus(_ status: String) {
        guard interactionStatus != status else { return }
        interactionStatus = status
    }

    private func setDamageFlashOpacity(_ value: Double) {
        simulationDamageFlashOpacity = value
        let quantized = (value * 20).rounded() / 20
        if abs(damageFlashOpacity - quantized) >= 0.001 {
            damageFlashOpacity = quantized
        }
    }

    private func applyCrustCarry(dt: Float) {
        guard let motion = universeStreamer?.updateCelestialMotion(
            around: playerPosition,
            deltaTime: dt
        ) else { return }
        playerPosition = motion.carried(playerPosition)
        playerAttitude = simd_normalize(motion.rotation * playerAttitude)
        if let ship = landedShipPosition {
            landedShipPosition = motion.carried(ship)
        }
        if let attitude = landedShipAttitude {
            landedShipAttitude = simd_normalize(motion.rotation * attitude)
        }
        if let ship = surfaceShipPosition {
            surfaceShipPosition = motion.carried(ship)
        }
        if let rover = surfaceRoverPosition {
            surfaceRoverPosition = motion.carried(rover)
        }
        if isSurfaceExploration {
            explorationHeading = simd_normalize(
                motion.rotation.act(explorationHeading)
            )
            explorationNorth = simd_normalize(
                motion.rotation.act(explorationNorth)
            )
            explorationEast = simd_normalize(
                motion.rotation.act(explorationEast)
            )
        }
        // The spin multiply is exact only while attitude stays a pure
        // rotation. After many day and night turns a small pitch error
        // stacks up, so a grounded view is rebuilt level to the ground
        // with the current heading kept.
        if isLanded || isSurfaceExploration {
            levelGroundedHorizon()
        }
        // Landed and docked frames return before the flight loop refreshes
        // the camera. Without this, the crust turns in the view while the
        // cockpit stays on the previous spot.
        applyCameraTransform()
    }

    /// Keeps a landed or on-foot view level with the ground underfoot.
    private func levelGroundedHorizon() {
        guard let world = universeStreamer?.nearestDestination(
            to: playerPosition,
            matching: .world
        ), world.distance > 0.001 else { return }
        let up = simd_normalize(-world.vector)
        playerAttitude = attitude(playerAttitude, levelTo: up)
        if isLanded, let ship = landedShipAttitude {
            landedShipAttitude = attitude(ship, levelTo: up)
        }
        guard isSurfaceExploration else { return }
        explorationHeading = flattened(explorationHeading, up: up)
        explorationNorth = flattened(explorationNorth, up: up)
        let east = simd_cross(up, explorationNorth)
        guard simd_length_squared(east) > 1e-8 else { return }
        explorationEast = simd_normalize(east)
        explorationNorth = simd_normalize(
            simd_cross(explorationEast, up)
        )
    }

    private func attitude(
        _ attitude: simd_quatf,
        levelTo up: SIMD3<Float>
    ) -> simd_quatf {
        var forward = attitude.act(SIMD3<Float>(0, 0, -1))
        forward -= up * simd_dot(forward, up)
        guard simd_length_squared(forward) > 1e-8 else { return attitude }
        forward = simd_normalize(forward)
        let right = simd_normalize(simd_cross(forward, up))
        let basis = simd_float3x3(columns: (right, up, -forward))
        return simd_normalize(simd_quatf(basis))
    }

    private func flattened(
        _ direction: SIMD3<Float>,
        up: SIMD3<Float>
    ) -> SIMD3<Float> {
        let tangent = direction - up * simd_dot(direction, up)
        guard simd_length_squared(tangent) > 1e-8 else { return direction }
        return simd_normalize(tangent)
    }

    private func daylightFactor() -> Float {
        let elevation =
            universeStreamer?.sunElevation(around: playerPosition) ?? 1
        return max(0, min(1, (elevation + 0.08) / 0.35))
    }

    func tick(deltaTime externalDelta: Float? = nil) {
        onFrameExtras?()
        let dt: Float
        if let externalDelta {
            dt = min(max(externalDelta, 0), 0.05)
            lastTick = .now
        } else {
            let now = ContinuousClock.now
            let duration = lastTick.duration(to: now)
            lastTick = now
            dt = min(
                Float(duration.components.seconds)
                    + Float(duration.components.attoseconds) / 1e18,
                0.05
            )
        }
        guard dt > 0 else { return }
        setDamageFlashOpacity(
            max(0, simulationDamageFlashOpacity - Double(dt) * 1.7)
        )
        let boostActive = atmosphericBoostBlend > 0.01
        if isAtmosphericBoostActive != boostActive {
            isAtmosphericBoostActive = boostActive
        }
        if gameOverTitle != nil {
            updateGameOver(dt: dt)
            return
        }
        // Single-player pause: settings gear is the only pause entry.
        if isPaused {
            updateCockpitVisuals(dt: dt)
            updateRelicKeyLocator()
            return
        }
        applyCrustCarry(dt: dt)
        updateCockpitVisuals(dt: dt)
        updateEngineAnimation(dt: dt)
        updateAutopilotAssist(dt: dt)
        burnShipFuel(dt: dt)
        updateWeaponEffects(dt: dt)
        updateSurfaceProjectiles(dt: dt)
        updateRelicKeyLocator()
        updateFlightEnvironment(dt: dt)
        if isWithinPlanetAtmosphere
            && (isBoosting || isHyperDriveCharging) {
            cancelHyperDriveCharge()
            autopilotHyperChargeRemaining = 0
        }
        updateAtmosphericBoost(dt: dt)

        if isShipDestroyed {
            speed = 0
            throttle = 0
            return
        }

        if isAutomatedFlightManeuver {
            updateAutomatedFlight(dt: dt)
            return
        }

        if isSurfaceExploration {
            updateSurfaceExploration(dt: dt)
            return
        }

        if isDocked || isLanded {
            speed = 0
            throttle = 0
            cancelHyperDriveCharge()
            telemetryAccumulator += TimeInterval(dt)
            if telemetryAccumulator > 0.12 {
                telemetryAccumulator = 0
                updateTelemetry()
            }
            return
        }

        let targetSpeed = Float(throttle) * maximumForwardSpeed
        if enginesRunning {
            speed += (targetSpeed - speed) * min(dt * 1.8, 1)
        } else {
            pitchInput = 0
            yawInput = 0
            rollInput = 0
            if isBoosting || isHyperDriveCharging {
                cancelHyperDriveCharge()
            }
            if let world = worldInLandingEnvelope() {
                beginPlanetaryLanding(on: world)
                updateAutomatedFlight(dt: dt)
                return
            }
        }

        var pitch = Float(pitchInput)
        var yaw = Float(yawInput)
        let roll = Float(rollInput)

        let autopilotDestination: NearbyNavigationTarget? = if let identifier = lockedTargetIdentifier {
            universeStreamer?.destination(
                identifiedBy: identifier,
                to: playerPosition
            )
        } else {
            universeStreamer?.nearestDestination(to: playerPosition)
        }

        if enginesRunning, autopilot, let destination = autopilotDestination {
            let arrivalDistance = autopilotStopDistance(for: destination)
            if lockedTargetIdentifier != nil
                && destination.distance <= arrivalDistance {
                if isBoosting || isHyperDriveCharging {
                    cancelHyperDriveCharge()
                }
                beginAutopilotArrivalFlash(
                    message: "Arrived at \(destination.name)"
                )
            } else {
                let desired = simd_normalize(destination.vector)
                let localDesired = playerAttitude.inverse.act(desired)
                yaw = max(-1, min(1, -localDesired.x * 1.8))
                pitch = max(-1, min(1, localDesired.y * 1.8))
            }
        }

        let turnRate: Float = 0.72
        let pitchRotation = simd_quatf(angle: pitch * turnRate * dt, axis: SIMD3<Float>(1, 0, 0))
        let yawRotation = simd_quatf(angle: yaw * turnRate * dt, axis: SIMD3<Float>(0, 1, 0))
        let rollRotation = simd_quatf(angle: roll * turnRate * dt, axis: SIMD3<Float>(0, 0, 1))
        playerAttitude = simd_normalize(playerAttitude * yawRotation * pitchRotation * rollRotation)
        // Capture radial-up before travel so hands-free atmosphere flight can
        // rotate attitude by the same arc the planet curve advances.
        let previousSurfaceUp = surfaceUpDirection

        let forward = playerAttitude.act(SIMD3<Float>(0, 0, -1))
        if isBoosting {
            let danger = universeStreamer?.constrainSpaceMovement(
                from: playerPosition,
                proposedDelta: forward * 1_000,
                clearance: 2
            )
            if let obstacle = danger?.obstacle {
                cancelHyperDriveCharge()
                speed = min(speed, maximumForwardSpeed)
                interactionStatus =
                    "Hyperdrive safety exit • \(obstacle) within 1000 m"
            }
        }
        let right = playerAttitude.act(SIMD3<Float>(1, 0, 0))
        let up = playerAttitude.act(SIMD3<Float>(0, 1, 0))
        let strafeSpeed: Float = 18
        let strafeVelocity =
            right * Float(strafeInputX) * strafeSpeed
            + up * Float(strafeInputY) * strafeSpeed
        let impactSpeed = travelSpeed
        let proposedDelta = (forward * travelSpeed + strafeVelocity) * dt
        let solidConstraint = universeStreamer?.constrainSpaceMovement(
            from: playerPosition,
            proposedDelta: proposedDelta,
            clearance: 2
        ) ?? (delta: proposedDelta, obstacle: nil)
        if let obstacle = solidConstraint.obstacle {
            if impactSpeed > 4 {
                applyShipDamage(
                    min(20, max(1, impactSpeed * 0.08)),
                    reason: "collision with \(obstacle)"
                )
            }
            speed = 0
            throttle = 0
            cancelHyperDriveCharge()
            interactionStatus =
                obstacle == nearbyWorldForEnvironment?.name
                    ? "Surface contact — LAND available"
                    : "Collision avoided • \(obstacle)"
        }
        let delta = constrainToPlanetSurface(solidConstraint.delta)
        playerPosition.translate(by: SIMD3<Double>(delta))
        applyAtmosphericTravelCurvature(
            previousUp: previousSurfaceUp,
            traveledDelta: delta
        )
        applyAtmosphericAutoUpright(dt: dt)
        universeStreamer?.update(around: playerPosition.sector)
        distanceTravelled += simd_length(delta)
        elapsedTime += TimeInterval(dt)
        telemetryAccumulator += TimeInterval(dt)
        applyCameraTransform()

        if telemetryAccumulator > 0.12 {
            telemetryAccumulator = 0
            updateTelemetry()
        }
    }

    private func updateAtmosphericBoost(dt: Float) {
        let target: Float =
            isAtmosphericBoostHeld && isWithinPlanetAtmosphere ? 1 : 0
        let response: Float = target > atmosphericBoostBlend ? 0.85 : 1.25
        let maximumStep = dt / response
        if atmosphericBoostBlend < target {
            atmosphericBoostBlend =
                min(target, atmosphericBoostBlend + maximumStep)
        } else {
            atmosphericBoostBlend =
                max(target, atmosphericBoostBlend - maximumStep)
        }
    }

    private func updateAutomatedFlight(dt: Float) {
        guard let identifier = automatedTargetIdentifier,
              let target = universeStreamer?.destination(
                identifiedBy: identifier,
                to: playerPosition
              ),
              target.distance > 0.001 else {
            automatedFlightPhase = .none
            automatedTargetIdentifier = nil
            interactionStatus = "Automated maneuver interrupted"
            return
        }

        let surfaceUp = -simd_normalize(target.vector)
        playerAttitude = levelAttitude(
            from: playerAttitude,
            surfaceUp: surfaceUp,
            dt: dt
        )

        switch automatedFlightPhase {
        case .levelingForLanding:
            landingLevelElapsed += dt
            let shipUp = simd_normalize(
                playerAttitude.act(SIMD3<Float>(0, 1, 0))
            )
            if landingLevelElapsed >= 0.65,
               simd_dot(shipUp, surfaceUp) >= 0.998 {
                automatedFlightPhase = .descendingForLanding
                interactionStatus = "Landing 2/3 • Descending"
            }

        case .descendingForLanding:
            let landingDistance =
                universeStreamer?.shipSurfaceRadius(for: target)
                ?? target.radius + PlanetSurfaceField.shipSurfaceClearance
            let remaining = max(0, target.distance - landingDistance)
            if remaining <= 0.05 {
                automatedFlightPhase = .none
                automatedTargetIdentifier = nil
                secureShip(to: target, landed: true)
                interactionStatus = "Landed • EXIT to leave the ship"
                return
            }
            let descentSpeed = max(4, min(45, remaining * 0.45))
            let step = min(remaining, descentSpeed * dt)
            playerPosition.translate(
                by: SIMD3<Double>(simd_normalize(target.vector) * step)
            )

        case .verticalTakeoff:
            let remaining = max(0, takeoffTargetDistance - target.distance)
            if remaining <= 0.05 {
                automatedFlightPhase = .none
                automatedTargetIdentifier = nil
                takeoffTargetDistance = 0
                securedLocationKind = nil
                securedLocationName = nil
                nearbyInteractionTarget = nil
                interactionStatus =
                    "Takeoff complete • Flight controls enabled"
                return
            }
            let step = min(remaining, 11 * dt)
            playerPosition.translate(
                by: SIMD3<Double>(surfaceUp * step)
            )

        case .none:
            return
        }

        universeStreamer?.update(around: playerPosition.sector)
        distanceTravelled += dt * max(0, speed)
        elapsedTime += TimeInterval(dt)
        applyCameraTransform()
        telemetryAccumulator += TimeInterval(dt)
        if telemetryAccumulator > 0.12 {
            telemetryAccumulator = 0
            updateTelemetry()
        }
    }

    private func levelAttitude(
        from attitude: simd_quatf,
        surfaceUp: SIMD3<Float>,
        dt: Float
    ) -> simd_quatf {
        let currentForward = attitude.act(SIMD3<Float>(0, 0, -1))
        var levelForward =
            currentForward
            - surfaceUp * simd_dot(currentForward, surfaceUp)
        if simd_length_squared(levelForward) < 0.0001 {
            levelForward = simd_cross(
                attitude.act(SIMD3<Float>(1, 0, 0)),
                surfaceUp
            )
        }
        levelForward = simd_normalize(levelForward)
        let right = simd_normalize(simd_cross(levelForward, surfaceUp))
        let target = simd_quatf(
            simd_float3x3(columns: (right, surfaceUp, -levelForward))
        )
        let alignment = max(-1, min(1, simd_dot(
            simd_normalize(attitude.act(SIMD3<Float>(0, 1, 0))),
            surfaceUp
        )))
        let angle = acos(alignment)
        guard angle > 0.001 else { return simd_normalize(target) }
        let fraction = min(1, dt * 1.6 / angle)
        return simd_normalize(simd_slerp(attitude, target, fraction))
    }

    private func initializeExplorationHeading() {
        guard isSurfaceExploration,
              let world = universeStreamer?.nearestDestination(
                to: playerPosition,
                matching: .world
              ),
              world.distance > 0.001 else {
            return
        }
        let surfaceUp = -simd_normalize(world.vector)
        var north =
            SIMD3<Float>(0, 0, -1)
                - surfaceUp
                    * simd_dot(SIMD3<Float>(0, 0, -1), surfaceUp)
        if simd_length_squared(north) < 0.001 {
            north =
                SIMD3<Float>(0, 1, 0)
                    - surfaceUp
                        * simd_dot(SIMD3<Float>(0, 1, 0), surfaceUp)
        }
        explorationNorth = simd_normalize(north)
        explorationEast = simd_normalize(
            simd_cross(explorationNorth, surfaceUp)
        )
        let shipForward = playerAttitude.act(SIMD3<Float>(0, 0, -1))
        let tangentForward =
            shipForward - surfaceUp * simd_dot(shipForward, surfaceUp)
        if simd_length_squared(tangentForward) > 0.001 {
            explorationHeading = simd_normalize(tangentForward)
        } else {
            explorationHeading = simd_normalize(
                simd_cross(
                    playerAttitude.act(SIMD3<Float>(1, 0, 0)),
                    surfaceUp
                )
            )
        }
    }

    private func updateSurfaceExploration(dt: Float) {
        guard let world = universeStreamer?.nearestDestination(
            to: playerPosition,
            matching: .world
        ), world.distance > 0.001 else {
            explorationTravelSpeed = 0
            return
        }

        // Radial before this frame's step — used so walking attitude can follow
        // planet curvature after the move (frozen landing-up makes distant
        // ground rise into the sky instead of sinking under the horizon).
        let previousSurfaceUp = -simd_normalize(world.vector)
        if activeExplorationMode == "Leave on foot" {
            updateWalkingHeading(surfaceUp: previousSurfaceUp)
        }
        let turnRate: Float =
            activeExplorationMode == "Deploy rover" ? 1.35 : 1.8
        let turn =
            activeExplorationMode == "Deploy rover"
                ? Float(explorationTurnInput) * turnRate * dt
                : 0
        if abs(turn) > 0.0001 {
            explorationHeading = simd_normalize(
                simd_quatf(angle: -turn, axis: previousSurfaceUp)
                    .act(explorationHeading)
            )
        }
        explorationHeading = simd_normalize(
            explorationHeading
                - previousSurfaceUp
                    * simd_dot(explorationHeading, previousSurfaceUp)
        )

        let signedInput: Float =
            activeExplorationMode == "Leave on foot"
                ? max(
                    walkingGestureActive ? 1 : 0,
                    max(0, Float(explorationForwardInput))
                )
                : Float(explorationForwardInput)
        let runMultiplier: Float =
            activeExplorationMode == "Leave on foot"
                && (isRunningGestureActive || controllerRunHeld)
                ? 2
                : 1
        explorationTravelSpeed =
            signedInput
            * explorationMaximumSpeed
            * runMultiplier
            * (signedInput < 0 ? 0.5 : 1)
        if activeExplorationMode == "Leave on foot" {
            updateWalkingJetpack(deltaTime: dt)
        }
        let proposedDelta =
            explorationHeading * explorationTravelSpeed * dt
                + pendingSurfaceKnockback
        pendingSurfaceKnockback = .zero
        let movedDistance = moveAcrossSurface(
            by: proposedDelta,
            deltaTime: dt
        )
        applyCreatureAttacks()
        if activeExplorationMode == "Deploy rover" {
            surfaceRoverPosition = playerPosition
        }
        updateSurfaceVehicleMarkers()
        distanceTravelled += movedDistance
        elapsedTime += TimeInterval(dt)

        let surfaceUp: SIMD3<Float>
        if let worldAfter = universeStreamer?.nearestDestination(
            to: playerPosition,
            matching: .world
        ), worldAfter.distance > 0.001 {
            surfaceUp = -simd_normalize(worldAfter.vector)
        } else {
            surfaceUp = previousSurfaceUp
        }

        if activeExplorationMode == "Leave on foot" {
            // Keep headset free-look, but rotate attitude by the same radial
            // arc just walked so the horizon curves over near ground first.
            applySurfaceTravelCurvature(
                from: previousSurfaceUp,
                to: surfaceUp
            )
        } else if activeExplorationMode == "Deploy rover" {
            let right = simd_normalize(
                simd_cross(explorationHeading, surfaceUp)
            )
            let basis = simd_float3x3(
                columns: (right, surfaceUp, -explorationHeading)
            )
            playerAttitude = simd_normalize(simd_quatf(basis))
        }
        explorationHeading = simd_normalize(
            explorationHeading
                - surfaceUp * simd_dot(explorationHeading, surfaceUp)
        )
        explorationHeadingDegrees = atan2(
            simd_dot(explorationHeading, explorationEast),
            simd_dot(explorationHeading, explorationNorth)
        ) * 180 / .pi
        if explorationHeadingDegrees < 0 {
            explorationHeadingDegrees += 360
        }
        updateSurfaceNavigation()
        applyCameraTransform()

        checkpointSaveAccumulator += dt
        if checkpointSaveAccumulator >= 4 {
            checkpointSaveAccumulator = 0
            let movedFarEnough: Bool = {
                guard let last = lastCheckpointPlayerPosition else {
                    return true
                }
                let delta = playerPosition.vector(
                    to: last.sector,
                    local: last.local
                )
                return simd_length(delta) > 2
            }()
            if movedFarEnough {
                lastCheckpointPlayerPosition = playerPosition
                persistLocationCheckpoint()
            }
        }

        telemetryAccumulator += TimeInterval(dt)
        if telemetryAccumulator > 0.12 {
            telemetryAccumulator = 0
            updateTelemetry()
        }
    }

    private func updateWalkingHeading(surfaceUp: SIMD3<Float>) {
        guard hasWalkingFacingDirection else { return }
        let facing = playerAttitude.act(walkingFacingDirection)
        let tangent =
            facing - surfaceUp * simd_dot(facing, surfaceUp)
        guard simd_length_squared(tangent) > 0.001 else { return }
        explorationHeading = simd_normalize(tangent)
    }

    /// On-foot: rotate view attitude by the radial change from walking so
    /// distant props fall under the horizon instead of climbing the sky.
    private func applySurfaceTravelCurvature(
        from previousUp: SIMD3<Float>,
        to newUp: SIMD3<Float>
    ) {
        let alignment = max(-1, min(1, simd_dot(previousUp, newUp)))
        guard alignment < 0.999999 else { return }
        var axis = simd_cross(previousUp, newUp)
        let axisLength = simd_length(axis)
        guard axisLength > 1e-8 else { return }
        axis /= axisLength
        let curvature = simd_quatf(angle: acos(alignment), axis: axis)
        playerAttitude = simd_normalize(curvature * playerAttitude)
    }

    @discardableResult
    private func moveAcrossSurface(
        by proposedDelta: SIMD3<Float>,
        deltaTime: Float = 1 / 60
    ) -> Float {
        guard let world = universeStreamer?.nearestDestination(
            to: playerPosition,
            matching: .world
        ), world.distance > 0.001 else {
            return 0
        }
        let surfaceConstraint =
            universeStreamer?.constrainSurfaceMovement(
                around: playerPosition,
                proposedDelta: proposedDelta,
                playerRadius:
                    activeExplorationMode == "Deploy rover" ? 1.15 : 0.34
            ) ?? (
                delta: proposedDelta,
                obstacle: nil,
                stepHeight: 0
            )
        if let obstacle = surfaceConstraint.obstacle {
            explorationTravelSpeed = 0
            interactionStatus = "Blocked by \(obstacle)"
        }
        let safeDelta = surfaceConstraint.delta
        if surfaceConstraint.stepHeight >= surfaceStepHeight {
            surfaceStepHeight = surfaceConstraint.stepHeight
        } else {
            // Fall quickly when a walkable prop underfoot is removed.
            let fallRate: Float =
                surfaceConstraint.stepHeight + 0.08 < surfaceStepHeight
                ? 16
                : 4.2
            surfaceStepHeight = max(
                surfaceConstraint.stepHeight,
                surfaceStepHeight - fallRate * deltaTime
            )
        }
        let vectorAfterMove = world.vector - safeDelta
        let outward = simd_length_squared(vectorAfterMove) > 0.000_001
            ? -simd_normalize(vectorAfterMove)
            : -simd_normalize(world.vector)
        let localTerrainElevation =
            universeStreamer?.surfaceElevation(
                around: playerPosition,
                worldOutward: outward
            ) ?? 0
        let surfaceDistance =
            (universeStreamer?.activeSurfaceRadius ?? world.radius)
                + UniverseScale.surfaceEyeHeight
                + localTerrainElevation
                + surfaceStepHeight
                + surfaceJetpackAltitude
        let correctedVectorToCenter =
            simd_normalize(vectorAfterMove) * surfaceDistance
        let delta = world.vector - correctedVectorToCenter
        playerPosition.translate(by: SIMD3<Double>(delta))
        universeStreamer?.update(around: playerPosition.sector)
        universeStreamer?.updateSurfaceExploration(
            around: playerPosition,
            deltaTime: deltaTime
        )
        return simd_length(delta)
    }

    private func updateWalkingJetpack(deltaTime: Float) {
        let maxFuel = Self.jetpackFuelCapacity
        let riseSpeed: Float = 3.4
        let slowFallSpeed: Float = 1.6
        let gravity: Float = 6.5

        if isJetpackThrusting,
           unlimitedFuelAndEnergy || surfaceJetpackFuel > 0 {
            let burn = unlimitedFuelAndEnergy
                ? deltaTime
                : min(deltaTime, surfaceJetpackFuel)
            if !unlimitedFuelAndEnergy {
                surfaceJetpackFuel -= burn
            }
            surfaceJetpackVelocity = riseSpeed
            surfaceJetpackAltitude += riseSpeed * burn
            if !unlimitedFuelAndEnergy, surfaceJetpackFuel <= 0 {
                isJetpackThrusting = false
            }
        } else if surfaceJetpackAltitude > 0 {
            surfaceJetpackVelocity = max(
                -slowFallSpeed,
                surfaceJetpackVelocity - gravity * deltaTime
            )
            surfaceJetpackAltitude = max(
                0,
                surfaceJetpackAltitude + surfaceJetpackVelocity * deltaTime
            )
            if surfaceJetpackAltitude <= 0 {
                surfaceJetpackAltitude = 0
                surfaceJetpackVelocity = 0
            }
        } else {
            surfaceJetpackVelocity = 0
            // Refuel only when grounded and not thrusting.
            if !isJetpackThrusting {
                surfaceJetpackFuel = min(
                    maxFuel,
                    surfaceJetpackFuel + deltaTime * 0.85
                )
            }
        }
        if abs(displayedJetpackFuel - surfaceJetpackFuel) >= 0.05
            || (surfaceJetpackFuel >= maxFuel - 0.001
                && displayedJetpackFuel < maxFuel) {
            displayedJetpackFuel = surfaceJetpackFuel
        }
    }

    private func updateSurfaceNavigation() {
        guard isSurfaceExploration,
              let shipPosition = surfaceShipPosition else {
            shipNavigationDistance = 0
            shipNavigationBearingDegrees = 0
            roverNavigationDistance = nil
            roverNavigationBearingDegrees = nil
            return
        }
        let shipNavigation = surfaceNavigation(to: shipPosition)
        shipNavigationDistance = shipNavigation.distance
        shipNavigationBearingDegrees = shipNavigation.relativeBearing

        if let roverPosition = surfaceRoverPosition {
            let roverNavigation = surfaceNavigation(to: roverPosition)
            roverNavigationDistance = roverNavigation.distance
            roverNavigationBearingDegrees =
                roverNavigation.relativeBearing
        } else {
            roverNavigationDistance = nil
            roverNavigationBearingDegrees = nil
        }
    }

    /// Keeps saved/on-foot actors on the same walkable shell as markers.
    private func reprojectSurfaceActorsOntoShell() {
        if let projected = universeStreamer?.reprojectOntoSurfaceShell(
            playerPosition
        ) {
            playerPosition = projected
        }
        if let ship = surfaceShipPosition,
           let projected = universeStreamer?.reprojectOntoSurfaceShell(
            ship
           ) {
            surfaceShipPosition = projected
        }
        if let rover = surfaceRoverPosition,
           let projected = universeStreamer?.reprojectOntoSurfaceShell(
            rover
           ) {
            surfaceRoverPosition = projected
        }
    }

    private func surfaceNavigation(
        to target: GalacticPosition
    ) -> (distance: Float, relativeBearing: Float) {
        // Compare on the active exploration shell so a stale radial scale
        // (e.g. checkpoint from surfacePerspectiveScale 24 vs 6) cannot
        // inflate distance and hide the enter-ship / enter-rover prompt.
        let from =
            universeStreamer?.reprojectOntoSurfaceShell(playerPosition)
            ?? playerPosition
        let to =
            universeStreamer?.reprojectOntoSurfaceShell(target)
            ?? target
        let vector = SIMD3<Float>(
            from.vector(
                to: to.sector,
                local: to.local
            )
        )
        let distance = simd_length(vector)
        guard distance > 0.001 else {
            return (0, 0)
        }
        let absoluteBearing = atan2(
            simd_dot(vector, explorationEast),
            simd_dot(vector, explorationNorth)
        ) * 180 / .pi
        var relative =
            absoluteBearing - explorationHeadingDegrees
        while relative > 180 { relative -= 360 }
        while relative < -180 { relative += 360 }
        return (distance, relative)
    }

    private func updateSurfaceVehicleMarkers() {
        universeStreamer?.updateSurfaceVehicleMarkers(
            shipPosition: surfaceShipPosition,
            roverPosition: surfaceRoverPosition,
            roverIsOccupied:
                activeExplorationMode == "Deploy rover"
        )
    }

    private func updateFlightEnvironment(dt: Float) {
        isWithinPlanetAtmosphere = false
        isInAirlessLandingRange = false
        if isLanded || isDocked {
            let securedWorld = universeStreamer?.nearestDestination(
                to: playerPosition,
                matching: .world
            )
            isWithinPlanetAtmosphere =
                isLanded && securedWorld?.hasAtmosphere == true
            environmentStatus =
                isDocked
                    ? "DOCKED"
                    : (securedWorld?.hasAtmosphere == true
                        ? "LANDED • ATMOSPHERE"
                        : "LANDED • AIRLESS")
            atmosphericSpeedLimit = 0
            atmosphericBoostLimit = 0
            refreshViewerSky(near: isLanded ? securedWorld : nil)
            if isLanded, let securedWorld, securedWorld.kind == .world {
                universeStreamer?.maintainProximitySurface(
                    around: playerPosition,
                    deltaTime: dt,
                    simulateLife: true,
                    allowRebase: false
                )
            }
            surfaceUpDirection = nil
            nearbyWorldForEnvironment = isLanded ? securedWorld : nil
            starHeat = max(0, starHeat - dt * 20)
            return
        }

        guard let world = universeStreamer?.nearestDestination(
            to: playerPosition,
            matching: .world
        ) else {
            environmentStatus = "SPACE"
            altitudeAboveSurface = nil
            atmosphericSpeedLimit = nil
            atmosphericBoostLimit = nil
            atmosphereHazeOpacity = 0
            updateAtmosphereEnvironment(
                for: nil,
                skyOpacity: 0,
                lightStrength: 0,
                showSky: false
            )
            surfaceUpDirection = nil
            nearbyWorldForEnvironment = nil
            if !isSurfaceExploration {
                universeStreamer?.endSurfaceExploration()
            }
            starHeat = max(0, starHeat - dt * 20)
            return
        }

        // Prefer Double-length altitude so far-from-planet status cannot stick
        // due to Float truncation on the navigation vector.
        let altitude =
            universeStreamer?.altitudeAboveSurface(
                to: playerPosition,
                world: world
            ) ?? max(0, world.distance - world.radius)
        nearbyWorldForEnvironment = world

        if world.celestialKind == .star {
            atmosphericSpeedLimit = nil
            atmosphericBoostLimit = nil
            surfaceUpDirection = nil
            updateAtmosphereEnvironment(
                for: nil,
                skyOpacity: 0,
                lightStrength: 0,
                showSky: false
            )
            let heatZoneDepth = max(world.radius * 0.6, 250)
            if altitude < heatZoneDepth {
                altitudeAboveSurface = altitude
                let proximity = 1 - altitude / heatZoneDepth
                starHeat = min(100, starHeat + dt * (12 + proximity * 55))
                atmosphereHazeOpacity =
                    Double(0.08 + proximity * 0.22)
                environmentStatus = "STAR HEAT \(Int(starHeat.rounded()))%"
                if starHeat >= 100 {
                    destroyShip(in: world.name)
                }
            } else {
                altitudeAboveSurface = nil
                environmentStatus = "SPACE"
                atmosphereHazeOpacity = 0
                starHeat = max(0, starHeat - dt * 16)
            }
            if !isSurfaceExploration {
                universeStreamer?.endSurfaceExploration()
            }
            return
        }

        starHeat = max(0, starHeat - dt * 20)
        guard world.hasAtmosphere else {
            // Near-body label only — not a 10 km pseudo-atmosphere shell.
            let airlessNearShell = max(world.radius * 0.75, 60)
            let nearAirless = altitude <= airlessNearShell
            environmentStatus = nearAirless ? "AIRLESS WORLD" : "SPACE"
            altitudeAboveSurface = nearAirless ? altitude : nil
            atmosphericSpeedLimit = nil
            atmosphericBoostLimit = nil
            atmosphereHazeOpacity = 0
            updateAtmosphereEnvironment(
                for: nil,
                skyOpacity: 0,
                lightStrength: 0,
                showSky: false
            )
            surfaceUpDirection = nil
            isWithinPlanetAtmosphere = false
            let landingRange =
                UniverseScale.lowerAtmosphereDepth(for: world.radius)
            isInAirlessLandingRange = altitude <= landingRange
            if isInAirlessLandingRange, world.distance > 0.001 {
                surfaceUpDirection = -simd_normalize(world.vector)
            }
            environmentStatus = isInAirlessLandingRange
                ? "AIRLESS • LANDING RANGE"
                : (nearAirless ? "AIRLESS WORLD" : "SPACE")
            let upper = UniverseScale.upperAtmosphereDepth(for: world.radius)
            if !isSurfaceExploration {
                if altitude <= upper {
                    universeStreamer?.maintainProximitySurface(
                        around: playerPosition,
                        deltaTime: dt,
                        simulateLife: altitude
                            <= UniverseScale.lowerAtmosphereDepth(
                                for: world.radius
                            ),
                        allowRebase: !isLanded
                    )
                } else {
                    universeStreamer?.endSurfaceExploration()
                }
            }
            return
        }

        let upperAtmosphereDepth =
            UniverseScale.upperAtmosphereDepth(for: world.radius)
        let lowerAtmosphereDepth =
            UniverseScale.lowerAtmosphereDepth(for: world.radius)
        guard altitude < upperAtmosphereDepth else {
            environmentStatus = "SPACE"
            altitudeAboveSurface = nil
            atmosphericSpeedLimit = nil
            atmosphericBoostLimit = nil
            atmosphereHazeOpacity = 0
            isWithinPlanetAtmosphere = false
            updateAtmosphereEnvironment(
                for: nil,
                skyOpacity: 0,
                lightStrength: 0,
                showSky: false
            )
            surfaceUpDirection = nil
            if !isSurfaceExploration {
                universeStreamer?.endSurfaceExploration()
            }
            return
        }

        altitudeAboveSurface = altitude
        if altitude <= lowerAtmosphereDepth {
            isWithinPlanetAtmosphere = true
            let lowerDepth = 1 - altitude / lowerAtmosphereDepth
            let cruiseCeiling = ScaleAndSpeedContract.lowerAtmosphereCruiseMax
            let surfaceLimit = cruiseCeiling * 0.35
            atmosphericSpeedLimit =
                cruiseCeiling + (surfaceLimit - cruiseCeiling) * lowerDepth
            atmosphericBoostLimit =
                ScaleAndSpeedContract.lowerAtmosphereBoostMax
            environmentStatus = "LOW ATMOSPHERE"
            refreshViewerSky(near: world)
            if !isSurfaceExploration {
                universeStreamer?.maintainProximitySurface(
                    around: playerPosition,
                    deltaTime: dt,
                    simulateLife: true,
                    allowRebase: !isLanded
                )
            }
        } else {
            isWithinPlanetAtmosphere = true
            // Upper cruise is 5× the lower cruise ceiling. Hyperdrive stays
            // blocked for the whole atmosphere stack.
            atmosphericSpeedLimit =
                ScaleAndSpeedContract.upperAtmosphereCruiseMax
            atmosphericBoostLimit =
                ScaleAndSpeedContract.upperAtmosphereBoostMax
            environmentStatus = "UPPER ATMOSPHERE"
            refreshViewerSky(near: world)
            if !isSurfaceExploration {
                universeStreamer?.endSurfaceExploration()
            }
        }
        surfaceUpDirection = world.distance > 0.001
            ? -simd_normalize(world.vector)
            : SIMD3<Float>(0, 1, 0)
    }

    /// Brightens the whole sky around the viewer, from the planet limb to
    /// the zenith, while the sun is up inside an atmosphere. The shell stays
    /// on the camera and turns off in space.
    private func refreshViewerSky(near world: NearbyNavigationTarget?) {
        let sky = universeStreamer?.atmosphericSky(around: playerPosition)
            ?? (presence: Float(0), daylight: Float(0))
        let sunElevation =
            universeStreamer?.sunElevation(around: playerPosition) ?? 0
        let sunset = horizonGlow(forSunElevation: sunElevation)
        let inAtmosphere =
            world?.hasAtmosphere == true && sky.presence > 0.02
        let coverage = max(sky.daylight, sunset * 0.92)
        let skyOpacity = inAtmosphere ? coverage * sky.presence * 0.9 : 0
        atmosphereHazeOpacity = Double(skyOpacity)
        updateAtmosphereEnvironment(
            for: inAtmosphere ? world : nil,
            skyOpacity: skyOpacity,
            lightStrength: inAtmosphere
                ? sky.presence * (0.15 + 0.75 * sky.daylight)
                : 0,
            showSky: skyOpacity > 0.02,
            daylight: sky.daylight,
            sunset: sunset
        )
    }

    /// 1 while the sun is crossing the horizon, 0 once it is clearly up or down.
    private func horizonGlow(forSunElevation elevation: Float) -> Float {
        let risen = smoothstep(0.02, 0.20, elevation)
        let stillUp = smoothstep(-0.16, -0.02, elevation)
        return (1 - risen) * stillUp
    }

    private func smoothstep(
        _ edge0: Float,
        _ edge1: Float,
        _ value: Float
    ) -> Float {
        let span = edge1 - edge0
        guard abs(span) > 0.0001 else { return value >= edge1 ? 1 : 0 }
        let t = max(0, min(1, (value - edge0) / span))
        return t * t * (3 - 2 * t)
    }

    /// The sky hole is the planet as seen from the eye, not a ring fixed
    /// on the horizon. Climbing shrinks that disk and drops it; the shell
    /// sits behind the limb so the ground itself is the edge.
    private func viewerSkyFit(
        for world: NearbyNavigationTarget,
        eye: SIMD3<Float>
    ) -> (lowerElevation: Float, shellRadius: Float, up: SIMD3<Float>) {
        let rootScale = abs(universeRoot?.scale.x ?? 1)
        let planetCenter = (universeRoot?.position ?? .zero)
            + playerAttitude.inverse.act(world.vector) * rootScale
        var down = planetCenter - eye
        if simd_length_squared(down) < 1 {
            down = playerAttitude.inverse.act(world.vector)
        }
        let distance = max(simd_length(down), 1)
        let up = -down / distance
        let visualRadius = max(1, world.radius * rootScale)
        let angularRadius = asin(min(0.9995, visualRadius / distance))
        let limbElevation = angularRadius - .pi / 2
        let high = max(0, 1 - angularRadius / (.pi / 2))
        let tuck = min(
            angularRadius * 0.3,
            max(0.14, 0.12 + 0.22 * high)
        )
        let lowerElevation = max(-.pi / 2 + 0.05, limbElevation - tuck)
        let limbDistance = sqrt(
            max(1, distance * distance - visualRadius * visualRadius)
        )
        let shellRadius = limbDistance + 40
        return (lowerElevation, shellRadius, up)
    }

    private func updateAtmosphereEnvironment(
        for world: NearbyNavigationTarget?,
        skyOpacity: Float,
        lightStrength: Float,
        showSky: Bool,
        daylight: Float = 1,
        sunset: Float = 0
    ) {
        guard let world,
              world.hasAtmosphere,
              let kind = world.celestialKind,
              let environment = atmosphereEnvironmentEntity else {
            disableAtmosphereEnvironment()
            return
        }

        environment.isEnabled = true
        if let parent = environment.parent {
            environment.position =
                aimAnchorEntity?.position(relativeTo: parent) ?? .zero
        }
        let fit = viewerSkyFit(for: world, eye: environment.position)
        let lowerElevation = fit.lowerElevation
        atmosphereSkyEntity?.isEnabled = showSky
        if showSky, simd_length_squared(fit.up) > 0.5 {
            let worldSun = universeStreamer?.nearestStarDirection(
                from: playerPosition
            )
            let sceneSun = worldSun.map {
                simd_normalize(playerAttitude.inverse.act($0))
            }
            atmosphereSkyEntity?.orientation = skyOrientation(
                up: fit.up,
                sun: sceneSun
            )
            atmosphereSkyEntity?.scale = SIMD3<Float>(
                repeating: fit.shellRadius
            )
            if abs(lowerElevation - lastSkyLimbElevation) > 0.006,
               var model = atmosphereSkyEntity?.model {
                model.mesh = SpaceSceneBuilder.makeSkyDomeMesh(
                    radius: 1,
                    lowerElevation: lowerElevation
                )
                atmosphereSkyEntity?.model = model
                lastSkyLimbElevation = lowerElevation
                lastSkyTextureKey = -1
            }
        }
        for light in atmosphereLightEntities {
            light.isEnabled = true
        }
        let opacity = max(0, min(1, skyOpacity))
        let quantizedOpacity = (opacity * 100).rounded() / 100
        let textureKey =
            Int((sunset * 24).rounded())
            + Int((daylight * 24).rounded()) * 100
        let kindChanged = lastAtmosphereVisualKind != kind
        if kindChanged
            || textureKey != lastSkyTextureKey
            || abs(quantizedOpacity - lastAtmosphereVisualOpacity) >= 0.01 {
            var skyMaterial = UnlitMaterial()
            if let texture = SpaceSceneBuilder.makeAtmosphereSkyTexture(
                daylight: daylight,
                sunset: sunset
            ) {
                skyMaterial.color = .init(
                    tint: .white,
                    texture: .init(texture)
                )
            } else {
                skyMaterial.color = .init(
                    tint: UIColor(red: 0.62, green: 0.78, blue: 1, alpha: 1)
                )
            }
            skyMaterial.blending = .transparent(
                opacity: .init(floatLiteral: quantizedOpacity)
            )
            atmosphereSkyEntity?.model?.materials = [skyMaterial]
            lastAtmosphereVisualOpacity = quantizedOpacity
            lastAtmosphereVisualKind = kind
            lastSkyTextureKey = textureKey
        }

        let dayFill = SIMD3<Float>(0.75, 0.84, 1)
        let warmFill = SIMD3<Float>(1, 0.58, 0.34)
        let fill = dayFill + (warmFill - dayFill) * (sunset * 0.7)
        let fillColor = UIColor(
            red: CGFloat(fill.x),
            green: CGFloat(fill.y),
            blue: CGFloat(fill.z),
            alpha: 1
        )
        let intensity = max(0, min(1, lightStrength)) * 1_200
        for light in atmosphereLightEntities {
            light.light.color = fillColor
            light.light.intensity = intensity
        }
    }

    private func skyOrientation(
        up: SIMD3<Float>,
        sun: SIMD3<Float>?
    ) -> simd_quatf {
        var towardSun = SIMD3<Float>(0, 0, 1)
        if let sun {
            towardSun = sun - up * simd_dot(sun, up)
        }
        if simd_length_squared(towardSun) < 1e-4 {
            let helper: SIMD3<Float> =
                abs(up.x) < 0.9
                ? SIMD3<Float>(1, 0, 0)
                : SIMD3<Float>(0, 0, 1)
            towardSun = simd_cross(helper, up)
        }
        towardSun = simd_normalize(towardSun)
        let right = simd_normalize(simd_cross(up, towardSun))
        return simd_quatf(simd_float3x3(columns: (right, up, towardSun)))
    }

    private func disableAtmosphereEnvironment() {
        for light in atmosphereLightEntities {
            light.light.intensity = 0
            light.isEnabled = false
        }
        atmosphereSkyEntity?.model?.materials = [
            UnlitMaterial(
                color: UIColor.clear
            )
        ]
        atmosphereSkyEntity?.isEnabled = false
        atmosphereEnvironmentEntity?.isEnabled = false
        lastAtmosphereVisualOpacity = -1
        lastAtmosphereVisualKind = nil
        lastSkyLimbElevation = 999
        lastSkyTextureKey = -1
    }

    private func constrainToPlanetSurface(
        _ proposedDelta: SIMD3<Float>
    ) -> SIMD3<Float> {
        guard let world = nearbyWorldForEnvironment,
              world.celestialKind != .star,
              world.distance > 0.001 else {
            return proposedDelta
        }

        let vectorAfterMove = world.vector - proposedDelta
        let minimumDistance =
            universeStreamer?.shipSurfaceRadius(for: world)
            ?? world.radius + PlanetSurfaceField.shipSurfaceClearance
        let distanceAfterMove = simd_length(vectorAfterMove)
        let towardCenter = simd_dot(
            proposedDelta,
            simd_normalize(world.vector)
        )

        // Test the entire movement segment so a hyperdrive frame cannot jump
        // completely through a planet and end beyond the far surface.
        let movementLengthSquared = simd_length_squared(proposedDelta)
        if world.distance > minimumDistance + 0.05,
           movementLengthSquared > 0.0001 {
            let b = -2 * simd_dot(world.vector, proposedDelta)
            let c = simd_length_squared(world.vector)
                - minimumDistance * minimumDistance
            let discriminant = b * b - 4 * movementLengthSquared * c
            if discriminant >= 0 {
                let entryTime =
                    (-b - sqrt(discriminant))
                    / (2 * movementLengthSquared)
                if entryTime >= 0, entryTime <= 1 {
                    speed = 0
                    throttle = 0
                    cancelHyperDriveCharge()
                    interactionStatus = "Surface contact — LAND available"
                    return proposedDelta * max(0, entryTime - 0.0001)
                }
            }
        }

        guard distanceAfterMove < minimumDistance else {
            return proposedDelta
        }

        let outwardFromCenter: SIMD3<Float>
        if distanceAfterMove > 0.001 {
            outwardFromCenter = -vectorAfterMove / distanceAfterMove
        } else {
            outwardFromCenter = -simd_normalize(world.vector)
        }
        let constrainedVectorToCenter = -outwardFromCenter * minimumDistance
        let constrainedDelta = world.vector - constrainedVectorToCenter

        if towardCenter > 0 {
            speed = 0
            throttle = 0
            cancelHyperDriveCharge()
            interactionStatus = "Surface contact — LAND available"
        }
        return constrainedDelta
    }

    /// Hands-free atmosphere flight: rotate attitude by the same radial arc
    /// the ship just traveled so horizon follow matches distance, not a
    /// lagged chase that jitters across the planet face.
    private func applyAtmosphericTravelCurvature(
        previousUp: SIMD3<Float>?,
        traveledDelta: SIMD3<Float>
    ) {
        guard (isWithinPlanetAtmosphere || isInAirlessLandingRange),
              !dominantHandActive,
              let previousUp,
              let world = nearbyWorldForEnvironment,
              world.celestialKind != .star,
              world.distance > 0.001,
              simd_length_squared(traveledDelta) > 1e-10
        else { return }

        // `world.vector` is ship→center from the pre-move sample.
        let newVector = world.vector - traveledDelta
        let newDistance = simd_length(newVector)
        guard newDistance > 0.001 else { return }
        let newUp = -newVector / newDistance

        let alignment = max(-1, min(1, simd_dot(previousUp, newUp)))
        guard alignment < 0.999999 else {
            surfaceUpDirection = newUp
            return
        }

        var axis = simd_cross(previousUp, newUp)
        let axisLength = simd_length(axis)
        guard axisLength > 1e-8 else {
            surfaceUpDirection = newUp
            return
        }
        axis /= axisLength
        let angle = acos(alignment)
        let curvature = simd_quatf(angle: angle, axis: axis)
        playerAttitude = simd_normalize(curvature * playerAttitude)
        surfaceUpDirection = newUp
    }

    /// Soft residual bank/pitch cleanup after stick release. Curvature is
    /// already matched to travel; this only eases leftover roll gently.
    private func applyAtmosphericAutoUpright(dt: Float) {
        guard (isWithinPlanetAtmosphere || isInAirlessLandingRange),
              !dominantHandActive,
              let surfaceUpDirection else { return }

        let currentUp = simd_normalize(
            playerAttitude.act(SIMD3<Float>(0, 1, 0))
        )
        let alignment = max(-1, min(1, simd_dot(currentUp, surfaceUpDirection)))
        let remainingAngle = acos(alignment)
        // Deadzone so tiny numerical drift never ticks the camera.
        guard remainingAngle > 0.004 else { return }

        var axis = simd_cross(currentUp, surfaceUpDirection)
        if simd_length_squared(axis) < 0.0001 {
            axis = playerAttitude.act(SIMD3<Float>(1, 0, 0))
        } else {
            axis = simd_normalize(axis)
        }
        // Forgiving ease: proportional to remaining error, hard-capped so
        // recovery never feels snappy or stepped.
        let easeRate: Float = 1.1
        let maxRate: Float = 0.32
        let step = min(remainingAngle, remainingAngle * easeRate * dt, maxRate * dt)
        let correction = simd_quatf(angle: step, axis: axis)
        playerAttitude = simd_normalize(correction * playerAttitude)
    }

    private func destroyShip(in starName: String) {
        applyShipDamage(2_000, reason: starName)
    }

    private func updateCockpitVisuals(dt: Float) {
        updateTrueForwardReference()
        updateWeaponReticleVisual()
        updateWeaponVisualRange()
        let pitchAngle = Float(pitchInput) * 0.28
        // yawInput already carries the hand-control sign. Applying another
        // inversion made the physical stick lean opposite the player's fist.
        let lateralAngle = Float(yawInput) * 0.32
        joystickPivotEntity?.orientation =
            simd_quatf(angle: lateralAngle, axis: [0, 0, 1])
            * simd_quatf(angle: pitchAngle, axis: [1, 0, 0])

        if let throttleHandleEntity {
            throttleHandleEntity.position = [
                0,
                0.13,
                -Float(throttle) * 0.18
            ]
        }
        updatePhysicalButtonLighting()

        hyperSpeedEntity?.isEnabled = isBoosting
        guard isBoosting, let hyperSpeedEntity else { return }
        for streak in hyperSpeedEntity.children {
            streak.position.z += 72 * dt
            if streak.position.z > 1.5 {
                streak.position.z -= 40
            }
        }
    }

    /// Keeps the ship/rover-forward cue on the vehicle centerline at the
    /// pilot's current eye height. Unlike the head-aimed weapon sight, the
    /// cue does not inherit head rotation, so looking around still reveals
    /// the actual direction of the nose.
    private func updateTrueForwardReference() {
        guard let trueForwardReferenceEntity,
              let aimAnchorEntity else { return }
        let showForwardCue =
            !isRefineryPresented
                && !isStationShopPresented
                && (!isOutsideShip
                    || activeExplorationMode == "Deploy rover")
        trueForwardReferenceEntity.isEnabled = showForwardCue
        guard showForwardCue else { return }

        // Cockpit is disabled in rover mode; keep the cue on an always-on
        // vehicle frame (cockpit parent / scene root) so terrain cannot hide
        // it by disabling the cockpit hierarchy.
        synchronizeTrueForwardParent()
        guard let frame = trueForwardReferenceEntity.parent else { return }
        let eyePosition = aimAnchorEntity.position(relativeTo: frame)
        trueForwardReferenceEntity.position =
            eyePosition + SIMD3<Float>(0, 0, -1.55)
    }

    private func synchronizeTrueForwardParent() {
        guard let trueForwardReferenceEntity,
              let cockpitEntity else { return }
        let wantsCockpitParent = cockpitEntity.isEnabled
        if wantsCockpitParent {
            if trueForwardReferenceEntity.parent !== cockpitEntity {
                cockpitEntity.addChild(trueForwardReferenceEntity)
            }
            return
        }
        guard activeExplorationMode == "Deploy rover",
              let vehicleFrame = cockpitEntity.parent else {
            return
        }
        if trueForwardReferenceEntity.parent !== vehicleFrame {
            vehicleFrame.addChild(trueForwardReferenceEntity)
        }
    }

    private func updateWeaponReticleVisual() {
        guard let weaponReticleEntity else { return }
        let hideForModal =
            weaponReticleSuppressed
                || isRefineryPresented
                || isStationShopPresented
                || inventoryVisible
        weaponReticleEntity.isEnabled =
            !isOutsideShip && !hideForModal && isWeaponArmed
        guard isWeaponArmed else {
            lastReticleWeaponIndex = nil
            return
        }
        guard lastReticleWeaponIndex != currentWeaponIndex else { return }

        let color: UIColor = switch currentWeaponType {
        case .laser: .systemRed
        case .missile: .systemOrange
        case .slowBeam: .systemCyan
        }
        var material = UnlitMaterial(
            color: color
        )
        // Ignore previously drawn depth, then write the near sight-plane depth
        // so later planet, atmosphere, and hyperdrive draws stay behind it.
        material.readsDepth = false
        material.writesDepth = true
        for child in weaponReticleEntity.children {
            (child as? ModelEntity)?.model?.materials = [material]
        }

        let radius =
            0.0402 * Float(currentWeaponType.reticleDiameter / 150)
        weaponReticleEntity.scale = SIMD3<Float>(repeating: radius)
        lastReticleWeaponIndex = currentWeaponIndex
    }

    /// The one authoritative firing ray used by the sight, contact scan, and
    /// every weapon. The anchor supplies the player's current head direction;
    /// playerAttitude converts that cockpit-space direction into galaxy space.
    private var weaponAimDirection: SIMD3<Float> {
        let cockpitDirection =
            aimAnchorEntity?.convert(
                direction: SIMD3<Float>(0, 0, -1),
                to: nil
            ) ?? SIMD3<Float>(0, 0, -1)
        return simd_normalize(playerAttitude.act(cockpitDirection))
    }

    private func updateWeaponVisualRange() {
        let target = aimedTarget(for: currentWeaponType)
        let range = weaponVisualRange(for: target)
        setBeamVisualRange(laserEntity, range: range)
        setBeamVisualRange(slowBeamEntity, range: range)
    }

    private func weaponVisualRange(
        for target: NearbyNavigationTarget?
    ) -> Float {
        min(
            max((target?.distance ?? 200) - (target?.radius ?? 0), 5),
            200
        )
    }

    private func setBeamVisualRange(_ beam: Entity?, range: Float) {
        guard let beam else { return }
        let aimPoint = SIMD3<Float>(0, 0, -range)
        for emitter in beam.children {
            let side: Float = emitter.name.contains("Left") ? -1 : 1
            let launchPoint = beamLaunchPoint(horizontalSide: side)
            let beamVector = aimPoint - launchPoint
            let beamLength = simd_length(beamVector)
            emitter.position = launchPoint
            emitter.orientation = simd_quatf(
                from: SIMD3<Float>(0, 1, 0),
                to: beamVector / beamLength
            )
            for segment in emitter.children {
                segment.position = [0, beamLength / 2, 0]
                segment.orientation = simd_quatf(angle: 0, axis: [0, 1, 0])
                segment.scale = [1, beamLength / 200, 1]
            }
        }
    }

    /// Begins beyond the lower side edges and farther away than every HUD
    /// panel, so beams enter the view cleanly without drawing over controls.
    private func beamLaunchPoint(
        horizontalSide: Float
    ) -> SIMD3<Float> {
        SIMD3<Float>(horizontalSide * 1.50, -0.60, -1.35)
    }

    private func weaponLaunchPoint(
        horizontalSide: Float
    ) -> SIMD3<Float> {
        SIMD3<Float>(horizontalSide * 0.24, -0.28, -0.62)
    }

    private func updatePhysicalButtonLighting() {
        let fireIsAvailable =
            dominantHandActive
            && !isDocked
            && !isLanded
            && !isAutomatedFlightManeuver
        if lastFireButtonLit != fireIsAvailable,
           let fireButton = fireButtonEntity as? ModelEntity {
            fireButton.model?.materials = [
                fireIsAvailable
                    ? UnlitMaterial(color: .systemRed)
                    : SimpleMaterial(
                        color: UIColor(red: 0.2, green: 0.025, blue: 0.025, alpha: 1),
                        roughness: 0.8,
                        isMetallic: false
                    )
            ]
            lastFireButtonLit = fireIsAvailable
        }

        let turboIsAvailable =
            supportHandActive
            && !isDocked
            && !isLanded
            && !isAutomatedFlightManeuver
        let turboIsActive =
            isBoosting
            || isAtmosphericBoostHeld
            || atmosphericBoostBlend > 0.01
        let turboState = turboIsActive ? 2 : (turboIsAvailable ? 1 : 0)
        if lastTurboButtonState != turboState,
           let turboButton = turboButtonEntity as? ModelEntity {
            let material: any Material = switch turboState {
            case 2: UnlitMaterial(color: .systemCyan)
            case 1: UnlitMaterial(color: .systemOrange)
            default:
                SimpleMaterial(
                    color: UIColor(red: 0.22, green: 0.08, blue: 0.015, alpha: 1),
                    roughness: 0.8,
                    isMetallic: false
                )
            }
            turboButton.model?.materials = [material]
            lastTurboButtonState = turboState
        }
    }

    private func applyCameraTransform() {
        universeStreamer?.updateRenderOrigin(around: playerPosition)
        universeStreamer?.updateSurfaceDetailVisibility(
            around: playerPosition,
            showGroundDetail: isOutsideShip
        )
        universeRoot?.orientation = playerAttitude.inverse
        universeRoot?.position = .zero
    }

    private func updateTelemetry() {
        displayedTravelSpeed = travelSpeed
        displayedExplorationTravelSpeed = explorationTravelSpeed
        displayedExplorationHeadingDegrees = explorationHeadingDegrees
        if abs(displayedDistanceTravelled - distanceTravelled) >= 1 {
            displayedDistanceTravelled = distanceTravelled
        }
        if abs(displayedElapsedTime - elapsedTime) >= 0.2 {
            displayedElapsedTime = elapsedTime
        }
        let sector = playerPosition.sector
        let regionLabel = "\(sector.x), \(sector.y), \(sector.z)"
        if currentRegion != regionLabel {
            currentRegion = regionLabel
        }
        visitedSectorCount = universeStreamer?.visitedSectorCount ?? 0
        discoveredBodyCount = universeStreamer?.discoveredBodyCount ?? 0
        discoveredPointOfInterestCount =
            universeStreamer?.discoveredPointOfInterestCount ?? 0
        investigatedWreckageCount =
            universeStreamer?.investigatedWreckageCount ?? 0
        universeStreamer?.updateSurfaceDetailVisibility(
            around: playerPosition,
            showGroundDetail: isOutsideShip
        )
        updateTargetContacts()
        guard let destination = universeStreamer?.nearestDestination(to: playerPosition) else { return }
        let objectLabel =
            "\(destination.kind.displayName) • \(destination.name)"
        if nearestObject != objectLabel {
            nearestObject = objectLabel
        }
        if abs(nearestDistance - destination.distance) >= 1 {
            nearestDistance = destination.distance
        }
        updateProximity(to: destination)
    }

    private func updateTargetContacts() {
        guard !isOutsideShip,
              !isDocked,
              !isLanded,
              !isAutomatedFlightManeuver else {
            targetContacts = []
            return
        }
        let shipForward = weaponAimDirection
        let contacts =
            universeStreamer?.destinations(
                to: playerPosition,
                alignedWith: shipForward,
                minimumAlignment: cos(currentWeaponType.aimHalfAngle),
                maximumDistance: 100_000
            ) ?? []
        targetContacts = contacts.map {
            TargetContact(
                id: $0.identifier,
                name: $0.name,
                kind: $0.kind,
                distance: $0.distance
            )
        }
    }

    private func updateProximity(to target: NearbyNavigationTarget) {
        nearbyInteractionTarget = nil
        contextActionTitle = nil
        contextActionEnabled = false

        if isDocked {
            contextActionTitle = "UNDOCK"
            contextActionEnabled = true
            return
        }

        let absoluteSpeed = abs(travelSpeed)
        switch target.kind {
        case .station
            where target.distance
                <= UniverseScale.stationDockingDistance:
            nearbyInteractionTarget = target
            contextActionTitle = absoluteSpeed <= 6 ? "DOCK" : "SLOW TO DOCK"
            contextActionEnabled = absoluteSpeed <= 6
            interactionStatus = "Station docking range"
        case .wreckage where target.distance <= 40:
            nearbyInteractionTarget = target
            if universeStreamer?.isWreckageInvestigated(target.identifier) == true {
                contextActionTitle = "EXAMINED"
                interactionStatus = "Wreckage already examined"
            } else {
                contextActionTitle = absoluteSpeed <= 8 ? "EXAMINE" : "SLOW TO EXAMINE"
                contextActionEnabled = absoluteSpeed <= 8
                interactionStatus = "Wreckage examination range"
            }
        default:
            interactionStatus = ""
        }
    }

    /// Purple locator beam from an equipped Relic Key toward the nearest Relic.
    private func updateRelicKeyLocator() {
        let holdingKey = equippedInventoryItem?.isRelicKey == true
            && activeExplorationMode == "Leave on foot"
            && heldInventoryItemEntity?.isEnabled == true
        guard holdingKey,
              let held = heldInventoryItemEntity,
              let aimWorld = universeStreamer?.nearestRelicDirection(
                from: held.position(relativeTo: nil)
              ) else {
            relicLocatorEntity?.removeFromParent()
            relicLocatorEntity = nil
            return
        }

        let beamLength: Float = 3.0
        let beam: Entity
        if let existing = relicLocatorEntity {
            beam = existing
        } else {
            let root = Entity()
            root.name = "Relic Key Locator Beam"
            var glow = UnlitMaterial(
                color: UIColor.systemPurple.withAlphaComponent(0.55)
            )
            glow.blending = .transparent(opacity: .init(floatLiteral: 0.55))
            let outer = ModelEntity(
                mesh: .generateCylinder(height: beamLength, radius: 0.022),
                materials: [glow]
            )
            outer.name = "Locator Glow"
            root.addChild(outer)
            let core = ModelEntity(
                mesh: .generateCylinder(height: beamLength, radius: 0.01),
                materials: [
                    UnlitMaterial(color: UIColor.systemPurple)
                ]
            )
            core.name = "Locator Core"
            root.addChild(core)
            held.addChild(root)
            relicLocatorEntity = root
            beam = root
        }

        if beam.parent !== held {
            held.addChild(beam)
        }

        // Aim in the held-key's local space so the beam rides with the hand.
        var localAim = held.convert(direction: aimWorld, from: nil)
        if simd_length_squared(localAim) < 0.000_1 {
            localAim = SIMD3<Float>(0, 0, -1)
        } else {
            localAim = simd_normalize(localAim)
        }

        // Cylinder is Y-up and centered; place so it starts at the key tip.
        let keyTip = SIMD3<Float>(0, 0, -0.14)
        beam.position = keyTip + localAim * (beamLength * 0.5)
        beam.orientation = simd_quatf(
            from: SIMD3<Float>(0, 1, 0),
            to: localAim
        )
        beam.isEnabled = true
    }
}
