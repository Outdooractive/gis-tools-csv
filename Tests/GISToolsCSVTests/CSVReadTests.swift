import Foundation
import GISTools
@testable import GISToolsCSV
import Testing

struct CSVReadTests {

    private var dataURL: URL {
        Bundle.module.resourceURL!.appendingPathComponent("TestData")
    }

    // MARK: - Points

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
    func readLonAlias() throws {
        let data = Data("""
        lat,lon,name
        48.135125,11.518585,Marienplatz
        """.utf8)
        let fc = try CSVCoder.read(from: data)
        let point = try #require(fc.features.first?.geometry as? Point)
        #expect(abs(point.coordinate.longitude - 11.518585) < 0.0000000001)
        #expect(abs(point.coordinate.latitude - 48.135125) < 0.0000000001)
    }

    @Test
    func readCoordinatesWithSurroundingWhitespace() throws {
        let data = Data("""
        latitude,longitude
        " 48.1 ",11.5
        """.utf8)
        let fc = try CSVCoder.read(from: data)
        let point = try #require(fc.features.first?.geometry as? Point)
        #expect(abs(point.coordinate.latitude - 48.1) < 0.0000000001)
    }

    @Test
    func readEmptyAltitudeIsNil() throws {
        let data = Data("""
        latitude,longitude,altitude
        48.1,11.5,
        """.utf8)
        let fc = try CSVCoder.read(from: data)
        let point = try #require(fc.features.first?.geometry as? Point)
        #expect(point.coordinate.altitude == nil)
    }

    @Test
    func readNullAltitudeIsNil() throws {
        let data = Data("""
        latitude,longitude,altitude
        48.1,11.5,NULL
        """.utf8)
        let fc = try CSVCoder.read(from: data)
        let point = try #require(fc.features.first?.geometry as? Point)
        #expect(point.coordinate.altitude == nil)
    }

    // MARK: - Geometry column

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
    func readProjectedWKTIsReprojectedToEPSG4326() throws {
        let data = Data("""
        id,geometry
        p1,"SRID=3857;POINT (1281000 6125000)"
        """.utf8)
        let fc = try CSVCoder.read(from: data)
        let point = try #require(fc.features[0].geometry as? Point)
        #expect(point.coordinate.projection == .epsg4326)
        #expect(abs(point.coordinate.longitude - 11.507) < 0.01)
        #expect(abs(point.coordinate.latitude - 48.1) < 0.01)
    }

    @Test
    func readWKBHexGeometry() throws {
        let point = Point(Coordinate3D(latitude: 48.1, longitude: 11.5))
        let data = try #require(WKBCoder.encode(geometry: point, targetProjection: nil))
        let hex = data.map { String(format: "%02X", $0) }.joined()
        let csv = Data("id,geometry\n1,\(hex)\n".utf8)

        let fc = try CSVCoder.read(from: csv)
        let pointRT = try #require(fc.features[0].geometry as? Point)
        #expect(abs(pointRT.coordinate.longitude - 11.5) < 0.0000000001)
        #expect(abs(pointRT.coordinate.latitude - 48.1) < 0.0000000001)
    }

    @Test
    func readTWKBHexGeometry() throws {
        // TWKB point (1, 2) with precision 0: type 1, empty metadata,
        // zigzag(1) = 2, zigzag(2) = 4.
        let csv = Data("id,geometry\n1,01000204\n".utf8)

        let fc = try CSVCoder.read(from: csv)
        let point = try #require(fc.features[0].geometry as? Point)
        #expect(abs(point.coordinate.longitude - 1.0) < 0.0000000001)
        #expect(abs(point.coordinate.latitude - 2.0) < 0.0000000001)
    }

    @Test
    func readGeoJSONGeometry() throws {
        let data = Data("""
        id,geometry
        p1,"{""type"":""Point"",""coordinates"":[11.5,48.1]}"
        """.utf8)
        let fc = try CSVCoder.read(from: data)
        let point = try #require(fc.features[0].geometry as? Point)
        #expect(abs(point.coordinate.longitude - 11.5) < 0.0000000001)
        #expect(abs(point.coordinate.latitude - 48.1) < 0.0000000001)
    }

    @Test
    func readEWKBGeometry() throws {
        let fc = try CSVCoder.read(from: dataURL.appendingPathComponent("ewkb_geometry.csv"))
        #expect(fc.features.count == 1)

        let feature = fc.features[0]
        #expect(feature.id == .int(241_458_031))

        let line = try #require(feature.geometry as? LineString)
        #expect(line.coordinates.count == 15)
        #expect(abs(line.coordinates[0].longitude - 10.184617401417709) < 0.000001)
        #expect(abs(line.coordinates[0].latitude - 47.53870670004494) < 0.000001)

        #expect(feature.properties["surface"] as? String == "gravel")
        #expect(feature.properties["tracktype"] as? String == "grade2")
        #expect(feature.properties["smoothness"] as? String == "intermediate")
    }

    @Test
    func emptyGeometryCellFallsBackToCoordinates() throws {
        let data = Data("""
        geometry,latitude,longitude
        ,48.1,11.5
        """.utf8)
        let fc = try CSVCoder.read(from: data)
        let point = try #require(fc.features.first?.geometry as? Point)
        #expect(abs(point.coordinate.latitude - 48.1) < 0.0000000001)
    }

    @Test
    func emptyGeometryCellProducesUnlocatedFeature() throws {
        let data = Data("""
        id,geometry,name
        1,,foo
        """.utf8)
        let fc = try CSVCoder.read(from: data)
        #expect(fc.features.count == 1)
        #expect(fc.features[0].geometry == nil)
        #expect(fc.features[0].id == .int(1))
        #expect(fc.features[0].properties["name"] as? String == "foo")
    }

    @Test
    func nullGeometryCellProducesUnlocatedFeature() throws {
        let data = Data("""
        id,geometry,name
        1,NULL,foo
        """.utf8)
        let fc = try CSVCoder.read(from: data)
        #expect(fc.features.count == 1)
        #expect(fc.features[0].geometry == nil)
        #expect(fc.features[0].properties["name"] as? String == "foo")
    }

    @Test
    func nullGeometryCellFallsBackToCoordinates() throws {
        let data = Data("""
        id,geometry,latitude,longitude
        1,NULL,48.1,11.5
        """.utf8)
        let fc = try CSVCoder.read(from: data)
        let point = try #require(fc.features[0].geometry as? Point)
        #expect(abs(point.coordinate.latitude - 48.1) < 0.0000000001)
    }

    @Test
    func raggedRowMissingGeometryCellThrows() {
        let data = Data("""
        name,geometry
        foo
        """.utf8)
        #expect(throws: CSVError.missingGeometry(line: 2)) {
            _ = try CSVCoder.read(from: data)
        }
    }

    @Test
    func raggedRowMissingCoordinateCellsThrows() {
        // There is no geometry column, and the row is too short to contain the
        // latitude/longitude pair.
        let data = Data("""
        id,latitude,longitude
        1,48.1,11.5
        2
        """.utf8)
        #expect(throws: CSVError.missingGeometry(line: 3)) {
            _ = try CSVCoder.read(from: data)
        }
    }

    // MARK: - Quoting and delimiters

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
    func readUTF8ByteOrderMark() throws {
        let data = Data("\u{FEFF}id,longitude,latitude,name\n1,11.5,48.1,Marienplatz\n".utf8)
        let fc = try CSVCoder.read(from: data)
        #expect(fc.features.count == 1)
        #expect(fc.features[0].id == .int(1))
        #expect(fc.features[0].properties["name"] as? String == "Marienplatz")
    }

    // MARK: - Errors

    @Test
    func headerOnlyProducesEmptyCollection() throws {
        let fc = try CSVCoder.read(from: Data("id,geometry\n".utf8))
        #expect(fc.features.isEmpty)
    }

    @Test
    func emptyDataThrowsMissingHeader() {
        #expect(throws: CSVError.missingHeader) {
            _ = try CSVCoder.read(from: Data())
        }
    }

    @Test
    func headerWithoutGeometrySourceThrows() {
        let data = Data("""
        name
        foo
        """.utf8)
        #expect(throws: CSVError.missingGeometryColumns) {
            _ = try CSVCoder.read(from: data)
        }
    }

    @Test
    func onlyLatitudeColumnThrows() {
        let data = Data("""
        latitude,name
        48.1,foo
        """.utf8)
        #expect(throws: CSVError.missingGeometryColumns) {
            _ = try CSVCoder.read(from: data)
        }
    }

    @Test
    func rowWithoutGeometryThrows() {
        let data = Data("""
        latitude,longitude
        ,
        """.utf8)
        #expect(throws: CSVError.invalidCoordinate(detail: "row 2: invalid latitude")) {
            _ = try CSVCoder.read(from: data)
        }
    }

    @Test
    func invalidCoordinateThrows() {
        let data = Data("""
        latitude,longitude
        notanumber,5
        """.utf8)
        #expect(throws: CSVError.invalidCoordinate(detail: "row 2: invalid latitude")) {
            _ = try CSVCoder.read(from: data)
        }
    }

    @Test
    func nonFiniteCoordinateThrows() {
        let data = Data("""
        latitude,longitude
        NaN,5
        """.utf8)
        #expect(throws: CSVError.invalidCoordinate(detail: "row 2: invalid latitude")) {
            _ = try CSVCoder.read(from: data)
        }
    }

    @Test
    func outOfRangeLatitudeThrows() {
        let data = Data("""
        latitude,longitude
        91,5
        """.utf8)
        #expect(throws: CSVError.invalidCoordinate(detail: "row 2: latitude 91.0 is out of range")) {
            _ = try CSVCoder.read(from: data)
        }
    }

    @Test
    func outOfRangeLongitudeThrows() {
        let data = Data("""
        latitude,longitude
        48,181
        """.utf8)
        #expect(throws: CSVError.invalidCoordinate(detail: "row 2: longitude 181.0 is out of range")) {
            _ = try CSVCoder.read(from: data)
        }
    }

    @Test
    func invalidAltitudeThrows() {
        let data = Data("""
        latitude,longitude,altitude
        48.1,11.5,high
        """.utf8)
        #expect(throws: CSVError.invalidCoordinate(detail: "row 2: invalid altitude")) {
            _ = try CSVCoder.read(from: data)
        }
    }

    @Test
    func invalidGeometryThrows() {
        let data = Data("""
        id,geometry
        a,"NOT WKT"
        """.utf8)
        #expect(throws: CSVError.invalidGeometry(detail: "row 2: could not parse geometry")) {
            _ = try CSVCoder.read(from: data)
        }
    }

    @Test
    func unterminatedQuoteThrowsMalformedCSV() {
        let data = Data("""
        id,geometry
        a,"POINT (1 2)
        """.utf8)
        #expect(throws: CSVError.malformedCSV(detail: "row 2: unterminated quoted field")) {
            _ = try CSVCoder.read(from: data)
        }
    }

    // MARK: - Ids

    @Test
    func numericIdTypes() throws {
        let data = Data("""
        id,latitude,longitude
        42,48.1,11.5
        -7,48.1,11.5
        18446744073709551615,48.1,11.5
        1.5,48.1,11.5
        001,48.1,11.5
        A1,48.1,11.5
        """.utf8)
        let fc = try CSVCoder.read(from: data)
        #expect(fc.features[0].id == .int(42))
        #expect(fc.features[1].id == .int(-7))
        #expect(fc.features[2].id == .uint(18_446_744_073_709_551_615))
        #expect(fc.features[3].id == .double(1.5))
        // Leading zeros are preserved as a string id.
        #expect(fc.features[4].id == .string("001"))
        #expect(fc.features[5].id == .string("A1"))
    }

    @Test
    func nullIdOmittedWithOmit() throws {
        let data = Data("""
        id,latitude,longitude
        NULL,48.1,11.5
        """.utf8)
        let fc = try CSVCoder.read(from: data, options: CSVReadOptions(nullHandling: .omit))
        #expect(fc.features[0].id == nil)
    }

    @Test
    func nullIdKeptAsStringByDefault() throws {
        let data = Data("""
        id,latitude,longitude
        NULL,48.1,11.5
        """.utf8)
        let fc = try CSVCoder.read(from: data)
        #expect(fc.features[0].id == .string("NULL"))
    }

    // MARK: - Numeric inference

    @Test
    func propertyValuesAreInferred() throws {
        let data = Data("""
        latitude,longitude,int,double,bool,upperBool,zip,scientific,nan,infinity,text
        48.1,11.5,42,1.5,true,FALSE,00123,1e3,NaN,Infinity,foo
        """.utf8)
        let fc = try CSVCoder.read(from: data)
        let properties = fc.features[0].properties
        #expect(properties["int"] as? Int == 42)
        #expect(properties["double"] as? Double == 1.5)
        #expect(properties["bool"] as? Bool == true)
        #expect(properties["upperBool"] as? Bool == false)
        // Leading zeros are significant and stay strings.
        #expect(properties["zip"] as? String == "00123")
        #expect(properties["scientific"] as? Double == 1000.0)
        // Non-finite numbers are not valid JSON and stay strings.
        #expect(properties["nan"] as? String == "NaN")
        #expect(properties["infinity"] as? String == "Infinity")
        #expect(properties["text"] as? String == "foo")
    }

    @Test
    func unicodePropertiesArePreserved() throws {
        let data = Data("""
        latitude,longitude,name,emoji
        48.1,11.5,München,🏔️
        """.utf8)
        let fc = try CSVCoder.read(from: data)
        #expect(fc.features[0].properties["name"] as? String == "München")
        #expect(fc.features[0].properties["emoji"] as? String == "🏔️")
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
        #expect(throws: CSVError.invalidGeometry(
            detail: "at least 2 coordinates are required for a LineString, got 1"))
        {
            _ = try CSVCoder.read(from: data, options: CSVReadOptions(treatAsLineString: true))
        }
    }

    @Test
    func treatAsLineStringAllowsDuplicateCoordinates() throws {
        let data = Data("""
        latitude,longitude
        48.1,11.5
        48.1,11.5
        """.utf8)
        let fc = try CSVCoder.read(from: data, options: CSVReadOptions(treatAsLineString: true))
        let line = try #require(fc.features.first?.geometry as? LineString)
        #expect(line.coordinates.count == 2)
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
    func treatAsLineStringWithUnlocatedFeatureThrows() {
        let data = Data("""
        id,geometry
        p1,"POINT (1 2)"
        p2,
        """.utf8)
        #expect(throws: CSVError.missingGeometry(line: 3)) {
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

// MARK: - Projection support

struct CSVProjectionReadTests {

    @Test
    func readXYCoordinatesInWebMercator() throws {
        let data = Data("""
        id,x,y,name
        1,1281000,6125000,Munich
        """.utf8)

        let fc = try CSVCoder.read(
            from: data,
            options: CSVReadOptions(projection: .epsg3857))
        let point = try #require(fc.features.first?.geometry as? Point)

        #expect(point.coordinate.projection == .epsg3857)
        #expect(point.coordinate.x == 1_281_000)
        #expect(point.coordinate.y == 6_125_000)
        #expect(fc.features.first?.properties["name"] as? String == "Munich")
    }

    @Test
    func readXYCoordinatesInNoSRID() throws {
        let data = Data("""
        x,y
        12.5,34.5
        """.utf8)

        let fc = try CSVCoder.read(
            from: data,
            options: CSVReadOptions(projection: .noSRID))
        let point = try #require(fc.features.first?.geometry as? Point)

        #expect(point.coordinate.projection == .noSRID)
        #expect(point.coordinate.x == 12.5)
        #expect(point.coordinate.y == 34.5)
    }

    @Test
    func canonicalLongitudeLatitudeWinsOverXY() throws {
        let data = Data("""
        x,y,longitude,latitude
        0,0,11.5,48.1
        """.utf8)

        let fc = try CSVCoder.read(from: data)
        let feature = try #require(fc.features.first)
        let point = try #require(feature.geometry as? Point)

        #expect(point.coordinate.longitude == 11.5)
        #expect(point.coordinate.latitude == 48.1)
        #expect(feature.properties["x"] as? Int == 0)
        #expect(feature.properties["y"] as? Int == 0)
    }

    @Test
    func readProjectedWKTGeometry() throws {
        let data = Data("""
        geometry
        POINT (1281000 6125000)
        """.utf8)

        let fc = try CSVCoder.read(
            from: data,
            options: CSVReadOptions(projection: .epsg3857))
        let point = try #require(fc.features.first?.geometry as? Point)

        #expect(point.coordinate.projection == .epsg3857)
        #expect(point.coordinate.x == 1_281_000)
        #expect(point.coordinate.y == 6_125_000)
    }
}

// MARK: - Additional projection coverage

struct CSVProjectionAdditionalReadTests {

    @Test
    func readECEFCoordinates() throws {
        let ecef = Coordinate3D(latitude: 48.1, longitude: 11.5)
            .projected(to: .epsg4978)
        let data = Data("""
        x,y,z
        \(ecef.x),\(ecef.y),\(ecef.z ?? 0)
        """.utf8)

        let fc = try CSVCoder.read(
            from: data,
            options: CSVReadOptions(projection: .epsg4978))
        let point = try #require(fc.features.first?.geometry as? Point)

        #expect(point.coordinate.projection == .epsg4978)
        #expect(abs(point.coordinate.x - ecef.x) < 0.000001)
        #expect(abs(point.coordinate.y - ecef.y) < 0.000001)
    }

    @Test
    func readCustomProjectionCoordinates() throws {
        let srid = 900_501
        let custom = CustomProjection(
            srid: srid,
            kind: .planar,
            forward: { coordinate in
                Coordinate3D(
                    x: coordinate.longitude * 1_000.0,
                    y: coordinate.latitude * 1_000.0,
                    projection: .epsg4326)
            },
            inverse: { coordinate in
                Coordinate3D(
                    latitude: coordinate.latitude / 1_000.0,
                    longitude: coordinate.longitude / 1_000.0)
            })
        _ = Projection.register(custom)
        let projection = try #require(Projection(srid: srid))

        let data = Data("""
        x,y
        11500,48100
        """.utf8)
        let fc = try CSVCoder.read(
            from: data,
            options: CSVReadOptions(projection: projection))
        let point = try #require(fc.features.first?.geometry as? Point)

        #expect(point.coordinate.projection == projection)
        #expect(point.coordinate.x == 11_500)
        #expect(point.coordinate.y == 48_100)
    }

    @Test
    func invalidProjectedCoordinateThrows() throws {
        let data = Data("""
        x,y
        999999999999999999999,999999999999999999999
        """.utf8)

        do {
            _ = try CSVCoder.read(
                from: data,
                options: CSVReadOptions(projection: .epsg3857))
            Issue.record("Expected invalid projected coordinate to throw")
        }
        catch let error as CSVError {
            guard case .invalidCoordinate = error else {
                Issue.record("Expected invalidCoordinate, got \(error)")
                return
            }
        }
    }
}

// MARK: - CRS column support

struct CSVCRSColumnReadTests {

    @Test
    func readProjectionFromCRSColumn() throws {
        let data = Data("""
        crs,x,y,name
        EPSG:3857,1281000,6125000,Munich
        """.utf8)

        let fc = try CSVCoder.read(from: data)
        let point = try #require(fc.features.first?.geometry as? Point)

        #expect(point.coordinate.projection == .epsg3857)
        #expect(point.coordinate.x == 1_281_000)
        #expect(fc.features.first?.properties["name"] as? String == "Munich")
    }

    @Test
    func readProjectionFromSRIDColumn() throws {
        let data = Data("""
        srid,longitude,latitude
        3857,1281000,6125000
        """.utf8)

        let fc = try CSVCoder.read(from: data)
        let point = try #require(fc.features.first?.geometry as? Point)
        #expect(point.coordinate.projection == .epsg3857)
    }

    @Test
    func crsColumnOverridesFallback() throws {
        let data = Data("""
        projection,x,y
        noSRID,12.5,34.5
        """.utf8)

        let fc = try CSVCoder.read(
            from: data,
            options: CSVReadOptions(projection: .epsg3857))
        let point = try #require(fc.features.first?.geometry as? Point)
        #expect(point.coordinate.projection == .noSRID)
    }

    @Test
    func invalidCRSColumnValueThrows() throws {
        let data = Data("""
        crs,x,y
        not-a-projection,12.5,34.5
        """.utf8)

        do {
            _ = try CSVCoder.read(from: data)
            Issue.record("Expected invalid CRS to throw")
        }
        catch let error as CSVError {
            guard case .invalidProjection = error else {
                Issue.record("Expected invalidProjection, got \(error)")
                return
            }
        }
    }

    @Test
    func inconsistentCRSColumnValuesThrow() throws {
        let data = Data("""
        crs,x,y
        EPSG:3857,1281000,6125000
        EPSG:4326,11.5,48.1
        """.utf8)

        do {
            _ = try CSVCoder.read(from: data)
            Issue.record("Expected inconsistent CRS to throw")
        }
        catch let error as CSVError {
            guard case .invalidProjection = error else {
                Issue.record("Expected invalidProjection, got \(error)")
                return
            }
        }
    }
}
