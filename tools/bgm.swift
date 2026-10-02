import Foundation
import AVFoundation

// Background-music export: applies a fixed gain and writes AAC (.m4a).
// usage: bgm <in> <out.m4a> <gain 0..1> <bitsPerSec>
let a = CommandLine.arguments
let src = URL(fileURLWithPath: a[1]), dst = URL(fileURLWithPath: a[2])
let gain = Float(a[3])!, br = Int(a[4])!
try? FileManager.default.removeItem(at: dst)

let asset = AVURLAsset(url: src)
let track = asset.tracks(withMediaType: .audio).first!
let mix = AVMutableAudioMix()
let params = AVMutableAudioMixInputParameters(track: track)
params.setVolume(gain, at: .zero)
mix.inputParameters = [params]

let reader = try AVAssetReader(asset: asset)
let out = AVAssetReaderAudioMixOutput(audioTracks: [track], audioSettings: [
  AVFormatIDKey: kAudioFormatLinearPCM, AVLinearPCMBitDepthKey: 16, AVLinearPCMIsFloatKey: false,
  AVLinearPCMIsBigEndianKey: false, AVLinearPCMIsNonInterleaved: false,
  AVSampleRateKey: 44100, AVNumberOfChannelsKey: 2])
out.audioMix = mix
reader.add(out)

let writer = try AVAssetWriter(outputURL: dst, fileType: .m4a)
let input = AVAssetWriterInput(mediaType: .audio, outputSettings: [
  AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 44100, AVNumberOfChannelsKey: 2, AVEncoderBitRateKey: br])
input.expectsMediaDataInRealTime = false
writer.add(input)

guard reader.startReading() else { print("reader failed", reader.error!); exit(1) }
writer.startWriting()
writer.startSession(atSourceTime: .zero)
let done = DispatchSemaphore(value: 0)
input.requestMediaDataWhenReady(on: DispatchQueue(label: "a")) {
  while input.isReadyForMoreMediaData {
    if let sb = out.copyNextSampleBuffer() { input.append(sb) }
    else { input.markAsFinished(); done.signal(); return }
  }
}
done.wait()
let fin = DispatchSemaphore(value: 0)
writer.finishWriting { fin.signal() }
fin.wait()
print(writer.status == .completed ? "ok" : "failed \(String(describing: writer.error))")
