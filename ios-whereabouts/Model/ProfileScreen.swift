import SwiftUI

@available(iOS 17.0, *)
struct ProfileScreen: View {
    @State private var sortBy: SortOption = .name
    @State private var ascending = true
    @State private var selected: CountryProfile?
    @ObservedObject private var store = VisitStore.shared

    var body: some View {
        NavigationStack {
            List(profiles) { profile in
                Button {
                    selected = profile
                } label: {
                    HStack {
                        Text(profile.code.flagEmoji)
                        VStack(alignment: .leading) {
                            Text(profile.code.localizedCountryName)
                                .font(.headline)
                            Text("\(profile.totalDays) days")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 6)
                }
            }
            .navigationTitle("Countries")
            .toolbar {
                Menu {
                    Section("Sort by") {
                        ForEach(SortOption.allCases, id: \.self) { opt in
                            Button {
                                sortBy = opt
                            } label: {
                                HStack {
                                    Text(opt.title)
                                    if sortBy == opt {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    }
                    Section {
                        Button {
                            ascending.toggle()
                        } label: {
                            HStack {
                                Text(ascending ? "Ascending" : "Descending")
                                Image(systemName: ascending ? "arrow.up" : "arrow.down")
                            }
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")  // valid SF symbol
                }
            }
            .sheet(item: $selected) { CountryDetailSheet(profile: $0) }
        }
    }

    private var profiles: [CountryProfile] {
        let summaries = VisitSummaryGenerator.generate(from: store.visits)
        var dict: [String: TimeInterval] = [:]
        var visitsByCode: [String: [VisitSummary]] = [:]

        for s in summaries {
            let dur = s.endDate.timeIntervalSince(s.startDate)
            let code = s.countries.first!
            dict[code, default: 0] += dur
            visitsByCode[code, default: []].append(s)
        }

        var arr = dict.map { code, total in
            CountryProfile(code: code,
                           totalTime: total,
                           visits: visitsByCode[code]!)
        }

        switch sortBy {
        case .name:
            arr.sort {
                ascending
                ? $0.code.localizedCountryName < $1.code.localizedCountryName
                : $0.code.localizedCountryName > $1.code.localizedCountryName
            }
        case .time:
            arr.sort {
                ascending ? $0.totalTime < $1.totalTime
                          : $0.totalTime > $1.totalTime
            }
        }
        return arr
    }
}

enum SortOption: CaseIterable {
    case name, time
    var title: String {
        switch self {
            case .name: return "Name"
            case .time: return "Time"
        }
    }
}

struct CountryProfile: Identifiable {
    let id = UUID()
    let code: String
    let totalTime: TimeInterval
    let visits: [VisitSummary]

    var totalDays: Int {
        Int(totalTime / 86400) + (totalTime.truncatingRemainder(dividingBy: 86400) > 0 ? 1 : 0)
    }
}

struct CountryDetailSheet: View {
    let profile: CountryProfile

    var body: some View {
        VStack(spacing: 20) {
            Text(profile.code.localizedCountryName)
                .font(.largeTitle).bold()
            Text(profile.code.flagEmoji)
                .font(.system(size: 60))

            let full = profile.totalTime / 86400
            let fullDays = Int(floor(full))
            let partialDays = Int(profile.totalDays) - fullDays

            HStack {
                VStack {
                    Text("\(fullDays)")
                        .font(.title)
                    Text("full days")
                }
                Spacer()
                VStack {
                    Text("\(partialDays)")
                        .font(.title)
                    Text("partial days")
                }
            }
            .padding(.horizontal, 40)

            Text("• A “full day” means you were in this country for a full 24 hours (00:00–23:59).\n• A “partial day” means you spent less than 24 hours in total.")
                .font(.footnote)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)
                .padding()

            Spacer()
        }
        .padding()
    }
}
