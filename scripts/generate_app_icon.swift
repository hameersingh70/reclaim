#!/usr/bin/env swift
import Cocoa
import CoreGraphics

func createReclaimIcon(pixelSize: Int) -> NSImage {
    let size = CGFloat(pixelSize)
    let img = NSImage(size: NSSize(width: size, height: size))
    img.lockFocus()
    guard let ctx = NSGraphicsContext.current?.cgContext else {
        img.unlockFocus()
        return img
    }

    let scale = size / 1024.0

    ctx.setAllowsAntialiasing(true)
    ctx.setShouldAntialias(true)
    ctx.interpolationQuality = .high

    // 1. Squircle dimensions (conforming to macOS Big Sur+ HIG icon grid)
    let bodySize: CGFloat = 824.0 * scale
    let bodyOrigin: CGFloat = (size - bodySize) / 2.0
    let squircleRect = CGRect(x: bodyOrigin, y: bodyOrigin, width: bodySize, height: bodySize)
    let cornerRadius: CGFloat = 185.0 * scale
    let squirclePath = CGPath(roundedRect: squircleRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)

    // Shadow for Squircle
    ctx.saveGState()
    let shadowColor = CGColor(red: 0, green: 0, blue: 0, alpha: 0.35)
    ctx.setShadow(offset: CGSize(width: 0, height: -12.0 * scale), blur: 24.0 * scale, color: shadowColor)

    // Outer Neo-Brutalist Border Fill
    ctx.setFillColor(CGColor(red: 0.06, green: 0.07, blue: 0.09, alpha: 1.0))
    ctx.addPath(squirclePath)
    ctx.fillPath()
    ctx.restoreGState()

    // 2. Draw Squircle Body with Gradient
    ctx.saveGState()
    ctx.addPath(squirclePath)
    ctx.clip()

    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bgColors = [
        CGColor(red: 0.11, green: 0.12, blue: 0.15, alpha: 1.0), // Deep obsidian
        CGColor(red: 0.06, green: 0.07, blue: 0.09, alpha: 1.0)  // Near pitch black
    ] as CFArray
    let bgLocations: [CGFloat] = [0.0, 1.0]
    if let bgGradient = CGGradient(colorsSpace: colorSpace, colors: bgColors, locations: bgLocations) {
        ctx.drawLinearGradient(bgGradient, start: CGPoint(x: size/2, y: bodyOrigin + bodySize), end: CGPoint(x: size/2, y: bodyOrigin), options: [])
    }

    // Concentric Radar Rings
    ctx.setStrokeColor(CGColor(red: 0.20, green: 0.23, blue: 0.28, alpha: 0.4))
    ctx.setLineWidth(max(1.0, 2.0 * scale))
    let center = CGPoint(x: size / 2.0, y: size / 2.0)
    for r in [140.0, 230.0, 320.0] {
        ctx.strokeEllipse(in: CGRect(x: center.x - r * scale, y: center.y - r * scale, width: r * 2.0 * scale, height: r * 2.0 * scale))
    }

    // Glowing Cyan Storage Reclaim Arc
    ctx.setStrokeColor(CGColor(red: 0.0, green: 0.88, blue: 1.0, alpha: 0.4))
    ctx.setLineWidth(max(1.5, 5.0 * scale))
    ctx.addArc(center: center, radius: 275.0 * scale, startAngle: 0.2, endAngle: 2.8, clockwise: false)
    ctx.strokePath()

    // Tech dots (only when resolution is >= 128)
    if pixelSize >= 128 {
        ctx.setFillColor(CGColor(red: 0.25, green: 0.30, blue: 0.38, alpha: 0.3))
        for xStep in stride(from: -300.0, through: 300.0, by: 75.0) {
            for yStep in stride(from: -300.0, through: 300.0, by: 75.0) {
                let dotRect = CGRect(x: center.x + xStep * scale - 1.5 * scale, y: center.y + yStep * scale - 1.5 * scale, width: 3.0 * scale, height: 3.0 * scale)
                ctx.fillEllipse(in: dotRect)
            }
        }
    }

    ctx.restoreGState()

    // 3. Squircle Inner Highlight Rim
    ctx.saveGState()
    ctx.addPath(squirclePath)
    ctx.setStrokeColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.12))
    ctx.setLineWidth(max(1.0, 3.0 * scale))
    ctx.strokePath()
    ctx.restoreGState()

    // 4. Kinetic Lightning Wedge / Bolt (Center Hero Symbol)
    let boltPath = CGMutablePath()
    boltPath.move(to: CGPoint(x: 550 * scale, y: 770 * scale))
    boltPath.addLine(to: CGPoint(x: 350 * scale, y: 520 * scale))
    boltPath.addLine(to: CGPoint(x: 480 * scale, y: 520 * scale))
    boltPath.addLine(to: CGPoint(x: 430 * scale, y: 250 * scale))
    boltPath.addLine(to: CGPoint(x: 670 * scale, y: 540 * scale))
    boltPath.addLine(to: CGPoint(x: 535 * scale, y: 540 * scale))
    boltPath.closeSubpath()

    // Shadow for Bolt
    ctx.saveGState()
    let boltGlow = CGColor(red: 1.0, green: 0.82, blue: 0.1, alpha: 0.6)
    ctx.setShadow(offset: CGSize(width: 0, height: -4.0 * scale), blur: max(2.0, 28.0 * scale), color: boltGlow)

    // Left & Right Blades
    let leftBlade = CGMutablePath()
    leftBlade.move(to: CGPoint(x: 550 * scale, y: 770 * scale))
    leftBlade.addLine(to: CGPoint(x: 350 * scale, y: 520 * scale))
    leftBlade.addLine(to: CGPoint(x: 480 * scale, y: 520 * scale))
    leftBlade.addLine(to: CGPoint(x: 430 * scale, y: 250 * scale))
    leftBlade.addLine(to: CGPoint(x: 510 * scale, y: 535 * scale))
    leftBlade.closeSubpath()

    let rightBlade = CGMutablePath()
    rightBlade.move(to: CGPoint(x: 550 * scale, y: 770 * scale))
    rightBlade.addLine(to: CGPoint(x: 510 * scale, y: 535 * scale))
    rightBlade.addLine(to: CGPoint(x: 430 * scale, y: 250 * scale))
    rightBlade.addLine(to: CGPoint(x: 670 * scale, y: 540 * scale))
    rightBlade.addLine(to: CGPoint(x: 535 * scale, y: 540 * scale))
    rightBlade.closeSubpath()

    // Left Blade Gradient (Cyan Energy)
    ctx.saveGState()
    ctx.addPath(leftBlade)
    ctx.clip()
    let cyanColors = [
        CGColor(red: 0.0, green: 0.95, blue: 0.9, alpha: 1.0),
        CGColor(red: 0.0, green: 0.55, blue: 0.95, alpha: 1.0)
    ] as CFArray
    if let cyanGrad = CGGradient(colorsSpace: colorSpace, colors: cyanColors, locations: [0.0, 1.0]) {
        ctx.drawLinearGradient(cyanGrad, start: CGPoint(x: 350 * scale, y: 700 * scale), end: CGPoint(x: 500 * scale, y: 300 * scale), options: [])
    }
    ctx.restoreGState()

    // Right Blade Gradient (Electric Amber)
    ctx.saveGState()
    ctx.addPath(rightBlade)
    ctx.clip()
    let amberColors = [
        CGColor(red: 1.0, green: 0.88, blue: 0.1, alpha: 1.0),
        CGColor(red: 1.0, green: 0.50, blue: 0.05, alpha: 1.0)
    ] as CFArray
    if let amberGrad = CGGradient(colorsSpace: colorSpace, colors: amberColors, locations: [0.0, 1.0]) {
        ctx.drawLinearGradient(amberGrad, start: CGPoint(x: 550 * scale, y: 750 * scale), end: CGPoint(x: 650 * scale, y: 300 * scale), options: [])
    }
    ctx.restoreGState()

    // Razor-Sharp Outer Stroke on Bolt
    ctx.addPath(boltPath)
    ctx.setStrokeColor(CGColor(red: 0.05, green: 0.05, blue: 0.06, alpha: 1.0))
    ctx.setLineWidth(max(1.0, 6.0 * scale))
    ctx.strokePath()

    // Center Spine Highlight
    ctx.setStrokeColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.85))
    ctx.setLineWidth(max(0.75, 2.5 * scale))
    ctx.move(to: CGPoint(x: 550 * scale, y: 760 * scale))
    ctx.addLine(to: CGPoint(x: 510 * scale, y: 535 * scale))
    ctx.addLine(to: CGPoint(x: 435 * scale, y: 260 * scale))
    ctx.strokePath()

    ctx.restoreGState()

    img.unlockFocus()
    return img
}

func savePNG(image: NSImage, pixelSize: Int, path: String) throws {
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff) else {
        throw NSError(domain: "IconGen", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create bitmap rep"])
    }
    rep.size = NSSize(width: pixelSize, height: pixelSize)
    guard let pngData = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "IconGen", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create PNG data"])
    }
    try pngData.write(to: URL(fileURLWithPath: path))
}

let fm = FileManager.default
let scriptDir = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent().path
let rootDir = (scriptDir as NSString).deletingLastPathComponent
let iconsetDir = "/tmp/ReclaimAppIcon.iconset"
try? fm.removeItem(atPath: iconsetDir)
try fm.createDirectory(atPath: iconsetDir, withIntermediateDirectories: true)

let specs: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for (filename, px) in specs {
    let img = createReclaimIcon(pixelSize: px)
    let dest = "\(iconsetDir)/\(filename)"
    try savePNG(image: img, pixelSize: px, path: dest)
}

let targetICNS = "\(rootDir)/Sources/ReclaimUI/Resources/AppIcon.icns"
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsetDir, "-o", targetICNS]
try process.run()
process.waitUntilExit()

print("✅ Successfully generated Reclaim AppIcon.icns at \(targetICNS)")
