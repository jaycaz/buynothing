//
//  main.swift — segtest
//
//  CLI harness that runs the app's real ForegroundSegmenter (Vision subject-lift)
//  + ObjectOrientationAligner — the same source files the iOS app compiles —
//  natively on macOS, so the snap-a-pic segmentation step can be tested and
//  automated without a device or simulator (the simulator has no Neural Engine
//  and cannot run subject-lift).
//
//  Build & run (see README.md):
//    swiftc -O -o segtest main.swift <the three utility files>
//    ./segtest /path/to/photo.jpg [outDir]
//

import Foundation
import CoreGraphics
import ImageIO

let args = CommandLine.arguments
guard args.count >= 2 else {
    FileHandle.standardError.write(Data("usage: segtest <photo> [outDir]\n".utf8))
    exit(2)
}
let inputPath = args[1]
let outDir = args.count >= 3 ? args[2] : "."

guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: inputPath) as CFURL, nil),
      let photo = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
    print("FAILED reason=cannot-load-image \(inputPath)")
    exit(1)
}
print("loaded \(photo.width)x\(photo.height)")

let start = Date()
do {
    let cutout = try ForegroundSegmenter.cutoutForegroundObject(from: photo)
    let aligned = ObjectOrientationAligner.align(cutout)
    let ms = Int(Date().timeIntervalSince(start) * 1000)

    let outURL = URL(fileURLWithPath: outDir, isDirectory: true)
        .appendingPathComponent("cutout_\(aligned.width)x\(aligned.height).png")
    guard let dest = CGImageDestinationCreateWithURL(outURL as CFURL, "public.png" as CFString, 1, nil) else {
        print("FAILED reason=cannot-create-destination")
        exit(1)
    }
    CGImageDestinationAddImage(dest, aligned, nil)
    guard CGImageDestinationFinalize(dest) else {
        print("FAILED reason=destination-finalize-failed")
        exit(1)
    }
    print("DONE ms=\(ms) cutout=\(cutout.image.width)x\(cutout.image.height) aligned=\(aligned.width)x\(aligned.height) out=\(outURL.path)")
} catch {
    print("FAILED reason=segmentation-failed: \(error)")
    exit(1)
}
