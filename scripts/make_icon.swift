// Draws the DockMinimize app icon and writes a 1024×1024 PNG.
// Usage: swift scripts/make_icon.swift <output.png>
import AppKit

let canvas: CGFloat = 1024

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        red: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

func roundedRect(_ rect: CGRect, _ radius: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

/// A macOS-style window: white body, title bar with traffic lights, a few content lines.
func drawWindow(_ ctx: CGContext, center: CGPoint, scale: CGFloat, alpha: CGFloat) {
    let size = CGSize(width: 440 * scale, height: 270 * scale)
    let rect = CGRect(x: center.x - size.width / 2, y: center.y - size.height / 2, width: size.width, height: size.height)
    let radius = 34 * scale

    ctx.saveGState()
    ctx.setAlpha(alpha)
    ctx.beginTransparencyLayer(auxiliaryInfo: nil)

    ctx.setShadow(offset: CGSize(width: 0, height: -14 * scale), blur: 40 * scale, color: color(0x140A4D, 0.45))
    ctx.addPath(roundedRect(rect, radius))
    ctx.setFillColor(color(0xFFFFFF))
    ctx.fillPath()
    ctx.setShadow(offset: .zero, blur: 0, color: nil)

    // Title bar.
    let titleHeight = 56 * scale
    ctx.saveGState()
    ctx.addPath(roundedRect(rect, radius))
    ctx.clip()
    ctx.setFillColor(color(0xEEF0FB))
    ctx.fill(CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: titleHeight))
    ctx.restoreGState()

    let lights: [UInt32] = [0xFF5F57, 0xFEBC2E, 0x28C840]
    for (index, hex) in lights.enumerated() {
        let r = 11 * scale
        let cx = rect.minX + 38 * scale + CGFloat(index) * 34 * scale
        ctx.setFillColor(color(hex))
        ctx.fillEllipse(in: CGRect(x: cx - r, y: rect.minY + titleHeight / 2 - r, width: r * 2, height: r * 2))
    }

    // Content lines.
    let lineWidths: [CGFloat] = [300, 360, 250]
    for (index, width) in lineWidths.enumerated() {
        let y = rect.minY + titleHeight + 44 * scale + CGFloat(index) * 48 * scale
        let line = CGRect(x: rect.minX + 40 * scale, y: y, width: width * scale, height: 20 * scale)
        ctx.addPath(roundedRect(line, 10 * scale))
        ctx.setFillColor(color(0xD9DCF2))
        ctx.fillPath()
    }

    ctx.endTransparencyLayer()
    ctx.restoreGState()
}

func lerp(_ a: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint {
    CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
}

func drawIcon(_ ctx: CGContext) {
    // Work in top-left-origin coordinates.
    ctx.translateBy(x: 0, y: canvas)
    ctx.scaleBy(x: 1, y: -1)

    // Squircle body following the macOS icon grid (824pt body, 100pt margin).
    let body = CGRect(x: 100, y: 100, width: 824, height: 824)
    let bodyPath = roundedRect(body, 185)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: color(0x000000, 0.35))
    ctx.addPath(bodyPath)
    ctx.setFillColor(color(0x4B3FD6))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(bodyPath)
    ctx.clip()
    let background = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [color(0x7C8CFF), color(0x5A49E0), color(0x3A1F9E)] as CFArray,
        locations: [0, 0.55, 1]
    )!
    ctx.drawLinearGradient(background, start: CGPoint(x: 300, y: 100), end: CGPoint(x: 724, y: 924),
                           options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])

    // Soft highlight in the top-left corner.
    let glow = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [color(0xFFFFFF, 0.28), color(0xFFFFFF, 0)] as CFArray,
        locations: [0, 1]
    )!
    ctx.drawRadialGradient(glow, startCenter: CGPoint(x: 260, y: 200), startRadius: 0,
                           endCenter: CGPoint(x: 260, y: 200), endRadius: 520, options: [])

    // Dock shelf.
    let dock = CGRect(x: 212, y: 712, width: 600, height: 116)
    ctx.addPath(roundedRect(dock, 40))
    ctx.setFillColor(color(0xFFFFFF, 0.2))
    ctx.fillPath()
    ctx.addPath(roundedRect(dock.insetBy(dx: 1.5, dy: 1.5), 38.5))
    ctx.setStrokeColor(color(0xFFFFFF, 0.4))
    ctx.setLineWidth(3)
    ctx.strokePath()

    let dockIcons: [(x: CGFloat, hex: UInt32)] = [(332, 0x5EE0C7), (452, 0xFFB86B), (572, 0xFFFFFF), (692, 0xFF7AA8)]
    let iconSize: CGFloat = 68
    let iconTop = dock.minY + 12
    for icon in dockIcons {
        let rect = CGRect(x: icon.x - iconSize / 2, y: iconTop, width: iconSize, height: iconSize)
        ctx.addPath(roundedRect(rect, 17))
        ctx.setFillColor(color(icon.hex, icon.hex == 0xFFFFFF ? 1 : 0.9))
        ctx.fillPath()
    }
    // "Running" dot under the target app.
    ctx.setFillColor(color(0xFFFFFF))
    ctx.fillEllipse(in: CGRect(x: 572 - 7, y: iconTop + iconSize + 7, width: 14, height: 14))

    // The window shrinking down into the Dock (genie trail).
    let windowCenter = CGPoint(x: 512, y: 312)
    let target = CGPoint(x: 572, y: iconTop + iconSize / 2)
    drawWindow(ctx, center: lerp(windowCenter, target, 0.76), scale: 0.3, alpha: 0.35)
    drawWindow(ctx, center: lerp(windowCenter, target, 0.47), scale: 0.56, alpha: 0.55)
    drawWindow(ctx, center: windowCenter, scale: 1, alpha: 1)

    ctx.restoreGState()
}

let output = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.png"
let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(canvas), pixelsHigh: Int(canvas),
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
)!
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
drawIcon(NSGraphicsContext.current!.cgContext)
NSGraphicsContext.current = nil
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output))
print("Wrote \(output)")
