// Passthrough.swift
// Copyright 2020 Dean Scarff
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

import Combine

/// Publishes values.
///
/// The publisher is available as the projected value, while setting the
/// wrapped value will publish an element.
@propertyWrapper
struct Passthrough<Output> {
  private let publisher = PassthroughSubject<Output, Never>()

  public init() {}

  /// The value to be published.
  ///
  /// *Do not read this value.*  It should only be used for writes.  Subscribe
  /// to the projected value to read the value.
  @inlinable var wrappedValue: Output {
    get {
      fatalError("Attempt to read @Passthrough wrappedValue")
    }
    set {
      publisher.send(newValue)
    }
  }

  /// The type-erased publisher.
  @inlinable public var projectedValue: AnyPublisher<Output, Never> {
    return publisher.eraseToAnyPublisher()
  }
}
