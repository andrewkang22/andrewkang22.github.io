import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// Tileable water-caustic texture (after Dave Hoskins' "Tileable Water Caustic"):
// white light network on transparent, for layering over the museum floor.
// usage: caustics <out.png> <size> <time>
let a = CommandLine.arguments
let N = Int(a[2])!, time = Double(a[3])!
let TAU = 6.28318530718
var px = [UInt8](repeating: 0, count: N * N * 4)
for y in 0..<N { for x in 0..<N {
  let ux = Double(x) / Double(N), uy = Double(y) / Double(N)
  let px0 = (ux * TAU).truncatingRemainder(dividingBy: TAU) - 250.0
  let py0 = (uy * TAU).truncatingRemainder(dividingBy: TAU) - 250.0
  var ix = px0, iy = py0
  var c = 1.0
  let inten = 0.005
  for n in 0..<5 {
    let t = time * (1.0 - (3.5 / Double(n + 1)))
    let nx = px0 + cos(t - ix) + sin(t + iy)
    let ny = py0 + sin(t - iy) + cos(t + ix)
    ix = nx; iy = ny
    let dx = px0 / (sin(ix + t) / inten), dy = py0 / (cos(iy + t) / inten)
    c += 1.0 / (dx * dx + dy * dy).squareRoot()
  }
  c /= 5.0
  c = 1.17 - pow(c, 1.4)
  let v = min(1.0, max(0.0, pow(abs(c), 8.0)))
  let i = (y * N + x) * 4
  let al = UInt8(v * 255)
  px[i] = al; px[i + 1] = al; px[i + 2] = al; px[i + 3] = al   // premultiplied white
}}
let ctx = CGContext(data: &px, width: N, height: N, bitsPerComponent: 8, bytesPerRow: N * 4,
                    space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
let d = CGImageDestinationCreateWithURL(URL(fileURLWithPath: a[1]) as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(d, ctx.makeImage()!, nil); CGImageDestinationFinalize(d)
print("ok", a[1])
