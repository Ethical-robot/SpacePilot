import SwiftUI

@main
struct SpacePilotApp: App {
    @State private var flight = FlightModel()
    @State private var immersionStyle: ImmersionStyle = .full

    var body: some Scene {
        WindowGroup {
            MissionControlView()
                .environment(flight)
        }
        .defaultSize(width: 720, height: 620)

        ImmersiveSpace(id: FlightModel.immersiveSpaceID) {
            ImmersiveSpaceView()
                .environment(flight)
        }
        .immersionStyle(selection: $immersionStyle, in: .full)
    }
}
