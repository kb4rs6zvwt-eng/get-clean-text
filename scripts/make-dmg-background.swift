import AppKit

// A vector background keeps lettering and the arrow sharp at any display scale.
// White edges merge with Finder's canvas when the window is enlarged.
let width: CGFloat = 600
let height: CGFloat = 330
var bounds = CGRect(x: 0, y: 0, width: width, height: height)
let destination = URL(fileURLWithPath: CommandLine.arguments[1])
let context = CGContext(destination as CFURL, mediaBox: &bounds, nil)!
context.beginPDFPage(nil)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
NSColor.white.setFill()
NSBezierPath(rect: bounds).fill()

func text(_ value: String, top: CGFloat, size: CGFloat, weight: NSFont.Weight, color: NSColor) {
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color
    ]
    let string = value as NSString
    let measured = string.size(withAttributes: attributes)
    string.draw(at: NSPoint(x: (width - measured.width) / 2, y: height - top - measured.height),
                withAttributes: attributes)
}
text("Get Clean Text", top: 30, size: 28, weight: .semibold,
     color: NSColor(calibratedWhite: 0.12, alpha: 1))
text("Glissez l’app dans Applications.", top: 76, size: 16, weight: .regular,
     color: NSColor(calibratedWhite: 0.42, alpha: 1))

let arrow = NSBezierPath()
arrow.move(to: NSPoint(x: 268, y: height - 190))
arrow.line(to: NSPoint(x: 332, y: height - 190))
arrow.move(to: NSPoint(x: 318, y: height - 176))
arrow.line(to: NSPoint(x: 332, y: height - 190))
arrow.line(to: NSPoint(x: 318, y: height - 204))
arrow.lineWidth = 3
arrow.lineCapStyle = .round
arrow.lineJoinStyle = .round
NSColor(calibratedRed: 0.18, green: 0.39, blue: 0.84, alpha: 1).setStroke()
arrow.stroke()
NSGraphicsContext.restoreGraphicsState()
context.endPDFPage()
context.closePDF()
