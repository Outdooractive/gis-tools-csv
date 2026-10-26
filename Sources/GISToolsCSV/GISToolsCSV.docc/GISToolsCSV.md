# ``GISToolsCSV``

CSV read and write support for Swift, built on top of
[GISTools](https://github.com/Outdooractive/gis-tools).

## Overview

`GISToolsCSV` converts CSV files into `FeatureCollection` values and back. It
requires a header row, recognizes geometry columns (WKT, EWKB/WKB/TWKB hex, or
GeoJSON) as well as latitude/longitude columns, and maps every other column to
a feature property.

The package is small and has no dependencies beyond `GISTools`:

- ``CSVCoder`` reads and writes CSV files and `Data`.
- ``CSVReadOptions`` and ``CSVWriteOptions`` control delimiters, null
  handling, geometry formats, headers, and line endings.
- ``CSVError`` reports file, encoding, parsing, and geometry problems.

```swift
import GISTools
import GISToolsCSV

let collection = try CSVCoder.read(from: csvURL)
try collection.writeCSV(to: outputURL)
```

## Topics

### Essentials

- <doc:GettingStarted>
- <doc:ReadingCSV>
- <doc:WritingCSV>
- <doc:Limitations>

### Reading

- ``CSVCoder``
- ``CSVReadOptions``
- ``CSVNullHandling``

### Writing

- ``CSVWriteOptions``
- ``CSVGeometryFormat``
- ``CSVLineEnding``

### Errors

- ``CSVError``
