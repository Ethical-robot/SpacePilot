import SwiftUI

@main
struct SpacePilotApp: App {
    @State private var flight = FlightModel()
    @State private var immersionStyle: ImmersionStyle = SpacePilotApp
        .immersionStyle(forShowPeople: true)

    var body: some Scene {
        WindowGroup {
            MissionControlView()
                .environment(flight)
        }
        .defaultSize(width: 720, height: 620)

        ImmersiveSpace(id: FlightModel.immersiveSpaceID) {
            ImmersiveSpaceView()
                .environment(flight)
                .onAppear {
                    immersionStyle = Self.immersionStyle(
                        forShowPeople: flight.showPeopleWhilePlaying
                    )
                }
                .onChange(of: flight.showPeopleWhilePlaying) { _, showPeople in
                    immersionStyle = Self.immersionStyle(
                        forShowPeople: showPeople
                    )
                }
        }
        .immersionStyle(
            selection: $immersionStyle,
            in: .full, .progressive
        )
    }

    /// People on: progressive immersion (starts fully immersive; Crown can
    /// reveal surroundings so system People Awareness can show nearby people).
    /// People off: full immersion only.
    private static func immersionStyle(
        forShowPeople showPeople: Bool
    ) -> ImmersionStyle {
        if showPeople {
            .progressive(0.0...1.0, initialAmount: 1.0)
        } else {
            .full
        }
    }
}
