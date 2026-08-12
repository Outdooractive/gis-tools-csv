import XCTest
import GISTools
@testable import GISToolsCSV

final class CSVFormatTests: XCTestCase {

    private var dataURL: URL {
        Bundle.module.resourceURL!.appendingPathComponent("TestData")
    }

    // MARK: - Delimiters

    func testReadSemicolonFile() throws {
        let fc = try CSVCoder.read(
            from: dataURL.appendingPathComponent("points_semicolon.csv"),
            delimiter: ";")
        XCTAssertEqual(fc.features.count, 3)
        let first = try XCTUnwrap(fc.features.first)
        let point = try XCTUnwrap(first.geometry as? Point)
        XCTAssertEqual(point.coordinate.longitude, 11.518585, accuracy: 1e-9)
        XCTAssertEqual(first.properties["name"] as? String, "Marienplatz")
    }

    func testReadTabFile() throws {
        let fc = try CSVCoder.read(
            from: dataURL.appendingPathComponent("points_tab.csv"),
            delimiter: "\t")
        XCTAssertEqual(fc.features.count, 3)
        XCTAssertEqual(fc.features[1].properties["name"] as? String, "Reichstag")
        let point = try XCTUnwrap(fc.features[2].geometry as? Point)
        XCTAssertEqual(point.coordinate.altitude, 1420.0)
    }

    func testReadPipeFile() throws {
        let fc = try CSVCoder.read(
            from: dataURL.appendingPathComponent("points_pipe.csv"),
            delimiter: "|")
        XCTAssertEqual(fc.features.count, 2)
        XCTAssertEqual(fc.features[0].id, .int(1))
        XCTAssertEqual(fc.features[1].properties["name"] as? String, "Reichstag")
    }

    func testReadSemicolonQuoted() throws {
        let fc = try CSVCoder.read(
            from: dataURL.appendingPathComponent("points_semicolon_quoted.csv"),
            delimiter: ";")
        XCTAssertEqual(fc.features.count, 2)
        // Quoted field keeps its delimiter.
        XCTAssertEqual(fc.features[0].properties["name"] as? String, "Munich, Bavaria; note")
    }

    // MARK: - Quoting edge cases

    func testReadEscapedQuotes() throws {
        let fc = try CSVCoder.read(
            from: dataURL.appendingPathComponent("quoted_edge_cases.csv"))
        XCTAssertEqual(fc.features.count, 3)
        XCTAssertEqual(
            fc.features[0].properties["name"] as? String,
            "escaped \"quote\" inside")
    }

    func testReadTrailingSpacesPreserved() throws {
        let fc = try CSVCoder.read(
            from: dataURL.appendingPathComponent("quoted_edge_cases.csv"))
        // Whitespace inside quotes is preserved.
        XCTAssertEqual(
            fc.features[1].properties["name"] as? String,
            "trailing spaces   ")
    }

    func testReadNewlineInQuotedField() throws {
        let fc = try CSVCoder.read(
            from: dataURL.appendingPathComponent("quoted_edge_cases.csv"))
        // The "line\nbreak" field swallows the newline but stays one record.
        XCTAssertEqual(fc.features.count, 3)
        XCTAssertEqual(fc.features[2].properties["name"] as? String, "line\nbreak")
    }

    // MARK: - Blank lines & ragged rows

    func testReadBlankLinesIgnored() throws {
        let fc = try CSVCoder.read(
            from: dataURL.appendingPathComponent("blank_lines.csv"))
        XCTAssertEqual(fc.features.count, 3)
        XCTAssertEqual(fc.features[0].id, .int(1))
        XCTAssertEqual(fc.features[2].properties["name"] as? String, "Alpine Lodge")
    }

    func testReadMissingColumns() throws {
        // Row 2 has an extra column, row 3 is missing name — should not throw.
        let fc = try CSVCoder.read(
            from: dataURL.appendingPathComponent("ragged_rows.csv"))
        XCTAssertEqual(fc.features.count, 3)
        // Extra column is simply ignored.
        XCTAssertEqual(fc.features[1].id, .int(2))
        // Missing name column -> no property set.
        XCTAssertNil(fc.features[2].properties["name"])
    }

    // MARK: - Line endings

    func testReadCRLFLineEndings() throws {
        let fc = try CSVCoder.read(
            from: dataURL.appendingPathComponent("crlf_line_endings.csv"))
        XCTAssertEqual(fc.features.count, 2)
        XCTAssertEqual(fc.features[0].id, .int(1))
        XCTAssertEqual(fc.features[1].properties["name"] as? String, "Reichstag")
    }

    func testReadMissingTrailingNewline() throws {
        let fc = try CSVCoder.read(
            from: dataURL.appendingPathComponent("missing_trailing_newline.csv"))
        XCTAssertEqual(fc.features.count, 2)
        XCTAssertEqual(fc.features[1].properties["name"] as? String, "Reichstag")
    }

    // MARK: - Broken CSV

    func testReadUnbalancedQuote() throws {
        // The whole remainder becomes one giant quoted field; it must still
        // not crash and should yield a geometry-less, malformed record set.
        // We assert it does not throw and that no error occurs.
        XCTAssertNoThrow(try CSVCoder.read(
            from: dataURL.appendingPathComponent("broken_unbalanced_quotes.csv")))
    }

    func testReadQuoteSwallowsLines() throws {
        // A quote opens in the name field of row 1 and swallows the following
        // lines as a single field — records get merged.
        let fc = try CSVCoder.read(
            from: dataURL.appendingPathComponent("broken_quote_swallows_line.csv"))
        // Should not crash; at least one row is produced.
        XCTAssertGreaterThanOrEqual(fc.features.count, 1)
    }

}
