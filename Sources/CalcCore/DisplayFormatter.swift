import CBID
import Foundation

/// Formats results the way Calculator.app displays them with its default settings:
/// a decimal NumberFormatter with up to 10 integer digits and 8 fraction digits,
/// grouping separators, and scientific notation for larger magnitudes.
public struct DisplayFormatter: Sendable {
    public var fractionDigits: Int
    public var maximumIntegerDigits: Int
    public var usesGrouping: Bool

    public init(fractionDigits: Int = 8, maximumIntegerDigits: Int = 10, usesGrouping: Bool = true) {
        self.fractionDigits = fractionDigits
        self.maximumIntegerDigits = maximumIntegerDigits
        self.usesGrouping = usesGrouping
    }

    public func string(for value: Decimal128) -> String {
        guard let (negative, digits, exponent) = value.normalizedParts else { return "Error" }
        if digits == "0" { return "0" }
        let sign = negative ? "-" : ""
        // Position of the most significant digit: value = 0.d1d2... × 10^magnitude.
        let magnitude = digits.count + exponent
        let atMostOneBillionth = magnitude < -8 || (magnitude == -8 && digits == "1")
        if magnitude > maximumIntegerDigits || atMostOneBillionth {
            return sign + scientific(digits: digits, magnitude: magnitude)
        }
        // Like the framework, format an NSDecimalNumber copy with a NumberFormatter,
        // showing `fractionDigits` places plus any zeros that lead the fraction.
        let places = fractionDigits + Self.leadingFractionZeros(digits: digits, exponent: exponent)
        let formatted = Self.format(digits: digits, exponent: exponent, fractionDigits: places, grouping: usesGrouping)
        return formatted == "0" ? "0" : sign + formatted
    }

    static func format(digits: String, exponent: Int, fractionDigits: Int, grouping: Bool) -> String {
        let decimal = NSDecimalNumber(string: digits + "E" + String(exponent), locale: Locale(identifier: "en_US_POSIX"))
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = grouping
        formatter.groupingSeparator = ","
        formatter.groupingSize = 3
        formatter.decimalSeparator = "."
        formatter.maximumIntegerDigits = 309
        formatter.maximumFractionDigits = fractionDigits
        return formatter.string(from: decimal) ?? "Error"
    }

    /// Zeros between the decimal point and the first non-zero fraction digit. The
    /// display shows that many extra places, so "1.0986…" keeps 9 and "0.000142…" 11.
    static func leadingFractionZeros(digits: String, exponent: Int) -> Int {
        guard exponent < 0 else { return 0 }
        let fractionCount = -exponent
        let fraction = digits.count >= fractionCount
            ? String(digits.suffix(fractionCount))
            : String(repeating: "0", count: fractionCount - digits.count) + digits
        return fraction.prefix(while: { $0 == "0" }).count
    }

    private func scientific(digits: String, magnitude: Int) -> String {
        // Mantissa d.ddd… = digits × 10^-(count-1), formatted like a fixed value.
        let mantissaExponent = -(digits.count - 1)
        let places = fractionDigits + Self.leadingFractionZeros(digits: digits, exponent: mantissaExponent)
        var power = magnitude - 1
        var mantissa = Self.format(digits: digits, exponent: mantissaExponent, fractionDigits: places, grouping: false)
        if mantissa == "10" {
            // Rounding carried into a new digit (9.999999999 → 10).
            power += 1
            mantissa = "1"
        }
        return mantissa + "×10" + Self.superscript(power)
    }

    /// Rounds digits×10^exponent half-to-even at `places` fraction digits.
    static func round(digits: String, exponent: Int, toFractionDigits places: Int) -> (digits: String, exponent: Int) {
        let drop = -exponent - places
        guard drop > 0 else { return (digits, exponent) }
        if drop > digits.count { return ("0", -places) }
        let keepCount = digits.count - drop
        var kept = Array(digits.prefix(keepCount))
        let removed = Array(digits.suffix(drop))
        let first = removed[0]
        let restNonZero = removed.dropFirst().contains { $0 != "0" }
        let lastKept = kept.last.map { Int(String($0))! } ?? 0
        let roundUp = first > "5" || (first == "5" && (restNonZero || lastKept % 2 == 1))
        if roundUp {
            var i = kept.count - 1
            var carry = true
            while carry && i >= 0 {
                if kept[i] == "9" { kept[i] = "0"; i -= 1 } else {
                    kept[i] = Character(String(Int(String(kept[i]))! + 1)); carry = false
                }
            }
            if carry { kept.insert("1", at: 0) }
        }
        var result = String(kept)
        if result.isEmpty { result = "0" }
        result = String(result.drop(while: { $0 == "0" }))
        if result.isEmpty { return ("0", -places) }
        return (result, -places)
    }

    static func superscript(_ n: Int) -> String {
        let map: [Character: Character] = ["0": "⁰", "1": "¹", "2": "²", "3": "³", "4": "⁴",
                                           "5": "⁵", "6": "⁶", "7": "⁷", "8": "⁸", "9": "⁹", "-": "⁻"]
        return String(String(n).map { map[$0] ?? $0 })
    }
}

extension Decimal128 {
    /// Sign, coefficient without trailing zeros, and exponent.
    var normalizedParts: (negative: Bool, digits: String, exponent: Int)? {
        guard var (negative, digits, exponent) = parts else { return nil }
        digits = String(digits.drop(while: { $0 == "0" }))
        if digits.isEmpty { return (false, "0", 0) }
        while digits.count > 1, digits.hasSuffix("0") {
            digits.removeLast()
            exponent += 1
        }
        if digits == "0" { negative = false }
        return (negative, digits, exponent)
    }
}
