import Foundation

// MARK: - CSV Reader

/// Parses CSV data into rows of strings.
///
/// Implements RFC 4180-style quoting: fields may be enclosed in double
/// quotes, may contain the delimiter, quotes (escaped as `""`), and
/// newlines. Both `\n` and `\r\n` line endings are supported.
///
/// The parser iterates over Unicode scalars (rather than grapheme clusters)
/// so that the `\r\n` sequence is seen as two distinct characters.
enum CSVReader {

    /// Parses CSV data into an array of rows. The delimiter is configurable.
    ///
    /// - Parameters:
    ///   - data: The CSV data.
    ///   - delimiter: The field delimiter (default `","`).
    /// - Returns: The parsed rows.
    /// - Throws: ``CSVError`` if the data cannot be decoded as UTF-8.
    static func parse(data: Data, delimiter: Character) throws -> [[String]] {
        guard let string = String(data: data, encoding: .utf8) else {
            throw CSVError.invalidEncoding
        }
        return parse(string: string, delimiter: delimiter)
    }

    /// Parses a CSV string into an array of rows.
    ///
    /// - Parameters:
    ///   - string: The CSV string.
    ///   - delimiter: The field delimiter (default `","`).
    /// - Returns: The parsed rows.
    static func parse(string: String, delimiter: Character) -> [[String]] {
        let delimiters: [UnicodeScalar] = delimiter.unicodeScalars.map { $0 }
        let delimitersSet = Set(delimiters)
        let scalars = Array(string.unicodeScalars)

        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false
        var index = 0

        func endRow() {
            row.append(field)
            rows.append(row)
            row = []
            field = ""
        }

        while index < scalars.count {
            let scalar = scalars[index]

            if inQuotes {
                if scalar == "\"" {
                    let next = index + 1
                    if next < scalars.count && scalars[next] == "\"" {
                        field.append("\"")
                        index = next
                    }
                    else {
                        inQuotes = false
                    }
                }
                else {
                    field.unicodeScalars.append(scalar)
                }
            }
            else {
                if scalar == "\"" {
                    inQuotes = true
                }
                else if delimitersSet.contains(scalar) {
                    row.append(field)
                    field = ""
                }
                else if scalar == "\n" {
                    endRow()
                }
                else if scalar == "\r" {
                    let next = index + 1
                    if next < scalars.count && scalars[next] == "\n" {
                        index = next
                    }
                    endRow()
                }
                else {
                    field.unicodeScalars.append(scalar)
                }
            }

            index += 1
        }

        if !field.isEmpty || !row.isEmpty {
            endRow()
        }

        return rows
    }

}

// MARK: - CSV Writer

/// Serializes rows of strings to CSV data.
enum CSVWriter {

    /// Serializes rows to a CSV string.
    ///
    /// - Parameters:
    ///   - rows: The rows to serialize.
    ///   - delimiter: The field delimiter (default `","`).
    /// - Returns: The CSV string.
    static func write(_ rows: [[String]], delimiter: Character) -> String {
        rows.map { row in
            row.map { escape($0, delimiter: delimiter) }.joined(separator: String(delimiter))
        }
        .joined(separator: "\n")
        + "\n"
    }

    /// Quotes a field if necessary and escapes embedded quotes.
    private static func escape(_ field: String, delimiter: Character) -> String {
        let mustQuote = field.contains(delimiter)
            || field.contains("\"")
            || field.contains("\n")
            || field.contains("\r")
        if mustQuote {
            let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return field
    }

}
