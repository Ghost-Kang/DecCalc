# Vendored code

`Sources/CBID` and `Sources/CBIDF128` are the C sources of the Intel® Decimal
Floating-Point Math Library 2.0 Update 5 (`LIBRARY/src` and `LIBRARY/float128`),
unmodified, under Intel's BSD-3-Clause license (`LICENSE-Intel.txt` in each target).

- Source: https://www.netlib.org/misc/intel/IntelRDFPMathLib20U5.tar.gz
- SHA-256: 85dafd70f0fe2a8da218ade4233fca9d3228b0b04cd6d8527f7499926be01037
- Build configuration: call by value, local rounding mode and status flags
  (see `Package.swift`). The library has no arm64 configuration; its 64-bit
  little-endian AMD64 configuration (`efi2`) compiles and runs correctly on arm64.

`Sources/CBID/include/CBID.h` is our own minimal interface to the library.
