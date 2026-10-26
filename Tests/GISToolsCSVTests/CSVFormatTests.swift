import Foundation
import GISTools
@testable import GISToolsCSV
import Testing

struct CSVFormatTests {

    private var dataURL: URL {
        Bundle.module.resourceURL!.appendingPathComponent("TestData")
    }

    // MARK: - Delimiters

    @Test
    func readSemicolonFile() throws {
        let fc = try CSVCoder.read(
            from: dataURL.appendingPathComponent("points_semicolon.csv"),
            options: CSVReadOptions(delimiter: ";"))
        #expect(fc.features.count == 3)
        let first = try #require(fc.features.first)
        let point = try #require(first.geometry as? Point)
        #expect(abs(point.coordinate.longitude - 11.518585) < 0.0000000001)
        #expect(first.properties["name"] as? String == "Marienplatz")
    }

    @Test
    func readTabFile() throws {
        let fc = try CSVCoder.read(
            from: dataURL.appendingPathComponent("points_tab.csv"),
            options: CSVReadOptions(delimiter: "\t"))
        #expect(fc.features.count == 3)
        #expect(fc.features[1].properties["name"] as? String == "Reichstag")
        let point = try #require(fc.features[2].geometry as? Point)
        #expect(point.coordinate.altitude == 1420.0)
    }

    @Test
    func readPipeFile() throws {
        let fc = try CSVCoder.read(
            from: dataURL.appendingPathComponent("points_pipe.csv"),
            options: CSVReadOptions(delimiter: "|"))
        #expect(fc.features.count == 2)
        #expect(fc.features[0].id == .int(1))
        #expect(fc.features[1].properties["name"] as? String == "Reichstag")
    }

    @Test
    func readSemicolonQuoted() throws {
        let fc = try CSVCoder.read(
            from: dataURL.appendingPathComponent("points_semicolon_quoted.csv"),
            options: CSVReadOptions(delimiter: ";"))
        #expect(fc.features.count == 2)
        // Quoted field keeps its delimiter.
        #expect(fc.features[0].properties["name"] as? String == "Munich, Bavaria; note")
    }

    @Test
    func readSemicolonFileWithTrailingNewline() throws {
        let fc = try CSVCoder.read(
            from: dataURL.appendingPathComponent("empty_trailing_newline.csv"),
            options: CSVReadOptions(delimiter: ";"))
        #expect(fc.features.count == 1)
        #expect(fc.features[0].properties["name"] as? String == "Munich, Bavaria")
    }

    // MARK: - Quoting edge cases

    @Test
    func readEscapedQuotes() throws {
        let fc = try CSVCoder.read(
            from: dataURL.appendingPathComponent("quoted_edge_cases.csv"))
        #expect(fc.features.count == 3)
        #expect(
            fc.features[0].properties["name"] as? String ==
                "escaped \"quote\" inside",
        )
    }

    @Test
    func readTrailingSpacesPreserved() throws {
        let fc = try CSVCoder.read(
            from: dataURL.appendingPathComponent("quoted_edge_cases.csv"))
        // Whitespace inside quotes is preserved.
        #expect(
            fc.features[1].properties["name"] as? String ==
                "trailing spaces   ",
        )
    }

    @Test
    func readNewlineInQuotedField() throws {
        let fc = try CSVCoder.read(
            from: dataURL.appendingPathComponent("quoted_edge_cases.csv"))
        // The "line\nbreak" field swallows the newline but stays one record.
        #expect(fc.features.count == 3)
        #expect(fc.features[2].properties["name"] as? String == "line\nbreak")
    }

    @Test
    func readQuoteInsideUnquotedFieldIsData() throws {
        let data = Data("""
        latitude,longitude,name
        48.1,11.5,a"b
        """.utf8)
        let fc = try CSVCoder.read(from: data)
        #expect(fc.features[0].properties["name"] as? String == "a\"b")
    }

    @Test
    func readEmptyQuotedValue() throws {
        let data = Data("""
        latitude,longitude,name
        48.1,11.5,""
        """.utf8)
        let fc = try CSVCoder.read(from: data)
        #expect(fc.features[0].properties["name"] as? String == "")
    }

    // MARK: - Blank lines & ragged rows

    @Test
    func readBlankLinesIgnored() throws {
        let fc = try CSVCoder.read(
            from: dataURL.appendingPathComponent("blank_lines.csv"))
        #expect(fc.features.count == 3)
        #expect(fc.features[0].id == .int(1))
        #expect(fc.features[2].properties["name"] as? String == "Alpine Lodge")
    }

    @Test
    func readMissingColumns() throws {
        // Row 2 has an extra column, row 3 is missing name — should not throw.
        let fc = try CSVCoder.read(
            from: dataURL.appendingPathComponent("ragged_rows.csv"))
        #expect(fc.features.count == 3)
        // Extra column is simply ignored.
        #expect(fc.features[1].id == .int(2))
        // Missing name column -> no property set.
        #expect(fc.features[2].properties["name"] == nil)
    }

    @Test
    func readRowWithOnlyEmptyValuesIsAnError() {
        // A line containing delimiters is a record, not a blank line. It has
        // no geometry, so it must not be skipped silently.
        let data = Data("""
        id,latitude,longitude
        1,48.1,11.5
        ,,
        2,48.2,11.6
        """.utf8)
        #expect(throws: CSVError.invalidCoordinate(detail: "row 3: invalid latitude")) {
            _ = try CSVCoder.read(from: data)
        }
    }

    @Test
    func readTrulyBlankLinesAreSkipped() throws {
        let data = Data("""
        id,latitude,longitude
        1,48.1,11.5


        2,48.2,11.6
        """.utf8)
        let fc = try CSVCoder.read(from: data)
        #expect(fc.features.count == 2)
        #expect(fc.features[1].id == .int(2))
    }

    // MARK: - Line endings

    @Test
    func readCRLFLineEndings() throws {
        let fc = try CSVCoder.read(
            from: dataURL.appendingPathComponent("crlf_line_endings.csv"))
        #expect(fc.features.count == 2)
        #expect(fc.features[0].id == .int(1))
        #expect(fc.features[1].properties["name"] as? String == "Reichstag")
    }

    @Test
    func readCROnlyLineEndings() throws {
        let data = Data("id,latitude,longitude\r1,48.1,11.5\r2,48.2,11.6\r".utf8)
        let fc = try CSVCoder.read(from: data)
        #expect(fc.features.count == 2)
    }

    @Test
    func readMissingTrailingNewline() throws {
        let fc = try CSVCoder.read(
            from: dataURL.appendingPathComponent("missing_trailing_newline.csv"))
        #expect(fc.features.count == 2)
        #expect(fc.features[1].properties["name"] as? String == "Reichstag")
    }

    // MARK: - Broken CSV

    @Test
    func readUnbalancedQuoteThrows() {
        #expect(throws: CSVError.malformedCSV(detail: "row 2: unterminated quoted field")) {
            _ = try CSVCoder.read(
                from: dataURL.appendingPathComponent("broken_unbalanced_quotes.csv"))
        }
    }

    @Test
    func readQuoteSwallowsLinesThrows() {
        // A quote opens in the name field of row 1 and swallows the following
        // lines. Silently merging records would corrupt the data, so this is
        // reported as an error.
        #expect(throws: CSVError.malformedCSV(detail: "row 2: unterminated quoted field")) {
            _ = try CSVCoder.read(
                from: dataURL.appendingPathComponent("broken_quote_swallows_line.csv"))
        }
    }

}
