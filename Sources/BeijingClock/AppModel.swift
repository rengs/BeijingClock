import Foundation
import BeijingTimeCore

/// 主线程使用。闹钟计算在 BeijingTimeCore，这里只负责读写状态。
final class AppModel {
    let store: AlarmStore
    private(set) var state: PersistedState
    let recoveredBackupURL: URL?
    var onChange: (() -> Void)?
    var onDue: ((_ rings: [DueAlarm], _ missed: [DueAlarm]) -> Void)?
    var onSaveError: ((String) -> Void)?

    init(store: AlarmStore = AlarmStore(fileURL: AlarmStore.applicationSupportFileURL())) {
        self.store = store
        let loaded = (try? store.load()) ?? LoadResult(state: .empty, backupURL: nil)
        var state = loaded.state
        state.handled = AlarmScheduling.prune(state.handled, now: Date())
        if let size = state.clock.customFontSize {
            state.clock.customFontSize = MenuBarMetrics.clampedFontSize(size)
        }
        self.state = state
        self.recoveredBackupURL = loaded.backupURL
    }

    func alarm(id: UUID) -> Alarm? {
        state.alarms.first { $0.id == id }
    }

    func tick(now: Date = Date()) {
        let result = AlarmScheduling.evaluate(
            alarms: state.alarms,
            now: now,
            handled: state.handled
        )
        let pruned = AlarmScheduling.prune(result.handled, now: now)
        guard result.alarms != state.alarms || pruned != state.handled else { return }
        state.alarms = result.alarms
        state.handled = pruned
        save()
        if !result.rings.isEmpty || !result.missed.isEmpty {
            onDue?(result.rings, result.missed)
        }
        onChange?()
    }

    func add(_ alarm: Alarm) -> Result<Void, AlarmBookError> {
        switch AlarmBook.adding(alarm, to: state) {
        case .failure(let error):
            return .failure(error)
        case .success(let updated):
            state = updated
            save()
            tick()
            onChange?()
            return .success(())
        }
    }

    func update(_ alarm: Alarm) -> Result<Void, AlarmBookError> {
        switch AlarmBook.updating(alarm, in: state) {
        case .failure(let error):
            return .failure(error)
        case .success(let updated):
            state = updated
            save()
            tick()
            onChange?()
            return .success(())
        }
    }

    func delete(id: UUID) {
        state = AlarmBook.deleting(id: id, from: state)
        save()
        onChange?()
    }

    func toggle(id: UUID) -> Result<Void, AlarmBookError> {
        switch AlarmBook.toggling(id: id, in: state) {
        case .failure(let error):
            return .failure(error)
        case .success(let updated):
            state = updated
            save()
            tick()
            onChange?()
            return .success(())
        }
    }

    func updateClock(_ body: (inout ClockDisplayOptions) -> Void) {
        body(&state.clock)
        if let size = state.clock.customFontSize {
            state.clock.customFontSize = MenuBarMetrics.clampedFontSize(size)
        }
        save()
        onChange?()
    }

    func setSoundEnabled(_ enabled: Bool) {
        guard state.soundEnabled != enabled else { return }
        state.soundEnabled = enabled
        save()
        onChange?()
    }

    func save() {
        do {
            try store.save(state)
        } catch {
            onSaveError?("无法保存数据：\(error.localizedDescription)")
        }
    }
}
