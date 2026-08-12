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

    /// The CSV has no header row. A header is required — the geometry is
    /// never guessed.
    case missingHeader

    /// A row did not provide a geometry (via a `geometry`/`geom` column or
    /// a latitude/longitude pair).
    case missingGeometry(line: Int)

    /// The latitude or longitude value is out of range.
    /// - Parameter detail: A description.
    case invalidCoordinate(detail: String)

    /// A `geometry`/`geom` column could not be parsed as WKT.
    /// - Parameter detail: The underlying WKT error.
    case invalidWKT(detail: String)

    /// A human-readable description of the error.
    public var errorDescription: String? {
        switch self {
        case .fileReadError(let detail):
            "Could not read CSV file: \(detail)"
        case .fileWriteError(let detail):
            "Could not write CSV file: \(detail)"
        case .invalidEncoding:
            "Invalid encoding"
        case .missingHeader:
            "The CSV has no header row. A header row is required."
        case .missingGeometry(let line):
            "CSV row \(line) has no geometry (no geometry/geom column and no latitude/longitude pair)."
        case .invalidCoordinate(let detail):
            "Invalid coordinate: \(detail)"
        case .invalidWKT(let detail):
            "Invalid WKT geometry: \(detail)"
        }
    }

}
