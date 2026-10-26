import Foundation

/// Errors thrown by CSV reading, writing, and validation.
public enum CSVError: LocalizedError, Equatable {

    /// The file could not be read.
    /// - Parameter detail: The underlying error description.
    case fileReadError(detail: String)

    /// The file could not be written.
    /// - Parameter detail: The underlying error description.
    case fileWriteError(detail: String)

    /// A string could not be created, likely due to an encoding issue.
    case invalidEncoding

    /// The CSV is malformed, for example because a quoted field is not
    /// terminated.
    /// - Parameter detail: A description of the problem.
    case malformedCSV(detail: String)

    /// The CSV has no header row. A header is required — the geometry is
    /// never guessed.
    case missingHeader

    /// The header row has no geometry-bearing column: neither a
    /// `geometry`/`geom` column nor a latitude/longitude pair.
    case missingGeometryColumns

    /// A row did not provide a geometry (via a `geometry`/`geom` column or
    /// a latitude/longitude pair).
    case missingGeometry(line: Int)

    /// A latitude, longitude, or altitude value is not a finite number or
    /// is outside the valid EPSG:4326 range.
    /// - Parameter detail: A description.
    case invalidCoordinate(detail: String)

    /// A `geometry`/`geom` column could not be parsed as a geometry, or a
    /// geometry could not be encoded for writing.
    /// - Parameter detail: The underlying geometry error.
    case invalidGeometry(detail: String)

    /// The configured geometry column name is empty or collides with a
    /// coordinate or id column name.
    /// - Parameter name: The invalid column name.
    case invalidGeometryColumnName(name: String)

    /// A human-readable description of the error.
    public var errorDescription: String? {
        switch self {
        case let .fileReadError(detail):
            "Could not read CSV file: \(detail)"
        case let .fileWriteError(detail):
            "Could not write CSV file: \(detail)"
        case .invalidEncoding:
            "Invalid encoding"
        case let .malformedCSV(detail):
            "Malformed CSV: \(detail)"
        case .missingHeader:
            "The CSV has no header row. A header row is required."
        case .missingGeometryColumns:
            "The CSV header has no geometry column and no latitude/longitude pair."
        case let .missingGeometry(line):
            "CSV row \(line) has no geometry (no geometry/geom column and no latitude/longitude pair)."
        case let .invalidCoordinate(detail):
            "Invalid coordinate: \(detail)"
        case let .invalidGeometry(detail):
            "Invalid geometry: \(detail)"
        case let .invalidGeometryColumnName(name):
            "Invalid geometry column name '\(name)'. It must not be empty or collide with a coordinate or id column."
        }
    }

}
