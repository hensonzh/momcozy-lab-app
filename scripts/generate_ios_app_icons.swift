// Generate opaque iOS icon sizes from the existing Android Momcozy AI avatar.
// Run from the app root: swift scripts/generate_ios_app_icons.swift
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let sourcePath = "android/app/src/main/res/mipmap-xxxhdpi/ic_launcher_foreground.png"
let iconDirectory = "ios/Runner/Assets.xcassets/AppIcon.appiconset"
let manifestPath = "\(iconDirectory)/Contents.json"
let sourceURL = URL(fileURLWithPath: sourcePath)
guard let imageSource = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
      let avatar = CGImageSourceCreateImageAtIndex(imageSource, 0, nil),
      let manifest = try JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: manifestPath))) as? [String: Any],
      let entries = manifest["images"] as? [[String: String]],
      let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
    fatalError("The Android avatar or iOS icon manifest is missing or invalid")
}

for entry in entries {
    guard let filename = entry["filename"],
          let pointSize = entry["size"]?.split(separator: "x").first.flatMap({ Double($0) }),
          let scale = entry["scale"].flatMap({ Double(String($0.dropLast())) }) else {
        fatalError("An iOS icon manifest entry lacks a filename, size, or scale")
    }
    let side = Int((pointSize * scale).rounded())
    guard let context = CGContext(
        data: nil,
        width: side,
        height: side,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    ) else {
        fatalError("Could not create \(filename)")
    }
    context.interpolationQuality = .high
    // Match the existing Android adaptive icon background, not a new colorway.
    context.setFillColor(red: 0xF1 / 255.0, green: 0xDA / 255.0, blue: 0xCE / 255.0, alpha: 1)
    let bounds = CGRect(x: 0, y: 0, width: side, height: side)
    context.fill(bounds)
    context.draw(avatar, in: bounds)

    let destinationURL = URL(fileURLWithPath: "\(iconDirectory)/\(filename)")
    guard let rendered = context.makeImage(),
          let destination = CGImageDestinationCreateWithURL(destinationURL as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        fatalError("Could not encode \(filename)")
    }
    CGImageDestinationAddImage(destination, rendered, nil)
    guard CGImageDestinationFinalize(destination) else {
        fatalError("Could not write \(filename)")
    }
}
print("Generated \(entries.count) iOS app icons from the Android Momcozy AI avatar.")
