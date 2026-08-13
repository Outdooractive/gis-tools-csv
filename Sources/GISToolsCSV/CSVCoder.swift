import Foundation
import GISTools

// MARK: - CSVCoder

/// Reads and writes CSV files to and from a ``FeatureCollection``.
///
/// CSV files must have a header row — geometry is never guessed. The header
/// is matched case-insensitively and may contain:
///
/// | Role            | Accepted column names                    |
/// |-----------------|------------------------------------------|
/// | Geometry (WKT)  | `geometry`, `geom`                       |
/// | Latitude        | `latitude`, `lat`                        |
/// | Longitude       | `longitude`, `long`, `lng`               |
/// | Altitude        | `altitude`, `elevation`, `elev`, `z`     |
/// | Feature id      | `id`, `feature_id`, `feature_identifier`, `identifier`, `fid`, … |
///
/// Every other column becomes a ``Feature`` property.
///
/// When writing, the `geometry`/`geom` column is always emitted as
/// `geometry` (WKT). If every ``Feature`` is a simple `Point`, the output
/// uses `id`, `longitude`, `latitude`, `altitude` columns; otherwise the
/// geometry column is emitted last (it can be long).
public enum CSVCoder {

    /// The default field delimiter.
    public static let defaultDelimiter: Character = ","

    // MARK: - Read

    /// Reads a CSV file and returns a ``FeatureCollection``.
    ///
    /// - Parameters:
    ///   - url: The URL of the CSV file to read.
    ///   - options: The read options (default ``CSVReadOptions``).
    /// - Returns: A ``FeatureCollection`` with the CSV data.
    /// - Throws: ``CSVError`` if the file cannot be read or parsed.
    public static func read(
        from url: URL,
        options: CSVReadOptions = CSVReadOptions()
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

    /// Reads CSV data and returns a ``FeatureCollection``.
    ///
    /// - Parameters:
    ///   - data: The raw CSV data.
    ///   - options: The read options (default ``CSVReadOptions``).
    /// - Returns: A ``FeatureCollection`` with the CSV data.
    /// - Throws: ``CSVError`` if the data cannot be parsed.
    public static func read(
        from data: Data,
        options: CSVReadOptions = CSVReadOptions()
    ) throws -> FeatureCollection {
        let rows = try CSVReader.parse(data: data, delimiter: options.delimiter)
        return try convertToFeatureCollection(rows: rows, nullHandling: options.nullHandling)
    }

    // MARK: - Write

    /// Serializes a ``FeatureCollection`` to CSV data.
    ///
    /// - Parameters:
    ///   - featureCollection: The FeatureCollection to serialize.
    ///   - options: The write options (default ``CSVWriteOptions``).
    /// - Returns: The CSV data.
    /// - Throws: ``CSVError`` if serialization fails.
    public static func write(
        _ featureCollection: FeatureCollection,
        options: CSVWriteOptions = CSVWriteOptions()
    ) throws -> Data {
        let rows = rows(from: featureCollection, options: options)
        let string = CSVWriter.write(rows, delimiter: options.delimiter, lineEnding: options.lineEnding)
        guard let data = string.data(using: .utf8) else {
            throw CSVError.invalidEncoding
        }
        return data
    }

    /// Writes a ``FeatureCollection`` as a CSV file.
    ///
    /// - Parameters:
    ///   - featureCollection: The FeatureCollection to write.
    ///   - url: The output URL for the CSV file.
    ///   - options: The write options (default ``CSVWriteOptions``).
    /// - Throws: ``CSVError`` if the file cannot be written.
    public static func write(
        _ featureCollection: FeatureCollection,
        to url: URL,
        options: CSVWriteOptions = CSVWriteOptions()
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
        nullHandling: CSVNullHandling
    ) throws -> FeatureCollection {
        guard let headerRow = rows.first, !headerRow.isEmpty else {
            throw CSVError.missingHeader
        }

        let mapping = CSVColumnMapping(headers: headerRow)
        guard mapping.hasGeometrySource else {
            throw CSVError.missingHeader
        }

        var features: [Feature] = []
        for (lineIndex, row) in rows.dropFirst().enumerated() {
            // Skip fully empty lines.
            if row.allSatisfy({ $0.trimmingCharacters(in: .whitespaces).isEmpty }) {
                continue
            }
            features.append(
                try feature(from: row, mapping: mapping, line: lineIndex + 2, nullHandling: nullHandling))
        }

        return FeatureCollection(features)
    }

    private static func feature(
        from row: [String],
        mapping: CSVColumnMapping,
        line: Int,
        nullHandling: CSVNullHandling
    ) throws -> Feature {
        var properties: [String: Sendable] = [:]

        // Determine the geometry.
        var geometry: GeoJsonGeometry?
        if let geometryIndex = mapping.geometryIndex,
           geometryIndex < row.count,
           !row[geometryIndex].isEmpty
        {
            let text = row[geometryIndex]
            do {
                // The reader auto-detects the format: WKT (with or without an
                // `SRID=…;` prefix), hex-encoded WKB/EWKB/TWKB, or GeoJSON.
                guard let decoded = GeoJsonReader.geometryFrom(string: text) else {
                    throw CSVError.invalidGeometry(detail: "row \(line): could not parse geometry")
                }
                geometry = decoded
            }
            catch {
                throw CSVError.invalidGeometry(detail: error.localizedDescription)
            }
        }
        else if let latitudeIndex = mapping.latitudeIndex,
                let longitudeIndex = mapping.longitudeIndex,
                latitudeIndex < row.count,
                longitudeIndex < row.count
        {
            let latText = row[latitudeIndex]
            let lonText = row[longitudeIndex]
            guard let latitude = Double(latText), let longitude = Double(lonText) else {
                throw CSVError.invalidCoordinate(detail: "row \(line): invalid latitude/longitude")
            }
            var altitude: Double?
            if let altitudeIndex = mapping.altitudeIndex,
               altitudeIndex < row.count,
               let value = Double(row[altitudeIndex])
            {
                altitude = value
            }
            geometry = Point(Coordinate3D(
                latitude: latitude,
                longitude: longitude,
                altitude: altitude))
        }

        guard let geometry else {
            throw CSVError.missingGeometry(line: line)
        }

        // Build the feature.
        var feature = Feature(geometry)

        if let idIndex = mapping.idIndex, idIndex < row.count, !row[idIndex].isEmpty {
            feature.id = identifier(from: row[idIndex])
        }

        // Remaining columns become properties.
        for (index, header) in mapping.headers.enumerated() {
            guard index < row.count else { continue }
            switch mapping.roles[index] {
            case .geometry, .latitude, .longitude, .altitude, .id:
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
        options: CSVWriteOptions
    ) -> [[String]] {
        let features = featureCollection.features

        // An explicit geometry format always uses the geometry column. Only
        // `.auto` keeps the all-points lat/lon/altitude layout.
        if options.geometryFormat == .auto,
           features.allSatisfy({ $0.geometry is Point })
        {
            return pointRows(features, options: options)
        }
        return mixedRows(features, options: options)
    }

    /// Rows when every feature is a simple point.
    ///
    /// Column order: `id`, `longitude`, `latitude`, `altitude`, then the
    /// remaining property columns.
    private static func pointRows(
        _ features: [Feature],
        options: CSVWriteOptions
    ) -> [[String]] {
        let propertyColumns = orderedPropertyColumns(features, excluding: ["longitude", "latitude", "altitude"])
        let header = ["id", "longitude", "latitude", "altitude"] + propertyColumns

        var rows: [[String]] = options.includeHeader ? [header] : []
        for feature in features {
            let point = feature.geometry as! Point
            let coordinate = point.coordinate

            var row: [String] = []
            row.append(idValue(feature.id))
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

    /// Rows when at least one feature has a complex (non-Point) geometry, or
    /// when an explicit geometry format is requested.
    ///
    /// Column order: `id`, property columns, then the geometry column last.
    private static func mixedRows(
        _ features: [Feature],
        options: CSVWriteOptions
    ) -> [[String]] {
        let propertyColumns = orderedPropertyColumns(features, excluding: [options.geometryColumnName])

        // Point features still emit their lat/lon/altitude as properties so no
        // data is lost; complex features emit their geometry in the geometry column.
        let header = ["id"] + propertyColumns + [options.geometryColumnName]
        var rows: [[String]] = options.includeHeader ? [header] : []
        for feature in features {
            var row: [String] = [idValue(feature.id)]
            for column in propertyColumns {
                row.append(value(for: column, in: feature, nullValue: options.nullValue))
            }
            row.append(geometryValue(feature.geometry, format: options.geometryFormat))
            rows.append(row)
        }
        return rows
    }

    /// Encodes a geometry for the geometry column in the requested format.
    private static func geometryValue(
        _ geometry: GeoJsonGeometry,
        format: CSVGeometryFormat
    ) -> String {
        switch format {
        case .auto, .wkt:
            return geometry.asWKT ?? ""
        case .ewkb:
            guard let data = WKBCoder.encode(geometry: geometry) else { return "" }
            return data.hexEncodedString()
        case .geojson:
            return geometry.asJsonString() ?? ""
        }
    }

    // MARK: - Property columns

    /// Computes the ordered, deduplicated property column names across all
    /// features, excluding any reserved names.
    private static func orderedPropertyColumns(
        _ features: [Feature],
        excluding reserved: Set<String>
    ) -> [String] {
        let reservedLower = Set(reserved.map { $0.lowercased() })
        var columns: [String] = []
        var seen = Set<String>()

        for feature in features {
            for key in feature.properties.keys {
                let lower = key.lowercased()
                if reservedLower.contains(lower) || seen.contains(lower) { continue }
                seen.insert(lower)
                columns.append(key)
            }
        }
        return columns
    }

    private static func value(
        for column: String,
        in feature: Feature,
        nullValue: String
    ) -> String {
        guard let value = feature.properties[column] else { return nullValue }
        if let number = value as? Double { return formatNumber(number) }
        if let number = value as? Int { return "\(number)" }
        if let boolean = value as? Bool { return boolean ? "true" : "false" }
        return "\(value)"
    }

    // MARK: - Helpers

    /// Builds a ``Feature.Identifier`` from a string, preferring numeric ids.
    private static func identifier(from text: String) -> Feature.Identifier {
        if let int = Int64(text) {
            return .int(Int(int))
        }
        if let uint = UInt64(text) {
            return .uint(UInt(uint))
        }
        if let double = Double(text) {
            return .double(double)
        }
        return .string(text)
    }

    private static func idValue(_ id: Feature.Identifier?) -> String {
        switch id {
        case .string(let value):
            return value
        case .int(let value):
            return "\(value)"
        case .uint(let value):
            return "\(value)"
        case .double(let value):
            return formatNumber(value)
        case .none:
            return ""
        }
    }

    /// Parses a raw CSV field into a loosely-typed value.
    ///
    /// Booleans, integers, and floating-point numbers are detected; anything
    /// else is kept as a string.
    private static func parseValue(_ text: String) -> Sendable {
        switch text.lowercased() {
        case "true": return true
        case "false": return false
        default:
            if let int = Int(text) { return int }
            if let double = Double(text) { return double }
            return text
        }
    }

    private static func formatNumber(_ value: Double) -> String {
        String(format: "%.9g", value)
    }

}

// MARK: - Data hex encoding

extension Data {

    /// The receiver as an uppercase hex string.
    fileprivate func hexEncodedString() -> String {
        map { String(format: "%02X", $0) }.joined()
    }

}
