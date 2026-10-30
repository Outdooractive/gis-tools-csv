# Getting started

Read a CSV file into a `FeatureCollection`, inspect it, and write it back.

## Add the dependency

`GISToolsCSV` requires Swift 6.1 or newer and the matching `GISTools`
release. Add both products to your target:

```swift
dependencies: [
    .package(url: "https://github.com/Outdooractive/gis-tools", from: "3.0.0"),
    .package(url: "https://github.com/Outdooractive/gis-tools-csv", from: "3.0.0"),
],
targets: [
    .target(
        name: "MyTarget",
        dependencies: [
            .product(name: "GISTools", package: "gis-tools"),
            .product(name: "GISToolsCSV", package: "gis-tools-csv"),
        ]),
]
```

Use a `gis-tools-csv` release whose `gis-tools` pin matches your project.
This release targets `gis-tools` 3.0.0.

## Read a file

```swift
import GISTools
import GISToolsCSV

let collection = try CSVCoder.read(from: csvURL)
print(collection.features.count)
```

The convenience initializer returns `nil` instead of throwing:

```swift
if let collection = FeatureCollection(csv: csvURL) {
    print(collection.features.count)
}
```

## Projected coordinates

CSV has no embedded CRS. Set `projection` when the coordinate columns contain
projected values:

```swift
let collection = try CSVCoder.read(
    from: csvURL,
    options: CSVReadOptions(projection: .epsg3857))
```

Writing a projected collection uses `x`/`y`/`z` columns by default. Use
`CSVWriteOptions(projection:)` to reproject first, or
`CSVWriteOptions(coordinateColumns:)` to force a naming style.

## Write a file

```swift
try collection.writeCSV(to: outputURL)
```

Or serialize to `Data`:

```swift
let data = try CSVCoder.write(collection)
```

## Next steps

- <doc:ReadingCSV> explains header mapping, geometry detection, and read
  options.
- <doc:WritingCSV> explains layouts, geometry formats, and write options.
- <doc:Limitations> lists what CSV cannot represent.
