# libviv

libviv is a software library for interacting with the Viiiiva's non-standard protocol.

The internal logic for libviv is implemented in C++17.  However, it has C and Objective C APIs, because other programming languages (in particular, Swift) are not able to interface directly with C++.  I expect that using this combination of C and C++ will make libviv portable to most platforms.

Developers wishing to use libviv in other apps should start by looking at `manager_c_bridge.h`, which is the high-level C interface for the library.  Lower-level C interfaces for reading and writing packets are also provided.  The internal C++ logic may also be re-used, though the classes and functions in the C++ headers (`*.hpp`) are not intended as a stable API.
