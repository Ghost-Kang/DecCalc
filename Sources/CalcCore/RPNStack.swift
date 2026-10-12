/// Reverse Polish entry, reproducing Calculate.framework's RPN format.
///
/// Each stack entry is either text the user is typing ("12.5") or a computed value
/// stored as a 34-digit decimal literal ("3333333333333333333333333333333333E-34"),
/// so no precision is lost between steps. Operations work on the top entry X and the
/// one below it, Y.
public struct RPNStack: Sendable {
    enum Entry: Sendable, Equatable {
        case typed(String)
        case computed(Decimal128)
        case constant(String)
        /// The 0 left by an error or AC: shown as 0, ignored by functions and Enter.
        case blank

        static func == (lhs: Entry, rhs: Entry) -> Bool {
            switch (lhs, rhs) {
            case (.typed(let a), .typed(let b)), (.constant(let a), .constant(let b)): return a == b
            case (.computed(let a), .computed(let b)): return a.bidString == b.bidString
            case (.blank, .blank): return true
            default: return false
            }
        }
    }

    var entries: [Entry] = []
    /// The next digit starts a new entry (after an operation).
    var pushOnInput = false
    /// The next digit replaces X (after Enter duplicated it).
    var replaceOnInput = false
    public var angleUnit: AngleUnit

    public init(angleUnit: AngleUnit = .radians) {
        self.angleUnit = angleUnit
    }

    public var count: Int { entries.count }

    /// Values from the bottom of the stack to X.
    public var values: [Evaluation] { entries.map(value(of:)) }

    /// Text of X as `plain.text` shows it.
    public var text: String {
        guard let x = entries.last else { return "0" }
        switch x {
        case .typed(let t): return Literal.render(t, grouping: true)
        case .computed(let d): return d.literal
        case .constant(let c): return c
        case .blank: return "0"
        }
    }

    public var xValue: Evaluation {
        entries.last.map(value(of:)) ?? .value(.zero)
    }

    func value(of entry: Entry) -> Evaluation {
        switch entry {
        case .computed(let d): return .value(d)
        case .typed(let t): return Evaluator(angleUnit: angleUnit).evaluate(Literal.render(t, grouping: false))
        case .constant(let c): return Evaluator(angleUnit: angleUnit).evaluate(c)
        case .blank: return .value(.zero)
        }
    }

    /// Pushes a number (memory recall) the way a constant is entered.
    public mutating func insert(_ value: Decimal128) {
        if !replaceOnInput { pushOnInput = true }
        pushInput(.computed(value))
    }

    /// True while X is text the user is typing (so the display shows it verbatim).
    public var xIsBeingTyped: Bool {
        if case .typed = entries.last { return !pushOnInput && !replaceOnInput }
        return false
    }

    /// Values of the stack entries, from X downward.
    public var valuesFromTop: [Evaluation] { values.reversed() }

    // MARK: Keys

    public mutating func press(_ key: Key) {
        if let digit = key.digit { typeCharacter(digit); return }
        switch key {
        case .decimal: typeCharacter(".")
        case .ee: typeExponent()
        case .enter: enter()
        case .add, .subtract, .multiply, .divide, .power, .exponentialBaseCustom, .root, .logarithmBaseCustom:
            binary(key)
        case .percent: percent()
        case .negate: negate()
        case .clear: clearX()
        case .allClear: self = RPNStack(angleUnit: angleUnit); entries = [.blank]; replaceOnInput = true
        case .delete: deleteBackward()
        case .swap: swap()
        case .drop: drop()
        case .rollIn: rollIn()
        case .rollOut: rollOut()
        case .pi: pushConstant("π")
        case .eulerNumber: pushConstant("𝑒")
        case .random:
            let digits = (0..<8).map { _ in String(Int.random(in: 0...9)) }.joined()
            pushInput(.typed("0." + digits))
        case .equals, .openParenthesis, .closeParenthesis:
            break
        default:
            unary(key)
        }
    }

    private mutating func pushInput(_ entry: Entry) {
        if entries.isEmpty || pushOnInput {
            entries.append(entry)
        } else {
            entries[entries.count - 1] = entry
        }
        pushOnInput = false
        replaceOnInput = false
    }

    /// Constants start a new entry unless Enter just duplicated X.
    private mutating func pushConstant(_ symbol: String) {
        if !replaceOnInput { pushOnInput = true }
        pushInput(.constant(symbol))
    }

    private mutating func typeCharacter(_ c: Character) {
        let start = Entry.typed(c == "." ? "0." : String(c))
        if entries.isEmpty || pushOnInput || replaceOnInput {
            pushInput(start)
            return
        }
        guard case .typed(let text) = entries[entries.count - 1] else {
            // Typing after a constant starts a new entry.
            pushOnInput = true
            pushInput(start)
            return
        }
        if c == "." {
            if text.contains(".") || text.contains("e") { return }
            entries[entries.count - 1] = .typed(text + ".")
        } else if let e = text.firstIndex(of: "e"), text[text.index(after: e)...].filter(\.isNumber).count >= 3 {
            return // Exponents take at most three digits.
        } else if text == "-0" {
            // A sign typed on an empty entry keeps the zero: "-04".
            entries[entries.count - 1] = .typed(text + String(c))
        } else {
            entries[entries.count - 1] = .typed(Literal.append(c, to: text))
        }
    }

    /// EE adds an exponent to X while X is typed text, even after a stack move;
    /// otherwise it starts a new "0e" entry.
    private mutating func typeExponent() {
        if !replaceOnInput, case .typed(let text) = entries.last {
            if !text.contains("e") { entries[entries.count - 1] = .typed(text + "e") }
            pushOnInput = false
            return
        }
        pushInput(.typed("0e"))
    }

    /// The placeholder an operation leaves on an empty stack; the next input replaces it.
    private mutating func placeholderForEmptyStack() {
        entries.append(.computed(Decimal128("0E+0")!))
        pushOnInput = false
        replaceOnInput = true
    }

    private mutating func enter() {
        if case .blank = entries.last { return }
        if entries.isEmpty { entries.append(.computed(Decimal128("0E+0")!)) }
        entries.append(entries[entries.count - 1])
        pushOnInput = false
        replaceOnInput = true
    }

    /// Replaces the top `consumed` entries with a computed result. A failed
    /// operation leaves 0, which the next input replaces.
    private mutating func finish(_ result: Decimal128?, consumed: Int) {
        entries.removeLast(min(consumed, entries.count))
        if let result, result.isFinite, Math.isInDisplayRange(result) {
            entries.append(.computed(result.isZero ? Decimal128("0E+0")! : result))
            pushOnInput = true
            replaceOnInput = false
        } else {
            entries.append(.blank)
            pushOnInput = false
            replaceOnInput = true
        }
    }

    private mutating func binary(_ key: Key) {
        if entries.isEmpty {
            placeholderForEmptyStack()
            return
        }
        guard entries.count >= 2,
              let y = value(of: entries[entries.count - 2]).value,
              let x = value(of: entries[entries.count - 1]).value else { return }
        var context = DecimalContext()
        let result: Decimal128?
        switch key {
        case .add: result = context.add(y, x)
        case .subtract: result = context.sub(y, x)
        case .multiply: result = context.mul(y, x)
        case .divide: result = x.isZero ? nil : context.div(y, x)
        case .power: result = Math.power(x, y, in: &context)
        case .exponentialBaseCustom: result = Math.power(y, x, in: &context)
        case .root: result = Math.root(x, y, in: &context)
        default:
            // log_Y(X)
            let denominator = context.ln(y)
            result = denominator.isZero ? nil : context.div(context.ln(x), denominator)
        }
        finish(result, consumed: 2)
    }

    private mutating func percent() {
        if entries.isEmpty {
            entries.append(.computed(Decimal128("0E+0")!))
            pushOnInput = true
            replaceOnInput = false
            return
        }
        guard let x = entries.last.map(value(of:))?.value else { return }
        var context = DecimalContext()
        if entries.count >= 2, let y = value(of: entries[entries.count - 2]).value {
            // X% of Y, computed as Y×X÷100; Y stays on the stack.
            entries[entries.count - 1] = .computed(Self.canonicalZero(context.div(context.mul(y, x), Constants.hundred)))
        } else {
            entries[entries.count - 1] = .computed(Self.canonicalZero(context.div(x, Constants.hundred)))
        }
        pushOnInput = true
        replaceOnInput = false
    }

    private mutating func unary(_ key: Key) {
        if entries.isEmpty { entries.append(.computed(Decimal128("0E+0")!)) }
        if case .blank = entries[entries.count - 1] { return }
        let xIsTypedZero = entries[entries.count - 1] == .typed("0")
        guard let x = value(of: entries[entries.count - 1]).value else { return }
        let operand = Node.number(x)
        let node: Node
        switch key {
        case .sine: node = .function(.sin, operand)
        case .cosine: node = .function(.cos, operand)
        case .tangent: node = .function(.tan, operand)
        case .inverseSine: node = .function(.asin, operand)
        case .inverseCosine: node = .function(.acos, operand)
        case .inverseTangent: node = .function(.atan, operand)
        case .hyperbolicSine: node = .function(.sinh, operand)
        case .hyperbolicCosine: node = .function(.cosh, operand)
        case .hyperbolicTangent: node = .function(.tanh, operand)
        case .inverseHyperbolicSine: node = .function(.asinh, operand)
        case .inverseHyperbolicCosine: node = .function(.acosh, operand)
        case .inverseHyperbolicTangent: node = .function(.atanh, operand)
        case .logarithmNatural: node = .function(.ln, operand)
        case .logarithmBase10: node = .function(.log, operand)
        case .logarithmBase2: node = .function(.log2, operand)
        case .squareRoot: node = .function(.sqrt, operand)
        case .cubeRoot: node = .function(.cbrt, operand)
        case .square: node = .binary(.power, operand, .number(Decimal128(2)))
        case .cube: node = .binary(.power, operand, .number(Decimal128(3)))
        case .factorial: node = .factorial(operand)
        case .reciprocal: node = .binary(.divide, .number(.one), operand)
        case .exponentialBaseEuler: node = .binary(.power, .number(Constants.e), operand)
        case .exponentialBase10: node = .binary(.power, .number(Decimal128(10)), operand)
        case .exponentialBase2: node = .binary(.power, .number(Decimal128(2)), operand)
        default: return
        }
        var context = DecimalContext()
        let result = node.evaluate(in: &context, angleUnit: angleUnit)
        if xIsTypedZero, let result, result.isZero { return } // "0" stays as typed
        finish(result, consumed: 1)
    }

    static func canonicalZero(_ value: Decimal128) -> Decimal128 {
        value.isZero ? Decimal128("0E+0")! : value
    }

    private mutating func negate() {
        guard let last = entries.last else {
            entries.append(.typed("-0"))
            return
        }
        switch last {
        case .typed(let text):
            if text == "0" { return }
            entries[entries.count - 1] = .typed(text.hasPrefix("-") ? String(text.dropFirst()) : "-" + text)
            // Negating the copy Enter made continues editing it.
            pushOnInput = false
            replaceOnInput = false
        case .computed(let d) where replaceOnInput && d.isZero:
            // The placeholder 0 becomes a "-0" entry that typing extends: "-05".
            entries[entries.count - 1] = .typed("-0")
            replaceOnInput = false
        case .computed(let d):
            entries[entries.count - 1] = .computed(d.negated)
        case .blank:
            break
        case .constant:
            if let v = value(of: last).value { entries[entries.count - 1] = .computed(v.negated) }
        }
    }

    private mutating func clearX() {
        if entries.isEmpty { entries.append(.typed("0")) } else { entries[entries.count - 1] = .typed("0") }
        pushOnInput = false
        replaceOnInput = true
    }

    /// Delete removes the last character of X. A computed X is first turned
    /// into its displayed text ("1603.041" → "1603.04").
    private mutating func deleteBackward() {
        guard let last = entries.last else { return }
        var text: String
        switch last {
        case .typed(let t):
            text = t
        case .computed(let d):
            text = DisplayFormatter(usesGrouping: false).string(for: d)
            if text.contains("×") { text = d.plainDescription }
        case .constant, .blank:
            entries[entries.count - 1] = .typed("0")
            pushOnInput = false
            replaceOnInput = true
            return
        }
        text.removeLast()
        if text.isEmpty || text == "-" {
            entries[entries.count - 1] = .typed("0")
            pushOnInput = false
            replaceOnInput = true
        } else {
            entries[entries.count - 1] = .typed(text)
            pushOnInput = false
            replaceOnInput = false
        }
    }

    /// Stack moves on an empty stack leave a placeholder (which the next input
    /// replaces after Swap and pushes past after a roll); with one entry they only
    /// make the next input start a new entry.
    private mutating func stackMove(replacingPlaceholder: Bool = false, _ move: (inout [Entry]) -> Void) {
        if entries.isEmpty {
            placeholderForEmptyStack()
            if !replacingPlaceholder {
                pushOnInput = true
                replaceOnInput = false
            }
            return
        }
        if entries.count >= 2 { move(&entries) }
        pushOnInput = true
        replaceOnInput = false
    }

    private mutating func swap() {
        // With a single entry Swap does nothing at all; typing continues in X.
        if entries.count == 1 { return }
        stackMove(replacingPlaceholder: true) { $0.swapAt($0.count - 1, $0.count - 2) }
    }

    private mutating func drop() {
        guard !entries.isEmpty else { return }
        entries.removeLast()
        pushOnInput = true
        replaceOnInput = false
    }

    /// Moves X to the bottom (R↓).
    private mutating func rollIn() {
        stackMove { $0.insert($0.removeLast(), at: 0) }
    }

    /// Moves the bottom entry to X (R↑).
    private mutating func rollOut() {
        stackMove { $0.append($0.removeFirst()) }
    }
}
