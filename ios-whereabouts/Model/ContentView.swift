import SwiftUI

struct ContentView: View {
    @StateObject private var locationManager = LocationManager()
    @StateObject private var visitStore = VisitStore.shared

    var body: some View {
        NavigationView {
            List {
                Section("Current Location") {
                    if let visit = locationManager.latestVisit {
                        Text("\(visit.countryName)")
                    } else {
                        Text("Waiting for location...")
                    }
                }

                Section("Visit Summary") {
                    let summaries = VisitSummaryGenerator.generate(from: visitStore.visits)

                    if summaries.isEmpty {
                        Text("Always allow location for this app and let data accumulate as time goes by.")
                            .foregroundColor(.gray)
                            .font(.footnote)
                    } else {
                        ForEach(summaries) { summary in
                            Text(summary.description)
                        }
                    }
                }
            }
            .navigationTitle("Country Visits")
            .onAppear {
//                VisitStore.shared.addMockVisits()

                locationManager.requestPermission()
                locationManager.startTracking()
                
                if VisitStore.shared.visits.isEmpty {
                    locationManager.fetchCurrentLocationOnce()
                }

            }
        }
    }
}
