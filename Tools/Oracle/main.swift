import Calculate
import Foundation

// Oracle for differential testing against the system Calculate.framework.
//
// Reads one case per line from stdin and prints one result line per case:
//   E <expression>                 evaluate a plain-text expression
//   K <format> <degrees> <op> ...  replay key operations on a CalculateExpression
// <format>: 0 infix, 2 RPN. <degrees>: 0 radians, 1 degrees.
// Pass --trace to also print the state after every key of a K case.
// K cases use the number formatter Calculator.app installs by default
// (decimal style, 10 integer digits, 8 fraction digits, grouping on);
// --fraction-digits N overrides the fraction digits.

func exactValue(_ result: CalculateResult?) -> String {
    guard let result,
          let term = (result.value(forKey: "terms") as? [NSObject])?.first,
          let value = term.value(forKey: "value") as? NSDecimalNumber
    else { return "nil" }
    return value.description
}

func formatted(_ result: CalculateResult?) -> String {
    result?.formattedResult ?? "nil"
}

func state(_ e: CalculateExpression) -> String {
    var fields = ["plain=\(e.plain.text)", "value=\(exactValue(e.result))", "shown=\(formatted(e.result))"]
    if e.format.rawValue == 2 {
        fields.append("stack=" + e.postfixStack.map { exactValue($0.result) }.joined(separator: ","))
    }
    return fields.joined(separator: "\t")
}

let arguments = CommandLine.arguments
let trace = arguments.contains("--trace")
let fractionDigits = arguments.firstIndex(of: "--fraction-digits").flatMap { Int(arguments[$0 + 1]) } ?? 8

func appNumberFormatter() -> NumberFormatter {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.maximumIntegerDigits = 10
    formatter.maximumFractionDigits = fractionDigits
    formatter.usesGroupingSeparator = true
    return formatter
}
let evaluator: AnyClass = NSClassFromString("Calculate")!

while let line = readLine() {
    let parts = line.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
    guard let kind = parts.first else { continue }
    switch kind {
    case "E":
        let expression = String(line.dropFirst(2))
        let result = (evaluator as AnyObject).perform(NSSelectorFromString("evaluate:options:"),
                                                      with: expression, with: [String: Any]())?
            .takeUnretainedValue() as? CalculateResult
        print("E\t\(expression)\tvalue=\(exactValue(result))\tshown=\(formatted(result))")
    case "K" where parts.count >= 3:
        let e = CalculateExpression("", options: [:], base: .base10, id: UUID())
        e.numberFormatter = appNumberFormatter()
        e.format = CalculateFormat(rawValue: Int(parts[1]) ?? 0)
        e.assumeDegrees = parts[2] == "1"
        let keys = Array(parts.dropFirst(3))
        for key in keys {
            guard let op = operationTable[key] else { print("K\tunknown key \(key)"); exit(2) }
            _ = e.update(op())
            if trace { print("  \(key)\t\(state(e))") }
        }
        print("K\t\(keys.joined(separator: " "))\t\(state(e))")
    default:
        print("?\t\(line)")
    }
}
