import SwiftUI

struct LogsScreen: View {
    @StateObject private var locationManager = LocationManager()
    @StateObject private var visitStore      = VisitStore.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    currentLocationCard

                    VStack(alignment: .leading, spacing: 16) {
                        Text("Visit History")
                            .font(.title2.weight(.semibold))
                            .padding(.horizontal)

                        ForEach(VisitSummaryGenerator.generate(from: visitStore.visits)) { summary in
                            VisitTimelineCard(summary: summary)
                                .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Country Visits")
            .onAppear {
                locationManager.requestPermission()
                locationManager.startTracking()
                if visitStore.visits.isEmpty {
                    locationManager.fetchCurrentLocationOnce()
                }
            }
        }
    }

    private var currentLocationCard: some View {
        GroupBox {
            HStack(spacing: 12) {
                Image(systemName: "location.fill")
                    .font(.largeTitle)
                    .foregroundStyle(Color.accentColor)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Location")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(locationManager.latestVisit?.countryName ?? "Waiting…")
                        .font(.title3.weight(.bold))
                }
                Spacer()
            }
            .padding(.vertical, 8)
        }
        .groupBoxStyle(.automatic)
        .padding(.horizontal)
    }
}

/// A “timeline” style card showing date range + description
struct VisitTimelineCard: View {
    let summary: VisitSummary

    // date formatter for the sub‑line
    private static let subdateFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f
    }()

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // timeline dot + line
            VStack {
                Circle()
                    .fill(summary.isMostRecent ? Color.accentColor : Color.gray.opacity(0.5))
                    .frame(width: 12, height: 12)
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
            }

            // card body
            VStack(alignment: .leading, spacing: 6) {
                // main description
                Text(summary.description)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)

                // sub‑date line
                Text(dateLine)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(.regularMaterial)
            .cornerRadius(10)
            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
    }

    private var dateLine: String {
        let start = Self.subdateFmt.string(from: summary.startDate)
        let end   = Self.subdateFmt.string(from: summary.endDate)
        return "\(start) – \(end)"
    }
}
