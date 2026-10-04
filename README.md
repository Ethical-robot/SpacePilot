# Space Pilot

A small native Apple Vision Pro space-flight simulator built with SwiftUI, RealityKit, and GameController.

## Run

1. Open `SpacePilot.xcodeproj` in Xcode.
2. Select the **SpacePilot** scheme and an Apple Vision Pro simulator (or a provisioned device).
3. Build and run, then select **Enter the cockpit**.

Grip the visible fixed-base joystick with one fist and raise the thumb to activate it. The control snaps into the hand and moves with the measured fist tilt. Lean it left or right for a coordinated turn and bank, away from you to pitch down, or toward you to pitch up. Press the thumb onto the fire button to fire continuously, and raise it to stop.

Hold the other hand in a fist with the knuckles facing up to grab the visible throttle. Push it forward for maximum forward speed or pull it back for reverse at up to half the maximum forward speed. Opening, rotating, or removing the throttle hand preserves the current speed.

The physical joystick and throttle remain hidden until their corresponding grip poses are detected, then disappear again when released so they do not obstruct the flight view.

At any throttle setting, hold the throttle-hand thumb on the orange turbo button for a visible three-second countdown. During this spool-up phase the ship travels forward at 4× normal top speed without consuming hyper-fuel. When the countdown reaches zero, 1,000× hyper speed and its directional streak tunnel engage. Extend the thumb to cancel. Hyperdrive fuel is unlimited during the current prototype. The expanded universe uses 100× interplanetary distances, preserving approximately the same hyperdrive travel time as before.

The lower cockpit panel controls landing, takeoff, docking, equipped weapons, unlimited-charge detection, autopilot target cancellation, and context-sensitive ship exits. The test loadout contains Laser, Missile, and Slow Beam weapons. Missile fires once per thumb press and locks targets inside its wide reticle. Slow Beam is a wider blue continuous beam whose slowdown grows with contact time. The test inventory includes a rover and drone.

Use the window sliders for thrust, pitch, and yaw. A paired controller uses the left stick for yaw/pitch, the right stick for roll, the right trigger for thrust, A for autopilot, and B for full stop.

The universe uses deterministic seeded sectors. Nearby regions stream into RealityKit as the player travels and distant regions unload automatically. The starting sector contains the familiar solar-system prototype; surrounding sectors contain reproducible procedural destinations. No downloaded assets or network access are required.

Planetary atmospheres establish a radial surface-up direction and progressively limit speed during descent. The extended upper atmosphere shows broad, rough biome landmarks; the deep lower atmosphere retains normal dogfighting speed near its upper boundary and reveals forests, terrain formations, landing sites, and other mid-scale details. Leaving the ship enables an additional ground-detail layer. If the dominant-hand joystick is released while inside an atmosphere, the ship gently rights itself relative to the planet while preserving pilot control whenever the stick is held. The cockpit reports atmospheric altitude and warns about dangerous star heat; sustained close star exposure destroys the ship.

Planet surfaces use deterministic type-specific biomes: ocean worlds include raised continents, forests, trees, hills, and valleys; desert worlds include dunes, mesas, and canyons; rocky worlds include highlands, craters, and boulders; ice worlds include shelves, ridges, and crevasses; and gas worlds include cloud bands and large storms.

After landing, choose **Deploy rover** or **Leave on foot**. The dominant fist becomes a surface controller: tilt forward or backward to move and left or right to steer. The rover travels at a medium 11 m/s maximum while on-foot movement is limited to 2.6 m/s. Both modes follow the curved surface and display a dedicated speed and heading HUD.

See [CONTROLS.md](CONTROLS.md) for the full living list of hand gestures, gamepad bindings, and HUD/window controls (update that file whenever controls change).

See [TASKS.md](TASKS.md) for the long-term gameplay and production roadmap.
