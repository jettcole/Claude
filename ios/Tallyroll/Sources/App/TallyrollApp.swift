import SwiftUI

@main
struct TallyrollApp: App {
    @StateObject private var store = Store()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .tint(Palette.register)
        }
    }
}
