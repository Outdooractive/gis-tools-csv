import Foundation

// MARK: - Geometry format

/// How geometry is written to the CSV geometry column.
public enum CSVGeometryFormat: Sendable {

    /// The default behavior: all-points collections use `longitude`/`latitude`/
    /// `altitude` columns, otherwise a WKT geometry column is emitted.
    case auto

    /// Always emit a geometry column containing WKT (SRID-prefixed).
    case wkt

    /// Always emit a geometry column containing hex-encoded EWKB.
    case ewkb

    /// Always emit a geometry column containing a GeoJSON string.
    case geojson

}

// MARK: - Line ending

/// The line ending used when writing CSV.
public enum CSVLineEnding: Sendable {

    /// `\n` (Unix/macOS).
    case lf

    /// `\r\n` (Windows).
    case crlf

    /// The raw line ending string.
    public var rawValue: String {
        switch self {
        case .lf: return "\n"
        case .crlf: return "\r\n"
        }
    }

}

// MARK: - Write options

/// Options that control how a ``FeatureCollection`` is written to CSV.
public struct CSVWriteOptions: Sendable {

    /// The field delimiter (default `","`).
    public var delimiter: Character

    /// How geometry is written (default `.auto`).
    public var geometryFormat: CSVGeometryFormat

    /// The name of the geometry column (default `"geometry"`).
    public var geometryColumnName: String

    /// Whether to write the header row (default `true`).
    public var includeHeader: Bool

    /// The value written for `nil` properties (default `""`).
    public var nullValue: String

    /// The line ending used between rows (default `.lf`).
    public var lineEnding: CSVLineEnding

    /// Creates write options.
    ///
    /// - Parameters:
    ///   - delimiter: The field delimiter (default `","`).
    ///   - geometryFormat: How geometry is written (default `.auto`).
    ///   - geometryColumnName: The name of the geometry column (default `"geometry"`).
    ///   - includeHeader: Whether to write the header row (default `true`).
    ///   - nullValue: The value written for `nil` properties (default `""`).
    ///   - lineEnding: The line ending used between rows (default `.lf`).
    public init(
        delimiter: Character = CSVCoder.defaultDelimiter,
        geometryFormat: CSVGeometryFormat = .auto,
        geometryColumnName: String = "geometry",
        includeHeader: Bool = true,
        nullValue: String = "",
        lineEnding: CSVLineEnding = .lf
    ) {
        self.delimiter = delimiter
        self.geometryFormat = geometryFormat
        self.geometryColumnName = geometryColumnName
        self.includeHeader = includeHeader
        self.nullValue = nullValue
        self.lineEnding = lineEnding
    }

}
