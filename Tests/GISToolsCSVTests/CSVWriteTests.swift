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

    // MARK: - Property columns

    @Test
    func writePropertyColumnsAreDeterministic() throws {
        var a = Feature(Point(Coordinate3D(latitude: 48.1, longitude: 11.5)))
        a.properties["zebra"] = 1
        a.properties["alpha"] = 2
        a.properties["mike"] = 3

        let data = try CSVCoder.write(FeatureCollection([a]))
        let textLines = lines(data)
        #expect(textLines[0] == "id,longitude,latitude,altitude,alpha,mike,zebra")
        #expect(textLines[1] == ",11.5,48.1,,2,3,1")
    }

    @Test
    func writePropertyOrderUsesFirstAppearanceAcrossFeatures() throws {
        var a = Feature(Point(Coordinate3D(latitude: 48.1, longitude: 11.5)))
        a.properties["bravo"] = "a"
        a.properties["alpha"] = "a"
        var b = Feature(Point(Coordinate3D(latitude: 48.2, longitude: 11.6)))
        b.properties["charlie"] = "b"
        b.properties["alpha"] = "b"

        let data = try CSVCoder.write(FeatureCollection([a, b]))
        let textLines = lines(data)
        #expect(textLines[0] == "id,longitude,latitude,altitude,alpha,bravo,charlie")
        #expect(textLines[1] == ",11.5,48.1,,a,a,")
        #expect(textLines[2] == ",11.6,48.2,,b,,b")
    }

    @Test
    func writeReservedPropertyNamesAreOmitted() throws {
        var a = Feature(Point(Coordinate3D(latitude: 48.1, longitude: 11.5)))
        a.properties = [
            "id": "property-id",
            "geometry": "property-geometry",
            "lat": 1.0,
            "z": 2.0,
            "fid": 3,
            "keep": "kept",
        ]

        let data = try CSVCoder.write(FeatureCollection([a]))
        let textLines = lines(data)
        #expect(textLines[0] == "id,longitude,latitude,altitude,keep")
        #expect(textLines[1] == ",11.5,48.1,,kept")
    }

    @Test
    func writePropertyNamesMatchedCaseInsensitively() throws {
        var a = Feature(Point(Coordinate3D(latitude: 48.1, longitude: 11.5)))
        a.properties["Name"] = "first"
        var b = Feature(Point(Coordinate3D(latitude: 48.2, longitude: 11.6)))
        b.properties["name"] = "second"

        let data = try CSVCoder.write(FeatureCollection([a, b]))
        let textLines = lines(data)
        #expect(textLines[0] == "id,longitude,latitude,altitude,Name")
        #expect(textLines[1] == ",11.5,48.1,,first")
        #expect(textLines[2] == ",11.6,48.2,,second")
    }

    @Test
    func writeDoublePropertiesKeepTheirType() throws {
        var a = Feature(Point(Coordinate3D(latitude: 48.1, longitude: 11.5)))
        a.properties["whole"] = 1.0
        a.properties["ratio"] = 1.0 / 3.0
        a.properties["huge"] = 1.0e20
        a.properties["integer"] = 1

        let data = try CSVCoder.write(FeatureCollection([a]))
        let textLines = lines(data)
        #expect(textLines[0] == "id,longitude,latitude,altitude,huge,integer,ratio,whole")
        #expect(textLines[1] == ",11.5,48.1,,1e+20,1,0.3333333333333333,1.0")
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
        #expect(hex.isNotEmpty)
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
        #expect(textLines[1].hasPrefix("1,\"{"))
        #expect(textLines[1].contains("Point"))
        #expect(textLines[1].contains("coordinates"))
    }

    @Test
    func writeGeoJsonFormatReprojectsProjectedGeometry() throws {
        let point = Feature(Point(Coordinate3D.epsg3857(x: 1_281_000, y: 6_125_000)))

        let data = try CSVCoder.write(
            FeatureCollection([point]),
            options: CSVWriteOptions(geometryFormat: .geojson))
        let fc = try CSVCoder.read(from: data)
        let pointRT = try #require(fc.features[0].geometry as? Point)
        #expect(pointRT.coordinate.projection == .epsg4326)
        #expect(abs(pointRT.coordinate.longitude - 11.507) < 0.01)
        #expect(abs(pointRT.coordinate.latitude - 48.1) < 0.01)
    }

    @Test
    func writeNonWGS84PointsUseGeometryColumn() throws {
        var point = Feature(Point(Coordinate3D.epsg3857(x: 1_281_000, y: 6_125_000)))
        point.id = .int(1)

        let data = try CSVCoder.write(FeatureCollection([point]))
        let textLines = lines(data)
        #expect(textLines[0] == "id,geometry")
        // WKT output is always reprojected to EPSG:4326.
        #expect(textLines[1].contains("SRID=4326;"))
        #expect(textLines[1].contains("POINT("))
    }

    @Test
    func writeUnlocatedFeatureHasEmptyGeometryCell() throws {
        var feature = Feature()
        feature.id = .int(1)
        feature.properties["name"] = "unlocated"

        let data = try CSVCoder.write(FeatureCollection([feature]))
        let textLines = lines(data)
        #expect(textLines[0] == "id,name,geometry")
        #expect(textLines[1] == "1,unlocated,")
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
    func writeCustomGeometryColumnNameExcludesPropertyOfSameName() throws {
        var line = Feature(LineString(unchecked: [
            Coordinate3D(latitude: 0, longitude: 0),
            Coordinate3D(latitude: 1, longitude: 1),
        ]))
        line.properties["shape"] = "property"

        let data = try CSVCoder.write(
            FeatureCollection([line]),
            options: CSVWriteOptions(geometryColumnName: "shape"))
        let textLines = lines(data)
        #expect(textLines[0] == "id,shape")
    }

    @Test
    func writeRejectsInvalidGeometryColumnNames() {
        let line = Feature(LineString(unchecked: [
            Coordinate3D(latitude: 0, longitude: 0),
            Coordinate3D(latitude: 1, longitude: 1),
        ]))
        let fc = FeatureCollection([line])

        for name in ["", "id", "latitude", "lat", "longitude", "z"] {
            #expect(throws: CSVError.invalidGeometryColumnName(name: name)) {
                _ = try CSVCoder.write(
                    fc,
                    options: CSVWriteOptions(geometryColumnName: name))
            }
        }
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
    func writeBooleanProperties() throws {
        var a = Feature(Point(Coordinate3D(latitude: 48.1, longitude: 11.5)))
        a.properties["active"] = true
        a.properties["inactive"] = false

        let data = try CSVCoder.write(FeatureCollection([a]))
        let textLines = lines(data)
        #expect(textLines[0] == "id,longitude,latitude,altitude,active,inactive")
        #expect(textLines[1] == ",11.5,48.1,,true,false")
    }

    @Test
    func writeNoHeaderForComplexGeometry() throws {
        var line = Feature(LineString(unchecked: [
            Coordinate3D(latitude: 0, longitude: 0),
            Coordinate3D(latitude: 1, longitude: 1),
        ]))
        line.id = .int(7)

        let data = try CSVCoder.write(
            FeatureCollection([line]),
            options: CSVWriteOptions(includeHeader: false))
        let textLines = lines(data)
        #expect(textLines.count == 1)
        #expect(textLines[0].hasPrefix("7,\"SRID=4326;LINESTRING"))
    }

    @Test
    func writeEmptyCollection() throws {
        let data = try CSVCoder.write(FeatureCollection([Feature]()))
        #expect(String(decoding: data, as: UTF8.self) == "id,longitude,latitude,altitude\n")
    }

    @Test
    func writeEmptyCollectionWithoutHeaderIsEmpty() throws {
        let data = try CSVCoder.write(
            FeatureCollection([Feature]()),
            options: CSVWriteOptions(includeHeader: false))
        #expect(data.isEmpty)
    }

    @Test
    func writeEmptyCollectionWithExplicitFormat() throws {
        let data = try CSVCoder.write(
            FeatureCollection([Feature]()),
            options: CSVWriteOptions(geometryFormat: .wkt))
        #expect(String(decoding: data, as: UTF8.self) == "id,geometry\n")
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
    func writeDoubleIDKeepsTypeMarker() throws {
        var a = Feature(Point(Coordinate3D(latitude: 48.1, longitude: 11.5)))
        a.id = .double(1.0)
        let data = try CSVCoder.write(FeatureCollection([a]))
        let textLines = lines(data)
        #expect(textLines[1].hasPrefix("1.0,"))
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

    @Test
    func writeQuotesSpecialPropertyValues() throws {
        var a = Feature(Point(Coordinate3D(latitude: 48.1, longitude: 11.5)))
        a.properties["name"] = "a,b"
        a.properties["quote"] = "a\"b"
        a.properties["newline"] = "a\nb"

        let data = try CSVCoder.write(FeatureCollection([a]))
        let text = String(decoding: data, as: UTF8.self)
        #expect(text.contains("\"a,b\""))
        #expect(text.contains("\"a\"\"b\""))
        #expect(text.contains("\"a\nb\""))
    }

}
