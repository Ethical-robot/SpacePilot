import SwiftUI

struct MissionControlView: View {
    @Environment(FlightModel.self) private var flight
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace

    var body: some View {
        @Bindable var flight = flight

        ZStack {
            LinearGradient(
                colors: [Color(red: 0.025, green: 0.045, blue: 0.11), .black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("SPACE PILOT")
                            .font(.system(size: 34, weight: .black, design: .rounded))
                        Text("VISION FLIGHT CONTROL")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.cyan)
                            .tracking(3)
                    }
                    Spacer()
                    StatusPill(isOnline: flight.isImmersive)
                }

                if flight.isImmersive {
                    telemetry
                    flightControls
                    actionButtons
                } else {
                    welcomeCard
                    Button {
                        Task {
                            let result = await openImmersiveSpace(id: FlightModel.immersiveSpaceID)
                            if case .opened = result {
                                flight.isImmersive = true
                                flight.resetFlight()
                            }
                        }
                    } label: {
                        Label("Enter the cockpit", systemImage: "visionpro")
                            .font(.title3.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.cyan)
                }
            }
            .padding(32)
        }
    }

    private var welcomeCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Image(systemName: "sparkles")
                .font(.system(size: 44))
                .foregroundStyle(.cyan)
            Text("Your solar system awaits.")
                .font(.title2.bold())
            Text("Fly through a procedural star field, visit four worlds, or let the navigation computer steer toward the nearest destination.")
                .foregroundStyle(.secondary)
            Divider()
            Label("Look around naturally in the full immersive space", systemImage: "eye")
            Label("Use the panel or a paired game controller", systemImage: "gamecontroller")
            Label("Remain seated or stationary while flying", systemImage: "figure.seated.seatbelt")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(26)
        .glassBackgroundEffect()
    }

    private var telemetry: some View {
        HStack(spacing: 12) {
            MetricCard(label: "SPEED", value: String(format: "%.1f", flight.displayedTravelSpeed), unit: "m/s")
            MetricCard(label: "NEAREST", value: flight.nearestObject, unit: String(format: "%.0f m", flight.nearestDistance))
            MetricCard(label: "DISTANCE", value: String(format: "%.0f", flight.displayedDistanceTravelled), unit: "m")
            MetricCard(label: "MISSION", value: formattedTime, unit: "")
        }
    }

    private var flightControls: some View {
        return VStack(spacing: 18) {
            ControlSlider(
                title: "THRUST",
                icon: "flame.fill",
                value: Binding(
                    get: { flight.throttle },
                    set: { flight.throttle = $0 }
                ),
                range: -0.5...1
            )
            ControlSlider(
                title: "PITCH",
                icon: "arrow.up.and.down",
                value: Binding(
                    get: { flight.pitchInput },
                    set: { flight.pitchInput = $0 }
                ),
                range: -1...1
            )
            ControlSlider(
                title: "YAW",
                icon: "arrow.left.and.right",
                value: Binding(
                    get: { flight.yawInput },
                    set: { flight.yawInput = $0 }
                ),
                range: -1...1
            )

            HStack {
                Label("HAND FLIGHT", systemImage: "hand.raised.fill")
                    .font(.caption.bold())
                Spacer()
                Text(flight.handTrackingStatus)
                    .font(.caption)
                    .foregroundStyle(flight.dominantHandActive ? .green : .secondary)
            }

            Toggle(isOn: Bindable(flight).autopilot) {
                Label("Navigation computer", systemImage: "scope")
            }
            .toggleStyle(.switch)
        }
        .padding(22)
        .glassBackgroundEffect()
    }

    private var actionButtons: some View {
        HStack {
            Button("Center controls") {
                flight.pitchInput = 0
                flight.yawInput = 0
                flight.rollInput = 0
                flight.strafeInputX = 0
                flight.strafeInputY = 0
            }
            Button("Full stop", systemImage: "stop.fill") {
                flight.stop()
            }
            .tint(.orange)
            Spacer()
            Button("Reset", systemImage: "arrow.counterclockwise") {
                flight.resetFlight()
            }
            Button("Exit space", systemImage: "rectangle.portrait.and.arrow.right") {
                Task {
                    await dismissImmersiveSpace()
                    flight.isImmersive = false
                }
            }
            .tint(.red)
        }
        .buttonStyle(.bordered)
    }

    private var formattedTime: String {
        let total = Int(flight.displayedElapsedTime)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}

private struct StatusPill: View {
    let isOnline: Bool

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(isOnline ? .green : .gray)
                .frame(width: 9, height: 9)
            Text(isOnline ? "FLIGHT ACTIVE" : "STANDBY")
                .font(.caption.bold())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .glassBackgroundEffect()
    }
}

private struct MetricCard: View {
    let label: String
    let value: String
    let unit: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.caption2.bold())
                .foregroundStyle(.cyan)
                .tracking(1)
            Text(value)
                .font(.title3.monospacedDigit().bold())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(unit.isEmpty ? " " : unit)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .glassBackgroundEffect()
    }
}

private struct ControlSlider: View {
    let title: String
    let icon: String
    @Binding var value: Double
    let range: ClosedRange<Double>

    var body: some View {
        HStack {
            Label(title, systemImage: icon)
                .font(.caption.bold())
                .frame(width: 105, alignment: .leading)
            Slider(value: $value, in: range)
            Text(String(format: "%+.0f%%", value * 100))
                .font(.caption.monospacedDigit())
                .frame(width: 54, alignment: .trailing)
        }
    }
}
