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
        addMockVisits()
        fetchVisits()
    }
    
    // add mock data for testing purposes
    func addMockVisits() {
        let ctx = container.viewContext
        
        // 0) Delete all existing
        let fetch: NSFetchRequest<NSFetchRequestResult> = CountryVisitEntity.fetchRequest()
        let delReq = NSBatchDeleteRequest(fetchRequest: fetch)
        do {
            try ctx.execute(delReq)
        } catch {
            print("Failed to clear old visits: \(error.localizedDescription)")
        }
        
        // 1) Prepare date formatter
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone.current
        
        let mockSegments: [(code: String, name: String, start: String, end: String? , lat: Double, lon: Double)] = [
            ("US","United States","2023-07-10 14:41:00", "2023-07-10 14:42:00", 38.889805, -77.009056),
            ("CA","Canada",       "2023-07-10 14:42:00","2023-08-18 09:30:00", 45.424721, -75.695000),
            ("US","United States","2023-08-18 09:30:00", "2023-08-20 09:30:00", 38.889805, -77.009056),
            ("FR","France",       "2023-08-20 09:30:00","2024-04-06 20:10:00", 48.864716,   2.349014),
            ("RO","Romania",      "2024-04-06 20:10:00", nil, 44.432250,  26.106260),
            
        ]
        
        for seg in mockSegments {
            guard let s = formatter.date(from: seg.start) else { continue }
            let e = seg.end.flatMap { formatter.date(from: $0) }
            
            let visit = CountryVisitEntity(context: ctx)
            visit.id             = UUID()
            visit.countryCode    = seg.code
            visit.countryName    = seg.name
            visit.latitude       = seg.lat
            visit.longitude      = seg.lon
            visit.startTimestamp = s
            visit.endTimestamp   = e
        }
        
        do {
            try ctx.save()
            fetchVisits()
            print("Mock visits reset and added")
        } catch {
            print("Failed to add mock data: \(error.localizedDescription)")
        }
    }
    
    // fetches visit desc by startTimestamp
    func fetchVisits() {
        let req: NSFetchRequest<CountryVisitEntity> = CountryVisitEntity.fetchRequest()
        req.sortDescriptors = [
            NSSortDescriptor(key: #keyPath(CountryVisitEntity.startTimestamp), ascending: false)
        ]
        do {
            visits = try container.viewContext.fetch(req)
        } catch {
            print("Failed to fetch visits: \(error)")
        }
    }
}
