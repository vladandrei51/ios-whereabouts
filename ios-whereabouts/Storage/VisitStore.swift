import Foundation
import CoreData
import CoreLocation

class VisitStore: ObservableObject {
    static let shared = VisitStore()

    let container: NSPersistentContainer

    @Published var visits: [CountryVisitEntity] = []

    private init() {
        container = NSPersistentContainer(name: "VisitModel")
        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Core Data failed to load: \(error.localizedDescription)")
            }
        }
        fetchVisits()
    }
    
    // add mock data for testing purposes
    func addMockVisits() {
        let context = container.viewContext
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone.current

        // USA: United States Capitol, Washington DC
        // Canada: Ottawa, ON
        // France: Paris
        // Romania: Bucharest
        let mockSegments: [(code: String, name: String, timestamp: String, lat: Double, lon: Double)] = [
            ("US", "United States", "2023-04-01 08:15:00", 38.889805, -77.009056),    // US Capitol :contentReference[oaicite:0]{index=0}
            ("CA", "Canada",        "2023-07-10 14:42:00", 45.424721, -75.695000),   // Ottawa :contentReference[oaicite:1]{index=1}
            ("FR", "France",        "2023-08-18 09:30:00", 48.864716,   2.349014),   // Paris :contentReference[oaicite:2]{index=2}
            ("RO", "Romania",       "2024-04-06 20:10:00", 44.432250,  26.106260),   // Bucharest :contentReference[oaicite:3]{index=3}
            ("US", "United States", "2025-04-08 11:00:00", 38.889805, -77.009056)
        ]

        for segment in mockSegments {
            guard let date = formatter.date(from: segment.timestamp) else {
                print("Failed to parse date: \(segment.timestamp)")
                continue
            }

            let visit = CountryVisitEntity(context: context)
            visit.id = UUID()
            visit.countryCode = segment.code
            visit.countryName = segment.name
            visit.timestamp = date
            visit.latitude = segment.lat
            visit.longitude = segment.lon
        }

        do {
            try context.save()
            fetchVisits()
            print("Mock visits added with coords")
        } catch {
            print("Failed to add mock data: \(error.localizedDescription)")
        }
    }

    func fetchVisits() {
        let request: NSFetchRequest<CountryVisitEntity> = CountryVisitEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CountryVisitEntity.timestamp, ascending: false)]

        do {
            visits = try container.viewContext.fetch(request)
        } catch {
            print("Failed to fetch visits: \(error.localizedDescription)")
        }
    }

    func saveVisit(from visit: CountryVisit) {
        let newVisit = CountryVisitEntity(context: container.viewContext)
        newVisit.id = visit.id
        newVisit.countryCode = visit.countryCode
        newVisit.countryName = visit.countryName
        newVisit.timestamp = visit.timestamp
        newVisit.latitude = visit.coordinates.latitude
        newVisit.longitude = visit.coordinates.longitude

        do {
            try container.viewContext.save()
            fetchVisits()
        } catch {
            print("Failed to save visit: \(error.localizedDescription)")
        }
    }

    func deleteVisit(_ visit: CountryVisitEntity) {
        container.viewContext.delete(visit)
        do {
            try container.viewContext.save()
            fetchVisits()
        } catch {
            print("Failed to delete visit: \(error.localizedDescription)")
        }
    }
}
