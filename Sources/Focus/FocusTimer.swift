import AppKit
import Observation
import UserNotifications

enum Phase: String, Codable {
    case focus, shortBreak, longBreak

    var title: String {
        switch self {
        case .focus: "Enfoque"
        case .shortBreak: "Descanso corto"
        case .longBreak: "Descanso largo"
        }
    }
}

enum RunState {
    case idle, running, paused
}

struct Preferences: Codable, Equatable {
    var focusMinutes = 25
    var shortBreakMinutes = 5
    var longBreakMinutes = 15
    var longBreakEvery = 4
    var dailyGoal = 10
    var autoStartBreaks = true
    var autoStartFocus = false
    var playSound = true
    var showTimeInMenuBar = true
}

struct FocusTask: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var done = false
    var pomodoros = 0
}

/// Estado completo de la app: el temporizador, las tareas y el historial diario.
/// Se guarda en UserDefaults; nada sale de la máquina.
@MainActor
@Observable
final class FocusTimer {
    private(set) var phase: Phase = .focus
    private(set) var state: RunState = .idle
    private(set) var remaining: TimeInterval = 0
    private(set) var total: TimeInterval = 0
    /// Pomodoros de enfoque terminados en el ciclo actual (define cuándo toca descanso largo).
    private(set) var cycleCount = 0

    var prefs: Preferences {
        didSet {
            Store.save(prefs, key: Store.prefsKey)
            if state == .idle { resetPhase() }
        }
    }

    var tasks: [FocusTask] {
        didSet { Store.save(tasks, key: Store.tasksKey) }
    }

    var selectedTaskID: UUID? {
        didSet { Store.save(selectedTaskID, key: Store.selectedTaskKey) }
    }

    /// Pomodoros completados por día, con clave "yyyy-MM-dd".
    private(set) var history: [String: Int] {
        didSet { Store.save(history, key: Store.historyKey) }
    }

    @ObservationIgnored private var endDate: Date?
    @ObservationIgnored private var ticker: Timer?

    init() {
        prefs = Store.load(Preferences.self, key: Store.prefsKey) ?? Preferences()
        tasks = Store.load([FocusTask].self, key: Store.tasksKey) ?? []
        selectedTaskID = Store.load(UUID?.self, key: Store.selectedTaskKey) ?? nil
        history = Store.load([String: Int].self, key: Store.historyKey) ?? [:]
        resetPhase()
    }

    // MARK: - Lectura

    var remainingFraction: Double {
        total > 0 ? max(0, min(1, remaining / total)) : 1
    }

    var timeString: String {
        let seconds = Int(remaining.rounded(.up))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    var todayCount: Int { history[Self.dayKey(Date())] ?? 0 }

    var selectedTask: FocusTask? {
        tasks.first { $0.id == selectedTaskID }
    }

    var hasProgress: Bool { state != .idle || remaining < total }

    // MARK: - Acciones

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

    /// Vuelve la fase actual al inicio, sin contarla.
    func stop() {
        stopTicker()
        endDate = nil
        state = .idle
        resetPhase()
    }

    /// Pasa a la siguiente fase sin registrar la actual.
    func skip() {
        stopTicker()
        endDate = nil
        state = .idle
        advance(completedFocus: false)
    }

    func resetCycle() {
        cycleCount = 0
        phase = .focus
        stop()
    }

    func addTask(_ title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let task = FocusTask(title: trimmed)
        tasks.append(task)
        if selectedTask == nil || selectedTask?.done == true { selectedTaskID = task.id }
    }

    func toggleDone(_ id: UUID) {
        guard let i = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[i].done.toggle()
        if tasks[i].done, selectedTaskID == id {
            selectedTaskID = tasks.first { !$0.done }?.id
        }
    }

    func deleteTask(_ id: UUID) {
        tasks.removeAll { $0.id == id }
        if selectedTaskID == id { selectedTaskID = tasks.first { !$0.done }?.id }
    }

    func clearCompletedTasks() {
        tasks.removeAll { $0.done }
    }

    // MARK: - Internos

    private func duration(of phase: Phase) -> TimeInterval {
        let minutes = switch phase {
        case .focus: prefs.focusMinutes
        case .shortBreak: prefs.shortBreakMinutes
        case .longBreak: prefs.longBreakMinutes
        }
        return TimeInterval(minutes * 60)
    }

    private func resetPhase() {
        total = duration(of: phase)
        remaining = total
    }

    private func startTicker() {
        stopTicker()
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        // .common para que siga corriendo mientras el popover o un menú están abiertos.
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
        stopTicker()
        endDate = nil
        state = .idle
        let finished = phase
        advance(completedFocus: finished == .focus)
        Notifier.phaseFinished(finished, next: phase, nextMinutes: Int(total / 60), sound: prefs.playSound)

        let autoStart = phase == .focus ? prefs.autoStartFocus : prefs.autoStartBreaks
        if autoStart { start() }
    }

    private func advance(completedFocus: Bool) {
        if phase == .focus {
            if completedFocus {
                history[Self.dayKey(Date()), default: 0] += 1
                if let i = tasks.firstIndex(where: { $0.id == selectedTaskID }) {
                    tasks[i].pomodoros += 1
                }
            }
            cycleCount += 1
            phase = cycleCount % max(1, prefs.longBreakEvery) == 0 ? .longBreak : .shortBreak
        } else {
            if phase == .longBreak { cycleCount = 0 }
            phase = .focus
        }
        resetPhase()
    }

    private static func dayKey(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}

enum Store {
    static let prefsKey = "prefs"
    static let tasksKey = "tasks"
    static let selectedTaskKey = "selectedTask"
    static let historyKey = "history"

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
    /// Las notificaciones sólo funcionan dentro del .app (con bundle id), no con `swift run`.
    private static var available: Bool { Bundle.main.bundleIdentifier != nil }

    static func requestAuthorization() {
        guard available else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func phaseFinished(_ finished: Phase, next: Phase, nextMinutes: Int, sound: Bool) {
        if sound { NSSound(named: finished == .focus ? "Glass" : "Hero")?.play() }
        guard available else { return }

        let content = UNMutableNotificationContent()
        if finished == .focus {
            content.title = "¡Pomodoro completado!"
            content.body = "Toca un \(next.title.lowercased()) de \(nextMinutes) min."
        } else {
            content.title = "Se acabó el descanso"
            content.body = "Hora de volver a enfocarse: \(nextMinutes) min."
        }
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
