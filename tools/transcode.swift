import Foundation
import AVFoundation

// Web transcode: H.264 + AAC MP4, fixed size and bitrate, Rec.709 (tone-maps HDR sources), fast-start.
// usage: transcode <in> <out.mp4> <width> <height> <videoBitsPerSec> [startSec] [durationSec] [--mute]
let a = CommandLine.arguments
let src = URL(fileURLWithPath: a[1]), dst = URL(fileURLWithPath: a[2])
let W = Int(a[3])!, H = Int(a[4])!, vbr = Int(a[5])!
let start = a.count > 6 && !a[6].hasPrefix("--") ? Double(a[6])! : 0
let dur = a.count > 7 && !a[7].hasPrefix("--") ? Double(a[7])! : -1
let mute = a.contains("--mute")
try? FileManager.default.removeItem(at: dst)

let asset = AVURLAsset(url: src)
let vTrack = asset.tracks(withMediaType: .video).first!
let aTrack = asset.tracks(withMediaType: .audio).first

let rec709: [String: Any] = [AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
                             AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
                             AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2]

// composition does the HDR->SDR conversion and the downscale
let comp = AVMutableVideoComposition(propertiesOf: asset)
comp.colorPrimaries = AVVideoColorPrimaries_ITU_R_709_2
comp.colorTransferFunction = AVVideoTransferFunction_ITU_R_709_2
comp.colorYCbCrMatrix = AVVideoYCbCrMatrix_ITU_R_709_2
let nat = vTrack.naturalSize.applying(vTrack.preferredTransform)
let nw = abs(nat.width), nh = abs(nat.height)
let sc = min(CGFloat(W) / nw, CGFloat(H) / nh)
comp.renderSize = CGSize(width: W, height: H)
let instr = AVMutableVideoCompositionInstruction()
instr.timeRange = CMTimeRange(start: .zero, duration: asset.duration)
let li = AVMutableVideoCompositionLayerInstruction(assetTrack: vTrack)
let tx = (CGFloat(W) - nw * sc) / 2, ty = (CGFloat(H) - nh * sc) / 2
li.setTransform(vTrack.preferredTransform.concatenating(CGAffineTransform(scaleX: sc, y: sc)).concatenating(CGAffineTransform(translationX: tx, y: ty)), at: .zero)
instr.layerInstructions = [li]
comp.instructions = [instr]

let reader = try AVAssetReader(asset: asset)
let t0 = CMTime(seconds: start, preferredTimescale: 600)
reader.timeRange = CMTimeRange(start: t0, duration: dur > 0 ? CMTime(seconds: dur, preferredTimescale: 600) : .positiveInfinity)
let vOut = AVAssetReaderVideoCompositionOutput(videoTracks: [vTrack], videoSettings: [
  kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange])
vOut.videoComposition = comp
vOut.alwaysCopiesSampleData = false
reader.add(vOut)

var aOut: AVAssetReaderTrackOutput? = nil
var channels = 2, rate = 48000.0
if !mute, let at = aTrack {
  if let fd = at.formatDescriptions.first, let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(fd as! CMAudioFormatDescription)?.pointee {
    channels = min(2, Int(asbd.mChannelsPerFrame)); rate = asbd.mSampleRate
  }
  aOut = AVAssetReaderTrackOutput(track: at, outputSettings: [AVFormatIDKey: kAudioFormatLinearPCM,
    AVNumberOfChannelsKey: channels, AVSampleRateKey: rate])
  reader.add(aOut!)
}

let writer = try AVAssetWriter(outputURL: dst, fileType: .mp4)
writer.shouldOptimizeForNetworkUse = true
let vIn = AVAssetWriterInput(mediaType: .video, outputSettings: [
  AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: W, AVVideoHeightKey: H,
  AVVideoColorPropertiesKey: rec709,
  AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: vbr,
                                    AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                                    AVVideoMaxKeyFrameIntervalDurationKey: 2.0]])
vIn.expectsMediaDataInRealTime = false
writer.add(vIn)
var aIn: AVAssetWriterInput? = nil
if aOut != nil {
  aIn = AVAssetWriterInput(mediaType: .audio, outputSettings: [AVFormatIDKey: kAudioFormatMPEG4AAC,
    AVNumberOfChannelsKey: channels, AVSampleRateKey: rate, AVEncoderBitRateKey: 128_000])
  writer.add(aIn!)
}

guard reader.startReading() else { print("reader failed:", reader.error!); exit(1) }
writer.startWriting()
writer.startSession(atSourceTime: t0)

let group = DispatchGroup()
func pump(_ input: AVAssetWriterInput, _ output: AVAssetReaderOutput, _ label: String) {
  group.enter()
  var done = false
  input.requestMediaDataWhenReady(on: DispatchQueue(label: label)) {
    while input.isReadyForMoreMediaData && !done {
      if let sb = output.copyNextSampleBuffer() {
        if !input.append(sb) { print("append failed:", writer.error as Any); done = true; input.markAsFinished(); group.leave() }
      } else { done = true; input.markAsFinished(); group.leave() }
    }
  }
}
pump(vIn, vOut, "v")
if let aIn = aIn, let aOut = aOut { pump(aIn, aOut, "a") }
group.wait()
let fin = DispatchSemaphore(value: 0)
writer.finishWriting { fin.signal() }
fin.wait()
if writer.status == .completed {
  let size = (try? FileManager.default.attributesOfItem(atPath: dst.path)[.size] as? Int) ?? 0
  print("ok", dst.lastPathComponent, String(format: "%.1f MB", Double(size) / 1e6))
} else { print("failed:", writer.error as Any); exit(1) }
