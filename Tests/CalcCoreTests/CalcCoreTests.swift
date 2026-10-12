@testable import CalcCore
import XCTest

// Every expectation below was observed on the system Calculate.framework through
// Tools/Oracle; the tests pin that behavior without needing the private framework.

final class EvaluatorTests: XCTestCase {
    private func value(_ text: String, _ unit: AngleUnit = .radians) -> String? {
        Evaluator(angleUnit: unit).evaluate(text).value?.plainDescription
    }

    func testDecimalArithmeticIsExact() {
        XCTAssertEqual(value("0.1+0.2"), "0.3")
        XCTAssertEqual(value("1÷3"), "0.3333333333333333333333333333333333")
        XCTAssertEqual(value("2÷3"), "0.6666666666666666666666666666666667")
    }

    func testPrecedence() {
        XCTAssertEqual(value("-2^2"), "-4")
        XCTAssertEqual(value("2^3^2"), "512")
        XCTAssertEqual(value("2^-1"), "0.5")
        XCTAssertEqual(value("3+4×5"), "23")
        XCTAssertEqual(value("√2^2"), "2")
        // Juxtaposition binds looser than ^: "2π^2" is 2×π², as in the framework.
        XCTAssertEqual(value("2π^2"), value("2×π^2"))
    }

    func testPercent() {
        XCTAssertEqual(value("5%"), "0.05")
        XCTAssertEqual(value("50+10%"), "55")
        XCTAssertEqual(value("50-10%"), "45")
        XCTAssertEqual(value("50×10%"), "5")
        XCTAssertEqual(value("(2%)%"), "0.0002")
        // Between operands "%" is modulo, unless its left factor follows × or ÷.
        XCTAssertEqual(value("17%945"), "17")
        XCTAssertEqual(value("3×17%945"), "481.95")
        XCTAssertEqual(value("3×17%945%3"), "1.95")
        XCTAssertEqual(value("8^26%"), "3022314549036572936765.44")
    }

    func testTrigonometry() {
        XCTAssertEqual(value("sin(π)"), "0")
        XCTAssertEqual(value("sin(30)", .degrees), "0.5")
        XCTAssertEqual(value("cos(60)", .degrees), "0.4999999999999999999999999999999996")
        XCTAssertEqual(value("cos(90)", .degrees), "0")
        XCTAssertEqual(value("sin(45)", .degrees), "0.7071067811865475244008443621048492")
        XCTAssertEqual(value("tan(45)", .degrees), "1")
        XCTAssertEqual(value("tan(4)", .degrees), "0.06992681194351041366692106032318177")
        XCTAssertEqual(value("sin^-1(0.5)", .degrees), "30")
        XCTAssertEqual(Evaluator(angleUnit: .degrees).evaluate("tan(90)"), .error)
    }

    func testFactorialUsesGamma() {
        XCTAssertEqual(value("3!"), "6")
        XCTAssertEqual(value("2.5!"), "3.323350970447842551184064031264647")
        XCTAssertEqual(value("30!"), "265252859812191058636308479999998")
        XCTAssertEqual(Evaluator().evaluate("104!"), .error)
        XCTAssertEqual(Evaluator().evaluate("(-2)!"), .error)
    }

    func testLogarithms() {
        XCTAssertEqual(value("log3(2)"), "0.6309297535714574370995271143427608")
        XCTAssertEqual(value("log5(100)"), "2.861353116146786101340213137527932")
        XCTAssertEqual(value("log2(18.5)"), "4.209453365628949781857804177613174")
        XCTAssertEqual(value("root(2, 4)"), "1.189207115002721066717499970560476")
    }

    func testRoundingIsHalfAwayFromZero() {
        // log(5)×5 has a 5 in the 35th digit.
        XCTAssertEqual(value("log(5)×5"), "3.494850021680094023931305526377535")
    }

    func testErrorsAndIncompleteExpressions() {
        XCTAssertEqual(Evaluator().evaluate("1÷0"), .error)
        XCTAssertEqual(Evaluator().evaluate("sin^-1(2)"), .error)
        XCTAssertEqual(Evaluator().evaluate("3+"), .incomplete)
        XCTAssertEqual(Evaluator().evaluate("sin()"), .incomplete)
        XCTAssertEqual(Evaluator().evaluate("10^log(0)"), .error)
    }

    func testResultsMustFitBinary64NormalRange() {
        XCTAssertNotNil(value("1.7976931334e308"))
        XCTAssertEqual(Evaluator().evaluate("1.7976931335e308"), .error)
        XCTAssertNotNil(value("2.226e-308"))
        XCTAssertEqual(Evaluator().evaluate("2.225e-308"), .error)
        XCTAssertEqual(value("1e400÷1e200"), "1" + String(repeating: "0", count: 200))
    }
}

final class DisplayFormatterTests: XCTestCase {
    private func shown(_ text: String) -> String {
        DisplayFormatter().string(for: Evaluator().evaluate(text).value!)
    }

    func testFractionDigits() {
        XCTAssertEqual(shown("1÷3"), "0.33333333")
        XCTAssertEqual(shown("ln(3)"), "1.098612289")
        XCTAssertEqual(shown("1÷7000"), "0.00014285714")
        XCTAssertEqual(shown("1÷3×1000000000"), "333,333,333.33333333")
        XCTAssertEqual(shown("5664+8e-30"), "5,664")
    }

    func testScientificNotation() {
        XCTAssertEqual(shown("1234567890"), "1,234,567,890")
        XCTAssertEqual(shown("12345678900"), "1.23456789×10¹⁰")
        XCTAssertEqual(shown("2^64"), "1.84467441×10¹⁹")
        XCTAssertEqual(shown("1÷1000000000"), "1×10⁻⁹")
        XCTAssertEqual(shown("15÷10000000000"), "0.0000000015")
        XCTAssertEqual(shown("1÷1100000000"), "9.090909091×10⁻¹⁰")
    }
}

final class InfixEditorTests: XCTestCase {
    private func text(_ keys: [Key]) -> String {
        var editor = InfixEditor()
        keys.forEach { editor.press($0) }
        return editor.text
    }

    func testFunctionsWrapTheLastOperand() {
        XCTAssertEqual(text([.digit3, .add, .digit4, .sine]), "3+sin(4)")
        XCTAssertEqual(text([.openParenthesis, .digit3, .add, .digit4, .closeParenthesis, .sine]), "sin((3+4))")
        XCTAssertEqual(text([.digit3, .sine, .sine]), "sin(sin(3))")
        XCTAssertEqual(text([.sine, .digit2, .add, .digit3]), "sin(2+3)")
    }

    func testPostfixAndPowers() {
        XCTAssertEqual(text([.digit2, .square, .square]), "(2^2)^2")
        XCTAssertEqual(text([.digit3, .factorial, .factorial]), "(3!)!")
        XCTAssertEqual(text([.digit2, .exponentialBaseEuler, .exponentialBaseEuler]), "𝑒^𝑒^2")
        XCTAssertEqual(text([.digit2, .square, .squareRoot]), "√(2^2)")
        XCTAssertEqual(text([.digit2, .factorial, .squareRoot]), "√2!")
        XCTAssertEqual(text([.digit2, .reciprocal, .reciprocal]), "2")
    }

    func testImplicitMultiplicationAndConstants() {
        XCTAssertEqual(text([.digit2, .pi]), "2π")
        XCTAssertEqual(text([.pi, .digit2]), "π×2")
        XCTAssertEqual(text([.digit2, .openParenthesis, .digit3, .closeParenthesis]), "2×(3)")
        XCTAssertEqual(text([.digit2, .pi, .negate]), "2×(-π)")
        XCTAssertEqual(text([.digit5, .percent, .digit2, .digit0]), "5%20")
    }

    func testParameterizedKeys() {
        XCTAssertEqual(text([.digit2, .root]), "√2")
        XCTAssertEqual(text([.digit2, .root, .digit3]), "∛2")
        XCTAssertEqual(text([.digit2, .root, .digit1, .digit2]), "root(2, 12)")
        XCTAssertEqual(text([.digit2, .logarithmBaseCustom, .digit3]), "log3(2)")
        XCTAssertEqual(text([.digit2, .exponentialBaseCustom, .digit3]), "3^2")
        XCTAssertEqual(text([.root, .digit7, .add, .digit2]), "√(7+2)")
    }

    func testOperatorsAndEditing() {
        XCTAssertEqual(text([.digit3, .add, .multiply, .digit4]), "3×4")
        XCTAssertEqual(text([.digit3, .multiply, .subtract, .digit4]), "3×-4")
        XCTAssertEqual(text([.add, .digit4]), "0+4")
        XCTAssertEqual(text([.digit3, .add, .digit4, .negate]), "3+(-4)")
        XCTAssertEqual(text([.digit3, .add, .digit4, .clear]), "3+")
        XCTAssertEqual(text([.digit1, .digit2, .digit3, .delete]), "12")
        XCTAssertEqual(text([.digit2, .ee, .subtract, .digit3]), "2e-3")
        XCTAssertEqual(text([.digit1, .digit2, .digit3, .digit4, .digit5]), "12,345")
        XCTAssertEqual(text([.openParenthesis, .digit3, .add, .digit4]), "(3+4)")
    }
}

final class RPNStackTests: XCTestCase {
    private func run(_ keys: [Key], _ unit: AngleUnit = .radians) -> RPNStack {
        var stack = RPNStack(angleUnit: unit)
        keys.forEach { stack.press($0) }
        return stack
    }

    private func values(_ stack: RPNStack) -> [String] {
        stack.values.map { $0.value?.plainDescription ?? "nil" }
    }

    func testOperationsCollapseToLiterals() {
        let stack = run([.digit3, .enter, .digit4, .add])
        XCTAssertEqual(stack.text, "7E+0")
        XCTAssertEqual(values(stack), ["7"])
        XCTAssertEqual(run([.digit1, .enter, .digit3, .divide]).text, "3333333333333333333333333333333333E-34")
        XCTAssertEqual(run([.digit2, .ee, .digit3, .enter, .digit5, .multiply]).text, "10E+3")
    }

    func testEnterDuplicatesAndTypingReplaces() {
        XCTAssertEqual(values(run([.digit3, .enter])), ["3", "3"])
        XCTAssertEqual(values(run([.digit3, .enter, .digit4])), ["3", "4"])
        XCTAssertEqual(values(run([.digit3, .enter, .enter])), ["3", "3", "3"])
        XCTAssertEqual(values(run([.digit3, .enter, .digit4, .add, .digit5])), ["7", "5"])
    }

    func testOperandOrder() {
        XCTAssertEqual(values(run([.digit3, .enter, .digit4, .power])), ["64"])
        XCTAssertEqual(values(run([.digit3, .enter, .digit4, .exponentialBaseCustom])), ["81"])
        XCTAssertEqual(values(run([.digit3, .enter, .digit4, .swap, .subtract])), ["1"])
        XCTAssertEqual(values(run([.digit8, .enter, .digit2, .logarithmBaseCustom])),
                       ["0.3333333333333333333333333333333333"])
        XCTAssertEqual(values(run([.digit5, .enter, .digit1, .digit0, .percent])), ["5", "0.5"])
    }

    func testStackMoves() {
        let base: [Key] = [.digit1, .enter, .digit2, .enter, .digit3]
        XCTAssertEqual(values(run(base + [.drop])), ["1", "2"])
        XCTAssertEqual(values(run(base + [.rollIn])), ["3", "1", "2"])
        XCTAssertEqual(values(run(base + [.rollOut])), ["2", "3", "1"])
        XCTAssertEqual(values(run([.digit9, .digit0, .digit8, .swap, .digit1])), ["9081"])
    }

    func testEdgeCases() {
        XCTAssertEqual(values(run([.add, .digit1])), ["1"])
        XCTAssertEqual(values(run([.sine, .digit2])), ["0", "2"])
        XCTAssertEqual(values(run([.digit1, .enter, .digit0, .divide, .digit5])), ["5"])
        XCTAssertEqual(run([.negate, .digit4]).text, "-04")
        XCTAssertEqual(values(run([.digit3, .pi])), ["3", "3.141592653589793238462643383279503"])
    }
}
