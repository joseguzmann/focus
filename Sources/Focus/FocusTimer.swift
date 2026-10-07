import AppKit
import Observation
import UserNotifications

enum Phase: String, Codable {
    case focus, rest

    var title: String {
        switch self {
        case .focus: "Focus"
        case .rest: "Break"
        }
    }
}

enum RunState {
    case idle, running, paused
}

struct Preferences: Codable, Equatable {
    var focusMinutes = 25
    var breakMinutes = 5
    var playSound = true
}

struct Tag: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var colorIndex: Int
}

/// A completed focus pomodoro.
struct Pomodoro: Identifiable, Codable {
    var id = UUID()
    var finishedAt: Date
    var minutes: Int
    var tagID: UUID?
}

/// App state: the timer, the tags and the completed pomodoros.
/// Stored in UserDefaults; nothing leaves the machine.
@MainActor
@Observable
final class FocusTimer {
    private(set) var phase: Phase = .focus
    private(set) var state: RunState = .idle
    private(set) var remaining: TimeInterval = 0
    private(set) var total: TimeInterval = 0

    var prefs: Preferences {
        didSet {
            Store.save(prefs, key: Store.prefsKey)
            if state == .idle { resetPhase() }
        }
    }

    private(set) var tags: [Tag] {
        didSet { Store.save(tags, key: Store.tagsKey) }
    }

    var selectedTagID: UUID? {
        didSet { Store.save(selectedTagID, key: Store.selectedTagKey) }
    }

    private(set) var pomodoros: [Pomodoro] {
        didSet { Store.save(pomodoros, key: Store.pomodorosKey) }
    }

    @ObservationIgnored private var endDate: Date?
    @ObservationIgnored private var ticker: Timer?

    init() {
        prefs = Store.load(Preferences.self, key: Store.prefsKey) ?? Preferences()
        tags = Store.load([Tag].self, key: Store.tagsKey) ?? []
        selectedTagID = Store.load(UUID?.self, key: Store.selectedTagKey) ?? nil
        pomodoros = Store.load([Pomodoro].self, key: Store.pomodorosKey) ?? []
        resetPhase()
    }

    // MARK: - Reading

    var remainingFraction: Double {
        total > 0 ? max(0, min(1, remaining / total)) : 1
    }

    var timeString: String {
        let seconds = Int(remaining.rounded(.up))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    var hasProgress: Bool { state != .idle || remaining < total }

    var selectedTag: Tag? {
        tags.first { $0.id == selectedTagID }
    }

    var todayPomodoros: [Pomodoro] {
        pomodoros.filter { Calendar.current.isDateInToday($0.finishedAt) }
    }

    func count(for tagID: UUID?, todayOnly: Bool = false) -> Int {
        (todayOnly ? todayPomodoros : pomodoros).filter { $0.tagID == tagID }.count
    }

    // MARK: - Timer

    func toggle() {
        state == .running ? pause() : start()
    }

    func start() {
        guard state != .running else { return }
        endDate = Date().addingTimeInterval(remaining)
        state = .running
        startTicker()
    }

    func pause() {
        guard state == .running else { return }
        tick()
        stopTicker()
        endDate = nil
        state = .paused
    }

    /// Restarts the current phase without counting it.
    func reset() {
        stopTicker()
        endDate = nil
        state = .idle
        resetPhase()
    }

    /// Moves to the other phase without recording the current one.
    func skip() {
        reset()
        phase = phase == .focus ? .rest : .focus
        resetPhase()
    }

    // MARK: - Tags

    func addTag(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let tag = Tag(name: trimmed, colorIndex: tags.count % TagColor.palette.count)
        tags.append(tag)
        if selectedTagID == nil { selectedTagID = tag.id }
    }

    /// Pomodoros of the deleted tag become untagged.
    func deleteTag(_ id: UUID) {
        tags.removeAll { $0.id == id }
        for i in pomodoros.indices where pomodoros[i].tagID == id {
            pomodoros[i].tagID = nil
        }
        if selectedTagID == id { selectedTagID = nil }
    }

    // MARK: - Internals

    private func resetPhase() {
        let minutes = phase == .focus ? prefs.focusMinutes : prefs.breakMinutes
        total = TimeInterval(minutes * 60)
        remaining = total
    }

    private func startTicker() {
        stopTicker()
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        // .common so it keeps ticking while the popover or a menu is open.
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }

    private func tick() {
        guard let endDate else { return }
        remaining = max(0, endDate.timeIntervalSinceNow)
        if remaining <= 0 { finish() }
    }

    private func finish() {
        let finished = phase
        if finished == .focus {
            pomodoros.append(Pomodoro(finishedAt: Date(), minutes: Int(total / 60), tagID: selectedTagID))
        }
        reset()
        phase = finished == .focus ? .rest : .focus
        resetPhase()
        Notifier.phaseFinished(finished, nextMinutes: Int(total / 60), sound: prefs.playSound)

        // Breaks start on their own; the next focus waits for you to start it.
        if phase == .rest { start() }
    }
}

enum Store {
    static let prefsKey = "settings"
    static let tagsKey = "tags"
    static let selectedTagKey = "selectedTag"
    static let pomodorosKey = "pomodoros"

    static func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    static func save<T: Encodable>(_ value: T, key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}

enum Notifier {
    /// Notifications only work inside the .app (it needs a bundle id), not with `swift run`.
    private static var available: Bool { Bundle.main.bundleIdentifier != nil }

    static func requestAuthorization() {
        guard available else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func phaseFinished(_ finished: Phase, nextMinutes: Int, sound: Bool) {
        if sound { NSSound(named: finished == .focus ? "Glass" : "Hero")?.play() }
        guard available else { return }

        let content = UNMutableNotificationContent()
        if finished == .focus {
            content.title = "Pomodoro complete!"
            content.body = "Time for a \(nextMinutes)-minute break."
        } else {
            content.title = "Break is over"
            content.body = "Ready for another \(nextMinutes)-minute pomodoro?"
        }
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
