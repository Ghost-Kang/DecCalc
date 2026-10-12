import CBID

/// Outcome of evaluating an expression, mirroring what Calculate.framework reports.
public enum Evaluation: Equatable, Sendable {
    /// A finite value.
    case value(Decimal128)
    /// The expression is incomplete ("3+", "sin()") and has no value yet.
    case incomplete
    /// The computation failed (division by zero, domain error, overflow).
    case error

    public var value: Decimal128? {
        if case .value(let v) = self { return v }
        return nil
    }

    public static func == (lhs: Evaluation, rhs: Evaluation) -> Bool {
        switch (lhs, rhs) {
        case (.value(let a), .value(let b)): return a.bidString == b.bidString
        case (.incomplete, .incomplete), (.error, .error): return true
        default: return false
        }
    }
}

public enum AngleUnit: Sendable {
    case radians, degrees
}

/// Evaluates the plain-text expressions the editor produces, such as "3+sin(4)×2",
/// "50+10%", "root(2, 4)" or "log3(2)", with decimal128 arithmetic.
public struct Evaluator {
    public var angleUnit: AngleUnit

    public init(angleUnit: AngleUnit = .radians) {
        self.angleUnit = angleUnit
    }

    public func evaluate(_ text: String) -> Evaluation {
        var parser = Parser(text: text)
        guard let tree = parser.parseExpression() else { return .incomplete }
        var context = DecimalContext()
        let value = tree.evaluate(in: &context, angleUnit: angleUnit)
        guard let value, value.isFinite, Math.isInDisplayRange(value) else { return .error }
        return .value(value)
    }
}

// MARK: - Syntax tree

indirect enum Node {
    case number(Decimal128)
    case negate(Node)
    case binary(BinaryOperator, Node, Node)
    case percent(Node)
    case factorial(Node)
    case function(Function, Node)
    case root(Node, index: Node)
    case log(Node, base: Node)
}

enum BinaryOperator {
    case add, subtract, multiply, divide, power, modulo
}

enum Function: String, CaseIterable {
    case sin, cos, tan, asin, acos, atan
    case sinh, cosh, tanh, asinh, acosh, atanh
    case ln, log, log2, sqrt, cbrt
}

// MARK: - Parser

/// Recursive-descent parser. Precedence, lowest first:
///   + -   (with "a+b%" meaning a + a×b/100)
///   × ÷ % and implicit multiplication ("2π")
///   unary minus   ("-2^2" is -(2^2))
///   ^     (right associative, exponent may carry a sign: "2^-1")
///   postfix ! and %
///   numbers, constants, ( ), functions, √ ∛
struct Parser {
    private let scalars: [Character]
    private var index = 0

    init(text: String) {
        // Grouping separators carry no meaning; drop them, but keep the comma in root(x, n).
        var characters: [Character] = []
        let source = Array(text)
        for (i, c) in source.enumerated() {
            if c == ",", i + 1 < source.count, source[i + 1].isNumber, i > 0, source[i - 1].isNumber {
                continue
            }
            if c == " " { continue }
            characters.append(c)
        }
        scalars = characters
    }

    mutating func parseExpression() -> Node? {
        guard let node = parseSum(), index == scalars.count else { return nil }
        return node
    }

    private var current: Character? { index < scalars.count ? scalars[index] : nil }

    private mutating func consume(_ c: Character) -> Bool {
        if current == c { index += 1; return true }
        return false
    }

    private mutating func consume(_ word: String) -> Bool {
        let chars = Array(word)
        guard index + chars.count <= scalars.count, Array(scalars[index..<index + chars.count]) == chars else { return false }
        index += chars.count
        return true
    }

    private mutating func parseSum() -> Node? {
        guard var left = parseProduct() else { return nil }
        while let c = current, c == "+" || c == "-" {
            index += 1
            guard let right = parseProduct() else { return nil }
            let op: BinaryOperator = c == "+" ? .add : .subtract
            if case .percent(let p) = right {
                // a ± b% means a ± a×b/100.
                left = .binary(op, left, .binary(.multiply, left, .percent(p)))
            } else {
                left = .binary(op, left, right)
            }
        }
        return left
    }

    /// A product chain: factors joined by ×, ÷, % and implicit multiplication.
    /// A "%" between operands means "percent of" when its left factor came after
    /// an explicit × or ÷ ("3×17%945" is 3 × 0.17 × 945); otherwise it is the
    /// modulo of the product so far ("17%945" is 17, "3×17%945%3" is 1.95).
    private mutating func parseProduct() -> Node? {
        guard var left = parseUnary() else { return nil }
        var lastFactorFollowsMulDiv = false
        while true {
            if consume("×") {
                guard let right = parseUnary() else { return nil }
                left = .binary(.multiply, left, right)
                lastFactorFollowsMulDiv = true
            } else if consume("÷") {
                guard let right = parseUnary() else { return nil }
                left = .binary(.divide, left, right)
                lastFactorFollowsMulDiv = true
            } else if current == "%" {
                index += 1
                guard let right = parseUnary() else { return nil }
                if lastFactorFollowsMulDiv, case .binary(let op, let a, let b) = left, op == .multiply || op == .divide {
                    left = .binary(.multiply, .binary(op, a, .percent(b)), right)
                } else {
                    left = .binary(.modulo, left, right)
                }
                lastFactorFollowsMulDiv = false
            } else if startsOperand {
                guard let right = parsePower() else { return nil }
                left = .binary(.multiply, left, right)
                lastFactorFollowsMulDiv = false
            } else {
                return left
            }
        }
    }

    private var startsOperand: Bool {
        guard let c = current else { return false }
        return c.isNumber || c == "." || c == "(" || c == "π" || c == "𝑒" || c == "√" || c == "∛" || c.isLetter
    }

    private mutating func parseUnary() -> Node? {
        if consume("-") {
            guard let operand = parseUnary() else { return nil }
            return .negate(operand)
        }
        return parsePower()
    }

    /// Set while parsing an exponent: a trailing "%" then belongs to the whole power ("8^26%" is (8^26)%).
    private var inExponent = false

    private mutating func parsePower() -> Node? {
        guard let base = parsePostfix() else { return nil }
        if consume("^") {
            let outer = inExponent
            inExponent = true
            let exponent = parseUnary()
            inExponent = outer
            guard let exponent else { return nil }
            var power = Node.binary(.power, base, exponent)
            if !inExponent {
                while current == "%" && !nextStartsOperand(after: index + 1) {
                    index += 1
                    power = .percent(power)
                }
            }
            return power
        }
        return base
    }

    private mutating func parsePostfix() -> Node? {
        guard var node = parsePrimary() else { return nil }
        while true {
            if consume("!") {
                node = .factorial(node)
            } else if current == "%" && !inExponent && !nextStartsOperand(after: index + 1) {
                index += 1
                node = .percent(node)
            } else {
                return node
            }
        }
    }

    private func nextStartsOperand(after position: Int) -> Bool {
        guard position < scalars.count else { return false }
        let c = scalars[position]
        return c.isNumber || c == "." || c == "(" || c == "π" || c == "𝑒" || c == "√" || c == "∛" || c.isLetter
    }

    private mutating func parsePrimary() -> Node? {
        guard let c = current else { return nil }
        if c.isNumber || c == "." { return parseNumber() }
        if consume("π") { return .number(Constants.pi) }
        if consume("𝑒") { return .number(Constants.e) }
        if consume("√") { return parseRadicand().map { .function(.sqrt, $0) } }
        if consume("∛") { return parseRadicand().map { .function(.cbrt, $0) } }
        if consume("(") {
            guard let inner = parseSum(), consume(")") else { return nil }
            return inner
        }
        return parseNamedFunction()
    }

    /// The operand of a prefix radical: another radical or a postfix-free primary ("√2", "√√2", "√(3+4)").
    private mutating func parseRadicand() -> Node? {
        parsePrimary()
    }

    private mutating func parseNamedFunction() -> Node? {
        if consume("root(") {
            guard let radicand = parseSum(), consume(","), let index = parseSum(), consume(")") else { return nil }
            return .root(radicand, index: index)
        }
        // Longest names first so "sinh" is not read as "sin".
        let names: [(String, Function)] = [
            ("sinh^-1", .asinh), ("cosh^-1", .acosh), ("tanh^-1", .atanh),
            ("sin^-1", .asin), ("cos^-1", .acos), ("tan^-1", .atan),
            ("sinh", .sinh), ("cosh", .cosh), ("tanh", .tanh),
            ("sin", .sin), ("cos", .cos), ("tan", .tan),
            ("ln", .ln), ("log2", .log2),
        ]
        for (name, function) in names where consume(name + "(") {
            return parseCallArgument().map { .function(function, $0) }
        }
        if consume("log") {
            // "log(x)" is base 10; "log3(x)" carries its base before the parenthesis.
            var baseDigits = ""
            while let c = current, c.isNumber || c == "." { baseDigits.append(c); index += 1 }
            guard consume("(") else { return nil }
            guard let argument = parseCallArgument() else { return nil }
            if baseDigits.isEmpty { return .function(.log, argument) }
            guard let base = Decimal128(baseDigits) else { return nil }
            return .log(argument, base: .number(base))
        }
        return nil
    }

    private mutating func parseCallArgument() -> Node? {
        guard let argument = parseSum(), consume(")") else { return nil }
        return argument
    }

    private mutating func parseNumber() -> Node? {
        var text = ""
        while let c = current, c.isNumber || c == "." {
            text.append(c)
            index += 1
        }
        // Scientific entry: "2e3", "2e-3".
        if current == "e" {
            var exponent = "e"
            var probe = index + 1
            if probe < scalars.count, scalars[probe] == "-" { exponent.append("-"); probe += 1 }
            var hasDigits = false
            while probe < scalars.count, scalars[probe].isNumber {
                exponent.append(scalars[probe]); probe += 1; hasDigits = true
            }
            if hasDigits {
                text += exponent
                index = probe
            }
        }
        if text.hasSuffix(".") { text.append("0") }
        if text.hasPrefix(".") { text = "0" + text }
        return Decimal128(text).map { .number($0) }
    }
}

// MARK: - Evaluation

enum Constants {
    /// π as Calculate.framework reads it: a 36-digit string rounded half away from zero.
    static let pi = Decimal128(roundingHalfAway: "3.14159265358979323846264338327950288")
    static let e = Decimal128("2.718281828459045235360287471352662")!
    static let hundred = Decimal128(100)
    static let oneEighty = Decimal128(180)
    static let two = Decimal128(2)
    static let ten = Decimal128(10)
    /// Degree/radian factors, computed once with half-away rounding like the framework.
    static let toRadians = Decimal128.divideRoundingHalfAway(pi, oneEighty)
    static let toDegrees = Decimal128.divideRoundingHalfAway(oneEighty, pi)
    /// Results must fit binary64's normal range, as in Calculate.framework.
    static let largestMagnitude = Decimal128("1.79769313345E+308")!
    static let smallestMagnitude = Decimal128("2.2250738585072014E-308")!
    /// Factorials (Γ(x+1)) are only defined up to this argument.
    static let largestFactorialArgument = Decimal128(103)
    /// Results of trigonometric functions within ±1e-31 are reported as exactly zero.
    static let trigZeroThreshold = Decimal128("1E-31")!
    /// Results of tangent beyond ±1e31 are treated as a pole.
    static let trigInfThreshold = Decimal128("1E+31")!
}

extension Node {
    /// Evaluates the tree; nil means an error. Any non-finite intermediate value
    /// (log(0), a pole of tan) is an error, as in Calculate.framework.
    func evaluate(in context: inout DecimalContext, angleUnit: AngleUnit) -> Decimal128? {
        guard let value = evaluateUnchecked(in: &context, angleUnit: angleUnit), value.isFinite else { return nil }
        return value
    }

    private func evaluateUnchecked(in context: inout DecimalContext, angleUnit: AngleUnit) -> Decimal128? {
        switch self {
        case .number(let value):
            return value
        case .negate(let operand):
            return operand.evaluate(in: &context, angleUnit: angleUnit)?.negated
        case .percent(let operand):
            guard let value = operand.evaluate(in: &context, angleUnit: angleUnit) else { return nil }
            return context.div(value, Constants.hundred)
        case .factorial(let operand):
            guard let value = operand.evaluate(in: &context, angleUnit: angleUnit) else { return nil }
            return Math.factorial(value, in: &context)
        case .binary(let op, let lhs, let rhs):
            guard let a = lhs.evaluate(in: &context, angleUnit: angleUnit),
                  let b = rhs.evaluate(in: &context, angleUnit: angleUnit) else { return nil }
            switch op {
            case .add: return context.add(a, b)
            case .subtract: return context.sub(a, b)
            case .multiply: return context.mul(a, b)
            case .divide:
                if b.isZero { return nil }
                return context.div(a, b)
            case .power: return Math.power(a, b, in: &context)
            case .modulo:
                // Floored modulo: the result takes the divisor's sign ("-794%4" is 2).
                if b.isZero { return nil }
                let r = context.fmod(a, b)
                if !r.isZero && r.isNegative != b.isNegative { return context.add(r, b) }
                return r
            }
        case .function(let function, let operand):
            guard let x = operand.evaluate(in: &context, angleUnit: angleUnit) else { return nil }
            return Math.apply(function, to: x, angleUnit: angleUnit, in: &context)
        case .root(let radicand, let index):
            guard let x = radicand.evaluate(in: &context, angleUnit: angleUnit),
                  let n = index.evaluate(in: &context, angleUnit: angleUnit) else { return nil }
            return Math.root(x, n, in: &context)
        case .log(let argument, let base):
            guard let x = argument.evaluate(in: &context, angleUnit: angleUnit),
                  let b = base.evaluate(in: &context, angleUnit: angleUnit) else { return nil }
            return Math.logarithm(x, base: b, in: &context)
        }
    }
}

enum Math {
    static func isInDisplayRange(_ value: Decimal128) -> Bool {
        if value.isZero { return true }
        var context = DecimalContext()
        let magnitude = value.magnitude
        return !context.greater(magnitude, Constants.largestMagnitude)
            && !context.less(magnitude, Constants.smallestMagnitude)
    }

    /// log_b(x) = log10(x) ÷ log10(b), the form Calculate.framework uses.
    static func logarithm(_ x: Decimal128, base b: Decimal128, in context: inout DecimalContext) -> Decimal128? {
        let denominator = context.log10(b)
        if denominator.isZero { return nil }
        return context.div(context.log10(x), denominator)
    }

    static func power(_ a: Decimal128, _ b: Decimal128, in context: inout DecimalContext) -> Decimal128? {
        if a.isZero && b.isNegative { return nil }
        return context.pow(a, b)
    }

    static func root(_ x: Decimal128, _ n: Decimal128, in context: inout DecimalContext) -> Decimal128? {
        if n.isZero { return nil }
        if x.isNegative {
            // Odd integer roots of negative numbers are real.
            guard n.isInteger, !context.equal(context.fmod(n, Decimal128(2)), .zero) else { return nil }
            let positive = context.pow(x.negated, context.div(.one, n))
            return positive.negated
        }
        return context.pow(x, context.div(.one, n))
    }

    /// x! = Γ(x+1), rounded to a whole number for whole x — the framework's method,
    /// which is why 30! comes out as 265252859812191058636308479999998.
    static func factorial(_ x: Decimal128, in context: inout DecimalContext) -> Decimal128? {
        if context.greater(x, Constants.largestFactorialArgument) { return nil }
        if x.isInteger && x.isNegative { return nil }
        let gamma = Decimal128(raw: cbid128_tgamma(context.add(x, .one).raw, context.rounding, &context.flags))
        guard gamma.isFinite else { return nil }
        if x.isInteger {
            return Decimal128(raw: cbid128_round_integral_nearest_even(gamma.raw, &context.flags))
        }
        return gamma
    }

    static func apply(_ function: Function, to x: Decimal128, angleUnit: AngleUnit,
                      in context: inout DecimalContext) -> Decimal128? {
        switch function {
        case .sin, .cos, .tan:
            let radians = angleUnit == .degrees ? context.mul(x, Constants.toRadians) : x
            let sine = { (c: inout DecimalContext) in
                snapToZero(Decimal128(raw: cbid128_sin(radians.raw, c.rounding, &c.flags)), in: &c)
            }
            let cosine = { (c: inout DecimalContext) in
                snapToZero(Decimal128(raw: cbid128_cos(radians.raw, c.rounding, &c.flags)), in: &c)
            }
            switch function {
            case .sin: return sine(&context)
            case .cos: return cosine(&context)
            default:
                if angleUnit == .degrees, cosine(&context).isZero { return nil }
                let value = Decimal128(raw: cbid128_tan(radians.raw, context.rounding, &context.flags))
                if !context.less(value.magnitude, Constants.trigInfThreshold) { return nil }
                return snapToZero(value, in: &context)
            }
        case .asin, .acos, .atan:
            let raw: CBIDDecimal128
            switch function {
            case .asin: raw = cbid128_asin(x.raw, context.rounding, &context.flags)
            case .acos: raw = cbid128_acos(x.raw, context.rounding, &context.flags)
            default: raw = cbid128_atan(x.raw, context.rounding, &context.flags)
            }
            let value = Decimal128(raw: raw)
            return angleUnit == .degrees ? context.mul(value, Constants.toDegrees) : value
        case .sinh: return context.unary(cbid128_sinh, x)
        case .cosh: return context.unary(cbid128_cosh, x)
        case .tanh: return context.unary(cbid128_tanh, x)
        case .asinh: return context.unary(cbid128_asinh, x)
        case .acosh: return context.unary(cbid128_acosh, x)
        case .atanh: return context.unary(cbid128_atanh, x)
        case .ln: return context.ln(x)
        case .log: return context.log10(x)
        case .log2: return logarithm(x, base: Constants.two, in: &context)
        case .sqrt: return x.isNegative ? nil : context.sqrt(x)
        case .cbrt: return context.cbrt(x)
        }
    }

    static func snapToZero(_ value: Decimal128, in context: inout DecimalContext) -> Decimal128 {
        if !context.greater(value.magnitude, Constants.trigZeroThreshold) { return .zero }
        return value
    }
}
