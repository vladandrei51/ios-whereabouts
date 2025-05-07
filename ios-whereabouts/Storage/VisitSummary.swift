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
        formatter.dateFormat = "dd MMM yyyy"

        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: startDate, to: endDate).day ?? 0

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
            } else if days == 0 {
                return "Welcome to \(countryList)!"
            } else {
                return "You've been in \(countryList) for the past \(days) days"
            }
        } else {
            if days >= 365 {
                let years = days / 365
                return "Over \(years) year\(years > 1 ? "s" : "") in \(countryList)"
            } else if days >= 60 {
                let months = days / 30
                return "\(months) month\(months > 1 ? "s" : "") in \(countryList)"
            } else if days >= 14 {
                let weeks = days / 7
                return "\(weeks) week\(weeks > 1 ? "s" : "") in \(countryList)"
            } else if days == 1 {
                return "1 day in \(countryList)"
            } else if days == 0 {
                return "Less than 24 hours in \(countryList)"
            } else {
                return "\(days) days in \(countryList)"
            }
        }
    }
}

final class VisitSummaryGenerator {
  static func generate(from visits: [CountryVisitEntity]) -> [VisitSummary] {
    // 1) turn each entity into a non‐optional (start, end, code) tuple
    typealias Interval = (start: Date, end: Date, code: String)
    let intervals: [Interval] = visits.compactMap { (v) -> Interval? in
      // require that we have a start date and a countryCode
      guard let s = v.startTimestamp,
            let code = v.countryCode
      else { return nil }
      // if no endTimestamp, treat as “now”
      let e = v.endTimestamp ?? Date()
      return (start: s, end: e, code: code)
    }

    // 2) sort that array by its .start
    let sortedIntervals = intervals.sorted(by: { lhs, rhs in
      return lhs.start < rhs.start
    })

    guard !sortedIntervals.isEmpty else { return [] }

    // 3) build VisitSummary instances
    var result: [VisitSummary] = []
    for (index, interval) in sortedIntervals.enumerated() {
      let isMostRecent = (index == sortedIntervals.count - 1)
      let summary = VisitSummary(
        startDate: interval.start,
        endDate:   interval.end,
        countries: [interval.code],
        isMostRecent: isMostRecent
      )
      result.append(summary)
    }

    // 4) we want the most‐recent first
    return result.reversed()
  }
}
