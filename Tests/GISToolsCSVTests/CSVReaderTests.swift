import Foundation
@testable import GISToolsCSV
import Testing

struct CSVReaderTests {

    // MARK: - Basic parsing

    @Test
    func parseEmptyString() throws {
        #expect(try CSVReader.parse(string: "", delimiter: ",") == [])
    }

    @Test
    func parseHeaderOnly() throws {
        #expect(
            try CSVReader.parse(string: "id,name\n", delimiter: ",") ==
                [["id", "name"]],
        )
    }

    @Test
    func parseSingleRowWithoutNewline() throws {
        #expect(
            try CSVReader.parse(string: "id,name", delimiter: ",") ==
                [["id", "name"]],
        )
    }

    @Test
    func parseTrailingDelimiter() throws {
        #expect(
            try CSVReader.parse(string: "a,b,", delimiter: ",") ==
                [["a", "b", ""]],
        )
    }

    @Test
    func parseTrailingNewlineDoesNotAddRow() throws {
        #expect(
            try CSVReader.parse(string: "a,b\n", delimiter: ",") ==
                [["a", "b"]],
        )
    }

    @Test
    func parseCRLF() throws {
        #expect(
            try CSVReader.parse(string: "a,b\r\nc,d\r\n", delimiter: ",") ==
                [["a", "b"], ["c", "d"]],
        )
    }

    @Test
    func parseLoneCR() throws {
        #expect(
            try CSVReader.parse(string: "a,b\rc,d\r", delimiter: ",") ==
                [["a", "b"], ["c", "d"]],
        )
    }

    @Test
    func parseBlankLineProducesEmptyRecord() throws {
        #expect(
            try CSVReader.parse(string: "a\n\nb\n", delimiter: ",") ==
                [["a"], [""], ["b"]],
        )
    }

    @Test
    func parsePreservesWhitespace() throws {
        #expect(
            try CSVReader.parse(string: " a , b \n", delimiter: ",") ==
                [[" a ", " b "]],
        )
    }

    // MARK: - Quoting

    @Test
    func parseQuotedFieldWithDelimiter() throws {
        #expect(
            try CSVReader.parse(string: "\"a,b\",c\n", delimiter: ",") ==
                [["a,b", "c"]],
        )
    }

    @Test
    func parseEscapedQuotes() throws {
        #expect(
            try CSVReader.parse(string: "\"a\"\"b\"\n", delimiter: ",") ==
                [["a\"b"]],
        )
    }

    @Test
    func parseQuotedFieldWithNewline() throws {
        #expect(
            try CSVReader.parse(string: "\"a\nb\",c\n", delimiter: ",") ==
                [["a\nb", "c"]],
        )
    }

    @Test
    func parseQuotedFieldWithCRLF() throws {
        #expect(
            try CSVReader.parse(string: "\"a\r\nb\",c\r\n", delimiter: ",") ==
                [["a\r\nb", "c"]],
        )
    }

    @Test
    func parseQuotedEmptyFieldAtEndOfFile() throws {
        #expect(try CSVReader.parse(string: "\"\"", delimiter: ",") == [[""]])
    }

    @Test
    func parseEmptyQuotedField() throws {
        #expect(
            try CSVReader.parse(string: "a,\"\",c\n", delimiter: ",") ==
                [["a", "", "c"]],
        )
    }

    @Test
    func parseStrayQuoteIsPreserved() throws {
        // A quote in the middle of an unquoted field is data, not syntax.
        #expect(
            try CSVReader.parse(string: "a\"b,c\n", delimiter: ",") ==
                [["a\"b", "c"]],
        )
    }

    @Test
    func parseCharactersAfterClosingQuoteAreAppended() throws {
        // Lenient behavior: trailing characters are kept, not dropped.
        #expect(
            try CSVReader.parse(string: "\"ab\"cd,e\n", delimiter: ",") ==
                [["abcd", "e"]],
        )
    }

    @Test
    func parseUnterminatedQuoteThrows() {
        #expect(throws: CSVError.malformedCSV(detail: "row 1: unterminated quoted field")) {
            _ = try CSVReader.parse(string: "\"abc", delimiter: ",")
        }
    }

    @Test
    func parseUnterminatedQuoteOnLaterRowThrows() {
        #expect(throws: CSVError.malformedCSV(detail: "row 2: unterminated quoted field")) {
            _ = try CSVReader.parse(string: "a,b\nc,\"d", delimiter: ",")
        }
    }

    // MARK: - Delimiters

    @Test
    func parseSemicolonDelimiter() throws {
        #expect(
            try CSVReader.parse(string: "a;b;c\n", delimiter: ";") ==
                [["a", "b", "c"]],
        )
    }

    @Test
    func parseTabDelimiter() throws {
        #expect(
            try CSVReader.parse(string: "a\tb\n", delimiter: "\t") ==
                [["a", "b"]],
        )
    }

    @Test
    func parseMultiScalarDelimiter() throws {
        #expect(
            try CSVReader.parse(string: "a🇩🇪b🇩🇪c\n", delimiter: "🇩🇪") ==
                [["a", "b", "c"]],
        )
    }

    // MARK: - BOM and encoding

    @Test
    func parseSkipsUTF8ByteOrderMark() throws {
        #expect(
            try CSVReader.parse(string: "\u{FEFF}id,name\n1,foo\n", delimiter: ",") ==
                [["id", "name"], ["1", "foo"]],
        )
    }

    @Test
    func parseInvalidUTF8Throws() {
        #expect(throws: CSVError.invalidEncoding) {
            _ = try CSVReader.parse(data: Data([0xFF, 0xFE, 0x00]), delimiter: ",")
        }
    }

    // MARK: - Writer

    @Test
    func writeEmptyRows() {
        #expect(CSVWriter.write([], delimiter: ",") == "")
    }

    @Test
    func writeSimpleRows() {
        #expect(CSVWriter.write([["a", "b"], ["1", "2"]], delimiter: ",") == "a,b\n1,2\n")
    }

    @Test
    func writeQuotesSpecialCharacters() {
        #expect(
            CSVWriter.write([["a,b", "c\"d", "e\nf", "g\rh"]], delimiter: ",") ==
                "\"a,b\",\"c\"\"d\",\"e\nf\",\"g\rh\"\n",
        )
    }

    @Test
    func writeCustomDelimiter() {
        #expect(
            CSVWriter.write([["a;b", "c"]], delimiter: ";") ==
                "\"a;b\";c\n",
        )
    }

    @Test
    func writeCRLFLineEnding() {
        #expect(
            CSVWriter.write([["a", "b"], ["1", "2"]], delimiter: ",", lineEnding: .crlf) ==
                "a,b\r\n1,2\r\n",
        )
    }

}
