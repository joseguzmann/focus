import AppKit
import SwiftUI

@main
struct FocusApp: App {
    @State private var timer = FocusTimer()

    init() {
        // Sin ícono en el Dock: la app vive sólo en la barra de menú.
        NSApplication.shared.setActivationPolicy(.accessory)
        Notifier.requestAuthorization()
    }

    var body: some Scene {
        MenuBarExtra {
            PopoverView()
                .environment(timer)
        } label: {
            MenuBarLabel(timer: timer)
        }
        .menuBarExtraStyle(.window)
    }
}

struct MenuBarLabel: View {
    let timer: FocusTimer

    var body: some View {
        let fraction = timer.state == .idle ? nil : timer.remainingFraction
        HStack(spacing: 4) {
            Image(nsImage: MenuBarIcon.image(remaining: fraction, paused: timer.state == .paused))
            if timer.state != .idle {
                Text(timer.timeString)
                    .monospacedDigit()
            }
        }
    }
}

/// Ícono de plantilla (se adapta a barra clara/oscura): un reloj con el anillo abierto,
/// como el logo de la app. Mientras corre, el anillo muestra el tiempo restante.
enum MenuBarIcon {
    static func image(remaining: Double?, paused: Bool) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            let center = NSPoint(x: rect.midX, y: rect.midY)
            let radius: CGFloat = 7.2
            NSColor.black.setStroke()

            if let remaining {
                // Anillo de fondo tenue + arco del tiempo restante desde las 12, en sentido horario.
                let track = NSBezierPath()
                track.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
                track.lineWidth = 1.4
                NSColor.black.withAlphaComponent(0.3).setStroke()
                track.stroke()

                NSColor.black.setStroke()
                let arc = NSBezierPath()
                arc.appendArc(withCenter: center, radius: radius, startAngle: 90,
                              endAngle: 90 - 360 * CGFloat(max(0.001, remaining)), clockwise: true)
                arc.lineWidth = 1.8
                arc.lineCapStyle = .round
                arc.stroke()
            } else {
                // Logo: anillo con una abertura arriba a la izquierda.
                let ring = NSBezierPath()
                ring.appendArc(withCenter: center, radius: radius, startAngle: 125, endAngle: 105, clockwise: false)
                ring.lineWidth = 1.6
                ring.lineCapStyle = .round
                ring.stroke()
            }

            if paused {
                let bar = NSBezierPath()
                bar.move(to: NSPoint(x: center.x - 1.6, y: center.y - 2.6))
                bar.line(to: NSPoint(x: center.x - 1.6, y: center.y + 2.6))
                bar.move(to: NSPoint(x: center.x + 1.6, y: center.y - 2.6))
                bar.line(to: NSPoint(x: center.x + 1.6, y: center.y + 2.6))
                bar.lineWidth = 1.4
                bar.lineCapStyle = .round
                bar.stroke()
            } else {
                // Manecillas: una a las 12 y otra hacia las 4.
                let hands = NSBezierPath()
                hands.move(to: NSPoint(x: center.x, y: center.y + 4.2))
                hands.line(to: center)
                hands.line(to: NSPoint(x: center.x + 3.0, y: center.y - 2.0))
                hands.lineWidth = 1.5
                hands.lineCapStyle = .round
                hands.lineJoinStyle = .round
                hands.stroke()
            }
            return true
        }
        image.isTemplate = true
        return image
    }
}
