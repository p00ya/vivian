# Vivian

Vivian is free, open source software for communicating with the [4iiii Viiiiva](https://4iiii.com/viiiiva-heart-rate-monitor/) heart rate monitor over Bluetooth LE.  In particular, it allows the user to download the Viiiiva's .FIT activity logs without using the official 4iiii app.

This software is Copyright Dean Scarff, 2020.  It is licensed under the Apache License, Version 2.0.

Vivian is not endorsed by 4iiii.  It has been tested with a Viiiiva running firmware version 2.0.0; whether it works with other versions or devices is unknown.

Vivian does *not* expose generic Bluetooth heart rate monitor (HRM) functionality: you can't use it for realtime heart rate or RRI monitoring.  There are many other fitness apps that can be used for realtime monitoring.

## Usage

`vivtool` is a macOS command-line interface for listing and downloading .FIT activity logs from a Viiiiva heart rate monitor.

```sh
$ vivtool ls -l
$ vivtool cp 0001.fit ./
$ vivtool rm 0001.fit
```

## Installation

The `vivtool` command can be installed using [Homebrew](https://brew.sh/) with a custom tap:

```sh
brew install --HEAD p00ya/tap/vivtool
```

## Technical Design

### Background

The Viiiiva supports "Activity Logging", which allows sensor data to be stored on the device in an activity log when no Bluetooth device is connected.  Later, the activity logs may be downloaded as .FIT files over Bluetooth.

4iiii's apps download the .FIT files using a non-standard Bluetooth GATT characteristic with service UUID `5b774111d5267b9a4ae7e59d015d79ed`.  The GATT characteristic is used as a transport for a non-standard protocol resembling ANT-FS.  Fitness apps relying on the standard Bluetooth Heart Rate Service cannot download the Viiiiva's activity logs.

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
