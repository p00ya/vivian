#!/bin/sh

# install.sh - install the vivtool binary and manual page under the "DSTROOT"
# directory, defaulting to /usr/local.

# Copyright 2022 Dean Scarff
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -e

DSTROOT="${DSTROOT:-/usr/local}"

echo "Installing to ${DSTROOT}"
cd vivtool
swift build -c release
test -d "${DSTROOT}/bin" || mkdir "${DSTROOT}/bin"
test -d "${DSTROOT}/share/man/man1" || install -d "${DSTROOT}/share/man/man1"
install "$(swift build -c release --show-bin-path)/vivtool" "${DSTROOT}/bin"
install -m 0644 vivtool.1 "${DSTROOT}/share/man/man1"
