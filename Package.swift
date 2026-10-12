// swift-tools-version: 6.0

import PackageDescription

// Intel's float128 sources include some .c files as templates; only these are
// compiled on their own (the list matches F128_NAMES in Intel's makefile).
let float128Templates = [
    "dpml_asinh.c", "dpml_cbrt.c", "dpml_cbrt_t_table.c", "dpml_erf.c", "dpml_error_codes.c",
    "dpml_exp.c", "dpml_expm1.c", "dpml_globals.c", "dpml_lgamma.c", "dpml_log.c",
    "dpml_pow_cons.c", "dpml_pow_t_table.c", "dpml_sqrt.c", "dpml_tgamma.c",
    "dpml_trig_reduce.c", "dpml_ux_cons.c", "dpml_ux_radian_reduce.c", "sizeof.c",
]

// The Intel library has no arm64 configuration; the 64-bit little-endian
// AMD64 configuration ("efi2") is correct for arm64 as well.
let intelPlatform: [CSetting] = [
    .define("LINUX"),
    .define("efi2"),
    .unsafeFlags(["-w", "-O2"]),
]

let package = Package(
    name: "DecCalc",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "DecCalc", targets: ["DecCalcApp"]),
        .executable(name: "calc", targets: ["calc"]),
        .library(name: "CalcCore", targets: ["CalcCore"]),
    ],
    targets: [
        .target(
            name: "CBIDF128",
            exclude: float128Templates + ["LICENSE-Intel.txt"],
            cSettings: intelPlatform + [
                .define("linux"),
                .define("USE_NATIVE_QUAD_TYPE", to: "0"),
            ]
        ),
        .target(
            name: "CBID",
            dependencies: ["CBIDF128"],
            exclude: ["LICENSE-Intel.txt"],
            cSettings: intelPlatform + [
                .define("DECIMAL_CALL_BY_REFERENCE", to: "0"),
                .define("DECIMAL_GLOBAL_ROUNDING", to: "0"),
                .define("DECIMAL_GLOBAL_EXCEPTION_FLAGS", to: "0"),
                .define("__NO_BINARY80__"),
                .define("USE_COMPILER_F128_TYPE", to: "0"),
                .define("USE_COMPILER_F80_TYPE", to: "0"),
            ]
        ),
        .target(name: "CalcCore", dependencies: ["CBID"]),
        .executableTarget(name: "calc", dependencies: ["CalcCore"]),
        .executableTarget(name: "DecCalcApp", dependencies: ["CalcCore"]),
        .testTarget(name: "CalcCoreTests", dependencies: ["CalcCore"]),
    ]
)
