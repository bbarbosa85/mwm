#!/usr/bin/env swift
//
//  generate-icons.swift
//  MWM
//
//  Draws MWM's icons, so they can be changed and regenerated instead of
//  edited as binary files:
//
//    swift script/generate-icons.swift Slate/Resources
//    swift script/generate-icons.swift Slate/Resources --preview /tmp/mwm-preview
//
//  Writes icon.icns (the app icon), status.pdf and statusActive.pdf (the menu
//  bar symbol, as template images). With --preview it also writes PNGs to look at.
//
import AppKit

// MARK: - Helpers

let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
  CGColor(colorSpace: sRGB, components: [
    CGFloat((hex >> 16) & 0xFF) / 255, CGFloat((hex >> 8) & 0xFF) / 255, CGFloat(hex & 0xFF) / 255, alpha,
  ])!
}

func roundedRect(_ rect: CGRect, _ radius: CGFloat) -> CGPath {
  CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

func bitmap(pixels: Int, draw: (CGContext) -> Void) -> NSBitmapImageRep {
  let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8,
                             samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                             bytesPerRow: 0, bitsPerPixel: 0)!
  let graphics = NSGraphicsContext(bitmapImageRep: rep)!
  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = graphics
  draw(graphics.cgContext)
  NSGraphicsContext.restoreGraphicsState()
  return rep
}

func writePNG(_ rep: NSBitmapImageRep, to url: URL) {
  try! rep.representation(using: .png, properties: [:])!.write(to: url)
}

// MARK: - App icon

// Drawn on a 1024 x 1024 canvas, on Apple's icon grid: an 824-point body with a 100-point margin.
func drawAppIcon(_ ctx: CGContext, scale s: CGFloat) {
  ctx.saveGState()
  ctx.scaleBy(x: s, y: s)

  let body = CGRect(x: 100, y: 100, width: 824, height: 824)
  let bodyPath = roundedRect(body, 185)

  // Body, with its shadow.
  ctx.saveGState()
  ctx.setShadow(offset: CGSize(width: 0, height: -12 * s), blur: 28 * s, color: color(0x000000, 0.35))
  ctx.addPath(bodyPath)
  ctx.setFillColor(color(0x2B35A8))
  ctx.fillPath()
  ctx.restoreGState()

  // Indigo to blue, with a soft light from the top.
  ctx.saveGState()
  ctx.addPath(bodyPath)
  ctx.clip()
  let base = CGGradient(colorsSpace: sRGB, colors: [color(0x6F8CFF), color(0x2B35A8)] as CFArray, locations: [0, 1])!
  ctx.drawLinearGradient(base, start: CGPoint(x: 300, y: body.maxY), end: CGPoint(x: 700, y: body.minY),
                         options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
  let light = CGGradient(colorsSpace: sRGB, colors: [color(0xFFFFFF, 0.20), color(0xFFFFFF, 0)] as CFArray, locations: [0, 1])!
  ctx.drawLinearGradient(light, start: CGPoint(x: 512, y: body.maxY), end: CGPoint(x: 512, y: 520),
                         options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
  ctx.restoreGState()

  // Three tiled windows: a tall one on the left, two stacked on the right.
  let area = CGRect(x: 232, y: 232, width: 560, height: 560)
  let gap: CGFloat = 36
  let leftWidth: CGFloat = 300
  let rightWidth = area.width - leftWidth - gap
  let rightHeight = (area.height - gap) / 2
  let left = CGRect(x: area.minX, y: area.minY, width: leftWidth, height: area.height)
  let rightBottom = CGRect(x: left.maxX + gap, y: area.minY, width: rightWidth, height: rightHeight)
  let rightTop = CGRect(x: left.maxX + gap, y: rightBottom.maxY + gap, width: rightWidth, height: rightHeight)

  let tiles: [(CGRect, CGColor)] = [
    (left, color(0xFFFFFF, 0.96)),
    (rightTop, color(0xFFFFFF, 0.70)),
    (rightBottom, color(0x7FE3FF, 0.96)),
  ]
  for (rect, fill) in tiles {
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -6 * s), blur: 16 * s, color: color(0x0A1055, 0.35))
    ctx.addPath(roundedRect(rect, 44))
    ctx.setFillColor(fill)
    ctx.fillPath()
    ctx.restoreGState()
  }

  // Window buttons on the big tile.
  let dotColors: [CGColor] = [color(0x2B35A8, 0.30), color(0x2B35A8, 0.30), color(0x2B35A8, 0.30)]
  for (i, dot) in dotColors.enumerated() {
    let center = CGPoint(x: left.minX + 46 + CGFloat(i) * 34, y: left.maxY - 46)
    ctx.setFillColor(dot)
    ctx.fillEllipse(in: CGRect(x: center.x - 11, y: center.y - 11, width: 22, height: 22))
  }

  ctx.restoreGState()
}

func writeAppIcon(to resources: URL, preview: URL?) {
  let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("MWM-\(UUID().uuidString).iconset")
  try! FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
  let sizes: [(String, Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32), ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256), ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
  ]
  for (name, pixels) in sizes {
    let rep = bitmap(pixels: pixels) { drawAppIcon($0, scale: CGFloat(pixels) / 1024) }
    writePNG(rep, to: iconset.appendingPathComponent("\(name).png"))
  }
  let task = Process()
  task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
  task.arguments = ["-c", "icns", iconset.path, "-o", resources.appendingPathComponent("icon.icns").path]
  try! task.run()
  task.waitUntilExit()
  precondition(task.terminationStatus == 0, "iconutil failed")
  try? FileManager.default.removeItem(at: iconset)

  if let preview {
    writePNG(bitmap(pixels: 512) { drawAppIcon($0, scale: 0.5) }, to: preview.appendingPathComponent("icon-512.png"))
    writePNG(bitmap(pixels: 32) { drawAppIcon($0, scale: 32.0 / 1024) }, to: preview.appendingPathComponent("icon-32.png"))
  }
}

// MARK: - Menu bar symbol

// Drawn on an 18 x 18 point canvas as a template image: only the shape matters,
// and macOS colors it for light and dark menu bars.
func drawStatusSymbol(_ ctx: CGContext, active: Bool,
                      ink: CGColor = CGColor(colorSpace: CGColorSpaceCreateDeviceGray(), components: [0, 1])!) {
  ctx.setFillColor(ink)
  ctx.setStrokeColor(ink)
  ctx.setLineWidth(1.2)

  let left = CGRect(x: 1, y: 2.5, width: 8.5, height: 13)
  let rightTop = CGRect(x: 10.5, y: 9.5, width: 6.5, height: 6)
  let rightBottom = CGRect(x: 10.5, y: 2.5, width: 6.5, height: 6)

  for (rect, filled) in [(left, active), (rightTop, false), (rightBottom, false)] {
    if filled {
      ctx.addPath(roundedRect(rect, 2.0))
      ctx.fillPath()
    } else {
      ctx.addPath(roundedRect(rect.insetBy(dx: 0.6, dy: 0.6), 1.4))
      ctx.strokePath()
    }
  }
}

func writeStatusPDF(to url: URL, active: Bool) {
  var box = CGRect(x: 0, y: 0, width: 18, height: 18)
  let ctx = CGContext(url as CFURL, mediaBox: &box, nil)!
  ctx.beginPDFPage(nil)
  drawStatusSymbol(ctx, active: active)
  ctx.endPDFPage()
  ctx.closePDF()
}

// One image with everything: the icon at a few sizes, and the menu bar symbol
// in a light and a dark menu bar, resting and active.
func writePreviewSheet(to url: URL) {
  let width = 1240, height = 760
  let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8,
                             samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                             bytesPerRow: 0, bitsPerPixel: 0)!
  let graphics = NSGraphicsContext(bitmapImageRep: rep)!
  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = graphics
  let ctx = graphics.cgContext

  func icon(at origin: CGPoint, size: CGFloat) {
    ctx.saveGState()
    ctx.translateBy(x: origin.x, y: origin.y)
    drawAppIcon(ctx, scale: size / 1024)
    ctx.restoreGState()
  }
  func menuBar(y: CGFloat, dark: Bool) {
    let background = dark ? color(0x1E1E20) : color(0xE8E8EA)
    ctx.setFillColor(background)
    ctx.fill(CGRect(x: 40, y: y, width: 540, height: 52))
    let ink = dark ? color(0xFFFFFF) : color(0x000000)
    for (i, active) in [false, true].enumerated() {
      ctx.saveGState()
      ctx.translateBy(x: 70 + CGFloat(i) * 90, y: y + 8)
      ctx.scaleBy(x: 2, y: 2)
      drawStatusSymbol(ctx, active: active, ink: ink)
      ctx.restoreGState()
    }
  }

  ctx.setFillColor(color(0xF4F4F6))
  ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
  ctx.setFillColor(color(0x17171A))
  ctx.fill(CGRect(x: 620, y: 0, width: 620, height: 380))

  icon(at: CGPoint(x: -20, y: 260), size: 520)
  icon(at: CGPoint(x: 600, y: 450), size: 256)
  icon(at: CGPoint(x: 880, y: 450), size: 128)
  icon(at: CGPoint(x: 1040, y: 450), size: 64)
  icon(at: CGPoint(x: 1140, y: 450), size: 32)
  icon(at: CGPoint(x: 600, y: 60), size: 256)
  icon(at: CGPoint(x: 880, y: 60), size: 128)
  icon(at: CGPoint(x: 1040, y: 60), size: 64)
  icon(at: CGPoint(x: 1140, y: 60), size: 32)

  menuBar(y: 180, dark: false)
  menuBar(y: 100, dark: true)
  NSGraphicsContext.restoreGraphicsState()
  writePNG(rep, to: url)
}

// MARK: - Main

let arguments = CommandLine.arguments
guard arguments.count >= 2 else {
  print("usage: generate-icons.swift <resources directory> [--preview <directory>]")
  exit(1)
}
let resources = URL(fileURLWithPath: arguments[1])
var preview: URL?
if let flag = arguments.firstIndex(of: "--preview"), flag + 1 < arguments.count {
  preview = URL(fileURLWithPath: arguments[flag + 1])
  try! FileManager.default.createDirectory(at: preview!, withIntermediateDirectories: true)
}

writeAppIcon(to: resources, preview: preview)
writeStatusPDF(to: resources.appendingPathComponent("status.pdf"), active: false)
writeStatusPDF(to: resources.appendingPathComponent("statusActive.pdf"), active: true)
if let preview { writePreviewSheet(to: preview.appendingPathComponent("preview-sheet.png")) }
print("Wrote icon.icns, status.pdf and statusActive.pdf to \(resources.path)")
