import Foundation
import GISTools
@testable import GISToolsCSV
import Testing

struct CSVReadTests {

    private var dataURL: URL {
        Bundle.module.resourceURL!.appendingPathComponent("TestData")
    }

    @Test
    func readPointsLatLon() throws {
        let fc = try CSVCoder.read(from: dataURL.appendingPathComponent("points.csv"))

        #expect(fc.features.count == 3)

        let first = fc.features[0]
        let point = try #require(first.geometry as? Point)
        #expect(abs(point.coordinate.longitude - 11.518585) < 0.0000000001)
        #expect(abs(point.coordinate.latitude - 48.135125) < 0.0000000001)
        #expect(point.coordinate.altitude == 520.0)
        #expect(first.id == .int(1))
        #expect(first.properties["name"] as? String == "Marienplatz")
    }

    @Test
    func readPointNoAltitude() throws {
        let fc = try CSVCoder.read(from: dataURL.appendingPathComponent("points_feature_id.csv"))
        let first = try #require(fc.features.first)
        let point = try #require(first.geometry as? Point)
        #expect(point.coordinate.altitude == nil)
        #expect(first.id == .string("A1"))
    }

    @Test
    func readFeatureIDAlias() throws {
        let fc = try CSVCoder.read(from: dataURL.appendingPathComponent("points_feature_id.csv"))
        #expect(fc.features[0].id == .string("A1"))
        #expect(fc.features[1].id == .string("A2"))
    }

    @Test
    func readUpperIDAlias() throws {
        // FEATURE_IDENTIFIER matches case-insensitively.
        let fc = try CSVCoder.read(from: dataURL.appendingPathComponent("points_upper_id.csv"))
        #expect(fc.features[0].id == .string("x"))
        #expect(fc.features[1].id == .string("y"))
    }

    @Test
    func readGeometryWKT() throws {
        let fc = try CSVCoder.read(from: dataURL.appendingPathComponent("geometry.csv"))
        #expect(fc.features.count == 3)

        #expect(fc.features[0].geometry is Point)
        #expect(fc.features[1].geometry is LineString)
        #expect(fc.features[2].geometry is GISTools.Polygon)

        let line = try #require(fc.features[1].geometry as? LineString)
        #expect(line.coordinates.count == 2)
        #expect(fc.features[1].id == .string("p2"))
    }

    @Test
    func readSRIDPrefixedWKT() throws {
        let data = Data("""
        id,geometry
        p1,"SRID=4326;POINT (11.5 48.1)"
        """.utf8)
        let fc = try CSVCoder.read(from: data)
        #expect(fc.features.count == 1)
        let point = try #require(fc.features[0].geometry as? Point)
        #expect(abs(point.coordinate.longitude - 11.5) < 0.0000000001)
        #expect(abs(point.coordinate.latitude - 48.1) < 0.0000000001)
    }

    @Test
    func readEWKBGeometry() throws {
        let fc = try CSVCoder.read(from: dataURL.appendingPathComponent("ewkb_geometry.csv"))
        #expect(fc.features.count == 1)

        let feature = fc.features[0]
        #expect(feature.id == .int(241458031))

        let line = try #require(feature.geometry as? LineString)
        #expect(line.coordinates.count == 15)
        #expect(abs(line.coordinates[0].longitude - 10.184617401417709) < 0.000001)
        #expect(abs(line.coordinates[0].latitude - 47.53870670004494) < 0.000001)

        #expect(feature.properties["surface"] as? String == "gravel")
        #expect(feature.properties["tracktype"] as? String == "grade2")
        #expect(feature.properties["smoothness"] as? String == "intermediate")
    }

    @Test
    func readQuotedFields() throws {
        let fc = try CSVCoder.read(from: dataURL.appendingPathComponent("points_quoted.csv"))
        #expect(fc.features.count == 2)
        #expect(fc.features[0].properties["name"] as? String == "Munich, Bavaria")
        #expect(fc.features[0].properties["description"] as? String == "a city; note the semicolon")
        #expect(fc.features[1].properties["description"] as? String == "line 1\nline 2")
    }

    @Test
    func readSemicolonDelimiter() throws {
        let data = Data("""
        id;longitude;latitude;name
        1;11.518585;48.135125;Marienplatz
        """.utf8)
        let fc = try CSVCoder.read(from: data, options: CSVReadOptions(delimiter: ";"))
        #expect(fc.features.count == 1)
        #expect(fc.features[0].properties["name"] as? String == "Marienplatz")
    }

    @Test
    func missingHeaderThrows() {
        #expect(throws: CSVError.missingHeader) {
            _ = try CSVCoder.read(from: Data("1,2,3\n".utf8))
        }
    }

    @Test
    func missingGeometryThrows() {
        let data = Data("""
        name
        foo
        """.utf8)
        #expect(throws: CSVError.missingHeader) {
            _ = try CSVCoder.read(from: data)
        }
    }

    @Test
    func invalidCoordinateThrows() {
        let data = Data("""
        latitude,longitude
        notanumber,5
        """.utf8)
        #expect(throws: CSVError.invalidCoordinate(detail: "row 2: invalid latitude/longitude")) {
            _ = try CSVCoder.read(from: data)
        }
    }

    @Test
    func invalidGeometryThrows() {
        let data = Data("""
        id,geometry
        a,"NOT WKT"
        """.utf8)
        #expect(throws: CSVError.invalidGeometry(detail: "Invalid geometry: row 2: could not parse geometry")) {
            _ = try CSVCoder.read(from: data)
        }
    }

    // MARK: - Treat as line string

    @Test
    func treatAsLineStringFromLatLon() throws {
        let fc = try CSVCoder.read(
            from: dataURL.appendingPathComponent("breitachklamm.csv"),
            options: CSVReadOptions(treatAsLineString: true))

        #expect(fc.features.count == 1)
        let line = try #require(fc.features[0].geometry as? LineString)
        #expect(line.coordinates.count == 3180)
        #expect(fc.features[0].id == nil)
        #expect(fc.features[0].properties.isEmpty)

        #expect(abs(line.coordinates[0].latitude - 47.401810) < 0.0000000001)
        #expect(abs(line.coordinates[0].longitude - 10.230148) < 0.0000000001)
        #expect(abs((line.coordinates[0].altitude ?? -1.0) - 826.762191) < 0.000001)
        #expect(abs(line.coordinates[3179].latitude - 47.399769) < 0.0000000001)
        #expect(abs(line.coordinates[3179].longitude - 10.222358) < 0.0000000001)
    }

    @Test
    func treatAsLineStringFromGeometryColumn() throws {
        let data = Data("""
        id,geometry
        p1,"POINT (1 2)"
        p2,"MULTIPOINT (3 4, 5 6)"
        p3,"LINESTRING (7 8, 9 10)"
        p4,"MULTILINESTRING ((11 12, 13 14), (15 16, 17 18))"
        """.utf8)
        let fc = try CSVCoder.read(from: data, options: CSVReadOptions(treatAsLineString: true))

        #expect(fc.features.count == 1)
        let line = try #require(fc.features[0].geometry as? LineString)
        let expected: [(Double, Double)] = [(1, 2), (3, 4), (5, 6), (7, 8), (9, 10), (11, 12), (13, 14), (15, 16), (17, 18)]
        #expect(line.coordinates.count == expected.count)
        for (coordinate, (longitude, latitude)) in zip(line.coordinates, expected) {
            #expect(abs(coordinate.longitude - longitude) < 0.0000000001)
            #expect(abs(coordinate.latitude - latitude) < 0.0000000001)
        }
    }

    @Test
    func treatAsLineStringTooFewCoordinatesThrows() {
        let data = Data("""
        latitude,longitude
        48.1,11.5
        """.utf8)
        #expect(throws: CSVError.invalidGeometry(detail: "at least 2 coordinates are required for a LineString, got 1")) {
            _ = try CSVCoder.read(from: data, options: CSVReadOptions(treatAsLineString: true))
        }
    }

    @Test
    func treatAsLineStringIncompatibleGeometryThrows() throws {
        let data = Data("""
        id,geometry
        p1,"POINT (1 2)"
        p2,"POLYGON ((0 0, 0 10, 10 10, 10 0, 0 0))"
        """.utf8)
        #expect(throws: CSVError.invalidGeometry(detail: "row 3: Polygon cannot be converted to a LineString")) {
            _ = try CSVCoder.read(from: data, options: CSVReadOptions(treatAsLineString: true))
        }
    }

    @Test
    func defaultOptionsKeepPointFeatures() throws {
        let fc = try CSVCoder.read(from: dataURL.appendingPathComponent("breitachklamm.csv"))
        #expect(fc.features.count == 3180)
        #expect(fc.features[0].geometry is Point)
    }

    // MARK: - Null handling

    @Test
    func nullKeptAsStringByDefault() throws {
        let data = Data("""
        id,name,value,geometry
        1,foo,NULL,"POINT (1 2)"
        """.utf8)
        let fc = try CSVCoder.read(from: data)
        let feature = fc.features[0]
        #expect(feature.properties["value"] as? String == "NULL")
    }

    @Test
    func nullOmittedWithOmit() throws {
        let data = Data("""
        id,name,value,geometry
        1,foo,NULL,"POINT (1 2)"
        """.utf8)
        let fc = try CSVCoder.read(
            from: data,
            options: CSVReadOptions(nullHandling: .omit))
        let feature = fc.features[0]
        #expect(feature.properties["value"] == nil)
        #expect(feature.properties["name"] as? String == "foo")
    }

    @Test
    func nullOmittedCaseInsensitive() throws {
        let data = Data("""
        id,a,b,c,geometry
        1,null,Null,NULL,"POINT (1 2)"
        """.utf8)
        let fc = try CSVCoder.read(
            from: data,
            options: CSVReadOptions(nullHandling: .omit))
        let feature = fc.features[0]
        #expect(feature.properties["a"] == nil)
        #expect(feature.properties["b"] == nil)
        #expect(feature.properties["c"] == nil)
    }

    @Test
    func emptyValueOmittedWithOmit() throws {
        let data = Data("""
        id,name,value,geometry
        1,foo,,"POINT (1 2)"
        """.utf8)
        let fc = try CSVCoder.read(
            from: data,
            options: CSVReadOptions(nullHandling: .omit))
        let feature = fc.features[0]
        #expect(feature.properties["value"] == nil)
        #expect(feature.properties["name"] as? String == "foo")
    }

    @Test
    func ewkbGeometryNullColumnsOmitted() throws {
        let fc = try CSVCoder.read(
            from: dataURL.appendingPathComponent("ewkb_geometry.csv"),
            options: CSVReadOptions(nullHandling: .omit))
        #expect(fc.features.count == 1)

        let feature = fc.features[0]
        // NULL columns are omitted.
        #expect(feature.properties["name"] == nil)
        #expect(feature.properties["int_name"] == nil)
        #expect(feature.properties["wikidata"] == nil)
        // Non-null columns are kept.
        #expect(feature.properties["surface"] as? String == "gravel")
        #expect(feature.properties["tracktype"] as? String == "grade2")
        #expect(feature.properties["smoothness"] as? String == "intermediate")
        #expect(feature.properties["type"] as? String == "track")
    }

}
