import RealityKit
import simd
import UIKit

enum SpaceSceneBuilder {
    /// Shared post-pass group so aiming + directional cues draw above world
    /// geometry in a stable order relative to each other.
    @MainActor
    static let hudOverlaySortGroup = ModelSortGroup(depthPass: .postPass)

    /// Cached Poly Haven circuit-board USDZ used for robot salvage drops.
    @MainActor
    private static var circuitBoardTemplate: Entity?

    @MainActor
    static func makeScene() -> Entity {
        let root = Entity()
        root.name = "Universe"
        preloadCircuitBoardTemplate()
        return root
    }

    /// Loads `Resources/CircuitBoard/CircuitBoard.usdz` once for cloning.
    @MainActor
    static func preloadCircuitBoardTemplate() {
        guard circuitBoardTemplate == nil else { return }
        guard let url = Bundle.main.url(
            forResource: "CircuitBoard",
            withExtension: "usdz",
            subdirectory: "Resources/CircuitBoard"
        ) ?? Bundle.main.url(
            forResource: "CircuitBoard",
            withExtension: "usdz"
        ) else {
            return
        }
        circuitBoardTemplate = try? Entity.load(contentsOf: url)
    }

    /// Salvage circuit board (robot wreckage / held prop). Uses authored USDZ when available.
    /// Mesh is flat in XY with the short axis on Z (~0.07 m thick).
    @MainActor
    static func makeCircuitBoardPickup(
        name: String = "Loose Electronic|Circuit Board",
        heldInPalm: Bool = false
    ) -> Entity {
        preloadCircuitBoardTemplate()
        let board: Entity
        if let template = circuitBoardTemplate {
            board = template.clone(recursive: true)
            board.name = name
        } else {
            board = makeFallbackCircuitBoardModel(name: name)
        }

        if heldInPalm {
            // USDZ is Y-up with the short axis on Y after export. Hand grip
            // uses +Y = palm-out, so identity lays the board in the palm
            // (plate grip). A ±90° tip puts the short axis along the arm
            // (spinning-plate-on-a-stick) — avoid that.
            board.orientation = simd_quatf(angle: 0, axis: [0, 1, 0])
            board.position = [0, 0.02, -0.06]
            board.scale = SIMD3<Float>(repeating: 0.55)
        } else {
            // Ground drop: same Y-up rest pose, slightly above the surface.
            board.orientation = simd_quatf(angle: 0, axis: [0, 1, 0])
            board.position = [0, 0.04, 0]
        }
        return board
    }

    @MainActor
    private static func makeFallbackCircuitBoardModel(
        name: String
    ) -> Entity {
        var material = PhysicallyBasedMaterial()
        if let url = Bundle.main.url(
            forResource: "circuit_board_diff",
            withExtension: "jpg",
            subdirectory: "Resources/CircuitBoard"
        ) ?? Bundle.main.url(
            forResource: "circuit_board_diff",
            withExtension: "jpg"
        ),
           let image = UIImage(contentsOfFile: url.path)?.cgImage,
           let texture = try? TextureResource(
            image: image,
            options: .init(semantic: .color)
           ) {
            material.baseColor = .init(texture: .init(texture))
            material.metallic = .init(floatLiteral: 0.35)
            material.roughness = .init(floatLiteral: 0.45)
        } else {
            material.baseColor = .init(
                tint: UIColor(red: 0.04, green: 0.38, blue: 0.18, alpha: 1)
            )
            material.metallic = .init(floatLiteral: 0.4)
            material.roughness = .init(floatLiteral: 0.4)
        }
        // Match USDZ: wide XY face, short Z thickness.
        let board = ModelEntity(
            mesh: .generateBox(
                width: 0.36,
                height: 0.28,
                depth: 0.03,
                cornerRadius: 0.01
            ),
            materials: [material]
        )
        board.name = name
        return board
    }

    @MainActor
    static func makeAtmosphereEnvironment() -> Entity {
        let environment = Entity()
        environment.name = "Atmosphere Environment"
        environment.isEnabled = false

        let sky = ModelEntity(
            mesh: .generateSphere(radius: 260),
            materials: [
                UnlitMaterial(
                    color: UIColor.systemBlue.withAlphaComponent(0)
                )
            ]
        )
        sky.name = "Atmosphere Sky"
        // Render the sphere from inside so it surrounds the player instead of
        // appearing as a flat HUD panel.
        sky.scale.x = -1
        environment.addChild(sky)

        let lightDirections: [SIMD3<Float>] = [
            [0, -1, -1],
            [0, 1, 1],
            [-1, 0, 0],
            [1, 0, 0],
            [0, -1, 1],
            [0, 1, -1]
        ]
        for (index, direction) in lightDirections.enumerated() {
            let light = DirectionalLight()
            light.name = "Atmosphere Fill Light \(index + 1)"
            light.light.color = .white
            light.light.intensity = 0
            light.orientation = simd_quatf(
                from: SIMD3<Float>(0, 0, -1),
                to: simd_normalize(direction)
            )
            environment.addChild(light)
        }
        return environment
    }

    @MainActor
    static func makeSurfaceToolMenu() -> Entity {
        let menu = Entity()
        menu.name = "Forearm Tool Menu"
        menu.isEnabled = false

        let backing = ModelEntity(
            mesh: .generateBox(width: 0.34, height: 0.075, depth: 0.008),
            materials: [
                SimpleMaterial(
                    color: UIColor(white: 0.025, alpha: 0.88),
                    roughness: 0.28,
                    isMetallic: true
                )
            ]
        )
        backing.position.z = -0.008
        menu.addChild(backing)

        let colors: [UIColor] = [
            .systemGray,
            .systemBrown,
            .systemCyan,
            .systemOrange,
            .systemRed,
            .systemGreen
        ]
        let center = Float(SurfaceTool.allCases.count - 1) * 0.5
        for (index, tool) in SurfaceTool.allCases.enumerated() {
            let slot = Entity()
            slot.name = "Tool Slot \(index) • \(tool.rawValue)"
            slot.position.x = (Float(index) - center) * 0.062
            let plate = ModelEntity(
                mesh: .generateBox(
                    width: 0.052,
                    height: 0.052,
                    depth: 0.012
                ),
                materials: [
                    UnlitMaterial(
                        color: colors[index].withAlphaComponent(0.82)
                    )
                ]
            )
            plate.name = "Tool Slot Plate"
            slot.addChild(plate)
            let isEmpty = tool == .empty
            let isAxe = tool == .axe
            let glyph = ModelEntity(
                mesh: .generateBox(
                    width: isEmpty ? 0.025 : (isAxe ? 0.012 : 0.009),
                    height: isAxe ? 0.034 : (isEmpty ? 0.002 : 0.026),
                    depth: isEmpty ? 0.002 : 0.008
                ),
                materials: [UnlitMaterial(color: .white)]
            )
            glyph.name = "Tool Slot Glyph"
            glyph.position.z = 0.009
            glyph.orientation = simd_quatf(
                angle: isAxe ? -0.55 : 0,
                axis: [0, 0, 1]
            )
            slot.addChild(glyph)
            menu.addChild(slot)
        }
        return menu
    }

    @MainActor
    static func makeHeldSurfaceTools() -> Entity {
        let root = Entity()
        root.name = "Dominant Hand Tool"
        root.isEnabled = false

        let empty = Entity()
        empty.name = SurfaceTool.empty.rawValue
        root.addChild(empty)

        let axe = Entity()
        axe.name = SurfaceTool.axe.rawValue
        let axeHandle = ModelEntity(
            mesh: .generateCylinder(height: 0.28, radius: 0.014),
            materials: [
                SimpleMaterial(
                    color: UIColor(red: 0.45, green: 0.28, blue: 0.12, alpha: 1),
                    roughness: 0.7,
                    isMetallic: false
                )
            ]
        )
        let handleRadius: Float = 0.014
        let handleLength: Float = 0.28
        axeHandle.orientation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
        // Handle on Z; tip (away) at −handleLength/2.
        axeHandle.position.z = -handleLength * 0.5 + 0.03
        axe.addChild(axeHandle)
        let tipZ = axeHandle.position.z - handleLength * 0.5
        // 90° from the prior layout so the smallest face lies parallel to
        // the handle (its long edge along Z). Faces by area:
        //   most  ±Y  bladeOut × alongHandle  (blade flats)
        //   mid   ±Z  bladeOut × thickness
        //   least ±X  alongHandle × thickness  ← seated on the handle tip
        let bladeOut: Float = 0.14
        let thickness: Float = 0.04
        let alongHandle: Float = 0.08
        let axeHead = ModelEntity(
            mesh: .generateBox(
                width: bladeOut,
                height: thickness,
                depth: alongHandle
            ),
            materials: [
                SimpleMaterial(
                    color: UIColor(white: 0.55, alpha: 1),
                    roughness: 0.35,
                    isMetallic: true
                )
            ]
        )
        axeHead.position = [
            handleRadius + bladeOut * 0.5,
            0,
            tipZ
        ]
        axe.addChild(axeHead)
        root.addChild(axe)

        let slicer = Entity()
        slicer.name = SurfaceTool.sonicSlicer.rawValue
        let slicerHandle = ModelEntity(
            mesh: .generateCylinder(height: 0.24, radius: 0.012),
            materials: [
                SimpleMaterial(
                    color: UIColor(white: 0.20, alpha: 1),
                    roughness: 0.25,
                    isMetallic: true
                )
            ]
        )
        slicerHandle.orientation = simd_quatf(
            angle: .pi / 2,
            axis: [1, 0, 0]
        )
        slicerHandle.position.z = -0.10
        slicer.addChild(slicerHandle)
        let slicerHead = ModelEntity(
            mesh: .generateBox(width: 0.16, height: 0.095, depth: 0.022),
            materials: [
                UnlitMaterial(
                    color: UIColor.systemCyan.withAlphaComponent(0.92)
                )
            ]
        )
        slicerHead.position = [0, 0.035, -0.22]
        slicerHead.orientation = simd_quatf(
            angle: -0.25,
            axis: [0, 0, 1]
        )
        slicer.addChild(slicerHead)
        root.addChild(slicer)

        let crumbler = makeHandTool(
            name: SurfaceTool.matterCrumbler.rawValue,
            color: .systemOrange,
            bodySize: [0.075, 0.075, 0.18]
        )
        root.addChild(crumbler)
        let launcher = makeHandTool(
            name: SurfaceTool.matterLauncher.rawValue,
            color: .systemRed,
            bodySize: [0.065, 0.09, 0.28]
        )
        root.addChild(launcher)

        let analyzer = Entity()
        analyzer.name = SurfaceTool.analyzer.rawValue
        let analyzerBody = ModelEntity(
            mesh: .generateBox(width: 0.12, height: 0.055, depth: 0.19),
            materials: [
                SimpleMaterial(
                    color: UIColor(white: 0.12, alpha: 1),
                    roughness: 0.36,
                    isMetallic: true
                )
            ]
        )
        analyzerBody.position.z = -0.09
        analyzer.addChild(analyzerBody)
        let analyzerScreen = ModelEntity(
            mesh: .generateBox(width: 0.085, height: 0.002, depth: 0.10),
            materials: [UnlitMaterial(color: .systemGreen)]
        )
        analyzerScreen.position = [0, 0.029, -0.095]
        analyzer.addChild(analyzerScreen)
        root.addChild(analyzer)
        return root
    }

    @MainActor
    static func makeHeldInventoryItem() -> Entity {
        let root = Entity()
        root.name = "Dominant Hand Inventory Item"
        root.isEnabled = false

        let log = ModelEntity(
            mesh: .generateCylinder(height: 0.24, radius: 0.045),
            materials: [
                SimpleMaterial(
                    color: .systemGreen,
                    roughness: 0.72,
                    isMetallic: false
                )
            ]
        )
        log.name = "Held Inventory Log"
        log.orientation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
        log.position.z = -0.10
        root.addChild(log)

        let mineral = ModelEntity(
            mesh: .generateSphere(radius: 0.075),
            materials: [
                SimpleMaterial(
                    color: .systemCyan,
                    roughness: 0.24,
                    isMetallic: true
                )
            ]
        )
        mineral.name = "Held Inventory Mineral"
        mineral.position.z = -0.09
        root.addChild(mineral)

        // Authored circuit-board mesh for held salvage (not the green orb).
        // Palm plate grip: short side against the hand, not edge-on on the arm.
        let circuitBoard = makeCircuitBoardPickup(
            name: "Held Inventory Circuit Board",
            heldInPalm: true
        )
        circuitBoard.isEnabled = false
        root.addChild(circuitBoard)

        let feces = Entity()
        feces.name = "Held Inventory Feces"
        feces.position.z = -0.10
        feces.isEnabled = false
        let fecesMaterial = SimpleMaterial(
            color: UIColor(red: 0.30, green: 0.16, blue: 0.07, alpha: 1),
            roughness: 0.88,
            isMetallic: false
        )
        for (radius, position, scale) in [
            (
                Float(0.065),
                SIMD3<Float>(0, 0, 0),
                SIMD3<Float>(1, 0.62, 0.82)
            ),
            (
                Float(0.052),
                SIMD3<Float>(0, 0.050, -0.004),
                SIMD3<Float>(1, 0.68, 0.86)
            ),
            (
                Float(0.037),
                SIMD3<Float>(0.006, 0.091, -0.007),
                SIMD3<Float>(1, 0.78, 0.90)
            ),
            (
                Float(0.022),
                SIMD3<Float>(0.017, 0.122, -0.006),
                SIMD3<Float>(0.72, 1, 0.78)
            )
        ] {
            let lobe = ModelEntity(
                mesh: .generateSphere(radius: radius),
                materials: [fecesMaterial]
            )
            lobe.position = position
            lobe.scale = scale
            feces.addChild(lobe)
        }
        root.addChild(feces)
        return root
    }

    @MainActor
    private static func makeHandTool(
        name: String,
        color: UIColor,
        bodySize: SIMD3<Float>
    ) -> Entity {
        let tool = Entity()
        tool.name = name
        let body = ModelEntity(
            mesh: .generateBox(
                width: bodySize.x,
                height: bodySize.y,
                depth: bodySize.z
            ),
            materials: [
                SimpleMaterial(
                    color: UIColor(white: 0.16, alpha: 1),
                    roughness: 0.28,
                    isMetallic: true
                )
            ]
        )
        body.position.z = -bodySize.z * 0.45
        tool.addChild(body)
        let emitter = ModelEntity(
            mesh: .generateCylinder(height: 0.035, radius: bodySize.x * 0.32),
            materials: [UnlitMaterial(color: color)]
        )
        emitter.orientation = simd_quatf(
            angle: .pi / 2,
            axis: [1, 0, 0]
        )
        emitter.position.z = -bodySize.z
        tool.addChild(emitter)
        return tool
    }

    @MainActor
    static func makeLaser() -> Entity {
        let beam = Entity()
        beam.name = "Forward Laser"
        beam.isEnabled = false

        beam.addChild(
            makeBeamEmitter(
                name: "Left Laser Emitter",
                glowRadius: 0.035,
                glowColor: UIColor.systemRed.withAlphaComponent(0.35),
                coreRadius: 0.009,
                coreColor: .white
            )
        )
        beam.addChild(
            makeBeamEmitter(
                name: "Right Laser Emitter",
                glowRadius: 0.035,
                glowColor: UIColor.systemRed.withAlphaComponent(0.35),
                coreRadius: 0.009,
                coreColor: .white
            )
        )
        return beam
    }

    @MainActor
    private static func makeBeamEmitter(
        name: String,
        glowRadius: Float,
        glowColor: UIColor,
        coreRadius: Float,
        coreColor: UIColor
    ) -> Entity {
        let emitter = Entity()
        emitter.name = name

        let glow = ModelEntity(
            mesh: .generateCylinder(height: 200, radius: glowRadius),
            materials: [UnlitMaterial(color: glowColor)]
        )
        glow.name = "\(name) Glow"
        emitter.addChild(glow)

        let core = ModelEntity(
            mesh: .generateCylinder(height: 200, radius: coreRadius),
            materials: [UnlitMaterial(color: coreColor)]
        )
        core.name = "\(name) Core"
        emitter.addChild(core)
        return emitter
    }

    @MainActor
    static func makeSlowBeam() -> Entity {
        let beam = Entity()
        beam.name = "Slow Beam"
        beam.isEnabled = false

        beam.addChild(
            makeBeamEmitter(
                name: "Left Slow Beam Emitter",
                glowRadius: 0.12,
                glowColor: UIColor.systemBlue.withAlphaComponent(0.28),
                coreRadius: 0.038,
                coreColor: UIColor.systemCyan.withAlphaComponent(0.9)
            )
        )
        beam.addChild(
            makeBeamEmitter(
                name: "Right Slow Beam Emitter",
                glowRadius: 0.12,
                glowColor: UIColor.systemBlue.withAlphaComponent(0.28),
                coreRadius: 0.038,
                coreColor: UIColor.systemCyan.withAlphaComponent(0.9)
            )
        )
        return beam
    }

    @MainActor
    static func makeWeaponReticle() -> Entity {
        let root = Entity()
        root.name = "Weapon Reticle"
        // The sight and weapon beams share the head anchor's exact forward ray.
        root.position = [0, 0, -0.75]

        let segmentCount = 96
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var indices: [UInt32] = []
        for segment in 0..<segmentCount {
            let angle = Float(segment) / Float(segmentCount) * 2 * .pi
            for radius: Float in [1, 0.94] {
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
                    nextOuter, nextInner, inner
                ]
            )
        }

        var descriptor = MeshDescriptor(name: "Weapon Reticle Ring")
        descriptor.positions = MeshBuffers.Positions(positions)
        descriptor.normals = MeshBuffers.Normals(normals)
        descriptor.primitives = .triangles(indices)

        var material = UnlitMaterial(
            color: UIColor.systemRed
        )
        material.readsDepth = false
        material.writesDepth = true
        let sortGroup = hudOverlaySortGroup

        if let ringMesh = try? MeshResource.generate(from: [descriptor]) {
            let ring = ModelEntity(mesh: ringMesh, materials: [material])
            ring.name = "Reticle Ring"
            ring.components.set(
                ModelSortGroupComponent(group: sortGroup, order: 10_000)
            )
            root.addChild(ring)
        }

        let horizontal = ModelEntity(
            mesh: .generateBox(width: 0.55, height: 0.028, depth: 0.008),
            materials: [material]
        )
        horizontal.name = "Reticle Horizontal"
        horizontal.components.set(
            ModelSortGroupComponent(group: sortGroup, order: 10_001)
        )
        root.addChild(horizontal)

        let vertical = ModelEntity(
            mesh: .generateBox(width: 0.028, height: 0.55, depth: 0.008),
            materials: [material]
        )
        vertical.name = "Reticle Vertical"
        vertical.components.set(
            ModelSortGroupComponent(group: sortGroup, order: 10_002)
        )
        root.addChild(vertical)

        let center = ModelEntity(
            mesh: .generateSphere(radius: 0.04),
            materials: [material]
        )
        center.name = "Reticle Center"
        center.components.set(
            ModelSortGroupComponent(group: sortGroup, order: 10_003)
        )
        root.addChild(center)

        root.scale = SIMD3<Float>(repeating: 0.0402)
        return root
    }

    @MainActor
    static func makeMissile() -> Entity {
        let missile = Entity()
        missile.name = "Missile"
        missile.isEnabled = false

        let hull = ModelEntity(
            mesh: .generateCylinder(height: 0.42, radius: 0.045),
            materials: [
                SimpleMaterial(color: .lightGray, roughness: 0.25, isMetallic: true)
            ]
        )
        hull.orientation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
        missile.addChild(hull)

        let nose = ModelEntity(
            mesh: .generateSphere(radius: 0.05),
            materials: [SimpleMaterial(color: .white, roughness: 0.3, isMetallic: true)]
        )
        nose.position.z = -0.22
        missile.addChild(nose)

        let exhaust = ModelEntity(
            mesh: .generateCylinder(height: 0.32, radius: 0.025),
            materials: [UnlitMaterial(color: .systemOrange)]
        )
        exhaust.position.z = 0.36
        exhaust.orientation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
        missile.addChild(exhaust)
        return missile
    }

    /// Per-ship cockpit console silhouette. Current ship uses three facets;
    /// cone-curve is reserved for later hulls.
    enum CockpitConsoleStyle: Sendable {
        case threeFacet
        case coneCurve
    }

    @MainActor
    static func makeCockpit(
        consoleStyle: CockpitConsoleStyle = .threeFacet
    ) -> Entity {
        let cockpit = Entity()
        cockpit.name = "Cockpit"

        switch consoleStyle {
        case .threeFacet:
            cockpit.addChild(makeThreeFacetFlightConsole())
        case .coneCurve:
            // Placeholder until a future ship adopts the cone wrap.
            cockpit.addChild(makeThreeFacetFlightConsole())
        }

        let joystick = makeJoystick()
        joystick.position = [0.34, -0.51, -0.66]
        cockpit.addChild(joystick)

        let throttle = makeThrottle()
        throttle.position = [-0.34, -0.51, -0.66]
        cockpit.addChild(throttle)

        cockpit.addChild(makeTrueForwardReference())
        cockpit.addChild(makeHyperSpeedTunnel())
        return cockpit
    }

    /// Wraparound dash: center ahead, wings yawed ~45° toward the pilot,
    /// every face pitched ~45° (bottom nearer). Top corners of neighbors meet.
    @MainActor
    private static func makeThreeFacetFlightConsole() -> Entity {
        let root = Entity()
        root.name = "Flight Console"
        // One foot (0.3048 m) farther forward than the previous dash so the
        // faces sit clear of the pilot. Negative Z is ship-forward.
        root.position = [0, 0.14, -0.68 - 0.3048]

        let face = SimpleMaterial(
            color: UIColor(red: 0.07, green: 0.09, blue: 0.12, alpha: 1),
            roughness: 0.45,
            isMetallic: true
        )

        let panelWidth: Float = 0.84
        let panelHeight: Float = 0.72
        let halfW = panelWidth * 0.5
        let halfH = panelHeight * 0.5
        let pitch = simd_quatf(angle: -.pi / 4, axis: [1, 0, 0])

        func facetOrientation(yaw: Float) -> simd_quatf {
            // Pitch in the panel's own plane, then yaw the wing toward the pilot.
            simd_quatf(angle: yaw, axis: [0, 1, 0]) * pitch
        }

        func addPanel(named name: String, onto facet: Entity) {
            // Backing sits behind the SwiftUI face so it cannot cover the buttons.
            let plate = ModelEntity(
                mesh: .generateBox(
                    width: panelWidth,
                    height: panelHeight,
                    depth: 0.012
                ),
                materials: [face]
            )
            plate.name = "\(name) Plate"
            plate.position.z = -0.03
            facet.addChild(plate)

            let uiAnchor = Entity()
            uiAnchor.name = "\(name) UI"
            // In front of the backing plate. Buttons are parented here.
            uiAnchor.position = [0, 0, 0.02]
            facet.addChild(uiAnchor)
        }

        let topRight = SIMD3<Float>(halfW, halfH, 0)
        let topLeft = SIMD3<Float>(-halfW, halfH, 0)

        func place(
            name: String,
            yaw: Float,
            joiningTopCorner localJoin: SIMD3<Float>,
            to mate: SIMD3<Float>
        ) -> (entity: Entity, topLeft: SIMD3<Float>, topRight: SIMD3<Float>) {
            let orientation = facetOrientation(yaw: yaw)
            let position = mate - orientation.act(localJoin)
            let facet = Entity()
            facet.name = name
            facet.orientation = orientation
            facet.position = position
            addPanel(named: name, onto: facet)
            root.addChild(facet)
            return (
                facet,
                position + orientation.act(topLeft),
                position + orientation.act(topRight)
            )
        }

        let centerOri = facetOrientation(yaw: 0)
        let center = Entity()
        center.name = "Flight Console Center"
        center.orientation = centerOri
        center.position = .zero
        addPanel(named: center.name, onto: center)
        root.addChild(center)
        let centerTopLeft = centerOri.act(topLeft)
        let centerTopRight = centerOri.act(topRight)

        // Each wing continues the 45° wrap. Top corners meet the neighbor.
        let left = place(
            name: "Flight Console Left",
            yaw: .pi / 4,
            joiningTopCorner: topRight,
            to: centerTopLeft
        )
        _ = place(
            name: "Flight Console Far Left",
            yaw: .pi / 2,
            joiningTopCorner: topRight,
            to: left.topLeft
        )
        let right = place(
            name: "Flight Console Right",
            yaw: -.pi / 4,
            joiningTopCorner: topLeft,
            to: centerTopRight
        )
        _ = place(
            name: "Flight Console Far Right",
            yaw: -.pi / 2,
            joiningTopCorner: topLeft,
            to: right.topRight
        )

        return root
    }

    @MainActor
    private static func makeTrueForwardReference() -> Entity {
        let reference = Entity()
        reference.name = "True Forward Reference"
        // FlightModel updates x/y from the live head anchor while preserving
        // this fixed ship-forward distance.
        reference.position = [0, 0, -1.55]

        // Match the aiming reticle depth policy so planets/atmosphere/HUD
        // backdrop cannot bury the ship/rover nose cue.
        var material = UnlitMaterial(
            color: UIColor.systemCyan.withAlphaComponent(0.82)
        )
        material.readsDepth = false
        material.writesDepth = true
        let sortGroup = hudOverlaySortGroup

        let segmentLength: Float = 0.044
        let segmentThickness: Float = 0.0045
        let gap: Float = 0.012
        let segments: [
            (
                position: SIMD3<Float>,
                size: SIMD3<Float>
            )
        ] = [
            (
                [-gap - segmentLength / 2, 0, 0],
                [segmentLength, segmentThickness, 0.003]
            ),
            (
                [gap + segmentLength / 2, 0, 0],
                [segmentLength, segmentThickness, 0.003]
            ),
            (
                [0, -gap - segmentLength / 2, 0],
                [segmentThickness, segmentLength, 0.003]
            ),
            (
                [0, gap + segmentLength / 2, 0],
                [segmentThickness, segmentLength, 0.003]
            )
        ]
        for (index, segment) in segments.enumerated() {
            let model = ModelEntity(
                mesh: .generateBox(
                    width: segment.size.x,
                    height: segment.size.y,
                    depth: segment.size.z
                ),
                materials: [material]
            )
            model.name = "True Forward Segment \(index + 1)"
            model.position = segment.position
            model.components.set(
                ModelSortGroupComponent(
                    group: sortGroup,
                    order: 9_950 + Int32(index)
                )
            )
            reference.addChild(model)
        }

        let center = ModelEntity(
            mesh: .generateSphere(radius: 0.0045),
            materials: [material]
        )
        center.name = "True Forward Center"
        center.components.set(
            ModelSortGroupComponent(group: sortGroup, order: 9_954)
        )
        reference.addChild(center)
        return reference
    }

    @MainActor
    private static func makeJoystick() -> Entity {
        let root = Entity()
        root.name = "Joystick Control"
        let metal = SimpleMaterial(color: .darkGray, roughness: 0.35, isMetallic: true)
        let gripMaterial = SimpleMaterial(
            color: UIColor(red: 0.08, green: 0.11, blue: 0.14, alpha: 1),
            roughness: 0.7,
            isMetallic: false
        )

        let base = ModelEntity(
            mesh: .generateCylinder(height: 0.07, radius: 0.11),
            materials: [metal]
        )
        root.addChild(base)

        let pivot = Entity()
        pivot.name = "Joystick Pivot"
        pivot.position.y = 0.035
        root.addChild(pivot)

        let shaft = ModelEntity(
            mesh: .generateCylinder(height: 0.25, radius: 0.022),
            materials: [metal]
        )
        shaft.position.y = 0.125
        pivot.addChild(shaft)

        let grip = ModelEntity(
            mesh: .generateBox(width: 0.075, height: 0.13, depth: 0.065, cornerRadius: 0.02),
            materials: [gripMaterial]
        )
        grip.position = [0, 0.25, 0]
        pivot.addChild(grip)

        let fireButton = ModelEntity(
            mesh: .generateCylinder(height: 0.018, radius: 0.026),
            materials: [UnlitMaterial(color: .systemRed)]
        )
        fireButton.name = "Fire Button"
        fireButton.position = [0, 0.324, -0.005]
        pivot.addChild(fireButton)
        return root
    }

    @MainActor
    private static func makeThrottle() -> Entity {
        let root = Entity()
        root.name = "Throttle Control"
        let metal = SimpleMaterial(color: .darkGray, roughness: 0.32, isMetallic: true)
        let gripMaterial = SimpleMaterial(
            color: UIColor(red: 0.08, green: 0.11, blue: 0.14, alpha: 1),
            roughness: 0.65,
            isMetallic: false
        )

        let track = ModelEntity(
            mesh: .generateBox(width: 0.16, height: 0.045, depth: 0.42, cornerRadius: 0.02),
            materials: [metal]
        )
        root.addChild(track)

        let handle = Entity()
        handle.name = "Throttle Handle"
        handle.position = [0, 0.13, 0]
        root.addChild(handle)

        let lever = ModelEntity(
            mesh: .generateCylinder(height: 0.2, radius: 0.024),
            materials: [metal]
        )
        lever.position.y = -0.06
        handle.addChild(lever)

        let grip = ModelEntity(
            mesh: .generateBox(width: 0.12, height: 0.1, depth: 0.09, cornerRadius: 0.025),
            materials: [gripMaterial]
        )
        grip.position.y = 0.06
        handle.addChild(grip)

        let turboButton = ModelEntity(
            mesh: .generateCylinder(height: 0.018, radius: 0.028),
            materials: [UnlitMaterial(color: .systemOrange)]
        )
        turboButton.name = "Turbo Button"
        // The default layout assumes the common right-hand-stick/left-hand-
        // throttle arrangement. Hand tracking mirrors this for the other hand.
        turboButton.position = [0.076, 0.06, -0.005]
        turboButton.orientation = simd_quatf(angle: .pi / 2, axis: [0, 0, 1])
        handle.addChild(turboButton)
        return root
    }

    @MainActor
    private static func makeHyperSpeedTunnel() -> Entity {
        let root = Entity()
        root.name = "Hyper Speed Tunnel"
        root.isEnabled = false
        let materials = [
            UnlitMaterial(color: UIColor.white.withAlphaComponent(0.85)),
            UnlitMaterial(color: UIColor.systemCyan.withAlphaComponent(0.72))
        ]
        var random = SeededRandom(seed: 0x4859_5045_5253_5044)

        for index in 0..<48 {
            let angle = random.float(in: 0...(2 * .pi))
            // Preserve a broad, unobstructed forward sight cone in hyperdrive.
            let radius = random.float(in: 4...10)
            let streak = ModelEntity(
                mesh: .generateCylinder(
                    height: random.float(in: 2.5...7),
                    radius: random.float(in: 0.006...0.018)
                ),
                materials: [materials[index.isMultiple(of: 3) ? 1 : 0]]
            )
            streak.name = "Hyper Streak"
            streak.position = [
                cos(angle) * radius,
                sin(angle) * radius,
                random.float(in: -38 ... -2)
            ]
            streak.orientation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
            root.addChild(streak)
        }
        return root
    }

    @MainActor
    private static func addStarfield(to root: Entity) {
        let starMesh = MeshResource.generateSphere(radius: 0.055)
        let bright = UnlitMaterial(color: .white)
        let blue = UnlitMaterial(color: .cyan)
        var random = SeededRandom(seed: 0x5A17_F13D)

        for index in 0..<520 {
            let direction = random.unitVector()
            let distance = random.float(in: 45...215)
            let entity = ModelEntity(
                mesh: starMesh,
                materials: [index.isMultiple(of: 13) ? blue : bright]
            )
            let scale = random.float(in: 0.35...2.1)
            entity.scale = SIMD3<Float>(repeating: scale)
            entity.position = direction * distance
            root.addChild(entity)
        }
    }

    @MainActor
    private static func addSun(to root: Entity) {
        let sun = ModelEntity(
            mesh: .generateSphere(radius: 5.5),
            materials: [UnlitMaterial(color: .yellow)]
        )
        sun.name = "Sun"
        sun.position = [-24, 18, -105]
        root.addChild(sun)

        let light = Entity()
        light.components.set(PointLightComponent(color: .white, intensity: 7_500_000, attenuationRadius: 240))
        light.position = sun.position
        root.addChild(light)
    }

    @MainActor
    private static func addPlanet(
        name: String,
        radius: Float,
        color: UIColor,
        position: SIMD3<Float>,
        ringed: Bool = false,
        to root: Entity
    ) {
        let planet = ModelEntity(
            mesh: .generateSphere(radius: radius),
            materials: [SimpleMaterial(color: color, roughness: 0.72, isMetallic: false)]
        )
        planet.name = name
        planet.position = position
        root.addChild(planet)

        let atmosphere = ModelEntity(
            mesh: .generateSphere(radius: radius * 1.035),
            materials: [UnlitMaterial(color: color.withAlphaComponent(0.13))]
        )
        atmosphere.position = position
        root.addChild(atmosphere)

        if ringed {
            let ring = ModelEntity(
                mesh: .generateCylinder(height: 0.035, radius: radius * 1.75),
                materials: [UnlitMaterial(color: UIColor.systemYellow.withAlphaComponent(0.55))]
            )
            ring.position = position
            ring.orientation = simd_quatf(angle: .pi / 2.7, axis: SIMD3<Float>(1, 0, 0))
            root.addChild(ring)
        }
    }

    // MARK: - Player ship exterior (chrome delta interceptor)

    /// Brushed-silver twin-engine delta interceptor matching the reference look
    /// (panel seams, reflective chrome, dark canopy, ribbed idle nozzles).
    /// Local space: +Y up, −Z forward (nose), +Z aft (engines).
    @MainActor
    static func makeInterceptorShip(
        name: String = "Landed Ship"
    ) -> Entity {
        let ship = Entity()
        ship.name = name

        let materials = makeInterceptorMaterials()
        let chrome = materials.hull
        let chromeMid = materials.hullMid
        let chromeDark = materials.hullDark
        let chromeDeep = materials.hullDeep
        let canopyGlass = materials.canopy
        let nozzleMetal = materials.nozzle
        let seam = materials.seam

        // —— Primary hull volumes (cool brushed silver) ——
        if let noseMesh = makeNoseConeMesh(length: 1.85, baseRadius: 0.36) {
            let nose = ModelEntity(mesh: noseMesh, materials: [chrome])
            nose.name = "Ship Nose"
            nose.position = [0, 1.20, -3.55]
            ship.addChild(nose)
        }

        addHullSegment(
            to: ship,
            name: "Ship Forward Hull",
            size: [0.88, 0.68, 2.0],
            position: [0, 1.18, -2.25],
            material: chrome,
            corner: 0.18
        )
        addHullSegment(
            to: ship,
            name: "Ship Mid Hull",
            size: [1.28, 0.92, 2.7],
            position: [0, 1.24, -0.2],
            material: chrome,
            corner: 0.22
        )
        addHullSegment(
            to: ship,
            name: "Ship Aft Hull",
            size: [1.48, 1.02, 1.85],
            position: [0, 1.30, 1.75],
            material: chromeMid,
            corner: 0.2
        )

        // Centerline dorsal ridge — slightly darker plate.
        addHullSegment(
            to: ship,
            name: "Ship Spine",
            size: [0.26, 0.18, 5.0],
            position: [0, 1.80, -0.15],
            material: chromeDark,
            corner: 0.06
        )

        // Long teardrop canopy — near-black reflective glass.
        let canopy = ModelEntity(
            mesh: .generateSphere(radius: 0.58),
            materials: [canopyGlass]
        )
        canopy.name = "Ship Canopy"
        canopy.position = [0, 1.70, -1.95]
        canopy.scale = [0.62, 0.42, 1.72]
        ship.addChild(canopy)

        addHullSegment(
            to: ship,
            name: "Ship Canopy Frame",
            size: [0.70, 0.07, 2.05],
            position: [0, 1.40, -1.90],
            material: chromeDeep,
            corner: 0.03
        )

        // Dense interlocking hull plates + dark recessed seams.
        addInterceptorPaneling(
            to: ship,
            plateMaterial: chromeMid,
            accentMaterial: chromeDark,
            seamMaterial: seam
        )

        // Forward canards.
        for side: Float in [-1, 1] {
            if let mesh = makeHorizontalFinMesh(
                name: "Canard \(side < 0 ? "L" : "R")",
                rootLeading: [side * 0.32, -2.65],
                tip: [side * 1.28, -2.10],
                rootTrailing: [side * 0.38, -1.80],
                halfHeight: 0.032,
                mirrorWinding: side < 0
            ) {
                let fin = ModelEntity(mesh: mesh, materials: [chrome])
                fin.name = "Ship Canard \(side < 0 ? "L" : "R")"
                fin.position.y = 1.16
                ship.addChild(fin)
            }
        }

        // Main delta wings with panel overlays.
        for side: Float in [-1, 1] {
            if let mesh = makeHorizontalFinMesh(
                name: "Delta \(side < 0 ? "L" : "R")",
                rootLeading: [side * 0.52, -1.40],
                tip: [side * 3.60, 1.20],
                rootTrailing: [side * 0.62, 2.40],
                midCut: [side * 1.60, 2.10],
                halfHeight: 0.065,
                mirrorWinding: side < 0
            ) {
                let wing = ModelEntity(mesh: mesh, materials: [chrome])
                wing.name = "Ship Wing \(side < 0 ? "L" : "R")"
                wing.position.y = 1.05
                ship.addChild(wing)
            }

            // Wing surface plates (lighter / mid chrome variation).
            let wingPlates: [(SIMD3<Float>, SIMD3<Float>)] = [
                ([side * 1.25, 1.13, -0.15], [0.95, 0.03, 1.15]),
                ([side * 2.15, 1.13, 0.55], [0.85, 0.03, 1.05]),
                ([side * 2.85, 1.13, 1.05], [0.55, 0.03, 0.75]),
                ([side * 1.70, 0.97, 0.40], [1.10, 0.03, 0.90])
            ]
            for (index, plate) in wingPlates.enumerated() {
                addHullSegment(
                    to: ship,
                    name: "Wing Plate \(side < 0 ? "L" : "R")-\(index)",
                    size: plate.1,
                    position: plate.0,
                    material: index.isMultiple(of: 2) ? chromeMid : chromeDark,
                    corner: 0.02
                )
            }

            // Upward wingtip fin.
            addHullSegment(
                to: ship,
                name: "Ship Wingtip \(side < 0 ? "L" : "R")",
                size: [0.07, 0.58, 0.70],
                position: [side * 3.48, 1.34, 1.08],
                material: chromeDark,
                corner: 0.025
            )
            // Small downward ventral fin under wing root/rear.
            addHullSegment(
                to: ship,
                name: "Ship Ventral Fin \(side < 0 ? "L" : "R")",
                size: [0.06, 0.42, 0.55],
                position: [side * 1.55, 0.72, 1.65],
                material: chromeDeep,
                corner: 0.02
            )
        }

        // Twin engine nacelles — polished housings, darker ribbed idle nozzles.
        for side: Float in [-1, 1] {
            let nacelle = ModelEntity(
                mesh: .generateCylinder(height: 2.40, radius: 0.50),
                materials: [chrome]
            )
            nacelle.name = "Ship Engine \(side < 0 ? "L" : "R")"
            nacelle.position = [side * 0.64, 1.36, 2.50]
            nacelle.orientation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
            ship.addChild(nacelle)

            // Nacelle panel bands.
            let bandZs: [Float] = [1.85, 2.35, 2.85, 3.25]
            for (bandIndex, z) in bandZs.enumerated() {
                let band = ModelEntity(
                    mesh: .generateCylinder(height: 0.08, radius: 0.525),
                    materials: [
                        bandIndex.isMultiple(of: 2) ? chromeDark : chromeMid
                    ]
                )
                band.position = SIMD3<Float>(side * 0.64, 1.36, z)
                band.orientation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
                ship.addChild(band)
            }

            let fairing = ModelEntity(
                mesh: .generateCylinder(height: 0.50, radius: 0.58),
                materials: [chromeDark]
            )
            fairing.position = [side * 0.64, 1.36, 3.55]
            fairing.orientation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
            ship.addChild(fairing)

            // Ribbed nozzle stack (idle — no exhaust).
            let ribRadii: [Float] = [0.66, 0.63, 0.60, 0.57, 0.54, 0.50]
            for (ribIndex, radius) in ribRadii.enumerated() {
                let rib = ModelEntity(
                    mesh: .generateCylinder(height: 0.07, radius: radius),
                    materials: [ribIndex < 2 ? chromeDeep : nozzleMetal]
                )
                rib.position = [
                    side * 0.64,
                    1.36,
                    3.82 + Float(ribIndex) * 0.075
                ]
                rib.orientation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
                ship.addChild(rib)
            }

            let throat = ModelEntity(
                mesh: .generateCylinder(height: 0.28, radius: 0.40),
                materials: [nozzleMetal]
            )
            throat.name = "Ship Nozzle \(side < 0 ? "L" : "R")"
            throat.position = [side * 0.64, 1.36, 4.28]
            throat.orientation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
            ship.addChild(throat)

            let core = ModelEntity(
                mesh: .generateCylinder(height: 0.12, radius: 0.28),
                materials: [seam]
            )
            core.position = [side * 0.64, 1.36, 4.40]
            core.orientation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
            ship.addChild(core)
        }

        // Dorsal fin between engines.
        addHullSegment(
            to: ship,
            name: "Ship Dorsal Fin",
            size: [0.09, 0.58, 0.80],
            position: [0, 1.96, 2.60],
            material: chromeDark,
            corner: 0.025
        )

        // Landing pads.
        for side: Float in [-1, 1] {
            let pad = ModelEntity(
                mesh: .generateCylinder(height: 0.11, radius: 0.20),
                materials: [chromeDeep]
            )
            pad.position = [side * 0.72, 0.56, 0.15]
            ship.addChild(pad)
        }
        let nosePad = ModelEntity(
            mesh: .generateCylinder(height: 0.09, radius: 0.15),
            materials: [chromeDeep]
        )
        nosePad.position = [0, 0.58, -2.45]
        ship.addChild(nosePad)

        // 3× exterior so a saucer rover reads as storable in the hangar bay.
        ship.scale = SIMD3<Float>(repeating: 3)
        return ship
    }

    /// Uniform scale applied to the landed interceptor exterior.
    static let interceptorShipVisualScale: Float = 3

    // MARK: - Surface rover (saucer / boat chassis)

    /// Saucer-boat rover with large side traction wheels, a top observation dome,
    /// and the same brushed-silver panel language as the interceptor ship.
    @MainActor
    static func makeSurfaceRover(
        name: String = "Parked Rover"
    ) -> Entity {
        let rover = Entity()
        rover.name = name

        let materials = makeInterceptorMaterials()
        let hull = materials.hull
        let hullMid = materials.hullMid
        let hullDark = materials.hullDark
        let hullDeep = materials.hullDeep
        let canopy = materials.canopy
        let seam = materials.seam
        let nozzle = materials.nozzle

        // —— Saucer / boat lower hull (wide, shallow, rounded) ——
        let belly = ModelEntity(
            mesh: .generateSphere(radius: 1.0),
            materials: [hull]
        )
        belly.name = "Rover Belly"
        belly.position = [0, 0.78, 0]
        belly.scale = [1.85, 0.42, 2.45]
        rover.addChild(belly)

        let deck = ModelEntity(
            mesh: .generateSphere(radius: 1.0),
            materials: [hullMid]
        )
        deck.name = "Rover Deck"
        deck.position = [0, 1.05, 0]
        deck.scale = [1.70, 0.28, 2.20]
        rover.addChild(deck)

        // Boat bow / stern lift.
        addHullSegment(
            to: rover,
            name: "Rover Bow",
            size: [1.55, 0.42, 1.15],
            position: [0, 0.92, -1.85],
            material: hull,
            corner: 0.28
        )
        addHullSegment(
            to: rover,
            name: "Rover Stern",
            size: [1.65, 0.48, 1.05],
            position: [0, 0.95, 1.80],
            material: hullMid,
            corner: 0.26
        )

        // Mid gunwale rail (boat rim).
        addHullSegment(
            to: rover,
            name: "Rover Gunwale",
            size: [2.95, 0.14, 3.85],
            position: [0, 1.18, 0],
            material: hullDark,
            corner: 0.12
        )

        // —— Large observation dome on top ——
        let dome = ModelEntity(
            mesh: .generateSphere(radius: 0.95),
            materials: [canopy]
        )
        dome.name = "Rover Dome"
        dome.position = [0, 1.55, -0.15]
        dome.scale = [1.05, 0.78, 1.15]
        rover.addChild(dome)

        // Dome collar / ring.
        let collar = ModelEntity(
            mesh: .generateCylinder(height: 0.12, radius: 1.05),
            materials: [hullDeep]
        )
        collar.name = "Rover Dome Collar"
        collar.position = [0, 1.28, -0.15]
        rover.addChild(collar)

        let collarRing = ModelEntity(
            mesh: .generateCylinder(height: 0.06, radius: 1.12),
            materials: [seam]
        )
        collarRing.position = [0, 1.22, -0.15]
        rover.addChild(collarRing)

        // —— Ship-style paneling on the saucer body ——
        addRoverPaneling(
            to: rover,
            plateMaterial: hullMid,
            accentMaterial: hullDark,
            seamMaterial: seam
        )

        // —— Large detailed traction wheels (side-mounted) ——
        let wheelZs: [Float] = [-1.25, 1.25]
        for side: Float in [-1, 1] {
            for (wheelIndex, z) in wheelZs.enumerated() {
                addTractionWheel(
                    to: rover,
                    side: side,
                    z: z,
                    index: wheelIndex,
                    tire: nozzle,
                    rim: hullDark,
                    hub: hullMid,
                    tread: seam,
                    bolt: hull
                )
            }
        }

        // Axle housings between wheels and hull.
        for side: Float in [-1, 1] {
            for z: Float in wheelZs {
                let hubArm = ModelEntity(
                    mesh: .generateCylinder(height: 0.55, radius: 0.16),
                    materials: [hullDeep]
                )
                hubArm.position = [side * 1.35, 0.72, z]
                hubArm.orientation = simd_quatf(
                    angle: .pi / 2,
                    axis: [0, 0, 1]
                )
                rover.addChild(hubArm)

                let knuckle = ModelEntity(
                    mesh: .generateSphere(radius: 0.22),
                    materials: [hullDark]
                )
                knuckle.position = [side * 1.55, 0.72, z]
                rover.addChild(knuckle)
            }
        }

        // Nose lamp / sensor cluster.
        let lamp = ModelEntity(
            mesh: .generateSphere(radius: 0.14),
            materials: [
                UnlitMaterial(color: UIColor.cyan.withAlphaComponent(0.85))
            ]
        )
        lamp.position = [0, 1.05, -2.45]
        rover.addChild(lamp)

        return rover
    }

    @MainActor
    private static func addRoverPaneling(
        to rover: Entity,
        plateMaterial: PhysicallyBasedMaterial,
        accentMaterial: PhysicallyBasedMaterial,
        seamMaterial: PhysicallyBasedMaterial
    ) {
        let plates: [(SIMD3<Float>, SIMD3<Float>, Bool)] = [
            ([0.95, 1.05, -0.9], [0.55, 0.10, 1.10], false),
            ([-0.95, 1.05, -0.9], [0.55, 0.10, 1.10], false),
            ([0.98, 1.08, 0.7], [0.58, 0.10, 1.15], true),
            ([-0.98, 1.08, 0.7], [0.58, 0.10, 1.15], true),
            ([0.70, 1.12, -1.75], [0.70, 0.09, 0.70], false),
            ([-0.70, 1.12, -1.75], [0.70, 0.09, 0.70], false),
            ([0.75, 1.14, 1.65], [0.75, 0.09, 0.75], true),
            ([-0.75, 1.14, 1.65], [0.75, 0.09, 0.75], true),
            ([0.0, 0.55, -0.8], [1.40, 0.08, 1.20], false),
            ([0.0, 0.52, 0.9], [1.50, 0.08, 1.30], true),
            ([0.35, 1.30, 0.85], [0.45, 0.08, 0.70], false),
            ([-0.35, 1.30, 0.85], [0.45, 0.08, 0.70], false),
            ([0.0, 1.32, 1.55], [0.90, 0.08, 0.55], true)
        ]
        for (index, plate) in plates.enumerated() {
            addHullSegment(
                to: rover,
                name: "Rover Plate \(index)",
                size: plate.1,
                position: plate.0,
                material: plate.2 ? accentMaterial : plateMaterial,
                corner: 0.04
            )
        }

        let seams: [(SIMD3<Float>, SIMD3<Float>)] = [
            ([0, 1.15, -1.55], [2.4, 0.03, 0.04]),
            ([0, 1.18, 0.0], [2.7, 0.03, 0.04]),
            ([0, 1.16, 1.45], [2.5, 0.03, 0.04]),
            ([0.9, 0.95, 0], [0.03, 0.40, 3.2]),
            ([-0.9, 0.95, 0], [0.03, 0.40, 3.2]),
            ([0, 0.70, 0], [2.2, 0.03, 0.04])
        ]
        for (index, seamSpec) in seams.enumerated() {
            addHullSegment(
                to: rover,
                name: "Rover Seam \(index)",
                size: seamSpec.1,
                position: seamSpec.0,
                material: seamMaterial,
                corner: 0.01
            )
        }
    }

    /// Oversized side traction wheel with rim, hub, tread blocks, and bolts.
    @MainActor
    private static func addTractionWheel(
        to parent: Entity,
        side: Float,
        z: Float,
        index: Int,
        tire: PhysicallyBasedMaterial,
        rim: PhysicallyBasedMaterial,
        hub: PhysicallyBasedMaterial,
        tread: PhysicallyBasedMaterial,
        bolt: PhysicallyBasedMaterial
    ) {
        let wheelRoot = Entity()
        wheelRoot.name = "Rover Wheel \(side < 0 ? "L" : "R")-\(index)"
        wheelRoot.position = SIMD3<Float>(side * 1.95, 0.78, z)
        parent.addChild(wheelRoot)

        // Wide tire drum (axis along X so face points outward).
        let drum = ModelEntity(
            mesh: .generateCylinder(height: 0.55, radius: 0.78),
            materials: [tire]
        )
        drum.name = "Tire"
        drum.orientation = simd_quatf(angle: .pi / 2, axis: [0, 0, 1])
        wheelRoot.addChild(drum)

        // Outer rim lip.
        let outerRim = ModelEntity(
            mesh: .generateCylinder(height: 0.10, radius: 0.84),
            materials: [rim]
        )
        outerRim.position = SIMD3<Float>(side * 0.28, 0, 0)
        outerRim.orientation = simd_quatf(angle: .pi / 2, axis: [0, 0, 1])
        wheelRoot.addChild(outerRim)

        let innerRim = ModelEntity(
            mesh: .generateCylinder(height: 0.08, radius: 0.82),
            materials: [rim]
        )
        innerRim.position = SIMD3<Float>(side * -0.26, 0, 0)
        innerRim.orientation = simd_quatf(angle: .pi / 2, axis: [0, 0, 1])
        wheelRoot.addChild(innerRim)

        // Hub dish + center cap.
        let hubDish = ModelEntity(
            mesh: .generateCylinder(height: 0.14, radius: 0.38),
            materials: [hub]
        )
        hubDish.position = SIMD3<Float>(side * 0.30, 0, 0)
        hubDish.orientation = simd_quatf(angle: .pi / 2, axis: [0, 0, 1])
        wheelRoot.addChild(hubDish)

        let hubCap = ModelEntity(
            mesh: .generateSphere(radius: 0.16),
            materials: [bolt]
        )
        hubCap.position = SIMD3<Float>(side * 0.40, 0, 0)
        hubCap.scale = [0.55, 1, 1]
        wheelRoot.addChild(hubCap)

        // Circumferential traction tread blocks.
        let treadCount = 14
        for treadIndex in 0..<treadCount {
            let angle = Float(treadIndex) / Float(treadCount) * 2 * .pi
            let radius: Float = 0.78
            let block = ModelEntity(
                mesh: .generateBox(
                    width: 0.42,
                    height: 0.16,
                    depth: 0.22,
                    cornerRadius: 0.03
                ),
                materials: [tread]
            )
            block.position = SIMD3<Float>(
                0,
                sin(angle) * radius,
                cos(angle) * radius
            )
            block.orientation = simd_quatf(
                angle: angle,
                axis: [1, 0, 0]
            )
            wheelRoot.addChild(block)
        }

        // Sidewall traction chevrons / ribs.
        let ribCount = 8
        for ribIndex in 0..<ribCount {
            let angle = Float(ribIndex) / Float(ribCount) * 2 * .pi
            let rib = ModelEntity(
                mesh: .generateBox(
                    width: 0.08,
                    height: 0.55,
                    depth: 0.12,
                    cornerRadius: 0.02
                ),
                materials: [rim]
            )
            rib.position = SIMD3<Float>(
                side * 0.22,
                sin(angle) * 0.52,
                cos(angle) * 0.52
            )
            rib.orientation = simd_quatf(angle: angle, axis: [1, 0, 0])
            wheelRoot.addChild(rib)
        }

        // Hub bolts around the dish.
        let boltCount = 8
        for boltIndex in 0..<boltCount {
            let angle = Float(boltIndex) / Float(boltCount) * 2 * .pi
            let stud = ModelEntity(
                mesh: .generateCylinder(height: 0.06, radius: 0.045),
                materials: [bolt]
            )
            stud.position = SIMD3<Float>(
                side * 0.36,
                sin(angle) * 0.24,
                cos(angle) * 0.24
            )
            stud.orientation = simd_quatf(angle: .pi / 2, axis: [0, 0, 1])
            wheelRoot.addChild(stud)
        }
    }

    private struct InterceptorMaterials {
        let hull: PhysicallyBasedMaterial
        let hullMid: PhysicallyBasedMaterial
        let hullDark: PhysicallyBasedMaterial
        let hullDeep: PhysicallyBasedMaterial
        let canopy: PhysicallyBasedMaterial
        let nozzle: PhysicallyBasedMaterial
        let seam: PhysicallyBasedMaterial
    }

    /// Cool brushed-silver palette from the reference (chrome + panel shade steps).
    @MainActor
    private static func makeInterceptorMaterials() -> InterceptorMaterials {
        let panelTexture = makeBrushedPanelTexture()

        func metal(
            tint: UIColor,
            roughness: Float,
            metallic: Float = 1.0,
            textured: Bool = true
        ) -> PhysicallyBasedMaterial {
            var material = PhysicallyBasedMaterial()
            if textured, let panelTexture {
                material.baseColor = .init(
                    tint: tint,
                    texture: .init(panelTexture)
                )
            } else {
                material.baseColor = .init(tint: tint)
            }
            material.metallic = .init(floatLiteral: metallic)
            material.roughness = .init(floatLiteral: roughness)
            material.specular = 0.62
            return material
        }

        // Cool silver / steel — not warm gray.
        let hull = metal(
            tint: UIColor(red: 0.82, green: 0.84, blue: 0.88, alpha: 1),
            roughness: 0.20
        )
        let hullMid = metal(
            tint: UIColor(red: 0.68, green: 0.70, blue: 0.74, alpha: 1),
            roughness: 0.26
        )
        let hullDark = metal(
            tint: UIColor(red: 0.48, green: 0.50, blue: 0.54, alpha: 1),
            roughness: 0.34
        )
        let hullDeep = metal(
            tint: UIColor(red: 0.28, green: 0.30, blue: 0.34, alpha: 1),
            roughness: 0.42
        )
        var canopy = PhysicallyBasedMaterial()
        canopy.baseColor = .init(
            tint: UIColor(red: 0.03, green: 0.04, blue: 0.07, alpha: 1)
        )
        canopy.metallic = .init(floatLiteral: 0.92)
        canopy.roughness = .init(floatLiteral: 0.05)
        canopy.specular = 0.9
        let nozzle = metal(
            tint: UIColor(red: 0.16, green: 0.16, blue: 0.18, alpha: 1),
            roughness: 0.62,
            textured: false
        )
        let seam = metal(
            tint: UIColor(red: 0.10, green: 0.11, blue: 0.13, alpha: 1),
            roughness: 0.72,
            textured: false
        )
        return InterceptorMaterials(
            hull: hull,
            hullMid: hullMid,
            hullDark: hullDark,
            hullDeep: hullDeep,
            canopy: canopy,
            nozzle: nozzle,
            seam: seam
        )
    }

    /// Procedural brushed silver with irregular dark panel seams.
    @MainActor
    private static func makeBrushedPanelTexture() -> TextureResource? {
        let dimension = 512
        let size = CGSize(width: dimension, height: dimension)
        UIGraphicsBeginImageContextWithOptions(size, true, 1)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }

        // Base cool metal.
        context.setFillColor(
            UIColor(red: 0.74, green: 0.76, blue: 0.80, alpha: 1).cgColor
        )
        context.fill(CGRect(origin: .zero, size: size))

        // Horizontal brush streaks.
        for y in stride(from: 0, to: dimension, by: 1) {
            let wobble = CGFloat((y * 37) % 23) / 120
            let white = 0.62 + wobble
            context.setFillColor(
                UIColor(white: white, alpha: 0.10).cgColor
            )
            context.fill(CGRect(x: 0, y: y, width: dimension, height: 1))
        }

        // Irregular darker panel fills.
        var seed = 1_337
        func nextUnit() -> CGFloat {
            seed = seed &* 1_103_515_245 &+ 12_345
            return CGFloat(seed % 1_000) / 1_000
        }
        for _ in 0..<48 {
            let x = nextUnit() * CGFloat(dimension)
            let y = nextUnit() * CGFloat(dimension)
            let w = 24 + nextUnit() * 70
            let h = 18 + nextUnit() * 54
            let shade = 0.52 + nextUnit() * 0.22
            context.setFillColor(
                UIColor(white: shade, alpha: 0.55).cgColor
            )
            context.fill(CGRect(x: x, y: y, width: w, height: h))
        }

        // Dark recessed panel seams.
        context.setStrokeColor(
            UIColor(red: 0.14, green: 0.15, blue: 0.17, alpha: 0.95).cgColor
        )
        context.setLineWidth(2.2)
        var xCursor: CGFloat = 0
        while xCursor < CGFloat(dimension) {
            context.move(to: CGPoint(x: xCursor, y: 0))
            context.addLine(to: CGPoint(x: xCursor, y: CGFloat(dimension)))
            context.strokePath()
            xCursor += 22 + nextUnit() * 36
        }
        var yCursor: CGFloat = 0
        while yCursor < CGFloat(dimension) {
            context.move(to: CGPoint(x: 0, y: yCursor))
            context.addLine(to: CGPoint(x: CGFloat(dimension), y: yCursor))
            context.strokePath()
            yCursor += 18 + nextUnit() * 30
        }

        // Fine rivet dots along some seams.
        context.setFillColor(
            UIColor(white: 0.25, alpha: 0.8).cgColor
        )
        for _ in 0..<220 {
            let rx = nextUnit() * CGFloat(dimension)
            let ry = nextUnit() * CGFloat(dimension)
            context.fill(CGRect(x: rx, y: ry, width: 2.2, height: 2.2))
        }

        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        guard let cgImage = image?.cgImage else { return nil }
        return try? TextureResource(
            image: cgImage,
            options: .init(semantic: .color)
        )
    }

    @MainActor
    private static func addHullSegment(
        to parent: Entity,
        name: String,
        size: SIMD3<Float>,
        position: SIMD3<Float>,
        material: PhysicallyBasedMaterial,
        corner: Float
    ) {
        let entity = ModelEntity(
            mesh: .generateBox(
                width: size.x,
                height: size.y,
                depth: size.z,
                cornerRadius: corner
            ),
            materials: [material]
        )
        entity.name = name
        entity.position = position
        parent.addChild(entity)
    }

    /// Raised interlocking plates + thin dark seam channels for the reference look.
    @MainActor
    private static func addInterceptorPaneling(
        to ship: Entity,
        plateMaterial: PhysicallyBasedMaterial,
        accentMaterial: PhysicallyBasedMaterial,
        seamMaterial: PhysicallyBasedMaterial
    ) {
        // Top / side plates along the fuselage.
        let plates: [(SIMD3<Float>, SIMD3<Float>, Bool)] = [
            // Port / starboard forward cheek plates.
            ([0.42, 1.35, -2.35], [0.28, 0.10, 0.70], false),
            ([-0.42, 1.35, -2.35], [0.28, 0.10, 0.70], false),
            ([0.48, 1.40, -1.55], [0.32, 0.11, 0.85], true),
            ([-0.48, 1.40, -1.55], [0.32, 0.11, 0.85], true),
            // Mid body armor tiles.
            ([0.58, 1.48, -0.55], [0.36, 0.12, 0.95], false),
            ([-0.58, 1.48, -0.55], [0.36, 0.12, 0.95], false),
            ([0.62, 1.52, 0.45], [0.38, 0.12, 0.90], true),
            ([-0.62, 1.52, 0.45], [0.38, 0.12, 0.90], true),
            ([0.66, 1.55, 1.35], [0.40, 0.13, 0.80], false),
            ([-0.66, 1.55, 1.35], [0.40, 0.13, 0.80], false),
            // Dorsal tiles.
            ([0.18, 1.78, -1.2], [0.30, 0.08, 0.75], true),
            ([-0.18, 1.78, -1.2], [0.30, 0.08, 0.75], true),
            ([0.20, 1.82, 0.2], [0.34, 0.08, 0.85], false),
            ([-0.20, 1.82, 0.2], [0.34, 0.08, 0.85], false),
            ([0.22, 1.84, 1.3], [0.36, 0.08, 0.70], true),
            ([-0.22, 1.84, 1.3], [0.36, 0.08, 0.70], true),
            // Belly plates.
            ([0.0, 0.78, -1.6], [0.70, 0.08, 1.10], false),
            ([0.0, 0.76, 0.0], [0.85, 0.08, 1.30], true),
            ([0.0, 0.78, 1.4], [0.95, 0.08, 1.00], false),
            // Nose side vents / hatches.
            ([0.38, 1.12, -2.85], [0.18, 0.16, 0.40], true),
            ([-0.38, 1.12, -2.85], [0.18, 0.16, 0.40], true),
            // Engine mount plates.
            ([0.55, 1.70, 2.2], [0.45, 0.10, 0.70], false),
            ([-0.55, 1.70, 2.2], [0.45, 0.10, 0.70], false)
        ]
        for (index, plate) in plates.enumerated() {
            addHullSegment(
                to: ship,
                name: "Hull Plate \(index)",
                size: plate.1,
                position: plate.0,
                material: plate.2 ? accentMaterial : plateMaterial,
                corner: 0.025
            )
        }

        // Thin dark seam channels between major sections.
        let seams: [(SIMD3<Float>, SIMD3<Float>)] = [
            ([0, 1.55, -2.95], [0.82, 0.025, 0.04]),
            ([0, 1.58, -1.55], [1.05, 0.025, 0.04]),
            ([0, 1.62, -0.2], [1.20, 0.025, 0.04]),
            ([0, 1.66, 1.15], [1.30, 0.025, 0.04]),
            ([0, 1.70, 2.25], [1.35, 0.025, 0.04]),
            ([0.52, 1.35, -0.4], [0.03, 0.55, 2.8]),
            ([-0.52, 1.35, -0.4], [0.03, 0.55, 2.8]),
            ([0, 1.05, -0.2], [1.15, 0.03, 0.04]),
            ([0, 1.05, 1.2], [1.25, 0.03, 0.04])
        ]
        for (index, seamSpec) in seams.enumerated() {
            addHullSegment(
                to: ship,
                name: "Hull Seam \(index)",
                size: seamSpec.1,
                position: seamSpec.0,
                material: seamMaterial,
                corner: 0.01
            )
        }
    }

    /// Horizontal fin / wing in the XZ plane (`points` are x,z), extruded on Y.
    @MainActor
    private static func makeHorizontalFinMesh(
        name: String,
        rootLeading: SIMD2<Float>,
        tip: SIMD2<Float>,
        rootTrailing: SIMD2<Float>,
        midCut: SIMD2<Float>? = nil,
        halfHeight: Float,
        mirrorWinding: Bool = false
    ) -> MeshResource? {
        var outline = [rootLeading, tip]
        if let midCut {
            outline.append(midCut)
        }
        outline.append(rootTrailing)
        if mirrorWinding {
            outline.reverse()
        }
        return makeExtrudedPolygonMesh(
            name: name,
            outlineXZ: outline,
            halfHeight: halfHeight
        )
    }

    /// Nose cone tip at −Z, base toward +Z.
    @MainActor
    private static func makeNoseConeMesh(
        length: Float,
        baseRadius: Float,
        segments: Int = 16
    ) -> MeshResource? {
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var indices: [UInt32] = []

        let tip = SIMD3<Float>(0, 0, -length * 0.5)
        positions.append(tip)
        normals.append(simd_normalize(SIMD3<Float>(0, 0, -1)))

        // Ring around base.
        for segment in 0..<segments {
            let angle = Float(segment) / Float(segments) * 2 * .pi
            let x = cos(angle) * baseRadius
            let y = sin(angle) * baseRadius
            let point = SIMD3<Float>(x, y, length * 0.5)
            positions.append(point)
            normals.append(simd_normalize(SIMD3<Float>(x, y, baseRadius * 0.35)))
        }
        // Tip triangles (outward facing).
        for segment in 0..<segments {
            let next = (segment + 1) % segments
            indices.append(contentsOf: [
                0,
                UInt32(1 + next),
                UInt32(1 + segment)
            ])
        }
        // Base cap center.
        let capCenter = UInt32(positions.count)
        positions.append([0, 0, length * 0.5])
        normals.append([0, 0, 1])
        for segment in 0..<segments {
            let next = (segment + 1) % segments
            indices.append(contentsOf: [
                capCenter,
                UInt32(1 + next),
                UInt32(1 + segment)
            ])
        }

        var descriptor = MeshDescriptor(name: "Ship Nose Cone")
        descriptor.positions = MeshBuffers.Positions(positions)
        descriptor.normals = MeshBuffers.Normals(normals)
        descriptor.primitives = .triangles(indices)
        return try? MeshResource.generate(from: [descriptor])
    }

    @MainActor
    private static func makeExtrudedPolygonMesh(
        name: String,
        outlineXZ: [SIMD2<Float>],
        halfHeight: Float
    ) -> MeshResource? {
        let count = outlineXZ.count
        guard count >= 3 else { return nil }

        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []
        var indices: [UInt32] = []

        // Top + bottom caps (unique normals).
        let topBase = UInt32(positions.count)
        for point in outlineXZ {
            positions.append([point.x, halfHeight, point.y])
            normals.append([0, 1, 0])
        }
        let bottomBase = UInt32(positions.count)
        for point in outlineXZ {
            positions.append([point.x, -halfHeight, point.y])
            normals.append([0, -1, 0])
        }
        for i in 1..<(count - 1) {
            indices.append(contentsOf: [
                topBase,
                topBase + UInt32(i),
                topBase + UInt32(i + 1)
            ])
            indices.append(contentsOf: [
                bottomBase,
                bottomBase + UInt32(i + 1),
                bottomBase + UInt32(i)
            ])
        }

        // Side walls with outward normals.
        for i in 0..<count {
            let next = (i + 1) % count
            let a = outlineXZ[i]
            let b = outlineXZ[next]
            let edge = SIMD3<Float>(b.x - a.x, 0, b.y - a.y)
            var outward = simd_normalize(SIMD3<Float>(edge.z, 0, -edge.x))
            // Ensure outward points away from origin in XZ.
            let mid = SIMD3<Float>((a.x + b.x) * 0.5, 0, (a.y + b.y) * 0.5)
            if simd_dot(outward, mid) < 0 {
                outward = -outward
            }
            let base = UInt32(positions.count)
            positions.append([a.x, halfHeight, a.y])
            positions.append([b.x, halfHeight, b.y])
            positions.append([b.x, -halfHeight, b.y])
            positions.append([a.x, -halfHeight, a.y])
            normals.append(contentsOf: [outward, outward, outward, outward])
            indices.append(contentsOf: [
                base, base + 1, base + 2,
                base, base + 2, base + 3
            ])
        }

        var descriptor = MeshDescriptor(name: name)
        descriptor.positions = MeshBuffers.Positions(positions)
        descriptor.normals = MeshBuffers.Normals(normals)
        descriptor.primitives = .triangles(indices)
        return try? MeshResource.generate(from: [descriptor])
    }

}

private struct SeededRandom {
    var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }

    mutating func float(in range: ClosedRange<Float>) -> Float {
        let unit = Float(next() >> 40) / Float(1 << 24)
        return range.lowerBound + unit * (range.upperBound - range.lowerBound)
    }

    mutating func unitVector() -> SIMD3<Float> {
        let z = float(in: -1...1)
        let angle = float(in: 0...(2 * .pi))
        let radius = sqrt(max(0, 1 - z * z))
        return SIMD3<Float>(radius * cos(angle), radius * sin(angle), z)
    }
}
