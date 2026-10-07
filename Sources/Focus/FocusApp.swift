import AppKit
import SwiftUI

@main
struct FocusApp: App {
    @State private var timer = FocusTimer()

    init() {
        // No Dock icon: the app lives only in the menu bar.
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
        let running = timer.state != .idle
        Image(nsImage: MenuBarIcon.image(
            remaining: running ? timer.remainingFraction : nil,
            paused: timer.state == .paused,
            time: running ? timer.timeString : nil
        ))
    }
}

/// Template image (adapts to light/dark menu bars): a clock with an open ring, like the
/// app logo, plus the remaining time in a pill while running. It is drawn as one image
/// because the menu bar ignores SwiftUI fonts and backgrounds in the label.
enum MenuBarIcon {
    private static let font = NSFont.monospacedDigitSystemFont(ofSize: 12.5, weight: .bold)
    private static let pillHeight: CGFloat = 17
    private static let pillPadding: CGFloat = 6
    private static let gap: CGFloat = 5

    static func image(remaining: Double?, paused: Bool, time: String?) -> NSImage {
        let textSize = time.map { ($0 as NSString).size(withAttributes: [.font: font]) } ?? .zero
        let width = time == nil ? 18 : 18 + gap + ceil(textSize.width) + pillPadding * 2
        let size = NSSize(width: width, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            let center = NSPoint(x: 9, y: rect.midY)
            let radius: CGFloat = 7.2
            NSColor.black.setStroke()

            if let remaining {
                // Faint track + arc of the remaining time from 12 o'clock, clockwise.
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
                // Logo: ring with a gap at the top left.
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
                // Hands: one at 12, the other towards 4.
                let hands = NSBezierPath()
                hands.move(to: NSPoint(x: center.x, y: center.y + 4.2))
                hands.line(to: center)
                hands.line(to: NSPoint(x: center.x + 3.0, y: center.y - 2.0))
                hands.lineWidth = 1.5
                hands.lineCapStyle = .round
                hands.lineJoinStyle = .round
                hands.stroke()
            }

            if let time {
                // Filled pill with the digits knocked out, so they show the menu bar through.
                let pill = NSRect(x: 18 + gap, y: (rect.height - pillHeight) / 2,
                                  width: rect.width - 18 - gap, height: pillHeight)
                NSColor.black.setFill()
                NSBezierPath(roundedRect: pill, xRadius: 5.5, yRadius: 5.5).fill()
                let context = NSGraphicsContext.current?.cgContext
                context?.setBlendMode(.destinationOut)
                (time as NSString).draw(
                    at: NSPoint(x: pill.minX + pillPadding, y: pill.midY - textSize.height / 2),
                    withAttributes: [.font: font, .foregroundColor: NSColor.black]
                )
                context?.setBlendMode(.normal)
            }
            return true
        }
        image.isTemplate = true
        return image
    }
}
