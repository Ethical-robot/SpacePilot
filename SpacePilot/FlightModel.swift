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
    case sonicSlicer = "SONIC SLICER"
    case matterCrumbler = "MATTER CRUMBLER"
    case matterLauncher = "MATTER LAUNCHER"
    case analyzer = "ANALYZER"
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

    var categoryLabel: String {
        switch category {
        case .log: "LOG"
        case .mineral: "MINERAL"
        case .electronic: "ELECTRONIC"
        case .creatureMaterial: "CREATURE MATERIAL"
        }
    }

    var displayName: String {
        processedElementName ?? materialName
    }
}

private struct InventorySnapshot: Codable {
    let items: [InventoryItem]
    let equippedItemID: String?
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

    var isImmersive = false
    var throttle = 0.18
    var pitchInput = 0.0
    var yawInput = 0.0
    var rollInput = 0.0
    var strafeInputX = 0.0
    var strafeInputY = 0.0
    var autopilot = false
    var speed: Float = 0
    var distanceTravelled: Float = 0
    var elapsedTime: TimeInterval = 0
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
    var atmosphericBoostBlend: Float = 0
    var isWithinPlanetAtmosphere = false
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
    var atmosphereHazeOpacity = 0.0
    var starHeat: Float = 0
    var isShipDestroyed = false
    var playerHealth: Float = 20
    var roverShield: Float = 60
    var roverHull: Float = 100
    var shipShield: Float = 500
    var shipHull: Float = 1_000
    var isShipShieldActive = true
    var damageFlashOpacity: Double = 0
    var gameOverTitle: String?
    var gameOverSubtitle = ""
    var explorationForwardInput = 0.0
    var explorationTurnInput = 0.0
    var explorationTravelSpeed: Float = 0
    var explorationHeadingDegrees: Float = 0
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
    var equippedInventoryItemID: String?

    let inventoryCapacity = 100
    let inventoryDemoSlotCount = 50

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
    @ObservationIgnored var playerPosition = GalacticPosition.origin
    @ObservationIgnored var playerAttitude = simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0))
    @ObservationIgnored var lastTick = ContinuousClock.now
    @ObservationIgnored var telemetryAccumulator: TimeInterval = 0
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
    @ObservationIgnored var landedShipPosition: GalacticPosition?
    @ObservationIgnored var landedShipAttitude: simd_quatf?
    @ObservationIgnored var surfaceShipPosition: GalacticPosition?
    @ObservationIgnored var surfaceRoverPosition: GalacticPosition?
    @ObservationIgnored var surfaceToolMenuEntity: Entity?
    @ObservationIgnored var heldSurfaceToolEntity: Entity?
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

        guard let data = defaults.data(
            forKey: Self.inventoryStorageKey
        ),
        let snapshot = try? JSONDecoder().decode(
            InventorySnapshot.self,
            from: data
        ) else {
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
        rebuildCollectedItemCounts()
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
        return limitedSpeed
            + (maximumForwardSpeed * atmosphericBoostMultiplier - limitedSpeed)
                * atmosphericBoostBlend
    }
    var isConsumingHyperFuel: Bool { isBoosting }
    var currentWeaponType: ShipWeapon { equippedWeapons[currentWeaponIndex] }
    var currentWeapon: String { currentWeaponType.rawValue }
    var reticleDiameter: CGFloat { currentWeaponType.reticleDiameter }
    var hasAutopilotTarget: Bool { lockedTargetIdentifier != nil }
    var isOutsideShip: Bool { activeExplorationMode != nil }
    var isSurfaceExploration: Bool {
        activeExplorationMode == "Deploy rover"
            || activeExplorationMode == "Leave on foot"
    }
    var canPresentInventory: Bool {
        isDocked || isLanded || isSurfaceExploration
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
        case .sonicSlicer:
            "AIM TOOL • PRESS THUMB DOWN TO ACTIVATE"
        case .matterCrumbler, .matterLauncher, .analyzer:
            "AIM TOOL • PRESS THUMB DOWN TO ACTIVATE"
        case .empty:
            "LOOK TO STEER • EXTEND SECONDARY HAND TO WALK"
        }
    }
    var canCycleWeapons: Bool {
        !isDocked && !isLanded && !isAutomatedFlightManeuver
    }
    var canUseDetection: Bool {
        !isDocked && !isLanded && !isAutomatedFlightManeuver
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
            target.hasAtmosphere
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
        activeExplorationMode = nil
        surfaceStepHeight = 0
        landedShipPosition = nil
        landedShipAttitude = nil
        surfaceShipPosition = nil
        surfaceRoverPosition = nil
        isRoverDeployed = false
        universeStreamer?.endSurfaceExploration()
        environmentStatus = "SPACE"
        altitudeAboveSurface = nil
        atmosphericSpeedLimit = nil
        atmosphereHazeOpacity = 0
        atmosphereEnvironmentEntity?.isEnabled = false
        lastAtmosphereVisualOpacity = -1
        lastAtmosphereVisualKind = nil
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
        damageFlashOpacity = 0
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
        restoreSavedLocation()
        universeStreamer?.update(around: playerPosition.sector)
        applyCameraTransform()
        updateCockpitVisuals(dt: 0)
        updateTelemetry()
    }

    func saveProgress() {
        persistInventory()
        persistLocationCheckpoint()
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
        var remaining = amount
        if isShipShieldActive && shipShield > 0 {
            let absorbed = min(shipShield, remaining)
            shipShield -= absorbed
            remaining -= absorbed
        }
        if remaining > 0 {
            shipHull = max(isOutsideShip ? 1 : 0, shipHull - remaining)
        }
        damageFlashOpacity = max(damageFlashOpacity, 0.42)
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
        damageFlashOpacity = max(damageFlashOpacity, 0.34)
        if activeExplorationMode == "Deploy rover" {
            var damage = Float(attacks.hits)
            let shieldDamage = min(roverShield, damage)
            roverShield -= shieldDamage
            damage -= shieldDamage
            roverHull = max(0, roverHull - damage)
            if roverHull <= 0 {
                destroyRover()
            }
            return
        }

        playerHealth = max(0, playerHealth - Float(attacks.hits))
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
        damageFlashOpacity = 0
        gameOverTitle = nil
        gameOverSubtitle = ""
        applyCameraTransform()
        updateSurfaceVehicleMarkers()
        persistLocationCheckpoint()
    }

    private func forceRecoveryToShip() {
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
        surfaceStepHeight = 0
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
        guard !isWithinPlanetAtmosphere else {
            cancelHyperDriveCharge()
            return
        }
        hyperDriveCountdown = max(0, remaining)
        isHyperDriveCharging = remaining > 0
        positionTurboButton(pressed: true)
    }

    func activateHyperDrive() {
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
        setWeaponTrigger(false)
        currentWeaponIndex = (currentWeaponIndex + 1) % equippedWeapons.count
        interactionStatus = "\(currentWeapon) selected"
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
        lockedTargetIdentifier = target.identifier
        lockedTargetName = target.name
        autopilot = true
        interactionStatus = "Autopilot locked: \(target.name)"
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
        lockedTargetIdentifier = target.identifier
        lockedTargetName = target.name
        autopilot = true
        interactionStatus =
            "Autopilot locked: \(target.name) • AIRLESS PLANET"
    }

    func cancelAutopilotTarget() {
        lockedTargetIdentifier = nil
        lockedTargetName = nil
        autopilot = false
    }

    func continueTowardContact(_ contact: TargetContact) {
        guard universeStreamer?.destination(
            identifiedBy: contact.id,
            to: playerPosition
        ) != nil else {
            interactionStatus = "\(contact.name) is no longer in sensor range"
            return
        }
        lockedTargetIdentifier = contact.id
        lockedTargetName = contact.name
        autopilot = true
        interactionStatus = "Continuing toward \(contact.name)"
    }

    func changeTrajectory() {
        cancelAutopilotTarget()
        interactionStatus = "Autopilot released • Change trajectory manually"
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
        case .world
            where target.hasAtmosphere
                && target.distance - target.radius
                    <= UniverseScale.lowerAtmosphereDepth(for: target.radius):
            beginPlanetaryLanding(on: target)
        case .world where target.distance <= target.radius + 22:
            beginPlanetaryLanding(on: target)
        case .world:
            interactionStatus = "Enter the lower atmosphere before landing"
        default:
            interactionStatus = "Move closer to the docking target"
        }
    }

    private func beginPlanetaryLanding(on target: NearbyNavigationTarget) {
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
            interactionStatus = "Takeoff complete"
            return
        }

        setWeaponTrigger(false)
        cancelHyperDriveCharge()
        throttle = 0
        speed = 0
        activeExplorationMode = nil
        surfaceStepHeight = 0
        isLanded = false
        automatedTargetIdentifier = world.identifier
        takeoffTargetDistance = world.distance + 30.48
        automatedFlightPhase = .verticalTakeoff
        interactionStatus = "Takeoff • Vertical climb 100 ft"
    }

    func selectExitOption(_ option: String) {
        guard availableExitOptions.contains(option) else { return }
        landedShipPosition = playerPosition
        landedShipAttitude = playerAttitude
        activeExplorationMode = option
        walkingRecoveryUsesRover = false
        cockpitEntity?.isEnabled = false
        interactionStatus = option
        if isSurfaceExploration {
            initializeExplorationHeading()
            if let surfaceAdjustment =
                universeStreamer?.beginSurfaceExploration(
                    around: playerPosition
                ) {
                playerPosition.translate(
                    by: SIMD3<Double>(surfaceAdjustment)
                )
                universeStreamer?.update(
                    around: playerPosition.sector
                )
                universeStreamer?.updateSurfaceExploration(
                    around: playerPosition
                )
                surfaceShipPosition = playerPosition
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
        setSurfaceToolMenuVisible(false)
        setHeldSurfaceToolVisible(false)
        if activeExplorationMode == "Deploy rover" {
            isRoverDeployed = false
            surfaceRoverPosition = nil
        }
        activeExplorationMode = nil
        surfaceStepHeight = 0
        universeStreamer?.endSurfaceExploration()
        if let shipPosition = landedShipPosition {
            playerPosition = shipPosition
        }
        if let shipAttitude = landedShipAttitude {
            playerAttitude = shipAttitude
        }
        landedShipPosition = nil
        landedShipAttitude = nil
        surfaceShipPosition = nil
        shipNavigationDistance = 0
        shipNavigationBearingDegrees = 0
        roverNavigationDistance = nil
        roverNavigationBearingDegrees = nil
        cockpitEntity?.isEnabled = true
        interactionStatus = "Returned to ship"
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
            return
        }
        walkingGestureActive = active && !surfaceToolMenuVisible
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
    }

    func setInventoryVisible(_ visible: Bool) {
        let shouldShow = visible && canPresentInventory
        if !shouldShow {
            inventoryVisible = false
            inventoryDismissedForCurrentGesture = false
        } else if !inventoryDismissedForCurrentGesture {
            inventoryVisible = true
            setSurfaceToolMenuVisible(false)
            walkingGestureActive = false
        }
    }

    func setSurfaceToolMenuVisible(_ visible: Bool) {
        let shouldShow =
            visible && activeExplorationMode == "Leave on foot"
        surfaceToolMenuVisible = shouldShow
        surfaceToolMenuEntity?.isEnabled = shouldShow
        if shouldShow {
            walkingGestureActive = false
            surfaceToolStatus = "Tap or swipe with right index finger"
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

    func surfaceToolMenuLocalX(
        for worldPosition: SIMD3<Float>
    ) -> Float? {
        guard surfaceToolMenuVisible,
              let menu = surfaceToolMenuEntity else {
            return nil
        }
        return menu.convert(position: worldPosition, from: nil).x
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
        guard SurfaceTool.allCases.indices.contains(index) else { return }
        stopMatterCrumblerBeam()
        equippedInventoryItemID = nil
        persistInventory()
        selectedSurfaceToolIndex = index
        updateSelectedSurfaceToolVisual()
        updateHeldInventoryItemVisual()
        surfaceToolStatus =
            selectedSurfaceTool == .empty
                ? "Tool put away"
                : "\(selectedSurfaceTool.rawValue) equipped"
    }

    func cycleSurfaceTool(by offset: Int) {
        let count = SurfaceTool.allCases.count
        selectSurfaceTool(
            at: (selectedSurfaceToolIndex + offset + count) % count
        )
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

    func updateHeldInventoryItemPose(
        position: SIMD3<Float>,
        pointingDirection: SIMD3<Float>
    ) {
        guard let heldInventoryItemEntity else { return }
        heldInventoryItemEntity.position =
            position + simd_normalize(pointingDirection) * 0.08
        heldInventoryItemEntity.orientation = simd_quatf(
            from: SIMD3<Float>(0, 0, -1),
            to: simd_normalize(pointingDirection)
        )
        heldInventoryItemEntity.isEnabled =
            equippedInventoryItemID != nil
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
        inventoryVisible = false
        inventoryDismissedForCurrentGesture = true
        surfaceToolStatus =
            "\(item.displayName) equipped from \(item.sourcePlanetName)"
    }

    func activateEquippedInventoryItem() {
        guard let item = equippedInventoryItem else {
            surfaceToolStatus = "Activation • no item in dominant hand"
            return
        }
        // Item-specific activation behavior will branch here as those
        // behaviors are defined.
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
            playerHealth = max(0, playerHealth - 5)
            damageFlashOpacity = max(damageFlashOpacity, 0.34)
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
        if let material = universeStreamer?.applySurfaceTool(
            selectedSurfaceTool,
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
        let aim = simd_normalize(direction)
        lastMatterCrumblerOrigin = position
        lastMatterCrumblerDirection = aim
        let beam: Entity
        if let existing = matterCrumblerBeamEntity {
            beam = existing
        } else {
            let created = ModelEntity(
                mesh: .generateCylinder(height: 12, radius: 0.024),
                materials: [
                    UnlitMaterial(
                        color: UIColor.systemCyan.withAlphaComponent(0.88)
                    )
                ]
            )
            created.name = "Matter Crumbler Continuous Beam"
            sceneRoot.addChild(created)
            matterCrumblerBeamEntity = created
            beam = created
        }
        beam.position = position + aim * 6
        beam.orientation = simd_quatf(
            from: SIMD3<Float>(0, 1, 0),
            to: aim
        )
        matterCrumblerBeamTimeout = 0.14

        guard deltaTime > 0 else { return }
        if let result = universeStreamer?.applySurfaceTool(
            .matterCrumbler,
            atWorldPosition: position,
            direction: aim,
            damageAmount: 40 * min(deltaTime, 0.10)
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

    func analyzeSurfaceTarget(
        from position: SIMD3<Float>,
        direction: SIMD3<Float>
    ) {
        guard activeExplorationMode == "Leave on foot",
              selectedSurfaceTool == .analyzer else {
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
                    processedElementName: nil
                )
            )
        }
        switch pickup.category {
        case .log:
            collectedLogs[pickup.materialName, default: 0] += 1
        case .mineral:
            collectedMinerals[pickup.materialName, default: 0] += 1
        case .electronic:
            break
        case .creatureMaterial:
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
            case .electronic:
                break
            case .creatureMaterial:
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
            equippedItemID: equippedInventoryItemID
        )
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: Self.inventoryStorageKey)
    }

    private func updateHeldInventoryItemVisual() {
        guard let heldInventoryItemEntity else { return }
        let item = equippedInventoryItem
        heldInventoryItemEntity.isEnabled = item != nil
        let isLog = item?.category == .log
        let isFeces =
            item?.materialName.lowercased().hasSuffix(" feces") == true
        heldInventoryItemEntity.findEntity(
            named: "Held Inventory Log"
        )?.isEnabled = isLog && !isFeces
        heldInventoryItemEntity.findEntity(
            named: "Held Inventory Mineral"
        )?.isEnabled = item != nil && !isLog && !isFeces
        heldInventoryItemEntity.findEntity(
            named: "Held Inventory Feces"
        )?.isEnabled = isFeces

        guard let item else { return }
        let color: UIColor = switch item.category {
        case .electronic:
            .systemGreen
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

    func leaveRover() {
        guard activeExplorationMode == "Deploy rover" else { return }
        explorationForwardInput = 0
        explorationTurnInput = 0
        explorationTravelSpeed = 0
        surfaceRoverPosition = playerPosition
        activeExplorationMode = "Leave on foot"
        walkingRecoveryUsesRover = true
        walkingGestureActive = false
        surfaceStepHeight = 0
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
        playerPosition = roverPosition
        activeExplorationMode = "Deploy rover"
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
        securedLocationIdentifier = target.identifier
        securedLocationKind = target.kind
        securedLocationName = target.name
        nearbyInteractionTarget = target
        persistLocationCheckpoint()
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
            interactionStatus = "Examined \(target.name)"
            contextActionTitle = "EXAMINED"
            contextActionEnabled = false
            investigatedWreckageCount =
                universeStreamer?.investigatedWreckageCount ?? 0
        case .world:
            break
        }
    }

    func tick() {
        let now = ContinuousClock.now
        let duration = lastTick.duration(to: now)
        lastTick = now
        let dt = min(Float(duration.components.seconds) + Float(duration.components.attoseconds) / 1e18, 0.05)
        guard dt > 0 else { return }
        damageFlashOpacity = max(
            0,
            damageFlashOpacity - Double(dt) * 1.7
        )
        if gameOverTitle != nil {
            updateGameOver(dt: dt)
            return
        }
        updateCockpitVisuals(dt: dt)
        updateWeaponEffects(dt: dt)
        updateSurfaceProjectiles(dt: dt)
        updateFlightEnvironment(dt: dt)
        if isWithinPlanetAtmosphere
            && (isBoosting || isHyperDriveCharging) {
            cancelHyperDriveCharge()
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
        speed += (targetSpeed - speed) * min(dt * 1.8, 1)

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

        if autopilot, let destination = autopilotDestination {
            let arrivalDistance: Float = switch destination.kind {
            case .world, .station: destination.radius + 80
            case .wreckage: 45
            }
            if lockedTargetIdentifier != nil && destination.distance <= arrivalDistance {
                interactionStatus = "Arrived in orbit of \(destination.name)"
                cancelAutopilotTarget()
            }
            let desired = simd_normalize(destination.vector)
            let localDesired = playerAttitude.inverse.act(desired)
            yaw = max(-1, min(1, -localDesired.x * 1.8))
            pitch = max(-1, min(1, localDesired.y * 1.8))
        }

        let turnRate: Float = 0.72
        let pitchRotation = simd_quatf(angle: pitch * turnRate * dt, axis: SIMD3<Float>(1, 0, 0))
        let yawRotation = simd_quatf(angle: yaw * turnRate * dt, axis: SIMD3<Float>(0, 1, 0))
        let rollRotation = simd_quatf(angle: roll * turnRate * dt, axis: SIMD3<Float>(0, 0, 1))
        playerAttitude = simd_normalize(playerAttitude * yawRotation * pitchRotation * rollRotation)
        applyAtmosphericAutoUpright(dt: dt)

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
            let landingDistance = target.radius + 2
            let remaining = max(0, target.distance - landingDistance)
            if remaining <= 0.05 {
                automatedFlightPhase = .none
                automatedTargetIdentifier = nil
                secureShip(to: target, landed: true)
                interactionStatus =
                    "Landing 3/3 • Landed — take off or leave ship"
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

        let surfaceUp = -simd_normalize(world.vector)
        if activeExplorationMode == "Leave on foot" {
            updateWalkingHeading(surfaceUp: surfaceUp)
        }
        let turnRate: Float =
            activeExplorationMode == "Deploy rover" ? 1.35 : 1.8
        let turn =
            activeExplorationMode == "Deploy rover"
                ? Float(explorationTurnInput) * turnRate * dt
                : 0
        if abs(turn) > 0.0001 {
            explorationHeading = simd_normalize(
                simd_quatf(angle: -turn, axis: surfaceUp)
                    .act(explorationHeading)
            )
        }
        explorationHeading = simd_normalize(
            explorationHeading
                - surfaceUp * simd_dot(explorationHeading, surfaceUp)
        )

        let signedInput: Float =
            activeExplorationMode == "Leave on foot"
                ? (walkingGestureActive ? 1 : 0)
                : Float(explorationForwardInput)
        explorationTravelSpeed =
            signedInput
            * explorationMaximumSpeed
            * (signedInput < 0 ? 0.5 : 1)
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

        if activeExplorationMode == "Deploy rover" {
            let right = simd_normalize(
                simd_cross(explorationHeading, surfaceUp)
            )
            let basis = simd_float3x3(
                columns: (right, surfaceUp, -explorationHeading)
            )
            playerAttitude = simd_normalize(simd_quatf(basis))
        }
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
        if checkpointSaveAccumulator >= 1 {
            checkpointSaveAccumulator = 0
            persistLocationCheckpoint()
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
            surfaceStepHeight = max(
                surfaceConstraint.stepHeight,
                surfaceStepHeight - 4.2 * deltaTime
            )
        }
        let vectorAfterMove = world.vector - safeDelta
        let localTerrainElevation =
            universeStreamer?.surfaceElevation(around: playerPosition) ?? 0
        let surfaceDistance =
            (universeStreamer?.activeSurfaceRadius ?? world.radius)
                + UniverseScale.surfaceEyeHeight
                + localTerrainElevation
                + surfaceStepHeight
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

    private func surfaceNavigation(
        to target: GalacticPosition
    ) -> (distance: Float, relativeBearing: Float) {
        let vector = SIMD3<Float>(
            playerPosition.vector(
                to: target.sector,
                local: target.local
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
        if isLanded {
            let landedWorld = universeStreamer?.nearestDestination(
                to: playerPosition,
                matching: .world
            )
            isWithinPlanetAtmosphere =
                landedWorld?.hasAtmosphere == true
            environmentStatus =
                landedWorld?.hasAtmosphere == true
                    ? "LANDED • ATMOSPHERE"
                    : "LANDED • AIRLESS"
            atmosphericSpeedLimit = 0
            atmosphereHazeOpacity =
                landedWorld?.hasAtmosphere == true ? 0.96 : 0
            updateAtmosphereEnvironment(
                for: landedWorld,
                skyOpacity: landedWorld?.hasAtmosphere == true ? 0.96 : 0,
                lightStrength: landedWorld?.hasAtmosphere == true ? 1 : 0,
                showSky: true
            )
            surfaceUpDirection = nil
            nearbyWorldForEnvironment = landedWorld
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
            atmosphereHazeOpacity = 0
            updateAtmosphereEnvironment(
                for: nil,
                skyOpacity: 0,
                lightStrength: 0,
                showSky: false
            )
            surfaceUpDirection = nil
            nearbyWorldForEnvironment = nil
            starHeat = max(0, starHeat - dt * 20)
            return
        }

        let altitude = max(0, world.distance - world.radius)
        altitudeAboveSurface = altitude
        nearbyWorldForEnvironment = world

        if world.celestialKind == .star {
            atmosphericSpeedLimit = nil
            surfaceUpDirection = nil
            updateAtmosphereEnvironment(
                for: nil,
                skyOpacity: 0,
                lightStrength: 0,
                showSky: false
            )
            let heatZoneDepth = max(world.radius * 0.6, 250)
            if altitude < heatZoneDepth {
                let proximity = 1 - altitude / heatZoneDepth
                starHeat = min(100, starHeat + dt * (12 + proximity * 55))
                atmosphereHazeOpacity =
                    Double(0.08 + proximity * 0.22)
                environmentStatus = "STAR HEAT \(Int(starHeat.rounded()))%"
                if starHeat >= 100 {
                    destroyShip(in: world.name)
                }
            } else {
                environmentStatus = "SPACE"
                atmosphereHazeOpacity = 0
                starHeat = max(0, starHeat - dt * 16)
            }
            return
        }

        starHeat = max(0, starHeat - dt * 20)
        guard world.hasAtmosphere else {
            environmentStatus = altitude <= 10_000 ? "AIRLESS WORLD" : "SPACE"
            atmosphericSpeedLimit = nil
            atmosphereHazeOpacity = 0
            updateAtmosphereEnvironment(
                for: nil,
                skyOpacity: 0,
                lightStrength: 0,
                showSky: false
            )
            surfaceUpDirection = altitude <= 10_000 && world.distance > 0.001
                ? -simd_normalize(world.vector)
                : nil
            return
        }

        let upperAtmosphereDepth =
            UniverseScale.upperAtmosphereDepth(for: world.radius)
        let lowerAtmosphereDepth =
            UniverseScale.lowerAtmosphereDepth(for: world.radius)
        guard altitude < upperAtmosphereDepth else {
            environmentStatus = "SPACE"
            atmosphericSpeedLimit = nil
            atmosphereHazeOpacity = 0
            updateAtmosphereEnvironment(
                for: nil,
                skyOpacity: 0,
                lightStrength: 0,
                showSky: false
            )
            surfaceUpDirection = nil
            return
        }

        if altitude <= lowerAtmosphereDepth {
            isWithinPlanetAtmosphere = true
            let lowerDepth = 1 - altitude / lowerAtmosphereDepth
            let dogfightLimit = maximumForwardSpeed * 0.5
            let surfaceLimit = maximumForwardSpeed * 0.175
            atmosphericSpeedLimit =
                dogfightLimit + (surfaceLimit - dogfightLimit) * lowerDepth
            let lowerSkyOpacity =
                lowerAtmosphereSkyOpacity(for: world.celestialKind)
            let skyOpacity =
                lowerSkyOpacity * (0.72 + lowerDepth * 0.28)
            atmosphereHazeOpacity = Double(skyOpacity)
            updateAtmosphereEnvironment(
                for: world,
                skyOpacity: skyOpacity,
                lightStrength: 0.68 + lowerDepth * 0.32,
                showSky: true
            )
            environmentStatus = "LOW ATMOSPHERE"
        } else {
            isWithinPlanetAtmosphere = true
            let upperProgress =
                (upperAtmosphereDepth - altitude)
                / (upperAtmosphereDepth - lowerAtmosphereDepth)
            // Upper-atmosphere flight is exactly twice the lower-atmosphere
            // entry limit, while still preventing hyperdrive near a planet.
            atmosphericSpeedLimit = maximumForwardSpeed
            atmosphereHazeOpacity = 0
            updateAtmosphereEnvironment(
                for: world,
                skyOpacity: 0,
                lightStrength: upperProgress * 0.60,
                showSky: false
            )
            environmentStatus = "UPPER ATMOSPHERE"
        }
        surfaceUpDirection = world.distance > 0.001
            ? -simd_normalize(world.vector)
            : SIMD3<Float>(0, 1, 0)
    }

    private func updateAtmosphereEnvironment(
        for world: NearbyNavigationTarget?,
        skyOpacity: Float,
        lightStrength: Float,
        showSky: Bool
    ) {
        guard let world,
              world.hasAtmosphere,
              let kind = world.celestialKind,
              let environment = atmosphereEnvironmentEntity else {
            disableAtmosphereEnvironment()
            return
        }

        environment.isEnabled = true
        atmosphereSkyEntity?.isEnabled = showSky
        for light in atmosphereLightEntities {
            light.isEnabled = true
        }
        let opacity = max(0, min(1, skyOpacity))
        let quantizedOpacity = (opacity * 100).rounded() / 100
        let kindChanged = lastAtmosphereVisualKind != kind
        if kindChanged
            || abs(quantizedOpacity - lastAtmosphereVisualOpacity) >= 0.01 {
            let color = atmosphereColor(for: kind)
            atmosphereSkyEntity?.model?.materials = [
                UnlitMaterial(
                    color: color.withAlphaComponent(
                        CGFloat(quantizedOpacity)
                    )
                )
            ]
            lastAtmosphereVisualOpacity = quantizedOpacity
            lastAtmosphereVisualKind = kind
        }

        let fillColor = atmosphereColor(for: kind)
        let intensity = 450 + max(0, min(1, lightStrength)) * 4_600
        for light in atmosphereLightEntities {
            light.light.color = fillColor
            light.light.intensity = intensity
        }
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
    }

    private func atmosphereColor(for kind: CelestialBodyKind) -> UIColor {
        switch kind {
        case .star:
            .white
        case .ocean:
            UIColor(red: 0.48, green: 0.76, blue: 1, alpha: 1)
        case .desert:
            UIColor(red: 1, green: 0.72, blue: 0.42, alpha: 1)
        case .rocky:
            UIColor(red: 0.74, green: 0.78, blue: 0.88, alpha: 1)
        case .ice:
            UIColor(red: 0.72, green: 0.95, blue: 1, alpha: 1)
        case .gas:
            UIColor(red: 0.78, green: 0.58, blue: 0.96, alpha: 1)
        }
    }

    private func lowerAtmosphereSkyOpacity(
        for kind: CelestialBodyKind?
    ) -> Float {
        switch kind {
        case .ocean, .ice:
            0.98
        case .desert:
            0.94
        case .rocky:
            0.90
        case .gas:
            0.84
        case .star, nil:
            0
        }
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
        let minimumDistance = world.radius + 2
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

    private func applyAtmosphericAutoUpright(dt: Float) {
        guard !dominantHandActive, let surfaceUpDirection else { return }

        let currentUp = simd_normalize(
            playerAttitude.act(SIMD3<Float>(0, 1, 0))
        )
        let alignment = max(-1, min(1, simd_dot(currentUp, surfaceUpDirection)))
        let remainingAngle = acos(alignment)
        guard remainingAngle > 0.001 else { return }

        var axis = simd_cross(currentUp, surfaceUpDirection)
        if simd_length_squared(axis) < 0.0001 {
            axis = playerAttitude.act(SIMD3<Float>(1, 0, 0))
        } else {
            axis = simd_normalize(axis)
        }
        let correction = simd_quatf(
            angle: min(remainingAngle, dt * 0.9),
            axis: axis
        )
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

    /// Keeps the ship-forward cue on the ship's centerline at the pilot's
    /// current eye height. Unlike the head-aimed weapon sight, the cue does
    /// not inherit head rotation, so looking around still reveals the actual
    /// direction of the nose.
    private func updateTrueForwardReference() {
        guard let cockpitEntity,
              let trueForwardReferenceEntity,
              let aimAnchorEntity else { return }
        let eyePosition = aimAnchorEntity.position(relativeTo: cockpitEntity)
        trueForwardReferenceEntity.position =
            eyePosition + SIMD3<Float>(0, 0, -1.55)
    }

    private func updateWeaponReticleVisual() {
        guard let weaponReticleEntity else { return }
        weaponReticleEntity.isEnabled =
            !isOutsideShip && !weaponReticleSuppressed
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
        universeRoot?.orientation = playerAttitude.inverse
        universeRoot?.position = .zero
    }

    private func updateTelemetry() {
        let sector = playerPosition.sector
        currentRegion = "\(sector.x), \(sector.y), \(sector.z)"
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
        nearestObject = "\(destination.kind.displayName) • \(destination.name)"
        nearestDistance = destination.distance
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
}
