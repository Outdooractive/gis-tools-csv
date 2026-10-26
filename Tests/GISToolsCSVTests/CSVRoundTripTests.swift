import Foundation
import GISTools
@testable import GISToolsCSV
import Testing

struct CSVRoundTripTests {

    @Test
    func roundTripPoints() throws {
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

        #expect(roundTrip.features.count == 2)

        let first = roundTrip.features[0]
        #expect(first.id == .int(1))
        let point = try #require(first.geometry as? Point)
        #expect(abs(point.coordinate.longitude - 11.518585) < 0.0000000001)
        #expect(abs(point.coordinate.latitude - 48.135125) < 0.0000000001)
        #expect(abs((point.coordinate.altitude ?? -1.0) - 520.0) < 0.0000000001)
        #expect(first.properties["name"] as? String == "Marienplatz")
        #expect(first.properties["population"] as? Int == 1_400_000)
    }

    @Test
    func roundTripPreservesPropertyTypes() throws {
        var feature = Feature(Point(Coordinate3D(latitude: 48.1, longitude: 11.5)))
        feature.properties["int"] = 42
        feature.properties["double"] = 1.0
        feature.properties["ratio"] = 1.0 / 3.0
        feature.properties["precise"] = 0.1 + 0.2
        feature.properties["bool"] = true
        feature.properties["zip"] = "00123"
        feature.properties["text"] = "hello"

        let data = try CSVCoder.write(FeatureCollection([feature]))
        let roundTrip = try CSVCoder.read(from: data)
        let properties = roundTrip.features[0].properties

        #expect(properties["int"] as? Int == 42)
        #expect(properties["double"] as? Double == 1.0)
        #expect(properties["ratio"] as? Double == 1.0 / 3.0)
        #expect(properties["precise"] as? Double == 0.1 + 0.2)
        #expect(properties["bool"] as? Bool == true)
        #expect(properties["zip"] as? String == "00123")
        #expect(properties["text"] as? String == "hello")
    }

    @Test
    func roundTripPreservesIDs() throws {
        let ids: [Feature.Identifier] = [
            .int(-7),
            .uint(18_446_744_073_709_551_615),
            .double(1.0),
            .string("A1"),
            .string("001"),
        ]
        let features = ids.map { id -> Feature in
            var feature = Feature(Point(Coordinate3D(latitude: 48.1, longitude: 11.5)))
            feature.id = id
            return feature
        }

        let data = try CSVCoder.write(FeatureCollection(features))
        let roundTrip = try CSVCoder.read(from: data)
        #expect(roundTrip.features.map(\.id) == ids)
    }

    @Test
    func roundTripPreservesSpecialCharacters() throws {
        var feature = Feature(Point(Coordinate3D(latitude: 48.1, longitude: 11.5)))
        feature.properties["name"] = "München 🏔️"
        feature.properties["comma"] = "a,b"
        feature.properties["quote"] = "a\"b"
        feature.properties["newline"] = "a\nb"
        feature.properties["crlf"] = "a\r\nb"

        let data = try CSVCoder.write(FeatureCollection([feature]))
        let roundTrip = try CSVCoder.read(from: data)
        let properties = roundTrip.features[0].properties

        #expect(properties["name"] as? String == "München 🏔️")
        #expect(properties["comma"] as? String == "a,b")
        #expect(properties["quote"] as? String == "a\"b")
        #expect(properties["newline"] as? String == "a\nb")
        #expect(properties["crlf"] as? String == "a\r\nb")
    }

    @Test
    func roundTripComplex() throws {
        var line = Feature(LineString(unchecked: [
            Coordinate3D(latitude: 47.56, longitude: 10.22),
            Coordinate3D(latitude: 47.62, longitude: 10.30),
            Coordinate3D(latitude: 47.70, longitude: 10.45),
        ]))
        line.id = .int(5)
        line.properties["name"] = "Trail"

        let ring = [
            Coordinate3D(latitude: 0, longitude: 0),
            Coordinate3D(latitude: 0, longitude: 10),
            Coordinate3D(latitude: 10, longitude: 10),
            Coordinate3D(latitude: 10, longitude: 0),
            Coordinate3D(latitude: 0, longitude: 0),
        ]
        let maybePolygon = GISTools.Polygon([ring])
        let polygonGeometry = try #require(maybePolygon)
        var polygon = Feature(polygonGeometry)
        polygon.id = .int(6)
        polygon.properties["name"] = "Plot"

        let original = FeatureCollection([line, polygon])
        let data = try CSVCoder.write(original)
        let roundTrip = try CSVCoder.read(from: data)

        #expect(roundTrip.features.count == 2)

        let lineRT = try #require(roundTrip.features[0].geometry as? LineString)
        #expect(lineRT.coordinates.count == 3)
        #expect(abs(lineRT.coordinates[0].longitude - 10.22) < 0.0000000001)
        #expect(roundTrip.features[0].id == .int(5))

        let polygonRT = try #require(roundTrip.features[1].geometry as? GISTools.Polygon)
        #expect(polygonRT.rings.count == 1)
        #expect(polygonRT.rings[0].coordinates.count == 5)
        #expect(roundTrip.features[1].id == .int(6))
        #expect(roundTrip.features[1].properties["name"] as? String == "Plot")
    }

    @Test
    func roundTripMultiGeometries() throws {
        let multiPoint = MultiPoint(unchecked: [
            Coordinate3D(latitude: 48.1, longitude: 11.5),
            Coordinate3D(latitude: 48.2, longitude: 11.6),
        ])
        let multiPolygon = MultiPolygon(unchecked: [[
            [
                Coordinate3D(latitude: 0, longitude: 0),
                Coordinate3D(latitude: 0, longitude: 10),
                Coordinate3D(latitude: 10, longitude: 10),
                Coordinate3D(latitude: 0, longitude: 0),
            ],
        ]])

        let original = FeatureCollection([
            Feature(multiPoint),
            Feature(multiPolygon),
        ])
        let data = try CSVCoder.write(original)
        let roundTrip = try CSVCoder.read(from: data)

        #expect(roundTrip.features[0].geometry is MultiPoint)
        #expect(roundTrip.features[1].geometry is MultiPolygon)
    }

    @Test
    func roundTripUnlocatedFeature() throws {
        var feature = Feature()
        feature.id = .string("unlocated")
        feature.properties["name"] = "Somewhere"
        feature.properties["count"] = 3

        let data = try CSVCoder.write(FeatureCollection([feature]))
        let roundTrip = try CSVCoder.read(from: data)

        #expect(roundTrip.features.count == 1)
        #expect(roundTrip.features[0].geometry == nil)
        #expect(roundTrip.features[0].id == .string("unlocated"))
        #expect(roundTrip.features[0].properties["name"] as? String == "Somewhere")
        #expect(roundTrip.features[0].properties["count"] as? Int == 3)
    }

    @Test
    func roundTripEmptyCollection() throws {
        for options in [CSVWriteOptions(), CSVWriteOptions(geometryFormat: .wkt)] {
            let data = try CSVCoder.write(FeatureCollection([Feature]()), options: options)
            let roundTrip = try CSVCoder.read(from: data)
            #expect(roundTrip.features.isEmpty)
        }
    }

    @Test
    func roundTripViaFile() throws {
        let url = FileManager.default
            .temporaryDirectory
            .appendingPathComponent("roundtrip-\(UUID().uuidString).csv")

        var a = Feature(Point(Coordinate3D(latitude: 48.135125, longitude: 11.518585, altitude: 520.0)))
        a.id = .int(1)
        a.properties["name"] = "Marienplatz"

        let fc = FeatureCollection([a])
        try fc.writeCSV(to: url)

        let loaded = try #require(FeatureCollection(csv: url))

        #expect(loaded.features.count == 1)
        let point = try #require(loaded.features[0].geometry as? Point)
        #expect(abs(point.coordinate.latitude - 48.135125) < 0.0000000001)

        try? FileManager.default.removeItem(at: url)
    }

    @Test
    func roundTripEWKB() throws {
        var line = Feature(LineString(unchecked: [
            Coordinate3D(latitude: 47.56, longitude: 10.22),
            Coordinate3D(latitude: 47.62, longitude: 10.30),
            Coordinate3D(latitude: 47.70, longitude: 10.45),
        ]))
        line.id = .int(5)
        line.properties["name"] = "Trail"

        let original = FeatureCollection([line])
        let data = try CSVCoder.write(
            original,
            options: CSVWriteOptions(geometryFormat: .ewkb))
        let roundTrip = try CSVCoder.read(from: data)

        #expect(roundTrip.features.count == 1)
        let lineRT = try #require(roundTrip.features[0].geometry as? LineString)
        #expect(lineRT.coordinates.count == 3)
        #expect(abs(lineRT.coordinates[0].longitude - 10.22) < 0.0000000001)
        #expect(roundTrip.features[0].id == .int(5))
        #expect(roundTrip.features[0].properties["name"] as? String == "Trail")
    }

    @Test
    func roundTripGeoJSON() throws {
        let ring = [
            Coordinate3D(latitude: 0, longitude: 0),
            Coordinate3D(latitude: 0, longitude: 10),
            Coordinate3D(latitude: 10, longitude: 10),
            Coordinate3D(latitude: 0, longitude: 0),
        ]
        let maybePolygon = GISTools.Polygon([ring])
        let polygonGeometry = try #require(maybePolygon)
        let polygon = Feature(polygonGeometry)

        let original = FeatureCollection([polygon])
        let data = try CSVCoder.write(
            original,
            options: CSVWriteOptions(geometryFormat: .geojson))
        let roundTrip = try CSVCoder.read(from: data)

        let polygonRT = try #require(roundTrip.features[0].geometry as? GISTools.Polygon)
        #expect(polygonRT.rings[0].coordinates.count == 4)
    }

    @Test
    func roundTripProjectedPointsAreReprojected() throws {
        var point = Feature(Point(Coordinate3D.epsg3857(x: 1_281_000, y: 6_125_000)))
        point.id = .int(1)

        let data = try CSVCoder.write(FeatureCollection([point]))
        let roundTrip = try CSVCoder.read(from: data)

        let pointRT = try #require(roundTrip.features[0].geometry as? Point)
        #expect(pointRT.coordinate.projection == .epsg4326)
        #expect(abs(pointRT.coordinate.longitude - 11.507) < 0.01)
        #expect(abs(pointRT.coordinate.latitude - 48.1) < 0.01)
    }

    @Test
    func roundTripNullValueWithOmit() throws {
        var a = Feature(Point(Coordinate3D(latitude: 48.1, longitude: 11.5)))
        a.properties["name"] = "foo"
        var b = Feature(Point(Coordinate3D(latitude: 48.2, longitude: 11.6)))
        b.properties["name"] = "bar"
        b.properties["optional"] = "present"

        let data = try CSVCoder.write(
            FeatureCollection([a, b]),
            options: CSVWriteOptions(nullValue: "NULL"))
        let roundTrip = try CSVCoder.read(
            from: data,
            options: CSVReadOptions(nullHandling: .omit))

        #expect(roundTrip.features[0].properties["optional"] == nil)
        #expect(roundTrip.features[1].properties["optional"] as? String == "present")
    }

    @Test
    func roundTripCustomDelimiterAndLineEnding() throws {
        var a = Feature(Point(Coordinate3D(latitude: 48.1, longitude: 11.5)))
        a.properties["name"] = "a;b"
        var b = Feature(Point(Coordinate3D(latitude: 48.2, longitude: 11.6)))
        b.properties["name"] = "c"

        let data = try CSVCoder.write(
            FeatureCollection([a, b]),
            options: CSVWriteOptions(delimiter: ";", lineEnding: .crlf))
        let roundTrip = try CSVCoder.read(
            from: data,
            options: CSVReadOptions(delimiter: ";"))

        #expect(roundTrip.features.count == 2)
        #expect(roundTrip.features[0].properties["name"] as? String == "a;b")
    }

}
