// Renders the Stem Lab app icon: dark squircle, four waveform rows,
// one color per stem (vocals / drums / bass / other).
// Usage: render-icon <output.png>

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let size = 1024
let out = URL(fileURLWithPath: CommandLine.arguments[1])

let space = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8,
                    bytesPerRow: 0, space: space,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!

func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

// macOS icon grid: content squircle inset ~100px at 1024, corner radius ~185
let squircle = CGRect(x: 100, y: 100, width: 824, height: 824)
let bgPath = CGPath(roundedRect: squircle, cornerWidth: 185, cornerHeight: 185, transform: nil)

ctx.saveGState()
ctx.addPath(bgPath)
ctx.clip()
let gradient = CGGradient(colorsSpace: space,
                          colors: [rgb(0x2B2D5C), rgb(0x141527)] as CFArray,
                          locations: [0, 1])!
ctx.drawLinearGradient(gradient,
                       start: CGPoint(x: 512, y: 1024),
                       end: CGPoint(x: 512, y: 0),
                       options: [])

// four stem rows: vocals cyan, drums amber, bass pink, other green
let colors: [CGColor] = [rgb(0x53C7F0), rgb(0xF2B04E), rgb(0xEF6A9E), rgb(0x6FCF8B)]
// waveform silhouette, shifted per row so the rows read as different signals
let wave: [CGFloat] = [0.30, 0.55, 0.42, 0.78, 1.00, 0.66, 0.88, 0.50, 0.72, 0.38, 0.60, 0.45, 0.28]

let contentInset: CGFloat = 210
let usableW = CGFloat(size) - contentInset * 2
let barW: CGFloat = 30
let n = wave.count
let gap = (usableW - CGFloat(n) * barW) / CGFloat(n - 1)
let rowMaxH: CGFloat = 118
let rowCenters: [CGFloat] = [700, 574, 448, 322]

for (row, color) in colors.enumerated() {
    ctx.setFillColor(color)
    for k in 0..<n {
        let h = max(barW, rowMaxH * wave[(k + row * 3) % n])
        let x = contentInset + CGFloat(k) * (barW + gap)
        let bar = CGRect(x: x, y: rowCenters[row] - h / 2, width: barW, height: h)
        ctx.addPath(CGPath(roundedRect: bar, cornerWidth: barW / 2, cornerHeight: barW / 2, transform: nil))
    }
    ctx.fillPath()
}
ctx.restoreGState()

let image = ctx.makeImage()!
let dest = CGImageDestinationCreateWithURL(out as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, image, nil)
CGImageDestinationFinalize(dest)
print("wrote \(out.path)")
