/// Calculator keys. Raw values match the names of Calculate.framework's
/// `CalculateExpression.Operation` getters, so key sequences can be replayed
/// on both implementations.
public enum Key: String, CaseIterable, Sendable {
    case digit0, digit1, digit2, digit3, digit4, digit5, digit6, digit7, digit8, digit9
    case decimal
    case add, subtract, multiply, divide, power
    case equals, clear, allClear, delete, negate, percent
    case openParenthesis, closeParenthesis
    case square, cube, reciprocal, factorial
    case squareRoot, cubeRoot, root
    case exponentialBaseEuler, exponentialBase10, exponentialBase2, exponentialBaseCustom
    case logarithmNatural, logarithmBase10, logarithmBase2, logarithmBaseCustom
    case sine, cosine, tangent, inverseSine, inverseCosine, inverseTangent
    case hyperbolicSine, hyperbolicCosine, hyperbolicTangent
    case inverseHyperbolicSine, inverseHyperbolicCosine, inverseHyperbolicTangent
    case pi, eulerNumber, ee, random
    case enter, swap, drop, rollIn, rollOut

    public var digit: Character? {
        switch self {
        case .digit0: "0"
        case .digit1: "1"
        case .digit2: "2"
        case .digit3: "3"
        case .digit4: "4"
        case .digit5: "5"
        case .digit6: "6"
        case .digit7: "7"
        case .digit8: "8"
        case .digit9: "9"
        default: nil
        }
    }

    var binaryOperator: Character? {
        switch self {
        case .add: "+"
        case .subtract: "-"
        case .multiply: "×"
        case .divide: "÷"
        case .power: "^"
        default: nil
        }
    }

    /// Keys that wrap the last operand in a named function: "sin(x)".
    var functionName: String? {
        switch self {
        case .sine: "sin"
        case .cosine: "cos"
        case .tangent: "tan"
        case .inverseSine: "sin^-1"
        case .inverseCosine: "cos^-1"
        case .inverseTangent: "tan^-1"
        case .hyperbolicSine: "sinh"
        case .hyperbolicCosine: "cosh"
        case .hyperbolicTangent: "tanh"
        case .inverseHyperbolicSine: "sinh^-1"
        case .inverseHyperbolicCosine: "cosh^-1"
        case .inverseHyperbolicTangent: "tanh^-1"
        case .logarithmNatural: "ln"
        case .logarithmBase10: "log"
        case .logarithmBase2: "log2"
        default: nil
        }
    }
}

public enum CalculatorMode: Sendable {
    case infix, rpn
}
