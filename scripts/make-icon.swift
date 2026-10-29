// Draws the app icon: a Google-coloured ring with a magnifier on a white squircle.
// Usage: swift scripts/make-icon.swift <output.png>
import AppKit

let size: CGFloat = 1024
let output = CommandLine.arguments[1]
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext

let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: NSColor.black.withAlphaComponent(0.3).cgColor)
ctx.addPath(CGPath(roundedRect: tile, cornerWidth: 185, cornerHeight: 185, transform: nil))
ctx.setFillColor(NSColor.white.cgColor)
ctx.fillPath()
ctx.setShadow(offset: .zero, blur: 0, color: nil)

let colors = [NSColor(srgbRed: 0.259, green: 0.522, blue: 0.957, alpha: 1),
              NSColor(srgbRed: 0.918, green: 0.263, blue: 0.208, alpha: 1),
              NSColor(srgbRed: 0.984, green: 0.737, blue: 0.020, alpha: 1),
              NSColor(srgbRed: 0.204, green: 0.659, blue: 0.325, alpha: 1)]
let center = CGPoint(x: 512, y: 512)
let radius: CGFloat = 270
ctx.setLineWidth(58)
ctx.setLineCap(.round)
for (index, color) in colors.enumerated() {
    let start = CGFloat(index) * .pi / 2 + 0.22
    ctx.addArc(center: center, radius: radius, startAngle: start, endAngle: start + .pi / 2 - 0.44, clockwise: false)
    ctx.setStrokeColor(color.cgColor)
    ctx.strokePath()
}

let ink = NSColor(srgbRed: 0.24, green: 0.25, blue: 0.27, alpha: 1).cgColor
ctx.setStrokeColor(ink)
ctx.setLineWidth(44)
ctx.addEllipse(in: CGRect(x: 512 - 100, y: 512 - 70, width: 200, height: 200))
ctx.strokePath()
ctx.move(to: CGPoint(x: 512 - 58, y: 512 - 58))
ctx.addLine(to: CGPoint(x: 512 - 150, y: 512 - 150))
ctx.strokePath()

NSGraphicsContext.current = nil
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output))
