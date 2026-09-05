import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// Vector bath emblem, rendered without external images or font dependencies.
let size = 1024
let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8,
                        bytesPerRow: size * 4, space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
context.setFillColor(CGColor(red: 0.20, green: 0.34, blue: 0.29, alpha: 1))
context.fill(CGRect(x: 0, y: 0, width: size, height: size))
context.setStrokeColor(CGColor(red: 0.40, green: 0.46, blue: 0.34, alpha: 1))
context.setLineWidth(2)
context.strokeEllipse(in: CGRect(x: 134, y: 134, width: 756, height: 756))
context.setStrokeColor(CGColor(red: 0.98, green: 0.95, blue: 0.85, alpha: 1))
context.setLineCap(.round)
context.setLineWidth(32)
context.move(to: CGPoint(x: 270, y: 420))
context.addCurve(to: CGPoint(x: 754, y: 420), control1: CGPoint(x: 185, y: 205), control2: CGPoint(x: 839, y: 205))
context.strokePath()
context.setLineWidth(23)
context.move(to: CGPoint(x: 353, y: 399))
context.addCurve(to: CGPoint(x: 671, y: 399), control1: CGPoint(x: 430, y: 357), control2: CGPoint(x: 594, y: 357))
context.strokePath()
context.setLineWidth(30)
for x in [382.0, 512.0, 642.0] {
    context.move(to: CGPoint(x: x, y: 484))
    context.addCurve(to: CGPoint(x: x + 8, y: 713), control1: CGPoint(x: x - 72, y: 557), control2: CGPoint(x: x + 72, y: 645))
    context.strokePath()
}
let url = URL(fileURLWithPath: CommandLine.arguments[1])
let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(destination, context.makeImage()!, nil)
guard CGImageDestinationFinalize(destination) else { fatalError("PNG export failed") }
