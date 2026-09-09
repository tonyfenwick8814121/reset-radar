import AppKit

guard CommandLine.arguments.count == 2 else {
    fatalError("Usage: swift generate_icon.swift output.png")
}

let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)
image.lockFocus()

let outer = NSBezierPath(roundedRect: NSRect(x: 52, y: 52, width: 920, height: 920), xRadius: 230, yRadius: 230)
NSGraphicsContext.current?.saveGraphicsState()
outer.addClip()
NSGradient(colors: [
    NSColor(calibratedRed: 0.055, green: 0.09, blue: 0.14, alpha: 1),
    NSColor(calibratedRed: 0.08, green: 0.54, blue: 0.46, alpha: 1),
    NSColor(calibratedRed: 0.94, green: 0.57, blue: 0.14, alpha: 1)
])!.draw(in: outer, angle: -42)

let glow = NSBezierPath(ovalIn: NSRect(x: 380, y: 440, width: 620, height: 620))
NSColor.white.withAlphaComponent(0.13).setFill()
glow.fill()
NSGraphicsContext.current?.restoreGraphicsState()

NSColor.white.withAlphaComponent(0.18).setStroke()
outer.lineWidth = 8
outer.stroke()

let center = NSPoint(x: 512, y: 512)
for (radius, alpha, width) in [(260.0, 0.24, 28.0), (174.0, 0.46, 30.0)] {
    let ring = NSBezierPath(ovalIn: NSRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
    NSColor.white.withAlphaComponent(alpha).setStroke()
    ring.lineWidth = width
    ring.stroke()
}

let hand = NSBezierPath()
hand.move(to: center)
hand.line(to: NSPoint(x: 512, y: 696))
hand.move(to: center)
hand.line(to: NSPoint(x: 650, y: 432))
hand.lineCapStyle = .round
hand.lineJoinStyle = .round
hand.lineWidth = 46
NSColor.white.setStroke()
hand.stroke()

let dot = NSBezierPath(ovalIn: NSRect(x: 476, y: 476, width: 72, height: 72))
NSColor.white.setFill()
dot.fill()

image.unlockFocus()
guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Could not encode icon")
}
try png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
