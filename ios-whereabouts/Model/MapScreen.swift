import SwiftUI
import MapKit

@available(iOS 17.0, *)
struct MapScreen: View {
    @State private var overlays: [CountryOverlay] = []
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 20, longitude: 0),
            span: MKCoordinateSpan(latitudeDelta: 100, longitudeDelta: 100)
        )
    )

    var body: some View {
        NavigationView {
            Map(position: $cameraPosition, interactionModes: .all) {
                ForEach(overlays) { overlay in
                    MapPolygon(overlay.polygon)
                        .foregroundStyle(Color.blue.opacity(0.3))
                        .stroke(Color.blue, lineWidth: 2)
                        .mapOverlayLevel(level: .aboveLabels)
                }
            }
            .navigationTitle("Visited Map")
            .onAppear { reloadOverlays() }
            .onChange(of: VisitStore.shared.visits) { reloadOverlays() }
        }
    }

    private func reloadOverlays() {
        let visits = VisitStore.shared.visits
        let codes = Set(visits.compactMap { $0.countryCode })
        overlays = loadCountryOverlays(for: codes, visits: visits)

        guard !overlays.isEmpty else { return }
        let unionRect = overlays
            .map { $0.polygon.boundingMapRect }
            .reduce(MKMapRect.null) { $0.union($1) }
        cameraPosition = .region(MKCoordinateRegion(unionRect))
    }

    /// Load countries.geojson and filter features by matching any fallback code
    private func loadCountryOverlays(
        for codes: Set<String>,
        visits: [CountryVisitEntity]
    ) -> [CountryOverlay] {
        guard
            let url = Bundle.main.url(forResource: "countries", withExtension: "geojson"),
            let data = try? Data(contentsOf: url),
            let features = try? MKGeoJSONDecoder().decode(data) as? [MKGeoJSONFeature]
        else {
            print("Unable to load countries.geojson!")
            return []
        }

        var result: [CountryOverlay] = []

        for feature in features {
            guard
                let propData = feature.properties,
                let dict = try? JSONSerialization.jsonObject(with: propData) as? [String:Any]
            else { continue }

            // Collect all possible two‑letter codes in priority order
            let possible: [String?] = [
                dict["ISO_A2"] as? String,
                dict["WB_A2"] as? String,
                dict["ISO_A2_EH"] as? String,
                dict["FIPS_10"] as? String,
                dict["POSTAL"] as? String
            ]

            // Take the first non-nil, non-"-99", two‑letter string
            let iso = possible
                .compactMap { $0 }
                .first { $0 != "-99" && $0.count == 2 }

            guard let isoCode = iso, codes.contains(isoCode) else { continue }

            // Get all visit coords for this ISO
            let coords = visits
                .filter { $0.countryCode == isoCode }
                .map { CLLocationCoordinate2D(latitude: $0.latitude,
                                              longitude: $0.longitude) }

            // For each geometry piece, only include if a visit point lies inside
            for geom in feature.geometry {
                if let poly = geom as? MKPolygon {
                    if coords.contains(where: poly.contains(_:)) {
                        result.append(.init(countryCode: isoCode, polygon: poly))
                    }
                }
                else if let multi = geom as? MKMultiPolygon {
                    for sub in multi.polygons where coords.contains(where: sub.contains(_:)) {
                        result.append(.init(countryCode: isoCode, polygon: sub))
                    }
                }
            }
        }

        return result
    }

    struct CountryOverlay: Identifiable {
        let id = UUID()
        let countryCode: String
        let polygon: MKPolygon
    }
}

extension MKPolygon {
    /// Hit‑test a coordinate against this polygon
    func contains(_ coordinate: CLLocationCoordinate2D) -> Bool {
        let mapPoint = MKMapPoint(coordinate)
        let renderer = MKPolygonRenderer(polygon: self)
        let point = renderer.point(for: mapPoint)
        return renderer.path.contains(point)
    }
}
