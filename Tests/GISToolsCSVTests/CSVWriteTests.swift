import Foundation
import GISTools
@testable import GISToolsCSV
import Testing

struct CSVWriteTests {

    private func lines(_ data: Data) -> [Substring] {
        String(decoding: data, as: UTF8.self)
            .split(separator: "\n", omittingEmptySubsequences: true)
    }

    @Test
    func writeAllPointsColumnOrder() throws {
        var a = Feature(Point(Coordinate3D(latitude: 48.135125, longitude: 11.518585, altitude: 520.0)))
        a.id = .int(1)
        a.properties["name"] = "Marienplatz"
        var b = Feature(Point(Coordinate3D(latitude: 52.518611, longitude: 13.376111)))
        b.id = .int(2)
        b.properties["name"] = "Reichstag"

        let data = try CSVCoder.write(FeatureCollection([a, b]))
        let textLines = lines(data)

        #expect(textLines[0] == "id,longitude,latitude,altitude,name")
        #expect(textLines[1] == "1,11.518585,48.135125,520,Marienplatz")
        #expect(textLines[2] == "2,13.376111,52.518611,,Reichstag")
    }

    @Test
    func writeComplexGeometryLast() throws {
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
        let textLines = lines(data)

        // Header: id, properties, geometry last.
        #expect(textLines[0] == "id,name,geometry")
        #expect(textLines[1] == "1,Marienplatz,SRID=4326;POINT(11.518585 48.135125)")
        #expect(textLines[2] == "2,Trail,\"SRID=4326;LINESTRING(10.22 47.56,10.3 47.62)\"")
    }

    @Test
    func writeUsesGeometryColumnNameAlways() throws {
        var line = Feature(LineString(unchecked: [
            Coordinate3D(latitude: 0, longitude: 0),
            Coordinate3D(latitude: 1, longitude: 1),
        ]))
        line.id = .int(7)
        let data = try CSVCoder.write(FeatureCollection([line]))
        let textLines = lines(data)
        #expect(textLines[0] == "id,geometry")
    }

    @Test
    func writeNoIDColumnOmitted() throws {
        var a = Feature(Point(Coordinate3D(latitude: 48.135125, longitude: 11.518585)))
        a.properties["name"] = "Marienplatz"
        var b = Feature(Point(Coordinate3D(latitude: 52.518611, longitude: 13.376111)))
        b.properties["name"] = "Reichstag"

        let data = try CSVCoder.write(FeatureCollection([a, b]))
        let textLines = lines(data)
        #expect(textLines[0] == "id,longitude,latitude,altitude,name")
        #expect(textLines[1] == ",11.518585,48.135125,,Marienplatz")
    }

    // MARK: - Geometry format

    @Test
    func writeWKTFormatUsesGeometryColumnForPoints() throws {
        var a = Feature(Point(Coordinate3D(latitude: 48.135125, longitude: 11.518585)))
        a.id = .int(1)
        a.properties["name"] = "Marienplatz"

        let data = try CSVCoder.write(
            FeatureCollection([a]),
            options: CSVWriteOptions(geometryFormat: .wkt))
        let textLines = lines(data)
        #expect(textLines[0] == "id,name,geometry")
        #expect(textLines[1] == "1,Marienplatz,SRID=4326;POINT(11.518585 48.135125)")
    }

    @Test
    func writeEWKBFormat() throws {
        var line = Feature(LineString(unchecked: [
            Coordinate3D(latitude: 47.56, longitude: 10.22),
            Coordinate3D(latitude: 47.62, longitude: 10.30),
        ]))
        line.id = .int(2)

        let data = try CSVCoder.write(
            FeatureCollection([line]),
            options: CSVWriteOptions(geometryFormat: .ewkb))
        let textLines = lines(data)
        #expect(textLines[0] == "id,geometry")
        // EWKB hex is uppercase and decodes back to a LineString.
        let hex = String(textLines[1].split(separator: ",")[1])
        #expect(!hex.isEmpty)
        #expect(hex == hex.uppercased())
        let geometry = GeoJsonReader.geometryFrom(string: hex)
        #expect(geometry is LineString)
    }

    @Test
    func writeGeoJsonFormat() throws {
        var point = Feature(Point(Coordinate3D(latitude: 48.135125, longitude: 11.518585)))
        point.id = .int(1)

        let data = try CSVCoder.write(
            FeatureCollection([point]),
            options: CSVWriteOptions(geometryFormat: .geojson))
        let textLines = lines(data)
        #expect(textLines[0] == "id,geometry")
        #expect(textLines[1].contains("type"))
        #expect(textLines[1].contains("Point"))
    }

    // MARK: - Column name, header, null value, line ending

    @Test
    func writeCustomGeometryColumnName() throws {
        var line = Feature(LineString(unchecked: [
            Coordinate3D(latitude: 0, longitude: 0),
            Coordinate3D(latitude: 1, longitude: 1),
        ]))
        line.id = .int(7)
        let data = try CSVCoder.write(
            FeatureCollection([line]),
            options: CSVWriteOptions(geometryColumnName: "geom"))
        let textLines = lines(data)
        #expect(textLines[0] == "id,geom")
    }

    @Test
    func writeNoHeader() throws {
        var a = Feature(Point(Coordinate3D(latitude: 48.135125, longitude: 11.518585)))
        a.id = .int(1)
        a.properties["name"] = "Marienplatz"
        let data = try CSVCoder.write(
            FeatureCollection([a]),
            options: CSVWriteOptions(includeHeader: false))
        let textLines = lines(data)
        #expect(textLines.count == 1)
        #expect(textLines[0] == "1,11.518585,48.135125,,Marienplatz")
    }

    @Test
    func writeNullValue() throws {
        var a = Feature(Point(Coordinate3D(latitude: 48.135125, longitude: 11.518585)))
        a.id = .int(1)
        a.properties["name"] = "Marienplatz"
        var b = Feature(Point(Coordinate3D(latitude: 52.518611, longitude: 13.376111)))
        b.id = .int(2)
        b.properties["name"] = "Reichstag"

        let data = try CSVCoder.write(
            FeatureCollection([a, b]),
            options: CSVWriteOptions(nullValue: "NULL"))
        let textLines = lines(data)
        #expect(textLines[0] == "id,longitude,latitude,altitude,name")
        #expect(textLines[1] == "1,11.518585,48.135125,NULL,Marienplatz")
        #expect(textLines[2] == "2,13.376111,52.518611,NULL,Reichstag")
    }

    @Test
    func writeCRLFLineEnding() throws {
        var a = Feature(Point(Coordinate3D(latitude: 48.135125, longitude: 11.518585)))
        a.id = .int(1)
        let data = try CSVCoder.write(
            FeatureCollection([a]),
            options: CSVWriteOptions(lineEnding: .crlf))
        let text = String(decoding: data, as: UTF8.self)
        #expect(text.contains("\r\n"))
        #expect(!text.contains("\n\n"))
    }

}
