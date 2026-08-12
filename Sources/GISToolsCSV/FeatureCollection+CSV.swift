import Foundation
import GISTools

// MARK: - FeatureCollection CSV convenience methods

extension FeatureCollection {

    /// Creates a ``FeatureCollection`` from a CSV file.
    ///
    /// - Parameters:
    ///   - csv: The URL of the CSV file.
    ///   - delimiter: The field delimiter (default `","`).
    public init?(csv url: URL, delimiter: Character = CSVCoder.defaultDelimiter) {
        guard let fc = try? CSVCoder.read(from: url, delimiter: delimiter) else { return nil }
        self = fc
    }

    /// Creates a ``FeatureCollection`` from CSV data.
    ///
    /// - Parameters:
    ///   - csvData: The raw CSV data.
    ///   - delimiter: The field delimiter (default `","`).
    public init?(csvData: Data, delimiter: Character = CSVCoder.defaultDelimiter) {
        guard let fc = try? CSVCoder.read(from: csvData, delimiter: delimiter) else { return nil }
        self = fc
    }

    /// Returns the receiver serialised as CSV data.
    ///
    /// - Parameter delimiter: The field delimiter (default `","`).
    /// - Returns: The CSV data.
    /// - Throws: ``CSVError`` if serialization fails.
    public func csvData(delimiter: Character = CSVCoder.defaultDelimiter) throws -> Data {
        try CSVCoder.write(self, delimiter: delimiter)
    }

    /// Writes the receiver as a CSV file.
    ///
    /// - Parameters:
    ///   - url: The output URL (must include `.csv` extension).
    ///   - delimiter: The field delimiter (default `","`).
    public func writeCSV(
        to url: URL,
        delimiter: Character = CSVCoder.defaultDelimiter
    ) throws {
        let data = try csvData(delimiter: delimiter)
        try data.write(to: url)
    }

}
