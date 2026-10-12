import CBID

/// IEEE 754 decimal128 value (34 significant digits), backed by Intel's BID library —
/// the same arithmetic the system Calculate.framework links statically.
public struct Decimal128: Sendable {
    var raw: CBIDDecimal128

    init(raw: CBIDDecimal128) {
        self.raw = raw
    }

    /// Parses decimal text such as "12.5", "-3E+4" or "2e-3". Returns nil for text the library rejects.
    public init?(_ text: String) {
        var flags: CBIDFlags = 0
        let value = text.withCString { cbid128_from_string($0, Int32(CBIDRoundNearestEven), &flags) }
        if cbid128_isNaN(value) != 0 && !text.lowercased().contains("nan") { return nil }
        raw = value
    }

    /// Parses with half-away-from-zero rounding, as the framework does for its constants.
    init(roundingHalfAway text: String) {
        var flags: CBIDFlags = 0
        raw = text.withCString { cbid128_from_string($0, Int32(CBIDRoundNearestAway), &flags) }
    }

    static func divideRoundingHalfAway(_ x: Decimal128, _ y: Decimal128) -> Decimal128 {
        var flags: CBIDFlags = 0
        return Decimal128(raw: cbid128_div(x.raw, y.raw, Int32(CBIDRoundNearestAway), &flags))
    }

    /// Text in the form NSDecimalNumber.description prints. NSDecimalNumber holds
    /// exponents from -128 to 127 only, and shows "NaN" beyond them; Tools/Oracle
    /// reads values through NSDecimalNumber, so comparisons use this form.
    public var decimalNumberDescription: String {
        guard let (_, digits, exponent) = normalizedParts else { return plainDescription }
        if digits != "0", exponent < -128 || exponent > 127 { return "NaN" }
        return plainDescription
    }

    public init(_ value: Int) {
        raw = cbid128_from_int64(Int64(value))
    }

    public static let zero = Decimal128(0)
    public static let one = Decimal128(1)
    public static let nan = Decimal128("NaN")!

    public var isNaN: Bool { cbid128_isNaN(raw) != 0 }
    public var isInfinite: Bool { cbid128_isInf(raw) != 0 }
    public var isFinite: Bool { cbid128_isFinite(raw) != 0 }
    public var isZero: Bool { cbid128_isZero(raw) != 0 }
    public var isNegative: Bool { cbid128_isSigned(raw) != 0 && !isZero }

    /// Text in the library's canonical form, e.g. "+3333333333333333333333333333333333E-34".
    public var bidString: String {
        var buffer = [CChar](repeating: 0, count: 64)
        var flags: CBIDFlags = 0
        cbid128_to_string(&buffer, raw, &flags)
        let end = buffer.firstIndex(of: 0) ?? buffer.count
        return String(decoding: buffer[..<end].map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }

    /// Sign, coefficient digits and exponent of a finite value (value = ±coefficient × 10^exponent).
    public var parts: (negative: Bool, digits: String, exponent: Int)? {
        guard isFinite else { return nil }
        let text = bidString
        guard let e = text.lastIndex(of: "E") else { return nil }
        let negative = text.hasPrefix("-")
        let digits = String(text[text.index(after: text.startIndex)..<e])
        let exponent = Int(text[text.index(after: e)...]) ?? 0
        return (negative, digits, exponent)
    }

    /// The literal Calculate.framework writes into an RPN stack entry: the BID text without a leading "+".
    public var literal: String {
        let text = bidString
        return text.hasPrefix("+") ? String(text.dropFirst()) : text
    }
}

// MARK: - Arithmetic with status flags

/// Collects IEEE status flags across a computation, like the `_my_fpsf` word in Calculate.
public struct DecimalContext {
    public var flags: CBIDFlags = 0
    /// Calculate.framework rounds half away from zero (BID rounding mode 4).
    public let rounding = Int32(CBIDRoundNearestAway)

    public init() {}

    public var divisionByZero: Bool { flags & CBIDFlags(CBIDFlagZeroDivide) != 0 }
    public var overflow: Bool { flags & CBIDFlags(CBIDFlagOverflow) != 0 }
    public var invalid: Bool { flags & CBIDFlags(CBIDFlagInvalid) != 0 }

    public mutating func add(_ x: Decimal128, _ y: Decimal128) -> Decimal128 { .init(raw: cbid128_add(x.raw, y.raw, rounding, &flags)) }
    public mutating func sub(_ x: Decimal128, _ y: Decimal128) -> Decimal128 { .init(raw: cbid128_sub(x.raw, y.raw, rounding, &flags)) }
    public mutating func mul(_ x: Decimal128, _ y: Decimal128) -> Decimal128 { .init(raw: cbid128_mul(x.raw, y.raw, rounding, &flags)) }
    public mutating func div(_ x: Decimal128, _ y: Decimal128) -> Decimal128 { .init(raw: cbid128_div(x.raw, y.raw, rounding, &flags)) }
    public mutating func pow(_ x: Decimal128, _ y: Decimal128) -> Decimal128 { .init(raw: cbid128_pow(x.raw, y.raw, rounding, &flags)) }
    public mutating func fmod(_ x: Decimal128, _ y: Decimal128) -> Decimal128 { .init(raw: cbid128_fmod(x.raw, y.raw, &flags)) }

    public mutating func unary(_ f: (CBIDDecimal128, Int32, UnsafeMutablePointer<CBIDFlags>) -> CBIDDecimal128,
                               _ x: Decimal128) -> Decimal128 {
        .init(raw: f(x.raw, rounding, &flags))
    }

    public mutating func sqrt(_ x: Decimal128) -> Decimal128 { unary(cbid128_sqrt, x) }
    public mutating func cbrt(_ x: Decimal128) -> Decimal128 { unary(cbid128_cbrt, x) }
    public mutating func exp(_ x: Decimal128) -> Decimal128 { unary(cbid128_exp, x) }
    public mutating func ln(_ x: Decimal128) -> Decimal128 { unary(cbid128_log, x) }
    public mutating func log10(_ x: Decimal128) -> Decimal128 { unary(cbid128_log10, x) }
    public mutating func log2(_ x: Decimal128) -> Decimal128 { unary(cbid128_log2, x) }

    public mutating func roundToIntegerTowardZero(_ x: Decimal128) -> Decimal128 {
        .init(raw: cbid128_round_integral_zero(x.raw, &flags))
    }

    public mutating func equal(_ x: Decimal128, _ y: Decimal128) -> Bool { cbid128_quiet_equal(x.raw, y.raw, &flags) != 0 }
    public mutating func less(_ x: Decimal128, _ y: Decimal128) -> Bool { cbid128_quiet_less(x.raw, y.raw, &flags) != 0 }
    public mutating func greater(_ x: Decimal128, _ y: Decimal128) -> Bool { cbid128_quiet_greater(x.raw, y.raw, &flags) != 0 }
}

public extension Decimal128 {
    var negated: Decimal128 { .init(raw: cbid128_negate(raw)) }
    var magnitude: Decimal128 { .init(raw: cbid128_abs(raw)) }

    var doubleValue: Double {
        var flags: CBIDFlags = 0
        return cbid128_to_binary64(raw, Int32(CBIDRoundNearestEven), &flags)
    }

    /// True when the value is a whole number.
    var isInteger: Bool {
        guard isFinite else { return false }
        var flags: CBIDFlags = 0
        let truncated = cbid128_round_integral_zero(raw, &flags)
        return cbid128_quiet_equal(truncated, raw, &flags) != 0
    }

    /// Plain decimal text with no exponent and no trailing fractional zeros, in the
    /// format of NSDecimalNumber.description: "0.5", "-12", "1000000".
    var plainDescription: String {
        if isNaN { return "NaN" }
        if isInfinite { return isNegative ? "-Infinity" : "Infinity" }
        guard var (negative, digits, exponent) = parts else { return "NaN" }
        // Strip trailing zeros from the coefficient.
        while digits.count > 1, digits.hasSuffix("0") {
            digits.removeLast()
            exponent += 1
        }
        if digits == "0" { return "0" }
        var text: String
        if exponent >= 0 {
            text = digits + String(repeating: "0", count: exponent)
        } else {
            let fractionCount = -exponent
            if digits.count > fractionCount {
                let split = digits.index(digits.endIndex, offsetBy: -fractionCount)
                text = digits[..<split] + "." + digits[split...]
            } else {
                text = "0." + String(repeating: "0", count: fractionCount - digits.count) + digits
            }
        }
        if negative { text = "-" + text }
        negative = false
        return text
    }
}

extension Decimal128: CustomStringConvertible {
    public var description: String { plainDescription }
}
