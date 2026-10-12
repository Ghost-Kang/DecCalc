import Foundation

/// One calculator session in infix or RPN mode: key handling, evaluation and display.
public final class Calculator {
    public var mode: CalculatorMode {
        didSet { if mode != oldValue { reset() } }
    }
    public var angleUnit: AngleUnit {
        didSet { rpn.angleUnit = angleUnit }
    }
    public var formatter = DisplayFormatter()

    public private(set) var infix = InfixEditor()
    public private(set) var rpn: RPNStack

    public init(mode: CalculatorMode = .infix, angleUnit: AngleUnit = .radians) {
        self.mode = mode
        self.angleUnit = angleUnit
        self.rpn = RPNStack(angleUnit: angleUnit)
    }

    public func reset() {
        infix = InfixEditor()
        rpn = RPNStack(angleUnit: angleUnit)
    }

    public func press(_ key: Key) {
        switch mode {
        case .infix: infix.press(key)
        case .rpn: rpn.press(key)
        }
    }

    public func insert(_ value: Decimal128) {
        switch mode {
        case .infix: infix.insert(value)
        case .rpn: rpn.insert(value)
        }
    }

    /// Starts a new infix expression that begins with `value` ("Ans").
    public func startNewExpression(with value: Decimal128?) {
        infix = InfixEditor()
        if let value { infix.insert(value) }
    }

    /// The expression text (infix) or the X entry (RPN).
    public var expressionText: String {
        switch mode {
        case .infix: infix.text
        case .rpn: rpn.text
        }
    }

    public var result: Evaluation {
        switch mode {
        case .infix:
            if infix.isEmpty { return .value(.zero) }
            return Evaluator(angleUnit: angleUnit).evaluate(infix.text)
        case .rpn:
            return rpn.xValue
        }
    }

    public func display(_ evaluation: Evaluation) -> String? {
        switch evaluation {
        case .value(let v): formatter.string(for: v)
        case .incomplete: nil
        case .error: "Error"
        }
    }

    /// One line describing the state, in the format Tools/Oracle prints.
    public var stateLine: String {
        let value: String
        switch result {
        case .value(let v): value = v.decimalNumberDescription
        case .incomplete, .error: value = "nil"
        }
        var fields = ["plain=\(expressionText)", "value=\(value)", "shown=\(display(result).map { $0 == "Error" ? "nil" : $0 } ?? "nil")"]
        if mode == .rpn {
            fields.append("stack=" + rpn.values.map { $0.value?.decimalNumberDescription ?? "nil" }.joined(separator: ","))
        }
        return fields.joined(separator: "\t")
    }
}
