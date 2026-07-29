// Decode the QR in a rendered slide and print its payload.
//
//     swift marketing/social/verify-qr.swift marketing/social/out/p3-s1-beta-open.png
//
// A wrong QR on a posted image can't be fixed after the fact — Instagram won't let you
// replace the image on a live post. So this runs against the actual PNG that gets uploaded,
// not against the source SVG. Uses Vision, so it needs nothing installed.

import AppKit
import Foundation
import Vision

guard CommandLine.arguments.count > 1 else {
    FileHandle.standardError.write(Data("usage: verify-qr.swift <image.png>\n".utf8))
    exit(2)
}

let path = CommandLine.arguments[1]
guard let image = NSImage(contentsOfFile: path),
      let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
else {
    FileHandle.standardError.write(Data("could not read image: \(path)\n".utf8))
    exit(1)
}

let request = VNDetectBarcodesRequest()
try VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])

let payloads = (request.results ?? []).compactMap(\.payloadStringValue)
guard !payloads.isEmpty else {
    FileHandle.standardError.write(Data("no barcode found in \(path)\n".utf8))
    exit(1)
}
payloads.forEach { print($0) }
