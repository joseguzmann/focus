// Dibuja el ícono de la app (1024×1024) en el PNG que se pase como argumento.
// Uso: swift scripts/make-icon.swift salida.png
import AppKit

let out = CommandLine.arguments.dropFirst().first ?? "icon.png"
let side: CGFloat = 1024
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(side), pixelsHigh: Int(side),
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

// Plantilla de íconos de macOS: cuadrado redondeado de 824 con margen de 100.
let tile = NSRect(x: 100, y: 100, width: 824, height: 824)
let tilePath = NSBezierPath(roundedRect: tile, xRadius: 185, yRadius: 185)
NSGradient(colors: [
    NSColor(red: 0.96, green: 0.42, blue: 0.32, alpha: 1),
    NSColor(red: 0.80, green: 0.22, blue: 0.16, alpha: 1),
])!.draw(in: tilePath, angle: -90)

let center = NSPoint(x: tile.midX, y: tile.midY)

// Disco interior un poco más claro.
NSColor.white.withAlphaComponent(0.14).setFill()
NSBezierPath(ovalIn: NSRect(x: center.x - 255, y: center.y - 255, width: 510, height: 510)).fill()

NSColor.white.setStroke()
let ring = NSBezierPath()
ring.appendArc(withCenter: center, radius: 300, startAngle: 128, endAngle: 102, clockwise: false)
ring.lineWidth = 46
ring.lineCapStyle = .round
ring.stroke()

let hands = NSBezierPath()
hands.move(to: NSPoint(x: center.x, y: center.y + 190))
hands.line(to: center)
hands.line(to: NSPoint(x: center.x + 135, y: center.y - 90))
hands.lineWidth = 44
hands.lineCapStyle = .round
hands.lineJoinStyle = .round
hands.stroke()

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
