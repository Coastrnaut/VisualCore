// swift-tools-version: 6.0
import PackageDescription
let names = ["DemoKit"]
let package = Package(name: "Demo", products: names.map { .library(name: $0, targets: [$0]) } + [.library(name: "DemoExtra", targets: ["DemoKit"])],
                      targets: [.target(name: "DemoKit")])
