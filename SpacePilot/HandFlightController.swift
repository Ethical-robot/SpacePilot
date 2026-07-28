import ARKit
import Foundation
import QuartzCore
import simd

@MainActor
final class HandFlightController {
    private let session = ARKitSession()
    private let handTracking = HandTrackingProvider()
    private let worldTracking = WorldTrackingProvider()
    private weak var flight: FlightModel?
    private var trackingTask: Task<Void, Never>?
    private var deviceTrackingTask: Task<Void, Never>?
    private var latestDeviceTransform: simd_float4x4?

    private var dominantHand: HandAnchor.Chirality?
    private var secondaryHand: HandAnchor.Chirality?
    private var joystickNeutral: FistFrame?
    private var throttleNeutralPosition: SIMD3<Float>?
    private var throttleNeutralValue = 0.0
    private var hyperDrivePressStartedAt: Double?
    private var dominantTriggerPressed = false
    private var lastJoystickTrackingTime = 0.0
    private var lastThrottleTrackingTime = 0.0
    private var lastWalkingTrackingTime = 0.0
    private var walkingGestureBeganAt: Double?
    private var lastWalkingPoseMatchTime = 0.0
    private var lastExplorationMode: String?
    private var leftPose: HandPose?
    private var rightPose: HandPose?
    private var toolMenuTouchActive = false
    private var toolMenuTouchStartX: Float?
    private var collectionGestureActive = false
    private var collectionGestureArmed = false
    private var activationGestureEngaged = false
    private var activationGestureConsumed = false
    private var leftActivationPinchTime: Double?
    private var rightActivationPinchTime: Double?
    private var lastDominantToolTip: SIMD3<Float>?
    private var lastSurfaceToolImpactTime = 0.0
    private var lastMatterCrumblerUpdateTime: Double?
    private var surfaceToolTriggerArmed = false
    private var surfaceToolTriggerPressed = false
    private var lastSelectedSurfaceTool: SurfaceTool?
    private var eatingStartedAt: Double?
    private var eatingItemID: String?
    private var lastEatingFragmentTime = 0.0
    private var eatingGestureConsumed = false

    func connect(to flight: FlightModel) {
        self.flight = flight

        guard HandTrackingProvider.isSupported else {
            flight.handTrackingStatus = "Hand tracking unavailable"
            return
        }

        if flight.activeExplorationMode == "Leave on foot" {
            dominantHand = nil
            secondaryHand = nil
            flight.handTrackingStatus =
                "Show the walking pose with either hand"
        } else if flight.isSurfaceExploration {
            if flight.dominantHandName == "LEFT" {
                dominantHand = .left
            } else if flight.dominantHandName == "RIGHT" {
                dominantHand = .right
            }
            flight.handTrackingStatus =
                "Close dominant hand to steer rover"
        } else {
            flight.handTrackingStatus = "Grip joystick with thumb up"
        }
        trackingTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await session.run([handTracking, worldTracking])
                deviceTrackingTask = Task { [weak self] in
                    await self?.trackDevicePose()
                }
                for await update in handTracking.anchorUpdates {
                    guard !Task.isCancelled else { break }
                    process(update.anchor)
                }
            } catch {
                flight.handTrackingStatus = "Hand tracking permission required"
            }
        }
    }

    func disconnect() {
        trackingTask?.cancel()
        trackingTask = nil
        deviceTrackingTask?.cancel()
        deviceTrackingTask = nil
        latestDeviceTransform = nil
        dominantHand = nil
        secondaryHand = nil
        joystickNeutral = nil
        throttleNeutralPosition = nil
        hyperDrivePressStartedAt = nil
        dominantTriggerPressed = false
        walkingGestureBeganAt = nil
        lastWalkingPoseMatchTime = 0
        lastExplorationMode = nil
        leftPose = nil
        rightPose = nil
        toolMenuTouchActive = false
        toolMenuTouchStartX = nil
        collectionGestureActive = false
        collectionGestureArmed = false
        resetActivationGesture()
        resetSurfaceToolGestureState()
        resetEatingGesture()
        flight?.setInventoryVisible(false)
        flight?.setWalkingGestureActive(false)
        clearJoystick()
        releaseThrottle()
        flight = nil
    }

    private func process(_ anchor: HandAnchor) {
        let now = ProcessInfo.processInfo.systemUptime
        synchronizeExplorationMode()
        guard anchor.isTracked, let pose = pose(for: anchor) else {
            handleTrackingLoss(anchor.chirality, now: now)
            return
        }
        if anchor.chirality == .left {
            leftPose = pose
        } else {
            rightPose = pose
        }

        if flight?.activeExplorationMode == "Leave on foot",
           dominantHand == nil {
            guard isWalkingRoleSelectionPose(pose) else {
                flight?.handTrackingStatus =
                    "Show the walking pose with either hand"
                return
            }
            secondaryHand = anchor.chirality
            dominantHand =
                anchor.chirality == .left ? .right : .left
            flight?.dominantHandName =
                dominantHand == .left ? "LEFT" : "RIGHT"
            flight?.saveProgress()
        }

        if dominantHand == nil {
            let canRestoreSurfaceControls =
                flight?.isSurfaceExploration == true
                    && pose.fingersCurled
            guard canRestoreSurfaceControls
                    || (pose.thumbIsUp && pose.fingersCurled) else {
                return
            }
            dominantHand = anchor.chirality
            joystickNeutral = pose.frame
            flight?.grabJoystick(at: pose.fistPosition)
        }

        if anchor.chirality == dominantHand {
            lastJoystickTrackingTime = now
            flight?.dominantHandActive = true
            flight?.dominantHandName =
                dominantHand == .left ? "LEFT" : "RIGHT"
            flight?.updateHeldInventoryItemPose(
                position: pose.fistPosition,
                pointingDirection: pose.wristToKnuckles
            )
            processEatingGesture(pose, now: now)
        } else {
            let walkingPoseReady =
                flight?.activeExplorationMode == "Leave on foot"
                    && isForgivingWalkingPose(pose)
            let inventoryActive =
                flight?.canPresentInventory == true
                    && flight?.walkingGestureActive != true
                    && !walkingPoseReady
                    && pose.allDigitsSpread
                    && isBackOfHandFacingUser(pose)
            flight?.setInventoryVisible(inventoryActive)
            if inventoryActive {
                walkingGestureBeganAt = nil
                flight?.setWalkingGestureActive(false)
                flight?.setSurfaceToolMenuVisible(false)
                flight?.supportHandActive = false
                updateStatus()
                return
            }
        }

        processActivationGesture(now: now)

        if flight?.activeExplorationMode == "Leave on foot" {
            if anchor.chirality == dominantHand {
                flight?.setMatterCrumblerTrackingHold(false)
                flight?.updateHeldSurfaceToolPose(
                    position: pose.fistPosition,
                    pointingDirection: pose.wristToKnuckles
                )
                processDominantSurfaceTool(pose, now: now)
            } else {
                lastWalkingTrackingTime = now
                let palmFacingUser = isPalmFacingUser(pose)
                let palmMenuActive =
                    flight?.inventoryVisible != true
                        && pose.fingersOutstretched
                        && palmFacingUser
                flight?.setSurfaceToolMenuVisible(palmMenuActive)
                if palmMenuActive {
                    flight?.updateSurfaceToolMenuPose(
                        position:
                            pose.wrist
                                - pose.wristToKnuckles * 0.045
                                + pose.palmNormal * 0.018,
                        palmNormal: pose.palmNormal
                    )
                }
                let matchesWalkingGesture =
                    !palmMenuActive
                        && flight?.inventoryVisible != true
                        && !palmFacingUser
                        && isForgivingWalkingPose(pose)
                if matchesWalkingGesture {
                    lastWalkingPoseMatchTime = now
                    if walkingGestureBeganAt == nil {
                        walkingGestureBeganAt = now
                    }
                    let isWalking =
                        now - (walkingGestureBeganAt ?? now) >= 0.10
                    flight?.setWalkingGestureActive(isWalking)
                    flight?.supportHandActive = isWalking
                } else if flight?.walkingGestureActive == true,
                          now - lastWalkingPoseMatchTime <= 0.35 {
                    // Brief joint occlusion or one noisy finger must not
                    // interrupt locomotion once the pose has latched.
                    flight?.setWalkingGestureActive(true)
                    flight?.supportHandActive = true
                } else {
                    walkingGestureBeganAt = nil
                    flight?.setWalkingGestureActive(false)
                    flight?.supportHandActive = false
                }
            }
            processToolMenuInteraction()
            processCollectionGesture()
            updateStatus()
        } else if anchor.chirality == dominantHand {
            lastJoystickTrackingTime = now
            applyJoystick(pose)
        } else if flight?.isOutsideShip == true {
            handleTrackingLoss(anchor.chirality, now: now)
        } else if pose.knucklesAreUp && pose.fingersCurled {
            lastThrottleTrackingTime = now
            applyThrottle(pose)
        } else {
            handleTrackingLoss(anchor.chirality, now: now)
        }
    }

    private func trackDevicePose() async {
        while !Task.isCancelled {
            if let anchor = worldTracking.queryDeviceAnchor(
                atTimestamp: CACurrentMediaTime()
            ), anchor.isTracked {
                latestDeviceTransform = anchor.originFromAnchorTransform
                let forward = -SIMD3<Float>(
                    anchor.originFromAnchorTransform.columns.2.x,
                    anchor.originFromAnchorTransform.columns.2.y,
                    anchor.originFromAnchorTransform.columns.2.z
                )
                flight?.setWalkingFacingDirection(forward)
            }
            try? await Task.sleep(for: .milliseconds(16))
        }
    }

    private func isInWalkingActivationZone(
        _ handPosition: SIMD3<Float>
    ) -> Bool {
        guard let transform = latestDeviceTransform else { return false }
        let headPosition = SIMD3<Float>(
            transform.columns.3.x,
            transform.columns.3.y,
            transform.columns.3.z
        )
        let headRight = simd_normalize(
            SIMD3<Float>(
                transform.columns.0.x,
                transform.columns.0.y,
                transform.columns.0.z
            )
        )
        let headUp = simd_normalize(
            SIMD3<Float>(
                transform.columns.1.x,
                transform.columns.1.y,
                transform.columns.1.z
            )
        )
        let headForward = simd_normalize(
            -SIMD3<Float>(
                transform.columns.2.x,
                transform.columns.2.y,
                transform.columns.2.z
            )
        )
        let offset = handPosition - headPosition
        let forwardDistance = simd_dot(offset, headForward)
        let sideDistance = abs(simd_dot(offset, headRight))
        let verticalDistance = simd_dot(offset, headUp)
        return forwardDistance >= 0.08
            && forwardDistance <= 0.90
            && sideDistance <= 0.70
            && verticalDistance >= -0.65
            && verticalDistance <= 0.35
    }

    private func isWalkingRoleSelectionPose(
        _ pose: HandPose
    ) -> Bool {
        isForgivingWalkingPose(pose)
            && !isPalmFacingUser(pose)
            && !(pose.allDigitsSpread
                && isBackOfHandFacingUser(pose))
    }

    private func isForgivingWalkingPose(
        _ pose: HandPose
    ) -> Bool {
        pose.thumbRaisedForWalking
            && pose.handOpenForWalking
            && isInWalkingActivationZone(pose.fistPosition)
    }

    private func isPalmFacingUser(_ pose: HandPose) -> Bool {
        guard let transform = latestDeviceTransform else { return false }
        let headPosition = SIMD3<Float>(
            transform.columns.3.x,
            transform.columns.3.y,
            transform.columns.3.z
        )
        let toHead = headPosition - pose.fistPosition
        guard simd_length_squared(toHead) > 0.001 else { return false }
        return simd_dot(
            pose.palmNormal,
            simd_normalize(toHead)
        ) > 0.42
    }

    private func isBackOfHandFacingUser(_ pose: HandPose) -> Bool {
        guard let transform = latestDeviceTransform else { return false }
        let headPosition = SIMD3<Float>(
            transform.columns.3.x,
            transform.columns.3.y,
            transform.columns.3.z
        )
        let toHead = headPosition - pose.fistPosition
        guard simd_length_squared(toHead) > 0.001 else { return false }
        return simd_dot(
            -pose.palmNormal,
            simd_normalize(toHead)
        ) > 0.42
    }

    private func processToolMenuInteraction() {
        guard let flight,
              flight.surfaceToolMenuVisible,
              let dominantPose,
              dominantPose.indexExtended else {
            toolMenuTouchActive = false
            toolMenuTouchStartX = nil
            return
        }
        guard let slot = flight.surfaceToolSlot(
            at: dominantPose.indexTip
        ), let localX = flight.surfaceToolMenuLocalX(
            for: dominantPose.indexTip
        ) else {
            toolMenuTouchActive = false
            toolMenuTouchStartX = nil
            return
        }
        if !toolMenuTouchActive {
            toolMenuTouchActive = true
            toolMenuTouchStartX = localX
            flight.selectSurfaceTool(at: slot)
            return
        }
        guard let startX = toolMenuTouchStartX else { return }
        let swipe = localX - startX
        if abs(swipe) >= 0.048 {
            flight.cycleSurfaceTool(by: swipe > 0 ? 1 : -1)
            toolMenuTouchStartX = localX
        }
    }

    private func processCollectionGesture() {
        guard let flight,
              flight.activeExplorationMode == "Leave on foot",
              let supportPose = nonDominantPose else {
            collectionGestureActive = false
            collectionGestureArmed = false
            return
        }

        guard !activationGestureEngaged else {
            collectionGestureActive = false
            return
        }

        // A deliberate non-dominant pinch while looking at a loose material is
        // also a complete pickup gesture. Keep it edge-triggered so holding the
        // pinch cannot repeatedly collect everything in the gaze window.
        if supportPose.thumbIndexPinched {
            if !collectionGestureActive {
                collectionGestureActive = true
                collectionGestureArmed = false
                if let gaze = currentHeadGaze() {
                    flight.collectLookedAtSurfaceItem(
                        from: gaze.position,
                        direction: gaze.direction
                    )
                }
            }
            return
        }

        if supportPose.isCShape && !supportPose.grabClosed {
            collectionGestureArmed = true
            collectionGestureActive = false
            return
        }

        if collectionGestureArmed,
           supportPose.grabClosed,
           !collectionGestureActive {
            collectionGestureActive = true
            collectionGestureArmed = false
            if let gaze = currentHeadGaze() {
                flight.collectLookedAtSurfaceItem(
                    from: gaze.position,
                    direction: gaze.direction
                )
            }
        } else if !supportPose.grabClosed {
            collectionGestureActive = false
            if !supportPose.isCShape {
                collectionGestureArmed = false
            }
        }
    }

    private var nonDominantPose: HandPose? {
        guard let dominantHand else { return nil }
        return dominantHand == .left ? rightPose : leftPose
    }

    private var dominantPose: HandPose? {
        guard let dominantHand else { return nil }
        return dominantHand == .left ? leftPose : rightPose
    }

    private func processActivationGesture(now: Double) {
        guard let flight,
              flight.canPresentInventory,
              let leftPose,
              let rightPose else {
            resetActivationGesture()
            return
        }

        if !activationGestureEngaged {
            let bothHandsFormC =
                leftPose.isCShape
                    && rightPose.isCShape
                    && !leftPose.grabClosed
                    && !rightPose.grabClosed
            guard bothHandsFormC else { return }
            activationGestureEngaged = true
            activationGestureConsumed = false
            leftActivationPinchTime = nil
            rightActivationPinchTime = nil
            collectionGestureArmed = false
            return
        }

        let leftStillValid =
            leftPose.isCShape || leftPose.grabClosed
        let rightStillValid =
            rightPose.isCShape || rightPose.grabClosed
        guard leftStillValid, rightStillValid else {
            resetActivationGesture()
            return
        }

        if activationGestureConsumed {
            if !leftPose.grabClosed,
               !rightPose.grabClosed {
                resetActivationGesture()
            }
            return
        }

        if leftPose.grabClosed,
           leftActivationPinchTime == nil {
            leftActivationPinchTime = now
        }
        if rightPose.grabClosed,
           rightActivationPinchTime == nil {
            rightActivationPinchTime = now
        }

        guard let leftTime = leftActivationPinchTime,
              let rightTime = rightActivationPinchTime else {
            return
        }
        guard abs(leftTime - rightTime) <= 0.60 else {
            resetActivationGesture()
            return
        }
        guard leftPose.grabClosed,
              rightPose.grabClosed else {
            return
        }
        flight.activateEquippedInventoryItem()
        // Keep collection suppressed until both hands leave the pinch/C pose.
        activationGestureConsumed = true
    }

    private func resetActivationGesture() {
        activationGestureEngaged = false
        activationGestureConsumed = false
        leftActivationPinchTime = nil
        rightActivationPinchTime = nil
    }

    private func currentHeadGaze() -> (
        position: SIMD3<Float>,
        direction: SIMD3<Float>
    )? {
        guard let transform = latestDeviceTransform else { return nil }
        return (
            position: SIMD3<Float>(
                transform.columns.3.x,
                transform.columns.3.y,
                transform.columns.3.z
            ),
            direction: simd_normalize(
                -SIMD3<Float>(
                    transform.columns.2.x,
                    transform.columns.2.y,
                    transform.columns.2.z
                )
            )
        )
    }

    private func processEatingGesture(
        _ pose: HandPose,
        now: Double
    ) {
        guard let flight,
              let item = flight.equippedInventoryItem,
              let transform = latestDeviceTransform else {
            resetEatingGesture()
            return
        }
        if eatingItemID != nil, eatingItemID != item.id {
            resetEatingGesture()
        }

        let headPosition = SIMD3<Float>(
            transform.columns.3.x,
            transform.columns.3.y,
            transform.columns.3.z
        )
        let headUp = simd_normalize(
            SIMD3<Float>(
                transform.columns.1.x,
                transform.columns.1.y,
                transform.columns.1.z
            )
        )
        let headForward = simd_normalize(
            -SIMD3<Float>(
                transform.columns.2.x,
                transform.columns.2.y,
                transform.columns.2.z
            )
        )
        let mouthPosition =
            headPosition + headForward * 0.08 - headUp * 0.10
        let itemPosition =
            pose.fistPosition + pose.wristToKnuckles * 0.08
        let mouthDistance = simd_distance(itemPosition, mouthPosition)
        let allowedDistance: Float =
            eatingStartedAt == nil ? 0.18 : 0.24

        guard mouthDistance <= allowedDistance else {
            if eatingStartedAt != nil {
                flight.cancelEatingAttempt()
            }
            resetEatingGesture()
            return
        }
        guard !eatingGestureConsumed else { return }

        if eatingStartedAt == nil {
            eatingStartedAt = now
            eatingItemID = item.id
            lastEatingFragmentTime = now - 0.18
            flight.beginEatingAttempt(item)
        }
        if now - lastEatingFragmentTime >= 0.18 {
            lastEatingFragmentTime = now
            flight.emitEatingFragments(from: itemPosition)
        }
        guard now - (eatingStartedAt ?? now) >= 2 else { return }
        flight.eatEquippedInventoryItem()
        eatingStartedAt = nil
        eatingGestureConsumed = true
        lastEatingFragmentTime = 0
    }

    private func resetEatingGesture() {
        eatingStartedAt = nil
        eatingItemID = nil
        lastEatingFragmentTime = 0
        eatingGestureConsumed = false
    }

    private func processDominantSurfaceTool(
        _ pose: HandPose,
        now: Double
    ) {
        guard let flight else { return }
        let toolTip =
            pose.fistPosition + pose.wristToKnuckles * 0.26
        defer { lastDominantToolTip = toolTip }

        if lastSelectedSurfaceTool != flight.selectedSurfaceTool {
            flight.stopMatterCrumblerBeam()
            lastSelectedSurfaceTool = flight.selectedSurfaceTool
            surfaceToolTriggerArmed = false
            surfaceToolTriggerPressed = false
            lastDominantToolTip = nil
            lastMatterCrumblerUpdateTime = nil
        }
        let thumbPressed = pose.thumbFoldRatio < 0.92
        let thumbReleased = pose.thumbFoldRatio > 1.00
        if thumbReleased {
            surfaceToolTriggerArmed = true
            surfaceToolTriggerPressed = false
        }

        switch flight.selectedSurfaceTool {
        case .sonicSlicer:
            if surfaceToolTriggerArmed,
               thumbPressed,
               now - lastSurfaceToolImpactTime > 0.35 {
                surfaceToolTriggerArmed = false
                surfaceToolTriggerPressed = true
                flight.applySelectedSurfaceTool(
                    atWorldPosition: toolTip,
                    direction: pose.wristToKnuckles
                )
                lastSurfaceToolImpactTime = now
            }
        case .matterCrumbler:
            if surfaceToolTriggerArmed, thumbPressed {
                surfaceToolTriggerPressed = true
                let elapsed = lastMatterCrumblerUpdateTime.map {
                    max(0, min(now - $0, 0.10))
                } ?? 0
                lastMatterCrumblerUpdateTime = now
                flight.updateMatterCrumblerBeam(
                    from: toolTip,
                    direction: pose.wristToKnuckles,
                    deltaTime: Float(elapsed)
                )
            } else if thumbReleased {
                flight.stopMatterCrumblerBeam()
                lastMatterCrumblerUpdateTime = nil
            }
        case .matterLauncher, .analyzer:
            if surfaceToolTriggerArmed, thumbPressed {
                surfaceToolTriggerArmed = false
                surfaceToolTriggerPressed = true
                switch flight.selectedSurfaceTool {
                case .matterLauncher:
                    flight.fireMatterLauncher(
                        from: toolTip,
                        direction: pose.wristToKnuckles
                    )
                case .analyzer:
                    flight.showSurfaceToolActivation(
                        .analyzer,
                        from: toolTip,
                        direction: pose.wristToKnuckles
                    )
                    flight.analyzeSurfaceTarget(
                        from: toolTip,
                        direction: pose.wristToKnuckles
                    )
                case .empty, .sonicSlicer, .matterCrumbler:
                    break
                }
            }
        case .empty:
            flight.stopMatterCrumblerBeam()
            surfaceToolTriggerArmed = false
            surfaceToolTriggerPressed = false
        }
    }

    private func isPointingForward(
        _ direction: SIMD3<Float>
    ) -> Bool {
        guard let transform = latestDeviceTransform else { return false }
        let headForward = simd_normalize(
            -SIMD3<Float>(
                transform.columns.2.x,
                transform.columns.2.y,
                transform.columns.2.z
            )
        )
        return simd_dot(
            simd_normalize(direction),
            headForward
        ) > 0.52
    }

    private func resetSurfaceToolGestureState() {
        flight?.stopMatterCrumblerBeam()
        lastDominantToolTip = nil
        lastSurfaceToolImpactTime = 0
        lastMatterCrumblerUpdateTime = nil
        surfaceToolTriggerArmed = false
        surfaceToolTriggerPressed = false
        lastSelectedSurfaceTool = nil
    }

    private func applyJoystick(_ pose: HandPose) {
        guard let flight else { return }
        guard pose.fingersCurled else {
            joystickNeutral = nil
            clearJoystick()
            return
        }
        if joystickNeutral == nil {
            guard pose.thumbIsUp || flight.isSurfaceExploration else {
                return
            }
            joystickNeutral = pose.frame
            flight.grabJoystick(at: pose.fistPosition)
        }
        guard let neutral = joystickNeutral else { return }

        let lateralTilt = simd_dot(pose.frame.up, neutral.right)
        let forwardTilt = simd_dot(pose.frame.up, neutral.forward)
        let lateral = angularInput(lateralTilt)
        let pitch = angularInput(-forwardTilt)

        if flight.isSurfaceExploration {
            flight.setExplorationControls(
                forward: -pitch,
                turn: lateral
            )
            flight.dominantHandActive = true
            flight.dominantHandName = dominantHand == .left ? "LEFT" : "RIGHT"
            updateStatus()
            return
        }

        flight.rollInput = smoothed(flight.rollInput, toward: -lateral * 0.78)
        flight.yawInput = smoothed(flight.yawInput, toward: -lateral)
        flight.pitchInput = smoothed(flight.pitchInput, toward: pitch)
        updateLaserTrigger(thumbFoldRatio: pose.thumbFoldRatio, thumbIsUp: pose.thumbIsUp)

        if !flight.hasAutopilotTarget {
            flight.autopilot = false
        }
        flight.dominantHandActive = true
        flight.dominantHandName = dominantHand == .left ? "LEFT" : "RIGHT"
        updateStatus()
    }

    private func updateLaserTrigger(thumbFoldRatio: Float, thumbIsUp: Bool) {
        guard let flight else { return }

        if dominantTriggerPressed {
            if thumbIsUp || thumbFoldRatio > 1.05 {
                dominantTriggerPressed = false
                flight.setWeaponTrigger(false)
            }
        } else if thumbFoldRatio < 0.86 {
            dominantTriggerPressed = true
            flight.setWeaponTrigger(true)
        }
    }

    private func applyThrottle(_ pose: HandPose) {
        guard let flight else { return }
        if throttleNeutralPosition == nil {
            throttleNeutralPosition = pose.fistPosition
            throttleNeutralValue = flight.throttle
            flight.grabThrottle(
                at: pose.fistPosition,
                secondaryHandIsLeft: dominantHand == .right
            )
        }
        guard let neutral = throttleNeutralPosition else { return }

        let travel = pose.fistPosition.z - neutral.z
        if travel < 0 {
            let amount = min(Double(-travel / 0.22), 1)
            flight.throttle = throttleNeutralValue + (1 - throttleNeutralValue) * amount
        } else {
            let amount = min(Double(travel / 0.22), 1)
            flight.throttle = throttleNeutralValue + (-0.5 - throttleNeutralValue) * amount
        }

        updateHyperDriveButton(thumbFoldRatio: pose.thumbFoldRatio)
        flight.supportHandActive = true
        updateStatus()
    }

    private func updateHyperDriveButton(thumbFoldRatio: Float) {
        guard let flight else { return }
        let now = ProcessInfo.processInfo.systemUptime

        if flight.isWithinPlanetAtmosphere {
            hyperDrivePressStartedAt = nil
            if thumbFoldRatio < 0.86 {
                flight.setAtmosphericBoostHeld(true)
            } else if thumbFoldRatio > 0.94 {
                flight.setAtmosphericBoostHeld(false)
            }
            return
        }

        if flight.isAtmosphericBoostHeld {
            flight.setAtmosphericBoostHeld(false)
        }

        if flight.isBoosting {
            if thumbFoldRatio > 1.03 {
                hyperDrivePressStartedAt = nil
                flight.cancelHyperDriveCharge()
            }
            return
        }

        if thumbFoldRatio < 0.86 {
            if hyperDrivePressStartedAt == nil {
                hyperDrivePressStartedAt = now
            }
            let elapsed = now - (hyperDrivePressStartedAt ?? now)
            let remaining = max(0, 3 - elapsed)
            if remaining == 0 {
                flight.activateHyperDrive()
            } else {
                flight.updateHyperDriveCharge(remaining: remaining)
            }
        } else if thumbFoldRatio > 0.94 {
            hyperDrivePressStartedAt = nil
            flight.cancelHyperDriveCharge()
        }
    }

    private func handleTrackingLoss(_ chirality: HandAnchor.Chirality, now: Double) {
        resetActivationGesture()
        if chirality == dominantHand, eatingStartedAt != nil {
            flight?.cancelEatingAttempt()
            resetEatingGesture()
        }
        if chirality != dominantHand {
            flight?.setInventoryVisible(false)
        }
        if flight?.activeExplorationMode == "Leave on foot",
           chirality != dominantHand {
            guard now - lastWalkingTrackingTime > 0.35 else { return }
            walkingGestureBeganAt = nil
            flight?.setWalkingGestureActive(false)
            flight?.setSurfaceToolMenuVisible(false)
            flight?.setInventoryVisible(false)
            flight?.supportHandActive = false
            updateStatus()
            return
        }
        if chirality == dominantHand {
            if flight?.activeExplorationMode == "Leave on foot",
               flight?.selectedSurfaceTool == .matterCrumbler,
               surfaceToolTriggerPressed {
                flight?.setMatterCrumblerTrackingHold(true)
            }
            guard now - lastJoystickTrackingTime > 0.22 else { return }
            joystickNeutral = nil
            clearJoystick()
            flight?.setHeldSurfaceToolVisible(false)
        } else {
            guard throttleNeutralPosition != nil || flight?.supportHandActive == true else { return }
            guard now - lastThrottleTrackingTime > 0.18 else { return }
            throttleNeutralPosition = nil
            releaseThrottle()
        }
        updateStatus()
    }

    private func synchronizeExplorationMode() {
        guard let flight else { return }
        let mode = flight.activeExplorationMode
        guard mode != lastExplorationMode else { return }

        lastExplorationMode = mode
        if mode == "Leave on foot" {
            dominantHand = nil
            secondaryHand = nil
            flight.dominantHandName = "—"
        } else {
            secondaryHand = nil
        }
        joystickNeutral = nil
        throttleNeutralPosition = nil
        walkingGestureBeganAt = nil
        lastWalkingPoseMatchTime = 0
        toolMenuTouchActive = false
        toolMenuTouchStartX = nil
        collectionGestureActive = false
        collectionGestureArmed = false
        resetActivationGesture()
        resetSurfaceToolGestureState()
        resetEatingGesture()
        flight.setWalkingGestureActive(false)
        flight.setSurfaceToolMenuVisible(false)
        flight.setInventoryVisible(false)
        flight.setHeldSurfaceToolVisible(
            mode == "Leave on foot"
        )
        flight.setExplorationControls(forward: 0, turn: 0)
        flight.dominantHandActive = false
        flight.supportHandActive = false
        flight.releaseJoystickVisual()
        flight.releaseThrottleVisual()
    }

    private func clearJoystick() {
        flight?.pitchInput = 0
        flight?.yawInput = 0
        flight?.rollInput = 0
        flight?.setExplorationControls(forward: 0, turn: 0)
        dominantTriggerPressed = false
        flight?.setWeaponTrigger(false)
        flight?.dominantHandActive = false
        flight?.releaseJoystickVisual()
    }

    private func releaseThrottle() {
        guard let flight else { return }
        flight.throttle = Double(flight.speed / flight.maximumForwardSpeed)
        hyperDrivePressStartedAt = nil
        flight.cancelHyperDriveCharge()
        flight.supportHandActive = false
        flight.releaseThrottleVisual()
    }

    private func updateStatus() {
        guard let flight else { return }
        if flight.isSurfaceExploration {
            if flight.activeExplorationMode == "Leave on foot",
               secondaryHand == nil {
                flight.handTrackingStatus =
                    "Show the walking pose with either hand"
            } else {
                flight.handTrackingStatus =
                    flight.activeExplorationMode == "Deploy rover"
                    ? "Rover steering active"
                    : (flight.walkingGestureActive
                        ? "Walking toward view direction"
                        : "Extend secondary hand to walk")
            }
        } else if flight.isAtmosphericBoostHeld
                    || flight.atmosphericBoostBlend > 0.01 {
            flight.handTrackingStatus = "Atmospheric boost active — release to ramp down"
        } else if flight.isBoosting {
            flight.handTrackingStatus = "Hyper speed active — unlimited fuel"
        } else if flight.isHyperDriveCharging {
            flight.handTrackingStatus =
                "Hyper speed in \(Int(ceil(flight.hyperDriveCountdown)))"
        } else if flight.dominantHandActive && flight.supportHandActive {
            flight.handTrackingStatus = "Joystick + throttle active"
        } else if flight.dominantHandActive {
            flight.handTrackingStatus = "Joystick active"
        } else {
            flight.handTrackingStatus = "Grip joystick with thumb up"
        }
    }

    private func pose(for anchor: HandAnchor) -> HandPose? {
        guard let skeleton = anchor.handSkeleton else { return nil }

        let wrist = worldPosition(.wrist, skeleton: skeleton, anchor: anchor)
        let thumbTip = worldPosition(.thumbTip, skeleton: skeleton, anchor: anchor)
        let thumbKnuckle = worldPosition(.thumbKnuckle, skeleton: skeleton, anchor: anchor)
        let indexKnuckle = worldPosition(.indexFingerKnuckle, skeleton: skeleton, anchor: anchor)
        let middleKnuckle = worldPosition(.middleFingerKnuckle, skeleton: skeleton, anchor: anchor)
        let ringKnuckle = worldPosition(.ringFingerKnuckle, skeleton: skeleton, anchor: anchor)
        let littleKnuckle = worldPosition(.littleFingerKnuckle, skeleton: skeleton, anchor: anchor)
        let palmWidth = max(simd_distance(indexKnuckle, littleKnuckle), 0.045)

        let fingerPairs: [(HandSkeleton.JointName, SIMD3<Float>)] = [
            (.indexFingerTip, indexKnuckle),
            (.middleFingerTip, middleKnuckle),
            (.ringFingerTip, ringKnuckle),
            (.littleFingerTip, littleKnuckle)
        ]
        let fingerTipPositions = fingerPairs.map { jointName, _ in
            worldPosition(jointName, skeleton: skeleton, anchor: anchor)
        }
        let fingerExtensionRatios = zip(
            fingerTipPositions,
            fingerPairs.map { $0.1 }
        ).map { tip, knuckle in
            simd_distance(tip, knuckle)
                / palmWidth
        }
        // A tip-to-knuckle distance alone cannot distinguish a straight
        // finger from a fist: both can occupy the same 1.05...1.12 range.
        // Require every finger to continue outward from the wrist through
        // its knuckle so flexed or folded fingers fail immediately.
        let fingerStraightness = zip(
            fingerTipPositions,
            fingerPairs.map { $0.1 }
        ).map { tip, knuckle in
            let palmDirection = knuckle - wrist
            let fingerDirection = tip - knuckle
            guard simd_length_squared(palmDirection) > 0.000_001,
                  simd_length_squared(fingerDirection) > 0.000_001 else {
                return Float(-1)
            }
            return simd_dot(
                simd_normalize(palmDirection),
                simd_normalize(fingerDirection)
            )
        }
        let fingersCurled =
            fingerExtensionRatios.allSatisfy { $0 < 1.12 }
        // Natural open hands vary substantially by finger length. Requiring
        // every fingertip to clear the old 1.38 ratio made the walking pose
        // nearly impossible, especially for the little finger.
        let extendedFingerCount =
            fingerExtensionRatios.filter { $0 > 1.08 }.count
        let fingersOutstretched =
            extendedFingerCount >= 3
                && fingerExtensionRatios.allSatisfy { $0 > 0.82 }
        let indexTip = fingerTipPositions[0]

        let knuckleCenter = (indexKnuckle + middleKnuckle + ringKnuckle + littleKnuckle) / 4
        let fistPosition = (wrist + knuckleCenter) / 2

        // Treat the little-finger side as the fixed base of a vertical joystick
        // and the index-finger side as its top. Translation does not affect this axis.
        let joystickUp = simd_normalize(indexKnuckle - littleKnuckle)
        let worldForward = SIMD3<Float>(0, 0, -1)
        let joystickRight = simd_normalize(simd_cross(worldForward, joystickUp))
        let joystickForward = simd_normalize(simd_cross(joystickUp, joystickRight))
        let frame = FistFrame(
            right: joystickRight,
            up: joystickUp,
            forward: joystickForward
        )

        let thumbVector = thumbTip - thumbKnuckle
        let thumbFoldRatio = min(
            simd_distance(thumbTip, indexKnuckle),
            simd_distance(thumbTip, middleKnuckle)
        ) / palmWidth
        let thumbIsUp =
            simd_length(thumbVector) / palmWidth > 0.62
            && simd_normalize(thumbVector).y > 0.42
            && thumbFoldRatio > 0.9
        let thumbRaisedForWalking =
            simd_length(thumbVector) / palmWidth > 0.50
                && simd_normalize(thumbVector).y > 0.18
                && thumbFoldRatio > 0.76
        let handOpenForWalking =
            extendedFingerCount >= 2
                && fingerExtensionRatios.filter { $0 > 0.78 }.count >= 3

        let uncorrectedAcrossPalm = littleKnuckle - indexKnuckle
        let palmRight = simd_normalize(
            anchor.chirality == .right ? uncorrectedAcrossPalm : -uncorrectedAcrossPalm
        )
        let wristToKnuckles = simd_normalize(knuckleCenter - wrist)
        let backOfHandNormal = simd_normalize(simd_cross(palmRight, wristToKnuckles))
        let palmNormal = -backOfHandNormal
        let knucklesAreUp = backOfHandNormal.y > 0.48
        let thumbIndexSpan =
            simd_distance(thumbTip, indexTip) / palmWidth
        let adjacentFingerSpreads = zip(
            fingerTipPositions,
            fingerTipPositions.dropFirst()
        ).map {
            simd_distance($0.0, $0.1) / palmWidth
        }
        let allDigitsSpread =
            !fingersCurled
                && fingerExtensionRatios.allSatisfy { $0 > 1.05 }
                && fingerStraightness.allSatisfy { $0 > 0.58 }
                && adjacentFingerSpreads.allSatisfy { $0 > 0.26 }
                && thumbIndexSpan > 0.72
                && simd_length(thumbVector) / palmWidth > 0.62
        let isCShape =
            !fingersCurled
                && thumbIndexSpan >= 0.46
                && thumbIndexSpan <= 1.70
                && fingerExtensionRatios[0] > 0.76
                && fingerExtensionRatios[1...3]
                    .filter { $0 < 1.32 }.count >= 2
        let thumbIndexPinched = thumbIndexSpan < 0.48
        let grabClosed =
            thumbIndexPinched || fingersCurled

        return HandPose(
            wrist: wrist,
            fistPosition: fistPosition,
            indexTip: indexTip,
            palmNormal: palmNormal,
            wristToKnuckles: wristToKnuckles,
            frame: frame,
            thumbIsUp: thumbIsUp,
            thumbRaisedForWalking: thumbRaisedForWalking,
            thumbFoldRatio: thumbFoldRatio,
            knucklesAreUp: knucklesAreUp,
            fingersCurled: fingersCurled,
            fingersOutstretched: fingersOutstretched,
            handOpenForWalking: handOpenForWalking,
            allDigitsSpread: allDigitsSpread,
            indexExtended: fingerExtensionRatios[0] > 1.05,
            isCShape: isCShape,
            grabClosed: grabClosed,
            thumbIndexPinched: thumbIndexPinched
        )
    }

    private func worldPosition(
        _ jointName: HandSkeleton.JointName,
        skeleton: HandSkeleton,
        anchor: HandAnchor
    ) -> SIMD3<Float> {
        let transform = anchor.originFromAnchorTransform
            * skeleton.joint(jointName).anchorFromJointTransform
        return SIMD3<Float>(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
    }

    private func angularInput(_ component: Float) -> Double {
        let deadZone: Float = 0.03
        let fullTilt: Float = 0.31
        let magnitude = abs(component)
        guard magnitude > deadZone else { return 0 }
        let normalized = min((magnitude - deadZone) / (fullTilt - deadZone), 1)
        return Double(copysign(normalized, component))
    }

    private func smoothed(_ current: Double, toward target: Double) -> Double {
        current + (target - current) * 0.48
    }
}

private struct FistFrame {
    let right: SIMD3<Float>
    let up: SIMD3<Float>
    let forward: SIMD3<Float>
}

private struct HandPose {
    let wrist: SIMD3<Float>
    let fistPosition: SIMD3<Float>
    let indexTip: SIMD3<Float>
    let palmNormal: SIMD3<Float>
    let wristToKnuckles: SIMD3<Float>
    let frame: FistFrame
    let thumbIsUp: Bool
    let thumbRaisedForWalking: Bool
    let thumbFoldRatio: Float
    let knucklesAreUp: Bool
    let fingersCurled: Bool
    let fingersOutstretched: Bool
    let handOpenForWalking: Bool
    let allDigitsSpread: Bool
    let indexExtended: Bool
    let isCShape: Bool
    let grabClosed: Bool
    let thumbIndexPinched: Bool
}
