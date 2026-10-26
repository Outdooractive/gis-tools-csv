import Foundation
import GISTools

// MARK: - CSVCoder

/// Reads and writes CSV files to and from a `FeatureCollection`.
///
/// CSV files must have a header row — geometry is never guessed. The header
/// is matched case-insensitively and may contain:
///
/// | Role            | Accepted column names                    |
/// |-----------------|------------------------------------------|
/// | Geometry        | `geometry`, `geom`                       |
/// | Latitude        | `latitude`, `lat`                        |
/// | Longitude       | `longitude`, `long`, `lon`, `lng`        |
/// | Altitude        | `altitude`, `elevation`, `elev`, `z`     |
/// | Feature id      | `id`, `feature_id`, `feature_identifier`, `identifier`, `fid`, … |
///
/// Every other column becomes a `Feature` property.
///
/// A geometry column can contain WKT (with or without an `SRID=…;` prefix),
/// hex-encoded WKB/EWKB/TWKB, or a GeoJSON geometry. Parsed geometries are
/// always returned in EPSG:4326; other projections are reprojected by the
/// underlying `GISTools` reader. An empty or `NULL` geometry cell becomes an
/// unlocated feature (no geometry) when the row has no latitude/longitude
/// values; when it does, the coordinate pair is used instead.
///
/// When writing, the `geometry`/`geom` column is always emitted as the
/// configured geometry column name (``CSVWriteOptions/geometryColumnName``,
/// default `geometry`). If every `Feature` is a simple `Point` in
/// EPSG:4326, the output uses `id`, `longitude`, `latitude`, `altitude`
/// columns; otherwise the geometry column is emitted last (it can be long).
/// Properties whose names collide with a reserved column name are omitted,
/// because the reader would otherwise misinterpret them.
public enum CSVCoder {

    /// The default field delimiter.
    public static let defaultDelimiter: Character = ","

    // MARK: - Read

    /// Reads a CSV file and returns a `FeatureCollection`.
    ///
    /// - Parameters:
    ///   - url: The URL of the CSV file to read.
    ///   - options: The read options (default ``CSVReadOptions``).
    /// - Returns: A `FeatureCollection` with the CSV data.
    /// - Throws: ``CSVError`` if the file cannot be read or parsed.
    public static func read(
        from url: URL,
        options: CSVReadOptions = CSVReadOptions(),
    ) throws -> FeatureCollection {
        do {
            let data = try Data(contentsOf: url)
            return try read(from: data, options: options)
        }
        catch let error as CSVError {
            throw error
        }
        catch {
            throw CSVError.fileReadError(detail: error.localizedDescription)
        }
    }

    /// Reads CSV data and returns a `FeatureCollection`.
    ///
    /// The data must be UTF-8 encoded. A leading UTF-8 byte order mark is
    /// ignored.
    ///
    /// - Parameters:
    ///   - data: The raw CSV data.
    ///   - options: The read options (default ``CSVReadOptions``).
    /// - Returns: A `FeatureCollection` with the CSV data.
    /// - Throws: ``CSVError`` if the data cannot be parsed.
    public static func read(
        from data: Data,
        options: CSVReadOptions = CSVReadOptions(),
    ) throws -> FeatureCollection {
        let rows = try CSVReader.parse(data: data, delimiter: options.delimiter)
        return try convertToFeatureCollection(
            rows: rows,
            nullHandling: options.nullHandling,
            projection: options.projection,
            treatAsLineString: options.treatAsLineString)
    }

    // MARK: - Write

    /// Serializes a `FeatureCollection` to CSV data.
    ///
    /// The output is UTF-8 and ends with the configured line ending.
    ///
    /// - Parameters:
    ///   - featureCollection: The FeatureCollection to serialize.
    ///   - options: The write options (default ``CSVWriteOptions``).
    /// - Returns: The CSV data.
    /// - Throws: ``CSVError`` if serialization fails.
    public static func write(
        _ featureCollection: FeatureCollection,
        options: CSVWriteOptions = CSVWriteOptions(),
    ) throws -> Data {
        let rows = try rows(from: featureCollection, options: options)
        let string = CSVWriter.write(rows, delimiter: options.delimiter, lineEnding: options.lineEnding)
        guard let data = string.data(using: .utf8) else {
            throw CSVError.invalidEncoding
        }

        return data
    }

    /// Writes a `FeatureCollection` as a CSV file.
    ///
    /// - Parameters:
    ///   - featureCollection: The FeatureCollection to write.
    ///   - url: The output URL for the CSV file.
    ///   - options: The write options (default ``CSVWriteOptions``).
    /// - Throws: ``CSVError`` if the file cannot be written.
    public static func write(
        _ featureCollection: FeatureCollection,
        to url: URL,
        options: CSVWriteOptions = CSVWriteOptions(),
    ) throws {
        let data = try write(featureCollection, options: options)
        do {
            try data.write(to: url)
        }
        catch {
            throw CSVError.fileWriteError(detail: error.localizedDescription)
        }
    }

    // MARK: - Convert rows → FeatureCollection

    private static func convertToFeatureCollection(
        rows: [[String]],
        nullHandling: CSVNullHandling,
        projection: Projection,
        treatAsLineString: Bool = false,
    ) throws -> FeatureCollection {
        guard let headerRow = rows.first, headerRow.isNotEmpty else {
            throw CSVError.missingHeader
        }

        let mapping = CSVColumnMapping(headers: headerRow)
        guard mapping.hasGeometrySource else {
            throw CSVError.missingGeometryColumns
        }

        let projection = try resolvedProjection(
            rows: rows,
            mapping: mapping,
            fallback: projection)

        var features: [Feature] = []
        var lineNumbers: [Int] = []
        for (lineIndex, row) in rows.dropFirst().enumerated() {
            // Skip completely blank lines. A line containing delimiters is a
            // record, even when all of its fields are empty.
            if row.count == 1, row[0].trimmingCharacters(in: .whitespaces).isEmpty {
                continue
            }
            try features.append(
                feature(
                    from: row,
                    mapping: mapping,
                    line: lineIndex + 2,
                    nullHandling: nullHandling,
                    projection: projection))
            lineNumbers.append(lineIndex + 2)
        }

        if treatAsLineString {
            return try flattenToLineString(features: features, lineNumbers: lineNumbers)
        }

        return FeatureCollection(features)
    }

    /// Concatenates the coordinates of all features (in order) into a single
    /// `LineString` feature.
    ///
    /// - Parameters:
    ///   - features: The parsed features.
    ///   - lineNumbers: The CSV line number for each feature (for error messages).
    /// - Returns: A `FeatureCollection` with a single `LineString` feature.
    /// - Throws: ``CSVError`` for unsupported geometry types or fewer than
    ///   2 coordinates in total.
    private static func flattenToLineString(
        features: [Feature],
        lineNumbers: [Int],
    ) throws -> FeatureCollection {
        var coordinates: [Coordinate3D] = []
        for (feature, line) in zip(features, lineNumbers) {
            guard let geometry = feature.geometry else {
                throw CSVError.missingGeometry(line: line)
            }

            switch geometry {
            case let point as Point:
                coordinates.append(point.coordinate)

            case let multiPoint as MultiPoint:
                coordinates.append(contentsOf: multiPoint.coordinates)

            case let lineString as LineString:
                coordinates.append(contentsOf: lineString.coordinates)

            case let multiLineString as MultiLineString:
                for lineString in multiLineString.coordinates {
                    coordinates.append(contentsOf: lineString)
                }

            default:
                throw CSVError.invalidGeometry(
                    detail: "row \(line): \(type(of: geometry)) cannot be converted to a LineString")
            }
        }

        guard coordinates.count >= 2, let lineString = LineString(coordinates) else {
            throw CSVError.invalidGeometry(
                detail: "at least 2 coordinates are required for a LineString, got \(coordinates.count)")
        }

        return FeatureCollection([Feature(lineString)])
    }

    private static func feature(
        from row: [String],
        mapping: CSVColumnMapping,
        line: Int,
        nullHandling: CSVNullHandling,
        projection: Projection,
    ) throws -> Feature {
        var properties: [String: Sendable] = [:]

        // Determine the geometry. A non-empty, non-NULL geometry cell wins; an
        // empty or NULL geometry cell falls back to a latitude/longitude pair,
        // or produces an unlocated feature when no coordinate pair is available.
        var geometry: GeoJsonGeometry?
        var hasGeometryCell = false

        if let geometryIndex = mapping.geometryIndex {
            guard geometryIndex < row.count else {
                throw CSVError.missingGeometry(line: line)
            }

            hasGeometryCell = true

            let text = row[geometryIndex]
            if !isNullValue(text) {
                // The reader auto-detects the format: WKT (with or without an
                // `SRID=…;` prefix), hex-encoded WKB/EWKB/TWKB, or GeoJSON.
                guard let decoded = decodeGeometry(text, projection: projection) else {
                    throw CSVError.invalidGeometry(detail: "row \(line): could not parse geometry")
                }

                geometry = decoded
            }
        }

        if geometry == nil,
           let latitudeIndex = mapping.latitudeIndex,
           let longitudeIndex = mapping.longitudeIndex,
           latitudeIndex < row.count,
           longitudeIndex < row.count
        {
            let latitude = try coordinateValue(
                in: row,
                at: latitudeIndex,
                line: line,
                name: "latitude")
            let longitude = try coordinateValue(
                in: row,
                at: longitudeIndex,
                line: line,
                name: "longitude")
            var altitude: Double?
            if let altitudeIndex = mapping.altitudeIndex, altitudeIndex < row.count {
                altitude = try altitudeValue(in: row, at: altitudeIndex, line: line)
            }

            if projection == .epsg4326 {
                guard (-90.0 ... 90.0).contains(latitude) else {
                    throw CSVError.invalidCoordinate(
                        detail: "row \(line): latitude \(latitude) is out of range")
                }
                guard (-180.0 ... 180.0).contains(longitude) else {
                    throw CSVError.invalidCoordinate(
                        detail: "row \(line): longitude \(longitude) is out of range")
                }
                geometry = Point(Coordinate3D(
                    latitude: latitude,
                    longitude: longitude,
                    altitude: altitude))
            }
            else {
                let coordinate = Coordinate3D(
                    x: longitude,
                    y: latitude,
                    z: altitude,
                    projection: projection)
                guard coordinate.isValid else {
                    throw CSVError.invalidCoordinate(
                        detail: "row \(line): coordinate is outside the projection's valid extent")
                }
                geometry = Point(coordinate)
            }
        }

        // A header without a geometry column must still provide a coordinate
        // pair for every row; only an explicitly empty geometry cell may
        // produce an unlocated feature.
        if geometry == nil, !hasGeometryCell {
            throw CSVError.missingGeometry(line: line)
        }

        // Build the feature.
        var feature =
            if let geometry {
                Feature(geometry)
            }
            else {
                Feature()
            }

        if let idIndex = mapping.idIndex, idIndex < row.count {
            let text = row[idIndex].trimmingCharacters(in: .whitespaces)
            if text.isNotEmpty, !(nullHandling == .omit && isNullValue(text)) {
                feature.id = identifier(from: text)
            }
        }

        // Remaining columns become properties.
        for (index, header) in mapping.headers.enumerated() {
            guard index < row.count else { continue }

            switch mapping.roles[index] {
            case .altitude, .geometry, .id, .latitude, .longitude, .projection:
                continue
            case .property:
                let value = row[index]
                if nullHandling == .omit, isNullValue(value) {
                    continue
                }
                properties[header] = parseValue(value)
            }
        }

        feature.properties = properties
        return feature
    }

    /// Decodes a hex string into bytes for WKB/EWKB/TWKB geometry cells.
    private static func hexData(_ string: String) -> Data? {
        let characters = Array(string.trimmingCharacters(in: .whitespacesAndNewlines))
        guard characters.count.isMultiple(of: 2), characters.isNotEmpty else {
            return nil
        }

        var bytes: [UInt8] = []
        bytes.reserveCapacity(characters.count / 2)
        for index in stride(from: 0, to: characters.count, by: 2) {
            guard let byte = UInt8(String(characters[index ... index + 1]), radix: 16) else {
                return nil
            }
            bytes.append(byte)
        }
        return Data(bytes)
    }

    /// Resolves a CRS/projection column for the whole file.
    ///
    /// A CRS column is optional. When present, all non-empty values must
    /// resolve to the same projection; empty/NULL cells fall back to
    /// ``CSVReadOptions/projection``.
    private static func resolvedProjection(
        rows: [[String]],
        mapping: CSVColumnMapping,
        fallback: Projection,
    ) throws -> Projection {
        guard let projectionIndex = mapping.projectionIndex else {
            return fallback
        }

        var resolved: Projection?
        for (lineIndex, row) in rows.dropFirst().enumerated() {
            guard projectionIndex < row.count else { continue }
            let text = row[projectionIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            if isNullValue(text) {
                continue
            }
            guard let projection = parseProjection(text) else {
                throw CSVError.invalidProjection(
                    detail: "row \(lineIndex + 2): unknown projection '\(text)'")
            }
            if let resolved, resolved != projection {
                throw CSVError.invalidProjection(
                    detail: "row \(lineIndex + 2): projection '\(text)' conflicts with an earlier row")
            }
            resolved = projection
        }

        return resolved ?? fallback
    }

    /// Parses a CRS/projection identifier from a CSV cell.
    ///
    /// Accepts plain SRIDs, `EPSG:n`, `urn:ogc:def:crs:EPSG::n`, `SRID=n`,
    /// `noSRID`/`none`, and WKT strings recognized by GISTools.
    private static func parseProjection(_ text: String) -> Projection? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()

        if lower == "nosrid" || lower == "none" {
            return .noSRID
        }

        if lower.hasPrefix("srid=") {
            let value = trimmed.dropFirst("srid=".count)
                .prefix { $0 != ";" }
            return Int(value).flatMap(Projection.init(srid:))
        }

        if lower.hasPrefix("epsg:") {
            return Int(trimmed.dropFirst("epsg:".count))
                .flatMap(Projection.init(srid:))
        }

        if lower.hasPrefix("urn:") {
            let value = trimmed.split(separator: ":").last.map(String.init) ?? ""
            return Int(value).flatMap(Projection.init(srid:))
        }

        if let srid = Int(trimmed) {
            return Projection(srid: srid)
        }

        return Projection(wkt: trimmed)
    }

    /// Decodes a geometry cell using the CSV's coordinate projection.
    ///
    /// GeoJSON geometry cells are defined as EPSG:4326 and are projected to
    /// the selected projection. WKT/WKB values without an embedded SRID are
    /// interpreted in the selected projection; embedded SRIDs take precedence.
    private static func decodeGeometry(
        _ text: String,
        projection: Projection,
    ) -> GeoJsonGeometry? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if trimmed.hasPrefix("{") {
            return GeoJsonReader.geometryFrom(string: trimmed, targetProjection: projection)
        }

        if let data = hexData(trimmed) {
            if let geometry = try? WKBCoder.decode(
                wkb: data,
                sourceProjection: nil,
                targetProjection: projection)
            {
                return geometry
            }
            if let geometry = try? WKBCoder.decode(
                wkb: data,
                sourceProjection: projection,
                targetProjection: projection)
            {
                return geometry
            }
            if let geometry = try? TWKBCoder.decode(
                twkb: data,
                sourceProjection: nil,
                targetProjection: projection)
            {
                return geometry
            }
            return try? TWKBCoder.decode(
                twkb: data,
                sourceProjection: projection,
                targetProjection: projection)
        }

        let sourceProjection: Projection? = trimmed.hasPrefix("SRID=") ? nil : projection
        return try? WKTCoder.decode(
            wkt: trimmed,
            sourceProjection: sourceProjection,
            targetProjection: projection)
    }

    /// Parses a required latitude or longitude value.
    private static func coordinateValue(
        in row: [String],
        at index: Int,
        line: Int,
        name: String,
    ) throws -> Double {
        let text = row[index].trimmingCharacters(in: .whitespaces)
        guard let value = Double(text), value.isFinite else {
            throw CSVError.invalidCoordinate(detail: "row \(line): invalid \(name)")
        }

        return value
    }

    /// Parses an optional altitude value. Empty and `NULL` cells become `nil`.
    private static func altitudeValue(
        in row: [String],
        at index: Int,
        line: Int,
    ) throws -> Double? {
        let text = row[index].trimmingCharacters(in: .whitespaces)
        if text.isEmpty || text.lowercased() == "null" {
            return nil
        }
        guard let value = Double(text), value.isFinite else {
            throw CSVError.invalidCoordinate(detail: "row \(line): invalid altitude")
        }

        return value
    }

    /// Whether a raw CSV value should be treated as null.
    ///
    /// `NULL` is matched case-insensitively; empty (or whitespace-only)
    /// values are also treated as null.
    private static func isNullValue(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty || trimmed.lowercased() == "null"
    }

    // MARK: - Convert FeatureCollection → rows

    private static func rows(
        from featureCollection: FeatureCollection,
        options: CSVWriteOptions,
    ) throws -> [[String]] {
        let output = options.projection.map { featureCollection.projected(to: $0) }
            ?? featureCollection
        let features = output.features
        let projection = options.projection ?? featureCollection.projection
        let projectionColumn = try projectionColumnName(options: options)

        // An explicit geometry format always uses the geometry column. `.auto`
        // keeps the point-coordinate layout for any projection; non-4326
        // values use x/y/z column names unless another style was requested.
        if options.geometryFormat == .auto,
           features.allSatisfy({ $0.geometry is Point })
        {
            return try pointRows(
                features,
                projection: projection,
                projectionColumn: projectionColumn,
                options: options)
        }
        return try mixedRows(
            features,
            projection: projection,
            projectionColumn: projectionColumn,
            options: options)
    }

    /// Validates and returns the optional CRS column name.
    private static func projectionColumnName(
        options: CSVWriteOptions,
    ) throws -> String? {
        guard let rawName = options.projectionColumnName else { return nil }
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard name.isNotEmpty,
              CSVColumnMapping.projectionAliases.contains(name.lowercased())
        else {
            throw CSVError.invalidProjection(
                detail: "projection column name '\(rawName)' must be one of projection, crs, or srid")
        }
        return name
    }

    /// Formats the output projection for a CRS column.
    private static func projectionValue(_ projection: Projection) -> String {
        projection.hasSRID ? "EPSG:\(projection.srid)" : "noSRID"
    }

    /// Rows when every feature is a simple point.
    ///
    /// Column order: `id`, coordinate columns, then the remaining property
    /// columns. EPSG:4326 defaults to `longitude`/`latitude`/`altitude`;
    /// other projections default to `x`/`y`/`z`.
    private static func pointRows(
        _ features: [Feature],
        projection: Projection,
        projectionColumn: String?,
        options: CSVWriteOptions,
    ) throws -> [[String]] {
        let useXY: Bool
        switch options.coordinateColumns {
        case .automatic: useXY = projection != .epsg4326
        case .xy: useXY = true
        case .longitudeLatitude: useXY = false
        }

        let propertyColumns = orderedPropertyColumns(
            features,
            excluding: CSVColumnMapping.allReservedNames)
        let coordinateNames = useXY
            ? ("x", "y", "z")
            : ("longitude", "latitude", "altitude")
        let header = ["id"]
            + (projectionColumn.map { [$0] } ?? [])
            + [coordinateNames.0, coordinateNames.1, coordinateNames.2]
            + propertyColumns

        var rows: [[String]] = options.includeHeader ? [header] : []
        for feature in features {
            guard let point = feature.geometry as? Point else { continue }

            let coordinate = point.coordinate

            var row: [String] = []
            row.append(idValue(feature.id))
            if projectionColumn != nil {
                row.append(projectionValue(projection))
            }
            row.append(formatNumber(coordinate.longitude))
            row.append(formatNumber(coordinate.latitude))
            row.append(coordinate.altitude.map(formatNumber) ?? options.nullValue)
            for column in propertyColumns {
                row.append(value(for: column, in: feature, nullValue: options.nullValue))
            }
            rows.append(row)
        }
        return rows
    }

    /// Rows when at least one feature has a complex (non-Point) geometry, no
    /// geometry, or an explicit geometry format is requested.
    ///
    /// Column order: `id`, property columns, then the geometry column last.
    private static func mixedRows(
        _ features: [Feature],
        projection: Projection,
        projectionColumn: String?,
        options: CSVWriteOptions,
    ) throws -> [[String]] {
        let geometryColumnName = options.geometryColumnName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard geometryColumnName.isNotEmpty,
              !CSVColumnMapping.nonGeometryReservedNames.contains(geometryColumnName.lowercased())
        else {
            throw CSVError.invalidGeometryColumnName(name: options.geometryColumnName)
        }

        let reserved = CSVColumnMapping.allReservedNames
            .union([geometryColumnName.lowercased()])
        let propertyColumns = orderedPropertyColumns(features, excluding: reserved)

        let header = ["id"]
            + (projectionColumn.map { [$0] } ?? [])
            + propertyColumns
            + [geometryColumnName]
        var rows: [[String]] = options.includeHeader ? [header] : []
        for feature in features {
            var row: [String] = [idValue(feature.id)]
            if projectionColumn != nil {
                row.append(projectionValue(projection))
            }
            for column in propertyColumns {
                row.append(value(for: column, in: feature, nullValue: options.nullValue))
            }
            try row.append(geometryValue(
                feature.geometry,
                format: options.geometryFormat,
                projection: projection))
            rows.append(row)
        }
        return rows
    }

    /// Encodes a geometry for the geometry column in the requested format.
    ///
    /// An unlocated feature (`nil` geometry) is written as an empty cell.
    private static func geometryValue(
        _ geometry: GeoJsonGeometry?,
        format: CSVGeometryFormat,
        projection: Projection,
    ) throws -> String {
        guard let geometry else { return "" }

        switch format {
        case .auto, .wkt:
            guard let wkt = WKTCoder.encode(
                geometry: geometry,
                targetProjection: projection)
            else {
                throw CSVError.invalidGeometry(
                    detail: "could not encode \(type(of: geometry)) as WKT")
            }

            return wkt

        case .ewkb:
            guard let data = WKBCoder.encode(geometry: geometry, targetProjection: projection) else {
                throw CSVError.invalidGeometry(
                    detail: "could not encode \(type(of: geometry)) as EWKB")
            }

            return data.hexEncodedString()

        case .geojson:
            // GeoJSON is defined in EPSG:4326. Reproject before serializing so
            // projected coordinates aren't emitted without their CRS.
            let output = geometry.projection == .epsg4326
                ? geometry
                : geometry.projected(to: .epsg4326)
            guard let json = output.asJsonString() else {
                throw CSVError.invalidGeometry(
                    detail: "could not encode \(type(of: geometry)) as GeoJSON")
            }

            return json
        }
    }

    // MARK: - Property columns

    /// Computes the ordered, deduplicated property column names across all
    /// features, excluding any reserved names.
    ///
    /// Within one feature, property keys are sorted alphabetically. This
    /// makes the output deterministic even though Swift dictionaries have no
    /// stable iteration order.
    private static func orderedPropertyColumns(
        _ features: [Feature],
        excluding reserved: Set<String>,
    ) -> [String] {
        let reservedLower = Set(reserved.map { $0.lowercased() })
        var columns: [String] = []
        var seen = Set<String>()

        for feature in features {
            for key in feature.properties.keys.sorted() {
                let lower = key.lowercased()
                if reservedLower.contains(lower) || seen.contains(lower) {
                    continue
                }
                seen.insert(lower)
                columns.append(key)
            }
        }
        return columns
    }

    /// Returns the property value for a column, matching names
    /// case-insensitively. The first spelling encountered wins.
    private static func propertyValue(
        for column: String,
        in feature: Feature,
    ) -> Sendable? {
        if let value = feature.properties[column] {
            return value
        }
        let lower = column.lowercased()
        guard let key = feature.properties
            .keys
            .sorted()
            .first(where: { $0.lowercased() == lower })
        else {
            return nil
        }

        return feature.properties[key]
    }

    private static func value(
        for column: String,
        in feature: Feature,
        nullValue: String,
    ) -> String {
        guard let value = propertyValue(for: column, in: feature) else {
            return nullValue
        }

        if let number = value as? Double {
            return formatDouble(number, forceDecimal: true)
        }
        if let number = value as? Int {
            return "\(number)"
        }
        if let boolean = value as? Bool {
            return boolean ? "true" : "false"
        }
        return "\(value)"
    }

    // MARK: - Helpers

    /// Builds a `Feature.Identifier` from a string, preferring numeric ids.
    ///
    /// Only canonical numeric spellings are converted. Values such as `001`
    /// or `1e3` stay strings so that leading zeros and textual ids survive a
    /// round-trip.
    private static func identifier(from text: String) -> Feature.Identifier {
        if let int = Feature.Identifier.IntId(text), String(int) == text {
            return .int(int)
        }
        if let uint = Feature.Identifier.UIntId(text), String(uint) == text {
            return .uint(uint)
        }
        if let double = Double(text), double.isFinite, String(double) == text {
            return .double(double)
        }
        return .string(text)
    }

    private static func idValue(_ id: Feature.Identifier?) -> String {
        switch id {
        case let .string(value):
            value
        case let .int(value):
            "\(value)"
        case let .uint(value):
            "\(value)"
        case let .double(value):
            formatDouble(value, forceDecimal: true)
        case .none:
            ""
        }
    }

    /// Parses a raw CSV field into a loosely-typed value.
    ///
    /// Booleans, integers, and floating-point numbers are detected; anything
    /// else is kept as a string. Only canonical integer spellings become
    /// `Int`, so values with leading zeros (postal codes, ids) stay strings.
    /// Non-finite values such as `NaN` and `Infinity` stay strings, because
    /// they cannot be represented in JSON.
    private static func parseValue(_ text: String) -> Sendable {
        switch text.lowercased() {
        case "true": return true
        case "false": return false
        default:
            if let int = Int(text), String(int) == text {
                return int
            }
            if text.contains(".") || text.contains("e") || text.contains("E"),
               let double = Double(text), double.isFinite
            {
                return double
            }
            return text
        }
    }

    /// Formats a coordinate value using the shortest round-trip
    /// representation, without a trailing `.0` for whole numbers.
    private static func formatNumber(_ value: Double) -> String {
        guard value.isFinite else { return "" }

        let text = String(value)
        if text.hasSuffix(".0") {
            return String(text.dropLast(2))
        }
        return text
    }

    /// Formats a `Double` property or id using the shortest round-trip
    /// representation. Whole numbers keep a `.0` suffix so they read back as
    /// `Double` instead of `Int`.
    private static func formatDouble(_ value: Double, forceDecimal: Bool) -> String {
        guard value.isFinite else { return "" }

        let text = String(value)
        if forceDecimal,
           !text.contains("."),
           !text.contains("e"),
           !text.contains("E")
        {
            return text + ".0"
        }
        return text
    }

}

// MARK: - Data hex encoding

extension Data {

    /// The receiver as an uppercase hex string.
    fileprivate func hexEncodedString() -> String {
        map { String(format: "%02X", $0) }.joined()
    }

}
