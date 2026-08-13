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

    /// Creates read options.
    ///
    /// - Parameters:
    ///   - delimiter: The field delimiter (default `","`).
    ///   - nullHandling: How `NULL` and empty values are handled (default `.keepAsString`).
    public init(
        delimiter: Character = CSVCoder.defaultDelimiter,
        nullHandling: CSVNullHandling = .keepAsString
    ) {
        self.delimiter = delimiter
        self.nullHandling = nullHandling
    }

}
