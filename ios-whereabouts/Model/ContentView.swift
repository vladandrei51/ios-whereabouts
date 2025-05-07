import SwiftUI

struct ContentView: View {
    enum Tab { case map, logs, countries }
    @State private var selection: Tab = .map
    
    @StateObject private var locationManager = LocationManager()
    @StateObject private var visitStore      = VisitStore.shared
    
    var body: some View {
        TabView(selection: $selection) {
            MapScreen()
                .tabItem { Label("Map", systemImage: "map") }
                .tag(Tab.map)
            
            CountryScreen()
                .tabItem { Label("Countries", systemImage: "globe") }
                .tag(Tab.countries)
            
            LogsScreen()
                .environmentObject(locationManager)
                .environmentObject(visitStore)
                .tabItem { Label("Logs", systemImage: "list.bullet") }
                .tag(Tab.logs)
        }
        .onAppear {
            locationManager.requestPermission()
            locationManager.startTracking()
            if visitStore.visits.isEmpty {
                locationManager.fetchCurrentLocationOnce()
            }
        }
    }
}
