import XCTest
import GISTools
@testable import GISToolsCSV

final class CSVRoundTripTests: XCTestCase {

    func testRoundTripPoints() throws {
        var a = Feature(Point(Coordinate3D(latitude: 48.135125, longitude: 11.518585, altitude: 520.0)))
        a.id = .int(1)
        a.properties["name"] = "Marienplatz"
        a.properties["population"] = 1_400_000
        var b = Feature(Point(Coordinate3D(latitude: 52.518611, longitude: 13.376111, altitude: 35.0)))
        b.id = .int(2)
        b.properties["name"] = "Reichstag"
        b.properties["population"] = 3_600_000

        let original = FeatureCollection([a, b])
        let data = try CSVCoder.write(original)
        let roundTrip = try CSVCoder.read(from: data)

        XCTAssertEqual(roundTrip.features.count, 2)

        let first = roundTrip.features[0]
        XCTAssertEqual(first.id, .int(1))
        let point = try XCTUnwrap(first.geometry as? Point)
        XCTAssertEqual(point.coordinate.longitude, 11.518585, accuracy: 1e-9)
        XCTAssertEqual(point.coordinate.latitude, 48.135125, accuracy: 1e-9)
        XCTAssertEqual(point.coordinate.altitude ?? -1, 520.0, accuracy: 1e-9)
        XCTAssertEqual(first.properties["name"] as? String, "Marienplatz")
        XCTAssertEqual(first.properties["population"] as? Int, 1_400_000)
    }

    func testRoundTripComplex() throws {
        var line = Feature(LineString(unchecked: [
            Coordinate3D(latitude: 47.56, longitude: 10.22),
            Coordinate3D(latitude: 47.62, longitude: 10.30),
            Coordinate3D(latitude: 47.70, longitude: 10.45),
        ]))
        line.id = .int(5)
        line.properties["name"] = "Trail"

        var polygon = Feature(GISTools.Polygon([
            [Coordinate3D(latitude: 0, longitude: 0),
             Coordinate3D(latitude: 0, longitude: 10),
             Coordinate3D(latitude: 10, longitude: 10),
             Coordinate3D(latitude: 10, longitude: 0),
             Coordinate3D(latitude: 0, longitude: 0)],
        ])!)
        polygon.id = .int(6)
        polygon.properties["name"] = "Plot"

        let original = FeatureCollection([line, polygon])
        let data = try CSVCoder.write(original)
        let roundTrip = try CSVCoder.read(from: data)

        XCTAssertEqual(roundTrip.features.count, 2)

        let lineRT = try XCTUnwrap(roundTrip.features[0].geometry as? LineString)
        XCTAssertEqual(lineRT.coordinates.count, 3)
        XCTAssertEqual(lineRT.coordinates[0].longitude, 10.22, accuracy: 1e-9)
        XCTAssertEqual(roundTrip.features[0].id, .int(5))

        let polygonRT = try XCTUnwrap(roundTrip.features[1].geometry as? GISTools.Polygon)
        XCTAssertEqual(polygonRT.rings.count, 1)
        XCTAssertEqual(polygonRT.rings[0].coordinates.count, 5)
        XCTAssertEqual(roundTrip.features[1].id, .int(6))
        XCTAssertEqual(roundTrip.features[1].properties["name"] as? String, "Plot")
    }

    func testRoundTripViaFile() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("roundtrip-\(UUID().uuidString).csv")

        var a = Feature(Point(Coordinate3D(latitude: 48.135125, longitude: 11.518585, altitude: 520.0)))
        a.id = .int(1)
        a.properties["name"] = "Marienplatz"

        let fc = FeatureCollection([a])
        try fc.writeCSV(to: url)

        guard let loaded = FeatureCollection(csv: url) else {
            return XCTFail("failed to read back")
        }

        XCTAssertEqual(loaded.features.count, 1)
        let point = try XCTUnwrap(loaded.features[0].geometry as? Point)
        XCTAssertEqual(point.coordinate.latitude, 48.135125, accuracy: 1e-9)

        try? FileManager.default.removeItem(at: url)
    }

}
