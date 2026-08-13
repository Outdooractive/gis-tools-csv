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
    ///   - delimiter: The field delimiter (default `","`).
    /// - Returns: A ``FeatureCollection`` with the CSV data.
    /// - Throws: ``CSVError`` if the file cannot be read or parsed.
    public static func read(
        from url: URL,
        delimiter: Character = defaultDelimiter
    ) throws -> FeatureCollection {
        do {
            let data = try Data(contentsOf: url)
            return try read(from: data, delimiter: delimiter)
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
    ///   - delimiter: The field delimiter (default `","`).
    /// - Returns: A ``FeatureCollection`` with the CSV data.
    /// - Throws: ``CSVError`` if the data cannot be parsed.
    public static func read(
        from data: Data,
        delimiter: Character = defaultDelimiter
    ) throws -> FeatureCollection {
        let rows = try CSVReader.parse(data: data, delimiter: delimiter)
        return try convertToFeatureCollection(rows: rows)
    }

    // MARK: - Write

    /// Serializes a ``FeatureCollection`` to CSV data.
    ///
    /// - Parameters:
    ///   - featureCollection: The FeatureCollection to serialize.
    ///   - delimiter: The field delimiter (default `","`).
    /// - Returns: The CSV data.
    /// - Throws: ``CSVError`` if serialization fails.
    public static func write(
        _ featureCollection: FeatureCollection,
        delimiter: Character = defaultDelimiter
    ) throws -> Data {
        let rows = rows(from: featureCollection)
        let string = CSVWriter.write(rows, delimiter: delimiter)
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
    ///   - delimiter: The field delimiter (default `","`).
    /// - Throws: ``CSVError`` if the file cannot be written.
    public static func write(
        _ featureCollection: FeatureCollection,
        to url: URL,
        delimiter: Character = defaultDelimiter
    ) throws {
        let data = try write(featureCollection, delimiter: delimiter)
        do {
            try data.write(to: url)
        }
        catch {
            throw CSVError.fileWriteError(detail: error.localizedDescription)
        }
    }

    // MARK: - Convert rows → FeatureCollection

    private static func convertToFeatureCollection(
        rows: [[String]]
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
                try feature(from: row, mapping: mapping, line: lineIndex + 2))
        }

        return FeatureCollection(features)
    }

    private static func feature(
        from row: [String],
        mapping: CSVColumnMapping,
        line: Int
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
                properties[header] = parseValue(row[index])
            }
        }

        feature.properties = properties
        return feature
    }

    // MARK: - Convert FeatureCollection → rows

    private static func rows(from featureCollection: FeatureCollection) -> [[String]] {
        let features = featureCollection.features

        if features.allSatisfy({ $0.geometry is Point }) {
            return pointRows(features)
        }
        return mixedRows(features)
    }

    /// Rows when every feature is a simple point.
    ///
    /// Column order: `id`, `longitude`, `latitude`, `altitude`, then the
    /// remaining property columns.
    private static func pointRows(_ features: [Feature]) -> [[String]] {
        let propertyColumns = orderedPropertyColumns(features, excluding: ["longitude", "latitude", "altitude"])
        let header = ["id", "longitude", "latitude", "altitude"] + propertyColumns

        var rows: [[String]] = [header]
        for feature in features {
            let point = feature.geometry as! Point
            let coordinate = point.coordinate

            var row: [String] = []
            row.append(idValue(feature.id))
            row.append(formatNumber(coordinate.longitude))
            row.append(formatNumber(coordinate.latitude))
            row.append(coordinate.altitude.map(formatNumber) ?? "")
            for column in propertyColumns {
                row.append(value(for: column, in: feature))
            }
            rows.append(row)
        }
        return rows
    }

    /// Rows when at least one feature has a complex (non-Point) geometry.
    ///
    /// Column order: `id`, property columns, then `geometry` last.
    private static func mixedRows(_ features: [Feature]) -> [[String]] {
        let propertyColumns = orderedPropertyColumns(features, excluding: ["geometry"])

        // Point features still emit their lat/lon/altitude as properties so no
        // data is lost; complex features emit their WKT in the geometry column.
        var rows: [[String]] = [["id"] + propertyColumns + ["geometry"]]
        for feature in features {
            var row: [String] = [idValue(feature.id)]
            for column in propertyColumns {
                row.append(value(for: column, in: feature))
            }
            row.append(feature.geometry.asWKT ?? "")
            rows.append(row)
        }
        return rows
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

    private static func value(for column: String, in feature: Feature) -> String {
        guard let value = feature.properties[column] else { return "" }
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
