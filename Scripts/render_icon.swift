import AppKit

// Renders an SVG to a PNG at an exact pixel size using AppKit's native SVG
// support (NSImage), so every icon size is a clean vector render, not an
// upscaled/downscaled bitmap.
let args = CommandLine.arguments
guard args.count == 4, let size = Double(args[2]) else {
    print("usage: render_icon.swift <svg-path> <size> <out-png-path>")
    exit(1)
}

let svgURL = URL(fileURLWithPath: args[1])
let outURL = URL(fileURLWithPath: args[3])
let pixelSize = CGFloat(size)

guard let svgData = try? Data(contentsOf: svgURL), let source = NSImage(data: svgData) else {
    print("failed to load SVG")
    exit(1)
}

// Render into a pixel-exact bitmap context (not lockFocus, which is scaled
// by the display's backing factor and would silently double the output size
// on a Retina screen).
guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(pixelSize),
    pixelsHigh: Int(pixelSize),
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    print("failed to create bitmap")
    exit(1)
}
bitmap.size = NSSize(width: pixelSize, height: pixelSize)

guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
    print("failed to create context")
    exit(1)
}
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context
context.imageInterpolation = .high
source.draw(in: NSRect(x: 0, y: 0, width: pixelSize, height: pixelSize),
            from: .zero, operation: .copy, fraction: 1.0)
NSGraphicsContext.restoreGraphicsState()

guard let png = bitmap.representation(using: .png, properties: [:]) else {
    print("failed to rasterize")
    exit(1)
}

try? png.write(to: outURL)
print("wrote \(outURL.path)")
