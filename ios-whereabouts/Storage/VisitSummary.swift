import Foundation
import CoreData

extension String {
    var flagEmoji: String {
        guard self.count == 2 else { return "" }
        let base: UInt32 = 127397
        return self.uppercased().unicodeScalars.compactMap {
            UnicodeScalar(base + $0.value)
        }.map { String($0) }.joined()
    }

    var localizedCountryName: String {
        Locale.current.localizedString(forRegionCode: self.uppercased()) ?? self
    }
}

struct VisitSummary: Identifiable {
    let id = UUID()
    let startDate: Date
    let endDate: Date
    let countries: Set<String> // ISO codes
    let isMostRecent: Bool

    var description: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"

        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: startDate, to: endDate).day ?? 0
        let start = formatter.string(from: startDate)

        let countryList = countries
            .map { "\($0.localizedCountryName) \($0.flagEmoji)" }
            .joined(separator: ", ")

        if isMostRecent {
            if days >= 365 {
                let years = days / 365
                return "You've been in \(countryList) for the past \(years) year\(years > 1 ? "s" : "")"
            } else if days >= 60 {
                let months = days / 30
                return "You've been in \(countryList) for the past \(months) month\(months > 1 ? "s" : "")"
            } else if days >= 14 {
                let weeks = days / 7
                return "You've been in \(countryList) for the past \(weeks) week\(weeks > 1 ? "s" : "")"
            } else if days == 1 {
                return "You've been in \(countryList) since yesterday"
            } else {
                return "You've been in \(countryList) for the past \(days) day\(days > 1 ? "s" : "")"
            }
        } else {
            if days >= 365 {
                let years = days / 365
                return "Over \(years) year\(years > 1 ? "s" : "") starting from \(start) in \(countryList)"
            } else if days >= 60 {
                let months = days / 30
                return "\(months) month\(months > 1 ? "s" : "") starting from \(start) in \(countryList)"
            } else if days >= 14 {
                let weeks = days / 7
                return "\(weeks) week\(weeks > 1 ? "s" : "") starting from \(start) in \(countryList)"
            } else if days == 1 {
                return "1 day in \(countryList)"
            } else {
                return "\(days) days starting from \(start) in \(countryList)"
            }
        }
    }
}

final class VisitSummaryGenerator {
    static func generate(from visits: [CountryVisitEntity]) -> [VisitSummary] {
        let sorted = visits
            .sorted { ($0.timestamp ?? .distantPast) < ($1.timestamp ?? .distantPast) }

        guard !sorted.isEmpty else { return [] }

        var result: [VisitSummary] = []

        for i in 0..<sorted.count {
            guard let start = sorted[i].timestamp,
                  let country = sorted[i].countryCode else { continue }

            let end: Date = {
                if i + 1 < sorted.count, let next = sorted[i + 1].timestamp {
                    return next
                } else {
                    return Date() // now
                }
            }()

            result.append(VisitSummary(
                startDate: start,
                endDate: end,
                countries: [country],
                isMostRecent: i == sorted.count - 1
            ))
        }

        return result.reversed()
    }
}
