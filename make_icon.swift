import AppKit
import CoreGraphics

// Run with: swift make_icon.swift Resources/AppIcon.png
guard CommandLine.arguments.count == 2 else {
    fatalError("Usage: swift make_icon.swift path/to/AppIcon.png")
}
let outputPath = CommandLine.arguments[1]

let scriptDir = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
let archUrl = scriptDir.appendingPathComponent("Resources/antigravity_arch.png")
guard let archData = try? Data(contentsOf: archUrl),
      let archRep = NSBitmapImageRep(data: archData),
      let archImg = archRep.cgImage else {
    fatalError("Failed to load \(archUrl.path)")
}

let size: CGFloat = 1024
let colorSpace = CGColorSpaceCreateDeviceRGB()
let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
guard let ctx = CGContext(data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace, bitmapInfo: bitmapInfo) else {
    fatalError("Failed to create CGContext")
}

ctx.setAllowsAntialiasing(true)
ctx.setShouldAntialias(true)
ctx.interpolationQuality = .high

func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1.0) -> NSColor {
    return NSColor(calibratedRed: r / 255.0, green: g / 255.0, blue: b / 255.0, alpha: a)
}

// 1. Base Squircle & Ambient Drop Shadow
let baseRect = CGRect(x: 52, y: 52, width: 920, height: 920)
let squircle = CGPath(roundedRect: baseRect, cornerWidth: 215, cornerHeight: 215, transform: nil)

ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -24), blur: 44, color: color(0, 0, 0, 0.60).cgColor)
ctx.setFillColor(color(12, 16, 26).cgColor)
ctx.addPath(squircle); ctx.fillPath()
ctx.restoreGState()

// 2. Base Gradient & Studio Lighting
ctx.saveGState()
ctx.addPath(squircle); ctx.clip()

let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                      colors: [color(26, 36, 58).cgColor,
                               color(14, 18, 30).cgColor,
                               color(7, 9, 16).cgColor] as CFArray,
                      locations: [0.0, 0.52, 1.0])!
ctx.drawLinearGradient(grad, start: CGPoint(x: 512, y: 972), end: CGPoint(x: 512, y: 52), options: [])

// Radial Ambient Core Glow
let glowCenter = CGPoint(x: 512, y: 535)
let glowGrad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                          colors: [color(0, 185, 255, 0.30).cgColor,
                                   color(255, 80, 50, 0.16).cgColor,
                                   color(0, 0, 0, 0).cgColor] as CFArray,
                          locations: [0.0, 0.45, 1.0])!
ctx.drawRadialGradient(glowGrad, startCenter: glowCenter, startRadius: 20, endCenter: glowCenter, endRadius: 460, options: [])

// Crisp Specular Top Rim Light
ctx.setStrokeColor(color(255, 255, 255, 0.22).cgColor)
ctx.setLineWidth(4.0); ctx.addPath(squircle); ctx.strokePath()
ctx.restoreGState()

// 3. Staggered 3D Antigravity Waves
// Left-Back Instance (Wave 3)
ctx.saveGState()
ctx.setAlpha(0.50)
ctx.setShadow(offset: CGSize(width: -16, height: -18), blur: 32, color: color(80, 50, 240, 0.45).cgColor)
let r3 = CGRect(x: 155, y: 355, width: 400, height: 400)
ctx.draw(archImg, in: r3)
ctx.restoreGState()

// Right-Back Instance (Wave 2)
ctx.saveGState()
ctx.setAlpha(0.70)
ctx.setShadow(offset: CGSize(width: 16, height: -18), blur: 32, color: color(0, 190, 255, 0.45).cgColor)
let r2 = CGRect(x: 469, y: 355, width: 400, height: 400)
ctx.draw(archImg, in: r2)
ctx.restoreGState()

// Front-Center Main Instance (Wave 1)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -30), blur: 50, color: color(0, 0, 0, 0.85).cgColor)
let r1 = CGRect(x: 232, y: 195, width: 560, height: 560)
ctx.draw(archImg, in: r1)
ctx.restoreGState()

// 4. Floating Multi-Instance Controller Pill at bottom
let pillBg = CGPath(roundedRect: CGRect(x: 320, y: 120, width: 384, height: 58), cornerWidth: 29, cornerHeight: 29, transform: nil)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -8), blur: 20, color: color(0, 0, 0, 0.60).cgColor)
ctx.setFillColor(color(18, 24, 40, 0.96).cgColor)
ctx.addPath(pillBg); ctx.fillPath()
ctx.setStrokeColor(color(0, 225, 255, 0.75).cgColor)
ctx.setLineWidth(3.5); ctx.addPath(pillBg); ctx.strokePath()

// 4 Google Colors Instance Indicators (Blue, Green, Yellow, Red)
let pillDots: [(CGFloat, NSColor)] = [
    (380, color(66, 133, 244)),   // Primary (Original)
    (468, color(52, 168, 83)),    // Second
    (556, color(251, 188, 4)),    // Third
    (644, color(234, 67, 53))     // Fourth
]
for (x, col) in pillDots {
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: 16, color: col.cgColor)
    ctx.setFillColor(col.cgColor)
    ctx.fillEllipse(in: CGRect(x: x - 13, y: 149 - 13, width: 26, height: 26))
    ctx.setFillColor(color(255, 255, 255, 0.95).cgColor)
    ctx.fillEllipse(in: CGRect(x: x - 5, y: 149 - 5, width: 10, height: 10))
    ctx.restoreGState()
}
ctx.restoreGState()

guard let masterImg = ctx.makeImage() else { fatalError("makeImage failed") }
let rep = NSBitmapImageRep(cgImage: masterImg)
guard let data = rep.representation(using: .png, properties: [:]) else { fatalError("png representation failed") }
try data.write(to: URL(fileURLWithPath: outputPath))
print("Saved \(outputPath)!")
