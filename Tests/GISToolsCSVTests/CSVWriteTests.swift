import XCTest
import GISTools
@testable import GISToolsCSV

final class CSVWriteTests: XCTestCase {

    func testWriteAllPointsColumnOrder() throws {
        var a = Feature(Point(Coordinate3D(latitude: 48.135125, longitude: 11.518585, altitude: 520.0)))
        a.id = .int(1)
        a.properties["name"] = "Marienplatz"
        var b = Feature(Point(Coordinate3D(latitude: 52.518611, longitude: 13.376111)))
        b.id = .int(2)
        b.properties["name"] = "Reichstag"

        let data = try CSVCoder.write(FeatureCollection([a, b]))
        let text = String(decoding: data, as: UTF8.self)

        let lines = text.split(separator: "\n", omittingEmptySubsequences: true)
        XCTAssertEqual(lines[0], "id,longitude,latitude,altitude,name")
        XCTAssertEqual(lines[1], "1,11.518585,48.135125,520,Marienplatz")
        XCTAssertEqual(lines[2], "2,13.376111,52.518611,,Reichstag")
    }

    func testWriteComplexGeometryLast() throws {
        var point = Feature(Point(Coordinate3D(latitude: 48.135125, longitude: 11.518585)))
        point.id = .int(1)
        point.properties["name"] = "Marienplatz"

        var line = Feature(LineString(unchecked: [
            Coordinate3D(latitude: 47.56, longitude: 10.22),
            Coordinate3D(latitude: 47.62, longitude: 10.30),
        ]))
        line.id = .int(2)
        line.properties["name"] = "Trail"

        let data = try CSVCoder.write(FeatureCollection([point, line]))
        let text = String(decoding: data, as: UTF8.self)
        let lines = text.split(separator: "\n", omittingEmptySubsequences: true)

        // Header: id, properties, geometry last.
        XCTAssertEqual(lines[0], "id,name,geometry")
        XCTAssertEqual(lines[1], "1,Marienplatz,SRID=4326;POINT(11.518585 48.135125)")
        XCTAssertEqual(lines[2], "2,Trail,\"SRID=4326;LINESTRING(10.22 47.56,10.3 47.62)\"")
    }

    func testWriteUsesGeometryColumnNameAlways() throws {
        var line = Feature(LineString(unchecked: [
            Coordinate3D(latitude: 0, longitude: 0),
            Coordinate3D(latitude: 1, longitude: 1),
        ]))
        line.id = .int(7)
        let data = try CSVCoder.write(FeatureCollection([line]))
        let text = String(decoding: data, as: UTF8.self)
        let lines = text.split(separator: "\n", omittingEmptySubsequences: true)
        XCTAssertEqual(lines[0], "id,geometry")
    }

    func testWriteNoIDColumnOmitted() throws {
        var a = Feature(Point(Coordinate3D(latitude: 48.135125, longitude: 11.518585)))
        a.properties["name"] = "Marienplatz"
        var b = Feature(Point(Coordinate3D(latitude: 52.518611, longitude: 13.376111)))
        b.properties["name"] = "Reichstag"

        let data = try CSVCoder.write(FeatureCollection([a, b]))
        let text = String(decoding: data, as: UTF8.self)
        let lines = text.split(separator: "\n", omittingEmptySubsequences: true)
        XCTAssertEqual(lines[0], "id,longitude,latitude,altitude,name")
        XCTAssertEqual(lines[1], ",11.518585,48.135125,,Marienplatz")
    }

}
