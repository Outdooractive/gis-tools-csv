import Foundation
import GISTools

// MARK: - FeatureCollection CSV convenience methods

extension FeatureCollection {

    /// Creates a ``FeatureCollection`` from a CSV file.
    ///
    /// - Parameters:
    ///   - csv: The URL of the CSV file.
    ///   - options: The read options (default ``CSVReadOptions``).
    public init?(csv url: URL, options: CSVReadOptions = CSVReadOptions()) {
        guard let fc = try? CSVCoder.read(from: url, options: options) else { return nil }
        self = fc
    }

    /// Creates a ``FeatureCollection`` from CSV data.
    ///
    /// - Parameters:
    ///   - csvData: The raw CSV data.
    ///   - options: The read options (default ``CSVReadOptions``).
    public init?(csvData: Data, options: CSVReadOptions = CSVReadOptions()) {
        guard let fc = try? CSVCoder.read(from: csvData, options: options) else { return nil }
        self = fc
    }

    /// Returns the receiver serialised as CSV data.
    ///
    /// - Parameter options: The write options (default ``CSVWriteOptions``).
    /// - Returns: The CSV data.
    /// - Throws: ``CSVError`` if serialization fails.
    public func csvData(options: CSVWriteOptions = CSVWriteOptions()) throws -> Data {
        try CSVCoder.write(self, options: options)
    }

    /// Writes the receiver as a CSV file.
    ///
    /// - Parameters:
    ///   - url: The output URL (must include `.csv` extension).
    ///   - options: The write options (default ``CSVWriteOptions``).
    public func writeCSV(
        to url: URL,
        options: CSVWriteOptions = CSVWriteOptions()
    ) throws {
        let data = try csvData(options: options)
        try data.write(to: url)
    }

}
