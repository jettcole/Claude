import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: Store

    var body: some View {
        TabView {
            SellView()
                .tabItem { Label("Sell", systemImage: "square.grid.2x2") }
                .badge(store.cart.count)

            LogView()
                .tabItem { Label("Log", systemImage: "list.bullet.rectangle.portrait") }

            ItemsView()
                .tabItem { Label("Items", systemImage: "shippingbox") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "slider.horizontal.3") }
        }
    }
}
