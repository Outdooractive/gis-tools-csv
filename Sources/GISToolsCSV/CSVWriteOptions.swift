import Foundation
import GISTools

// MARK: - Geometry format

/// How geometry is written to the CSV geometry column.
public enum CSVGeometryFormat: Sendable, Equatable, Hashable {

    /// The default behavior: all-points collections in EPSG:4326 use
    /// `longitude`/`latitude`/`altitude` columns, otherwise a WKT geometry
    /// column is emitted.
    case auto

    /// Always emit a geometry column containing WKT (SRID-prefixed).
    case wkt

    /// Always emit a geometry column containing hex-encoded EWKB.
    case ewkb

    /// Always emit a geometry column containing a GeoJSON string.
    case geojson

}

// MARK: - Coordinate columns

/// The column names used for the point-coordinate layout.
public enum CSVCoordinateColumns: Sendable, Equatable, Hashable {

    /// `longitude`/`latitude`/`altitude` for EPSG:4326, otherwise `x`/`y`/`z`.
    case automatic

    /// Always use `longitude`/`latitude`/`altitude`.
    case longitudeLatitude

    /// Always use `x`/`y`/`z`.
    case xy

}

// MARK: - Line ending

/// The line ending used when writing CSV.
public enum CSVLineEnding: Sendable, Equatable, Hashable {

    /// `\n` (Unix/macOS).
    case lf

    /// `\r\n` (Windows).
    case crlf

    /// The raw line ending string.
    public var rawValue: String {
        switch self {
        case .lf: "\n"
        case .crlf: "\r\n"
        }
    }

}

// MARK: - Write options

/// Options that control how a `FeatureCollection` is written to CSV.
public struct CSVWriteOptions: Sendable, Equatable, Hashable {

    /// The field delimiter (default `","`).
    public var delimiter: Character

    /// The projection to write coordinates in. When `nil`, the feature
    /// collection's projection is used.
    public var projection: Projection?

    /// The point-coordinate column names (default `.automatic`).
    public var coordinateColumns: CSVCoordinateColumns

    /// An optional CRS column name (`projection`, `crs`, or `srid`).
    ///
    /// When set, every row receives a CRS value for the output projection.
    /// A `nil` value writes no CRS column.
    public var projectionColumnName: String?

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
    ///   - projection: The output projection, or `nil` for the collection projection.
    ///   - coordinateColumns: The point-coordinate column names (default `.automatic`).
    ///   - projectionColumnName: An optional CRS column name (`projection`, `crs`, or `srid`).
    ///   - geometryFormat: How geometry is written (default `.auto`).
    ///   - geometryColumnName: The name of the geometry column (default `"geometry"`).
    ///   - includeHeader: Whether to write the header row (default `true`).
    ///   - nullValue: The value written for `nil` properties (default `""`).
    ///   - lineEnding: The line ending used between rows (default `.lf`).
    public init(
        delimiter: Character = CSVCoder.defaultDelimiter,
        projection: Projection? = nil,
        coordinateColumns: CSVCoordinateColumns = .automatic,
        projectionColumnName: String? = nil,
        geometryFormat: CSVGeometryFormat = .auto,
        geometryColumnName: String = "geometry",
        includeHeader: Bool = true,
        nullValue: String = "",
        lineEnding: CSVLineEnding = .lf,
    ) {
        self.delimiter = delimiter
        self.projection = projection
        self.coordinateColumns = coordinateColumns
        self.projectionColumnName = projectionColumnName
        self.geometryFormat = geometryFormat
        self.geometryColumnName = geometryColumnName
        self.includeHeader = includeHeader
        self.nullValue = nullValue
        self.lineEnding = lineEnding
    }

}
