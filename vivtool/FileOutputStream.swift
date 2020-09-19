// FileOutputStream.swift
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

import Foundation

/// Stream that writes to files.
class FileOutputStream: TextOutputStream {
  private let fileHandle: FileHandle
  let encoding: String.Encoding

  init(_ fileHandle: FileHandle, encoding: String.Encoding = .utf8) {
    self.fileHandle = fileHandle
    self.encoding = encoding
  }

  func write(_ string: String) {
    if let data = string.data(using: encoding) {
      fileHandle.write(data)
    }
  }
}
