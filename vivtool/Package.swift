// swift-tools-version:5.5

// Package.swift - Swift Package Manager manifest for vivtool.
// Copyright 2022 Dean Scarff
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import PackageDescription

let package = Package(
  name: "vivtool",
  platforms: [.macOS(.v11)],
  products: [
    .executable(name: "vivtool", targets: ["vivtool"])
  ],
  dependencies: [
    .package(
      name: "swift-argument-parser",
      url: "https://github.com/apple/swift-argument-parser",
      .upToNextMinor(from: "1.0.3")),
    .package(name: "viv", path: "../viv"),
  ],
  targets: [
    .executableTarget(
      name: "vivtool",
      dependencies: [
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        .product(name: "libviv", package: "viv"),
      ],
      cSettings: [
        .define("NDEBUG", .when(configuration: .release)),
        .define("DEBUG=0", .when(configuration: .release)),
        .define("DEBUG=1", .when(configuration: .debug)),
      ]
    ),
    .testTarget(
      name: "vivtoolTests",
      dependencies: ["vivtool"],
      cSettings: [
        .define("NDEBUG", .when(configuration: .release)),
        .define("DEBUG=0", .when(configuration: .release)),
        .define("DEBUG=1", .when(configuration: .debug)),
      ]),
  ]
)
