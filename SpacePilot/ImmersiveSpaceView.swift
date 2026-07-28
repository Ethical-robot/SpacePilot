import GameController
import RealityKit
import SwiftUI

struct ImmersiveSpaceView: View {
    @Environment(FlightModel.self) private var flight
    @State private var controllerObserver = ControllerObserver()
    @State private var handController = HandFlightController()
    @State private var isDetectionPickerPresented = false

    var body: some View {
        RealityView { content, attachments in
            let scene = SpaceSceneBuilder.makeScene()
            content.add(scene)
            flight.universeRoot = scene
            flight.universeStreamer = UniverseStreamer(root: scene)
            let viewAnchor = AnchorEntity(.head)
            viewAnchor.name = "Player View Anchor"
            content.add(viewAnchor)
            flight.aimAnchorEntity = viewAnchor
            let surfaceToolMenu = SpaceSceneBuilder.makeSurfaceToolMenu()
            content.add(surfaceToolMenu)
            let heldSurfaceTools =
                SpaceSceneBuilder.makeHeldSurfaceTools()
            content.add(heldSurfaceTools)
            let heldInventoryItem =
                SpaceSceneBuilder.makeHeldInventoryItem()
            content.add(heldInventoryItem)
            flight.configureSurfaceTools(
                menu: surfaceToolMenu,
                heldTool: heldSurfaceTools,
                heldInventoryItem: heldInventoryItem
            )
            let atmosphereEnvironment =
                SpaceSceneBuilder.makeAtmosphereEnvironment()
            content.add(atmosphereEnvironment)
            flight.configureAtmosphereEnvironment(atmosphereEnvironment)
            let laser = SpaceSceneBuilder.makeLaser()
            viewAnchor.addChild(laser)
            flight.laserEntity = laser
            let slowBeam = SpaceSceneBuilder.makeSlowBeam()
            viewAnchor.addChild(slowBeam)
            flight.slowBeamEntity = slowBeam
            let reticle = SpaceSceneBuilder.makeWeaponReticle()
            viewAnchor.addChild(reticle)
            flight.configureWeaponReticle(reticle)
            let missile = SpaceSceneBuilder.makeMissile()
            viewAnchor.addChild(missile)
            flight.missileEntity = missile
            let cockpit = SpaceSceneBuilder.makeCockpit()
            content.add(cockpit)
            flight.configureCockpit(cockpit)
            flight.resetFlight()
            if let hud = attachments.entity(for: "cockpitHUD") {
                hud.position = SIMD3<Float>(0, 0.40, -1.18)
                hud.components.set(
                    ModelSortGroupComponent(
                        group: .planarUIAlwaysInFront,
                        order: 9_100
                    )
                )
                viewAnchor.addChild(hud)
            }
            if let explorationHUD = attachments.entity(for: "explorationHUD") {
                explorationHUD.position = SIMD3<Float>(0, 0.25, -1.12)
                explorationHUD.components.set(
                    ModelSortGroupComponent(
                        group: .planarUIAlwaysInFront,
                        order: 9_100
                    )
                )
                viewAnchor.addChild(explorationHUD)
            }
            if let health = attachments.entity(for: "survivabilityHUD") {
                health.position = SIMD3<Float>(0, 0.28, -1.10)
                health.components.set(
                    ModelSortGroupComponent(
                        group: .planarUIAlwaysInFront,
                        order: 9_300
                    )
                )
                viewAnchor.addChild(health)
            }
            if let damage = attachments.entity(for: "damageOverlay") {
                damage.position = SIMD3<Float>(0, 0, -0.72)
                damage.components.set(
                    ModelSortGroupComponent(
                        group: .planarUIAlwaysInFront,
                        order: 9_900
                    )
                )
                viewAnchor.addChild(damage)
            }
            if let countdown = attachments.entity(for: "hyperDriveCountdown") {
                countdown.position = SIMD3<Float>(0, 0.18, -1.20)
                countdown.components.set(
                    ModelSortGroupComponent(
                        group: .planarUIAlwaysInFront,
                        order: 9_200
                    )
                )
                viewAnchor.addChild(countdown)
            }
            if let controls = attachments.entity(for: "cockpitControls") {
                controls.position = SIMD3<Float>(0, -0.36, -0.92)
                controls.orientation = simd_quatf(angle: -0.12, axis: [1, 0, 0])
                controls.components.set(
                    ModelSortGroupComponent(
                        group: .planarUIAlwaysInFront,
                        order: 9_100
                    )
                )
                viewAnchor.addChild(controls)
            }
            if let picker = attachments.entity(for: "detectionPicker") {
                picker.position = [0, 0, -0.72]
                picker.components.set(
                    ModelSortGroupComponent(
                        group: .planarUIAlwaysInFront,
                        order: 9_500
                    )
                )
                viewAnchor.addChild(picker)
            }
            if let contacts = attachments.entity(
                for: "targetContactPanel"
            ) {
                contacts.position = [0.31, 0.10, -0.74]
                contacts.scale = SIMD3<Float>(repeating: 0.74 / 1.4)
                contacts.components.set(
                    ModelSortGroupComponent(
                        group: .planarUIAlwaysInFront,
                        order: 9_000
                    )
                )
                viewAnchor.addChild(contacts)
            }
            if let inventory = attachments.entity(
                for: "surfaceInventory"
            ) {
                inventory.position = [0, 0.02, -0.78]
                inventory.scale = SIMD3<Float>(repeating: 0.72)
                inventory.components.set(
                    ModelSortGroupComponent(
                        group: .planarUIAlwaysInFront,
                        order: 9_700
                    )
                )
                viewAnchor.addChild(inventory)
            }
        } attachments: {
            Attachment(id: "cockpitHUD") {
                CockpitHUD()
                    .environment(flight)
            }
            Attachment(id: "explorationHUD") {
                ExplorationHUD()
                    .environment(flight)
            }
            Attachment(id: "survivabilityHUD") {
                SurvivabilityHUD()
                    .environment(flight)
            }
            Attachment(id: "damageOverlay") {
                DamageAndGameOverOverlay()
                    .environment(flight)
            }
            Attachment(id: "hyperDriveCountdown") {
                HyperDriveCountdown()
                    .environment(flight)
            }
            Attachment(id: "cockpitControls") {
                CockpitControlPanel(
                    isDetectionPickerPresented:
                        $isDetectionPickerPresented
                )
                    .environment(flight)
            }
            Attachment(id: "detectionPicker") {
                DetectionPicker(
                    isPresented: $isDetectionPickerPresented
                )
                .environment(flight)
            }
            Attachment(id: "targetContactPanel") {
                ShipTargetContactHUD()
                    .environment(flight)
            }
            Attachment(id: "surfaceInventory") {
                SurfaceInventoryView()
                    .environment(flight)
            }
        }
        .handlesGameControllerEvents(matching: .gamepad)
        .task {
            controllerObserver.connect(to: flight)
            handController.connect(to: flight)
            while !Task.isCancelled {
                flight.tick()
                try? await Task.sleep(for: .milliseconds(16))
            }
        }
        .onChange(of: isDetectionPickerPresented) { _, isPresented in
            flight.setWeaponReticleSuppressed(isPresented)
        }
        .onDisappear {
            flight.setWeaponReticleSuppressed(false)
            flight.saveProgress()
            controllerObserver.disconnect()
            handController.disconnect()
            flight.universeRoot = nil
            flight.aimAnchorEntity = nil
            flight.surfaceToolMenuEntity = nil
            flight.heldSurfaceToolEntity = nil
            flight.heldInventoryItemEntity = nil
            flight.universeStreamer?.removeAll()
            flight.universeStreamer = nil
            flight.setWeaponTrigger(false)
            flight.laserEntity = nil
            flight.slowBeamEntity = nil
            flight.weaponReticleEntity = nil
            flight.missileEntity = nil
            flight.clearAtmosphereEnvironment()
            flight.isImmersive = false
        }
    }
}

private struct SurfaceInventoryView: View {
    @Environment(FlightModel.self) private var flight

    private let columns = Array(
        repeating: GridItem(.fixed(82), spacing: 8),
        count: 10
    )

    private var sortedItems: [InventoryItem] {
        flight.inventoryItems.sorted {
            if $0.sourcePlanetName != $1.sourcePlanetName {
                return $0.sourcePlanetName < $1.sourcePlanetName
            }
            if $0.displayName != $1.displayName {
                return $0.displayName < $1.displayName
            }
            return $0.categoryLabel < $1.categoryLabel
        }
    }

    var body: some View {
        if flight.inventoryVisible && flight.canPresentInventory {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label(
                        "PLANETARY MATERIAL INVENTORY",
                        systemImage: "shippingbox.fill"
                    )
                    .font(.title3.bold())
                    Spacer()
                    Text(
                        "\(flight.inventoryItems.count)"
                            + " / \(flight.inventoryCapacity) SLOTS"
                    )
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.cyan)
                }

                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(0..<flight.inventoryDemoSlotCount, id: \.self) {
                        index in
                        if sortedItems.indices.contains(index) {
                            inventoryButton(sortedItems[index])
                        } else {
                            emptySlot(index)
                        }
                    }
                }

                Text(
                    "50 demo slots shown • select an item to place it"
                        + " in your dominant hand"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(20)
            .frame(width: 920)
            .background(.black.opacity(0.72))
            .glassBackgroundEffect()
        }
    }

    private func inventoryButton(_ item: InventoryItem) -> some View {
        let iconName: String = switch item.category {
        case .log: "tree.fill"
        case .mineral: "diamond.fill"
        case .electronic: "cpu.fill"
        case .creatureMaterial: "pawprint.fill"
        }
        let iconColor: Color = switch item.category {
        case .log: .green
        case .mineral: .cyan
        case .electronic: .orange
        case .creatureMaterial: .pink
        }
        return Button {
            flight.equipInventoryItem(item)
        } label: {
            VStack(spacing: 3) {
                Image(systemName: iconName)
                .font(.title3)
                .foregroundStyle(iconColor)
                Text(item.displayName)
                    .font(.caption2.bold())
                    .lineLimit(1)
                Text(item.sourcePlanetName)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text("×\(item.quantity)")
                    .font(.caption2.monospacedDigit().bold())
            }
            .frame(width: 80, height: 82)
            .background(.white.opacity(0.10))
            .clipShape(.rect(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            "\(item.displayName), \(item.quantity),"
                + " collected from \(item.sourcePlanetName)"
        )
    }

    private func emptySlot(_ index: Int) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(.white.opacity(0.035))
            RoundedRectangle(cornerRadius: 10)
                .stroke(.white.opacity(0.10), lineWidth: 1)
            Text("\(index + 1)")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.white.opacity(0.18))
        }
        .frame(width: 80, height: 82)
    }
}

private struct ShipTargetContactHUD: View {
    @Environment(FlightModel.self) private var flight

    var body: some View {
        if !flight.isOutsideShip && !flight.targetContacts.isEmpty {
            TargetContactPanel()
                .environment(flight)
        }
    }
}

private struct CockpitHUD: View {
    @Environment(FlightModel.self) private var flight

    var body: some View {
        HStack(alignment: .top, spacing: 210) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 14) {
                    Label(
                        String(format: "%.0f m/s", flight.travelSpeed),
                        systemImage: "speedometer"
                    )
                    Text("SECTOR \(flight.currentRegion)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Text("VISITED \(flight.visitedSectorCount)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 10) {
                    Label(flight.nearestObject, systemImage: "scope")
                    Text(String(format: "%.0f m", flight.nearestDistance))
                        .monospacedDigit()
                        .foregroundStyle(.cyan)
                    if flight.environmentStatus != "SPACE" {
                        Text(flight.environmentStatus)
                            .font(.caption.bold())
                            .foregroundStyle(
                                flight.starHeat > 0
                                    || flight.isShipDestroyed
                                    ? .red
                                    : .orange
                            )
                        if let altitude = flight.altitudeAboveSurface,
                           !flight.isShipDestroyed {
                            Text("ALT \(Int(altitude.rounded())) m")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.cyan)
                        }
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .glassBackgroundEffect()

            VStack(alignment: .trailing, spacing: 8) {
                HStack(spacing: 10) {
                    Label(
                        flight.handTrackingStatus,
                        systemImage: "hand.raised.fill"
                    )
                    .foregroundStyle(
                        flight.dominantHandActive ? .green : .secondary
                    )
                    if flight.dominantHandActive {
                        Text(flight.dominantHandName)
                            .font(.caption.bold())
                            .foregroundStyle(.cyan)
                    }
                    if flight.autopilot {
                        Text(
                            flight.lockedTargetName.map {
                                "LOCK • \($0)"
                            } ?? "AUTO"
                        )
                        .font(.caption.bold())
                        .foregroundStyle(.green)
                    }
                }
                HStack(spacing: 10) {
                    if flight.isLaserFiring {
                        Text(flight.currentWeapon)
                            .font(.caption.bold())
                            .foregroundStyle(
                                flight.currentWeaponType == .slowBeam
                                    ? .cyan
                                    : .red
                            )
                    }
                    if let target = flight.slowBeamTargetName {
                        Text(
                            "\(target) −\(flight.slowBeamEffectPercent)%"
                        )
                        .font(.caption.monospacedDigit().bold())
                        .foregroundStyle(.cyan)
                    }
                    if flight.isAtmosphericBoostHeld
                        || flight.atmosphericBoostBlend > 0.01 {
                        Text(
                            "ATM BOOST ×"
                                + "\(Int(flight.atmosphericBoostMultiplier))"
                        )
                        .foregroundStyle(.orange)
                    } else if flight.isBoosting {
                        Text("HYPER ×\(Int(flight.boostMultiplier))")
                            .foregroundStyle(.orange)
                    } else if flight.isHyperDriveCharging {
                        Text(
                            "SPOOL ×"
                                + "\(Int(flight.hyperDriveChargeMultiplier))"
                        )
                        .foregroundStyle(.orange)
                    }
                }
                .font(.caption.bold())
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .glassBackgroundEffect()
        }
        .font(.headline)
        .opacity(flight.isOutsideShip ? 0 : 1)
    }
}

private struct TargetContactPanel: View {
    @Environment(FlightModel.self) private var flight

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("TARGET CONTACTS", systemImage: "scope")
                    .font(.caption.bold())
                Spacer()
                Text("≤ 100,000 m")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            ScrollView {
                VStack(spacing: 6) {
                    ForEach(flight.targetContacts) { contact in
                        HStack(spacing: 8) {
                            Image(systemName: icon(for: contact.kind))
                                .foregroundStyle(.cyan)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(contact.name)
                                    .font(.caption.bold())
                                    .lineLimit(1)
                                Text(
                                    "\(contact.kind.displayName) • "
                                    + String(
                                        format: "%.0f m",
                                        contact.distance
                                    )
                                )
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("CONTINUE") {
                                flight.continueTowardContact(contact)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.green)
                            .font(.caption2.bold())
                        }
                    }
                }
            }
            .frame(maxHeight: 210)

            Button("CHANGE TRAJECTORY", systemImage: "arrow.triangle.turn.up.right.diamond.fill") {
                flight.changeTrajectory()
            }
            .buttonStyle(.bordered)
            .tint(.orange)
        }
        .frame(width: 310)
        .padding(12)
        .glassBackgroundEffect()
    }

    private func icon(for kind: NavigationTargetKind) -> String {
        switch kind {
        case .world: "globe.americas.fill"
        case .station: "building.2.fill"
        case .wreckage: "exclamationmark.triangle.fill"
        }
    }
}

private struct ExplorationHUD: View {
    @Environment(FlightModel.self) private var flight

    var body: some View {
        Group {
            if flight.isSurfaceExploration {
                VStack(spacing: 0) {
                    HStack(spacing: 16) {
                        SurfaceCompass()
                            .environment(flight)
                        Label(
                            flight.activeExplorationMode == "Deploy rover"
                                ? "ROVER"
                                : "ON FOOT",
                            systemImage:
                                flight.activeExplorationMode == "Deploy rover"
                                ? "car.side.fill"
                                : "figure.walk"
                        )
                        .font(.headline.bold())
                        Text(
                            String(
                                format: "%.1f / %.1f m/s",
                                abs(flight.explorationTravelSpeed),
                                flight.explorationMaximumSpeed
                            )
                        )
                        .monospacedDigit()
                        Text(
                            "HDG \(Int(flight.explorationHeadingDegrees.rounded()))°"
                        )
                        .monospacedDigit()
                        Text("FIST: TILT FORWARD/BACK • LEFT/RIGHT")
                            .font(.caption.bold())
                            .foregroundStyle(.cyan)
                            .opacity(
                                flight.activeExplorationMode == "Deploy rover"
                                    ? 1 : 0
                            )
                        if flight.activeExplorationMode == "Leave on foot" {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(
                                    flight.surfaceToolMenuVisible
                                        ? "PALM MENU • RIGHT INDEX: TAP / SWIPE"
                                        : flight.surfaceToolInstruction
                                )
                                .font(.caption.bold())
                                .foregroundStyle(
                                    flight.walkingGestureActive
                                        ? .green
                                        : .cyan
                                )
                                Text(
                                    "\(flight.selectedSurfaceTool.rawValue)"
                                        + " • AMMO \(flight.matterLauncherAmmoCount)"
                                        + " • \(flight.surfaceToolStatus)"
                                )
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.vertical, 14)

                    Divider()
                        .opacity(0.32)
                    SurfaceVitalsStrip()
                        .environment(flight)
                }
                .glassBackgroundEffect()
            }
        }
        .allowsHitTesting(false)
    }
}

private struct SurfaceCompass: View {
    @Environment(FlightModel.self) private var flight

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(.black.opacity(0.45))
                Circle()
                    .stroke(.white.opacity(0.55), lineWidth: 1.5)
                Text("N").offset(y: -28)
                Text("E").offset(x: 28)
                Text("S").offset(y: 28)
                Text("W").offset(x: -28)
                navigationArrow(
                    systemImage: "airplane",
                    color: .cyan,
                    bearing: flight.shipNavigationBearingDegrees
                )
                if let bearing = flight.roverNavigationBearingDegrees {
                    navigationArrow(
                        systemImage: "car.side.fill",
                        color: .orange,
                        bearing: bearing
                    )
                    .scaleEffect(0.72)
                }
            }
            .font(.caption2.bold())
            .frame(width: 82, height: 82)

            VStack(alignment: .leading, spacing: 5) {
                Label(
                    String(
                        format: "SHIP %.1f m",
                        flight.shipNavigationDistance
                    ),
                    systemImage: "airplane"
                )
                .foregroundStyle(.cyan)
                if let distance = flight.roverNavigationDistance {
                    Label(
                        String(format: "ROVER %.1f m", distance),
                        systemImage: "car.side.fill"
                    )
                    .foregroundStyle(.orange)
                }
            }
            .font(.caption.monospacedDigit().bold())
        }
    }

    private func navigationArrow(
        systemImage: String,
        color: Color,
        bearing: Float
    ) -> some View {
        VStack(spacing: 0) {
            Image(systemName: "location.north.fill")
            Image(systemName: systemImage)
                .font(.system(size: 7, weight: .bold))
        }
        .foregroundStyle(color)
            .offset(y: -15)
            .rotationEffect(.degrees(Double(bearing)))
    }
}

private struct HyperDriveCountdown: View {
    @Environment(FlightModel.self) private var flight

    var body: some View {
        Group {
            if flight.isHyperDriveCharging {
                VStack(spacing: 2) {
                    Text("HYPERDRIVE")
                        .font(.headline.bold())
                        .tracking(3)
                    Text("\(countdownSecond)")
                        .font(.system(size: 72, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
                .foregroundStyle(.orange)
                .padding(.horizontal, 28)
                .padding(.vertical, 12)
                .glassBackgroundEffect()
            }
        }
        .animation(.snappy(duration: 0.18), value: countdownSecond)
        .allowsHitTesting(false)
    }

    private var countdownSecond: Int {
        max(1, min(3, Int(ceil(flight.hyperDriveCountdown))))
    }
}

private struct SurvivabilityHUD: View {
    @Environment(FlightModel.self) private var flight

    var body: some View {
        VStack(spacing: 5) {
            meter(
                "PLAYER",
                value: flight.playerHealth,
                maximum: 20,
                tint: .green
            )
            if flight.activeExplorationMode == "Deploy rover" {
                meter(
                    "ROVER SHIELD",
                    value: flight.roverShield,
                    maximum: 60,
                    tint: .cyan
                )
                meter(
                    "ROVER HULL",
                    value: flight.roverHull,
                    maximum: 100,
                    tint: .orange
                )
            } else if !flight.isOutsideShip {
                if flight.isShipShieldActive {
                    meter(
                        "SHIP SHIELD",
                        value: flight.shipShield,
                        maximum: 500,
                        tint: .cyan
                    )
                }
                meter(
                    "SHIP HULL",
                    value: flight.shipHull,
                    maximum: 1_000,
                    tint: .orange
                )
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .frame(width: 310)
        .glassBackgroundEffect()
        .opacity(flight.isSurfaceExploration ? 0 : 1)
        .allowsHitTesting(false)
    }

    private func meter(
        _ title: String,
        value: Float,
        maximum: Float,
        tint: Color
    ) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.caption2.bold().monospaced())
                .frame(width: 86, alignment: .leading)
            ProgressView(
                value: Double(max(0, value)),
                total: Double(maximum)
            )
            .tint(tint)
            Text("\(Int(value.rounded()))")
                .font(.caption2.monospacedDigit())
                .frame(width: 34, alignment: .trailing)
        }
    }
}

private struct SurfaceVitalsStrip: View {
    @Environment(FlightModel.self) private var flight

    var body: some View {
        HStack(spacing: 16) {
            PlayerHealthBar(
                value: flight.playerHealth,
                maximum: 20
            )
            if flight.activeExplorationMode == "Deploy rover" {
                compactMeter(
                    "SHIELD",
                    value: flight.roverShield,
                    maximum: 60,
                    tint: .cyan
                )
                compactMeter(
                    "HULL",
                    value: flight.roverHull,
                    maximum: 100,
                    tint: .orange
                )
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 7)
    }

    private func compactMeter(
        _ title: String,
        value: Float,
        maximum: Float,
        tint: Color
    ) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.caption2.bold().monospaced())
            PlainMeter(value: value, maximum: maximum, tint: tint)
                .frame(width: 74)
        }
    }
}

private struct PlayerHealthBar: View {
    let value: Float
    let maximum: Float

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "waveform.path.ecg")
                .font(.caption.bold())
                .foregroundStyle(.green)
            PlainMeter(value: value, maximum: maximum, tint: .green)
                .frame(width: 138)
            Text("\(Int(value.rounded()))")
                .font(.caption2.monospacedDigit())
                .frame(width: 24, alignment: .trailing)
        }
    }
}

private struct PlainMeter: View {
    let value: Float
    let maximum: Float
    let tint: Color

    var body: some View {
        GeometryReader { geometry in
            let fraction = max(0, min(1, value / maximum))
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(.white.opacity(0.16))
                Rectangle()
                    .fill(tint)
                    .frame(
                        width: geometry.size.width * CGFloat(fraction)
                    )
            }
        }
        .frame(height: 7)
    }
}

private struct DamageAndGameOverOverlay: View {
    @Environment(FlightModel.self) private var flight

    var body: some View {
        ZStack {
            Color.clear
            RoundedRectangle(cornerRadius: 90)
                .stroke(
                    Color.red.opacity(flight.damageFlashOpacity),
                    lineWidth: 42
                )
                .blur(radius: 18)
                .padding(20)
            if let title = flight.gameOverTitle {
                Rectangle()
                    .fill(.black.opacity(0.88))
                VStack(spacing: 18) {
                    Text("GAME OVER")
                        .font(.system(size: 32, weight: .medium))
                        .tracking(10)
                        .foregroundStyle(.red)
                    Text(title)
                        .font(.system(size: 68, weight: .black))
                    Text(flight.gameOverSubtitle)
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.74))
                }
                .foregroundStyle(.white)
            }
        }
        .frame(width: 1_050, height: 680)
        .allowsHitTesting(false)
        .animation(.easeOut(duration: 0.12), value: flight.damageFlashOpacity)
    }
}

private struct CockpitControlPanel: View {
    @Environment(FlightModel.self) private var flight
    @Binding var isDetectionPickerPresented: Bool

    var body: some View {
        Group {
            if shouldShowPanel {
                VStack(spacing: 8) {
                    if flight.isOutsideShip {
                        HStack(spacing: 12) {
                            Label(
                                flight.activeExplorationMode ?? "Outside ship",
                                systemImage: "figure.walk"
                            )
                            .font(.headline)
                            if flight.activeExplorationMode == "Deploy rover" {
                                Button(
                                    "LEAVE ROVER",
                                    systemImage: "figure.walk"
                                ) {
                                    flight.leaveRover()
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.orange)
                            }
                            if !flight.isSurfaceExploration
                                || flight.canEnterShip {
                                Button(
                                    "ENTER SHIP",
                                    systemImage: "airplane"
                                ) {
                                    flight.returnToShip()
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.cyan)
                            }
                            if flight.canEnterRover {
                                Button(
                                    "ENTER ROVER",
                                    systemImage: "car.side.fill"
                                ) {
                                    flight.enterRover()
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.orange)
                            }
                        }
                    } else {
                        HStack(spacing: 10) {
                            Button(flight.landingControlTitle, systemImage: "arrow.up.and.down.circle.fill") {
                                flight.performLandingControl()
                            }
                            .disabled(!flight.canUseLandingControl)
                            .tint(flight.canUseLandingControl ? .cyan : .gray.opacity(0.35))

                            Button(flight.currentWeapon, systemImage: "scope") {
                                flight.cycleWeapon()
                            }
                            .disabled(!flight.canCycleWeapons)
                            .tint(flight.canCycleWeapons ? .red : .gray.opacity(0.35))

                            Button(
                                flight.isShipShieldActive
                                    ? "SHIELD ON"
                                    : "SHIELD OFF",
                                systemImage:
                                    flight.isShipShieldActive
                                        ? "shield.fill"
                                        : "shield.slash"
                            ) {
                                flight.toggleShipShield()
                            }
                            .tint(
                                flight.isShipShieldActive ? .blue : .gray
                            )

                            Button {
                                isDetectionPickerPresented = true
                            } label: {
                                Label("DETECT ∞", systemImage: "sensor.tag.radiowaves.forward.fill")
                            }
                            .disabled(!flight.canUseDetection)
                            .tint(flight.canUseDetection ? .green : .gray.opacity(0.35))

                            Menu {
                                ForEach(flight.availableExitOptions, id: \.self) { option in
                                    Button(option) {
                                        flight.selectExitOption(option)
                                    }
                                }
                            } label: {
                                Label("LEAVE", systemImage: "figure.walk")
                            }
                            .disabled(!flight.canLeaveShip)
                            .tint(flight.canLeaveShip ? .orange : .gray.opacity(0.35))
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    if !flight.interactionStatus.isEmpty {
                        Text(flight.interactionStatus)
                            .font(.caption.monospaced())
                            .foregroundStyle(.cyan)
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .glassBackgroundEffect()
            }
        }
    }

    private var shouldShowPanel: Bool {
        !flight.isOutsideShip
            || !flight.isSurfaceExploration
            || flight.activeExplorationMode == "Deploy rover"
            || flight.canEnterShip
            || flight.canEnterRover
    }
}

private struct DetectionPicker: View {
    @Environment(FlightModel.self) private var flight
    @Binding var isPresented: Bool

    var body: some View {
        if isPresented && !flight.isOutsideShip {
            VStack(spacing: 14) {
                Label(
                    "FIND NEAREST",
                    systemImage: "sensor.tag.radiowaves.forward.fill"
                )
                .font(.title3.bold())

                HStack(spacing: 12) {
                    detectionButton(
                        "PLANET",
                        systemImage: "globe.americas.fill",
                        kind: .world
                    )
                    Button(
                        "AIRLESS PLANET",
                        systemImage: "moon.stars.fill"
                    ) {
                        flight.detectNearestAirlessPlanet()
                        isPresented = false
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.indigo)
                    .controlSize(.large)
                }

                HStack(spacing: 12) {
                    detectionButton(
                        "STATION",
                        systemImage: "building.2.fill",
                        kind: .station
                    )
                    detectionButton(
                        "WRECKAGE",
                        systemImage: "exclamationmark.triangle.fill",
                        kind: .wreckage
                    )
                }

                HStack(spacing: 12) {
                    Button(
                        "CANCEL CURRENT TARGET",
                        systemImage: "scope"
                    ) {
                        flight.cancelAutopilotTarget()
                        isPresented = false
                    }
                    .disabled(!flight.hasAutopilotTarget)
                    .tint(
                        flight.hasAutopilotTarget
                            ? .red
                            : .gray.opacity(0.35)
                    )

                    Button("CLOSE", systemImage: "xmark.circle.fill") {
                        isPresented = false
                    }
                    .tint(.secondary)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(22)
            .glassBackgroundEffect()
        }
    }

    private func detectionButton(
        _ title: String,
        systemImage: String,
        kind: NavigationTargetKind
    ) -> some View {
        Button(title, systemImage: systemImage) {
            flight.detectNearest(kind)
            isPresented = false
        }
        .buttonStyle(.borderedProminent)
        .tint(.green)
        .controlSize(.large)
    }
}

@MainActor
private final class ControllerObserver {
    private weak var flight: FlightModel?

    func connect(to flight: FlightModel) {
        self.flight = flight
        GCController.controllers().forEach(configure)
    }

    func disconnect() {
        flight?.pitchInput = 0
        flight?.yawInput = 0
        flight?.rollInput = 0
        flight = nil
    }

    private func configure(_ controller: GCController) {
        guard let gamepad = controller.extendedGamepad else { return }
        gamepad.leftThumbstick.valueChangedHandler = { [weak self] _, x, y in
            Task { @MainActor in
                self?.flight?.yawInput = Double(-x)
                self?.flight?.pitchInput = Double(y)
            }
        }
        gamepad.rightThumbstick.xAxis.valueChangedHandler = { [weak self] _, value in
            Task { @MainActor in self?.flight?.rollInput = Double(value) }
        }
        gamepad.rightTrigger.valueChangedHandler = { [weak self] _, value, _ in
            Task { @MainActor in self?.flight?.throttle = Double(value) }
        }
        gamepad.buttonA.pressedChangedHandler = { [weak self] _, _, pressed in
            guard pressed else { return }
            Task { @MainActor in
                guard let self, let flight = self.flight else { return }
                flight.autopilot.toggle()
            }
        }
        gamepad.buttonB.pressedChangedHandler = { [weak self] _, _, pressed in
            guard pressed else { return }
            Task { @MainActor in self?.flight?.stop() }
        }
    }
}
