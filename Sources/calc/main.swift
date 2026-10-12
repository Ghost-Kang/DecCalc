import CalcCore
import Foundation

// Command-line front end speaking the same line protocol as Tools/Oracle, so the
// two can be compared case by case:
//   P <degrees> <expression>        evaluate plain text (degrees: 0 or 1)
//   K <format> <degrees> <op> ...   replay key operations (format: 0 infix, 2 RPN)
// Pass --trace to print the state after every key of a K case.

let trace = CommandLine.arguments.contains("--trace")

func valueText(_ evaluation: Evaluation) -> String {
    switch evaluation {
    case .value(let v): return v.plainDescription
    case .incomplete, .error: return "nil"
    }
}

while let line = readLine() {
    let parts = line.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
    guard let kind = parts.first else { continue }
    switch kind {
    case "P" where parts.count >= 3:
        let text = parts.dropFirst(2).joined(separator: " ")
        let evaluator = Evaluator(angleUnit: parts[1] == "1" ? .degrees : .radians)
        print("P\t\(text)\tvalue=\(valueText(evaluator.evaluate(text)))")
    case "K" where parts.count >= 3:
        let mode: CalculatorMode = parts[1] == "2" ? .rpn : .infix
        let calculator = Calculator(mode: mode, angleUnit: parts[2] == "1" ? .degrees : .radians)
        let keys = Array(parts.dropFirst(3))
        for name in keys {
            guard let key = Key(rawValue: name) else { print("K\tunknown key \(name)"); exit(2) }
            calculator.press(key)
            if trace { print("  \(name)\t\(calculator.stateLine)") }
        }
        print("K\t\(keys.joined(separator: " "))\t\(calculator.stateLine)")
    default:
        print("?\t\(line)")
    }
}
