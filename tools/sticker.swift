import Foundation
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins
import ImageIO

// Lifts the subject out of a product photo and turns it into a paper-cutout sticker PNG.
// usage: sticker <in> <out.png> <maxDim> <border> <seed>
let a = CommandLine.arguments
let maxDim = CGFloat(Double(a[3])!), border = CGFloat(Double(a[4])!), seed = CGFloat(Double(a[5])!)
let srgb = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CIContext(options: [.workingColorSpace: srgb, .outputColorSpace: srgb])

let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: a[1]) as CFURL, nil)!
let raw = CGImageSourceCreateImageAtIndex(src, 0, nil)!
// flatten onto white so transparent inputs behave like the product shots
let fc = CGContext(data: nil, width: raw.width, height: raw.height, bitsPerComponent: 8, bytesPerRow: 0,
                   space: srgb, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
fc.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1)); fc.fill(CGRect(x: 0, y: 0, width: raw.width, height: raw.height))
fc.draw(raw, in: CGRect(x: 0, y: 0, width: raw.width, height: raw.height))
let flat = fc.makeImage()!

let req = VNGenerateForegroundInstanceMaskRequest()
let handler = VNImageRequestHandler(cgImage: flat)
try handler.perform([req])
guard let obs = req.results?.first else { print("no subject in", a[1]); exit(1) }
let pb = try obs.generateMaskedImage(ofInstances: obs.allInstances, from: handler, croppedToInstancesExtent: true)
let cut = CIImage(cvPixelBuffer: pb)

// scale subject
let lz = CIFilter.lanczosScaleTransform()
lz.inputImage = cut; lz.scale = Float(maxDim / max(cut.extent.width, cut.extent.height)); lz.aspectRatio = 1
var subj = lz.outputImage!
let pad = border + 18
subj = subj.transformed(by: CGAffineTransform(translationX: -subj.extent.minX + pad, y: -subj.extent.minY + pad))
let canvas = CGRect(x: 0, y: 0, width: ceil(subj.extent.width + 2 * pad), height: ceil(subj.extent.height + 2 * pad))
let clear = CIImage(color: .clear).cropped(to: canvas)
subj = subj.composited(over: clear).cropped(to: canvas)

// white silhouette with a hard-ish alpha: rgb=1, a = clamp(a*k - b)
func whiteAlpha(_ im: CIImage, k: CGFloat, b: CGFloat) -> CIImage {
  im.applyingFilter("CIColorMatrix", parameters: [
    "inputRVector": CIVector(x: 0, y: 0, z: 0, w: 0), "inputGVector": CIVector(x: 0, y: 0, z: 0, w: 0),
    "inputBVector": CIVector(x: 0, y: 0, z: 0, w: 0), "inputAVector": CIVector(x: 0, y: 0, z: 0, w: k),
    "inputBiasVector": CIVector(x: 1, y: 1, z: 1, w: -b)]).applyingFilter("CIColorClamp").cropped(to: canvas)
}
let sil = whiteAlpha(subj, k: 3, b: 0.6)

// grow into the paper border, then round it off
var outline = sil.applyingFilter("CIMorphologyMaximum", parameters: ["inputRadius": border]).cropped(to: canvas)
outline = outline.composited(over: clear).applyingGaussianBlur(sigma: Double(border) * 0.45).cropped(to: canvas)
outline = whiteAlpha(outline, k: 5, b: 2.2)

// scissor wobble: low-frequency noise displacement of the outline edge
let noise = CIFilter.randomGenerator().outputImage!
  .transformed(by: CGAffineTransform(translationX: seed * 131, y: seed * 71))
  .applyingGaussianBlur(sigma: 9)
  .applyingFilter("CIColorMatrix", parameters: [
    "inputRVector": CIVector(x: 26, y: 0, z: 0, w: 0), "inputGVector": CIVector(x: 0, y: 26, z: 0, w: 0),
    "inputBVector": CIVector(x: 0, y: 0, z: 0, w: 0), "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 0),
    "inputBiasVector": CIVector(x: -12.5, y: -12.5, z: 0, w: 1)])
  .applyingFilter("CIColorClamp").cropped(to: canvas)
outline = outline.applyingFilter("CIDisplacementDistortion", parameters: [
  "inputDisplacementImage": noise, "inputScale": border * 0.55]).cropped(to: canvas)
// make sure the wobble never bites into the subject
outline = sil.applyingFilter("CIMorphologyMaximum", parameters: ["inputRadius": border * 0.45])
  .cropped(to: canvas).composited(over: outline).cropped(to: canvas)

// warm paper with faint grain
let paper = CIFilter.randomGenerator().outputImage!
  .transformed(by: CGAffineTransform(translationX: seed * 17, y: seed * 29))
  .applyingFilter("CIColorMatrix", parameters: [
    "inputRVector": CIVector(x: 0.035, y: 0, z: 0, w: 0), "inputGVector": CIVector(x: 0.035, y: 0, z: 0, w: 0),
    "inputBVector": CIVector(x: 0.035, y: 0, z: 0, w: 0), "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 0),
    "inputBiasVector": CIVector(x: 0.965, y: 0.957, z: 0.93, w: 1)])
  .cropped(to: canvas)
let paperOutline = paper.applyingFilter("CISourceInCompositing", parameters: ["inputBackgroundImage": outline])

let sticker = subj.composited(over: paperOutline).cropped(to: canvas)
try ctx.writePNGRepresentation(of: sticker, to: URL(fileURLWithPath: a[2]), format: .RGBA8, colorSpace: srgb)
print(a[2], Int(canvas.width), "x", Int(canvas.height))
