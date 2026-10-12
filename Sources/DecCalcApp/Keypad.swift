import CalcCore
import SwiftUI

/// What a keypad button does.
enum PadAction {
    case key(Key)
    case clear
    case memory(MemoryAction)
    case toggleSecond
    case toggleAngle
}

enum PadStyle {
    case digit, function, operation, accent
}

struct PadButton: Identifiable {
    let id = UUID()
    let label: String
    let action: PadAction
    let style: PadStyle
    var span = 1

    static func digit(_ label: String, _ key: Key, span: Int = 1) -> PadButton {
        PadButton(label: label, action: .key(key), style: .digit, span: span)
    }

    static func function(_ label: String, _ key: Key) -> PadButton {
        PadButton(label: label, action: .key(key), style: .function)
    }

    static func operation(_ label: String, _ key: Key) -> PadButton {
        PadButton(label: label, action: .key(key), style: .operation)
    }
}

enum Keypads {
    /// The four-column pad shared by all layouts; RPN swaps "=" for Enter.
    static func basic(rpn: Bool) -> [[PadButton]] {
        [
            [PadButton(label: "AC", action: .clear, style: .function),
             .function("+/−", .negate), .function("%", .percent), .operation("÷", .divide)],
            [.digit("7", .digit7), .digit("8", .digit8), .digit("9", .digit9), .operation("×", .multiply)],
            [.digit("4", .digit4), .digit("5", .digit5), .digit("6", .digit6), .operation("−", .subtract)],
            [.digit("1", .digit1), .digit("2", .digit2), .digit("3", .digit3), .operation("+", .add)],
            rpn
                ? [.digit("0", .digit0), .digit(".", .decimal), .function("⌫", .delete), .operation("enter", .enter)]
                : [.digit("0", .digit0, span: 2), .digit(".", .decimal), .operation("=", .equals)],
        ]
    }

    /// The scientific panel to the left of the basic pad.
    static func scientific(second: Bool, degrees: Bool, rpn: Bool) -> [[PadButton]] {
        let firstRow: [PadButton] = rpn
            ? [.function("x⇄y", .swap), .function("R↓", .rollIn), .function("R↑", .rollOut), .function("drop", .drop)]
            : [.function("(", .openParenthesis), .function(")", .closeParenthesis), .function("⌫", .delete), .function("EE", .ee)]
        return [
            firstRow + [
                PadButton(label: "mc", action: .memory(.clear), style: .function),
                PadButton(label: "m+", action: .memory(.add), style: .function),
            ],
            [
                PadButton(label: "2ⁿᵈ", action: .toggleSecond, style: second ? .accent : .function),
                .function("x²", .square), .function("x³", .cube), .function("xʸ", .power),
                second ? .function("yˣ", .exponentialBaseCustom) : .function("eˣ", .exponentialBaseEuler),
                second ? .function("2ˣ", .exponentialBase2) : .function("10ˣ", .exponentialBase10),
            ],
            [
                .function("¹⁄ₓ", .reciprocal), .function("²√x", .squareRoot), .function("³√x", .cubeRoot),
                .function("ʸ√x", .root),
                second ? .function("logᵧ", .logarithmBaseCustom) : .function("ln", .logarithmNatural),
                second ? .function("log₂", .logarithmBase2) : .function("log₁₀", .logarithmBase10),
            ],
            [
                .function("x!", .factorial),
                second ? .function("sin⁻¹", .inverseSine) : .function("sin", .sine),
                second ? .function("cos⁻¹", .inverseCosine) : .function("cos", .cosine),
                second ? .function("tan⁻¹", .inverseTangent) : .function("tan", .tangent),
                .function("e", .eulerNumber),
                rpn ? .function("EE", .ee) : PadButton(label: "m−", action: .memory(.subtract), style: .function),
            ],
            [
                PadButton(label: degrees ? "Rad" : "Deg", action: .toggleAngle, style: .function),
                second ? .function("sinh⁻¹", .inverseHyperbolicSine) : .function("sinh", .hyperbolicSine),
                second ? .function("cosh⁻¹", .inverseHyperbolicCosine) : .function("cosh", .hyperbolicCosine),
                second ? .function("tanh⁻¹", .inverseHyperbolicTangent) : .function("tanh", .hyperbolicTangent),
                .function("π", .pi),
                PadButton(label: "mr", action: .memory(.recall), style: .function),
            ],
        ]
    }
}

struct PadButtonView: View {
    let button: PadButton
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: button.style == .function ? 16 : 22, weight: .regular, design: .rounded))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .foregroundStyle(.white)
                .background(background)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(label)
    }

    private var background: Color {
        switch button.style {
        case .digit: Color(white: 0.36)
        case .function: Color(white: 0.24)
        case .operation: Color.orange
        case .accent: Color(white: 0.55)
        }
    }
}

struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.brightness(configuration.isPressed ? 0.2 : 0)
    }
}
