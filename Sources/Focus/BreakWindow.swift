import AppKit
import SwiftUI

/// Shows a floating window when a pomodoro ends, while the break runs and when it ends,
/// following `FocusTimer.breakWindowMode`. It floats above other windows and on every
/// Space, so it is noticed without having to open the menu bar popover.
@MainActor
final class BreakWindowController: NSObject, NSWindowDelegate {
    private let timer: FocusTimer
    private var window: NSWindow?
    private var closingProgrammatically = false

    init(timer: FocusTimer) {
        self.timer = timer
        super.init()
        observe()
    }

    private func observe() {
        withObservationTracking {
            _ = timer.breakWindowMode
        } onChange: { [weak self] in
            // onChange fires before the new value is stored: read it on the next turn.
            DispatchQueue.main.async {
                self?.sync()
                self?.observe()
            }
        }
    }

    private func sync() {
        if timer.breakWindowMode == nil {
            hide()
        } else {
            show()
        }
    }

    private func show() {
        let window = window ?? makeWindow()
        if !window.isVisible { window.center() }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func hide() {
        guard let window, window.isVisible else { return }
        closingProgrammatically = true
        window.close()
        closingProgrammatically = false
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 400),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered, defer: false
        )
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.contentView = NSHostingView(rootView: BreakView().environment(timer))
        self.window = window
        return window
    }

    func windowWillClose(_ notification: Notification) {
        // Closed with the red button: forget the prompt; a running break keeps running.
        if !closingProgrammatically { timer.dismissWindow() }
    }
}

struct BreakView: View {
    @Environment(FocusTimer.self) private var timer

    var body: some View {
        VStack(spacing: 0) {
            switch timer.breakWindowMode {
            case .breakReady: breakReady
            case .onBreak: onBreak
            case .workReady: workReady
            case nil: EmptyView()
            }
        }
        .frame(width: 560, height: 400)
        .background(background)
    }

    private var background: some View {
        let color = timer.breakWindowMode == .breakReady ? Theme.focus : Theme.rest
        return LinearGradient(colors: [color.opacity(0.18), color.opacity(0.04)],
                              startPoint: .top, endPoint: .bottom)
    }

    // MARK: Pomodoro ended

    private var breakReady: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 54))
                .foregroundStyle(Theme.focus)
            Text("Pomodoro complete!")
                .font(.system(size: 30, weight: .semibold, design: .rounded))
            Text(summary)
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
            Spacer()
            HStack(spacing: 12) {
                SecondaryButton(title: "Skip break") { timer.skip() }
                    .keyboardShortcut(.cancelAction)
                PrimaryButton(title: "Start \(minutes)-min break", systemImage: "cup.and.saucer.fill",
                              color: Theme.rest) { timer.start() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.bottom, 32)
        }
    }

    // MARK: Break running

    private var onBreak: some View {
        VStack(spacing: 6) {
            Spacer()
            Text("BREAK")
                .font(.system(size: 15, weight: .semibold))
                .tracking(3)
                .foregroundStyle(Theme.rest)
            Text(timer.timeString)
                .font(.system(size: 132, weight: .medium, design: .rounded))
                .monospacedDigit()
            // Fills up as the break goes by.
            Capsule()
                .fill(Theme.rest.opacity(0.18))
                .frame(width: 320, height: 6)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(Theme.rest)
                        .frame(width: max(6, 320 * (1 - timer.remainingFraction)), height: 6)
                        .animation(.linear(duration: 0.5), value: timer.remainingFraction)
                }
            Text("Breathe, stretch, drink some water.")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .padding(.top, 12)
            Spacer()
            SecondaryButton(title: "End break and get back to work") { timer.backToWork() }
                .padding(.bottom, 28)
        }
    }

    // MARK: Break ended

    private var workReady: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "bolt.circle.fill")
                .font(.system(size: 54))
                .foregroundStyle(Theme.rest)
            Text("Break's over")
                .font(.system(size: 30, weight: .semibold, design: .rounded))
            Text("Ready for another \(minutes)-minute pomodoro?")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
            Spacer()
            HStack(spacing: 12) {
                SecondaryButton(title: "Later") { timer.dismissWindow() }
                    .keyboardShortcut(.cancelAction)
                PrimaryButton(title: "Back to work", systemImage: "play.fill",
                              color: Theme.focus) { timer.backToWork() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(.bottom, 32)
        }
    }

    private var minutes: Int { Int(timer.total / 60) }

    private var summary: String {
        let today = timer.todayPomodoros.count
        let count = today == 1 ? "1 pomodoro today" : "\(today) pomodoros today"
        guard let tag = timer.selectedTag else { return count }
        return "\(tag.name) · \(count)"
    }
}

private struct PrimaryButton: View {
    let title: String
    let systemImage: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 22)
                .frame(height: 42)
                .background(Capsule().fill(color))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct SecondaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 18)
                .frame(height: 42)
                .background(Capsule().fill(Color.secondary.opacity(0.12)))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
