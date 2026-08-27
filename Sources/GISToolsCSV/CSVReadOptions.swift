import Foundation

// MARK: - Null handling

/// How `NULL` (and empty) values in a CSV are treated when building
/// ``Feature`` properties.
public enum CSVNullHandling: Sendable {

    /// Keep the raw value as a string (e.g. `"NULL"` stays a `String`).
    case keepAsString

    /// Omit the property entirely for `NULL` and empty values.
    case omit

}

// MARK: - Read options

/// Options that control how a CSV is read into a ``FeatureCollection``.
public struct CSVReadOptions: Sendable {

    /// The field delimiter (default `","`).
    public var delimiter: Character

    /// How `NULL` and empty values are handled (default `.keepAsString`).
    public var nullHandling: CSVNullHandling

    /// When enabled, the coordinates of all rows are concatenated (in row
    /// order) into a single `LineString` feature (default `false`).
    ///
    /// Works for rows providing `latitude`/`longitude` columns (optionally
    /// with `altitude`) as well as for a `geometry`/`geom` column containing
    /// `POINT`, `MULTIPOINT`, `LINESTRING`, or `MULTILINESTRING` geometries
    /// (their coordinates are flattened in order). Any other geometry type
    /// is an error, and the result must contain at least 2 coordinates.
    /// Row properties and ids are dropped.
    public var treatAsLineString: Bool

    /// Creates read options.
    ///
    /// - Parameters:
    ///   - delimiter: The field delimiter (default `","`).
    ///   - nullHandling: How `NULL` and empty values are handled (default `.keepAsString`).
    ///   - treatAsLineString: Concatenate all coordinates into a single `LineString` (default `false`).
    public init(
        delimiter: Character = CSVCoder.defaultDelimiter,
        nullHandling: CSVNullHandling = .keepAsString,
        treatAsLineString: Bool = false
    ) {
        self.delimiter = delimiter
        self.nullHandling = nullHandling
        self.treatAsLineString = treatAsLineString
    }

}
