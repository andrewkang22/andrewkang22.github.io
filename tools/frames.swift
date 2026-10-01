import Foundation
import AVFoundation
import ImageIO
import UniformTypeIdentifiers

// usage: frames <video> <outPrefix> <maxWidth> <t1> [t2 ...]   -> <outPrefix>-<t>.jpg
let a = CommandLine.arguments
let asset = AVURLAsset(url: URL(fileURLWithPath: a[1]))
let gen = AVAssetImageGenerator(asset: asset)
gen.appliesPreferredTrackTransform = true
gen.requestedTimeToleranceBefore = CMTime(seconds: 0.25, preferredTimescale: 600)
gen.requestedTimeToleranceAfter = CMTime(seconds: 0.25, preferredTimescale: 600)
let mw = CGFloat(Double(a[3])!)
gen.maximumSize = CGSize(width: mw, height: mw)
for t in a[4...] {
  let time = CMTime(seconds: Double(t)!, preferredTimescale: 600)
  let img = try gen.copyCGImage(at: time, actualTime: nil)
  let url = URL(fileURLWithPath: "\(a[2])-\(t).jpg")
  let d = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil)!
  CGImageDestinationAddImage(d, img, [kCGImageDestinationLossyCompressionQuality: 0.82] as CFDictionary)
  CGImageDestinationFinalize(d)
  print(url.lastPathComponent, img.width, "x", img.height)
}
