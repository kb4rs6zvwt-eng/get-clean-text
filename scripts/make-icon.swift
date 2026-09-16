import AppKit

let directory = CommandLine.arguments[1]
try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let image = NSImage(size: NSSize(width: pixels, height: pixels))
        image.lockFocus()
        let p = CGFloat(pixels)
        let bounds = NSRect(x: p * 0.06, y: p * 0.06, width: p * 0.88, height: p * 0.88)
        let path = NSBezierPath(roundedRect: bounds, xRadius: p * 0.20, yRadius: p * 0.20)
        NSGradient(starting: NSColor(calibratedRed: 0.20, green: 0.42, blue: 0.91, alpha: 1),
                   ending: NSColor(calibratedRed: 0.11, green: 0.22, blue: 0.60, alpha: 1))!.draw(in: path, angle: -90)
        let text = "Aa" as NSString
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: p * 0.43, weight: .medium), .foregroundColor: NSColor.white
        ]
        let textSize = text.size(withAttributes: attributes)
        text.draw(at: NSPoint(x: (p - textSize.width) / 2, y: (p - textSize.height) / 2 + p * 0.025), withAttributes: attributes)
        let line = NSBezierPath(roundedRect: NSRect(x: p * 0.28, y: p * 0.24, width: p * 0.44, height: p * 0.035),
                                xRadius: p * 0.0175, yRadius: p * 0.0175)
        NSColor.white.withAlphaComponent(0.6).setFill()
        line.fill()
        image.unlockFocus()
        let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
        let suffix = scale == 2 ? "@2x" : ""
        try bitmap.representation(using: .png, properties: [:])!.write(to:
            URL(fileURLWithPath: "\(directory)/icon_\(size)x\(size)\(suffix).png"))
    }
}
