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
                // Outside-ship enter/rover row stays head-relative.
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
            syncConsoleFacetUI(attachments, cockpit: cockpit)
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
            if let shop = attachments.entity(for: "stationShop") {
                // Closer than inventory (-0.78) so shop buttons stay hittable.
                shop.position = [0, 0.04, -0.70]
                shop.scale = SIMD3<Float>(repeating: 0.70)
                shop.components.set(
                    ModelSortGroupComponent(
                        group: .planarUIAlwaysInFront,
                        order: 9_850
                    )
                )
                viewAnchor.addChild(shop)
            }
            if let refinery = attachments.entity(for: "refineryPanel") {
                // Midway between top HUD (~0.40) and lower controls (~-0.36).
                // Closer than inventory (-0.78) so CLOSE/craft stay hittable.
                refinery.position = [0, -0.02, -0.70]
                refinery.scale = SIMD3<Float>(repeating: 0.68)
                refinery.components.set(
                    ModelSortGroupComponent(
                        group: .planarUIAlwaysInFront,
                        order: 9_860
                    )
                )
                viewAnchor.addChild(refinery)
            }
        } update: { _, attachments in
            guard let cockpit = flight.cockpitEntity else { return }
            syncConsoleFacetUI(attachments, cockpit: cockpit)
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
                OutsideShipControlBar()
                    .environment(flight)
            }
            Attachment(id: "consoleFarLeft") {
                FlightConsoleFarLeftFacet()
                    .environment(flight)
            }
            Attachment(id: "consoleLeft") {
                FlightConsoleVideoFacet(title: "MONITOR")
                    .environment(flight)
            }
            Attachment(id: "consoleCenter") {
                FlightConsoleReadoutFacet()
                    .environment(flight)
            }
            Attachment(id: "consoleRight") {
                FlightConsoleSystemsFacet()
                    .environment(flight)
            }
            Attachment(id: "consoleFarRight") {
                FlightConsoleFarRightFacet()
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
            Attachment(id: "stationShop") {
                StationShopView()
                    .environment(flight)
            }
            Attachment(id: "refineryPanel") {
                RefineryFabricatorView()
                    .environment(flight)
            }
        }
        .handlesGameControllerEvents(matching: .gamepad)
        .task {
            controllerObserver.connect(to: flight)
            handController.connect(to: flight)
            while !Task.isCancelled {
                // Head pose feeds walk/kit/jetpack zone checks; yaw pinch
                // does not need it, so missing this looks like "only turn works".
                handController.pollDevicePose()
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

    private func syncConsoleFacetUI(
        _ attachments: RealityViewAttachments,
        cockpit: Entity
    ) {
        let facets = [
            ("consoleFarLeft", "Flight Console Far Left UI"),
            ("consoleLeft", "Flight Console Left UI"),
            ("consoleCenter", "Flight Console Center UI"),
            ("consoleRight", "Flight Console Right UI"),
            ("consoleFarRight", "Flight Console Far Right UI")
        ]
        for (id, anchorName) in facets {
            guard let ui = attachments.entity(for: id),
                  let anchor = cockpit.findEntity(named: anchorName) else {
                continue
            }
            if ui.parent !== anchor {
                anchor.addChild(ui)
            }
            ui.position = .zero
            // Identity keeps the attachment's front toward the pilot.
            // A 180° yaw showed the back face, so the labels read backwards.
            ui.orientation = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
            ui.scale = SIMD3<Float>(repeating: 1)
        }
    }
}

private struct SurfaceInventoryView: View {
    @Environment(FlightModel.self) private var flight
    @State private var pendingDifficulty: GameDifficulty = .normal

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
        // Hide while refinery/shop owns the interaction plane — otherwise the
        // closer inventory attachment steals pinches and the modal feels stuck.
        if flight.inventoryVisible
            && flight.canPresentInventory
            && !flight.isRefineryPresented
            && !flight.isStationShopPresented {
            VStack(alignment: .leading, spacing: 14) {
                // Top-bar menus must expand downward (below this header),
                // never upward above the bar. See PanelMenuExpansion.
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .center, spacing: 12) {
                        Label(
                            "PLANETARY MATERIAL INVENTORY",
                            systemImage: "shippingbox.fill"
                        )
                        .font(.title3.bold())
                        Spacer()
                        Text(ProgressionEconomy.formatMon(flight.mon))
                            .font(.headline.monospacedDigit())
                            .foregroundStyle(.yellow)
                        Text(
                            "\(flight.inventoryItems.count)"
                                + " / \(flight.inventoryCapacity) SLOTS"
                        )
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(.cyan)
                        Button {
                            if flight.isSettingsMenuPresented {
                                flight.closeSettingsMenu()
                            } else {
                                pendingDifficulty = flight.gameDifficulty
                                flight.openSettingsMenu()
                            }
                        } label: {
                            Image(
                                systemName: flight.isSettingsMenuPresented
                                    ? "xmark.circle.fill"
                                    : "gearshape.fill"
                            )
                            .font(.title2)
                            .foregroundStyle(
                                flight.isSettingsMenuPresented
                                    ? .orange : .white
                            )
                            .frame(width: 44, height: 44)
                            .background(.white.opacity(0.12))
                            .clipShape(.circle)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(
                            flight.isSettingsMenuPresented
                                ? "Close settings"
                                : "Open settings"
                        )
                    }

                    if flight.isSettingsMenuPresented {
                        settingsPanel
                            .transition(.move(edge: .top).combined(with: .opacity))
                    } else {
                        inventoryGrid
                    }
                }
                .panelMenuExpansion(.topBarDrops)
            }
            .padding(20)
            .frame(width: 920)
            .background(.black.opacity(0.72))
            .glassBackgroundEffect()
        }
    }

    @ViewBuilder
    private var inventoryGrid: some View {
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

        HStack(spacing: 10) {
            if flight.isFabricatorAvailable {
                Button("REFINERY") { flight.openRefineryPanel() }
                    .buttonStyle(.borderedProminent)
                    .tint(.mint)
            }
            if let equipped = flight.equippedInventoryItem {
                if equipped.isRelic {
                    Button("OPEN RELIC") { flight.openEquippedRelic() }
                        .buttonStyle(.borderedProminent)
                        .tint(.yellow)
                        .disabled(equipped.relicCanOpen != true)
                }
                if equipped.isEnergyCube {
                    Button("USE CUBE") {
                        flight.useEnergyCube(itemID: equipped.id)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                }
                if flight.isFabricatorAvailable,
                   [.log, .mineral, .electronic, .creatureMaterial, .relic]
                    .contains(equipped.category),
                   !equipped.isEnergyCube {
                    Button("REFINE 1") {
                        flight.refineInventoryItem(equipped.id)
                    }
                    .buttonStyle(.bordered)
                }
            }
            Text(
                "Energy \(Int(flight.organicEnergy))/\(Int(flight.organicEnergyCapacity))"
                    + " • Fuel \(Int(flight.shipFuel))"
            )
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }

        Text(
            "Select to equip • Relic Key points to Relics • scan before harvest for +33%"
        )
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private var settingsPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("SETTINGS", systemImage: "gearshape.fill")
                    .font(.title3.bold())
                Spacer()
                if flight.isPaused {
                    Text("PAUSED")
                        .font(.caption.bold())
                        .foregroundStyle(.orange)
                }
                Text(flight.gameDifficulty.rawValue.uppercased())
                    .font(.caption.bold())
                    .foregroundStyle(.cyan)
            }

            Text("Dominant hand (settings only — gestures no longer switch)")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            handednessRow(
                title: "Ship",
                selection: flight.shipDominantHand
            ) { flight.setShipDominantHand($0) }
            handednessRow(
                title: "Walking",
                selection: flight.walkingDominantHand
            ) { flight.setWalkingDominantHand($0) }
            handednessRow(
                title: "Rover",
                selection: flight.roverDominantHand
            ) { flight.setRoverDominantHand($0) }

            VStack(alignment: .leading, spacing: 8) {
                Toggle(isOn: Binding(
                    get: { flight.showPeopleWhilePlaying },
                    set: { flight.setShowPeopleWhilePlaying($0) }
                )) {
                    Text("Show people while playing")
                        .font(.headline)
                }
                Text(
                    "On by default. Uses progressive immersion so nearby"
                        + " people can appear (Digital Crown adjusts immersion)."
                        + " Also requires People Awareness in visionOS Settings"
                        + " → Awareness & Safety → Show People Through"
                        + " → Environments and Immersive Apps."
                )
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            if let prompt = flight.settingsResetPrompt {
                resetDifficultyChooser(prompt)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Progress")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Button {
                        pendingDifficulty = flight.gameDifficulty
                        flight.beginSettingsResetPrompt(.fullReset)
                    } label: {
                        Label(
                            "Reset game data",
                            systemImage: "arrow.counterclockwise.circle"
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)

                    Text(
                        "Returns you to the starting station and clears"
                            + " inventory & Mon (§)."
                    )
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                    Button {
                        pendingDifficulty = flight.gameDifficulty
                        flight.beginSettingsResetPrompt(.worldResetKeepStuff)
                    } label: {
                        Label(
                            "Reset world (keep stuff) • TEST",
                            systemImage: "wrench.and.screwdriver"
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.bordered)
                    .tint(.orange)

                    Text(
                        "Testing only — relocate + change difficulty,"
                            + " keep inventory. Removed at ship."
                    )
                    .font(.caption2)
                    .foregroundStyle(.orange.opacity(0.85))
                }
            }

            Button("Resume") {
                flight.closeSettingsMenu()
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
        }
    }

    private func handednessRow(
        title: String,
        selection: DominantHandSetting,
        onSelect: @escaping (DominantHandSetting) -> Void
    ) -> some View {
        HStack {
            Text(title)
                .font(.headline)
                .frame(width: 90, alignment: .leading)
            ForEach(DominantHandSetting.allCases, id: \.self) { hand in
                Button {
                    onSelect(hand)
                } label: {
                    Text(hand == .right ? "Right" : "Left")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            selection == hand
                                ? Color.cyan.opacity(0.35)
                                : Color.white.opacity(0.08)
                        )
                        .clipShape(.rect(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func resetDifficultyChooser(
        _ prompt: SettingsResetPrompt
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(
                prompt == .fullReset
                    ? "Reset game — choose difficulty"
                    : "World reset (keep stuff) — choose difficulty"
            )
            .font(.headline)

            ForEach(GameDifficulty.allCases, id: \.self) { difficulty in
                Button {
                    pendingDifficulty = difficulty
                } label: {
                    HStack(alignment: .top) {
                        Image(
                            systemName: pendingDifficulty == difficulty
                                ? "checkmark.circle.fill"
                                : "circle"
                        )
                        .foregroundStyle(
                            pendingDifficulty == difficulty ? .cyan : .secondary
                        )
                        VStack(alignment: .leading, spacing: 2) {
                            Text(difficulty.rawValue)
                                .font(.headline)
                            Text(difficulty.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(10)
                    .background(.white.opacity(0.08))
                    .clipShape(.rect(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }

            HStack {
                Button("Cancel") {
                    flight.cancelSettingsResetPrompt()
                }
                .buttonStyle(.bordered)
                Spacer()
                Button(
                    prompt == .fullReset
                        ? "Reset & start"
                        : "Reset world"
                ) {
                    flight.confirmSettingsReset(
                        difficulty: pendingDifficulty,
                        keepInventoryAndCredits:
                            prompt == .worldResetKeepStuff
                    )
                }
                .buttonStyle(.borderedProminent)
                .tint(prompt == .fullReset ? .red : .orange)
            }
        }
        .padding(12)
        .background(.black.opacity(0.35))
        .clipShape(.rect(cornerRadius: 12))
    }

    private func inventoryButton(_ item: InventoryItem) -> some View {
        let iconName: String = switch item.category {
        case .log: "tree.fill"
        case .mineral: "diamond.fill"
        case .electronic: "cpu.fill"
        case .creatureMaterial: "pawprint.fill"
        case .relic: "crown.fill"
        case .relicKey: "key.fill"
        case .element: "atom"
        case .blueprint: "doc.text.fill"
        case .module: "cpu"
        }
        let iconColor: Color = switch item.category {
        case .log: .green
        case .mineral: .cyan
        case .electronic: .orange
        case .creatureMaterial: .pink
        case .relic: .yellow
        case .relicKey: .purple
        case .element: .mint
        case .blueprint: .white
        case .module: .blue
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

private struct StationShopView: View {
    @Environment(FlightModel.self) private var flight

    var body: some View {
        if flight.isStationShopPresented {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("STATION SHOP", systemImage: "cart.fill")
                        .font(.title3.bold())
                    Spacer()
                    Text(ProgressionEconomy.formatMon(flight.mon))
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(.yellow)
                    Button("CLOSE") { flight.closeStationShop() }
                        .buttonStyle(.bordered)
                }
                ForEach(ProgressionEconomy.ShopSKU.allCases) { sku in
                    Button {
                        flight.purchaseShopSKU(sku)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(sku.title).font(.headline)
                                Spacer()
                                Text(ProgressionEconomy.formatMon(sku.priceMon))
                                    .foregroundStyle(.yellow)
                            }
                            Text(sku.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(.white.opacity(0.08))
                        .clipShape(.rect(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
            .frame(width: 720)
            .background(.black.opacity(0.78))
            .glassBackgroundEffect()
        }
    }
}

private struct RefineryFabricatorView: View {
    @Environment(FlightModel.self) private var flight

    /// Fits between top HUD and lower cockpit / leave-ship controls.
    private let panelWidth: CGFloat = 560
    private let panelMaxHeight: CGFloat = 360
    private let dismissPlaneWidth: CGFloat = 1_100
    private let dismissPlaneHeight: CGFloat = 640

    var body: some View {
        if flight.isRefineryPresented {
            ZStack {
                Button {
                    flight.closeRefineryPanel()
                } label: {
                    Color.black.opacity(0.22)
                        .frame(
                            width: dismissPlaneWidth,
                            height: dismissPlaneHeight
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close refinery")

                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        Label(
                            "FABRICATOR",
                            systemImage: "hammer.fill"
                        )
                        .font(.headline.bold())
                        Spacer(minLength: 8)
                        Text(
                            "E \(Int(flight.organicEnergy))"
                                + "/\(Int(flight.organicEnergyCapacity))"
                        )
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.green)
                        Button("CLOSE") { flight.closeRefineryPanel() }
                            .buttonStyle(.borderedProminent)
                            .tint(.secondary)
                            .controlSize(.small)
                    }

                    Button("CONVERT LOGS → ENERGY") {
                        _ = flight.convertLogsToEnergy()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .disabled(!flight.canConvertLogsToEnergy)
                    .opacity(flight.canConvertLogsToEnergy ? 1 : 0.45)

                    Text("Craft")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)

                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            ForEach(ProgressionEconomy.craftRecipes) { recipe in
                                craftRecipeRow(recipe)
                            }
                        }
                        .padding(.trailing, 4)
                    }
                    .scrollIndicators(.visible)

                    Text(
                        "Equip an inventory item, then REFINE 1 from the kit."
                    )
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
                .padding(16)
                .frame(
                    width: panelWidth,
                    height: panelMaxHeight,
                    alignment: .top
                )
                .background(.black.opacity(0.82))
                .glassBackgroundEffect()
                .clipShape(.rect(cornerRadius: 16))
            }
            .frame(
                width: dismissPlaneWidth,
                height: dismissPlaneHeight
            )
            .allowsHitTesting(true)
        }
    }

    @ViewBuilder
    private func craftRecipeRow(
        _ recipe: ProgressionEconomy.CraftRecipe
    ) -> some View {
        let craftable = flight.canCraftRecipe(recipe)
        let ingredients = flight.recipeIngredientStatuses(recipe)
        Button {
            _ = flight.craftRecipe(recipe.id)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(recipe.title)
                    .font(
                        craftable
                            ? .subheadline.bold()
                            : .subheadline
                    )
                    .foregroundStyle(
                        craftable
                            ? Color.primary
                            : Color.secondary.opacity(0.55)
                    )
                recipeIngredientsLine(ingredients)
                if let note = craftRecipeNote(recipe) {
                    Text(note)
                        .font(.caption2)
                        .foregroundStyle(.secondary.opacity(0.7))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .background(
                craftable
                    ? Color.white.opacity(0.12)
                    : Color.white.opacity(0.04)
            )
            .clipShape(.rect(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .disabled(!craftable)
    }

    private func recipeIngredientsLine(
        _ ingredients: [(id: String, label: String, satisfied: Bool)]
    ) -> Text {
        var combined = Text("")
        for (index, ingredient) in ingredients.enumerated() {
            if index > 0 {
                combined = combined
                    + Text(" • ")
                    .font(.caption2)
                    .foregroundColor(Color.secondary.opacity(0.45))
            }
            combined = combined
                + Text(ingredient.label)
                .font(
                    ingredient.satisfied
                        ? .caption2.bold()
                        : .caption2
                )
                .foregroundColor(
                    ingredient.satisfied
                        ? Color.primary
                        : Color.secondary.opacity(0.5)
                )
        }
        return combined
    }

    private func craftRecipeNote(
        _ recipe: ProgressionEconomy.CraftRecipe
    ) -> String? {
        var notes: [String] = []
        if let recharge = recipe.energyCubeRecharge {
            notes.append("single-use +\(Int(recharge)) energy")
        }
        if let fuel = recipe.shipFuelAmount {
            notes.append("+\(Int(fuel)) ship fuel")
        }
        if let bonus = recipe.energyCapacityBonus {
            notes.append("permanent +\(Int(bonus)) capacity")
        }
        if recipe.blueprintID != nil {
            notes.append("needs blueprint")
        }
        if let required = recipe.requiredStorageExpansions, required > 0 {
            notes.append("requires prior storage \(required)")
        }
        return notes.isEmpty ? nil : notes.joined(separator: " • ")
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
                    Text("FUEL \(Int(flight.shipFuel))")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(
                            flight.shipFuel < 20 ? .red : .orange
                        )
                    Text(ProgressionEconomy.formatMon(flight.mon))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.yellow)
                    Text("SECTOR \(flight.currentRegion)")
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
                // Ship shield meter lives on the center console above Shield.
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
            compactMeter(
                "ENERGY",
                value: flight.organicEnergy,
                maximum: flight.organicEnergyCapacity,
                tint: .green
            )
            if flight.activeExplorationMode == "Leave on foot",
               flight.displayedJetpackFuel < FlightModel.jetpackFuelCapacity - 0.05 {
                compactMeter(
                    "ROCKET",
                    value: flight.displayedJetpackFuel,
                    maximum: FlightModel.jetpackFuelCapacity,
                    tint: .yellow
                )
            }
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

/// Expansion direction for panel-attached menus.
/// - `bottomBarRaises`: options appear above the trigger (lower cockpit bar).
/// - `topBarDrops`: options appear below the trigger (inventory / top bars).
private enum PanelMenuExpansion {
    case bottomBarRaises
    case topBarDrops
}

private extension View {
    func panelMenuExpansion(_ expansion: PanelMenuExpansion) -> some View {
        // Marker for layout audits — keeps top/bottom menu direction explicit.
        accessibilityHint(
            expansion == .bottomBarRaises
                ? "Menu expands upward from the bottom bar"
                : "Menu expands downward from the top bar"
        )
    }
}

/// Floating bar for outside-ship actions (enter ship / rover / etc.).
private struct OutsideShipControlBar: View {
    @Environment(FlightModel.self) private var flight

    private var shouldShow: Bool {
        flight.isOutsideShip
            && (
                !flight.isSurfaceExploration
                    || flight.activeExplorationMode == "Deploy rover"
                    || flight.canEnterShip
                    || flight.canEnterRover
                    || flight.isFabricatorAvailable
            )
    }

    var body: some View {
        Group {
            if shouldShow {
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
                    if !flight.isSurfaceExploration || flight.canEnterShip {
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
                    if flight.isFabricatorAvailable {
                        Button(
                            "FABRICATOR",
                            systemImage: "hammer.fill"
                        ) {
                            flight.openRefineryPanel()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.mint)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .glassBackgroundEffect()
            }
        }
    }
}

private struct FlightConsoleFarLeftFacet: View {
    @Environment(FlightModel.self) private var flight

    var body: some View {
        Group {
            if !flight.isOutsideShip {
                consoleFacetChrome {
                    ConsoleLampStation(
                        caption: "AUTO-PILOT",
                        padLabel: flight.autopilot
                            || flight.isAutopilotMenuPresented
                            ? "ON" : "OFF",
                        isLit: flight.autopilot
                            || flight.isAutopilotMenuPresented
                            || flight.autopilotConsoleFlashing,
                        litColor: .green,
                        disabled: !flight.canPresentDetectionPicker
                            && !flight.autopilot
                    ) {
                        flight.toggleAutopilotConsole()
                    }
                    .opacity(
                        flight.autopilotConsoleFlashing
                            && !flight.autopilot ? 0.45 : 1
                    )

                    ConsoleLampStation(
                        caption: "FABRICATOR",
                        padLabel: flight.consolePage == .fabricator
                            ? "ON" : "OFF",
                        isLit: flight.consolePage == .fabricator,
                        litColor: .mint,
                        disabled: !flight.isFabricatorAvailable
                    ) {
                        flight.toggleFabricatorConsole()
                    }
                }
                .frame(width: 300, height: 480)
            }
        }
    }
}

private struct FlightConsoleVideoFacet: View {
    let title: String

    var body: some View {
        consoleFacetChrome {
            Text(title)
                .font(.caption.bold().monospaced())
                .foregroundStyle(.cyan.opacity(0.35))
            Spacer()
        }
        .frame(width: 300, height: 480)
    }
}

private struct FlightConsoleReadoutFacet: View {
    @Environment(FlightModel.self) private var flight

    var body: some View {
        Group {
            if !flight.isOutsideShip {
                consoleFacetChrome {
                    switch flight.consolePage {
                    case .fabricator:
                        FabricatorReadout()
                    case .autopilot:
                        AutopilotCategoryReadout()
                    case .autopilotPlanets:
                        AutopilotPlanetReadout()
                    case .autopilotStations:
                        KnownTargetReadout(
                            title: "STATIONS",
                            nearestTitle: "NEAREST STATION",
                            kind: .station
                        )
                    case .autopilotDebris:
                        KnownTargetReadout(
                            title: "SPACE DEBRIS",
                            nearestTitle: "NEAREST DEBRIS",
                            kind: .wreckage
                        )
                    case .engineStart:
                        EngineAnimationReadout(starting: true)
                    case .engineStop:
                        EngineAnimationReadout(starting: false)
                    case .standby:
                        Text("SELECT A SYSTEM")
                            .font(.caption.bold().monospaced())
                            .foregroundStyle(.cyan.opacity(0.45))
                        if !flight.interactionStatus.isEmpty {
                            Text(flight.interactionStatus)
                                .font(.caption2.monospaced())
                                .foregroundStyle(.cyan)
                                .multilineTextAlignment(.center)
                        }
                        Spacer()
                    }
                }
                .frame(width: 340, height: 520)
            }
        }
    }
}

private struct FabricatorReadout: View {
    @Environment(FlightModel.self) private var flight

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("FABRICATOR")
                .font(.caption.bold().monospaced())
                .foregroundStyle(.mint)
            Button("CONVERT LOGS → ENERGY") {
                _ = flight.convertLogsToEnergy()
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .disabled(!flight.canConvertLogsToEnergy)
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(ProgressionEconomy.craftRecipes) { recipe in
                        Button(recipe.title) {
                            _ = flight.craftRecipe(recipe.id)
                        }
                        .buttonStyle(.bordered)
                        .tint(.mint)
                        .disabled(!flight.canCraftRecipe(recipe))
                    }
                }
            }
        }
    }
}

private struct AutopilotCategoryReadout: View {
    @Environment(FlightModel.self) private var flight

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("AUTO-PILOT")
                .font(.caption.bold().monospaced())
                .foregroundStyle(.green)
            if !flight.hasNavModule {
                Text(flight.detectionLockReason)
                    .font(.caption2)
                    .foregroundStyle(.orange)
            } else {
                Button("PLANET") { flight.consolePage = .autopilotPlanets }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                Button("STATION") { flight.consolePage = .autopilotStations }
                    .buttonStyle(.borderedProminent)
                    .tint(.cyan)
                Button("SPACE DEBRIS") { flight.consolePage = .autopilotDebris }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                Button("CLEAR TARGET") { flight.cancelAutopilotTarget() }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .disabled(!flight.hasAutopilotTarget)
            }
            Spacer()
        }
    }
}

private struct AutopilotPlanetReadout: View {
    @Environment(FlightModel.self) private var flight

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PLANET")
                .font(.caption.bold().monospaced())
                .foregroundStyle(.green)
            Button("NEAREST PLANET") {
                flight.engageNearestPlanet()
            }
            Button("AIRLESS PLANET") {
                flight.engageNearestPlanet(airless: true)
            }
            Button("GAS PLANET") {
                flight.engageNearestPlanet(kind: .gas)
            }
            Button("ICE PLANET") {
                flight.engageNearestPlanet(kind: .ice)
            }
            Button("FIRE PLANET") {
                flight.engageNearestPlanet(kind: .desert)
            }
            Button("BACK") { flight.consolePage = .autopilot }
                .tint(.secondary)
            Spacer()
        }
        .buttonStyle(.borderedProminent)
    }
}

private struct KnownTargetReadout: View {
    @Environment(FlightModel.self) private var flight
    let title: String
    let nearestTitle: String
    let kind: NavigationTargetKind

    var body: some View {
        let known = flight.knownConsoleDestinations(kind)
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.bold().monospaced())
                .foregroundStyle(.cyan)
            Button(nearestTitle) {
                flight.detectNearest(kind)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    if known.isEmpty {
                        Text("No previous visits in range")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(known, id: \.identifier) { target in
                        Button(
                            "\(target.name)  \(Int(target.distance)) m"
                        ) {
                            flight.engageAutopilot(toward: target)
                        }
                        .buttonStyle(.bordered)
                        .tint(.cyan)
                    }
                }
            }
            Button("BACK") {
                flight.consolePage = .autopilot
            }
            .buttonStyle(.bordered)
            .tint(.secondary)
        }
    }
}

private struct EngineAnimationReadout: View {
    let starting: Bool
    @Environment(FlightModel.self) private var flight

    var body: some View {
        let progress = 1 - min(1, flight.engineAnimRemaining / 1.6)
        VStack(spacing: 12) {
            Text(starting ? "ENGINES STARTING" : "ENGINES SHUTTING DOWN")
                .font(.caption.bold().monospaced())
                .foregroundStyle(starting ? .cyan : .orange)
            HStack(spacing: 8) {
                ForEach(0..<5, id: \.self) { index in
                    let lit = starting
                        ? progress > Double(index) / 5
                        : progress < Double(5 - index) / 5
                    RoundedRectangle(cornerRadius: 3)
                        .fill(lit ? Color.cyan : Color.white.opacity(0.12))
                        .frame(width: 18, height: lit ? 70 : 24)
                }
            }
            Spacer()
        }
    }
}

private struct FlightConsoleSystemsFacet: View {
    @Environment(FlightModel.self) private var flight

    var body: some View {
        Group {
            if !flight.isOutsideShip {
                consoleFacetChrome {
                    ConsoleLampStation(
                        caption: flight.isWeaponArmed
                            ? flight.currentWeapon
                            : " ",
                        padLabel: flight.isWeaponArmed ? "ARMED" : "DISARMED",
                        isLit: flight.isWeaponArmed,
                        litColor: .red,
                        disabled: !flight.canCycleWeapons
                    ) {
                        flight.cycleWeapon()
                    }

                    VStack(spacing: 6) {
                        HStack(spacing: 8) {
                            Text("SHIELD")
                                .font(.caption2.bold().monospaced())
                                .foregroundStyle(.secondary)
                            ProgressView(
                                value: Double(max(0, flight.shipShield)),
                                total: 500
                            )
                            .tint(.cyan)
                            Text("\(Int(flight.shipShield.rounded()))")
                                .font(.caption2.monospacedDigit())
                                .frame(width: 36, alignment: .trailing)
                        }
                        .opacity(flight.isShipShieldActive ? 1 : 0.45)

                        ConsoleLampStation(
                            caption: "SHIELD",
                            padLabel: flight.isShipShieldActive ? "ON" : "OFF",
                            isLit: flight.isShipShieldActive,
                            litColor: .blue,
                            disabled: false
                        ) {
                            flight.toggleShipShield()
                        }
                    }
                }
                .frame(width: 300, height: 480)
            }
        }
    }
}

private struct FlightConsoleFarRightFacet: View {
    @Environment(FlightModel.self) private var flight
    @State private var isExitMenuPresented = false

    var body: some View {
        Group {
            if !flight.isOutsideShip {
                VStack(spacing: 8) {
                    if isExitMenuPresented {
                        VStack(alignment: .trailing, spacing: 6) {
                            ForEach(flight.availableExitOptions, id: \.self) { option in
                                Button(option) {
                                    flight.selectExitOption(option)
                                    isExitMenuPresented = false
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.orange)
                            }
                        }
                    }
                    consoleFacetChrome {
                        ConsoleLampStation(
                            caption: "ENGINES",
                            padLabel: flight.enginesRunning ? "ON" : "OFF",
                            isLit: flight.enginesRunning,
                            litColor: .cyan,
                            disabled: false
                        ) {
                            flight.toggleShipEngines()
                        }

                        ConsoleLampStation(
                            caption: "EXIT",
                            padLabel: "EXIT",
                            isLit: flight.canLeaveShip,
                            litColor: .orange,
                            disabled: !flight.canLeaveShip
                        ) {
                            isExitMenuPresented.toggle()
                        }
                    }
                }
                .frame(width: 300, height: 520, alignment: .bottom)
            }
        }
        .onChange(of: flight.isLanded) { _, landed in
            if landed { isExitMenuPresented = true }
        }
        .onChange(of: flight.canLeaveShip) { _, canLeave in
            if !canLeave { isExitMenuPresented = false }
        }
    }
}

private func consoleFacetChrome<Content: View>(
    @ViewBuilder content: () -> Content
) -> some View {
    VStack(spacing: 14) {
        content()
    }
    .padding(16)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(red: 0.05, green: 0.07, blue: 0.10))
}

private struct ConsoleLampStation: View {
    let caption: String
    let padLabel: String
    let isLit: Bool
    let litColor: Color
    let disabled: Bool
    let action: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            Text(caption)
                .font(.caption.bold().monospaced())
                .foregroundStyle(Color.cyan.opacity(0.7))
                .frame(maxWidth: .infinity)
            Button(action: action) {
                Text(padLabel)
                    .font(.headline.bold().monospaced())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isLit ? litColor : Color(white: 0.22))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(
                                isLit ? Color.white : Color(white: 0.45),
                                lineWidth: 2
                            )
                    )
            }
            .buttonStyle(.plain)
            .disabled(disabled)
            .opacity(disabled ? 0.4 : 1)
        }
    }
}

private struct AutopilotDestinationPicker: View {
    @Environment(FlightModel.self) private var flight
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 10) {
            Text("AUTO-PILOT TARGET")
                .font(.caption.bold().monospaced())
                .foregroundStyle(.green)

            if !flight.hasNavModule {
                Text(flight.detectionLockReason)
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
            } else {
                VStack(spacing: 6) {
                    destinationButton("PLANET", kind: .world)
                    Button("AIRLESS PLANET") {
                        flight.detectNearestAirlessPlanet()
                        isPresented = false
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.indigo)
                    destinationButton("STATION", kind: .station)
                    destinationButton("WRECKAGE", kind: .wreckage)
                    Button("CLEAR TARGET") {
                        flight.cancelAutopilotTarget()
                        isPresented = false
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .disabled(!flight.hasAutopilotTarget)
                }
            }

            Button("CLOSE") { isPresented = false }
                .buttonStyle(.bordered)
                .tint(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(Color.black.opacity(0.78))
        .clipShape(.rect(cornerRadius: 12))
        .panelMenuExpansion(.bottomBarRaises)
    }

    private func destinationButton(
        _ title: String,
        kind: NavigationTargetKind
    ) -> some View {
        Button(title) {
            flight.detectNearest(kind)
            isPresented = false
        }
        .buttonStyle(.borderedProminent)
        .tint(.green)
    }
}

@MainActor
private final class ControllerObserver {
    private weak var flight: FlightModel?
    private var connectObserver: NSObjectProtocol?
    private var disconnectObserver: NSObjectProtocol?
    private var leftStickX: Float = 0
    private var leftStickY: Float = 0
    private var leftShoulderHeld = false
    private var leftStickClicked = false
    private var rightTriggerValue: Float = 0
    private var rightTriggerWasPressed = false
    private var lastToolUpdateTime = ProcessInfo.processInfo.systemUptime
    private var toolPulseTask: Task<Void, Never>?

    func connect(to flight: FlightModel) {
        self.flight = flight
        GCController.controllers().forEach(configure)
        connectObserver = NotificationCenter.default.addObserver(
            forName: .GCControllerDidConnect,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                GCController.controllers().forEach {
                    self?.configure($0)
                }
            }
        }
        disconnectObserver = NotificationCenter.default.addObserver(
            forName: .GCControllerDidDisconnect,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.clearSurfaceLocomotion()
            }
        }
        startToolPulse()
    }

    func disconnect() {
        toolPulseTask?.cancel()
        toolPulseTask = nil
        if let connectObserver {
            NotificationCenter.default.removeObserver(connectObserver)
        }
        if let disconnectObserver {
            NotificationCenter.default.removeObserver(disconnectObserver)
        }
        connectObserver = nil
        disconnectObserver = nil
        clearSurfaceLocomotion()
        flight?.pitchInput = 0
        flight?.yawInput = 0
        flight?.rollInput = 0
        flight?.throttle = 0
        flight = nil
    }

    private func startToolPulse() {
        toolPulseTask?.cancel()
        toolPulseTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 16_000_000)
                await MainActor.run {
                    self?.pulseControllerTool()
                }
            }
        }
    }

    private func pulseControllerTool() {
        guard let flight,
              !flight.isPaused,
              flight.activeExplorationMode == "Leave on foot" else {
            return
        }
        let now = ProcessInfo.processInfo.systemUptime
        let dt = Float(min(0.05, max(0, now - lastToolUpdateTime)))
        lastToolUpdateTime = now
        // Gamepad fallback: pose equipped inventory (Relic Key beam origin)
        // only when hand tracking hasn't updated recently.
        let handPoseAge =
            now - flight.lastHeldInventoryHandPoseTime
        if flight.equippedInventoryItem != nil,
           handPoseAge > 0.28,
           let head = flight.aimAnchorEntity {
            let forward = head.orientation.act(SIMD3<Float>(0, 0, -1))
            let origin =
                head.position(relativeTo: nil)
                + forward * 0.32
                + SIMD3<Float>(0, -0.12, 0)
            flight.updateHeldInventoryItemPose(
                position: origin,
                pointingDirection: forward
            )
        }
        let pressed = rightTriggerValue > 0.35
        flight.updateControllerSurfaceTool(
            pressed: pressed,
            wasPressed: rightTriggerWasPressed,
            deltaTime: dt
        )
        rightTriggerWasPressed = pressed
    }

    private func clearSurfaceLocomotion() {
        guard let flight else { return }
        if flight.activeExplorationMode == "Leave on foot" {
            flight.setExplorationControls(forward: 0, turn: 0)
            flight.setControllerRunHeld(false)
            flight.setJetpackThrusting(false)
            flight.stopMatterCrumblerBeam()
        } else if flight.activeExplorationMode == "Deploy rover" {
            flight.setExplorationControls(forward: 0, turn: 0)
        }
    }

    private func configure(_ controller: GCController) {
        guard let gamepad = controller.extendedGamepad else { return }

        gamepad.leftThumbstick.valueChangedHandler = { [weak self] _, x, y in
            Task { @MainActor in
                guard let self else { return }
                self.leftStickX = x
                self.leftStickY = y
                self.applyLeftStick()
            }
        }
        gamepad.leftThumbstickButton?.pressedChangedHandler = {
            [weak self] _, _, pressed in
            Task { @MainActor in
                self?.leftStickClicked = pressed
                self?.applyLeftStick()
            }
        }
        gamepad.rightThumbstick.xAxis.valueChangedHandler = { [weak self] _, value in
            Task { @MainActor in
                guard let self, let flight = self.flight else { return }
                if flight.isPaused
                    || flight.isSurfaceExploration
                    || flight.autopilot
                    || !flight.enginesRunning {
                    if !flight.enginesRunning {
                        flight.rollInput = 0
                    }
                    return
                }
                flight.rollInput = Double(value)
            }
        }
        gamepad.rightTrigger.valueChangedHandler = { [weak self] _, value, _ in
            Task { @MainActor in
                guard let self, let flight = self.flight else { return }
                self.rightTriggerValue = value
                if flight.isPaused
                    || flight.autopilot
                    || !flight.enginesRunning
                    || flight.activeExplorationMode == "Leave on foot"
                    || flight.activeExplorationMode == "Deploy rover" {
                    return
                }
                flight.throttle = Double(value)
            }
        }
        gamepad.leftTrigger.valueChangedHandler = { [weak self] _, value, _ in
            Task { @MainActor in
                guard let flight = self?.flight,
                      !flight.isPaused,
                      !flight.autopilot,
                      flight.enginesRunning,
                      !flight.isSurfaceExploration else { return }
                if value > 0.08 {
                    flight.throttle = Double(-value * 0.5)
                }
            }
        }
        gamepad.buttonA.pressedChangedHandler = { [weak self] _, _, pressed in
            Task { @MainActor in
                guard let self, let flight = self.flight else { return }
                if flight.isPaused { return }
                if flight.activeExplorationMode == "Leave on foot" {
                    flight.setJetpackThrusting(pressed)
                    return
                }
                guard pressed else { return }
                if flight.activeExplorationMode == "Deploy rover" {
                    flight.leaveRover()
                    return
                }
                if flight.hasAutopilotTarget {
                    flight.toggleAutopilotFromConsole()
                } else {
                    flight.autopilot = false
                }
            }
        }
        gamepad.buttonB.pressedChangedHandler = { [weak self] _, _, pressed in
            guard pressed else { return }
            Task { @MainActor in
                guard let flight = self?.flight, !flight.isPaused else { return }
                if flight.isSurfaceExploration {
                    flight.boardNearestSurfaceVehicle()
                    return
                }
                flight.stop()
            }
        }
        gamepad.buttonX.pressedChangedHandler = { [weak self] _, _, pressed in
            guard pressed else { return }
            Task { @MainActor in
                guard let flight = self?.flight,
                      !flight.isPaused,
                      flight.activeExplorationMode == "Leave on foot" else {
                    return
                }
                flight.collectWithControllerGaze()
            }
        }
        gamepad.buttonY.pressedChangedHandler = { [weak self] _, _, pressed in
            guard pressed else { return }
            Task { @MainActor in
                guard let flight = self?.flight else { return }
                if flight.isSurfaceExploration || flight.canPresentInventory {
                    flight.toggleSurfaceKit()
                }
            }
        }
        gamepad.leftShoulder.pressedChangedHandler = { [weak self] _, _, pressed in
            Task { @MainActor in
                guard let self else { return }
                self.leftShoulderHeld = pressed
                self.applyLeftStick()
                guard pressed,
                      let flight = self.flight,
                      !flight.isPaused,
                      flight.activeExplorationMode == "Leave on foot" else {
                    return
                }
                flight.cycleSurfaceTool(by: -1)
            }
        }
        gamepad.rightShoulder.pressedChangedHandler = { [weak self] _, _, pressed in
            guard pressed else { return }
            Task { @MainActor in
                guard let flight = self?.flight,
                      !flight.isPaused,
                      flight.activeExplorationMode == "Leave on foot" else {
                    return
                }
                flight.cycleSurfaceTool(by: 1)
            }
        }
        gamepad.dpad.up.pressedChangedHandler = { [weak self] _, _, pressed in
            guard pressed else { return }
            Task { @MainActor in
                guard let flight = self?.flight else { return }
                if flight.isSurfaceExploration || flight.canPresentInventory {
                    flight.toggleSurfaceKit()
                }
            }
        }
    }

    private func applyLeftStick() {
        guard let flight, !flight.isPaused else { return }
        if flight.activeExplorationMode == "Leave on foot" {
            let forward = Double(max(0, leftStickY))
            flight.setExplorationControls(forward: forward, turn: 0)
            let moving = leftStickY > 0.15
            let run =
                moving
                    && (leftStickClicked || leftShoulderHeld)
            flight.setControllerRunHeld(run)
            return
        }
        if flight.activeExplorationMode == "Deploy rover" {
            flight.setExplorationControls(
                forward: Double(leftStickY),
                turn: Double(leftStickX)
            )
            return
        }
        if flight.autopilot || !flight.enginesRunning {
            flight.yawInput = 0
            flight.pitchInput = 0
            flight.rollInput = 0
            return
        }
        flight.yawInput = Double(-leftStickX)
        flight.pitchInput = Double(leftStickY)
    }
}
