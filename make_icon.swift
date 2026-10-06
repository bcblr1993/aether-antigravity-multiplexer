import AppKit

// Run with swift make_icon.swift Resources/AppIcon.png.
// Coordinates are in the 1024-point icon canvas and remain legible at Dock sizes.
let size = 1024
let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                              bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                              isPlanar: false, colorSpaceName: .deviceRGB,
                              bytesPerRow: 0, bitsPerPixel: 0)!

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(calibratedRed: red / 255, green: green / 255, blue: blue / 255, alpha: alpha)
}

func rounded(_ rect: NSRect, radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
}

func stroke(_ path: NSBezierPath, color ink: NSColor, width: CGFloat) {
    ink.setStroke()
    path.lineWidth = width
    path.lineCapStyle = .round
    path.lineJoinStyle = .round
    path.stroke()
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
NSGraphicsContext.current?.imageInterpolation = .high

let base = rounded(NSRect(x: 40, y: 40, width: 944, height: 944), radius: 215)
NSGradient(starting: color(16, 29, 72), ending: color(42, 70, 170))!
    .draw(in: base, angle: -36)

// A subtle highlight gives depth without imitating the system's glass effect.
NSGraphicsContext.saveGraphicsState()
base.addClip()
let upperGlow = NSBezierPath(ovalIn: NSRect(x: 350, y: 585, width: 700, height: 510))
NSGradient(starting: color(105, 172, 255, 0.20), ending: color(105, 172, 255, 0))!
    .draw(in: upperGlow, relativeCenterPosition: NSPoint(x: 0, y: 0))
NSGraphicsContext.restoreGraphicsState()

// Three independent application windows, with a single front-facing identity.
let left = rounded(NSRect(x: 135, y: 290, width: 498, height: 465), radius: 94)
color(84, 217, 242, 0.23).setFill(); left.fill()
stroke(left, color: color(149, 239, 253, 0.75), width: 12)

let right = rounded(NSRect(x: 391, y: 290, width: 498, height: 465), radius: 94)
color(149, 134, 255, 0.34).setFill(); right.fill()
stroke(right, color: color(189, 180, 255, 0.80), width: 12)

let frontRect = NSRect(x: 233, y: 213, width: 558, height: 550)
let front = rounded(frontRect, radius: 105)
NSGradient(starting: color(248, 251, 255), ending: color(207, 227, 255))!
    .draw(in: front, angle: 90)
stroke(front, color: color(255, 255, 255, 0.85), width: 10)

// Restrained title-bar detail identifies the shapes as windows at large sizes.
for x in [317.0, 352.0, 387.0] {
    color(72, 104, 177, 0.48).setFill()
    NSBezierPath(ovalIn: NSRect(x: x, y: 692, width: 17, height: 17)).fill()
}

// The broad A is the Aether mark and remains recognizable at 16 points.
let mark = NSBezierPath()
mark.move(to: NSPoint(x: 339, y: 321))
mark.line(to: NSPoint(x: 512, y: 614))
mark.line(to: NSPoint(x: 685, y: 321))
stroke(mark, color: color(31, 65, 152), width: 66)
let crossbar = NSBezierPath()
crossbar.move(to: NSPoint(x: 426, y: 420))
crossbar.line(to: NSPoint(x: 598, y: 420))
stroke(crossbar, color: color(49, 112, 227), width: 55)

NSGraphicsContext.current?.flushGraphics()
NSGraphicsContext.restoreGraphicsState()
guard CommandLine.arguments.count == 2,
      let data = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Usage: swift make_icon.swift path/to/AppIcon.png")
}
try data.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
