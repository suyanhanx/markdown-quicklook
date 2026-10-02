import AppKit
import Foundation

// Reproducible vector artwork: Markdown M and preview eye, no borrowed brand assets.
let output = URL(fileURLWithPath: "build/AppIcon.iconset")
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
for size in [16, 32, 64, 128, 256, 512, 1024] {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    let transform = AffineTransform(scale: CGFloat(size) / 1024)
    (transform as NSAffineTransform).concat()
    let frame = NSBezierPath(roundedRect: NSRect(x: 70, y: 70, width: 884, height: 884), xRadius: 196, yRadius: 196)
    NSGradient(starting: NSColor(red: 0.12, green: 0.46, blue: 0.94, alpha: 1), ending: NSColor(red: 0.10, green: 0.22, blue: 0.63, alpha: 1))!.draw(in: frame, angle: -90)
    let mark = NSBezierPath()
    mark.move(to: NSPoint(x: 268, y: 410)); mark.line(to: NSPoint(x: 268, y: 712)); mark.line(to: NSPoint(x: 512, y: 505)); mark.line(to: NSPoint(x: 756, y: 712)); mark.line(to: NSPoint(x: 756, y: 410))
    mark.lineWidth = 70; mark.lineJoinStyle = .round; mark.lineCapStyle = .round
    NSColor.white.setStroke(); mark.stroke()
    let eye = NSBezierPath()
    eye.move(to: NSPoint(x: 362, y: 280)); eye.curve(to: NSPoint(x: 662, y: 280), controlPoint1: NSPoint(x: 435, y: 380), controlPoint2: NSPoint(x: 589, y: 380)); eye.curve(to: NSPoint(x: 362, y: 280), controlPoint1: NSPoint(x: 589, y: 180), controlPoint2: NSPoint(x: 435, y: 180))
    eye.lineWidth = 25; eye.stroke()
    NSColor.white.setFill(); NSBezierPath(ovalIn: NSRect(x: 477, y: 245, width: 70, height: 70)).fill()
    NSGraphicsContext.restoreGraphicsState()
    let data = bitmap.representation(using: .png, properties: [:])!
    if size <= 512 { try data.write(to: output.appendingPathComponent("icon_\(size)x\(size).png")) }
    if size >= 32 { try data.write(to: output.appendingPathComponent("icon_\(size/2)x\(size/2)@2x.png")) }
}
