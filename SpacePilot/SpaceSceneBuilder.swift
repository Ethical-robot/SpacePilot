import RealityKit
import simd
import UIKit

enum SpaceSceneBuilder {
    @MainActor
    static func makeScene() -> Entity {
        let root = Entity()
        root.name = "Universe"
        return root
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
            slot.addChild(plate)
            let glyph = ModelEntity(
                mesh: .generateBox(
                    width: index == 0 ? 0.025 : 0.009,
                    height: index == 1 ? 0.034 : 0.026,
                    depth: index == 0 ? 0.002 : 0.008
                ),
                materials: [UnlitMaterial(color: .white)]
            )
            glyph.position.z = 0.009
            glyph.orientation = simd_quatf(
                angle: index == 1 ? -0.55 : 0,
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
        let sortGroup = ModelSortGroup(depthPass: .postPass)

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

    @MainActor
    static func makeCockpit() -> Entity {
        let cockpit = Entity()
        cockpit.name = "Cockpit"

        let consoleMaterial = SimpleMaterial(
            color: UIColor(red: 0.055, green: 0.075, blue: 0.095, alpha: 0.96),
            roughness: 0.42,
            isMetallic: true
        )
        let console = ModelEntity(
            mesh: .generateBox(width: 1.45, height: 0.08, depth: 0.48),
            materials: [consoleMaterial]
        )
        console.position = [0, -0.58, -0.78]
        console.orientation = simd_quatf(angle: -0.12, axis: [1, 0, 0])
        cockpit.addChild(console)

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

    @MainActor
    private static func makeTrueForwardReference() -> Entity {
        let reference = Entity()
        reference.name = "True Forward Reference"
        // FlightModel updates x/y from the live head anchor while preserving
        // this fixed ship-forward distance.
        reference.position = [0, 0, -1.55]

        var material = UnlitMaterial(
            color: UIColor.systemCyan.withAlphaComponent(0.38)
        )
        material.readsDepth = false
        material.writesDepth = false
        let sortGroup = ModelSortGroup(depthPass: .postPass)

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
                    order: 9_900 + Int32(index)
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
            ModelSortGroupComponent(group: sortGroup, order: 9_904)
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
