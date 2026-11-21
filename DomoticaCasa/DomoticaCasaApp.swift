import SwiftUI

@main
struct DomoticaCasaApp: App {
    @StateObject private var home = HomeStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(home)
                .preferredColorScheme(.light)
        }
    }
}
