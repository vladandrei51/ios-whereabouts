import SwiftUI

@available(iOS 17.0, *)
struct CountryScreen: View {
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
                    Image(systemName: "arrow.up.arrow.down")
                }
            }
            .sheet(item: $selected) { CountryDetailSheet(profile: $0) }
        }
    }
    
    private var profiles: [CountryProfile] {
        let summaries = VisitSummaryGenerator.generate(from: store.visits)
        var totalByCode: [String: TimeInterval] = [:]
        var visitsByCode: [String: [VisitSummary]] = [:]
        
        for s in summaries {
            let dur = s.endDate.timeIntervalSince(s.startDate)
            let code = s.countries.first!
            totalByCode[code, default: 0] += dur
            visitsByCode[code, default: []].append(s)
        }
        
        var arr = totalByCode.map { code, total in
            CountryProfile(code: code,
                           totalTime: total,
                           visits: visitsByCode[code]!)
        }
        
        switch sortBy {
        case .name:
            arr.sort { ascending
                ? $0.code.localizedCountryName < $1.code.localizedCountryName
                : $0.code.localizedCountryName > $1.code.localizedCountryName }
        case .time:
            arr.sort { ascending
                ? $0.totalTime < $1.totalTime
                : $0.totalTime > $1.totalTime }
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
        // count unique calendar days covered by this country
        let cal = Calendar.current
        let days = visits.flatMap { summary -> [Date] in
            let startDay = cal.startOfDay(for: summary.startDate)
            let endDay   = cal.startOfDay(for: summary.endDate)
            // include all days from startDay through endDay
            var d = startDay
            var arr: [Date] = [d]
            while d < endDay {
                d = cal.date(byAdding: .day, value: 1, to: d)!
                arr.append(d)
            }
            return arr
        }
        return Set(days).count
    }
}

struct CountryDetailSheet: View {
    @ObservedObject private var store = VisitStore.shared
    let profile: CountryProfile
    
    private static let rangeFmt: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .medium; return f
    }()
    private static let dayFmt: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .medium; return f
    }()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text(profile.code.localizedCountryName)
                    .font(.system(.largeTitle, weight: .bold))
                Text(profile.code.flagEmoji)
                    .font(.system(size: 60))
                    .symbolRenderingMode(.multicolor)
                
                HStack(spacing: 40) {
                    VStack {
                        Text("\(fullDates.count)")
                            .font(.title).bold()
                        Text("full days")
                    }
                    VStack {
                        Text("\(partialDates.count)")
                            .font(.title).bold()
                        Text("partial days")
                    }
                }
                
                Text("""
                    • A “full day” means you spent the entire calendar‑day (00:00–23:59) in this country, with no time logged elsewhere.  
                    • A “partial day” means that on that calendar‑day you split your time between this country and at least one other.
                    """)
                .font(.footnote)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(10)
                
                if let period = fullDayPeriod() {
                    HStack {
                        Image(systemName: "calendar")
                        Text("Full‑day periods: ")
                            .font(.subheadline.weight(.semibold))
                        +
                        Text(period)
                            .font(.subheadline)
                        Spacer()
                    }
                    .padding()
                    .background(.regularMaterial)
                    .cornerRadius(8)
                }
                
                if !partialDates.isEmpty {
                    HStack {
                        Image(systemName: "clock.arrow.circlepath")
                        (
                            Text("Partial‑day dates: ")
                                .font(.subheadline.weight(.semibold))
                            +
                            Text(partialDates
                                .map { Self.dayFmt.string(from: $0) }
                                .joined(separator: ", "))
                            .font(.subheadline)
                        )
                        Spacer()
                    }
                    .padding()
                    .background(.regularMaterial)
                    .cornerRadius(8)
                }
                
                Spacer(minLength: 20)
            }
            .padding()
        }
    }
    
    // All visit summaries across all countries
    private var allSummaries: [VisitSummary] {
        VisitSummaryGenerator.generate(from: store.visits)
    }
    
    // Calendar days where this country is the only one with any time logged
    private var fullDates: [Date] {
        let cal = Calendar.current
        
        // build a map: day -> set of country codes present that day
        var dayToCodes: [Date: Set<String>] = [:]
        for summary in allSummaries {
            let code = summary.countries.first!
            let startDay = cal.startOfDay(for: summary.startDate)
            let endDay   = cal.startOfDay(for: summary.endDate)
            var d = startDay
            dayToCodes[d, default: []].insert(code)
            while d < endDay {
                d = cal.date(byAdding: .day, value: 1, to: d)!
                dayToCodes[d, default: []].insert(code)
            }
        }
        
        // pick those days where only this profile.code appears
        return dayToCodes
            .filter { $0.value == [profile.code] }
            .map { $0.key }
            .sorted()
    }
    
    // Calendar days where more than one country appears
    private var partialDates: [Date] {
        let cal = Calendar.current
        
        // build a map: day -> set of country codes present that day
        var dayToCodes: [Date: Set<String>] = [:]
        for summary in allSummaries {
            let code = summary.countries.first!
            let startDay = cal.startOfDay(for: summary.startDate)
            let endDay   = cal.startOfDay(for: summary.endDate)
            var d = startDay
            dayToCodes[d, default: []].insert(code)
            while d < endDay {
                d = cal.date(byAdding: .day, value: 1, to: d)!
                dayToCodes[d, default: []].insert(code)
            }
        }
        
        return dayToCodes
            .filter { pair in
                let (day, codes) = pair
                return codes.contains(profile.code) && codes.count > 1
            }
            .map { $0.key }
            .sorted()
    }
    
    private func fullDayPeriod() -> String? {
        guard let first = fullDates.first,
              let last  = fullDates.last else { return nil }
        if first != last {
            return "\(Self.rangeFmt.string(from: first)) – \(Self.rangeFmt.string(from: last))"
        } else {
            return "\(Self.rangeFmt.string(from: first))"
        }
    }
}
