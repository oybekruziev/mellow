// Slices 5-frame horizontal sprite sheets (transparent background) into
// square 512×512 frames that share one scale and one ground baseline.
//
//   swift scripts/slice_sprites.swift <sheet.png> <name> [<sheet2.png> <name2> …]
//
// All sheets passed together share the same crop box, so a mascot's loop and
// wake frames line up exactly. Writes Mellow/Resources/Assets.xcassets/<name>-01…05.imageset.
import AppKit
import CoreGraphics

let args = CommandLine.arguments
guard args.count >= 3, args.count % 2 == 1 else { print("usage: slice_sprites.swift <sheet.png> <name> [<sheet2.png> <name2> …]"); exit(1) }
let frameCount = 5
let threshold: UInt8 = 24
let space = CGColorSpaceCreateDeviceRGB()

struct Sheet { let image: CGImage; let name: String; let frames: [Range<Int>]; let top: Int; let bottom: Int }

func analyze(_ path: String, _ name: String) -> Sheet {
    guard let source = NSImage(contentsOfFile: path),
          let image = source.cgImage(forProposedRect: nil, context: nil, hints: nil) else { print("cannot read \(path)"); exit(1) }
    let width = image.width, height = image.height
    var pixels = [UInt8](repeating: 0, count: width * height * 4)
    let context = CGContext(data: &pixels, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                            space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    func alpha(_ x: Int, _ y: Int) -> UInt8 { pixels[(y * width + x) * 4 + 3] } // y = 0 is the top row
    // Opaque columns; the frameCount widest runs of them are the frames.
    let columnFilled = (0..<width).map { x in (0..<height).contains { alpha(x, $0) > threshold } }
    var runs: [Range<Int>] = []
    var start: Int?
    for x in 0...width {
        let filled = x < width && columnFilled[x]
        if filled, start == nil { start = x }
        if !filled, let s = start { runs.append(s..<x); start = nil }
    }
    // Merge runs split by tiny gaps (sparkles, whiskers).
    var merged: [Range<Int>] = []
    for run in runs {
        if let last = merged.last, run.lowerBound - last.upperBound < 12 { merged[merged.count - 1] = last.lowerBound..<run.upperBound }
        else { merged.append(run) }
    }
    let frames = Array(merged.sorted { $0.count > $1.count }.prefix(frameCount).sorted { $0.lowerBound < $1.lowerBound })
    guard frames.count == frameCount else { print("\(name): found \(frames.count) frames, expected \(frameCount)"); exit(1) }
    var top = height, bottom = 0
    for frame in frames { for x in frame { for y in 0..<height where alpha(x, y) > threshold { top = min(top, y); bottom = max(bottom, y) } } }
    return Sheet(image: image, name: name, frames: frames, top: top, bottom: bottom)
}

let sheets = stride(from: 1, to: args.count, by: 2).map { analyze(args[$0], args[$0 + 1]) }
// One shared box for every sheet: same width (scale) and same bottom (ground baseline).
let boxWidth = sheets.flatMap(\.frames).map(\.count).max()!
let boxHeight = sheets.map { $0.bottom - $0.top + 1 }.max()!
let side = max(boxWidth, boxHeight)
let pad = Double(side) * 0.06
let output = 512
let scale = Double(output) / (Double(side) + pad * 2)
let assets = URL(fileURLWithPath: "Mellow/Resources/Assets.xcassets")

for sheet in sheets {
    let image = sheet.image
    for (index, frame) in sheet.frames.enumerated() {
        let center = Double(frame.lowerBound + frame.upperBound) / 2
        let crop = CGRect(x: Int(center - Double(boxWidth) / 2), y: sheet.bottom + 1 - boxHeight, width: boxWidth, height: boxHeight)
        let visible = crop.intersection(CGRect(x: 0, y: 0, width: image.width, height: image.height))
        guard let piece = image.cropping(to: visible) else { exit(1) }
        let context = CGContext(data: nil, width: output, height: output, bitsPerComponent: 8, bytesPerRow: 0,
                                space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.interpolationQuality = .high
        // Place the visible part where it sits inside the full crop box; bottom-aligned (CG origin is bottom-left).
        let x = (Double(output) - Double(boxWidth) * scale) / 2 + (visible.minX - crop.minX) * scale
        let y = pad * scale + (crop.maxY - visible.maxY) * scale
        context.draw(piece, in: CGRect(x: x, y: y, width: visible.width * scale, height: visible.height * scale))
        let file = String(format: "%@-%02d", sheet.name, index + 1)
        let folder = assets.appending(path: "\(file).imageset")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let rep = NSBitmapImageRep(cgImage: context.makeImage()!)
        try! rep.representation(using: .png, properties: [:])!.write(to: folder.appending(path: "\(file).png"))
        let json = #"{ "images" : [ { "filename" : "\#(file).png", "idiom" : "universal" } ], "info" : { "author" : "xcode", "version" : 1 } }"#
        try! json.write(to: folder.appending(path: "Contents.json"), atomically: true, encoding: .utf8)
    }
    print("wrote \(sheet.name)-01…05")
}
