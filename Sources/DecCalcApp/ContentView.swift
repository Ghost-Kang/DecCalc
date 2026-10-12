import AppKit
import CalcCore
import SwiftUI

struct ContentView: View {
    @State var model = CalculatorModel()
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 1) {
            display
            HStack(spacing: 1) {
                if model.layout != .basic {
                    grid(Keypads.scientific(second: model.secondFunctions,
                                            degrees: model.angleUnit == .degrees,
                                            rpn: model.layout == .rpn))
                        .frame(width: 6 * 62)
                }
                grid(Keypads.basic(rpn: model.layout == .rpn))
                    .frame(width: 4 * 62)
            }
            .frame(height: 5 * 52)
        }
        .background(Color(white: 0.12))
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("Mode", selection: $model.layout) {
                    ForEach(LayoutMode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .fixedSize()
            }
        }
        .focusable()
        .focused($focused)
        .focusEffectDisabled()
        .onAppear { focused = true }
        .onKeyPress(phases: .down, action: handleKeyPress)
        .onCopyCommand { [NSItemProvider(object: model.copyText as NSString)] }
    }

    private var display: some View {
        VStack(alignment: .trailing, spacing: 4) {
            HStack {
                if model.layout != .basic {
                    Text(model.angleUnit == .degrees ? "Deg" : "Rad")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if model.memory != nil {
                    Text("M").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
            if model.layout == .rpn {
                ForEach(Array(model.stackLines.prefix(4).enumerated().reversed()), id: \.offset) { index, line in
                    HStack(alignment: .firstTextBaseline) {
                        Text(["X", "Y", "Z", "T"][index]).font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Text(line)
                            .font(.system(size: index == 0 ? 40 : 20, weight: .light, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.3)
                            .textSelection(.enabled)
                    }
                }
            } else {
                Text(model.expressionLine)
                    .font(.system(size: 18, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.head)
                Text(model.mainLine)
                    .font(.system(size: 48, weight: .light, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.3)
                    .textSelection(.enabled)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, minHeight: model.layout == .rpn ? 170 : 110, alignment: .bottomTrailing)
        .background(Color(white: 0.16))
    }

    private func grid(_ rows: [[PadButton]]) -> some View {
        Grid(horizontalSpacing: 1, verticalSpacing: 1) {
            ForEach(rows.indices, id: \.self) { r in
                GridRow {
                    ForEach(rows[r]) { button in
                        PadButtonView(button: button, label: label(for: button)) { perform(button.action) }
                            .gridCellColumns(button.span)
                    }
                }
            }
        }
    }

    private func label(for button: PadButton) -> String {
        if case .clear = button.action {
            return model.clearKey == .allClear ? "AC" : "C"
        }
        return button.label
    }

    private func perform(_ action: PadAction) {
        switch action {
        case .key(let key): model.press(key)
        case .clear: model.press(model.clearKey)
        case .memory(let m): model.memory(m)
        case .toggleSecond: model.secondFunctions.toggle()
        case .toggleAngle: model.angleUnit = model.angleUnit == .degrees ? .radians : .degrees
        }
    }

    private func handleKeyPress(_ press: KeyPress) -> KeyPress.Result {
        if press.modifiers.contains(.command) { return .ignored }
        switch press.key {
        case .return:
            model.press(model.layout == .rpn ? .enter : .equals)
            return .handled
        case .delete, .deleteForward:
            model.press(.delete)
            return .handled
        case .escape:
            model.press(.allClear)
            return .handled
        default:
            break
        }
        let map: [Character: Key] = [
            "0": .digit0, "1": .digit1, "2": .digit2, "3": .digit3, "4": .digit4,
            "5": .digit5, "6": .digit6, "7": .digit7, "8": .digit8, "9": .digit9,
            ".": .decimal, ",": .decimal, "+": .add, "-": .subtract, "*": .multiply, "x": .multiply,
            "/": .divide, "^": .power, "%": .percent, "(": .openParenthesis, ")": .closeParenthesis,
            "=": .equals, "!": .factorial, "e": .eulerNumber, "p": .pi, "c": .clear,
        ]
        guard let character = press.characters.first, let key = map[character] else { return .ignored }
        model.press(key)
        return .handled
    }
}
