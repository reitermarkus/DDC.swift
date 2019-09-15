// swift-tools-version:5.0
import PackageDescription

let package = Package(
  name: "DDC.swift",
  platforms: [
    .macOS(.v10_12)
  ],
  products: [
    .library(
      name: "DDC",
      targets: ["DDC"]),
  ],
  targets: [
    .target(
      name: "DDC",
      dependencies: [],
      path: "DDC"),
  ]
)
