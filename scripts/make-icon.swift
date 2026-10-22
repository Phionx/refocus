import AppKit
import Foundation

let output = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> NSColor {
    NSColor(srgbRed: r / 255, green: g / 255, blue: b / 255, alpha: 1)
}
func drawIcon(size: Int, to file: URL) throws {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                                  bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                  isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let context = NSGraphicsContext(bitmapImageRep: bitmap)!
    NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = context
    context.cgContext.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)
    let plate = NSBezierPath(roundedRect: NSRect(x: 64, y: 64, width: 896, height: 896), xRadius: 202, yRadius: 202)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow(); shadow.shadowColor = NSColor.black.withAlphaComponent(0.22)
    shadow.shadowBlurRadius = 26; shadow.shadowOffset = NSSize(width: 0, height: -10); shadow.set()
    color(21, 49, 58).setFill(); plate.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGradient(starting: color(21, 43, 57), ending: color(35, 98, 91))!.draw(in: plate, angle: 55)
    let ring = NSBezierPath(ovalIn: NSRect(x: 338, y: 338, width: 348, height: 348))
    color(183, 221, 199).withAlphaComponent(0.13).setStroke(); ring.lineWidth = 14; ring.stroke()
    color(239, 247, 230).setStroke()
    for (x, y, dx, dy) in [(278.0, 278.0, 1.0, 1.0), (746.0, 278.0, -1.0, 1.0),
                          (278.0, 746.0, 1.0, -1.0), (746.0, 746.0, -1.0, -1.0)] {
        let corner = NSBezierPath()
        corner.move(to: NSPoint(x: x, y: y + dy * 132))
        corner.line(to: NSPoint(x: x, y: y + dy * 34))
        corner.curve(to: NSPoint(x: x + dx * 34, y: y),
                     controlPoint1: NSPoint(x: x, y: y + dy * 10),
                     controlPoint2: NSPoint(x: x + dx * 10, y: y))
        corner.line(to: NSPoint(x: x + dx * 132, y: y))
        corner.lineWidth = 52; corner.lineCapStyle = .round; corner.lineJoinStyle = .round; corner.stroke()
    }
    color(205, 240, 142).setFill()
    NSBezierPath(ovalIn: NSRect(x: 448, y: 448, width: 128, height: 128)).fill()
    NSGraphicsContext.restoreGraphicsState()
    try bitmap.representation(using: .png, properties: [:])!.write(to: file)
}
for size in [16, 32, 128, 256, 512] {
    try drawIcon(size: size, to: output.appendingPathComponent("icon_\(size)x\(size).png"))
    try drawIcon(size: size * 2, to: output.appendingPathComponent("icon_\(size)x\(size)@2x.png"))
}
