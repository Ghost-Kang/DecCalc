import CalcCore
import Foundation
import Observation

enum LayoutMode: String, CaseIterable, Identifiable {
    case basic = "Basic"
    case scientific = "Scientific"
    case rpn = "RPN"

    var id: String { rawValue }
}

enum MemoryAction {
    case clear, add, subtract, recall
}

/// App-level session state on top of CalcCore: the "=" flow, memory, 2nd functions
/// and the display strings.
@Observable
@MainActor
final class CalculatorModel {
    private let calculator = Calculator()

    var layout: LayoutMode = .basic {
        didSet {
            calculator.mode = layout == .rpn ? .rpn : .infix
            showingResult = false
            refresh()
        }
    }

    var angleUnit: AngleUnit = .radians {
        didSet {
            calculator.angleUnit = angleUnit
            refresh()
        }
    }

    var secondFunctions = false
    private(set) var memory: Decimal128?
    private var lastAnswer: Decimal128?
    /// True after "=": the next number starts a new expression and the next
    /// operator continues from the answer.
    private(set) var showingResult = false

    private(set) var expressionLine = ""
    private(set) var mainLine = "0"
    private(set) var stackLines: [String] = []

    init() {
        refresh()
    }

    // MARK: Keys

    func press(_ key: Key) {
        if layout == .rpn {
            calculator.press(key)
            refresh()
            return
        }
        if showingResult {
            switch key {
            case .equals:
                refresh()
                return
            case .allClear, .clear:
                calculator.startNewExpression(with: nil)
                showingResult = false
                refresh()
                return
            default:
                if Self.startsFreshNumber(key) {
                    calculator.startNewExpression(with: nil)
                } else {
                    calculator.startNewExpression(with: lastAnswer)
                }
                showingResult = false
            }
        }
        calculator.press(key)
        if key == .equals, case .value(let v) = calculator.result {
            lastAnswer = v
            showingResult = true
        }
        if secondFunctions, Self.isSecondFunction(key) {
            secondFunctions = false
        }
        refresh()
    }

    /// The clear key reads "C" while there is something to clear and "AC" otherwise.
    var clearKey: Key {
        if layout == .rpn { return .clear }
        return calculator.infix.isEmpty || showingResult ? .allClear : .clear
    }

    func memory(_ action: MemoryAction) {
        switch action {
        case .clear:
            memory = nil
        case .add, .subtract:
            guard case .value(let v) = calculator.result else { return }
            var context = DecimalContext()
            let current = memory ?? .zero
            memory = action == .add ? context.add(current, v) : context.sub(current, v)
        case .recall:
            guard let memory else { return }
            if showingResult {
                calculator.startNewExpression(with: nil)
                showingResult = false
            }
            calculator.insert(memory)
        }
        refresh()
    }

    /// Text placed on the pasteboard by ⌘C.
    var copyText: String {
        switch calculator.result {
        case .value(let v): return calculator.formatter.string(for: v).replacingOccurrences(of: ",", with: "")
        default: return mainLine
        }
    }

    // MARK: Display

    private func refresh() {
        switch layout {
        case .rpn:
            let rpn = calculator.rpn
            let values = rpn.valuesFromTop
            stackLines = values.enumerated().map { index, value in
                if index == 0, rpn.xIsBeingTyped { return calculator.expressionText }
                return calculator.display(value) ?? "Error"
            }
            if stackLines.isEmpty { stackLines = ["0"] }
            mainLine = stackLines[0]
            expressionLine = ""
        case .basic, .scientific:
            let expression = calculator.expressionText
            let result = calculator.display(calculator.result)
            if showingResult {
                expressionLine = expression + "="
                mainLine = result ?? "Error"
            } else {
                expressionLine = calculator.infix.isEmpty ? "" : expression
                mainLine = result ?? expression
            }
            stackLines = []
        }
    }

    private static func startsFreshNumber(_ key: Key) -> Bool {
        if key.digit != nil { return true }
        switch key {
        case .decimal, .pi, .eulerNumber, .random, .openParenthesis: return true
        default: return false
        }
    }

    private static func isSecondFunction(_ key: Key) -> Bool {
        switch key {
        case .inverseSine, .inverseCosine, .inverseTangent,
             .inverseHyperbolicSine, .inverseHyperbolicCosine, .inverseHyperbolicTangent,
             .exponentialBaseCustom, .exponentialBase2, .logarithmBaseCustom, .logarithmBase2:
            return true
        default:
            return false
        }
    }
}
