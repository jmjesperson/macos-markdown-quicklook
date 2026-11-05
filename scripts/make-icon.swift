import AppKit

// 1024×1024 macOS app icon: a dark rounded tile (Apple's icon grid: 824 pt body, 100 pt margin) holding
// a white page with a folded corner and a markdown "M↓" mark.
let size: CGFloat = 1024
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024, bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext
func rgb(_ hex: Int, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}

// Tile with a soft shadow.
let tile = NSRect(x: 100, y: 100, width: 824, height: 824)
let tilePath = NSBezierPath(roundedRect: tile, xRadius: 185, yRadius: 185)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: NSColor.black.withAlphaComponent(0.35).cgColor)
rgb(0x161B22).setFill(); tilePath.fill()
ctx.restoreGState()
NSGradient(starting: rgb(0x2D333B), ending: rgb(0x0D1117))!.draw(in: tilePath, angle: -90)

// Page with a folded top-right corner.
let page = NSRect(x: 262, y: 190, width: 500, height: 644)
let fold: CGFloat = 130
let pagePath = NSBezierPath()
pagePath.move(to: NSPoint(x: page.minX + 36, y: page.minY))
pagePath.line(to: NSPoint(x: page.maxX - 36, y: page.minY))
pagePath.curve(to: NSPoint(x: page.maxX, y: page.minY + 36), controlPoint1: NSPoint(x: page.maxX - 16, y: page.minY), controlPoint2: NSPoint(x: page.maxX, y: page.minY + 16))
pagePath.line(to: NSPoint(x: page.maxX, y: page.maxY - fold))
pagePath.line(to: NSPoint(x: page.maxX - fold, y: page.maxY))
pagePath.line(to: NSPoint(x: page.minX + 36, y: page.maxY))
pagePath.curve(to: NSPoint(x: page.minX, y: page.maxY - 36), controlPoint1: NSPoint(x: page.minX + 16, y: page.maxY), controlPoint2: NSPoint(x: page.minX, y: page.maxY - 16))
pagePath.line(to: NSPoint(x: page.minX, y: page.minY + 36))
pagePath.curve(to: NSPoint(x: page.minX + 36, y: page.minY), controlPoint1: NSPoint(x: page.minX, y: page.minY + 16), controlPoint2: NSPoint(x: page.minX + 16, y: page.minY))
pagePath.close()
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -8), blur: 20, color: NSColor.black.withAlphaComponent(0.4).cgColor)
NSColor.white.setFill(); pagePath.fill()
ctx.restoreGState()
let foldPath = NSBezierPath()
foldPath.move(to: NSPoint(x: page.maxX - fold, y: page.maxY))
foldPath.line(to: NSPoint(x: page.maxX - fold, y: page.maxY - fold + 24))
foldPath.curve(to: NSPoint(x: page.maxX - fold + 24, y: page.maxY - fold), controlPoint1: NSPoint(x: page.maxX - fold, y: page.maxY - fold + 8), controlPoint2: NSPoint(x: page.maxX - fold + 8, y: page.maxY - fold))
foldPath.line(to: NSPoint(x: page.maxX, y: page.maxY - fold))
foldPath.close()
rgb(0xD0D7DE).setFill(); foldPath.fill()

// "M↓" mark: a stroked M and a down arrow, centred on the page.
let ink = rgb(0x1F2328)
ink.setStroke(); ink.setFill()
let stroke: CGFloat = 46
let markY: CGFloat = 390, markH: CGFloat = 200
let m = NSBezierPath()
m.lineWidth = stroke; m.lineJoinStyle = .miter; m.lineCapStyle = .butt
let mx: CGFloat = 322
m.move(to: NSPoint(x: mx, y: markY))
m.line(to: NSPoint(x: mx, y: markY + markH))
m.line(to: NSPoint(x: mx + 95, y: markY + markH - 100))
m.line(to: NSPoint(x: mx + 190, y: markY + markH))
m.line(to: NSPoint(x: mx + 190, y: markY))
m.stroke()
let ax: CGFloat = 640
let shaft = NSBezierPath(rect: NSRect(x: ax - stroke / 2, y: markY + 70, width: stroke, height: markH - 70 + stroke / 2))
shaft.fill()
let head = NSBezierPath()
head.move(to: NSPoint(x: ax - 70, y: markY + 92))
head.line(to: NSPoint(x: ax + 70, y: markY + 92))
head.line(to: NSPoint(x: ax, y: markY - stroke / 2))
head.close(); head.fill()

// Text lines below the mark, hinting at a rendered document.
rgb(0xAFB8C1).setFill()
for (k, w) in [CGFloat(360), 300, 330].enumerated() {
    NSBezierPath(roundedRect: NSRect(x: 322, y: 300 - CGFloat(k) * 46, width: w, height: 22), xRadius: 11, yRadius: 11).fill()
}
// A heading bar above the mark.
rgb(0x0969DA).setFill()
NSBezierPath(roundedRect: NSRect(x: 322, y: 690, width: 220, height: 34), xRadius: 17, yRadius: 17).fill()

NSGraphicsContext.current = nil
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
