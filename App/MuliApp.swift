import SwiftUI

// The property wrapper also builds with the standalone Swift command-line tools.
typealias ViewState<Value> = SwiftUI.State<Value>

@main
struct MuliApp: App {
    var body: some Scene {
        #if os(macOS)
        Window("木历", id: "calendar") {
            CalendarScreen()
                .frame(minWidth: 340, minHeight: 420)
        }
        .defaultSize(width: 440, height: 580)
        .windowResizability(.contentMinSize)
        #else
        WindowGroup {
            CalendarScreen()
        }
        #endif
    }
}
