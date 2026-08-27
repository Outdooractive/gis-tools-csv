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

    func testReadEWKBGeometry() throws {
        let fc = try CSVCoder.read(from: dataURL.appendingPathComponent("ewkb_geometry.csv"))
        XCTAssertEqual(fc.features.count, 1)

        let feature = fc.features[0]
        XCTAssertEqual(feature.id, .int(241458031))

        let line = try XCTUnwrap(feature.geometry as? LineString)
        XCTAssertEqual(line.coordinates.count, 15)
        XCTAssertEqual(line.coordinates[0].longitude, 10.184617401417709, accuracy: 1e-6)
        XCTAssertEqual(line.coordinates[0].latitude, 47.53870670004494, accuracy: 1e-6)

        XCTAssertEqual(feature.properties["surface"] as? String, "gravel")
        XCTAssertEqual(feature.properties["tracktype"] as? String, "grade2")
        XCTAssertEqual(feature.properties["smoothness"] as? String, "intermediate")
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
        let fc = try CSVCoder.read(from: data, options: CSVReadOptions(delimiter: ";"))
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

    func testInvalidGeometryThrows() {
        let data = Data("""
        id,geometry
        a,"NOT WKT"
        """.utf8)
        XCTAssertThrowsError(try CSVCoder.read(from: data)) { error in
            guard case CSVError.invalidGeometry = error else {
                return XCTFail("expected invalidGeometry, got \(error)")
            }
        }
    }

    // MARK: - Treat as line string

    func testTreatAsLineStringFromLatLon() throws {
        let fc = try CSVCoder.read(
            from: dataURL.appendingPathComponent("breitachklamm.csv"),
            options: CSVReadOptions(treatAsLineString: true))

        XCTAssertEqual(fc.features.count, 1)
        let line = try XCTUnwrap(fc.features[0].geometry as? LineString)
        XCTAssertEqual(line.coordinates.count, 3180)
        XCTAssertNil(fc.features[0].id)
        XCTAssertTrue(fc.features[0].properties.isEmpty)

        XCTAssertEqual(line.coordinates[0].latitude, 47.401810, accuracy: 1e-9)
        XCTAssertEqual(line.coordinates[0].longitude, 10.230148, accuracy: 1e-9)
        XCTAssertEqual(line.coordinates[0].altitude, 826.762191)
        XCTAssertEqual(line.coordinates[3179].latitude, 47.399769, accuracy: 1e-9)
        XCTAssertEqual(line.coordinates[3179].longitude, 10.222358, accuracy: 1e-9)
    }

    func testTreatAsLineStringFromGeometryColumn() throws {
        let data = Data("""
        id,geometry
        p1,"POINT (1 2)"
        p2,"MULTIPOINT (3 4, 5 6)"
        p3,"LINESTRING (7 8, 9 10)"
        p4,"MULTILINESTRING ((11 12, 13 14), (15 16, 17 18))"
        """.utf8)
        let fc = try CSVCoder.read(from: data, options: CSVReadOptions(treatAsLineString: true))

        XCTAssertEqual(fc.features.count, 1)
        let line = try XCTUnwrap(fc.features[0].geometry as? LineString)
        let expected: [(Double, Double)] = [(1, 2), (3, 4), (5, 6), (7, 8), (9, 10), (11, 12), (13, 14), (15, 16), (17, 18)]
        XCTAssertEqual(line.coordinates.count, expected.count)
        for (coordinate, (longitude, latitude)) in zip(line.coordinates, expected) {
            XCTAssertEqual(coordinate.longitude, longitude, accuracy: 1e-9)
            XCTAssertEqual(coordinate.latitude, latitude, accuracy: 1e-9)
        }
    }

    func testTreatAsLineStringTooFewCoordinatesThrows() {
        let data = Data("""
        latitude,longitude
        48.1,11.5
        """.utf8)
        XCTAssertThrowsError(try CSVCoder.read(from: data, options: CSVReadOptions(treatAsLineString: true))) { error in
            guard case CSVError.invalidGeometry = error else {
                return XCTFail("expected invalidGeometry, got \(error)")
            }
        }
    }

    func testTreatAsLineStringIncompatibleGeometryThrows() {
        let data = Data("""
        id,geometry
        p1,"POINT (1 2)"
        p2,"POLYGON ((0 0, 0 10, 10 10, 10 0, 0 0))"
        """.utf8)
        XCTAssertThrowsError(try CSVCoder.read(from: data, options: CSVReadOptions(treatAsLineString: true))) { error in
            guard case CSVError.invalidGeometry(let detail) = error else {
                return XCTFail("expected invalidGeometry, got \(error)")
            }
            XCTAssertTrue(detail.contains("row 3"), "expected row 3 in detail, got \(detail)")
        }
    }

    func testDefaultOptionsKeepPointFeatures() throws {
        let fc = try CSVCoder.read(from: dataURL.appendingPathComponent("breitachklamm.csv"))
        XCTAssertEqual(fc.features.count, 3180)
        XCTAssertTrue(fc.features[0].geometry is Point)
    }

    // MARK: - Null handling

    func testNullKeptAsStringByDefault() throws {
        let data = Data("""
        id,name,value,geometry
        1,foo,NULL,"POINT (1 2)"
        """.utf8)
        let fc = try CSVCoder.read(from: data)
        let feature = fc.features[0]
        XCTAssertEqual(feature.properties["value"] as? String, "NULL")
    }

    func testNullOmittedWithOmit() throws {
        let data = Data("""
        id,name,value,geometry
        1,foo,NULL,"POINT (1 2)"
        """.utf8)
        let fc = try CSVCoder.read(
            from: data,
            options: CSVReadOptions(nullHandling: .omit))
        let feature = fc.features[0]
        XCTAssertNil(feature.properties["value"])
        XCTAssertEqual(feature.properties["name"] as? String, "foo")
    }

    func testNullOmittedCaseInsensitive() throws {
        let data = Data("""
        id,a,b,c,geometry
        1,null,Null,NULL,"POINT (1 2)"
        """.utf8)
        let fc = try CSVCoder.read(
            from: data,
            options: CSVReadOptions(nullHandling: .omit))
        let feature = fc.features[0]
        XCTAssertNil(feature.properties["a"])
        XCTAssertNil(feature.properties["b"])
        XCTAssertNil(feature.properties["c"])
    }

    func testEmptyValueOmittedWithOmit() throws {
        let data = Data("""
        id,name,value,geometry
        1,foo,,"POINT (1 2)"
        """.utf8)
        let fc = try CSVCoder.read(
            from: data,
            options: CSVReadOptions(nullHandling: .omit))
        let feature = fc.features[0]
        XCTAssertNil(feature.properties["value"])
        XCTAssertEqual(feature.properties["name"] as? String, "foo")
    }

    func testEWKBGeometryNullColumnsOmitted() throws {
        let fc = try CSVCoder.read(
            from: dataURL.appendingPathComponent("ewkb_geometry.csv"),
            options: CSVReadOptions(nullHandling: .omit))
        XCTAssertEqual(fc.features.count, 1)

        let feature = fc.features[0]
        // NULL columns are omitted.
        XCTAssertNil(feature.properties["name"])
        XCTAssertNil(feature.properties["int_name"])
        XCTAssertNil(feature.properties["wikidata"])
        // Non-null columns are kept.
        XCTAssertEqual(feature.properties["surface"] as? String, "gravel")
        XCTAssertEqual(feature.properties["tracktype"] as? String, "grade2")
        XCTAssertEqual(feature.properties["smoothness"] as? String, "intermediate")
        XCTAssertEqual(feature.properties["type"] as? String, "track")
    }

}
