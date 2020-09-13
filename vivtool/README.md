#  vivtool

`vivtool` is a macOS command-line utility for downloading .FIT activity logs from a Viiiiva without using the official 4iiii app.  It is part of the [Vivian project](https://github.com/p00ya/vivian), see the project page for user-oriented documentation.

This README is targeted at developers.

## Design

`vivtool` uses a Redux-like design: components exchange information via the `Store` class.  They dispatch mutations to the `State` via the `Store`.  They subscribe to changes via `Combine` publishers on the `State` class.  Reads and writes to the state occur on `DispatchQueue.main`.

