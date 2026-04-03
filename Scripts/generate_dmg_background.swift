import AppKit

let fileManager = FileManager.default
let projectRoot = URL(fileURLWithPath: fileManager.currentDirectoryPath)
let outputURL = projectRoot.appendingPathComponent("build/dmg-background.png")

let width: CGFloat = 700
let height: CGFloat = 440
let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(width),
    pixelsHigh: Int(height),
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
)!

NSGraphicsContext.saveGraphicsState()
let context = NSGraphicsContext(bitmapImageRep: rep)!
NSGraphicsContext.current = context

let canvas = NSRect(x: 0, y: 0, width: width, height: height)
NSGraphicsContext.current?.imageInterpolation = .high

let base = NSGradient(colors: [
    NSColor(calibratedRed: 0.95, green: 0.965, blue: 0.98, alpha: 1),
    NSColor(calibratedRed: 0.87, green: 0.90, blue: 0.95, alpha: 1),
])!
base.draw(in: canvas, angle: -25)

for (rect, color, alpha) in [
    (NSRect(x: 30, y: 220, width: 280, height: 180), NSColor(calibratedRed: 0.34, green: 0.84, blue: 0.72, alpha: 1), 0.20),
    (NSRect(x: 250, y: 160, width: 240, height: 170), NSColor(calibratedRed: 0.27, green: 0.67, blue: 0.93, alpha: 1), 0.18),
    (NSRect(x: 440, y: 260, width: 180, height: 120), NSColor.white, 0.35),
    (NSRect(x: 120, y: 40, width: 360, height: 110), NSColor(calibratedWhite: 1, alpha: 1), 0.18),
] as [(NSRect, NSColor, CGFloat)] {
    let path = NSBezierPath(ovalIn: rect)
    color.withAlphaComponent(alpha).setFill()
    path.fill()
}

let panelRect = NSRect(x: 36, y: 285, width: 295, height: 105)
let panelPath = NSBezierPath(roundedRect: panelRect, xRadius: 24, yRadius: 24)
NSColor.white.withAlphaComponent(0.35).setFill()
panelPath.fill()
NSColor.white.withAlphaComponent(0.45).setStroke()
panelPath.lineWidth = 1
panelPath.stroke()

let titleAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 34, weight: .bold),
    .foregroundColor: NSColor(calibratedRed: 0.10, green: 0.14, blue: 0.19, alpha: 1)
]
let subtitleAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 16, weight: .medium),
    .foregroundColor: NSColor(calibratedRed: 0.26, green: 0.32, blue: 0.40, alpha: 0.92)
]

("Keyboard Cleaner" as NSString).draw(at: CGPoint(x: 60, y: 340), withAttributes: titleAttrs)
("Drag to Applications to install" as NSString).draw(at: CGPoint(x: 62, y: 308), withAttributes: subtitleAttrs)

let sparkle = NSBezierPath()
sparkle.lineWidth = 6
sparkle.lineCapStyle = .round
sparkle.move(to: CGPoint(x: 600, y: 360))
sparkle.line(to: CGPoint(x: 600, y: 400))
sparkle.move(to: CGPoint(x: 580, y: 380))
sparkle.line(to: CGPoint(x: 620, y: 380))
NSColor.white.withAlphaComponent(0.88).setStroke()
sparkle.stroke()

NSGraphicsContext.restoreGraphicsState()

guard let data = rep.representation(using: .png, properties: [:]) else {
    throw NSError(domain: "DMGBackground", code: 1)
}

try fileManager.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
try data.write(to: outputURL)
