import Foundation

// MARK: - CSV Reader

/// Parses CSV data into rows of strings.
///
/// Implements RFC 4180-style quoting: fields may be enclosed in double
/// quotes, may contain the delimiter, quotes (escaped as `""`), and
/// newlines. Both `\n` and `\r\n` line endings are supported, as well as
/// lone `\r` line endings. A UTF-8 byte order mark at the start of the data
/// is ignored.
///
/// The parser is deliberately lenient in two places:
/// - A double quote that does not start a field is kept as a literal
///   character instead of being dropped.
/// - Characters following a closing quote are appended to the field.
///
/// An unterminated quoted field is an error, because silently swallowing the
/// rest of the file would corrupt the data.
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
    /// - Throws: ``CSVError`` if the data cannot be decoded as UTF-8 or
    ///   contains an unterminated quoted field.
    static func parse(data: Data, delimiter: Character) throws -> [[String]] {
        guard let string = String(data: data, encoding: .utf8) else {
            throw CSVError.invalidEncoding
        }

        return try parse(string: string, delimiter: delimiter)
    }

    /// Parses a CSV string into an array of rows.
    ///
    /// - Parameters:
    ///   - string: The CSV string.
    ///   - delimiter: The field delimiter (default `","`).
    /// - Returns: The parsed rows.
    /// - Throws: ``CSVError`` if the string contains an unterminated quoted
    ///   field.
    static func parse(string: String, delimiter: Character) throws -> [[String]] {
        let text = string.hasPrefix("\u{FEFF}") ? String(string.dropFirst()) : string
        let delimiterScalars = Array(delimiter.unicodeScalars)
        let scalars = Array(text.unicodeScalars)

        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false
        var rowStarted = false
        var index = 0

        func endRow() {
            row.append(field)
            rows.append(row)
            row = []
            field = ""
            rowStarted = false
        }

        while index < scalars.count {
            let scalar = scalars[index]

            if inQuotes {
                rowStarted = true
                if scalar == "\"" {
                    let next = index + 1
                    if next < scalars.count, scalars[next] == "\"" {
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
                index += 1
                continue
            }

            // A delimiter may consist of more than one Unicode scalar when a
            // grapheme cluster is used as the delimiter.
            if delimiterScalars.isNotEmpty,
               index + delimiterScalars.count <= scalars.count,
               Array(scalars[index ..< (index + delimiterScalars.count)]) == delimiterScalars
            {
                row.append(field)
                field = ""
                rowStarted = true
                index += delimiterScalars.count
                continue
            }

            switch scalar {
            case "\"":
                // Only a quote at the start of a field opens a quoted field.
                // Any other quote is data and must not be dropped.
                if field.isEmpty {
                    inQuotes = true
                }
                else {
                    field.append("\"")
                }
                rowStarted = true

            case "\n":
                endRow()

            case "\r":
                let next = index + 1
                if next < scalars.count, scalars[next] == "\n" {
                    index = next
                }
                endRow()

            default:
                field.unicodeScalars.append(scalar)
                rowStarted = true
            }

            index += 1
        }

        if inQuotes {
            throw CSVError.malformedCSV(
                detail: "row \(rows.count + 1): unterminated quoted field")
        }

        // Only append a final row if it has content. A trailing line ending
        // must not produce an extra empty record.
        if rowStarted {
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
    ///   - lineEnding: The line ending used between rows (default `.lf`).
    /// - Returns: The CSV string, or an empty string when `rows` is empty.
    static func write(
        _ rows: [[String]],
        delimiter: Character,
        lineEnding: CSVLineEnding = .lf,
    ) -> String {
        guard rows.isNotEmpty else { return "" }

        return rows.lazy
            .map { row in
                row.lazy.map { escape($0, delimiter: delimiter) }.joined(separator: String(delimiter))
            }
            .joined(separator: lineEnding.rawValue)
            + lineEnding.rawValue
    }

    /// Quotes a field if necessary and escapes embedded quotes.
    private static func escape(_ field: String, delimiter: Character) -> String {
        let scalars = field.unicodeScalars
        let mustQuote = field.contains(delimiter)
            || scalars.contains("\"")
            || scalars.contains("\n")
            || scalars.contains("\r")
        if mustQuote {
            let escaped = field.replacing("\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return field
    }

}
