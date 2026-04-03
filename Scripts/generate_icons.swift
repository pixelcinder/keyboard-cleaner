import AppKit

let fileManager = FileManager.default
let projectRoot = URL(fileURLWithPath: fileManager.currentDirectoryPath)
let appIconSetURL = projectRoot.appendingPathComponent("KeyboardCleaner/Assets.xcassets/AppIcon.appiconset")
let menuBarIconSetURL = projectRoot.appendingPathComponent("KeyboardCleaner/Assets.xcassets/MenuBarIcon.imageset")
let previewURL = projectRoot.appendingPathComponent("icon_preview_v2.png")

struct Palette {
    static let inkTop = NSColor(calibratedRed: 0.09, green: 0.12, blue: 0.17, alpha: 1)
    static let inkBottom = NSColor(calibratedRed: 0.05, green: 0.07, blue: 0.11, alpha: 1)
    static let mint = NSColor(calibratedRed: 0.33, green: 0.85, blue: 0.73, alpha: 1)
    static let aqua = NSColor(calibratedRed: 0.28, green: 0.68, blue: 0.92, alpha: 1)
    static let keyTop = NSColor(calibratedWhite: 0.98, alpha: 0.98)
    static let keyBottom = NSColor(calibratedWhite: 0.86, alpha: 0.96)
    static let graphite = NSColor(calibratedRed: 0.16, green: 0.19, blue: 0.24, alpha: 1)
}

func roundedRectPath(_ rect: NSRect, radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
}

func fillLinearGradient(in path: NSBezierPath, colors: [NSColor], angle: CGFloat) {
    let gradient = NSGradient(colors: colors)!
    gradient.draw(in: path, angle: angle)
}

func drawGlow(in rect: NSRect, color: NSColor, alpha: CGFloat) {
    let glowPath = NSBezierPath(ovalIn: rect)
    color.withAlphaComponent(alpha).setFill()
    glowPath.fill()
}

func drawSparkle(center: CGPoint, radius: CGFloat, color: NSColor) {
    let sparkle = NSBezierPath()
    sparkle.lineWidth = max(1, radius * 0.28)
    sparkle.lineCapStyle = .round
    sparkle.move(to: CGPoint(x: center.x, y: center.y + radius))
    sparkle.line(to: CGPoint(x: center.x, y: center.y - radius))
    sparkle.move(to: CGPoint(x: center.x - radius, y: center.y))
    sparkle.line(to: CGPoint(x: center.x + radius, y: center.y))
    color.setStroke()
    sparkle.stroke()
}

func savePNG(image: NSImage, to url: URL) throws {
    guard
        let tiff = image.tiffRepresentation,
        let rep = NSBitmapImageRep(data: tiff),
        let data = rep.representation(using: .png, properties: [:])
    else {
        throw NSError(domain: "IconGeneration", code: 1)
    }
    try data.write(to: url)
}

func drawAppIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    defer { image.unlockFocus() }

    NSGraphicsContext.current?.imageInterpolation = .high

    let canvas = NSRect(x: 0, y: 0, width: size, height: size)
    let iconRect = canvas.insetBy(dx: size * 0.035, dy: size * 0.035)
    let iconRadius = size * 0.23

    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.22)
    shadow.shadowBlurRadius = size * 0.05
    shadow.shadowOffset = NSSize(width: 0, height: -size * 0.02)
    shadow.set()

    let iconPath = roundedRectPath(iconRect, radius: iconRadius)
    fillLinearGradient(in: iconPath, colors: [Palette.inkTop, Palette.inkBottom], angle: -90)

    NSGraphicsContext.current?.saveGraphicsState()
    iconPath.addClip()

    drawGlow(
        in: NSRect(x: size * 0.16, y: size * 0.52, width: size * 0.48, height: size * 0.34),
        color: Palette.mint,
        alpha: 0.22
    )
    drawGlow(
        in: NSRect(x: size * 0.46, y: size * 0.44, width: size * 0.34, height: size * 0.28),
        color: Palette.aqua,
        alpha: 0.18
    )
    drawGlow(
        in: NSRect(x: size * 0.26, y: size * 0.10, width: size * 0.56, height: size * 0.30),
        color: NSColor.white,
        alpha: 0.06
    )

    let glossPath = roundedRectPath(
        NSRect(x: iconRect.minX, y: iconRect.midY, width: iconRect.width, height: iconRect.height * 0.48),
        radius: iconRadius
    )
    let gloss = NSGradient(colors: [
        NSColor.white.withAlphaComponent(0.12),
        NSColor.white.withAlphaComponent(0.03),
        .clear,
    ])!
    gloss.draw(in: glossPath, angle: 90)

    let keyWidth = size * 0.43
    let keyHeight = size * 0.30
    let keyRect = NSRect(
        x: (size - keyWidth) / 2,
        y: size * 0.31,
        width: keyWidth,
        height: keyHeight
    )
    let keyBaseRect = keyRect.offsetBy(dx: 0, dy: -size * 0.03)

    let baseShadow = NSShadow()
    baseShadow.shadowColor = NSColor.black.withAlphaComponent(0.18)
    baseShadow.shadowBlurRadius = size * 0.03
    baseShadow.shadowOffset = NSSize(width: 0, height: -size * 0.012)
    baseShadow.set()

    let keyBasePath = roundedRectPath(keyBaseRect, radius: size * 0.09)
    fillLinearGradient(
        in: keyBasePath,
        colors: [
            NSColor(calibratedWhite: 0.82, alpha: 0.92),
            NSColor(calibratedWhite: 0.72, alpha: 0.88),
        ],
        angle: -90
    )

    NSShadow().set()

    let keyFacePath = roundedRectPath(keyRect, radius: size * 0.09)
    fillLinearGradient(in: keyFacePath, colors: [Palette.keyTop, Palette.keyBottom], angle: -90)

    let innerHighlight = roundedRectPath(keyRect.insetBy(dx: size * 0.008, dy: size * 0.008), radius: size * 0.08)
    NSColor.white.withAlphaComponent(0.28).setStroke()
    innerHighlight.lineWidth = max(1.5, size * 0.006)
    innerHighlight.stroke()

    let sheenPath = NSBezierPath()
    sheenPath.lineWidth = size * 0.028
    sheenPath.lineCapStyle = .round
    sheenPath.move(to: CGPoint(x: keyRect.minX + keyRect.width * 0.22, y: keyRect.maxY - keyRect.height * 0.28))
    sheenPath.curve(
        to: CGPoint(x: keyRect.maxX - keyRect.width * 0.14, y: keyRect.midY + keyRect.height * 0.06),
        controlPoint1: CGPoint(x: keyRect.midX - keyRect.width * 0.04, y: keyRect.maxY - keyRect.height * 0.06),
        controlPoint2: CGPoint(x: keyRect.maxX - keyRect.width * 0.32, y: keyRect.midY + keyRect.height * 0.18)
    )
    Palette.aqua.withAlphaComponent(0.28).setStroke()
    sheenPath.stroke()

    let dot = NSBezierPath(ovalIn: NSRect(x: keyRect.midX - size * 0.017, y: keyRect.midY - size * 0.017, width: size * 0.034, height: size * 0.034))
    Palette.graphite.withAlphaComponent(0.88).setFill()
    dot.fill()

    drawSparkle(center: CGPoint(x: size * 0.73, y: size * 0.71), radius: size * 0.045, color: NSColor.white.withAlphaComponent(0.95))
    drawSparkle(center: CGPoint(x: size * 0.25, y: size * 0.22), radius: size * 0.026, color: Palette.mint.withAlphaComponent(0.85))

    let edgePath = roundedRectPath(iconRect.insetBy(dx: size * 0.004, dy: size * 0.004), radius: iconRadius * 0.96)
    let edgeGradient = NSGradient(colors: [
        NSColor.white.withAlphaComponent(0.22),
        NSColor.white.withAlphaComponent(0.03),
        NSColor.black.withAlphaComponent(0.12),
    ])!
    edgeGradient.draw(in: edgePath, angle: -62)

    NSGraphicsContext.current?.restoreGraphicsState()

    return image
}

func drawMenuBarIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    defer { image.unlockFocus() }

    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    let keyRect = rect.insetBy(dx: size * 0.19, dy: size * 0.22)
    let path = roundedRectPath(keyRect, radius: size * 0.18)
    NSColor.black.setStroke()
    path.lineWidth = max(1.2, size * 0.11)
    path.stroke()

    let shine = NSBezierPath()
    shine.lineWidth = max(1.1, size * 0.095)
    shine.lineCapStyle = .round
    shine.move(to: CGPoint(x: keyRect.minX + size * 0.18, y: keyRect.maxY - size * 0.25))
    shine.line(to: CGPoint(x: keyRect.midX + size * 0.05, y: keyRect.midY + size * 0.02))
    NSColor.black.setStroke()
    shine.stroke()

    let sparkle = NSBezierPath()
    let s = size * 0.10
    let c = CGPoint(x: rect.maxX - size * 0.24, y: rect.maxY - size * 0.25)
    sparkle.lineWidth = max(1, size * 0.08)
    sparkle.lineCapStyle = .round
    sparkle.move(to: CGPoint(x: c.x, y: c.y + s))
    sparkle.line(to: CGPoint(x: c.x, y: c.y - s))
    sparkle.move(to: CGPoint(x: c.x - s, y: c.y))
    sparkle.line(to: CGPoint(x: c.x + s, y: c.y))
    NSColor.black.setStroke()
    sparkle.stroke()

    return image
}

try fileManager.createDirectory(at: menuBarIconSetURL, withIntermediateDirectories: true)

let appSizes: [(Int, String)] = [
    (16, "icon_16x16.png"),
    (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"),
    (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"),
    (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"),
    (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"),
    (1024, "icon_512x512@2x.png"),
]

for (size, fileName) in appSizes {
    let image = drawAppIcon(size: CGFloat(size))
    try savePNG(image: image, to: appIconSetURL.appendingPathComponent(fileName))
}

try savePNG(image: drawAppIcon(size: 1024), to: previewURL)
try savePNG(image: drawMenuBarIcon(size: 18), to: menuBarIconSetURL.appendingPathComponent("menubar.png"))
try savePNG(image: drawMenuBarIcon(size: 36), to: menuBarIconSetURL.appendingPathComponent("menubar@2x.png"))
