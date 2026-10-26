import Foundation
import GISTools
@testable import GISToolsCSV
import Testing

struct CSVApiTests {

    private var dataURL: URL {
        Bundle.module.resourceURL!.appendingPathComponent("TestData")
    }

    // MARK: - FeatureCollection convenience API

    @Test
    func featureCollectionFromCSVData() throws {
        let data = Data("""
        id,longitude,latitude,name
        1,11.5,48.1,Marienplatz
        """.utf8)
        let fc = try #require(FeatureCollection(csvData: data))
        #expect(fc.features.count == 1)
        #expect(fc.features[0].id == .int(1))
    }

    @Test
    func featureCollectionFromInvalidCSVDataReturnsNil() {
        #expect(FeatureCollection(csvData: Data()) == nil)
        #expect(FeatureCollection(csvData: Data("name\nfoo\n".utf8)) == nil)
    }

    @Test
    func featureCollectionFromCSVFile() throws {
        let fc = try #require(FeatureCollection(csv: dataURL.appendingPathComponent("points.csv")))
        #expect(fc.features.count == 3)
    }

    @Test
    func featureCollectionFromMissingCSVFileReturnsNil() {
        let url = URL(fileURLWithPath: "/this/file/does/not/exist.csv")
        #expect(FeatureCollection(csv: url) == nil)
    }

    @Test
    func featureCollectionCSVDataMatchesCoder() throws {
        let fc = try CSVCoder.read(from: dataURL.appendingPathComponent("points.csv"))
        let convenienceData = try fc.csvData()
        let coderData = try CSVCoder.write(fc)
        #expect(convenienceData == coderData)
    }

    @Test
    func featureCollectionWriteCSV() throws {
        let fc = try CSVCoder.read(from: dataURL.appendingPathComponent("points.csv"))
        let url = FileManager.default
            .temporaryDirectory
            .appendingPathComponent("api-\(UUID().uuidString).csv")

        try fc.writeCSV(to: url)
        let loaded = try #require(FeatureCollection(csv: url))
        #expect(loaded.features.count == fc.features.count)

        try? FileManager.default.removeItem(at: url)
    }

    @Test
    func featureCollectionWriteCSVWrapsIOErrors() throws {
        let fc = FeatureCollection([Feature]())
        let url = URL(fileURLWithPath: "/this/directory/does/not/exist/out.csv")
        #expect(throws: CSVError.self) {
            try fc.writeCSV(to: url)
        }
    }

    // MARK: - Coder file errors

    @Test
    func coderReadMissingFileThrowsFileReadError() {
        let url = URL(fileURLWithPath: "/this/file/does/not/exist.csv")
        #expect(throws: CSVError.self) {
            _ = try CSVCoder.read(from: url)
        }
    }

    @Test
    func coderWriteToInvalidPathThrowsFileWriteError() throws {
        let fc = FeatureCollection([Feature]())
        let url = URL(fileURLWithPath: "/this/directory/does/not/exist/out.csv")
        do {
            try CSVCoder.write(fc, to: url)
            Issue.record("Expected a file write error")
        }
        catch let error as CSVError {
            guard case .fileWriteError = error else {
                Issue.record("Expected a file write error, got \(error)")
                return
            }
        }
    }

    // MARK: - Options

    @Test
    func readOptionsDefaults() {
        let options = CSVReadOptions()
        #expect(options.delimiter == ",")
        #expect(options.nullHandling == .keepAsString)
        #expect(options.treatAsLineString == false)
        #expect(options == CSVReadOptions())
        #expect(options != CSVReadOptions(delimiter: ";"))
    }

    @Test
    func writeOptionsDefaults() {
        let options = CSVWriteOptions()
        #expect(options.delimiter == ",")
        #expect(options.geometryFormat == .auto)
        #expect(options.geometryColumnName == "geometry")
        #expect(options.includeHeader == true)
        #expect(options.nullValue == "")
        #expect(options.lineEnding == .lf)
        #expect(options == CSVWriteOptions())
        #expect(options != CSVWriteOptions(includeHeader: false))
    }

    @Test
    func lineEndingRawValues() {
        #expect(CSVLineEnding.lf.rawValue == "\n")
        #expect(CSVLineEnding.crlf.rawValue == "\r\n")
    }

    @Test
    func defaultDelimiter() {
        #expect(CSVCoder.defaultDelimiter == ",")
    }

    // MARK: - Error descriptions

    @Test
    func errorDescriptions() {
        #expect(
            CSVError.fileReadError(detail: "denied").errorDescription ==
                "Could not read CSV file: denied",
        )
        #expect(
            CSVError.fileWriteError(detail: "denied").errorDescription ==
                "Could not write CSV file: denied",
        )
        #expect(CSVError.invalidEncoding.errorDescription == "Invalid encoding")
        #expect(
            CSVError.malformedCSV(detail: "row 1: bad").errorDescription ==
                "Malformed CSV: row 1: bad",
        )
        #expect(
            CSVError.missingHeader.errorDescription ==
                "The CSV has no header row. A header row is required.",
        )
        #expect(
            CSVError.missingGeometryColumns.errorDescription ==
                "The CSV header has no geometry column and no latitude/longitude pair.",
        )
        #expect(
            CSVError.missingGeometry(line: 3).errorDescription ==
                "CSV row 3 has no geometry (no geometry/geom column and no latitude/longitude pair).",
        )
        #expect(
            CSVError.invalidCoordinate(detail: "bad").errorDescription ==
                "Invalid coordinate: bad",
        )
        #expect(
            CSVError.invalidGeometry(detail: "bad").errorDescription ==
                "Invalid geometry: bad",
        )
        #expect(
            CSVError.invalidGeometryColumnName(name: "lat").errorDescription ==
                "Invalid geometry column name 'lat'. It must not be empty or collide with a coordinate or id column.",
        )
    }

    @Test
    func errorsAreEquatable() {
        #expect(CSVError.missingHeader == CSVError.missingHeader)
        #expect(CSVError.missingGeometry(line: 1) != CSVError.missingGeometry(line: 2))
        #expect(CSVError.invalidGeometry(detail: "a") == CSVError.invalidGeometry(detail: "a"))
    }

}
