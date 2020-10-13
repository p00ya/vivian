# Vivian

Vivian is free, open source software for communicating with the [4iiii Viiiiva](https://4iiii.com/viiiiva-heart-rate-monitor/) heart rate monitor over Bluetooth LE.  In particular, it allows the user to download the Viiiiva's .FIT activity logs without using the official 4iiii app.

This software is Copyright Dean Scarff, 2020.  It is licensed under the Apache License, Version 2.0.

Vivian is not endorsed by 4iiii.  It has been tested with a Viiiiva running firmware version 2.0.0; whether it works with other versions or devices is unknown.

Vivian does *not* expose generic Bluetooth heart rate monitor (HRM) functionality: you can't use it for realtime heart rate or RRI monitoring.  There are many other fitness apps that can be used for realtime monitoring.

Currently, the sole end-user product of the Vivian project is `vivtool`, a macOS command-line interface for listing and downloading .FIT activity logs from a Viiiiva heart rate monitor.

## Usage

`vivtool` is a command-line interface, which means you must run the program from macOS's Terminal.app or similar terminal software.

List all activity logs on the Viiiiva:

```sh
$ vivtool ls -l
650  2020-09-20T12:12:07Z  0001.fit
614  2020-09-20T05:12:17Z  0002.fit
471  2020-09-19T12:44:29Z  0003.fit
```

Copy an activity log from the Viiiiva to the current directory:

```sh
$ vivtool cp 0001.fit ./
```

Remove an activity log from the Viiiiva:

```sh
$ vivtool rm 0001.fit
```

For a complete reference, consult the manual page:

```sh
$ man vivtool
```

## Installation

The `vivtool` command requires macOS 10.15 (Catalina) or later to run.  Choose one of the options for installation below.

### Homebrew

The `vivtool` command can be installed using [Homebrew](https://brew.sh/) with a custom tap:

```sh
brew install --HEAD p00ya/tap/vivtool
```

### Github releases

A precompiled binary can be downloaded from the github releases page.  To download, extract, and authorize the executable to run, run these commands:

```sh
curl -LO https://github.com/p00ya/vivian/releases/latest/download/vivtool.tar.xz
tar -xf vivtool.tar.xz --strip-components 1
xattr -d com.apple.quarantine bin/vivtool
codesign -s "-" -v bin/vivtool
```

The last two commands remove the quarantine flag and sign the executable for local use.  Without these extra steps, macOS's "Gatekeeper" system will pop up a dialog saying "vivtool cannot be opened because the developer cannot be verified" or "vivtool cannot be opened because Apple cannot check it for malicious software".

The files can then be copied to system paths:

```sh
install -p bin/vivtool /usr/local/bin/
install -d /usr/local/share/man/man1/
install -p share/man/man1/vivtool.1 /usr/local/share/man/man1/
```

### Installation from source

You can clone the git repository and build the project with Xcode.  It will require Xcode 11.4 or later to be installed.

```sh
git clone https://github.com/p00ya/vivian.git
cd vivian
xcodebuild install -scheme vivtool -configuration Release DSTROOT=/usr/local
```

Xcode will install the executable and manual page in the `/usr/local` hierarchy if you have permission to write to that directory.  Alternatively, you can change the `DSTROOT` parameter to stage it elsewhere.

## Technical Design

### Background

The Viiiiva supports "Activity Logging", which allows sensor data to be stored on the device in an activity log when no Bluetooth device is connected.  Later, the activity logs may be downloaded as .FIT files over Bluetooth.

4iiii's apps download the .FIT files using a non-standard Bluetooth GATT characteristic with service UUID `5b774111d5267b9a4ae7e59d015d79ed` (`5B774111-D526-7B9A-4AE7-E59D015D79ED`).  The GATT characteristic is used as a transport for a non-standard protocol resembling ANT-FS.  Fitness apps relying on the standard Bluetooth Heart Rate Service cannot download the Viiiiva's activity logs.

### Design Goals

The goals for the project are to build:

1. A command-line app for power users (including the author) to retrieve activity logs on macOS.
2. A software library that will allow other developers to write their own apps that utilize Viiiiva's non-standard protocol.
3. A desktop app to allow end-users to download activity logs from their Viiiiva.

Currently the first two goals have been met, and the desktop app is on hold.

### Building

The binaries can be built by opening `vivian.xcodeproj` and building from Xcode.  Alternatively, test and build from the command line:

```sh
xcodebuild test -scheme vivtool
xcodebuild build -scheme vivtool -configuration Release
```

### Overview

There are two main components to the project:

* [libviv](viv/), a software library that allows other developers to write their own apps that utilize Viiiiva's non-standard protocol.
* [vivtool](vivtool/), a macOS command-line utility for downloading .FIT activity logs from a Viiiiva without using the official 4iiii app.
