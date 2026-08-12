import XCTest
import GISTools
@testable import GISToolsCSV

final class CSVReadTests: XCTestCase {

    private var dataURL: URL {
        Bundle.module.resourceURL!.appendingPathComponent("TestData")
    }

    func testReadPointsLatLon() throws {
        let fc = try CSVCoder.read(from: dataURL.appendingPathComponent("points.csv"))

        XCTAssertEqual(fc.features.count, 3)

        let first = fc.features[0]
        let point = try XCTUnwrap(first.geometry as? Point)
        XCTAssertEqual(point.coordinate.longitude, 11.518585, accuracy: 1e-9)
        XCTAssertEqual(point.coordinate.latitude, 48.135125, accuracy: 1e-9)
        XCTAssertEqual(point.coordinate.altitude, 520.0)
        XCTAssertEqual(first.id, .int(1))
        XCTAssertEqual(first.properties["name"] as? String, "Marienplatz")
    }

    func testReadPointNoAltitude() throws {
        let fc = try CSVCoder.read(from: dataURL.appendingPathComponent("points_feature_id.csv"))
        let first = try XCTUnwrap(fc.features.first)
        let point = try XCTUnwrap(first.geometry as? Point)
        XCTAssertNil(point.coordinate.altitude)
        XCTAssertEqual(first.id, .string("A1"))
    }

    func testReadFeatureIDAlias() throws {
        let fc = try CSVCoder.read(from: dataURL.appendingPathComponent("points_feature_id.csv"))
        XCTAssertEqual(fc.features[0].id, .string("A1"))
        XCTAssertEqual(fc.features[1].id, .string("A2"))
    }

    func testReadUpperIDAlias() throws {
        // FEATURE_IDENTIFIER matches case-insensitively.
        let fc = try CSVCoder.read(from: dataURL.appendingPathComponent("points_upper_id.csv"))
        XCTAssertEqual(fc.features[0].id, .string("x"))
        XCTAssertEqual(fc.features[1].id, .string("y"))
    }

    func testReadGeometryWKT() throws {
        let fc = try CSVCoder.read(from: dataURL.appendingPathComponent("geometry.csv"))
        XCTAssertEqual(fc.features.count, 3)

        XCTAssertTrue(fc.features[0].geometry is Point)
        XCTAssertTrue(fc.features[1].geometry is LineString)
        XCTAssertTrue(fc.features[2].geometry is GISTools.Polygon)

        let line = try XCTUnwrap(fc.features[1].geometry as? LineString)
        XCTAssertEqual(line.coordinates.count, 2)
        XCTAssertEqual(fc.features[1].id, .string("p2"))
    }

    func testReadSRIDPrefixedWKT() throws {
        let data = Data("""
        id,geometry
        p1,"SRID=4326;POINT (11.5 48.1)"
        """.utf8)
        let fc = try CSVCoder.read(from: data)
        XCTAssertEqual(fc.features.count, 1)
        let point = try XCTUnwrap(fc.features[0].geometry as? Point)
        XCTAssertEqual(point.coordinate.longitude, 11.5, accuracy: 1e-9)
        XCTAssertEqual(point.coordinate.latitude, 48.1, accuracy: 1e-9)
    }

    func testReadQuotedFields() throws {
        let fc = try CSVCoder.read(from: dataURL.appendingPathComponent("points_quoted.csv"))
        XCTAssertEqual(fc.features.count, 2)
        XCTAssertEqual(fc.features[0].properties["name"] as? String, "Munich, Bavaria")
        XCTAssertEqual(fc.features[0].properties["description"] as? String, "a city; note the semicolon")
        XCTAssertEqual(fc.features[1].properties["description"] as? String, "line 1\nline 2")
    }

    func testReadSemicolonDelimiter() throws {
        let data = Data("""
        id;longitude;latitude;name
        1;11.518585;48.135125;Marienplatz
        """.utf8)
        let fc = try CSVCoder.read(from: data, delimiter: ";")
        XCTAssertEqual(fc.features.count, 1)
        XCTAssertEqual(fc.features[0].properties["name"] as? String, "Marienplatz")
    }

    func testMissingHeaderThrows() {
        XCTAssertThrowsError(try CSVCoder.read(from: Data("1,2,3\n".utf8))) { error in
            XCTAssertEqual(error as? CSVError, .missingHeader)
        }
    }

    func testMissingGeometryThrows() {
        let data = Data("""
        name
        foo
        """.utf8)
        XCTAssertThrowsError(try CSVCoder.read(from: data)) { error in
            guard case CSVError.missingHeader = error else {
                return XCTFail("expected missingHeader, got \(error)")
            }
        }
    }

    func testInvalidCoordinateThrows() {
        let data = Data("""
        latitude,longitude
        notanumber,5
        """.utf8)
        XCTAssertThrowsError(try CSVCoder.read(from: data)) { error in
            guard case CSVError.invalidCoordinate = error else {
                return XCTFail("expected invalidCoordinate, got \(error)")
            }
        }
    }

    func testInvalidWKTThrows() {
        let data = Data("""
        id,geometry
        a,"NOT WKT"
        """.utf8)
        XCTAssertThrowsError(try CSVCoder.read(from: data)) { error in
            guard case CSVError.invalidWKT = error else {
                return XCTFail("expected invalidWKT, got \(error)")
            }
        }
    }

}
