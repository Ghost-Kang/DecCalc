/// Key-driven editor for infix expressions. It reproduces how Calculate.framework's
/// `CalculateExpression` turns key presses into expression text: functions wrap the
/// last operand ("3+4 sin" → "3+sin(4)"), a digit after a finished operand inserts
/// an implicit "×", unbalanced parentheses are closed in the text, and so on.
public struct InfixEditor: Sendable {
    /// The top-level sequence; open groups and function calls nest inside it.
    var root = Group(closed: true)
    /// A node whose numeric parameter (root index, log base, power base) the next digits fill in.
    var pendingParameter = false
    /// True right after "=": delete then removes the whole last operand.
    var justEvaluated = false

    public init() {}

    public var isEmpty: Bool { root.items.isEmpty }

    /// The plain-text form, as `CalculateExpression.plain.text` renders it.
    public var text: String {
        let rendered = root.render(grouping: true)
        return rendered.isEmpty ? "0" : rendered
    }

    /// Inserts a number as a literal operand (memory recall, the previous answer),
    /// with an implicit "×" after a finished operand.
    public mutating func insert(_ value: Decimal128) {
        pendingParameter = false
        justEvaluated = false
        let text = value.plainDescription
        root.withInnermost { group in
            if text.hasPrefix("-") {
                group.insertOperand(.negated(.literal(String(text.dropFirst()))))
            } else {
                group.insertOperand(.literal(text))
            }
        }
    }

    public mutating func press(_ key: Key) {
        let wasEvaluated = justEvaluated
        justEvaluated = false
        if pendingParameter {
            let consumed = root.withInnermost { $0.fillParameter(with: key) }
            if consumed { return }
            root.withInnermost { $0.finishParameter(endedBy: key) }
        }
        pendingParameter = false

        if let digit = key.digit {
            root.withInnermost { $0.typeDigit(digit) }
            return
        }
        if let symbol = key.binaryOperator {
            root.withInnermost { $0.typeOperator(symbol, isTopLevel: $1) }
            return
        }
        if let name = key.functionName {
            root.withInnermost { $0.applyFunction(name, isTopLevel: $1 && !wasEvaluated) }
            return
        }
        switch key {
        case .decimal:
            root.withInnermost { $0.typeDecimal() }
        case .equals:
            justEvaluated = true
        case .allClear:
            self = InfixEditor()
        case .clear:
            root.clearLastOperand()
        case .delete:
            if wasEvaluated, case .operand(let o) = root.items.last, !(o.isCall) {
                root.clearLastOperand()
            } else {
                root.deleteBackward()
            }
        case .negate:
            root.withInnermost { $0.negateLast(isTopLevel: $1) }
        case .percent:
            root.withInnermost { $0.applyPercent(isTopLevel: $1) }
        case .openParenthesis:
            root.withInnermost { $0.openGroup(isTopLevel: $1) }
        case .closeParenthesis:
            // Closing a radical typed before its radicand turns it into ʸ√x awaiting the index.
            pendingParameter = root.closeInnermost()
        case .square:
            root.withInnermost { $0.applyPostfix("^2", isTopLevel: $1) }
        case .cube:
            root.withInnermost { $0.applyPostfix("^3", isTopLevel: $1) }
        case .factorial:
            root.withInnermost { $0.applyPostfix("!", isTopLevel: $1) }
        case .reciprocal:
            root.withInnermost { $0.applyReciprocal(isTopLevel: $1) }
        case .squareRoot:
            root.withInnermost { $0.applyPrefix("√") }
        case .cubeRoot:
            root.withInnermost { $0.applyPrefix("∛") }
        case .root where root.withInnermost({ $0.lastOperand == nil }):
            root.withInnermost { $0.applyPrefix("√") }
        case .logarithmBaseCustom where root.withInnermost({ $0.lastOperand == nil }):
            root.withInnermost { $0.applyFunction("log") }
        case .exponentialBaseCustom where root.withInnermost({ $0.lastOperand == nil }):
            // On an empty slot the exponent defaults to 0 and the base comes next: "25^0".
            // Right after an operator the key does nothing.
            pendingParameter = root.withInnermost { group -> Bool in
                guard group.items.isEmpty else { return false }
                group.items.append(.operand(.parameterized(.customPower(base: ""), .literal("0"))))
                return true
            }
        case .exponentialBaseEuler:
            root.withInnermost { $0.applyPower(base: "𝑒", isTopLevel: $1) }
        case .exponentialBase10:
            root.withInnermost { $0.applyPower(base: "10", isTopLevel: $1) }
        case .exponentialBase2:
            root.withInnermost { $0.applyPower(base: "2", isTopLevel: $1) }
        case .root:
            pendingParameter = root.withInnermost { $0.applyParameterized(.root(index: "")) }
        case .logarithmBaseCustom:
            pendingParameter = root.withInnermost { $0.applyParameterized(.log(base: "")) }
        case .exponentialBaseCustom:
            pendingParameter = root.withInnermost { $0.applyParameterized(.customPower(base: "")) }
        case .pi:
            root.withInnermost { $0.typeConstant("π") }
        case .eulerNumber:
            root.withInnermost { $0.typeConstant("𝑒") }
        case .random:
            root.withInnermost { $0.typeRandom() }
        case .ee:
            root.withInnermost { $0.startExponent() }
        default:
            break // RPN-only keys have no effect on an infix expression.
        }
    }
}

// MARK: - Model

enum Item: Sendable {
    case operand(Operand)
    /// A binary operator: + - × ÷ ^ %.
    case op(Character)
    /// A leading minus sign: "-4", "3×-4".
    case sign
    /// A "×" the editor inserted between adjacent operands; C removes it with the operand.
    case implicitTimes
}

enum Parameterized: Sendable {
    case root(index: String)
    case log(base: String)
    case customPower(base: String)
}

indirect enum Operand: Sendable {
    /// Digits as typed, e.g. "1.500" or "2e-3" (an "e" with no digits yet is hidden).
    case literal(String)
    case constant(String)
    /// A literal directly followed by a constant: "2π".
    case juxtaposed(String, String)
    case group(Group)
    /// "sin(...)": the argument is a group whose parentheses are the call's.
    case call(String, Group)
    case prefix(String, Operand)
    case postfix(Operand, String)
    case power(base: String, Operand)
    case reciprocal(Operand)
    case negated(Operand)
    case parameterized(Parameterized, Operand)
    case random(String)
    /// A radical typed before its radicand: "√86", "√(7+2)", or just "√" while empty.
    case radical(String, Group)
    /// An operand with the leading minus sign a function absorbed: the "-56" in "sin(-56)".
    case signed(Operand)

    var isCall: Bool {
        if case .call = self { return true }
        return false
    }

    var isLiteral: Bool {
        if case .literal = self { return true }
        return false
    }

    /// An operand that is still being built and accepts more digits.
    var isOpenLiteral: Bool { isLiteral }
}

struct Group: Sendable {
    var items: [Item] = []
    var closed: Bool

    init(items: [Item] = [], closed: Bool) {
        self.items = items
        self.closed = closed
    }

    // MARK: Navigation

    /// Runs `body` on the innermost open group (an unclosed parenthesis or function call),
    /// passing whether that group is the top level.
    @discardableResult
    mutating func withInnermost<T>(_ body: (inout Group, Bool) -> T) -> T {
        withInnermost(isTopLevel: true, body)
    }

    @discardableResult
    mutating func withInnermost<T>(_ body: (inout Group) -> T) -> T {
        withInnermost(isTopLevel: true) { group, _ in body(&group) }
    }

    private mutating func withInnermost<T>(isTopLevel: Bool, _ body: (inout Group, Bool) -> T) -> T {
        if let last = items.indices.last, case .operand(var operand) = items[last], operand.hasOpenGroup {
            let result = operand.withOpenGroup { $0.withInnermost(isTopLevel: false, body) }
            items[last] = .operand(operand)
            return result
        }
        return body(&self, isTopLevel)
    }

    /// Closes the innermost unclosed group, dropping a dangling operator first.
    /// Returns true when a radical became ʸ√x and now waits for its index.
    @discardableResult
    mutating func closeInnermost() -> Bool {
        guard let last = items.indices.last, case .operand(var operand) = items[last], operand.hasOpenGroup else { return false }
        if case .radical(_, let g) = operand, !g.items.isEmpty,
           !(g.items.last.map { if case .operand(let o) = $0 { return o.hasOpenGroup } else { return false } } ?? false) {
            var content = g
            if case .op = content.items.last { content.items.removeLast() }
            if case .sign = content.items.last { content.items.removeLast() }
            content.closed = true
            let radicand: Operand
            if content.items.count == 1, case .operand(let only) = content.items[0] {
                radicand = only
            } else {
                radicand = .group(content)
            }
            items[last] = .operand(.parameterized(.root(index: ""), radicand))
            return true
        }
        var converted = false
        _ = operand.withOpenGroup { inner -> Bool in
            if let lastInner = inner.items.indices.last, case .operand(var nested) = inner.items[lastInner],
               nested.hasOpenGroup {
                if case .radical = nested {
                    var holder = Group(items: [.operand(nested)], closed: true)
                    converted = holder.closeInnermost()
                    inner.items[lastInner] = holder.items[0]
                    return true
                }
                nested.withOpenGroup { converted = $0.closeInnermost() }
                inner.items[lastInner] = .operand(nested)
                return true
            }
            if inner.items.isEmpty { return true }
            if let lastItem = inner.items.last {
                switch lastItem {
                case .op, .sign, .implicitTimes: inner.items.removeLast()
                case .operand: break
                }
            }
            inner.closed = true
            return true
        }
        items[last] = .operand(operand)
        return converted
    }

    // MARK: Queries

    var lastOperand: Operand? {
        if case .operand(let o) = items.last { return o }
        return nil
    }

    var endsWithOperator: Bool {
        switch items.last {
        case .op, .sign, .implicitTimes: return true
        default: return false
        }
    }

    private mutating func replaceLastOperand(_ operand: Operand) {
        items[items.count - 1] = .operand(operand)
    }

    /// The last operand for a wrapping function. A minus sign right before it
    /// becomes part of the argument, as the framework does: "-56 sin" is "sin(-56)".
    private mutating func takeLastOperandForFunction() -> Operand? {
        guard let operand = lastOperand else { return nil }
        if items.count >= 2, case .sign = items[items.count - 2] {
            items.remove(at: items.count - 2)
            return .signed(operand)
        }
        return operand
    }

    /// Functions typed after eˣ, 10ˣ or 2ˣ apply to the exponent: "𝑒^cos(974)".
    private mutating func applyInsideExponent(_ wrap: (Operand) -> Operand) -> Bool {
        guard case .power(let base, let exponent) = lastOperand else { return false }
        replaceLastOperand(.power(base: base, wrap(exponent)))
        return true
    }

    mutating func insertOperand(_ operand: Operand) {
        appendOperand(operand)
    }

    /// Appends an operand, inserting an implicit "×" after a finished operand.
    private mutating func appendOperand(_ operand: Operand) {
        if lastOperand != nil { items.append(.implicitTimes) }
        items.append(.operand(operand))
    }

    // MARK: Typing

    mutating func typeDigit(_ digit: Character) {
        switch lastOperand {
        case .literal(let text):
            if let e = text.firstIndex(of: "e") {
                var exponent = String(text[text.index(after: e)...])
                var sign = ""
                if exponent.hasPrefix("-") || exponent.hasPrefix("+") { sign = String(exponent.removeFirst()) }
                if exponent.count >= 3 { return } // Exponents take at most three digits.
                exponent = exponent.isEmpty ? String(digit) : Literal.append(digit, to: exponent)
                replaceLastOperand(.literal(String(text[...e]) + sign + exponent))
            } else {
                replaceLastOperand(.literal(Literal.append(digit, to: text)))
            }
        case .postfix(let inner, "%"):
            // "5%" followed by digits reads as the modulo operator: "5%20".
            replaceLastOperand(inner)
            items.append(.op("%"))
            items.append(.operand(.literal(String(digit))))
        case .some:
            appendOperand(.literal(String(digit)))
        case nil:
            items.append(.operand(.literal(String(digit))))
        }
    }

    mutating func typeDecimal() {
        switch lastOperand {
        case .literal(let text):
            if !text.contains("."), !text.contains("e") { replaceLastOperand(.literal(text + ".")) }
        case .some:
            appendOperand(.literal("0."))
        case nil:
            items.append(.operand(.literal("0.")))
        }
    }

    mutating func startExponent() {
        guard case .literal(let text) = lastOperand, !text.contains("e") else { return }
        replaceLastOperand(.literal(text + "e"))
    }

    mutating func typeConstant(_ symbol: String) {
        if case .postfix(let inner, "%") = lastOperand {
            replaceLastOperand(inner)
            items.append(.op("%"))
            items.append(.operand(.constant(symbol)))
            return
        }
        switch lastOperand {
        case .literal(let text) where !text.contains("e"):
            replaceLastOperand(.juxtaposed(text, symbol))
        case .some:
            appendOperand(.constant(symbol))
        case nil:
            items.append(.operand(.constant(symbol)))
        }
    }

    mutating func typeRandom() {
        let digits = (0..<8).map { _ in String(Int.random(in: 0...9)) }.joined()
        let literal = Operand.random("0." + digits)
        if case .random = lastOperand {
            replaceLastOperand(literal)
        } else {
            appendOperand(literal)
        }
    }

    mutating func typeOperator(_ symbol: Character, isTopLevel: Bool) {
        // An exponent sign while entering scientific notation: "2e-3", "2e+3".
        if case .literal(let text) = lastOperand, text.hasSuffix("e"), symbol == "-" || symbol == "+" {
            replaceLastOperand(.literal(text + String(symbol)))
            return
        }
        // A lone "0" followed by "-" becomes a leading minus sign.
        if symbol == "-", items.count == 1, case .operand(.literal("0")) = items[0] {
            items = [.sign]
            return
        }
        switch items.last {
        case nil:
            if symbol == "-" {
                items.append(.sign)
            } else if isTopLevel {
                items.append(.operand(.literal("0")))
                items.append(.op(symbol))
            }
        case .sign:
            switch symbol {
            case "-", "^":
                return
            case "+":
                items.removeLast()
                if case .op = items.last { items[items.count - 1] = .op(symbol) }
            default:
                if items.count >= 2, case .op("^") = items[items.count - 2] {
                    items.append(.op(symbol))
                } else {
                    items.removeLast()
                    if case .op = items.last { items[items.count - 1] = .op(symbol) }
                }
            }
        case .op(let previous):
            if symbol == "-", previous == "×" || previous == "÷" || previous == "^" {
                items.append(.sign)
            } else if symbol != "^" {
                items[items.count - 1] = .op(symbol)
            }
        case .operand:
            items.append(.op(symbol))
        case .implicitTimes:
            items[items.count - 1] = .op(symbol)
        }
    }

    // MARK: Wrapping the last operand

    mutating func applyFunction(_ name: String, isTopLevel: Bool = false) {
        if case .postfix(let inner, "%") = lastOperand {
            replaceLastOperand(inner)
            items.append(.op("%"))
            items.append(.operand(.call(name, Group(closed: false))))
            return
        }
        if applyInsideExponent({ .call(name, Group(items: [.operand($0)], closed: true)) }) { return }
        if let operand = takeLastOperandForFunction() {
            replaceLastOperand(.call(name, Group(items: [.operand(operand)], closed: true)))
        } else {
            items.append(.operand(.call(name, Group(closed: false))))
        }
    }

    mutating func applyPostfix(_ suffix: String, isTopLevel: Bool) {
        if suffix == "!" {
            while endsWithOperator, items.count > 1 { items.removeLast() }
        }
        if let operand = lastOperand {
            replaceLastOperand(.postfix(operand, suffix))
        } else if items.isEmpty, isTopLevel {
            items.append(.operand(.postfix(.literal("0"), suffix)))
        }
    }

    mutating func applyPercent(isTopLevel: Bool) {
        if items.isEmpty {
            guard isTopLevel else { return }
            items.append(.operand(.postfix(.literal("0"), "%")))
            return
        }
        while endsWithOperator, items.count > 1 {
            items.removeLast()
        }
        guard let operand = lastOperand else { return }
        replaceLastOperand(.postfix(operand, "%"))
    }

    mutating func applyPrefix(_ symbol: String) {
        if let operand = takeLastOperandForFunction() {
            replaceLastOperand(.prefix(symbol, operand))
        } else {
            items.append(.operand(.radical(symbol, Group(closed: false))))
        }
    }

    mutating func applyPower(base: String, isTopLevel: Bool) {
        if let operand = takeLastOperandForFunction() {
            replaceLastOperand(.power(base: base, operand))
        } else if items.isEmpty, isTopLevel {
            items.append(.operand(.power(base: base, .literal("0"))))
        }
    }

    mutating func applyReciprocal(isTopLevel: Bool) {
        if case .reciprocal(let inner) = lastOperand {
            replaceLastOperand(inner)
        } else if let operand = lastOperand {
            replaceLastOperand(.reciprocal(operand))
        } else if items.isEmpty, isTopLevel {
            items.append(.operand(.reciprocal(.literal("0"))))
        }
    }

    /// Wraps the last operand in ʸ√x, log_y or yˣ; returns true when the next digits fill the parameter.
    mutating func applyParameterized(_ kind: Parameterized) -> Bool {
        guard let operand = takeLastOperandForFunction() else { return false }
        replaceLastOperand(.parameterized(kind, operand))
        return true
    }

    /// Feeds a key into the parameter slot of the last ʸ√x, log_y or yˣ node.
    /// Returns false when the key ends the slot and should be handled normally.
    mutating func fillParameter(with key: Key) -> Bool {
        guard case .parameterized(let kind, let operand) = lastOperand else { return false }
        let updated: Parameterized
        switch kind {
        case .root(let index):
            if key == .negate { return true }
            if key == .subtract, index.isEmpty {
                updated = .root(index: "-")
            } else {
                guard let digit = key.digit else { return false }
                updated = .root(index: Literal.append(digit, to: index))
            }
        case .log(let base):
            guard let digit = key.digit else { return false }
            updated = .log(base: Literal.append(digit, to: base))
        case .customPower(let base):
            if key == .equals { return true }
            if key == .clear {
                replaceLastOperand(.parameterized(.customPower(base: ""), operand))
                return true
            }
            // The base slot takes a number or a constant: "3^2", "𝑒^9", "0.5^2".
            if let digit = key.digit, !base.hasSuffix("π"), !base.hasSuffix("𝑒") {
                updated = .customPower(base: Literal.append(digit, to: base.isEmpty ? "0" : base))
            } else if key == .decimal, !base.contains("."), !base.contains("π"), !base.contains("𝑒") {
                updated = .customPower(base: (base.isEmpty ? "0" : base) + ".")
            } else if (key == .pi || key == .eulerNumber), base.isEmpty {
                updated = .customPower(base: key == .pi ? "π" : "𝑒")
            } else {
                return false
            }
        }
        replaceLastOperand(.parameterized(updated, operand))
        return true
    }

    /// A yˣ whose base is still empty when an operator arrives keeps its exponent
    /// as a parenthesized group: "5 yˣ ^ 4" gives "(5)^4".
    mutating func finishParameter(endedBy key: Key) {
        guard key.binaryOperator != nil,
              case .parameterized(.customPower(base: ""), let exponent) = lastOperand else { return }
        if case .literal("0") = exponent {
            // The default exponent of an empty-slot yˣ leaves a plain 0.
            replaceLastOperand(.literal("0"))
        } else {
            replaceLastOperand(.group(Group(items: [.operand(exponent)], closed: true)))
        }
    }

    mutating func negateLast(isTopLevel: Bool = false) {
        guard let operand = lastOperand else {
            // On an empty expression the key leaves a 0 that typing replaces.
            if items.isEmpty, isTopLevel { items.append(.operand(.literal("0"))) }
            return
        }
        if case .literal("0") = operand { return }
        if items.count >= 2, case .sign = items[items.count - 2] {
            items.remove(at: items.count - 2)
            return
        }
        if items.count >= 2, case .op("-") = items[items.count - 2] {
            items[items.count - 2] = .op("+")
            return
        }
        switch operand {
        case .literal(let text) where text.contains("e"):
            // Toggles the exponent's sign once exponent digits exist.
            guard let e = text.firstIndex(of: "e") else { return }
            var exponent = String(text[text.index(after: e)...])
            guard exponent.contains(where: \.isNumber) else { return }
            if exponent.hasPrefix("-") { exponent.removeFirst() }
            else if exponent.hasPrefix("+") { exponent = "-" + exponent.dropFirst() }
            else { exponent = "-" + exponent }
            replaceLastOperand(.literal(String(text[...e]) + exponent))
        case .negated(let inner):
            replaceLastOperand(inner)
        case .juxtaposed(let literal, let constant):
            replaceLastOperand(.literal(literal))
            items.append(.op("×"))
            items.append(.operand(.negated(.constant(constant))))
        default:
            replaceLastOperand(.negated(operand))
        }
    }

    mutating func openGroup(isTopLevel: Bool) {
        if isTopLevel, items.count == 1, case .operand(.literal("0")) = items[0] {
            items.removeAll()
        }
        if lastOperand != nil {
            items.append(.op("×"))
        }
        items.append(.operand(.group(Group(closed: false))))
    }

    // MARK: Removing

    mutating func removeLastOperand() {
        if lastOperand != nil { items.removeLast() }
    }

    /// The C key: removes the last operand of the innermost open group, or the
    /// group itself when it is still empty.
    mutating func clearLastOperand() {
        guard let last = items.indices.last, case .operand(var operand) = items[last] else { return }
        if operand.hasOpenGroup {
            let removeGroup = operand.withOpenGroup { inner -> Bool in
                if inner.items.isEmpty { return true }
                inner.clearLastOperand()
                return false
            }
            if removeGroup { items.removeLast() } else { items[last] = .operand(operand) }
            return
        }
        items.removeLast()
        if case .implicitTimes = items.last { items.removeLast() }
    }

    /// The delete key: removes the last typed character or unwraps the last postfix.
    mutating func deleteBackward() {
        guard let last = items.indices.last else { return }
        switch items[last] {
        case .op, .sign, .implicitTimes:
            items.removeLast()
        case .operand(var operand):
            if operand.hasOpenGroup {
                let emptied = operand.withOpenGroup { inner -> Bool in
                    if inner.items.isEmpty { return true }
                    inner.deleteBackward()
                    return false
                }
                if emptied {
                    // Deleting inside an empty "(" removes the parenthesis itself.
                    items.removeLast()
                } else {
                    items[last] = .operand(operand)
                }
                return
            }
            switch operand {
            case .literal(var text):
                text.removeLast()
                if text.isEmpty || text == "-" {
                    items.removeLast()
                    if case .implicitTimes = items.last { items.removeLast() }
                } else {
                    items[last] = .operand(.literal(text))
                }
            case .postfix(let inner, _):
                items[last] = .operand(inner)
            case .juxtaposed(let literal, _):
                items[last] = .operand(.literal(literal))
            case .constant, .random:
                items.removeLast()
            case .group(var group):
                group.closed = false
                items[last] = .operand(.group(group))
            case .call(let name, var group):
                group.closed = false
                items[last] = .operand(.call(name, group))
            default:
                break
            }
        }
    }
}

extension Operand {
    /// True when this operand ends in an unclosed group that receives typing.
    var hasOpenGroup: Bool {
        switch self {
        case .group(let g), .call(_, let g), .radical(_, let g):
            return !g.closed
        default:
            return false
        }
    }

    @discardableResult
    mutating func withOpenGroup<T>(_ body: (inout Group) -> T) -> T {
        switch self {
        case .group(var g):
            let result = body(&g)
            self = .group(g)
            return result
        case .call(let name, var g):
            let result = body(&g)
            self = .call(name, g)
            return result
        case .radical(let symbol, var g):
            let result = body(&g)
            self = .radical(symbol, g)
            return result
        default:
            var dummy = Group(closed: true)
            return body(&dummy)
        }
    }
}

// MARK: - Rendering

enum Literal {
    /// Appends a digit, collapsing leading zeros ("0" then "1" gives "1").
    static func append(_ digit: Character, to text: String) -> String {
        if text == "0" { return String(digit) }
        if text == "-0" { return "-" + String(digit) }
        return text + String(digit)
    }

    /// Display form: grouping separators in the integer part, a trailing "." or a
    /// bare "e" hidden. "1234.50" → "1,234.50", "2." → "2", "2.e3" stays.
    static func render(_ text: String, grouping: Bool) -> String {
        var mantissa = text
        var exponent = ""
        if let e = text.firstIndex(of: "e") {
            mantissa = String(text[..<e])
            exponent = String(text[e...])
            if exponent == "e" { exponent = "" }
        }
        if exponent.isEmpty, mantissa.hasSuffix(".") {
            mantissa.removeLast()
        }
        var integer = mantissa
        var fraction = ""
        if let dot = mantissa.firstIndex(of: ".") {
            integer = String(mantissa[..<dot])
            fraction = String(mantissa[dot...])
        }
        if integer.isEmpty { integer = "0" }
        if grouping { integer = group(integer) }
        return integer + fraction + exponent
    }

    static func group(_ digits: String) -> String {
        var negative = false
        var body = digits
        if body.hasPrefix("-") { negative = true; body.removeFirst() }
        var result = ""
        for (i, c) in body.reversed().enumerated() {
            if i > 0, i % 3 == 0 { result.append(",") }
            result.append(c)
        }
        return (negative ? "-" : "") + String(result.reversed())
    }
}

extension Group {
    func render(grouping: Bool) -> String {
        var text = ""
        for (i, item) in items.enumerated() {
            if case .operand(let o) = item, i + 1 < items.count, case .op("^") = items[i + 1], o.isPower {
                text += "(" + o.render(grouping: grouping) + ")"
                continue
            }
            switch item {
            case .op(let c): text.append(c)
            case .sign: text.append("-")
            case .implicitTimes: text.append("×")
            case .operand(let o): text += o.render(grouping: grouping)
            }
        }
        return text
    }
}

extension Operand {
    func render(grouping: Bool) -> String {
        switch self {
        case .literal(let text):
            return Literal.render(text, grouping: grouping)
        case .random(let text):
            return text
        case .constant(let symbol):
            return symbol
        case .juxtaposed(let literal, let constant):
            return Literal.render(literal, grouping: grouping) + constant
        case .group(let g):
            return "(" + g.render(grouping: grouping) + ")"
        case .call(let name, let g):
            return name + "(" + g.render(grouping: grouping) + ")"
        case .signed(let inner):
            return "-" + inner.render(grouping: grouping)
        case .radical(let symbol, let g):
            if g.items.isEmpty { return symbol }
            if g.items.count == 1, case .operand(let only) = g.items[0] {
                if case .parameterized(.customPower, _) = only {
                    return symbol + "(" + only.render(grouping: grouping) + ")"
                }
                return symbol + only.renderUnderRadical(grouping: grouping)
            }
            return symbol + "(" + g.render(grouping: grouping) + ")"
        case .prefix(let symbol, let inner):
            return symbol + inner.renderUnderRadical(grouping: grouping)
        case .postfix(let inner, let suffix):
            return inner.renderAsPostfixBase(for: suffix, grouping: grouping) + suffix
        case .power(let base, let exponent):
            return base + "^" + exponent.render(grouping: grouping)
        case .reciprocal(let inner):
            return "(1÷" + inner.render(grouping: grouping) + ")"
        case .negated(let inner):
            return "(-" + inner.render(grouping: grouping) + ")"
        case .parameterized(let kind, let inner):
            switch kind {
            case .root(let index):
                switch index {
                case "", "2": return "√" + inner.renderUnderRadical(grouping: grouping)
                case "3": return "∛" + inner.renderUnderRadical(grouping: grouping)
                default: return "root(" + inner.render(grouping: grouping) + ", " + index + ")"
                }
            case .log(let base):
                let shownBase = (base == "10" || base.isEmpty) ? "" : base
                return "log" + shownBase + "(" + inner.render(grouping: grouping) + ")"
            case .customPower(let base):
                let shownBase = base.isEmpty ? "" : Literal.render(base, grouping: grouping)
                return shownBase + "^" + inner.render(grouping: grouping)
            }
        }
    }

    var isPower: Bool {
        switch self {
        case .postfix(_, let suffix): return suffix.hasPrefix("^")
        case .power, .parameterized(.customPower, _): return true
        default: return false
        }
    }

    /// A postfix parenthesizes an operand ending in the same kind of postfix:
    /// "(2^2)^2", "(𝑒^2)^2", "(3!)!", "(2%)%" — but "2^2!".
    func renderAsPostfixBase(for suffix: String, grouping: Bool) -> String {
        let wrap: Bool
        switch self {
        case .postfix(_, let inner):
            wrap = inner == suffix || (inner.hasPrefix("^") && suffix.hasPrefix("^"))
        case .power, .parameterized(.customPower, _):
            wrap = suffix.hasPrefix("^")
        default:
            wrap = false
        }
        return wrap ? "(" + render(grouping: grouping) + ")" : render(grouping: grouping)
    }

    /// Radicals parenthesize powers but not factorials: "√(2^2)" but "√2!".
    func renderUnderRadical(grouping: Bool) -> String {
        switch self {
        case .juxtaposed:
            return "(" + render(grouping: grouping) + ")"
        case .postfix(_, let suffix) where suffix.hasPrefix("^"):
            return "(" + render(grouping: grouping) + ")"
        case .power:
            return "(" + render(grouping: grouping) + ")"
        default:
            return render(grouping: grouping)
        }
    }
}
