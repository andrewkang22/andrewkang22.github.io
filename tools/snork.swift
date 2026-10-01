import Foundation
import Vision
import CoreGraphics
import CoreVideo
import ImageIO
import UniformTypeIdentifiers

// Cuts both waving hands out of the snorkel photo and paints them out of a background plate.
// usage: snork <photo> <outdir>
let args = CommandLine.arguments
let outDir = args[2]
let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: args[1]) as CFURL, nil)!
let photo = CGImageSourceCreateImageAtIndex(src, 0, nil)!
let W = photo.width, H = photo.height
let srgb = CGColorSpace(name: CGColorSpace.sRGB)!

func rgba(_ img: CGImage) -> [UInt8] {
  var px = [UInt8](repeating: 0, count: img.width * img.height * 4)
  let c = CGContext(data: &px, width: img.width, height: img.height, bitsPerComponent: 8,
                    bytesPerRow: img.width * 4, space: srgb,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
  c.draw(img, in: CGRect(x: 0, y: 0, width: img.width, height: img.height))
  return px
}
var px = rgba(photo)
let orig = px

// Vision subject mask on a crop around the snorkeler, mapped back to full-res coords
let crop = CGRect(x: 540, y: 190, width: 300, height: 180)
let cropImg = photo.cropping(to: crop)!
let req = VNGenerateForegroundInstanceMaskRequest()
let handler = VNImageRequestHandler(cgImage: cropImg)
try handler.perform([req])
let obs = req.results!.first!
let mbuf = try obs.generateScaledMaskForImage(forInstances: obs.allInstances, from: handler)
CVPixelBufferLockBaseAddress(mbuf, .readOnly)
let mw = CVPixelBufferGetWidth(mbuf), mh = CVPixelBufferGetHeight(mbuf)
let mrow = CVPixelBufferGetBytesPerRow(mbuf) / 4
let mptr = CVPixelBufferGetBaseAddress(mbuf)!.assumingMemoryBound(to: Float32.self)
var mask = [Float](repeating: 0, count: W * H)
for y in 0..<mh { for x in 0..<mw {
  mask[(y + Int(crop.minY)) * W + x + Int(crop.minX)] = mptr[y * mrow + x]
}}
CVPixelBufferUnlockBaseAddress(mbuf, .readOnly)

struct Hand { let name: String; let poly: [(Double, Double)]; let pivot: (Double, Double) }
let hands = [
  Hand(name: "hand-r", poly: [(655.6,259.3),(662.5,249.9),(670.6,245.5),(682.5,245.8),(688.1,249.3),
                              (693.1,264.9),(693.1,274.3),(687.5,279.3),(675,279.9),(670,273),(658.8,266.1)],
       pivot: (686, 276)),
  Hand(name: "hand-l", poly: [(577.4,289.75),(583,279.75),(591.75,275.4),(605.5,276.6),(616.75,292.9),
                              (609.25,302.25),(604.25,307.25),(600.5,314.1),(586.75,314.1),(583,303.5)],
       pivot: (593.6, 314.5)),
]

func inside(_ p: [(Double, Double)], _ x: Double, _ y: Double) -> Bool {
  var c = false; var j = p.count - 1
  for i in 0..<p.count {
    if (p[i].1 > y) != (p[j].1 > y) && x < (p[j].0 - p[i].0) * (y - p[i].1) / (p[j].1 - p[i].1) + p[i].0 { c.toggle() }
    j = i
  }
  return c
}
// soft polygon coverage: supersample 4x4
func coverage(_ p: [(Double, Double)], _ x: Int, _ y: Int) -> Double {
  var n = 0
  for sy in 0..<4 { for sx in 0..<4 { if inside(p, Double(x) + (Double(sx) + 0.5) / 4, Double(y) + (Double(sy) + 0.5) / 4) { n += 1 } } }
  return Double(n) / 16
}
func smooth(_ e0: Double, _ e1: Double, _ v: Double) -> Double { let t = max(0, min(1, (v - e0) / (e1 - e0))); return t * t * (3 - 2 * t) }

var layout: [String: [String: Double]] = [:]
for h in hands {
  let xs = h.poly.map { $0.0 }, ys = h.poly.map { $0.1 }
  let bx0 = Int(floor(xs.min()!)) - 3, by0 = Int(floor(ys.min()!)) - 3
  let bx1 = Int(ceil(xs.max()!)) + 3, by1 = Int(ceil(ys.max()!)) + 3
  let bw = bx1 - bx0, bh = by1 - by0
  // hand axis: pivot -> polygon centroid
  let cx = xs.reduce(0, +) / Double(xs.count), cy = ys.reduce(0, +) / Double(ys.count)
  var ax = cx - h.pivot.0, ay = cy - h.pivot.1; let al = (ax * ax + ay * ay).squareRoot(); ax /= al; ay /= al

  var alpha = [Double](repeating: 0, count: bw * bh)
  var fill = [Bool](repeating: false, count: W * H)
  for y in by0..<by1 { for x in bx0..<bx1 {
    let t = (Double(x) - h.pivot.0) * ax + (Double(y) - h.pivot.1) * ay
    let m = Double(mask[y * W + x])
    let a = m * coverage(h.poly, x, y)
    alpha[(y - by0) * bw + (x - bx0)] = a * smooth(-1, 4, t)
    if a > 0.12 && t > 2.5 { fill[y * W + x] = true }
  }}
  // grow the paint-out region 2px so no hand fringe survives in the plate
  var grown = fill
  for y in by0..<by1 { for x in bx0..<bx1 where fill[y * W + x] {
    for dy in -2...2 { for dx in -2...2 where dx * dx + dy * dy <= 5 { grown[(y + dy) * W + x + dx] = true } }
  }}
  // diffusion fill (Laplace) from surrounding pixels
  let fx0 = bx0 - 4, fy0 = by0 - 4, fx1 = bx1 + 4, fy1 = by1 + 4
  for _ in 0..<1500 {
    for y in fy0..<fy1 { for x in fx0..<fx1 where grown[y * W + x] {
      for c in 0..<3 {
        let s = Int(px[((y - 1) * W + x) * 4 + c]) + Int(px[((y + 1) * W + x) * 4 + c])
              + Int(px[(y * W + x - 1) * 4 + c]) + Int(px[(y * W + x + 1) * 4 + c])
        px[(y * W + x) * 4 + c] = UInt8((s + 2) / 4)
      }
    }}
  }
  // light grain so the patch matches the photo's noise
  var rng = SystemRandomNumberGenerator()
  for y in fy0..<fy1 { for x in fx0..<fx1 where grown[y * W + x] {
    let n = Int.random(in: -3...3, using: &rng)
    for c in 0..<3 { let i = (y * W + x) * 4 + c; px[i] = UInt8(max(0, min(255, Int(px[i]) + n))) }
  }}

  // hand layer PNG (premultiplied RGBA from the untouched photo)
  var hp = [UInt8](repeating: 0, count: bw * bh * 4)
  for y in 0..<bh { for x in 0..<bw {
    let a = alpha[y * bw + x]; let si = ((y + by0) * W + x + bx0) * 4; let di = (y * bw + x) * 4
    for c in 0..<3 { hp[di + c] = UInt8(Double(orig[si + c]) * a) }
    hp[di + 3] = UInt8(a * 255)
  }}
  let hc = CGContext(data: &hp, width: bw, height: bh, bitsPerComponent: 8, bytesPerRow: bw * 4, space: srgb,
                     bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
  let hd = CGImageDestinationCreateWithURL(URL(fileURLWithPath: "\(outDir)/\(h.name).png") as CFURL, UTType.png.identifier as CFString, 1, nil)!
  CGImageDestinationAddImage(hd, hc.makeImage()!, nil); CGImageDestinationFinalize(hd)

  layout[h.name] = [
    "left": Double(bx0) / Double(W) * 100, "top": Double(by0) / Double(H) * 100,
    "width": Double(bw) / Double(W) * 100, "height": Double(bh) / Double(H) * 100,
    "originX": (h.pivot.0 - Double(bx0)) / Double(bw) * 100, "originY": (h.pivot.1 - Double(by0)) / Double(bh) * 100,
  ]
}

let pc = CGContext(data: &px, width: W, height: H, bitsPerComponent: 8, bytesPerRow: W * 4, space: srgb,
                   bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
let pd = CGImageDestinationCreateWithURL(URL(fileURLWithPath: "\(outDir)/scene1-plate.jpg") as CFURL, UTType.jpeg.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(pd, pc.makeImage()!, [kCGImageDestinationLossyCompressionQuality: 0.9] as CFDictionary)
CGImageDestinationFinalize(pd)

let json = try JSONSerialization.data(withJSONObject: layout, options: [.prettyPrinted, .sortedKeys])
print(String(data: json, encoding: .utf8)!)
