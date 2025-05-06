import SwiftUI

struct ContentView: View {
    enum Tab { case map, logs, countries }
    @State private var selection: Tab = .map

    var body: some View {
        TabView(selection: $selection) {
            MapScreen()
                .tabItem { Label("Map", systemImage: "map") }
                .tag(Tab.map)
            
            ProfileScreen()
                .tabItem { Label("Countries", systemImage: "globe") }
                .tag(Tab.countries)


            LogsScreen()
                .tabItem { Label("Logs", systemImage: "list.bullet") }
                .tag(Tab.logs)

        }
    }
}
