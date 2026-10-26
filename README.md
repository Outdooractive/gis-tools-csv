# GISToolsCSV

CSV read and write support for Swift, built on top of [**gis-tools**](https://github.com/Outdooractive/gis-tools). Parses CSV rows into typed `FeatureCollection` objects — and writes them back as CSV.

## Features

- Reads and writes CSV files, with a configurable delimiter (`,` `;` `\t` or any `Character`)
- Works directly with Postgres/PostGIS CSV exports (`COPY TO`)
- **Header required** — geometry is never guessed
- Geometry columns (`geometry`, `geom`) parsed with **format auto-detection**: WKT (with or without an `SRID=…;` prefix), hex-encoded WKB/EWKB/TWKB, or GeoJSON
- Point geometry from `latitude`/`longitude` (and aliases, including `lat`, `lon`, `lng`), with optional altitude
- Feature ids from an `id` column (and many aliases), matched case-insensitively
- All other columns become `Feature` properties (booleans, ints, doubles, strings)
- RFC 4180-style quoting: embedded delimiters, quotes, and newlines
- UTF-8 input with an optional byte order mark; `\n`, `\r\n`, and lone `\r` line endings
- Unlocated features are supported through empty or `NULL` geometry cells
- Deterministic output, with geometry in EPSG:4326 and typed double properties

## Requirements

Swift 6.1 or higher. Compiles on iOS (≥ iOS 15), macOS (≥ macOS 15), tvOS (≥ tvOS 15), watchOS (≥ watchOS 7), Linux, Android and Wasm. No external dependencies beyond the base `gis-tools` package.

## Installation with Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/Outdooractive/gis-tools", exact: "3.0.0-beta.5"),
    .package(url: "https://github.com/Outdooractive/gis-tools-csv", from: "3.0.0-beta.1"),
],
targets: [
    .target(name: "MyTarget", dependencies: [
        .product(name: "GISTools", package: "gis-tools"),
        .product(name: "GISToolsCSV", package: "gis-tools-csv"),
    ]),
]
```

Use a `gis-tools-csv` release whose `gis-tools` pin matches your project. This
branch targets `gis-tools` `3.0.0-beta.5`.

## Usage

### Reading

```swift
import GISTools
import GISToolsCSV

let url = URL(fileURLWithPath: "/path/to/file.csv")
let fc = try CSVCoder.read(from: url)

// With a non-default delimiter:
let fc = try CSVCoder.read(from: url, options: CSVReadOptions(delimiter: ";"))

// Omit NULL and empty values from properties (e.g. PostGIS exports):
let fc = try CSVCoder.read(from: url, options: CSVReadOptions(nullHandling: .omit))

// Concatenate all coordinates into a single LineString (e.g. GPS tracks):
let fc = try CSVCoder.read(from: url, options: CSVReadOptions(treatAsLineString: true))

// Or via the convenience init (returns nil on failure):
guard let fc = FeatureCollection(csv: url) else { return }
```

`CSVReadOptions` controls how a CSV is read:

| Option | Default | Description |
|---|---|---|
| `delimiter` | `","` | The field delimiter. Any single `Character` is accepted. |
| `nullHandling` | `.keepAsString` | How `NULL` and empty values are treated. `.keepAsString` keeps them as strings; `.omit` drops the property entirely. `NULL` is matched case-insensitively. Null handling also applies to the id column and an optional altitude. |
| `treatAsLineString` | `false` | Concatenates the coordinates of all rows (in row order) into a single `LineString` feature, dropping row properties and ids. Works for `latitude`/`longitude` rows and for `POINT`/`MULTIPOINT`/`LINESTRING`/`MULTILINESTRING` geometries in a `geometry`/`geom` column; other geometry types and fewer than 2 coordinates in total are errors. |

### Writing

```swift
try fc.writeCSV(to: outputURL)

// Or via the coder directly:
try CSVCoder.write(fc, to: outputURL)

// Serialize to Data:
let data = try CSVCoder.write(fc)

// Write geometry as EWKB hex:
try CSVCoder.write(fc, to: outputURL, options: CSVWriteOptions(geometryFormat: .ewkb))
```

`CSVWriteOptions` controls how a `FeatureCollection` is written:

| Option | Default | Description |
|---|---|---|
| `delimiter` | `","` | The field delimiter. |
| `geometryFormat` | `.auto` | How geometry is written. `.auto` uses `longitude`/`latitude`/`altitude` columns for all-points collections in EPSG:4326 and a WKT geometry column otherwise. `.wkt`, `.ewkb` (hex), and `.geojson` always emit a geometry column. |
| `geometryColumnName` | `"geometry"` | The name of the geometry column. It must not be empty or collide with a coordinate/id column. |
| `includeHeader` | `true` | Whether to write the header row. |
| `nullValue` | `""` | The value written for `nil` properties and a missing altitude (e.g. `"NULL"`). |
| `lineEnding` | `.lf` | The line ending between rows (`.lf` or `.crlf`). |

### Column mapping (reading)

The header row is matched **case-insensitively**:

| Role            | Accepted column names                          |
|-----------------|------------------------------------------------|
| Geometry        | `geometry`, `geom`                             |
| Latitude        | `latitude`, `lat`                              |
| Longitude       | `longitude`, `long`, `lon`, `lng`              |
| Altitude        | `altitude`, `elevation`, `elev`, `z`           |
| Feature id      | `id`, `feature_id`, `feature_identifier`, `identifier`, `ident`, `fid`, `objectid`, `object_id`, `gid`, `idfield` |

Any other column becomes a `Feature` property. Numeric properties are parsed as `Int` or `Double`, `true`/`false` as `Bool`, everything else stays a `String`. Only canonical integer spellings become `Int`, so leading-zero values such as `00123` stay strings. `NaN` and `Infinity` stay strings because they are not valid JSON numbers.

If a row has a non-empty `geometry` column it is used as-is. The format is auto-detected, so it may be WKT (e.g. `POINT (11.5 48.1)` or `SRID=4326;LINESTRING (…)`), a hex-encoded PostGIS EWKB/WKB/TWKB string, or GeoJSON — and it may decode to a `Point`, `LineString`, `Polygon`, … All geometries are returned in EPSG:4326. If the geometry cell is empty or `NULL`, a latitude/longitude pair is used when available; if there is no pair either, the row becomes an unlocated feature. A row without a geometry column and without coordinate values is an error.

Latitude and longitude must be finite and within -90…90 and -180…180 degrees. An invalid altitude is an error; an empty or `NULL` altitude becomes `nil`.

### Column mapping (writing)

For **all-point EPSG:4326** collections, the output uses `id`, `longitude`, `latitude`, `altitude`, then the remaining property columns:

```
id,longitude,latitude,altitude,name
1,11.518585,48.135125,520,Marienplatz
```

Otherwise the geometry column is written **last** (it can be long), named `geometry` by default:

```
id,name,geometry
2,Trail,"SRID=4326;LINESTRING(10.22 47.56,10.3 47.62)"
```

Feature ids are always written to the `id` column (empty if a feature has none). Property columns are ordered deterministically: first appearance across features, alphabetically within one feature. Properties whose names collide with reserved column names (`id`, `geometry`, `lat`, `z`, …) are omitted, because the reader would misinterpret them. Whole-number `Double` properties keep a `.0` suffix so they read back as `Double`.

Geometry written with `.wkt`, `.ewkb`, or `.geojson` is always reprojected to EPSG:4326. An unlocated feature is written as an empty geometry cell and can be read back.

## API Reference

| API | Description |
|---|---|
| `CSVCoder.read(from url:options:)` | Reads a CSV file into a `FeatureCollection` |
| `CSVCoder.read(from data:options:)` | Reads CSV data into a `FeatureCollection` |
| `CSVCoder.write(_:options:)` | Serializes a `FeatureCollection` to CSV `Data` |
| `CSVCoder.write(_:to:options:)` | Writes a `FeatureCollection` to a CSV file |
| `CSVReadOptions` | Options controlling CSV reading (`delimiter`, `nullHandling`, `treatAsLineString`) |
| `CSVWriteOptions` | Options controlling CSV writing (`delimiter`, `geometryFormat`, `geometryColumnName`, `includeHeader`, `nullValue`, `lineEnding`) |
| `CSVError` | File, encoding, parsing, coordinate, and geometry errors |
| `FeatureCollection(csv:options:)` | Convenience init from a CSV file (returns `nil` on failure) |
| `FeatureCollection(csvData:options:)` | Convenience init from CSV data (returns `nil` on failure) |
| `FeatureCollection.csvData(options:)` | Serializes the receiver to CSV `Data` |
| `FeatureCollection.writeCSV(to:options:)` | Writes the receiver as a CSV file |

## Behavior notes

- Input must be UTF-8. A leading UTF-8 byte order mark is ignored.
- An unterminated quoted field throws `CSVError.malformedCSV` instead of silently swallowing the rest of the file.
- A quote inside an unquoted field is kept as data.
- A completely blank line is skipped; a line containing delimiters is a record, even if all fields are empty.
- `FeatureCollection.writeCSV(to:)` wraps file system errors in `CSVError.fileWriteError`.
- `FeatureCollection.csvData(options:)` and `writeCSV(to:options:)` accept the same options as `CSVCoder`.

## Documentation

A DocC catalog lives in `Sources/GISToolsCSV/GISToolsCSV.docc/`. Build it with:

```sh
./scripts/build-documentation.sh
```

## Development

```sh
swift test
swift test --enable-code-coverage
./scripts/coverage.sh 95
./scripts/build-documentation.sh
```

CI runs tests on macOS and Linux, enforces at least 95% line coverage on Linux, and builds the DocC catalog with warnings treated as errors.

## Limitations

- A header row is required — geometry columns are never guessed.
- CSV has no CRS. Latitude/longitude columns are always interpreted as EPSG:4326 degrees; geometry columns are reprojected to EPSG:4326.
- Feature and collection foreign members, collection metadata, and bounding boxes are not written.
- Property names that collide with reserved column names are omitted on write.
- Property types are inferred, so a string `"1"` reads back as an `Int`, and nested values are not reconstructed.
- The whole file is decoded into memory; there is no streaming reader.
- Written geometry uses the configured `geometryColumnName` and is emitted as WKT by default.

## Contributing

Please [create an issue](https://github.com/Outdooractive/gis-tools-csv/issues) or [open a pull request](https://github.com/Outdooractive/gis-tools-csv/pulls) with a fix or enhancement.

## License

MIT

## Authors

Thomas Rasch, Outdooractive

Built on top of [**gis-tools**](https://github.com/Outdooractive/gis-tools).
