import AppKit
import CalcCore
import SwiftUI

/// `DecCalc --snapshot <dir>` renders each layout to a PNG, for documentation and visual checks.
@MainActor
enum Snapshot {
    static func render(to directory: URL) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let scenes: [(String, LayoutMode, [Key])] = [
            ("basic", .basic, [.digit1, .divide, .digit3, .equals]),
            ("scientific", .scientific, [.digit2, .add, .digit3, .sine, .multiply, .pi]),
            ("rpn", .rpn, [.digit3, .enter, .digit4, .add, .digit5, .multiply, .digit2, .squareRoot]),
        ]
        for (name, layout, keys) in scenes {
            let model = CalculatorModel()
            model.layout = layout
            keys.forEach(model.press)
            let view = ContentView(model: model).fixedSize().preferredColorScheme(.dark)
            let renderer = ImageRenderer(content: view)
            renderer.scale = 2
            guard let image = renderer.nsImage,
                  let tiff = image.tiffRepresentation,
                  let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else { continue }
            try? png.write(to: directory.appendingPathComponent("\(name).png"))
        }
    }
}
